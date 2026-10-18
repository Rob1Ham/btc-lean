import Bitcoin.Crypto.Curve.Secp
import Bitcoin.Crypto.Curve.Mod

/-!
# BitcoinProofs.EcdsaDeep.SmulCor (E04)

Scalar-multiplication correctness for the secp256k1 executable group law
(`Bitcoin.Crypto.Curve.Secp` — read-only here): the double-and-add
scalar mult `smulBits` (STRUCTURAL over the little-endian bit list, the
R6/D-004 kernel-reducible mirror of the WF-recursive `mulP`, exactly the
`expBits`-over-`expM` pattern of `Curve/Mod.lean:138-205` / F-W14-1) equals
`mulP (bitsVal bs) p` — and hence, over the abstract Monoid-of-RawPoint rung
(`RawGroup`, this file), the bit-list walk `smulMon` equals the group
multiple `n • p` by `bitsVal bs`.

## The two rungs (E04 charter)

1. **`smulBits_eq_mulP`** (zero mathlib, zero hypotheses): the structural
   double-and-add over `bs` IS the WF `mulP` at the integer `bitsVal bs`.
   Induction is structural in `bs`; the `k`-descent lemmas `mulP_two_mul` /
   `mulP_two_mul_add_one` (`Mod.lean`-style, over the `mulP.eq_2` equation
   lemma) are the blessed route through WF definitions (proof shape of
   `Mod.expM_lt` / `Secp.mulP_ok`). Because `smulBits` is structural,
   `decide`/`rfl` reduce through it (R6 evidence: `SmulCor.kcheck` below).
2. **Rung 2 (§E, raw layer, zero mathlib) + the group lane
   (`SmulCorIF`, NEW proofs file)**: "smul correctness vs repeated
   addition". The raw layer (§E): `smulAdd k p` = the
   repeated-addition walk (`0 ↦ none = 𝒪`, `(k+1) p ↦ addP p (smulAdd
   k p)` — `p` on the LEFT, `mulP`'s odd-lane shape), plus `addP_self`
   (`addP p p = doubleP p` — the ONE zero-hypothesis group-law rung:
   `addRaw`'s `x₁ = x₂ ∧ y₁ = y₂` branch fires at `p = p` by `Nat.beq`
   reflexivity). `smulAdd k p = mulP k p` is NOT zero-hypothesis —
   the double-and-add vs repeated-addition identity is the
   chord/tangent associativity = E02/E05's `OnCurve` layer (F-E04-002)
   — so the group rung lives as a CONDITIONAL theorem in the proofs
   package: `BitcoinProofs.EcdsaDeep.SmulCorIF.MulPIF` (mathlib) takes
   a monoid hom `φ : RawPoint → M` (`φ none = 0`,
   `φ (addP p q) = φ p + φ q`) and proves `mulP_okφ`/`mulP_noneφ`
   (WF `mulP` = the group multiple `k • φ p` — the E04 discharge of
   `E02E03IF`'s `mulP_okE`/`mulP_noneE` fields, TweakCor.lean) +
   `smulAdd_okφ`/`smulBits_okφ` (the ladder: repeated addition = WF
   `mulP` = structural `smulBits` = `bitsVal bs • φ p`, all three
   rungs conditional on `addP_okφ` alone).
   **Correction (F-E04-004)**: the 57848b3 docstring's rung-2 claim
   ("`smulBits_eq_smul` (group rung) ... over `RawGroup` = the
   `RawPoint` additive Monoid ... mathlib `nsmul`, associativity/
   `nsmul_eq` for free") was OVER-PROMISED: no zero-hypothesis proof
   that `addP` is associative exists (that is E05's on-curve
   chord/tangent content), so an honest `Monoid RawPoint` with
   `add := addP`, `zero := none` cannot be landed zero-hypothesis
   (the Wall 2 decide-wall also blocks a concrete counterexample check);
   `smulBits_eq_smul` as a zero-hypothesis group-rung statement is
   not landable; the monoid
   lives in the hom-IMAGE (`M` under `MulPIF`'s `φ`), not on
   `RawPoint`, and the group-rung statement becomes
   `smulBits_okφ`/`smulAdd_okφ` (conditional). The `RawGroup`-
   `PointCor` bridge point (the E03-`PointCor` @[rule] hook) is
   unchanged — none landed (see `F-E04-003`); SmulCorIF.lean carries
   that side for E04.

## Scope notes (honest)

- On-curve preservation (`onCurve p → onCurve (smul n p)`) is NOT here:
  it is the equation-preservation layer = E02/E03's mapping + E05's
  add-correctness (the chord/tangent algebra needs `P` primality =
  `CurveZMod.P_prime`). This file proves the raw SCALAR-TOWER
  correctness (structural = WF = repeated addition, the last equation
  conditional on the hom — SmulCorIF). See `F-E04-002`.
- `smulAdd k p = mulP k p` (double-and-add = repeated addition) is NOT
  zero-hypothesis either — same OnCurve layer (F-E04-002): `mulP 2 p =
  doubleP p = addP p p = smulAdd 2 p` holds (zero-hyp), but the k ≥ 4
  steps need `p + (p + s) = (p + p) + (p + p)`-shaped associativity.
- `liftX`/decompression path is separable and covered by
  `Secp.liftX_onCurve` (TPR-049) + E08; not touched (OFF-LIMITS files).
- No `sorry`, no `native_decide`, no new axioms (prints below).
- OFF-LIMITS respected: no existing file edited (the E04 unit = this
  file + the NEW `SmulCorIF.lean` (both mine); modules listed in the
  unit commit messages per earlier plan §3).
-/

namespace BitcoinProofs.EcdsaDeep.SmulCor

open Bitcoin.Crypto.Curve.Mod (bitsVal)
open Bitcoin.Crypto.Curve.Secp

/-! ## §A The structural double-and-add (kernel-reducible mirror of `mulP`)

`smulBits bs p` walks the little-endian bit list `bs` from the TOP (the
recursion consumes the head bit = the NEXT-highest bit, the additive
half-point form — `bs` is a suffix of the full little-endian
representation): `bs = b :: bs'` means the value is `b + 2 * bitsVal bs'`,
so `smulBits (b::bs') p` = (if b then `p +` else skip) `(2 •) (smulBits
bs' p)`. Structural in `bs` ⇒ `rfl`/`decide` reduce it (R6); the
equation-with-`mulP` is the theorem (§C). -/

/-- Structural double-and-add over a little-endian bit list (LSB first).
`bs` carries the exponent `bitsVal bs` (`Curve/Mod.lean:163`); structural
recursion on `bs` (NOT on a WF measure) — the R6 kernel-reducible
mirror of the WF `mulP` (`Secp.lean:248`), the scalar-twin of
`Mod.expBits` (`Mod.lean:157`, SGN-103). `smulBits [] p = none = mulP 0 p`
by the zero convention. -/
def smulBits : List Bool → RawPoint → RawPoint
  | [], _ => none
  | b :: bs, p =>
      if b then addP p (doubleP (smulBits bs p)) else doubleP (smulBits bs p)

theorem smulBits_nil (p : RawPoint) : smulBits [] p = none := rfl

theorem smulBits_cons_false (bs : List Bool) (p : RawPoint) :
    smulBits (false :: bs) p = doubleP (smulBits bs p) := rfl

theorem smulBits_cons_true (bs : List Bool) (p : RawPoint) :
    smulBits (true :: bs) p = addP p (doubleP (smulBits bs p)) := rfl

/-! ## §B The `k`-descent lemmas (through the WF `mulP`)

`mulP` is WF-recursive (`Secp.lean:248-257`, halving on `k`). We never
unfold its recursion directly; we route through the **equation lemma**
`mulP.eq_2` (auto-generated, carries the match + the ite condition
`((k'+1) % 2 == 0) = true` as a Prop) — the same discipline as
`Mod.expBits_eq_pow_mod` / `Secp.mulP_ok` (the way: one `simp only
[mulP]`-free step through `.eq_2`, everything else `Nat`-arithmetic
(`omega`, `% 2` facts) + the existing `mulP_zero`/`mulP_one`/`addP_none`/
`doubleP_none` closure lemmas (`Secp.lean:259-273`).

The two shapes (the scalar-twins of the `Nat.pow` facts behind
`expBits_eq_pow_mod`, `Mod.lean:200-204`):

* `mulP_two_mul`: `mulP (2*v) p = doubleP (mulP v p)` — the even lane
  (`k = 2v = (2v-1)+1`, `(2v) % 2 = 0`). **v = 0 included**: both sides
  `none` (`mulP 0 p = none`, `doubleP none = none`) — the descent is
  total, no `0 < k` side condition (mirrors `mulP_zero`'s totality).
* `mulP_two_mul_add_one`: `mulP (2*v+1) p = addP p (doubleP (mulP v p))`
  — the odd lane (`k = 2v+1 = (2v)+1`, `(2v+1) % 2 = 1`).

Together: `mulP` at `k` is `mulP` at `k/2` with one more
double/add-double-and-add — i.e. `mulP` IS the little-endian bit walk,
one bit per halving, which is exactly what `smulBits` fixes structurally
(§C). -/

/-- **M2 (even lane, total).** `mulP (2*v) p = doubleP (mulP v p)`,
`v = 0` included (both sides `none` — no `0 < v` side condition). -/

theorem mulP_two_mul (p : RawPoint) : ∀ v : Nat,
    mulP (2 * v) p = doubleP (mulP v p) := by
  intro v
  match v with
  | 0 =>
    -- 2 * 0 = 0 (Nat.mul, second-arg match); mulP 0 p = none (BOTH sides);
    -- doubleP none = none
    show mulP (0 : Nat) p = doubleP (mulP (0 : Nat) p)
    rw [mulP_zero, doubleP_none]
  | v' + 1 =>
    -- 2 * (v'+1) = 2*v' + 2 = (2*v' + 1) + 1 (Nat.mul/add on the second args)
    have h2v : 2 * (v' + 1) = (2 * v' + 1) + 1 := by omega
    rw [h2v]
    -- the ite condition, as a Prop: ((2*v'+1)+1) % 2 == 0, holds (2*v'+2 = 2*(v'+1))
    rw [mulP.eq_2]
    split
    · -- even lane (consistent): (2*v'+1+1) / 2 = v'+1
      rw [show ((2 * v' + 1) + 1) / 2 = v' + 1 by omega]
    · -- odd lane: contradictory (2*v'+2 is even)
      rename_i hc
      exfalso
      exact hc (Nat.beq_eq.mpr (by omega))

/-- **M3 (odd lane).** `mulP (2*v+1) p = addP p (doubleP (mulP v p))`. -/

theorem mulP_two_mul_add_one (p : RawPoint) : ∀ v : Nat,
    mulP (2 * v + 1) p = addP p (doubleP (mulP v p)) := by
  intro v
  match v with
  | 0 =>
    -- mulP 1 p = p (mulP_one); RHS: addP p (doubleP (mulP 0 p)) = addP p none = p
    show mulP (1 : Nat) p = addP p (doubleP (mulP (0 : Nat) p))
    rw [mulP_one, mulP_zero, doubleP_none, addP_none]
  | v' + 1 =>
    -- 2*(v'+1)+1 = 2*v'+2+1 = ((2*v'+1)+1)+1
    have h2v : 2 * (v' + 1) + 1 = ((2 * v' + 1) + 1) + 1 := by omega
    rw [h2v]
    -- odd lane: the ite condition is FALSE ((2*v'+3) % 2 = 1)
    rw [mulP.eq_2]
    split
    · -- even lane: contradictory (2*v'+3 is odd)
      rename_i hc
      exfalso
      have h0 : (((2 * v' + 1) + 1) + 1) % 2 = 0 := Nat.beq_eq.mp hc
      omega
    · -- odd lane (consistent): ((2*v'+1)+1)+1) / 2 = v'+1
      rw [show (((2 * v' + 1) + 1) + 1) / 2 = v' + 1 by omega]

/-! ## §C Rung 1 — the structural walk IS the WF `mulP` (zero hypotheses)

`smulBits bs p = mulP (bitsVal bs) p`. Induction is **structural** on `bs`
(the recursion of `smulBits`), the `k`-side enters only through the two
descent lemmas `mulP_two_mul` / `mulP_two_mul_add_one` at `bitsVal` —
no WF unfolding, no `sorry`, no hypotheses: the theorem is a pure
equation between the two executable definitions. The `bitsVal`-shape
facts are the `Mod.lean:163-165` def-equations (`(if b then 1 else 0) +
2 * bitsVal bs`, the `1 + 2 * v` form by `Nat.add`-shape; the `2 * v + 1`
swap is `omega` — `Nat.add` recurses on the second argument, so `1 + 2*v`
and `2*v+1` are NOT definitionally equal). -/

/-- **A (rung 1).** The structural double-and-add over the little-endian
bit list computes the WF-recursive `mulP` at the integer `bitsVal bs` —
unconditionally (total; `[] ↔ 0` by the zero conventions). -/

theorem smulBits_eq_mulP (p : RawPoint) : ∀ (bs : List Bool),
    smulBits bs p = mulP (bitsVal bs) p := by
  intro bs
  induction bs with
  | nil =>
    -- smulBits [] p = none = mulP 0 p = mulP (bitsVal []) p
    show none = mulP (0 : Nat) p
    rw [mulP_zero]
  | cons b bs ih =>
    -- bitsVal (b :: bs) = (if b then 1 else 0) + 2 * bitsVal bs (Mod.lean:165)
    cases b with
    | false =>
      -- LHS: doubleP (smulBits bs p); RHS: mulP (2 * bitsVal bs) p (M2)
      have hbf : bitsVal (false :: bs) = 2 * bitsVal bs := by simp [bitsVal]
      rw [smulBits_cons_false, hbf, ih, mulP_two_mul]
    | true =>
      -- LHS: addP p (doubleP (smulBits bs p)); RHS: mulP (2 * bitsVal bs + 1) p (M3)
      have hbt : bitsVal (true :: bs) = 1 + 2 * bitsVal bs := by simp [bitsVal]
      have hswap : 1 + 2 * bitsVal bs = 2 * bitsVal bs + 1 := by omega
      rw [smulBits_cons_true, hbt, hswap, ih, mulP_two_mul_add_one]

/-- info: 'BitcoinProofs.EcdsaDeep.SmulCor.smulBits_eq_mulP' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms smulBits_eq_mulP

/-- info: 'BitcoinProofs.EcdsaDeep.SmulCor.mulP_two_mul' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms mulP_two_mul

/-- info: 'BitcoinProofs.EcdsaDeep.SmulCor.mulP_two_mul_add_one' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms mulP_two_mul_add_one

/-! ## §E Rung 2 (raw layer) — repeated addition `smulAdd` + the
zero-hypothesis group-law rung `addP_self`

"Smul correctness vs repeated addition": the semantic target of scalar
multiplication is the ITERATED `addP` walk. `smulAdd k p` (E1) is that
walk, structural on `k` (successor; `p` on the LEFT = `mulP`'s odd-lane
shape), the additive twin of `expM` (`Mod.lean`) — `0 ↦ none = 𝒪`.

The ONE zero-hypothesis group-law rung (E0): `addP p p = doubleP p`.
`addRaw`'s first branch `x₁ == x₂ && y₁ == y₂` (`Secp.lean:233`) fires
at `(p, p)` by `Nat.beq` reflexivity — raw ADDITION and raw DOUBLING
agree on the diagonal, with NO curve hypothesis. This is the rung the
WF `mulP` and the successor `smulAdd` share unconditionally (via
`mulP_two_mul`'s even lane): `mulP 2 p = doubleP p = addP p p =
smulAdd 2 p`.

What is NOT here (honest scope, F-E04-002): `smulAdd k p = mulP k p`
beyond the k ≤ 2 diagonal — the double-and-add vs repeated-addition
identity needs `p + (p + s) = (p + p) + (p + p)`-shaped associativity
of the raw law = the OnCurve chord/tangent layer (E02/E05), NOT
zero-hypothesis. So the group rung ("smul = the monoid multiple") is a
CONDITIONAL theorem over a monoid hom in the proofs package:
`SmulCorIF.MulPIF` (new module) takes `φ : RawPoint → M` with
`φ none = 0` and `φ (addP p q) = φ p + φ q` (E3h) and proves, from
`addP_okφ` + `addP_self` + the §B k-descent lemmas ALONE:
`mulP_okφ : φ (mulP k p) = k • φ p` (E2), `mulP_noneφ`,
`smulAdd_okφ : φ (smulAdd k p) = k • φ p` (E4) — so
`φ (smulAdd k p) = φ (mulP k p)` and `φ (smulBits bs p) =
bitsVal bs • φ p` (the full ladder, F-E04-005), plus the
`E02E03IF`-connection: `SmulIF` (= `MulPIF` over `E.Point` + the
`e`-splitting lanes) DISCHARGES E02E03IF's two E04-marked fields
`mulP_okE`/`mulP_noneE` (TweakCor.lean) from `addP_okE`'s φ-form.
See `SmulCorIF.lean` for the E04/E03 contract split. -/

/-- **E0 (the diagonal).** `addP p p = doubleP p` — `addRaw`'s first
branch fires at `(p, p)` by `Nat.beq` reflexivity (the one
zero-hypothesis group-law rung). ZERO hypotheses. -/
theorem addP_self (p : RawPoint) : addP p p = doubleP p := by
  cases p with
  | none => rfl
  | some v =>
    obtain ⟨x, y⟩ := v
    show addP (some (x, y)) (some (x, y)) = doubleP (some (x, y))
    simp [addP, doubleP, addRaw]

/-- **E1 (rung 2 raw).** Repeated addition over the executable `addP`:
`smulAdd k p` = p `addP`-added to itself `k` times (`0 ↦ none = 𝒪`,
`(k+1) p ↦ addP p (smulAdd k p)`). Structural on `k` (successor), `p`
on the LEFT (`mulP`'s odd-lane shape) — the additive twin of `expM`
(`Mod.lean`), NOT the double-and-add of `mulP`/`smulBits`. -/
def smulAdd : Nat → RawPoint → RawPoint
  | 0, _ => none
  | k + 1, p => addP p (smulAdd k p)

theorem smulAdd_zero (p : RawPoint) : smulAdd 0 p = none := rfl

theorem smulAdd_succ (k : Nat) (p : RawPoint) :
    smulAdd (k + 1) p = addP p (smulAdd k p) := rfl

theorem smulAdd_one (p : RawPoint) : smulAdd 1 p = p := by
  show addP p (smulAdd 0 p) = p
  exact addP_none p

/-- info: 'BitcoinProofs.EcdsaDeep.SmulCor.addP_self' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms addP_self

/-- info: 'BitcoinProofs.EcdsaDeep.SmulCor.smulAdd_one' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms smulAdd_one

/-! ## §D R6 evidence — kernel reduction through `smulBits` (F-E04-001)

The R6 charter claim of the structural mirror, on the record as COMPILING
checks — every `decide`/`rfl` below closes WITHOUT `native_decide`
(D-004 clean). The empirical map, probed in scratch (`dprobe.lean`,
2026-10-17) — TWO decide-walls, both WF-recursive (`termination_by`):

* **Wall 1** — `mulP` itself (WF, `Secp.lean:248`): the wall R6 was written
  for; the structural `smulBits` is the fix (D-1/D-2 below reduce).
* **Wall 2** — `egcd` (WF, `Mod.lean:211`), inside `invP = invM P d`
  (`Secp.lean:169`), i.e. inside every *real* (non-vertical, non-`none`)
  `doubleRaw`/`addRaw` step: 2-step real-point walks blow "maximum
  recursion depth" even at `maxRecDepth 100000` + `maxHeartbeats
  4000000` (scratch `dprobe` P2). The *branch-table* + `negN`-arithmetic
  of `addRaw` (256-bit `(x + P - y) % P` GMP `Nat.mod`) DOES decide
  (D-3) — the wall is exactly the `invP`/`egcd` step.

D-1 walk structure; D-2 structural `bitsVal`; D-3 REAL mod-p arithmetic
deciding (branch table + `negN`, incl. negative controls); D-4 negative
control that the walk `decide`s are not vacuous; D-5 bridge — structural
= WF *via the theorems, not the kernel* (the kernel cannot, Wall 1). -/

section kcheck

private def kc2 : RawPoint := some (1, 2)
private def kc3 : RawPoint := some (2, 3)

-- D-1: the walk is total and kernel-reduces on concrete bit lists
example : smulBits ([] : List Bool) kc2 = none := by decide
example : smulBits ([] : List Bool) kc2 = none := rfl
example : smulBits [false] kc2 = none := by decide
example : smulBits [false, false] kc3 = none := by decide
example : smulBits [true] kc2 = addP kc2 (doubleP none) := by decide
example : smulBits [true] kc2 = kc2 := by decide
example : smulBits [true] kc2 = kc2 := rfl

-- D-2: `bitsVal` (structural) reduces — the LHS↔RHS glue of the bridge
example : bitsVal ([] : List Bool) = 0 := by decide
example : bitsVal [true] = 1 := by decide
example : bitsVal [true, false] = 1 := by decide
example : bitsVal [true, true] = 3 := by decide
example : bitsVal [true, false, true] = 5 := by decide

-- D-3: REAL 256-bit mod-p arithmetic decides where no `invP` is reached:
-- the `addRaw` case table (incl. the vertical branch `y₁ = -y₂`, real
-- `negN` comparisons) and `doubleRaw`'s `y = 0` vertical branch
example : negN 2 ≠ 2 := by decide
example : addP (some (1, 2)) (some (1, negN 2)) = none := by decide
example : addP (some (1, 2)) (some (1, negN 2)) ≠ some (1, 2) := by decide
example : doubleP (some (5, 0)) = none := by decide
example : doubleP (some (5, 0)) ≠ some (5, 0) := by decide

-- D-4: negative controls (a corrupted walk would FAIL these decides)
example : smulBits [true] kc2 ≠ smulBits [false] kc2 := by decide
example : smulBits [true, false] kc3 ≠ none := by decide

-- D-5: bridge sanity — structural = WF at 1 *through the theorems*
-- (D-2's `bitsVal` + rung 1; `mulP_one` and D-1's `smulBits [true] kc2
-- = kc2` collapse the two sides to `kc2` separately); the kernel alone
-- cannot (Wall 1)
example : smulBits [true] kc2 = mulP 1 kc2 := by
  have hb : bitsVal [true] = 1 := by decide
  rw [smulBits_eq_mulP, hb]

-- D-6 (§E): the repeated-addition walk kernel-reduces (vertical lane:
-- no `invP` is reached — `addRaw`'s diagonal branch goes straight to
-- `doubleRaw`, whose `y = 0` branch returns before `invP`); the
-- `≠`-control is the corrupted-walk guard (D-4 style)
example : smulAdd 0 kc2 = none := by decide
example : smulAdd 1 kc2 = kc2 := by decide
example : smulAdd 1 kc2 = kc2 := rfl
example : smulAdd 2 (some (5, 0)) = none := by decide
example : smulAdd 2 (some (5, 0)) ≠ smulAdd 1 (some (5, 0)) := by decide
example : smulAdd 3 (some (5, 0)) = some (5, 0) := by decide
example : smulAdd 4 (some (5, 0)) = none := by decide
example : addP (some (5, 0)) (some (5, 0)) = none := by decide

-- The TWO decide-walls (NOT includable as failing examples; pinned in
-- F-E04-001 with the scratch reproduction `dprobe.lean` P2/P4):
-- Wall 1:  `example : mulP 1 kc2 = kc2 := by decide` — WF `mulP`.
-- Wall 2:  `example : kc2 ≠ doubleP kc2 := by decide` and
--      `example : smulBits [true] kc2 ≠ doubleP kc2 := by decide` and
--      `example : smulBits [true, true] kc3 = addP kc3 (doubleP (addP kc3
--        (doubleP none))) := by decide` — real `doubleRaw`/`addRaw` =
--        `invP` = `egcd` (WF), max recursion depth even at 100000.

end kcheck

end BitcoinProofs.EcdsaDeep.SmulCor
