import BitcoinProofs.Wallet.Psbt.Canonical
import Bitcoin.Wallet.RuleAttr

/-!
# PSBT v0 — decoder/encoder round trips

This module proves the inversion laws for the committed PSBT v0 model:
the typed parsers recover exactly what the canonical encoder emitted, map
decoding recovers exactly the encoded maps, and the whole-file decoder
`decode` accepts `encode p` and returns `p` on a precisely stated
wire-canonical domain.

The whole-file law is **not** the unrestricted statement
`decode (encode p) = .ok p` for every `Canonical p` from
`Bitcoin.Wallet.Psbt.Laws`: `Canonical` is an encoder-side ordering /
no-dropped-field predicate and does not by itself constrain key data
sizes, unknown key types, or transaction wire domains.  `WireCanonical`
below adds the remaining parser obligations; the comment above it records
concrete counterexamples to the unrestricted form.

## What is NOT modelled or claimed

* No signature, script, fee, policy or consensus validity is proved.
* Core's cryptographic key checks (`CPubKey::IsFullyValid`,
  `CheckSignatureEncoding`) are outside the model; only the structural
  length constraints of the committed decoder are analysed.
* The Taproot builder completeness check and PSBT v2 are not modelled.
-/

namespace BitcoinProofs.Wallet.Psbt

open Bitcoin.Data
open Bitcoin.Serialization
open Bitcoin.Wallet.Psbt

/-! ## Generic map-entry lemmas -/

/-- `entriesOfType` distributes over list concatenation. -/
theorem entriesOfType_append (typ : Nat) (a b : List RawKV) :
    entriesOfType typ (a ++ b) = entriesOfType typ a ++ entriesOfType typ b := by
  induction a with
  | nil => simp [entriesOfType]
  | cons kv rest ih =>
    unfold entriesOfType at ih ⊢
    cases h : typeAndData kv.1 with
    | none => simp [h, ih]
    | some p =>
      obtain ⟨t, d⟩ := p
      by_cases ht : t = typ <;> simp [h, ht, ih]

/-- A single `keyOf`-encoded entry of the same type is returned by
`entriesOfType`. -/
theorem entriesOfType_keyOf_same (typ : Nat) (h : typ < 0xfd)
    (d v : ByteArray) :
    entriesOfType typ [kvData typ d v] = [(d, v)] := by
  simp [entriesOfType, kvData, typeAndData_keyOf typ h d]

/-- A single `keyOf`-encoded entry of a different type is filtered out. -/
theorem entriesOfType_keyOf_ne (typ t : Nat) (h : t < 0xfd) (hne : t ≠ typ)
    (d v : ByteArray) :
    entriesOfType typ [kvData t d v] = [] := by
  simp [entriesOfType, kvData, typeAndData_keyOf t h d, hne]

/-- A mapped group of entries of the same type is returned unchanged. -/
theorem entriesOfType_map_kvData_same (typ : Nat) (h : typ < 0xfd)
    (l : List (ByteArray × ByteArray)) :
    entriesOfType typ (l.map (fun p => kvData typ p.1 p.2)) = l := by
  induction l with
  | nil => rfl
  | cons p rest ih =>
    obtain ⟨d, v⟩ := p
    have hstep : entriesOfType typ
        (List.map (fun p => kvData typ p.1 p.2) ((d, v) :: rest))
        = (d, v) :: entriesOfType typ
            (List.map (fun p => kvData typ p.1 p.2) rest) := by
      simp [entriesOfType, kvData, typeAndData_keyOf typ h d]
    rw [hstep, ih]

/-- A mapped group of entries of a different type is filtered out. -/
theorem entriesOfType_map_kvData_ne (typ t : Nat) (h : t < 0xfd) (hne : t ≠ typ)
    (l : List (ByteArray × ByteArray)) :
    entriesOfType typ (l.map (fun p => kvData t p.1 p.2)) = [] := by
  induction l with
  | nil => rfl
  | cons p rest ih =>
    obtain ⟨d, v⟩ := p
    simp only [List.map_cons]
    rw [show kvData t d v :: List.map (fun p => kvData t p.1 p.2) rest
        = [kvData t d v] ++ List.map (fun p => kvData t p.1 p.2) rest from rfl]
    rw [entriesOfType_append, entriesOfType_keyOf_ne typ t h hne d v, ih]
    rfl


/-- The `keyOf`-mapped form of `entriesOfType_map_kvData_same`. -/
theorem entriesOfType_map_keyOf_same {α : Type} (typ : Nat) (h : typ < 0xfd)
    (l : List α) (f : α → ByteArray) (g : α → ByteArray) :
    entriesOfType typ (l.map (fun x => (keyOf typ (f x), g x)))
      = l.map (fun x => (f x, g x)) := by
  induction l with
  | nil => rfl
  | cons x rest ih =>
    simp only [List.map_cons]
    have hstep : entriesOfType typ
        ((keyOf typ (f x), g x) :: List.map (fun x => (keyOf typ (f x), g x)) rest)
        = (f x, g x) :: entriesOfType typ
            (List.map (fun x => (keyOf typ (f x), g x)) rest) := by
      simp [entriesOfType, typeAndData_keyOf typ h (f x)]
    rw [hstep, ih]

/-- The `keyOf`-mapped form of `entriesOfType_map_kvData_ne`. -/
theorem entriesOfType_map_keyOf_ne {α : Type} (typ t : Nat) (h : t < 0xfd)
    (hne : t ≠ typ) (l : List α) (f : α → ByteArray) (g : α → ByteArray) :
    entriesOfType typ (l.map (fun x => (keyOf t (f x), g x))) = [] := by
  induction l with
  | nil => rfl
  | cons x rest ih =>
    simp only [List.map_cons]
    rw [show (keyOf t (f x), g x) :: List.map (fun x => (keyOf t (f x), g x)) rest
        = [(keyOf t (f x), g x)] ++ List.map (fun x => (keyOf t (f x), g x)) rest from rfl]
    rw [entriesOfType_append]
    have hsingle : entriesOfType typ [(keyOf t (f x), g x)] = [] := by
      simp [entriesOfType, typeAndData_keyOf t h (f x), hne]
    rw [hsingle, ih]
    rfl

/-- A list all of whose key types differ from `typ` contributes no
`entriesOfType typ`. -/
theorem entriesOfType_eq_nil_of_all_ne (typ : Nat) (kvs : List RawKV)
    (h : ∀ kv ∈ kvs, ∀ (t : Nat) (d : ByteArray),
      typeAndData kv.1 = some (t, d) → t ≠ typ) :
    entriesOfType typ kvs = [] := by
  unfold entriesOfType
  rw [List.filterMap_eq_nil_iff]
  intro kv hkv
  cases hd : typeAndData kv.1 with
  | none => rfl
  | some p =>
    obtain ⟨t, d⟩ := p
    have ht : t ≠ typ := h kv hkv t d hd
    simp [hd, ht]


/-! ## Global-map round trip -/

/-- Unknown global keys: decodable, not a modelled type, and not one of
the v2 global types that the v0 decoder rejects. -/
def GlobalUnknownOK (u : List RawKV) : Prop :=
  ∀ kv ∈ u, ∃ (t : Nat) (d : ByteArray),
    typeAndData kv.1 = some (t, d)
    ∧ isKnownGlobalType t = false
    ∧ t ≠ GLOBAL_TX_VERSION ∧ t ≠ GLOBAL_FALLBACK_LOCKTIME
    ∧ t ≠ GLOBAL_INPUT_COUNT ∧ t ≠ GLOBAL_OUTPUT_COUNT
    ∧ t ≠ GLOBAL_TX_MODIFIABLE

/-- `isKnownGlobalType` is false exactly for types other than `0x00`,
`0x01` and `0xFB`. -/
theorem isKnownGlobalType_false_iff (t : Nat) :
    isKnownGlobalType t = false
      ↔ t ≠ GLOBAL_UNSIGNED_TX ∧ t ≠ GLOBAL_XPUB ∧ t ≠ GLOBAL_VERSION := by
  unfold isKnownGlobalType
  constructor
  · intro h
    refine ⟨?_, ?_, ?_⟩
    · intro he; rw [he] at h; simp at h
    · intro he; rw [he] at h; simp at h
    · intro he; rw [he] at h; simp at h
  · rintro ⟨h0, h1, hv⟩
    simp [h0, h1, hv]

/-- A decoded entry has a unique key type/data pair. -/
theorem typeAndData_inj {k : ByteArray} {t t' : Nat} {d d' : ByteArray}
    (h : typeAndData k = some (t, d)) (h' : typeAndData k = some (t', d')) :
    t = t' ∧ d = d' := by
  rw [h] at h'
  injection h' with hp
  exact Prod.mk.inj hp

/-- A `keyOf`-encoded key decodes to exactly its type and key data. -/
theorem typeAndData_keyOf_eq {typ : Nat} (h : typ < 0xfd) {d : ByteArray}
    {t : Nat} {d' : ByteArray} (hd : typeAndData (keyOf typ d) = some (t, d')) :
    typ = t ∧ d = d' := by
  rw [typeAndData_keyOf typ h d] at hd
  injection hd with hp
  exact Prod.mk.inj hp

/-- Entries of a known global type never occur in the unknown list. -/
theorem entriesOfType_global_unknown_nil (typ : Nat) (u : List RawKV)
    (hu : GlobalUnknownOK u) (htyp : isKnownGlobalType typ = true) :
    entriesOfType typ u = [] := by
  apply entriesOfType_eq_nil_of_all_ne
  intro kv hkv t d hd
  obtain ⟨t', d', hd', hfalse, _⟩ := hu kv hkv
  obtain ⟨rfl, -⟩ := typeAndData_inj hd hd'
  intro ht
  rw [← ht] at htyp
  rw [hfalse] at htyp
  exact Bool.noConfusion htyp

/-- `entriesOfType` of a cons cell. -/
theorem entriesOfType_cons (typ : Nat) (kv : RawKV) (rest : List RawKV) :
    entriesOfType typ (kv :: rest)
      = entriesOfType typ [kv] ++ entriesOfType typ rest := by
  rw [show kv :: rest = [kv] ++ rest from rfl, entriesOfType_append]

/-- The unsigned transaction is the unique type-`0x00` global entry. -/
theorem entriesOfType_globalKVs_unsigned (g : Global) (hu : GlobalUnknownOK g.unknown) :
    entriesOfType GLOBAL_UNSIGNED_TX (globalKVs g)
      = [(ByteArray.empty, encodeTxNoWitness g.unsignedTx)] := by
  have hx : entriesOfType GLOBAL_UNSIGNED_TX
      (g.xpubs.map (fun x => (keyOf GLOBAL_XPUB x.xpub, encHDKeypathValue x.origin))) = [] :=
    entriesOfType_map_keyOf_ne GLOBAL_UNSIGNED_TX GLOBAL_XPUB (by decide) (by decide)
      g.xpubs (fun x => x.xpub) (fun x => encHDKeypathValue x.origin)
  have hunk := entriesOfType_global_unknown_nil GLOBAL_UNSIGNED_TX g.unknown hu (by decide)
  unfold globalKVs
  rw [entriesOfType_cons]
  have hsingle : entriesOfType GLOBAL_UNSIGNED_TX
      [(keyOf GLOBAL_UNSIGNED_TX ByteArray.empty, encodeTxNoWitness g.unsignedTx)]
      = [(ByteArray.empty, encodeTxNoWitness g.unsignedTx)] := by
    simpa [kvData] using entriesOfType_keyOf_same GLOBAL_UNSIGNED_TX (by decide)
      ByteArray.empty (encodeTxNoWitness g.unsignedTx)
  rw [hsingle, entriesOfType_append, hx, hunk]
  simp

/-- The global xpub entries, in wire order. -/
theorem entriesOfType_globalKVs_xpubs (g : Global) (hu : GlobalUnknownOK g.unknown) :
    entriesOfType GLOBAL_XPUB (globalKVs g)
      = g.xpubs.map (fun x => (x.xpub, encHDKeypathValue x.origin)) := by
  have hsingle : entriesOfType GLOBAL_XPUB
      [(keyOf GLOBAL_UNSIGNED_TX ByteArray.empty, encodeTxNoWitness g.unsignedTx)] = [] :=
    entriesOfType_keyOf_ne GLOBAL_XPUB GLOBAL_UNSIGNED_TX (by decide) (by decide)
      ByteArray.empty (encodeTxNoWitness g.unsignedTx)
  have hunk := entriesOfType_global_unknown_nil GLOBAL_XPUB g.unknown hu (by decide)
  unfold globalKVs
  rw [entriesOfType_cons, hsingle, entriesOfType_append]
  rw [entriesOfType_map_keyOf_same GLOBAL_XPUB (by decide)]
  rw [hunk]
  simp

/-- The encoder never emits `PSBT_GLOBAL_VERSION`. -/
theorem entriesOfType_globalKVs_version (g : Global) (hu : GlobalUnknownOK g.unknown) :
    entriesOfType GLOBAL_VERSION (globalKVs g) = [] := by
  have hsingle : entriesOfType GLOBAL_VERSION
      [(keyOf GLOBAL_UNSIGNED_TX ByteArray.empty, encodeTxNoWitness g.unsignedTx)] = [] :=
    entriesOfType_keyOf_ne GLOBAL_VERSION GLOBAL_UNSIGNED_TX (by decide) (by decide)
      ByteArray.empty (encodeTxNoWitness g.unsignedTx)
  have hx : entriesOfType GLOBAL_VERSION
      (g.xpubs.map (fun x => (keyOf GLOBAL_XPUB x.xpub, encHDKeypathValue x.origin))) = [] :=
    entriesOfType_map_keyOf_ne GLOBAL_VERSION GLOBAL_XPUB (by decide) (by decide)
      g.xpubs (fun x => x.xpub) (fun x => encHDKeypathValue x.origin)
  have hunk := entriesOfType_global_unknown_nil GLOBAL_VERSION g.unknown hu (by decide)
  unfold globalKVs
  rw [entriesOfType_cons, hsingle, entriesOfType_append, hx, hunk]
  simp

/-- Unfolding equation for `rejectGlobalV2` on a cons cell. -/
theorem rejectGlobalV2_cons (kv : RawKV) (rest : List RawKV) :
    rejectGlobalV2 (kv :: rest)
      = (match typeAndData kv.1 with
         | some (t, _) =>
           if t = GLOBAL_TX_VERSION || t = GLOBAL_FALLBACK_LOCKTIME
              || t = GLOBAL_INPUT_COUNT || t = GLOBAL_OUTPUT_COUNT
              || t = GLOBAL_TX_MODIFIABLE then
             .error (.v2FieldInV0 t)
           else rejectGlobalV2 rest
         | none => .ok ()) := rfl

/-- A global type that the v0 decoder's v2 check does not reject. -/
def NotV2 (t : Nat) : Prop :=
  t ≠ GLOBAL_TX_VERSION ∧ t ≠ GLOBAL_FALLBACK_LOCKTIME
  ∧ t ≠ GLOBAL_INPUT_COUNT ∧ t ≠ GLOBAL_OUTPUT_COUNT
  ∧ t ≠ GLOBAL_TX_MODIFIABLE

/-- The decoder's v0 rejection of the v2 global types succeeds on every
encoded global map whose unknown entries avoid those types. -/
theorem rejectGlobalV2_globalKVs (g : Global) (hu : GlobalUnknownOK g.unknown) :
    rejectGlobalV2 (globalKVs g) = .ok () := by
  have hrest : ∀ kvs : List RawKV,
      (∀ kv ∈ kvs, ∀ (t : Nat) (d : ByteArray),
        typeAndData kv.1 = some (t, d) → NotV2 t) →
      rejectGlobalV2 kvs = .ok () := by
    intro kvs
    induction kvs with
    | nil => intro _; rfl
    | cons kv rest ih =>
      intro h
      unfold rejectGlobalV2
      cases hd : typeAndData kv.1 with
      | none =>
        simp only [hd]
      | some p =>
        obtain ⟨t, d⟩ := p
        obtain ⟨h2, h3, h4, h5, h6⟩ := h kv (by simp) t d hd
        simp only [hd]
        rw [if_neg (by simp [h2, h3, h4, h5, h6])]
        exact ih (by
          intro x hx t' d' ht'
          exact h x (List.mem_cons_of_mem _ hx) t' d' ht')
  -- a decodable, v2-free prefix does not change the verdict on the suffix
  have happ : ∀ (a b : List RawKV),
      (∀ kv ∈ a, ∃ (t : Nat) (d : ByteArray),
        typeAndData kv.1 = some (t, d) ∧ NotV2 t) →
      rejectGlobalV2 (a ++ b) = rejectGlobalV2 b := by
    intro a
    induction a with
    | nil => intro b _; rfl
    | cons kv rest ih =>
      intro b h
      obtain ⟨t, d, hd, hv⟩ := h kv (by simp)
      obtain ⟨h2, h3, h4, h5, h6⟩ := hv
      rw [List.cons_append, rejectGlobalV2_cons]
      simp only [hd]
      rw [if_neg (by simp [h2, h3, h4, h5, h6])]
      exact ih b (fun x hx => h x (List.mem_cons_of_mem _ hx))
  have havSingle : ∀ kv ∈ [(keyOf GLOBAL_UNSIGNED_TX ByteArray.empty,
        encodeTxNoWitness g.unsignedTx)],
      ∃ (t : Nat) (d : ByteArray), typeAndData kv.1 = some (t, d) ∧ NotV2 t := by
    intro kv hkv
    simp only [List.mem_singleton] at hkv
    rw [hkv]
    exact ⟨GLOBAL_UNSIGNED_TX, ByteArray.empty,
      typeAndData_keyOf GLOBAL_UNSIGNED_TX (by decide) ByteArray.empty,
      by decide, by decide, by decide, by decide, by decide⟩
  have havXpubs : ∀ kv ∈ g.xpubs.map
        (fun x => (keyOf GLOBAL_XPUB x.xpub, encHDKeypathValue x.origin)),
      ∃ (t : Nat) (d : ByteArray), typeAndData kv.1 = some (t, d) ∧ NotV2 t := by
    intro kv hkv
    rcases List.mem_map.mp hkv with ⟨x, _, hxk⟩
    rw [← hxk]
    exact ⟨GLOBAL_XPUB, x.xpub,
      typeAndData_keyOf GLOBAL_XPUB (by decide) x.xpub,
      by decide, by decide, by decide, by decide, by decide⟩
  have havUnk : ∀ kv ∈ g.unknown,
      ∃ (t : Nat) (d : ByteArray), typeAndData kv.1 = some (t, d) ∧ NotV2 t := by
    intro kv hkv
    obtain ⟨t, d, hd, _, h2, h3, h4, h5, h6⟩ := hu kv hkv
    exact ⟨t, d, hd, h2, h3, h4, h5, h6⟩
  unfold globalKVs
  change rejectGlobalV2
    ([(keyOf GLOBAL_UNSIGNED_TX ByteArray.empty, encodeTxNoWitness g.unsignedTx)]
      ++ (g.xpubs.map (fun x => (keyOf GLOBAL_XPUB x.xpub, encHDKeypathValue x.origin))
          ++ g.unknown)) = .ok ()
  rw [happ _ _ havSingle, happ _ _ havXpubs]
  apply hrest
  intro kv hkv t d hd
  obtain ⟨t', d', hd', hv⟩ := havUnk kv hkv
  obtain ⟨rfl, -⟩ := typeAndData_inj hd hd'
  exact hv

/-- The global single-key fields (`0x00`, `0xFB`) carry empty key data on
every encoded global map. -/
theorem checkSingleKeyData_globalKVs (g : Global) (hu : GlobalUnknownOK g.unknown) :
    checkSingleKeyData
      [(GLOBAL_UNSIGNED_TX, "global unsigned tx"),
       (GLOBAL_VERSION, "global version")] (globalKVs g) = .ok () := by
  have hgen : ∀ kvs : List RawKV,
      (∀ kv ∈ kvs, ∀ (t : Nat) (d : ByteArray),
        typeAndData kv.1 = some (t, d) →
        (singleFieldName
          [(GLOBAL_UNSIGNED_TX, "global unsigned tx"),
           (GLOBAL_VERSION, "global version")] t).isSome = true →
        d.isEmpty = true) →
      checkSingleKeyData
        [(GLOBAL_UNSIGNED_TX, "global unsigned tx"),
         (GLOBAL_VERSION, "global version")] kvs = .ok () := by
    intro kvs
    induction kvs with
    | nil => intro _; rfl
    | cons kv rest ih =>
      intro h
      unfold checkSingleKeyData
      cases hd : typeAndData kv.1 with
      | none =>
        simp only [hd]
        exact ih (by
          intro x hx t' d' ht'
          exact h x (List.mem_cons_of_mem _ hx) t' d' ht')
      | some p =>
        obtain ⟨t, d⟩ := p
        cases hf : singleFieldName
            [(GLOBAL_UNSIGNED_TX, "global unsigned tx"),
             (GLOBAL_VERSION, "global version")] t with
        | none =>
          simp only [hd, hf]
          exact ih (by
            intro x hx t' d' ht'
            exact h x (List.mem_cons_of_mem _ hx) t' d' ht')
        | some name =>
          have hde : d.isEmpty = true := h kv (by simp) t d hd (by simp [hf])
          simp only [hd, hf, hde]
          exact ih (by
            intro x hx t' d' ht'
            exact h x (List.mem_cons_of_mem _ hx) t' d' ht')
  apply hgen
  intro kv hkv t d hd hsingle
  simp only [globalKVs, List.mem_cons, List.mem_append, List.mem_map] at hkv
  rcases hkv with rfl | ⟨x, hx, hxk⟩ | hu'
  · obtain ⟨rfl, hdv⟩ := typeAndData_keyOf_eq (by decide) hd
    subst hdv
    rfl
  · rw [← hxk] at hd
    obtain ⟨rfl, -⟩ := typeAndData_keyOf_eq (by decide) hd
    have hnone : singleFieldName
        [(GLOBAL_UNSIGNED_TX, "global unsigned tx"),
         (GLOBAL_VERSION, "global version")] GLOBAL_XPUB = none := by decide
    rw [hnone] at hsingle
    simp at hsingle
  · obtain ⟨t', d', hd', hfalse, _⟩ := hu kv hu'
    obtain ⟨rfl, -⟩ := typeAndData_inj hd hd'
    obtain ⟨h0, h1, hv⟩ := (isKnownGlobalType_false_iff t).mp hfalse
    have hf : singleFieldName
        [(GLOBAL_UNSIGNED_TX, "global unsigned tx"),
         (GLOBAL_VERSION, "global version")] t = none := by
      simp [singleFieldName, Ne.symm h0, Ne.symm hv]
    rw [hf] at hsingle
    simp at hsingle

/-- `PSBT_GLOBAL_VERSION` is absent from an encoded global map, so the v0
version check accepts it. -/
theorem checkGlobalVersion_globalKVs (g : Global) (hu : GlobalUnknownOK g.unknown) :
    checkGlobalVersion (globalKVs g) = .ok () := by
  unfold checkGlobalVersion
  rw [show valueOfType GLOBAL_VERSION (globalKVs g) = none from by
    unfold valueOfType
    rw [entriesOfType_globalKVs_version g hu]
    rfl]

/-- **PSBT-001.** A stream whose first five bytes differ from the magic
`psbt\xff` is rejected with `badMagic`. -/
@[walletRule "PSBT-001"]
theorem decode_badMagic (b : ByteArray) (h : (bL b).take 5 ≠ magicBytes) :
    decode b = .error .badMagic := by
  unfold decode
  dsimp only
  rw [if_neg h]

/-- **PSBT-005.** A global map without `PSBT_GLOBAL_UNSIGNED_TX` is
rejected (with `missingUnsignedTx` once the preceding checks pass, and
with their error otherwise). -/
@[walletRule "PSBT-005"]
theorem parseGlobal_missingUnsignedTx (kvs : List RawKV)
    (h : valueOfType GLOBAL_UNSIGNED_TX kvs = none) :
    ∀ g, parseGlobal kvs ≠ .ok g := by
  intro g hok
  unfold parseGlobal at hok
  rw [h] at hok
  cases hr : rejectGlobalV2 kvs with
  | error e => rw [hr] at hok; simp at hok
  | ok u =>
    rw [hr] at hok
    simp only [bindE_ok] at hok
    cases hc : checkSingleKeyData
        [(GLOBAL_UNSIGNED_TX, "global unsigned tx"),
         (GLOBAL_VERSION, "global version")] kvs with
    | error e => rw [hc] at hok; simp at hok
    | ok u =>
      rw [hc] at hok
      simp only [bindE_ok] at hok
      cases hv : checkGlobalVersion kvs with
      | error e => rw [hv] at hok; simp at hok
      | ok u => rw [hv] at hok; simp at hok

/-- `checkKeyEncoding` accepts a list whose keys all decode to a type and
key data (the check only asks for decodability). -/
theorem checkKeyEncoding_decodable (kvs : List RawKV)
    (h : ∀ kv ∈ kvs, ∃ (t : Nat) (d : ByteArray), typeAndData kv.1 = some (t, d)) :
    checkKeyEncoding kvs = .ok () := by
  induction kvs with
  | nil => rfl
  | cons kv rest ih =>
    obtain ⟨t, d, hd⟩ := h kv (by simp)
    simp only [checkKeyEncoding, hd]
    exact ih (fun x hx => h x (List.mem_cons_of_mem _ hx))

/-- The strict key order component of `canonicalMap`. -/
theorem canonicalMap_strictlySorted {kvs : List RawKV}
    (h : canonicalMap kvs = true) : strictlySorted kvs = true := by
  have h' := h
  simp only [canonicalMap, Bool.and_eq_true_iff] at h'
  exact h'.2

/-- `decMapL` consumes exactly one map from a longer byte string. -/
theorem decMapL_encMapL_append (kvs : List RawKV) (rest : Bytes)
    (h : MapWireOK kvs) : decMapL (encMapL kvs ++ rest) = .ok (kvs, rest) := by
  unfold decMapL
  have hlen : kvs.length + 1 ≤ (encMapL kvs ++ rest).length := by
    rw [List.length_append]
    have hb := encMapBodyL_length kvs
    simp only [encMapL, List.length_append, List.length_cons, List.length_nil]
    omega
  have hgo := decMapGo_encMapBodyL kvs (encMapL kvs ++ rest).length rest hlen h
  simpa [encMapL, List.append_assoc] using hgo

/-- `decMapChecked` consumes exactly one checked map from a longer byte
string when the map is canonical and all its keys are decodable. -/
theorem decMapChecked_encMapL_append (kvs : List RawKV) (rest : Bytes)
    (hmap : canonicalMap kvs = true)
    (hkeys : ∀ kv ∈ kvs, ∃ (t : Nat) (d : ByteArray), typeAndData kv.1 = some (t, d)) :
    decMapChecked (encMapL kvs ++ rest) = .ok (kvs, rest) := by
  unfold decMapChecked
  rw [decMapL_encMapL_append kvs rest (canonicalMap_mapWireOK hmap)]
  simp only [bindE_ok]
  rw [checkKeyEncoding_decodable kvs hkeys]
  simp only [bindE_ok]
  rw [findDuplicate_eq_none_of_strictlySorted kvs (canonicalMap_strictlySorted hmap)]

/-- A complete map encoding is never empty. -/
theorem encMapL_ne_nil (kvs : List RawKV) : encMapL kvs ≠ [] := by
  simp [encMapL]

/-- Decoding `n` consecutive maps inverts their concatenated encodings,
leaving the trailing bytes. -/
theorem decNMaps_flatMap (ms : List (List RawKV)) (rest : Bytes)
    (hcan : ∀ m ∈ ms, canonicalMap m = true)
    (hkeys : ∀ m ∈ ms, ∀ kv ∈ m,
      ∃ (t : Nat) (d : ByteArray), typeAndData kv.1 = some (t, d)) :
    decNMaps ms.length (ms.flatMap encMapL ++ rest) = .ok (ms, rest) := by
  induction ms generalizing rest with
  | nil =>
    rw [List.length_nil, List.flatMap_nil]
    exact decNMaps.eq_1 rest
  | cons m ms ih =>
    rw [List.length_cons, List.flatMap_cons, List.append_assoc]
    have hne : encMapL m ++ (ms.flatMap encMapL ++ rest) ≠ [] := by
      intro hh
      exact encMapL_ne_nil m (List.append_eq_nil_iff.mp hh).1
    rw [decNMaps.eq_3 _ ms.length hne]
    rw [decMapChecked_encMapL_append m _ (hcan m (by simp)) (hkeys m (by simp))]
    simp only [bindE_ok]
    rw [ih rest (fun x hx => hcan x (List.mem_cons_of_mem _ hx))
      (fun x hx => hkeys x (List.mem_cons_of_mem _ hx))]
    rfl

/-- The decoder's local input-map loop inverts a list of maps. -/
theorem parseIns_map (ms : List (List RawKV)) (ins : List PsbtInput)
    (hlen : ms.length = ins.length)
    (h : ∀ (m : List RawKV) (i : PsbtInput), (m, i) ∈ ms.zip ins →
      parseInput m = .ok i) :
    decode.parseIns ms = .ok ins := by
  induction ms generalizing ins with
  | nil =>
    cases ins with
    | nil => exact decode.parseIns.eq_1
    | cons _ _ => simp at hlen
  | cons m ms ih =>
    cases ins with
    | nil => simp at hlen
    | cons i ins =>
      rw [decode.parseIns.eq_2]
      have hm : parseInput m = .ok i := h m i (by simp)
      rw [hm]
      simp only [bindE_ok]
      rw [ih ins (by simpa using hlen) (fun m' i' hmem => h m' i' (by simp [hmem]))]
      rfl

/-- The decoder's local output-map loop inverts a list of maps. -/
theorem parseOuts_map (ms : List (List RawKV)) (outs : List PsbtOutput)
    (hlen : ms.length = outs.length)
    (h : ∀ (m : List RawKV) (o : PsbtOutput), (m, o) ∈ ms.zip outs →
      parseOutput m = .ok o) :
    decode.parseOuts ms = .ok outs := by
  induction ms generalizing outs with
  | nil =>
    cases outs with
    | nil => exact decode.parseOuts.eq_1
    | cons _ _ => simp at hlen
  | cons m ms ih =>
    cases outs with
    | nil => simp at hlen
    | cons o outs =>
      rw [decode.parseOuts.eq_2]
      have hm : parseOutput m = .ok o := h m o (by simp)
      rw [hm]
      simp only [bindE_ok]
      rw [ih outs (by simpa using hlen) (fun m' o' hmem => h m' o' (by simp [hmem]))]
      rfl

/-- The global unsigned transaction is the first entry the encoder emits. -/
theorem valueOfType_globalKVs_unsigned (g : Global) (hu : GlobalUnknownOK g.unknown) :
    valueOfType GLOBAL_UNSIGNED_TX (globalKVs g) = some (encodeTxNoWitness g.unsignedTx) := by
  unfold valueOfType
  rw [entriesOfType_globalKVs_unsigned g hu]
  rfl

/-- The decoder's `checkSigs` local loop accepts a transaction whose
scriptSigs are all empty. -/
theorem checkSigs_ok (l : List TxIn)
    (h : ∀ i ∈ l, i.scriptSig.bytes.isEmpty = true) :
    ∀ k, parseGlobal.checkSigs k l = .ok () := by
  induction l with
  | nil => intro k; exact parseGlobal.checkSigs.eq_1 k
  | cons ti rest ih =>
    intro k
    rw [parseGlobal.checkSigs.eq_2]
    rw [if_pos (h ti (by simp))]
    exact ih (fun x hx => h x (List.mem_cons_of_mem _ hx)) (k + 1)

/-- The decoder's `xpubs` local loop inverts the encoder's xpub group. -/
theorem parseGlobal_xpubs_map (l : List XpubEntry)
    (h : ∀ x ∈ l, x.xpub.size = 78 ∧ x.origin.fingerprint.size = 4) :
    parseGlobal.xpubs (l.map (fun x => (x.xpub, encHDKeypathValue x.origin))) = .ok l := by
  induction l with
  | nil => rw [List.map_nil]; exact parseGlobal.xpubs.eq_1
  | cons x rest ih =>
    rw [List.map_cons, parseGlobal.xpubs.eq_2]
    obtain ⟨hsz, hfp⟩ := h x (by simp)
    rw [if_pos hsz]
    rw [parseHDKeypath_enc "global xpub" x.origin hfp]
    simp only [bindE_ok]
    rw [ih (fun y hy => h y (List.mem_cons_of_mem _ hy))]
    rfl

/-- The global-unknown filter returns exactly the model's unknown list. -/
theorem filter_globalKVs_unknown (g : Global) (hu : GlobalUnknownOK g.unknown) :
    (globalKVs g).filter (fun kv =>
      match typeAndData kv.1 with
      | some (t, _) => !isKnownGlobalType t
      | none => false) = g.unknown := by
  have hxpub (x : XpubEntry) :
      (match typeAndData (keyOf GLOBAL_XPUB x.xpub) with
       | some (t, _) => !isKnownGlobalType t
       | none => false) = false := by
    rw [typeAndData_keyOf GLOBAL_XPUB (by decide) x.xpub]
    simp [isKnownGlobalType]
  have huns :
      (match typeAndData (keyOf GLOBAL_UNSIGNED_TX ByteArray.empty) with
       | some (t, _) => !isKnownGlobalType t
       | none => false) = false := by
    rw [typeAndData_keyOf GLOBAL_UNSIGNED_TX (by decide) ByteArray.empty]
    simp [isKnownGlobalType]
  have hunk : ∀ kv ∈ g.unknown,
      (match typeAndData kv.1 with
       | some (t, _) => !isKnownGlobalType t
       | none => false) = true := by
    intro kv hkv
    obtain ⟨t, d, hd, hfalse, _⟩ := hu kv hkv
    rw [hd]
    simp [hfalse]
  unfold globalKVs
  rw [List.filter_cons_of_neg (by rw [huns]; simp)]
  rw [List.filter_append]
  rw [show List.filter _ (g.xpubs.map (fun x => (keyOf GLOBAL_XPUB x.xpub, encHDKeypathValue x.origin)))
        = [] from by
    rw [List.filter_eq_nil_iff]
    intro kv hkv
    rcases List.mem_map.mp hkv with ⟨x, _, hxk⟩
    rw [← hxk]
    simp [typeAndData_keyOf GLOBAL_XPUB (by decide) x.xpub]
    decide]
  rw [List.nil_append]
  exact List.filter_eq_self.mpr hunk

/-- `parseGlobal` recovers the model from the encoder's global map,
provided the unsigned transaction is in the wire domain and witness-free,
its scriptSigs are empty, and the xpub records have their wire lengths. -/
theorem parseGlobal_globalKVs (g : Global) (hu : GlobalUnknownOK g.unknown)
    (htx : wireDomain g.unsignedTx) (hnw : hasWitness g.unsignedTx = false)
    (hsigs : ∀ i ∈ g.unsignedTx.vin, i.scriptSig.bytes.isEmpty = true)
    (hxp : ∀ x ∈ g.xpubs, x.xpub.size = 78 ∧ x.origin.fingerprint.size = 4) :
    parseGlobal (globalKVs g) = .ok g := by
  unfold parseGlobal
  rw [rejectGlobalV2_globalKVs g hu]
  simp only [bindE_ok]
  rw [checkSingleKeyData_globalKVs g hu]
  simp only [bindE_ok]
  rw [checkGlobalVersion_globalKVs g hu]
  simp only [bindE_ok]
  rw [valueOfType_globalKVs_unsigned g hu]
  simp only [bindE_ok]
  rw [parseTxValue_enc g.unsignedTx htx hnw]
  simp only [bindE_ok]
  rw [hnw]
  simp only [Bool.false_eq_true, if_false]
  rw [checkSigs_ok g.unsignedTx.vin hsigs 0]
  simp only [bindE_ok]
  rw [entriesOfType_globalKVs_xpubs g hu]
  rw [parseGlobal_xpubs_map g.xpubs hxp]
  simp only [bindE_ok]
  apply congrArg Except.ok
  cases g with
  | mk tx xp u =>
    change GlobalUnknownOK u at hu
    change (⟨tx, xp, List.filter (fun kv =>
      match typeAndData kv.1 with
      | some (t, _) => !isKnownGlobalType t
      | none => false) (globalKVs ⟨tx, xp, u⟩)⟩ : Global) = ⟨tx, xp, u⟩
    exact congrArg (Global.mk tx xp) (filter_globalKVs_unknown (g := ⟨tx, xp, u⟩) hu)

/-- The `canonicalMap` facts carried by `Canonical`. -/
theorem canonicalMap_of_canonicalB {p : Psbt} (h : Canonical p) :
    canonicalMap (globalKVs p.global) = true
    ∧ (∀ i ∈ p.inputs, canonicalMap (inputKVs i) = true)
    ∧ (∀ o ∈ p.outputs, canonicalMap (outputKVs o) = true) := by
  have h' := h
  unfold Canonical canonicalB at h'
  simp only [Bool.and_eq_true_iff] at h'
  obtain ⟨⟨⟨_, hg⟩, hi⟩, ho⟩ := h'
  refine ⟨hg, ?_, ?_⟩
  · intro i hi'
    have hail := (List.all_eq_true.mp hi) i hi'
    have hci := hail
    simp only [inputCanonical, Bool.and_eq_true_iff] at hci
    exact hci.2
  · intro o ho'
    have hall := (List.all_eq_true.mp ho) o ho'
    have hco := hall
    simp only [outputCanonical, Bool.and_eq_true_iff] at hco
    exact hco.2

/-- The local input-map loop, in the form needed for `encode p`: the
maps are exactly the projections of the model's input list. -/
theorem parseIns_map_self {α : Type} (l : List α) (f : α → List RawKV)
    (g : α → PsbtInput)
    (h : ∀ a ∈ l, parseInput (f a) = .ok (g a)) :
    decode.parseIns (l.map f) = .ok (l.map g) := by
  induction l with
  | nil => rw [List.map_nil]; exact decode.parseIns.eq_1
  | cons a l ih =>
    rw [List.map_cons, decode.parseIns.eq_2, h a (by simp)]
    simp only [bindE_ok]
    rw [ih (fun b hb => h b (List.mem_cons_of_mem _ hb))]
    rfl

/-- The local output-map loop, in the form needed for `encode p`. -/
theorem parseOuts_map_self {α : Type} (l : List α) (f : α → List RawKV)
    (g : α → PsbtOutput)
    (h : ∀ a ∈ l, parseOutput (f a) = .ok (g a)) :
    decode.parseOuts (l.map f) = .ok (l.map g) := by
  induction l with
  | nil => rw [List.map_nil]; exact decode.parseOuts.eq_1
  | cons a l ih =>
    rw [List.map_cons, decode.parseOuts.eq_2, h a (by simp)]
    simp only [bindE_ok]
    rw [ih (fun b hb => h b (List.mem_cons_of_mem _ hb))]
    rfl

/-
Counterexamples to `decode ∘ encode = id` on `Canonical` alone:

* a global/input/output `unknown` key with an un-decodable CompactSize
  prefix (for example key bytes `#[0xfd, 0x00]`): `canonicalMap` accepts
  the entry, but `decMapChecked` rejects it with `badKeyEncoding`;
* an `unknown` entry whose key type is known (for example an extra
  `PSBT_IN_PARTIAL_SIG` pair not in `partialSigs`): the decoder folds it
  into the typed field or rejects it, so it is not preserved as unknown;
* an xpub record with key data of length other than 78: `parseGlobal`
  rejects it with `badKeyDataSize`;
* partial-signature or BIP32 key data of length other than 33/65, an
  empty partial signature, or a taproot signature whose size is not
  64/65: `parseInput` rejects it;
* a zero-input unsigned transaction: `wireDomain` requires
  `0 < vin.length`, and `decTxCore` reads a zero vin count as the SegWit
  dummy, so `parseTxValue` does not return the original transaction;
* a taproot leaf version at least 256: `encTapLeafValue` writes
  `leafVersion.toUInt8`, so decoding recovers the low byte, not the
  original `Nat`.

These are prose counterexamples, not separately mechanised declarations.
-/
/-- A stronger encoder-side domain on which `decode ∘ encode` is the
identity: canonical maps whose keys decode, whose typed maps parse back
to the model, and whose non-witness-UTXO consistency check succeeds.

`Canonical` alone is not enough: it permits unknown entries whose key
type is not decodable and unknown entries of a *known* type (which the
decoder would fold into the typed fields), and it does not bound the
value parsers' domains (transaction `wireDomain`, 78-byte xpubs, pubkey
and signature lengths, taproot leaf versions below 256, ...).  Those
obligations are made explicit here rather than hidden in the law. -/
def WireCanonical (p : Psbt) : Prop :=
  Canonical p
  ∧ (∀ kv ∈ globalKVs p.global,
      ∃ (t : Nat) (d : ByteArray), typeAndData kv.1 = some (t, d))
  ∧ (∀ i ∈ p.inputs, ∀ kv ∈ inputKVs i,
      ∃ (t : Nat) (d : ByteArray), typeAndData kv.1 = some (t, d))
  ∧ (∀ o ∈ p.outputs, ∀ kv ∈ outputKVs o,
      ∃ (t : Nat) (d : ByteArray), typeAndData kv.1 = some (t, d))
  ∧ parseGlobal (globalKVs p.global) = .ok p.global
  ∧ (∀ i ∈ p.inputs, parseInput (inputKVs i) = .ok i)
  ∧ (∀ o ∈ p.outputs, parseOutput (outputKVs o) = .ok o)
  ∧ checkUtxos p.global.unsignedTx 0 p.inputs = .ok ()
  ∧ p.inputs.length = p.global.unsignedTx.vin.length
  ∧ p.outputs.length = p.global.unsignedTx.vout.length

/-- Decoding the canonical encoding of a `WireCanonical` PSBT recovers
the model exactly.  This is the proved form of `decodeEncodeTarget`; the
unrestricted statement is false (see the report and `Lifecycle.lean`). -/
theorem decode_encode_wire (p : Psbt) (h : WireCanonical p) :
    decode (encode p) = .ok p := by
  obtain ⟨hcan, hkeysG, hkeysI, hkeysO, hparseG, hparseI, hparseO,
    hcheck, hlenI, hlenO⟩ := h
  obtain ⟨hg, hi, ho⟩ := canonicalMap_of_canonicalB hcan
  have hsortG : sortKVs (globalKVs p.global) = globalKVs p.global :=
    sortKVs_eq_self _ (canonicalMap_strictlySorted hg)
  have hsortI : ∀ i ∈ p.inputs, sortKVs (inputKVs i) = inputKVs i :=
    fun i hi' => sortKVs_eq_self _ (canonicalMap_strictlySorted (hi i hi'))
  have hsortO : ∀ o ∈ p.outputs, sortKVs (outputKVs o) = outputKVs o :=
    fun o ho' => sortKVs_eq_self _ (canonicalMap_strictlySorted (ho o ho'))
  have hcanI : ∀ m ∈ p.inputs.map (fun i => sortKVs (inputKVs i)),
      canonicalMap m = true := by
    intro m hm
    rcases List.mem_map.mp hm with ⟨i, hi', rfl⟩
    rw [hsortI i hi']
    exact hi i hi'
  have hcanO : ∀ m ∈ p.outputs.map (fun o => sortKVs (outputKVs o)),
      canonicalMap m = true := by
    intro m hm
    rcases List.mem_map.mp hm with ⟨o, ho', rfl⟩
    rw [hsortO o ho']
    exact ho o ho'
  have hkeysIS : ∀ m ∈ p.inputs.map (fun i => sortKVs (inputKVs i)),
      ∀ kv ∈ m, ∃ (t : Nat) (d : ByteArray), typeAndData kv.1 = some (t, d) := by
    intro m hm kv hkv
    rcases List.mem_map.mp hm with ⟨i, hi', rfl⟩
    rw [hsortI i hi'] at hkv
    exact hkeysI i hi' kv hkv
  have hkeysOS : ∀ m ∈ p.outputs.map (fun o => sortKVs (outputKVs o)),
      ∀ kv ∈ m, ∃ (t : Nat) (d : ByteArray), typeAndData kv.1 = some (t, d) := by
    intro m hm kv hkv
    rcases List.mem_map.mp hm with ⟨o, ho', rfl⟩
    rw [hsortO o ho'] at hkv
    exact hkeysO o ho' kv hkv
  have henc : bL (encode p) = magicBytes ++
      (encMapL (sortKVs (globalKVs p.global))
        ++ (p.inputs.flatMap (fun i => encMapL (sortKVs (inputKVs i)))
          ++ p.outputs.flatMap (fun o => encMapL (sortKVs (outputKVs o))))) := by
    unfold encode
    rw [bL_bytesOfList]
    simp only [List.append_assoc]
  -- the encoder's three segments, in the order the decoder reads them
  let iFlat := p.inputs.flatMap (fun i => encMapL (sortKVs (inputKVs i)))
  let oFlat := p.outputs.flatMap (fun o => encMapL (sortKVs (outputKVs o)))
  have henc' : bL (encode p) = magicBytes ++
      (encMapL (sortKVs (globalKVs p.global)) ++ (iFlat ++ oFlat)) := by
    rw [henc]
  unfold decode
  dsimp only
  rw [henc']
  rw [show List.take 5 (magicBytes ++
      (encMapL (sortKVs (globalKVs p.global)) ++ (iFlat ++ oFlat))) = magicBytes from by
    rw [show 5 = magicBytes.length from rfl, List.take_left]]
  rw [show List.drop 5 (magicBytes ++
      (encMapL (sortKVs (globalKVs p.global)) ++ (iFlat ++ oFlat)))
      = encMapL (sortKVs (globalKVs p.global)) ++ (iFlat ++ oFlat) from by
    rw [show 5 = magicBytes.length from rfl, List.drop_left]]
  simp only [if_pos rfl]
  rw [hsortG]
  rw [decMapChecked_encMapL_append (globalKVs p.global) (iFlat ++ oFlat) hg hkeysG]
  simp only [bindE_ok]
  rw [hparseG]
  simp only [bindE_ok]
  rw [← hlenI]
  dsimp only [iFlat, oFlat]
  rw [← List.flatMap_map (f := fun i => sortKVs (inputKVs i))]
  rw [← List.length_map (f := fun i => sortKVs (inputKVs i))]
  rw [decNMaps_flatMap (p.inputs.map (fun i => sortKVs (inputKVs i)))
    (List.flatMap (fun o => encMapL (sortKVs (outputKVs o))) p.outputs) hcanI hkeysIS]
  simp only [bindE_ok]
  rw [List.map_congr_left (fun i hi' => hsortI i hi')]
  rw [← List.flatMap_map (f := fun o => sortKVs (outputKVs o))]
  rw [← hlenO]
  rw [← List.length_map (f := fun o => sortKVs (outputKVs o))]
  rw [show decNMaps (List.map (fun o => sortKVs (outputKVs o)) p.outputs).length
        (List.flatMap encMapL (List.map (fun o => sortKVs (outputKVs o)) p.outputs))
      = .ok (p.outputs.map (fun o => sortKVs (outputKVs o)), []) from by
    simpa using decNMaps_flatMap (p.outputs.map (fun o => sortKVs (outputKVs o)))
      [] hcanO hkeysOS]
  simp only [bindE_ok]
  rw [List.map_congr_left (fun o ho' => hsortO o ho')]
  rw [show decode.parseIns (p.inputs.map inputKVs) = .ok p.inputs from by
    simpa using parseIns_map_self p.inputs inputKVs id hparseI]
  simp only [bindE_ok]
  rw [show decode.parseOuts (p.outputs.map outputKVs) = .ok p.outputs from by
    simpa using parseOuts_map_self p.outputs outputKVs id hparseO]
  simp only [bindE_ok]
  rw [hcheck]
  rfl

end BitcoinProofs.Wallet.Psbt
