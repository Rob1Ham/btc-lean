import Bitcoin.Crypto.Curve.Secp
import Mathlib.NumberTheory.LucasPrimality
import Mathlib.Tactic.NormNum.Prime

/-!
# BitcoinProofs.Crypto.CurveZMod — P-primality + ZMod field bridge

Mathlib is a LEAF DEPENDENCY of this package ONLY (core stays zero-dep;
dual-route measurement).

## Part 1 — `Fact (Nat.Prime P)` by a complete Pratt certificate

`lucas_primality` (mathlib) needs, for each level, a witness `a` with
`a^(m−1) = 1` and `a^((m−1)/q) ≠ 1` for every prime `q ∣ m−1`. The chain
(sympy-verified):

    P−1    = 2 · 3 · 7 · 13441 · Cbig                (Cbig prime, 72 digits)
    Cbig−1 = 2 · 3 · 5 · 29² · 31 · 7723 · Rbig · Qtwo
    Rbig−1 = 2 · 3 · Qbig                            (Qbig prime, 23 digits)
    Qbig−1 = 8 · 3 · 5323 · Sbig                     (Sbig prime, 18 digits)
    Sbig−1 = 8 · 25 · 2621 · 24809 · 13331831        (leaves, trial division)

Witnesses: P→3, Cbig→10, Qbig→5, Rbig→6, Qtwo→3, Sbig→6.

**The kernel-reduction lesson, applied twice over.** The exponents are
256-bit, so `a^e` must NEVER be kernel-evaluated through Lean's linear
`Nat.pow`. v1 of this file routed every exponent through the core's
`natBitsF 400 e` fuel wrapper; that made each leaf `decide` reduce a
400-deep fuel recursion *inside* the decidability instance → "maximum
recursion depth" even at `maxRecDepth 100000`. v2 therefore hardcodes every
exponent's bit list as a python-generated `List Bool` literal: the kernel
only ever evaluates the STRUCTURAL square-and-multiply `Mod.expBits` over a
literal list (O(bits) GMP modmuls), bridged by `Mod.expBits_eq_pow_mod` plus
a per-literal `decide` of `Mod.bitsVal`. All sorry-free; no `native_decide`
(proofs package is outside the Test/ zone).

Two further elaborator gotchas baked into the emitted shape:
* ZMod-level statements write the base as an explicit cast
  `((a : Nat) : ZMod m)`; the `OfNat` literal form `(6 : ZMod m)` makes the
  unifier whnf-reduce the ZMod power linearly in the exponent.
* Small-prime primality uses `norm_num`, once per distinct prime — the
  `Decidable (Nat.Prime p)` instance is kernel trial division over all
  `m < p`, pathological already at `p ≈ 25000`.
-/

namespace BitcoinProofs.Crypto.CurveZMod

open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Curve.Mod

set_option maxRecDepth 100000
set_option maxHeartbeats 2000000

/-! ## Transport toolkit (all symbolic — no big-number kernel work) -/

theorem natCast_pow_eq (m a : Nat) : ∀ e : Nat,
    ((a : ZMod m) ^ e : ZMod m) = (((a ^ e) % m : Nat) : ZMod m) := by
  intro e
  induction e with
  | zero => simp
  | succ k ih =>
    have h1 : ((a : ZMod m) ^ (k + 1) : ZMod m) = (a : ZMod m) ^ k * (a : ZMod m) :=
      pow_succ _ _
    rw [h1, ih, ← Nat.cast_mul, ZMod.natCast_eq_natCast_iff']
    rw [mul_mod_congr_left, ← Nat.pow_succ, Nat.mod_mod]

/-- A proved `(a^e) % m = 1` transports to `ZMod m`. -/
theorem zpow_one {m a e : Nat} (hm : 1 < m) (h : (a ^ e) % m = 1) :
    ((a : ZMod m) ^ e) = 1 := by
  rw [natCast_pow_eq, ← Nat.cast_one, ZMod.natCast_eq_natCast_iff',
    Nat.mod_mod, h, Nat.mod_eq_of_lt hm]

/-- A proved `(a^e) % m ≠ 1` transports to `ZMod m`. -/
theorem zpow_ne_one {m a e : Nat} (hm : 1 < m) (h : (a ^ e) % m ≠ 1) :
    ((a : ZMod m) ^ e) ≠ 1 := by
  intro hc
  apply h
  rw [natCast_pow_eq, ← Nat.cast_one, ZMod.natCast_eq_natCast_iff',
    Nat.mod_mod, Nat.mod_eq_of_lt hm] at hc
  exact hc

/-- `(a^E) % m = 1` from the structural square-and-multiply over a literal
bit list (`bs` is the little-endian binary expansion of `E`). -/
theorem eq_via_exp {m a E : Nat} (hm : 1 < m) {bs : List Bool}
    (hb : bitsVal bs = E) (h : expBits m a bs = 1) : (a ^ E) % m = 1 := by
  have hp := expBits_eq_pow_mod m a hm bs
  rw [hp, hb] at h
  exact h

/-- `(a^E) % m ≠ 1`, same routing as `eq_via_exp`. -/
theorem ne_via_exp {m a E : Nat} (hm : 1 < m) {bs : List Bool}
    (hb : bitsVal bs = E) (h : expBits m a bs ≠ 1) : (a ^ E) % m ≠ 1 := by
  intro hc
  apply h
  have hp := expBits_eq_pow_mod m a hm bs
  rw [hp, hb]
  exact hc

/-! ## Small primes (once each; `norm_num`, not the kernel `decide` instance) -/


theorem pr2 : Nat.Prime 2 := Nat.prime_two
theorem pr3 : Nat.Prime 3 := Nat.prime_three
theorem pr5 : Nat.Prime 5 := Nat.prime_five
theorem pr7 : Nat.Prime 7 := by norm_num
theorem pr11 : Nat.Prime 11 := by norm_num
theorem pr29 : Nat.Prime 29 := by norm_num
theorem pr31 : Nat.Prime 31 := by norm_num
theorem pr1627 : Nat.Prime 1627 := by norm_num
theorem pr2621 : Nat.Prime 2621 := by norm_num
theorem pr2657 : Nat.Prime 2657 := by norm_num
theorem pr4423 : Nat.Prime 4423 := by norm_num
theorem pr5323 : Nat.Prime 5323 := by norm_num
theorem pr7723 : Nat.Prime 7723 := by norm_num
theorem pr13441 : Nat.Prime 13441 := by norm_num
theorem pr24809 : Nat.Prime 24809 := by norm_num
theorem pr41201 : Nat.Prime 41201 := by norm_num
theorem pr96557 : Nat.Prime 96557 := by norm_num
theorem pr7240687 : Nat.Prime 7240687 := by norm_num
theorem pr13331831 : Nat.Prime 13331831 := by norm_num
theorem pr107590001 : Nat.Prime 107590001 := by norm_num

/-! ## Level: Sbig -/

def Sbig : Nat := 173378833005251801

theorem ssplit : Sbig - 1 = 2 * 2 * 2 * 5 * 5 * 2621 * 24809 * 13331831 := by decide

def bssF : List Bool := [false, false, false, true, true, false, true, true, false, false, true, true, false, false, false, true, true, false, false, true, true, false, true, true, false, false, false, true, false, false, true, false, true, false, false, false, false, true, false, false, true, true, true, false, true, true, true, true, true, true, true, false, false, true, true, false, false, true]
theorem hbsF : bitsVal bssF = 173378833005251800 := by decide
theorem vsF : expBits Sbig 6 bssF = 1 := by decide
theorem sexpl : (6 ^ (Sbig - 1)) % Sbig = 1 :=
  eq_via_exp (m := Sbig) (a := 6) (E := Sbig - 1) (by decide) hbsF vsF
theorem sexplZ : (((6 : Nat) : ZMod Sbig) ^ (Sbig - 1)) = 1 :=
  zpow_one (by decide) sexpl

def bss0 : List Bool := [false, false, true, true, false, true, true, false, false, true, true, false, false, false, true, true, false, false, true, true, false, true, true, false, false, false, true, false, false, true, false, true, false, false, false, false, true, false, false, true, true, true, false, true, true, true, true, true, true, true, false, false, true, true, false, false, true]
theorem hbs0 : bitsVal bss0 = 86689416502625900 := by decide
theorem vs0 : expBits Sbig 6 bss0 ≠ 1 := by decide
def bss1 : List Bool := [false, false, false, true, true, true, true, true, false, false, false, true, false, true, true, true, true, false, false, false, true, false, false, true, false, true, true, true, false, false, false, false, true, false, true, true, false, true, true, false, true, false, false, false, true, true, false, false, true, true, false, true, true, true, true]
theorem hbs1 : bitsVal bss1 = 34675766601050360 := by decide
theorem vs1 : expBits Sbig 6 bss1 ≠ 1 := by decide
def bss2 : List Bool := [false, false, false, true, true, true, false, true, true, false, true, false, false, false, false, false, true, true, false, true, false, false, false, false, false, false, false, true, true, true, false, true, true, false, false, true, false, true, false, false, false, false, true, true, true, true]
theorem hbs2 : bitsVal bss2 = 66149879055800 := by decide
theorem vs2 : expBits Sbig 6 bss2 ≠ 1 := by decide
def bss3 : List Bool := [false, false, false, true, true, false, false, false, true, true, true, true, true, false, true, false, false, true, false, true, false, false, true, true, true, false, true, false, false, true, false, false, true, true, false, true, true, false, true, false, false, true, true]
theorem hbs3 : bitsVal bss3 = 6988545810200 := by decide
theorem vs3 : expBits Sbig 6 bss3 ≠ 1 := by decide
def bss4 : List Bool := [false, false, false, true, false, true, true, true, true, true, true, true, false, true, false, true, false, true, true, false, false, true, false, false, true, true, true, false, false, false, false, false, true, true]
theorem hbs4 : bitsVal bss4 = 13004877800 := by decide
theorem vs4 : expBits Sbig 6 bss4 ≠ 1 := by decide

theorem s_hd : ∀ q : Nat, Nat.Prime q → q ∣ Sbig - 1 →
    (((6 : Nat) : ZMod Sbig) ^ ((Sbig - 1) / q)) ≠ 1 := by
  intro q hq hdv
  rw [ssplit] at hdv
  rcases (Nat.Prime.dvd_mul hq).mp hdv with dl2 | dr2
  · rcases (Nat.Prime.dvd_mul hq).mp dl2 with dl4 | dr4
    · rcases (Nat.Prime.dvd_mul hq).mp dl4 with dl6 | dr6
      · rcases (Nat.Prime.dvd_mul hq).mp dl6 with dl8 | dr8
        · rcases (Nat.Prime.dvd_mul hq).mp dl8 with dl10 | dr10
          · rcases (Nat.Prime.dvd_mul hq).mp dl10 with dl12 | dr12
            · rcases (Nat.Prime.dvd_mul hq).mp dl12 with dl14 | dr14
              · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2).mp dl14
                subst eqq
                exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbs0 vs0)
              · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2).mp dr14
                subst eqq
                exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbs0 vs0)
            · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2).mp dr12
              subst eqq
              exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbs0 vs0)
          · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr5).mp dr10
            subst eqq
            exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbs1 vs1)
        · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr5).mp dr8
          subst eqq
          exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbs1 vs1)
      · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2621).mp dr6
        subst eqq
        exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbs2 vs2)
    · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr24809).mp dr4
      subst eqq
      exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbs3 vs3)
  · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr13331831).mp dr2
    subst eqq
    exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbs4 vs4)

/-- Sbig is prime (Pratt certificate level). -/
theorem Sbig_prime : Nat.Prime Sbig :=
  lucas_primality Sbig ((6 : Nat) : ZMod Sbig) sexplZ s_hd

/-! ## Level: Qbig -/

def Qbig : Nat := 22149492674086928081353

theorem qsplit : Qbig - 1 = 2 * 2 * 2 * 3 * 5323 * Sbig := by decide

def bsqF : List Bool := [false, false, false, true, false, false, true, true, true, false, false, false, false, true, true, false, true, true, true, false, true, false, true, false, false, false, true, false, true, false, true, false, false, true, false, true, false, false, false, false, false, true, false, true, true, false, false, true, true, false, true, false, true, true, true, true, true, false, false, true, true, true, false, true, false, false, false, false, true, true, false, true, false, false, true]
theorem hbqF : bitsVal bsqF = 22149492674086928081352 := by decide
theorem vqF : expBits Qbig 5 bsqF = 1 := by decide
theorem qexpl : (5 ^ (Qbig - 1)) % Qbig = 1 :=
  eq_via_exp (m := Qbig) (a := 5) (E := Qbig - 1) (by decide) hbqF vqF
theorem qexplZ : (((5 : Nat) : ZMod Qbig) ^ (Qbig - 1)) = 1 :=
  zpow_one (by decide) qexpl

def bsq0 : List Bool := [false, false, true, false, false, true, true, true, false, false, false, false, true, true, false, true, true, true, false, true, false, true, false, false, false, true, false, true, false, true, false, false, true, false, true, false, false, false, false, false, true, false, true, true, false, false, true, true, false, true, false, true, true, true, true, true, false, false, true, true, true, false, true, false, false, false, false, true, true, false, true, false, false, true]
theorem hbq0 : bitsVal bsq0 = 11074746337043464040676 := by decide
theorem vq0 : expBits Qbig 5 bsq0 ≠ 1 := by decide
def bsq1 : List Bool := [false, false, false, true, true, false, false, true, false, false, false, false, false, true, false, false, true, false, true, true, true, false, false, false, false, false, true, true, true, false, false, false, false, true, true, true, false, true, false, true, false, false, false, true, false, false, false, true, false, false, true, true, true, true, true, true, true, false, true, true, true, true, false, false, false, false, false, false, true, false, false, true, true]
theorem hbq1 : bitsVal bsq1 = 7383164224695642693784 := by decide
theorem vq1 : expBits Qbig 5 bsq1 ≠ 1 := by decide
def bsq2 : List Bool := [false, false, false, true, true, false, true, false, false, false, true, false, true, true, false, false, true, false, true, false, false, true, true, false, false, false, true, false, true, false, true, true, false, true, true, true, true, false, false, false, true, true, false, true, false, true, false, false, true, true, true, true, true, true, false, true, true, false, false, true, true, true]
theorem hbq2 : bitsVal bsq2 = 4161091992126043224 := by decide
theorem vq2 : expBits Qbig 5 bsq2 ≠ 1 := by decide
def bsq3 : List Bool := [false, false, false, true, false, false, false, false, true, true, false, false, true, true, true, true, true]
theorem hbq3 : bitsVal bsq3 = 127752 := by decide
theorem vq3 : expBits Qbig 5 bsq3 ≠ 1 := by decide

theorem q_hd : ∀ q : Nat, Nat.Prime q → q ∣ Qbig - 1 →
    (((5 : Nat) : ZMod Qbig) ^ ((Qbig - 1) / q)) ≠ 1 := by
  intro q hq hdv
  rw [qsplit] at hdv
  rcases (Nat.Prime.dvd_mul hq).mp hdv with dl2 | dr2
  · rcases (Nat.Prime.dvd_mul hq).mp dl2 with dl4 | dr4
    · rcases (Nat.Prime.dvd_mul hq).mp dl4 with dl6 | dr6
      · rcases (Nat.Prime.dvd_mul hq).mp dl6 with dl8 | dr8
        · rcases (Nat.Prime.dvd_mul hq).mp dl8 with dl10 | dr10
          · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2).mp dl10
            subst eqq
            exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbq0 vq0)
          · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2).mp dr10
            subst eqq
            exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbq0 vq0)
        · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2).mp dr8
          subst eqq
          exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbq0 vq0)
      · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr3).mp dr6
        subst eqq
        exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbq1 vq1)
    · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr5323).mp dr4
      subst eqq
      exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbq2 vq2)
  · have eqq := (Nat.prime_dvd_prime_iff_eq hq Sbig_prime).mp dr2
    subst eqq
    exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbq3 vq3)

/-- Qbig is prime (Pratt certificate level). -/
theorem Qbig_prime : Nat.Prime Qbig :=
  lucas_primality Qbig ((5 : Nat) : ZMod Qbig) qexplZ q_hd

/-! ## Level: Rbig -/

def Rbig : Nat := 132896956044521568488119

theorem rsplit : Rbig - 1 = 2 * 3 * Qbig := by decide

def bsrF : List Bool := [false, true, true, false, true, true, false, true, false, true, false, true, false, false, true, false, false, false, true, true, false, false, false, false, false, true, false, true, true, true, true, true, true, false, true, true, true, true, false, false, false, false, true, true, true, false, false, true, true, false, false, false, false, false, true, true, true, true, false, true, true, false, true, false, false, false, true, false, false, true, false, false, false, false, true, true, true]
theorem hbrF : bitsVal bsrF = 132896956044521568488118 := by decide
theorem vrF : expBits Rbig 6 bsrF = 1 := by decide
theorem rexpl : (6 ^ (Rbig - 1)) % Rbig = 1 :=
  eq_via_exp (m := Rbig) (a := 6) (E := Rbig - 1) (by decide) hbrF vrF
theorem rexplZ : (((6 : Nat) : ZMod Rbig) ^ (Rbig - 1)) = 1 :=
  zpow_one (by decide) rexpl

def bsr0 : List Bool := [true, true, false, true, true, false, true, false, true, false, true, false, false, true, false, false, false, true, true, false, false, false, false, false, true, false, true, true, true, true, true, true, false, true, true, true, true, false, false, false, false, true, true, true, false, false, true, true, false, false, false, false, false, true, true, true, true, false, true, true, false, true, false, false, false, true, false, false, true, false, false, false, false, true, true, true]
theorem hbr0 : bitsVal bsr0 = 66448478022260784244059 := by decide
theorem vr0 : expBits Rbig 6 bsr0 ≠ 1 := by decide
def bsr1 : List Bool := [false, true, false, false, true, false, false, true, true, true, false, false, false, false, true, true, false, true, true, true, false, true, false, true, false, false, false, true, false, true, false, true, false, false, true, false, true, false, false, false, false, false, true, false, true, true, false, false, true, true, false, true, false, true, true, true, true, true, false, false, true, true, true, false, true, false, false, false, false, true, true, false, true, false, false, true]
theorem hbr1 : bitsVal bsr1 = 44298985348173856162706 := by decide
theorem vr1 : expBits Rbig 6 bsr1 ≠ 1 := by decide
def bsr2 : List Bool := [false, true, true]
theorem hbr2 : bitsVal bsr2 = 6 := by decide
theorem vr2 : expBits Rbig 6 bsr2 ≠ 1 := by decide

theorem r_hd : ∀ q : Nat, Nat.Prime q → q ∣ Rbig - 1 →
    (((6 : Nat) : ZMod Rbig) ^ ((Rbig - 1) / q)) ≠ 1 := by
  intro q hq hdv
  rw [rsplit] at hdv
  rcases (Nat.Prime.dvd_mul hq).mp hdv with dl2 | dr2
  · rcases (Nat.Prime.dvd_mul hq).mp dl2 with dl4 | dr4
    · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2).mp dl4
      subst eqq
      exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbr0 vr0)
    · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr3).mp dr4
      subst eqq
      exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbr1 vr1)
  · have eqq := (Nat.prime_dvd_prime_iff_eq hq Qbig_prime).mp dr2
    subst eqq
    exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbr2 vr2)

/-- Rbig is prime (Pratt certificate level). -/
theorem Rbig_prime : Nat.Prime Rbig :=
  lucas_primality Rbig ((6 : Nat) : ZMod Rbig) rexplZ r_hd

/-! ## Level: Qtwo -/

def Qtwo : Nat := 255515944373312847190720520512484175977

theorem qtsplit : Qtwo - 1 = 2 * 2 * 2 * 7 * 7 * 11 * 1627 * 2657 * 4423 * 96557 * 41201 * 107590001 * 7240687 := by decide

def bsqtF : List Bool := [false, false, false, true, false, true, true, false, false, false, false, false, true, true, true, false, false, false, false, true, true, false, false, true, true, true, true, true, true, true, false, true, false, false, true, true, false, false, true, true, false, false, false, true, true, false, true, true, false, false, true, true, true, false, true, false, false, false, false, false, false, true, false, true, true, false, false, true, true, false, false, false, false, false, true, false, false, false, true, false, false, true, true, false, false, true, true, true, true, true, false, false, true, false, true, true, false, true, false, false, true, true, false, true, false, false, true, false, true, false, false, true, false, true, false, true, true, true, false, false, false, false, false, false, false, false, true, true]
theorem hbqtF : bitsVal bsqtF = 255515944373312847190720520512484175976 := by decide
theorem vqtF : expBits Qtwo 3 bsqtF = 1 := by decide
theorem qtexpl : (3 ^ (Qtwo - 1)) % Qtwo = 1 :=
  eq_via_exp (m := Qtwo) (a := 3) (E := Qtwo - 1) (by decide) hbqtF vqtF
theorem qtexplZ : (((3 : Nat) : ZMod Qtwo) ^ (Qtwo - 1)) = 1 :=
  zpow_one (by decide) qtexpl

def bsqt0 : List Bool := [false, false, true, false, true, true, false, false, false, false, false, true, true, true, false, false, false, false, true, true, false, false, true, true, true, true, true, true, true, false, true, false, false, true, true, false, false, true, true, false, false, false, true, true, false, true, true, false, false, true, true, true, false, true, false, false, false, false, false, false, true, false, true, true, false, false, true, true, false, false, false, false, false, true, false, false, false, true, false, false, true, true, false, false, true, true, true, true, true, false, false, true, false, true, true, false, true, false, false, true, true, false, true, false, false, true, false, true, false, false, true, false, true, false, true, true, true, false, false, false, false, false, false, false, false, true, true]
theorem hbqt0 : bitsVal bsqt0 = 127757972186656423595360260256242087988 := by decide
theorem vqt0 : expBits Qtwo 3 bsqt0 ≠ 1 := by decide
def bsqt1 : List Bool := [false, false, false, true, true, false, true, false, false, true, false, false, false, true, false, true, false, false, true, true, false, false, true, true, false, true, true, false, true, true, true, true, false, true, false, true, false, false, false, true, true, true, false, false, false, false, true, false, true, false, true, true, false, false, false, false, false, false, false, false, false, true, true, false, true, false, false, false, true, true, true, false, true, true, true, false, true, true, true, false, true, false, true, false, false, false, true, false, false, true, true, true, true, false, false, false, false, true, true, true, true, true, false, false, true, false, true, false, true, false, false, false, false, true, true, false, true, true, true, false, true, true, false, true, true]
theorem hbqt1 : bitsVal bsqt1 = 36502277767616121027245788644640596568 := by decide
theorem vqt1 : expBits Qtwo 3 bsqt1 ≠ 1 := by decide
def bsqt2 : List Bool := [false, false, false, true, true, true, false, false, false, true, false, true, false, false, false, false, false, false, false, true, false, false, true, true, true, false, true, false, false, false, false, true, true, false, true, false, true, true, false, true, true, true, false, false, true, false, false, false, false, false, true, false, true, false, false, true, false, true, true, true, false, false, false, false, true, true, false, true, false, true, true, true, false, true, true, true, false, true, true, true, false, false, true, false, true, false, false, false, true, false, false, true, true, false, true, false, true, false, true, true, false, true, true, false, false, false, false, false, true, true, false, true, true, false, false, true, true, true, true, false, true, false, false, false, true]
theorem hbqt2 : bitsVal bsqt2 = 23228722215755713380974592773862197816 := by decide
theorem vqt2 : expBits Qtwo 3 bsqt2 ≠ 1 := by decide
def bsqt3 : List Bool := [false, false, false, true, true, true, false, true, true, false, true, true, false, false, true, true, true, true, true, false, false, false, false, false, false, true, false, true, false, false, false, false, true, true, true, false, true, true, false, false, true, false, false, false, false, true, true, false, true, false, false, true, false, false, true, false, false, true, false, true, false, false, true, true, false, false, true, true, true, true, true, false, true, false, false, false, true, true, true, false, true, true, true, true, false, false, true, false, true, false, false, false, false, false, false, true, true, true, true, false, false, false, false, false, true, true, true, true, true, true, false, false, false, true, true, true, true]
theorem hbqt3 : bitsVal bsqt3 = 157047292177819820031174259688066488 := by decide
theorem vqt3 : expBits Qtwo 3 bsqt3 ≠ 1 := by decide
def bsqt4 : List Bool := [false, false, false, true, false, true, true, false, true, false, false, true, true, false, true, true, false, false, false, true, false, false, true, true, true, true, false, true, true, true, true, false, false, false, false, true, false, false, true, true, false, false, false, true, true, true, false, true, true, true, true, true, true, true, false, false, true, true, false, true, false, true, true, true, false, false, false, false, true, false, false, true, false, false, true, false, false, true, true, true, false, true, false, false, false, true, true, true, true, false, false, false, false, false, true, false, true, true, true, false, false, true, true, false, true, false, true, false, false, false, false, true, false, true, false, false, true]
theorem hbqt4 : bitsVal bsqt4 = 96167084822473785167753300907972968 := by decide
theorem vqt4 : expBits Qtwo 3 bsqt4 ≠ 1 := by decide
def bsqt5 : List Bool := [false, false, false, true, true, false, true, false, false, false, false, false, false, false, false, true, true, false, false, true, true, false, false, false, true, false, false, false, false, false, true, false, false, false, false, true, true, false, true, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false, false, true, false, false, false, true, false, false, false, true, true, false, true, false, false, false, false, true, true, true, true, false, true, true, false, false, true, false, false, false, false, true, false, false, false, true, false, true, true, true, false, true, true, false, true, false, false, false, true, false, false, false, false, false, false, true, false, false, true, true, false, true]
theorem hbqt5 : bitsVal bsqt5 = 57769826898782013834664372713652312 := by decide
theorem vqt5 : expBits Qtwo 3 bsqt5 ≠ 1 := by decide
def bsqt6 : List Bool := [false, false, false, true, false, true, true, true, false, true, true, false, true, true, true, true, true, true, true, true, false, false, true, false, false, true, false, true, true, false, false, false, false, true, false, false, false, true, true, false, false, false, true, true, false, true, true, true, true, false, false, false, true, false, true, true, true, true, true, false, true, false, false, false, false, false, false, false, false, true, false, false, true, true, true, false, false, false, false, true, true, true, false, false, false, true, false, false, false, true, true, true, true, false, true, false, false, false, true, false, false, false, true, true, true, false, false, false, true, true, false, false, true]
theorem hbqt6 : bitsVal bsqt6 = 6201692783507993669831327407404776 := by decide
theorem vqt6 : expBits Qtwo 3 bsqt6 ≠ 1 := by decide
def bsqt7 : List Bool := [false, false, false, true, false, false, false, false, true, true, false, false, false, true, false, true, true, false, false, true, true, false, false, false, false, true, false, false, false, true, false, false, true, true, false, true, false, true, false, false, false, false, true, true, true, true, true, true, true, false, false, true, false, false, true, false, true, true, false, true, true, true, true, false, false, false, true, false, false, false, true, true, false, false, false, true, false, true, true, true, false, false, true, false, false, false, true, false, true, false, false, false, false, true, false, true, false, false, false, true, true, true, true, false, false, true, false, false, false, false, false, true]
theorem hbqt7 : bitsVal bsqt7 = 2646270538369179315748423423599368 := by decide
theorem vqt7 : expBits Qtwo 3 bsqt7 ≠ 1 := by decide
def bsqt8 : List Bool := [false, false, false, true, true, false, false, false, false, true, true, true, false, false, true, false, false, true, true, false, false, true, false, false, false, true, false, true, true, true, false, true, true, true, true, false, true, false, true, false, false, false, true, true, true, false, true, true, true, false, false, false, true, true, true, true, false, false, true, false, false, true, true, true, true, false, false, true, true, false, false, false, true, false, true, false, true, false, true, false, true, false, true, true, true, false, false, true, false, false, false, true, false, true, true, false, true, false, true, true, true, true, false, true, true]
theorem hbqt8 : bitsVal bsqt8 = 35288908963101546467996824129048 := by decide
theorem vqt8 : expBits Qtwo 3 bsqt8 ≠ 1 := by decide
def bsqt9 : List Bool := [false, false, false, true, false, true, true, true, false, true, false, false, false, false, true, true, false, false, false, true, true, false, true, true, false, false, false, false, false, true, false, false, true, true, true, true, true, true, true, true, true, false, true, false, false, false, true, false, true, true, true, true, true, false, true, true, false, true, true, true, false, false, false, false, true, true, false, false, false, false, true, false, false, false, true, false, true, true, false, true, false, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, false, true, true, true]
theorem hbqt9 : bitsVal bsqt9 = 2374904191824599455024826335976 := by decide
theorem vqt9 : expBits Qtwo 3 bsqt9 ≠ 1 := by decide

theorem qt_hd : ∀ q : Nat, Nat.Prime q → q ∣ Qtwo - 1 →
    (((3 : Nat) : ZMod Qtwo) ^ ((Qtwo - 1) / q)) ≠ 1 := by
  intro q hq hdv
  rw [qtsplit] at hdv
  rcases (Nat.Prime.dvd_mul hq).mp hdv with dl2 | dr2
  · rcases (Nat.Prime.dvd_mul hq).mp dl2 with dl4 | dr4
    · rcases (Nat.Prime.dvd_mul hq).mp dl4 with dl6 | dr6
      · rcases (Nat.Prime.dvd_mul hq).mp dl6 with dl8 | dr8
        · rcases (Nat.Prime.dvd_mul hq).mp dl8 with dl10 | dr10
          · rcases (Nat.Prime.dvd_mul hq).mp dl10 with dl12 | dr12
            · rcases (Nat.Prime.dvd_mul hq).mp dl12 with dl14 | dr14
              · rcases (Nat.Prime.dvd_mul hq).mp dl14 with dl16 | dr16
                · rcases (Nat.Prime.dvd_mul hq).mp dl16 with dl18 | dr18
                  · rcases (Nat.Prime.dvd_mul hq).mp dl18 with dl20 | dr20
                    · rcases (Nat.Prime.dvd_mul hq).mp dl20 with dl22 | dr22
                      · rcases (Nat.Prime.dvd_mul hq).mp dl22 with dl24 | dr24
                        · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2).mp dl24
                          subst eqq
                          exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt0 vqt0)
                        · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2).mp dr24
                          subst eqq
                          exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt0 vqt0)
                      · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2).mp dr22
                        subst eqq
                        exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt0 vqt0)
                    · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr7).mp dr20
                      subst eqq
                      exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt1 vqt1)
                  · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr7).mp dr18
                    subst eqq
                    exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt1 vqt1)
                · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr11).mp dr16
                  subst eqq
                  exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt2 vqt2)
              · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr1627).mp dr14
                subst eqq
                exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt3 vqt3)
            · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2657).mp dr12
              subst eqq
              exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt4 vqt4)
          · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr4423).mp dr10
            subst eqq
            exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt5 vqt5)
        · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr96557).mp dr8
          subst eqq
          exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt7 vqt7)
      · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr41201).mp dr6
        subst eqq
        exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt6 vqt6)
    · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr107590001).mp dr4
      subst eqq
      exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt9 vqt9)
  · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr7240687).mp dr2
    subst eqq
    exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbqt8 vqt8)

/-- Qtwo is prime (Pratt certificate level). -/
theorem Qtwo_prime : Nat.Prime Qtwo :=
  lucas_primality Qtwo ((3 : Nat) : ZMod Qtwo) qtexplZ qt_hd

/-! ## Level: Cbig -/

def Cbig : Nat := 205115282021455665897114700593932402728804164701536103180137503955397371

theorem csplit : Cbig - 1 = 2 * 3 * 5 * 29 * 29 * 31 * 7723 * Rbig * Qtwo := by decide

def bscF : List Bool := [false, true, false, true, true, true, true, true, false, true, false, true, false, true, false, true, false, false, false, true, true, true, false, false, true, true, false, false, true, true, true, true, false, false, true, false, false, true, false, true, true, false, true, true, false, false, false, false, false, false, true, true, false, false, true, false, true, false, true, true, false, true, true, false, true, true, true, false, true, true, true, false, false, true, false, true, true, false, false, true, false, false, false, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, true, true, false, true, true, false, true, true, false, false, true, false, false, true, true, false, true, false, false, true, false, true, true, true, false, false, false, true, false, true, false, true, true, false, true, true, true, true, false, false, true, true, false, false, true, true, true, true, true, true, false, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, true, false, true, false, true, true, false, false, false, true, false, false, true, false, true, false, false, false, false, false, true, true, false, false, false, true, false, true, true, false, true, true, true, false, false, false, true, true, true, true, false, true, false, false, true, true, true, false, false, false, false, false, true, true, false, false, true, false, false, false, false, false, true, true, true, false, true, true, false, true, true, true]
theorem hbcF : bitsVal bscF = 205115282021455665897114700593932402728804164701536103180137503955397370 := by decide
theorem vcF : expBits Cbig 10 bscF = 1 := by decide
theorem cexpl : (10 ^ (Cbig - 1)) % Cbig = 1 :=
  eq_via_exp (m := Cbig) (a := 10) (E := Cbig - 1) (by decide) hbcF vcF
theorem cexplZ : (((10 : Nat) : ZMod Cbig) ^ (Cbig - 1)) = 1 :=
  zpow_one (by decide) cexpl

def bsc0 : List Bool := [true, false, true, true, true, true, true, false, true, false, true, false, true, false, true, false, false, false, true, true, true, false, false, true, true, false, false, true, true, true, true, false, false, true, false, false, true, false, true, true, false, true, true, false, false, false, false, false, false, true, true, false, false, true, false, true, false, true, true, false, true, true, false, true, true, true, false, true, true, true, false, false, true, false, true, true, false, false, true, false, false, false, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, true, true, false, true, true, false, true, true, false, false, true, false, false, true, true, false, true, false, false, true, false, true, true, true, false, false, false, true, false, true, false, true, true, false, true, true, true, true, false, false, true, true, false, false, true, true, true, true, true, true, false, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, true, false, true, false, true, true, false, false, false, true, false, false, true, false, true, false, false, false, false, false, true, true, false, false, false, true, false, true, true, false, true, true, true, false, false, false, true, true, true, true, false, true, false, false, true, true, true, false, false, false, false, false, true, true, false, false, true, false, false, false, false, false, true, true, true, false, true, true, false, true, true, true]
theorem hbc0 : bitsVal bsc0 = 102557641010727832948557350296966201364402082350768051590068751977698685 := by decide
theorem vc0 : expBits Cbig 10 bsc0 ≠ 1 := by decide
def bsc1 : List Bool := [false, true, true, true, true, true, true, true, false, false, false, true, true, true, false, false, false, false, false, true, false, true, true, false, false, true, true, false, false, true, false, true, true, false, false, false, false, true, true, true, true, false, false, true, true, false, true, false, true, false, false, true, true, false, false, false, true, true, true, true, false, false, true, true, true, true, true, false, false, true, false, false, false, true, true, true, true, false, true, true, false, true, false, false, true, true, true, true, true, false, false, false, true, false, true, true, true, false, false, true, true, true, true, false, false, true, true, false, false, false, false, true, false, false, true, true, false, false, false, true, false, true, true, false, true, true, false, false, false, true, false, false, true, false, true, false, false, false, true, false, false, false, true, false, true, false, true, false, false, false, false, true, true, false, true, true, false, true, false, true, false, true, false, true, false, false, false, true, true, true, true, false, true, false, false, false, false, true, true, true, false, true, false, true, false, false, true, true, false, true, true, false, false, true, true, true, true, true, false, true, false, false, true, false, true, true, true, false, true, true, true, true, false, true, false, true, false, false, true, true, false, false, false, false, false, false, false, true, false, true, true, true, true, false, false, true]
theorem hbc1 : bitsVal bsc1 = 68371760673818555299038233531310800909601388233845367726712501318465790 := by decide
theorem vc1 : expBits Cbig 10 bsc1 ≠ 1 := by decide
def bsc2 : List Bool := [false, true, false, false, true, true, false, false, false, true, false, false, false, true, false, false, false, false, false, true, true, false, true, true, true, true, false, false, false, true, true, false, true, true, true, false, false, false, false, true, true, true, true, true, false, false, true, true, false, false, false, true, false, true, false, true, false, true, false, false, false, true, true, true, true, true, true, false, true, false, false, false, false, true, false, false, true, false, true, false, true, true, false, true, false, true, false, false, true, false, false, false, true, true, false, true, false, true, false, false, false, true, true, true, true, true, false, false, false, false, false, true, true, true, true, false, false, false, false, true, true, false, true, true, false, true, true, true, false, true, false, true, false, false, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, false, true, false, true, true, false, true, true, false, false, true, true, false, false, true, true, true, false, true, true, true, true, false, false, true, false, true, true, true, false, true, true, false, false, true, true, true, true, false, false, true, false, true, false, false, false, true, true, false, true, true, false, true, false, false, true, false, false, false, false, true, true, false, true, true, false, false, true, false, false, false, false, true, false, true, true, false, false, false, true, true, true, true, true, false, true]
theorem hbc2 : bitsVal bsc2 = 41023056404291133179422940118786480545760832940307220636027500791079474 := by decide
theorem vc2 : expBits Cbig 10 bsc2 ≠ 1 := by decide
def bsc3 : List Bool := [false, true, false, false, false, false, true, true, true, false, false, true, true, false, true, true, false, false, false, false, false, true, false, true, true, false, true, false, true, false, false, true, false, false, true, false, false, true, false, true, true, true, true, false, true, true, true, true, false, false, false, false, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, false, true, true, false, true, false, true, false, true, true, true, false, true, true, false, true, false, true, false, false, false, true, true, true, false, true, false, true, true, true, true, true, true, true, false, true, false, false, true, false, false, false, true, false, true, true, true, false, false, false, false, false, true, false, true, false, false, false, true, true, true, false, false, true, false, true, true, true, false, false, true, true, true, true, false, false, true, false, true, false, true, true, true, false, true, true, false, false, false, true, false, false, false, false, true, true, true, true, false, true, false, true, true, false, false, true, true, true, true, true, true, false, false, true, false, true, false, false, false, false, true, false, true, true, false, true, true, true, true, true, false, false, false, false, false, true, false, false, true, false, true, true, false, true, false, false, true, true, false, false, true, true, false, true, false, false, true, true, false, false, false, false, false, true]
theorem hbc3 : bitsVal bsc3 = 7072940759360540203348782779101117335476005679363313902763362205358530 := by decide
theorem vc3 : expBits Cbig 10 bsc3 ≠ 1 := by decide
def bsc4 : List Bool := [false, true, true, false, false, false, true, true, true, false, true, true, false, false, false, false, true, false, false, true, false, true, true, true, true, false, false, true, false, false, true, false, false, false, true, false, false, true, true, true, false, true, true, true, false, false, true, true, true, false, true, true, false, true, true, false, false, false, false, false, false, true, false, true, false, false, true, true, true, false, false, false, true, false, false, true, false, false, false, true, false, false, false, true, true, true, false, false, true, false, false, false, true, true, false, true, false, false, false, true, false, true, false, true, true, false, false, false, false, true, false, true, false, true, true, true, false, true, false, false, false, true, false, false, false, true, false, true, true, false, true, true, true, true, false, true, false, true, false, true, false, false, false, true, true, false, false, false, false, true, false, true, true, true, false, true, false, true, true, false, true, false, true, true, false, false, false, false, true, true, false, true, true, false, false, false, true, false, false, true, true, false, false, false, true, false, true, true, true, false, true, false, false, false, false, false, true, false, true, true, true, true, false, true, true, false, false, false, true, false, true, false, true, false, false, true, false, false, true, true, false, true, true, false, true, false, true, false, true, true, true, true]
theorem hbc4 : bitsVal bsc4 = 6616622000692118254745635503030077507380779506501164618714113030819270 := by decide
theorem vc4 : expBits Cbig 10 bsc4 ≠ 1 := by decide
def bsc5 : List Bool := [false, true, true, true, false, true, true, true, true, false, true, true, true, false, true, false, true, false, true, false, true, true, true, true, true, true, false, true, true, false, false, true, false, false, true, true, false, false, true, true, true, true, false, false, true, false, true, false, false, false, true, false, false, false, true, false, false, false, false, false, false, true, false, false, false, true, true, true, true, true, true, true, false, false, false, true, true, true, true, true, true, true, false, false, false, false, false, false, false, true, false, true, true, true, true, true, true, false, true, false, false, true, true, false, true, false, true, true, false, true, false, false, false, false, true, false, false, true, true, true, false, false, false, false, false, false, true, false, true, true, false, false, true, true, true, false, false, false, false, true, false, true, false, true, false, true, false, false, false, true, false, false, true, false, false, true, true, false, true, false, true, false, true, true, true, false, true, true, true, true, false, false, true, false, false, false, true, false, false, true, true, false, false, true, false, false, true, false, true, true, false, true, true, false, false, true, true, false, true, false, false, false, true, false, false, true, true, false, true, false, false, false, true, true, false, false, false, false, true, true, true, true, true, true]
theorem hbc5 : bitsVal bsc5 = 26559016188198325248881872406310035313842310591937861346644762910190 := by decide
theorem vc5 : expBits Cbig 10 bsc5 ≠ 1 := by decide
def bsc6 : List Bool := [false, true, true, false, true, false, true, true, false, true, false, true, true, true, true, false, true, false, false, false, false, true, true, false, false, true, true, true, false, false, true, false, false, false, false, false, false, false, true, true, false, true, true, true, false, true, false, true, false, true, true, true, true, true, false, false, true, false, true, false, true, true, false, true, false, false, true, true, true, true, true, true, false, false, true, true, true, true, false, false, true, false, true, true, false, false, false, true, false, false, true, false, true, true, true, true, true, true, true, true, false, false, false, true, true, true, false, true, false, false, true, true, false, true, true, false, true, false, true, true, false, true, false, true, true, false, true, false, true, false, false, true, true, true, false, false, false, true, false, true, false, true, false, false, true, false, false, true, true, false, true, false, false, true, true, true, false, false, false, false, true]
theorem hbc6 : bitsVal bsc6 = 1543415952677955745309227852991199086604869270230 := by decide
theorem vc6 : expBits Cbig 10 bsc6 ≠ 1 := by decide
def bsc7 : List Bool := [false, true, false, true, false, true, true, true, true, true, false, false, true, true, false, false, true, false, true, false, true, true, true, true, true, true, true, false, false, false, false, false, false, false, true, true, true, true, true, true, true, false, false, false, false, false, false, true, true, false, false, false, true, true, true, false, true, true, false, false, false, false, false, false, false, false, true, true, true, true, false, false, true, true, false, true, true, true, true, true, true, true, true, false, true, false, true, false, true, true, true, true, true, false, false, false, false, false, true, false, true, false, false, true, true, true, true, false, false, true]
theorem hbc7 : bitsVal bsc7 = 802749442992798076634733441528810 := by decide
theorem vc7 : expBits Cbig 10 bsc7 ≠ 1 := by decide

theorem c_hd : ∀ q : Nat, Nat.Prime q → q ∣ Cbig - 1 →
    (((10 : Nat) : ZMod Cbig) ^ ((Cbig - 1) / q)) ≠ 1 := by
  intro q hq hdv
  rw [csplit] at hdv
  rcases (Nat.Prime.dvd_mul hq).mp hdv with dl2 | dr2
  · rcases (Nat.Prime.dvd_mul hq).mp dl2 with dl4 | dr4
    · rcases (Nat.Prime.dvd_mul hq).mp dl4 with dl6 | dr6
      · rcases (Nat.Prime.dvd_mul hq).mp dl6 with dl8 | dr8
        · rcases (Nat.Prime.dvd_mul hq).mp dl8 with dl10 | dr10
          · rcases (Nat.Prime.dvd_mul hq).mp dl10 with dl12 | dr12
            · rcases (Nat.Prime.dvd_mul hq).mp dl12 with dl14 | dr14
              · rcases (Nat.Prime.dvd_mul hq).mp dl14 with dl16 | dr16
                · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2).mp dl16
                  subst eqq
                  exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbc0 vc0)
                · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr3).mp dr16
                  subst eqq
                  exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbc1 vc1)
              · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr5).mp dr14
                subst eqq
                exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbc2 vc2)
            · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr29).mp dr12
              subst eqq
              exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbc3 vc3)
          · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr29).mp dr10
            subst eqq
            exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbc3 vc3)
        · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr31).mp dr8
          subst eqq
          exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbc4 vc4)
      · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr7723).mp dr6
        subst eqq
        exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbc5 vc5)
    · have eqq := (Nat.prime_dvd_prime_iff_eq hq Rbig_prime).mp dr4
      subst eqq
      exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbc6 vc6)
  · have eqq := (Nat.prime_dvd_prime_iff_eq hq Qtwo_prime).mp dr2
    subst eqq
    exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbc7 vc7)

/-- Cbig is prime (Pratt certificate level). -/
theorem Cbig_prime : Nat.Prime Cbig :=
  lucas_primality Cbig ((10 : Nat) : ZMod Cbig) cexplZ c_hd

/-! ## Level: P -/

theorem psplit : P - 1 = 2 * 3 * 7 * 13441 * Cbig := by decide

def bspF : List Bool := [false, true, true, true, false, true, false, false, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true]
theorem hbpF : bitsVal bspF = 115792089237316195423570985008687907853269984665640564039457584007908834671662 := by decide
theorem vpF : expBits P 3 bspF = 1 := by decide
theorem pexpl : (3 ^ (P - 1)) % P = 1 :=
  eq_via_exp (m := P) (a := 3) (E := P - 1) (by decide) hbpF vpF
theorem pexplZ : (((3 : Nat) : ZMod P) ^ (P - 1)) = 1 :=
  zpow_one (by decide) pexpl

def bsp0 : List Bool := [true, true, true, false, true, false, false, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true]
theorem hbp0 : bitsVal bsp0 = 57896044618658097711785492504343953926634992332820282019728792003954417335831 := by decide
theorem vp0 : expBits P 3 bsp0 ≠ 1 := by decide
def bsp1 : List Bool := [false, true, false, true, true, true, false, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false, true]
theorem hbp1 : bitsVal bsp1 = 38597363079105398474523661669562635951089994888546854679819194669302944890554 := by decide
theorem vp1 : expBits P 3 bsp1 ≠ 1 := by decide
def bsp2 : List Bool := [false, true, false, false, false, true, true, true, false, true, false, true, true, false, true, true, false, true, true, false, true, true, false, true, true, false, true, true, false, true, true, false, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true]
theorem hbp2 : bitsVal bsp2 = 16541727033902313631938712144098272550467140666520080577065369143986976381666 := by decide
theorem vp2 : expBits P 3 bsp2 ≠ 1 := by decide
def bsp3 : List Bool := [false, true, true, true, false, true, false, false, true, false, true, true, false, false, false, false, false, false, true, true, false, false, true, false, true, true, true, false, false, true, true, true, true, true, true, true, false, false, false, false, true, false, true, true, true, true, false, false, false, true, false, true, true, true, true, false, false, true, true, true, false, true, true, true, true, true, true, false, true, false, false, true, true, true, true, false, true, false, true, false, true, false, false, true, false, false, false, true, true, false, true, false, true, false, true, false, true, false, true, false, true, true, true, true, true, true, true, true, false, true, false, false, false, true, false, true, false, true, false, false, true, false, false, true, true, false, true, true, false, true, true, false, true, true, true, false, false, false, false, false, false, true, false, true, true, true, true, false, true, false, false, true, true, true, true, false, false, true, true, false, true, false, false, false, false, false, true, false, false, true, true, false, true, false, false, true, true, true, true, true, false, true, false, true, true, false, true, true, true, true, true, false, true, false, false, true, true, true, false, true, true, false, true, false, true, true, true, false, true, true, false, true, true, false, true, false, false, true, true, true, true, true, false, false, false, true, true, false, true, true, false, false, false, false, false, false, false, true, true, true, false, false, true]
theorem hbp3 : bitsVal bsp3 = 8614841844901137967678817424945160914609774917464516333565775166126689582 := by decide
theorem vp3 : expBits P 3 bsp3 ≠ 1 := by decide
def bsp4 : List Bool := [false, true, false, true, false, true, false, false, true, false, true, true, true, false, false, true, false, false, false, true]
theorem hbp4 : bitsVal bsp4 = 564522 := by decide
theorem vp4 : expBits P 3 bsp4 ≠ 1 := by decide

theorem p_hd : ∀ q : Nat, Nat.Prime q → q ∣ P - 1 →
    (((3 : Nat) : ZMod P) ^ ((P - 1) / q)) ≠ 1 := by
  intro q hq hdv
  rw [psplit] at hdv
  rcases (Nat.Prime.dvd_mul hq).mp hdv with dl2 | dr2
  · rcases (Nat.Prime.dvd_mul hq).mp dl2 with dl4 | dr4
    · rcases (Nat.Prime.dvd_mul hq).mp dl4 with dl6 | dr6
      · rcases (Nat.Prime.dvd_mul hq).mp dl6 with dl8 | dr8
        · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr2).mp dl8
          subst eqq
          exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbp0 vp0)
        · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr3).mp dr8
          subst eqq
          exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbp1 vp1)
      · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr7).mp dr6
        subst eqq
        exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbp2 vp2)
    · have eqq := (Nat.prime_dvd_prime_iff_eq hq pr13441).mp dr4
      subst eqq
      exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbp3 vp3)
  · have eqq := (Nat.prime_dvd_prime_iff_eq hq Cbig_prime).mp dr2
    subst eqq
    exact zpow_ne_one (by decide) (ne_via_exp (by decide) hbp4 vp4)

/-- P is prime (Pratt certificate level).
SGN-104: P primality via 6-level Pratt certificate (mathlib lucas_primality, proofs package only). -/
@[rule "SGN-104"]
theorem P_prime : Nat.Prime P :=
  lucas_primality P ((3 : Nat) : ZMod P) pexplZ p_hd

/-! ## The exported instance -/

/-- **The secp256k1 field prime is prime** — complete Pratt certificate
(levels Sbig → Qbig → Rbig → Qtwo → Cbig → P), sorry-free, kernel-decided
only through the STRUCTURAL `Mod.expBits` square-and-multiply over literal
bit lists (§5 lesson respected). -/
instance secp_P_prime : Fact (Nat.Prime P) := ⟨P_prime⟩

end BitcoinProofs.Crypto.CurveZMod
