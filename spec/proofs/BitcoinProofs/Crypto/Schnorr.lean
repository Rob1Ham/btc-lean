import Bitcoin.Crypto.Schnorr.Verify
import Bitcoin.Crypto.Curve.Secp

/-!
# BitcoinProofs.Crypto.Schnorr

X02 correctness theorems over the REAL BIP340 verifier
(`Bitcoin.Crypto.Schnorr.Verify`, X02) and the curve layer.
Zero-dependency on mathlib: plain Lean + the core library only (the
ZMod closure for the group-law algebra stays in `CurveZMod`; nothing
here needs primality — every theorem is conditional on the runtime
checks the verifier itself performs, per the liftX design).

Theorems:

* **lift_x correctness** — `liftX_correct`: whenever `liftX x = some (x', y')`,
  the lifted point is ON the curve (`y'² = x'³ + 7 mod P`) with the
  x-coordinate preserved and EVEN y. Conditional only on the runtime
  residue check (no `P_prime` hypothesis); re-exposed from `Curve.Secp`.
* **e-computation determinism** — `eOf_deterministic`/`eOf_congr`: the
  challenge is a pure function of `(r, px, msg)` (equal inputs, equal e),
  and `eOf` is always reduced mod n.
* **range-check totality** — `verify_totality`: `verifyImpl = true` pins
  ALL consensus gates (sizes, lift, `r < p`, `s < n`).
* **verdict purity** — `verify_purity`: the verdict is a total function of
  exactly its three arguments (congruence; no environment/execdata/global
  state appears in the definition — the seam-level analogue of
  `ecdsaEntry_execData_independent`, instantiated for the real verifier).

OUT OF SCOPE (honest note): soundness/unforgeability
("no valid signature without knowledge of d" — EC-discrete-log hardness)
is NOT formalized; neither is completeness over ALL accepting (r, s, P)
tuples (the conformance corpora — official 19 + 225 python-cross-checked
pairs — sample the space; ZMod group-law closure is the tool a
future soundness lane would build on). The `Secp.addP`/`mulP` equation
preservation proofs also live at the ZMod layer, not here.
-/

namespace BitcoinProofs.Crypto.Schnorr

open Bitcoin.Crypto.Curve.Secp Bitcoin.Crypto.Schnorr.Verify
  Bitcoin.Crypto.Schnorr

/-! ## lift_x correctness (conditional on the runtime residue check) -/

/-- **lift_x correctness** (TPR-049): a successful lift lands ON the curve
with x preserved and even y — `y'² = x'³ + 7 (mod P)`, `x' = x`,
`y' ≡ 0 (mod 2)`. No primality hypothesis: the proof uses only the
verifier's own `isSqrt` check plus `P` odd (for the even pick). -/
theorem liftX_correct (x x' y' : Nat) (h : liftX x = some (x', y')) :
    Bitcoin.Crypto.Curve.Secp.OnCurve x' y' ∧ x' = x ∧ y' % 2 = 0 :=
  ⟨liftX_onCurve h, liftX_snd h, liftX_even h⟩

/-- Corollary: the point `verifyImpl` lifts from an accepted pubkey lies
on the curve — the `P` in the verification equation really is a curve
point (bip-0340 step 2 sound spot). -/
theorem verify_pubkey_onCurve (sig pk msg : ByteArray)
    (h : verifyImpl sig pk msg = true) :
    ∃ px py : Nat, Bitcoin.Crypto.Curve.Secp.OnCurve px py
      ∧ py % 2 = 0
      ∧ liftX (bytesToNatBE pk) = some (px, py) := by
  obtain ⟨px, py, hl, _, _⟩ := verifyImpl_true_lift sig pk msg h
  exact ⟨px, py, liftX_onCurve hl, liftX_even hl, hl⟩

/-! ## e-computation determinism (TPR-048) -/

/-- The challenge digest is a pure function of `(r, px, msg)`: the tagged
hash is total and its preimage `challengePre` is total — equal arguments
give equal digests. -/
theorem challengeTagged_congr (r₁ r₂ px₁ px₂ : Nat) (m₁ m₂ : ByteArray)
    (hr : r₁ = r₂) (hpx : px₁ = px₂) (hm : m₁ = m₂) :
    challengeTagged r₁ px₁ m₁ = challengeTagged r₂ px₂ m₂ := by
  subst hr; subst hpx; subst hm; rfl

/-- **e-computation determinism** (TPR-048): `e` is a pure function of
`(r, px, msg)` — equal inputs give equal challenges. Combined with
`challengeTagged_size` (32-byte digest) and the `% n` reduction this is
bip-0340 step 5 in full. -/
theorem eOf_congr (r₁ r₂ px₁ px₂ : Nat) (m₁ m₂ : ByteArray)
    (hr : r₁ = r₂) (hpx : px₁ = px₂) (hm : m₁ = m₂) :
    eOf r₁ px₁ m₁ = eOf r₂ px₂ m₂ := by
  subst hr; subst hpx; subst hm; rfl

/-- `e` is always reduced: `eOf r px msg < n` (bip-0340 step 5 "mod n"). -/
theorem eOf_lt_n (r px : Nat) (msg : ByteArray) : eOf r px msg < n :=
  Nat.mod_lt _ n_pos

/-! ## Range-check totality (TPR-050/051) -/

/-- **Range-check totality**: acceptance implies every consensus gate
passed — the three encodings' sizes, the lift, `r < p`, `s < n`. -/
theorem verify_totality (sig pk msg : ByteArray)
    (h : verifyImpl sig pk msg = true) :
    sig.size = 64 ∧ pk.size = 32
      ∧ ∃ px py : Nat, liftX (bytesToNatBE pk) = some (px, py)
      ∧ bytesToNatBE (sig.extract 0 32) < P
      ∧ bytesToNatBE (sig.extract 32 64) < n :=
  verifyImpl_true_conditions sig pk msg h

/-- Contrapositive (gate form): out-of-range `r` always rejects. -/
theorem verify_rejects_r_ge_p (sig pk msg : ByteArray)
    (hr : bytesToNatBE (sig.extract 0 32) ≥ P) :
    verifyImpl sig pk msg = false := by
  unfold verifyImpl
  split
  · rfl
  · split
    · rfl
    · rename_i _ _
      -- r ≥ P survives to the range gate
      have : (bytesToNatBE (sig.extract 0 32) ≥ P
          || bytesToNatBE (sig.extract 32 64) ≥ n) = true := by
        simp [hr]
      rw [verifyLifted, if_pos this]

/-- Contrapositive (gate form): out-of-range `s` always rejects. -/
theorem verify_rejects_s_ge_n (sig pk msg : ByteArray)
    (hs : bytesToNatBE (sig.extract 32 64) ≥ n) :
    verifyImpl sig pk msg = false := by
  unfold verifyImpl
  split
  · rfl
  · split
    · rfl
    · rename_i _ _
      have : (bytesToNatBE (sig.extract 0 32) ≥ P
          || bytesToNatBE (sig.extract 32 64) ≥ n) = true := by
        simp [hs]
      rw [verifyLifted, if_pos this]

/-! ## Verdict purity (TPR-053) -/

/-- **Verdict purity**: the BIP340 verdict is a total function of exactly
its three arguments — equal `(sig, pk, msg)` give equal verdicts. There
is no environment, no execdata, no global state in the definition
(TPR-053: "verify is a total deterministic function of (sig, pk, msg)";
Core's per-call state — the RNG in signing — exists on the SIGN side
only, which is not part of verification). -/
theorem verify_purity (s₁ s₂ p₁ p₂ m₁ m₂ : ByteArray)
    (hs : s₁ = s₂) (hp : p₁ = p₂) (hm : m₁ = m₂) :
    verifyImpl s₁ p₁ m₁ = verifyImpl s₂ p₂ m₂ :=
  verifyImpl_congr s₁ s₂ p₁ p₂ m₁ m₂ hs hp hm

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Crypto.Schnorr.liftX_correct' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms liftX_correct

/-- info: 'BitcoinProofs.Crypto.Schnorr.verify_pubkey_onCurve' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verify_pubkey_onCurve

/-- info: 'BitcoinProofs.Crypto.Schnorr.challengeTagged_congr' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms challengeTagged_congr

/-- info: 'BitcoinProofs.Crypto.Schnorr.eOf_congr' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms eOf_congr

/-- info: 'BitcoinProofs.Crypto.Schnorr.eOf_lt_n' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms eOf_lt_n

/-- info: 'BitcoinProofs.Crypto.Schnorr.verify_totality' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verify_totality

/-- info: 'BitcoinProofs.Crypto.Schnorr.verify_rejects_r_ge_p' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verify_rejects_r_ge_p

/-- info: 'BitcoinProofs.Crypto.Schnorr.verify_rejects_s_ge_n' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verify_rejects_s_ge_n

/-- info: 'BitcoinProofs.Crypto.Schnorr.verify_purity' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verify_purity

end BitcoinProofs.Crypto.Schnorr
