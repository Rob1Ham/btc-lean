import Bitcoin.SigHash.Interface
import Bitcoin.SigHash.Digest
import Bitcoin.SigHash.Ops
import Bitcoin.Interpreter.Defs

/-!
# Z01 dark-corner audit — tri-modal SIGHASH_SINGLE + FindAndDelete

2026-10-16/17. Python3 probes:
`ecdsa_one_probe.py`,
`fad_probe.py`, `Z01_print_one.cpp` = compiled-Core witness).

Ground truth: Bitcoin Core @ `cce32b168`.

Proof-form note (audit meta-finding F-Z01-004): kernel `decide` through
the seam's SHA-256 (double compression, UInt32 array folds) does NOT close
in toolchain v4.35.0 — the tree's own digest pins use `native_decide`
(runners/Test/Audit/MutationPackCrypto.lean), which would add
`Lean.ofReduceBool` outside this audit's allowed axiom trio. Every pin
below is therefore kernel-pure:
  * preimage-level (`legacyMsgL`, list vehicle) for digest facts;
  * digest-level facts are VERIFIED BY EXECUTION (`#eval` + python3
    cross-check), not as in-file theorems.
The out-of-range-SINGLE arm needs no hashing (early return), so C1's
digest pins are decide-cheap.
-/

namespace Bitcoin.Proofs.Audit.Z01

open Bitcoin.Data Bitcoin.SigHash Bitcoin.Interpreter Bitcoin.Serialization

set_option maxRecDepth 100000
set_option maxHeartbeats 1000000

private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else none

private def fromHex (s : String) : ByteArray :=
  go (s.toList.filter (fun c => c != '\n' && c != ' ')) ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc

private def fromHexL (s : String) : Bytes := bL (fromHex s)

/-- 1-vin / 0-vout tx: nIn = 0 ≥ vout.size = 0 ⇒ legacy SINGLE overflow. -/
def txOOR : Bitcoin.Data.Tx :=
  { version := 1
    vin := [⟨⟨fromHex "1111111111111111111111111111111111111111111111111111111111111111", 0⟩,
            ⟨fromHex ""⟩, 0xffffffff⟩]
    vout := []
    locktime := 0x00000000, witness := [] }

/-- 1-vin / 1-vout tx for the FindAndDelete digest case (fad_probe.py). -/
def fadTx : Bitcoin.Data.Tx :=
  { version := 1
    vin := [⟨⟨fromHex "1111111111111111111111111111111111111111111111111111111111111111", 0⟩,
            ⟨fromHex ""⟩, 0xffffffff⟩]
    vout := [⟨10000, ⟨fromHex "51"⟩⟩]
    locktime := 0x00000000, witness := [] }

/-! ## C1 — tri-modal SIGHASH_SINGLE (F-Z01-001, repaired by FIX-L-SIGHASH2) -/

section C1

/-- **Core's** `uint256::ONE` bytes — compiled-Core witness
(a compiled-Core witness prints the bytes `hash.begin()` feeds
secp256k1): internal order `01` ‖ 31 zeros (uint256.cpp:35
`const uint256 uint256::ONE(1);` + ctor `base_blob(uint8_t v) : m_data{v}`,
uint256.h:40). -/
def uint256OneCore : ByteArray :=
  fromHex "0100000000000000000000000000000000000000000000000000000000000000"

/-- The tree's constant is now Core's `uint256::ONE`: `01` ‖ 31 zeros
(SigHash/Interface.lean). -/
example : SINGLE_OVERFLOW_ONE =
    fromHex "0100000000000000000000000000000000000000000000000000000000000000" := by
  decide

/-- **F-Z01-001 repaired pin**: the tree's constant IS Core's
`uint256::ONE`. -/
example : (SINGLE_OVERFLOW_ONE == uint256OneCore) = true := by decide

/-- The legacy overflow digest returns Core's `uint256::ONE` (concrete tx,
ht 0x03 and SINGLE|ACP 0x83; the early return fires before any vin access —
interpreter.cpp:1614-1622). -/
example : signatureHashLegacy txOOR 0 ⟨fromHex ""⟩ 0x00000003
    = SINGLE_OVERFLOW_ONE := by decide

example : signatureHashLegacy txOOR 0 ⟨fromHex ""⟩ 0x00000083
    = SINGLE_OVERFLOW_ONE := by decide

/-- Hence for the same concrete tx the tree's digest equals Core's ONE. -/
example : (bytesBEq (signatureHashLegacy txOOR 0 ⟨fromHex ""⟩ 0x00000003)
             uint256OneCore) = true := by decide

-- BIP143 arm: hashOutputs = ZERO (SCR-141/SWT-046) — same tx shape.
example : hashOutputsL txOOR 0 0x03 = zeroHashL := by decide

-- BIP341 arm: fail-closed (TPR-042) — pinned in-tree at
-- Bitcoin.Crypto.Taproot.Sighash.sigMsgTaproot_single_no_output_none
-- (X03 namespace) + Interpreter/Rules.lean `schnorrVerdict_sighash_fail_closed`
-- (SCR-166): construction `none` ⇒ verdict false. Not restated here
-- (cross-reference).

end C1

/-! ## C2 — FindAndDelete as consensus behavior in legacy sighash -/

section C2

-- S = 70 deterministic bytes; pattern = its serialized push 0x46 ‖ S
def S70L : Bytes :=
  fromHexL "303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f3031323334"
def sigPushL : Bytes := 0x46 :: S70L

-- scriptCode = push S; CHECKSIG (P2PK shape — the sig appears in it)
def fadSCL : Bytes := sigPushL ++ [0xac]
-- same-LENGTH control whose bytes do NOT match the pattern
def fadSCctlL : Bytes := 0x46 :: (List.replicate 70 0x00) ++ [0xac]

-- Core verdict (fad_probe.py): nFound = 1, scriptCode → "ac"
example : findAndDeleteL fadSCL sigPushL = [0xac] := by decide

-- boundary-only matching (fad_probe.py boundary-probe): the same byte run
-- inside a PUSHDATA1 payload (4c 48 ‖ 46‖S‖ac) is NOT deleted
example : findAndDeleteL ([0x4c, 0x48] ++ sigPushL ++ [0xac]) sigPushL
    = [0x4c, 0x48] ++ sigPushL ++ [0xac] := by decide

-- a boundary match may SPLIT an opcode (fad_probe.py split-probe):
-- 02 0a ab bc  -"02 0a"->  ab bc  (0x02 = push-2 of "0a ab"; after the
-- deletion the 2nd payload byte re-parses as an opcode)
example : findAndDeleteL (fromHexL "020aabbcc") (fromHexL "020a")
    = fromHexL "abbc" := by decide

-- F-Z01-002 end-to-end preimage pins (fad_probe.py, byte-exact):
-- with FindAndDelete (Core), the check's message is the PREIMAGE over "ac"
example : legacyMsgL fadTx 0 (bL (fromHex "ac")) 0x00000001
    = fromHexL "010000000111111111111111111111111111111111111111111111111111111111111111110000000001acffffffff01102700000000000001510000000001000000" := by
  decide

-- Consensus-observability: had FindAndDelete NOT run, the message differs
example : (legacyMsgL fadTx 0 (fromHexL "ac") 0x00000001 ==
           legacyMsgL fadTx 0 fadSCctlL 0x00000001) = false := by
  decide

-- Digest-level facts (VERIFIED BY EXECUTION, not restated as theorems —
-- see the proof-form note in the module docstring):
--   dshaL(legacyMsgL fadTx 0 "ac" 1)       = 325fa2a61e8d1eaf88b409bb3e2dc5cd6424f627adfd506ee16652c3ec0a9e8a  (tree #eval == python3)
--   dshaL(legacyMsgL fadTx 0 ctl 1)        = 4bafa604f64cb087691ac0f1aa5f943247c43fdd8c9436a99c1a8754cb9c53fc  (python3)
--   tree's legacy digest == python3 port on both (fad_probe.py, F-Z01-002).

end C2

end Bitcoin.Proofs.Audit.Z01
