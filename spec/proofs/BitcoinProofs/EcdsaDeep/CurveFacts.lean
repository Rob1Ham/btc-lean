import BitcoinProofs.EcdsaDeep.TweakCor
import BitcoinProofs.EcdsaDeep.SecpCurve

/-!
# E03B — the E02E03IF record's curve-fact discharge

E02's `SecpCurve.lean` landed the mathlib Weierstrass instance
`E : WeierstrassCurve.Affine (ZMod P)` (`y² = x³ + 7`) and its curve
facts; E09's `E02E03IF` (TweakCor.lean:129) still carried them as
hypotheses. This file discharges the record's curve-fact obligations at
`E`, so a future `E02E03IF` constructor supplies only the E03/E04 map
laws (`e`, `e_some`, `e_none`, `addP_okE`, `mulP_okE`, `mulP_noneE`);
see `E02E03IF.ofCurveFacts` (below).

* `secp256k1_curve_equation` — `y² = x³ + 7` at the instance.
* `secp256k1_G_on_curve` — the generator is on `E`.
* `secp256k1_G_nondegenerate` — its mathlib point is not `0`.
* `onCurveE_discharge` — the record's `onCurveE` field, at `E`.
* `E02E03IF.onCurveE_eq` / `.e_G` — every record over `E` has exactly
  these curve facts (no extra obligation).
-/

namespace BitcoinProofs.EcdsaDeep.E03B

open Bitcoin.Crypto.Curve.Secp
open WeierstrassCurve
open WeierstrassCurve.Affine
open BitcoinProofs.EcdsaDeep.SecpCurve
open BitcoinProofs.EcdsaDeep.TweakCor (E02E03IF)

/-- (a) The short Weierstrass equation over `ZMod P`: `y² = x³ + 7`. -/
theorem secp256k1_curve_equation (x y : ZMod P) :
    E.Equation x y ↔ y ^ 2 = x ^ 3 + ((7 : Nat) : ZMod P) :=
  secp256k1_Equation x y

/-- (b) The generator `G = (Gx, Gy)` is on the instance `E`. -/
theorem secp256k1_G_on_curve :
    E.Equation ((Gx : Nat) : ZMod P) ((Gy : Nat) : ZMod P) :=
  G_Equation

/-- (c) Non-degeneracy: the mathlib image of `G` is not the point at
infinity (`Point.some` vs `Point.zero`). -/
theorem secp256k1_G_nondegenerate : G_Point ≠ 0 := by
  unfold G_Point
  exact Point.some_ne_zero _

/-- The record's `onCurveE` field (TweakCor.lean:133), discharged at
E02's `E`; zero hypotheses, range-free. -/
theorem onCurveE_discharge (x y : Nat) :
    OnCurve x y ↔ E.Equation ((x : Nat) : ZMod P) ((y : Nat) : ZMod P) :=
  OnCurve_eq_Equation x y

/-- `Point.mk` ignores the `Equation`-proof (proof irrelevance). -/
theorem point_mk_proof_irrel (x y : ZMod P) (h₁ h₂ : E.Equation x y) :
    (Point.mk (x := x) (y := y) h₁ : E.Point) =
      Point.mk (x := x) (y := y) h₂ := by
  unfold Point.mk
  exact congrArg (Point.some x y) (Subsingleton.elim _ _)

end BitcoinProofs.EcdsaDeep.E03B

namespace BitcoinProofs.EcdsaDeep.TweakCor

open Bitcoin.Crypto.Curve.Secp
open WeierstrassCurve
open WeierstrassCurve.Affine
open BitcoinProofs.EcdsaDeep.SecpCurve

/-- Every record over E02's `E` has the discharged `onCurveE` field. -/
theorem E02E03IF.onCurveE_eq (IF : E02E03IF E) :
    IF.onCurveE = OnCurve_eq_Equation := by
  funext x y
  exact Subsingleton.elim _ _

/-- Every record over E02's `E` maps the generator to `G_Point`:
`G_okE`'s curve-fact content is forced by E02's `G_Equation` + the
record's own `e_some`. -/
theorem E02E03IF.e_G (IF : E02E03IF E) :
    IF.e (some G) = some G_Point := by
  rw [IF.G_okE]
  congr 1

/-- **Record construction with the curve facts discharged**: given only
the E03/E04 map-law fields, build `E02E03IF E`. `onCurveE` is E02's
theorem and `G_okE` is the supplied `e_some` at the generator, so no
curve-fact hypothesis remains. -/
def E02E03IF.ofCurveFacts
    (e : RawPoint → Option E.Point)
    (e_some : ∀ (x y : Nat) (hc : OnCurve x y),
      e (some (x, y)) = some (Point.mk (x := ((x : Nat) : ZMod P))
        (y := ((y : Nat) : ZMod P)) ((OnCurve_eq_Equation x y).mp hc)))
    (e_none : ∀ (x y : Nat), e (some (x, y)) ≠ none → OnCurve x y)
    (addP_okE : ∀ (Pt Q : RawPoint) (x₃ y₃ : Nat) (A B : E.Point),
      addP Pt Q = some (x₃, y₃) → e Pt = some A → e Q = some B →
        e (some (x₃, y₃)) = some (A + B))
    (mulP_okE : ∀ (k : Nat) (Q : RawPoint) (x₃ y₃ : Nat) (B : E.Point),
      mulP k Q = some (x₃, y₃) → e Q = some B → e (some (x₃, y₃)) = some (k • B))
    (mulP_noneE : ∀ (k : Nat) (Q : RawPoint) (B : E.Point),
      mulP k Q = none → e Q = some B → k • B = 0) :
    E02E03IF E :=
  { onCurveE := OnCurve_eq_Equation
    e := e
    e_some := e_some
    e_none := e_none
    addP_okE := addP_okE
    mulP_okE := mulP_okE
    mulP_noneE := mulP_noneE
    G_okE := e_some Gx Gy G_onCurve }

end BitcoinProofs.EcdsaDeep.TweakCor

/-! ## Axiom pins (all exactly the standard trio; zero `sorryAx`) -/

/-- info: 'BitcoinProofs.EcdsaDeep.E03B.secp256k1_curve_equation' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.EcdsaDeep.E03B.secp256k1_curve_equation

/-- info: 'BitcoinProofs.EcdsaDeep.E03B.secp256k1_G_on_curve' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.EcdsaDeep.E03B.secp256k1_G_on_curve

/-- info: 'BitcoinProofs.EcdsaDeep.E03B.secp256k1_G_nondegenerate' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.EcdsaDeep.E03B.secp256k1_G_nondegenerate

/-- info: 'BitcoinProofs.EcdsaDeep.E03B.onCurveE_discharge' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.EcdsaDeep.E03B.onCurveE_discharge

/-- info: 'BitcoinProofs.EcdsaDeep.TweakCor.E02E03IF.onCurveE_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.EcdsaDeep.TweakCor.E02E03IF.onCurveE_eq

/-- info: 'BitcoinProofs.EcdsaDeep.TweakCor.E02E03IF.e_G' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.EcdsaDeep.TweakCor.E02E03IF.e_G

/-- info: 'BitcoinProofs.EcdsaDeep.TweakCor.E02E03IF.ofCurveFacts' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.EcdsaDeep.TweakCor.E02E03IF.ofCurveFacts
