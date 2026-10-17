/-!
# BitcoinProofs.SmallCurve.Scheme — the SmallCurve carbon copy (E10, U1)

The **small-curve carbon copy** of the secp256k1 EC layer: a TINY
prime-field Weierstrass curve where EVERYTHING — field ops, point ops,
scalar mult, the whole ECDSA scheme including verify — is
**kernel-decidable** (the R6 / D-004 hedge rung of the DEEP-LEAN
suite; see `db/findings-dl/E10.md`).

## The curve (a scaled-down secp256k1 in every parameter shape)

* `p = 65647 = 0x1006F` — 17-bit prime, `p ≡ 3 (mod 4)` (the secp
  `sqrtP`-by-exponentiation shape), `p ≡ 1 (mod 3)`;
* curve `y² = x³ + 7 (mod p)` — **the same a=0/b=7 equation** as
  secp256k1, `7` a non-cube mod `p` (nonsingular, python-verified);
* `#E = n = 65173 = 0xFE95` — 16-bit **prime**, cofactor `h = 1`
  (the secp picture: prime-order group);
* `n ≠ p` (t = p+1−n = 475, ordinary), `G = (1, 31426)` — **Gx = 1**
  (secp `Gx = 0x79BE…`), `Gy` even (the BIP-0340 even-y convention),
  `n·G = 𝒪` (python-verified: `curve.py`, frozen in-tree);
* 9/9 python sign/verify roundtrips + 9/9 high-S (the lax-ECDSA
  invariance) + all negatives + the mod-n-reduction edges
  (the SGN-110 analog) — all green in the python oracle first.

## Design: the R6 fix (why the carbon copy is kernel-decidable)

The secp layer (`Curve/Mod.lean`, `Curve/Secp.lean`, W14b) is a
*faithful but well-founded-recursive* program: `invM` (extended
Euclid), `expM`/`sqrtP` (WF recursion on the exponent), `mulP` (WF
recursion on the scalar) all poison `decide` (W14 F-W14-1).  This
module keeps **every definitional shape** of the secp layer — the
`addRaw`/`doubleRaw`/`addP`/`negP` case tables, the `RawPoint =
Option (Nat × Nat)` representation, the `mulM m x y = (x*y)%m` field
ops — and replaces exactly the three WF-poisoned kernels by
**structural** recursions on literal-width bit lists (the W14b
F-W14b-1 fix, in reusable form):

* `expB m x bs = x ^ (bitsVal bs) % m` — square-and-multiply over a
  little-endian `List Bool` (structural in `bs`; `Curve.Mod.expBits`
  carbon).  **Correctness `expB_eq_pow` is PROVED here** (core `Nat`
  lemmas only) — the secp version is still a Review-3 TODO
  (`Mod.lean:169`).
* `invP' d = expB p d bitsP2 = d ^ (p-2) % p` — the **Fermat**
  inverse (secp: `invP d = invM p d`, extended Euclid).  Correctness
  `invP'_correct` (mathlib `ZMod` + `Nat.Prime p`, `norm_num`) is the
  `VerifyEquationSmall.lean` (U3) deliverable.
* `mulP' k q = bitListRec (bitsOfN k) q` — LSB-first
  double-and-add, structural in the 17 bits of `k`
  (`bitsOfN k = (List.range 17).map ((k>>>i)%2==1)`).  The secp
  `mulP k q` is the same loop with the bit list computed by the WF
  recursion itself; `mulP' k q = k • q` (for `k < 2^17`) is the U3
  mathlib transport lane.

`readBE`/`byteAt`/`blen`/`parseDerLax` (the `Ecdsa/Der.lean`
byte layer) are **curve-free** (`parseDerLax` returns raw `Nat`
`r₀ s₀`, mod-`n` reduction happens in the verifier) and
kernel-safe (E06's 215-vector `DerBatteryCor` decides the 256-bit
secp parser in the kernel) — they are IMPORTED unchanged
(`Bitcoin.Crypto.Ecdsa.Der`, the zero-changed carbon) by U2
(`EcdsaSmall.lean`).  `parsePubKey` IS curve-specific (p, sqrtP,
onCurveN) — it is the `Ecdsa/Verify.lean:47-63` carbon with the
byte-widths rescaled to the 17-bit `p` (33/65-byte → 4/7-byte
forms, `readBE b 1 32` → `readBE b 1 3`).

## What is proved HERE (all zero-mathlib, plain `lean`, sorry-free)

* constant pins (`p`, `n` properties) — `decide`;
* `expB_zero`, `expB_eq_pow` — the structural-exponentiation
  correctness backbone (core `Nat` congruence toolkit, the
  `Curve/Mod.lean:40-52,137-144` shapes);
* `mulP'_zero` (`mulP' 0 q = none`, the secp `mulP_zero` carbon);
* `G`-pins (`onCurveN' Gx Gy = true` by `decide` — the
  `Secp.lean:122-132` `onCurveN_G` carbon, here 17-bit;
  `mulP' n G = none` = **`n·G = 𝒪` in the kernel**);
* `RawOK`-closure for `mulP'` (the `Secp.lean:281-332` family
  carbon) — `bitListRec` preserves the `x < p` invariant.

Axiom footprints: all theorems are `decide`/core-lemma proofs (see
the `#print axioms` pins in the U3 file).

## What is NOT here (honest scope)

Group-law **correctness** (`mulP' k q = k • q` in the curve group,
`addP` = the Weierstrass addition) is the E03/E05 mathlib lane over
secp — on SmallCurve it is the `VerifyEquationSmall` (U3)
`WeierstrassCurve.Affine` transport, PROPOSED.  The ECDSA
verify-equation iff (`E06`'s `verifyImpl_sound`/`_eq_raw` carbon) is
U2; the ZMod/Fermat bridge + `Nat.Prime` certificates (16-bit
`norm_num` one-liners) is U3; the py-oracle roundtrip battery is U4.
-/

namespace BitcoinProofs.SmallCurve.Scheme

/-! ## Constants (the python-frozen curve; `curve.py`) -/

/-- The field prime. 17-bit, `p ≡ 3 (mod 4)` (the `sqrtP` shape),
`p ≡ 1 (mod 3)` (with 7 a non-cube: nonsingular, `#E` odd). -/
def p : Nat := 65647

/-- The group order. 16-bit PRIME, `h = 1` (the secp picture). -/
def n : Nat := 65173

/-- The curve b (a = 0): `y² = x³ + 7` — the secp256k1 equation. -/
def curveB : Nat := 7

/-- The generator x-coordinate. **`Gx = 1`** (python: smallest `x ≥ 1`
with `x³+7` a nonzero QR; secp `Gx = 0x79BE667E…`). -/
def Gx : Nat := 1

/-- The generator y-coordinate (EVEN — the BIP-0340 even-y convention;
`sqrtP (Gx³+7) = 31426`, python-verified). -/
def Gy : Nat := 31426

/-- The generator (affine). -/
def G : Nat × Nat := (Gx, Gy)

/-- The `p ≡ 3 (mod 4)` square-root exponent `(p+1)/4 = 16412`. -/
def sqrtExp : Nat := (p + 1) / 4

theorem p_pos : 0 < p := by decide
theorem p_gt_one : 1 < p := by decide
theorem p_odd : p % 2 = 1 := by decide
theorem p_mod_4 : p % 4 = 3 := by decide
theorem p_mod_3 : p % 3 = 1 := by decide
theorem n_pos : 0 < n := by decide
theorem n_gt_one : 1 < n := by decide
theorem n_lt_p : n < p := by decide
theorem n_ne_p : n ≠ p := by decide
/-- t = p+1−n = 475 (ordinary). -/
theorem t_odd : (p + 1 - n) % 2 = 1 := by decide

/-! ## Field ops (`Curve/Mod.lean:32-36` carbon, modulus explicit) -/

def addM (m x y : Nat) : Nat := (x + y) % m
def subM (m x y : Nat) : Nat := (x + m - y) % m
def mulM (m x y : Nat) : Nat := (x * y) % m

/-! ### Closure (`Mod.lean:108-116` carbon) -/

theorem addM_lt (m x y : Nat) (hm : 0 < m) : addM m x y < m := Nat.mod_lt _ hm
theorem subM_lt (m x y : Nat) (hm : 0 < m) : subM m x y < m := Nat.mod_lt _ hm
theorem mulM_lt (m x y : Nat) (hm : 0 < m) : mulM m x y < m := Nat.mod_lt _ hm

/-! ### Congruence toolkit (`Mod.lean:40-52` carbon) -/

theorem add_mod_congr_left (a b n : Nat) : (a % n + b) % n = (a + b) % n := by
  rw [Nat.add_mod (a % n) b n, Nat.mod_mod a n, Nat.add_mod a b n]

theorem add_mod_congr_right (a b n : Nat) : (a + b % n) % n = (a + b) % n := by
  rw [Nat.add_mod a (b % n) n, Nat.mod_mod b n, Nat.add_mod a b n]

theorem mul_mod_congr_left (a b n : Nat) : (a % n * b) % n = (a * b) % n := by
  rw [Nat.mul_mod (a % n) b n, Nat.mod_mod a n, Nat.mul_mod a b n]

theorem mul_mod_congr_right (a b n : Nat) : (a * (b % n)) % n = (a * b) % n := by
  rw [Nat.mul_mod a (b % n) n, Nat.mod_mod b n, Nat.mul_mod a b n]

/-- The `mulM` congruence (`Mod.lean:137-144` carbon). -/
theorem mulM_congr {m a b c d : Nat} (h1 : a % m = c % m) (h2 : b % m = d % m) :
    mulM m a b = mulM m c d := by
  show (a * b) % m = (c * d) % m
  have e1 : (a * b) % m = ((a % m) * (b % m)) % m := by
    rw [← mul_mod_congr_left a b m, ← mul_mod_congr_right (a % m) b m]
  have e2 : ((c % m) * (d % m)) % m = (c * d) % m := by
    rw [mul_mod_congr_left c (d % m) m, mul_mod_congr_right c d m]
  rw [e1, h1, h2, e2]

/-! ## Structural exponentiation (the `Curve.Mod.expBits` carbon)

`expB m x bs` computes `x ^ (bitsVal bs) % m` — square-and-multiply
over the little-endian bit list `bs`, **structural** in `bs` (never
WF-recursive on a Nat measure): the W14b F-W14b-1 kernel-decidability
fix.  Correctness (`expB_eq_pow`, below) is proved over the core `Nat`
lemmas only — the secp `expM`/`expBits` version of this theorem is
still a Review-3 TODO (`Mod.lean:169`), so the carbon already
**improves** on the original here. -/

/-- Square-and-multiply over an explicit little-endian bit list. -/
def expB (m x : Nat) : List Bool → Nat
  | [] => 1
  | b :: bs => mulM m (mulM m (expB m x bs) (expB m x bs)) (if b then x else 1)

/-- The numeric value of a little-endian bit list. -/
def bitsVal : List Bool → Nat
  | [] => 0
  | b :: bs => (if b then 1 else 0) + 2 * bitsVal bs

/-- The little-endian bit list of `e` at width `w` (runtime helper,
structural in the literal-width `List.range w`). -/
def bitsOfW (w e : Nat) : List Bool :=
  (List.range w).map (fun i => (e >>> i) % 2 == 1)

/-- The 17 little-endian bits of `p - 2 = 65645` (python-frozen:
`probe_lits.py`). -/
def bitsP2 : List Bool :=
  [true, false, true, true, false, true, true, false, false, false,
   false, false, false, false, false, false, true]

/-- The 16 little-endian bits of `n - 2 = 65171` (python-frozen). -/
def bitsN2 : List Bool :=
  [true, true, false, false, true, false, false, true, false, true,
   true, true, true, true, true, true]

/-- The 15 little-endian bits of `sqrtExp = (p+1)/4 = 16412`
(python-frozen). -/
def bitsSqrt : List Bool :=
  [false, false, true, true, true, false, false, false, false, false,
   false, false, false, false, true]

theorem bitsVal_bitsP2 : bitsVal bitsP2 = p - 2 := by decide
theorem bitsVal_bitsN2 : bitsVal bitsN2 = n - 2 := by decide
theorem bitsVal_bitsSqrt : bitsVal bitsSqrt = sqrtExp := by decide

/-! **The `expB_zero` pitfall** (found by the kernel, twice): the naive
`expB m 0 bs = 0` is FALSE — `expB m 0 [] = 1 = 0 ^ 0` (the `[]` round
returns 1 unconditionally) and even `expB m 0 [false] = 1` (a `false`
round multiplies by `1`, never touching `0`).  The correct statement is
`expB_eq_pow` at `x = 0` (i.e. `expB m 0 bs = 0 ^ bitsVal bs % m`,
`= 1` iff every bit is `false`).  The secp `invP_zero` analog
(`invP' 0 = 0`) is therefore a `decide` on the literal `bitsP2`
(which has a `true` bit) — see `invP'_zero` below. -/

/-- **`expB m x bs = x ^ (bitsVal bs) % m`** — the square-and-multiply
loop is the binary exponentiation (core `Nat` congruence toolkit
only; zero mathlib).

Proof: induction on `bs`.  The `b :: bs` round computes
`mulM m (mulM m Xb Xb) (if b then x else 1)` where `Xb = x ^ bv % m`
(the `ih`), i.e. mod-`(Xb * Xb) * (xᵇ)`; the goal is
`x ^ (bᵇ + 2*bv) % m` = `xᵇ * (x^bv * x^bv) % m` (by `Nat.pow_add`,
`Nat.mul_succ` on `2*bv`).  Both sides are `(A * B) % m` shapes with
equal residues (`xᵇ % m = xᵇ % m` since `xᵇ = x` (`b = true`) resp.
`xᵇ = 1` (`b = false`)); `mulM_congr` closes. -/

theorem expB_eq_pow (m x : Nat) (hm : 1 < m) : ∀ (bs : List Bool),
    expB m x bs = x ^ (bitsVal bs) % m := by
  intro bs
  induction bs with
  | nil =>
      -- expB [] = 1 = 1 % m  (1 < m);  x ^ 0 = 1
      simp only [expB, bitsVal, Nat.pow_zero]
      exact (Nat.mod_eq_of_lt hm).symm
  | cons b bs ih =>
      -- expB (b::bs) = ((Xb * Xb % m) * (if b then x else 1)) % m,
      -- Xb = x^bv % m (ih);  x ^ (b^ + 2*bv) = x^b^ * (x^bv * x^bv)
      cases b with
      | false =>
          -- expB = ((Xb*Xb)%m * 1) % m = (Xb*Xb) % m = (x^bv * x^bv) % m;
          -- x^(0+2*bv) = x^(bv+bv) = x^bv * x^bv
          simp only [expB, bitsVal] at ih ⊢
          simp at ih ⊢
          rw [ih]
          simp only [mulM]
          rw [Nat.mul_one, ← Nat.mul_mod, Nat.mod_mod, Nat.two_mul, Nat.pow_add]
      | true =>
          -- expB = ((Xb*Xb)%m * x) % m = (x^bv * x^bv * x) % m;
          -- x^(1+2*bv) = x^succ(2bv) = x^(2bv) * x = (x^bv * x^bv) * x
          simp only [expB, bitsVal] at ih ⊢
          simp at ih ⊢
          rw [ih]
          simp only [mulM]
          rw [← Nat.mul_mod, mul_mod_congr_left, Nat.one_add, Nat.pow_succ,
              Nat.two_mul, Nat.pow_add]

/-! ## Curve constants and the Fermat field inverses

`invP'`/`invN'`/`sqrtP'` are the R6 structural replacements of secp's
WF-recursive `invM`/`sqrtP` (extended Euclid / `expM`): Fermat
exponentiation over the literal bit lists (17 bits of `p-2`, 16 bits
of `n-2`, 15 bits of `(p+1)/4`).  `expB_eq_pow` above gives
`invP' d = d ^ (p-2) % p` etc. — via `bitsVal_bitsP2`-style pins. -/

/-- The field inverse (Fermat): `invP' d = d ^ (p-2) % p`. -/
def invP' (d : Nat) : Nat := expB p d bitsP2

/-- The scalar-field inverse (Fermat): `invN' s = s ^ (n-2) % n`. -/
def invN' (s : Nat) : Nat := expB n s bitsN2

/-- The p ≡ 3 (mod 4) square root: `sqrtP' x = x ^ ((p+1)/4) % p`. -/
def sqrtP' (x : Nat) : Nat := expB p x bitsSqrt

/-- The residue test (`Secp.isSqrt` carbon). -/
def isSqrt' (x r : Nat) : Bool := mulM p r r == x

/-- `expB m x bs < m` (the `expM_lt` carbon, `Mod.lean:118-127`). -/
theorem expB_lt (m x : Nat) (hm : 1 < m) : ∀ (bs : List Bool),
    expB m x bs < m := by
  intro bs
  induction bs with
  | nil => exact hm
  | cons b bs ih => exact mulM_lt m _ _ (by omega)

theorem invP'_lt (d : Nat) : invP' d < p := expB_lt p d p_gt_one bitsP2
theorem invN'_lt (s : Nat) : invN' s < n := expB_lt n s n_gt_one bitsN2
theorem sqrtP'_lt (x : Nat) : sqrtP' x < p := expB_lt p x p_gt_one bitsSqrt

/-- `invP' 0 = 0` (the secp `invP_zero` analog — here a `decide`:
`0 ^ (p-2) = 0`, `bitsP2` has a `true` bit). -/
theorem invP'_zero : invP' 0 = 0 := by decide

/-- `invN' 0 = 0`. -/
theorem invN'_zero : invN' 0 = 0 := by decide

/-! ## The curve equation (`Secp.lean:94-132` carbon) -/

/-- Curve equation on raw representatives: `y² = x³ + 7 (mod p)`. -/
def onCurveN' (x y : Nat) : Bool :=
  mulM p y y == addM p (mulM p (mulM p x x) x) curveB

/-- The generator is on the curve (the `onCurveN_G` carbon,
`Secp.lean:122-132` — here 17-bit, kernel-decided). -/
theorem onCurveN'_G : onCurveN' Gx Gy = true := by decide

theorem Gx_lt : Gx < p := by decide
theorem Gy_lt : Gy < p := by decide

/-! ## Negation (`Secp.lean:133-146` carbon) -/

/-- Negation of the y-coordinate: `-y = p - y (mod p)`. -/
def negN (y : Nat) : Nat := subM p 0 y

theorem negN_lt (y : Nat) : negN y < p := subM_lt p 0 y p_pos

/-- `negN 0 = 0` (`subM p 0 0 = (0 + p - 0) % p = p % p = 0`). -/
theorem negN_zero : negN 0 = 0 := by
  simp [negN, subM]

/-! ## Raw points (`Secp.lean:148-160` carbon) -/

/-- A raw affine point: `none` = O, `some (x, y)` with `x, y` in `[0, p)`. -/
abbrev RawPoint' := Option (Nat × Nat)

/-- The coordinate invariant (`Secp.RawOK` carbon). -/
def RawOK' : RawPoint' → Prop
  | none => True
  | some (x, y) => x < p ∧ y < p

/-! ## The group operations (total, case-complete; `Secp.lean:162-246` carbon)

Every field op is a `mulM`/`subM`/`addM` (a `% p`), so — exactly as in
secp (`Secp.lean:22-33`: "`invP 0 = 0` keeps every branch defined even
for off-curve garbage inputs") — **`RawOK'` is preserved
unconditionally** (mod-closure only) through `doubleRaw`/`addRaw`
(`doubleRaw_ok`/`addRaw_ok`); `negP'`/`addP'`/`bitListRec`/`mulP'`
pass their inputs through (`negP' (x,y) = (x, negN y)` keeps `x`; the
`true`-gates of `bitListRec` add the base `q` itself), so their
closure is **`hq`-gated** (the `RawOK' q` hypothesis; for `mulP' k G`
it is `RawOK' (some G) = Gx < p ∧ Gy < p`, the `G`-pins). -/

/-- Point doubling (the `doubleRaw` carbon; `y = 0` → `none`). -/
def doubleRaw (x y : Nat) : RawPoint' :=
  if y == 0 then none
  else
    let lam := mulM p (mulM p 3 (mulM p x x)) (invP' (addM p y y))
    let x3 := subM p (mulM p lam lam) (addM p x x)
    let y3 := subM p (mulM p lam (subM p x x3)) y
    some (x3, y3)

def doubleP' : RawPoint' → RawPoint'
  | none => none
  | some (x, y) => doubleRaw x y

/-- Point negation (the `negP` carbon). -/
def negP' : RawPoint' → RawPoint'
  | none => none
  | some (x, y) => some (x, negN y)

/-- Point addition (the complete case table carbon). -/
def addRaw (x1 y1 x2 y2 : Nat) : RawPoint' :=
  if x1 == x2 && y1 == y2 then doubleRaw x1 y1
  else if x1 == x2 && y1 == negN y2 then none
  else
    let lam := mulM p (subM p y2 y1) (invP' (subM p x2 x1))
    let x3 := subM p (subM p (mulM p lam lam) x1) x2
    let y3 := subM p (mulM p lam (subM p x1 x3)) y1
    some (x3, y3)

def addP' : RawPoint' → RawPoint' → RawPoint'
  | none, q => q
  | p', none => p'
  | some (x1, y1), some (x2, y2) => addRaw x1 y1 x2 y2

/-! ## Scalar multiplication (the R6 structural `mulP` carbon)

secp `mulP` (`Secp.lean:248-252`) is the LSB-first double-and-add
**WF-recursive on the scalar** `k`:

    mulP (k'+1) p = if (k'+1) % 2 == 0 then doubleP (mulP ((k'+1)/2) p)
                    else addP p (doubleP (mulP ((k'+1)/2) p))
    mulP 0 p = none

— i.e. `mulP k p = bitListRec (bits of k) p` where `bitListRec` is
**structural in the bit list**:

    bitListRec (b :: bs) q = (if b then addP' q (doubleP' (bitListRec bs q))
                              else doubleP' (bitListRec bs q))
    bitListRec [] q = none                 (= mulP 0 q = none)

For `k < 2^16` (all consensus scalars: `u1, u2, r, s, z < n = 65173 <
2^16`), `bitsOfW 16 k` is the complete little-endian bit list of `k`
(the high-order `false`s are no-ops: `doubleP' none = none`), and
`mulP' k q = mulP k q` (the WF/structural equivalence) is the U3
transport lane's theorem; the definitional carbon is what the kernel
decides. -/

/-- Scalar mult, structural in the little-endian bit list of `k`. -/
def bitListRec : List Bool → RawPoint' → RawPoint'
  | [] => fun _ => none
  | b :: bs => fun q =>
      (if b then addP' q (doubleP' (bitListRec bs q))
       else doubleP' (bitListRec bs q))

/-- Scalar multiplication (the `mulP` carbon; `k < 2^16`). -/
def mulP' (k : Nat) (q : RawPoint') : RawPoint' :=
  bitListRec (bitsOfW 16 k) q

/-! ### The `RawOK'` closure family (`Secp.lean:281-332` carbon) -/

theorem doubleRaw_ok (x y : Nat) : RawOK' (doubleRaw x y) := by
  unfold doubleRaw
  by_cases hy : y == 0
  · simp only [hy]
    exact True.intro
  · simp only [hy]
    exact ⟨subM_lt p _ _ p_pos, subM_lt p _ _ p_pos⟩

theorem doubleP'_ok (q : RawPoint') : RawOK' (doubleP' q) := by
  cases q with
  | none => exact True.intro
  | some v =>
      obtain ⟨x, y⟩ := v
      exact doubleRaw_ok x y

theorem addRaw_ok (x1 y1 x2 y2 : Nat) : RawOK' (addRaw x1 y1 x2 y2) := by
  unfold addRaw
  by_cases h1 : x1 == x2 && y1 == y2
  · simp only [h1]
    exact doubleRaw_ok x1 y1
  · by_cases h2 : x1 == x2 && y1 == negN y2
    · simp only [h1, h2]
      exact True.intro
    · simp only [h1, h2]
      exact ⟨subM_lt p _ _ p_pos, subM_lt p _ _ p_pos⟩

theorem negP'_ok (q : RawPoint') (hq : RawOK' q) : RawOK' (negP' q) := by
  cases q with
  | none => exact True.intro
  | some v =>
      obtain ⟨x, y⟩ := v
      obtain ⟨hx, _hy⟩ := hq
      exact ⟨hx, negN_lt y⟩

theorem addP'_ok (q1 q2 : RawPoint') (hq1 : RawOK' q1) (hq2 : RawOK' q2) :
    RawOK' (addP' q1 q2) := by
  cases q1 with
  | none => exact hq2
  | some v1 =>
      obtain ⟨x1, y1⟩ := v1
      cases q2 with
      | none => exact hq1
      | some v2 =>
          obtain ⟨x2, y2⟩ := v2
          exact addRaw_ok x1 y1 x2 y2

/-- **`bitListRec` preserves `RawOK'`** — the `mulP_ok` carbon
(`Secp.lean:281-332`), `hq`-gated (the `true`-gates add the base `q`
itself). -/
theorem bitListRec_ok : ∀ (bs : List Bool) (q : RawPoint') (hq : RawOK' q),
    RawOK' (bitListRec bs q) := by
  intro bs
  induction bs with
  | nil => intro q hq; exact True.intro
  | cons b bs ih =>
      intro q hq
      cases b with
      | false => exact doubleP'_ok (bitListRec bs q)
      | true =>
          exact addP'_ok q (doubleP' (bitListRec bs q)) hq (doubleP'_ok (bitListRec bs q))

/-- `mulP' k q` preserves `RawOK'` (the `mulP_ok` carbon). -/
theorem mulP'_ok (k : Nat) (q : RawPoint') (hq : RawOK' q) :
    RawOK' (mulP' k q) :=
  bitListRec_ok (bitsOfW 16 k) q hq

/-- `RawOK' G` (the generator pins). -/
theorem RawOK'_G : RawOK' (some G) := ⟨Gx_lt, Gy_lt⟩

/-! ### `mulP'` structural pins (the `mulP_zero` carbon family) -/

/-- `mulP' 0 q = none` — the secp `mulP_zero` carbon
(`Secp.lean:258`: `mulP 0 p = none`, there by `simp only [mulP]`).
Here `bitsOfW 16 0 = [false × 16]` and `bitListRec [] q = none`
discards `q` (the base `q` only enters at `true` bits), so
`mulP' 0 q = doubleP' ^16 none = none` — **`rfl` even for a free
`q = some (x, y)`** (a free-var `decide` cannot close it; the
kernel's defeq reduction can — the F-E10-1 discipline). -/
theorem mulP'_zero (q : RawPoint') : mulP' 0 q = none := by
  cases q <;> rfl

/-- `mulP' 1 G = G` (`[T, F^15]` → `addP' G (doubleP' none) =
`addP' G none` = `G`). -/
theorem mulP'_one_G : mulP' 1 G = G := by
  decide

/-- **`n · G = O`** — the group order pin, in the kernel (16 rounds
of double-and-add over the 16 bits of `n = 65173`, ~500 `mulM` + 2
`invP'`-chains; python-verified `curve.py`, here kernel-decided). -/
theorem mulP'_nG : mulP' n G = none := by
  decide

end BitcoinProofs.SmallCurve.Scheme
