import Bitcoin.Consensus.TxCheck
import Bitcoin.SigHash.Interface
import Bitcoin.Serialization.Interface
import Bitcoin.Ledger.Interface
import Bitcoin.Capstone.Block
import Bitcoin.Capstone.Pow
import Bitcoin.Data.Basic
import Bitcoin.Data.Tx

/-! # GENERATED FILE — do not hand-edit.
Regenerate: python3 spec/scripts/audit/gen_mutation_pack.py

MutationPack (FAST tier): decide-only conformance pins — no digest
hashing — for the per-mutant `killed-pack` channel. The crypto
digest/EC pins live in MutationPackCrypto.lean (checked for the
mutants that need them).

Sections: §1 TXV corpus holes (FIND-W16-001/002/003 + cb-length),
§2 sighash tri-modal + the BIP143 E4a preimage bytes, §6 contextual
edges (maturity, BIP34, compactTarget mask).
-/

namespace Test.Audit.MutationPack

open Bitcoin.Data Bitcoin.Consensus Bitcoin.SigHash Bitcoin.Serialization
open Bitcoin.Capstone.Block Bitcoin.Capstone.Pow Bitcoin.Chain Bitcoin.Ledger

set_option maxRecDepth 100000
set_option maxHeartbeats 1000000

-- hex helpers (Test.Sighash pattern; compile-time constants)
private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
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

private def beHex (s : String) : ByteArray := fromHex s
private def bytes (a : Array UInt8) : ByteArray := ByteArray.mk a
private def txOf (hex : String) : Tx :=
  match decodeTx (fromHex hex) with
  | .ok t => t
  | .error _ => ⟨0, [], [], 0, []⟩   -- fixtures decode; never hit
private def scOf (hex : String) : Script := ⟨fromHex hex⟩
private def bOf (hex : String) : Bytes := bL (fromHex hex)

/-! ## §1 FIND-W16-001/002/003 corpus-hole shapes (TxCheck) -/

-- FIND-W16-001: vin-empty is unrepresentable on the wire (the 0x00
-- vin count reads as the BIP144 marker) but the RULE is a Tx-level
-- predicate — pinned at the Tx-value level.
example : checkTransaction ⟨1, [], [⟨1, ⟨bytes #[0x51]⟩⟩], 0, []⟩
    = some .vinEmpty := by decide

-- FIND-W16-002 post-FIX-TS04 (918df3c): the oversize gate is the
-- Core stripped size txStrippedWeightL = 4*serTxSize
-- (tx_check.cpp:26-30 @cce32b168), marker/witness excluded. 2-byte
-- cb scriptSig + minimal vouts: 99_995 → base 1_000_007 → stripped
-- 4_000_028 > 4M (reject); 99_994 → base 999_997 → 3_999_988 (accept).
def bigTx (n : Nat) : Tx :=
  ⟨1, [⟨OutPoint.null, ⟨bytes #[0x51, 0x51]⟩, 0xFFFFFFFF⟩],
   (List.range n).map (fun _ => ⟨1, ⟨bytes #[0x51]⟩⟩), 0, []⟩
example : checkTransaction (bigTx 99995) = some .oversize := by native_decide
example : checkTransaction (bigTx 99994) = none := by native_decide

-- the +4-weight LOOSENING kill (MUT-TXV-003): 6-byte cb scriptSig
-- + 99_994 vouts = base serTxSize 1_000_001 → stripped = 4·base =
-- 4_000_004 — over the TRUE bound (reject) but NOT over MAX+4 (a
-- loosened > MAX+4 bound accepts; stripped ≡ 0 mod 4, so 4M+4 is
-- the ONLY loosened-bound kill point). Post-FIX-TS04 repair: the
-- pre-TS04 5-byte shape = old-gate txWeightL 4_000_003 ≠ 0 mod 4
-- (marker-model story, retired); the stripped gate is
-- witness/marker-blind (F-TS04-001).
def bigTx8 (n : Nat) : Tx :=
  ⟨1, [⟨OutPoint.null, ⟨bytes #[0x51, 0x51, 0x51, 0x51, 0x51, 0x51]⟩, 0xFFFFFFFF⟩],
   (List.range n).map (fun _ => ⟨1, ⟨bytes #[0x51]⟩⟩), 0, []⟩
example : checkTransaction (bigTx8 99994) = some .oversize := by native_decide

-- FIND-W16-003: MAX_MONEY boundary EXACTLY.
def tx1out (v : Amount) : Tx :=
  ⟨1, [⟨⟨bytes #[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], 0⟩, ⟨ByteArray.empty⟩, 0xFFFFFFFF⟩],
   [⟨v, ⟨bytes #[0x51]⟩⟩], 0, []⟩
def tx2out (v1 v2 : Amount) : Tx :=
  ⟨1, [⟨⟨bytes #[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], 0⟩, ⟨ByteArray.empty⟩, 0xFFFFFFFF⟩],
   [⟨v1, ⟨bytes #[0x51]⟩⟩, ⟨v2, ⟨bytes #[0x51]⟩⟩], 0, []⟩
example : checkTransaction (tx1out MAX_MONEY) = none := by decide
example : checkTransaction (tx1out (MAX_MONEY + 1)) = some .voutTooLarge := by decide
example : checkTransaction (tx2out (MAX_MONEY / 2) (MAX_MONEY - MAX_MONEY / 2)) = none := by decide
example : checkTransaction (tx2out (MAX_MONEY / 2 + 1) (MAX_MONEY / 2))
    = some .txoutTotalTooLarge := by decide

-- cb-length lower bound (bad-cb-length, 1-byte scriptSig).
example : checkTransaction ⟨1, [⟨OutPoint.null, ⟨bytes #[0x51]⟩, 0xFFFFFFFF⟩],
    [⟨1, ⟨bytes #[0x51]⟩⟩], 0, []⟩ = some .cbLength := by decide

/-! ## §2 sighash tri-modal + BIP143 preimage field order -/

-- SIGHASH_SINGLE index overflow: legacy digest = uint256::ONE
-- (interpreter.cpp:1614-1622), also for SINGLE|ANYONECANPAY.
-- (decide-cheap: the overflow arm returns before any hashing.)
example : signatureHashLegacy ⟨1, [], [⟨1, ⟨bytes #[0x51]⟩⟩], 0, []⟩ 1
    (scOf "") 0x03 = SINGLE_OVERFLOW_ONE := by decide
example : signatureHashLegacy ⟨1, [], [⟨1, ⟨bytes #[0x51]⟩⟩], 0, []⟩ 1
    (scOf "") 0x83 = SINGLE_OVERFLOW_ONE := by decide

-- BIP143 E4a PREIMAGE bytes (decide-cheap: ACP zeroes the three
-- sub-hashes) — pins the 10-field ORDER: version, hashPrevouts,
-- hashSequence, outpoint, scriptCode, amount, nSequence,
-- hashOutputs, nLockTime, hashtype (bip-0143 E4).
example : bip143MsgL (txOf "0100000002e9b542c5176808107ff1df906f46bb1f2583b16112b95ee5380665ba7fcfc0010000000000ffffffff80e68831516392fcd100d186b3c2c7b95c80b53c77e77c35ba03a66b429a2a1b0000000000ffffffff0280969800000000001976a914de4b231626ef508c9a74a8517e6783c0546d6b2888ac80969800000000001976a9146648a8cd4531e1ec47f35916de8e259237294d1e88ac00000000") 0
    (bOf "0063ab68210392972e2eb617b2388771abe27235fd5ac44af8e61693261550447a4c3e39da98ac") 0x83 16777215
    = bL (beHex "0100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e9b542c5176808107ff1df906f46bb1f2583b16112b95ee5380665ba7fcfc00100000000270063ab68210392972e2eb617b2388771abe27235fd5ac44af8e61693261550447a4c3e39da98acffffff0000000000ffffffffb258eaf08c39fbe9fbac97c15c7e7adeb8df142b0df6f83e017f349c2b6fe3d20000000083000000") := by native_decide

/-! ## §6 contextual edges: coinbase maturity, BIP34, compactTarget -/

-- Coinbase maturity boundary (BLK-100/INV-028): spend at height 99
-- rejects, at 100 accepts (coin from height 0).
def cbCoin : OutPoint → Option Coin := fun _ => some ⟨1, 0, true, ⟨bytes #[0x51]⟩⟩
def spend1 : Tx := ⟨1, [⟨⟨bytes #[2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2], 0⟩, ⟨ByteArray.empty⟩, 0xFFFFFFFF⟩],
   [⟨1, ⟨bytes #[0x51]⟩⟩], 0, []⟩
example : maturityOk cbCoin spend1 99 = false := by decide
example : maturityOk cbCoin spend1 100 = true := by decide

-- BIP34 coinbase-height push (BLK-069): missing at an active height
-- rejects; vacuous below. (cb from §5's fixture has no push.)
example : bip34Ok 227931 (txOf "010000000100000000000000000000000000000000000000000000000000000000000000ffffffff020000ffffffff010100000000000000015100000000")
    = false := by decide
-- positive: scriptSig = 0x02 0x01 0x64 = minimal push of CScriptNum(100).
def wcbF : Tx := txOf "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff020164ffffffff010100000000000000015100000000"
example : bip34Ok 100 wcbF = true := by decide

-- FIND-W16-004: compactTarget mask ABOVE difficulty 1 — bit 23 of
-- the mantissa is MASKED OFF (0x1e800000 decodes to 0), and
-- targets above the mainnet powLimit fail targetOk.
example : compactTarget 0x1e800000 = 0 := by decide
example : targetOk 0x1e00ffff = false := by decide
example : targetOk 0x1d00ffff = true := by decide

end Test.Audit.MutationPack
