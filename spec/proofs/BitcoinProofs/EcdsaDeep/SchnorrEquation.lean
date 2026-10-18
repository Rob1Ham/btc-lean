import Bitcoin.Crypto.Schnorr.Verify
import Bitcoin.Crypto.Curve.Secp

/-!
# BitcoinProofs.EcdsaDeep.SchnorrEquation (E08, Unit 1)

**BIP340 verification ⇔ the verification equation** — the iff for X02's
REAL verifier (`Bitcoin.Crypto.Schnorr.Verify.verifyImpl`, read-only
here), sorry-free, zero-mathlib (plain Lean + core only; the ZMod
group-law closure stays in `CurveZMod`'s lane).

## What is proved

`verifyImpl sig pk msg = true` **↔** `satisfiesEquation sig pk msg`, where

    satisfiesEquation sig pk msg :=
      sig.size = 64 ∧ pk.size = 32
      ∧ ∃ px py,  liftX (bytesToNatBE pk) = some (px, py)      -- step 2
                ∧ satisfiesLifted sig px py msg

    satisfiesLifted sig px py msg :=                            -- steps 3–7
        r < P                                                    -- step 3
      ∧ s < n                                                    -- step 4
      ∧ ∃ ry,  s·G + e·(px, p − py) = some (r, ry)              -- step 6
              ∧ ry % 2 = 0                                       -- step 7

with `r := bytesToNatBE (sig.extract 0 32)`, `s := bytesToNatBE
(sig.extract 32 64)`, and `e := eOf r px msg =
int(tagged_hash("BIP0340/challenge", bytes(r) ‖ bytes(px) ‖ m)) mod n`
(bip-0340 §"Verification" step 5; `eOf` re-appears verbatim inside the
equation, and `eOf_lt` re-pins `e < n`).

So X02's verifier accepts **exactly** when: the sizes are right (step 1),
the pubkey lifts (step 2, even-y, `liftX`), the ranges hold (steps 3–4),
and the verification equation holds **in the exact form the code
computes it** — `R = s·G − e·P` implemented as `s·G + e·(px, p−py)`
(the sign-symmetry of the negation map; see the fidelity note in
`Crypto/Schnorr/Verify.lean` — Core applies `−e` via the scalar `n − e`,
X02 via the point `(px, p−py)`, the same group element), with `x(R) = r`
and even `y(R)` (step 7's triple check). `verifyImpl_true_equation_e`
restates the →-direction in BIP340's own notation with `e` named.

## Directions, honestly named

* **→ `verifyImpl_true_satisfies`** (soundness direction, the target
  minimum): an accepted signature satisfies the equation — the verdict
  fabricates nothing. Built on X02's `verifyImpl_true_cases` /
  `verifyLifted_true_range` / `verifyLifted_true_R` (in the core import,
  read-only), glued with no new algebra.
* **← `verifyImpl_of_satisfies`** (completeness on the equation): a
  64-byte sig / 32-byte pk pair whose lifted pubkey, ranges, equation
  point and even-y all hold IS accepted — no gate rejects it. This is
  the equation-verification direction NEW in this file; the proof is
  gate-branching only (`omega`-killed range gate, `simp`-killed
  size/lift/match/equality gates). No primality, no residue reasoning:
  the lift's own runtime check is the hypothesis (`liftX … = some _`).

## Scope honesty (what this is NOT)

The theorem is about the EQUATION as the code computes it. It does NOT
(a) prove the group law (`s·G + e·(px,p−py)` behaving like the abstract
`ZMod`-point-arithmetic `s·G − e·P` — `CurveZMod`'s closure lane), (b)
prove `liftX` totality/even-y-unique (runtime-conditional in
`Curve.Secp`, `liftX_onCurve`/`liftX_even`), or (c) formalize
unforgeability / EC-discrete-log hardness (out of scope everywhere;
see `Crypto/Schnorr.lean` §"OUT OF SCOPE").

Zero mathlib. Axiom footprints pinned per theorem (`#guard_msgs`).
-/

namespace BitcoinProofs.EcdsaDeep.SchnorrEquation

open Bitcoin.Crypto.Curve.Secp Bitcoin.Crypto.Schnorr.Verify
  Bitcoin.Crypto.Schnorr

/-! ## The challenge scalar (BIP340 step 5), as it appears in the equation -/

/-- `e` is always reduced mod n (bip-0340 step 5 "mod n"; the reduction
lives inside `eOf`). Own one-liner (`Nat.mod_lt` + `Secp.n_pos`), so
this file depends on no other proofs-package module. -/
theorem eOf_lt (r px : Nat) (msg : ByteArray) : eOf r px msg < n :=
  Nat.mod_lt _ n_pos

/-! ## The equation predicates (steps 3–7 / steps 1–7) -/

/-- **The verification equation, post-lift level** (bip-0340 §"Verification"
steps 3–7): ranges `r < P`, `s < n`, and the equation point
`R = s·G − e·P` (computed as `s·G + e·(px, p−py)`) is a real point with
`x(R) = r` and even `y(R)`. `e = eOf r px msg` (step 5). -/
def satisfiesLifted (sig : ByteArray) (px py : Nat) (msg : ByteArray) : Prop :=
  bytesToNatBE (sig.extract 0 32) < P
  ∧ bytesToNatBE (sig.extract 32 64) < n
  ∧ ∃ ry : Nat,
      addP (mulP (bytesToNatBE (sig.extract 32 64)) G)
        (mulP (eOf (bytesToNatBE (sig.extract 0 32)) px msg) (some (px, negN py)))
        = some (bytesToNatBE (sig.extract 0 32), ry)
      ∧ ry % 2 = 0

/-- **The verification equation, composed level** (bip-0340
§"Verification" steps 1–7): sizes (step 1), the even-y lift
`P = lift_x(int(pk))` (step 2), and the post-lift equation
`satisfiesLifted` (steps 3–7). `verifyImpl = true` iff this. -/
def satisfiesEquation (sig pk msg : ByteArray) : Prop :=
  sig.size = 64 ∧ pk.size = 32
  ∧ ∃ px py : Nat, liftX (bytesToNatBE pk) = some (px, py)
    ∧ satisfiesLifted sig px py msg

/-! ## The ←-direction (equation ⇒ accept): gate-branching only -/

/-- **Post-lift ←-direction**: a signature whose ranges, equation point
and even-y check all hold is accepted by `verifyLifted` (steps 3–8;
completeness on the equation). The proof is pure gate-branching: the
range gate falls to `omega` (via `hlt`/`hsl`), the match/equality gates
to `simp`+`rw [heq]`. No primality, no residues, no group law. -/
theorem verifyLifted_of_satisfies (sig : ByteArray) (px py : Nat)
    (msg : ByteArray) (hsat : satisfiesLifted sig px py msg) :
    verifyLifted sig px py msg = true := by
  obtain ⟨hlt, hsl, ry0, heq, hry⟩ := hsat
  unfold verifyLifted
  have hc : (bytesToNatBE (sig.extract 0 32) ≥ P
      || bytesToNatBE (sig.extract 32 64) ≥ n) = false := by
    have h1 : ¬(bytesToNatBE (sig.extract 0 32) ≥ P) := by omega
    have h2 : ¬(bytesToNatBE (sig.extract 32 64) ≥ n) := by omega
    simp [h1, h2]
  simp only [hc]
  rw [heq]
  simp [hry]

/-- **Composed ←-direction**: sizes, lift, ranges, equation point and
even-y ⇒ `verifyImpl = true` (bip-0340 steps 1–8). The size gate falls
to `simp [sizeGate, hsz, hpk]`, the lift branch to `rw [hlift]`, the
rest is `verifyLifted_of_satisfies`. -/
theorem verifyImpl_of_satisfies (sig pk msg : ByteArray)
    (hsat : satisfiesEquation sig pk msg) :
    verifyImpl sig pk msg = true := by
  obtain ⟨hsz, hpk, px, py, hlift, hsatL⟩ := hsat
  unfold verifyImpl
  have hsg : (!sizeGate sig pk) = false := by
    have hg : sizeGate sig pk = true := by simp [sizeGate, hsz, hpk]
    simp [hg]
  simp only [hsg]
  rw [hlift]
  exact verifyLifted_of_satisfies sig px py msg hsatL

/-! ## The →-direction (accept ⇒ equation), on X02's read-only theorems -/

/-- **Post-lift →-direction** (soundness direction): an accepted
post-lift verdict satisfies the equation — ranges (X02
`verifyLifted_true_range`), equation point with `x(R) = r` and even
`y(R)` (X02 `verifyLifted_true_R`). No new algebra. -/
theorem verifyLifted_true_satisfies (sig : ByteArray) (px py : Nat)
    (msg : ByteArray) (h : verifyLifted sig px py msg = true) :
    satisfiesLifted sig px py msg := by
  obtain ⟨hr1, hr2⟩ := verifyLifted_true_range sig px py msg h
  obtain ⟨rx, ry, heq, hx, hy⟩ := verifyLifted_true_R sig px py msg h
  rw [hx] at heq
  exact ⟨hr1, hr2, ry, heq, hy⟩

/-- **Composed →-direction** (the soundness minimum):
`verifyImpl = true` ⇒ sizes (step 1), the lift (step 2), and the full
post-lift equation (steps 3–7). On X02's `verifyImpl_true_cases` +
`sizeGate_eq_true`. -/
theorem verifyImpl_true_satisfies (sig pk msg : ByteArray)
    (h : verifyImpl sig pk msg = true) :
    satisfiesEquation sig pk msg := by
  obtain ⟨hs, px, py, hl, hv⟩ := verifyImpl_true_cases sig pk msg h
  obtain ⟨hs1, hs2⟩ := sizeGate_eq_true hs
  exact ⟨hs1, hs2, px, py, hl, verifyLifted_true_satisfies sig px py msg hv⟩

/-! ## The master iff -/

/-- **BIP340 verification ⇔ the verification equation** (bip-0340
§"Verification"; TPR-050..053 composed): X02's `verifyImpl` accepts
`sig pk msg` **iff** `satisfiesEquation sig pk msg` — sizes, even-y
lift, `r < P`, `s < n`, and `R = s·G − e·P` with `x(R) = r`, even
`y(R)`, `e = eOf r px msg` (step 5, reduced mod n). The →-half is
soundness (an accepted signature satisfies the equation); the ←-half
is completeness on the equation (nothing else can reject). -/
theorem verifyImpl_iff (sig pk msg : ByteArray) :
    verifyImpl sig pk msg = true ↔ satisfiesEquation sig pk msg :=
  ⟨verifyImpl_true_satisfies sig pk msg,
   verifyImpl_of_satisfies sig pk msg⟩

/-- The post-lift iff (steps 3–7 alone), same two halves. -/
theorem verifyLifted_iff (sig : ByteArray) (px py : Nat) (msg : ByteArray) :
    verifyLifted sig px py msg = true ↔ satisfiesLifted sig px py msg :=
  ⟨verifyLifted_true_satisfies sig px py msg,
   verifyLifted_of_satisfies sig px py msg⟩

/-! ## The equation in BIP340 notation, `e` named -/

/-- The →-direction restated in bip-0340 §"Verification" notation:
acceptance gives a lifted pubkey `P = (px, py)`, the challenge
`e = eOf r px msg < n` (step 5), and the equation point
`R = s·G − e·P` (computed `s·G + e·(px, p−py)`) with `x(R) = r` and
even `y(R)`. This is the statement to read against the spec text. -/
theorem verifyImpl_true_equation_e (sig pk msg : ByteArray)
    (h : verifyImpl sig pk msg = true) :
    ∃ px py rx ry e : Nat,
      liftX (bytesToNatBE pk) = some (px, py)
      ∧ e = eOf (bytesToNatBE (sig.extract 0 32)) px msg
      ∧ e < n
      ∧ addP (mulP (bytesToNatBE (sig.extract 32 64)) G)
          (mulP e (some (px, negN py)))
          = some (rx, ry)
      ∧ rx = bytesToNatBE (sig.extract 0 32)
      ∧ ry % 2 = 0 := by
  obtain ⟨hsz, hpk, px, py, hl, hlt, hsl, ry0, heq, hry⟩ :=
    verifyImpl_true_satisfies sig pk msg h
  exact ⟨px, py, bytesToNatBE (sig.extract 0 32), ry0,
    eOf (bytesToNatBE (sig.extract 0 32)) px msg, hl, rfl,
    eOf_lt _ _ _, heq, rfl, hry⟩

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.EcdsaDeep.SchnorrEquation.eOf_lt' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms eOf_lt

/-- info: 'BitcoinProofs.EcdsaDeep.SchnorrEquation.verifyLifted_of_satisfies' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyLifted_of_satisfies

/-- info: 'BitcoinProofs.EcdsaDeep.SchnorrEquation.verifyImpl_of_satisfies' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyImpl_of_satisfies

/-- info: 'BitcoinProofs.EcdsaDeep.SchnorrEquation.verifyLifted_true_satisfies' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyLifted_true_satisfies

/-- info: 'BitcoinProofs.EcdsaDeep.SchnorrEquation.verifyImpl_true_satisfies' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyImpl_true_satisfies

/-- info: 'BitcoinProofs.EcdsaDeep.SchnorrEquation.verifyImpl_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verifyImpl_iff

/-- info: 'BitcoinProofs.EcdsaDeep.SchnorrEquation.verifyLifted_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verifyLifted_iff

/-- info: 'BitcoinProofs.EcdsaDeep.SchnorrEquation.verifyImpl_true_equation_e' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyImpl_true_equation_e

end BitcoinProofs.EcdsaDeep.SchnorrEquation
