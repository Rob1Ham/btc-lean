import Bitcoin.Data.Basic
import Bitcoin.Crypto.Curve.Mod
import Bitcoin.Crypto.Field.Interface

/-!
# Bitcoin.Crypto.Curve.Secp — the secp256k1 group law (zero-dependency)

Affine point arithmetic over the field representation (`Nat`, `x < P`
invariant re-established by every op; see `Curve.Mod`). This is the group-law
layer over the field representation; the field-arithmetic prototype is its level-2A counterpart.

## Point representation

`RawPoint := Option (Nat × Nat)` at the computation layer;
`AffinePoint := Option (Fe × Fe)` (the frozen interface type,
`Fe = {x : Nat // x < P}`) at the API layer. `none` is the point at
infinity 𝒪. All group operations are **total** — the case table of `addP`
is complete and every branch returns a defined value, which is a consensus
requirement: script evaluation must be a pure total function (BIP340
§design: "completely specified at the byte level").

## The addition law (a = 0, b = 7; Core: src/crypto/secp256k1 group.h)

For P₁ = (x₁,y₁), P₂ = (x₂,y₂):
* P₁ = 𝒪 or P₂ = 𝒪              → the other point;
* x₁ = x₂ ∧ y₁ = y₂             → doubling (𝒪 when y₁ = 0: vertical tangent);
* x₁ = x₂ ∧ y₁ = −y₂            → 𝒪 (vertical chord);
* otherwise                     → λ = (y₂−y₁)·(x₂−x₁)⁻¹, x₃ = λ²−x₁−x₂,
                                  y₃ = λ(x₁−x₃)−y₁.

Division is `invP` (extended-Euclid inverse, `Curve.Mod.invM`); `invP 0 = 0`
keeps every branch defined even for off-curve garbage inputs.

## Where the equation-preservation proofs live

Proving that the chord/tangent formulas preserve `y² = x³ + 7` needs modular
cancellation, i.e. invertibility of every nonzero residue — P's primality.
Per the recommendation (the field-arithmetic notes §6 item 4) the closure theorems are
proved in the `proofs` package over `ZMod P` (mathlib's proved Weierstrass
group law + `field_simp`/`ring` automation; `BitcoinProofs.Crypto.CurveZMod`),
bridged to these executable definitions. Core stays zero-dep and axiom-light;
the conformance vectors exercise the executable paths directly.

## Even-y / lift_x (BIP340 §lift_x; BIP341 tweak keys)

`liftX x` returns the point with x-coordinate `x` whose y is EVEN (BIP340:
"implementations MUST use the even-y convention"); `none` when x ≥ P or
x³+7 is not a quadratic residue. The square root (p ≡ 3 mod 4 ⇒ root =
(x³+7)^((P+1)/4)) supplies the candidate; the two roots are `r, P−r`,
exactly one even (P odd). `liftX`'s correctness theorem is conditional on
the runtime residue check the code performs — no primality needed.
-/

namespace Bitcoin.Crypto.Curve.Secp

open Bitcoin.Crypto.Curve.Mod

/-! ## Constants -/

/-- The field prime (frozen in `Bitcoin.Crypto.Field`). -/
abbrev P : Nat := Bitcoin.Crypto.Field.P

theorem P_pos : 0 < P := by decide
theorem P_gt_one : 1 < P := by decide
theorem P_odd : P % 2 = 1 := by decide

/-- The group order
n = 0xFFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFE BAAEDCE6
AF48A03B BFD25E8C D0364141 (SEC2 secp256k1; BIP340 §group order). -/
def n : Nat :=
  0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

theorem n_pos : 0 < n := by decide
theorem n_gt_one : 1 < n := by decide

/-- Curve constant b = 7 (a = 0). -/
def curveB : Nat := 7

/-- The generator G x-coordinate (SEC2 secp256k1 base point). -/
def Gx : Nat := 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798

/-- The generator G y-coordinate. -/
def Gy : Nat := 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8

theorem Gx_lt : Gx < P := by decide
theorem Gy_lt : Gy < P := by decide

/-- The generator as a raw point. -/
def G : Nat × Nat := (Gx, Gy)

/-- (P+1)/4, the square-root exponent for p ≡ 3 (mod 4) (the modular-arithmetic layer `sqrtExp`). -/
def sqrtExp : Nat := (P + 1) / 4

/-! ## The curve equation -/

/-- Curve equation on raw representatives: `y² = x³ + 7 (mod P)`.
Sign-correct form — BIP-0340-vector bugfix, ported (the first version
encoded `x³ = y² + 7`, the negated-b cousin, and all 18 on-curve BIP-0340
keys failed). -/
def onCurveN (x y : Nat) : Bool :=
  mulM P y y == addM P (mulM P (mulM P x x) x) curveB

/-- Prop-level form: congruent-representative equality. -/
def OnCurve (x y : Nat) : Prop := (y * y) % P = (x * x * x + curveB) % P

theorem onCurveN_true {x y : Nat} (h : onCurveN x y = true) : OnCurve x y := by
  have he : mulM P y y = addM P (mulM P (mulM P x x) x) curveB := Nat.beq_eq.mp h
  unfold OnCurve at *
  unfold mulM addM at he
  rw [he, mul_mod_congr_left, Nat.mod_add_mod]

theorem onCurveN_of_OnCurve {x y : Nat} (h : OnCurve x y) :
    onCurveN x y = true := by
  have h1 : mulM P y y = y * y % P := rfl
  have h2 : addM P (mulM P (mulM P x x) x) curveB = (x * x * x + curveB) % P := by
    unfold addM mulM
    rw [mul_mod_congr_left, Nat.mod_add_mod]
  unfold onCurveN
  rw [h1, h2]
  exact Nat.beq_eq.mpr h

/-- The generator is on the curve (kernel-checked on the 256-bit literals;
mirrored against the BIP-0340 corpus at runtime in the test layer).
SGN-101: secp256k1 domain parameters — G on curve (src/key.cpp init / group.h SECP256K1_G). -/
@[rule "SGN-101"]
theorem G_onCurve : OnCurve Gx Gy := by
  unfold OnCurve
  decide

theorem onCurveN_G : onCurveN Gx Gy = true :=
  onCurveN_of_OnCurve G_onCurve

/-! ## y-negation -/

/-- Negation of the y-coordinate: `−y = P − y (mod P)`. -/
def negN (y : Nat) : Nat := subM P 0 y

theorem negN_lt (y : Nat) : negN y < P := subM_lt P 0 y P_pos

theorem add_negN_zero {y : Nat} (hy : y < P) : addM P (negN y) y = 0 :=
  addM_subM_zero P y P_pos hy

theorem negN_zero {y : Nat} (hy : y < P) (hz : y = 0) : negN y = 0 := by
  subst hz; simp [negN, subM]

/-- Negation preserves the curve equation: `(P−y)² ≡ y² (mod P)` — proved
over `Int` (Nat truncated subtraction would bite: `2y` may exceed `P`). -/
theorem OnCurve_negN {x y : Nat} (hy : y < P) (h : OnCurve x y) : OnCurve x (negN y) := by
  unfold OnCurve negN subM
  rw [Nat.zero_add, mul_mod_congr_left, mul_mod_congr_right, ← h]
  -- goal: ((P - y) * (P - y)) % P = (y * y) % P
  have hdown : ((P - y) * (P - y)) % P = (y * y) % P := by
    -- bridge through `Int`: `P − y ≡ −y (mod P)`, and negation is multiplicative
    have hsub : ((P - y : Nat) : Int) = (P : Int) - (y : Int) :=
      Int.natCast_sub (show y ≤ P by omega)
    have e1 : ((P - y : Nat) : Int) % (P : Int) = (-(y : Int)) % (P : Int) := by
      rw [hsub]
      have h2 : (P : Int) - (y : Int) = (P : Int) * 1 + (-(y : Int)) := by omega
      rw [h2, Int.mul_add_emod_self_left]
    have t1 : (((P - y) * (P - y) % P : Nat) : Int) = ((y * y % P : Nat) : Int) := by
      rw [Int.natCast_emod, Int.natCast_mul, Int.natCast_emod, Int.natCast_mul,
        Int.mul_emod, e1, ← Int.mul_emod, Int.neg_mul_neg]
    exact Int.ofNat_inj.mp t1
  exact hdown

/-! ## Modular inverse and square root at the secp256k1 constants -/

/-- Field inverse (extended Euclid, `Curve.Mod.invM` at `P`). -/
def invP (d : Nat) : Nat := invM P d

theorem invP_lt (d : Nat) : invP d < P := invM_lt P d P_pos

/-- `invP 0 = 0` (defined behavior; egcd P 0 = (P,1,0), g = P ≠ 1). -/
theorem invP_zero : invP 0 = 0 := by
  unfold invP invM
  simp only [egcd]
  simp

/-- Inverse correctness at `P` (from `Mod.invM_correct` + coprimality).
The coprimality of a nonzero residue with P is exactly P's primality —
discharged in the proofs package (`CurveZMod.secp_P_coprime`); here it is a
hypothesis, never an axiom. -/
theorem invP_correct {d : Nat} (hd : 0 < d) (_hdP : d < P)
    (hcop : Nat.gcd P d = 1) : (d * invP d) % P = 1 :=
  invM_correct P d P_gt_one hd hcop

/-- Square root for p ≡ 3 (mod 4): `r = x^((P+1)/4)`; `r² = x (mod P)` iff x
is a nonzero quadratic residue (checked at runtime by the caller; report §2.3). -/
def sqrtP (x : Nat) : Nat := expM P x sqrtExp

/-- The residue test used by `liftX`: does `r² = x (mod P)`? -/
def isSqrt (x r : Nat) : Bool := mulM P r r == x

/-! ## Raw points -/

/-- A raw affine point: `none` = 𝒪, `some (x, y)` with `x, y` intended in
`[0, P)` (invariant tracked by `RawOK` below). -/
abbrev RawPoint := Option (Nat × Nat)

/-- The coordinate invariant: every concrete coordinate is a canonical
field representative. -/
def RawOK : RawPoint → Prop
  | none => True
  | some (x, y) => x < P ∧ y < P

theorem RawOK.some {x y : Nat} (hx : x < P) (hy : y < P) : RawOK (some (x, y)) :=
  ⟨hx, hy⟩

/-! ## The group operations (total, case-complete) -/

/-- Negation of a point: `−(x,y) = (x,−y)`; `−𝒪 = 𝒪`. -/
def negP : RawPoint → RawPoint
  | none => none
  | some (x, y) => some (x, negN y)

/-- Point doubling: `(x,y) ↦ (λ²−2x, λ(x−x₃)−y)` with `λ = 3x²·(2y)⁻¹`;
`𝒪 ↦ 𝒪`; `(x,0) ↦ 𝒪` (vertical tangent). -/
def doubleRaw (x y : Nat) : RawPoint :=
  if y == 0 then none else
    let lam := mulM P (mulM P 3 (mulM P x x)) (invP (addM P y y))
    let x3 := subM P (mulM P lam lam) (addM P x x)
    let y3 := subM P (mulM P lam (subM P x x3)) y
    some (x3, y3)

def doubleP : RawPoint → RawPoint
  | none => none
  | some (x, y) => doubleRaw x y

/-- Point addition (complete case table; see module docstring). The third
branch divides by `x₂−x₁`; when `x₁ = x₂` but `y₁ ∉ {y₂, −y₂}` (possible
only off the curve), `invP 0 = 0` keeps the result defined. -/
def addRaw (x1 y1 x2 y2 : Nat) : RawPoint :=
  if x1 == x2 && y1 == y2 then doubleRaw x1 y1
  else if x1 == x2 && y1 == negN y2 then none
  else
    let lam := mulM P (subM P y2 y1) (invP (subM P x2 x1))
    let x3 := subM P (subM P (mulM P lam lam) x1) x2
    let y3 := subM P (mulM P lam (subM P x1 x3)) y1
    some (x3, y3)

def addP : RawPoint → RawPoint → RawPoint
  | none, q => q
  | p, none => p
  | some (x1, y1), some (x2, y2) => addRaw x1 y1 x2 y2

/-- Scalar multiplication by double-and-add (LSB first; `k ≥ 2^256` allowed —
consensus callers stay below `n`). -/
def mulP (k : Nat) (p : RawPoint) : RawPoint :=
  match k with
  | 0 => none
  | k' + 1 =>
    if (k' + 1) % 2 == 0 then doubleP (mulP ((k' + 1) / 2) p)
    else addP p (doubleP (mulP ((k' + 1) / 2) p))
termination_by k
decreasing_by
  · exact Nat.div_lt_self (by omega) (by decide)
  · exact Nat.div_lt_self (by omega) (by decide)

/-- `k * 0 = ...`: scalar mult by zero is 𝒪. -/
theorem mulP_zero (p : RawPoint) : mulP 0 p = none := by
  simp only [mulP]

/-- Scalar mult by one is the point itself (the double-and-add pipeline
`1/2 = 0`, `1 % 2 = 1`, `addP p none = p` unravels). -/
theorem addP_none (p : RawPoint) : addP p none = p := by
  cases p <;> rfl

theorem doubleP_none : doubleP none = none := rfl

theorem mulP_one (p : RawPoint) : mulP 1 p = p := by
  rw [mulP.eq_def]
  show addP p (doubleP (mulP 0 p)) = p
  rw [mulP_zero, doubleP_none, addP_none]

/-! ## The invariant `RawOK` is preserved by every operation

Every coordinate that leaves an operation is the output of `mulM`/`addM`/
`subM` (all `< P` by `Mod._lt`) or of `invP` (`invM_lt`), so the invariant
needs no primality — it is bookkeeping of representatives. -/

theorem negP_ok (p : RawPoint) (hp : RawOK p) : RawOK (negP p) := by
  cases p with
  | none => exact trivial
  | some pt =>
    obtain ⟨x, y⟩ := pt
    obtain ⟨hx, -⟩ := hp
    exact RawOK.some hx (negN_lt y)

theorem doubleRaw_ok {x y : Nat} (_hx : x < P) (_hy : y < P) :
    RawOK (doubleRaw x y) := by
  unfold doubleRaw
  split
  · exact trivial
  · refine RawOK.some (subM_lt P _ _ P_pos) (subM_lt P _ _ P_pos)

theorem doubleP_ok (p : RawPoint) (hp : RawOK p) : RawOK (doubleP p) := by
  cases p with
  | none => exact trivial
  | some pt =>
    obtain ⟨x, y⟩ := pt
    obtain ⟨hx, hy⟩ := hp
    exact doubleRaw_ok hx hy

theorem addRaw_ok {x1 y1 x2 y2 : Nat} (hx1 : x1 < P) (hy1 : y1 < P)
    (_hx2 : x2 < P) (_hy2 : y2 < P) : RawOK (addRaw x1 y1 x2 y2) := by
  unfold addRaw
  split
  · exact doubleRaw_ok hx1 hy1
  · split
    · exact trivial
    · exact RawOK.some (subM_lt P _ _ P_pos) (subM_lt P _ _ P_pos)

theorem addP_ok (p q : RawPoint) (hp : RawOK p) (hq : RawOK q) : RawOK (addP p q) := by
  cases p with
  | none => exact hq
  | some a =>
    cases q with
    | none => exact hp
    | some b =>
      obtain ⟨x1, y1⟩ := a
      obtain ⟨x2, y2⟩ := b
      obtain ⟨hx1, hy1⟩ := hp
      obtain ⟨hx2, hy2⟩ := hq
      exact addRaw_ok hx1 hy1 hx2 hy2

/-- Scalar multiplication preserves `RawOK` (strong induction on `k`; proof
shape mirrors `Mod.expM_lt`, the standard way through WF definitions). -/
theorem mulP_ok (p : RawPoint) (hp : RawOK p) : ∀ k : Nat, RawOK (mulP k p) := by
  intro k
  induction k using Nat.strongRecOn with
  | ind k ih =>
    cases k with
    | zero => simp only [mulP, RawOK]
    | succ k' =>
      by_cases he : (k' + 1) % 2 == 0
      · simp only [mulP, he]
        exact doubleP_ok _ (ih _ (Nat.div_lt_self (by omega) (by omega)))
      · simp only [mulP, he]
        exact addP_ok p _ hp (doubleP_ok _ (ih _ (Nat.div_lt_self (by omega) (by omega))))

/-! ## lift_x (BIP340) with the even-y convention

`liftX x` = the point with x-coordinate `x` and even y, or `none` when
`x ≥ P` or `x³+7` is a non-residue. The residue check `isSqrt` is performed
at runtime, so `liftX_onCurve` below needs **no primality**: it only uses
that the code's own check passed. -/

/-- `x³ + 7 (mod P)` — the RHS of the curve equation at `x`. -/
def liftY2 (x : Nat) : Nat := addM P (mulM P (mulM P x x) x) curveB

/-- Square-root candidate: `r = (x³+7)^((P+1)/4)` (the modular-arithmetic layer §2.3, `p ≡ 3 mod 4`). -/
def liftCand (x : Nat) : Nat := sqrtP (liftY2 x)

theorem liftCand_lt (x : Nat) : liftCand x < P := expM_lt P _ _ P_gt_one

/-- Even-y pick: of the two roots `r, P−r` exactly one is even (`P` odd). -/
def liftPick (r : Nat) : Nat := if r % 2 == 0 then r else negN r

theorem liftPick_lt (r : Nat) (hr : r < P) : liftPick r < P := by
  unfold liftPick
  split
  · exact hr
  · exact negN_lt _

/-- `lift_x` (BIP340 §lift_x): the even-y point with x-coordinate `x`. -/
@[rule "TPR-054"]
def liftX (x : Nat) : RawPoint :=
  if P ≤ x then none
  else if isSqrt (liftY2 x) (liftCand x) then some (x, liftPick (liftCand x))
  else none

theorem liftX_ok (x : Nat) : RawOK (liftX x) := by
  unfold liftX
  split
  · exact trivial
  · split
    · exact RawOK.some (by omega) (liftPick_lt _ (liftCand_lt x))
    · exact trivial

/-- The x-coordinate is preserved (BIP340: "fail if x ≥ p"; otherwise the
returned point has x-coordinate `x`). -/
theorem liftX_snd {x x' y' : Nat} (h : liftX x = some (x', y')) : x' = x := by
  unfold liftX at h
  split at h
  · exact absurd h (by simp)
  · split at h
    · simp at h
      exact h.1.symm
    · exact absurd h (by simp)

/-- `y` is even (BIP340 even-y convention; `P` is odd so exactly one of
`r, P−r` is even). -/
theorem liftX_even {x x' y' : Nat} (h : liftX x = some (x', y')) :
    y' % 2 = 0 := by
  unfold liftX at h
  split at h
  · exact absurd h (by simp)
  · split at h
    · simp at h
      obtain ⟨-, hy⟩ := h
      unfold liftPick at hy
      split at hy
      · rw [← hy]
        rename_i hr
        exact Nat.beq_eq.mp hr
      · rw [← hy]
        rename_i hr
        have h1 : ¬ (liftCand x % 2 = 0) := fun hh => hr (by rw [hh]; rfl)
        have h2 : liftCand x < P := liftCand_lt x
        have h3 : P % 2 = 1 := P_odd
        have hpos : 0 < liftCand x := by omega
        unfold negN subM
        rw [Nat.zero_add, Nat.mod_eq_of_lt (show P - liftCand x < P by omega)]
        omega
    · exact absurd h (by simp)

/-- The lifted point is on the curve — conditional only on the runtime
`isSqrt` check the code itself performs, never on `P`'s primality. -/
@[rule "TPR-049"]
theorem liftX_onCurve {x x' y' : Nat} (h : liftX x = some (x', y')) :
    OnCurve x' y' := by
  unfold liftX at h
  split at h
  · exact absurd h (by simp)
  · split at h
    · simp only [Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, hy⟩ := h
      rename_i hchk
      -- the runtime check said r² = x³+7 (mod P)
      have hchk' : (liftCand x * liftCand x) % P = (x * x * x + curveB) % P := by
        have he := Nat.beq_eq.mp hchk
        unfold isSqrt at he
        simp only [mulM, addM, liftY2] at he
        rw [mul_mod_congr_left, Nat.mod_add_mod] at he
        exact he
      have hbase : OnCurve x (liftCand x) := by
        unfold OnCurve
        rw [hchk']
      unfold liftPick at hy
      split at hy
      · rw [← hy]; exact hbase
      · rw [← hy]; exact OnCurve_negN (liftCand_lt x) hbase
    · exact absurd h (by simp)

/-- A canonical residue is a quadratic residue when it has a square root
in `[0, P)`. This is the predicate behind BIP340's non-QR failure gate. -/
def IsQR (a : Nat) : Prop := ∃ r, r < P ∧ (r * r) % P = a

/-- A passing `isSqrt` check exhibits a square root, hence a quadratic
residue. No primality of `P` is needed for this direction. -/
theorem isQR_of_isSqrt {a r : Nat} (hr : r < P) (h : isSqrt a r = true) :
    IsQR a := by
  refine ⟨r, hr, ?_⟩
  unfold isSqrt at h
  have he := Nat.beq_eq.mp h
  unfold mulM at he
  exact he

/-- The code's residue check is `false` on a non-residue. -/
theorem isSqrt_eq_false_of_not_isQR {a r : Nat} (hr : r < P)
    (h : ¬ IsQR a) : isSqrt a r = false := by
  cases hb : isSqrt a r with
  | false => rfl
  | true => exact absurd (isQR_of_isSqrt hr hb) h

/-- **TPR-049** (failure face): `x ≥ p` fails the lift. -/
@[rule "TPR-049"]
theorem liftX_none_of_ge {x : Nat} (h : P ≤ x) : liftX x = none := by
  unfold liftX
  rw [ite_eq_left h]

/-- **TPR-049** (failure face): a non-QR `x³+7` fails the lift. -/
@[rule "TPR-049"]
theorem liftX_none_of_not_isQR {x : Nat} (h : ¬ IsQR (liftY2 x)) :
    liftX x = none := by
  unfold liftX
  by_cases hx : P ≤ x
  · rw [ite_eq_left hx]
  · rw [ite_eq_right hx]
    have hf : isSqrt (liftY2 x) (liftCand x) = false :=
      isSqrt_eq_false_of_not_isQR (liftCand_lt x) h
    rw [ite_eq_right (by simp [hf])]

/-- **TPR-049** (gate iff): `liftX` returns `none` exactly on `x ≥ P`
or a failed residue check. -/
@[rule "TPR-049"]
theorem liftX_none_iff (x : Nat) :
    liftX x = none ↔ P ≤ x ∨ isSqrt (liftY2 x) (liftCand x) = false := by
  unfold liftX
  by_cases hx : P ≤ x
  · simp [hx]
  · by_cases hs : isSqrt (liftY2 x) (liftCand x) = true
    · simp [hx, hs]
    · simp [hx, hs]

/-- **TPR-049** (success face): a lifted point keeps the requested
x-coordinate, has an EVEN y, and satisfies `y² = x³+7 (mod P)` — i.e.
`y` is an even square root of `x³+7`, as BIP340's `lift_x` requires. -/
@[rule "TPR-049"]
theorem liftX_even_root {x x' y' : Nat} (h : liftX x = some (x', y')) :
    x' = x ∧ y' % 2 = 0 ∧ OnCurve x y' := by
  refine ⟨liftX_snd h, liftX_even h, ?_⟩
  have hc := liftX_onCurve h
  rw [liftX_snd h] at hc
  exact hc

/-! ## Byte decoding helpers

Big/little-endian `ByteArray` → `Nat`. Used by ECDSA (message hash `z`)
and the taproot tweak (BIP341: `t = le256(t)`); `tagHash` composition is
the seam's job. -/

/-- Big-endian byte string → `Nat` (first byte most significant). -/
def bytesToNatBE (b : ByteArray) : Nat :=
  b.data.foldl (fun acc u => acc * 256 + u.toNat) 0

/-- Little-endian byte string → `Nat` (first byte least significant). -/
def bytesToNatLE (b : ByteArray) : Nat :=
  b.data.foldr (fun u acc => acc * 256 + u.toNat) 0

end Bitcoin.Crypto.Curve.Secp
