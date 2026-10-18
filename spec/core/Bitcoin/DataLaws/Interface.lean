import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.Crypto.Seam.Interface
import Bitcoin.DataLaws.Laws

/-!
# Bitcoin.DataLaws — FROZEN INTERFACE, bodies filled

## Interface contract (do not edit outside an interface-change PR)

Core counterpart files: src/consensus/validation.h:139-142 (weight),
                        src/primitives/transaction.cpp (ComputeHash:81-84,
                        ComputeWitnessHash:86-93), src/consensus/tx_verify.cpp
                        (IsFinalTx:23-43), src/primitives/transaction.h
                        (nSequence, SEQUENCE_FINAL),
                        src/script/script.h:48 (LOCKTIME_THRESHOLD)
Status: statements frozen 2026-10-16; the four
                        stub bodies and the six frozen theorem proofs were
                        filled (see the type-law notes).
                        The last stub `totalSize` (the witness
                        framing) is now the real
                        extended-serialization size `|serTxWithWitness tx|`
                        (BIP141/BIP144), still consumed opaquely by
                        `txWeight`. The module is sorryAx-free end to end.

## Scope

The weight model (BIP141 3×base+total), txid/wtxid laws, and the
locktime/sequence field laws (finality, BIP113 MTP cutoff, BIP68
sequence numbers) over the frozen types. Exit: T1 lemmas on types,
sorry-free (`totalSize`'s former stub is now filled).
-/

namespace Bitcoin.DataLaws

open Bitcoin.Data Bitcoin.Crypto.Seam

/-! ## Witness framing on the wire (BIP144; Core `SerializeTransaction`) -/

/-- One witness stack on the wire (BIP144): CompactSize item-count, then
each item as CompactSize-length-prefixed bytes. -/
def serWitnessStack (s : List ByteArray) : ByteArray :=
  compactSizeEnc s.length ++
    s.foldl (fun acc item => acc ++ compactSizeEnc item.size ++ item) ByteArray.empty

/-- `CTxWitness` on the wire: one stack per input (an absent/short `Tx.witness`
slot serializes as an empty stack — `getD` default, matching Core's
per-input `scriptWitness` read in `SerializeTransaction`). SWT-067: the
witness side of the weight formula — each input contributes
`CompactSize(count) + Σ (CompactSize(len) + item)` to `totalSize`, which
enters `txWeight = 3·base + total` exactly once (per-input BIP144
framing; the proved composite is `txWeight_formula`, SWT-019). -/
@[rule "SWT-067"]
def serWitness (tx : Tx) : ByteArray :=
  (List.range tx.vin.length).foldl
    (fun acc i => acc ++ serWitnessStack (tx.witness.getD i [])) ByteArray.empty

/-- Extended (with-witness) serialization — Core `SerializeTransaction`
(transaction.cpp), BIP144 framing:
version ‖ 0x00 0x01 ‖ vin ‖ vout ‖ witness ‖ locktime. -/
def serTxWithWitness (tx : Tx) : ByteArray :=
  serU32 tx.version.toUInt32
    ++ (ByteArray.empty.push 0x00).push 0x01
    ++ compactSizeEnc tx.vin.length
    ++ tx.vin.foldl (fun acc i => acc ++ serTxIn i) ByteArray.empty
    ++ compactSizeEnc tx.vout.length
    ++ tx.vout.foldl (fun acc o => acc ++ serTxOut o) ByteArray.empty
    ++ serWitness tx
    ++ serU32 tx.locktime

/-! ## Weight model (BIP141; TXV-019, SWT-017/018) -/

/-- Stripped (base) size in bytes = `|serTx(tx)|`. -/
def baseSize (tx : Tx) : Nat := (serTx tx).size

/-- Total size in bytes = the extended (with-witness) serialization size
`|serTxWithWitness(tx)|`: base serialization + the 0x00/0x01 marker/flag
pair + the per-input BIP144 witness stacks (BIP141 "total size"; Core's
`GetTransactionWeight` uses `::GetSerializeSize(TX_WITH_WITNESS(tx))` for
this term). The witness framing itself is `encodeTx` /
`SerializeTransaction`. Formerly the last `opaque` seam stub
(`SORRY`), now filled with this real body; `txWeight`'s
formula law consumes it by `rfl`. -/
def totalSize (tx : Tx) : Nat := (serTxWithWitness tx).size

/-- `GetTransactionWeight` (consensus/validation.h:139-142):
`weight = base·(WITNESS_SCALE_FACTOR−1) + total`, as `Nat` (Core computes
in `int32_t`; sizes here are far below the overflow bound). -/
def txWeight (tx : Tx) : Nat := 3 * baseSize tx + totalSize tx

/-- TXV-019/SWT-019: the weight formula itself. -/
@[rule "TXV-019", rule "SWT-019"]
theorem txWeight_formula (tx : Tx) : txWeight tx = 3 * baseSize tx + totalSize tx := rfl

/-- Sanity law: weight ≥ base size. -/
theorem weight_ge_base (tx : Tx) : baseSize tx ≤ txWeight tx := by
  unfold txWeight baseSize
  omega

/-- Sanity law: weight ≥ total size. -/
theorem weight_ge_total (tx : Tx) : totalSize tx ≤ txWeight tx := by
  unfold txWeight
  omega

/-- Zero weight ⇔ both serialized forms are empty. -/
theorem weight_eq_zero_iff (tx : Tx) :
    txWeight tx = 0 ↔ baseSize tx = 0 ∧ totalSize tx = 0 := by
  unfold txWeight
  omega

/-! ### Virtual size (BIP141 §Additional definitions, SWT-020)

`GetVirtualTransactionSize` (policy-facing but defined in the BIP141
consensus text): `vsize = ⌈weight / WITNESS_SCALE_FACTOR⌉`, computed as
`(weight + 3) / 4` (Core's `GetVirtualTransactionSize`,
consensus/validation.h; the round-up is `+ scale − 1` before the floor
division). SWT-067's per-input framing feeds `totalSize` via
`serWitness` (one `serWitnessStack` per `vin` slot). -/

/-- Virtual size = ⌈weight / 4⌉, round-up form `(weight + 3) / 4`. -/
def vsize (tx : Tx) : Nat := (txWeight tx + 3) / 4

/-- SWT-020: the vsize formula, definitionally `(weight + scale − 1) / scale`. -/
@[rule "SWT-020"] theorem vsize_formula (tx : Tx) : vsize tx = (txWeight tx + 3) / 4 := rfl

/-- vsize is sandwiched: `weight / 4 ≤ vsize < weight / 4 + 1`, i.e. it is
the ceiling. -/
theorem vsize_ceiling (tx : Tx) :
    txWeight tx / 4 ≤ vsize tx ∧ vsize tx ≤ txWeight tx / 4 + 1 := by
  unfold vsize
  omega

/-- vsize ≥ 1 for any non-empty tx (weight ≥ 1 ⇒ ⌈w/4⌉ ≥ 1). -/
theorem vsize_pos_of_pos (tx : Tx) (h : 0 < txWeight tx) : 0 < vsize tx := by
  unfold vsize
  omega

/-- Scale identity: at `WITNESS_SCALE_FACTOR = 4` one legacy byte contributes
one weight unit and each base byte is counted `3 + 1` times in total. -/
theorem weight_scale_identity (tx : Tx) :
    txWeight tx + baseSize tx = totalSize tx + 4 * baseSize tx := by
  unfold txWeight baseSize
  omega

/-- Sizes of a foldl-concatenation, with the accumulator made explicit:
the result is the accumulator's size plus the sizes of the concatenated
parts (bridge lemma for the size laws below; the `ByteArray.empty`-seeded
instance is what the serializers use). -/
private theorem foldl_concat_size_init {α : Type} (f : α → ByteArray) :
    ∀ (l : List α) (init : ByteArray),
      (l.foldl (fun acc x => acc ++ f x) init).size
        = init.size + (l.foldl (fun acc x => acc ++ f x) ByteArray.empty).size := by
  intro l
  induction l with
  | nil => intro _; rfl
  | cons a l ih =>
      intro init
      simp only [List.foldl_cons]
      rw [ByteArray.empty_append, ih (init ++ f a), ih (f a),
        ByteArray.size_append]
      omega

/-- `serU32` writes exactly 4 bytes. -/
private theorem serU32_size (x : UInt32) : (serU32 x).size = 4 := rfl

/-- The total (with-witness) serialization is never shorter than the base
serialization: BIP144 framing (0x00/0x01 marker + flag pair, then the
per-input witness stacks) only appends bytes around the *identical*
version/`vin`/`vout`/locktime payload — the wire-level counterpart of
`weight_ge_base`'s chain `base ≤ total ≤ weight`. -/
theorem totalSize_ge_base (tx : Tx) : baseSize tx ≤ totalSize tx := by
  unfold totalSize baseSize serTxWithWitness serTx
  simp only [ByteArray.size_append]
  simp only [serU32_size]
  have h2 : ((ByteArray.empty.push 0x00 : ByteArray).push 0x01).size = 2 := rfl
  rw [h2]
  have h0 : ByteArray.empty.size = 0 := rfl
  omega

/-- Size of a `foldl`-concatenation seeded with the empty byte array: the
result is the sum of the per-item sizes (the witness-stack form of the
`foldl_concat_size_init` bridge). -/
private theorem foldl_concat_size_empty {α : Type} (f : α → ByteArray) :
    ∀ (l : List α),
      (l.foldl (fun acc x => acc ++ f x) ByteArray.empty).size
        = (l.map (fun x => (f x).size)).sum := by
  intro l
  induction l with
  | nil => rfl
  | cons a l ih =>
      simp only [List.foldl_cons, List.map_cons, List.sum_cons]
      rw [ByteArray.empty_append, foldl_concat_size_init f l (f a), ih]

/-- **SWT-067** (per-input composition): the witness section of the
extended serialization is exactly the concatenation of the per-input
BIP144 stacks, so its size is the sum of the individual stack sizes. -/
@[rule "SWT-067"]
theorem serWitness_size_eq_sum (tx : Tx) :
    (serWitness tx).size =
      ((List.range tx.vin.length).map
        (fun i => (serWitnessStack (tx.witness.getD i [])).size)).sum := by
  unfold serWitness
  exact foldl_concat_size_empty (fun i => serWitnessStack (tx.witness.getD i []))
    (List.range tx.vin.length)

/-- **SWT-067** (with-witness serialization is the base payload plus the
2-byte marker/flag pair plus the witness stacks): the BIP144 framing adds
exactly those bytes around the *identical* `serTx` payload. -/
@[rule "SWT-067"]
theorem totalSize_eq_base_add_witness (tx : Tx) :
    totalSize tx = baseSize tx + 2 + (serWitness tx).size := by
  unfold totalSize baseSize serTxWithWitness serTx
  simp only [ByteArray.size_append]
  have h2 : ((ByteArray.empty.push 0x00 : ByteArray).push 0x01).size = 2 := rfl
  rw [h2]
  omega

/-- **SWT-067** (transaction weight): `weight = no-witness
serialization × 3 + total (with-witness) serialization`, and the
with-witness serialization decomposes into the base payload, the 2-byte
marker/flag pair and the witness-stack bytes — i.e.
`3·|serTx| + (|serTx| + 2) + |serWitness|`. Note that the last term is
the **stack bytes only**; adding a full with-witness serialization here
would double-count the base payload and the marker/flag. -/
@[rule "SWT-067"]
theorem txWeight_eq_three_base_add_witness (tx : Tx) :
    txWeight tx = 3 * baseSize tx + (baseSize tx + 2) + (serWitness tx).size := by
  rw [txWeight_formula, totalSize_eq_base_add_witness]
  omega

/-- **SWT-067** (no double count): the same weight collected as
`4·stripped + 2-byte marker/flag + witness-stack bytes`. This is the
exact BIP141 `stripped×4 + witness_size` form of the transaction weight
(Core consensus/validation.h:139-142). -/
@[rule "SWT-067"]
theorem txWeight_eq_four_base_add_marker_add_witness (tx : Tx) :
    txWeight tx = 4 * baseSize tx + 2 + (serWitness tx).size := by
  rw [txWeight_formula, totalSize_eq_base_add_witness]
  omega

/-- **SWT-067** (double-count refutation): whenever the witness section
is non-empty, the weight is strictly smaller than
`3·base + total + witness` — i.e. `total` already contains the witness
stacks, so the old "×3 + wit ser + stack ser" reading cannot be right. -/
@[rule "SWT-067"]
theorem txWeight_lt_three_base_add_total_add_witness (tx : Tx)
    (hw : 0 < (serWitness tx).size) :
    txWeight tx < 3 * baseSize tx + totalSize tx + (serWitness tx).size := by
  rw [txWeight_formula]
  omega

/-! ## txid / wtxid (TXV-017/018, BLK-005/006) -/

/-- `txid = dsha256(encodeTxNoWitness tx)` (transaction.cpp:ComputeHash:81-84).
`encodeTxNoWitness` is `Bitcoin.Serialization.encodeTxNoWitness`, whose
live definition is exactly `serTx` (`TX_NO_WITNESS`). -/
@[rule "TXV-017"]
def txid (tx : Tx) : ByteArray := sha256d (serTx tx)

/-- TXV-017 unfold: the txid pipeline in data-layer / serialization-layer seam terms. -/
theorem txid_eq_dsha256_serTx (tx : Tx) : txid tx = sha256d (serTx tx) := rfl

/-- The txid only depends on the base serialization. -/
theorem txid_congr (a b : Tx) (h : serTx a = serTx b) : txid a = txid b := by
  unfold txid
  exact congrArg sha256d h

/-- `CTransaction::HasWitness()` (transaction.h): some input carries a
non-empty witness stack (`CScriptWitness::IsNull` = stack empty). Core
quantifies over `vin`; here over the witness slots — the two coincide on
well-formed domain (`witness.length = vin.length`). -/
def hasWitness (tx : Tx) : Bool :=
  tx.witness.any (fun s => !s.isEmpty)

/-! ## Core-faithful weight (TXV-019 retarget)

`GetTransactionWeight` (consensus/validation.h:139-142) uses
`GetSerializeSize(TX_WITH_WITNESS(tx))` for its total term. Under BIP144
`TX_WITH_WITNESS` is the *extended* serialization only when `HasWitness()`:
a witness-free transaction has no 0x00/0x01 marker/flag pair and no witness
stacks. The original `totalSize` above always emits that framing; the
declarations below provide the Core-faithful parallel model and leave
`totalSize`/`txWeight` and their consumers untouched. -/

/-- Core-faithful `SerializeTransaction`: extended (BIP144) form exactly when
`HasWitness()`, otherwise the base serialization. -/
def serTxWithWitnessCore (tx : Tx) : ByteArray :=
  if hasWitness tx then serTxWithWitness tx else serTx tx

/-- Core-faithful total size = `|TX_WITH_WITNESS(tx)|`. -/
def totalSizeCore (tx : Tx) : Nat := (serTxWithWitnessCore tx).size

/-- Core-faithful transaction weight = `3 * stripped + total`. -/
def txWeightCore (tx : Tx) : Nat := 3 * baseSize tx + totalSizeCore tx

/-- TXV-019: the Core-faithful weight formula. -/
@[rule "TXV-019"]
theorem txWeightCore_formula (tx : Tx) :
    txWeightCore tx = 3 * baseSize tx + totalSizeCore tx := rfl

/-- `HasWitness() = false` is exactly "every serialized witness slot is an
empty stack" (`CScriptWitness::IsNull`). -/
@[rule "TXV-019"]
theorem hasWitness_false_iff_all_empty (tx : Tx) :
    hasWitness tx = false ↔ tx.witness.all (fun s => s.isEmpty) = true := by
  unfold hasWitness
  rw [List.any_eq_false, List.all_eq_true]
  constructor
  · intro h s hs
    have h' := h s hs
    simpa using h'
  · intro h s hs
    have h' := h s hs
    simpa using h'

/-- In-range `getD` lookup returns a member of the list. -/
private theorem getD_mem' {α : Type} (d : α) :
    ∀ (l : List α) (i : Nat), i < l.length → l.getD i d ∈ l := by
  intro l
  induction l with
  | nil => intro i hi; simp at hi
  | cons a l ih =>
    intro i hi
    cases i with
    | zero => simp
    | succ i =>
      simp only [List.getD_cons_succ]
      exact List.mem_cons_of_mem _ (ih i (by simpa using hi))

/-- Out-of-range `getD` lookup returns the default. -/
private theorem getD_default_of_ge' {α : Type} (d : α) :
    ∀ (l : List α) (i : Nat), l.length ≤ i → l.getD i d = d := by
  intro l
  induction l with
  | nil => intro i _; rfl
  | cons a l ih =>
    intro i h
    cases i with
    | zero => simp at h
    | succ j =>
      simp only [List.getD_cons_succ]
      exact ih j (by simpa using h)

/-- With no witness, every in-range witness slot is the empty stack. -/
private theorem getD_empty_of_all_empty {tx : Tx}
    (h : tx.witness.all (fun s : List ByteArray => s.isEmpty) = true)
    (i : Nat) : tx.witness.getD i [] = [] := by
  by_cases hi : i < tx.witness.length
  · have hmem : tx.witness.getD i [] ∈ tx.witness := getD_mem' [] tx.witness i hi
    have hempty : (tx.witness.getD i []).isEmpty = true :=
      List.all_eq_true.mp h _ hmem
    exact List.isEmpty_iff.mp hempty
  · exact getD_default_of_ge' [] tx.witness i (by omega)

/-- A witness-free transaction serializes no witness stacks: each of the
`vin.length` BIP144 stacks is the single-byte empty-stack count. -/
@[rule "TXV-019"]
theorem serWitness_size_eq_vin_of_no_witness (tx : Tx)
    (h : hasWitness tx = false) : (serWitness tx).size = tx.vin.length := by
  have hall : tx.witness.all (fun s : List ByteArray => s.isEmpty) = true :=
    (hasWitness_false_iff_all_empty tx).mp h
  rw [serWitness_size_eq_sum]
  have hmap : (List.range tx.vin.length).map
      (fun i => (serWitnessStack (tx.witness.getD i [])).size)
      = (List.range tx.vin.length).map (fun _ => 1) := by
    apply List.map_congr_left
    intro i _
    rw [getD_empty_of_all_empty hall i]
    rfl
  rw [hmap, List.map_const', List.sum_replicate_nat]
  simp

/-- TXV-019 (no-witness case): `TX_WITH_WITNESS` is exactly the base
serialization — no marker/flag and no witness stacks. -/
@[rule "TXV-019"]
theorem totalSizeCore_eq_base_of_no_witness (tx : Tx)
    (h : hasWitness tx = false) : totalSizeCore tx = baseSize tx := by
  simp [totalSizeCore, serTxWithWitnessCore, baseSize, h]

/-- TXV-019 (witness case): the Core-faithful total is the base payload plus
the 2-byte marker/flag pair plus the BIP144 witness section. -/
@[rule "TXV-019"]
theorem totalSizeCore_eq_base_add_witness_of_hasWitness (tx : Tx)
    (h : hasWitness tx = true) :
    totalSizeCore tx = baseSize tx + 2 + (serWitness tx).size := by
  unfold totalSizeCore serTxWithWitnessCore
  rw [h]
  simpa [totalSize] using totalSize_eq_base_add_witness tx

/-- TXV-019 (Core's exact identity, both branches): with a witness the
weight is `4 * stripped + 2 + witness_bytes`; without one it is exactly
`4 * stripped` (BIP141: `weight = stripped * 4 + witness_size`, and
`witness_size = total - stripped`). -/
@[rule "TXV-019"]
theorem txWeightCore_eq_core_identity (tx : Tx) :
    txWeightCore tx =
      if hasWitness tx then 4 * baseSize tx + 2 + (serWitness tx).size
      else 4 * baseSize tx := by
  unfold txWeightCore
  by_cases h : hasWitness tx = true
  · rw [h, totalSizeCore_eq_base_add_witness_of_hasWitness tx h]
    simp
    omega
  · have hf : hasWitness tx = false := by
      cases hb : hasWitness tx with
      | false => rfl
      | true => exact absurd hb h
    rw [hf, totalSizeCore_eq_base_of_no_witness tx hf]
    simp
    omega

/-- TXV-019 (old-model delta, total size): for a witness-free tx the old
unconditional extended serialization overcounts by exactly `2 + vin.length`
bytes (the marker/flag pair plus one empty-stack count per input). -/
@[rule "TXV-019"]
theorem totalSize_eq_totalSizeCore_add_of_no_witness (tx : Tx)
    (h : hasWitness tx = false) :
    totalSize tx = totalSizeCore tx + 2 + tx.vin.length := by
  rw [totalSizeCore_eq_base_of_no_witness tx h, totalSize_eq_base_add_witness,
    serWitness_size_eq_vin_of_no_witness tx h]

/-- TXV-019 (exact old-model delta, weight form): the old `txWeight`
overcounts a witness-free tx by exactly `2 + vin.length` weight units — the
stripped term is identical and only the total differs. -/
@[rule "TXV-019"]
theorem txWeight_eq_txWeightCore_add_of_no_witness (tx : Tx)
    (h : hasWitness tx = false) :
    txWeight tx = txWeightCore tx + 2 + tx.vin.length := by
  unfold txWeight txWeightCore
  rw [totalSizeCore_eq_base_of_no_witness tx h, totalSize_eq_base_add_witness,
    serWitness_size_eq_vin_of_no_witness tx h]
  omega

/-- TXV-019 (sanity bridge): the Core-faithful weight is never larger than the
old `txWeight` for a witness-free transaction. -/
@[rule "TXV-019"]
theorem txWeightCore_le_txWeight_of_no_witness (tx : Tx)
    (h : hasWitness tx = false) : txWeightCore tx ≤ txWeight tx := by
  have hd := txWeight_eq_txWeightCore_add_of_no_witness tx h
  omega

/-- `wtxid` (transaction.cpp:ComputeWitnessHash:86-93): dsha256 of the
extended serialization — **returns the txid verbatim when `!HasWitness()`**,
which is exactly the branch Core takes. -/
@[rule "TXV-018"]
def wtxid (tx : Tx) : ByteArray :=
  if hasWitness tx then sha256d (serTxWithWitness tx) else txid tx

/-- Witness data never influences the txid. -/
theorem txid_witness_independence (tx : Tx) (w : List WitnessStack) :
    txid { tx with witness := w } = txid tx := by
  simp [txid, serTx]

/-- No witness ⇒ wtxid = txid (BLK-006; ComputeWitnessHash's `!HasWitness()`
branch returns the txid unchanged). -/
theorem wtxid_eq_txid_iff_no_witness (tx : Tx) :
    tx.witness.all (·.isEmpty) → wtxid tx = txid tx := by
  intro h
  have hw : hasWitness tx = false := by
    unfold hasWitness
    cases ha : tx.witness.any (fun s => !s.isEmpty) with
    | false => rfl
    | true =>
        exfalso
        obtain ⟨s, hs, hne⟩ := List.any_eq_true.mp ha
        rw [List.all_eq_true.mp h s hs] at hne
        simp at hne
  simp [wtxid, hw]

/-- The wtxid only depends on the extended serialization and the
has-witness bit. -/
theorem wtxid_congr (a b : Tx) (h : serTxWithWitness a = serTxWithWitness b)
    (hw : hasWitness a = hasWitness b) (ht : serTx a = serTx b) :
    wtxid a = wtxid b := by
  unfold wtxid txid
  rw [hw, h, ht]

/-! ## Locktime / sequence (INV-011..014, TXV-020..) -/

/-- INV-012/013 domain predicate: locktime is in the time domain iff
≥ `LOCKTIME_THRESHOLD` = 500,000,000 (script.h:48). Below the threshold
the comparison is against block height (INV-012), at-or-above against
the BIP113 median-time-past (INV-013). -/
@[rule "TXV-028"]
def locktimeIsTimeDomain (lt : UInt32) : Bool := decide (500000000 ≤ lt)

/-- The threshold reading of the domain predicate. -/
theorem locktimeIsTimeDomain_iff (lt : UInt32) :
    locktimeIsTimeDomain lt = true ↔ 500000000 ≤ lt := by
  simp [locktimeIsTimeDomain]

/-- Height domain is exactly "below the threshold". -/
theorem locktime_height_domain_iff (lt : UInt32) :
    locktimeIsTimeDomain lt = false ↔ lt < 500000000 := by
  simp [locktimeIsTimeDomain, decide_eq_false_iff_not]

/-- **TXV-028**: the cutoff expression used by `IsFinalTx` switches on the
raw `LOCKTIME_THRESHOLD` — the domain predicate is exactly
`500_000_000 ≤ nLockTime`, with no other branch. -/
@[rule "TXV-028"]
theorem locktime_cutoff_threshold (tx : Tx) (height mtp : UInt32) :
    (if locktimeIsTimeDomain tx.locktime then mtp else height)
      = if 500000000 ≤ tx.locktime then mtp else height := by
  unfold locktimeIsTimeDomain
  by_cases h : 500000000 ≤ tx.locktime
  · simp [h]
  · simp [h]

/-- **TXV-028** (below the cutoff): `nLockTime < 500_000_000` compares to
the block height. -/
@[rule "TXV-028"]
theorem locktime_cutoff_height (tx : Tx) (height mtp : UInt32)
    (h : tx.locktime < 500000000) :
    (if locktimeIsTimeDomain tx.locktime then mtp else height) = height := by
  have hlt : ¬ (500000000 ≤ tx.locktime) := by
    intro hle
    have h1 := UInt32.lt_iff_toNat_lt.mp h
    have h2 := UInt32.le_iff_toNat_le.mp hle
    omega
  unfold locktimeIsTimeDomain
  rw [show decide (500000000 ≤ tx.locktime) = false from by
    rw [decide_eq_false_iff_not]; exact hlt]
  rfl

/-- **TXV-028** (at or above the cutoff): `500_000_000 ≤ nLockTime`
compares to the time cutoff (`mtp`). -/
@[rule "TXV-028"]
theorem locktime_cutoff_time (tx : Tx) (height mtp : UInt32)
    (h : 500000000 ≤ tx.locktime) :
    (if locktimeIsTimeDomain tx.locktime then mtp else height) = mtp := by
  unfold locktimeIsTimeDomain
  rw [show decide (500000000 ≤ tx.locktime) = true from by
    rw [decide_eq_true_iff]; exact h]
  rfl

/-- `IsFinalTx` (consensus/tx_verify.cpp:23-43) at block `height` with
(block, BIP113-corrected) median-time-past `mtp`: final iff
`nLockTime = 0`, or `nLockTime` is below the height/time cutoff
(`nLockTime < LOCKTIME_THRESHOLD ? nBlockHeight : nBlockTime`), or every
input's `nSequence` is `SEQUENCE_FINAL`. -/
@[rule "INV-012", rule "INV-013", rule "TXV-029", rule "BLK-066"]
def isFinalTx (tx : Tx) (height : UInt32) (mtp : UInt32) : Bool :=
  tx.locktime == 0
    || tx.locktime < (if locktimeIsTimeDomain tx.locktime then mtp else height)
    || tx.vin.all (fun i => i.sequence == SEQUENCE_FINAL)

/-- **TXV-028**: `IsFinalTx`'s explicit cutoff reads the raw threshold —
below it the comparison target is the block height, at or above it the
(BIP113) median-time-past. -/
@[rule "TXV-028"]
theorem isFinalTx_cutoff_threshold (tx : Tx) (height mtp : UInt32) :
    isFinalTx tx height mtp =
      (tx.locktime == 0
        || tx.locktime < (if 500000000 ≤ tx.locktime then mtp else height)
        || tx.vin.all (fun i => i.sequence == SEQUENCE_FINAL)) := by
  unfold isFinalTx
  rw [locktime_cutoff_threshold tx height mtp]

/-- INV-011/TXV-027: `nLockTime = 0 ⇒ final`. -/
@[rule "INV-011", rule "TXV-027"]
theorem final_locktime_zero (tx : Tx) (height : UInt32) (mtp : UInt32) :
    tx.locktime = 0 → isFinalTx tx height mtp = true := by
  intro h
  unfold isFinalTx
  rw [h]
  rfl

/-- INV-012: below the threshold the cutoff is the block height. -/
theorem final_height_domain (tx : Tx) (height mtp : UInt32)
    (hd : locktimeIsTimeDomain tx.locktime = false) (hlt : tx.locktime < height) :
    isFinalTx tx height mtp = true := by
  unfold isFinalTx
  simp [hd, hlt]

/-- INV-013: at-or-above the threshold the cutoff is the (BIP113-corrected)
median-time-past. -/
theorem final_time_domain (tx : Tx) (height mtp : UInt32)
    (ht : locktimeIsTimeDomain tx.locktime = true) (hlt : tx.locktime < mtp) :
    isFinalTx tx height mtp = true := by
  unfold isFinalTx
  simp [ht, hlt]

/-- INV-014/TXV-030: all-`SEQUENCE_FINAL` inputs ⇒ final regardless of
locktime. -/
@[rule "INV-014", rule "TXV-030"]
theorem final_sequence_final (tx : Tx) (height : UInt32) (mtp : UInt32) :
    tx.vin.all (fun i => i.sequence = 0xFFFFFFFF) → isFinalTx tx height mtp = true := by
  intro h
  unfold isFinalTx
  have hall : tx.vin.all (fun i => i.sequence == SEQUENCE_FINAL) = true := by
    rw [List.all_eq_true]
    intro i hi
    have h1 := List.all_eq_true.mp h i hi
    have h2 : i.sequence = 0xFFFFFFFF := of_decide_eq_true h1
    rw [h2]
    rfl
  rw [hall]
  exact Bool.or_true _

/-- Full spec of `IsFinalTx` (tx_verify.cpp:23-43) as a proposition. -/
theorem isFinalTx_iff (tx : Tx) (height mtp : UInt32) :
    isFinalTx tx height mtp = true ↔
      tx.locktime = 0 ∨
        tx.locktime < (if locktimeIsTimeDomain tx.locktime then mtp else height) ∨
        ∀ i ∈ tx.vin, i.sequence = SEQUENCE_FINAL := by
  unfold isFinalTx
  simp [List.all_eq_true, beq_iff_eq, or_assoc]

/-- Contrapositive: a non-final tx has a nonzero locktime below the cutoff
and some non-`SEQUENCE_FINAL` input. -/
theorem not_final_imp (tx : Tx) (height mtp : UInt32)
    (h : isFinalTx tx height mtp = false) :
    tx.locktime ≠ 0 ∧
      ¬ (tx.locktime < (if locktimeIsTimeDomain tx.locktime then mtp else height)) ∧
      ∃ i ∈ tx.vin, i.sequence ≠ SEQUENCE_FINAL := by
  unfold isFinalTx at h
  simp at h
  refine ⟨h.1.1, fun hlt => ?_, h.2⟩
  have hle := UInt32.le_iff_toNat_le.mp h.1.2
  have hlt' := UInt32.lt_iff_toNat_lt.mp hlt
  omega

/-! ## Concrete sanity instances (kernel-`decide`d at build time) -/

set_option maxRecDepth 100000

/-- Hex test-infra (mirrors `Main.fromHex`; kept private here so the
conformance vectors below are checkable inside the library build). -/
private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

private def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc

/-- A one-in/one-out segwit transaction (version 2, sequence
`0x00400010` = 16 × 512 s time-based relative locktime, witness stack
`[0xab 0xcd]`). Computed independently in Python (see
the type-law notes' Appendix A). -/
def sampleSegwitTx : Tx where
  version := 2
  vin := [{ prevout := ⟨serU32 0x01020304 ++ zeroBytes 28, 1⟩
            scriptSig := Script.empty
            sequence := 0x00400010 }]
  vout := [{ value := 1000, scriptPubKey := scriptOf [0x51] }]
  locktime := 0
  witness := [[(ByteArray.empty.push 0xab).push 0xcd]]

/-- Base serialization vector: 61 bytes (computed independently in Python). -/
def sampleSegwitBaseHex : String :=
  "0200000001040302010000000000000000000000000000000000000000000000000000000001000000001000400001E803000000000000015100000000"

/-- Extended serialization vector: 67 bytes (computed independently in Python). -/
def sampleSegwitFullHex : String :=
  "02000000000101040302010000000000000000000000000000000000000000000000000000000001000000001000400001E80300000000000001510102ABCD00000000"

example : bytesBEq (serTx sampleSegwitTx) (fromHex sampleSegwitBaseHex) = true := by decide
example : bytesBEq (serTxWithWitness sampleSegwitTx) (fromHex sampleSegwitFullHex) = true := by decide
example : baseSize sampleSegwitTx = 61 := by decide
example : totalSize sampleSegwitTx = 67 := by decide
example : hasWitness sampleSegwitTx = true := by decide
example : hasWitness { sampleSegwitTx with witness := [[]] } = false := by decide
example : (serTx { sampleSegwitTx with witness := [[]] }) = serTx sampleSegwitTx := rfl
example : isFinalTx sampleSegwitTx 800000 1600000000 = true := by decide
example : isFinalTx { sampleSegwitTx with locktime := 900000000 } 800000 800000 = false := by
  decide

-- Axiom transcripts of the frozen-interface proofs (the pins double as the
-- in-module half of the axiom-manifest gate). The former `sorryAx` entries
-- were the transitive footprints of `totalSize` and `sha256d`
-- opaque stubs; both seams now carry real bodies and the module is
-- sorryAx-free end to end (`totalSize` filled).
/-- info: 'Bitcoin.DataLaws.txWeight_formula' depends on axioms: [propext] -/
#guard_msgs in #print axioms txWeight_formula
/-- info: 'Bitcoin.DataLaws.totalSize_ge_base' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms totalSize_ge_base
/-- info: 'Bitcoin.DataLaws.txid_witness_independence' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txid_witness_independence
/-- info: 'Bitcoin.DataLaws.wtxid_eq_txid_iff_no_witness' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms wtxid_eq_txid_iff_no_witness
/-- info: 'Bitcoin.DataLaws.final_locktime_zero' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms final_locktime_zero
/-- info: 'Bitcoin.DataLaws.final_sequence_final' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms final_sequence_final

end Bitcoin.DataLaws
