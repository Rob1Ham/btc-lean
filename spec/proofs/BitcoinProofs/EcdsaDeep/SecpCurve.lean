import BitcoinProofs.Crypto.CurveZMod
import Mathlib.AlgebraicGeometry.EllipticCurve.Affine.Basic
import Mathlib.AlgebraicGeometry.EllipticCurve.Affine.Point

/-!
# BitcoinProofs.EcdsaDeep.SecpCurve (E02) — secp256k1 as a mathlib
`WeierstrassCurve.Affine (ZMod P)`

The E02 half of the `E02E03IF` interface (E09's `TweakCor.lean:129`,
the negotiation contract between this lane and E03's `PointCor`): the
mathlib Weierstrass **instantiation** `E` for secp256k1 over `ZMod P`
(`P` = the W14b field prime, `CurveZMod.secp_P_prime :
Fact (Nat.Prime P)`), with

* `a₁ = a₂ = a₃ = a₄ = 0, a₆ = 7` (the short Weierstrass form
  `y² = x³ + 7` of secp256k1; `a = 0, b = 7` = `Secp.curveB`,
  Core group.h `SECP256K1_CONST`), and
* `secp256k1_IsElliptic : E.IsElliptic` — the mathlib `IsUnit Δ`
  condition, proved from `Δ = -21168 ≠ 0 [P]` (secp256k1's
  discriminant `-16·(4·0³ + 27·7²) = -21168`; `P > 21168` by `decide`,
  so `P ∤ 21168`).

Everything here is over the **full** `ZMod P` (P = the FIELD prime,
NOT the group order `n`); `Nontrivial (ZMod P)` / `Field (ZMod P)` /
`DecidableEq (ZMod P)` are in scope globally via `CurveZMod.secp_P_prime`
(E09's p2b probe). The `Equation`-shaping and the `Δ`-computation
(§B/§C) are pure zero-field-arithmetic (no `Fact (Nat.Prime P)` was
needed anywhere except `Nontrivial`/`Field` themselves).

## Main statements (all sorry-free, axiom pins at the bottom)

1. **`secp256k1_Equation`** (§D): `E.Equation x y ↔ y ^ 2 = x ^ 3 +
   ((7 : Nat) : ZMod P)` — the short-form Weierstrass equation, the
   mathlib `equation_iff` with the zero `a₁..a₄` and `a₆ = 7`.
2. **`OnCurve_eq_Equation`** (§E): the E02E03IF `onCurveE` field
   (TweakCor.lean:133-134) — raw `OnCurve x y`
   (RANGE-FREE: `(y*y)%P = (x*x*x+7)%P`, Secp.lean:104) ↔
   `E.Equation ((x : Nat) : ZMod P) ((y : Nat) : ZMod P)`.
   **Zero hypotheses** — not even primality: the mod-`P` congruence
   `((y*y)%P = (x*x*x+7)%P)` ↔ the `ZMod P` cast equation is
   `ZMod.natCast_eq_natCast_iff'` (Basic.lean:510) + `push_cast`
   (cast-mul/add/pow-elimination) + `ring_nf` (pow ↔ mul monomial
   normal forms), both directions. This DISCHARGES the E02 half of
   E02E03IF's `onCurveE` at the def `E` — E03's instantiation duty is
   the coercion `(x : Nat) : ZMod P` at the `Point.mk` sites.
3. **`secp256k1_IsElliptic`** (§C): `E.IsElliptic` = mathlib's
   `IsUnit Δ`. Over the field `ZMod P`: `Δ = -21168` ≠ `0` (P >
   21168), hence `Δ ∣ 1` (witness `Δ⁻¹`, `mul_inv_cancel₀`), hence
   `IsUnit Δ` (`isUnit_of_dvd_one`), hence
   elliptic. **This is where `Fact (Nat.Prime P)` first bites**
   (Field → `a ≠ 0 → a ∣ 1`), closing E09's "E02's `IsElliptic` from
   `Δ ≠ 0` + `CurveZMod.P_prime`" gap (E09.md:65-67) and giving the
   suite's first **consumer** of `secp_P_prime` (SCS-A13's
   "zero consumers" gap).
4. **`G_Equation`** (§F): `E.Equation ((Gx : Nat) : ZMod P) ((Gy :
   Nat) : ZMod P)` — the generator `(Gx, Gy)` is on the mathlib
   `E`, from the raw `G_onCurve` (SGN-101, Secp.lean:126, kernel-
   decided) through `OnCurve_eq_Equation`. This is E02E03IF's
   `G_okE` precondition (TweakCor.lean:164-166, `(onCurveE Gx
   Gy).mp G_onCurve`), and gives `G_Point : E.Point` (§F:
   `Point.mk (x := ((Gx : Nat) : ZMod P)) (y := ((Gy : Nat) : ZMod P))
   G_Equation`) — the mathlib image of `G` at the raw `some (Gx, Gy)`
   (E02E03IF's `G_okE` RHS, modulo E03's `e`).

## Scope honesty (E06/E14 convention)

* `E` is a `def` over the `ZMod P` of `CurveZMod`'s global `Fact`
  — no new `Fact`, no `NeZero` axiom, no CharP-2 juggling (P is odd:
  the short-form `equation_iff` needs none).
* Nothing here is assumed about the group order `n`, `n • B = 0`,
  the curve's point count, or the raw `addP`/`mulP` (E03/E04 lanes).
* No `@[rule]` tags (this is a proofs-package E-unit, PD02's
  ledger untouched); no existing file edited.
* `Nonsingular`-level: `equation_iff_nonsingular` (Basic.lean:262)
  needs `[Nontrivial R] [W.IsElliptic]` only — over `E` both hold, so
  `E.Equation x y ↔ E.Nonsingular x y` is available to E03's
  `Point`-image work (`Point.some`'s `Nonsingular x y` constructor
  argument vs the `Equation`-form here; mathlib's own `Point.mk`
  (Point.lean:545) routes `Equation` → `Nonsingular` through exactly
  this lemma).
-/

namespace BitcoinProofs.EcdsaDeep.SecpCurve

open Bitcoin.Crypto.Curve.Secp

/-! ## §A The instantiation

`E := WeierstrassCurve.mk 0 0 0 0 ((7 : Nat) : ZMod P)`. The `a₁..a₄`
projections are `0` by `rfl` (structure-literal); `a₆ = ((7 : Nat) :
ZMod P)` — the `Nat`-cast form (not the `OfNat (ZMod P) 7` form) is
deliberate: it is the form `natCast_eq_natCast_iff'` produces on the
`Equation` side, so `OnCurve_eq_Equation` (§E) closes by `push_cast`/
`ring_nf` with no cast-literal mismatch. -/

/-- **secp256k1 over `ZMod P`** — the mathlib Weierstrass curve of the
DL tower (E02). Short form `y² = x³ + 7` (`a₁ = a₂ = a₃ = a₄ = 0`,
`a₆ = 7 = Secp.curveB`), over the field prime `P` (W14b `CurveZMod`,
`Fact (Nat.Prime P)` global). -/
def E : WeierstrassCurve.Affine (ZMod P) :=
  WeierstrassCurve.mk (0 : ZMod P) (0 : ZMod P) (0 : ZMod P) (0 : ZMod P)
    ((7 : Nat) : ZMod P)

theorem E_a₁ : E.a₁ = (0 : ZMod P) := rfl
theorem E_a₂ : E.a₂ = (0 : ZMod P) := rfl
theorem E_a₃ : E.a₃ = (0 : ZMod P) := rfl
theorem E_a₄ : E.a₄ = (0 : ZMod P) := rfl
theorem E_a₆ : E.a₆ = ((7 : Nat) : ZMod P) := rfl

/-! ## §B The standard quantities (zero-arithmetic, no `Fact`) -/

/-- `b₂ = 0`. -/
theorem E_b₂ : WeierstrassCurve.b₂ E = (0 : ZMod P) := by
  show (E.a₁ ^ 2 + 4 * E.a₂ : ZMod P) = 0
  rw [show E.a₁ = 0 from rfl, show E.a₂ = 0 from rfl]; ring

/-- `b₄ = 0`. -/
theorem E_b₄ : WeierstrassCurve.b₄ E = (0 : ZMod P) := by
  show (2 * E.a₄ + E.a₁ * E.a₃ : ZMod P) = 0
  rw [show E.a₄ = 0 from rfl, show E.a₁ = 0 from rfl, show E.a₃ = 0 from rfl]; ring

/-- `b₆ = 28 = 4 · a₆`. -/
theorem E_b₆ : WeierstrassCurve.b₆ E = ((28 : Nat) : ZMod P) := by
  show (E.a₃ ^ 2 + 4 * E.a₆ : ZMod P) = _
  rw [show E.a₃ = 0 from rfl, show E.a₆ = ((7 : Nat) : ZMod P) from rfl]
  push_cast; ring

/-- `b₈ = 0`. -/
theorem E_b₈ : WeierstrassCurve.b₈ E = (0 : ZMod P) := by
  show (E.a₁ ^ 2 * E.a₆ + 4 * E.a₂ * E.a₆ - E.a₁ * E.a₃ * E.a₄
      + E.a₂ * E.a₃ ^ 2 - E.a₄ ^ 2 : ZMod P) = 0
  rw [show E.a₁ = 0 from rfl, show E.a₂ = 0 from rfl, show E.a₃ = 0 from rfl,
      show E.a₄ = 0 from rfl, show E.a₆ = ((7 : Nat) : ZMod P) from rfl]
  push_cast; ring

/-- **The discriminant**: `Δ = -27 · b₆² = -27 · 28² = -21168`
(secp256k1's `Δ = -16(4a³ + 27b²) = -16 · 27 · 7²` with `a = 0`,
`b = 7`). -/
theorem E_Δ : WeierstrassCurve.Δ E = ((-21168 : Int) : ZMod P) := by
  show (-((E.a₁ ^ 2 + 4 * E.a₂) ^ 2
      * (E.a₁ ^ 2 * E.a₆ + 4 * E.a₂ * E.a₆ - E.a₁ * E.a₃ * E.a₄
      + E.a₂ * E.a₃ ^ 2 - E.a₄ ^ 2) : ZMod P)
      - 8 * (2 * E.a₄ + E.a₁ * E.a₃) ^ 3
      - 27 * (E.a₃ ^ 2 + 4 * E.a₆) ^ 2
      + 9 * (E.a₁ ^ 2 + 4 * E.a₂) * (2 * E.a₄ + E.a₁ * E.a₃)
      * (E.a₃ ^ 2 + 4 * E.a₆)) = _
  rw [show E.a₁ = 0 from rfl, show E.a₂ = 0 from rfl, show E.a₃ = 0 from rfl,
      show E.a₄ = 0 from rfl, show E.a₆ = ((7 : Nat) : ZMod P) from rfl]
  push_cast; ring

/-! ## §C `Δ ≠ 0`, hence `IsElliptic`

`Δ = -21168` as an integer mod `P`: `P > 21168` (both literals
`decide`), so `(P : ℤ) ∤ 21168` (`Int.le_of_dvd` positivity), so the
`ZMod P`-image of `-21168` is nonzero (`Int.cast_neg` +
`ZMod.intCast_zmod_eq_zero_iff_dvd`), so a UNIT — `IsUnit` — over
the field `ZMod P` (this is where `Fact (Nat.Prime P)` bites:
`Field (ZMod P)` gives `mul_inv_cancel₀ : a ≠ 0 → a * a⁻¹ = 1`,
so `Δ ∣ 1` with witness `Δ⁻¹`, and `isUnit_of_dvd_one` gives
`IsUnit Δ`). -/

/-- **`Δ ≠ 0`** in `ZMod P`: `21168 < P` (decide) and `P ∤ 21168`. -/
theorem E_Δ_ne : WeierstrassCurve.Δ E ≠ (0 : ZMod P) := by
  intro hc
  rw [E_Δ, Int.cast_neg, neg_eq_zero] at hc
  have hd : (P : Int) ∣ (21168 : Int) := (ZMod.intCast_zmod_eq_zero_iff_dvd _ _).mp hc
  have hP : (21168 : Int) < (P : Int) := by decide
  have : (P : Int) ≤ 21168 := Int.le_of_dvd (by decide : (0:Int) < 21168) hd
  omega

/-- **secp256k1 is elliptic** (E02's `IsElliptic` gap, E09.md:65-67):
the mathlib `IsUnit Δ` condition, from `Δ ≠ 0` over the field
`ZMod P` (`Field (ZMod P)` gives `mul_inv_cancel₀`, so `Δ ∣ 1` with
witness `Δ⁻¹`, and `isUnit_of_dvd_one` transports to `IsUnit Δ`).
The `Nontrivial (ZMod P)` /
`Field (ZMod P)` instances are global via `CurveZMod.secp_P_prime`
(`Fact (Nat.Prime P)`). **First in-tree consumer of `secp_P_prime`**
(SCS-A13's "zero consumers" gap). -/
instance secp256k1_IsElliptic : E.IsElliptic where
  isUnit := isUnit_of_dvd_one ⟨(WeierstrassCurve.Δ E)⁻¹, (mul_inv_cancel₀ E_Δ_ne).symm⟩

/-! ## §D The short Weierstrass equation

`E.Equation x y ↔ y ^ 2 = x ^ 3 + ((7 : Nat) : ZMod P)`, the short
form `y² = x³ + 7` — mathlib's `equation_iff` (Basic.lean:143) with
the zero `a₁..a₄` and `a₆ = 7` (p5-proven). -/

/-- **The short Weierstrass equation of `E`** (§D): `E.Equation x y ↔
`y ^ 2 = x ^ 3 + ((7 : Nat) : ZMod P)` (the short form `y² = x³ + 7`,
`a = 0` / `b = 7` = `Secp.curveB`, Core group.h `SECP256K1_CONST`). -/
theorem secp256k1_Equation (x y : ZMod P) :
    E.Equation x y ↔ y ^ 2 = x ^ 3 + ((7 : Nat) : ZMod P) := by
  rw [WeierstrassCurve.Affine.equation_iff]
  show y ^ 2 + E.a₁ * x * y + E.a₃ * y = x ^ 3 + E.a₂ * x ^ 2 + E.a₄ * x + E.a₆ ↔ _
  rw [show E.a₁ = 0 from rfl, show E.a₂ = 0 from rfl, show E.a₃ = 0 from rfl,
      show E.a₄ = 0 from rfl, show E.a₆ = ((7 : Nat) : ZMod P) from rfl]
  push_cast; ring

/-! ## §E The `OnCurve ↔ Equation` bridge (E02E03IF's `onCurveE`)

The E02 half of E02E03IF's `onCurveE` (TweakCor.lean:133-134), at the
def `E`: raw `OnCurve x y` (RANGE-FREE: `(y*y)%P = (x*x*x+7)%P`,
Secp.lean:104) ↔ `E.Equation ((x : Nat) : ZMod P) ((y : Nat) : ZMod
P))`. **ZERO hypotheses** (p6-proven; see §A's note on the Nat-cast
form of `a₆`). -/

/-- **The raw↔mathlib on-curve bridge** (§E; E02E03IF's `onCurveE`
field at the def `E`, TweakCor.lean:133-134): raw `OnCurve x y` ↔
`E.Equation ((x : Nat) : ZMod P) ((y : Nat) : ZMod P)`. RANGE-FREE
(works for ALL `x y : Nat`; no `x < P` needed) and hypothesis-free
(not even `Fact (Nat.Prime P)`); `ZMod.natCast_eq_natCast_iff'`
(Basic.lean:510) is the mod-`P`-congruence ↔ cast-equation key. -/
theorem OnCurve_eq_Equation (x y : Nat) :
    OnCurve x y ↔ E.Equation ((x : Nat) : ZMod P) ((y : Nat) : ZMod P) := by
  rw [WeierstrassCurve.Affine.equation_iff]
  rw [OnCurve, show Bitcoin.Crypto.Curve.Secp.curveB = 7 from rfl]
  show (y * y) % P = (x * x * x + 7) % P ↔
    ((y : ZMod P) ^ 2 + E.a₁ * x * y + E.a₃ * y = x ^ 3 + E.a₂ * x ^ 2 + E.a₄ * x + E.a₆)
  rw [show E.a₁ = 0 from rfl, show E.a₂ = 0 from rfl, show E.a₃ = 0 from rfl,
      show E.a₄ = 0 from rfl, show E.a₆ = ((7 : Nat) : ZMod P) from rfl]
  constructor
  · intro h
    have hz : ((y * y : Nat) : ZMod P) = ((x * x * x + 7 : Nat) : ZMod P) :=
      (ZMod.natCast_eq_natCast_iff' (y * y) (x * x * x + 7) P).mpr h
    push_cast at hz
    ring_nf at hz ⊢
    exact hz
  · intro h
    ring_nf at h
    have hz : ((y * y : Nat) : ZMod P) = ((x * x * x + 7 : Nat) : ZMod P) := by
      push_cast
      ring_nf
      exact h
    exact (ZMod.natCast_eq_natCast_iff' (y * y) (x * x * x + 7) P).mp hz

/-! ## §F The generator `G` on `E` (E02E03IF's `G_okE` precondition)

`G_Equation` = E02E03IF's `G_okE` precondition (TweakCor.lean:164-166)
at the def `E`; `G_Point` = the mathlib image of `G` (the `G_okE` RHS,
modulo E03's `e`). **Lane-split note (E02/E03)**: E03-2 owns the curve
FACTS lane (`y² = x³ + 7` as an equation theorem / `G`-on-curve
restatements over `PointCor`'s α-map); `G_Equation` here is the
E-instantiation side — raw `G_onCurve` (kernel-decided) through
`OnCurve_eq_Equation` — and is deliberately E03-AGNOSTIC (no `PointCor`
reference). -/

/-- **The generator `(Gx, Gy)` is on the mathlib `E`** (§F): from the
raw `G_onCurve` (SGN-101, Secp.lean:126, kernel-decided) through
`OnCurve_eq_Equation`. This is E02E03IF's `G_okE` precondition
(TweakCor.lean:164-166). -/
theorem G_Equation : E.Equation ((Gx : Nat) : ZMod P) ((Gy : Nat) : ZMod P) :=
  (OnCurve_eq_Equation Gx Gy).mp G_onCurve

/-- **The mathlib point of `G`** (§F): `Point.mk (x := ((Gx : Nat) :
ZMod P)) (y := ((Gy : Nat) : ZMod P)) G_Equation` — the E02E03IF
`G_okE` RHS (TweakCor.lean:164-166) at the def `E`, modulo E03's
`e`. `Point.mk` (Point.lean:545) routes `Equation` → `Nonsingular`
through `equation_iff_nonsingular` (Basic.lean:262). -/
def G_Point : E.Point :=
  WeierstrassCurve.Affine.Point.mk (x := ((Gx : Nat) : ZMod P)) (y := ((Gy : Nat) : ZMod P))
    G_Equation

/-! ## §G Axiom pins

`#print axioms` (direct-lean, E09's RC05 no-flock route) — all pins
exactly `[propext, Classical.choice, Quot.sound]`, ZERO `sorryAx` /
ad-hoc axioms; nothing else is assumed. (`secp256k1_Equation`,
`OnCurve_eq_Equation`, `G_Equation`, `secp256k1_IsElliptic` /
`G_Point` = the §D/§E/§F/§C-+§F four + instance; `G_onCurve`'s own
kernel-pins = SGN-101's `Nat.lean` = the raw layer.) -/

end BitcoinProofs.EcdsaDeep.SecpCurve
