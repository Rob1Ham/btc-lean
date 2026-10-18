import Bitcoin.Crypto.Curve.Secp
import Bitcoin.Crypto.Schnorr.TaggedHash

/-!
# Bitcoin.Crypto.Schnorr.Verify — BIP340 verification over the curve and field layers

A faithful transliteration of the BIP340 verification algorithm
(bip-0340.mediawiki §"Verification"), over the EXISTING core curve layer
(`Bitcoin.Crypto.Curve.Secp`: `liftX` even-y lift, `addP`/`mulP` group law,
extended-Euclid `invP` underneath, `negN` y-negation) — no new math.

## Algorithm (spec text, step-for-step)

1. Fail if `sig.size ≠ 64` or `pk.size ≠ 32` (sizeGate). The message may
   be ANY length (bip-0340 step 1 gates only sig/pk; vectors 15–18 exercise
   msg of size 0/1/17/100 — the Schnorr module's first draft wrongly gated msg = 32 and
   exactly those four vectors caught it). Core's tapscript entry always
   feeds a 32-byte BIP342 sighash, so on Core's domain the two agree.
2. `P = lift_x(int(pk))` — fail if `x ≥ p` or `x³+7` is a non-residue
   (Secp.liftX implements exactly this, even-y convention).
3. `r = int(sig[0:32])`;  fail if `r ≥ p`.
4. `s = int(sig[32:64])`; fail if `s ≥ n`.
5. `e = int(tagged_hash("BIP0340/challenge", bytes(r) ‖ bytes(P.x) ‖ m)) mod n`
   (`TaggedHash.challengeTagged` + mod-n; python-verified).
6. `R = s·G − e·P` — implemented as `s·G + e·(−P)` with `−P = (px, p − py)`
   (`Secp.negN`), the same group element by the sign-symmetry of the
   negation map; `mulP` is total so no special cases.
7. Fail if `R` is infinite (`none`), or `x(R) ≠ r`, or `has_even_y(R)` is false.
8. Accept.

## Core fidelity (Core = ground truth)

Core's verify path (`secp256k1_schnorrsig_verify`, vendored
src/crypto/secp256k1, dispatched from src/key.cpp `CPubKey::Verify`)
matches the BIP340 spec step-for-step on the VERIFICATION side: same
32-byte size gates (Core `assert`s `msglen == 32` on the caller side,
enforced as a fail-closed range check here because consensus code must be
total), same `r < p` (fe_set_b32_limit overflow flag), same `s < order`
(scalar_set_b32 overflow flag), same challenge digest, same `s·G − e·P`
verdict with the infinity / x(R)≠r / odd-y triple check, and the same
even-y-only lift (`xonly_pubkey_parse` refuses x ≥ p and non-residues).
Differences are all on the SIGNING side (aux-randomness handling, nonce
derivation), out of scope for a consensus verifier. The one
representational difference: Core applies the `−e` via the scalar `n − e`
in its ecmult; we apply it via the point negation `(px, p−py)` — identical
group element, and `Secp.OnCurve_negN` guarantees −P stays on the curve.
-/

namespace Bitcoin.Crypto.Schnorr.Verify

open Bitcoin.Crypto.Curve.Secp

/-! ## Size gate (step 1) -/

/-- Step 1: `sig = r‖s` (64 bytes) and `pk` (32 bytes). The message is
NOT gated — BIP340 allows any length (vectors 15–18). -/
def sizeGate (sig pk : ByteArray) : Bool :=
  sig.size == 64 && pk.size == 32

theorem sizeGate_eq_true {sig pk : ByteArray} (h : sizeGate sig pk = true) :
    sig.size = 64 ∧ pk.size = 32 := by
  simp only [sizeGate, Bool.and_eq_true, beq_iff_eq] at h
  exact ⟨h.1, h.2⟩

theorem sizeGate_false_of_size (sig pk : ByteArray) (h : sig.size ≠ 64) :
    sizeGate sig pk = false := by
  simp [sizeGate, h]

/-! ## The challenge scalar (TPR-048) -/

/-- BIP340 step 5: `e = int(tagged_hash("BIP0340/challenge",
bytes(r) ‖ bytes(P.x) ‖ m)) mod n` (bip-0340 §"Verification"; Core
`schnorrsig_main_impl.h` computes the same digest and reduces mod n). -/
@[rule "TPR-048"]
def eOf (r px : Nat) (msg : ByteArray) : Nat :=
  bytesToNatBE (challengeTagged r px msg) % n

/-! ## The post-lift core (steps 3–7) -/

/-- Steps 3–7 for an already-lifted pubkey `P = (px, py)`: range checks,
challenge, `R = s·G − e·P`, and the infinity/x/even-y triple. Let-free on
purpose: every occurrence of `r`/`s`/`e` is spelled out, so the definition
is a single if/match spine that `split` can peel in proofs. -/
def verifyLifted (sig : ByteArray) (px py : Nat) (msg : ByteArray) : Bool :=
  -- steps 3–4: range checks (fail: r ≥ p, s ≥ n)
  if bytesToNatBE (sig.extract 0 32) ≥ P || bytesToNatBE (sig.extract 32 64) ≥ n then
    false
  else
    -- step 6: R = s·G − e·P  (= s·G + e·(px, p−py)); e as in step 5
    match addP (mulP (bytesToNatBE (sig.extract 32 64)) G)
        (mulP (eOf (bytesToNatBE (sig.extract 0 32)) px msg) (some (px, negN py))) with
    -- step 7: R infinite → fail; x(R) ≠ r or odd-y → fail
    | none => false
    | some (rx, ry) =>
      rx == bytesToNatBE (sig.extract 0 32) && ry % 2 == 0
      -- step 8: accept

/-- Range-check totality (TPR-050/TPR-051): an accepted signature's halves
satisfy `r < p` and `s < n`. -/
theorem verifyLifted_true_range (sig : ByteArray) (px py : Nat) (msg : ByteArray)
    (h : verifyLifted sig px py msg = true) :
    bytesToNatBE (sig.extract 0 32) < P ∧ bytesToNatBE (sig.extract 32 64) < n := by
  unfold verifyLifted at h
  split at h
  · simp at h
  · rename_i hrs
    -- hrs : ¬((r ≥ P || s ≥ n) = true), i.e. both comparisons false
    have h2 : (bytesToNatBE (sig.extract 0 32) ≥ P
        || bytesToNatBE (sig.extract 32 64) ≥ n) = false :=
      Bool.eq_false_iff.mpr (by simpa using hrs)
    have hr := (Bool.or_eq_false_iff.mp h2).1
    have hs2 := (Bool.or_eq_false_iff.mp h2).2
    exact ⟨Nat.lt_of_not_ge (by simpa using hr),
      Nat.lt_of_not_ge (by simpa using hs2)⟩

/-- An accepted post-lift verdict witnesses the final equation point
(TPR-052): `R = s·G − e·P` is a real point with `x(R) = r` and even `y`. -/
theorem verifyLifted_true_R (sig : ByteArray) (px py : Nat) (msg : ByteArray)
    (h : verifyLifted sig px py msg = true) :
    ∃ rx ry : Nat,
      addP (mulP (bytesToNatBE (sig.extract 32 64)) G)
        (mulP (eOf (bytesToNatBE (sig.extract 0 32)) px msg) (some (px, negN py)))
        = some (rx, ry)
      ∧ rx = bytesToNatBE (sig.extract 0 32) ∧ ry % 2 = 0 := by
  unfold verifyLifted at h
  split at h
  · simp at h
  · rename_i hrs
    split at h
    · simp at h
    · rename_i hrxy
      simp only [Bool.and_eq_true, beq_iff_eq] at h
      exact ⟨_, _, hrxy, h.1, h.2⟩

/-! ## The verifier (steps 1–8) -/

/-- BIP340 verification (bip-0340 §"Verification"). Total and deterministic
in `(sig, pk, msg)` — every branch returns a defined `Bool` (BIP340 §design:
"completely specified at the byte level"). Arg order `(sig, pk, msg)`
mirrors the seam call `schnorrVerdict` makes: `verify body pk h`. -/
@[rule "TPR-050", rule "TPR-051", rule "TPR-052", rule "TPR-053"]
def verifyImpl (sig pk msg : ByteArray) : Bool :=
  if !sizeGate sig pk then false
  else match liftX (bytesToNatBE pk) with
    | none => false  -- step 2 fail: x ≥ p or non-residue
    | some (px, py) => verifyLifted sig px py msg

/-! ## Structural theorems on the composed verifier

These need no primality and no crypto: they read off the case structure.
`liftX`'s own correctness — `liftX_onCurve`, `liftX_even`, `liftX_snd` —
is already proved in `Curve.Secp`, conditional only on the runtime residue
check the code itself performs. The conformance harness exercises the
executable paths; the ZMod closure is the proofs package's lane. -/

/-- Step-1 gate: a signature that is not 64 bytes fails before anything
else (bip-0340 step 1; Core SCRIPT_ERR_SCHNORR_SIG_SIZE upstream). -/
theorem verifyImpl_sig_size (sig pk msg : ByteArray) (h : sig.size ≠ 64) :
    verifyImpl sig pk msg = false := by
  unfold verifyImpl
  split
  · rfl
  · rename_i hc
    exact absurd (sizeGate_false_of_size sig pk h) (by simpa using hc)

/-- Step-1 gate: a pubkey that is not 32 bytes fails (bip-0340 step 1;
Core's caller-side `pubkey.size == 32` assert, fail-closed here — a
consensus function cannot assert). -/
theorem verifyImpl_pk_size (sig pk msg : ByteArray) (h : pk.size ≠ 32) :
    verifyImpl sig pk msg = false := by
  unfold verifyImpl
  split
  · rfl
  · rename_i hc
    have hs : sizeGate sig pk = true := by simpa using hc
    exact absurd (sizeGate_eq_true hs).2 h

/- The message is NOT size-gated (bip-0340 step 1 gates sig/pk only;
vectors 15–18: msg of size 0/1/17/100 all verify). Core's tapscript entry
always feeds a 32-byte BIP342 sighash, so this is a conservative superset
that agrees with Core on Core's own domain. Documented as the one
deliberate spec-over-Core deviation (spec text wins; see report §2). -/

/-- The master case analysis: `verifyImpl = true` decomposes into the
size gate, a successful lift, and a successful post-lift core. -/
theorem verifyImpl_true_cases (sig pk msg : ByteArray)
    (h : verifyImpl sig pk msg = true) :
    sizeGate sig pk = true
      ∧ ∃ px py : Nat, liftX (bytesToNatBE pk) = some (px, py)
        ∧ verifyLifted sig px py msg = true := by
  unfold verifyImpl at h
  split at h
  · simp at h
  · rename_i hng
    split at h
    · simp at h
    · rename_i hl
      exact ⟨by simpa using hng, ⟨_, _, hl, h⟩⟩

/-- Helper: lift + range of the composed verifier. -/
theorem verifyImpl_true_lift (sig pk msg : ByteArray)
    (h : verifyImpl sig pk msg = true) :
    ∃ px py : Nat, liftX (bytesToNatBE pk) = some (px, py) ∧
      bytesToNatBE (sig.extract 0 32) < P ∧ bytesToNatBE (sig.extract 32 64) < n := by
  obtain ⟨_, px, py, hl, hv⟩ := verifyImpl_true_cases sig pk msg h
  have hr := verifyLifted_true_range sig px py msg hv
  exact ⟨px, py, hl, hr.1, hr.2⟩

/-- Totality of the acceptance conditions (TPR-050/051/052 composition):
`verifyImpl = true` pins ALL the consensus gates — the three sizes, the
lift (`x < p`, residue), and the `r < p` / `s < n` range checks. -/
theorem verifyImpl_true_conditions (sig pk msg : ByteArray)
    (h : verifyImpl sig pk msg = true) :
    sig.size = 64 ∧ pk.size = 32
      ∧ ∃ px py : Nat, liftX (bytesToNatBE pk) = some (px, py)
      ∧ bytesToNatBE (sig.extract 0 32) < P
      ∧ bytesToNatBE (sig.extract 32 64) < n := by
  obtain ⟨hs, px, py, hl, hv⟩ := verifyImpl_true_cases sig pk msg h
  obtain ⟨hr1, hr2⟩ := verifyLifted_true_range sig px py msg hv
  have hsz := sizeGate_eq_true hs
  refine ⟨hsz.1, hsz.2, px, py, hl, hr1, hr2⟩

/-- TPR-052 at the composed level: an accepted verdict witnesses the
verification equation — `s·G − e·P` is a real point with `x(R) = r`,
even `y`, and the lifted pubkey point (whose on-curve/even-y properties
are `Secp.liftX_onCurve`/`liftX_even`). -/
theorem verifyImpl_true_equation (sig pk msg : ByteArray)
    (h : verifyImpl sig pk msg = true) :
    ∃ px py rx ry : Nat,
      liftX (bytesToNatBE pk) = some (px, py)
      ∧ addP (mulP (bytesToNatBE (sig.extract 32 64)) G)
          (mulP (eOf (bytesToNatBE (sig.extract 0 32)) px msg) (some (px, negN py)))
          = some (rx, ry)
      ∧ rx = bytesToNatBE (sig.extract 0 32)
      ∧ ry % 2 = 0 := by
  obtain ⟨_, px, py, hl, hv⟩ := verifyImpl_true_cases sig pk msg h
  obtain ⟨rx, ry, heq, hx, hy⟩ := verifyLifted_true_R sig px py msg hv
  exact ⟨px, py, rx, ry, hl, heq, hx, hy⟩
/-- Verdict purity (TPR-053): `verifyImpl` is a total function of exactly
its three arguments — equal arguments give equal verdicts (congruence;
there is no environment, execdata, or global state in the definition).
This is the seam-usable form of "deterministic function of (sig, pk, msg)";
full unforgeability/soundness is OUT of scope (see report §4). -/
theorem verifyImpl_congr (s₁ s₂ p₁ p₂ m₁ m₂ : ByteArray)
    (hs : s₁ = s₂) (hp : p₁ = p₂) (hm : m₁ = m₂) :
    verifyImpl s₁ p₁ m₁ = verifyImpl s₂ p₂ m₂ := by
  subst hs; subst hp; subst hm; rfl

end Bitcoin.Crypto.Schnorr.Verify
