import Bitcoin.Wallet.Psbt.Laws
import Bitcoin.Wallet.RuleAttr

/-!
# PSBT v0 — CompactSize and canonical-map laws

This module proves the byte-level canonicality facts that the committed
model (`Bitcoin.Wallet.Psbt.Encode`) states but does not prove:

* the CompactSize parse/encode round-trip at the PSBT layer, on the
  represented domain `n ≤ MAX_SIZE` (`src/serialize.h:35`);
* strict lexicographic key order (`strictlySorted`) is preserved by the
  insertion sort (`sortKVs`) and excludes duplicate raw keys
  (`src/psbt.h:581-584`);
* `decMapChecked` accepts the canonical encoding of every map whose
  keys are decodable and whose key/value lengths fit a CompactSize;
* a successful map decode re-encodes to exactly the consumed prefix,
  with the separator reinserted (`src/psbt.h:568-584,914-923`).

## What is NOT modelled or claimed

Nothing here claims that an arbitrary byte string accepted by Core is
canonical: the decoder also accepts maps in non-ascending order, and
`sortKVs` normalises those.  The canonical predicate used for the
identity statements is the encoder-side predicate from
`Bitcoin.Wallet.Psbt.Encode`, not Core's acceptance set.  No signature,
script, fee or consensus validity is asserted.
-/

namespace BitcoinProofs.Wallet.Psbt

open Bitcoin.Data
open Bitcoin.Serialization
open Bitcoin.Wallet.Psbt

/-! ## CompactSize at the PSBT layer -/

/-- The PSBT-layer CompactSize decoder inverts the canonical encoder on
the represented domain `n ≤ MAX_SIZE`.  Core's `ReadCompactSize` rejects
non-minimal forms (`serialize.h:333-361`), so this is an iff on the
canonical image; it is not a law about arbitrary length prefixes. -/
theorem decCsP_encCSL (n : Nat) (h : n ≤ Bitcoin.Serialization.MAX_SIZE) (rest : Bytes) :
    decCsP (encCSL n ++ rest) = .ok (n, rest) := by
  unfold decCsP
  rw [decCS_encCSL n h rest]

/-- A successful PSBT-layer CompactSize decode consumed a canonical
encoding. -/
theorem decCsP_shape {l : Bytes} {n : Nat} {rest : Bytes}
    (h : decCsP l = .ok (n, rest)) : l = encCSL n ++ rest := by
  unfold decCsP at h
  cases hc : decCS l with
  | error e => rw [hc] at h; simp at h
  | ok p =>
    obtain ⟨m, r⟩ := p
    rw [hc] at h
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    exact decCS_shape l m r hc

/-! ## Lexicographic key order -/

/-- `bytesLt` is exactly the list lexicographic order inherited from
`UInt8`.  This is the order Core's `std::vector<unsigned char>::operator<`
uses for map keys. -/
theorem bytesLt_iff_lt (a b : Bytes) : bytesLt a b = true ↔ a < b := by
  induction a generalizing b with
  | nil =>
    cases b with
    | nil => simp [bytesLt]
    | cons y ys => simp [bytesLt]
  | cons x xs ih =>
    cases b with
    | nil => simp [bytesLt]
    | cons y ys =>
      simp only [bytesLt, List.cons_lex_cons_iff]
      by_cases hxy : x < y
      · have hlex : List.Lex (· < ·) (x :: xs) (y :: ys) := List.Lex.rel hxy
        simpa [hxy] using hlex
      · have hle : y ≤ x := UInt8.not_lt.mp hxy
        by_cases hyx : y < x
        · have hne : x ≠ y := by
            intro he
            rw [he] at hyx
            exact UInt8.lt_irrefl y hyx
          rw [if_neg hxy, if_pos hyx]
          simp only [Bool.false_eq_true, false_iff]
          intro hl
          rcases (List.cons_lex_cons_iff.mp hl) with hlt | ⟨heq, _⟩
          · exact hxy hlt
          · exact hne heq
        · have heq : x = y := UInt8.le_antisymm (UInt8.not_lt.mp hyx) hle
          subst heq
          rw [if_neg hxy, if_neg hyx]
          simpa using ih ys

/-- `bytesLt` is irreflexive. -/
theorem bytesLt_irrefl (a : Bytes) : bytesLt a a = false := by
  cases h : bytesLt a a with
  | false => rfl
  | true => exact absurd ((bytesLt_iff_lt a a).mp h) (List.lt_irrefl a)

/-- Distinct keys are unequal. -/
theorem bytesLt_ne {a b : Bytes} (h : bytesLt a b = true) : a ≠ b := by
  intro he
  subst he
  rw [bytesLt_irrefl] at h
  exact Bool.noConfusion h

/-- `bytesLt` is transitive. -/
theorem bytesLt_trans {a b c : Bytes}
    (hab : bytesLt a b = true) (hbc : bytesLt b c = true) :
    bytesLt a c = true := by
  rw [bytesLt_iff_lt] at *
  exact List.lex_trans (fun h₁ h₂ => UInt8.lt_trans h₁ h₂) hab hbc

/-- Every entry after the head of a strictly sorted list has a strictly
larger key than the head. -/
theorem strictlySorted_head_lt_of_mem :
    ∀ {a : RawKV} {xs : List RawKV}, strictlySorted (a :: xs) = true →
      ∀ y ∈ xs, bytesLt (bL a.1) (bL y.1) = true
  | a, [], _, y, hy => by simp at hy
  | a, b :: bs, h, y, hy => by
    have hh : (bytesLt (bL a.1) (bL b.1) && strictlySorted (b :: bs)) = true := by
      simpa [strictlySorted] using h
    have hab : bytesLt (bL a.1) (bL b.1) = true := (Bool.and_eq_true_iff.mp hh).1
    have htail : strictlySorted (b :: bs) = true := (Bool.and_eq_true_iff.mp hh).2
    rcases List.mem_cons.mp hy with rfl | hy'
    · exact hab
    · exact bytesLt_trans hab (strictlySorted_head_lt_of_mem htail y hy')

/-- The tail of a strictly sorted non-empty list is strictly sorted. -/
theorem strictlySorted_tail (a : RawKV) (rest : List RawKV)
    (h : strictlySorted (a :: rest) = true) : strictlySorted rest = true := by
  cases rest with
  | nil => rfl
  | cons b bs =>
    have hh : (bytesLt (bL a.1) (bL b.1) && strictlySorted (b :: bs)) = true := by
      simpa [strictlySorted] using h
    exact (Bool.and_eq_true_iff.mp hh).2

/-- Byte-array Boolean equality is sound.  `ByteArray` itself has no
`LawfulBEq` instance, so we go through the underlying `Array UInt8`. -/
theorem byteArray_beq_eq {a b : ByteArray} (h : (a == b) = true) : a = b := by
  change (a.data == b.data) = true at h
  exact ByteArray.ext_iff.mpr (beq_iff_eq.mp h)

/-- A strictly sorted map has no duplicate raw key. -/
theorem findDuplicate_eq_none_of_strictlySorted :
    ∀ kvs : List RawKV, strictlySorted kvs = true → findDuplicate kvs = none
  | [], _ => rfl
  | a :: rest, h => by
    have htail := strictlySorted_tail a rest h
    have hno : rest.any (fun kv => kv.1 == a.1) = false := by
      cases hany : rest.any (fun kv => kv.1 == a.1) with
      | false => rfl
      | true =>
        rw [List.any_eq_true] at hany
        obtain ⟨kv, hmem, hbeq⟩ := hany
        have hkey : kv.1 = a.1 := byteArray_beq_eq hbeq
        have hlt := strictlySorted_head_lt_of_mem h kv hmem
        rw [hkey, bytesLt_irrefl] at hlt
        exact Bool.noConfusion hlt
    simp [findDuplicate, hno, findDuplicate_eq_none_of_strictlySorted rest htail]

/-- Insertion of an entry smaller than every key of a list puts it at
the head. -/
theorem insertKV_eq_cons_of_all_lt (kv : RawKV) :
    ∀ {xs : List RawKV}, (∀ y ∈ xs, bytesLt (bL kv.1) (bL y.1) = true) →
      insertKV kv xs = kv :: xs
  | [], _ => rfl
  | x :: xs, h => by
    have hx : bytesLt (bL kv.1) (bL x.1) = true := h x (by simp)
    simp [insertKV, hx]

/-- The insertion sort is the identity on a strictly sorted list. -/
theorem sortKVs_eq_self :
    ∀ kvs : List RawKV, strictlySorted kvs = true → sortKVs kvs = kvs
  | [], _ => rfl
  | a :: rest, h => by
    have htail := strictlySorted_tail a rest h
    have hlt : ∀ y ∈ rest, bytesLt (bL a.1) (bL y.1) = true :=
      strictlySorted_head_lt_of_mem h
    change insertKV a (sortKVs rest) = a :: rest
    rw [sortKVs_eq_self rest htail]
    exact insertKV_eq_cons_of_all_lt a hlt

/-! ## The decoder's accepted canonical maps -/

/-- `canonicalMap` supplies the two framing facts `MapWireOK` needs:
each key and value fits a CompactSize and no key is empty. -/
theorem canonicalMap_mapWireOK {kvs : List RawKV} (h : canonicalMap kvs = true) :
    MapWireOK kvs := by
  have hboth : kvSizesOk kvs = true ∧ strictlySorted kvs = true := by
    simpa [canonicalMap] using h
  have hall : ∀ x ∈ kvs, x.1.size ≤ Bitcoin.Serialization.MAX_SIZE
      ∧ x.2.size ≤ Bitcoin.Serialization.MAX_SIZE ∧ !x.1.isEmpty = true := by
    have hsz := hboth.1
    simp only [kvSizesOk] at hsz
    rw [List.all_eq_true] at hsz
    intro x hx
    have hx' := hsz x hx
    simpa [Bool.and_eq_true_iff, and_assoc] using hx'
  exact hall

/-- A key produced by `keyOf` for a v0 key type is decodable by
`typeAndData`, which recovers the type and the key data exactly. -/
theorem typeAndData_keyOf (typ : Nat) (h : typ < 0xfd) (d : ByteArray) :
    typeAndData (keyOf typ d) = some (typ, d) := by
  unfold typeAndData keyOf
  rw [bL_bytesOfList]
  have htyp : typ < 256 := by omega
  have hto : typ.toUInt8.toNat = typ := by
    rw [show typ.toUInt8.toNat = typ % 256 from rfl, Nat.mod_eq_of_lt htyp]
  have hlt : typ.toUInt8.toNat < 0xfd := by omega
  simp [decCS, hto, h, bytesOfList_bL]

/-- Every key of a list produced by `keyOf` from a v0 type is accepted by
the decoder's `checkKeyEncoding`. -/
theorem checkKeyEncoding_keyOf (kvs : List RawKV)
    (h : ∀ kv ∈ kvs, ∃ (t : Nat) (d : ByteArray), t < 0xfd ∧ kv.1 = keyOf t d) :
    checkKeyEncoding kvs = .ok () := by
  induction kvs with
  | nil => rfl
  | cons kv rest ih =>
    obtain ⟨t, d, ht, hkey⟩ := h kv (by simp)
    have hrest : ∀ x ∈ rest, ∃ (t : Nat) (d : ByteArray), t < 0xfd ∧ x.1 = keyOf t d :=
      fun x hx => h x (List.mem_cons_of_mem _ hx)
    simp [checkKeyEncoding, hkey, typeAndData_keyOf t ht d, ih hrest]

/-- `decMapChecked` accepts the canonical encoding of a map whose entries
are framed, whose keys are `keyOf`-encoded v0 types, and whose keys are
strictly ascending (hence duplicate-free). -/
theorem decMapChecked_encMapL (kvs : List RawKV) (hmap : canonicalMap kvs = true)
    (hkeys : ∀ kv ∈ kvs, ∃ (t : Nat) (d : ByteArray), t < 0xfd ∧ kv.1 = keyOf t d) :
    decMapChecked (encMapL kvs) = .ok (kvs, []) := by
  have hwire := canonicalMap_mapWireOK hmap
  have hboth : kvSizesOk kvs = true ∧ strictlySorted kvs = true := by
    simpa [canonicalMap] using hmap
  have hsorted : strictlySorted kvs = true := hboth.2
  unfold decMapChecked
  rw [decMapL_encMapL kvs hwire]
  simp only [bindE_ok]
  rw [checkKeyEncoding_keyOf kvs hkeys]
  simp only [bindE_ok]
  rw [findDuplicate_eq_none_of_strictlySorted kvs hsorted]

/-- Map inversion shape at the checked-decoder layer: a successful
`decMapChecked` consumed exactly the canonical map encoding. -/
theorem decMapChecked_shape (l : Bytes) (kvs : List RawKV) (tail : Bytes)
    (h : decMapChecked l = .ok (kvs, tail)) : l = encMapL kvs ++ tail := by
  unfold decMapChecked at h
  cases hd : decMapL l with
  | error e => rw [hd] at h; simp at h
  | ok p =>
    obtain ⟨m, l1⟩ := p
    rw [hd] at h
    simp only [bindE_ok] at h
    cases hc : checkKeyEncoding m with
    | error e => rw [hc] at h; simp at h
    | ok u =>
      rw [hc] at h
      simp only [bindE_ok] at h
      cases hdup : findDuplicate m with
      | some k => rw [hdup] at h; simp at h
      | none =>
        rw [hdup] at h
        have hp : (m, l1) = (kvs, tail) := by
          simpa only [Except.ok.injEq] using h
        have hm : m = kvs := (Prod.mk.inj hp).1
        have hl : l1 = tail := (Prod.mk.inj hp).2
        rw [hm] at hd
        rw [hl] at hd
        exact decMapL_shape l kvs tail hd

/-- A strictly sorted canonical map has no duplicate raw key.  This is the
map-level counterpart of the decoder's duplicate check. -/
theorem canonicalMap_no_duplicateKey {kvs : List RawKV}
    (h : canonicalMap kvs = true) : findDuplicate kvs = none := by
  have hboth : kvSizesOk kvs = true ∧ strictlySorted kvs = true := by
    simpa [canonicalMap] using h
  exact findDuplicate_eq_none_of_strictlySorted kvs hboth.2

/-! ## Traceability tags

The tags below are attached only to declarations that prove the named
component of the row's statement over the committed model.  Rows whose statement
mentions Core behaviour outside the model (for example `PSBT-009`'s
`CPubKey::IsFullyValid`) are intentionally not tagged here. A tag on a PARTIAL
row covers the declared component, not the row's uncovered cases. -/

/-- **PSBT-002.** A successful map-entry decode consumed exactly a
CompactSize-prefixed key followed by a CompactSize-prefixed value, with the
stated lengths equal to the decoded component lengths.  A length prefix that
did not match the consumed key/value bytes therefore cannot be accepted as
that record. -/
@[walletRule "PSBT-002"]
theorem decKV_is_length_prefixed {l : Bytes} {kv : RawKV} {rest : Bytes}
    (h : decKV l = .ok (kv, rest)) :
    l = encCSL kv.1.size ++ bL kv.1 ++ encCSL kv.2.size ++ bL kv.2 ++ rest := by
  simpa [encKVL, List.append_assoc] using decKV_shape l kv rest h

/-- **PSBT-003.** Once the map body has been decoded and every key encoding
has been checked, a duplicate raw key is rejected with `duplicateKey`. -/
@[walletRule "PSBT-003"]
theorem decMapChecked_rejects_duplicate {l : Bytes} {kvs : List RawKV}
    {rest : Bytes} {k : ByteArray}
    (hd : decMapL l = .ok (kvs, rest))
    (hc : checkKeyEncoding kvs = .ok ())
    (hdup : findDuplicate kvs = some k) :
    decMapChecked l = .error (.duplicateKey k) := by
  unfold decMapChecked
  rw [hd]
  simp only [bindE_ok]
  rw [hc]
  simp only [bindE_ok, hdup]

end BitcoinProofs.Wallet.Psbt
