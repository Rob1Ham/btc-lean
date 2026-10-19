import Bitcoin.DataLaws.Interface
import BitcoinProofs.Theorems.WitnessSerialization

/-!
# TPR-071 — the annex enters the actual transaction weight

`validationWeightInit_annex_included` proves that the *serialized stack
size helper* grows when the annex is appended. The consensus weight,
however, is computed from the real BIP144 transaction serialization. This
module composes the two: for a one-input transaction carrying the witness
stack `items`, replacing that stack by `items ++ [annex]` changes
`txWeight` by exactly

* the growth of the stack-count CompactSize (which crosses a boundary
  when the new item count reaches 253, 65536, …),
* the annex length CompactSize, and
* the annex bytes themselves.

The primary theorem `txWeight_annex_witness_contribution` states this for
the transaction's actual witness slot; the equality
`txWeight_witness_slot_append_annex` is the slot-level form used by the
argument, and the strict-growth corollary records that the contribution is
never zero.
-/

namespace BitcoinProofs.Theorems.Ops.TPR071

open Bitcoin.Data Bitcoin.DataLaws
open Bitcoin.Crypto.Taproot.Program (compactSizeEnc_size_mono compactSizeEnc_size_pos)

/-- Size of one BIP144 witness stack: stack-count CompactSize plus each
item's length CompactSize and payload. -/
private theorem serWitnessStack_size (s : List ByteArray) :
    (serWitnessStack s).size =
      (compactSizeEnc s.length).size +
        (s.map (fun d => (compactSizeEnc d.size).size + d.size)).sum := by
  unfold serWitnessStack
  rw [ByteArray.size_append]
  have h : ∀ (l : List ByteArray) (init : ByteArray),
      (l.foldl (fun acc item => acc ++ compactSizeEnc item.size ++ item) init).size =
        init.size + (l.map (fun d => (compactSizeEnc d.size).size + d.size)).sum := by
    intro l
    induction l with
    | nil => intro init; simp
    | cons a l ih =>
      intro init
      simp only [List.foldl_cons, List.map_cons, List.sum_cons]
      rw [ih]
      simp only [ByteArray.size_append]
      omega
  rw [h s ByteArray.empty]
  simp

/-- Appending one witness item adds the item's length prefix and payload,
plus any growth of the stack-count prefix (the count itself grows by one,
so this term can be larger than one byte at 253/65536/…). -/
private theorem serWitnessStack_size_append_single (items : List ByteArray)
    (item : ByteArray) :
    (serWitnessStack (items ++ [item])).size =
      (serWitnessStack items).size +
        ((compactSizeEnc (items.length + 1)).size -
          (compactSizeEnc items.length).size) +
        ((compactSizeEnc item.size).size + item.size) := by
  rw [serWitnessStack_size, serWitnessStack_size]
  simp only [List.length_append, List.length_singleton, List.map_append,
    List.map_cons, List.map_nil, List.sum_append, List.sum_cons, List.sum_nil]
  have hm : (compactSizeEnc items.length).size ≤
      (compactSizeEnc (items.length + 1)).size :=
    compactSizeEnc_size_mono (Nat.le_succ items.length)
  omega

/-- Slot-level weight composition: replacing one input's witness stack
`items` by `items ++ [annex]` adds the annex (and count-prefix growth) to
the real transaction weight. -/
theorem txWeight_witness_slot_append_annex (tx : Tx) (hvin : tx.vin.length = 1)
    (items : List ByteArray) (annex : ByteArray) :
    txWeight { tx with witness := [items ++ [annex]] } =
      txWeight { tx with witness := [items] } +
        ((compactSizeEnc (items.length + 1)).size -
          (compactSizeEnc items.length).size) +
        ((compactSizeEnc annex.size).size + annex.size) := by
  have hbase : baseSize { tx with witness := [items ++ [annex]] } =
      baseSize { tx with witness := [items] } := rfl
  rw [txWeight_eq_four_base_add_marker_add_witness,
    txWeight_eq_four_base_add_marker_add_witness, hbase]
  have hw₁ : (serWitness { tx with witness := [items ++ [annex]] }).size =
      (serWitnessStack (items ++ [annex])).size := by
    unfold serWitness
    rw [hvin]
    simp
  have hw₀ : (serWitness { tx with witness := [items] }).size =
      (serWitnessStack items).size := by
    unfold serWitness
    rw [hvin]
    simp
  rw [hw₁, hw₀, serWitnessStack_size_append_single]
  omega

/-- **TPR-071 (whole rule).** For a transaction whose witness slot is
`items`, appending the annex changes the actual `txWeight` by the annex
length CompactSize, the annex payload, and any stack-count CompactSize
growth. The annex is therefore part of the transaction-weight
serialization, not only of the size helper. -/
@[rule "TPR-071"]
theorem txWeight_annex_witness_contribution (tx : Tx) (hvin : tx.vin.length = 1)
    (items : List ByteArray) (annex : ByteArray)
    (hwit : tx.witness = [items]) :
    txWeight { tx with witness := [items ++ [annex]] } =
      txWeight tx +
        ((compactSizeEnc (items.length + 1)).size -
          (compactSizeEnc items.length).size) +
        ((compactSizeEnc annex.size).size + annex.size) := by
  rw [txWeight_witness_slot_append_annex tx hvin items annex]
  have h : { tx with witness := [items] } = tx := by
    cases tx with
    | mk version vin vout locktime witness =>
      simp only at hwit
      subst hwit
      rfl
  rw [h]

/-- The annex contribution is strictly positive: even an empty annex pays
its length CompactSize, and the appended item always grows the count
prefix by at least its own encoded count byte. -/
@[rule "TPR-071"]
theorem txWeight_annex_witness_contribution_pos (tx : Tx)
    (hvin : tx.vin.length = 1) (items : List ByteArray) (annex : ByteArray)
    (hwit : tx.witness = [items]) :
    txWeight tx < txWeight { tx with witness := [items ++ [annex]] } := by
  rw [txWeight_annex_witness_contribution tx hvin items annex hwit]
  have hm := compactSizeEnc_size_mono (Nat.le_succ items.length)
  have hp := compactSizeEnc_size_pos annex.size
  omega

end BitcoinProofs.Theorems.Ops.TPR071
