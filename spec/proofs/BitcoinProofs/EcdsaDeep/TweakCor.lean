import Bitcoin.Crypto.Taproot.TapTweak
import BitcoinProofs.Crypto.CurveZMod
import Mathlib.AlgebraicGeometry.EllipticCurve.Affine.Basic
import Mathlib.AlgebraicGeometry.EllipticCurve.Affine.Point

/-!
# BitcoinProofs.EcdsaDeep.TweakCor — TapTweak group-level correctness (E09)

BIP341's output-key equation, at the GROUP level:

    Q = P + t • G,   t = int(taggedHash("TapTweak", P.x ‖ merkle_root))

`Bitcoin.Crypto.Taproot.tweakPoint` (X03 Unit 1, TapTweak.lean:135-141,
READ-ONLY) computes that equation over the W14b **raw** structure
(`RawPoint = Option (Nat × Nat)`, `addP`, `mulP`; Curve/Secp.lean),
returning `none` for the two libsecp reject modes (tweak ≥ n; `P + tG = ∞`).

This module proves, from the E02/E03 **structure hypotheses** alone (the
`E02E03IF` record below = the mathlib Weierstrass instantiation of
secp256k1 + the raw↔mathlib correspondence; that lane has NOT landed, so
the hypotheses are the contractual interface):

1. **`tweakPoint_output_onCurve`** (E09 MAIN 1): every affine output of
   `tweakPoint p Pt root` is ON the secp256k1 curve `y² = x³ + 7` (raw
   `OnCurve qx qy`) — provided the input `Pt` is (`e_none` +
   `addP_okE`/`mulP_okE`; zero-tweak lane `Q = Pt` outright). NO property
   of the tweak hash, of `Pt`, or of `n` is assumed.
2. **`tweakPoint_output_eq`** (E09 MAIN 2): every affine output equals the
   group expression `A + (tweakScalar p root) • B` in the mathlib
   Weierstrass group, where `A` is the mathlib image of the raw input
   (`e Pt = some A`) and `B` the image of the generator
   (`e (some G) = some B`) — under `addP_okE`/`mulP_okE` +
   `mulP_noneE` (the zero-tweak/`∞` lane).
3. **Core anchoring (VERIFIED, X03/X02)**: `tweakScalar` is EXACTLY
   BIP341's `t = int_from_bytes(taggedHash('TapTweak', p ‖ root))`
   (rfl), and `tweakPoint`'s reject modes are EXACTLY libsecp's
   (TPR-016/017 restatements from X03, read-only).

No `@[rule]` tags added here (TapTweak.lean is X03-retry's tree); this
file pins nothing in rules.yaml.

## The E02E03 interface (E09's contractual reading of "E02/E03 structure")

`E02E03IF` collects what E02 (mathlib `WeierstrassCurve.Affine`
instantiation for secp256k1) + E03 (raw↔mathlib point correspondence) +
E04 (scalar-mult none-convention) owe the suite, as Prop-hypotheses over
the raw layer. Parameters: `E : WeierstrassCurve.Affine (ZMod P)` with
`a₁ = a₂ = a₃ = a₄ = 0, a₆ = 7`, `[ell : E.IsElliptic]`; `[CommRing
(ZMod P)]`, `[Field (ZMod P)]`, `[DecidableEq (ZMod P)]`, `[Nontrivial
(ZMod P)]` are all in scope GLOBALLY via `CurveZMod.secp_P_prime :
Fact (Nat.Prime P)` (CurveZMod.lean:548, the W14b Pratt certificate) —
probed before this file was written (build/scratch/e09check/p2b.lean).
Fields:

* `onCurveE` : raw `OnCurve x y` (RANGE-FREE: `OnCurve x y := (y*y)%P =
  (x*x*x+7)%P`, Secp.lean:104 — both sides are statements about
  `(x, y) mod P`) ↔ `E.Equation ((x : Nat) : ZMod P) ((y : Nat) : ZMod P)`;
* `e`        : the raw→mathlib point map, `RawPoint → Option E.Point`
  (`none ↦ none` = 𝒪, E03);
* `e_some`   : on an on-curve pair, `e (some (x, y))` is the mathlib point
  `Point.mk (x, y)` (E03 correspondence);
* `e_none`   : `e (some (x, y)) ≠ none → OnCurve x y` — the map is
  FAITHFUL TO THE CURVE (E03 soundness; the one hypothesis the
  predecessor's 2-sorry draft was missing, F-E09-002);
* `addP_okE` : `addP Pt Q = some (x₃, y₃)` → `e Pt = some A → e Q = some B
  → e (some (x₃, y₃)) = some (A + B)` (E03: raw addP computes the group
  law on e-images);
* `mulP_okE` : `mulP k Q = some (x₃, y₃)` (with `e Q = some B`) →
  `e (some (x₃, y₃)) = some (k • B)` (E03/E04);
* `mulP_noneE`: `mulP k Q = none` (with `e Q = some B`) → `k • B = 0`
  (E03/E04 none-convention: raw `none` IS the point at infinity; needed
  for the ZERO-TWEAK lane — `tweakPoint_zero`, TapTweak.lean:217-234);
* `G_okE`    : `e (some G) = some (Point.mk (Gx, Gy))` (E02's
  `G_Equation` from `G_onCurve` + `onCurveE`).

The mathlib `Equation` here is over the FULL `ZMod P` (P = field prime,
NOT the group order n); the identity `n • B = 0` (n = the group order,
Secp.lean:70) is NOT a field of the record (not needed by either MAIN)
— it lands with E02's `SecpCurve` instantiation.

## Scope honesty (E06/E14 convention)

Nothing here is assumed about `taggedHash` (X02's), `SHA256`, the tweak's
distribution, or `Nat.Prime n`. The `WeierstrassCurve.Affine (ZMod P)`
instantiation `E` with `[ell : E.IsElliptic]` is a HYPOTHESIS of the
record (E02's lane), NOT constructed here; where E02 lands
`proofs/BitcoinProofs/EcdsaDeep/SecpCurve.lean` with a matching record,
a `def e02e03IF : E02E03IF E := ...` closes the gap — see the PROPOSED
disposition in `db/findings-dl/E09.md`. `ZMod P` primality IS available
globally (CurveZMod), but `E`'s secp256k1 shape (`a₆ = 7`) and
`IsElliptic` are not.

## Core anchors (all @cce32b168 unless noted; TapTweak.lean cites
cce32b168 = pin+2, merkle/f840c26 uncommitted)

* `ComputeTapTweakHash` (pubkey.cpp:246-255) = `taptweak`
  (TapTweak.lean:88).
* `t = int_from_bytes(...)` (BIP341:184) = `tweakScalar`
  (TapTweak.lean:114).
* `secp256k1_xonly_pubkey_tweak_add_check` (extrakeys_main_impl.h:142-161)
  = `tweakPoint` (TapTweak.lean:135), `Q = P + tG` (eckey_impl.h:23-33).

## Axiom footprints

Sorry-free. All proofs are case analysis over `tweakPoint`'s own
`if`-rejection structure (X03's `tweakPoint_some`/`tweakPoint_none`,
TapTweak.lean:186/202) + the interface fields; pins at the bottom
(`#guard_msgs in #print axioms`, all `[propext]`-only).
-/

namespace BitcoinProofs.EcdsaDeep.TweakCor

open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Taproot
open WeierstrassCurve
open WeierstrassCurve.Affine

/-! ## The E02/E03 interface record (contract; see module docstring) -/

/-- The E02/E03 structure hypotheses for secp256k1, as a record over the
raw layer (`E` = the mathlib `WeierstrassCurve.Affine (ZMod P)` with
`a₁ = a₂ = a₃ = a₄ = 0, a₆ = 7`, `[ell : E.IsElliptic]`). NOTHING about
`E`'s definition is needed by the two MAIN theorems; the fields are used
as follows: `e_some` + `G_okE` transport the input/generator on-curve
facts, `addP_okE` + `mulP_okE` are the E03/E04 group-law correctness of
the raw operations, `e_none` is the E03 soundness (e-faithfulness),
`mulP_noneE` is the E03/E04 none-convention. See the module docstring
for the full E02E03IF contract. -/
structure E02E03IF (E : WeierstrassCurve.Affine (ZMod P)) [ell : E.IsElliptic] where
  /-- The raw↔mathlib on-curve correspondence (E03). Raw `OnCurve x y` is
  RANGE-FREE (Secp.lean:104: `(y*y)%P = (x*x*x+7)%P`), so no `x < P`
  hypothesis is needed. -/
  onCurveE : ∀ x y : Nat, OnCurve x y ↔
    E.Equation ((x : Nat) : ZMod P) ((y : Nat) : ZMod P)
  /-- The raw→mathlib point map (E03): `none ↦ none` = 𝒪, an on-curve
  `(x, y) ↦ Point.mk (x, y)`, `none` for off-curve garbage. -/
  e : RawPoint → Option E.Point
  /-- On an on-curve pair, `e` is the mathlib point (E03). -/
  e_some : ∀ (x y : Nat) (hc : OnCurve x y),
    e (some (x, y)) = some (Point.mk (x := ((x : Nat) : ZMod P))
                                     (y := ((y : Nat) : ZMod P))
       ((onCurveE x y).mp hc))
  /-- `e` is faithful to the curve (E03 soundness): if `e (some (x, y))`
  is a point at all, `(x, y)` is on the raw curve. -/
  e_none : ∀ (x y : Nat), e (some (x, y)) ≠ none → OnCurve x y
  /-- The raw point-add computes the group law (E03): if
  `addP Pt Q = some (x₃, y₃)` and `e Pt = some A`, `e Q = some B` (both
  mathlib points), then `e (some (x₃, y₃)) = some (A + B)`. -/
  addP_okE : ∀ (Pt Q : RawPoint) (x₃ y₃ : Nat) (A B : E.Point),
    addP Pt Q = some (x₃, y₃) → e Pt = some A → e Q = some B →
      e (some (x₃, y₃)) = some (A + B)
  /-- The raw scalar-mult computes the group multiple (E03/E04): if
  `mulP k Q = some (x₃, y₃)` (with `e Q = some B`), then
  `e (some (x₃, y₃)) = some (k • B)`. -/
  mulP_okE : ∀ (k : Nat) (Q : RawPoint) (x₃ y₃ : Nat) (B : E.Point),
    mulP k Q = some (x₃, y₃) → e Q = some B →
      e (some (x₃, y₃)) = some (k • B)
  /-- The none-convention (E03/E04): raw `mulP k Q = none` (with
  `e Q = some B`) means the group multiple is the point at infinity. -/
  mulP_noneE : ∀ (k : Nat) (Q : RawPoint) (B : E.Point),
    mulP k Q = none → e Q = some B → k • B = 0
  /-- The generator: `e (some G)` is the mathlib point `(Gx, Gy)`
  (E02's `G_Equation` from `G_onCurve` + `onCurveE`). -/
  G_okE : e (some G) = some (Point.mk (x := ((Gx : Nat) : ZMod P))
                                      (y := ((Gy : Nat) : ZMod P))
     ((onCurveE Gx Gy).mp G_onCurve))

/-! ### tweakPoint's structure, from X03 (READ-ONLY, restated here)

Two restatements of X03's own theorems (the ONLY facts about `tweakPoint`
used below; both are theorems of TapTweak.lean, cited in the anchors).

NOTE on `G`: in TapTweak.lean, `mulP (tweakScalar p root) G` elaborates
with `G : Nat × Nat` (Secp.lean:89) coerced to `RawPoint` by the
elaborator as `mulP _ (some G)` — see the olean-checked `#check` in
build/scratch/e09check/p1.lean. The restatements below re-state X03's
theorems VERBATIM (proof = the theorem itself), so the coercion is
identical on both sides. -/

/-- **X03 restatement (a.k.a. `tweakPoint_some`)**: an affine output of
`tweakPoint` means (i) the tweak is in range (`t < n`, TPR-017) and
(ii) the raw equation `addP Pt (mulP (tweakScalar p root) G) = some (x, y)`
holds (TPR-016). See TapTweak.lean:186-192. -/
theorem tweakPoint_some' (p : ByteArray) (Pt : RawPoint)
    (root : Option ByteArray) (x y : Nat)
    (h : tweakPoint p Pt root = some (x, y)) :
    tweakScalar p root < n ∧
      addP Pt (mulP (tweakScalar p root) G) = some (x, y) :=
  tweakPoint_some p Pt root x y h

/-- **X03 restatement (a.k.a. `tweakPoint_none`)**: `none` means the
tweak overflowed the group order OR `P + tG = ∞` (the two libsecp
reject modes). See TapTweak.lean:202-208. -/
theorem tweakPoint_none' (p : ByteArray) (Pt : RawPoint)
    (root : Option ByteArray) (h : tweakPoint p Pt root = none) :
    n ≤ tweakScalar p root ∨
      addP Pt (mulP (tweakScalar p root) G) = none :=
  tweakPoint_none p Pt root h

/-! ## The MAIN theorems -/

/-- **E09 MAIN 1 (onCurve)**: let `Pt = some (px, py)` be an on-curve
input (the `liftX` even-y lift, BIP341:69, is the caller's job). Then
every AFFINE output of `tweakPoint p Pt root` — i.e. every accepted
output key `Q = (qx, qy)` — is on the secp256k1 curve `y² = x³ + 7`
(raw `OnCurve qx qy`), and every reject mode is one of the two libsecp
failures (tweak ≥ n, or `P + tG = ∞` — in the raw layer
`addP Pt (mulP t G) = none`).

Hypotheses: the E02E03IF record (E02's instantiation + E03/E04's
group-law correctness). NO property of the tweak hash, of `Pt`, or of
`n` (other than the code's own range check) is assumed.

Proof structure (both conjuncts are `tweakPoint`'s own `if`-rejection
structure, TapTweak.lean:139-142 + X03's `tweakPoint_some`/`_none`):
the reject conjunct is `tweakPoint_none'` verbatim; the affine
conjunct splits on `mulP (tweakScalar p root) G` —
`none` = the ZERO-TWEAK lane (`addP Pt none = Pt = (px,py)`, on-curve
by `hPc`), `some (tx,ty)` = the generic lane, where `mulP_okE` (at the
generator, `G_okE` + `G_onCurve`) makes `e (some (tx,ty))` a point,
`addP_okE` (at `e Pt = some A`, `e_some` + `hPc`) makes `e (some (qx,
qy))` a point, and `e_none` pulls `(qx, qy)` back onto the raw curve. -/
theorem tweakPoint_output_onCurve (p : ByteArray) (Pt : RawPoint)
    (root : Option ByteArray) {E : WeierstrassCurve.Affine (ZMod P)}
    [ell : E.IsElliptic] (IF : E02E03IF E) (px py : Nat)
    (hP : Pt = some (px, py)) (hPc : OnCurve px py) :
    (∀ qx qy : Nat, tweakPoint p Pt root = some (qx, qy) → OnCurve qx qy) ∧
    (tweakPoint p Pt root = none →
      n ≤ tweakScalar p root ∨
        addP Pt (mulP (tweakScalar p root) G) = none) := by
  refine ⟨fun qx qy hQ => ?_, fun hnone => tweakPoint_none' p Pt root hnone⟩
  -- the reject modes are exhaustive (tweakPoint's `if` is total)
  obtain ⟨_htr, hadd⟩ := tweakPoint_some' p Pt root qx qy hQ
  cases hmul : mulP (tweakScalar p root) G with
  | none =>
    -- zero-tweak/none lane: addP Pt none = Pt, so (qx,qy) = (px,py)
    rw [hmul] at hadd
    rw [addP_none] at hadd
    rw [hP, Option.some.injEq, Prod.mk.injEq] at hadd
    obtain ⟨rfl, rfl⟩ := hadd
    exact hPc
  | some tG =>
    obtain ⟨tx, ty⟩ := tG
    -- the generator's mathlib image (E02: G_okE + G_onCurve)
    have hB : IF.e (some (tx, ty)) =
        some ((tweakScalar p root) • (Point.mk (x := ((Gx : Nat) : ZMod P))
            (y := ((Gy : Nat) : ZMod P))
            ((IF.onCurveE Gx Gy).mp G_onCurve))) :=
      IF.mulP_okE (tweakScalar p root) (some G) tx ty _ hmul IF.G_okE
    -- the input's mathlib image (E03: e_some + hPc)
    have hA : IF.e Pt =
        some (Point.mk (x := ((px : Nat) : ZMod P)) (y := ((py : Nat) : ZMod P))
          ((IF.onCurveE px py).mp hPc)) := by
      rw [hP]; exact IF.e_some px py hPc
    -- the group law on e-images (E03: addP_okE)
    rw [hmul] at hadd
    have hQ' := IF.addP_okE Pt (some (tx, ty)) qx qy _ _ hadd hA hB
    -- e (some (qx, qy)) is a point (≠ none) ...
    have hne : IF.e (some (qx, qy)) ≠ none := by
      intro hc
      rw [hc] at hQ'
      exact absurd hQ' (by simp)
    -- ... so (qx, qy) is on the raw curve (E03 soundness: e_none)
    exact IF.e_none qx qy (fun hc => by rw [hc] at hQ'; exact absurd hQ' (by simp))

/-- **E09 MAIN 2 (the group equation Q = P + t • G)**: under the same
hypotheses as MAIN 1 (E02E03IF + `Pt = some (px, py)` on-curve), every
affine output `Q = (qx, qy)` of `tweakPoint p Pt root` has its mathlib
image equal to the GROUP EXPRESSION — `e Q = e P + t • e G` in the
Weierstrass group of `E`, with `t = tweakScalar p root` and `e P`, `e G`
the images of the input point and the generator (`e_some` + `G_okE`,
the equation written on those images).

This is the CONSENSUS-CORRECT form of BIP341's `Q = P + int(t)G`
(bip-0341.mediawiki §"Script validation rules"; Core
`secp256k1_xonly_pubkey_tweak_add_check` → `secp256k1_ec_pubkey_tweak_add`
→ `secp256k1_ecmult` eckey_impl.h:23-33): the raw `addP`/`mulP`
computation inside `tweakPoint` computes the mathlib group operation —
`IF.addP_okE` (E03) + `IF.mulP_okE` (E03/E04) — so an ACCEPTED output
key is the group sum. The `none`-lane (`mulP t G = none`, the raw
infinity convention) is closed by `IF.mulP_noneE` (E03/E04): the group
multiple is the point at infinity, `t • e G = 0`, and the equation
collapses to `e Q = e P` via `add_zero` (the zero-tweak lane:
`tweakPoint_zero`, TapTweak.lean — `P + 0·G = P`). -/
theorem tweakPoint_output_eq (p : ByteArray) (Pt : RawPoint)
    (root : Option ByteArray) {E : WeierstrassCurve.Affine (ZMod P)}
    [ell : E.IsElliptic] (IF : E02E03IF E) (px py : Nat)
    (hP : Pt = some (px, py)) (hPc : OnCurve px py) :
    ∀ qx qy : Nat, tweakPoint p Pt root = some (qx, qy) →
      IF.e (some (qx, qy)) =
        some ((Point.mk (x := ((px : Nat) : ZMod P))
                        (y := ((py : Nat) : ZMod P))
                  ((IF.onCurveE px py).mp hPc))
              + (tweakScalar p root) •
                (Point.mk (x := ((Gx : Nat) : ZMod P))
                          (y := ((Gy : Nat) : ZMod P))
                    ((IF.onCurveE Gx Gy).mp G_onCurve))) := by
  intro qx qy hQ
  obtain ⟨_htr, hadd⟩ := tweakPoint_some' p Pt root qx qy hQ
  cases hmul : mulP (tweakScalar p root) G with
  | none =>
    -- the raw-infinity lane: `mulP t G = none` means the GROUP multiple
    -- is the point at infinity (mulP_noneE), so `t • e G = 0` and the
    -- equation collapses to `e Q = e P` (add_zero); `(qx,qy) = (px,py)`
    -- by the raw structure (`addP Pt none = Pt`).
    have h0 : (tweakScalar p root) •
        (Point.mk (x := ((Gx : Nat) : ZMod P))
                  (y := ((Gy : Nat) : ZMod P))
            ((IF.onCurveE Gx Gy).mp G_onCurve)) = 0 :=
      IF.mulP_noneE (tweakScalar p root) (some G) _ hmul IF.G_okE
    rw [hmul] at hadd
    rw [addP_none] at hadd
    rw [hP, Option.some.injEq, Prod.mk.injEq] at hadd
    obtain ⟨rfl, rfl⟩ := hadd
    rw [h0, add_zero]
    exact IF.e_some px py hPc
  | some tG =>
    obtain ⟨tx, ty⟩ := tG
    -- e G's image through the raw multiple (E03/E04: mulP_okE + G_okE)
    have hB : IF.e (some (tx, ty)) =
        some ((tweakScalar p root) •
          (Point.mk (x := ((Gx : Nat) : ZMod P))
                    (y := ((Gy : Nat) : ZMod P))
              ((IF.onCurveE Gx Gy).mp G_onCurve))) :=
      IF.mulP_okE (tweakScalar p root) (some G) tx ty _ hmul IF.G_okE
    -- the input's mathlib image (E03: e_some + hPc)
    have hA : IF.e Pt =
        some (Point.mk (x := ((px : Nat) : ZMod P))
                       (y := ((py : Nat) : ZMod P))
                  ((IF.onCurveE px py).mp hPc)) := by
      rw [hP]; exact IF.e_some px py hPc
    -- the group law on e-images (E03: addP_okE) = the equation
    rw [hmul] at hadd
    exact IF.addP_okE Pt (some (tx, ty)) qx qy _ _ hadd hA hB

/-! ## Axiom footprints (X02/Unit-1 style: `#guard_msgs in #print axioms`)

All sorry-free. The restatements `tweakPoint_some'`/`tweakPoint_none'`
= X03's `tweakPoint_some`/`tweakPoint_none` verbatim (TapTweak.lean's
own pins: the standard trio). The MAIN theorems are case analysis over
`tweakPoint`'s `match`/`if` structure + the interface fields — see the
pins below. -/

/-- info: 'BitcoinProofs.EcdsaDeep.TweakCor.tweakPoint_some'' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms tweakPoint_some'

/-- info: 'BitcoinProofs.EcdsaDeep.TweakCor.tweakPoint_none'' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms tweakPoint_none'

/-- info: 'BitcoinProofs.EcdsaDeep.TweakCor.tweakPoint_output_onCurve' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms tweakPoint_output_onCurve

/-- info: 'BitcoinProofs.EcdsaDeep.TweakCor.tweakPoint_output_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms tweakPoint_output_eq

end BitcoinProofs.EcdsaDeep.TweakCor
