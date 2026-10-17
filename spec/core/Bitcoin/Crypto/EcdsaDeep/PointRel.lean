import Bitcoin.Crypto.Curve.Secp

/-!
# Bitcoin.Crypto.EcdsaDeep.PointRel — the raw point-relation layer (E02B)

The E02B landing of the relation layer that E02's `SecpCurve.lean`
deferred (see `spec/db/findings-dl/E02.md`, "PROPOSED / NOT landed"):
`E03`-agnostic *relations* over the raw curve layer (`RawPoint`, `addP`,
`doubleP`, `negP`, `mulP`) together with

* **decidable hooks** (`OnCurve`, `RawOK`, and each relation) so the
  proof lane can `decide`/`by_cases` on raw statements without
  re-deriving computable decision procedures, and
* **λ-table branch hooks**: the case split of `addRaw` / `doubleRaw`
  expressed as separate equations (same point ⇒ double, inverse ⇒ `none`,
  else the slope branch; `y = 0` ⇒ `none` for doubling). These are
  exactly the raw-side premises that an E03 correspondence proof needs
  to match the `dite` case table of mathlib's
  `WeierstrassCurve.Affine.Point.add`.

This file is deliberately in the **core** package (no mathlib import):
the mathlib `Point.add` side lives in the proofs package; this layer
only names the raw facts. `DecidableEq (ZMod P)` is not needed here and
is global in proofs via `BitcoinProofs.Crypto.CurveZMod.secp_P_prime`.
-/

namespace Bitcoin.Crypto.EcdsaDeep.PointRel

open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Curve.Mod

/-! ## Relation definitions (E03-agnostic, raw layer only) -/

/-- The raw point-addition relation: `addP p q` lands exactly at `r`. -/
def PointAddRel (p q r : RawPoint) : Prop := addP p q = r

/-- The raw point-doubling relation: `doubleP p` lands exactly at `r`. -/
def PointDoubleRel (p r : RawPoint) : Prop := doubleP p = r

/-- The raw point-negation relation: `negP p` lands exactly at `r`. -/
def PointNegRel (p r : RawPoint) : Prop := negP p = r

/-- The raw scalar-multiplication relation: `mulP k p` lands exactly at `r`. -/
def PointSmulRel (k : Nat) (p r : RawPoint) : Prop := mulP k p = r

/-! ## Decidable equality hooks -/

/-- The curve equation is decidable, computed by the executable
`onCurveN` (both directions are already theorems in `Secp`). -/
instance decidableOnCurve (x y : Nat) : Decidable (OnCurve x y) :=
  decidable_of_iff (onCurveN x y = true) ⟨onCurveN_true, onCurveN_of_OnCurve⟩

/-- The coordinate invariant is decidable (finite conjunction of `< P`). -/
instance decidableRawOK (p : RawPoint) : Decidable (RawOK p) := by
  cases p with
  | none => exact isTrue trivial
  | some pt =>
    obtain ⟨x, y⟩ := pt
    change Decidable (x < P ∧ y < P)
    infer_instance

instance decidablePointAddRel (p q r : RawPoint) : Decidable (PointAddRel p q r) := by
  unfold PointAddRel; infer_instance

instance decidablePointDoubleRel (p r : RawPoint) : Decidable (PointDoubleRel p r) := by
  unfold PointDoubleRel; infer_instance

instance decidablePointNegRel (p r : RawPoint) : Decidable (PointNegRel p r) := by
  unfold PointNegRel; infer_instance

instance decidablePointSmulRel (k : Nat) (p r : RawPoint) :
    Decidable (PointSmulRel k p r) := by
  unfold PointSmulRel; infer_instance

/-! ## λ-table branch hooks for `addRaw` / `doubleRaw` -/

/-- Same point: `addRaw` doubles. -/
theorem addRaw_same {x y : Nat} : addRaw x y x y = doubleRaw x y := by
  unfold addRaw
  rw [ite_eq_left (by
    rw [Bool.and_eq_true]
    exact ⟨beq_self_eq_true x, beq_self_eq_true y⟩)]

/-- Inverse points (`y₁ = −y₂`, distinct): `addRaw` is `none` (𝒪). -/
theorem addRaw_of_y_eq {x1 y1 x2 y2 : Nat} (hx : x1 = x2) (hy : y1 = negN y2)
    (hne : y1 ≠ y2) : addRaw x1 y1 x2 y2 = none := by
  unfold addRaw
  rw [ite_eq_right (by
    rw [Bool.and_eq_true]
    intro h
    exact hne (Nat.beq_eq.mp h.2))]
  rw [ite_eq_left (by
    rw [Bool.and_eq_true]
    exact ⟨Nat.beq_eq.mpr hx, Nat.beq_eq.mpr hy⟩)]

/-- Distinct x-coordinates: the slope branch, with the exact `let`-body. -/
theorem addRaw_of_ne {x1 y1 x2 y2 : Nat} (hx : x1 ≠ x2) :
    addRaw x1 y1 x2 y2 =
      (let lam := mulM P (subM P y2 y1) (invP (subM P x2 x1))
       let x3 := subM P (subM P (mulM P lam lam) x1) x2
       let y3 := subM P (mulM P lam (subM P x1 x3)) y1
       some (x3, y3)) := by
  unfold addRaw
  rw [ite_eq_right (by
    rw [Bool.and_eq_true]
    intro h
    exact hx (Nat.beq_eq.mp h.1))]
  rw [ite_eq_right (by
    rw [Bool.and_eq_true]
    intro h
    exact hx (Nat.beq_eq.mp h.1))]

/-- Vertical tangent (`y = 0`): doubling is 𝒪. -/
theorem doubleRaw_zero (x : Nat) : doubleRaw x 0 = none := by
  unfold doubleRaw
  rw [ite_eq_left (beq_self_eq_true 0)]

/-- `y ≠ 0`: the doubling slope branch, with the exact `let`-body. -/
theorem doubleRaw_of_ne {x y : Nat} (hy : y ≠ 0) :
    doubleRaw x y =
      (let lam := mulM P (mulM P 3 (mulM P x x)) (invP (addM P y y))
       let x3 := subM P (mulM P lam lam) (addM P x x)
       let y3 := subM P (mulM P lam (subM P x x3)) y
       some (x3, y3)) := by
  unfold doubleRaw
  rw [ite_eq_right (by
    intro h
    exact hy (Nat.beq_eq.mp h))]

/-- `addP` at two concrete points is `addRaw` (definitional). -/
theorem addP_some_some (x1 y1 x2 y2 : Nat) :
    addP (some (x1, y1)) (some (x2, y2)) = addRaw x1 y1 x2 y2 := rfl

/-- `addP` with 𝒪 on the left (definitional; the right version is
`Secp.addP_none`). -/
theorem addP_none_left (q : RawPoint) : addP none q = q := rfl


/-! ## `mulP` recursion hooks (parity split; salvage of the E02B p1 probe) -/

/-- Even step of the LSB-first ladder: `mulP (k+1)` doubles the half. -/
theorem mulP_succ_even {k : Nat} {p : RawPoint}
    (h : ((k + 1) % 2 == 0) = true) :
    mulP (k + 1) p = doubleP (mulP ((k + 1) / 2) p) := by
  rw [mulP.eq_2, ite_eq_left h]

/-- Odd step of the LSB-first ladder: add the base point. -/
theorem mulP_succ_odd {k : Nat} {p : RawPoint}
    (h : ((k + 1) % 2 == 0) = false) :
    mulP (k + 1) p = addP p (doubleP (mulP ((k + 1) / 2) p)) := by
  rw [mulP.eq_2, ite_eq_right (by rw [h]; simp)]

/-! ## `negP` λ-table hooks (definitional) -/

theorem negP_none : negP none = none := rfl

theorem negP_some (x y : Nat) : negP (some (x, y)) = some (x, negN y) := rfl

/-! ## The abstract correspondence package (relation form of E02E03IF)

`PointRelCorr` is the E03-agnostic, relation-level form of the
`addP_okE` / `mulP_okE` / `mulP_noneE` fields of `E02E03IF`
(`TweakCor.lean`): an abstract carrier `G` with operations `add`, `smul`
and zero `zero`, a raw→abstract map `e`, and the four transport laws in
terms of the relation defs above. No group axioms are assumed — the
consumer supplies them (over mathlib `E.Point` they are instances). -/

/-- Raw operations implement the abstract `add`/`smul` under `e`. -/
structure PointRelCorr (G : Type) (zero : G) (add : G → G → G)
    (smul : Nat → G → G) (e : RawPoint → Option G) : Prop where
  /-- `addP` computes the abstract sum on transported points. -/
  add_corr : ∀ (p q r : RawPoint) (A B : G), PointAddRel p q r →
    e p = some A → e q = some B → e r = some (add A B)
  /-- `doubleP` computes the abstract double. -/
  double_corr : ∀ (p r : RawPoint) (A : G), PointDoubleRel p r →
    e p = some A → e r = some (add A A)
  /-- `negP` computes the abstract inverse, given an inverse operation. -/
  neg_corr : ∀ (p r : RawPoint) (A B : G), PointNegRel p r →
    e p = some A → e r = some B → add A B = zero
  /-- `mulP` computes the abstract multiple. -/
  smul_corr : ∀ (k : Nat) (p r : RawPoint) (A : G), PointSmulRel k p r →
    e p = some A → e r = some (smul k A)
  /-- `mulP = none` means the abstract multiple is zero (E03/E04's
  `mulP_noneE`). -/
  smul_none : ∀ (k : Nat) (p : RawPoint) (A : G), mulP k p = none →
    e p = some A → smul k A = zero



/-! ## Axiom pins (D2 ladder, `#guard_msgs` form)

All branch/recursion hooks = the standard trio `[propext,
Classical.choice, Quot.sound]` (the `ite` decidability and the `Bool`
reflection lemmas), ZERO `sorryAx`, no custom axioms. The relation defs
and the `PointRelCorr` structure are definitions (no footprint). -/

section AxiomPins

/-- info: 'Bitcoin.Crypto.EcdsaDeep.PointRel.addRaw_same' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms addRaw_same
/-- info: 'Bitcoin.Crypto.EcdsaDeep.PointRel.addRaw_of_y_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms addRaw_of_y_eq
/-- info: 'Bitcoin.Crypto.EcdsaDeep.PointRel.addRaw_of_ne' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms addRaw_of_ne
/-- info: 'Bitcoin.Crypto.EcdsaDeep.PointRel.doubleRaw_zero' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms doubleRaw_zero
/-- info: 'Bitcoin.Crypto.EcdsaDeep.PointRel.doubleRaw_of_ne' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms doubleRaw_of_ne
/-- info: 'Bitcoin.Crypto.EcdsaDeep.PointRel.mulP_succ_even' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms mulP_succ_even
/-- info: 'Bitcoin.Crypto.EcdsaDeep.PointRel.mulP_succ_odd' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms mulP_succ_odd

end AxiomPins

end Bitcoin.Crypto.EcdsaDeep.PointRel
