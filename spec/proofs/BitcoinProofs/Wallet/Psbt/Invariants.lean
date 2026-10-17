import BitcoinProofs.Wallet.Psbt.Canonical

/-!
# PSBT v0 — decoder invariants

This module collects the structural invariants that the committed PSBT v0
decoder (`Bitcoin.Wallet.Psbt.Decode`) relies on but that are stated only in
prose in `Bitcoin.Wallet.Psbt.Laws` / `Encode`:

* **Unique keys.**  A map accepted by `decMapChecked` has no duplicate raw
  key.  The duplicate test `findDuplicate` is a total, computable function,
  so rejection is decided rather than accidental: if `decMapL` and
  `checkKeyEncoding` succeed, then `decMapChecked` succeeds exactly when
  `findDuplicate kvs = none`.
* **Sorted encoding.**  The canonical encoder (`encode`) sorts every map by
  raw key.  We prove that `sortKVs` is a correct insertion sort: on a list
  with pairwise distinct keys its result is strictly ascending, so the
  encoder really does emit BIP 174 canonical key order.
* **Unknown pairs.**  Every raw key-value pair present in the encoder's map
  is present, with the same `encKVL` bytes, in the map that the decoder
  returns.  Consequently an unknown pair is preserved byte-for-byte through
  `decode`/`encode` on the map layer; the typed `parseInput` /
  `parseOutput` / `parseGlobal` functions copy the filtered raw list into
  their `unknown` field unchanged (see `inputKVs`/`outputKVs`/`globalKVs`
  and the matching `.unknown` projections in `Decode.lean`).
* **Index bounds.**  A successful `decode` produces exactly
  `unsignedTx.vin.length` input maps and `unsignedTx.vout.length` output
  maps, so every input/output index used by `spentOutput`,
  `inputViolations`, `fillTx`, and the UTXO checks is in range.

## Core anchors (pinned commit `cce32b168`)

* duplicate raw key rejection: `src/psbt.h:581-584`, and the same in the
  input/output map readers (`src/psbt.h:914-923`, `1066-1235`);
* canonical/ascending key order: BIP 174's map rule, implemented by Core's
  `std::map<std::vector<unsigned char>, ...>` iteration
  (`src/psbt.h:1327-1331,548-552,1056-1060`);
* unknown-pair retention: `src/psbt.h:321,953,1250` and the unknown-map
  emitters at `src/psbt.h:1327-1331,548-552,1056-1060`;
* map counts: `src/psbt.h:1561-1611`; trailing-byte rejection:
  `src/psbt.cpp:876-878`.

## What is NOT modeled or claimed

Nothing here asserts signature validity, key-on-curve validity, sighash
acceptability, script/UTXO consistency beyond the structural checks of
`WellFormed`, fee policy, PSBT v2, or consensus validity.  In particular,
the decoder is *not* claimed to accept only sorted maps: it accepts maps in
any wire order and the encoder normalises them.  The counterexample is
recorded next to `decMapChecked_encMapL_of_nodup`.  The "unknown" results
are about raw key-value pairs whose decoded key type is not one of the
modelled types; a pair whose key type *is* modelled is a typed field, not
an unknown pair (also recorded there).

## Corrected forms / counterexamples

The statement "every accepted map has strictly ascending keys" is false:
`decMapChecked` accepts `[(keyOf 0x01 d, v), (keyOf 0x00 d', v')]` (distinct
keys, unsorted).  The true invariants are (a) accepted maps have *unique*
keys, proved below, and (b) *encoded* maps are strictly ascending, proved
below.  Similarly, "every pair with an unmodelled-looking value survives as
unknown" is false: the filter is by decoded key type, so a pair with a known
type is consumed by the typed parser; the corrected hypothesis is
`isKnown*Type t = false` (plus absence of the v2 types rejected earlier).
-/

namespace BitcoinProofs.Wallet.Psbt.Invariants

open Bitcoin.Data
open Bitcoin.Serialization
open Bitcoin.Wallet.Psbt
open BitcoinProofs.Wallet.Psbt

/-! ## Duplicate-key decision -/

/-- Soundness and completeness of the decoder's `ByteArray` equality test. -/
theorem byteArray_beq_iff (a b : ByteArray) : (a == b) = true ↔ a = b := by
  constructor
  · intro h
    change (a.data == b.data) = true at h
    exact ByteArray.ext_iff.mpr (beq_iff_eq.mp h)
  · intro h
    subst h
    change (a.data == a.data) = true
    exact beq_iff_eq.mpr rfl

/-- `findDuplicate` returns `none` exactly on lists whose raw keys are
pairwise distinct.  This is the specification of the decoder's duplicate
test; it is a computable `Bool`/`Option` function, so the decision is not
accidental. -/
theorem findDuplicate_none_iff_nodup (kvs : List RawKV) :
    findDuplicate kvs = none ↔ (kvs.map (fun kv => kv.1)).Nodup := by
  induction kvs with
  | nil => simp [findDuplicate]
  | cons a rest ih =>
    unfold findDuplicate
    cases hany : rest.any (fun kv => kv.1 == a.1) with
    | true =>
      have hmem : a.1 ∈ rest.map (fun kv => kv.1) := by
        rw [List.any_eq_true] at hany
        obtain ⟨kv, hkv, hbeq⟩ := hany
        exact List.mem_map.mpr ⟨kv, hkv, (byteArray_beq_iff _ _).mp hbeq⟩
      simp [List.nodup_cons, hmem]
    | false =>
      rw [ite_eq_right (by simp)]
      rw [ih]
      simp only [List.map_cons, List.nodup_cons]
      rw [List.any_eq_false] at hany
      constructor
      · intro h
        refine ⟨?_, h⟩
        intro hmem
        rcases List.mem_map.mp hmem with ⟨kv, hkv, heq⟩
        exact hany kv hkv ((byteArray_beq_iff _ _).mpr heq)
      · rintro ⟨_, hnd⟩
        exact hnd

/-- A map accepted by the checked decoder has no duplicate raw key. -/
theorem decMapChecked_no_duplicate {l : Bytes} {kvs : List RawKV} {rest : Bytes}
    (h : decMapChecked l = .ok (kvs, rest)) : findDuplicate kvs = none := by
  unfold decMapChecked at h
  cases hm : decMapL l with
  | error e => rw [hm] at h; simp at h
  | ok p =>
    obtain ⟨m, l1⟩ := p
    rw [hm] at h
    simp only [bindE_ok] at h
    cases hc : checkKeyEncoding m with
    | error e => rw [hc] at h; simp at h
    | ok _ =>
      rw [hc] at h
      simp only [bindE_ok] at h
      cases hf : findDuplicate m with
      | some k => rw [hf] at h; simp at h
      | none =>
        rw [hf] at h
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        exact hf

/-- The accepted maps have pairwise distinct raw keys. -/
theorem decMapChecked_keys_nodup {l : Bytes} {kvs : List RawKV} {rest : Bytes}
    (h : decMapChecked l = .ok (kvs, rest)) :
    (kvs.map (fun kv => kv.1)).Nodup :=
  (findDuplicate_none_iff_nodup kvs).mp (decMapChecked_no_duplicate h)

/-- Duplicate rejection is decided by `findDuplicate`: once the map framing
and key encoding succeed, `decMapChecked` returns `ok` exactly when the
duplicate test returns `none`. -/
theorem decMapChecked_ok_iff (l : Bytes) (kvs : List RawKV) (rest : Bytes)
    (hl : decMapL l = .ok (kvs, rest))
    (hc : checkKeyEncoding kvs = .ok ()) :
    decMapChecked l = .ok (kvs, rest) ↔ findDuplicate kvs = none := by
  unfold decMapChecked
  rw [hl]
  simp only [bindE_ok]
  rw [hc]
  simp only [bindE_ok]
  cases hf : findDuplicate kvs with
  | none => simp
  | some k => simp

/-- Conversely, a duplicate detected in a successfully framed map is a
`duplicateKey` error, not an accidental failure elsewhere. -/
theorem decMapChecked_duplicate {l : Bytes} {kvs : List RawKV} {rest : Bytes}
    {k : ByteArray} (hl : decMapL l = .ok (kvs, rest))
    (hc : checkKeyEncoding kvs = .ok ()) (hf : findDuplicate kvs = some k) :
    decMapChecked l = .error (.duplicateKey k) := by
  unfold decMapChecked
  rw [hl]
  simp only [bindE_ok]
  rw [hc]
  simp only [bindE_ok, hf]

/-- Every map returned by `decNMaps` (hence every input/output map of a
successful `decode`) has pairwise distinct raw keys. -/
theorem decNMaps_keys_nodup : ∀ (n : Nat) (l : Bytes)
    (ms : List (List RawKV)) (rest : Bytes),
    decNMaps n l = .ok (ms, rest) →
    ∀ m ∈ ms, (m.map (fun kv => kv.1)).Nodup := by
  intro n
  induction n with
  | zero =>
    intro l ms rest h m hm
    rw [decNMaps.eq_1] at h
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    simp at hm
  | succ n ih =>
    intro l ms rest h m hm
    cases l with
    | nil =>
      rw [decNMaps.eq_2] at h
      simp at h
    | cons b bs =>
      rw [decNMaps.eq_3 _ n (by simp)] at h
      cases hd : decMapChecked (b :: bs) with
      | error e => rw [hd] at h; simp at h
      | ok q =>
        obtain ⟨m0, l1⟩ := q
        rw [hd] at h
        simp only [bindE_ok] at h
        cases hr : decNMaps n l1 with
        | error e => rw [hr] at h; simp at h
        | ok q2 =>
          obtain ⟨ms', rest'⟩ := q2
          rw [hr] at h
          simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl⟩ := h
          rcases List.mem_cons.mp hm with rfl | hm'
          · exact decMapChecked_keys_nodup hd
          · exact ih l1 ms' rest' hr m hm'

/-! ## The insertion sort behind `encode` -/

/-- The strict raw-key relation used by `encKVL` and `sortKVs`. -/
def KeyLt (a b : RawKV) : Prop := bytesLt (bL a.1) (bL b.1) = true

theorem keyLt_trans {a b c : RawKV} (hab : KeyLt a b) (hbc : KeyLt b c) :
    KeyLt a c :=
  bytesLt_trans hab hbc

theorem keyLt_irrefl (a : RawKV) : ¬ KeyLt a a := by
  intro h
  change bytesLt (bL a.1) (bL a.1) = true at h
  have hf : bytesLt (bL a.1) (bL a.1) = false := bytesLt_irrefl _
  rw [hf] at h
  exact Bool.noConfusion h

/-- Total trichotomy for the byte lexicographic order.  `UInt8` has no
`LinearOrder` instance in the pinned toolchain, so we construct the
trichotomy from `Nat.lt_trichotomy` on `toNat`. -/
theorem uint8_trichotomy (a b : UInt8) : a < b ∨ a = b ∨ b < a := by
  rcases Nat.lt_trichotomy a.toNat b.toNat with h | h | h
  · exact Or.inl (by simpa [UInt8.lt_iff_toNat_lt] using h)
  · exact Or.inr (Or.inl (UInt8.toNat_inj.mp h))
  · exact Or.inr (Or.inr (by simpa [UInt8.lt_iff_toNat_lt] using h))

theorem bytesLt_trichotomy : ∀ (a b : Bytes),
    bytesLt a b = true ∨ a = b ∨ bytesLt b a = true
  | [], [] => Or.inr (Or.inl rfl)
  | [], _ :: _ => Or.inl (by simp [bytesLt])
  | _ :: _, [] => Or.inr (Or.inr (by simp [bytesLt]))
  | x :: xs, y :: ys => by
    rcases uint8_trichotomy x y with hxy | heq | hyx
    · exact Or.inl (by simp [bytesLt, hxy])
    · subst heq
      rcases bytesLt_trichotomy xs ys with h | h | h
      · exact Or.inl (by simp [bytesLt, h])
      · exact Or.inr (Or.inl (by simp [h]))
      · exact Or.inr (Or.inr (by simp [bytesLt, h]))
    · exact Or.inr (Or.inr (by simp [bytesLt, hyx]))

/-- Trichotomy lifts to raw keys (the key is the whole `ByteArray`, so two
distinct keys are either strictly increasing or strictly decreasing). -/
theorem keyLt_trichotomy (a b : RawKV) :
    KeyLt a b ∨ a.1 = b.1 ∨ KeyLt b a := by
  rcases bytesLt_trichotomy (bL a.1) (bL b.1) with h | h | h
  · exact Or.inl h
  · exact Or.inr (Or.inl (bL_inj h))
  · exact Or.inr (Or.inr h)

/-- If `a` is not strictly below `b` and the keys differ, then `b` is
strictly below `a`. -/
theorem keyLt_of_not_of_ne {a b : RawKV} (h : ¬ KeyLt a b) (hne : a.1 ≠ b.1) :
    KeyLt b a := by
  rcases keyLt_trichotomy a b with hlt | heq | hgt
  · exact absurd hlt h
  · exact absurd heq hne
  · exact hgt

theorem insertKV_mem (kv x : RawKV) (xs : List RawKV) :
    x ∈ insertKV kv xs ↔ x = kv ∨ x ∈ xs := by
  induction xs with
  | nil => simp [insertKV]
  | cons y ys ih =>
    unfold insertKV
    by_cases h : bytesLt (bL kv.1) (bL y.1) = true
    · simp [h]
    · simp [h, ih, or_left_comm]

theorem sortKVs_mem (x : RawKV) (kvs : List RawKV) :
    x ∈ sortKVs kvs ↔ x ∈ kvs := by
  induction kvs with
  | nil => simp [sortKVs]
  | cons y ys ih =>
    change x ∈ insertKV y (sortKVs ys) ↔ x ∈ y :: ys
    rw [insertKV_mem, ih]
    simp

/-- Inserting a key distinct from every key of a strictly ascending list
preserves strict ascendancy. -/
theorem insertKV_pairwise {kv : RawKV} {xs : List RawKV}
    (hs : List.Pairwise KeyLt xs)
    (hne : ∀ x ∈ xs, x.1 ≠ kv.1) :
    List.Pairwise KeyLt (insertKV kv xs) := by
  induction xs with
  | nil => simp [insertKV]
  | cons x rest ih =>
    have hs' := List.pairwise_cons.mp hs
    have hxrest : ∀ y ∈ rest, KeyLt x y := hs'.1
    have hsrest : List.Pairwise KeyLt rest := hs'.2
    by_cases hlt : bytesLt (bL kv.1) (bL x.1) = true
    · have hkey : KeyLt kv x := hlt
      unfold insertKV
      rw [ite_eq_left hlt]
      rw [List.pairwise_cons]
      refine ⟨?_, hs⟩
      intro y hy
      rcases List.mem_cons.mp hy with rfl | hy'
      · exact hkey
      · exact keyLt_trans hkey (hxrest y hy')
    · have hne_rest : ∀ y ∈ rest, y.1 ≠ kv.1 :=
        fun y hy => hne y (List.mem_cons_of_mem _ hy)
      have ih' := ih hsrest hne_rest
      unfold insertKV
      rw [ite_eq_right hlt]
      rw [List.pairwise_cons]
      refine ⟨?_, ih'⟩
      intro y hy
      rw [insertKV_mem] at hy
      rcases hy with rfl | hy'
      · exact keyLt_of_not_of_ne hlt (Ne.symm (hne x (by simp)))
      · exact hxrest y hy'

/-- `sortKVs` produces a strictly ascending list whenever the input keys are
pairwise distinct. -/
theorem sortKVs_pairwise (kvs : List RawKV)
    (hnd : (kvs.map (fun kv => kv.1)).Nodup) :
    List.Pairwise KeyLt (sortKVs kvs) := by
  induction kvs with
  | nil => simp [sortKVs]
  | cons a rest ih =>
    have hnd' := List.nodup_cons.mp hnd
    have hnot : a.1 ∉ rest.map (fun kv => kv.1) := hnd'.1
    have htail : (rest.map (fun kv => kv.1)).Nodup := hnd'.2
    have hne : ∀ x ∈ sortKVs rest, x.1 ≠ a.1 := by
      intro x hx he
      have hxr : x ∈ rest := (sortKVs_mem x rest).mp hx
      exact hnot (List.mem_map.mpr ⟨x, hxr, he⟩)
    change List.Pairwise KeyLt (insertKV a (sortKVs rest))
    exact insertKV_pairwise (ih htail) hne

/-- `strictlySorted` (the encoder's `Bool` predicate) and `Pairwise KeyLt`
(the structural ordering predicate) agree. -/
theorem strictlySorted_iff_pairwise (kvs : List RawKV) :
    strictlySorted kvs = true ↔ List.Pairwise KeyLt kvs := by
  induction kvs with
  | nil => simp [strictlySorted]
  | cons a rest ih =>
    cases rest with
    | nil => simp [strictlySorted]
    | cons b bs =>
      change (bytesLt (bL a.1) (bL b.1) && strictlySorted (b :: bs)) = true ↔
        List.Pairwise KeyLt (a :: b :: bs)
      rw [List.pairwise_cons]
      constructor
      · intro h
        obtain ⟨hab, htail⟩ := Bool.and_eq_true_iff.mp h
        have htailpair : List.Pairwise KeyLt (b :: bs) := ih.mp htail
        refine ⟨?_, htailpair⟩
        intro y hy
        rcases List.mem_cons.mp hy with rfl | hy'
        · exact hab
        · exact keyLt_trans hab ((List.pairwise_cons.mp htailpair).1 y hy')
      · rintro ⟨hall, htailpair⟩
        have hab : KeyLt a b := hall b (by simp)
        have htail : strictlySorted (b :: bs) = true := ih.mpr htailpair
        exact Bool.and_eq_true_iff.mpr ⟨hab, htail⟩

theorem sortKVs_strictlySorted (kvs : List RawKV)
    (hnd : (kvs.map (fun kv => kv.1)).Nodup) :
    strictlySorted (sortKVs kvs) = true :=
  (strictlySorted_iff_pairwise _).mpr (sortKVs_pairwise kvs hnd)

/-- `kvSizesOk` is invariant under sorting (insertion sort is a
permutation). -/
theorem kvSizesOk_sortKVs {kvs : List RawKV} (h : kvSizesOk kvs = true) :
    kvSizesOk (sortKVs kvs) = true := by
  unfold kvSizesOk at *
  rw [List.all_eq_true] at h ⊢
  intro kv hkv
  exact h kv ((sortKVs_mem kv kvs).mp hkv)

/-- The sorted form of a sized, duplicate-free map is canonical. -/
theorem canonicalMap_sortKVs {kvs : List RawKV}
    (hsz : kvSizesOk kvs = true)
    (hnd : (kvs.map (fun kv => kv.1)).Nodup) :
    canonicalMap (sortKVs kvs) = true := by
  unfold canonicalMap
  rw [kvSizesOk_sortKVs hsz, sortKVs_strictlySorted kvs hnd]
  rfl

/-- `canonicalMap` implies pairwise distinct raw keys. -/
theorem canonicalMap_keys_nodup {kvs : List RawKV}
    (h : canonicalMap kvs = true) :
    (kvs.map (fun kv => kv.1)).Nodup := by
  have hstrict : strictlySorted kvs = true := by
    have h' := h
    unfold canonicalMap at h'
    exact (Bool.and_eq_true_iff.mp h').2
  exact (findDuplicate_none_iff_nodup kvs).mp
    (findDuplicate_eq_none_of_strictlySorted kvs hstrict)

/-! ## Canonical encoding is key-sorted -/

/-- The encoder's global map is strictly ascending on a canonical PSBT. -/
theorem encode_globalKVs_strictlySorted (p : Psbt) (hp : Canonical p) :
    strictlySorted (sortKVs (globalKVs p.global)) = true := by
  have h := hp
  unfold Canonical canonicalB at h
  simp only [Bool.and_eq_true_iff] at h
  have hg : canonicalMap (globalKVs p.global) = true := h.1.1.2
  exact sortKVs_strictlySorted _ (canonicalMap_keys_nodup hg)

/-- Every input map emitted by the encoder is strictly ascending on a
canonical PSBT. -/
theorem encode_inputKVs_strictlySorted (p : Psbt) (hp : Canonical p)
    (i : PsbtInput) (hi : i ∈ p.inputs) :
    strictlySorted (sortKVs (inputKVs i)) = true := by
  have h := hp
  unfold Canonical canonicalB at h
  simp only [Bool.and_eq_true_iff] at h
  have hall : p.inputs.all inputCanonical = true := h.1.2
  rw [List.all_eq_true] at hall
  have hci : inputCanonical i = true := hall i hi
  unfold inputCanonical at hci
  have hmap : canonicalMap (inputKVs i) = true := (Bool.and_eq_true_iff.mp hci).2
  exact sortKVs_strictlySorted _ (canonicalMap_keys_nodup hmap)

/-- Every output map emitted by the encoder is strictly ascending on a
canonical PSBT. -/
theorem encode_outputKVs_strictlySorted (p : Psbt) (hp : Canonical p)
    (o : PsbtOutput) (ho : o ∈ p.outputs) :
    strictlySorted (sortKVs (outputKVs o)) = true := by
  have h := hp
  unfold Canonical canonicalB at h
  simp only [Bool.and_eq_true_iff] at h
  have hall : p.outputs.all outputCanonical = true := h.2
  rw [List.all_eq_true] at hall
  have hco : outputCanonical o = true := hall o ho
  unfold outputCanonical at hco
  have hmap : canonicalMap (outputKVs o) = true := (Bool.and_eq_true_iff.mp hco).2
  exact sortKVs_strictlySorted _ (canonicalMap_keys_nodup hmap)

/-! ## The decoder does not require sorted input (corrected form) -/

/-- Corrected version of "accepted maps are sorted": the checked decoder
accepts any non-empty, CompactSize-sized, decodable-key map whose keys are
pairwise distinct, regardless of wire order.  This is exactly the domain the
decoder relies on; sortedness is an *encoder* obligation.

Counterexample to the stronger claim: with
`kvs = [(keyOf 0x01 d, v), (keyOf 0x00 d', v')]` the keys are distinct but
`bytesLt (keyOf 0x01 d) (keyOf 0x00 d') = false`, so `strictlySorted kvs`
is false while `decMapChecked (encMapL kvs) = ok (kvs, [])` by this theorem.
Core likewise accepts maps in any order and stores them in a `std::map`
(`src/psbt.h:581-584`), so it never rejects an unsorted map. -/
theorem decMapChecked_encMapL_of_nodup (kvs : List RawKV)
    (hwire : MapWireOK kvs)
    (hkeys : ∀ kv ∈ kvs, ∃ (t : Nat) (d : ByteArray), t < 0xfd ∧ kv.1 = keyOf t d)
    (hnd : (kvs.map (fun kv => kv.1)).Nodup) :
    decMapChecked (encMapL kvs) = .ok (kvs, []) := by
  unfold decMapChecked
  rw [decMapL_encMapL kvs hwire]
  simp only [bindE_ok]
  rw [checkKeyEncoding_keyOf kvs hkeys]
  simp only [bindE_ok]
  rw [(findDuplicate_none_iff_nodup kvs).mpr hnd]

/-! ## Input/output map indices are in bounds -/

theorem decNMaps_length : ∀ (n : Nat) (l : Bytes)
    (ms : List (List RawKV)) (rest : Bytes),
    decNMaps n l = .ok (ms, rest) → ms.length = n := by
  intro n
  induction n with
  | zero =>
    intro l ms rest h
    rw [decNMaps.eq_1] at h
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    rfl
  | succ n ih =>
    intro l ms rest h
    cases l with
    | nil =>
      rw [decNMaps.eq_2] at h
      simp at h
    | cons b bs =>
      rw [decNMaps.eq_3 _ n (by simp)] at h
      cases hd : decMapChecked (b :: bs) with
      | error e => rw [hd] at h; simp at h
      | ok q =>
        obtain ⟨m, l1⟩ := q
        rw [hd] at h
        simp only [bindE_ok] at h
        cases hr : decNMaps n l1 with
        | error e => rw [hr] at h; simp at h
        | ok q2 =>
          obtain ⟨ms', rest'⟩ := q2
          rw [hr] at h
          simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl⟩ := h
          simp [ih l1 ms' rest' hr]

theorem parseIns_length : ∀ (ms : List (List RawKV)) (ins : List PsbtInput),
    decode.parseIns ms = .ok ins → ins.length = ms.length := by
  intro ms
  induction ms with
  | nil =>
    intro ins h
    rw [decode.parseIns.eq_1] at h
    simp only [Except.ok.injEq] at h
    subst h
    rfl
  | cons m ms ih =>
    intro ins h
    rw [decode.parseIns.eq_2] at h
    cases hp : parseInput m with
    | error e => rw [hp] at h; simp at h
    | ok _ =>
      cases hrest : decode.parseIns ms with
      | error e => rw [hp, hrest] at h; simp at h
      | ok ins' =>
        rw [hp, hrest] at h
        simp only [bindE_ok, Except.ok.injEq] at h
        subst h
        simp [ih ins' hrest]

theorem parseOuts_length : ∀ (ms : List (List RawKV)) (outs : List PsbtOutput),
    decode.parseOuts ms = .ok outs → outs.length = ms.length := by
  intro ms
  induction ms with
  | nil =>
    intro outs h
    rw [decode.parseOuts.eq_1] at h
    simp only [Except.ok.injEq] at h
    subst h
    rfl
  | cons m ms ih =>
    intro outs h
    rw [decode.parseOuts.eq_2] at h
    cases hp : parseOutput m with
    | error e => rw [hp] at h; simp at h
    | ok _ =>
      cases hrest : decode.parseOuts ms with
      | error e => rw [hp, hrest] at h; simp at h
      | ok outs' =>
        rw [hp, hrest] at h
        simp only [bindE_ok, Except.ok.injEq] at h
        subst h
        simp [ih outs' hrest]

/-- A successful `decode` has exactly one input map per unsigned-tx input
and one output map per unsigned-tx output.  This is the index-bounds
invariant used by `spentOutput`, `inputViolations`, and `fillTx`. -/
theorem decode_indexBounded (b : ByteArray) (p : Psbt)
    (h : decode b = .ok p) :
    p.inputs.length = p.global.unsignedTx.vin.length ∧
      p.outputs.length = p.global.unsignedTx.vout.length := by
  unfold decode at h
  dsimp only at h
  split at h
  · cases hd : decMapChecked (List.drop 5 (bL b)) with
    | error e => rw [hd] at h; simp at h
    | ok q =>
      obtain ⟨gkvs, l1⟩ := q
      rw [hd] at h
      simp only [bindE_ok] at h
      cases hg : parseGlobal gkvs with
      | error e => rw [hg] at h; simp at h
      | ok g =>
        rw [hg] at h
        simp only [bindE_ok] at h
        cases hi : decNMaps g.unsignedTx.vin.length l1 with
        | error e => rw [hi] at h; simp at h
        | ok q2 =>
          obtain ⟨ikvss, l2⟩ := q2
          rw [hi] at h
          simp only [bindE_ok] at h
          cases ho : decNMaps g.unsignedTx.vout.length l2 with
          | error e => rw [ho] at h; simp at h
          | ok q3 =>
            obtain ⟨okvss, l3⟩ := q3
            rw [ho] at h
            simp only [bindE_ok] at h
            cases he : l3.isEmpty with
            | false => rw [he] at h; simp at h
            | true =>
              simp only [he, ite_true] at h
              cases hins : decode.parseIns ikvss with
              | error e => rw [hins] at h; simp at h
              | ok ins =>
                rw [hins] at h
                simp only [bindE_ok] at h
                cases houts : decode.parseOuts okvss with
                | error e => rw [houts] at h; simp at h
                | ok outs =>
                  rw [houts] at h
                  simp only [bindE_ok] at h
                  cases hut : checkUtxos g.unsignedTx 0 ins with
                  | error e => rw [hut] at h; simp at h
                  | ok _ =>
                    rw [hut] at h
                    simp only [bindE_ok, Except.ok.injEq] at h
                    subst h
                    constructor
                    · rw [parseIns_length ikvss ins hins]
                      exact decNMaps_length g.unsignedTx.vin.length l1
                        ikvss l2 hi
                    · rw [parseOuts_length okvss outs houts]
                      exact decNMaps_length g.unsignedTx.vout.length l2
                        okvss l3 ho
  · simp at h

theorem decode_inputs_length (b : ByteArray) (p : Psbt)
    (h : decode b = .ok p) :
    p.inputs.length = p.global.unsignedTx.vin.length :=
  (decode_indexBounded b p h).1

theorem decode_outputs_length (b : ByteArray) (p : Psbt)
    (h : decode b = .ok p) :
    p.outputs.length = p.global.unsignedTx.vout.length :=
  (decode_indexBounded b p h).2

/-- At every valid input index of a decoded PSBT there is an input map. -/
theorem decode_input_at (b : ByteArray) (p : Psbt)
    (h : decode b = .ok p) {k : Nat}
    (hk : k < p.global.unsignedTx.vin.length) :
    ∃ inp, p.inputs[k]? = some inp := by
  have hk' : k < p.inputs.length := by
    rw [decode_inputs_length b p h]; exact hk
  exact ⟨p.inputs[k], List.getElem?_eq_some_iff.mpr ⟨hk', rfl⟩⟩

/-- At every valid output index of a decoded PSBT there is an output map. -/
theorem decode_output_at (b : ByteArray) (p : Psbt)
    (h : decode b = .ok p) {k : Nat}
    (hk : k < p.global.unsignedTx.vout.length) :
    ∃ out, p.outputs[k]? = some out := by
  have hk' : k < p.outputs.length := by
    rw [decode_outputs_length b p h]; exact hk
  exact ⟨p.outputs[k], List.getElem?_eq_some_iff.mpr ⟨hk', rfl⟩⟩

/-! ## Unknown key-value pairs survive the raw map round trip -/

/-- A member of a `flatMap` contributes its own block contiguously. -/
theorem exists_append_of_mem_flatMap {α β : Type} (f : α → List β) :
    ∀ {l : List α} {x : α}, x ∈ l →
      ∃ pre post, l.flatMap f = pre ++ f x ++ post := by
  intro l
  induction l with
  | nil => intro x hx; simp at hx
  | cons a as ih =>
    intro x hx
    rcases List.mem_cons.mp hx with rfl | hx'
    · exact ⟨[], as.flatMap f, by simp⟩
    · obtain ⟨pre, post, hpre⟩ := ih hx'
      exact ⟨f a ++ pre, post, by
        simp only [List.flatMap_cons, hpre, List.append_assoc]⟩

/-- Map-level unknown preservation.  If `u` is a sublist of the encoder's
raw map `kvs`, then (i) the checked decoder accepts the sorted encoding and
returns the same raw entries, (ii) every `kv ∈ u` is among the returned raw
entries, and (iii) the same `encKVL kv` block occurs in the re-encoded map.
Thus each unknown pair survives with identical key and value bytes.

The hypotheses `hcanon` (length bounds plus strict order) and `hkeys`
(decodable v0 key types) are precisely the framing hypotheses of
`decMapChecked_encMapL`; they do not assume anything about which types are
"unknown". -/
theorem decMapChecked_encMapL_unknown_preserved
    (kvs u : List RawKV)
    (hcanon : canonicalMap (sortKVs kvs) = true)
    (hkeys : ∀ kv ∈ sortKVs kvs,
      ∃ (t : Nat) (d : ByteArray), t < 0xfd ∧ kv.1 = keyOf t d)
    (hsub : ∀ kv ∈ u, kv ∈ kvs) :
    decMapChecked (encMapL (sortKVs kvs)) = .ok (sortKVs kvs, []) ∧
      (∀ kv ∈ u, kv ∈ sortKVs kvs) ∧
      (∀ kv ∈ u, ∃ pre post,
        encMapBodyL (sortKVs kvs) = pre ++ encKVL kv ++ post) := by
  have hdec := decMapChecked_encMapL (sortKVs kvs) hcanon hkeys
  refine ⟨hdec, ?_, ?_⟩
  · intro kv hkv
    exact (sortKVs_mem kv kvs).mpr (hsub kv hkv)
  · intro kv hkv
    have hmem : kv ∈ sortKVs kvs := (sortKVs_mem kv kvs).mpr (hsub kv hkv)
    have hsplit := exists_append_of_mem_flatMap (encKVL) (l := sortKVs kvs)
      (x := kv) hmem
    simpa [encMapBodyL] using hsplit

/-- The global unknown list is a suffix of `globalKVs`. -/
theorem global_unknown_mem_globalKVs (g : Global) :
    ∀ kv ∈ g.unknown, kv ∈ globalKVs g := by
  intro kv hkv
  unfold globalKVs
  simp [hkv]

/-- The input unknown list is a suffix of `inputKVs`. -/
theorem input_unknown_mem_inputKVs (i : PsbtInput) :
    ∀ kv ∈ i.unknown, kv ∈ inputKVs i := by
  intro kv hkv
  unfold inputKVs
  simp [hkv]

/-- The output unknown list is a suffix of `outputKVs`. -/
theorem output_unknown_mem_outputKVs (o : PsbtOutput) :
    ∀ kv ∈ o.unknown, kv ∈ outputKVs o := by
  intro kv hkv
  unfold outputKVs
  simp [hkv]

/-- Global unknown pairs are preserved byte-for-byte through the global map
decode/encode. -/
theorem global_unknown_preserved (g : Global)
    (hcanon : canonicalMap (sortKVs (globalKVs g)) = true)
    (hkeys : ∀ kv ∈ sortKVs (globalKVs g),
      ∃ (t : Nat) (d : ByteArray), t < 0xfd ∧ kv.1 = keyOf t d)
    (kv : RawKV) (hkv : kv ∈ g.unknown) :
    decMapChecked (encMapL (sortKVs (globalKVs g)))
        = .ok (sortKVs (globalKVs g), []) ∧
      kv ∈ sortKVs (globalKVs g) ∧
      ∃ pre post, encMapBodyL (sortKVs (globalKVs g))
        = pre ++ encKVL kv ++ post := by
  have h := decMapChecked_encMapL_unknown_preserved
    (globalKVs g) g.unknown hcanon hkeys (global_unknown_mem_globalKVs g)
  exact ⟨h.1, h.2.1 kv hkv, h.2.2 kv hkv⟩

/-- Input unknown pairs are preserved byte-for-byte through the input map
decode/encode. -/
theorem input_unknown_preserved (i : PsbtInput)
    (hcanon : canonicalMap (sortKVs (inputKVs i)) = true)
    (hkeys : ∀ kv ∈ sortKVs (inputKVs i),
      ∃ (t : Nat) (d : ByteArray), t < 0xfd ∧ kv.1 = keyOf t d)
    (kv : RawKV) (hkv : kv ∈ i.unknown) :
    decMapChecked (encMapL (sortKVs (inputKVs i)))
        = .ok (sortKVs (inputKVs i), []) ∧
      kv ∈ sortKVs (inputKVs i) ∧
      ∃ pre post, encMapBodyL (sortKVs (inputKVs i))
        = pre ++ encKVL kv ++ post := by
  have h := decMapChecked_encMapL_unknown_preserved
    (inputKVs i) i.unknown hcanon hkeys (input_unknown_mem_inputKVs i)
  exact ⟨h.1, h.2.1 kv hkv, h.2.2 kv hkv⟩

/-- Output unknown pairs are preserved byte-for-byte through the output map
decode/encode. -/
theorem output_unknown_preserved (o : PsbtOutput)
    (hcanon : canonicalMap (sortKVs (outputKVs o)) = true)
    (hkeys : ∀ kv ∈ sortKVs (outputKVs o),
      ∃ (t : Nat) (d : ByteArray), t < 0xfd ∧ kv.1 = keyOf t d)
    (kv : RawKV) (hkv : kv ∈ o.unknown) :
    decMapChecked (encMapL (sortKVs (outputKVs o)))
        = .ok (sortKVs (outputKVs o), []) ∧
      kv ∈ sortKVs (outputKVs o) ∧
      ∃ pre post, encMapBodyL (sortKVs (outputKVs o))
        = pre ++ encKVL kv ++ post := by
  have h := decMapChecked_encMapL_unknown_preserved
    (outputKVs o) o.unknown hcanon hkeys (output_unknown_mem_outputKVs o)
  exact ⟨h.1, h.2.1 kv hkv, h.2.2 kv hkv⟩

end BitcoinProofs.Wallet.Psbt.Invariants
