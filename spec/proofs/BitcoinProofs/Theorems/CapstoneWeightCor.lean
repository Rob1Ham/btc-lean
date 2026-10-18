import Bitcoin.Capstone.Block

/-!
# BitcoinProofs.Theorems.CapstoneWeightCor — P12: proved block-weight spec (sorry-free)

Corollaries of the executable capstone weight layer (`Bitcoin.Capstone.Block`,
rules BLK-024/025/026 — validation.cpp `GetBlockWeight`/`DEFAULT_MAX_BLOCK_WEIGHT`,
BIP141 §"Block size/weight"). Everything here is pure `Nat`/`List`/`ByteArray`
arithmetic over the frozen definitions

* `txCountPrefix txs = (encodeCompactSize txs.length).size`
* `strippedSize txs = 80 + txCountPrefix txs + Σ (serTx t).size`   (BLK-024)
* `blockWeight txs totalSize = 3 * strippedSize txs + totalSize`   (BLK-025, BIP141)
* `weightOk txs totalSize = (blockWeight txs totalSize ≤ 4_000_000)` (BLK-026)

turning the runtime booleans the 6-anchor capstone run consumed into proved
statements. No Mathlib needed.

C4 portfolio linkage (with per-theorem axiom footprints):

| C4 ID   | theorem | statement (short) | axioms |
|---------|---------|-------------------|--------|
| (BLK-024 law) | `serU8_size` … `serU64_size` | fixed `serU*` widths 1/2/4/8 bytes | propext |
| (BLK-024 law) | `compactSizeEnc_size_pos` | a CompactSize encoding is never empty (≥ 1 byte) | propext, Quot.sound |
| (BLK-024 law) | `compactSizeEnc_size_mono` | CompactSize encoding length is monotone in the count | propext, Quot.sound |
| (BLK-024 law) | `txCountPrefix_pos` | the tx-count prefix contributes ≥ 1 byte | propext, Quot.sound |
| (BLK-024 law) | `txCountPrefix_sublist` | tx-count prefix is monotone under sublist | propext, Quot.sound |
| (BLK-024 cor) | `strippedSize_geq_header` | `80 ≤ strippedSize txs` (header always counted) | propext, Quot.sound |
| (BLK-024 cor) | `strippedSize_geq_header_count` | `81 ≤ strippedSize txs` (header + nonempty count prefix) | propext, Quot.sound |
| (BLK-024 law) | `foldl_add_eq_sum` | the BLK-024 byte sum is `List.sum` | propext |
| (BLK-024 law) | `sum_map_sublist` | byte sum is monotone under `List.Sublist` | propext, Quot.sound |
| (BLK-024 law) | `sum_map_append` | byte sum is additive over concatenation | propext, Quot.sound |
| (BLK-024 law) | `strippedSize_sublist` | stripped size is monotone under `List.Sublist` | propext, Quot.sound |
| (BLK-024 cor) | `strippedSize_mono_prefix` | a prefix's stripped size ≤ the whole block's | propext, Quot.sound |
| (BLK-024 cor) | `strippedSize_le_of_prefix_append` | `strippedSize txs' ≤ strippedSize (txs' ++ rest)` | propext, Quot.sound |
| (BLK-025 law) | `blockWeight_eq` | `blockWeight = 3 * strippedSize + totalSize` definitionally | propext, Quot.sound |
| (BLK-025 cor) | `blockWeight_pos` | weight > 0 whenever the total size is > 0 | propext, Quot.sound |
| (BLK-025 law) | `weight_formula_algebra` | BIP141 algebra, subtraction-free: `4s = (3s+t) + (s−t)` when `t ≤ s` | propext, Quot.sound |
| (BLK-026 law) | `weightOk_iff` | `weightOk = true ↔ 3s + t ≤ 4_000_000` | propext, Quot.sound |
| (BLK-026 cor) | `weightOk_of_small` | sufficient condition `3s + t ≤ 4_000_000` ⇒ `weightOk = true` | propext, Quot.sound |
| (BLK-026 cor) | `weightOk_of_small_sizes` | numeric corollary: `s ≤ 1_000_000` ∧ `t ≤ 1_000_000` ⇒ `weightOk = true` | propext, Quot.sound |
| (BLK-026 cor) | `weightOk_contra` | `totalSize > 4_000_000` ⇒ `weightOk = false` | propext, Quot.sound |

Honest notes:

* The classic rule of thumb "stripped ≤ 1M and total ≤ 4M ⇒ weight OK" is
  FALSE as stated (3·1M + 4M = 7M > 4M); the sufficient condition is the
  direct one `3 * strippedSize txs + totalSize ≤ 4_000_000`
  (`weightOk_of_small`), of which `weightOk_of_small_sizes` is the largest
  symmetric numeric instance.
* `weight_formula_algebra` is stated subtraction-free as the mission
  requires: `4s = blockWeight + (s − t)` under `t ≤ s`, i.e. the witness
  discount `s − t` is exactly what separates weight from 4×stripped.
-/

namespace BitcoinProofs.Theorems.CapstoneWeight

open Bitcoin.Capstone.Block Bitcoin.Data

/-! ## Serialization helper laws (encodeCompactSize / serU*) -/

/-- `serU8` is exactly one byte. -/
theorem serU8_size (x : UInt8) : (serU8 x).size = 1 := rfl

/-- `serU16` is exactly two bytes. -/
theorem serU16_size (x : UInt16) : (serU16 x).size = 2 := rfl

/-- `serU32` is exactly four bytes. -/
theorem serU32_size (x : UInt32) : (serU32 x).size = 4 := rfl

/-- `serU64` is exactly eight bytes. -/
theorem serU64_size (x : UInt64) : (serU64 x).size = 8 := rfl

/-- A CompactSize encoding is never empty: every branch emits at least the
one-byte marker/payload (`serialize.h WriteCompactSize` — 1, 3, 5 or 9
bytes for the four ranges). -/
theorem compactSizeEnc_size_pos (n : Nat) : 1 ≤ (compactSizeEnc n).size := by
  unfold compactSizeEnc
  split
  · rw [serU8_size]; omega
  · split
    · rw [ByteArray.size_append, serU8_size, serU16_size]; omega
    · split
      · rw [ByteArray.size_append, serU8_size, serU32_size]; omega
      · rw [ByteArray.size_append, serU8_size, serU64_size]; omega

/-- The CompactSize encoding length is monotone: a larger count never
serializes shorter (1, 3, 5, 9 bytes over the four ascending ranges). -/
theorem compactSizeEnc_size_mono {n m : Nat} (h : n ≤ m) :
    (compactSizeEnc n).size ≤ (compactSizeEnc m).size := by
  unfold compactSizeEnc
  repeat' split
  all_goals
    simp only [ByteArray.size_append, serU8_size, serU16_size, serU32_size,
      serU64_size]
  all_goals omega

/-- The tx-count prefix of ANY block contributes at least one byte (even
the empty block's count `0` encodes as `[0x00]`). -/
theorem txCountPrefix_pos (txs : List Tx) : 1 ≤ txCountPrefix txs :=
  compactSizeEnc_size_pos txs.length

/-- The tx-count prefix is monotone under sublists (fewer txs ⇒ shorter
count encoding). -/
theorem txCountPrefix_sublist {txs' txs : List Tx} (h : List.Sublist txs' txs) :
    txCountPrefix txs' ≤ txCountPrefix txs := by
  have hlen : txs'.length ≤ txs.length := h.length_le
  exact compactSizeEnc_size_mono hlen

/-! ## BLK-024: stripped-size lower bounds and monotonicity -/

/-- The 80-byte header is always part of the stripped size. -/
theorem strippedSize_geq_header (txs : List Tx) : 80 ≤ strippedSize txs := by
  simp only [strippedSize]
  omega

/-- Header + count prefix: `81 ≤ strippedSize`, unconditionally, because a
CompactSize encoding is never empty (`compactSizeEnc_size_pos`). -/
theorem strippedSize_geq_header_count (txs : List Tx) : 81 ≤ strippedSize txs := by
  have h := txCountPrefix_pos txs
  simp only [strippedSize]
  omega

/-- The BLK-024 byte sum `l.foldl Nat.add 0` is exactly `List.sum` (whose
core lemmas are stated in `+` form). -/
theorem foldl_add_eq_sum (l : List Nat) : l.foldl Nat.add 0 = l.sum := by
  rw [List.sum_eq_foldl]
  rfl

/-- The byte sum is additive over concatenation. -/
theorem sum_map_append {α : Type} (f : α → Nat) (l₁ l₂ : List α) :
    ((l₁ ++ l₂).map f).foldl Nat.add 0
      = (l₁.map f).foldl Nat.add 0 + (l₂.map f).foldl Nat.add 0 := by
  simp only [foldl_add_eq_sum]
  rw [List.map_append, List.sum_append]

/-- The byte sum, in `List.sum` form, is monotone under sublists (dropping
or keeping elements can only decrease a sum of `Nat`). -/
theorem sum_map_sublist_sum {α : Type} (f : α → Nat) {l₁ l₂ : List α}
    (h : List.Sublist l₁ l₂) : (l₁.map f).sum ≤ (l₂.map f).sum := by
  induction h with
  | slnil => exact Nat.le_refl _
  | cons a _ ih =>
      rw [List.map_cons, List.sum_cons]
      omega
  | cons_cons a _ ih =>
      rw [List.map_cons, List.sum_cons, List.map_cons, List.sum_cons]
      omega

/-- The byte sum is monotone under sublists (dropping or keeping elements
can only decrease a sum of `Nat`). -/
theorem sum_map_sublist {α : Type} (f : α → Nat) {l₁ l₂ : List α}
    (h : List.Sublist l₁ l₂) :
    (l₁.map f).foldl Nat.add 0 ≤ (l₂.map f).foldl Nat.add 0 := by
  simp only [foldl_add_eq_sum]
  exact sum_map_sublist_sum f h

/-- **BLK-024 monotonicity**: stripped size is monotone under `List.Sublist`
(a block cannot get cheaper by losing txs). -/
theorem strippedSize_sublist {txs' txs : List Tx} (h : List.Sublist txs' txs) :
    strippedSize txs' ≤ strippedSize txs := by
  have hs := sum_map_sublist (fun t => (serTx t).size) h
  have hcp := txCountPrefix_sublist h
  simp only [strippedSize]
  omega

/-- **BLK-024 monotonicity, prefix form**: a prefix of the tx list has
stripped size ≤ that of the whole list. -/
theorem strippedSize_mono_prefix {txs' txs : List Tx} (h : List.IsPrefix txs' txs) :
    strippedSize txs' ≤ strippedSize txs :=
  strippedSize_sublist h.sublist

/-- **BLK-024 monotonicity, append form**: `strippedSize txs' ≤ strippedSize
(txs' ++ rest)` — the count prefix and the appended txs only add bytes. -/
theorem strippedSize_le_of_prefix_append (txs' rest : List Tx) :
    strippedSize txs' ≤ strippedSize (txs' ++ rest) := by
  have hsum := sum_map_append (fun t => (serTx t).size) txs' rest
  have hlen : txs'.length ≤ (txs' ++ rest).length := by
    rw [List.length_append]; omega
  have hcp : txCountPrefix txs' ≤ txCountPrefix (txs' ++ rest) :=
    compactSizeEnc_size_mono hlen
  simp only [strippedSize]
  omega

/-! ## BLK-025: block weight -/

/-- **BLK-025** unfolding: weight = 3 × stripped + total (definitional). -/
theorem blockWeight_eq (txs : List Tx) (totalSize : Nat) :
    blockWeight txs totalSize = 3 * strippedSize txs + totalSize := rfl

/-- Weight is positive whenever the total (serialized) size is positive —
in particular for any real block (`raw.size > 0`). -/
theorem blockWeight_pos (txs : List Tx) {totalSize : Nat} (ht : 0 < totalSize) :
    0 < blockWeight txs totalSize := by
  have h80 := strippedSize_geq_header txs
  rw [blockWeight_eq]
  omega

/-- **BIP141 algebra, subtraction-free**: when the total size does not
exceed the stripped size, `4 × stripped = blockWeight + (stripped − total)`:
weight is 4×stripped minus the witness discount `stripped − total` that
segwit txs enjoy. -/
theorem weight_formula_algebra (txs : List Tx) {totalSize : Nat}
    (ht : totalSize ≤ strippedSize txs) :
    4 * strippedSize txs = blockWeight txs totalSize + (strippedSize txs - totalSize) := by
  rw [blockWeight_eq]
  omega

/-! ## BLK-026: the weight budget -/

/-- **BLK-026** characterization: `weightOk` is exactly the arithmetic
budget `3 × strippedSize + totalSize ≤ 4_000_000` (BIP141
`DEFAULT_MAX_BLOCK_WEIGHT`). -/
@[rule "BLK-026"]
theorem weightOk_iff (txs : List Tx) (totalSize : Nat) :
    weightOk txs totalSize = true ↔ 3 * strippedSize txs + totalSize ≤ 4_000_000 := by
  unfold weightOk blockWeight
  exact decide_eq_true_iff

/-- **BLK-026 sufficient condition**: `3 * strippedSize txs + totalSize ≤
4_000_000` implies the executable gate accepts (`weightOk = true`). -/
theorem weightOk_of_small (txs : List Tx) {totalSize : Nat}
    (h : 3 * strippedSize txs + totalSize ≤ 4_000_000) :
    weightOk txs totalSize = true :=
  (weightOk_iff txs totalSize).mpr h

/-- **BLK-026 numeric corollary**: the largest symmetric sufficient
condition — stripped ≤ 1,000,000 and total ≤ 1,000,000 force the weight
budget (3·1M + 1M = 4M exactly). -/
theorem weightOk_of_small_sizes (txs : List Tx) {totalSize : Nat}
    (h₁ : strippedSize txs ≤ 1_000_000) (h₂ : totalSize ≤ 1_000_000) :
    weightOk txs totalSize = true :=
  weightOk_of_small txs (by have := strippedSize_geq_header txs; omega)

/-- **BLK-026 contrapositive**: any block whose total serialized size alone
exceeds 4,000,000 bytes is rejected by the executable gate
(`weightOk = false`). -/
theorem weightOk_contra (txs : List Tx) {totalSize : Nat}
    (h : 4_000_000 < totalSize) :
    weightOk txs totalSize = false := by
  unfold weightOk blockWeight
  exact decide_eq_false_iff_not.mpr (by omega)

end BitcoinProofs.Theorems.CapstoneWeight
