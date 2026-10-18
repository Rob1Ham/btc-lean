import Bitcoin.Numeric.Interface
import Bitcoin.Numeric.ScriptNum
import Bitcoin.Data.Basic
import Bitcoin.Data.Script
import Bitcoin.Data.Tx
import Bitcoin.Ledger.Interface
import Bitcoin.Ledger.Utxo
import Bitcoin.TxValidation.Interface
import Bitcoin.TxValidation.Mempool
import Bitcoin.Invariants.RC10
import Bitcoin.Interpreter.Defs

/-!
# Z07 dark-corner audit — MEMPOOL_HEIGHT at tx level + OP_1NEGATE

2026-10-16. Python3 probes:
`crosscheck.py` — ALL PASS,
`probe_num.lean`).

Ground truth: Bitcoin Core @ `cce32b168` (validation.cpp,
interpreter.cpp, script.h/cpp).

## C1 — MEMPOOL_HEIGHT = 0x7FFFFFFF at tx level (Review-1 report 07 §K8/TXV-042)

Core: mempool coins carry `MEMPOOL_HEIGHT = 0x7FFFFFFF` (txmempool.h:51,
injected at txmempool.cpp:804,816); `CalculatePrevHeights`
(validation.cpp:198-200) maps a sentinel-height coin to `tip + 1`
("assume all mempool transactions confirm in the next block") and a
MISSING coin to `nullopt` (fail-closed, validation.cpp:202-204); the
result feeds `CalculateSequenceLocks`/`CheckSequenceLocksAtTip`
(validation.cpp:210-270, evaluated at `tip + 1`).

The tree captures the CONSTANT (three definitions, all `0x7FFFFFFF`),
the 31-bit dominance, the coin-code packing roundtrip, and the tip+1
mapping — but the mapping (`RC10.prevHeightOrNext`, INV-118) is **not
composed** into the tx-level BIP68 path: `prevHeightData`
(TxValidation/Interface.lean:340) reads `c.height.toNat` RAW and maps a
missing coin to `(0, 0)` (fail-OPEN). Pins below (F-Z07-001):
  * `bip68SentinelDiv` — a version-2 tx with `nSequence = 0` spending a
    sentinel-height coin: tree `bip68HeightOk … 900001 = false`, Core
    says `true` (prevHeight 900001 → lockpoint 900000 < 900001);
  * `bip68CoreMapped` — mapping the coin height through
    `prevHeightOrNext … tip` first recovers Core's verdict `true`;
  * `bip68MissingFailOpen` — missing coin: tree `(0,0)`-fallback passes
    trivially, Core fail-closes (`nullopt` ⇒ not admitted).

## C2 — OP_1NEGATE: pushNum 0 decodes to -1 (Review-1 report 06 §1/SCR-047)

Core: wire `0x4f` → `case OP_1NEGATE:` computes `bn = (int)opcode -
(OP_1 - 1) = -1` (interpreter.cpp:499-523), pushes `bn.getvch()` =
CScriptNum::serialize(-1) = `{0x81}` (script.h:342-373); the byte 0x81
decodes back to -1 under either `fRequireMinimal` (script.h:246-271);
CheckMinimalPush (script.cpp:373-396 @ cce32b168) returns `false` for a
1-byte `0x81` payload under EVERY direct-push opcode (the cce32b168 text
has NO OP_1NEGATE early return — its "Excludes OP_1NEGATE, OP_1-16"
comment is stale; only the assert is there); `0x4f ≤ OP_16` so the 201
budget never counts it (interpreter.cpp:459-463). Captured in-tree:
parse (0x4f → `pushNum 0`), step (`stepBody` pushes `0x81`,
opCount-invariant, MINIMALDATA-ungated), encode, minimal-push,
op-budget. The ONE unpinned micro-fact was the minimal DECODE of the
exact pushed byte — pinned below (`dec_81_min` / `dec_81_pol`), plus
roundtrip, the negative-zero contrast, the canonical-`{0x81,0x00}` = +129
pair (cross-evidence for the F-Z07-002 Y07 mis-pin), step pins under both
policies, the CheckMinimalPush boundary trio, and the disabled-OP_RIGHT
contrast. All kernel `decide`s, sorry-free.
-/

namespace Bitcoin.Proofs.Audit.Z07

open Bitcoin.Data Bitcoin.Numeric Bitcoin.Ledger Bitcoin.TxValidation
open Bitcoin.TxValidation.Mempool Bitcoin.Invariants.RC10 Bitcoin.Interpreter
open Bitcoin.Script.Parser
open Bitcoin.Crypto.Seam (stubChecker)

set_option maxRecDepth 10000
set_option maxHeartbeats 4000000

-- core 4.35 has no DecidableEq Except (Y07 note); derive it test-locally
deriving instance DecidableEq for Except

/-! ## C1 — the MEMPOOL_HEIGHT sentinel at tx level -/

/-- The three tree definitions agree and equal Core's
`MEMPOOL_HEIGHT` (txmempool.h:51). -/
example : Bitcoin.Ledger.MEMPOOL_HEIGHT = 0x7FFFFFFF := rfl
example : mempoolHeight = Bitcoin.Ledger.MEMPOOL_HEIGHT := rfl
-- RC10's INV-118 theorems are stated against `Bitcoin.Ledger.MEMPOOL_HEIGHT`
-- directly (the built olean predates RC10's local `def MEMPOOL_HEIGHT`;
-- `mempool_height_ne_real : … h ≠ Bitcoin.Ledger.MEMPOOL_HEIGHT` confirms).

/-- The sentinel survives the coin-code packing with BOTH coinbase bits
(coins.h:77-89; python3 crosscheck "pack/decode sentinel"). -/
example : coinMetaDecode (coinMetaEncode 2147483647 false) = (2147483647, false) := rfl
example : coinMetaDecode (coinMetaEncode 2147483647 true) = (2147483647, true) := rfl
example : coinHeightOfCode (packCoinCode mempoolHeight false) = mempoolHeight :=
  mempoolHeight_pack_roundtrip
example : coinHeightOfCode (packCoinCode mempoolHeight true) = mempoolHeight := by
  decide

/-- Boundary dominance: at the maximal 31-bit-realizable tip the NEXT
height IS the sentinel (python3 crosscheck "boundary"), and no
mainnet-feasible height collides with it. -/
example : (2147483646 : UInt32) + 1 = mempoolHeight := rfl

theorem no_real_height_is_sentinel (h : UInt32) (hh : h.toNat ≤ 1000000) :
    h ≠ mempoolHeight := mempool_height_ne_real h hh

/-- The version-2 spender with `nSequence = 0` (BIP68 rel-0 height lock). -/
def txCsv : Tx :=
  { version := 2
    vin := [⟨⟨ByteArray.empty, 0⟩, ⟨ByteArray.empty⟩, 0x00000000⟩]
    vout := []
    locktime := 0x00000000, witness := [] }

/-- A view carrying the unconfirmed parent as a sentinel-height coin —
exactly what the mempool coins view injects (txmempool.cpp:804,816). -/
def uSentinel : UtxoSet := fun _ =>
  some { value := 1000, height := 0x7FFFFFFF, isCoinbase := false,
         scriptPubKey := ⟨ByteArray.empty⟩ }

def uEmpty : UtxoSet := fun _ => none

/-- **F-Z07-001 divergence pin (sentinel arm)**: the tree's tx-level BIP68
height projection on a sentinel-height coin is `false` at tip 900000 —
it uses the raw `0x7FFFFFFF` height (`prevHeightData`, Interface.lean:340),
so the lockpoint is `2147483646 ≥ 900001`. Core's `CalculatePrevHeights`
maps the sentinel to `tip + 1 = 900001` ⇒ lockpoint `900000 < 900001`
⇒ **`true`** (validation.cpp:198-200; python3 crosscheck "CORE rel=0"). -/
theorem bip68SentinelDiv :
    bip68HeightOk txCsv uSentinel true 900001 = false := by decide

/-- The Core-matching composition: mapping the view's coin heights
through `prevHeightOrNext … tip` (RC10's INV-118 helper) first, the SAME
`bip68HeightOk` returns Core's `true` — proving the divergence is exactly
the missing mapping, not the lockpoint algebra. -/
def uMapped (tip : UInt32) : UtxoSet := fun o =>
  (uSentinel o).map fun c => { c with height := prevHeightOrNext c.height tip }

theorem bip68CoreMapped :
    bip68HeightOk txCsv (uMapped 900000) true 900001 = true := by decide

/-- **F-Z07-001 divergence pin (missing arm)**: with the coin absent, the
tree's `(0, 0)` fallback passes trivially (lockpoint `-1 < 900001`) —
fail-OPEN — while Core's `CalculatePrevHeights` returns `nullopt` and the
mempool does NOT admit the tx (validation.cpp:202-204, fail-closed;
python3 crosscheck "LEAN missing-coin"). -/
theorem bip68MissingFailOpen :
    bip68HeightOk txCsv uEmpty true 900001 = true := by decide

/-! ## C2 — OP_1NEGATE: wire 0x4f, pushed byte 0x81, value -1 -/

section C2

/-- Encode: -1's canonical wire is the single byte 0x81
(CScriptNum::serialize, script.h:342-373; SCR-047). -/
theorem enc_81 : encodeScriptNum (-1 : ScriptNum) false = serU8 0x81 := rfl

/-- **The previously-unpinned micro-fact**: the pushed byte `0x81`
DECODES to -1 under the consensus minimal flag
(CScriptNum ctor, script.h:246-271; `129 % 128 ≠ 0` ⇒ minimal-OK,
`setVchBE [129] = -1`). This is the decode half of "pushNum 0 decodes
to -1" and closes the last gap in SCR-047's coverage. -/
theorem dec_81_min : decodeScriptNum (bytesFromLE [0x81]) true 4 = some (-1) := by
  decide

/-- Same verdict with the minimal flag off. -/
theorem dec_81_pol : decodeScriptNum (bytesFromLE [0x81]) false 4 = some (-1) := by
  decide

/-- Full roundtrip at the corner value. -/
theorem rt_81 :
    decodeScriptNum (encodeScriptNum (-1 : ScriptNum) false) true 4 = some (-1) := by
  decide

/-- Negative-zero CONTRAST: `0x80` is NOT an alternative -1 encoding —
it is 0 (and non-minimal as a 1-byte vector, SCR-083). -/
theorem dec_80_min : decodeScriptNum (bytesFromLE [0x80]) true 4 = none := by decide
theorem dec_80_val : decodeScriptNum (bytesFromLE [0x80]) false 4 = some 0 := by decide

/-- The canonical +129 encoding `81 00` decodes to **+129** under both
flags (the `vch[size-2] & 0x80` exception accepts it as minimal) —
NOT -1: python3 crosscheck "decode([0x81,0x00])"; cross-evidence for
F-Z07-002 (Y07's s09/s10 mis-pin). -/
theorem dec_8100 :
    decodeScriptNum (bytesFromLE [0x81, 0x00]) false 4 = some 129 := by decide
theorem dec_8100_min :
    decodeScriptNum (bytesFromLE [0x81, 0x00]) true 4 = some 129 := by decide

/-- Parse/serialize roundtrip at wire level (Parser/Defs.lean:219,385). -/
theorem parse_4f : parseFrom 2 (ByteArray.mk #[(0x4f : UInt8)]) 0 =
    some [Opcode.pushNum 0] := by decide
theorem ser_4f : serializeOpcode (Opcode.pushNum 0) =
    ByteArray.mk #[(0x4f : UInt8)] := by decide

/-- The canonical step (`stepBody`, Defs.lean:786): executed
`pushNum 0` pushes exactly `0x81`, opCount unchanged. -/
def zCtx : Ctx :=
  { flags := {}, pol := default, chk := ⟨stubChecker, default, none⟩,
    sv := .base, bytes := ByteArray.empty, ed := default }

def zSt : State := { stack := [], alt := [], vf := [], opCount := 0, codeSep := 0, vwLeft := none }

theorem step_4f :
    stepBody zCtx { ast := .pushNum 0, wire := 0x4f, next := 1 } zSt =
    .ok { zSt with stack := serU8 0x81 :: [], opCount := 0 } := by decide

/-- Core :518-522 "no need for a CheckMinimalPush here": MINIMALDATA does
NOT gate the pushNum path — same verdict under `minimalData := true`. -/
theorem step_4f_minimal :
    stepBody { zCtx with pol := { minimalData := true } }
      { ast := .pushNum 0, wire := 0x4f, next := 1 } zSt =
    .ok { zSt with stack := serU8 0x81 :: [], opCount := 0 } := by decide

/-- CheckMinimalPush boundary (script.cpp:382-384 @ cce32b168 — NO
OP_1NEGATE early return in this commit): a direct 1-byte push of `0x81`
is non-minimal under EVERY direct-push opcode, OP_1NEGATE included. -/
theorem cmp_81_01 : checkMinimalPush (serU8 0x81) 0x01 = false := by decide
theorem cmp_81_4c : checkMinimalPush (serU8 0x81) 0x4c = false := by decide
theorem cmp_81_4f : checkMinimalPush (serU8 0x81) 0x4f = false := by decide

/-- Budget exemption: `0x4f ≤ OP_16`, so pushNum 0 never counts
(interpreter.cpp:459-463, SCR-024) … -/
theorem opc_4f : opcodeCount [Opcode.pushNum 0] = 0 := by decide

/-- … and the raw byte `0x81` as an OPCODE is a different thing entirely:
OP_RIGHT, disabled (CVE-2010-5137 family) — `-1` comes only from `0x4f`. -/
theorem dis_81 : disabledWire 0x81 = true := by decide
theorem opc_81 : opcodeCount [Opcode.op ⟨0x81, by decide⟩] = 1 := by decide

end C2

/-! ## Axiom footprints (`#guard_msgs in #print axioms`, scratch rule 4) -/

/-- info: 'Bitcoin.Proofs.Audit.Z07.bip68SentinelDiv' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip68SentinelDiv

/-- info: 'Bitcoin.Proofs.Audit.Z07.bip68CoreMapped' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip68CoreMapped

/-- info: 'Bitcoin.Proofs.Audit.Z07.bip68MissingFailOpen' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip68MissingFailOpen

/-- info: 'Bitcoin.Proofs.Audit.Z07.dec_81_min' does not depend on any axioms -/
#guard_msgs in #print axioms dec_81_min

end Bitcoin.Proofs.Audit.Z07
