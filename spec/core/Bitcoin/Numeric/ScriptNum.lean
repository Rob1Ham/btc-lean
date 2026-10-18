import Bitcoin.Data.Basic
import Bitcoin.RuleAttr

/-!
# Bitcoin.Numeric.ScriptNum — `CScriptNum` and the numeric-opcode layer

Lean transcription of Bitcoin Core's `CScriptNum`
(`src/script/script.h:227-394` @ `cce32b168`; verified line-by-line against
Core, `research/06-script-interpreter.md` §1.5). The frozen public signatures live in
`Numeric/Interface.lean` and delegate here.

## Core semantics mirrored (SCR-079…086)

* Decode (`CScriptNum(vch, fRequireMinimal, nMaxNumSize)`, script.h:246-271):
  * `vch.size() > nMaxNumSize` ⇒ failure (SCR-079/080);
  * under `fRequireMinimal` (consensus for the CLTV/CSV operands, the
    CHECKMULTISIG counts and CHECKSIGADD's `num`; policy otherwise via
    MINIMALDATA — B2 report §1.5): if the most-significant byte minus its
    sign bit is zero, the vector is rejected unless it is a single byte
    with nonzero low 7 bits, or the second-most-significant byte has its
    high bit set (script.h:252-268, SCR-084). This also rejects the
    negative-zero `0x80` as a number (SCR-083);
  * value = little-endian sign-magnitude (`set_vch`, script.h:376-391).
* Encode (`CScriptNum::serialize`, script.h:342-373): little-endian
  sign-magnitude; 0 ⇒ empty vector; the sign bit `0x80` rides on the
  most-significant byte; when the magnitude's top byte already has its
  high bit set a fresh `0x00` (positive) / `0x80` (negative) byte becomes
  the new most-significant byte. Core's encoder is *unconditionally
  canonical* — there is no non-minimal encoder — so the `minimal` flag on
  the frozen `encodeScriptNum` signature is accepted for interface
  symmetry and ignored (both flags give identical output).
* `CastToBool` (interpreter.cpp:46-59): an element is TRUE iff it has a
  nonzero byte, except the empty vector and the case where the *first*
  nonzero byte is the last byte and equals `0x80` (negative zero) — those
  are FALSE (SCR-057).
* `getint` (script.h:326-333): clamp to the 32-bit `int` range for the
  depth/count consumers (SCR-086).

## Representation choices

* Values are Lean `Int` (Core: `int64_t`; negatives representable).
  Int arithmetic cannot overflow, which is exactly Core's post-2010 design
  ("operands must be in the range [-2^31+1..2^31-1], but results may
  overflow and are valid as long as they are not used in a subsequent
  numeric operation", script.h:229-236): the *only* width limit is the
  byte-length limit at decode time (SCR-085).
* Byte vectors are modeled as `List Nat` (entries `< 256`) in *big-endian*
  order internally (most-significant byte first): the minimal-encoding and
  sign rules are stated on the most-significant byte, so BE makes them
  structural. Wire (LE) order appears only at the `ByteArray` bridge.
* `magBE` is fuel-recursive (the prototype's `bytesOfNumAux` pattern; interface):
  structural on fuel, so kernel `decide` reduces it in tests. Fuel 10
  covers every value decodable within the 5-byte CLTV/CSV width (and far
  beyond `int64`).

Ground truth: Bitcoin Core v32.99 @ `cce32b168` (`script.h`,
`interpreter.cpp`), cross-checked against a python3 re-implementation of
`serialize`/`set_vch` (generator `vecgen.py`; transcript in report
w2-04 §5).
-/

namespace Bitcoin.Numeric

/-! ## Byte-list bridges (`ByteArray` ↔ `List Nat`) -/

/-- `ByteArray.get!` is (propositionally) the `GetElem!` projection.
(The two unfold through different `GetElem?` instances, so `rfl` gets
stuck on the bounds `if` for a generic index.) -/
theorem get!_eq_getElem! (b : ByteArray) (i : Nat) : b.get! i = b[i]! := by
  by_cases h : i < b.size
  · simp only [ByteArray.get!, getElem!_pos b.data i h, getElem!_pos b i h]
    rfl
  · simp only [ByteArray.get!, getElem!_neg b.data i h, getElem!_neg b i h]

/-- Bytes of `b` in index order, as `Nat`s in `0..255`.
Script numbers are little-endian on the wire. -/
def bytesOf (b : ByteArray) : List Nat :=
  (List.range b.size).map (fun i => (b[i]!).toNat)

theorem bytesOf_length (b : ByteArray) : (bytesOf b).length = b.size := by
  simp [bytesOf]

theorem bytesOf_lt (b : ByteArray) : ∀ d ∈ bytesOf b, d < 256 := by
  intro d hd
  simp only [bytesOf, List.mem_map, List.mem_range] at hd
  obtain ⟨i, _, hd⟩ := hd
  simp only [← hd]
  exact UInt8.toNat_lt _

theorem bytesOf_getElem (b : ByteArray) (i : Nat) (h : i < b.size) :
    (bytesOf b)[i]'(by rw [bytesOf_length]; exact h) = (b[i]!).toNat := by
  simp [bytesOf, List.getElem_map, List.getElem_range]

theorem bytesOf_push (b : ByteArray) (x : UInt8) :
    bytesOf (b.push x) = bytesOf b ++ [x.toNat] := by
  apply List.ext_getElem
  · simp [bytesOf_length, ByteArray.size_push]
  · intro i h1 h2
    rcases Nat.lt_or_ge i b.size with h | h
    · have hp : i < (b.push x).size := by
        have := ByteArray.size_push (bs := b) (b := x)
        omega
      rw [List.getElem_append_left (show i < (bytesOf b).length by
          rw [bytesOf_length]; exact h),
        bytesOf_getElem (b.push x) i hp, ByteArray.getElem!_push_lt b x i h,
        bytesOf_getElem b i h]
    · have he : i = b.size := by
        have hs : (bytesOf (b.push x)).length = b.size + 1 := by
          rw [bytesOf_length, ByteArray.size_push (bs := b) (b := x)]
        omega
      subst he
      have hp : b.size < (b.push x).size := by
        have := ByteArray.size_push (bs := b) (b := x)
        omega
      rw [bytesOf_getElem (b.push x) b.size hp, ByteArray.getElem!_push_eq,
        List.getElem_append_right (show (bytesOf b).length ≤ b.size from by
          rw [bytesOf_length]; omega)]
      have hidx : b.size - (bytesOf b).length = 0 := by
        rw [bytesOf_length]; omega
      simp only [hidx]
      simp

/-- Build a `ByteArray` from a LE byte list (entries taken mod 256 like
`UInt8.ofNat`; canonical entries are `< 256`). -/
def bytesFromLE (l : List Nat) : ByteArray :=
  (l.map (fun n => n.toUInt8)).foldl (fun acc x => acc.push x) ByteArray.empty

theorem foldl_push_length : ∀ (l : List UInt8) (a : ByteArray),
    (l.foldl (fun acc x => acc.push x) a).size = a.size + l.length := by
  intro l
  induction l with
  | nil => intro a; simp
  | cons x r ih =>
    intro a
    rw [List.foldl_cons, ih (a.push x), ByteArray.size_push (bs := a) (b := x),
      List.length_cons]
    omega

theorem bytesFromLE_length (l : List Nat) : (bytesFromLE l).size = l.length := by
  rw [bytesFromLE, foldl_push_length]
  simp

theorem bytesOf_foldl_push : ∀ (l : List UInt8) (a : ByteArray),
    bytesOf (l.foldl (fun acc x => acc.push x) a) = bytesOf a ++ (l.map (·.toNat)) := by
  intro l
  induction l with
  | nil => intro a; simp
  | cons x r ih =>
    intro a
    rw [List.foldl_cons, ih (a.push x), bytesOf_push, List.map_cons, List.append_assoc,
      List.singleton_append]

/-- Byte-level roundtrip: `bytesOf` undoes `bytesFromLE` on canonical
(entries `< 256`) little-endian lists. -/
theorem bytesOf_bytesFromLE_aux : ∀ (l : List Nat) (a : ByteArray),
    (∀ n ∈ l, n < 256) →
    bytesOf ((l.map (fun n => n.toUInt8)).foldl (fun acc x => acc.push x) a)
      = bytesOf a ++ l := by
  intro l
  induction l with
  | nil => intro a _; simp
  | cons x r ih =>
    intro a h
    have hx : x.toUInt8.toNat = x := by
      simp [Nat.mod_eq_of_lt (h x (List.mem_cons_self ..))]
    have hmem : ∀ n ∈ r, n < 256 := fun n hn => h n (List.mem_cons_of_mem _ hn)
    rw [List.map_cons, List.foldl_cons, ih (a.push x.toUInt8) hmem, bytesOf_push, hx,
      List.append_assoc, List.singleton_append]

/-- Byte-level roundtrip: `bytesOf` undoes `bytesFromLE` on canonical
(entries `< 256`) little-endian lists. -/
theorem bytesOf_bytesFromLE :
    ∀ l : List Nat, (∀ n ∈ l, n < 256) → bytesOf (bytesFromLE l) = l := by
  intro l h
  have hempty : bytesOf (ByteArray.empty : ByteArray) = [] := rfl
  rw [bytesFromLE, bytesOf_bytesFromLE_aux l ByteArray.empty h, hempty, List.nil_append]

/-- Index `i` of the wire list, read off the reversed (BE) list:
`reverse[k-1-i] = wire[i]`. -/
theorem bytesOf_reverse_getElem (b : ByteArray) (i : Nat) (h : i < b.size) :
    (bytesOf b).reverse[b.size - 1 - i]'(by
        rw [List.length_reverse, bytesOf_length]; omega) = (b.get! i).toNat := by
  rw [get!_eq_getElem!,
    List.getElem_reverse (show b.size - 1 - i < (bytesOf b).reverse.length from by
      rw [List.length_reverse, bytesOf_length]; omega)]
  simp only [bytesOf_length, show b.size - 1 - (b.size - 1 - i) = i from by omega]
  exact bytesOf_getElem b i h

/-- Head of the BE view = last wire byte. -/
theorem bytesOf_reverse_get0 (b : ByteArray) (h : 0 < b.size) :
    (bytesOf b).reverse[0]'(by rw [List.length_reverse, bytesOf_length]; omega)
      = (b.get! (b.size - 1)).toNat := by
  rw [get!_eq_getElem!,
    List.getElem_reverse (show 0 < (bytesOf b).reverse.length from by
      rw [List.length_reverse, bytesOf_length]; omega)]
  simp only [bytesOf_length, Nat.sub_zero]
  exact bytesOf_getElem b (b.size - 1) (by omega)

/-- Second element of the BE view = second-to-last wire byte. -/
theorem bytesOf_reverse_get1 (b : ByteArray) (h : 1 < b.size) :
    (bytesOf b).reverse[1]'(by rw [List.length_reverse, bytesOf_length]; omega)
      = (b.get! (b.size - 2)).toNat := by
  rw [get!_eq_getElem!,
    List.getElem_reverse (show 1 < (bytesOf b).reverse.length from by
      rw [List.length_reverse, bytesOf_length]; omega)]
  simp only [bytesOf_length, show b.size - 1 - 1 = b.size - 2 from by omega]
  exact bytesOf_getElem b (b.size - 2) (by omega)

/-! ## Magnitude digits, big-endian (`magBEAux` / `magOfBE`) -/

/-- Big-endian base-256 digits of `n ≥ 0` (most-significant byte first),
fuel-recursive for kernel `decide`-friendliness (the prototype `bytesOfNumAux`
pattern). Exactly Core's `serialize` digit loop
(`while (absvalue) { push(absvalue & 0xff); absvalue >>= 8; }`,
script.h:355-358) read in reverse order. -/
def magBEAux : Nat → Nat → List Nat
  | 0, _ => []
  | f+1, n => if n = 0 then [] else magBEAux f (n / 256) ++ [n % 256]

/-- Fuel-10 wrapper: sufficient for every value decodable within the
5-byte CLTV/CSV width (`256^10 = 2^80` dwarfs `int64`). -/
def magBE (n : Nat) : List Nat := magBEAux 10 n

/-- Numeric value of a big-endian digit list: `d₀·256^(k-1) + … + d_{k-1}`. -/
def magOfBE : List Nat → Nat
  | [] => 0
  | d :: t => d * 256 ^ t.length + magOfBE t

theorem magOfBE_append_last (l : List Nat) (d : Nat) :
    magOfBE (l ++ [d]) = magOfBE l * 256 + d := by
  induction l with
  | nil => simp [magOfBE]
  | cons e t ih =>
    simp only [magOfBE, List.cons_append, List.length_append, List.length_singleton, ih]
    rw [Nat.pow_succ, ← Nat.mul_assoc, Nat.add_mul, ← Nat.add_assoc]

theorem magOfBE_lt : ∀ l : List Nat, (∀ d ∈ l, d < 256) → magOfBE l < 256 ^ l.length := by
  intro l
  induction l with
  | nil => intro _; simp [magOfBE]
  | cons d t ih =>
    intro h
    have hd : d < 256 := h d (List.mem_cons_self ..)
    have hmem : ∀ e ∈ t, e < 256 := fun e he => h e (List.mem_cons_of_mem _ he)
    have ht := ih hmem
    simp only [magOfBE, List.length_cons]
    rw [Nat.pow_succ]
    have key : d * 256 ^ t.length + magOfBE t < d * 256 ^ t.length + 256 ^ t.length :=
      Nat.add_lt_add_left ht _
    have h256 : 256 * 256 ^ t.length = 255 * 256 ^ t.length + 256 ^ t.length :=
      Nat.succ_mul 255 _
    have h255 : d * 256 ^ t.length ≤ 255 * 256 ^ t.length :=
      Nat.mul_le_mul_right _ (by omega)
    omega

theorem magOfBE_eq_zero_iff : ∀ l : List Nat, (∀ d ∈ l, d < 256) →
    (magOfBE l = 0 ↔ ∀ e ∈ l, e = 0) := by
  intro l
  induction l with
  | nil => intro _; simp [magOfBE]
  | cons d t ih =>
    intro h
    have hmem : ∀ e ∈ t, e < 256 := fun e he => h e (List.mem_cons_of_mem _ he)
    have hpow : 1 ≤ 256 ^ t.length := Nat.one_le_pow _ _ (by omega)
    constructor
    · intro hz
      simp only [magOfBE] at hz
      rcases Nat.add_eq_zero_iff.mp hz with ⟨hm, ht0⟩
      rcases Nat.mul_eq_zero.mp hm with hd0 | hp0
      · intro e he
        rcases List.mem_cons.mp he with rfl | he'
        · exact hd0
        · exact (ih hmem).mp ht0 e he'
      · exact absurd hp0 (by omega)
    · intro hall
      have hd0 : d = 0 := hall d (List.mem_cons_self ..)
      have ht0 : magOfBE t = 0 := (ih hmem).mpr (fun e he => hall e (List.mem_cons_of_mem _ he))
      simp [magOfBE, hd0, ht0]

theorem magBEAux_digits_lt : ∀ (f n : Nat), ∀ d ∈ magBEAux f n, d < 256 := by
  intro f
  induction f with
  | zero => intro n d hd; simp [magBEAux] at hd
  | succ f ih =>
    intro n d hd
    by_cases hn : n = 0
    · subst hn; simp [magBEAux] at hd
    · simp only [magBEAux, ite_eq_right hn, List.mem_append] at hd
      rcases hd with h | h
      · exact ih _ d h
      · simp only [List.mem_singleton] at h
        have hmod := Nat.mod_lt n (by omega : (0:Nat) < 256)
        omega

theorem magBEAux_length_le : ∀ (f k n : Nat), n < 256 ^ k → k ≤ f →
    (magBEAux f n).length ≤ k := by
  intro f
  induction f with
  | zero =>
    intro k n hk hf
    have hk0 : k = 0 := by omega
    subst hk0
    simp [magBEAux]
  | succ f ih =>
    intro k n hk hf
    by_cases hn : n = 0
    · subst hn; simp [magBEAux]
    · rcases Nat.eq_zero_or_pos k with k0 | kpos
      · subst k0
        rw [Nat.pow_zero] at hk
        omega
      · obtain ⟨k', rfl⟩ : ∃ k'', k = k'' + 1 := ⟨k - 1, by omega⟩
        rw [magBEAux, ite_eq_right hn, List.length_append, List.length_singleton]
        have hA : 1 ≤ 256 ^ k' := Nat.one_le_pow _ _ (by omega)
        rw [Nat.pow_succ] at hk
        have hk' : n / 256 < 256 ^ k' := by omega
        have hle := ih k' (n / 256) hk' (by omega)
        omega

/-- For `0 < n < 256^f` the digit list is a nonempty `d :: t` whose head
(the most-significant byte) is nonzero — the structural fact behind "the
encoder output is always minimal" (SCR-084). -/
theorem magBEAux_exists_head : ∀ (f n : Nat), 0 < n → n < 256 ^ f →
    ∃ d t, magBEAux f n = d :: t ∧ 0 < d := by
  intro f
  induction f with
  | zero =>
    intro n _ hk
    rw [Nat.pow_zero] at hk
    exact absurd hk (by omega)
  | succ f ih =>
    intro n hpos hk
    rw [magBEAux, ite_eq_right (show ¬ n = 0 from by omega)]
    rcases Nat.lt_or_ge (n / 256) 1 with h0 | hpos'
    · -- single digit: `n % 256 = n ≠ 0`
      have hzero : magBEAux f (n / 256) = [] := by
        have hz : n / 256 = 0 := by omega
        rw [hz]; cases f <;> simp [magBEAux]
      refine ⟨n % 256, [], ?_, by omega⟩
      rw [hzero]
      rfl
    · have hA : 1 ≤ 256 ^ f := Nat.one_le_pow _ _ (by omega)
      rw [Nat.pow_succ] at hk
      have hk' : n / 256 < 256 ^ f := by omega
      obtain ⟨d, t, hdt, hd⟩ := ih _ hpos' hk'
      refine ⟨d, t ++ [n % 256], ?_, hd⟩
      rw [hdt]
      rfl

theorem magOfBE_magBEAux : ∀ (f n : Nat), n < 256 ^ f → magOfBE (magBEAux f n) = n := by
  intro f
  induction f with
  | zero =>
    intro n h
    rw [Nat.pow_zero] at h
    have : n = 0 := by omega
    subst this
    simp [magBEAux, magOfBE]
  | succ f ih =>
    intro n h
    by_cases hn : n = 0
    · subst hn; simp [magBEAux, magOfBE]
    · have hA : 1 ≤ 256 ^ f := Nat.one_le_pow _ _ (by omega)
      rw [Nat.pow_succ] at h
      have hdiv : n / 256 < 256 ^ f := by omega
      rw [magBEAux, ite_eq_right hn, magOfBE_append_last, ih _ hdiv]
      omega

theorem magBE_digits_lt (n : Nat) : ∀ d ∈ magBE n, d < 256 :=
  magBEAux_digits_lt 10 n

theorem magOfBE_magBE (n : Nat) (h : n < 256 ^ 10) : magOfBE (magBE n) = n :=
  magOfBE_magBEAux 10 n h

/-- `n < 2^31` suffices for the fuel-10 wrapper. -/
theorem natAbs_lt_pow10 (n : Nat) (h : n < 2 ^ 31) : n < 256 ^ 10 := by
  have : (2 ^ 31 : Nat) < 256 ^ 10 := by decide
  omega

/-! ## `CScriptNum::serialize`: sign handling (SCR-082, SCR-085) -/

/-- `CScriptNum::serialize`'s sign handling (script.h:364-370) on
big-endian digits: prepend `0x00`/`0x80` when the top byte already has
its high bit set, else OR the sign bit into the top byte. -/
def encodeSignBE : Bool → List Nat → List Nat
  | _, [] => []
  | neg, d :: t =>
    if d < 128 then (if neg then d + 128 else d) :: t
    else (if neg then (128 : Nat) else (0 : Nat)) :: d :: t

theorem encodeSignBE_digits_lt (neg : Bool) (l : List Nat) (h : ∀ d ∈ l, d < 256) :
    ∀ d ∈ encodeSignBE neg l, d < 256 := by
  cases l with
  | nil => intro d hd; simp [encodeSignBE] at hd
  | cons a t =>
    intro d hd
    have ha : a < 256 := h a (List.mem_cons_self ..)
    by_cases hlt : a < 128
    · cases neg
      · have hout : encodeSignBE false (a :: t) = a :: t := by simp [encodeSignBE, hlt]
        rw [hout] at hd
        rcases List.mem_cons.mp hd with rfl | hd'
        · omega
        · exact h d (List.mem_cons_of_mem _ hd')
      · have hout : encodeSignBE true (a :: t) = (a + 128) :: t := by simp [encodeSignBE, hlt]
        rw [hout] at hd
        rcases List.mem_cons.mp hd with rfl | hd'
        · have := Nat.mod_lt (a + 128) (by omega : (0:Nat) < 256)
          omega
        · exact h d (List.mem_cons_of_mem _ hd')
    · cases neg
      · have hout : encodeSignBE false (a :: t) = (0 : Nat) :: a :: t := by
          simp [encodeSignBE, hlt]
        rw [hout] at hd
        rcases List.mem_cons.mp hd with rfl | hd'
        · decide
        · exact h d hd'
      · have hout : encodeSignBE true (a :: t) = (128 : Nat) :: a :: t := by
          simp [encodeSignBE, hlt]
        rw [hout] at hd
        rcases List.mem_cons.mp hd with rfl | hd'
        · decide
        · exact h d hd'

theorem encodeSignBE_length_le (neg : Bool) (l : List Nat) :
    (encodeSignBE neg l).length ≤ l.length + 1 := by
  cases l with
  | nil => simp [encodeSignBE]
  | cons a t =>
    by_cases hlt : a < 128
    · cases neg
      · have hout : encodeSignBE false (a :: t) = a :: t := by simp [encodeSignBE, hlt]
        rw [hout]; simp
      · have hout : encodeSignBE true (a :: t) = (a + 128) :: t := by simp [encodeSignBE, hlt]
        rw [hout]; simp
    · cases neg
      · have hout : encodeSignBE false (a :: t) = (0 : Nat) :: a :: t := by
          simp [encodeSignBE, hlt]
        rw [hout]; simp
      · have hout : encodeSignBE true (a :: t) = (128 : Nat) :: a :: t := by
          simp [encodeSignBE, hlt]
        rw [hout]; simp

/-! ## `set_vch`: decode value (SCR-082, SCR-083) -/

/-- `set_vch` (script.h:376-391) on a big-endian digit list: the numeric
value with the sign bit interpreted on the most-significant byte.
`0x80` as the whole vector decodes to the *negative zero* `0` (SCR-083). -/
def setVchBE : List Nat → Int
  | [] => 0
  | d :: t =>
    if d < 128 then (((d * 256 ^ t.length + magOfBE t : Nat)) : Int)
    else -((((d - 128) * 256 ^ t.length + magOfBE t : Nat)) : Int)

@[rule "SCR-083"]
theorem setVchBE_neg_zero {t : List Nat} (h : ∀ e ∈ t, e = 0) :
    setVchBE (128 :: t) = 0 := by
  have hmem : ∀ e ∈ t, e < 256 := fun e he => by rw [h e he]; omega
  have ht0 : magOfBE t = 0 := (magOfBE_eq_zero_iff t hmem).mpr h
  simp [setVchBE, ht0]

theorem setVchBE_encodeSignBE : ∀ (neg : Bool) (l : List Nat),
    setVchBE (encodeSignBE neg l) =
      if neg then -(((magOfBE l : Nat) : Int)) else ((magOfBE l : Nat) : Int) := by
  intro neg l
  cases l with
  | nil => cases neg <;> simp [encodeSignBE, setVchBE, magOfBE]
  | cons d t =>
    by_cases hlt : d < 128
    · cases neg
      · have hout : encodeSignBE false (d :: t) = d :: t := by simp [encodeSignBE, hlt]
        rw [hout]; simp [setVchBE, magOfBE, hlt]
      · have hout : encodeSignBE true (d :: t) = (d + 128) :: t := by simp [encodeSignBE, hlt]
        have hsub : (d + 128 : Nat) - 128 = d := by omega
        have hge : ¬ (d + 128 : Nat) < 128 := by omega
        rw [hout, setVchBE, ite_eq_right hge, hsub, magOfBE]
        simp
    · cases neg
      · have hout : encodeSignBE false (d :: t) = (0 : Nat) :: d :: t := by
          simp [encodeSignBE, hlt]
        rw [hout]; simp [setVchBE, magOfBE]
      · have hout : encodeSignBE true (d :: t) = (128 : Nat) :: d :: t := by
          simp [encodeSignBE, hlt]
        rw [hout]; simp [setVchBE, magOfBE]

/-! ## The minimal-encoding rule (SCR-084) -/

/-- Minimal-encoding check (script.h:252-268) on a big-endian digit list:
reject (return `false`) iff the most-significant byte minus its sign bit
is zero **and** (the vector is a single byte **or** the second-byte's
high bit is clear). The one-byte `0x80` (negative zero) is rejected too
(SCR-083). -/
def minimalOkBE : List Nat → Bool
  | [] => true
  | d :: t =>
    if d % 128 = 0 then
      match t with
      | [] => false
      | e :: _ => decide (e ≥ 128)
    else true

/-- The canonical encoder output always passes the minimal-encoding check
— the roundtrip invariant Core relies on (`getvch` → `CScriptNum`). -/
theorem minimalOkBE_encodeSignBE : ∀ (neg : Bool) (l : List Nat),
    (∀ d ∈ l, d < 256) → (∃ d t, l = d :: t ∧ 0 < d) →
    minimalOkBE (encodeSignBE neg l) = true := by
  intro neg l hdigits hex
  obtain ⟨d, t, hcons, hdpos⟩ := hex
  subst hcons
  by_cases hlt : d < 128
  · cases neg
    · have hout : encodeSignBE false (d :: t) = d :: t := by simp [encodeSignBE, hlt]
      rw [hout]
      simp only [minimalOkBE, ite_eq_right (show d % 128 ≠ 0 from by
        rw [Nat.mod_eq_of_lt hlt]; omega)]
    · have hout : encodeSignBE true (d :: t) = (d + 128) :: t := by simp [encodeSignBE, hlt]
      rw [hout]
      simp only [minimalOkBE, ite_eq_right (show (d + 128) % 128 ≠ 0 from by omega)]
  · have hge128 : decide (d ≥ 128) = true := decide_eq_true (by omega : d ≥ 128)
    cases neg
    · have hout : encodeSignBE false (d :: t) = (0 : Nat) :: d :: t := by
        simp [encodeSignBE, hlt]
      rw [hout, minimalOkBE, ite_eq_left (show (0 : Nat) % 128 = 0 from by omega)]
      exact hge128
    · have hout : encodeSignBE true (d :: t) = (128 : Nat) :: d :: t := by
        simp [encodeSignBE, hlt]
      rw [hout, minimalOkBE, ite_eq_left (show (128 : Nat) % 128 = 0 from by omega)]
      exact hge128

/-! ## Assembled `CScriptNum` encode/decode -/

/-- Full canonical encode (`getvch` = `serialize(m_value)`, script.h:368-372):
sign-magnitude LE on the wire; here in BE order, reversed at the bridge. -/
def scriptNumBE (n : Int) : List Nat := encodeSignBE (decide (n < 0)) (magBE n.natAbs)

theorem scriptNumBE_digits_lt (n : Int) : ∀ d ∈ scriptNumBE n, d < 256 :=
  encodeSignBE_digits_lt _ _ (magBE_digits_lt _)

theorem scriptNumBE_value (n : Int) (h : n.natAbs < 256 ^ 10) :
    setVchBE (scriptNumBE n) = n := by
  show setVchBE (encodeSignBE (decide (n < 0)) (magBE n.natAbs)) = n
  rw [setVchBE_encodeSignBE, magOfBE_magBE n.natAbs h]
  rcases Int.lt_trichotomy n 0 with hneg | h0 | hpos
  · rw [ite_eq_left (decide_eq_true hneg), Int.ofNat_natAbs_of_nonpos (by omega : n ≤ 0)]
    simp
  · subst h0; simp
  · rw [ite_eq_right (by rw [decide_eq_true_eq]; omega),
      Int.ofNat_natAbs_of_nonneg (by omega : 0 ≤ n)]

theorem scriptNumBE_length_le (n : Int) (k : Nat) (h : n.natAbs < 256 ^ k) (hk : k ≤ 9) :
    (scriptNumBE n).length ≤ k + 1 := by
  show (encodeSignBE (decide (n < 0)) (magBEAux 10 n.natAbs)).length ≤ k + 1
  have hmag := magBEAux_length_le 10 k n.natAbs h (by omega)
  have h2 := Nat.add_le_add_right hmag 1
  exact Nat.le_trans (encodeSignBE_length_le _ _) h2

/-- The 4-byte story (SCR-080/085): a value with `|n| < 2^31` — exactly
the decode-acceptable range at width 4 — re-encodes to **at most 4**
bytes. The tightness comes from the sign-bit analysis: if the magnitude's
top byte already had its high bit set, `|n| ≥ 2^31`. -/
theorem scriptNumBE_length_le4 (n : Int) (h : n.natAbs < 2 ^ 31) :
    (scriptNumBE n).length ≤ 4 := by
  by_cases h0 : n = 0
  · subst h0
    simp [scriptNumBE, magBE, magBEAux, encodeSignBE]
  · have hpos : 0 < n.natAbs := by
      have : n.natAbs ≠ 0 := fun hc => h0 (Int.natAbs_eq_zero.mp hc)
      omega
    have h10 : n.natAbs < 256 ^ 10 := natAbs_lt_pow10 _ h
    obtain ⟨d, t, hdt0, hdpos⟩ := magBEAux_exists_head 10 n.natAbs hpos h10
    have hdt : magBE n.natAbs = d :: t := hdt0
    have hmemd : d ∈ magBE n.natAbs := by rw [hdt]; exact List.mem_cons_self ..
    have hdlt : d < 256 := magBE_digits_lt _ _ hmemd
    have hval : magOfBE (d :: t) = n.natAbs := by
      rw [← hdt]; exact magOfBE_magBE n.natAbs h10
    have hnv : n.natAbs = d * 256 ^ t.length + magOfBE t := by
      have hvmag : magOfBE (d :: t) = d * 256 ^ t.length + magOfBE t := rfl
      omega
    rcases Nat.lt_or_ge d 128 with hlt | hge
    · -- no extra byte: length = |t| + 1; |t| ≤ 3 since 256^|t| ≤ |n| < 2^31 < 256^4
      have hlen : (scriptNumBE n).length = t.length + 1 := by
        show (encodeSignBE (decide (n < 0)) (magBE n.natAbs)).length = _
        rw [hdt]
        cases hb : decide (n < 0) <;> simp [encodeSignBE, hlt, List.length_cons]
      have hge1 : 256 ^ t.length ≤ n.natAbs := by
        have h1 : 1 * 256 ^ t.length ≤ d * 256 ^ t.length :=
          Nat.mul_le_mul_right _ (by omega)
        omega
      rcases Nat.lt_or_ge t.length 4 with hk | hk
      · omega
      · exfalso
        have h4 : (256 ^ 4 : Nat) ≤ 256 ^ t.length := Nat.pow_le_pow_right (by omega) hk
        have h32 : (2 ^ 31 : Nat) < 256 ^ 4 := by decide
        omega
    · -- extra byte: length = |t| + 2; |t| ≤ 2 since 128·256^|t| ≤ |n| < 2^31
      have hlen : (scriptNumBE n).length = t.length + 2 := by
        show (encodeSignBE (decide (n < 0)) (magBE n.natAbs)).length = _
        rw [hdt, encodeSignBE, ite_eq_right (show ¬(d < 128) from by omega)]
        cases hb : decide (n < 0) <;> simp [List.length_cons]
      have hge1 : 128 * 256 ^ t.length ≤ n.natAbs := by
        have h1 : 128 * 256 ^ t.length ≤ d * 256 ^ t.length :=
          Nat.mul_le_mul_right _ (by omega)
        omega
      rcases Nat.lt_or_ge t.length 3 with hk | hk
      · omega
      · exfalso
        have h3 : (128 * 256 ^ 3 : Nat) ≤ 128 * 256 ^ t.length :=
          Nat.mul_le_mul_left 128 (Nat.pow_le_pow_right (by omega) hk)
        have heq : (128 * 256 ^ 3 : Nat) = 2 ^ 31 := by decide
        omega

theorem minimalOkBE_scriptNumBE (n : Int) (h : n.natAbs < 256 ^ 10) :
    minimalOkBE (scriptNumBE n) = true := by
  by_cases h0 : n = 0
  · subst h0
    simp [scriptNumBE, magBE, magBEAux, encodeSignBE, minimalOkBE]
  · have hpos : 0 < n.natAbs := by
      have : n.natAbs ≠ 0 := fun hc => h0 (Int.natAbs_eq_zero.mp hc)
      omega
    obtain ⟨d, t, hdt0, hdpos⟩ := magBEAux_exists_head 10 n.natAbs hpos h
    have hcons : magBE n.natAbs = d :: t := hdt0
    exact minimalOkBE_encodeSignBE _ _ (magBE_digits_lt _) ⟨d, t, hcons, hdpos⟩

/-! ## Decode (`CScriptNum` constructor, script.h:246-271) -/

/-- Decode on a big-endian digit list: width check (SCR-079/080),
optional minimal check (SCR-084), then `set_vch` (SCR-082). -/
def decodeBE (minimal : Bool) (maxSize : Nat) (l : List Nat) : Option Int :=
  if l.length > maxSize then none
  else if minimal ∧ ¬ minimalOkBE l then none
  else some (setVchBE l)

theorem decodeBE_some {minimal : Bool} {maxSize : Nat} {l : List Nat}
    (hlen : l.length ≤ maxSize) (hmin : minimal = false ∨ minimalOkBE l = true) :
    decodeBE minimal maxSize l = some (setVchBE l) := by
  rw [decodeBE, ite_eq_right (show ¬ l.length > maxSize from by omega)]
  by_cases h2 : minimal ∧ ¬ minimalOkBE l
  · rcases hmin with h | h
    · simp [h] at h2
    · simp [h] at h2
  · rw [ite_eq_right h2]

/-! ## `CastToBool` (interpreter.cpp:46-59) -/

/-- `CastToBool` on a big-endian digit list: false iff all bytes are zero
or the only nonzero byte is a lone sign bit (`0x80`) in the
most-significant position (the negative-zero caveat). -/
def castToBoolList (l : List Nat) : Bool :=
  match l with
  | [] => false
  | d :: t => t.any (fun e => e ≠ 0) || decide (d ≠ 0 ∧ d ≠ 128)

/-- `CastToBool` agrees with the numeric value being nonzero, on every
byte vector with bytes `< 256` — including the negative-zero corner:
`[0x80]` decodes to `0` and casts to `false` (SCR-057, SCR-083). -/
theorem castToBoolList_iff : ∀ l : List Nat, (∀ d ∈ l, d < 256) →
    (castToBoolList l = true ↔ setVchBE l ≠ 0) := by
  intro l
  induction l with
  | nil => intro _; simp [castToBoolList, setVchBE]
  | cons d t ih =>
    intro h
    have hmem : ∀ e ∈ t, e < 256 := fun e he => h e (List.mem_cons_of_mem _ he)
    have hmag : magOfBE t = 0 ↔ ∀ e ∈ t, e = 0 := magOfBE_eq_zero_iff t hmem
    have hset : setVchBE (d :: t) =
        if d < 128 then (((d * 256 ^ t.length + magOfBE t : Nat)) : Int)
        else -((((d - 128) * 256 ^ t.length + magOfBE t : Nat)) : Int) := rfl
    have hpow : 1 ≤ 256 ^ t.length := Nat.one_le_pow _ _ (by omega)
    by_cases ha : t.any (fun e => e ≠ 0)
    · -- `t` has a nonzero byte: the value is nonzero (its magnitude is) …
      obtain ⟨e, he, hne⟩ := List.any_eq_true.mp ha
      have hpos : 0 < magOfBE t := by
        rcases Nat.eq_zero_or_pos (magOfBE t) with h0 | h0
        · exact absurd (hmag.mp h0 e he) (of_decide_eq_true hne)
        · exact h0
      refine ⟨fun _ => ?_, fun _ => ?_⟩
      · rw [hset]
        split
        · intro hz
          rw [Int.ofNat_eq_zero, Nat.add_eq_zero_iff, Nat.mul_eq_zero] at hz
          obtain ⟨hm, hm0⟩ := hz
          rcases hm with h' | h'
          · omega
          · exact absurd hm0 (Nat.ne_of_gt hpos)
        · intro hz
          have hx : (((d - 128) * 256 ^ t.length + magOfBE t : Nat) : Int) = 0 := by
            omega
          rw [Int.ofNat_eq_zero, Nat.add_eq_zero_iff, Nat.mul_eq_zero] at hx
          obtain ⟨hm, hm0⟩ := hx
          rcases hm with h' | h'
          · omega
          · exact absurd hm0 (Nat.ne_of_gt hpos)
      · rw [castToBoolList, ha]; rfl
    · -- `t` is all zeros: both sides reduce to `d ∉ {0, 128}`
      have haf : t.any (fun e => e ≠ 0) = false := by
        cases hb : t.any (fun e => e ≠ 0) with
        | false => rfl
        | true => exact absurd hb ha
      have ht0 : magOfBE t = 0 := hmag.mpr (by
        intro e he
        rcases Nat.eq_zero_or_pos e with h0 | h0
        · exact h0
        · exact absurd (List.any_eq_true.mpr ⟨e, he, decide_eq_true (Nat.ne_of_gt h0)⟩) ha)
      refine ⟨fun hc => ?_, fun hv => ?_⟩
      · rw [castToBoolList, haf, Bool.false_or, decide_eq_true_iff] at hc
        rw [hset, ht0]
        rcases Nat.lt_or_ge d 128 with hlt | hge
        · rw [ite_eq_left hlt, Nat.add_zero]
          intro hz
          rw [Int.ofNat_eq_zero, Nat.mul_eq_zero] at hz
          rcases hz with h' | h'
          · exact absurd h' hc.1
          · omega
        · rw [ite_eq_right (show ¬(d < 128) from by omega), Nat.add_zero]
          intro hz
          have hx : (((d - 128) * 256 ^ t.length : Nat) : Int) = 0 := by
            omega
          rw [Int.ofNat_eq_zero, Nat.mul_eq_zero] at hx
          rcases hx with h' | h'
          · omega
          · omega
      · rw [hset, ht0] at hv
        rcases Nat.lt_or_ge d 128 with hlt | hge
        · rw [ite_eq_left hlt, Nat.add_zero] at hv
          rw [castToBoolList, haf, Bool.false_or, decide_eq_true_iff]
          refine ⟨?_, by omega⟩
          intro hz
          rw [hz] at hv; simp at hv
        · rw [ite_eq_right (show ¬(d < 128) from by omega), Nat.add_zero] at hv
          rw [castToBoolList, haf, Bool.false_or, decide_eq_true_iff]
          refine ⟨by omega, ?_⟩
          intro hz
          rw [hz] at hv; simp at hv

/-! ## `getint` clamping (SCR-086) -/

/-- `CScriptNum::getint` (script.h:326-333): clamp to the 32-bit `int`
range (the depth/count consumers; `int` is 32-bit on all platforms Core
supports). -/
@[rule "SCR-086"]
def getIntClamped (n : Int) : Int :=
  if 2147483647 < n then 2147483647
  else if n < -2147483648 then -2147483648
  else n

theorem getIntClamped_in_range (n : Int) :
    -2147483648 ≤ getIntClamped n ∧ getIntClamped n ≤ 2147483647 := by
  unfold getIntClamped
  split
  · exact ⟨by decide, by decide⟩
  · split
    · exact ⟨by decide, by decide⟩
    · omega

theorem getIntClamped_id {n : Int} (h : -2147483648 ≤ n) (h2 : n ≤ 2147483647) :
    getIntClamped n = n := by
  unfold getIntClamped
  split
  · omega
  · split
    · omega
    · rfl

theorem getIntClamped_max {n : Int} (h : 2147483647 < n) :
    getIntClamped n = 2147483647 := by
  unfold getIntClamped
  rw [ite_eq_left h]

theorem getIntClamped_min {n : Int} (h : n < -2147483648) :
    getIntClamped n = -2147483648 := by
  unfold getIntClamped
  rw [ite_eq_right (by omega), ite_eq_left h]

end Bitcoin.Numeric
