import Bitcoin.RuleAttr
import Bitcoin.DataLaws.Interface
import Bitcoin.Consensus.TxCheck

/-!
# Bitcoin.Invariants.RC01

RC01's INV closure module — independent verification layer for rule-DB row
**INV-003**, the stripped-size oversize gate of `CheckTransaction`
(`consensus/tx_check.cpp:26-29` @cce32b168):

```
if (::GetSerializeSize(TX_NO_WITNESS(tx)) * WITNESS_SCALE_FACTOR > MAX_BLOCK_WEIGHT)
    return state.DoS(100, ..., REJECT_INVALID, "bad-txns-oversize");
```

— the witness, and the BIP144 marker/flag, are **not** counted.

`checkTransaction` itself now consumes the same stripped-size gate (its
`txStrippedWeightL` is `4 · serTxSize`, bridged to `DataLaws.baseSize` by
`Bitcoin.TxValidation.LocktimeSigOps.txStrippedWeightL_eq_dataLaws`, and
`checkTransaction_weight_bound` / `checkTransaction_weight_reject` there
carry TXV-003 / INV-003). This module independently re-derives the gate as a
standalone predicate over `DataLaws.baseSize` and pins it with
python3-cross-checked vectors:

- `sampleSegwitTx` (DataLaws): base 61 B → `4·61 = 244` → accept;
- a 1-input tx with a 1,333,000-byte scriptSig: base 1,333,065 B →
  `4·base = 5,332,260` → `bad-txns-oversize`.

The BIP141 transaction weight (`3·base + total`, `DataLaws.txWeight`) is a
different metric — it belongs to block weight, not this stateless gate.
-/

namespace Bitcoin.Invariants.RC01

open Bitcoin.Data Bitcoin.DataLaws Bitcoin.Consensus

/-- INV-003: Core's stripped-size oversize gate as a standalone predicate —
`bad-txns-oversize` iff `4 · baseSize(tx) > MAX_BLOCK_WEIGHT`, computed by
W02/W03's faithful `baseSize` (witness excluded). -/
@[rule "INV-003"]
def weightCheck (tx : Tx) : Option TxCheckError :=
  if baseSize tx * Bitcoin.Consensus.WITNESS_SCALE_FACTOR > MAX_BLOCK_WEIGHT then
    some .oversize
  else none

/-- INV-003 accept direction: stripped size within the budget ⇒
`weightCheck` passes. -/
theorem weightCheck_ok (tx : Tx)
    (h : baseSize tx * Bitcoin.Consensus.WITNESS_SCALE_FACTOR ≤ MAX_BLOCK_WEIGHT) :
    weightCheck tx = none := by
  unfold weightCheck
  split
  · next hc => exact absurd hc (by omega)
  · rfl

/-- INV-003 reject direction: stripped size above the budget ⇒
`weightCheck` rejects with exactly Core's `bad-txns-oversize`. -/
theorem weightCheck_fail (tx : Tx)
    (h : MAX_BLOCK_WEIGHT < baseSize tx * Bitcoin.Consensus.WITNESS_SCALE_FACTOR) :
    weightCheck tx = some .oversize := by
  unfold weightCheck
  split
  · rfl
  · next hc => exact absurd h (by omega)

/-- INV-003 characterisation: `weightCheck` passes exactly when the
stripped-size weight is within budget. -/
theorem weightCheck_none_iff (tx : Tx) :
    weightCheck tx = none ↔
      baseSize tx * Bitcoin.Consensus.WITNESS_SCALE_FACTOR ≤ MAX_BLOCK_WEIGHT := by
  constructor
  · intro h
    have key : baseSize tx * Bitcoin.Consensus.WITNESS_SCALE_FACTOR ≤ MAX_BLOCK_WEIGHT ∨
        MAX_BLOCK_WEIGHT < baseSize tx * Bitcoin.Consensus.WITNESS_SCALE_FACTOR := by
      omega
    cases key with
    | inl hle => exact hle
    | inr hgt =>
      exfalso
      rw [weightCheck_fail tx hgt] at h
      simp at h
  · exact weightCheck_ok tx

/-! ## Vectors -/

-- Accept vector: the DataLaws segwit sample (base 61 B) →
-- stripped weight 4·61 = 244 ≤ 4,000,000 (sizes python3-cross-checked in
-- research/w2-03-type-laws.md Appendix A). Its BIP141 weight is 250,
-- which is the separate BLOCK metric.
#guard_msgs in
example : txWeight sampleSegwitTx = 250 := by decide

#guard_msgs in
example : weightCheck sampleSegwitTx = none := by decide

-- Reject vector: one input with a 1,333,000-byte scriptSig.
-- base = 4 + 1 + (32+4+5+1333000+4) + 1 + (8+1+1) + 4 = 1,333,065
-- (5-byte CompactSize: 1,333,000 > 0xffff);
-- stripped weight = 4·1,333,065 = 5,332,260 > 4,000,000.
def bigTx : Tx :=
  { sampleSegwitTx with
    vin := [{ prevout := OutPoint.null
              scriptSig := ⟨zeroBytes 1333000⟩
              sequence := 0xFFFFFFFF }]
    witness := [[]] }

/-- info: some (Bitcoin.Consensus.TxCheckError.oversize) -/
#guard_msgs in
#eval weightCheck bigTx

/-- info: 5332260 -/
#guard_msgs in
#eval baseSize bigTx * Bitcoin.Consensus.WITNESS_SCALE_FACTOR

/-- info: 5332263 -/
#guard_msgs in
#eval txWeight bigTx

-- Axiom pin: the exact-gate characterisation (sorry-free, standard axioms).
/-- info: 'Bitcoin.Invariants.RC01.weightCheck_none_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms weightCheck_none_iff

end Bitcoin.Invariants.RC01
