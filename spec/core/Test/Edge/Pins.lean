import Bitcoin.Consensus.TxCheck
import Bitcoin.Chain.Basic

/-! # EDGE-MUTANT killer pins (survivor mutants, the edge-case pins)

Boundary pins for the survivor mutants in `spec/db/mutations/mutations.yaml`
that no runner layer can distinguish (error-constructor-equivalent, or the
predicate is outside every judged layer). These are the `tests:` channel of
`mutate.py` — a mutant that flips any pin fails this module.

The corpus rows that distinguish the same mutants are
`spec/vectors/edge/{tx_invalid_edge,tx_valid_edge}.json` (see
`BitcoinVectors.Gen.EdgeVectors`); `te-000/te-001` additionally kill
MUT-TXV-001/003 through the runner pass-rate.
-/

namespace Test.Edge.Pins

open Bitcoin.Data Bitcoin.Consensus Bitcoin.Chain

set_option maxRecDepth 100000
set_option maxHeartbeats 1000000

private def bytes (a : Array UInt8) : ByteArray := ByteArray.mk a
private def h32 : ByteArray := bytes #[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]

/-- Vin-empty pin: the vin-empty predicate at Tx level (BIP144 marker framing
makes the shape wire-representable; the runner row is `te-000`). -/
example : checkTransaction ⟨1, [], [⟨1, ⟨bytes #[0x51]⟩⟩], 0, []⟩
    = some .vinEmpty := by decide

/-- Oversize-gate pin (918df3c): the oversize gate is the Core
stripped size `txStrippedWeightL = 4·serTxSize` (tx_check.cpp:26-30
@cce32b168), which excludes the BIP144 marker/witness — so the
+4-loosening kill sits at `stripped = 4_000_004 = 4M+4`: the true gate
rejects, a loosened `> MAX+4` bound accepts (4M+4 is the only kill
point: stripped ≡ 0 mod 4). `bigW` (s=4) keeps the `txWeightL`
pin (3·base+total = 4_000_001 = Core `GetTransactionWeight` — the BLOCK
metric; the mutant does not touch `txWeightL`); `bigW6` (s=6) is the
killer: base serTxSize = 1_000_001 = stripped 4_000_004. -/
private def bigW (n : Nat) : Tx :=
  ⟨1, [⟨⟨h32, 0⟩, ⟨bytes #[0x51,0x51,0x51,0x51]⟩, 0xFFFFFFFF⟩],
   (List.range n).map (fun _ => ⟨1, ⟨bytes #[0x51]⟩⟩), 0, [[bytes #[0x51]]]⟩

example : txWeightL (bigW 99994) = 4_000_001 := by native_decide

/-- The stripped-gate killer shape (s=6 = `bigW` with a 6-byte scriptSig;
witness kept to show the gate is witness/marker-blind). -/
private def bigW6 (n : Nat) : Tx :=
  ⟨1, [⟨⟨h32, 0⟩, ⟨bytes #[0x51,0x51,0x51,0x51,0x51,0x51]⟩, 0xFFFFFFFF⟩],
   (List.range n).map (fun _ => ⟨1, ⟨bytes #[0x51]⟩⟩), 0, [[bytes #[0x51]]]⟩

example : txStrippedWeightL (bigW6 99994) = 4_000_004 := by native_decide
example : checkTransaction (bigW6 99994) = some .oversize := by native_decide

/-- MAX_MONEY pin: per-output MAX_MONEY boundary. The mutant routes
MAX_MONEY+1 through the cumulative guard (`some .txoutTotalTooLarge`), so only
the error constructor distinguishes it — hence this test-channel pin. -/
private def tx1out (v : Amount) : Tx :=
  ⟨1, [⟨⟨h32, 0⟩, ⟨ByteArray.empty⟩, 0xFFFFFFFF⟩],
   [⟨v, ⟨bytes #[0x51]⟩⟩], 0, []⟩
private def tx2out (v1 v2 : Amount) : Tx :=
  ⟨1, [⟨⟨h32, 0⟩, ⟨ByteArray.empty⟩, 0xFFFFFFFF⟩],
   [⟨v1, ⟨bytes #[0x51]⟩⟩, ⟨v2, ⟨bytes #[0x51]⟩⟩], 0, []⟩

example : checkTransaction (tx1out (MAX_MONEY + 1)) = some .voutTooLarge := by decide
example : checkTransaction (tx2out MAX_MONEY 1) = some .txoutTotalTooLarge := by decide

/-- Compact-target pin: the compact-target magnitude mask. Bit 23 in the nBits word
is the sign-magnitude flag nibble, not target magnitude; the widened mask
(`0x00ffffff`) shifts 0x800000 by 216 instead of returning 0. -/
example : compactTarget 0x1e800000 = 0 := by decide
example : compactTarget 0x1d00ffff = 0xffff * 256 ^ (0x1d - 3) := by decide

end Test.Edge.Pins
