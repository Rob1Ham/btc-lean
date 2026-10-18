import Bitcoin.Data.Basic
import Bitcoin.Crypto.Curve.Mod

/-!
# Bitcoin.Crypto.Field — FROZEN INTERFACE

## Interface contract (do not edit outside an interface-change PR)

Core counterpart files: src/crypto/secp256k1 (subtree): field_5x52_impl.h,
                        field.h (secp256k1_fe), modinv64 (safegcd —
                        Wuille'26 verified-inversion lineage)
Status: frozen 2026-10-16. Statements are
                        sorry-stubbed placeholders; the bodies are filled separately.

## Scope (2A slot)

F_p arithmetic for p = 2^256 - 2^32 - 977, modular inverse, and the
inverse-correctness theorem. NO mathlib in core: `Fe` is a Subtype of
Nat (invalid states unrepresentable, design tier L1). If later needs
mathlib's `ZMod`, the swap happens via interface-change PR + a proven
abstraction lemma (same pattern as the UTXO set).

Representation is deliberately abstract: ALL theorems are stated over
`Fe` + the field laws, never over the bit layout.

## FILL NOTE (P01, 2026-10-16)

The four `opaque` placeholders were replaced by `def`s of byte-identical
type, delegating to `Bitcoin.Crypto.Curve.Mod` (`addM/mulM/subM/invM`).
Reason (finding, mirrors FILL HISTORY in `Curve/Interface.lean`):
`opaque f := body` is kernel-opaque — `rfl`, `unfold`, `delta`,
`simp only`, `decide`, `show` all fail to see through it — so no theorem
about the bodies can be proved while they stay `opaque`.

`feInv_correct` needs "every 0 < d < P is invertible mod P", i.e. the
primality of P. Core has no mathlib (hence no `Nat.Prime`, no mathlib
`lucas_primality`), so a self-contained Lucas/Pratt development is included
below:

* pigeonhole over `Nat` ranges (`pig_count`/`pig_hole`/`pig_surj`),
* fuel-based least-divisor scan and trial-division `primeTest`,
* `leastPowAux` + `leastPow_spec` (multiplicative order of `a` mod `N`),
* abstract-atom order lemmas `order_dvd`/`order_eq` (keeping `omega` away
  from composite `leastPowAux`-atoms and live `∃`-hypotheses — both pull
  `Classical.choice` into otherwise constructive proofs), and
* `lucas_primality` over `Nat`, axiom footprint `[propext, Quot.sound]`.

The 6-level Pratt certificate (Sbig → Qbig → Rbig → Qtwo → Cbig → P; the
same sympy-verified data as the proofs-package `CurveZMod.lean`) discharges
every per-level Lucas step through the kernel-reducible STRUCTURAL
`Mod.expBits` over literal bit lists (§5 lesson: never kernel-evaluate
`Nat.pow` at 256-bit exponents). All witness checks are `decide`s against
`Mod.expBits`/`Mod.bitsVal`; small primes are kernel trial divisions. No
`native_decide` anywhere. Axiom footprints: the primality layer needs only
`[propext, Quot.sound]`; `feInv_correct` additionally carries
`Classical.choice` — inherited verbatim from the delegate
`Mod.invM_correct`, which already uses it, so the footprint equals
the generalized-from layer's exactly.
-/


namespace Bitcoin.Crypto.Field

/-! ## The field prime and the element type (unchanged, the frozen interface) -/

/-- The secp256k1 field prime p = 2^256 − 2^32 − 977. -/
def P : Nat :=
  2^256 - 2^32 - 977

/-- Field element: { x : Nat // x < P } — invalid states unrepresentable. -/
abbrev Fe := { x : Nat // x < P }

/-- Zero and one. -/
def feZero : Fe := ⟨0, by decide⟩

def feOne : Fe := ⟨1, by decide⟩

theorem P_pos : 0 < P := by decide

theorem P_gt_one : 1 < P := by decide

open Bitcoin.Crypto.Curve.Mod

/-! ## Pigeonhole (classical-free, over `Nat` ranges) -/

/-- Does `f` take the value `v` somewhere on `[0, d)`? (structural scan) -/
private def hitScan (f : Nat → Nat) (v : Nat) : Nat → Bool
  | 0 => false
  | d + 1 => (f d == v) || hitScan f v d

private theorem beq_false_ne {a b : Nat} (h : (a == b) = false) : a ≠ b := by
  intro he
  rw [he] at h
  have h2 : (b == b) = true := Nat.beq_refl b
  rw [h2] at h
  exact absurd h (by decide)

private theorem hitScan_eq_true {f : Nat → Nat} {v d : Nat} (h : hitScan f v d = true) :
    ∃ i, i < d ∧ f i = v := by
  induction d with
  | zero => simp [hitScan] at h
  | succ d IH =>
    simp only [hitScan, Bool.or_eq_true, beq_iff_eq] at h
    rcases h with h | h
    · exact ⟨d, by omega, h⟩
    · obtain ⟨i, hi, he⟩ := IH h
      exact ⟨i, by omega, he⟩

private theorem hitScan_eq_false {f : Nat → Nat} {v d : Nat} (h : hitScan f v d = false) :
    ∀ i, i < d → f i ≠ v := by
  induction d with
  | zero => intro i hi; omega
  | succ d IH =>
    intro i hi
    simp only [hitScan, Bool.or_eq_false_iff] at h
    rcases Nat.lt_or_ge i d with hlt | hle
    · exact IH h.2 i hlt
    · rcases Nat.lt_or_ge i (d + 1) with hlt | _
      · have : i = d := by omega
        subst this
        exact beq_false_ne h.1
      · omega

/-- Pigeonhole: `d` pairwise-distinct values in `[1, hi)` force `d + 1 ≤ hi`. -/
private theorem pig_count : ∀ (hi d : Nat) (f : Nat → Nat), 0 < hi →
    (∀ i j, i < d → j < d → f i = f j → i = j) →
    (∀ i, i < d → 1 ≤ f i ∧ f i < hi) → d + 1 ≤ hi := by
  intro hi
  induction hi with
  | zero => intro d f h0 _ _; exact absurd h0 (by omega)
  | succ hi IH =>
    intro d f _ hinj hrange
    rcases Nat.lt_trichotomy d hi with hlt | heq | hgt
    · omega
    · omega
    · exfalso
      cases hs : hitScan f hi d with
      | false =>
        -- no `i < d` has `f i = hi`, so all values lie in `[1, hi)`
        have hall := hitScan_eq_false hs
        have hdpos : 0 < d := by omega
        obtain ⟨_, hf0⟩ := hrange 0 hdpos
        have hrange' : ∀ i, i < d → 1 ≤ f i ∧ f i < hi := by
          intro i hi'
          obtain ⟨h1, h2⟩ := hrange i (by omega)
          have hne := hall i (by omega)
          exact ⟨h1, by omega⟩
        have := IH d f (by omega) hinj hrange'
        have hge : hi + 1 ≤ d := by omega
        omega
      | true =>
        obtain ⟨i0, hi0, hfi0⟩ := hitScan_eq_true hs
        have hdpos : 0 < d := by omega
        obtain ⟨_, hf0⟩ := hrange 0 hdpos
        -- reindex, skipping the index `i0` that hits the top value `hi`
        have key : ∀ j, j < d - 1 → (if j < i0 then j else j + 1) < d := by
          intro j hj
          rcases Nat.lt_or_ge j i0 with h | h
          · rw [ite_eq_left h]; omega
          · rw [ite_eq_right (by omega : ¬(j < i0))]; omega
        have hinj' : ∀ i j, i < d - 1 → j < d - 1 →
            f (if i < i0 then i else i + 1) = f (if j < i0 then j else j + 1) → i = j := by
          intro i j hi' hj' heq
          rcases Nat.lt_or_ge i i0 with h1 | h1 <;> rcases Nat.lt_or_ge j i0 with h2 | h2
          · rw [ite_eq_left h1, ite_eq_left h2] at heq; exact hinj i j (by omega) (by omega) heq
          · rw [ite_eq_left h1, ite_eq_right (by omega : ¬(j < i0))] at heq
            have := hinj i (j + 1) (by omega) (by omega) heq
            omega
          · rw [ite_eq_right (by omega : ¬(i < i0)), ite_eq_left h2] at heq
            have := hinj (i + 1) j (by omega) (by omega) heq
            omega
          · rw [ite_eq_right (by omega : ¬(i < i0)), ite_eq_right (by omega : ¬(j < i0))] at heq
            have := hinj (i + 1) (j + 1) (by omega) (by omega) heq
            omega
        have hrange' : ∀ i, i < d - 1 → 1 ≤ f (if i < i0 then i else i + 1) ∧
            f (if i < i0 then i else i + 1) < hi := by
          intro i hi'
          have hlt := key i hi'
          obtain ⟨h1, h2⟩ := hrange _ hlt
          refine ⟨h1, ?_⟩
          have hne : (if i < i0 then i else i + 1) ≠ i0 := by
            rcases Nat.lt_or_ge i i0 with h | h
            · rw [ite_eq_left h]; omega
            · rw [ite_eq_right (by omega : ¬(i < i0))]; omega
          have hneq : f (if i < i0 then i else i + 1) ≠ f i0 := fun heq =>
            hne (hinj _ i0 hlt hi0 heq)
          omega
        have := IH (d - 1) (fun j => f (if j < i0 then j else j + 1)) (by omega) hinj' hrange'
        omega

/-- Pigeonhole (hole form): `d` pairwise-distinct values in `[1, hi)`, all
avoiding `v ∈ [1, hi)`, force `d + 2 ≤ hi`. -/
private theorem pig_hole : ∀ (hi d : Nat) (f : Nat → Nat) (v : Nat), 1 ≤ v → v < hi →
    (∀ i j, i < d → j < d → f i = f j → i = j) →
    (∀ i, i < d → 1 ≤ f i ∧ f i < hi) →
    (∀ i, i < d → f i ≠ v) → d + 2 ≤ hi := by
  intro hi
  induction hi with
  | zero => intro d f v h0 _ _ _ _; omega
  | succ hi IH =>
    intro d f v hv1 hv hinj hrange hne
    rcases Nat.lt_or_ge v hi with hvlt | hvge
    · -- `v < hi`: split on whether the top value `hi` is hit
      have hhipos : 0 < hi := by omega
      cases hs : hitScan f hi d with
      | false =>
        have hrange' : ∀ i, i < d → 1 ≤ f i ∧ f i < hi := by
          intro i hi'
          obtain ⟨h1, h2⟩ := hrange i hi'
          have hne' := hitScan_eq_false hs i hi'
          exact ⟨h1, by omega⟩
        have h1 := IH d f v hv1 hvlt hinj hrange' hne
        omega
      | true =>
        obtain ⟨i0, hi0, hfi0⟩ := hitScan_eq_true hs
        have key : ∀ j, j < d - 1 → (if j < i0 then j else j + 1) < d := by
          intro j hj
          rcases Nat.lt_or_ge j i0 with h | h
          · rw [ite_eq_left h]; omega
          · rw [ite_eq_right (by omega : ¬(j < i0))]; omega
        have hinj' : ∀ i j, i < d - 1 → j < d - 1 →
            f (if i < i0 then i else i + 1) = f (if j < i0 then j else j + 1) → i = j := by
          intro i j hi' hj' heq
          rcases Nat.lt_or_ge i i0 with h1 | h1 <;> rcases Nat.lt_or_ge j i0 with h2 | h2
          · rw [ite_eq_left h1, ite_eq_left h2] at heq; exact hinj i j (by omega) (by omega) heq
          · rw [ite_eq_left h1, ite_eq_right (by omega : ¬(j < i0))] at heq
            have := hinj i (j + 1) (by omega) (by omega) heq
            omega
          · rw [ite_eq_right (by omega : ¬(i < i0)), ite_eq_left h2] at heq
            have := hinj (i + 1) j (by omega) (by omega) heq
            omega
          · rw [ite_eq_right (by omega : ¬(i < i0)), ite_eq_right (by omega : ¬(j < i0))] at heq
            have := hinj (i + 1) (j + 1) (by omega) (by omega) heq
            omega
        have hrange' : ∀ i, i < d - 1 → 1 ≤ f (if i < i0 then i else i + 1) ∧
            f (if i < i0 then i else i + 1) < hi := by
          intro i hi'
          have hlt := key i hi'
          obtain ⟨h1, h2⟩ := hrange _ hlt
          refine ⟨h1, ?_⟩
          have hneX : (if i < i0 then i else i + 1) ≠ i0 := by
            rcases Nat.lt_or_ge i i0 with h | h
            · rw [ite_eq_left h]; omega
            · rw [ite_eq_right (by omega : ¬(i < i0))]; omega
          have hneq : f (if i < i0 then i else i + 1) ≠ f i0 := by
            intro heq2
            exact hneX (hinj _ i0 hlt hi0 heq2)
          omega
        have h1 := IH (d - 1) (fun j => f (if j < i0 then j else j + 1)) v hv1 hvlt
          hinj' hrange' (fun i hi' => hne _ (key i hi'))
        omega
    · -- `v = hi`
      have hveq : v = hi := by omega
      have hhipos : 0 < hi := by omega
      cases hs : hitScan f hi d with
      | false =>
        have hrange' : ∀ i, i < d → 1 ≤ f i ∧ f i < hi := by
          intro i hi'
          obtain ⟨h1, h2⟩ := hrange i hi'
          have hne' := hitScan_eq_false hs i hi'
          exact ⟨h1, by omega⟩
        have := pig_count hi d f hhipos hinj hrange'
        omega
      | true =>
        obtain ⟨i0, hi0, hfi0⟩ := hitScan_eq_true hs
        exact absurd hfi0 (fun heq => hne i0 hi0 (hveq ▸ heq))

/-- Pigeonhole (surjective form): `d = hi - 1` pairwise-distinct values in
`[1, hi)` cover every `v ∈ [1, hi)`. -/
private theorem pig_surj : ∀ (hi d : Nat) (f : Nat → Nat), d + 1 = hi →
    (∀ i j, i < d → j < d → f i = f j → i = j) →
    (∀ i, i < d → 1 ≤ f i ∧ f i < hi) →
    ∀ v, 1 ≤ v → v < hi → ∃ i, i < d ∧ f i = v := by
  intro hi d f hd hinj hrange v hv1 hv2
  cases hs : hitScan f v d with
  | true => exact hitScan_eq_true hs
  | false =>
    exfalso
    have hne : ∀ i, i < d → f i ≠ v := hitScan_eq_false hs
    have := pig_hole hi d f v hv1 (by omega) hinj hrange hne
    omega


/-! ## Least divisor scan and trial-division primality test -/

/-- Least divisor of `m` in `[lo, lo + fuel)`, or `0` if the fuel runs out. -/
private def leastDivFrom (m fuel lo : Nat) : Nat :=
  match fuel with
  | 0 => 0
  | fuel + 1 => if m < lo then 0 else if m % lo = 0 then lo else leastDivFrom m fuel (lo + 1)

private theorem leastDivFrom_pos : ∀ (fuel lo m : Nat), 1 ≤ lo → lo ≤ m → m < lo + fuel →
    0 < leastDivFrom m fuel lo := by
  intro fuel
  induction fuel with
  | zero => intro lo m h1 h2 h3; omega
  | succ fuel IH =>
    intro lo m h1 h2 h3
    rw [leastDivFrom]
    have hm : ¬ (m < lo) := by omega
    rw [ite_eq_right hm]
    by_cases hd : m % lo = 0
    · rw [ite_eq_left hd]; exact h1
    · rw [ite_eq_right hd]
      have hlt : lo < m := by
        rcases Nat.lt_or_ge lo m with h | h
        · exact h
        · have heq : lo = m := by omega
          rw [heq, Nat.mod_self] at hd
          exact absurd hd (by omega)
      exact IH (lo + 1) m (by omega) hlt (by omega)

private theorem leastDivFrom_spec : ∀ (fuel lo m : Nat) (d : Nat),
    leastDivFrom m fuel lo = d → 0 < d →
    lo ≤ d ∧ d ∣ m ∧ ∀ s, lo ≤ s → s < d → m % s ≠ 0 := by
  intro fuel
  induction fuel with
  | zero => intro lo m d h hd; rw [leastDivFrom] at h; exact absurd hd (by omega)
  | succ fuel IH =>
    intro lo m d h hd
    rw [leastDivFrom] at h
    have hm : ¬ (m < lo) := by
      intro hml
      rw [ite_eq_left hml] at h
      omega
    rw [ite_eq_right hm] at h
    by_cases hmod : m % lo = 0
    · rw [ite_eq_left hmod] at h
      have hdeq : lo = d := by omega
      subst hdeq
      refine ⟨Nat.le_refl lo, Nat.dvd_of_mod_eq_zero hmod, ?_⟩
      intro s hs hlt
      omega
    · rw [ite_eq_right hmod] at h
      obtain ⟨h1, h2, h3⟩ := IH (lo + 1) m d h hd
      refine ⟨Nat.le_trans (Nat.le_succ lo) h1, h2, ?_⟩
      intro s hs hlt
      rcases Nat.lt_or_ge s (lo + 1) with hlt' | hlt'
      · have hse : s = lo := by omega
        rw [hse]
        exact hmod
      · exact h3 s (by omega) hlt

/-- The least divisor `d ≥ 2` of a composite `m` satisfies `d * d ≤ m`. -/
private theorem leastDiv_sqrt : ∀ (m k : Nat), 2 ≤ m → k ∣ m → 2 ≤ k → k < m →
    ∃ d, 2 ≤ d ∧ d ∣ m ∧ d * d ≤ m := by
  intro m k hm hk2 hkm hkm'
  have hpos : 0 < leastDivFrom m m 2 :=
    leastDivFrom_pos m 2 m (by omega) (by omega) (by omega)
  obtain ⟨hd2, hddvd, hdmin⟩ := leastDivFrom_spec m 2 m _ rfl hpos
  refine ⟨leastDivFrom m m 2, hd2, hddvd, ?_⟩
  -- `d ≤ k` by minimality
  have hdk : leastDivFrom m m 2 ≤ k := by
    rcases Nat.lt_or_ge k (leastDivFrom m m 2) with h | h
    · exact absurd (Nat.mod_eq_zero_of_dvd hk2) (hdmin k hkm h)
    · exact h
  have hdm : leastDivFrom m m 2 < m := by omega
  -- `j := m / d` is a divisor of `m`, `2 ≤ j`, hence `j ≥ d` by minimality
  have hjudge : leastDivFrom m m 2 * (m / leastDivFrom m m 2) = m :=
    Nat.mul_div_cancel' hddvd
  have hjdvd : (m / leastDivFrom m m 2) ∣ m :=
    ⟨leastDivFrom m m 2, (Nat.div_mul_cancel hddvd).symm⟩
  have hj2 : 2 ≤ m / leastDivFrom m m 2 := by
    have h1 : m / leastDivFrom m m 2 ≠ 0 := by
      intro h0
      rw [h0, Nat.mul_zero] at hjudge
      omega
    have hqpos : 0 < m / leastDivFrom m m 2 := Nat.pos_of_ne_zero h1
    have h2 : m / leastDivFrom m m 2 ≠ 1 := by
      intro h1'
      rw [h1', Nat.mul_one] at hjudge
      omega
    omega
  have hjd : leastDivFrom m m 2 ≤ m / leastDivFrom m m 2 := by
    rcases Nat.lt_or_ge (m / leastDivFrom m m 2) (leastDivFrom m m 2) with h | h
    · exact absurd (Nat.mod_eq_zero_of_dvd hjdvd) (hdmin _ hj2 h)
    · exact h
  have hdd : leastDivFrom m m 2 * leastDivFrom m m 2 ≤
      leastDivFrom m m 2 * (m / leastDivFrom m m 2) :=
    Nat.mul_le_mul_left _ hjd
  rw [hjudge] at hdd
  exact hdd

/-- Trial-division scan with early exit at `lo * lo > m`. -/
private def noDiv (m fuel lo : Nat) : Bool :=
  match fuel with
  | 0 => true
  | fuel + 1 =>
    if lo * lo > m then true
    else (m % lo != 0) && noDiv m fuel (lo + 1)

private theorem noDiv_true : ∀ (fuel lo m : Nat), noDiv m fuel lo = true →
    ∀ s, lo ≤ s → s < lo + fuel → s * s ≤ m → m % s ≠ 0 := by
  intro fuel
  induction fuel with
  | zero => intro lo m _ s hs hlt _; omega
  | succ fuel IH =>
    intro lo m h s hs hlt hsq
    rw [noDiv] at h
    by_cases hex : lo * lo > m
    · rw [ite_eq_left hex] at h
      have hle : lo * lo ≤ s * s := Nat.mul_le_mul hs hs
      omega
    · rw [ite_eq_right hex] at h
      simp only [Bool.and_eq_true] at h
      have h1 : m % lo ≠ 0 := by
        simp at h
        exact h.1
      rcases Nat.lt_or_ge s (lo + 1) with hlt' | hlt'
      · have hse : s = lo := by omega
        rw [hse]
        exact h1
      · exact IH (lo + 1) m h.2 s (by omega) (by omega) hsq

private theorem noDiv_false : ∀ (fuel lo m d : Nat), 2 ≤ lo → lo ≤ d → d ∣ m → d < m →
    d * d ≤ m → (∀ s, lo ≤ s → s < d → m % s ≠ 0) → d < lo + fuel →
    noDiv m fuel lo = false := by
  intro fuel
  induction fuel with
  | zero => intro lo m d _ h2 _ _ _ _ hlt; omega
  | succ fuel IH =>
    intro lo m d hlo hld hdvd hdm hsq hmin hlt
    rw [noDiv]
    have hnotex : ¬ (lo * lo > m) := by
      have hle : lo * lo ≤ d * d := Nat.mul_le_mul hld hld
      omega
    rw [ite_eq_right hnotex]
    rcases Nat.lt_or_ge lo d with hlt' | heq
    · have hmodne : m % lo ≠ 0 := hmin lo (Nat.le_refl lo) hlt'
      have h1 : (m % lo != 0) = true := by simp [hmodne]
      rw [h1]
      exact IH (lo + 1) m d (by omega) (by omega) hdvd hdm hsq
        (fun s hs' hlt' => hmin s (by omega) hlt') (by omega)
    · have hle : lo = d := by omega
      have hmod : m % lo = 0 := by
        rw [hle]
        exact Nat.mod_eq_zero_of_dvd hdvd
      have h1 : (m % lo != 0) = false := by simp [hmod]
      rw [h1]
      rfl

private theorem noDiv_false_ex : ∀ (fuel lo m : Nat), noDiv m fuel lo = false →
    ∃ s, lo ≤ s ∧ s < lo + fuel ∧ s * s ≤ m ∧ m % s = 0 := by
  intro fuel
  induction fuel with
  | zero => intro lo m h; rw [noDiv] at h; exact absurd h (by decide)
  | succ fuel IH =>
    intro lo m h
    rw [noDiv] at h
    by_cases hex : lo * lo > m
    · rw [ite_eq_left hex] at h
      exact absurd h (by decide)
    · rw [ite_eq_right hex] at h
      simp only [Bool.and_eq_false_iff] at h
      rcases h with h | h
      · refine ⟨lo, Nat.le_refl lo, by omega, Nat.le_of_not_gt hex, ?_⟩
        simp at h
        exact h
      · obtain ⟨s, hs1, hs2, hs3, hs4⟩ := IH (lo + 1) m h
        exact ⟨s, by omega, by omega, hs3, hs4⟩

/-- Primality test: `m ≥ 2` is prime iff no trial divisor `d` with `2 ≤ d, d*d ≤ m` divides `m`. -/
private def primeTest (m : Nat) : Bool :=
  match m with
  | 0 => false
  | 1 => false
  | m' + 2 => noDiv (m' + 2) (m' + 1) 2

private theorem primeTest_correct : ∀ m, primeTest m = true →
    2 ≤ m ∧ ∀ k, k ∣ m → k = 1 ∨ k = m := by
  intro m h
  match m with
  | 0 => rw [primeTest] at h; exact absurd h (by decide)
  | 1 => rw [primeTest] at h; exact absurd h (by decide)
  | m' + 2 =>
    have h2 : 2 ≤ m' + 2 := by omega
    refine ⟨h2, ?_⟩
    intro k hk
    obtain ⟨j, hj⟩ := hk
    by_cases hk1 : k = 1
    · exact Or.inl hk1
    by_cases hkm : k = m' + 2
    · exact Or.inr hkm
    exfalso
    have hk0 : k ≠ 0 := by
      intro h0
      rw [h0, Nat.zero_mul] at hj
      omega
    have hk2 : 2 ≤ k := by omega
    have hkle : k ≤ m' + 2 := Nat.le_of_dvd (by omega) ⟨j, hj⟩
    have hkm' : k < m' + 2 := by omega
    obtain ⟨d, hd2, hddvd, hdsq⟩ := leastDiv_sqrt (m' + 2) k h2 ⟨j, hj⟩ hk2 hkm'
    have hdd : d ≤ m' + 2 := Nat.le_of_dvd (by omega) hddvd
    have hnd := noDiv_true (m' + 1) 2 (m' + 2) h d (by omega) (by omega) hdsq
    exact hnd (Nat.mod_eq_zero_of_dvd hddvd)

private theorem primeTest_composite : ∀ m, 2 ≤ m → primeTest m = false →
    ∃ k, k ∣ m ∧ 2 ≤ k ∧ k < m := by
  intro m hm h
  match m with
  | 0 => exact absurd hm (by omega)
  | 1 => exact absurd hm (by omega)
  | m' + 2 =>
    rw [primeTest] at h
    obtain ⟨s, hs1, hs2, hs3, hs4⟩ := noDiv_false_ex (m' + 1) 2 (m' + 2) h
    refine ⟨s, Nat.dvd_of_mod_eq_zero hs4, hs1, ?_⟩
    rcases Nat.lt_or_ge s (m' + 2) with hlt | hge
    · exact hlt
    · exfalso
      have h1 : s * 2 ≤ s * s := Nat.mul_le_mul_left s hs1
      omega

private theorem exists_prime_factor_aux : ∀ (fuel m : Nat), m ≤ fuel → 2 ≤ m →
    ∃ p, primeTest p = true ∧ p ∣ m := by
  intro fuel
  induction fuel with
  | zero => intro m h1 h2; exact absurd h2 (by omega)
  | succ fuel IH =>
    intro m h1 h2
    rcases Nat.lt_or_ge m (fuel + 1) with hlt | heq
    · exact IH m (by omega) h2
    · have hmeq : m = fuel + 1 := by omega
      rw [hmeq]
      by_cases hp : primeTest (fuel + 1) = true
      · exact ⟨fuel + 1, hp, Nat.dvd_refl (fuel + 1)⟩
      · have hf : primeTest (fuel + 1) = false := by
          simp at hp
          exact hp
        obtain ⟨k, hk, hk2, hkm⟩ := primeTest_composite (fuel + 1) (by omega) hf
        obtain ⟨p, hp1, hp2⟩ := IH k (by omega) hk2
        exact ⟨p, hp1, Nat.dvd_trans hp2 hk⟩

private theorem exists_prime_factor : ∀ m, 2 ≤ m → ∃ p, primeTest p = true ∧ p ∣ m :=
  fun m h => exists_prime_factor_aux m m (Nat.le_refl m) h

/-! ## Primality (divisor form) and the Lucas test -/

/-- Primality in divisor form (core Lean 4 v4.35 has no `Nat.Prime`). -/
def Prime (p : Nat) : Prop := 2 ≤ p ∧ ∀ m, m ∣ p → m = 1 ∨ m = p

private theorem primeTest_prime {p : Nat} (h : primeTest p = true) : Prime p :=
  primeTest_correct p h

private theorem prime_dvd_mul {p x y : Nat} (hp : Prime p) (hd : p ∣ x * y) : p ∣ x ∨ p ∣ y := by
  rcases hp.2 (Nat.gcd p x) (Nat.gcd_dvd_left p x) with h | h
  · exact Or.inr (Nat.Coprime.dvd_of_dvd_mul_left h hd)
  · exact Or.inl (by rw [← h]; exact Nat.gcd_dvd_right p x)

private theorem prime_dvd_pow_of_pos {p a : Nat} (hp : Prime p) :
    ∀ i, p ∣ a ^ (i + 1) → p ∣ a := by
  intro i
  induction i with
  | zero =>
    intro hdvd
    rw [Nat.pow_one] at hdvd
    exact hdvd
  | succ i IH =>
    intro hdvd
    rw [Nat.pow_succ] at hdvd
    rcases prime_dvd_mul hp hdvd with h | h
    · exact IH h
    · exact h

/-- Least exponent `d ∈ [lo, lo + fuel)` with `a ^ d % N = 1` (or `0` if none). -/
private def leastPowAux (a N : Nat) : Nat → Nat → Nat
  | 0, _ => 0
  | fuel + 1, lo => if a ^ lo % N = 1 then lo else leastPowAux a N fuel (lo + 1)

private theorem leastPow_spec : ∀ (a N fuel lo r : Nat), 1 ≤ lo →
    leastPowAux a N fuel lo = r → (∃ s, lo ≤ s ∧ s < lo + fuel ∧ a ^ s % N = 1) →
    lo ≤ r ∧ r < lo + fuel ∧ a ^ r % N = 1 ∧ ∀ s, lo ≤ s → s < r → a ^ s % N ≠ 1 := by
  intro a N fuel
  induction fuel with
  | zero =>
    intro lo r h1 _ ⟨s, hs1, hs2, _⟩
    exact absurd hs2 (by omega)
  | succ fuel IH =>
    intro lo r h1 heq ⟨s, hs1, hs2, hsw⟩
    rw [leastPowAux] at heq
    by_cases hlo : a ^ lo % N = 1
    · rw [ite_eq_left hlo] at heq
      have hre : lo = r := by omega
      subst hre
      refine ⟨Nat.le_refl lo, by omega, hlo, ?_⟩
      intro s' hs1' hs2'
      exact absurd hs2' (by omega)
    · rw [ite_eq_right hlo] at heq
      have hsne : s ≠ lo := by
        intro h0
        rw [h0] at hsw
        exact hlo hsw
      have hs' : lo + 1 ≤ s ∧ s < lo + 1 + fuel ∧ a ^ s % N = 1 :=
        ⟨by omega, by omega, hsw⟩
      obtain ⟨h1', h2', h3', h4'⟩ := IH (lo + 1) r (by omega) heq ⟨s, hs'⟩
      refine ⟨by omega, by omega, h3', ?_⟩
      intro s' hs1' hs2'
      rcases Nat.lt_or_ge s' (lo + 1) with hlt' | hlt'
      · have hse : s' = lo := by omega
        rw [hse]
        exact hlo
      · exact h4' s' (by omega) hs2'

/-- If `r` is the least positive exponent with `a ^ r % N = 1`, then `r` divides
any exponent `M` with `a ^ M % N = 1`. (Abstract-atom form: avoids `omega` on
composite function-application atoms, which would pull in `Classical.choice`.) -/
private theorem order_dvd {a N M r : Nat} (hN : 1 < N)
    (hmin : ∀ s, 1 ≤ s → s < r → a ^ s % N ≠ 1)
    (hra : a ^ r % N = 1) (hr1 : 1 ≤ r)
    (hM : a ^ M % N = 1) : r ∣ M := by
  by_cases hmod : M % r = 0
  · refine ⟨M / r, ?_⟩
    have h := Nat.div_add_mod M r
    rw [hmod] at h
    omega
  · exfalso
    have hr2 : 1 ≤ M % r := Nat.pos_of_ne_zero hmod
    have hr3 : M % r < r := Nat.mod_lt _ hr1
    have hdq : a ^ (r * (M / r)) % N = 1 := by
      rw [Nat.pow_mul, Nat.pow_mod, hra, Nat.one_pow,
        Nat.mod_eq_of_lt hN]
    have hsplit : a ^ (M % r) % N = 1 := by
      have hdm' : M = r * (M / r) + M % r :=
        (Nat.div_add_mod M r).symm
      have e0 : a ^ M = a ^ (r * (M / r) + M % r) := congrArg (fun x => a ^ x) hdm'
      have e1 : a ^ (r * (M / r) + M % r) =
          a ^ (r * (M / r)) * a ^ (M % r) := Nat.pow_add _ _ _
      have e2 : (a ^ (r * (M / r)) * a ^ (M % r)) % N = a ^ (M % r) % N := by
        rw [Nat.mul_mod, hdq, Nat.one_mul, Nat.mod_mod]
      rw [← e2, ← e1, ← e0, hM]
    exact hmin _ hr2 hr3 hsplit

/-- If `r` is the least positive exponent with `a ^ r % N = 1`, `r ≤ M`, and
`M` passes the Lucas step for every prime divisor `q ∣ M`, then `r = M`. -/
private theorem order_eq {a N M r : Nat} (hN : 1 < N) (hMpos : 0 < M)
    (hmin : ∀ s, 1 ≤ s → s < r → a ^ s % N ≠ 1)
    (hra : a ^ r % N = 1) (hr1 : 1 ≤ r) (hrlt : r < 1 + M)
    (hM : a ^ M % N = 1)
    (hstep : ∀ q, Prime q → q ∣ M → a ^ (M / q) % N ≠ 1) : r = M := by
  rcases Nat.lt_or_ge r M with hlt | hge
  · exfalso
    have hdvd : r ∣ M := order_dvd hN hmin hra hr1 hM
    obtain ⟨u, hu⟩ := hdvd
    have hru : r * u = M := hu.symm
    have hu2 : 2 ≤ u := by
      have hu0 : u ≠ 0 := by
        intro h0; rw [h0, Nat.mul_zero] at hru; omega
      have hu1 : u ≠ 1 := by
        intro h1'; rw [h1', Nat.mul_one] at hru; omega
      omega
    obtain ⟨q, hqtest, hqd⟩ := exists_prime_factor u hu2
    have hqp : Prime q := primeTest_prime hqtest
    have hqpos : 0 < q := by have := hqp.1; omega
    have huq : u = q * (u / q) := (Nat.mul_div_cancel' hqd).symm
    have h2 : M = q * (r * (u / q)) := by
      rw [hu, congrArg (fun x => r * x) huq]
      exact Nat.mul_left_comm r q (u / q)
    have hqM : q ∣ M := ⟨r * (u / q), h2⟩
    have hsplit : M / q = r * (u / q) := by
      have h3 : M / q = (q * (r * (u / q))) / q := congrArg (fun x => x / q) h2
      rw [h3, Nat.mul_div_cancel_left _ hqpos]
    refine hstep q hqp hqM ?_
    rw [hsplit, Nat.pow_mul, Nat.pow_mod, hra, Nat.one_pow,
      Nat.mod_eq_of_lt hN]
  · exact Nat.le_antisymm (by omega) hge

private theorem lucas_primality {N a : Nat} (hN : 1 < N) (_ha : 0 < a)
    (hpow : a ^ (N - 1) % N = 1)
    (hstep : ∀ q, Prime q → q ∣ N - 1 → a ^ ((N - 1) / q) % N ≠ 1) : Prime N := by
  have hN2 : 2 ≤ N := hN
  have hpow1 : a ^ (N - 1) = a * a ^ (N - 2) := by
    have h1 : N - 1 = 1 + (N - 2) := by omega
    rw [h1, Nat.pow_add, Nat.pow_one]
  have hmodlt : ∀ x, x % N < N := fun x => Nat.mod_lt x (by omega)
  -- the multiplicative order `d` of `a` mod `N` exists and divides `N - 1`
  have hex : ∃ s, 1 ≤ s ∧ s < 1 + (N - 1) ∧ a ^ s % N = 1 :=
    ⟨N - 1, by omega, by omega, hpow⟩
  obtain ⟨hd1, hdlt, hda, hdmin⟩ :=
    leastPow_spec a N (N - 1) 1 (leastPowAux a N (N - 1) 1) (Nat.le_refl 1) rfl hex
  clear hex
  -- the order must be exactly `N - 1` (abstract-atom lemma; no omega on the atom)
  have hdeq : leastPowAux a N (N - 1) 1 = N - 1 :=
    order_eq hN (M := N - 1) (Nat.sub_pos_of_lt hN) hdmin hda hd1 hdlt hpow hstep
  rw [hdeq] at hd1 hdlt hda hdmin
  clear hdeq hd1 hdlt hda
  -- the powers `a ^ i % N`, `i < N - 1`, are distinct
  have hinv : ∀ i, i ≤ N - 1 → a ^ i * a ^ (N - 1 - i) = a ^ (N - 1) := by
    intro i hi
    rw [← Nat.pow_add]
    have hsum : i + (N - 1 - i) = N - 1 := by omega
    rw [hsum]
  have hinj : ∀ i j, i < N - 1 → j < N - 1 → a ^ i % N = a ^ j % N → i = j := by
    intro i j hi hj heq
    rcases Nat.lt_trichotomy i j with h | h | h
    · exfalso
      have h4 : a ^ (i + (N - 1 - j)) % N = 1 := by
        have mm1 : (a ^ i * a ^ (N - 1 - j)) % N =
            a ^ i % N * (a ^ (N - 1 - j) % N) % N := Nat.mul_mod _ _ _
        have mm2 : (a ^ j * a ^ (N - 1 - j)) % N =
            a ^ j % N * (a ^ (N - 1 - j) % N) % N := Nat.mul_mod _ _ _
        have e1 : a ^ (i + (N - 1 - j)) = a ^ i * a ^ (N - 1 - j) := Nat.pow_add _ _ _
        have e2 : a ^ (N - 1) = a ^ j * a ^ (N - 1 - j) := (hinv j (by omega)).symm
        have key : a ^ (i + (N - 1 - j)) % N = a ^ (N - 1) % N := by
          rw [e1, mm1, e2, mm2, heq]
        rw [key, hpow]
      exact hdmin (i + (N - 1 - j)) (by omega) (by omega) h4
    · exact h
    · exfalso
      have h4 : a ^ (j + (N - 1 - i)) % N = 1 := by
        have mm1 : (a ^ j * a ^ (N - 1 - i)) % N =
            a ^ j % N * (a ^ (N - 1 - i) % N) % N := Nat.mul_mod _ _ _
        have mm2 : (a ^ i * a ^ (N - 1 - i)) % N =
            a ^ i % N * (a ^ (N - 1 - i) % N) % N := Nat.mul_mod _ _ _
        have e1 : a ^ (j + (N - 1 - i)) = a ^ j * a ^ (N - 1 - i) := Nat.pow_add _ _ _
        have e2 : a ^ (N - 1) = a ^ i * a ^ (N - 1 - i) := (hinv i (by omega)).symm
        have key : a ^ (j + (N - 1 - i)) % N = a ^ (N - 1) % N := by
          rw [e1, mm1, e2, mm2, ← heq]
        rw [key, hpow]
      exact hdmin (j + (N - 1 - i)) (by omega) (by omega) h4
  -- no power of `a` vanishes mod `N`
  have hnz : ∀ i, i < N - 1 → a ^ i % N ≠ 0 := by
    intro i hi h0
    obtain ⟨p, hptest, hpd⟩ := exists_prime_factor N hN2
    have hpp : Prime p := primeTest_prime hptest
    rcases Nat.lt_or_ge i 1 with hi0 | hi1
    · have hie : i = 0 := by omega
      rw [hie, Nat.pow_zero] at h0
      rw [Nat.mod_eq_of_lt (by omega : 1 < N)] at h0
      omega
    · have hpa : p ∣ a := by
        have hd : p ∣ a ^ i := Nat.dvd_trans hpd (Nat.dvd_of_mod_eq_zero h0)
        have hie : i - 1 + 1 = i := by omega
        rw [← hie] at hd
        exact prime_dvd_pow_of_pos hpp (i - 1) hd
      have hp1 : p ∣ 1 := by
        obtain ⟨c, hc⟩ : ∃ c, a ^ (N - 1) = 1 + N * c := by
          have h := Nat.div_add_mod (a ^ (N - 1)) N
          rw [hpow] at h
          exact ⟨a ^ (N - 1) / N, h.symm.trans (Nat.add_comm _ _)⟩
        have hd1' : p ∣ a ^ (N - 1) := by
          rw [hpow1]
          exact Nat.dvd_trans hpa (Nat.dvd_mul_right a (a ^ (N - 2)))
        have hd2' : p ∣ N * c := Nat.dvd_trans hpd (Nat.dvd_mul_right N c)
        have hd3 : p ∣ (1 + N * c) - N * c := by
          refine Nat.dvd_sub ?_ hd2'
          rw [← hc]
          exact hd1'
        rw [Nat.add_sub_cancel_right] at hd3
        exact hd3
      have := hpp.1
      rw [Nat.eq_one_of_dvd_one hp1] at this
      omega
  -- pigeonhole: the powers cover every residue in `[1, N)`
  have hsurj : ∀ v, 1 ≤ v → v < N → ∃ i, i < N - 1 ∧ a ^ i % N = v := by
    have hsum : (N - 1) + 1 = N := by omega
    have hs := pig_surj N (N - 1) (fun i => a ^ i % N) hsum hinj
      (fun i hi => ⟨Nat.pos_of_ne_zero (hnz i hi), hmodlt (a ^ i)⟩)
    exact hs
  -- conclude `N` is prime
  refine ⟨hN, ?_⟩
  intro m hm
  by_cases hm1 : m = 1
  · exact Or.inl hm1
  by_cases hmN : m = N
  · exact Or.inr hmN
  exfalso
  have hm0 : m ≠ 0 := by
    intro h0
    obtain ⟨w, hw⟩ := hm
    rw [h0, Nat.zero_mul] at hw
    omega
  have hm2 : 2 ≤ m := by omega
  have hmle : m ≤ N := Nat.le_of_dvd (by omega) hm
  have hmlt : m < N := by omega
  obtain ⟨i, hi, hei⟩ := hsurj m (by omega) hmlt
  have hmod1 : m * a ^ (N - 1 - i) % N = 1 := by
    have mm1 : m * a ^ (N - 1 - i) % N =
        m % N * (a ^ (N - 1 - i) % N) % N := Nat.mul_mod _ _ _
    have mm2 : a ^ i * a ^ (N - 1 - i) % N =
        a ^ i % N * (a ^ (N - 1 - i) % N) % N := Nat.mul_mod _ _ _
    have key : m * a ^ (N - 1 - i) % N = a ^ i * a ^ (N - 1 - i) % N := by
      rw [mm1, mm2, hei, Nat.mod_eq_of_lt hmlt]
    have h3 : a ^ i * a ^ (N - 1 - i) % N = 1 := by
      rw [hinv i (by omega), hpow]
    rw [key]; exact h3
  obtain ⟨c, hc⟩ : ∃ c, m * a ^ (N - 1 - i) = 1 + N * c := by
    have h := Nat.div_add_mod (m * a ^ (N - 1 - i)) N
    rw [hmod1] at h
    exact ⟨m * a ^ (N - 1 - i) / N, h.symm.trans (Nat.add_comm _ _)⟩
  have hres : m ∣ 1 := by
    have hd1' : m ∣ m * a ^ (N - 1 - i) := Nat.dvd_mul_right m _
    have hd2' : m ∣ N * c := Nat.dvd_trans hm (Nat.dvd_mul_right N c)
    have hd3 : m ∣ (1 + N * c) - N * c := by
      refine Nat.dvd_sub ?_ hd2'
      rw [← hc]
      exact hd1'
    rw [Nat.add_sub_cancel_right] at hd3
    exact hd3
  have := hm2
  rw [Nat.eq_one_of_dvd_one hres] at this
  omega

/-! ## Bridges from the kernel-reducible `expBits` -/

private theorem eq_via_exp {m a E : Nat} (hm : 1 < m) {bs : List Bool}
    (hbs : bitsVal bs = E) (h : expBits m a bs = 1) : a ^ E % m = 1 := by
  rw [← hbs, ← expBits_eq_pow_mod m a hm bs]
  exact h

private theorem ne_via_exp {m a E : Nat} (hm : 1 < m) {bs : List Bool}
    (hbs : bitsVal bs = E) (h : expBits m a bs ≠ 1) : a ^ E % m ≠ 1 := by
  intro he
  refine h ?_
  rw [expBits_eq_pow_mod m a hm bs, hbs]
  exact he

private theorem prime_dvd_prime {q p : Nat} (hq : Prime q) (hp : Prime p) (hd : q ∣ p) :
    q = p := by
  rcases hp.2 q hd with h | h
  · have h2 := hq.1
    rw [h] at h2
    omega
  · exact h

/-! ## Small primes (kernel trial division via `primeTest`) -/

set_option maxRecDepth 100000

private theorem pr2 : Prime 2 := primeTest_prime (by decide)
private theorem pr3 : Prime 3 := primeTest_prime (by decide)
private theorem pr5 : Prime 5 := primeTest_prime (by decide)
private theorem pr7 : Prime 7 := primeTest_prime (by decide)
private theorem pr11 : Prime 11 := primeTest_prime (by decide)
private theorem pr29 : Prime 29 := primeTest_prime (by decide)
private theorem pr31 : Prime 31 := primeTest_prime (by decide)
private theorem pr1627 : Prime 1627 := primeTest_prime (by decide)
private theorem pr2621 : Prime 2621 := primeTest_prime (by decide)
private theorem pr2657 : Prime 2657 := primeTest_prime (by decide)
private theorem pr4423 : Prime 4423 := primeTest_prime (by decide)
private theorem pr5323 : Prime 5323 := primeTest_prime (by decide)
private theorem pr7723 : Prime 7723 := primeTest_prime (by decide)
private theorem pr13441 : Prime 13441 := primeTest_prime (by decide)
private theorem pr24809 : Prime 24809 := primeTest_prime (by decide)
private theorem pr41201 : Prime 41201 := primeTest_prime (by decide)
private theorem pr96557 : Prime 96557 := primeTest_prime (by decide)
private theorem pr7240687 : Prime 7240687 := primeTest_prime (by decide)
private theorem pr13331831 : Prime 13331831 := primeTest_prime (by decide)
private theorem pr107590001 : Prime 107590001 := primeTest_prime (by decide)

private def Sbig : Nat := 173378833005251801

private theorem ssplit : Sbig - 1 = 2 * 2 * 2 * 5 * 5 * 2621 * 24809 * 13331831 := by decide

private def bssF : List Bool := [false, false, false, true, true, false, true, true, false, false, true, true, false, false, false, true, true, false, false, true, true, false, true, true, false, false, false, true, false, false, true, false, true, false, false, false, false, true, false, false, true, true, true, false, true, true, true, true, true, true, true, false, false, true, true, false, false, true]
private theorem hbsF : bitsVal bssF = 173378833005251800 := by decide
private theorem vsF : expBits Sbig 6 bssF = 1 := by decide
private theorem sexpl : (6 ^ (Sbig - 1)) % Sbig = 1 :=
  eq_via_exp (m := Sbig) (a := 6) (E := Sbig - 1) (by decide) hbsF vsF

private def bss0 : List Bool := [false, false, true, true, false, true, true, false, false, true, true, false, false, false, true, true, false, false, true, true, false, true, true, false, false, false, true, false, false, true, false, true, false, false, false, false, true, false, false, true, true, true, false, true, true, true, true, true, true, true, false, false, true, true, false, false, true]
private theorem hbs0 : bitsVal bss0 = 86689416502625900 := by decide
private theorem vs0 : expBits Sbig 6 bss0 ≠ 1 := by decide
private def bss1 : List Bool := [false, false, false, true, true, true, true, true, false, false, false, true, false, true, true, true, true, false, false, false, true, false, false, true, false, true, true, true, false, false, false, false, true, false, true, true, false, true, true, false, true, false, false, false, true, true, false, false, true, true, false, true, true, true, true]
private theorem hbs1 : bitsVal bss1 = 34675766601050360 := by decide
private theorem vs1 : expBits Sbig 6 bss1 ≠ 1 := by decide
private def bss2 : List Bool := [false, false, false, true, true, true, false, true, true, false, true, false, false, false, false, false, true, true, false, true, false, false, false, false, false, false, false, true, true, true, false, true, true, false, false, true, false, true, false, false, false, false, true, true, true, true]
private theorem hbs2 : bitsVal bss2 = 66149879055800 := by decide
private theorem vs2 : expBits Sbig 6 bss2 ≠ 1 := by decide
private def bss3 : List Bool := [false, false, false, true, true, false, false, false, true, true, true, true, true, false, true, false, false, true, false, true, false, false, true, true, true, false, true, false, false, true, false, false, true, true, false, true, true, false, true, false, false, true, true]
private theorem hbs3 : bitsVal bss3 = 6988545810200 := by decide
private theorem vs3 : expBits Sbig 6 bss3 ≠ 1 := by decide
private def bss4 : List Bool := [false, false, false, true, false, true, true, true, true, true, true, true, false, true, false, true, false, true, true, false, false, true, false, false, true, true, true, false, false, false, false, false, true, true]
private theorem hbs4 : bitsVal bss4 = 13004877800 := by decide
private theorem vs4 : expBits Sbig 6 bss4 ≠ 1 := by decide

private theorem s_hd : ∀ q : Nat, Prime q → q ∣ Sbig - 1 →
    (6 ^ ((Sbig - 1) / q)) % Sbig ≠ 1 := by
  intro q hq hdv
  rw [ssplit] at hdv
  rcases prime_dvd_mul hq hdv with dl2 | dr2
  · rcases prime_dvd_mul hq dl2 with dl4 | dr4
    · rcases prime_dvd_mul hq dl4 with dl6 | dr6
      · rcases prime_dvd_mul hq dl6 with dl8 | dr8
        · rcases prime_dvd_mul hq dl8 with dl10 | dr10
          · rcases prime_dvd_mul hq dl10 with dl12 | dr12
            · rcases prime_dvd_mul hq dl12 with dl14 | dr14
              · have eqq := prime_dvd_prime hq (pr2) dl14
                subst eqq
                exact ne_via_exp (by decide) hbs0 vs0
              · have eqq := prime_dvd_prime hq (pr2) dr14
                subst eqq
                exact ne_via_exp (by decide) hbs0 vs0
            · have eqq := prime_dvd_prime hq (pr2) dr12
              subst eqq
              exact ne_via_exp (by decide) hbs0 vs0
          · have eqq := prime_dvd_prime hq (pr5) dr10
            subst eqq
            exact ne_via_exp (by decide) hbs1 vs1
        · have eqq := prime_dvd_prime hq (pr5) dr8
          subst eqq
          exact ne_via_exp (by decide) hbs1 vs1
      · have eqq := prime_dvd_prime hq (pr2621) dr6
        subst eqq
        exact ne_via_exp (by decide) hbs2 vs2
    · have eqq := prime_dvd_prime hq (pr24809) dr4
      subst eqq
      exact ne_via_exp (by decide) hbs3 vs3
  · have eqq := prime_dvd_prime hq (pr13331831) dr2
    subst eqq
    exact ne_via_exp (by decide) hbs4 vs4


/-- `Sbig` is prime (Pratt certificate level). -/
private theorem Sbig_prime : Prime Sbig :=
  lucas_primality (N := Sbig) (a := 6) (by decide) (by decide) sexpl s_hd

private def Qbig : Nat := 22149492674086928081353

private theorem qsplit : Qbig - 1 = 2 * 2 * 2 * 3 * 5323 * Sbig := by decide

private def bsqF : List Bool := [false, false, false, true, false, false, true, true, true, false, false, false, false, true, true, false, true, true, true, false, true, false, true, false, false, false, true, false, true, false, true, false, false, true, false, true, false, false, false, false, false, true, false, true, true, false, false, true, true, false, true, false, true, true, true, true, true, false, false, true, true, true, false, true, false, false, false, false, true, true, false, true, false, false, true]
private theorem hbqF : bitsVal bsqF = 22149492674086928081352 := by decide
private theorem vqF : expBits Qbig 5 bsqF = 1 := by decide
private theorem qexpl : (5 ^ (Qbig - 1)) % Qbig = 1 :=
  eq_via_exp (m := Qbig) (a := 5) (E := Qbig - 1) (by decide) hbqF vqF

private def bsq0 : List Bool := [false, false, true, false, false, true, true, true, false, false, false, false, true, true, false, true, true, true, false, true, false, true, false, false, false, true, false, true, false, true, false, false, true, false, true, false, false, false, false, false, true, false, true, true, false, false, true, true, false, true, false, true, true, true, true, true, false, false, true, true, true, false, true, false, false, false, false, true, true, false, true, false, false, true]
private theorem hbq0 : bitsVal bsq0 = 11074746337043464040676 := by decide
private theorem vq0 : expBits Qbig 5 bsq0 ≠ 1 := by decide
private def bsq1 : List Bool := [false, false, false, true, true, false, false, true, false, false, false, false, false, true, false, false, true, false, true, true, true, false, false, false, false, false, true, true, true, false, false, false, false, true, true, true, false, true, false, true, false, false, false, true, false, false, false, true, false, false, true, true, true, true, true, true, true, false, true, true, true, true, false, false, false, false, false, false, true, false, false, true, true]
private theorem hbq1 : bitsVal bsq1 = 7383164224695642693784 := by decide
private theorem vq1 : expBits Qbig 5 bsq1 ≠ 1 := by decide
private def bsq2 : List Bool := [false, false, false, true, true, false, true, false, false, false, true, false, true, true, false, false, true, false, true, false, false, true, true, false, false, false, true, false, true, false, true, true, false, true, true, true, true, false, false, false, true, true, false, true, false, true, false, false, true, true, true, true, true, true, false, true, true, false, false, true, true, true]
private theorem hbq2 : bitsVal bsq2 = 4161091992126043224 := by decide
private theorem vq2 : expBits Qbig 5 bsq2 ≠ 1 := by decide
private def bsq3 : List Bool := [false, false, false, true, false, false, false, false, true, true, false, false, true, true, true, true, true]
private theorem hbq3 : bitsVal bsq3 = 127752 := by decide
private theorem vq3 : expBits Qbig 5 bsq3 ≠ 1 := by decide

private theorem q_hd : ∀ q : Nat, Prime q → q ∣ Qbig - 1 →
    (5 ^ ((Qbig - 1) / q)) % Qbig ≠ 1 := by
  intro q hq hdv
  rw [qsplit] at hdv
  rcases prime_dvd_mul hq hdv with dl2 | dr2
  · rcases prime_dvd_mul hq dl2 with dl4 | dr4
    · rcases prime_dvd_mul hq dl4 with dl6 | dr6
      · rcases prime_dvd_mul hq dl6 with dl8 | dr8
        · rcases prime_dvd_mul hq dl8 with dl10 | dr10
          · have eqq := prime_dvd_prime hq (pr2) dl10
            subst eqq
            exact ne_via_exp (by decide) hbq0 vq0
          · have eqq := prime_dvd_prime hq (pr2) dr10
            subst eqq
            exact ne_via_exp (by decide) hbq0 vq0
        · have eqq := prime_dvd_prime hq (pr2) dr8
          subst eqq
          exact ne_via_exp (by decide) hbq0 vq0
      · have eqq := prime_dvd_prime hq (pr3) dr6
        subst eqq
        exact ne_via_exp (by decide) hbq1 vq1
    · have eqq := prime_dvd_prime hq (pr5323) dr4
      subst eqq
      exact ne_via_exp (by decide) hbq2 vq2
  · have eqq := prime_dvd_prime hq (Sbig_prime) dr2
    subst eqq
    exact ne_via_exp (by decide) hbq3 vq3


/-- `Qbig` is prime (Pratt certificate level). -/
private theorem Qbig_prime : Prime Qbig :=
  lucas_primality (N := Qbig) (a := 5) (by decide) (by decide) qexpl q_hd

private def Rbig : Nat := 132896956044521568488119

private theorem rsplit : Rbig - 1 = 2 * 3 * Qbig := by decide

private def bsrF : List Bool := [false, true, true, false, true, true, false, true, false, true, false, true, false, false, true, false, false, false, true, true, false, false, false, false, false, true, false, true, true, true, true, true, true, false, true, true, true, true, false, false, false, false, true, true, true, false, false, true, true, false, false, false, false, false, true, true, true, true, false, true, true, false, true, false, false, false, true, false, false, true, false, false, false, false, true, true, true]
private theorem hbrF : bitsVal bsrF = 132896956044521568488118 := by decide
private theorem vrF : expBits Rbig 6 bsrF = 1 := by decide
private theorem rexpl : (6 ^ (Rbig - 1)) % Rbig = 1 :=
  eq_via_exp (m := Rbig) (a := 6) (E := Rbig - 1) (by decide) hbrF vrF

private def bsr0 : List Bool := [true, true, false, true, true, false, true, false, true, false, true, false, false, true, false, false, false, true, true, false, false, false, false, false, true, false, true, true, true, true, true, true, false, true, true, true, true, false, false, false, false, true, true, true, false, false, true, true, false, false, false, false, false, true, true, true, true, false, true, true, false, true, false, false, false, true, false, false, true, false, false, false, false, true, true, true]
private theorem hbr0 : bitsVal bsr0 = 66448478022260784244059 := by decide
private theorem vr0 : expBits Rbig 6 bsr0 ≠ 1 := by decide
private def bsr1 : List Bool := [false, true, false, false, true, false, false, true, true, true, false, false, false, false, true, true, false, true, true, true, false, true, false, true, false, false, false, true, false, true, false, true, false, false, true, false, true, false, false, false, false, false, true, false, true, true, false, false, true, true, false, true, false, true, true, true, true, true, false, false, true, true, true, false, true, false, false, false, false, true, true, false, true, false, false, true]
private theorem hbr1 : bitsVal bsr1 = 44298985348173856162706 := by decide
private theorem vr1 : expBits Rbig 6 bsr1 ≠ 1 := by decide
private def bsr2 : List Bool := [false, true, true]
private theorem hbr2 : bitsVal bsr2 = 6 := by decide
private theorem vr2 : expBits Rbig 6 bsr2 ≠ 1 := by decide

private theorem r_hd : ∀ q : Nat, Prime q → q ∣ Rbig - 1 →
    (6 ^ ((Rbig - 1) / q)) % Rbig ≠ 1 := by
  intro q hq hdv
  rw [rsplit] at hdv
  rcases prime_dvd_mul hq hdv with dl2 | dr2
  · rcases prime_dvd_mul hq dl2 with dl4 | dr4
    · have eqq := prime_dvd_prime hq (pr2) dl4
      subst eqq
      exact ne_via_exp (by decide) hbr0 vr0
    · have eqq := prime_dvd_prime hq (pr3) dr4
      subst eqq
      exact ne_via_exp (by decide) hbr1 vr1
  · have eqq := prime_dvd_prime hq (Qbig_prime) dr2
    subst eqq
    exact ne_via_exp (by decide) hbr2 vr2


/-- `Rbig` is prime (Pratt certificate level). -/
private theorem Rbig_prime : Prime Rbig :=
  lucas_primality (N := Rbig) (a := 6) (by decide) (by decide) rexpl r_hd

private def Qtwo : Nat := 255515944373312847190720520512484175977

private theorem qtsplit : Qtwo - 1 = 2 * 2 * 2 * 7 * 7 * 11 * 1627 * 2657 * 4423 * 96557 * 41201 * 107590001 * 7240687 := by decide

private def bsqtF : List Bool := [false, false, false, true, false, true, true, false, false, false, false, false, true, true, true, false, false, false, false, true, true, false, false, true, true, true, true, true, true, true, false, true, false, false, true, true, false, false, true, true, false, false, false, true, true, false, true, true, false, false, true, true, true, false, true, false, false, false, false, false, false, true, false, true, true, false, false, true, true, false, false, false, false, false, true, false, false, false, true, false, false, true, true, false, false, true, true, true, true, true, false, false, true, false, true, true, false, true, false, false, true, true, false, true, false, false, true, false, true, false, false, true, false, true, false, true, true, true, false, false, false, false, false, false, false, false, true, true]
private theorem hbqtF : bitsVal bsqtF = 255515944373312847190720520512484175976 := by decide
private theorem vqtF : expBits Qtwo 3 bsqtF = 1 := by decide
private theorem qtexpl : (3 ^ (Qtwo - 1)) % Qtwo = 1 :=
  eq_via_exp (m := Qtwo) (a := 3) (E := Qtwo - 1) (by decide) hbqtF vqtF

private def bsqt0 : List Bool := [false, false, true, false, true, true, false, false, false, false, false, true, true, true, false, false, false, false, true, true, false, false, true, true, true, true, true, true, true, false, true, false, false, true, true, false, false, true, true, false, false, false, true, true, false, true, true, false, false, true, true, true, false, true, false, false, false, false, false, false, true, false, true, true, false, false, true, true, false, false, false, false, false, true, false, false, false, true, false, false, true, true, false, false, true, true, true, true, true, false, false, true, false, true, true, false, true, false, false, true, true, false, true, false, false, true, false, true, false, false, true, false, true, false, true, true, true, false, false, false, false, false, false, false, false, true, true]
private theorem hbqt0 : bitsVal bsqt0 = 127757972186656423595360260256242087988 := by decide
private theorem vqt0 : expBits Qtwo 3 bsqt0 ≠ 1 := by decide
private def bsqt1 : List Bool := [false, false, false, true, true, false, true, false, false, true, false, false, false, true, false, true, false, false, true, true, false, false, true, true, false, true, true, false, true, true, true, true, false, true, false, true, false, false, false, true, true, true, false, false, false, false, true, false, true, false, true, true, false, false, false, false, false, false, false, false, false, true, true, false, true, false, false, false, true, true, true, false, true, true, true, false, true, true, true, false, true, false, true, false, false, false, true, false, false, true, true, true, true, false, false, false, false, true, true, true, true, true, false, false, true, false, true, false, true, false, false, false, false, true, true, false, true, true, true, false, true, true, false, true, true]
private theorem hbqt1 : bitsVal bsqt1 = 36502277767616121027245788644640596568 := by decide
private theorem vqt1 : expBits Qtwo 3 bsqt1 ≠ 1 := by decide
private def bsqt2 : List Bool := [false, false, false, true, true, true, false, false, false, true, false, true, false, false, false, false, false, false, false, true, false, false, true, true, true, false, true, false, false, false, false, true, true, false, true, false, true, true, false, true, true, true, false, false, true, false, false, false, false, false, true, false, true, false, false, true, false, true, true, true, false, false, false, false, true, true, false, true, false, true, true, true, false, true, true, true, false, true, true, true, false, false, true, false, true, false, false, false, true, false, false, true, true, false, true, false, true, false, true, true, false, true, true, false, false, false, false, false, true, true, false, true, true, false, false, true, true, true, true, false, true, false, false, false, true]
private theorem hbqt2 : bitsVal bsqt2 = 23228722215755713380974592773862197816 := by decide
private theorem vqt2 : expBits Qtwo 3 bsqt2 ≠ 1 := by decide
private def bsqt3 : List Bool := [false, false, false, true, true, true, false, true, true, false, true, true, false, false, true, true, true, true, true, false, false, false, false, false, false, true, false, true, false, false, false, false, true, true, true, false, true, true, false, false, true, false, false, false, false, true, true, false, true, false, false, true, false, false, true, false, false, true, false, true, false, false, true, true, false, false, true, true, true, true, true, false, true, false, false, false, true, true, true, false, true, true, true, true, false, false, true, false, true, false, false, false, false, false, false, true, true, true, true, false, false, false, false, false, true, true, true, true, true, true, false, false, false, true, true, true, true]
private theorem hbqt3 : bitsVal bsqt3 = 157047292177819820031174259688066488 := by decide
private theorem vqt3 : expBits Qtwo 3 bsqt3 ≠ 1 := by decide
private def bsqt4 : List Bool := [false, false, false, true, false, true, true, false, true, false, false, true, true, false, true, true, false, false, false, true, false, false, true, true, true, true, false, true, true, true, true, false, false, false, false, true, false, false, true, true, false, false, false, true, true, true, false, true, true, true, true, true, true, true, false, false, true, true, false, true, false, true, true, true, false, false, false, false, true, false, false, true, false, false, true, false, false, true, true, true, false, true, false, false, false, true, true, true, true, false, false, false, false, false, true, false, true, true, true, false, false, true, true, false, true, false, true, false, false, false, false, true, false, true, false, false, true]
private theorem hbqt4 : bitsVal bsqt4 = 96167084822473785167753300907972968 := by decide
private theorem vqt4 : expBits Qtwo 3 bsqt4 ≠ 1 := by decide
private def bsqt5 : List Bool := [false, false, false, true, true, false, true, false, false, false, false, false, false, false, false, true, true, false, false, true, true, false, false, false, true, false, false, false, false, false, true, false, false, false, false, true, true, false, true, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false, false, true, false, false, false, true, false, false, false, true, true, false, true, false, false, false, false, true, true, true, true, false, true, true, false, false, true, false, false, false, false, true, false, false, false, true, false, true, true, true, false, true, true, false, true, false, false, false, true, false, false, false, false, false, false, true, false, false, true, true, false, true]
private theorem hbqt5 : bitsVal bsqt5 = 57769826898782013834664372713652312 := by decide
private theorem vqt5 : expBits Qtwo 3 bsqt5 ≠ 1 := by decide
private def bsqt6 : List Bool := [false, false, false, true, false, true, true, true, false, true, true, false, true, true, true, true, true, true, true, true, false, false, true, false, false, true, false, true, true, false, false, false, false, true, false, false, false, true, true, false, false, false, true, true, false, true, true, true, true, false, false, false, true, false, true, true, true, true, true, false, true, false, false, false, false, false, false, false, false, true, false, false, true, true, true, false, false, false, false, true, true, true, false, false, false, true, false, false, false, true, true, true, true, false, true, false, false, false, true, false, false, false, true, true, true, false, false, false, true, true, false, false, true]
private theorem hbqt6 : bitsVal bsqt6 = 6201692783507993669831327407404776 := by decide
private theorem vqt6 : expBits Qtwo 3 bsqt6 ≠ 1 := by decide
private def bsqt7 : List Bool := [false, false, false, true, false, false, false, false, true, true, false, false, false, true, false, true, true, false, false, true, true, false, false, false, false, true, false, false, false, true, false, false, true, true, false, true, false, true, false, false, false, false, true, true, true, true, true, true, true, false, false, true, false, false, true, false, true, true, false, true, true, true, true, false, false, false, true, false, false, false, true, true, false, false, false, true, false, true, true, true, false, false, true, false, false, false, true, false, true, false, false, false, false, true, false, true, false, false, false, true, true, true, true, false, false, true, false, false, false, false, false, true]
private theorem hbqt7 : bitsVal bsqt7 = 2646270538369179315748423423599368 := by decide
private theorem vqt7 : expBits Qtwo 3 bsqt7 ≠ 1 := by decide
private def bsqt8 : List Bool := [false, false, false, true, true, false, false, false, false, true, true, true, false, false, true, false, false, true, true, false, false, true, false, false, false, true, false, true, true, true, false, true, true, true, true, false, true, false, true, false, false, false, true, true, true, false, true, true, true, false, false, false, true, true, true, true, false, false, true, false, false, true, true, true, true, false, false, true, true, false, false, false, true, false, true, false, true, false, true, false, true, false, true, true, true, false, false, true, false, false, false, true, false, true, true, false, true, false, true, true, true, true, false, true, true]
private theorem hbqt8 : bitsVal bsqt8 = 35288908963101546467996824129048 := by decide
private theorem vqt8 : expBits Qtwo 3 bsqt8 ≠ 1 := by decide
private def bsqt9 : List Bool := [false, false, false, true, false, true, true, true, false, true, false, false, false, false, true, true, false, false, false, true, true, false, true, true, false, false, false, false, false, true, false, false, true, true, true, true, true, true, true, true, true, false, true, false, false, false, true, false, true, true, true, true, true, false, true, true, false, true, true, true, false, false, false, false, true, true, false, false, false, false, true, false, false, false, true, false, true, true, false, true, false, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, false, true, true, true]
private theorem hbqt9 : bitsVal bsqt9 = 2374904191824599455024826335976 := by decide
private theorem vqt9 : expBits Qtwo 3 bsqt9 ≠ 1 := by decide

private theorem qt_hd : ∀ q : Nat, Prime q → q ∣ Qtwo - 1 →
    (3 ^ ((Qtwo - 1) / q)) % Qtwo ≠ 1 := by
  intro q hq hdv
  rw [qtsplit] at hdv
  rcases prime_dvd_mul hq hdv with dl2 | dr2
  · rcases prime_dvd_mul hq dl2 with dl4 | dr4
    · rcases prime_dvd_mul hq dl4 with dl6 | dr6
      · rcases prime_dvd_mul hq dl6 with dl8 | dr8
        · rcases prime_dvd_mul hq dl8 with dl10 | dr10
          · rcases prime_dvd_mul hq dl10 with dl12 | dr12
            · rcases prime_dvd_mul hq dl12 with dl14 | dr14
              · rcases prime_dvd_mul hq dl14 with dl16 | dr16
                · rcases prime_dvd_mul hq dl16 with dl18 | dr18
                  · rcases prime_dvd_mul hq dl18 with dl20 | dr20
                    · rcases prime_dvd_mul hq dl20 with dl22 | dr22
                      · rcases prime_dvd_mul hq dl22 with dl24 | dr24
                        · have eqq := prime_dvd_prime hq (pr2) dl24
                          subst eqq
                          exact ne_via_exp (by decide) hbqt0 vqt0
                        · have eqq := prime_dvd_prime hq (pr2) dr24
                          subst eqq
                          exact ne_via_exp (by decide) hbqt0 vqt0
                      · have eqq := prime_dvd_prime hq (pr2) dr22
                        subst eqq
                        exact ne_via_exp (by decide) hbqt0 vqt0
                    · have eqq := prime_dvd_prime hq (pr7) dr20
                      subst eqq
                      exact ne_via_exp (by decide) hbqt1 vqt1
                  · have eqq := prime_dvd_prime hq (pr7) dr18
                    subst eqq
                    exact ne_via_exp (by decide) hbqt1 vqt1
                · have eqq := prime_dvd_prime hq (pr11) dr16
                  subst eqq
                  exact ne_via_exp (by decide) hbqt2 vqt2
              · have eqq := prime_dvd_prime hq (pr1627) dr14
                subst eqq
                exact ne_via_exp (by decide) hbqt3 vqt3
            · have eqq := prime_dvd_prime hq (pr2657) dr12
              subst eqq
              exact ne_via_exp (by decide) hbqt4 vqt4
          · have eqq := prime_dvd_prime hq (pr4423) dr10
            subst eqq
            exact ne_via_exp (by decide) hbqt5 vqt5
        · have eqq := prime_dvd_prime hq (pr96557) dr8
          subst eqq
          exact ne_via_exp (by decide) hbqt7 vqt7
      · have eqq := prime_dvd_prime hq (pr41201) dr6
        subst eqq
        exact ne_via_exp (by decide) hbqt6 vqt6
    · have eqq := prime_dvd_prime hq (pr107590001) dr4
      subst eqq
      exact ne_via_exp (by decide) hbqt9 vqt9
  · have eqq := prime_dvd_prime hq (pr7240687) dr2
    subst eqq
    exact ne_via_exp (by decide) hbqt8 vqt8


/-- `Qtwo` is prime (Pratt certificate level). -/
private theorem Qtwo_prime : Prime Qtwo :=
  lucas_primality (N := Qtwo) (a := 3) (by decide) (by decide) qtexpl qt_hd

private def Cbig : Nat := 205115282021455665897114700593932402728804164701536103180137503955397371

private theorem csplit : Cbig - 1 = 2 * 3 * 5 * 29 * 29 * 31 * 7723 * Rbig * Qtwo := by decide

private def bscF : List Bool := [false, true, false, true, true, true, true, true, false, true, false, true, false, true, false, true, false, false, false, true, true, true, false, false, true, true, false, false, true, true, true, true, false, false, true, false, false, true, false, true, true, false, true, true, false, false, false, false, false, false, true, true, false, false, true, false, true, false, true, true, false, true, true, false, true, true, true, false, true, true, true, false, false, true, false, true, true, false, false, true, false, false, false, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, true, true, false, true, true, false, true, true, false, false, true, false, false, true, true, false, true, false, false, true, false, true, true, true, false, false, false, true, false, true, false, true, true, false, true, true, true, true, false, false, true, true, false, false, true, true, true, true, true, true, false, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, true, false, true, false, true, true, false, false, false, true, false, false, true, false, true, false, false, false, false, false, true, true, false, false, false, true, false, true, true, false, true, true, true, false, false, false, true, true, true, true, false, true, false, false, true, true, true, false, false, false, false, false, true, true, false, false, true, false, false, false, false, false, true, true, true, false, true, true, false, true, true, true]
private theorem hbcF : bitsVal bscF = 205115282021455665897114700593932402728804164701536103180137503955397370 := by decide
private theorem vcF : expBits Cbig 10 bscF = 1 := by decide
private theorem cexpl : (10 ^ (Cbig - 1)) % Cbig = 1 :=
  eq_via_exp (m := Cbig) (a := 10) (E := Cbig - 1) (by decide) hbcF vcF

private def bsc0 : List Bool := [true, false, true, true, true, true, true, false, true, false, true, false, true, false, true, false, false, false, true, true, true, false, false, true, true, false, false, true, true, true, true, false, false, true, false, false, true, false, true, true, false, true, true, false, false, false, false, false, false, true, true, false, false, true, false, true, false, true, true, false, true, true, false, true, true, true, false, true, true, true, false, false, true, false, true, true, false, false, true, false, false, false, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, true, true, false, true, true, false, true, true, false, false, true, false, false, true, true, false, true, false, false, true, false, true, true, true, false, false, false, true, false, true, false, true, true, false, true, true, true, true, false, false, true, true, false, false, true, true, true, true, true, true, false, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, true, false, true, false, true, true, false, false, false, true, false, false, true, false, true, false, false, false, false, false, true, true, false, false, false, true, false, true, true, false, true, true, true, false, false, false, true, true, true, true, false, true, false, false, true, true, true, false, false, false, false, false, true, true, false, false, true, false, false, false, false, false, true, true, true, false, true, true, false, true, true, true]
private theorem hbc0 : bitsVal bsc0 = 102557641010727832948557350296966201364402082350768051590068751977698685 := by decide
private theorem vc0 : expBits Cbig 10 bsc0 ≠ 1 := by decide
private def bsc1 : List Bool := [false, true, true, true, true, true, true, true, false, false, false, true, true, true, false, false, false, false, false, true, false, true, true, false, false, true, true, false, false, true, false, true, true, false, false, false, false, true, true, true, true, false, false, true, true, false, true, false, true, false, false, true, true, false, false, false, true, true, true, true, false, false, true, true, true, true, true, false, false, true, false, false, false, true, true, true, true, false, true, true, false, true, false, false, true, true, true, true, true, false, false, false, true, false, true, true, true, false, false, true, true, true, true, false, false, true, true, false, false, false, false, true, false, false, true, true, false, false, false, true, false, true, true, false, true, true, false, false, false, true, false, false, true, false, true, false, false, false, true, false, false, false, true, false, true, false, true, false, false, false, false, true, true, false, true, true, false, true, false, true, false, true, false, true, false, false, false, true, true, true, true, false, true, false, false, false, false, true, true, true, false, true, false, true, false, false, true, true, false, true, true, false, false, true, true, true, true, true, false, true, false, false, true, false, true, true, true, false, true, true, true, true, false, true, false, true, false, false, true, true, false, false, false, false, false, false, false, true, false, true, true, true, true, false, false, true]
private theorem hbc1 : bitsVal bsc1 = 68371760673818555299038233531310800909601388233845367726712501318465790 := by decide
private theorem vc1 : expBits Cbig 10 bsc1 ≠ 1 := by decide
private def bsc2 : List Bool := [false, true, false, false, true, true, false, false, false, true, false, false, false, true, false, false, false, false, false, true, true, false, true, true, true, true, false, false, false, true, true, false, true, true, true, false, false, false, false, true, true, true, true, true, false, false, true, true, false, false, false, true, false, true, false, true, false, true, false, false, false, true, true, true, true, true, true, false, true, false, false, false, false, true, false, false, true, false, true, false, true, true, false, true, false, true, false, false, true, false, false, false, true, true, false, true, false, true, false, false, false, true, true, true, true, true, false, false, false, false, false, true, true, true, true, false, false, false, false, true, true, false, true, true, false, true, true, true, false, true, false, true, false, false, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, false, true, false, true, true, false, true, true, false, false, true, true, false, false, true, true, true, false, true, true, true, true, false, false, true, false, true, true, true, false, true, true, false, false, true, true, true, true, false, false, true, false, true, false, false, false, true, true, false, true, true, false, true, false, false, true, false, false, false, false, true, true, false, true, true, false, false, true, false, false, false, false, true, false, true, true, false, false, false, true, true, true, true, true, false, true]
private theorem hbc2 : bitsVal bsc2 = 41023056404291133179422940118786480545760832940307220636027500791079474 := by decide
private theorem vc2 : expBits Cbig 10 bsc2 ≠ 1 := by decide
private def bsc3 : List Bool := [false, true, false, false, false, false, true, true, true, false, false, true, true, false, true, true, false, false, false, false, false, true, false, true, true, false, true, false, true, false, false, true, false, false, true, false, false, true, false, true, true, true, true, false, true, true, true, true, false, false, false, false, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, false, true, true, false, true, false, true, false, true, true, true, false, true, true, false, true, false, true, false, false, false, true, true, true, false, true, false, true, true, true, true, true, true, true, false, true, false, false, true, false, false, false, true, false, true, true, true, false, false, false, false, false, true, false, true, false, false, false, true, true, true, false, false, true, false, true, true, true, false, false, true, true, true, true, false, false, true, false, true, false, true, true, true, false, true, true, false, false, false, true, false, false, false, false, true, true, true, true, false, true, false, true, true, false, false, true, true, true, true, true, true, false, false, true, false, true, false, false, false, false, true, false, true, true, false, true, true, true, true, true, false, false, false, false, false, true, false, false, true, false, true, true, false, true, false, false, true, true, false, false, true, true, false, true, false, false, true, true, false, false, false, false, false, true]
private theorem hbc3 : bitsVal bsc3 = 7072940759360540203348782779101117335476005679363313902763362205358530 := by decide
private theorem vc3 : expBits Cbig 10 bsc3 ≠ 1 := by decide
private def bsc4 : List Bool := [false, true, true, false, false, false, true, true, true, false, true, true, false, false, false, false, true, false, false, true, false, true, true, true, true, false, false, true, false, false, true, false, false, false, true, false, false, true, true, true, false, true, true, true, false, false, true, true, true, false, true, true, false, true, true, false, false, false, false, false, false, true, false, true, false, false, true, true, true, false, false, false, true, false, false, true, false, false, false, true, false, false, false, true, true, true, false, false, true, false, false, false, true, true, false, true, false, false, false, true, false, true, false, true, true, false, false, false, false, true, false, true, false, true, true, true, false, true, false, false, false, true, false, false, false, true, false, true, true, false, true, true, true, true, false, true, false, true, false, true, false, false, false, true, true, false, false, false, false, true, false, true, true, true, false, true, false, true, true, false, true, false, true, true, false, false, false, false, true, true, false, true, true, false, false, false, true, false, false, true, true, false, false, false, true, false, true, true, true, false, true, false, false, false, false, false, true, false, true, true, true, true, false, true, true, false, false, false, true, false, true, false, true, false, false, true, false, false, true, true, false, true, true, false, true, false, true, false, true, true, true, true]
private theorem hbc4 : bitsVal bsc4 = 6616622000692118254745635503030077507380779506501164618714113030819270 := by decide
private theorem vc4 : expBits Cbig 10 bsc4 ≠ 1 := by decide
private def bsc5 : List Bool := [false, true, true, true, false, true, true, true, true, false, true, true, true, false, true, false, true, false, true, false, true, true, true, true, true, true, false, true, true, false, false, true, false, false, true, true, false, false, true, true, true, true, false, false, true, false, true, false, false, false, true, false, false, false, true, false, false, false, false, false, false, true, false, false, false, true, true, true, true, true, true, true, false, false, false, true, true, true, true, true, true, true, false, false, false, false, false, false, false, true, false, true, true, true, true, true, true, false, true, false, false, true, true, false, true, false, true, true, false, true, false, false, false, false, true, false, false, true, true, true, false, false, false, false, false, false, true, false, true, true, false, false, true, true, true, false, false, false, false, true, false, true, false, true, false, true, false, false, false, true, false, false, true, false, false, true, true, false, true, false, true, false, true, true, true, false, true, true, true, true, false, false, true, false, false, false, true, false, false, true, true, false, false, true, false, false, true, false, true, true, false, true, true, false, false, true, true, false, true, false, false, false, true, false, false, true, true, false, true, false, false, false, true, true, false, false, false, false, true, true, true, true, true, true]
private theorem hbc5 : bitsVal bsc5 = 26559016188198325248881872406310035313842310591937861346644762910190 := by decide
private theorem vc5 : expBits Cbig 10 bsc5 ≠ 1 := by decide
private def bsc6 : List Bool := [false, true, true, false, true, false, true, true, false, true, false, true, true, true, true, false, true, false, false, false, false, true, true, false, false, true, true, true, false, false, true, false, false, false, false, false, false, false, true, true, false, true, true, true, false, true, false, true, false, true, true, true, true, true, false, false, true, false, true, false, true, true, false, true, false, false, true, true, true, true, true, true, false, false, true, true, true, true, false, false, true, false, true, true, false, false, false, true, false, false, true, false, true, true, true, true, true, true, true, true, false, false, false, true, true, true, false, true, false, false, true, true, false, true, true, false, true, false, true, true, false, true, false, true, true, false, true, false, true, false, false, true, true, true, false, false, false, true, false, true, false, true, false, false, true, false, false, true, true, false, true, false, false, true, true, true, false, false, false, false, true]
private theorem hbc6 : bitsVal bsc6 = 1543415952677955745309227852991199086604869270230 := by decide
private theorem vc6 : expBits Cbig 10 bsc6 ≠ 1 := by decide
private def bsc7 : List Bool := [false, true, false, true, false, true, true, true, true, true, false, false, true, true, false, false, true, false, true, false, true, true, true, true, true, true, true, false, false, false, false, false, false, false, true, true, true, true, true, true, true, false, false, false, false, false, false, true, true, false, false, false, true, true, true, false, true, true, false, false, false, false, false, false, false, false, true, true, true, true, false, false, true, true, false, true, true, true, true, true, true, true, true, false, true, false, true, false, true, true, true, true, true, false, false, false, false, false, true, false, true, false, false, true, true, true, true, false, false, true]
private theorem hbc7 : bitsVal bsc7 = 802749442992798076634733441528810 := by decide
private theorem vc7 : expBits Cbig 10 bsc7 ≠ 1 := by decide

private theorem c_hd : ∀ q : Nat, Prime q → q ∣ Cbig - 1 →
    (10 ^ ((Cbig - 1) / q)) % Cbig ≠ 1 := by
  intro q hq hdv
  rw [csplit] at hdv
  rcases prime_dvd_mul hq hdv with dl2 | dr2
  · rcases prime_dvd_mul hq dl2 with dl4 | dr4
    · rcases prime_dvd_mul hq dl4 with dl6 | dr6
      · rcases prime_dvd_mul hq dl6 with dl8 | dr8
        · rcases prime_dvd_mul hq dl8 with dl10 | dr10
          · rcases prime_dvd_mul hq dl10 with dl12 | dr12
            · rcases prime_dvd_mul hq dl12 with dl14 | dr14
              · rcases prime_dvd_mul hq dl14 with dl16 | dr16
                · have eqq := prime_dvd_prime hq (pr2) dl16
                  subst eqq
                  exact ne_via_exp (by decide) hbc0 vc0
                · have eqq := prime_dvd_prime hq (pr3) dr16
                  subst eqq
                  exact ne_via_exp (by decide) hbc1 vc1
              · have eqq := prime_dvd_prime hq (pr5) dr14
                subst eqq
                exact ne_via_exp (by decide) hbc2 vc2
            · have eqq := prime_dvd_prime hq (pr29) dr12
              subst eqq
              exact ne_via_exp (by decide) hbc3 vc3
          · have eqq := prime_dvd_prime hq (pr29) dr10
            subst eqq
            exact ne_via_exp (by decide) hbc3 vc3
        · have eqq := prime_dvd_prime hq (pr31) dr8
          subst eqq
          exact ne_via_exp (by decide) hbc4 vc4
      · have eqq := prime_dvd_prime hq (pr7723) dr6
        subst eqq
        exact ne_via_exp (by decide) hbc5 vc5
    · have eqq := prime_dvd_prime hq (Rbig_prime) dr4
      subst eqq
      exact ne_via_exp (by decide) hbc6 vc6
  · have eqq := prime_dvd_prime hq (Qtwo_prime) dr2
    subst eqq
    exact ne_via_exp (by decide) hbc7 vc7


/-- `Cbig` is prime (Pratt certificate level). -/
private theorem Cbig_prime : Prime Cbig :=
  lucas_primality (N := Cbig) (a := 10) (by decide) (by decide) cexpl c_hd

/-! ## Level: P -/

private theorem psplit : P - 1 = 2 * 3 * 7 * 13441 * Cbig := by decide

private def bspF : List Bool := [false, true, true, true, false, true, false, false, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true]
private theorem hbpF : bitsVal bspF = 115792089237316195423570985008687907853269984665640564039457584007908834671662 := by decide
private theorem vpF : expBits P 3 bspF = 1 := by decide
private theorem pexpl : (3 ^ (P - 1)) % P = 1 :=
  eq_via_exp (m := P) (a := 3) (E := P - 1) (by decide) hbpF vpF

private def bsp0 : List Bool := [true, true, true, false, true, false, false, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true]
private theorem hbp0 : bitsVal bsp0 = 57896044618658097711785492504343953926634992332820282019728792003954417335831 := by decide
private theorem vp0 : expBits P 3 bsp0 ≠ 1 := by decide
private def bsp1 : List Bool := [false, true, false, true, true, true, false, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true]
private theorem hbp1 : bitsVal bsp1 = 38597363079105398474523661669562635951089994888546854679819194669302944890554 := by decide
private theorem vp1 : expBits P 3 bsp1 ≠ 1 := by decide
private def bsp2 : List Bool := [false, true, false, false, false, true, true, true, false, true, false, true, true, false, true, true, false, true, true, false, true, true, false, true, true, false, true, true, false, true, true, false, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true]
private theorem hbp2 : bitsVal bsp2 = 16541727033902313631938712144098272550467140666520080577065369143986976381666 := by decide
private theorem vp2 : expBits P 3 bsp2 ≠ 1 := by decide
private def bsp3 : List Bool := [false, true, true, true, false, true, false, false, true, false, true, true, false, false, false, false, false, false, true, true, false, false, true, false, true, true, true, false, false, true, true, true, true, true, true, true, false, false, false, false, true, false, true, true, true, true, false, false, false, true, false, true, true, true, true, false, false, true, true, true, false, true, true, true, true, true, true, false, true, false, false, true, true, true, true, false, true, false, true, false, true, false, false, true, false, false, false, true, true, false, true, false, true, false, true, false, true, false, true, false, true, true, true, true, true, true, true, true, false, true, false, false, false, true, false, true, false, true, false, false, true, false, false, true, true, false, true, true, false, true, true, false, true, true, true, false, false, false, false, false, false, true, false, true, true, true, true, false, true, false, false, true, true, true, true, false, false, true, true, false, true, false, false, false, false, false, true, false, false, true, true, false, true, false, false, true, true, true, true, true, false, true, false, true, true, false, true, true, true, true, true, false, true, false, false, true, true, true, false, true, true, false, true, false, true, true, true, false, true, true, false, true, true, false, true, false, false, true, true, true, true, true, false, false, false, true, true, false, true, true, false, false, false, false, false, false, false, true, true, true, false, false, true]
private theorem hbp3 : bitsVal bsp3 = 8614841844901137967678817424945160914609774917464516333565775166126689582 := by decide
private theorem vp3 : expBits P 3 bsp3 ≠ 1 := by decide
private def bsp4 : List Bool := [false, true, false, true, false, true, false, false, true, false, true, true, true, false, false, true, false, false, false, true]
private theorem hbp4 : bitsVal bsp4 = 564522 := by decide
private theorem vp4 : expBits P 3 bsp4 ≠ 1 := by decide

private theorem p_hd : ∀ q : Nat, Prime q → q ∣ P - 1 →
    (3 ^ ((P - 1) / q)) % P ≠ 1 := by
  intro q hq hdv
  rw [psplit] at hdv
  rcases prime_dvd_mul hq hdv with dl2 | dr2
  · rcases prime_dvd_mul hq dl2 with dl4 | dr4
    · rcases prime_dvd_mul hq dl4 with dl6 | dr6
      · rcases prime_dvd_mul hq dl6 with dl8 | dr8
        · have eqq := prime_dvd_prime hq (pr2) dl8
          subst eqq
          exact ne_via_exp (by decide) hbp0 vp0
        · have eqq := prime_dvd_prime hq (pr3) dr8
          subst eqq
          exact ne_via_exp (by decide) hbp1 vp1
      · have eqq := prime_dvd_prime hq (pr7) dr6
        subst eqq
        exact ne_via_exp (by decide) hbp2 vp2
    · have eqq := prime_dvd_prime hq (pr13441) dr4
      subst eqq
      exact ne_via_exp (by decide) hbp3 vp3
  · have eqq := prime_dvd_prime hq (Cbig_prime) dr2
    subst eqq
    exact ne_via_exp (by decide) hbp4 vp4


/-- `P` is prime (Pratt certificate level). -/
private theorem P_prime : Prime P :=
  lucas_primality (N := P) (a := 3) (by decide) (by decide) pexpl p_hd

/-! ## Coprimality of small residues with P -/

/-- Every `0 < x < P` is invertible mod `P` (consequence of `P_prime`). -/
theorem gcd_P_of_lt (x : Nat) (hx : 0 < x) (hlt : x < P) : Nat.gcd P x = 1 := by
  have h1 : Nat.gcd P x ∣ P := Nat.gcd_dvd_left P x
  have h2 : Nat.gcd P x ∣ x := Nat.gcd_dvd_right P x
  rcases P_prime.2 (Nat.gcd P x) h1 with h | h
  · exact h
  · exfalso
    have h3 : P ∣ x := by rw [← h]; exact h2
    have hle : P ≤ x := Nat.le_of_dvd hx h3
    omega

/-! ## Field operations (delegating to `Bitcoin.Crypto.Curve.Mod`) -/

/-- Field addition mod `P`. -/
def feAdd (a b : Fe) : Fe :=
  ⟨addM P a.val b.val, addM_lt P a.val b.val P_pos⟩

/-- Field multiplication mod `P`. -/
def feMul (a b : Fe) : Fe :=
  ⟨mulM P a.val b.val, mulM_lt P a.val b.val P_pos⟩

/-- Field negation mod `P`. -/
def feNeg (a : Fe) : Fe :=
  ⟨subM P 0 a.val, subM_lt P 0 a.val P_pos⟩

/-- Field multiplicative inverse mod `P` (with `invM 0 = 0` for the
degenerate input; `feInv_correct` covers `a ≠ feZero`). -/
def feInv (a : Fe) : Fe :=
  ⟨invM P a.val, invM_lt P a.val P_pos⟩

/-! ## Frozen laws (the modular-arithmetic layer exit criteria) -/

/-- `feAdd` respects the canonical representative (p | carry). -/
theorem feAdd_spec (a b : Fe) : (feAdd a b).val = (a.val + b.val) % P :=
  rfl

/-- `feMul` respects the canonical representative. -/
theorem feMul_spec (a b : Fe) : (feMul a b).val = (a.val * b.val) % P :=
  rfl

/-- Inverse correctness (the modular-arithmetic layer headline; safegcd lineage). -/
theorem feInv_correct (a : Fe) (ha : a ≠ feZero) :
    feMul (feInv a) a = feOne := by
  have hav : 0 < a.val := by
    have h0 : a.val ≠ 0 := fun h0 => ha (Subtype.ext h0)
    omega
  have hcop : Nat.gcd P a.val = 1 := gcd_P_of_lt a.val hav a.property
  have hinv : (a.val * invM P a.val) % P = 1 :=
    invM_correct P a.val P_gt_one hav hcop
  refine Subtype.ext ?_
  show ((invM P a.val) * a.val) % P = 1
  rw [Nat.mul_comm, hinv]

end Bitcoin.Crypto.Field
