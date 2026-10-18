import Bitcoin.DataLaws.Laws
import Bitcoin.Consensus.TxCheck
import Bitcoin.Chain.Basic
import Bitcoin.Capstone.Pow

/-!
# Z11 dark-corner audit — null-prevout empty-vs-32-byte + UInt32 target truncation

2026-10-16. Python3 probes:
`z11_c1_nullprevout_probe.py`,
`z11_c2_setcompact_probe.py`).

Ground truth: Bitcoin Core @ `cce32b168`.

## C1 — Null prevout: empty-vs-32-byte distinction (Review-1 C1 bug)

Core semantics: `COutPoint::IsNull() = hash.IsNull() && n == NULL_INDEX`
(`primitives/transaction.h:43`) where `hash` is a `uint256` — a FIXED 32-byte
blob whose `IsNull` is `std::all_of(... == 0)` (`uint256.h:50-55`). "Null" is
therefore *exactly* `n = 0xffffffff ∧ 32 zero bytes`; an empty (0-byte) hash is
a Lean-representation-only state that must NOT classify as null.

CAPTURED in-tree: `OutPoint.isNull` (`spec/core/Bitcoin/Data/Tx.lean:35-37`)
conjuncts `o.hash.size = 32` (verified below T4/T5), `OutPoint.null` is the
canonical 32-zero-byte value, and `checkTransaction` routes on it exactly like
Core (`consensus/tx_check.cpp:55-64`: coinbase → cbLength arm, else any null
prevout → `bad-txns-prevout-null`; order vinEmpty/voutEmpty/oversize/outputs/
inputsDuplicate/coinbase matches). Decisive behavioral pins below:
- byte-identical hash, only `n` differing (`0xffffffff` vs `0x00000000`)
  lands in DIFFERENT consensus branches (coinbase/cbLength vs non-coinbase);
- an empty-hash + NULL_INDEX input is NOT coinbase and passes the stateless
  null check (the pre-fix PoC would have classified it coinbase and failed
  `bad-cb-length` on its empty scriptSig).

## C2 — UInt32 target truncation (Review-1 C1 bug)

Core semantics: `arith_uint256::SetCompact` (`arith_uint256.cpp:176-194`)
shifts the 23-bit mantissa LEFT by `8·(size−3)` on a 256-bit accumulator —
real targets (e.g. difficulty-1 = `0xffff · 256^26`, 224 bits) do not fit in
`uint32`. Performing the shift in `UInt32` silently truncates (pre-fix PoC).

CAPTURED in-tree: `Bitcoin.Chain.compactTarget` (`Chain/Basic.lean:28-32`)
computes the shift in `Nat` (comment: "shift in Nat: targets exceed 32
bits"); the decode gate `Bitcoin.Capstone.Pow.targetOk` (pow.cpp:95-116 arms)
plus `powOk` (`BLK-037/038/039`) consume it. Decisive pins below:
- `compactTarget 0x1d00ffff > 0xFFFFFFFF` — NO UInt32-valued decoder can
  represent even the difficulty-1 target (the truncation bug is impossible);
- python3-pinned exact magnitudes for real mainnet nBits (genesis `0x1d00ffff`,
  block-400000 `0x181bc330`, wiki classic `0x1b0404cb`);
- overflow-class nBits (`0x22010000`, `0xff123456`) rejected by the
  `≤ powLimit` arm exactly where Core's `fOverflow` fires.

F-Z11-003 (closed): Core's `fNegative` arm (`arith_uint256.cpp:188`:
word ≠ 0 ∧ bit 0x00800000 set → reject at `pow.cpp:155`) is now applied by
`targetOk` through `Bitcoin.Capstone.Pow.setCompactFull`. The sign-bit
encoding `0x03800123` is REJECTED, matching Core; the pin below records the
corrected result (BLK-037/038, X08 decode-gate rows).
-/

namespace Bitcoin.Proofs.Audit.Z11

open Bitcoin.Data Bitcoin.Chain Bitcoin.Capstone.Pow Bitcoin.Consensus

-- byte-replication helper (`ByteArray.replicate` is absent in this
-- toolchain, as documented in Audit/Z03; foldl keeps `decide`-reduction cheap)
private def repBytes (n : Nat) (v : UInt8) : ByteArray :=
  (List.replicate n v).foldl (fun acc b => acc.push b) ByteArray.empty

/-! ## C1: null prevout — the empty-vs-32-byte distinction -/

-- T1 (positive control): canonical null outpoint IS null (Core
-- COutPoint().IsNull() == true; python T1).
example : OutPoint.isNull OutPoint.null = true := by decide

-- T2 (Core-representable): 32 zero bytes but n = 0 → NOT null
-- (Core COutPoint(uint256(),0).IsNull() == false; python T2).
example : OutPoint.isNull ⟨repBytes 32 0, 0⟩ = false := by decide

-- T3: n = NULL_INDEX but one hash byte nonzero → NOT null
-- (python T3: 00×31 ‖ 01).
example : OutPoint.isNull ⟨(repBytes 31 0).push 1, NULL_INDEX⟩ = false := by decide

-- T4 (THE dark corner): EMPTY hash + n = NULL_INDEX → NOT null. This is the
-- Review-1 bug: the pre-fix PoC treated empty as null. Reuses DataLaws'
-- regression lemma (isNull_rejects_empty_hash); python T4.
example : OutPoint.isNull ⟨ByteArray.empty, NULL_INDEX⟩ = false :=
  Bitcoin.DataLaws.isNull_rejects_empty_hash NULL_INDEX

-- T5: short (16-byte) hash + n = NULL_INDEX → NOT null (size ≠ 32); python T5.
example : OutPoint.isNull ⟨repBytes 16 0, NULL_INDEX⟩ = false := by decide

/-! ### consensus-level consequences (checkTransaction routing) -/

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

-- REAL genesis-style coinbase input: 32 zero bytes + n = 0xffffffff.
def cbTx : Tx :=
  { version := 1
    vin := [⟨⟨repBytes 32 0, 0xffffffff⟩, ⟨fromHex "046aaf"⟩, 0xffffffff⟩]
    vout := [⟨5000000000, ⟨fromHex "51"⟩⟩]
    locktime := 0, witness := [] }

-- classified coinbase (transaction.h:347) …
example : cbTx.isCoinBase = true := by decide
-- … and routed to the cbLength arm (3 bytes ∈ [2,100] → passes).
example : checkTransaction cbTx = none := by decide

-- DECISIVE: byte-identical hash, n = 0 instead of 0xffffffff. Core: NOT null,
-- NOT coinbase → NON-coinbase branch, prevoutNull never fires. Had `isNull`
-- ignored `n` (or mis-sized the hash), this would misroute to the cbLength arm
-- and reject on the 1-byte scriptSig.
def n0Tx : Tx :=
  { version := 1
    vin := [⟨⟨repBytes 32 0, 0x00000000⟩, ⟨fromHex "51"⟩, 0xffffffff⟩]
    vout := [⟨10000, ⟨fromHex "51"⟩⟩]
    locktime := 0, witness := [] }

example : n0Tx.isCoinBase = false := by decide
example : checkTransaction n0Tx = none := by decide

-- DECISIVE: a genuinely null prevout in a TWO-input tx → non-coinbase branch
-- fires `bad-txns-prevout-null` (tx_check.cpp:62-64; INV-009/TXV-003-row).
def nullSpendTx : Tx :=
  { version := 1
    vin := [⟨⟨repBytes 32 7, 5⟩, ⟨fromHex ""⟩, 0xfffffffe⟩,
            ⟨⟨repBytes 32 0, 0xffffffff⟩, ⟨fromHex ""⟩, 0xffffffff⟩]
    vout := [⟨10000, ⟨fromHex "51"⟩⟩]
    locktime := 0, witness := [] }

example : nullSpendTx.isCoinBase = false := by decide
example : checkTransaction nullSpendTx = some TxCheckError.prevoutNull := by decide

-- THE empty-hash state (Lean-representation-only): must NOT classify coinbase
-- and must NOT trigger prevoutNull. The PRE-FIX PoC (empty ≡ null) would have
-- classified this tx coinbase and rejected `bad-cb-length` (0-byte scriptSig).
def emptyHashTx : Tx :=
  { version := 1
    vin := [⟨⟨ByteArray.empty, 0xffffffff⟩, ⟨fromHex ""⟩, 0xffffffff⟩]
    vout := [⟨10000, ⟨fromHex "51"⟩⟩]
    locktime := 0, witness := [] }

example : emptyHashTx.isCoinBase = false := by decide
example : checkTransaction emptyHashTx = none := by decide

/-! ## C2: UInt32 target truncation — the Nat-shift decode -/

-- Difficulty-1 target is EXACTLY 0xffff·256^26 (arith_uint256.cpp:180-185
-- magnitude; existing core theorem, restated as a pin).
example : compactTarget 0x1d00ffff = 0xffff * 256 ^ (0x1d - 3) :=
  Bitcoin.Chain.compactTarget_difficulty_one

-- DECISIVE anti-truncation pin: even the difficulty-1 target EXCEEDS UInt32
-- range — no UInt32-valued decoder could ever represent it (the pre-fix PoC's
-- `0xffff <<< 232` in UInt32 collapses to 0; python: UInt32-shift-bug=0).
theorem z11_compactTarget_gt_u32max : 0xFFFFFFFF < compactTarget 0x1d00ffff := by decide

-- python3-pinned magnitudes (z11_c2_setcompact_probe.py):
-- genesis 0x1d00ffff → 0xffff·256^26 (224 bits)
example : compactTarget 0x1d00ffff =
    26959535291011309493156476344723991336010898738574164086137773096960 := by decide
-- real mainnet anchor block 400000: nBits 0x181bc330
example : compactTarget 0x181bc330 =
    680733321990486529407107157001552378184394215934016880640 := by decide
-- wiki classic 0x1b0404cb → 0x404cb·256^24
example : compactTarget 0x1b0404cb =
    1653206561150525499452195696179626311675293455763937233695932416 := by decide

-- size ≤ 3 right-shift arm (word = 0x008000 → 0x8000 >> 8 = 0x80 … wait:
-- 0x03008000: size=3, word=0x008000, shift 0 → 0x8000 = 32768; python-AGREE).
example : compactTarget 0x03008000 = 32768 := by decide

-- decode gate agreement with Core CheckProofOfWork (pow.cpp:95-116 @cce32b168):
-- real mainnet nBits passes …
example : targetOk 0x1d00ffff = true := by decide
example : targetOk 0x181bc330 = true := by decide
-- … target 0 rejected (0x01003456: word 0x3456 <<(8·(3-1))… size=1 → 0x3456>>>16 = 0) …
example : targetOk 0x01003456 = false := by decide
-- … overflow-class nBits rejected: Core fires fOverflow (arith_uint256.cpp:190-192)
-- and the live gate applies the same fOverflow flag — same verdict (python AGREE).
example : targetOk 0x22010000 = false := by decide
example : targetOk 0xff123456 = false := by decide
-- size=33 at the boundary: no fOverflow in Core, but target > powLimit → reject (AGREE).
example : targetOk 0x2100ffff = false := by decide

-- F-Z11-003 (closed, corrected pin): Core REJECTS 0x03800123 via the fNegative
-- arm (word = 0x123 ≠ 0, sign bit 0x00800000 set; arith_uint256.cpp:188,
-- pow.cpp:155). The live targetOk now applies the same SetCompact flag and
-- rejects it too (Bitcoin.Capstone.Pow.targetOk_negative_witness).
example : targetOk 0x03800123 = false := by decide
-- Companion sign-bit pin: 0x1d80ffff (powLimit.GetCompact(true)) is a negative
-- compact target and is rejected even though its masked magnitude ≤ powLimit.
example : targetOk 0x1d80ffff = false := by decide

end Bitcoin.Proofs.Audit.Z11
