import Bitcoin.Capstone.Block

/-!
# BitcoinProofs.AF.PDW51 — TOP-251..255 row faces, Capstone/Block band

Route B: proofs-side restatements of `Bitcoin.Capstone.Block` weight and
coinbase-position rows. No core writes; `@[rule]` tags ride these
theorems. Axiom pin target: `[propext, Classical.choice, Quot.sound]`.
-/

namespace BitcoinProofs.AF.PDW51
open Bitcoin.Capstone.Block Bitcoin.Data

/-! ## Serialization width helpers (self-contained; core has no widths) -/

theorem serU8_size (x : UInt8) : (serU8 x).size = 1 := rfl
theorem serU16_size (x : UInt16) : (serU16 x).size = 2 := rfl
theorem serU32_size (x : UInt32) : (serU32 x).size = 4 := rfl
theorem serU64_size (x : UInt64) : (serU64 x).size = 8 := rfl

/-- Every CompactSize encoding emits at least its 1-byte marker. -/
theorem compactSizeEnc_size_pos (n : Nat) : 1 ≤ (compactSizeEnc n).size := by
  unfold compactSizeEnc
  split
  · rw [serU8_size]; omega
  · split
    · rw [ByteArray.size_append, serU8_size, serU16_size]; omega
    · split
      · rw [ByteArray.size_append, serU8_size, serU32_size]; omega
      · rw [ByteArray.size_append, serU8_size, serU64_size]; omega

/-- The BLK-024 byte sum `foldl Nat.add 0` is `List.sum`. -/
theorem foldl_add_eq_sum (l : List Nat) : l.foldl Nat.add 0 = l.sum := by
  rw [List.sum_eq_foldl]; rfl

/-! ## BLK-024: stripped size decomposition -/

/-- **BLK-024**: stripped size = 80-byte header + tx-count prefix + the
base (witness-stripped) serialized tx bytes (validation.cpp:3955; the
`bad-blk-length` face itself is the weight gate, BLK-026/INV-093). -/
@[rule "BLK-024"]
theorem strippedSize_row (txs : List Tx) :
    strippedSize txs = 80 + txCountPrefix txs
      + (txs.map (fun t => (serTx t).size)).sum := by
  simp only [strippedSize, foldl_add_eq_sum]

/-- Header + non-empty count prefix are always counted: `81 ≤ stripped`. -/
theorem strippedSize_ge_header_count (txs : List Tx) : 81 ≤ strippedSize txs := by
  have h : 1 ≤ txCountPrefix txs := compactSizeEnc_size_pos txs.length
  simp only [strippedSize]
  omega

/-- **BLK-024**: the stripped-size gate — `4 × stripped ≤ 4,000,000`
(`CheckBlock`'s `bad-blk-length`, validation.cpp:3955). The core model
checks the equivalent weight gate (`weightOk`); this definition restates
the stripped-size face of the same check. -/
@[rule "BLK-024"]
def strippedSizeOk (txs : List Tx) : Bool :=
  4 * strippedSize txs ≤ 4_000_000

/-- **BLK-024**: pass is exactly the ×4 bound. -/
@[rule "BLK-024"]
theorem strippedSizeOk_iff (txs : List Tx) :
    strippedSizeOk txs = true ↔ 4 * strippedSize txs ≤ 4_000_000 := by
  unfold strippedSizeOk
  exact decide_eq_true_iff

/-- **BLK-024** reject face: `strippedSizeOk = false` iff ×4 exceeds 4M. -/
@[rule "BLK-024"]
theorem strippedSizeOk_eq_false_iff (txs : List Tx) :
    strippedSizeOk txs = false ↔ 4_000_000 < 4 * strippedSize txs := by
  unfold strippedSizeOk
  rw [decide_eq_false_iff_not]
  exact Nat.not_le

/-- **BLK-024**: rejection is exactly `1,000,000 < strippedSize`
(`bad-blk-length`, in the row's bytes ×4 form). -/
@[rule "BLK-024"]
theorem strippedSize_bad_length_iff (txs : List Tx) :
    strippedSizeOk txs = false ↔ 1_000_000 < strippedSize txs := by
  rw [strippedSizeOk_eq_false_iff]
  omega

/-! ## BLK-025: BIP141 weight equation -/

/-- **BLK-025**: weight = 3 × stripped + total (BIP141; validation.h:143). -/
@[rule "BLK-025"]
theorem blockWeight_row (txs : List Tx) (totalSize : Nat) :
    blockWeight txs totalSize = 3 * strippedSize txs + totalSize := rfl

/-- The header alone contributes 240 WU even before the txs. -/
theorem blockWeight_ge_header (txs : List Tx) (totalSize : Nat) :
    240 + totalSize ≤ blockWeight txs totalSize := by
  have h := strippedSize_ge_header_count txs
  rw [blockWeight_row]; omega

/-! ## SWT-017: BIP141 weight/witness-discount algebra -/

/-- **SWT-017**: `4 × stripped = weight + witnessDiscount`, i.e. weight is
`4 × base` minus the segwit witness discount `stripped − total`
(consensus.h:13-15; subtraction-free form, `total ≤ stripped`). -/
@[rule "SWT-017"]
theorem blockWeight_witness_discount (txs : List Tx) {totalSize : Nat}
    (h : totalSize ≤ strippedSize txs) :
    4 * strippedSize txs = blockWeight txs totalSize
      + (strippedSize txs - totalSize) := by
  rw [blockWeight_row]; omega

/-! ## INV-093: the 4M weight gate -/

/-- **INV-093**: `weightOk` is exactly `3 × stripped + total ≤ 4,000,000`
(validation.cpp ContextualCheckBlock:4187, BIP141). -/
@[rule "INV-093"]
theorem weightOk_iff (txs : List Tx) (totalSize : Nat) :
    weightOk txs totalSize = true ↔
      3 * strippedSize txs + totalSize ≤ 4_000_000 := by
  unfold weightOk blockWeight
  exact decide_eq_true_iff

/-- Reject face: `weightOk = false` iff the budget is exceeded. -/
theorem weightOk_eq_false_iff (txs : List Tx) (totalSize : Nat) :
    weightOk txs totalSize = false ↔
      4_000_000 < 3 * strippedSize txs + totalSize := by
  unfold weightOk blockWeight
  rw [decide_eq_false_iff_not]
  exact Nat.not_le

/-! ## BLK-027: vtx[0] is a coinbase -/

/-- **BLK-027**: on a non-empty tx list, `cbPositionOk` holds iff the head
is a coinbase and no later tx is (validation.cpp:3959-3963). -/
@[rule "BLK-027"]
theorem cbPositionOk_cons_iff (cb : Tx) (rest : List Tx) :
    cbPositionOk (cb :: rest) = true ↔
      cb.isCoinBase = true ∧
        rest.any (fun t => t.isCoinBase) = false := by
  simp [cbPositionOk, Bool.and_eq_true]

/-- Empty block fails the position gate. -/
theorem cbPositionOk_nil : cbPositionOk ([] : List Tx) = false := rfl

/-- Pass ⇒ head is a coinbase (BLK-027 face). -/
theorem cbPositionOk_pass_head {cb : Tx} {rest : List Tx}
    (h : cbPositionOk (cb :: rest) = true) : cb.isCoinBase = true :=
  ((cbPositionOk_cons_iff cb rest).mp h).1

/-- Pass ⇒ no later tx is a coinbase (BLK-028 face). -/
theorem cbPositionOk_pass_tail {cb : Tx} {rest : List Tx}
    (h : cbPositionOk (cb :: rest) = true) :
    rest.any (fun t => t.isCoinBase) = false :=
  ((cbPositionOk_cons_iff cb rest).mp h).2

/-- **BLK-027**: `IsCoinBase` is exactly "one input whose prevout is null"
(`transaction.h:347`: `vin.size() == 1 && vin[0].prevout.IsNull()`). -/
@[rule "BLK-027"]
theorem isCoinBase_row_iff (tx : Tx) :
    tx.isCoinBase = true ↔
      ∃ i : TxIn, tx.vin = [i] ∧ i.prevout.isNull = true := by
  unfold Tx.isCoinBase
  cases tx.vin with
  | nil => simp
  | cons i rest => cases rest <;> simp

/-- **BLK-027**: the coinbase-position gate passing entails the expanded
`IsCoinBase` predicate on `vtx[0]` (single input, null prevout). -/
@[rule "BLK-027"]
theorem cbPositionOk_head_isCoinBase {cb : Tx} {rest : List Tx}
    (h : cbPositionOk (cb :: rest) = true) :
    ∃ i : TxIn, cb.vin = [i] ∧ i.prevout.isNull = true :=
  (isCoinBase_row_iff cb).mp (cbPositionOk_pass_head h)

#print axioms strippedSize_row
#print axioms strippedSizeOk_iff
#print axioms strippedSizeOk_eq_false_iff
#print axioms strippedSize_bad_length_iff
#print axioms blockWeight_row
#print axioms blockWeight_witness_discount
#print axioms weightOk_iff
#print axioms weightOk_eq_false_iff
#print axioms cbPositionOk_cons_iff
#print axioms isCoinBase_row_iff
#print axioms cbPositionOk_head_isCoinBase

end BitcoinProofs.AF.PDW51
