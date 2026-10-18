import BitcoinProofs.Crypto.CurveZMod
import BitcoinProofs.SmallCurve.Scheme
import Mathlib.AlgebraicGeometry.EllipticCurve.Affine.Basic
import Mathlib.AlgebraicGeometry.EllipticCurve.Affine.Point
import Bitcoin.Crypto.Taproot.TapTweak

/-!
# BitcoinProofs.SmallCurve.TweakCorSmall — the E09 TweakCor carbon, on
# SmallCurve (E10-2, U2)

BIP341's output-key equation at the GROUP level, on the SMALL curve:

    Q = P + t • G,   t = int(taggedHash("TapTweak", P.x ‖ merkle_root))

The **small-curve carbon copy of E09's `EcdsaDeep/TweakCor.lean`**
(the DL tower's secp256k1 TweakCor), with exactly the three
replacements the R6/E10 hedge fixes:

* `P` (secp field prime) → `pL = 65647` (Scheme's 17-bit prime):
  `abbrev pL := 65647` + `variable [Fact (Nat.Prime pL)]` (the
  `CurveZMod.secp_P_prime`-mirror; probed P1c/P1d: `CommRing`/
  `Field`/`Nontrivial`/`DecidableEq (ZMod pL)` ALL resolve from the
  `Fact` alone — E10-1's U1a left `Nat.Prime p` python-verified
  only, and the kernel `decide : Nat.Prime 65647` proved a 19-36GB
  hazard (F-E10-2-A), so primality stays a variable here);
* `Bitcoin.Crypto.Taproot.tweakPoint` (X03, secp `addP`/`mulP`) →
  `tweakPointS` = the `TapTweak.lean:135-141` def-shape VERBATIM over
  the SmallCurve ops (`addP'`/`mulP'`, Scheme.lean:378/414) + the
  secp `taptweak`/`tweakScalar` shape (`bytesToNatBE (taggedHash
  "TapTweak" (p ‖ root))`, TapTweak.lean:89/105-114) — the only NEW
  def-words in this file;
* `E02E03IF E` (E09's record over `Affine (ZMod P)`, the E02/E03
  secp structure-hypotheses) → `E02E03IFSmall E` over `Affine (ZMod
  pL)` — field-for-field the same contract (E09 TweakCor.lean:
  129-166 carbon), on the Prop-level `OnCurve'` (the `Secp.OnCurve`
  (Secp.lean:104) carbon — Scheme has only the Bool `onCurveN'`).

The two MAIN theorems (`tweakPointS_output_onCurve`,
`tweakPointS_output_eq`) are E09's `tweakPoint_output_onCurve`/
`tweakPoint_output_eq` (TweakCor.lean:223-334) modulo those
three replacements: same statements, same proofs (case analysis over
`tweakPointS`'s own `if`-rejection structure + the interface fields
`e_none`/`addP_okE`/`mulP_okE`/`mulP_noneE`/`G_okE`; the
zero-tweak/`∞` lane by `mulP_noneE` + `add_zero`).

**16-bit scalar bound.** `Scheme.mulP' k q` walks only the 16 low bits
of `k` (`bitListRec (bitsOfW 16 k)`), so `mulP'` is periodic in `k` with
period `2^16`. The interface fields `mulP_okE`/`mulP_noneE` therefore
carry an explicit `k < 2^16` hypothesis; without it they would assert
`(k + 2^16) • B = k • B` for arbitrary `B`, which is false (for `B = G`
the order is `n = 65173`, and `2^16 ≢ 0 (mod n)`). The MAIN theorems
discharge the bound from the code's own range check:
`tweakPointS_some` gives `tweakScalarS p root < n`, and
`n_lt_two_pow_16 : n < 2^16`.

## What is sorry-free here (E06/E14 honesty)

* §A (`taptweakS`/`tweakScalarS`/`tweakPointS`) + the §A structure
  lemmas (`tweakPointS_overflow`/`_some`/`_none`/`_zero`, the
  TapTweak.lean:170-234 verdict-family carbon) + BOTH §B MAINs +
  `tweakScalarS_lt_two_pow_16`: **sorry-free**;
* §D `SCDE : E02E03IFSmall SC` — the secp `E02E03IF`-gap's exact
  small twin: the INSTANTIATION record over `SC :=
  WeierstrassCurve.Affine (ZMod pL)` (a₁=…=a₄=0, a₆=7). It is
  **not constructed here**: `addP_okE`/`mulP_okE` (raw case-table =
  mathlib `Point.add` transport) are the E03/E05 lane's small-curve
  version, and the `e`-map needs a `Decidable` instance for the
  `OnCurve'` Prop that this file deliberately does not build by
  kernel `decide` (the 17-bit decidability study is out of scope, see
  the §D note).

## Core anchors (all @cce32b168): exactly TweakCor's (E09):
`ComputeTapTweakHash` (pubkey.cpp:246-255) = `taptweak`
(TapTweak.lean:88), `t = int_from_bytes(...)`
(BIP341:184) = `tweakScalar` (TapTweak.lean:114),
`secp256k1_xonly_pubkey_tweak_add_check` (extrakeys_main_impl.h:
142-161) = `tweakPoint` (TapTweak.lean:135), `Q = P + tG`
(eckey_impl.h:23-33). `tweakPointS` is the same def-shape on the
SmallCurve ops — the small-curve sanity twin's whole point.

## Axiom footprints: `#guard_msgs in #print axioms` pins at the
bottom. There is no `sorry` in this file; `SCDE` is not constructed
(see §D), so no `sorryAx`-anchored hypothesis is used.
-/

namespace BitcoinProofs.SmallCurve.TweakCorSmall

open BitcoinProofs.SmallCurve.Scheme
open WeierstrassCurve
open WeierstrassCurve.Affine
open Bitcoin.Crypto.Schnorr (taggedHash tagTapTweak)
open Bitcoin.Crypto.Curve.Secp (bytesToNatBE)

/-! ## Constants (Scheme + the `Fact`-bridge) -/

/-- The field prime (Scheme.p := 65647), as an `abbrev`-literal so the
`ZMod pL` globals resolve from `[Fact (Nat.Prime pL)]` (P1c/P1d). -/
abbrev pL : Nat := 65647

theorem pL_eq : pL = p := rfl

/-- The group order fits the 16-bit scalar window of `mulP'`
(`n = 65173 < 65536`). This is the bound the interface fields
`mulP_okE`/`mulP_noneE` require. -/
theorem n_lt_two_pow_16 : n < 2 ^ 16 := by decide

/-- The Prop-level curve equation (the `Secp.OnCurve`
(Secp.lean:104) carbon, 17-bit; Scheme has only the Bool `onCurveN'`). -/
def OnCurve' (x y : Nat) : Prop := (y * y) % pL = (x * x * x + curveB) % pL

/-- The generator is on the curve (the `Secp.G_onCurve`
(Secp.lean:126-131, there `unfold OnCurve; decide` on the 256-bit
literals) carbon — here 17-bit). -/
theorem onCurve'_G : OnCurve' Gx Gy := by
  unfold OnCurve'
  decide

/-- The `Secp.addP_none` (Secp.lean:265-266) carbon (Scheme.lean:378
`addP' p' none = p'`, the `_eq₂` branch). -/
theorem addP'_none (p' : RawPoint') : addP' p' none = p' := by
  cases p' <;> rfl

/-! ## The TapTweak carbon over the SmallCurve ops (`tweakPointS`) -/

/-- `taptweak p root` = `taggedHash("TapTweak", p ‖ root)` — the
`Bitcoin.Crypto.Taproot.taptweak` (TapTweak.lean:89) def-shape
VERBATIM (Core `XOnlyPubKey::ComputeTapTweakHash`,
pubkey.cpp:246-255). -/
def taptweakS (p : ByteArray) (root : Option ByteArray) : ByteArray :=
  match root with
  | none => taggedHash tagTapTweak p
  | some root => taggedHash tagTapTweak (p ++ root)

/-- The tweak scalar `t = int_from_bytes(taptweak p root)` (BIP341:184)
— the `Bitcoin.Crypto.Taproot.tweakScalar` (TapTweak.lean:105-114)
def-shape VERBATIM. Used raw (no mod-n reduction) so the overflow
reject (`t ≥ n`) is a first-class verdict branch. -/
def tweakScalarS (p : ByteArray) (root : Option ByteArray) : Nat :=
  bytesToNatBE (taptweakS p root)

/-- `tweakPointS p Pt root` = the output key `Q` — or `none` = the two
libsecp reject modes — the `Bitcoin.Crypto.Taproot.tweakPoint`
(TapTweak.lean:135-141) def-shape VERBATIM, over the SmallCurve ops
(`addP'`/`mulP'` at `n` = 65173, `G` = (1, 31426)). -/
def tweakPointS (p : ByteArray) (Pt : RawPoint') (root : Option ByteArray) :
    RawPoint' :=
  if n ≤ tweakScalarS p root then none
  else addP' Pt (mulP' (tweakScalarS p root) (some G))

/-! ### `tweakPointS`'s structure (the TapTweak.lean:170-234 verdict
family carbon; X03's `tweakPoint_overflow`/`tweakPoint_some`/
`tweakPoint_none`/`tweakPoint_zero` restatements) -/

/-- TPR-017 (tweak range check, reject side): a tweak ≥ the group order
is rejected (TapTweak.lean:170-179 carbon). -/
theorem tweakPointS_overflow (p : ByteArray) (Pt : RawPoint')
    (root : Option ByteArray) (h : n ≤ tweakScalarS p root) :
    tweakPointS p Pt root = none := by
  unfold tweakPointS
  split
  · rfl
  · rename_i hk
    exact absurd h hk

/-- TPR-016 (commitment equation) + TPR-017 (accept side):
`tweakPointS = some (x, y)` iff (i) `t < n` and (ii) the raw equation
`addP' Pt (mulP' t (some G)) = some (x, y)` (TapTweak.lean:181-198
carbon). -/
theorem tweakPointS_some (p : ByteArray) (Pt : RawPoint')
    (root : Option ByteArray) (x y : Nat)
    (h : tweakPointS p Pt root = some (x, y)) :
    tweakScalarS p root < n ∧
      addP' Pt (mulP' (tweakScalarS p root) (some G)) = some (x, y) := by
  unfold tweakPointS at h
  split at h
  · exact absurd h (by simp)
  · rename_i hk
    exact ⟨Nat.lt_of_not_ge hk, h⟩

/-- The tweak scalar is below `2^16` on every accepted output (the
16-bit bound required by the interface's `mulP_okE`/`mulP_noneE`). -/
theorem tweakScalarS_lt_two_pow_16 (p : ByteArray) (Pt : RawPoint')
    (root : Option ByteArray) (qx qy : Nat)
    (h : tweakPointS p Pt root = some (qx, qy)) :
    tweakScalarS p root < 2 ^ 16 := by
  have hlt := (tweakPointS_some p Pt root qx qy h).1
  have hn := n_lt_two_pow_16
  omega

/-- TPR-016/TPR-017 (reject totality): `tweakPointS = none` means the
tweak overflowed OR `P + tG = ∞` (TapTweak.lean:200-208 carbon). -/
theorem tweakPointS_none (p : ByteArray) (Pt : RawPoint')
    (root : Option ByteArray) (h : tweakPointS p Pt root = none) :
    n ≤ tweakScalarS p root ∨
      addP' Pt (mulP' (tweakScalarS p root) (some G)) = none := by
  unfold tweakPointS at h
  split at h
  · rename_i hk
    exact Or.inl hk
  · exact Or.inr h

/-- A zero tweak is accepted and the output key IS the internal key:
`P + 0·G = P + 𝒪 = P` (TapTweak.lean:210-234 carbon, there via
`mulP_zero`/`addP_none`; here via the Scheme carbons `mulP'_zero`
(Scheme.lean:497) + `addP'_none` (above)). -/
theorem tweakPointS_zero (p : ByteArray) (Pt : RawPoint')
    (root : Option ByteArray) (h : tweakScalarS p root = 0) :
    tweakPointS p Pt root = Pt := by
  unfold tweakPointS
  rw [h]
  have hn : ¬ n ≤ 0 := by have := n_pos; omega
  split
  · rename_i hk
    exact absurd hk hn
  · show addP' Pt (mulP' 0 (some G)) = Pt
    rw [mulP'_zero, addP'_none]

section
variable [Fact (Nat.Prime pL)]

/-- The small curve: `y² = x³ + 7` over `ZMod pL` — E02E03IF's `E`
instantiated at the SmallCurve parameters (the secp E02-lane's small
twin). -/
def SC : WeierstrassCurve.Affine (ZMod pL) where
  a₁ := 0; a₂ := 0; a₃ := 0; a₄ := 0; a₆ := 7

/-! ## The E02/E03 interface record (E09's `E02E03IF`
(TweakCor.lean:129-166) carbon, field-for-field) -/

/-- The E02/E03 structure hypotheses for SmallCurve, as a record over
the raw layer (E09 TweakCor.lean:120-166 carbon; `P`→`pL`,
`OnCurve`→`OnCurve'`, `addP`/`mulP`→`addP'`/`mulP'`). NOTHING about
`SC`'s definition is needed by the two MAIN theorems; see the module
docstring for the full contract. -/
structure E02E03IFSmall (E : WeierstrassCurve.Affine (ZMod pL))
    [ell : E.IsElliptic] where
  /-- The raw↔mathlib on-curve correspondence (E03). `OnCurve' x y` is
  RANGE-FREE (Secp.lean:104 carbon), so no `x < pL` hypothesis. -/
  onCurveE : ∀ x y : Nat, OnCurve' x y ↔
    E.Equation ((x : Nat) : ZMod pL) ((y : Nat) : ZMod pL)
  /-- The raw→mathlib point map (E03). -/
  e : RawPoint' → Option E.Point
  /-- On an on-curve pair, `e` is the mathlib point (E03). -/
  e_some : ∀ (x y : Nat) (hc : OnCurve' x y),
    e (some (x, y)) = some (Point.mk (x := ((x : Nat) : ZMod pL))
                                     (y := ((y : Nat) : ZMod pL))
        ((onCurveE x y).mp hc))
  /-- `e` is faithful to the curve (E03 soundness). -/
  e_none : ∀ (x y : Nat), e (some (x, y)) ≠ none → OnCurve' x y
  /-- The raw point-add computes the group law (E03). -/
  addP_okE : ∀ (Pt Q : RawPoint') (x₃ y₃ : Nat) (A B : E.Point),
    addP' Pt Q = some (x₃, y₃) → e Pt = some A → e Q = some B →
      e (some (x₃, y₃)) = some (A + B)
  /-- The raw scalar-mult computes the group multiple (E03/E04).
  `mulP'` walks the 16 low bits of `k` (`Scheme.mulP'` = `bitsOfW 16`), so
  this field is stated only for `k < 2^16`. Without the bound it would
  assert `(k + 2^16) • B = k • B` for every `B`, which is false. -/
  mulP_okE : ∀ (k : Nat) (Q : RawPoint') (x₃ y₃ : Nat) (B : E.Point),
    k < 2 ^ 16 → mulP' k Q = some (x₃, y₃) → e Q = some B →
      e (some (x₃, y₃)) = some (k • B)
  /-- The none-convention (E03/E04), under the same 16-bit bound as
  `mulP_okE` (see the note there). -/
  mulP_noneE : ∀ (k : Nat) (Q : RawPoint') (B : E.Point),
    k < 2 ^ 16 → mulP' k Q = none → e Q = some B → k • B = 0
  /-- The generator. -/
  G_okE : e (some G) = some (Point.mk (x := ((Gx : Nat) : ZMod pL))
                                       (y := ((Gy : Nat) : ZMod pL))
      ((onCurveE Gx Gy).mp onCurve'_G))

/-! ## The MAIN theorems (E09 TweakCor.lean:223-334 carbon) -/

/-- **E09 MAIN 1 (onCurve), the SmallCurve twin**: every AFFINE output
of `tweakPointS p Pt root` — i.e. every accepted output key
`Q = (qx, qy)` — is on the curve `y² = x³ + 7 (mod pL)` (raw
`OnCurve' qx qy`), and every reject mode is one of the two libsecp
failures (tweak ≥ n, or `P + tG = ∞`).

Hypotheses: the E02E03IFSmall record. NO property of the tweak hash,
of `Pt`, or of `n` (other than the code's own range check) is
assumed. Proof = E09 `tweakPoint_output_onCurve` (TweakCor.lean:
223-264) verbatim. -/
theorem tweakPointS_output_onCurve (p : ByteArray) (Pt : RawPoint')
    (root : Option ByteArray) {E : WeierstrassCurve.Affine (ZMod pL)}
    [ell : E.IsElliptic] (IF : E02E03IFSmall E) (px py : Nat)
    (hP : Pt = some (px, py)) (hPc : OnCurve' px py) :
    (∀ qx qy : Nat, tweakPointS p Pt root = some (qx, qy) → OnCurve' qx qy) ∧
    (tweakPointS p Pt root = none →
      n ≤ tweakScalarS p root ∨
        addP' Pt (mulP' (tweakScalarS p root) (some G)) = none) := by
  refine ⟨fun qx qy hQ => ?_, fun hnone => tweakPointS_none p Pt root hnone⟩
  obtain ⟨htr, hadd⟩ := tweakPointS_some p Pt root qx qy hQ
  have hk := tweakScalarS_lt_two_pow_16 p Pt root qx qy hQ
  cases hmul : mulP' (tweakScalarS p root) (some G) with
  | none =>
    rw [hmul] at hadd
    rw [addP'_none] at hadd
    rw [hP, Option.some.injEq, Prod.mk.injEq] at hadd
    obtain ⟨rfl, rfl⟩ := hadd
    exact hPc
  | some tG =>
    obtain ⟨tx, ty⟩ := tG
    have hB : IF.e (some (tx, ty)) =
        some ((tweakScalarS p root) • (Point.mk (x := ((Gx : Nat) : ZMod pL))
            (y := ((Gy : Nat) : ZMod pL))
            ((IF.onCurveE Gx Gy).mp onCurve'_G))) :=
      IF.mulP_okE (tweakScalarS p root) (some G) tx ty _ hk hmul IF.G_okE
    have hA : IF.e Pt =
        some (Point.mk (x := ((px : Nat) : ZMod pL)) (y := ((py : Nat) : ZMod pL))
          ((IF.onCurveE px py).mp hPc)) := by
      rw [hP]; exact IF.e_some px py hPc
    rw [hmul] at hadd
    have hQ' := IF.addP_okE Pt (some (tx, ty)) qx qy _ _ hadd hA hB
    have hne : IF.e (some (qx, qy)) ≠ none := by
      intro hc
      rw [hc] at hQ'
      exact absurd hQ' (by simp)
    exact IF.e_none qx qy (fun hc => by rw [hc] at hQ'; exact absurd hQ' (by simp))

/-- **E09 MAIN 2 (the group equation `Q = P + t • G`), the SmallCurve
twin**: under the same hypotheses, every affine output `Q = (qx, qy)`
of `tweakPointS p Pt root` has its mathlib image equal to the GROUP
EXPRESSION — `e Q = e P + t • e G` in the Weierstrass group of `E`,
with `t = tweakScalarS p root`. Proof = E09
`tweakPoint_output_eq` (TweakCor.lean:285-334) verbatim. -/
theorem tweakPointS_output_eq (p : ByteArray) (Pt : RawPoint')
    (root : Option ByteArray) {E : WeierstrassCurve.Affine (ZMod pL)}
    [ell : E.IsElliptic] (IF : E02E03IFSmall E) (px py : Nat)
    (hP : Pt = some (px, py)) (hPc : OnCurve' px py) :
    ∀ qx qy : Nat, tweakPointS p Pt root = some (qx, qy) →
      IF.e (some (qx, qy)) =
        some ((Point.mk (x := ((px : Nat) : ZMod pL))
                        (y := ((py : Nat) : ZMod pL))
                  ((IF.onCurveE px py).mp hPc))
              + (tweakScalarS p root) •
                (Point.mk (x := ((Gx : Nat) : ZMod pL))
                          (y := ((Gy : Nat) : ZMod pL))
                    ((IF.onCurveE Gx Gy).mp onCurve'_G))) := by
  intro qx qy hQ
  obtain ⟨htr, hadd⟩ := tweakPointS_some p Pt root qx qy hQ
  have hk := tweakScalarS_lt_two_pow_16 p Pt root qx qy hQ
  cases hmul : mulP' (tweakScalarS p root) (some G) with
  | none =>
    have h0 : (tweakScalarS p root) •
        (Point.mk (x := ((Gx : Nat) : ZMod pL))
                  (y := ((Gy : Nat) : ZMod pL))
            ((IF.onCurveE Gx Gy).mp onCurve'_G)) = 0 :=
      IF.mulP_noneE (tweakScalarS p root) (some G) _ hk hmul IF.G_okE
    rw [hmul] at hadd
    rw [addP'_none] at hadd
    rw [hP, Option.some.injEq, Prod.mk.injEq] at hadd
    obtain ⟨rfl, rfl⟩ := hadd
    rw [h0, add_zero]
    exact IF.e_some px py hPc
  | some tG =>
    obtain ⟨tx, ty⟩ := tG
    have hB : IF.e (some (tx, ty)) =
        some ((tweakScalarS p root) •
          (Point.mk (x := ((Gx : Nat) : ZMod pL))
                    (y := ((Gy : Nat) : ZMod pL))
              ((IF.onCurveE Gx Gy).mp onCurve'_G))) :=
      IF.mulP_okE (tweakScalarS p root) (some G) tx ty _ hk hmul IF.G_okE
    have hA : IF.e Pt =
        some (Point.mk (x := ((px : Nat) : ZMod pL))
                       (y := ((py : Nat) : ZMod pL))
                 ((IF.onCurveE px py).mp hPc)) := by
      rw [hP]; exact IF.e_some px py hPc
    rw [hmul] at hadd
    exact IF.addP_okE Pt (some (tx, ty)) qx qy _ _ hadd hA hB

end

/-! ## §D — the instantiation record (PROPOSED, U2b)

`SCDE : E02E03IFSmall SC` — the secp `E02E03IF`-gap's exact small
twin: the INSTANTIATION record over `SC :=
WeierstrassCurve.Affine (ZMod pL)` (a₁=…=a₄=0, a₆=7), with

* `eS` = the `none ↦ none`-else-`Point.mk` map (the E03-shape),
* `onCurveE` = `OnCurve' x y ↔ SC.Equation` (EquationG),
* `addP_okE`/`mulP_okE` = the raw case-table = mathlib `Point.add`
  transport (the E03/E05 lane's small-curve version), with the
  16-bit scalar bound on `mulP_okE`/`mulP_noneE` noted above.

NOT constructed in this file (F-E10-2-B): the `eS`-shape above needs
a `Point.mk`-valued match on the `OnCurve'`-Prop (a `Decidable
(OnCurve' x y)`-instance = a 17-bit kernel decidability study of its
own — the raw `OnCurve'`-Prop-decidable instance is NOT in Scheme,
and building it by `decide`-instances on `(y*y)%pL = ...`-Nats is
exactly the sort of kernel-decidability gamble U0's gates exist to
avoid; the 19-36GB `Nat.Prime`-decide hazard (F-E10-2-A) was the
second warning). The MAINs need NONE of it (E09's exact
structure-hypotheses contract) — `SCDE`-discharge is the U2b lane.
-/

/-! ## Regression checks for the 16-bit interface bound

`mulP'` reads only the low 16 bits (`bitsOfW 16`). These two kernel checks
pin the periodicity that motivates the `k < 2^16` hypotheses on
`mulP_okE`/`mulP_noneE`: at `k = 2^16` the walk is the zero walk (`none`),
and at `k = 2^16 + 1` it agrees with `k = 1`. -/

example : mulP' (2 ^ 16) (some G) = none := by decide
example : mulP' (2 ^ 16 + 1) (some G) = mulP' 1 (some G) := by decide

/-! ## Axiom footprints (X02/E09 style: `#guard_msgs in #print axioms`)

E09's profile, IMPROVED at the leaves: `onCurve'_G` (the secp
`G_onCurve`'s `decide`-twin) and `addP'_none` (the `cases <;> rfl`
carbon) are **zero-axiom**; the §A verdict family carries
`[propext, Quot.sound]` (E09's `tweakPoint_some'`/`_none'` = X03's own
= the standard trio, with `Classical.choice` from X03's lemmas); the
two MAINs = **exactly E09's `[propext, Classical.choice, Quot.sound]`**
(the `Prop`-valued `match`/`decide`-discriminant leaves). -/

/-- info: 'BitcoinProofs.SmallCurve.TweakCorSmall.onCurve'_G' does not depend on any axioms -/
#guard_msgs in #print axioms onCurve'_G

/-- info: 'BitcoinProofs.SmallCurve.TweakCorSmall.addP'_none' does not depend on any axioms -/
#guard_msgs in #print axioms addP'_none

/-- info: 'BitcoinProofs.SmallCurve.TweakCorSmall.tweakPointS_overflow' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tweakPointS_overflow

/-- info: 'BitcoinProofs.SmallCurve.TweakCorSmall.tweakPointS_some' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tweakPointS_some

/-- info: 'BitcoinProofs.SmallCurve.TweakCorSmall.tweakPointS_none' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tweakPointS_none

/-- info: 'BitcoinProofs.SmallCurve.TweakCorSmall.tweakPointS_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tweakPointS_zero

/-- info: 'BitcoinProofs.SmallCurve.TweakCorSmall.tweakPointS_output_onCurve' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms tweakPointS_output_onCurve

/-- info: 'BitcoinProofs.SmallCurve.TweakCorSmall.tweakPointS_output_eq' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms tweakPointS_output_eq

end BitcoinProofs.SmallCurve.TweakCorSmall
