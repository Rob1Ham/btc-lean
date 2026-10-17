import Bitcoin.Crypto.Ecdsa.Verify

/-!
# Bitcoin.Crypto.EcdsaDeep.VerifyStruct — the kernel-decidable verifyImpl mirror (E11)

EcdsaDeep contributor E11. Target of this file: the **structural mirror** of the
consensus ECDSA verifier `Bitcoin.Crypto.Ecdsa.Verify.verifyImpl`
(Ecdsa/Verify.lean:82, the lax-ECDSA decision's compute layer) that is
**kernel-reducible** — i.e. `decide`/`rfl` in the Lean kernel can evaluate
it on concrete 215-vector-battery inputs — together with the
**mirror-equality theorems** that reduce `verifyStruct = verifyImpl` to
small, explicitly-named hypotheses (E16's `EcdsaDeep/Entry.lean` transport
slot: `ecdsaEntryDeep verifyStruct = ecdsaEntry verifyImpl` modulo exactly
this equality).

## Why a mirror is needed (R6 / D-004 / F-W14-1)

`verifyImpl` is NOT kernel-reducible: three of its ingredients are
well-founded-recursive (`termination_by`), and the kernel cannot unfold
`WellFounded.fix`:

* `sqrtP x = expM P x sqrtExp`   (WF on the exponent; `Curve/Mod.lean:106`,
  `Curve/Secp.lean:189`) — used by `parsePubKey` (Verify.lean:47);
* `invM n s` = `egcd n s`        (WF on the second argument;
  `Curve/Mod.lean:211`/`:357`) — the ECDSA scalar inverse `w`
  (Verify.lean:95), and *also* the field inverse `invP` inside every
  `addRaw`/`doubleRaw` point step (Secp.lean:169/232/218);
* `mulP u p`                      (WF on the scalar; Secp.lean:248) — both
  scalar multiplications (Verify.lean:98).

Everything else in `verifyImpl` (`parseDerLax`, `blen`/`byteAt`/`readBE`,
`mulM`/`addM`/`subM`, the `Nat`/`Bool`/`Option` plumbing) already reduces
in the kernel — evidenced in-tree by the four `by decide` examples of
`Test/Crypto/EcdsaTest.lean:277-295` (the Der layer only) and the
secp256k1 literals decided in `Curve/Secp.lean:63-85` (`G_onCurve`,
`Gx_lt`, …) and `Curve/Field/Interface.lean`'s Pratt certificates
(`expBits P 3 bspF = 1 := by decide`, :1205).

## The mirror technique (W14's `expBits` pattern, made systematic)

A WF recursion on a 256-bit `Nat` **value** cannot be made
kernel-reducible by adding a fuel counter alone: matching on a bignum
literal still needs the literal in constructor form. Instead every
recursion is re-based on the structure of a **small literal** (or of a
list the kernel can only build small), with the big values confined to
GMP-accelerated positions (`Nat` `%`, `/`, `*`, `+`, `==`) that the
kernel decides on 256-bit literals all over the crypto tree:

* `bitsLeF k e : List Bool` — the `k` low bits of `e`, **fuel `k` =
  small literal, `e` never matched** (only `e % 2`, `e / 2`). With
  `e < 2^k` it is a faithful bit-list (`bitsLeF_bitsVal`), and
  `Mod.expBits` (structural on the bit list, kernel-reducible by the
  in-tree Pratt certificates) takes over: `sqrtPS x = expBits P x
  (bitsLeF 254 sqrtExp)`. **`sqrtPS = sqrtP` is proved unconditionally**
  (`expM_eq_pow_mod` here + in-tree `expBits_eq_pow_mod` (SGN-103) +
  `bitsLeF_bitsVal` + `sqrtExp < 2^254` by `decide`).
* `egcdL fs a b` — one Euclid step per **fuel-list** cons, `b == 0` by
  `Nat.beq` instead of the WF `match b`; `egcdLDone fs a b` is the same
  recursion collecting `b == 0 || …`, i.e. the kernel-decidable witness
  "the Euclid descent of `(a, b)` reaches `b = 0` within `fs.length`
  steps". `egcdL_eq_egcd` reduces `egcdL fs a b = egcd a b` to exactly
  `egcdLDone fs a b = true` — no `sorry`, no primality, no depth
  arithmetic: the *entire* hypothesis is the structural-completion flag.
* `mulPbs bs p` — the `mulP` double-and-add recurrence re-based on the
  scalar's LE bit list (`bitsLeF 256 u`): `mulPbsG_eq_mulP` reduces
  `mulPbsG fs (bitsLeF 256 u) p = mulP u p` to `u < 2^256` **and** the
  point-op-level `egcdLDone` flags (each `invP` inside `addRaw`/
  `doubleRaw` runs the `egcdL` mirror).
* Point ops (`addRawG`/`doubleRawG`/`addPG`/`doublePG`) and the scalar
  inverse (`invMSG`) are verbatim shape-copies of `Secp`/`Mod`/`Verify`
  with `invP`/`invM` replaced by the `egcdL`-backed `invPSG`/`invMSG`;
  `parsePubKeyG` is a verbatim `parsePubKey` with `sqrtP := sqrtPG`.
* `verifyStructG fs` is a verbatim `verifyImpl` over these, and
  `verifyStruct := verifyStructG (zeros 600)` fixes the fuel list.

## VERIFIED vs PROPOSED (this file)

VERIFIED (sorry-free, `#guard_msgs` axiom pins at the bottom):
`sqrtPS_eq_sqrtP`/`sqrtPG_eq_sqrtP` (unconditional), `expM_eq_pow_mod`,
`bitsLeF_bitsVal`, `egcdL_eq_egcd` (under `egcdLDone`), `invMSG_eq_invM`,
`addRawG_eq_addRaw`, `doubleRawG_eq_doubleRaw`, `addPG_eq_addP`,
`doublePG_eq_doubleP`, `mulPbsG_eq_mulP` (under `u < 2^256` + the
point-op `egcdLDone` flags), `parsePubKeyG_eq_parsePubKey`
(unconditional), and `verifyStructG_eq_verifyImpl` reducing the mirror
equality to the three explicitly named **structural-mirror hypotheses**
`hE`/`hN` (universal `egcdLDone` completion of the two egcd uses:
mod-`P` inside every point op, mod-`n` for the scalar inverse) —
`hG` (`0 < G < n` on the scalar) is *discharged* by in-tree facts.
See `verifyStructCor` (proofs package) for the per-battery-vector
discharges (`decide`).

PROPOSED (NOT here): the universal `hE`/`hN` (a Euclid/Lamé-style depth
≤ 600 bound for the two 256-bit moduli — E02/E07 territory), and the
`verifyStruct = verifyImpl` *battery* instantiation (E11's proofs file).
Nothing in this file assumes, states or axiomatizes them.
-/

namespace Bitcoin.Crypto.EcdsaDeep.VerifyStruct

open Bitcoin.Crypto.Curve.Mod
open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Ecdsa.Der
open Bitcoin.Crypto.Ecdsa.Verify

/-! ## Little-endian bit lists (fuel-structural; the value is never matched) -/

/-- The `k` low bits of `e`, least-significant first. Recursion is on the
**fuel `k`** (a small literal at every use site); `e` occurs only in the
GMP-accelerated positions `e % 2`, `e / 2` and `e % 2 == 1`, so the
kernel reduces `bitsLeF 254 e` on a 256-bit `e`. Contrast
`Mod.natBitsF` (Mod.lean:171), which matches on the value (`n + 1`) and
so is runtime-only. -/
def bitsLeF : Nat → Nat → List Bool
  | 0, _ => []
  | k + 1, e => (e % 2 == 1) :: bitsLeF k (e / 2)

/-- `bitsLeF k e` is a faithful bit-list of `e` whenever `e < 2^k`. -/
theorem bitsLeF_bitsVal : ∀ (k e : Nat), e < 2 ^ k → bitsVal (bitsLeF k e) = e := by
  intro k
  induction k with
  | zero =>
    intro e he
    have h0 : e = 0 := by omega
    subst h0
    rfl
  | succ k' ih =>
    intro e he
    have h2 : 2 ^ (k' + 1) = 2 * 2 ^ k' := by
      rw [Nat.pow_succ]
      omega
    -- e / 2 < 2 ^ k', arithmetically from e < 2 * 2 ^ k'
    have hd2 : e / 2 < 2 ^ k' := by
      have := Nat.div_add_mod e 2
      omega
    have hee : e % 2 + 2 * (e / 2) = e := Nat.mod_add_div e 2
    have hq2 : e % 2 < 2 := Nat.mod_lt e (by omega)
    show (if e % 2 == 1 then 1 else 0) + 2 * bitsVal (bitsLeF k' (e / 2)) = e
    rw [ih (e / 2) hd2]
    split
    · next h1 =>
      have he1 : e % 2 = 1 := Nat.beq_eq.mp h1
      omega
    · next h1 =>
      have he1 : e % 2 ≠ 1 := fun hh => h1 (Nat.beq_eq.mpr hh)
      omega

/-! ## The exponent mirror: `sqrtPG` (unconditionally = `sqrtP`) -/

/-- `expM` computes `x ^ e % m`. Strong induction on the (variable)
exponent, the `expM_lt` proof shape (Mod.lean:123). This is the bridge
from the WF square-and-multiply to `Mod.expBits`
(`expBits_eq_pow_mod`, SGN-103). -/
theorem expM_eq_pow_mod (m x : Nat) (hm : 1 < m) : ∀ e : Nat, expM m x e = x ^ e % m := by
  intro e
  induction e using Nat.strongRecOn with
  | ind e' IH =>
    cases e' with
    | zero =>
      simp only [expM]
      rw [Nat.pow_zero, Nat.mod_eq_of_lt hm]
    | succ e2 =>
      by_cases hodd : e2 % 2 == 1
      · -- e2 + 1 is even: expM m x (e2+1) = mulM (expM k) (expM k), k := (e2+1)/2
        have he2 : e2 % 2 = 1 := Nat.beq_eq.mp hodd
        have hlt : (e2 + 1) / 2 < e2 + 1 := Nat.div_lt_self (by omega) (by omega)
        have hih := IH ((e2 + 1) / 2) hlt
        have hk : (e2 + 1) / 2 * 2 = e2 + 1 := by
          have := Nat.div_add_mod (e2 + 1) 2
          omega
        simp only [expM, hodd]
        rw [hih]
        rw [mulM_congr (m := m) (a := x ^ ((e2 + 1) / 2) % m)
          (b := x ^ ((e2 + 1) / 2) % m) (c := x ^ ((e2 + 1) / 2))
          (d := x ^ ((e2 + 1) / 2)) (Nat.mod_mod _ _) (Nat.mod_mod _ _)]
        show (x ^ ((e2 + 1) / 2) * x ^ ((e2 + 1) / 2)) % m = x ^ (e2 + 1) % m
        have hke : x ^ ((e2 + 1) / 2) * x ^ ((e2 + 1) / 2) = x ^ (e2 + 1) := by
          rw [← Nat.pow_add, show (e2 + 1) / 2 + (e2 + 1) / 2 = e2 + 1 from by omega]
        rw [hke]
      · -- e2 + 1 is odd: expM m x (e2+1) = mulM x (expM e2)
        have he2 : e2 % 2 ≠ 1 := fun hh => hodd (Nat.beq_eq.mpr hh)
        have hlt : e2 < e2 + 1 := Nat.lt_succ_self e2
        have hih := IH e2 hlt
        simp only [expM, hodd]
        rw [hih]
        rw [mulM_congr (m := m) (a := x) (b := x ^ e2 % m) (c := x) (d := x ^ e2)
          rfl (Nat.mod_mod _ _)]
        show (x * x ^ e2) % m = x ^ (e2 + 1) % m
        rw [Nat.pow_succ]
        exact congrArg (fun t => t % m) (Nat.mul_comm x (x ^ e2))

/-- `sqrtP`'s exponent fits in 254 bits (kernel `decide` on the secp256k1
literals, `Secp`-style). -/
theorem sqrtExp_lt : sqrtExp < 2 ^ 254 := by decide

theorem n_lt_two256 : n < 2 ^ 256 := by decide

/-- The structural square root: `expBits` over the fuel-structural bit
list of `sqrtExp`. `254` is a small literal, so the kernel reduces
`sqrtPG x` on a 256-bit `x`. -/
def sqrtPG (x : Nat) : Nat := expBits P x (bitsLeF 254 sqrtExp)

/-- **Unconditional bridge**: the structural sqrt IS `sqrtP`. Via
`expM_eq_pow_mod` + in-tree `expBits_eq_pow_mod` (SGN-103) +
`bitsLeF_bitsVal`. No hypothesis, no primality. -/
theorem sqrtPG_eq_sqrtP (x : Nat) : sqrtPG x = sqrtP x := by
  unfold sqrtPG sqrtP
  rw [expBits_eq_pow_mod P x P_gt_one (bitsLeF 254 sqrtExp),
    expM_eq_pow_mod P x P_gt_one sqrtExp, bitsLeF_bitsVal 254 sqrtExp sqrtExp_lt]

/-! ## The egcd mirror: `egcdL` + the kernel-decidable witness `egcdLDone` -/

/-- The fuel-list Euclid: one step per cons, `b == 0` by `Nat.beq` (the
`b` VALUE is never matched). Shape-verbatim mirror of `Mod.egcd`
(Mod.lean:211) modulo the `b' + 1` vs `b` spelling (equal when
`b = b' + 1`). At fuel `[]` with `b ≠ 0` the result is the `b = 0`
answer — the honest fuel-out behavior; `egcdLDone` witnesses it away. -/
def egcdL : List Nat → Nat → Nat → Int × Int × Int
  | [], a, _ => ((a : Int), 1, 0)
  | _ :: fs', a, b =>
      if b == 0 then ((a : Int), 1, 0)
      else
        let (g, x, y) := egcdL fs' b (a % b)
        (g, y, x - (a / b) * y)

/-- The kernel-decidable completion witness: the Euclid descent of
`(a, b)` reaches `b = 0` within `fs.length` steps. Structural on `fs`,
`b` never matched (only `b == 0`, `a % b`). -/
def egcdLDone : List Nat → Nat → Nat → Bool
  | [], _, b => b == 0
  | _ :: fs', a, b => b == 0 || egcdLDone fs' b (a % b)

/-- **Bridge**: under the completion witness, the fuel-list Euclid IS
`egcd`. Induction on the fuel list; the `b = 0` case reduces `egcd a 0`
by the literal-zero match, the `b ≠ 0` case is the `egcd`-succ equation
(`simp only [egcd]`, the `egcd_bezout` proof shape, Mod.lean:240) with
the `b' + 1 = b` spelling congruence. No `sorry`, no primality. -/
theorem egcdL_eq_egcd : ∀ (fs : List Nat) (a b : Nat), egcdLDone fs a b = true →
    egcdL fs a b = egcd a b := by
  intro fs
  induction fs with
  | nil =>
    intro a b h
    have hb : b = 0 := Nat.beq_eq.mp h
    subst hb
    simp only [egcd]
    simp [egcdL]
  | cons z fs' ih =>
    intro a b h
    simp only [egcdLDone, Bool.or_eq_true] at h
    cases hb0 : b == 0 with
    | true =>
      have hb : b = 0 := Nat.beq_eq.mp hb0
      subst hb
      simp only [egcd]
      simp only [egcdL, hb0]
      simp
    | false =>
      have hbne : b ≠ 0 := by
        intro hh; rw [hh] at hb0; exact absurd hb0 (by decide)
      have hf : ¬((b == 0) = true) := by rw [hb0]; simp
      have h' := h.resolve_left hf
      obtain ⟨b', hbS⟩ : ∃ b' : Nat, b = b' + 1 := by
        cases b with
        | zero => exact absurd rfl hbne
        | succ b'' => exact ⟨b'', rfl⟩
      subst hbS
      have hrec := ih (b'+1) (a % (b'+1)) h'
      have hL : egcdL (z :: fs') a (b'+1)
          = (let (g, x, y) := egcdL fs' (b'+1) (a % (b'+1)); (g, y, x - (a / (b'+1)) * y)) := by
        simp only [egcdL]
        rw [hb0]
        rfl
      have hR : egcd a (b'+1)
          = (let (g, x, y) := egcd (b'+1) (a % (b'+1)); (g, y, x - (a / (b'+1)) * y)) := by
        simp only [egcd]
      obtain ⟨g, u, v, hgv⟩ : ∃ g u v : Int, egcd (b'+1) (a % (b'+1)) = (g, u, v) := ⟨_, _, _, rfl⟩
      rw [hgv] at hR
      dsimp only at hR
      rw [hL, hR]
      rw [hrec]
      dsimp only
      rw [hgv]

/-! ## The scalar-inverse mirror `invMSG` -/

/-- `Mod.invM` (Mod.lean:357) with `egcd` replaced by the fuel-list
`egcdL`. -/
def invMSG (fs : List Nat) (m x : Nat) : Nat :=
  let (g, _, v) := egcdL fs m x
  if g == 1 then (v % (m : Int)).toNat else 0

/-- **Bridge**: under the completion witness, `invMSG` IS `invM`. -/
theorem invMSG_eq_invM (fs : List Nat) (m x : Nat) (h : egcdLDone fs m x = true) :
    invMSG fs m x = invM m x := by
  have he : ∃ g u v : Int, egcdL fs m x = (g, u, v) := ⟨_, _, _, rfl⟩
  obtain ⟨g, u, v, hgl⟩ := he
  have heq : ∃ g' u' v' : Int, egcd m x = (g', u', v') := ⟨_, _, _, rfl⟩
  obtain ⟨g', u', v', heg⟩ := heq
  have hgg := egcdL_eq_egcd fs m x h
  rw [hgl, heg] at hgg
  have hge : g = g' := congrArg (fun p : Int × Int × Int => p.1) hgg
  have hve : v = v' := congrArg (fun p : Int × Int × Int => p.2.2) hgg
  unfold invMSG invM
  rw [hgl, heg, hge, hve]

/-! ## The point-op mirror (`invP` → `invPSG`) -/

/-- `Secp.invP` (Secp.lean:169) with `invM P` replaced by `invMSG fs P`. -/
def invPSG (fs : List Nat) (d : Nat) : Nat := invMSG fs P d

/-- `Secp.doubleRaw` (Secp.lean:218) over `invPSG`. -/
def doubleRawG (fs : List Nat) (x y : Nat) : RawPoint :=
  if y == 0 then none else
    let lam := mulM P (mulM P 3 (mulM P x x)) (invPSG fs (addM P y y))
    let x3 := subM P (mulM P lam lam) (addM P x x)
    let y3 := subM P (mulM P lam (subM P x x3)) y
    some (x3, y3)

def doublePG (fs : List Nat) : RawPoint → RawPoint
  | none => none
  | some (x, y) => doubleRawG fs x y

/-- `Secp.addRaw` (Secp.lean:232) over `invPSG`. -/
def addRawG (fs : List Nat) (x1 y1 x2 y2 : Nat) : RawPoint :=
  if x1 == x2 && y1 == y2 then doubleRawG fs x1 y1
  else if x1 == x2 && y1 == negN y2 then none
  else
    let lam := mulM P (subM P y2 y1) (invPSG fs (subM P x2 x1))
    let x3 := subM P (subM P (mulM P lam lam) x1) x2
    let y3 := subM P (mulM P lam (subM P x1 x3)) y1
    some (x3, y3)

def addPG (fs : List Nat) : RawPoint → RawPoint → RawPoint
  | none, q => q
  | p, none => p
  | some (x1, y1), some (x2, y2) => addRawG fs x1 y1 x2 y2

/-- **Bridges**: under the completion witness of the `invP`-call, each
point-op mirror IS its `Secp` original (shape-verbatim congruence). -/
theorem invPSG_eq_invP (fs : List Nat) (d : Nat) (h : egcdLDone fs P d = true) :
    invPSG fs d = invP d := by
  unfold invPSG invP
  rw [invMSG_eq_invM fs P d h]

theorem doubleRawG_eq_doubleRaw (fs : List Nat) (x y : Nat)
    (h : egcdLDone fs P (addM P y y) = true) : doubleRawG fs x y = doubleRaw x y := by
  unfold doubleRawG doubleRaw
  split
  · rfl
  · rw [invPSG_eq_invP fs (addM P y y) h]

theorem doublePG_eq_doubleP (fs : List Nat) (p : RawPoint)
    (h : ∀ x y : Nat, p = some (x, y) → egcdLDone fs P (addM P y y) = true) :
    doublePG fs p = doubleP p := by
  cases p with
  | none => rfl
  | some pt =>
    obtain ⟨x, y⟩ := pt
    simp only [doublePG, doubleP]
    exact doubleRawG_eq_doubleRaw fs x y (h x y rfl)

theorem addRawG_eq_addRaw (fs : List Nat) (x1 y1 x2 y2 : Nat)
    (hD : egcdLDone fs P (subM P x2 x1) = true)
    (hDD : x1 == x2 && y1 == y2 → egcdLDone fs P (addM P y1 y1) = true) :
    addRawG fs x1 y1 x2 y2 = addRaw x1 y1 x2 y2 := by
  unfold addRawG addRaw
  split
  · rename_i hc
    rw [doubleRawG_eq_doubleRaw fs x1 y1 (hDD hc)]
  · split
    · rfl
    · rw [invPSG_eq_invP fs (subM P x2 x1) hD]

/-! ## The scalar-multiplication mirror `mulPbsG` (bit-list structural) -/

/-- The `mulP` double-and-add recurrence re-based on the scalar's LE bit
list (`Secp.mulP`, Secp.lean:248): per bit `b`, `mulP (2j + b) p =
(if b then addP p ∘ doubleP else doubleP) (mulP j p)`. Recursion on the
LIST structure — kernel-reducible — and `p` is threaded verbatim. -/
def mulPbsG (fs : List Nat) : List Bool → RawPoint → RawPoint
  | [], _ => none
  | b :: bs', p =>
      if b then addPG fs p (doublePG fs (mulPbsG fs bs' p))
      else doublePG fs (mulPbsG fs bs' p)

/-- The scalar-multiplication mirror: `mulPSG fs u p = mulPbsG fs
(bitsLeF 256 u) p` (the `256` is a small literal; `u` never matched). -/
def mulPSG (fs : List Nat) (u : Nat) (p : RawPoint) : RawPoint :=
  mulPbsG fs (bitsLeF 256 u) p

/-! ## The pass-2 bridges: `mulPSG = mulP`, `verifyStructG = verifyImpl`

The universal mod-`P` completion hypothesis (E14's fuel-sufficiency
hand-off F-E14-9 / F-E14-8, the Lamé-depth `≤ 600` bound = E02/E07
territory, PROPOSED-NOT-HERE):

  `hE : ∀ d < P, egcdLDone FL P d = true`

makes every `invPSG`-call-site inside every point op bridge to `invP`
(the call-site arguments are `addM`/`subM` outputs, `< P` by
`Mod.addM_lt`/`subM_lt` — no primality), and the mod-`n` analogue `hN`
bridges the scalar inverse. Under exactly these two the mirror IS the
verifier. -/

/-- `addPG fs = addP` under `hE` (the `hE`-form of `addRawG_eq_addRaw`:
every flag is `hE` at a `< P` argument). -/
theorem addPG_eq_addP (fs : List Nat) (hE : ∀ d : Nat, d < P → egcdLDone fs P d = true) :
    ∀ (p q : RawPoint), addPG fs p q = addP p q := by
  intro p q
  cases p with
  | none => rfl
  | some pt =>
    obtain ⟨x1, y1⟩ := pt
    cases q with
    | none => rfl
    | some qt =>
      obtain ⟨x2, y2⟩ := qt
      simp only [addPG, addP]
      exact addRawG_eq_addRaw fs x1 y1 x2 y2 (hE _ (subM_lt P _ _ P_pos))
        (fun _ => hE _ (addM_lt P _ _ P_pos))

/-- `doublePG fs = doubleP` under `hE` (the `hE`-form of
`doublePG_eq_doubleP`). -/
theorem doublePG_eq_doubleP_hE (fs : List Nat) (hE : ∀ d : Nat, d < P → egcdLDone fs P d = true) :
    ∀ (p : RawPoint), doublePG fs p = doubleP p := by
  intro p
  cases p with
  | none => rfl
  | some pt =>
    obtain ⟨x, y⟩ := pt
    simp only [doublePG, doubleP]
    exact doubleRawG_eq_doubleRaw fs x y (hE _ (addM_lt P _ _ P_pos))

/-- **The scalar-multiplication bridge**: under `hE`, the bit-list mirror
IS `mulP` on the whole range `u < 2^k`. Induction on the fuel `k`
(`bitsLeF` and `mulP`'s `k'+1`-descent both recurse at `u / 2`); the two
branches line up through `bitsLeF`'s head `u % 2 == 1` vs `mulP`'s
`(k'+1) % 2 == 0`; `k ≥ u` (via `u < 2^k`) keeps the mirror's `[]`
leaf = `mulP 0 = none` honest at `u = 0`. -/
theorem mulPbsG_eq_mulP (fs : List Nat) (hE : ∀ d : Nat, d < P → egcdLDone fs P d = true) :
    ∀ (k u : Nat) (p : RawPoint), u < 2 ^ k →
    mulPbsG fs (bitsLeF k u) p = mulP u p := by
  intro k
  induction k with
  | zero =>
    intro u p hu
    have h0 : u = 0 := by omega
    subst h0
    -- `mulP` is WF-recursive (termination_by): `mulP 0 p ≢ none` in the
    -- kernel, so `mulP_zero` (an equation-lemma) must be REWRITTEN; the
    -- mirror side then reduces structurally (`bitsLeF 0 0 ≡ []`,
    -- `mulPbsG fs [] p ≡ none`).
    rw [mulP_zero]
    rfl
  | succ k' ih =>
    intro u p hu
    have h2 : 2 ^ (k' + 1) = 2 * 2 ^ k' := by
      rw [Nat.pow_succ]
      omega
    have hd2 : u / 2 < 2 ^ k' := by
      have := Nat.div_add_mod u 2
      omega
    cases u with
    | zero =>
      have h02 : (0:Nat) / 2 = 0 := by decide
      have hlt : (0:Nat) < 2 ^ k' := by have := hd2; omega
      have hq : mulPbsG fs (bitsLeF k' 0) p = mulP 0 p := ih 0 p hlt
      show doublePG fs (mulPbsG fs (bitsLeF k' ((0:Nat) / 2)) p) = mulP 0 p
      rw [h02]
      rw [hq]
      rw [doublePG_eq_doubleP_hE fs hE (mulP 0 p), mulP_zero]
      rfl
    | succ u' =>
      by_cases hq : u' % 2 == 0
      · -- u = u'+1 is ODD: `bitsLeF`'s head true, `mulP`'s odd branch
        have hq' : u' % 2 = 0 := Nat.beq_eq.mp hq
        have hu1 : (u'+1) % 2 = 1 := by omega
        have hbT : ((u'+1) % 2 == 1) = true := by rw [hu1]; decide
        have hbF : ((u'+1) % 2 == 0) = false := by rw [hu1]; decide
        -- mirror side: the head-`true` ite takes `addPG`/`doublePG`
        have hL : mulPbsG fs (bitsLeF (k'+1) (u'+1)) p
            = addP p (doubleP (mulP ((u'+1)/2) p)) := by
          show mulPbsG fs (((u'+1) % 2 == 1) :: bitsLeF k' ((u'+1)/2)) p
              = addP p (doubleP (mulP ((u'+1)/2) p))
          rw [hbT]
          show addPG fs p (doublePG fs (mulPbsG fs (bitsLeF k' ((u'+1)/2)) p))
              = addP p (doubleP (mulP ((u'+1)/2) p))
          rw [ih ((u'+1)/2) p hd2]
          rw [addPG_eq_addP fs hE p (doublePG fs (mulP ((u'+1)/2) p)),
              doublePG_eq_doubleP_hE fs hE (mulP ((u'+1)/2) p)]
        -- `mulP` side: the `(u'+1) % 2 == 0` ite takes the else branch
        have hR : mulP (u'+1) p
            = addP p (doubleP (mulP ((u'+1)/2) p)) := by
          rw [mulP.eq_def]
          show (if ((u'+1) % 2 == 0) = true then doubleP (mulP ((u'+1)/2) p)
                else addP p (doubleP (mulP ((u'+1)/2) p)))
            = addP p (doubleP (mulP ((u'+1)/2) p))
          rw [hbF]
          rfl
        rw [hL, hR]
      · -- u = u'+1 is EVEN: `bitsLeF`'s head false, `mulP`'s even branch
        have hqF : (u' % 2 == 0) = false := by
          cases hbb : (u' % 2 == 0) with
          | true  => exact absurd hbb hq
          | false => rfl
        have hq' : u' % 2 ≠ 0 := by
          intro h0
          rw [h0] at hq
          exact hq (by simp)
        have hu1 : (u'+1) % 2 = 0 := by omega
        have hbF1 : ((u'+1) % 2 == 1) = false := by rw [hu1]; decide
        have hbT0 : ((u'+1) % 2 == 0) = true := by rw [hu1]; decide
        -- mirror side: the head-`false` ite takes `doublePG`
        have hL : mulPbsG fs (bitsLeF (k'+1) (u'+1)) p
            = doubleP (mulP ((u'+1)/2) p) := by
          show mulPbsG fs (((u'+1) % 2 == 1) :: bitsLeF k' ((u'+1)/2)) p
              = doubleP (mulP ((u'+1)/2) p)
          rw [hbF1]
          show doublePG fs (mulPbsG fs (bitsLeF k' ((u'+1)/2)) p)
              = doubleP (mulP ((u'+1)/2) p)
          rw [ih ((u'+1)/2) p hd2]
          rw [doublePG_eq_doubleP_hE fs hE (mulP ((u'+1)/2) p)]
        -- `mulP` side: the `(u'+1) % 2 == 0` ite takes the then branch
        have hR : mulP (u'+1) p
            = doubleP (mulP ((u'+1)/2) p) := by
          rw [mulP.eq_def]
          show (if ((u'+1) % 2 == 0) = true then doubleP (mulP ((u'+1)/2) p)
                else addP p (doubleP (mulP ((u'+1)/2) p)))
            = doubleP (mulP ((u'+1)/2) p)
          rw [hbT0]
          rfl
        rw [hL, hR]

theorem mulPSG_eq_mulP (fs : List Nat) (hE : ∀ d : Nat, d < P → egcdLDone fs P d = true)
    (u : Nat) (p : RawPoint) (hu : u < 2 ^ 256) :
    mulPSG fs u p = mulP u p := by
  unfold mulPSG
  exact mulPbsG_eq_mulP fs hE 256 u p hu

/-! ## The public-key parse mirror (unconditionally = `parsePubKey`) -/

/-- `Verify.parsePubKey` (Verify.lean:47) with `sqrtP := sqrtPG` —
**unconditionally** equal, by `sqrtPG_eq_sqrtP`. -/
def parsePubKeyG (b : ByteArray) : RawPoint :=
  let tag := byteAt b 0
  if blen b == 33 && (tag == 0x02 || tag == 0x03) then
    let x := readBE b 1 32
    if x ≥ P then none
    else
      let y2 := liftY2 x
      let root := sqrtPG y2
      if !isSqrt y2 root then none
      else some (x, if (tag == 0x03) == (root % 2 == 1) then root else negN root)
  else if blen b == 65 && (tag == 0x04 || tag == 0x06 || tag == 0x07) then
    let x := readBE b 1 32
    let y := readBE b 33 32
    if x ≥ P || y ≥ P then none
    else if (tag == 0x06 || tag == 0x07) && ((y % 2 == 1) != (tag == 0x07)) then none
    else if onCurveN x y then some (x, y) else none
  else none

/-- **Unconditional bridge**: the parse mirror IS `parsePubKey`. -/
theorem parsePubKeyG_eq_parsePubKey (b : ByteArray) :
    parsePubKeyG b = parsePubKey b := by
  unfold parsePubKeyG parsePubKey
  simp only [sqrtPG_eq_sqrtP]

/-! ## The verifier mirror -/

/-- The fixed fuel list: 600 cons cells (Lamé-style worst case for the
256-bit Euclid descents is ≈ 385; 600 is the margin carried by the
`egcdLDone` witnesses). -/
def fuelLN : Nat := 600

def zeros : Nat → List Nat
  | 0 => []
  | k + 1 => 0 :: zeros k

def FL : List Nat := zeros fuelLN

/-- The kernel-decidable structural mirror of `verifyImpl`
(Verify.lean:82): verbatim shape, `parsePubKey := parsePubKeyG`,
`invM n := invMSG fs n`, `mulP := mulPSG fs`. -/
def verifyStructG (fs : List Nat) (sig pk msg : ByteArray) : Bool :=
  match parseDerLax sig with
  | none => false
  | some (r0, s0) =>
    match parsePubKeyG pk with
    | none => false
    | some (qx, qy) =>
      -- scalar_set_b32 reduction (mod n) + nonzero check
      let z := bytesToNatBE msg % n
      let r := r0 % n
      let s := s0 % n
      if r == 0 || s == 0 then false
      else
        let w := invMSG fs n s
        let u1 := mulM n z w
        let u2 := mulM n r w
        match addPG fs (mulPSG fs u1 (some G)) (mulPSG fs u2 (some (qx, qy))) with
        | none => false
        | some (rx, _) => rx % n == r

/-- **The crown bridge** (pass-2's `verifyStructG_eq_verifyImpl`, the
E16 `EntryWired` integration slot's hypothesis-form equality): under
the two universal-completion hypotheses —
  `hE : ∀ d < P, egcdLDone fs P d = true` (F-E14-9, the mod-`P`
Lamé-depth bound, PROPOSED-NOT-HERE) and its mod-`n` analogue `hN`
(F-E14-8) — the structural mirror `verifyStructG fs` IS `verifyImpl`.
The parse bridge `parsePubKeyG = parsePubKey` is unconditional;
`invMSG = invM` at `s0 % n` (via `hN`, `s0 % n < n` by `Nat.mod_lt`),
`mulPSG = mulP` (via `hE`, at `u1, u2 = mulM n _ w < n < 2^256`) and
`addPG = addP` (via `hE`) carry the scalar-multiplication pipeline.
No property of `parseDerLax` — both `match`es are split on both sides
of the equation (E06's `verifyImpl_iff` route). -/
theorem verifyStructG_eq_verifyImpl (fs : List Nat)
    (hE : ∀ d : Nat, d < P → egcdLDone fs P d = true)
    (hN : ∀ s : Nat, s < n → egcdLDone fs n s = true) (sig pk msg : ByteArray) :
    verifyStructG fs sig pk msg = verifyImpl sig pk msg := by
  unfold verifyStructG verifyImpl
  rw [parsePubKeyG_eq_parsePubKey pk]
  cases hd : parseDerLax sig with
  | none => dsimp only
  | some rs =>
    obtain ⟨r0, s0⟩ := rs
    cases hp : parsePubKey pk with
    | none => dsimp only
    | some q =>
      obtain ⟨qx, qy⟩ := q
      dsimp only
      have hs : s0 % n < n := Nat.mod_lt _ n_pos
      have hu1 : mulM n (bytesToNatBE msg % n) (invM n (s0 % n)) < 2 ^ 256 :=
        Nat.lt_trans (mulM_lt n _ _ n_pos) n_lt_two256
      have hu2 : mulM n (r0 % n) (invM n (s0 % n)) < 2 ^ 256 :=
        Nat.lt_trans (mulM_lt n _ _ n_pos) n_lt_two256
      rw [invMSG_eq_invM fs n (s0 % n) (hN (s0 % n) hs),
          mulPSG_eq_mulP fs hE (mulM n (bytesToNatBE msg % n) (invM n (s0 % n))) (some G) hu1,
          mulPSG_eq_mulP fs hE (mulM n (r0 % n) (invM n (s0 % n))) (some (qx, qy)) hu2,
          addPG_eq_addP fs hE]
      rfl

/-- The mirror at the fixed fuel list — E16's `EcdsaDeep/Entry.lean`
integration slot (`verifyD := Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct`). -/
def verifyStruct (sig pk msg : ByteArray) : Bool := verifyStructG FL sig pk msg

end Bitcoin.Crypto.EcdsaDeep.VerifyStruct
