import Bitcoin.Data.Basic
import Bitcoin.RuleAttr

/-!
# Bitcoin.Crypto.Curve.Mod — generic modular arithmetic over `Nat`

Zero-dependency port (W14b) of the W14 field layer
(`research/poc/w2-14-field/Field.lean`), **generalized over the modulus**:
the curve layer needs arithmetic mod `p = 2²⁵⁶ − 2³² − 977` (field
coordinates) AND mod `n = 0xFFFF…D0364141` (the group order, for ECDSA
scalars). Every operation takes the modulus explicitly and re-establishes
the invariant `x < m` ("canonical representative").

Representation decision (W14, benchmarked): plain `Nat`; Lean's runtime
backs `Nat` mul/div/mod with GMP ⇒ `mulM` at 275–281 ns/op on 256-bit
operands (1.4× CPython), vs `BitVec 256` at 421–431 ns and hand-rolled
limbs at ~9.2 µs. See w2-14-secp256k1-field.md §2.1.

Kernel note (W14 finding F-W14-1, applies here verbatim):
`expM`/`egcd` are well-founded-recursive (`termination_by`), so
`decide`/`rfl` cannot reduce through them. All *runnable* conformance
checking happens in compiled test drivers (fine — WF code executes at
runtime); theorem statements avoid kernel-deciding through these defs.
`expBits` below is a structurally-recursive variant (exponent as a bit
list) that IS kernel-reducible, for curated `decide` checks.
-/

namespace Bitcoin.Crypto.Curve.Mod

/-! ## Core operations (modulus explicit, invariant `x < m` established by each op) -/

def addM (m x y : Nat) : Nat := (x + y) % m

def subM (m x y : Nat) : Nat := (x + m - y) % m

def mulM (m x y : Nat) : Nat := (x * y) % m

/-! ## Congruence toolkit (core `Nat` lemmas; `omega` cannot see variable moduli) -/

theorem add_mod_congr_left (a b n : Nat) : (a % n + b) % n = (a + b) % n := by
  rw [Nat.add_mod (a % n) b n, Nat.mod_mod a n, Nat.add_mod a b n]

theorem add_mod_congr_right (a b n : Nat) : (a + b % n) % n = (a + b) % n := by
  rw [Nat.add_mod a (b % n) n, Nat.mod_mod b n, Nat.add_mod a b n]

theorem mul_mod_congr_left (a b n : Nat) : (a % n * b) % n = (a * b) % n := by
  rw [Nat.mul_mod (a % n) b n, Nat.mod_mod a n, Nat.mul_mod a b n]

theorem mul_mod_congr_right (a b n : Nat) : (a * (b % n)) % n = (a * b) % n := by
  rw [Nat.mul_mod a (b % n) n, Nat.mod_mod b n, Nat.mul_mod a b n]

/-! ## Closure (the `x < m` invariant) -/

theorem addM_lt (m x y : Nat) (hm : 0 < m) : addM m x y < m := Nat.mod_lt _ hm

theorem subM_lt (m x y : Nat) (hm : 0 < m) : subM m x y < m := Nat.mod_lt _ hm

theorem mulM_lt (m x y : Nat) (hm : 0 < m) : mulM m x y < m := Nat.mod_lt _ hm

/-! ## Field laws (cheap tier: sorry-free, core lemmas + congruence toolkit) -/

theorem addM_comm (m x y : Nat) : addM m x y = addM m y x := by
  simp only [addM, Nat.add_comm]

theorem addM_assoc (m x y z : Nat) : addM m (addM m x y) z = addM m x (addM m y z) := by
  simp only [addM, add_mod_congr_left, add_mod_congr_right, Nat.add_assoc]

theorem mulM_comm (m x y : Nat) : mulM m x y = mulM m y x := by
  simp only [mulM, Nat.mul_comm]

theorem mulM_assoc (m x y z : Nat) : mulM m (mulM m x y) z = mulM m x (mulM m y z) := by
  simp only [mulM, mul_mod_congr_left, mul_mod_congr_right, Nat.mul_assoc]

theorem mulM_left_distrib (m x y z : Nat) :
    mulM m x (addM m y z) = addM m (mulM m x y) (mulM m x z) := by
  simp only [mulM, addM, mul_mod_congr_right, Nat.left_distrib, ← Nat.add_mod]

theorem mulM_right_distrib (m x y z : Nat) :
    mulM m (addM m x y) z = addM m (mulM m x z) (mulM m y z) := by
  rw [mulM_comm, mulM_left_distrib]
  simp only [mulM_comm]

theorem addM_zero (m x : Nat) (hm : x < m) : addM m 0 x = x := by
  simp only [addM, Nat.zero_add, Nat.mod_eq_of_lt hm]

theorem mulM_zero (m x : Nat) : mulM m 0 x = 0 := by
  simp only [mulM, Nat.zero_mul, Nat.zero_mod]

theorem mulM_one (m x : Nat) (hm : x < m) : mulM m 1 x = x := by
  simp only [mulM, Nat.one_mul, Nat.mod_eq_of_lt hm]

theorem subM_self (m x : Nat) : subM m x x = 0 := by
  simp only [subM, Nat.add_sub_cancel_left, Nat.mod_self]

/-- Additive inverse: `subM m 0 y` acts as −y, and adds with `y` to 0. -/
theorem addM_subM_zero (m y : Nat) (_hm : 0 < m) (hy : y < m) :
    addM m (subM m 0 y) y = 0 := by
  rcases Nat.eq_zero_or_pos y with h | h
  · subst h; simp [addM, subM]
  · simp only [addM, subM, Nat.zero_add]
    rw [show (m - y) % m = m - y from Nat.mod_eq_of_lt (by omega),
        show m - y + y = m from by omega, Nat.mod_self]

/-! ## Modular exponentiation (square-and-multiply over `mulM`) -/

def expM (m x e : Nat) : Nat :=
  match e with
  | 0 => 1
  | e' + 1 =>
    if e' % 2 == 1 then
      -- e' + 1 is even: x^(e'+1) = (x^((e'+1)/2))^2
      let r := expM m x ((e' + 1) / 2)
      mulM m r r
    else
      -- e' + 1 is odd: x^(e'+1) = x · x^e'
      mulM m x (expM m x e')
termination_by e
decreasing_by
  · omega
  · omega

/-- Closure of `expM` under the modulus (needs `2 ≤ m` since `expM _ _ 0 = 1`). -/
theorem expM_lt (m x e : Nat) (hm : 1 < m) : expM m x e < m := by
  induction e using Nat.strongRecOn with
  | ind e IH =>
    cases e with
    | zero => simp only [expM]; exact hm
    | succ e' =>
      by_cases hodd : e' % 2 == 1
      · simp only [expM, hodd]
        have hlt : (e' + 1) / 2 < e' + 1 := Nat.div_lt_self (by omega) (by omega)
        have := IH ((e' + 1) / 2) hlt
        exact mulM_lt m _ _ (by omega)
      · simp only [expM, hodd]
        have := IH e' (by omega)
        exact mulM_lt m _ _ (by omega)

/-! ## Structurally-recursive exponentiation (kernel-reducible variant)

`expBits m x bs` computes `x^E % m` where `E` is the binary number whose
bits, least-significant first, are `bs`. Because the recursion is on the
structure of `bs` (not on a well-founded measure), `decide`/`rfl` reduce
through it — the W14 F-W14-1 workaround, in reusable form. -/

/-- Multiplication congruence: equal residues multiply to equal residues. -/
theorem mulM_congr {m a b c d : Nat} (h1 : a % m = c % m) (h2 : b % m = d % m) :
    mulM m a b = mulM m c d := by
  show (a * b) % m = (c * d) % m
  have e1 : (a * b) % m = ((a % m) * (b % m)) % m := by
    rw [← mul_mod_congr_left a b m, ← mul_mod_congr_right (a % m) b m]
  have e2 : ((c % m) * (d % m)) % m = (c * d) % m := by
    rw [mul_mod_congr_left c (d % m) m, mul_mod_congr_right c d m]
  rw [e1, h1, h2, e2]

/-- Square-and-multiply over an explicit little-endian bit list:
`expBits m x bs = x ^ (bitsVal bs) % m` (proved below). -/
def expBits (m x : Nat) : List Bool → Nat
  | [] => 1
  | b :: bs =>
    mulM m (mulM m (expBits m x bs) (expBits m x bs)) (if b then x else 1)

/-- The numeric value of a little-endian bit list. -/
def bitsVal : List Bool → Nat
  | [] => 0
  | b :: bs => (if b then 1 else 0) + 2 * bitsVal bs

/-- Bit list of `e`, least-significant first, computed with an explicit fuel.
Runtime helper only (structural recursion); its correctness theorem is left
to Review 3 (the kernel-reducible path that matters is `expBits_eq_pow_mod`
with caller-supplied bits). -/
def natBitsF : Nat → Nat → List Bool
  | 0, _ => []
  | _ + 1, 0 => []
  | k + 1, n + 1 => (n % 2 == 0) :: natBitsF k ((n + 1) / 2)

/-- Spec: `expBits` computes `x^(bitsVal bs) % m`.
SGN-103: kernel-reducible square-and-multiply (structural over bit lists). -/
@[rule "SGN-103"]
theorem expBits_eq_pow_mod (m x : Nat) (hm : 1 < m) : ∀ (bs : List Bool),
    expBits m x bs = (x ^ bitsVal bs) % m := by
  intro bs
  induction bs with
  | nil =>
    show 1 = _
    rw [show bitsVal ([] : List Bool) = 0 from rfl, Nat.pow_zero, Nat.mod_eq_of_lt hm]
  | cons b bs' ih =>
    have he : expBits m x (b :: bs')
        = mulM m (mulM m (expBits m x bs') (expBits m x bs')) (if b then x else 1) := rfl
    have hsplit : bitsVal (b :: bs') = (if b then 1 else 0) + 2 * bitsVal bs' := rfl
    calc expBits m x (b :: bs')
        = mulM m (mulM m (expBits m x bs') (expBits m x bs')) (if b then x else 1) := he
      _ = mulM m ((x ^ bitsVal bs' * x ^ bitsVal bs') % m) (if b then x else 1) := by
            rw [ih, mulM_congr (m := m) (a := x ^ bitsVal bs' % m)
              (b := x ^ bitsVal bs' % m) (c := x ^ bitsVal bs')
              (d := x ^ bitsVal bs') (Nat.mod_mod _ _) (Nat.mod_mod _ _)]
            rfl
      _ = (((x ^ bitsVal bs' * x ^ bitsVal bs') % m) * (if b then x else 1)) % m := rfl
      _ = ((x ^ bitsVal bs' * x ^ bitsVal bs') * (if b then x else 1)) % m :=
            mul_mod_congr_left _ _ _
      _ = (x ^ ((if b then 1 else 0) + 2 * bitsVal bs')) % m := by
            rw [Nat.pow_add]
            cases b <;>
              simp [Nat.pow_add, Nat.two_mul, Nat.mul_comm, Nat.one_mul,
                Nat.pow_one, Nat.pow_zero]
      _ = (x ^ bitsVal (b :: bs')) % m := by rw [hsplit]

/-! ## Extended Euclid over ℤ, and the modular inverse -/

/-- `egcd a b = (g, u, v)` with `(a:ℤ)*u + (b:ℤ)*v = g`; `g = gcd a b` when `0 < a`.
The certificate `u` is what the modular inverse needs. (Verbatim W14 machinery.) -/
def egcd (a b : Nat) : Int × Int × Int :=
  match b with
  | 0 => ((a : Int), 1, 0)
  | b' + 1 =>
    let (g, x, y) := egcd (b' + 1) (a % (b' + 1))
    (g, y, x - (a / (b' + 1)) * y)
termination_by b
decreasing_by exact Nat.mod_lt _ (by omega)

/-- Bezout certificate: the arithmetic step of Euclid's recurrence. -/
private theorem euclid_step (A B Q R X Y G : Int) (hqr : A = B * Q + R)
    (hIH : B * X + R * Y = G) : A * Y + B * (X - Q * Y) = G := by
  rw [hqr, Int.add_mul, Int.mul_sub, ← Int.mul_assoc]
  obtain ⟨T, hT⟩ : ∃ T : Int, (B * Q) * Y = T := ⟨_, rfl⟩
  obtain ⟨F, hF⟩ : ∃ F : Int, B * X = F := ⟨_, rfl⟩
  rw [hF] at hIH
  rw [hT, hF]
  omega

theorem egcd_bezout : ∀ (b a : Nat) (g u v : Int), egcd a b = (g, u, v) →
    (a : Int) * u + (b : Int) * v = g := by
  intro b
  induction b using Nat.strongRecOn with
  | ind b IH =>
    intro a g u v heq
    cases b with
    | zero =>
      simp only [egcd] at heq
      obtain ⟨rfl, rfl, rfl⟩ := heq
      simp
    | succ b' =>
      have hrecE : ∃ g' x' y' : Int, egcd (b' + 1) (a % (b' + 1)) = (g', x', y') :=
        ⟨_, _, _, rfl⟩
      obtain ⟨g', x', y', hrec⟩ := hrecE
      simp only [egcd] at heq
      rw [hrec] at heq
      dsimp only at heq
      have hlt : a % (b' + 1) < b' + 1 := Nat.mod_lt _ (by omega)
      have ih := IH (a % (b' + 1)) hlt (b' + 1) g' x' y' hrec
      obtain ⟨_, _, _⟩ := heq
      have hqr : (a : Int) = (b' + 1 : Int) * (a / (b' + 1) : Int) + (a % (b' + 1) : Int) := by
        have h := Nat.div_add_mod a (b' + 1)
        simpa using (congrArg (fun n : Nat => (n : Int)) h).symm
      exact euclid_step (a : Int) (b' + 1 : Int) _ _ x' u g hqr ih

theorem egcd_pos_dvd : ∀ (b a : Nat) (g u v : Int), egcd a b = (g, u, v) → 0 < a →
    0 < g ∧ g ∣ (a : Int) ∧ g ∣ (b : Int) := by
  intro b
  induction b using Nat.strongRecOn with
  | ind b IH =>
    intro a g u v heq ha
    cases b with
    | zero =>
      simp only [egcd] at heq
      obtain ⟨rfl, rfl, rfl⟩ := heq
      exact ⟨by omega, Int.dvd_refl _, Int.dvd_zero _⟩
    | succ b' =>
      have hrecE : ∃ g' x' y' : Int, egcd (b' + 1) (a % (b' + 1)) = (g', x', y') :=
        ⟨_, _, _, rfl⟩
      obtain ⟨g', x', y', hrec⟩ := hrecE
      simp only [egcd] at heq
      rw [hrec] at heq
      dsimp only at heq
      have hlt : a % (b' + 1) < b' + 1 := Nat.mod_lt _ (by omega)
      obtain ⟨hg, hd1, hd2⟩ := IH (a % (b' + 1)) hlt (b' + 1) g' x' y' hrec (by omega)
      obtain ⟨_, _, _⟩ := heq
      refine ⟨hg, ?_, hd1⟩
      obtain ⟨k, hk⟩ := hd1
      obtain ⟨m, hm⟩ := hd2
      have hqr : (↑a : Int) = (↑(b' + 1)) * (↑(a / (b' + 1))) + (↑(a % (b' + 1))) :=
        (congrArg (fun n : Nat => (n : Int)) (Nat.div_add_mod a (b' + 1))).symm
      have h1 : (↑(b' + 1)) * (↑(a / (b' + 1))) = g * (k * (↑(a / (b' + 1)))) := by
        rw [hk, Int.mul_assoc]
      have h2 : (↑a : Int) = g * (k * (↑(a / (b' + 1))) + m) := by
        rw [hqr, h1, hm, Int.mul_add]
      exact ⟨k * (↑(a / (b' + 1))) + m, h2⟩

/-- `a ∣ b → a ∣ b * c` over `Int`. -/
private theorem dvd_mul_of_dvd_left' {a b c : Int} (h : a ∣ b) : a ∣ b * c := by
  obtain ⟨k, hk⟩ := h
  exact ⟨k * c, by rw [hk, Int.mul_assoc]⟩

/-- `Nat` divisibility lifts to the `Int` cast. -/
private theorem natDvd_cast_dvd {d N : Nat} (h : d ∣ N) : (d : Int) ∣ (N : Int) := by
  obtain ⟨k, hk⟩ := h
  exact ⟨k, by rw [hk]; rfl⟩

/-- A nonnegative `Int` divisor of the cast of a positive `Nat` descends to
`Nat` divisibility. -/
private theorem intDvd_cast_natDvd {g : Int} {N : Nat} (hg : 0 ≤ g) (hN : 0 < N)
    (h : g ∣ (N : Int)) : g.toNat ∣ N := by
  obtain ⟨k, hk⟩ := h
  have hkpos : 0 < k := by
    rcases Int.lt_trichotomy k 1 with hk0 | hk0 | hk0
    · have hkle : k ≤ 0 := by omega
      have h1 : 0 ≤ -k := by omega
      have h2 : 0 ≤ g * -k := Int.mul_nonneg hg h1
      have h3 : g * k = -(g * -k) := by rw [Int.mul_neg, Int.neg_neg]
      have h4 : (N : Int) ≤ 0 := by rw [hk, h3]; omega
      omega
    · omega
    · omega
  have hg' : g = (g.toNat : Int) := (Int.toNat_of_nonneg hg).symm
  have hk' : k = (k.toNat : Int) := (Int.toNat_of_nonneg (by omega : (0 : Int) ≤ k)).symm
  refine ⟨k.toNat, ?_⟩
  rw [hg', hk'] at hk
  rw [← Int.natCast_mul] at hk
  exact Int.ofNat_inj.mp hk

theorem egcd_gcd_toNat (a b : Nat) (ha : 0 < a) (g u v : Int) (heq : egcd a b = (g, u, v)) :
    0 < g ∧ g.toNat = Nat.gcd a b := by
  obtain ⟨hg, hda, hdb⟩ := egcd_pos_dvd b a g u v heq ha
  refine ⟨hg, ?_⟩
  have hgcdpos : 0 < Nat.gcd a b := Nat.gcd_pos_of_pos_left b ha
  have hga : g.toNat ∣ a := intDvd_cast_natDvd (by omega : (0 : Int) ≤ g) ha hda
  have hgb : g.toNat ∣ b := by
    cases b with
    | zero => exact Nat.dvd_zero _
    | succ b'' => exact intDvd_cast_natDvd (by omega : (0 : Int) ≤ g) (by omega) hdb
  have hd1 : g.toNat ∣ Nat.gcd a b := Nat.dvd_gcd hga hgb
  have hle1 : g.toNat ≤ Nat.gcd a b := Nat.le_of_dvd hgcdpos hd1
  have h1 : (Nat.gcd a b : Int) ∣ (a : Int) := natDvd_cast_dvd (Nat.gcd_dvd_left a b)
  have h2 : (Nat.gcd a b : Int) ∣ (b : Int) := natDvd_cast_dvd (Nat.gcd_dvd_right a b)
  have hbez := egcd_bezout b a g u v heq
  have h3 : (Nat.gcd a b : Int) ∣ (a : Int) * u := dvd_mul_of_dvd_left' h1
  have h4 : (Nat.gcd a b : Int) ∣ (b : Int) * v := dvd_mul_of_dvd_left' h2
  have h5 : (Nat.gcd a b : Int) ∣ g := by
    have h := Int.dvd_add h3 h4
    rw [hbez] at h
    exact h
  have hgtoNat : 0 < g.toNat := by
    have := Int.toNat_of_nonneg (by omega : (0 : Int) ≤ g)
    omega
  have hgd : Nat.gcd a b ∣ g.toNat := by
    refine intDvd_cast_natDvd (Int.natCast_nonneg _) hgtoNat ?_
    rw [← Int.toNat_of_nonneg (by omega : (0 : Int) ≤ g)] at h5
    exact h5
  have hle2 : Nat.gcd a b ≤ g.toNat := Nat.le_of_dvd hgtoNat hgd
  exact Nat.le_antisymm hle1 hle2

/-! ### The modular inverse (extended Euclid) -/

/-- Modular inverse of `x` mod `m` via extended Euclid on `(m, x)`: the returned
triple satisfies `m·u + x·v = g`, so when `g = 1` the coefficient `v` of `x` is
the inverse. Returns `0` when `gcd m x ≠ 1` (defined behavior; callers that
need a real inverse pre-check coprimality). -/
def invM (m x : Nat) : Nat :=
  let (g, _, v) := egcd m x
  if g == 1 then (v % (m : Int)).toNat else 0

/-- **Inverse correctness** (W14 `invMod_correct`, generalized to modulus `m`).
For `0 < x` coprime to `m`, `(x * invM m x) % m = 1`. Sorry-free.
SGN-102: modular inverse correctness. -/
@[rule "SGN-102"]
theorem invM_correct (m x : Nat) (hm : 1 < m) (_hx : 0 < x) (hcop : Nat.gcd m x = 1) :
    (x * invM m x) % m = 1 := by
  have hrecE : ∃ g u v : Int, egcd m x = (g, u, v) :=
    ⟨(egcd m x).1, (egcd m x).2.1, (egcd m x).2.2, rfl⟩
  obtain ⟨g, u, v, heq⟩ := hrecE
  have ⟨hg, hgn⟩ := egcd_gcd_toNat m x (by omega) g u v heq
  have hg1 : g = 1 := by
    have htn : g = (g.toNat : Int) := (Int.toNat_of_nonneg (by omega : (0 : Int) ≤ g)).symm
    rw [htn, hgn, hcop]
    rfl
  have hp0 : (m : Int) ≠ 0 := by
    have := hm
    omega
  have hbez : (m : Int) * u + (x : Int) * v = 1 := by
    rw [← hg1]; exact egcd_bezout x m g u v heq
  have hunfold : invM m x = (v % (m : Int)).toNat := by
    unfold invM
    rw [heq]
    dsimp only
    rw [hg1]
    rfl
  rw [hunfold]
  have key1 : ((x : Int) * (v % (m : Int))) % (m : Int) = ((x : Int) * v) % (m : Int) := by
    have hvm : (v % (m : Int)) % (m : Int) = v % (m : Int) :=
      Int.emod_emod_of_dvd v (Int.dvd_refl (m : Int))
    calc ((x : Int) * (v % (m : Int))) % (m : Int)
        = (x : Int) % (m : Int) * ((v % (m : Int)) % (m : Int)) % (m : Int) :=
          Int.mul_emod x (v % (m : Int)) (m : Int)
      _ = (x : Int) % (m : Int) * (v % (m : Int)) % (m : Int) := by rw [hvm]
      _ = ((x : Int) * v) % (m : Int) := by
            rw [Int.mul_emod x v (m : Int)]
  have h1 : (x : Int) * v = 1 - (m : Int) * u := by
    have h := hbez
    rw [Int.add_comm ((m : Int) * u) ((x : Int) * v)] at h
    have h2 := congrArg (fun w : Int => w - (m : Int) * u) h
    rw [Int.add_sub_cancel] at h2
    exact h2
  have key2 : ((x : Int) * v) % (m : Int) = 1 := by
    have hstep : ((m : Int) * u + (x : Int) * v) % (m : Int) = ((x : Int) * v) % (m : Int) :=
      Int.mul_add_emod_self_left (m : Int) u ((x : Int) * v)
    rw [← hstep, hbez]
    exact Int.emod_eq_of_lt (by omega) (by omega)
  have hfin : (((x * (v % (m : Int)).toNat) % m : Nat) : Int) = 1 := by
    have hcast : (((v % (m : Int)).toNat : Int)) = v % (m : Int) :=
      Int.toNat_of_nonneg (Int.emod_nonneg v hp0)
    rw [show (((x * (v % (m : Int)).toNat) % m : Nat) : Int)
        = ((x : Int) * ((v % (m : Int)).toNat : Int)) % (m : Int) from rfl,
        hcast, key1, key2]
  exact Int.ofNat_inj.mp hfin

/-- The inverse is a canonical representative. -/
theorem invM_lt (m x : Nat) (hm : 0 < m) : invM m x < m := by
  have h0 : (0:Int) ≤ (egcd m x).2.2 % (m:Int) :=
    Int.emod_nonneg _ (by have := hm; omega)
  have hlt : (egcd m x).2.2 % (m:Int) < (m:Int) :=
    Int.emod_lt_of_pos _ (by have := hm; omega)
  have hcast : (((egcd m x).2.2 % (m:Int)).toNat : Int) = (egcd m x).2.2 % (m:Int) :=
    Int.toNat_of_nonneg h0
  have hfin : (((egcd m x).2.2 % (m:Int)).toNat : Int) < (m:Int) := by rw [hcast]; exact hlt
  have hres : invM m x < m := by
    unfold invM
    dsimp only
    split
    · exact Int.ofNat_lt.mp hfin
    · exact hm
  exact hres

end Bitcoin.Crypto.Curve.Mod
