import Bitcoin.Serialization.Interface
import Bitcoin.DataLaws.Interface

/-!
# BitcoinProofs.Theorems.Layout.WitnessLayout — witness framing layout (Review-6, contributor S03)

Per-input witness stack serialization layout theorems (BIP144, Core
`SerializeTransaction` @ `cce32b168`), covering:

* **varint item-count**: every per-input stack record opens with the
  CompactSize item count (`DataLaws.serWitnessStack` / `Serialization.encStackL`);
* **per-item varint-length prefixes**: each stack item is
  `CompactSize(item.size) ++ item` (decode side: `decStackL` consumes exactly
  that for a one-item stack);
* **marker/flag position rules**: in the extended serialization the SegWit
  bytes `0x00 0x01` sit immediately after the 4-byte version and before the
  vin count (`serTxWithWitness_layout`); the base (`TX_NO_WITNESS`) encoding
  has no such bytes (`serTx_layout`); decode side: a vin-count byte `0x00`
  reinterprets the next byte as the flag — flag `0x00` is Core's short
  empty-vin record (`decTxCore_flag0_shortRecord`), flag `0x01` with no
  witness stacks at all is the superfluous-witness error
  (`decTxCore_superfluous_zeroVin`);
* **superfluous-witness-record exactness (TXV-015/SWT-039)**: the wire
  witness section of an all-empty-witness tx is exactly one `0x00` count byte
  per input (`encStacksL_all_empty`), and an empty stack record is exactly
  `[0x00]` (`encStackL_empty_iff`);
* **wtxid ≠ txid iff witness nonempty**: for a tx with ≥ 1 input the two
  hash preimages (`serTxWithWitness` vs `serTx`) differ in wire length
  (`serTxWithWitness_ne_serTx`); the hash-level biconditional holds
  conditional on dsha256 injectivity, pinned as an explicit hypothesis
  (`wtxid_eq_txid_iff_of_inj`) rather than assumed globally.

All theorems are sorry-free; axiom footprints audited in `scratch/S03/`.
-/

namespace BitcoinProofs.Theorems.Layout

open Bitcoin.Data Bitcoin.Serialization

/-! ## bL-images of the foldl-built ByteArray concatenations -/

private theorem bL_serWitnessStack_foldl :
    ∀ (s : List ByteArray) (acc : ByteArray),
      bL (s.foldl (fun a item => a ++ compactSizeEnc item.size ++ item) acc)
        = bL acc ++ s.flatMap (fun item => bL (compactSizeEnc item.size ++ item)) := by
  intro s
  induction s with
  | nil => intro acc; simp
  | cons x xs ih =>
      intro acc
      simp only [List.foldl_cons]
      rw [ih]
      simp [bL_append]

private theorem bL_serWitness_foldl (tx : Tx) :
    ∀ (acc : ByteArray),
      bL ((List.range tx.vin.length).foldl
            (fun a i => a ++ Bitcoin.DataLaws.serWitnessStack (tx.witness.getD i [])) acc)
        = bL acc ++ (List.range tx.vin.length).flatMap
            (fun i => bL (Bitcoin.DataLaws.serWitnessStack (tx.witness.getD i []))) := by
  intro acc
  revert acc
  induction (List.range tx.vin.length) with
  | nil => intro acc; simp
  | cons y ys ih =>
      intro acc
      simp only [List.foldl_cons]
      rw [ih]
      simp [bL_append]

private theorem bL_foldl_serTxIn (l : List TxIn) (acc : ByteArray) :
    bL (l.foldl (fun a i => a ++ serTxIn i) acc)
      = bL acc ++ l.flatMap (fun i => bL (serTxIn i)) :=
  bL_foldl_append serTxIn l acc

private theorem bL_foldl_serTxOut (l : List TxOut) (acc : ByteArray) :
    bL (l.foldl (fun a o => a ++ serTxOut o) acc)
      = bL acc ++ l.flatMap (fun o => bL (serTxOut o)) :=
  bL_foldl_append serTxOut l acc

/-! ## Cross-model agreement: ByteArray vs byte-list witness encoders -/

/-- **L1 (varint item-count + per-item prefix agreement).** The ByteArray
stack encoder `serWitnessStack` and the list-layer `encStackL` produce the
same bytes: CompactSize item count, then each item as
`CompactSize(item.size) ++ item`. -/
theorem serWitnessStack_bL (s : List ByteArray) :
    bL (Bitcoin.DataLaws.serWitnessStack s) = encStackL s := by
  unfold Bitcoin.DataLaws.serWitnessStack encStackL
  rw [bL_append, bL_compactSizeEnc, bL_serWitnessStack_foldl, bL_empty]
  simp only [bL_append, bL_compactSizeEnc, List.nil_append]

/-- **L2 (per-input layout agreement).** `serWitness` walks the per-`vin`
slots exactly as `encStacksL`: the stack of input `i` is `tx.witness[i]`
(`getD`-default empty). -/
theorem serWitness_bL (tx : Tx) :
    bL (Bitcoin.DataLaws.serWitness tx) = encStacksL tx := by
  unfold Bitcoin.DataLaws.serWitness encStacksL
  rw [bL_serWitness_foldl, bL_empty, List.nil_append]
  simp only [serWitnessStack_bL]

/-- **L3 (extended layout).** Byte layout of the extended (BIP144)
serialization: version ‖ `0x00 0x01` ‖ vin-count ‖ vins ‖ vout-count ‖
vouts ‖ witness section ‖ locktime — the marker/flag bytes are exactly the
two bytes after the 4-byte version, before the vin varint. -/
theorem serTxWithWitness_layout (tx : Tx) :
    bL (Bitcoin.DataLaws.serTxWithWitness tx)
      = encU32L tx.version.toUInt32
          ++ 0x00 :: 0x01 :: encCSL tx.vin.length
          ++ tx.vin.flatMap (fun i => bL (serTxIn i))
          ++ encCSL tx.vout.length
          ++ tx.vout.flatMap (fun o => bL (serTxOut o))
          ++ encStacksL tx
          ++ encU32L tx.locktime := by
  unfold Bitcoin.DataLaws.serTxWithWitness Bitcoin.DataLaws.serWitness
  simp only [bL_serU32, bL_append, bL_push, bL_empty, bL_compactSizeEnc,
    bL_foldl_serTxIn, bL_foldl_serTxOut, bL_serWitness_foldl, List.singleton_append,
    List.cons_append, List.nil_append, List.append_assoc, serWitnessStack_bL, encStacksL]

/-- **L4 (base layout, marker/flag absent).** The base (`TX_NO_WITNESS`)
encoding — the txid preimage — carries no marker/flag bytes and no witness
section: version ‖ vin-count ‖ vins ‖ vout-count ‖ vouts ‖ locktime. -/
theorem serTx_layout (tx : Tx) :
    bL (serTx tx)
      = encU32L tx.version.toUInt32
          ++ encCSL tx.vin.length
          ++ tx.vin.flatMap (fun i => bL (serTxIn i))
          ++ encCSL tx.vout.length
          ++ tx.vout.flatMap (fun o => bL (serTxOut o))
          ++ encU32L tx.locktime := by
  unfold serTx
  simp only [bL_serU32, bL_append, bL_compactSizeEnc, bL_foldl_serTxIn,
    bL_foldl_serTxOut, bL_empty, List.nil_append, List.append_assoc]

/-! ## hasWitness coherence across the two models -/

/-- **L5 (model coherence).** On the one-slot-per-input domain
(`witness.length = vin.length`) the serialization-layer `hasWitness`
(indexed over `range vin.length`) and the DataLaws-layer `hasWitness`
(`List.any` over the slots) coincide. -/
theorem hasWitness_agree (tx : Tx) (hwlen : tx.witness.length = tx.vin.length) :
    Bitcoin.Serialization.hasWitness tx = Bitcoin.DataLaws.hasWitness tx := by
  have hmap : (List.range tx.vin.length).map (fun i => tx.witness.getD i [])
      = tx.witness := by
    rw [← hwlen]
    exact list_eq_map_getD [] tx.witness
  have h2 : tx.witness.any (fun s : List ByteArray => !s.isEmpty)
      = ((List.range tx.vin.length).map (fun i => tx.witness.getD i [])).any
          (fun s : List ByteArray => !s.isEmpty) := by
    rw [hmap]
  unfold Bitcoin.Serialization.hasWitness Bitcoin.DataLaws.hasWitness
  rw [h2, List.any_map]
  rfl

/-! ## Superfluous-witness-record exactness (TXV-015 / SWT-039) -/

/-- A CompactSize encoding is never empty (it has at least one byte). -/
theorem encCSL_ne_nil (n : Nat) : encCSL n ≠ [] := by
  unfold encCSL
  split
  · simp
  · split
    · simp
    · split
      · simp
      · simp

/-- **L6 (empty-stack record exactness).** The wire record of an empty
witness stack is exactly the single `0x00` count byte — and nothing else
encodes to it. -/
theorem encStackL_empty_iff (s : List ByteArray) :
    encStackL s = [0x00] ↔ s = [] := by
  constructor
  · intro h
    cases s with
    | nil => rfl
    | cons x xs =>
        exfalso
        unfold encStackL at h
        have h1 := congrArg List.length h
        simp only [List.length_append, List.length_cons, List.length_nil] at h1
        have hA : 0 < (encCSL (xs.length + 1)).length := by
          cases hc : encCSL (xs.length + 1) with
          | nil => exact absurd hc (encCSL_ne_nil _)
          | cons a as => simp
        have hB : ((x :: xs).flatMap (fun item : ByteArray =>
            encCSL item.size ++ bL item)).length = 0 := by omega
        rw [List.flatMap_cons] at hB
        simp only [List.length_append] at hB
        have hnil : 0 < (encCSL x.size).length := by
          cases hc : encCSL x.size with
          | nil => exact absurd hc (encCSL_ne_nil _)
          | cons a as => simp
        omega
  · intro h
    subst h
    rfl

/-- **L7 (per-input accounting).** Each stack record occupies at least one
wire byte (its varint count), so the witness section of a tx with `n` inputs
is at least `n` bytes. -/
theorem encStacksL_length_ge (tx : Tx) :
    tx.vin.length ≤ (encStacksL tx).length := by
  have hgen : ∀ (l : List Nat) (f : Nat → Bytes), (∀ i, 1 ≤ (f i).length) →
      l.length ≤ (l.flatMap f).length := by
    intro l
    induction l with
    | nil => intro _ _; simp
    | cons a l ih =>
        intro f hf
        simp only [List.flatMap_cons, List.length_append, List.length_cons]
        have h1 := hf a
        have h2 := ih f (fun i => hf i)
        omega
  have h1 : ∀ i : Nat, 1 ≤ (encStackL (tx.witness.getD i [])).length := by
    intro i
    unfold encStackL
    cases hc : encCSL (tx.witness.getD i []).length with
    | nil => exact absurd hc (encCSL_ne_nil _)
    | cons a as => simp only [List.length_cons, List.length_append]; omega
  have hmain := hgen (List.range tx.vin.length)
    (fun i => encStackL (tx.witness.getD i [])) h1
  rwa [List.length_range] at hmain

private theorem flatMap_range_const (f : Nat → Bytes) :
    ∀ (n : Nat), (∀ i, i < n → f i = [0x00]) →
      (List.range n).flatMap f = List.replicate n (0x00 : UInt8) := by
  intro n
  induction n with
  | zero => intro _; rfl
  | succ k ih =>
      intro h
      rw [List.range_succ, List.flatMap_append, ih (fun i hi => h i (by omega))]
      rw [List.replicate_succ']
      have e2 : ([k] : List Nat).flatMap f = f k := by simp
      rw [e2, h k (by omega)]

/-- **L8 (superfluous record, encode side).** If every in-range witness slot
is empty, the wire witness section is *exactly* one `0x00` byte per input —
the canonical superfluous-witness record that TXV-015 bans under a set flag. -/
theorem encStacksL_all_empty (tx : Tx)
    (h : ∀ i, i < tx.vin.length → tx.witness.getD i [] = ([] : List ByteArray)) :
    encStacksL tx = List.replicate tx.vin.length 0x00 := by
  unfold encStacksL
  exact flatMap_range_const (fun i => encStackL (tx.witness.getD i [])) tx.vin.length
    (fun i hi => by rw [h i hi]; rfl)

/-! ## Marker/flag position rules on the decode side (TXV-013) -/

/-- **L9 (flag-0 short record).** Wire bytes `version ‖ 0x00 0x00 ‖ locktime`:
the vin-count position holds the SegWit marker `0x00`, and a zero flag byte
selects Core's short record — vin stays empty, no vout and no witness is
read (`UnserializeTransaction`'s `flags == 0` branch). -/
theorem decTxCore_flag0_shortRecord (v lt : UInt32) (rest : Bytes) :
    decTxCore (encU32L v ++ (0x00 : UInt8) :: (0x00 : UInt8) :: (encU32L lt ++ rest))
      = .ok (⟨UInt32.toInt32 v, [], [], lt, []⟩, rest) := by
  unfold decTxCore
  rw [decU32L_encU32L]
  simp only [bindE_ok]
  rw [decCS_zero]
  simp only [bindE_ok]
  rw [if_pos True.intro]
  rw [decU8L_cons]
  simp only [bindE_ok]
  rw [if_pos True.intro]
  rw [decU32L_encU32L]
  simp only [bindE_ok]

/-- **L10 (superfluous record, decode side).** Wire bytes
`version ‖ 0x00 0x01 ‖ 0x00 ‖ 0x00 ‖ locktime` (flag set, zero inputs, zero
witness stacks) are rejected with exactly `superfluousWitness` — the
all-empty-witness record under a set flag is never accepted. -/
theorem decTxCore_superfluous_zeroVin (v lt : UInt32) (rest : Bytes) :
    decTxCore (encU32L v ++ (0x00 : UInt8) :: (0x01 : UInt8)
        :: ((0x00 : UInt8) :: (0x00 : UInt8) :: (encU32L lt ++ rest)))
      = .error SerError.superfluousWitness := by
  unfold decTxCore
  rw [decU32L_encU32L]
  simp only [bindE_ok]
  rw [decCS_zero]
  simp only [bindE_ok]
  rw [if_pos True.intro]
  rw [decU8L_cons]
  simp only [bindE_ok]
  rw [if_neg (by decide : ¬ ((0x01 : UInt8) = 0))]
  have hvin : decVinL ((0x00 : UInt8) :: (0x00 : UInt8) :: (encU32L lt ++ rest))
      = .ok ([], (0x00 : UInt8) :: (encU32L lt ++ rest)) := by
    simp only [decVinL, decCS_zero, bindE_ok, decN]
  rw [hvin]
  simp only [bindE_ok]
  rw [decCS_zero]
  simp only [bindE_ok]
  have hout : decN decTxOutL 0 (encU32L lt ++ rest) = .ok ([], encU32L lt ++ rest) := rfl
  rw [hout]
  simp only [bindE_ok]
  first
  | rw [if_pos True.intro]
  | rw [if_pos (by decide : ((0x01 : UInt8).toNat % 2 = 1))]
  have hstk : decN decStackL ([] : List TxIn).length (encU32L lt ++ rest)
      = .ok ([], encU32L lt ++ rest) := rfl
  rw [hstk]
  simp only [bindE_ok]
  first
  | rw [if_pos True.intro]
  | rw [if_pos (by rfl : ([] : List ByteArray).all (fun s : List ByteArray => s.isEmpty) = true)]
  | rfl

/-- **L11 (per-item prefix, decode side).** A one-item stack decodes from
exactly `CompactSize(1) ‖ CompactSize(item.size) ‖ item`: the per-item
varint-length prefix is consumed exactly. -/
theorem decStackL_single_item (item : ByteArray) (rest : Bytes)
    (h : item.size ≤ Bitcoin.Serialization.MAX_SIZE) :
    decStackL (encCSL 1 ++ (encCSL item.size ++ bL item) ++ rest)
      = .ok ([item], rest) := by
  have h1 : ([item] : List ByteArray).length = 1 := rfl
  have hc : [item].length ≤ Bitcoin.Serialization.MAX_SIZE := by
    have h2 : Bitcoin.Serialization.MAX_SIZE = 33554432 := rfl
    omega
  have hi : ∀ x ∈ [item], x.size ≤ Bitcoin.Serialization.MAX_SIZE := by
    intro x hx
    have hx' : x = item := List.mem_singleton.mp hx
    rw [hx']
    exact h
  have hrt := decStackL_enc [item] rest hc hi
  have henc : encStackL [item]
      = encCSL 1 ++ (encCSL item.size ++ bL item) := by
    simp only [encStackL, List.flatMap_cons, List.flatMap_nil, List.append_nil]
    rw [h1]
  rw [henc] at hrt
  exact hrt

/-! ## wtxid vs txid (BLK-005/006, TXV-017/018) -/

/-- **L12 (preimage separation).** For a tx with at least one input, the
wtxid preimage (extended serialization) is never the txid preimage (base
serialization): the extended form carries the two marker/flag bytes plus a
nonempty witness section, so the two wire images differ in length. -/
theorem serTxWithWitness_ne_serTx (tx : Tx) (hvin : 0 < tx.vin.length) :
    Bitcoin.DataLaws.serTxWithWitness tx ≠ serTx tx := by
  intro h
  have hb : bL (Bitcoin.DataLaws.serTxWithWitness tx) = bL (serTx tx) := by rw [h]
  rw [serTxWithWitness_layout, serTx_layout] at hb
  have h4 : (encU32L tx.version.toUInt32).length = 4 := rfl
  have h6 := congrArg List.length hb
  simp only [List.length_append, List.length_cons] at h6
  have hS : 1 ≤ (encStacksL tx).length := by
    have h7 := encStacksL_length_ge tx
    omega
  omega

/-- **L13 (wtxid differs when witness nonempty, hash level).** Under dsha256
injectivity (pinned as an explicit hypothesis — hash injectivity is not
provable), a tx with one witness slot per input and some nonempty stack has
`wtxid ≠ txid`. -/
theorem wtxid_ne_txid_of_hasWitness (tx : Tx)
    (hwlen : tx.witness.length = tx.vin.length)
    (hw : Bitcoin.DataLaws.hasWitness tx = true)
    (hinj : ∀ a b : ByteArray, Bitcoin.Crypto.Seam.sha256d a
      = Bitcoin.Crypto.Seam.sha256d b → a = b) :
    Bitcoin.DataLaws.wtxid tx ≠ Bitcoin.DataLaws.txid tx := by
  have hwT := hw
  unfold Bitcoin.DataLaws.hasWitness at hw
  rw [List.any_eq_true] at hw
  obtain ⟨s, hs, -⟩ := hw
  have hpos : 0 < tx.witness.length := by
    cases hl : tx.witness with
    | nil => rw [hl] at hs; simp at hs
    | cons b bs => simp
  have hvin : 0 < tx.vin.length := by omega
  intro heq
  simp only [Bitcoin.DataLaws.wtxid, hwT, Bitcoin.DataLaws.txid, ite_true] at heq
  exact serTxWithWitness_ne_serTx tx hvin (hinj _ _ heq)

/-- **L14 (the biconditional).** `wtxid tx = txid tx ↔ no input carries a
nonempty witness stack` — on the one-slot-per-input domain, conditional only
on dsha256 injectivity (see `wtxid_ne_txid_of_hasWitness`). The ← direction
is BLK-006's `!HasWitness()` branch; the → direction is the
injectivity-pinned preimage separation. -/
theorem wtxid_eq_txid_iff_of_inj (tx : Tx)
    (hwlen : tx.witness.length = tx.vin.length)
    (hinj : ∀ a b : ByteArray, Bitcoin.Crypto.Seam.sha256d a
      = Bitcoin.Crypto.Seam.sha256d b → a = b) :
    Bitcoin.DataLaws.wtxid tx = Bitcoin.DataLaws.txid tx
      ↔ Bitcoin.DataLaws.hasWitness tx = false := by
  constructor
  · intro heq
    cases hb : Bitcoin.DataLaws.hasWitness tx with
    | false =>
        simp only [Bitcoin.DataLaws.wtxid, hb, Bitcoin.DataLaws.txid, ite_true]
    | true => exact absurd heq (wtxid_ne_txid_of_hasWitness tx hwlen hb hinj)
  · intro hw
    unfold Bitcoin.DataLaws.hasWitness at hw
    have hall : tx.witness.all (fun s : List ByteArray => s.isEmpty) = true := by
      apply List.all_eq_true.mpr
      intro s hs
      cases hc : s.isEmpty with
      | true => rfl
      | false =>
          exfalso
          have h1 : tx.witness.any (fun s : List ByteArray => !s.isEmpty) = true :=
            List.any_eq_true.mpr ⟨s, hs, by rw [hc]; rfl⟩
          rw [h1] at hw
          simp at hw
    exact Bitcoin.DataLaws.wtxid_eq_txid_iff_no_witness tx hall

end BitcoinProofs.Theorems.Layout
