import Bitcoin.Capstone.Block

/-!
# BitcoinProofs.Theorems.CapstoneBip34Cor — P04: the BIP34 coinbase-height push, proved

**BLK-069** (`bad-cb-height`): from `BIP34_HEIGHT = 227931` on, the coinbase
scriptSig must *begin with* the minimal push of `CScriptNum(height)`
(`CScriptNum::getvch`: little-endian magnitude, one `0x00` sign byte
appended when the top byte has the high bit set).

The executable core (`Bitcoin.Capstone.Block`) implements this as

    cbHeightDigits (private) → cbHeightBytes → cbHeightPush → bip34Ok

`cbHeightDigits` is `private`, so this module carries an exact definitional
mirror (`digitsOf` / `bytesOf`, digit helpers `dig0..dig3`) and proves the
bridge `cbHeightBytes_eq : cbHeightBytes n = bytesOf n` by `rfl` — the
kernel delta-unfolds `cbHeightBytes` and, through it, the private
`cbHeightDigits`, whose body is syntactically the mirror. No axioms.
Every downstream theorem is stated about the REAL public core functions
`cbHeightBytes`, `cbHeightPush`, `bip34Ok`.

C4 portfolio linkage (axiom footprints: ∅ = none, P = `propext`,
Q = `Quot.sound`, C = `Classical.choice`):

| C4 ID / rule | theorem here | statement (short) | axioms |
|----------|--------------|-------------------|--------|
| (BLK-069 vacuity) | `bip34Ok_vacuous_below` | height < 227931 ⇒ `bip34Ok = true` unconditionally (W15-flags-style vacuity) | P,C,Q |
| (BLK-069 zero pin) | `cbHeightPush_zero` | height 0 pushes exactly `[0x00]` (all-zero digits strip to empty) | P |
| (BLK-069 genesis era) | `cbHeightPush_one_byte_heights` | 0 < n < 128 ⇒ push = `[0x01, n]` | P,Q |
| (BLK-069 anchor 481824) | `cbHeightPush_481824` | push = `[0x03, 0x20, 0x5A, 0x07]` — REAL anchor data (W17 run) | P |
| (BLK-069 anchor 709632) | `cbHeightPush_709632` | push = `[0x03, 0x00, 0xD4, 0x0A]` — REAL anchor data (W17 run) | P |
| (BLK-069 activation pin) | `cbHeightPush_227931` | the push at the BIP34 activation height itself | P |
| (BLK-069 bound) | `cbHeightPush_length_bound` | every `UInt32` height pushes ≤ 6 bytes | P,Q |
| (BLK-069 bound, sharp) | `cbHeightPush_length_bound31` | height < 2^31 ⇒ ≤ 5 bytes (the realistic regime) | P,Q |
| (BLK-069 bound pin) | `cbHeightPush_max` | 2^32−1 pushes exactly 6 bytes — so "≤ 5 on all of UInt32" is FALSE (the generic bound is 6, not 5) | P |
| (CScriptNum::getvch) | `cbHeightBytes_sign_rule` | top digit ≥ 0x80 ⇒ exactly one `0x00` sign byte appended | P,Q |
| (BLK-069 acceptance) | `bip34Ok_push_prefix` | any coinbase whose scriptSig *extends* the exact push passes the gate (the direction the W17 anchor run exercised) | P,C,Q |

Supporting lemmas (bridges, digit roundtrips, the `digitsOf_cases`
workhorse): footprints ⊆ {P, Q}; see the `#print axioms` pins at the bottom.

**Where the `Classical.choice` comes from**: the two `bip34Ok`-value
theorems. `bip34Ok`'s body calls `Bitcoin.Data.bytesBEq`, whose decidable
instance (over `List.all`) is proved using `Classical.choice` in the core
layer — even a bare `rfl` about `bip34Ok` has footprint
`[propext, Classical.choice, Quot.sound]`. It is inherited from the
generalized-from layer, not introduced by this module; every theorem here
that does NOT mention `bip34Ok`'s value is choice-free.
-/

namespace BitcoinProofs.Theorems.CapstoneBip34

open Bitcoin.Capstone.Block Bitcoin.Data

/-! ## Definitional mirror of the private digit layer -/

/-- Byte 0 of `n` (LSB), mirroring the private `cbHeightDigits` body. -/
def dig0 (n : Nat) : UInt8 := (n % 256).toUInt8

/-- Byte 1 of `n`. -/
def dig1 (n : Nat) : UInt8 := (n / 256 % 256).toUInt8

/-- Byte 2 of `n`. -/
def dig2 (n : Nat) : UInt8 := (n / 65536 % 256).toUInt8

/-- Byte 3 of `n` — the *top* digit for every height < 2^32. -/
def dig3 (n : Nat) : UInt8 := (n / 16777216 % 256).toUInt8

/-- Exact definitional mirror of the private `cbHeightDigits`: the four
unrolled LSB-first base-256 digits, redundant zero digits stripped on the
MSB side. -/
def digitsOf (n : Nat) : List UInt8 :=
  let l := [dig0 n, dig1 n, dig2 n, dig3 n]
  match l.reverse.dropWhile (fun b => b.toNat == 0) with
  | [] => []
  | l' => l'.reverse

/-- Exact definitional mirror of `cbHeightBytes` (`CScriptNum::getvch`). -/
def bytesOf (n : Nat) : List UInt8 :=
  let l := digitsOf n
  match l.getLast? with
  | some b => if b.toNat ≥ 0x80 then l ++ [0] else l
  | none => []

/-- **Bridge theorem**: the public `cbHeightBytes` IS the mirror `bytesOf`.
Proof: `rfl` — the kernel delta-unfolds `cbHeightBytes` and (through it)
the private `cbHeightDigits`; after zeta-reduction both sides are the
mirror body. -/
theorem cbHeightBytes_eq (n : Nat) : cbHeightBytes n = bytesOf n := rfl

/-! ## Small ByteArray / list plumbing -/

/-- `ByteArray.push`-fold builds the same bytes as `List.toByteArray`. -/
theorem foldl_push_toByteArray (l : List UInt8) (acc : ByteArray) :
    l.foldl (fun a b => a.push b) acc = List.toByteArray.loop l acc := by
  induction l generalizing acc with
  | nil => rfl
  | cons b bs ih => simp only [List.foldl, ih]; rfl

/-- `List.toByteArray` preserves the length. -/
theorem toByteArray_size (l : List UInt8) : l.toByteArray.size = l.length := by
  have h : ∀ (l : List UInt8) (acc : ByteArray),
      (List.toByteArray.loop l acc).size = acc.size + l.length := by
    intro l
    induction l with
    | nil => intro acc; rfl
    | cons b bs ih =>
        intro acc
        simp only [List.toByteArray.loop, ih, ByteArray.size_push, List.length_cons]
        omega
  show (List.toByteArray.loop l ByteArray.empty).size = l.length
  rw [h]
  simp

/-- The push is one length byte plus the `CScriptNum` bytes. -/
theorem cbHeightPush_size (h : UInt32) :
    (cbHeightPush h).size = (bytesOf h.toNat).length + 1 := by
  have hpush : cbHeightPush h =
      ((bytesOf h.toNat).length.toUInt8 :: bytesOf h.toNat).toByteArray := by
    simp only [cbHeightPush, cbHeightBytes_eq, foldl_push_toByteArray]
    rfl
  rw [hpush, toByteArray_size, List.length_cons]

/-- Full shape of the push. -/
theorem cbHeightPush_eq (h : UInt32) :
    cbHeightPush h =
      ((bytesOf h.toNat).length.toUInt8 :: bytesOf h.toNat).toByteArray := by
  simp only [cbHeightPush, cbHeightBytes_eq, foldl_push_toByteArray]
  rfl

/-! ## Digit roundtrips -/

/-- `(dig0 n).toNat` is the LSB of `n`. -/
theorem dig0_toNat (n : Nat) : (dig0 n).toNat = n % 256 := by
  simp [dig0]

/-- `(dig1 n).toNat` is byte 1 of `n`. -/
theorem dig1_toNat (n : Nat) : (dig1 n).toNat = n / 256 % 256 := by
  simp [dig1]

/-- `(dig2 n).toNat` is byte 2 of `n`. -/
theorem dig2_toNat (n : Nat) : (dig2 n).toNat = n / 65536 % 256 := by
  simp [dig2]

/-- `(dig3 n).toNat` is byte 3 of `n`. -/
theorem dig3_toNat (n : Nat) : (dig3 n).toNat = n / 16777216 % 256 := by
  simp [dig3]

/-! ## The digit-strip case analysis -/

/-- `dropWhile` keeps a nonzero leading byte (as `UInt8`). -/
theorem dropWhile_zero_cons_false {b : UInt8} {l : List UInt8}
    (h : (b.toNat == 0) = false) :
    (b :: l).dropWhile (fun x => x.toNat == 0) = b :: l := by
  simp [List.dropWhile, h]

/-- `dropWhile` skips a zero leading byte (as `UInt8`). -/
theorem dropWhile_zero_cons_true {b : UInt8} {l : List UInt8}
    (h : (b.toNat == 0) = true) :
    (b :: l).dropWhile (fun x => x.toNat == 0) = l.dropWhile (fun x => x.toNat == 0) := by
  simp [List.dropWhile, h]

/-- A nonzero `Nat` is `BEq`-unequal to zero. -/
theorem beq_zero_of_ne {x : Nat} (h : x ≠ 0) : (x == 0) = false := by
  cases h' : x with
  | zero => exact absurd h' h
  | succ m => rfl

/-- **The MSB-strip spec**: `dropWhile` on the reversed digit list eats
exactly the leading (most-significant) zero digits. -/
theorem digitsOf_stripped (n : Nat) :
    ([dig0 n, dig1 n, dig2 n, dig3 n] : List UInt8).reverse.dropWhile (fun b => b.toNat == 0)
      = if (dig3 n).toNat ≠ 0 then [dig3 n, dig2 n, dig1 n, dig0 n]
        else if (dig2 n).toNat ≠ 0 then [dig2 n, dig1 n, dig0 n]
        else if (dig1 n).toNat ≠ 0 then [dig1 n, dig0 n]
        else if (dig0 n).toNat ≠ 0 then [dig0 n]
        else [] := by
  rw [show ([dig0 n, dig1 n, dig2 n, dig3 n] : List UInt8).reverse
        = [dig3 n, dig2 n, dig1 n, dig0 n] from rfl]
  by_cases h3 : (dig3 n).toNat = 0
  · rw [if_neg (show ¬((dig3 n).toNat ≠ 0) from by omega),
        dropWhile_zero_cons_true (by rw [h3]; rfl)]
    by_cases h2 : (dig2 n).toNat = 0
    · rw [if_neg (show ¬((dig2 n).toNat ≠ 0) from by omega),
          dropWhile_zero_cons_true (by rw [h2]; rfl)]
      by_cases h1 : (dig1 n).toNat = 0
      · rw [if_neg (show ¬((dig1 n).toNat ≠ 0) from by omega),
            dropWhile_zero_cons_true (by rw [h1]; rfl)]
        by_cases h0 : (dig0 n).toNat = 0
        · rw [if_neg (show ¬((dig0 n).toNat ≠ 0) from by omega),
              dropWhile_zero_cons_true (by rw [h0]; rfl)]
          rfl
        · rw [if_pos (show (dig0 n).toNat ≠ 0 from by omega),
              dropWhile_zero_cons_false (beq_zero_of_ne (by omega))]
      · rw [if_pos (show (dig1 n).toNat ≠ 0 from by omega),
            dropWhile_zero_cons_false (beq_zero_of_ne (by omega))]
    · rw [if_pos (show (dig2 n).toNat ≠ 0 from by omega),
          dropWhile_zero_cons_false (beq_zero_of_ne (by omega))]
  · rw [if_pos (show (dig3 n).toNat ≠ 0 from by omega),
        dropWhile_zero_cons_false (beq_zero_of_ne (by omega))]

/-- `bytesOf` in terms of the stripped digits (definitional). -/
theorem bytesOf_of_digits (n : Nat) (L : List UInt8) (h : digitsOf n = L) :
    bytesOf n =
      match L.getLast? with
      | some b => if b.toNat ≥ 0x80 then L ++ [0] else L
      | none => [] := by
  simp only [bytesOf, h]

/-- Shorthand: the digits of `n` are the four-byte truncation per the
zero-pattern, in each of the five exhaustive cases. -/
theorem digitsOf_sh1 (n : Nat) (h3 : (dig3 n).toNat = 0) (h2 : (dig2 n).toNat = 0)
    (h1 : (dig1 n).toNat = 0) (h0 : (dig0 n).toNat ≠ 0) :
    digitsOf n = [dig0 n] := by
  simp only [digitsOf]
  rw [digitsOf_stripped n,
      if_neg (show ¬((dig3 n).toNat ≠ 0) from by omega),
      if_neg (show ¬((dig2 n).toNat ≠ 0) from by omega),
      if_neg (show ¬((dig1 n).toNat ≠ 0) from by omega),
      if_pos (show (dig0 n).toNat ≠ 0 from by omega)]
  rfl

theorem digitsOf_sh2 (n : Nat) (h3 : (dig3 n).toNat = 0) (h2 : (dig2 n).toNat = 0)
    (h1 : (dig1 n).toNat ≠ 0) :
    digitsOf n = [dig0 n, dig1 n] := by
  simp only [digitsOf]
  rw [digitsOf_stripped n,
      if_neg (show ¬((dig3 n).toNat ≠ 0) from by omega),
      if_neg (show ¬((dig2 n).toNat ≠ 0) from by omega),
      if_pos (show (dig1 n).toNat ≠ 0 from by omega)]
  rfl

theorem digitsOf_sh3 (n : Nat) (h3 : (dig3 n).toNat = 0) (h2 : (dig2 n).toNat ≠ 0) :
    digitsOf n = [dig0 n, dig1 n, dig2 n] := by
  simp only [digitsOf]
  rw [digitsOf_stripped n,
      if_neg (show ¬((dig3 n).toNat ≠ 0) from by omega),
      if_pos (show (dig2 n).toNat ≠ 0 from by omega)]
  rfl

theorem digitsOf_sh4 (n : Nat) (h3 : (dig3 n).toNat ≠ 0) :
    digitsOf n = [dig0 n, dig1 n, dig2 n, dig3 n] := by
  simp only [digitsOf]
  rw [digitsOf_stripped n, if_pos (show (dig3 n).toNat ≠ 0 from by omega)]
  rfl

theorem digitsOf_sh0 (n : Nat) (h3 : (dig3 n).toNat = 0) (h2 : (dig2 n).toNat = 0)
    (h1 : (dig1 n).toNat = 0) (h0 : (dig0 n).toNat = 0) :
    digitsOf n = [] := by
  simp only [digitsOf]
  rw [digitsOf_stripped n,
      if_neg (show ¬((dig3 n).toNat ≠ 0) from by omega),
      if_neg (show ¬((dig2 n).toNat ≠ 0) from by omega),
      if_neg (show ¬((dig1 n).toNat ≠ 0) from by omega),
      if_neg (show ¬((dig0 n).toNat ≠ 0) from by omega)]

/-- **THE CASE ANALYSIS** (workhorse): `digitsOf`/`bytesOf` split into five
exhaustive shapes keyed by the digit zero-pattern, each disjunct carrying
the zero-pattern side conditions. This is the proved behavioral spec of the
private `cbHeightDigits` together with the `CScriptNum::getvch` sign rule. -/
theorem digitsOf_cases (n : Nat) :
    (digitsOf n = [] ∧ (dig0 n).toNat = 0 ∧ (dig1 n).toNat = 0 ∧ (dig2 n).toNat = 0
        ∧ (dig3 n).toNat = 0 ∧ bytesOf n = [])
    ∨ (digitsOf n = [dig0 n] ∧ (dig3 n).toNat = 0 ∧ (dig2 n).toNat = 0 ∧ (dig1 n).toNat = 0
        ∧ (dig0 n).toNat ≠ 0
        ∧ bytesOf n = if (dig0 n).toNat ≥ 0x80 then [dig0 n, 0] else [dig0 n])
    ∨ (digitsOf n = [dig0 n, dig1 n] ∧ (dig3 n).toNat = 0 ∧ (dig2 n).toNat = 0
        ∧ (dig1 n).toNat ≠ 0
        ∧ bytesOf n = if (dig1 n).toNat ≥ 0x80 then [dig0 n, dig1 n, 0] else [dig0 n, dig1 n])
    ∨ (digitsOf n = [dig0 n, dig1 n, dig2 n] ∧ (dig3 n).toNat = 0 ∧ (dig2 n).toNat ≠ 0
        ∧ bytesOf n = if (dig2 n).toNat ≥ 0x80 then [dig0 n, dig1 n, dig2 n, 0]
                      else [dig0 n, dig1 n, dig2 n])
    ∨ (digitsOf n = [dig0 n, dig1 n, dig2 n, dig3 n] ∧ (dig3 n).toNat ≠ 0
        ∧ bytesOf n = if (dig3 n).toNat ≥ 0x80 then [dig0 n, dig1 n, dig2 n, dig3 n, 0]
                      else [dig0 n, dig1 n, dig2 n, dig3 n]) := by
  by_cases h3 : (dig3 n).toNat = 0
  · by_cases h2 : (dig2 n).toNat = 0
    · by_cases h1 : (dig1 n).toNat = 0
      · by_cases h0 : (dig0 n).toNat = 0
        · exact Or.inl ⟨digitsOf_sh0 n h3 h2 h1 h0, h0, h1, h2, h3,
            by rw [bytesOf_of_digits n [] (digitsOf_sh0 n h3 h2 h1 h0)]; rfl⟩
        · refine Or.inr (Or.inl ⟨?_, h3, h2, h1, ?_, ?_⟩)
          · exact digitsOf_sh1 n h3 h2 h1 (by omega)
          · omega
          · rw [bytesOf_of_digits n [dig0 n] (digitsOf_sh1 n h3 h2 h1 (by omega))]
            rfl
      · refine Or.inr (Or.inr (Or.inl ⟨?_, h3, h2, ?_, ?_⟩))
        · exact digitsOf_sh2 n h3 h2 (by omega)
        · omega
        · rw [bytesOf_of_digits n [dig0 n, dig1 n] (digitsOf_sh2 n h3 h2 (by omega))]
          rfl
    · refine Or.inr (Or.inr (Or.inr (Or.inl ⟨?_, h3, ?_, ?_⟩)))
      · exact digitsOf_sh3 n h3 (by omega)
      · omega
      · rw [bytesOf_of_digits n [dig0 n, dig1 n, dig2 n] (digitsOf_sh3 n h3 (by omega))]
        rfl
  · refine Or.inr (Or.inr (Or.inr (Or.inr ⟨?_, ?_, ?_⟩)))
    · exact digitsOf_sh4 n (by omega)
    · omega
    · rw [bytesOf_of_digits n [dig0 n, dig1 n, dig2 n, dig3 n] (digitsOf_sh4 n (by omega))]
      rfl

/-! ## BLK-069: the gate itself -/

/-- **BLK-069 vacuity** (W15-flags-style): below the BIP34 activation
height 227931 the gate is vacuously true, for EVERY coinbase — the `if`
takes the `else true` branch and the scriptSig is never inspected. -/
theorem bip34Ok_vacuous_below (height : UInt32) (cb : Tx)
    (h : height < Bitcoin.Ledger.BIP34_HEIGHT) :
    bip34Ok height cb = true := by
  have h' : height.toNat < Bitcoin.Ledger.BIP34_HEIGHT.toNat :=
    UInt32.lt_iff_toNat_lt.mp h
  simp only [bip34Ok, if_neg (show ¬(Bitcoin.Ledger.BIP34_HEIGHT ≤ height) from by
    rw [UInt32.le_iff_toNat_le]; omega)]

/-- **BLK-069 acceptance direction** (the one the W17 anchor run
exercised): when BIP34 is active and the coinbase scriptSig *extends* the
exact minimal push — `push ++ rest` — the gate passes
(`ByteArray.extract_append_eq_left` reads the pushed prefix back). -/
theorem bip34Ok_push_prefix (height : UInt32) (cb : Tx) (txin : TxIn)
    (vinRest : List TxIn) (rest : ByteArray)
    (hact : Bitcoin.Ledger.BIP34_HEIGHT ≤ height)
    (hvin : cb.vin = txin :: vinRest)
    (hss : txin.scriptSig.bytes = cbHeightPush height ++ rest) :
    bip34Ok height cb = true := by
  simp only [bip34Ok, if_pos hact, hvin, List.getD_cons_zero, hss,
    ByteArray.extract_append_eq_left rfl, bytesBEq]
  simp

/-! ## The sign-byte rule -/

/-- **`CScriptNum::getvch` sign rule**: when the top digit (byte 3) has the
high bit set, exactly one `0x00` sign byte is appended to the stripped
little-endian magnitude. -/
theorem cbHeightBytes_sign_rule (n : Nat) (h : (dig3 n).toNat ≥ 0x80) :
    cbHeightBytes n = digitsOf n ++ [0] := by
  have hne : (dig3 n).toNat ≠ 0 := by omega
  rcases digitsOf_cases n with ⟨hd, z0, z1, z2, z3, hb⟩
    | ⟨hd, z3, z2, z1, _, hb⟩ | ⟨hd, z3, z2, _, hb⟩
    | ⟨hd, z3, _, hb⟩ | ⟨hd, _, hb⟩
  · exfalso; omega
  · exfalso; omega
  · exfalso; omega
  · exfalso; omega
  · rw [cbHeightBytes_eq, hb, if_pos h, hd]
    rfl

/-! ## Length bounds for the push -/

/-- The stripped digit list has at most 4 digits. -/
theorem digitsOf_length_le4 (n : Nat) : (digitsOf n).length ≤ 4 := by
  rcases digitsOf_cases n with ⟨hd, _, _, _, _, _⟩ | ⟨hd, _, _, _, _, _⟩
    | ⟨hd, _, _, _, _⟩ | ⟨hd, _, _, _⟩ | ⟨hd, _, _⟩ <;>
  rw [hd] <;> simp

/-- `bytesOf` adds at most one sign byte to the stripped digits. -/
theorem bytesOf_length_le (n : Nat) :
    (bytesOf n).length ≤ (digitsOf n).length + 1 := by
  have h0 : bytesOf n =
      match (digitsOf n).getLast? with
      | some b => if b.toNat ≥ 0x80 then digitsOf n ++ [0] else digitsOf n
      | none => [] := bytesOf_of_digits n _ rfl
  cases hh : (digitsOf n).getLast? with
  | none => rw [h0, hh]; simp
  | some b =>
    rw [h0, hh]
    by_cases h80 : b.toNat ≥ 0x80
    · simp only [if_pos h80, List.length_append, List.length_singleton]; omega
    · simp only [if_neg h80]; omega

/-- **Generic bound**: every `UInt32` height pushes at most 6 bytes
(4 digits + 1 sign byte + 1 length byte). -/
theorem cbHeightPush_length_bound (h : UInt32) : (cbHeightPush h).size ≤ 6 := by
  rw [cbHeightPush_size]
  have h1 := bytesOf_length_le h.toNat
  have h2 := digitsOf_length_le4 h.toNat
  omega

/-- **Sharp bound**: heights below 2^31 — every realistic BIP34 regime,
where the top digit's high bit is clear — push at most 5 bytes. -/
theorem cbHeightPush_length_bound31 (h : UInt32) (hl : h.toNat < 2147483648) :
    (cbHeightPush h).size ≤ 5 := by
  have hd3 : (dig3 h.toNat).toNat < 0x80 := by simp [dig3_toNat]; omega
  rw [cbHeightPush_size]
  rcases digitsOf_cases h.toNat with ⟨_, _, _, _, _, hb⟩
    | ⟨_, _, _, _, _, hb⟩ | ⟨_, _, _, _, hb⟩ | ⟨_, _, _, hb⟩ | ⟨_, _, hb⟩
  · rw [hb]; simp
  · rw [hb]; by_cases hx : (dig0 h.toNat).toNat ≥ 0x80
    · rw [if_pos hx]; simp
    · rw [if_neg hx]; simp
  · rw [hb]; by_cases hx : (dig1 h.toNat).toNat ≥ 0x80
    · rw [if_pos hx]; simp
    · rw [if_neg hx]; simp
  · rw [hb]; by_cases hx : (dig2 h.toNat).toNat ≥ 0x80
    · rw [if_pos hx]; simp
    · rw [if_neg hx]; simp
  · rw [hb, if_neg (show ¬((dig3 h.toNat).toNat ≥ 0x80) from by omega)]; simp

/-- **Pin (honesty note)**: at the extreme `UInt32` value 2^32−1 the push
is SIX bytes — four `0xFF` digits plus the `0x00` sign byte plus the length
byte. This is why the generic bound is 6, and the often-quoted "≤ 5" holds
only below 2^31 (see `cbHeightPush_length_bound31`). -/
theorem cbHeightPush_max :
    cbHeightPush 4294967295 = ([5, 255, 255, 255, 255, 0] : List UInt8).toByteArray := by
  rfl

/-! ## Concrete pushes (kernel computations; the W17 anchor data) -/

/-- Height 0 (genesis-era, pre-BIP34): all four digits are zero, the strip
empties the list, and the push of the empty `CScriptNum` is the single
length byte `0x00`. -/
theorem cbHeightPush_zero : cbHeightPush 0 = ([0] : List UInt8).toByteArray := by
  rfl

/-- **The genesis-era push**: any height 0 < n < 128 is one nonzero digit
with the high bit clear, so the push is exactly `[0x01, n]`. -/
theorem cbHeightPush_one_byte_heights (h : UInt32) (hpos : 0 < h.toNat)
    (hlt : h.toNat < 128) :
    cbHeightPush h = ([1, h.toNat.toUInt8] : List UInt8).toByteArray := by
  have hd3 : (dig3 h.toNat).toNat = 0 := by simp [dig3_toNat]; omega
  have hd2 : (dig2 h.toNat).toNat = 0 := by simp [dig2_toNat]; omega
  have hd1 : (dig1 h.toNat).toNat = 0 := by simp [dig1_toNat]; omega
  have hd0 : (dig0 h.toNat).toNat ≠ 0 := by simp [dig0_toNat]; omega
  rcases digitsOf_cases h.toNat with ⟨_, z0, _, _, _, _⟩
    | ⟨hd, _, _, _, _, hb⟩ | ⟨_, _, z1, _, _⟩ | ⟨_, _, z2, _⟩ | ⟨_, z3, _⟩
  · exfalso; omega
  · rw [cbHeightPush_eq, hb, if_neg (show ¬((dig0 h.toNat).toNat ≥ 0x80) from by
      simp [dig0_toNat]; omega)]
    have hd0' : dig0 h.toNat = h.toNat.toUInt8 := by
      simp only [dig0, show h.toNat % 256 = h.toNat from by omega]
    rw [hd0']
    rfl
  · exfalso; omega
  · exfalso; omega
  · exfalso; omega

/-- Nat-flavored form of `cbHeightPush_one_byte_heights` (the literal
mission statement; `⟨n⟩` realized as `UInt32.ofNatLT`). -/
theorem cbHeightPush_one_byte_ofNat (n : Nat) (hpos : 0 < n) (hlt : n < 128) :
    cbHeightPush (UInt32.ofNatLT n (by omega : n < 4294967296)) =
      ([1, n.toUInt8] : List UInt8).toByteArray := by
  have h32 : n < 4294967296 := by omega
  have hto : (UInt32.ofNatLT n h32).toNat = n := by simp
  have hres := cbHeightPush_one_byte_heights (UInt32.ofNatLT n h32)
    (by rw [hto]; exact hpos) (by rw [hto]; exact hlt)
  rwa [hto] at hres

/-- **REAL anchor 481824** (SegWit activation; the W17 capstone run
verified this exact push against the block's coinbase): 481824 = 0x075A20,
digits `0x20 0x5A 0x07`, top digit 0x07 < 0x80 so no sign byte. -/
theorem cbHeightPush_481824 :
    cbHeightPush 481824 = ([0x03, 0x20, 0x5A, 0x07] : List UInt8).toByteArray := by
  rfl

/-- **REAL anchor 709632**: 709632 = 0x0AD400, digits `0x00 0xD4 0x0A`,
top digit 0x0A < 0x80 so no sign byte (note the interior zero digit is NOT
stripped — only MSB-side zeros are). -/
theorem cbHeightPush_709632 :
    cbHeightPush 709632 = ([0x03, 0x00, 0xD4, 0x0A] : List UInt8).toByteArray := by
  rfl

/-- The push at the BIP34 activation height itself: 227931 = 0x37A5B. -/
theorem cbHeightPush_227931 :
    cbHeightPush 227931 = ([0x03, 0x5B, 0x7A, 0x03] : List UInt8).toByteArray := by
  rfl

/-! ### Axiom footprint pins

Footprints: `∅` (no axioms), `P` = `propext`, `Q` = `Quot.sound`,
`C` = `Classical.choice` (inherited from the core layer's `bytesBEq`
decidability instance; see the module docstring note).  Everything here is
sorry-free; the pins below are checked on every build. -/

/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightBytes_eq' depends on axioms: [propext] -/
#guard_msgs in #print axioms cbHeightBytes_eq
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.foldl_push_toByteArray' does not depend on any axioms -/
#guard_msgs in #print axioms foldl_push_toByteArray
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.toByteArray_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms toByteArray_size
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightPush_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms cbHeightPush_size
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightPush_eq' depends on axioms: [propext] -/
#guard_msgs in #print axioms cbHeightPush_eq
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.dig0_toNat' depends on axioms: [propext] -/
#guard_msgs in #print axioms dig0_toNat
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.dig1_toNat' depends on axioms: [propext] -/
#guard_msgs in #print axioms dig1_toNat
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.dig2_toNat' depends on axioms: [propext] -/
#guard_msgs in #print axioms dig2_toNat
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.dig3_toNat' depends on axioms: [propext] -/
#guard_msgs in #print axioms dig3_toNat
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.dropWhile_zero_cons_false' depends on axioms: [propext] -/
#guard_msgs in #print axioms dropWhile_zero_cons_false
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.dropWhile_zero_cons_true' depends on axioms: [propext] -/
#guard_msgs in #print axioms dropWhile_zero_cons_true
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.beq_zero_of_ne' does not depend on any axioms -/
#guard_msgs in #print axioms beq_zero_of_ne
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.digitsOf_stripped' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms digitsOf_stripped
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.bytesOf_of_digits' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms bytesOf_of_digits
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.digitsOf_sh0' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms digitsOf_sh0
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.digitsOf_sh1' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms digitsOf_sh1
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.digitsOf_sh2' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms digitsOf_sh2
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.digitsOf_sh3' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms digitsOf_sh3
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.digitsOf_sh4' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms digitsOf_sh4
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.digitsOf_cases' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms digitsOf_cases
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.bip34Ok_vacuous_below' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip34Ok_vacuous_below
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.bip34Ok_push_prefix' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip34Ok_push_prefix
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightBytes_sign_rule' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms cbHeightBytes_sign_rule
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.digitsOf_length_le4' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms digitsOf_length_le4
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.bytesOf_length_le' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms bytesOf_length_le
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightPush_length_bound' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms cbHeightPush_length_bound
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightPush_length_bound31' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms cbHeightPush_length_bound31
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightPush_max' depends on axioms: [propext] -/
#guard_msgs in #print axioms cbHeightPush_max
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightPush_zero' depends on axioms: [propext] -/
#guard_msgs in #print axioms cbHeightPush_zero
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightPush_one_byte_heights' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms cbHeightPush_one_byte_heights
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightPush_one_byte_ofNat' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms cbHeightPush_one_byte_ofNat
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightPush_481824' depends on axioms: [propext] -/
#guard_msgs in #print axioms cbHeightPush_481824
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightPush_709632' depends on axioms: [propext] -/
#guard_msgs in #print axioms cbHeightPush_709632
/-- info: 'BitcoinProofs.Theorems.CapstoneBip34.cbHeightPush_227931' depends on axioms: [propext] -/
#guard_msgs in #print axioms cbHeightPush_227931

end BitcoinProofs.Theorems.CapstoneBip34
