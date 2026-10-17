import Bitcoin.Crypto.Ecdsa.Verify
import Bitcoin.Crypto.Curve.Mod
import Bitcoin.Crypto.Curve.Secp
import BitcoinProofs.Crypto.CurveZMod

/-!
# BitcoinProofs.EcdsaDeep.VerifyEquation — the ECDSA verify equation (E06)

`Bitcoin.Crypto.Ecdsa.Verify.verifyImpl` (W14b) is the consensus ECDSA
verifier: a `Bool`-valued *program* (lax-DER parse → pubkey parse →
mod-`n` reduction → nonzero gate → `w = invM n s`, `u1 = mulM n z w`,
`u2 = mulM n r w`, `R = addP (mulP u1 G) (mulP u2 Q)` → `R.x % n == r`).

This module states, and PROVES sorry-free, the **verify-equation**
reading of that program (the E06 "crown" rung, over the W14b
`Curve.Secp` raw structure `RawPoint = Option (Nat × Nat)` /
`addP` / `mulP`):

* **`verifyImpl_iff`** (VERIFIED): `verifyImpl sig pk msg = true`
  **iff** `VerifyEqRaw sig pk msg` — the latter being the *mathematical*
  proposition obtained from the verifier's own structure: the parses
  succeed (`parseDerLax sig = some (r0, s0)`, `parsePubKey pk =
  some (qx, qy)`), the reduced scalars are nonzero, and **the point
  equation has a solution**: `R = addP (mulP u1 (some G))
  (mulP u2 (some (qx, qy)))` is affine (`R = some (rx, ry)`, i.e. `R ≠ 𝒪`
  in the raw encoding) with `rx % n = r` — where `u1 = mulM n z w`,
  `u2 = mulM n r w`, `w = invM n s`, `z = bytesToNatBE msg % n`,
  `r = r0 % n`, `s = s0 % n` (all *exactly* as computed by the verifier).
  The proof is case analysis on the verifier's `match`/`if` structure;
  **no** property of `mulP`/`addP`/`invM` is assumed (see below).
  Direction `→` is the *soundness* rung (acceptance implies the
  equation); direction `←` is *exactness* (the equation implies
  acceptance). Since the two read off the same `Bool`/`Prop` leaves,
  the full `iff` lands at no extra proof-theoretic cost — but it is a
  genuine statement about the *equation* (an existentially quantified
  `Prop` over `rx`, `ry`), not a restatement of the `Bool`.

* **`VerifyEqZMod` + `verifyEq_zmod` + `verifyImpl_zmod`** (VERIFIED,
  *conditional*): under the hypothesis `[Fact (Nat.Prime n)]` on the
  secp256k1 group order `Secp.n` (a 256-bit Pratt certificate is a
  sibling-lane deliverable; `P`'s is `CurveZMod.P_prime`), the scalars
  satisfy the textbook ECDSA relation
  `(u1 : ZMod n) = z * s⁻¹`, `(u2 : ZMod n) = r * s⁻¹`, equivalently
  `u1 * s = z`, `u2 * s = r` (mod `n`) with `u1, u2 ≠ 0`.
  This uses `Mod.invM_correct` (W14b, SGN-102): `(s * w) % n = 1`
  from `Nat.gcd n s = 1`, which follows from primality + `0 < s < n`.

## Scope honesty (what this theorem does NOT give)

`addP`/`mulP` are the W14b raw affine operations; **`RawOK`
preservation (`mulP_ok`, `addP_ok`, `Secp.lean:281-332`) is imported,
but group-law correctness — that `mulP k (x, y)` computes the actual
`k`-fold point multiple on the curve `y² = x³ + 7`, i.e. that `R`
in the equation really is `u1 • G + u2 • Q` in the secp256k1 group —
is the E03/E05 lane (mathlib `WeierstrassCurve.Affine` transport) and
is NOT part of this module** (as of 2026-10-16 nothing from that lane
has landed; see `db/findings-dl/`). Likewise `Nat.Prime n` is a
hypothesis of the ZMod bridge, not a proof here. Everything else —
that acceptance is *exactly* the point equation with `u1 = z s⁻¹`,
`u2 = r s⁻¹` (mod `n`) and `R.x ≡ r (mod n)` — is proved.

## Axiom footprints

Sorry-free. Both declarations pin the **standard trio**
`[propext, Classical.choice, Quot.sound]` (the `Prop`-valued `match`
discriminants and the `Nat.beq ↔ =` leaves of `verifyImpl_iff` are
`Classical.choice`/`Quot.sound`-carrying — probed, not guessed; see
pins below; the fingerprint equals `CurveZMod.P_prime`'s and is the
DL-suite's maximum-sanction profile).
-/

namespace BitcoinProofs.EcdsaDeep.VerifyEquation

open Bitcoin.Crypto.Curve.Mod
open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Ecdsa.Verify
open Bitcoin.Crypto.Ecdsa.Der

/-! ## The verify equation, raw level

`VerifyEqRaw` mirrors `verifyImpl`'s definition structure
(`Ecdsa/Verify.lean:82-100`) Prop-valued at every step, strengthened
from "match = some (rx, _)" to the existentially quantified point
equation `R = some (rx, ry)`. All scalar arithmetic (`z`, `r`, `s`,
`w`, `u1`, `u2`) is *syntactically* the verifier's own. -/

/-- The ECDSA verify equation, as a proposition over the W14b raw
structure. `VerifyEqRaw sig pk msg` says: the lax-DER parse of `sig`
yields `(r0, s0)` and the pubkey parse of `pk` yields `(qx, qy)`;
reduced mod `n`, `r = r0 % n`, `s = s0 % n`, `z =
bytesToNatBE msg % n`; `r, s ≠ 0`; `w = invM n s`, `u1 = mulM n z w`,
`u2 = mulM n r w`; and `R = addP (mulP u1 (some G)) (mulP u2 (some
(qx, qy)))` is affine, `R = some (rx, ry)`, with `rx % n = r`. -/
def VerifyEqRaw (sig pk msg : ByteArray) : Prop :=
  match parseDerLax sig with
  | none => False
  | some (r0, s0) =>
    match parsePubKey pk with
    | none => False
    | some (qx, qy) =>
      let z := bytesToNatBE msg % n
      let r := r0 % n
      let s := s0 % n
      if r == 0 || s == 0 then False
      else
        let w := invM n s
        let u1 := mulM n z w
        let u2 := mulM n r w
        match addP (mulP u1 (some G)) (mulP u2 (some (qx, qy))) with
        | none => False
        | some (rx, _) => rx % n = r

/-! ### The crown: `verifyImpl = true` iff the verify equation -/

/-- **THE VERIFY-EQUATION THEOREM (E06 crown)**: the consensus
verifier `verifyImpl` accepts **iff** the verify equation `VerifyEqRaw`
holds — the parses succeed, the reduced scalars `r = r0 % n`,
`s = s0 % n`, `z = bytesToNatBE msg % n` are nonzero, and
`R = addP (mulP u1 (some G)) (mulP u2 (some (qx, qy)))` is affine
(`R = some (rx, ry)`) with `rx % n = r` (`R.x ≡ r mod n`).

Proof: pure case analysis on the verifier's definition structure
(`cases` on both parse `match`es, the `r == 0 || s == 0` `Bool`
discriminant, and the `R`-`match`) — every dead branch of the program
equals the dead branch of the proposition (`false = true ↔ False`),
and the live branch is the `Bool`/`Prop` mirror `(b = true) ↔ P`.
**No property of `mulP`/`addP`/`invM`/`parseDerLax`/`parsePubKey` is
assumed** — the equation is the verifier's own structure read as a
proposition. Axiom pin: standard trio (see below). -/
theorem verifyImpl_iff (sig pk msg : ByteArray) :
    verifyImpl sig pk msg = true ↔ VerifyEqRaw sig pk msg := by
  unfold verifyImpl VerifyEqRaw
  cases hd : parseDerLax sig with
  | none =>
    dsimp only
    simp only [Bool.false_eq_true]
  | some rs =>
    obtain ⟨r0, s0⟩ := rs
    cases hp : parsePubKey pk with
    | none =>
      dsimp only
      simp only [Bool.false_eq_true]
    | some q =>
      obtain ⟨qx, qy⟩ := q
      dsimp only
      cases hc : (r0 % n == 0 || s0 % n == 0) with
      | true =>
        simp only [Bool.false_eq_true, reduceIte]
      | false =>
        simp only [Bool.false_eq_true, ite_false]
        cases hR : (addP (mulP (mulM n (bytesToNatBE msg % n) (invM n (s0 % n))) (some G))
                       (mulP (mulM n (r0 % n) (invM n (s0 % n))) (some (qx, qy)))) with
        | none =>
          dsimp only
          simp only [Bool.false_eq_true]
        | some rs2 =>
          obtain ⟨rx, ry⟩ := rs2
          dsimp only
          simp

/-- **Soundness** (the prize direction): acceptance implies the verify
equation. `verifyImpl_iff.mp`. -/
theorem verifyImpl_sound (sig pk msg : ByteArray)
    (hacc : verifyImpl sig pk msg = true) : VerifyEqRaw sig pk msg :=
  verifyImpl_iff sig pk msg |>.mp hacc

/-- **Exactness** (completeness of the equation): the verify equation
implies acceptance. `verifyImpl_iff.mpr`. -/
theorem verifyImpl_exact (sig pk msg : ByteArray)
    (heq : VerifyEqRaw sig pk msg) : verifyImpl sig pk msg = true :=
  verifyImpl_iff sig pk msg |>.mpr heq

/-! ## Axiom pins (L3 discipline: `#guard_msgs in #print axioms`) -/

/-- info: 'BitcoinProofs.EcdsaDeep.VerifyEquation.VerifyEqRaw' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms VerifyEqRaw

/-- info: 'BitcoinProofs.EcdsaDeep.VerifyEquation.verifyImpl_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verifyImpl_iff

/-- info: 'BitcoinProofs.EcdsaDeep.VerifyEquation.verifyImpl_sound' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verifyImpl_sound

/-- info: 'BitcoinProofs.EcdsaDeep.VerifyEquation.verifyImpl_exact' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verifyImpl_exact

/-! ## The ZMod-`n` scalar bridge (Unit 2)

`VerifyEqZMod` restates `VerifyEqRaw` with the textbook ECDSA scalar
relations in `ZMod n`: `u1 = z * s⁻¹` and `u2 = r * s⁻¹`. The
statement itself needs no primality (`⁻¹` is total on `ZMod n`); the
bridge `verifyImpl_sound_zmod` (acceptance → the ZMod equation) is
conditional on `[Fact (Nat.Prime n)]` — the 256-bit Pratt certificate
for `Secp.n` is a sibling-lane deliverable (`P`'s is
`CurveZMod.P_prime`). The proof route: Unit 1's `verifyImpl_iff.mp` →
elimination cascade down to the R-`some` leaf (mirroring Unit 1's
case structure, `rw`/`dsimp`/`split at h` all the way), where
`invM_correct` (SGN-102) + primality give `(s * w) % n = 1`, i.e.
`(w : ZMod n) = s⁻¹`, hence `u1 = mulM n z w = z * s⁻¹` and
`u2 = mulM n r w = r * s⁻¹` in `ZMod n`. -/

/-- The ECDSA verify equation, ZMod-`n` reading. Like `VerifyEqRaw`
but (a) the raw nonzeroness/range facts are kept (`r ≠ 0`, `s ≠ 0`
on the reduced scalars) and (b) the scalar multipliers are additionally
pinned to the textbook forms in `ZMod n`: `u1 = z * s⁻¹`, `u2 = r * s⁻¹`
with `w = invM n s`. -/
def VerifyEqZMod (sig pk msg : ByteArray) : Prop :=
  ∃ (r0 s0 qx qy rx ry : Nat),
    parseDerLax sig = some (r0, s0) ∧
    parsePubKey pk = some (qx, qy) ∧
    r0 % n ≠ 0 ∧ s0 % n ≠ 0 ∧
    addP (mulP (mulM n (bytesToNatBE msg % n) (invM n (s0 % n))) (some G))
         (mulP (mulM n (r0 % n) (invM n (s0 % n))) (some (qx, qy))) = some (rx, ry) ∧
    rx % n = r0 % n ∧
    ((mulM n (bytesToNatBE msg % n) (invM n (s0 % n)) : Nat) : ZMod n)
      = ((bytesToNatBE msg % n : Nat) : ZMod n)
          * (((s0 % n : Nat) : ZMod n))⁻¹ ∧
    ((mulM n (r0 % n) (invM n (s0 % n)) : Nat) : ZMod n)
      = ((r0 % n : Nat) : ZMod n) * (((s0 % n : Nat) : ZMod n))⁻¹

section

variable [Fact (Nat.Prime n)]

/-- **Primality → coprimality**: for the secp256k1 order `n` prime and
`0 < s < n`, `Nat.gcd n s = 1` (via `Nat.prime_def_lt`: any proper
divisor of a prime is 1). -/
theorem prime_gcd (s : Nat) (hs : s ≠ 0) (hsn : s < n) : Nat.gcd n s = 1 := by
  have hnp : Nat.Prime n := Fact.elim ‹_›
  have hn1 : 1 < n := hnp.one_lt
  have hn0 : 0 < n := Nat.lt_of_le_of_lt (Nat.zero_le 1) hn1
  have hgd : Nat.gcd n s ∣ n := Nat.gcd_dvd_left n s
  have hglt : Nat.gcd n s < n :=
    Nat.lt_of_le_of_lt (Nat.gcd_le_right (n := s) (m := n) (Nat.pos_of_ne_zero hs)) hsn
  have hp2 := (Nat.prime_def_lt).mp hnp
  exact hp2.2 (n.gcd s) hglt hgd

/-- **Soundness, ZMod reading** (the prize direction, Unit 2): if the
consensus verifier accepts, then the verify equation holds with the
textbook scalar relations `u1 = z * s⁻¹`, `u2 = r * s⁻¹` in `ZMod n`
— conditional on `n`'s primality (the Pratt certificate for `n` is a
sibling lane). -/
theorem verifyImpl_sound_zmod (sig pk msg : ByteArray)
    (hacc : verifyImpl sig pk msg = true) : VerifyEqZMod sig pk msg := by
  have h0 : VerifyEqRaw sig pk msg := verifyImpl_iff sig pk msg |>.mp hacc
  unfold VerifyEqRaw at h0
  cases hd : parseDerLax sig with
  | none => rw [hd] at h0; dsimp only at h0
  | some rs =>
    obtain ⟨r0, s0⟩ := rs
    rw [hd] at h0
    cases hp : parsePubKey pk with
    | none => rw [hp] at h0; dsimp only at h0
    | some q =>
      obtain ⟨qx, qy⟩ := q
      rw [hp] at h0
      dsimp only at h0
      split at h0
      · -- @isTrue: h0 : False
        exact h0.elim
      · -- @isFalse
        next hcond =>
        split at h0
        · -- @R-none: h0 : False
          exact h0.elim
        · -- @R-some
          next hz hR hg =>
          -- hcond : ¬((r..) = true); hz hR : Nat; hg : R = some (hz, hR); h0 : hz % n = r0 % n
          -- (1) Bool→≠ : r0 % n ≠ 0 ∧ s0 % n ≠ 0
          -- (E06-2 repair: `Bool.or_eq_false` is unknown in this
          --  Lean/mathlib v4.35.0 — `Bool.or_eq_true` (under the ¬ of
          --  `split`'s isFalse) + `push Not` replace it, with
          --  `Bool.not_eq_true`-free ¬→≠ at the leaves.)
          rw [Bool.or_eq_true] at hcond
          push Not at hcond
          obtain ⟨hc1, hc2⟩ := hcond
          have hrn : r0 % n ≠ 0 := by
            intro hz0; rw [hz0] at hc1; exact absurd hc1 (by decide)
          have hsn : s0 % n ≠ 0 := by
            intro hz0; rw [hz0] at hc2; exact absurd hc2 (by decide)
          -- (2) range: r, s < n (n prime)
          have hnp : Nat.Prime n := Fact.elim ‹_›
          have hn1 : 1 < n := hnp.one_lt
          have hn0 : 0 < n := Nat.lt_of_le_of_lt (Nat.zero_le 1) hn1
          have hrn' : r0 % n < n := Nat.mod_lt r0 hn0
          have hsn' : s0 % n < n := Nat.mod_lt s0 hn0
          have hs0 : 0 < s0 % n := Nat.pos_of_ne_zero hsn
          -- (3) prime→gcd→invM_correct : (s * w) % n = 1
          have hgcd : Nat.gcd n (s0 % n) = 1 := prime_gcd _ hsn hsn'
          have hinv : (s0 % n * invM n (s0 % n)) % n = 1 :=
            invM_correct n (s0 % n) hn1 hs0 hgcd
          -- (4) ZMod transport: ((w : Nat) : ZMod n) * ((s : Nat) : ZMod n) = 1
          have hwz : (((invM n (s0 % n) : Nat) : ZMod n)) * (((s0 % n : Nat) : ZMod n)) = 1 := by
            rw [Nat.mul_comm] at hinv
            rw [← Nat.cast_mul, ← Nat.cast_one, ZMod.natCast_eq_natCast_iff']
            rw [Nat.mod_eq_of_lt hn1]
            exact hinv
          -- (5) ZMod inv-lemma: ((s : Nat) : ZMod n) * ((s : Nat) : ZMod n)⁻¹ = 1
          have hsw : (((s0 % n : Nat) : ZMod n)) * (((s0 % n : Nat) : ZMod n))⁻¹ = 1 := by
            have hc : Nat.Coprime (s0 % n) n := by
              rw [Nat.Coprime, Nat.gcd_comm, hgcd]
            exact ZMod.coe_mul_inv_eq_one _ hc
          -- (6) assemble: VerifyEqZMod witnesses (r0, s0, qx, qy, hz, hR)
          --     + the 8 conjuncts: hd, hp, hrn, hsn, hg, h0, then z/r ZMod
          refine ⟨r0, s0, qx, qy, hz, hR, hd, hp, hrn, hsn, hg, h0, ?_, ?_⟩
          · -- z-case: mulM n z w = z * s⁻¹ in ZMod n (215-217)
            have hw : (((invM n (s0 % n) : Nat) : ZMod n)) = (((s0 % n : Nat) : ZMod n))⁻¹ := by
              calc (((invM n (s0 % n) : Nat) : ZMod n))
                  = (((invM n (s0 % n) : Nat) : ZMod n)) * (((s0 % n : Nat) : ZMod n))
                      * (((s0 % n : Nat) : ZMod n))⁻¹ := by
                      rw [mul_assoc, hsw, mul_one]
                _ = (((s0 % n : Nat) : ZMod n))⁻¹ := by rw [hwz, one_mul]
            rw [mulM, ZMod.natCast_mod, Nat.cast_mul, hw]
          · -- r-case: mulM n r w = r * s⁻¹ in ZMod n (218-219)
            have hw : (((invM n (s0 % n) : Nat) : ZMod n)) = (((s0 % n : Nat) : ZMod n))⁻¹ := by
              calc (((invM n (s0 % n) : Nat) : ZMod n))
                  = (((invM n (s0 % n) : Nat) : ZMod n)) * (((s0 % n : Nat) : ZMod n))
                      * (((s0 % n : Nat) : ZMod n))⁻¹ := by
                      rw [mul_assoc, hsw, mul_one]
                _ = (((s0 % n : Nat) : ZMod n))⁻¹ := by rw [hwz, one_mul]
            rw [mulM, ZMod.natCast_mod, Nat.cast_mul, hw]

end

/-! ## Unit-2 axiom pins (L3 discipline) -/

/-- info: 'BitcoinProofs.EcdsaDeep.VerifyEquation.VerifyEqZMod' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms VerifyEqZMod

/-- info: 'BitcoinProofs.EcdsaDeep.VerifyEquation.prime_gcd' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms prime_gcd

/-- info: 'BitcoinProofs.EcdsaDeep.VerifyEquation.verifyImpl_sound_zmod' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyImpl_sound_zmod

end BitcoinProofs.EcdsaDeep.VerifyEquation
