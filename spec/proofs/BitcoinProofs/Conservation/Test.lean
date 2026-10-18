import BitcoinProofs.Conservation.Thms

/-!
# BitcoinProofs.Conservation.Test — executable cross-checks

Every numeral below was produced by `reference.py` in this directory
(`python3 reference.py` regenerates and re-asserts all of them); the
`decide` proofs make Lean recompute the same values from the definitions,
so the two implementations must agree or the build fails.

Sections:
1. The 41-epoch subsidy table (epochs 0..40), incl. the two boundary
   heights 6,720,000 (last satoshi epoch starts) and 6,930,000 (subsidy 0).
2. Issuance / 21M cap (THM-039): exact total 2,099,999,997,690,000.
3. Supply at selected heights (THM-040), all ≤ cap.
4. Hand-conservation instance: totalIn 4000 = totalOut 1000 + fee 3000,
   exercised THROUGH the frozen `single_tx_conservation` /
   `single_tx_fee_in_range` theorems (InputAuth := trivially true).
5. L3 axiom pins for this package's headline theorems.
-/

namespace BitcoinProofs.Conservation.Test

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Conservation

/-! ## 1. Subsidy table, epochs 0..40 (rows from `reference.py`) -/

example : blockSubsidy 0 = 5000000000 := by decide
example : blockSubsidy 210000 = 2500000000 := by decide
example : blockSubsidy 420000 = 1250000000 := by decide
example : blockSubsidy 630000 = 625000000 := by decide
example : blockSubsidy 840000 = 312500000 := by decide
example : blockSubsidy 1050000 = 156250000 := by decide
example : blockSubsidy 1260000 = 78125000 := by decide
example : blockSubsidy 1470000 = 39062500 := by decide
example : blockSubsidy 1680000 = 19531250 := by decide
example : blockSubsidy 1890000 = 9765625 := by decide
example : blockSubsidy 2100000 = 4882812 := by decide
example : blockSubsidy 2310000 = 2441406 := by decide
example : blockSubsidy 2520000 = 1220703 := by decide
example : blockSubsidy 2730000 = 610351 := by decide
example : blockSubsidy 2940000 = 305175 := by decide
example : blockSubsidy 3150000 = 152587 := by decide
example : blockSubsidy 3360000 = 76293 := by decide
example : blockSubsidy 3570000 = 38146 := by decide
example : blockSubsidy 3780000 = 19073 := by decide
example : blockSubsidy 3990000 = 9536 := by decide
example : blockSubsidy 4200000 = 4768 := by decide
example : blockSubsidy 4410000 = 2384 := by decide
example : blockSubsidy 4620000 = 1192 := by decide
example : blockSubsidy 4830000 = 596 := by decide
example : blockSubsidy 5040000 = 298 := by decide
example : blockSubsidy 5250000 = 149 := by decide
example : blockSubsidy 5460000 = 74 := by decide
example : blockSubsidy 5670000 = 37 := by decide
example : blockSubsidy 5880000 = 18 := by decide
example : blockSubsidy 6090000 = 9 := by decide
example : blockSubsidy 6300000 = 4 := by decide
example : blockSubsidy 6510000 = 2 := by decide
example : blockSubsidy 6720000 = 1 := by decide   -- epoch 32: the LAST satoshi
example : blockSubsidy 6930000 = 0 := by decide   -- epoch 33: subsidy exhausted
example : blockSubsidy 7140000 = 0 := by decide
example : blockSubsidy 7350000 = 0 := by decide
example : blockSubsidy 7560000 = 0 := by decide
example : blockSubsidy 7770000 = 0 := by decide
example : blockSubsidy 7980000 = 0 := by decide
example : blockSubsidy 8190000 = 0 := by decide
example : blockSubsidy 8400000 = 0 := by decide

/-! ## 2. Issuance and the 21M cap (THM-039) -/

example : totalIssuance = 2099999997690000 := by decide

example : issuanceThrough 40 = totalIssuance := by decide   -- flat after epoch 33
example : issuanceThrough 100 = totalIssuance := by decide

example : MoneyRange ((2099999997690000 : Nat) : Amount) = true := by decide
example : MAX_MONEY = 2100000000000000 := by decide

/-! ## 3. Supply at selected heights (THM-040), all ≤ the cap -/

example : supplyAt 0 = 5000000000 := by decide
example : supplyAt 1 = 10000000000 := by decide
example : supplyAt 209999 = 1050000000000000 := by decide
example : supplyAt 210000 = 1050002500000000 := by decide
example : supplyAt 692999 = 1876875000000000 := by decide
example : supplyAt 6719999 = 2099999997480000 := by decide
example : supplyAt 6720000 = 2099999997480001 := by decide
example : supplyAt 6929999 = 2099999997690000 := by decide
example : supplyAt 6930000 = 2099999997690000 := by decide
example : supplyAt 13439999 = 2099999997690000 := by decide
example : supplyAt 13440000 = 2099999997690000 := by decide

example : supplyAt 6929999 ≤ totalIssuance := by decide
example : supplyAt 13440000 ≤ totalIssuance := by decide

/-! ## 4. Hand-conservation instance (through the frozen theorems) -/

/-- Two utxo coins: 1500 sats at vout 0, 2500 sats at vout 1. -/
def coinA : Coin := ⟨1500, 0, false, Script.empty⟩
def coinB : Coin := ⟨2500, 0, false, Script.empty⟩

def oA : OutPoint := ⟨ByteArray.empty, 0⟩
def oB : OutPoint := ⟨ByteArray.empty, 1⟩

/-- The test UTXO view: vout 0 → coinA, vout 1 → coinB, else nothing. -/
def uTest : UtxoSet := fun o =>
  if o.n = 0 then some coinA else if o.n = 1 then some coinB else none

def iA : TxIn := ⟨oA, Script.empty, 0⟩
def iB : TxIn := ⟨oB, Script.empty, 0⟩

def txTest : Tx :=
  ⟨1, [iA, iB], [⟨400, Script.empty⟩, ⟨600, Script.empty⟩], 0, []⟩

/-- Every prevout this test touches exists in `uTest`. -/
theorem uTest_has (o : OutPoint) (h : o = oA ∨ o = oB) : uTest o ≠ none := by
  rcases h with rfl | rfl
  · simp [uTest, oA]
  · simp [uTest, oB]

theorem hexists_txTest : ∀ i ∈ txTest.vin, uTest i.prevout ≠ none := by
  intro i hi
  have hm : i = iA ∨ i = iB := by
    rcases List.mem_cons.mp hi with rfl | hin
    · exact Or.inl rfl
    · rcases List.mem_cons.mp hin with rfl | h2
      · exact Or.inr rfl
      · exact absurd h2 (by simp)
  rcases hm with rfl | rfl
  · exact uTest_has _ (Or.inl rfl)
  · exact uTest_has _ (Or.inr rfl)

/-- The sums: 4000 in, 1000 out, fee 3000 (reference.py §4). -/
example : totalIn uTest txTest = 4000 := by decide
example : totalOut txTest = 1000 := by decide

/-- THM-036 instance, end to end through the frozen theorem:
`totalIn = totalOut + fee` with `totalOut ≤ totalIn` forces `fee ≥ 0`
(even with a do-nothing InputAuth). -/
example : (0 : Amount) ≤ 3000 := by
  have h := single_tx_conservation (InputAuth := fun _ => True) uTest txTest 3000
    (fun _ _ => trivial) hexists_txTest ⟨by decide, by decide⟩ (by decide) (by decide)
  exact h

/-- INV-030/TXV-025 instance, end to end: the fee is in full MoneyRange. -/
example : MoneyRange (3000 : Amount) = true := by
  have h := single_tx_fee_in_range uTest txTest 3000
    hexists_txTest ⟨by decide, by decide⟩ (by decide) (by decide)
  exact h

/-- THM-038 instance: a coinbase claiming exactly subsidy + fees passes. -/
example : coinbaseAmountOk 0 (100 : Amount) (Tx.mk 1 [] [⟨5000000100, Script.empty⟩] 0 []) = true := by
  refine decide_eq_true ?_
  -- totalOut cb = 5000000100 = blockSubsidy 0 + 100
  decide

/-- The counterexample from `reference.py` §5, as a Lean statement: WITHOUT
`hle`, the frozen equation alone admits a negative fee — this is why
added `hle : totalOut ≤ totalIn` to `single_tx_conservation`. -/
example : ∃ (vi vo fee : Amount), vi = vo + fee ∧ MoneyRange vi = true ∧
    MoneyRange vo = true ∧ fee < 0 ∧ ¬ (vo ≤ vi) :=
  ⟨5, 10, -5, by decide, by decide, by decide, by decide, by decide⟩

/-! ## 5. L3 axiom pins (D2): drift on any of these fails the build -/

/--
info: 'BitcoinProofs.Conservation.moneyRange_add' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in #print axioms BitcoinProofs.Conservation.moneyRange_add

/--
info: 'BitcoinProofs.Conservation.fee_moneyRange' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms BitcoinProofs.Conservation.fee_moneyRange

/--
info: 'BitcoinProofs.Conservation.totalIn_eq' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in #print axioms BitcoinProofs.Conservation.totalIn_eq

/--
info: 'BitcoinProofs.Conservation.subsidy_le_max' depends on axioms: [propext]
-/
#guard_msgs in #print axioms BitcoinProofs.Conservation.subsidy_le_max

/--
info: 'BitcoinProofs.Conservation.totalIssuance_exact' does not depend on any axioms
-/
#guard_msgs in #print axioms BitcoinProofs.Conservation.totalIssuance_exact

/--
info: 'BitcoinProofs.Conservation.supplyAt_le_cap' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in #print axioms BitcoinProofs.Conservation.supplyAt_le_cap

/--
info: 'BitcoinProofs.Conservation.coinbase_cap_exact' depends on axioms: [propext]
-/
#guard_msgs in #print axioms BitcoinProofs.Conservation.coinbase_cap_exact

end BitcoinProofs.Conservation.Test
