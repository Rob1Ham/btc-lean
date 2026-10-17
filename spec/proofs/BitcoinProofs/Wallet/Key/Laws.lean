import Bitcoin.Wallet.Key.Bip32
import Init.Omega

/-!
# BitcoinProofs.Wallet.Key.Laws

Structural laws of the wallet key layer over the executable model in
`Bitcoin.Wallet.Key.{Origin,Bip32}`.

Theorems here concern syntax and bookkeeping only.  They do not assert
anything about the cryptographic strength of HMAC-SHA-512, the group law
of secp256k1, or the secrecy of private key material.  Whenever a result
depends on the concrete value of `hmacSha512`, the statement says so.
-/

namespace BitcoinProofs.Wallet.Key

open Bitcoin.Wallet.Key

/-! ## Decimal rendering of a child number -/

/-- `Char.toNat` of the character spelled by a decimal digit. -/
theorem char_toNat_ofNat_add (n : Nat) (h : n < 10) :
    (Char.ofNat (48 + n)).toNat = 48 + n := by
  have hn : n ≤ 9 := Nat.le_of_lt_succ h
  have hle : 48 + n ≤ 57 := Nat.add_le_add_left hn 48
  have hlt : 48 + n < 55296 := Nat.lt_of_le_of_lt hle (by decide)
  have hvalid : (48 + n).isValidChar := Or.inl hlt
  simp [Char.ofNat, hvalid, Char.ofNatAux, Char.toNat,
    Nat.mod_eq_of_lt (Nat.lt_of_lt_of_le hlt (by decide : 55296 ≤ 2 ^ 32))]

/-- The character `'0' + n` is an ASCII decimal digit when `n < 10`. -/
theorem isAsciiDigit_char_ofNat_add (n : Nat) (h : n < 10) :
    isAsciiDigit (Char.ofNat (48 + n)) = true := by
  unfold isAsciiDigit
  rw [char_toNat_ofNat_add n h]
  have hn : n ≤ 9 := Nat.le_of_lt_succ h
  have h1 : 48 ≤ 48 + n := Nat.le_add_right 48 n
  have h2 : 48 + n ≤ 57 := Nat.add_le_add_left hn 48
  simp [h1, h2]

/-- Decimal digits of a natural number, most significant first.  The
recursion is on the value; the result is the canonical spelling with no
leading zeroes. -/
def natDigits (n : Nat) : List Char :=
  if h : n < 10 then
    [Char.ofNat (48 + n)]
  else
    natDigits (n / 10) ++ [Char.ofNat (48 + n % 10)]
termination_by n
decreasing_by
  exact Nat.div_lt_self
    (Nat.pos_of_ne_zero (by intro hz; subst hz; exact h (by decide)))
    (by decide)

/-- `natDigits` is nonempty. -/
theorem natDigits_ne_nil : ∀ n : Nat, natDigits n ≠ [] := by
  intro n
  refine Nat.strongRecOn n (fun n ih => ?_)
  unfold natDigits
  split
  · simp
  · rename_i hge
    have hlt : n / 10 < n := Nat.div_lt_self
      (Nat.pos_of_ne_zero (by intro hz; subst hz; exact hge (by decide)))
      (by decide)
    simp [ih (n / 10) hlt]

/-- Every character produced by `natDigits` is an ASCII decimal digit. -/
theorem natDigits_ascii : ∀ n : Nat, ∀ c ∈ natDigits n,
    isAsciiDigit c = true := by
  intro n
  refine Nat.strongRecOn n (fun n ih => ?_)
  unfold natDigits
  split
  · rename_i h
    intro c hc
    simp at hc
    subst hc
    exact isAsciiDigit_char_ofNat_add n h
  · rename_i hge
    intro c hc
    have hlt : n / 10 < n := Nat.div_lt_self
      (Nat.pos_of_ne_zero (by intro hz; subst hz; exact hge (by decide)))
      (by decide)
    have hmod : n % 10 < 10 := Nat.mod_lt n (by decide)
    simp at hc
    rcases hc with hc | hc
    · exact ih (n / 10) hlt c hc
    · subst hc
      exact isAsciiDigit_char_ofNat_add (n % 10) hmod

/-- Appending one decimal digit multiplies the accumulated value by ten
and adds the digit.  If an earlier character fails the test, both sides
are `none`. -/
theorem digitsValueAux_append_digit :
    ∀ (acc : Nat) (l : List Char) (c : Char),
      isAsciiDigit c = true →
      digitsValueAux acc (l ++ [c]) =
        (digitsValueAux acc l).map
          (fun v => v * 10 + (c.toNat - 48)) := by
  intro acc l
  revert acc
  induction l with
  | nil =>
    intro acc c hc
    show digitsValueAux acc [c] =
      (digitsValueAux acc []).map
        (fun v => v * 10 + (c.toNat - 48))
    simp [digitsValueAux, hc]
  | cons x xs ih =>
    intro acc c hc
    show digitsValueAux acc (x :: (xs ++ [c])) =
      (digitsValueAux acc (x :: xs)).map
        (fun v => v * 10 + (c.toNat - 48))
    unfold digitsValueAux
    split
    · exact ih (acc * 10 + (x.toNat - 48)) c hc
    · simp

/-- Reading back the decimal spelling recovers the number. -/
theorem digitsValueAux_natDigits : ∀ n : Nat,
    digitsValueAux 0 (natDigits n) = some n := by
  intro n
  refine Nat.strongRecOn n (fun n ih => ?_)
  unfold natDigits
  split
  · rename_i h
    have hn : n ≤ 9 := Nat.le_of_lt_succ h
    have h1 : 48 ≤ 48 + n := Nat.le_add_right 48 n
    have h2 : 48 + n ≤ 57 := Nat.add_le_add_left hn 48
    simp [digitsValueAux, isAsciiDigit, char_toNat_ofNat_add n h, h1, h2]
  · rename_i hge
    have hlt : n / 10 < n := Nat.div_lt_self
      (Nat.pos_of_ne_zero (by intro hz; subst hz; exact hge (by decide)))
      (by decide)
    have hrec := ih (n / 10) hlt
    have hmod : n % 10 < 10 := Nat.mod_lt n (by decide)
    have hascii := isAsciiDigit_char_ofNat_add (n % 10) hmod
    rw [digitsValueAux_append_digit 0 (natDigits (n / 10))
      (Char.ofNat (48 + n % 10)) hascii]
    rw [hrec]
    simp [char_toNat_ofNat_add (n % 10) hmod]
    exact Nat.div_add_mod' n 10

/-! ## Canonical rendering and the parser round-trip -/

/-- Characters of a canonical child-number spelling: decimal digits,
then `h` exactly for a hardened step. -/
def renderChildChars (c : ChildNumber) : List Char :=
  natDigits c.index ++ (if c.hardened then ['h'] else [])

/-- Canonical child-number spelling.  The grammar also accepts `'`, but
the printer always emits `h`, so the printed form is one representative
of each accepted equivalence class. -/
def renderChild (c : ChildNumber) : String :=
  String.ofList (renderChildChars c)

/-- Characters after the leading `m`: a slash then one component, for
each component. -/
def bodyChars : List ChildNumber → List Char
  | [] => []
  | [c] => renderChildChars c
  | c :: d :: cs => renderChildChars c ++ '/' :: bodyChars (d :: cs)

/-- Canonical full-path spelling.  `renderPath []` is the bare root `m`. -/
def renderPath : List ChildNumber → String
  | [] => "m"
  | p => "m/" ++ String.ofList (bodyChars p)

/-- The characters of `renderChild` are exactly `renderChildChars`. -/
theorem renderChild_toList (c : ChildNumber) :
    (renderChild c).toList = renderChildChars c :=
  String.toList_ofList

/-- The rendered component contains no slash. -/
theorem natDigits_no_slash : ∀ n : Nat, ∀ c ∈ natDigits n, c ≠ '/' := by
  intro n c hc heq
  have ha := natDigits_ascii n c hc
  subst heq
  unfold isAsciiDigit at ha
  have hb := of_decide_eq_true ha
  simp at hb

/-- The rendered component contains no apostrophe. -/
theorem natDigits_no_apostrophe : ∀ n : Nat, ∀ c ∈ natDigits n, c ≠ '\'' := by
  intro n c hc heq
  have ha := natDigits_ascii n c hc
  subst heq
  unfold isAsciiDigit at ha
  have hb := of_decide_eq_true ha
  simp at hb

/-- The rendered component contains no `h`. -/
theorem natDigits_no_h : ∀ n : Nat, ∀ c ∈ natDigits n, c ≠ 'h' := by
  intro n c hc heq
  have ha := natDigits_ascii n c hc
  subst heq
  unfold isAsciiDigit at ha
  have hb := of_decide_eq_true ha
  simp at hb

/-- No rendered component contains a slash. -/
theorem renderChildChars_no_slash (c : ChildNumber) :
    ∀ x ∈ renderChildChars c, x ≠ '/' := by
  intro x hx
  unfold renderChildChars at hx
  rw [List.mem_append] at hx
  rcases hx with hx | hx
  · exact natDigits_no_slash c.index x hx
  · split at hx
    · simp at hx
      subst hx
      decide
    · simp at hx

/-- A character returned by `getLast?` is a member. -/
theorem mem_of_getLast?_eq_some {l : List Char} {c : Char}
    (h : l.getLast? = some c) : c ∈ l := by
  have hne : l ≠ [] := by intro he; subst he; simp at h
  rw [List.getLast?_eq_some_getLast hne] at h
  injection h with hc
  subst hc
  exact List.getLast_mem hne

/-- The parsed body of a rendered component is its digit spelling, and
the hardened marker is recovered exactly. -/
theorem parseChildNumber_render (c : ChildNumber) :
    parseChildNumber (renderChild c) = .ok c := by
  cases c with
  | mk index hardened lt =>
  cases hardened
  · -- unhardened: the character list is `natDigits index`
    unfold parseChildNumber renderChild renderChildChars
    rw [String.toList_ofList]
    simp
    have hne : natDigits index ≠ [] := natDigits_ne_nil index
    cases hlast : (natDigits index).getLast? with
    | none =>
      cases hnd : natDigits index with
      | nil => exact absurd hnd hne
      | cons d ds =>
        rw [hnd] at hlast
        cases ds with
        | nil => simp at hlast
        | cons e es => simp [List.getLast?_cons_cons] at hlast
    | some last =>
      have hmem := mem_of_getLast?_eq_some hlast
      have hnh : last ≠ 'h' := natDigits_no_h index last hmem
      have hna : last ≠ '\'' := natDigits_no_apostrophe index last hmem
      simp [hlast, hnh, hna, hne]
      rw [digitsValueAux_natDigits index]
      simp [lt]
  · -- hardened: the character list is `natDigits index ++ ['h']`
    unfold parseChildNumber renderChild renderChildChars
    rw [String.toList_ofList]
    simp
    have hne : natDigits index ≠ [] := natDigits_ne_nil index
    simp [hne]
    rw [digitsValueAux_natDigits index]
    simp [lt]

/-- A list with no separator is returned as one component. -/
theorem splitOnAux_no_sep (sep : Char) :
    ∀ (l : List Char) (cur : List Char) (acc : List String),
      (∀ x ∈ l, x ≠ sep) →
      splitOnAux sep cur acc l =
        acc.reverse ++ [String.ofList (cur.reverse ++ l)] := by
  intro l
  induction l with
  | nil =>
    intro cur acc h
    simp [splitOnAux]
  | cons c cs ih =>
    intro cur acc h
    have hc : c ≠ sep := h c (by simp)
    have hrest : ∀ x ∈ cs, x ≠ sep := fun x hx => h x (by simp [hx])
    simp [splitOnAux, hc]
    rw [ih (c :: cur) acc hrest]
    simp [List.reverse_cons, List.append_assoc]

/-- A separator splits off exactly the accumulated component. -/
theorem splitOnAux_append_sep (sep : Char) :
    ∀ (l : List Char) (cur : List Char) (acc : List String) (r : List Char),
      (∀ x ∈ l, x ≠ sep) →
      splitOnAux sep cur acc (l ++ sep :: r) =
        splitOnAux sep [] (String.ofList (cur.reverse ++ l) :: acc) r := by
  intro l
  induction l with
  | nil =>
    intro cur acc r h
    simp [splitOnAux]
  | cons c cs ih =>
    intro cur acc r h
    have hc : c ≠ sep := h c (by simp)
    have hrest : ∀ x ∈ cs, x ≠ sep := fun x hx => h x (by simp [hx])
    simp [splitOnAux, hc]
    rw [ih (c :: cur) acc r hrest]
    simp [List.reverse_cons, List.append_assoc]

/-- Splitting the rendered body yields exactly the rendered components. -/
theorem splitOnAux_body : ∀ (acc : List String) (p : List ChildNumber),
    p ≠ [] →
      splitOnAux '/' [] acc (bodyChars p) =
        acc.reverse ++ p.map renderChild := by
  intro acc p
  revert acc
  induction p with
  | nil => intro acc h; exact absurd rfl h
  | cons c cs ih =>
    intro acc hne
    cases cs with
    | nil =>
      have hno := renderChildChars_no_slash c
      have h := splitOnAux_no_sep '/' (renderChildChars c) [] acc hno
      simp [bodyChars, h, renderChild]
    | cons d ds =>
      have hno := renderChildChars_no_slash c
      have h := splitOnAux_append_sep '/' (renderChildChars c) [] acc
        (bodyChars (d :: ds)) hno
      simp [bodyChars, h, renderChild]
      rw [ih (String.ofList (renderChildChars c) :: acc) (by simp)]
      simp [renderChild, List.reverse_cons, List.append_assoc]

/-- A rendered component is never the root marker `m`. -/
theorem renderChild_ne_m (c : ChildNumber) : renderChild c ≠ "m" := by
  intro h
  have hchars : renderChildChars c = ['m'] := by
    rw [← renderChild_toList c, h]
    rfl
  have hne := natDigits_ne_nil c.index
  unfold renderChildChars at hchars
  cases hnd : natDigits c.index with
  | nil => exact hne hnd
  | cons d ds =>
    rw [hnd] at hchars
    have hhead := congrArg List.head? hchars
    simp [List.head?_append] at hhead
    have hdig := natDigits_ascii c.index d (by rw [hnd]; simp)
    unfold isAsciiDigit at hdig
    have hb := of_decide_eq_true hdig
    simp [hhead] at hb

/-- The parser inverts the printer componentwise. -/
theorem parseChildNumbers_map_render :
    ∀ p : List ChildNumber,
      parseChildNumbers (p.map renderChild) = .ok p := by
  intro p
  induction p with
  | nil => rfl
  | cons c cs ih =>
    have hne := renderChild_ne_m c
    simp [parseChildNumbers, hne, parseChildNumber_render c, ih]

/-- `splitOn` of a printed path is the root marker followed by the
printed components. -/
theorem splitOn_renderPath (p : List ChildNumber) :
    splitOn '/' (renderPath p) = "m" :: p.map renderChild := by
  cases p with
  | nil => simp [renderPath, splitOn, splitOnAux]
  | cons c cs =>
    have hb := splitOnAux_body ["m"] (c :: cs) (by simp)
    simp [renderPath, splitOn, splitOnAux, String.toList_append,
      String.toList_ofList, hb]

/-- Parsing a canonically printed path returns that path: the printed
grammar is a section of the accepted grammar. -/
theorem parsePath_render (p : List ChildNumber) :
    parsePath (renderPath p) = .ok p := by
  unfold parsePath
  rw [splitOn_renderPath]
  simp [parseChildNumbers_map_render]

/-! ## The hardened-index predicate -/

/-- The model's `isHardened` is exactly the numerical threshold. -/
theorem isHardened_iff (i : UInt32) :
    isHardened i = true ↔ 0x80000000 ≤ i := by
  unfold isHardened
  exact decide_eq_true_iff

/-- `Nat.toUInt32` of a value below 2^32 reads back unchanged. -/
theorem toUInt32_toNat_of_lt (n : Nat) (h : n < 2 ^ 32) :
    (n.toUInt32).toNat = n := by
  simp [Nat.toUInt32, Nat.mod_eq_of_lt h]

/-- The natural value of a serialized child number: the index with bit 31
set exactly when the step is hardened. -/
theorem toUInt32_toNat (c : ChildNumber) :
    c.toUInt32.toNat =
      c.index ||| (if c.hardened then 0x80000000 else 0) := by
  unfold ChildNumber.toUInt32
  rw [UInt32.toNat_or]
  cases h : c.hardened
  · simp [h, Nat.toUInt32, UInt32.toNat_zero,
      Nat.mod_eq_of_lt (Nat.lt_of_lt_of_le c.lt (by decide : 0x80000000 ≤ 2 ^ 32))]
  · simp [h, Nat.toUInt32, UInt32.toNat_ofNat,
      Nat.mod_eq_of_lt (by decide : 0x80000000 < 2 ^ 32),
      Nat.mod_eq_of_lt (Nat.lt_of_lt_of_le c.lt (by decide : 0x80000000 ≤ 2 ^ 32))]

/-- Serialization preserves the `hardened` flag.  The index bound
`c.index < 2^31` is what keeps bit 31 free for the flag. -/
theorem isHardened_toUInt32 (c : ChildNumber) :
    isHardened c.toUInt32 = c.hardened := by
  cases h : c.hardened
  · have hnat : c.toUInt32.toNat = c.index := by
      rw [toUInt32_toNat, h]
      exact Nat.or_zero c.index
    have hnot : ¬ (0x80000000 : UInt32) ≤ c.toUInt32 := by
      rw [UInt32.not_le, UInt32.lt_iff_toNat_lt]
      rw [hnat]
      show c.index < (0x80000000 : UInt32).toNat
      rw [show (0x80000000 : UInt32).toNat = 0x80000000 by decide]
      exact c.lt
    simp [isHardened, h, hnot]
  · have hnat : c.toUInt32.toNat = c.index ||| 0x80000000 := by
      rw [toUInt32_toNat, h]
      simp
    have hgeNat : (0x80000000 : Nat) ≤ c.toUInt32.toNat := by
      rw [hnat]
      exact Nat.right_le_or
    have hge : (0x80000000 : UInt32) ≤ c.toUInt32 := by
      rw [UInt32.le_iff_toNat_le]
      rw [show (0x80000000 : UInt32).toNat = 0x80000000 by decide]
      exact hgeNat
    simp [isHardened, h, hge]

/-! ## Path concatenation and derivation -/

/-- `Except.ok` is a left unit for `bind`. -/
@[simp] theorem Except_ok_bind {ε α β : Type} (a : α) (f : α → Except ε β) :
    (Except.ok a).bind f = f a := rfl

/-- `Except.error` absorbs `bind`. -/
@[simp] theorem Except_error_bind {ε α β : Type} (e : ε) (f : α → Except ε β) :
    (Except.error e).bind f = Except.error e := rfl

/-- Private derivation along an appended path is the composition of the
two derivations.  This is a structural identity; no cryptographic
assumption is involved. -/
theorem derivePath_append :
    ∀ (x : ExtPrivKey) (p q : List UInt32),
      derivePath x (p ++ q) =
        (derivePath x p).bind (fun y => derivePath y q) := by
  intro x p
  revert x
  induction p with
  | nil => intro x q; simp [derivePath]
  | cons i rest ih =>
    intro x q
    cases h : ckdPriv x i with
    | error e => simp [derivePath, h]
    | ok y =>
      simp [derivePath, h]
      exact ih y q

/-- Public derivation has the same composition law. -/
theorem derivePubPath_append :
    ∀ (x : ExtPubKey) (p q : List UInt32),
      derivePubPath x (p ++ q) =
        (derivePubPath x p).bind (fun y => derivePubPath y q) := by
  intro x p
  revert x
  induction p with
  | nil => intro x q; simp [derivePubPath]
  | cons i rest ih =>
    intro x q
    cases h : ckdPub x i with
    | error e => simp [derivePubPath, h]
    | ok y =>
      simp [derivePubPath, h]
      exact ih y q

/-- Concatenation of parsed descriptor paths commutes with mapping the
child numbers to wire indices. -/
theorem derivePathCN_append (x : ExtPrivKey) (p q : List ChildNumber) :
    derivePathCN x (p ++ q) =
      (derivePathCN x p).bind (fun y => derivePathCN y q) := by
  unfold derivePathCN
  rw [List.map_append, derivePath_append]

/-- Two successful derivation legs compose into one successful derivation
along the appended path. -/
theorem derivePath_append_ok (x y z : ExtPrivKey) (p q : List UInt32)
    (hp : derivePath x p = .ok y) (hq : derivePath y q = .ok z) :
    derivePath x (p ++ q) = .ok z := by
  rw [derivePath_append, hp]
  simp [hq]

/-- The same for public derivation. -/
theorem derivePubPath_append_ok (x y z : ExtPubKey) (p q : List UInt32)
    (hp : derivePubPath x p = .ok y) (hq : derivePubPath y q = .ok z) :
    derivePubPath x (p ++ q) = .ok z := by
  rw [derivePubPath_append, hp]
  simp [hq]

/-- Associativity of path concatenation, phrased as the equality of the
two derivations: deriving along `(p ++ q) ++ r` is deriving along
`p ++ (q ++ r)`. -/
theorem derivePath_append_assoc (x : ExtPrivKey) (p q r : List UInt32) :
    derivePath x ((p ++ q) ++ r) = derivePath x (p ++ (q ++ r)) := by
  rw [List.append_assoc]

/-! ## Key origins as metadata -/

/-- A key tagged with an optional origin.  The origin is bookkeeping: it
records where the key came from, and no operation below validates that
the fingerprint actually belongs to the key. -/
structure SourcedKey (K : Type) where
  origin : Option KeyOrigin
  key : K

/-- Attach an origin to key material. -/
def attachOrigin {K : Type} (o : KeyOrigin) (k : K) : SourcedKey K := ⟨some o, k⟩

/-- Strip the origin, keeping the key material. -/
def stripOrigin {K : Type} (s : SourcedKey K) : K := s.key

/-- Attaching then stripping is the identity on key material. -/
theorem stripOrigin_attachOrigin {K : Type} (o : KeyOrigin) (k : K) :
    stripOrigin (attachOrigin o k) = k := rfl

/-- Attaching preserves every field of an extended private key,
including the secret scalar. -/
theorem attachOrigin_priv (o : KeyOrigin) (x : ExtPrivKey) :
    (attachOrigin o x).key.key = x.key ∧
    (attachOrigin o x).key.depth = x.depth ∧
    (attachOrigin o x).key.parentFingerprint = x.parentFingerprint ∧
    (attachOrigin o x).key.childNumber = x.childNumber ∧
    (attachOrigin o x).key.chainCode = x.chainCode :=
  ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- Attaching preserves the extended public key. -/
theorem attachOrigin_pub (o : KeyOrigin) (x : ExtPubKey) :
    (attachOrigin o x).key = x := rfl

/-- The 78-byte private payload ignores the origin tag. -/
theorem attachOrigin_serializePriv (o : KeyOrigin) (x : ExtPrivKey) :
    serializePriv (attachOrigin o x).key = serializePriv x := rfl

/-- The 78-byte public payload ignores the origin tag. -/
theorem attachOrigin_serializePub (o : KeyOrigin) (x : ExtPubKey) :
    serializePub (attachOrigin o x).key = serializePub x := rfl

/-- Re-attaching an existing origin round-trips on the tag. -/
theorem attachOrigin_origin {K : Type} (o : KeyOrigin) (k : K) :
    (attachOrigin o k).origin = some o := rfl

/-- A stripped key cannot recover an origin, so the natural round-trip is
`strip` then a fresh attach; the key component is unchanged. -/
theorem attachOrigin_stripOrigin_key {K : Type} (s : SourcedKey K) (o : KeyOrigin) :
    stripOrigin (attachOrigin o (stripOrigin s)) = stripOrigin s := rfl

/-! ## Fingerprint field arithmetic -/

/-- The fingerprint is a function of the compressed public-key
serialization alone.  `hash160` is an opaque model function here, so this
is congruence only, not a cryptographic claim. -/
theorem fingerprint_congr {p q : PubKey} (h : serPub p = serPub q) :
    fingerprint p = fingerprint q := by
  unfold fingerprint
  rw [h]

/-- The fingerprint field always occupies four bytes. -/
theorem fingerprint_field_size (p : PubKey) : (fingerprint p).size = 4 :=
  fingerprint_size p

end BitcoinProofs.Wallet.Key
