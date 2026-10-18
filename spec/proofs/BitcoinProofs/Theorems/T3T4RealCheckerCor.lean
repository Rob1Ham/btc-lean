import Bitcoin.Capstone.RealChecker
import Bitcoin.Crypto.Ecdsa.Verify
import Bitcoin.Crypto.Schnorr.Verify

/-!
# BitcoinProofs.Theorems.T3T4RealCheckerCor — THM-051, the real-checker
# instantiation tier

C4 portfolio row **THM-051** (Tier 4, "abstraction-instance consistency"):

> the `InputAuth`/`VerifySig` interfaces are instantiated by the actual
> tower such that `VerifySig`-level determinism holds *(interface lemmas,
> not crypto proofs)*.

proved the **seam contract** — `checker_ext`,
`checker_eq_of_entry_eq`, `ecdsaEntry_execData_independent`, the
`schnorrEntry` gates — over an **abstract** `verify` parameter (36 pins).
The **real tower** was then wired into that seam:
`realEcdsaEntry` (lax-ECDSA `verifyImpl`, 215/215 conformance) and
`realSchnorrEntry` (X02 BIP340 `verifyImpl`, 19/19 official vectors),
assembled as `realCheckerFullOf` = `txCheckerOf` with both real entries.
This module proves the missing **seam ↔ tower consistency** lemmas for the
REAL instances, plus the two facts that only the real wiring makes
stateable:

* **X02-non-interference** (A5/A6): `realCheckerFullOf` and
  `realCheckerOf` are *verdict-identical* checkers at
  `verifyScriptFull` — X02's Unit-3 Schnorr wiring (with the BIP342
  sighash still the fail-closed `none` stand-in) changed zero
  interpreter verdicts. The one-parameter X03 flip of
  `sighashSchnorr` is therefore a **single, verdict-visible** change
  point.
* **fail-closed totality** (A4): until X03 lands, the live consensus
  checker **cannot accept any Schnorr signature** (no false accepts) —
  every gate (sigversion / 32-byte key / 64-65-byte sig /
  65th-byte ≠ SIGHASH_DEFAULT) fails closed *upstream* of the real
  `verifyImpl`, and the stand-in digest is `none`.

## reduction discipline (decide-cannot-reduce-WF-defs)

No theorem here reduces `verifyImpl` (either lane) into the field/EC
arithmetic: `verifyImpl` is treated as an opaque total function with
X02's pinned facts, and every proof is a **congruence** (A0/A1/A2/A7),
a **gate corollary** of ∀-`verify` theorems (A3), or a
**fail-closed totality** argument that never reaches the EC math (A4).
The only funext on an entry is A5's (carrying `Quot.sound`), which
asserts that fail-closed Schnorr slot and X02's stand-in-digest
slot are the *same* function — both are `fun _ _ _ _ => false` up to the
seam's own gates.

## Statement-fidelity notes (sanctioned interface-change path: none)

The natural THM-051 reading "the real checker's verdict depends only on
(sig, pk, digest)" is **refutable as stated** for the *current* wiring:
with `sighashSchnorr = fun _ _ _ => none` the Schnorr verdict does not
depend on the digest at all (it is constantly `false`, A4). A5+A4
document this rather than patching it: the *ECDSA* lane carries the
purity statement (A1/A2/A7), the *Schnorr* lane carries fail-closed
totality (A4), and A6 is exactly the statement that the two wirings are
verdict-identical **today**. When X03 flips the sighash slot, A4/A5/A6
are the theorems that must be re-visited (their statements will change
verdict-visibly); every other row is flip-invariant.
-/

namespace BitcoinProofs.Theorems.T3T4RealCheckerCor

open Bitcoin.Crypto.Seam Bitcoin.Crypto.Seam.Entry Bitcoin.Crypto.Seam.Der
  Bitcoin.Capstone.RealChecker Bitcoin.Interpreter Bitcoin.Data

/-! ## A0 — the tower instantiation, definitionally pinned (THM-051
"instantiated by the actual tower") -/

/-- THM-051 (wiring pin, ECDSA lane): the abstract `verify` parameter of
`ecdsaEntry` in the real wiring IS lax-ECDSA `verifyImpl`
(`Bitcoin.Crypto.Ecdsa.Verify.verifyImpl`, 215/215 conformance, Core
`CPubKey::Verify` semantics), with sighash dispatch and
`hasAmount = true` (the capstone always supplies the spent coin). -/
theorem realEcdsaEntry_verify_is_w14b (tx : Tx) (nIn : Nat) (amount : Amount) :
    realEcdsaEntry tx nIn amount
      = ecdsaEntry Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
          (sighashDispatch tx nIn amount) true := rfl

/-- THM-051 (wiring pin, Schnorr lane): the abstract `verify` parameter of
`schnorrEntry` in the real wiring IS X02's BIP340 `verifyImpl`
(`Bitcoin.Crypto.Schnorr.Verify.verifyImpl`, 19/19 official vectors),
with the BIP342 sighash still the fail-closed `none` stand-in (X03/X04
slot). -/
theorem realSchnorrEntry_verify_is_x02 :
    realSchnorrEntry
      = schnorrEntry Bitcoin.Crypto.Schnorr.Verify.verifyImpl
          (fun _ _ _ => none) := rfl

/-! ## A1 — real-ECDSA-lane purity (THM-051 "VerifySig-level
determinism", real instance) -/

/-- **THM-051 (real-ECDSA purity)**: the real ECDSA entry's verdict is a
pure function of exactly `(tx, nIn, amount, sig, pk, scriptCode,
sigversion)` — equal arguments give equal verdicts. Proof is pure
congruence (the verifier is never unfolded), and the
`ScriptExecutionData` argument is irrelevant even before A2 (the adapter
ignores it definitionally). -/
theorem realEcdsaEntry_pure (tx₁ tx₂ : Tx) (n₁ n₂ : Nat) (am₁ am₂ : Amount)
    (sig pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (htx : tx₁ = tx₂) (hn : n₁ = n₂) (ham : am₁ = am₂) :
    (realEcdsaEntry tx₁ n₁ am₁).checkECDSASignature sig pk code v d
      = (realEcdsaEntry tx₂ n₂ am₂).checkECDSASignature sig pk code v d := by
  rw [htx, hn, ham]

/-- Same purity for the real-ECDSA arguments of the entry alone: equal
`(sig, pk, code, v)` give equal verdicts (the entry functions are the
only channel from the checker to the interpreter;
`checker_eq_of_entry_eq` then transports verdict equality through
`verifyScriptFull`). -/
theorem realEcdsaEntry_congr_args (tx : Tx) (nIn : Nat) (amount : Amount)
    (sig₁ sig₂ pk₁ pk₂ code₁ code₂ : ByteArray) (v₁ v₂ : SigVersion)
    (d₁ d₂ : ScriptExecutionData)
    (hs : sig₁ = sig₂) (hp : pk₁ = pk₂) (hc : code₁ = code₂) (hv : v₁ = v₂) :
    (realEcdsaEntry tx nIn amount).checkECDSASignature sig₁ pk₁ code₁ v₁ d₁
      = (realEcdsaEntry tx nIn amount).checkECDSASignature sig₂ pk₂ code₂ v₂ d₂ := by
  rw [hs, hp, hc, hv]
  -- the residual `… d₁ = … d₂` is the seam's execdata-independence (A2),
  -- definitionally: both sides are `ecdsaVerdict … v₂ sig₂ pk₂ code₂`.
  exact ecdsaEntry_execData_independent Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
    (sighashDispatch tx nIn amount) true sig₂ pk₂ code₂ v₂ d₁ d₂

/-! ## A2 — execdata independence, real instances (seam contract
`ecdsaEntry_execData_independent` is a ∀-`verify` theorem) -/

/-- **THM-051 (execdata independence, real ECDSA)**: the real ECDSA lane
cannot see the interpreter's `ScriptExecutionData` — Core's
`CheckECDSASignature` takes none (interpreter.cpp:1701-1706 @cce32b168),
and the real wiring preserves the seam contract. Instantiation of
∀-`verify` theorem at `verifyImpl`; no EC reduction. -/
theorem realEcdsaEntry_execData_independent (tx : Tx) (nIn : Nat) (amount : Amount)
    (sig pk code : ByteArray) (v : SigVersion) (d₁ d₂ : ScriptExecutionData) :
    (realEcdsaEntry tx nIn amount).checkECDSASignature sig pk code v d₁
      = (realEcdsaEntry tx nIn amount).checkECDSASignature sig pk code v d₂ :=
  ecdsaEntry_execData_independent Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
    (sighashDispatch tx nIn amount) true sig pk code v d₁ d₂

/-- Same for the both-lanes assembly `realCheckerFullOf` (via `txCheckerOf`'s
ECDSA field, definitionally `ecdsaEntry`'s). -/
theorem realCheckerFullOf_ecdsa_execData_independent (tx : Tx) (nIn : Nat) (amount : Amount)
    (sig pk code : ByteArray) (v : SigVersion) (d₁ d₂ : ScriptExecutionData) :
    (realCheckerFullOf tx nIn amount).base.checkECDSASignature sig pk code v d₁
      = (realCheckerFullOf tx nIn amount).base.checkECDSASignature sig pk code v d₂ :=
  ecdsaEntry_execData_independent Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
    (sighashDispatch tx nIn amount) true sig pk code v d₁ d₂

/-! ## A3 — the gates hold at the REAL verifiers (corollaries of the
∀-`verify` seam theorems) -/

/-- THM-051 (gate, real Schnorr; SWT-054-analogue TPR slot): only 64- and
65-byte signatures can reach the real BIP340 verifier — size gate
(`schnorrEntry_size_gate`, interpreter.cpp:1736-1737) instantiated at
X02's `verifyImpl`. -/
theorem realSchnorrEntry_size_gate (sig pk : ByteArray) (v : SigVersion)
    (d : ScriptExecutionData) (h : sig.size ≠ 64 ∧ sig.size ≠ 65) :
    realSchnorrEntry.checkSchnorrSignature sig pk v d = false :=
  schnorrEntry_size_gate Bitcoin.Crypto.Schnorr.Verify.verifyImpl
    (fun _ _ _ => none) sig pk v d h

/-- THM-051 (gate, real Schnorr): a non-taproot/tapscript sigversion or a
non-32-byte key fails closed BEFORE the real verifier is reached
(interpreter.cpp:1731-1735; Core `assert`s these — consensus functions
fail closed). -/
theorem realSchnorrEntry_ver_key_gate (sig pk : ByteArray) (v : SigVersion)
    (d : ScriptExecutionData)
    (h : ¬(v = SigVersion.taproot ∨ v = SigVersion.tapscript) ∨ pk.size ≠ 32) :
    realSchnorrEntry.checkSchnorrSignature sig pk v d = false := by
  simp only [realSchnorrEntry, schnorrEntry, schnorrVerdict]
  rcases h with h | h
  · rw [if_neg (by simp [h])]
  · by_cases hV : (v = SigVersion.taproot || v = SigVersion.tapscript) = true
    · rw [if_pos hV, if_neg h]
    · rw [if_neg hV]

/-- THM-051 (gate, real Schnorr; TPR-072-analogue): a 65-byte signature
whose trailing hashtype byte IS `SIGHASH_DEFAULT` is a hashtype error —
rejected before the real verifier (interpreter.cpp:1741-1742). -/
theorem realSchnorrEntry_default_hashtype_rejected (sig pk : ByteArray)
    (v : SigVersion) (d : ScriptExecutionData)
    (h : sig.size = 65 ∧ sig[64]! = SIGHASH_DEFAULT) :
    realSchnorrEntry.checkSchnorrSignature sig pk v d = false := by
  simp only [realSchnorrEntry, schnorrEntry, schnorrVerdict]
  split
  · split
    · exact schnorrHashtype_65_default_rejected sig h.1 h.2 ▸ rfl
    · rfl
  · rfl

/-- THM-051 (gate, real ECDSA; SWT-054): empty signatures fail closed
before any EC math — `ecdsaEntry_empty_sig_false` (a ∀-`verify`
theorem) at real verifier. -/
theorem realEcdsaEntry_empty_sig_false (tx : Tx) (nIn : Nat) (amount : Amount)
    (pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    (realEcdsaEntry tx nIn amount).checkECDSASignature
        ByteArray.empty pk code v d = false :=
  ecdsaEntry_empty_sig_false Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
    (sighashDispatch tx nIn amount) true pk code v d

/-- THM-051 (gate, real ECDSA): an invalid pubkey header (not 33 or 65
bytes / bad prefix) fails before the signature is looked at
(interpreter.cpp:1703-1704) — at the real verifier. -/
theorem realEcdsaEntry_badPubKey_false (tx : Tx) (nIn : Nat) (amount : Amount)
    (sig pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (h : isValidPubKey pk = false) :
    (realEcdsaEntry tx nIn amount).checkECDSASignature sig pk code v d = false :=
  ecdsaEntry_badPubKey_false Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
    (sighashDispatch tx nIn amount) true sig pk code v d h

/-! ## A4 — fail-closed totality: no false Schnorr accepts (until X03) -/

/-- **THM-051 (fail-closed totality, the honest X02-state pin)**: the live
consensus Schnorr entry — real BIP340 `verifyImpl` behind gates,
BIP342 sighash still the `none` stand-in — returns `false` for EVERY
signature, key, sigversion and execdata. Every gate fails closed
*upstream* of the real verifier (sigversion / 32-byte key / 64-65-byte
sig / 65th-byte ≠ DEFAULT), and the only remaining path dies at the
missing-digest fail-closed (`none => false`,
interpreter.cpp:1745-1747). Consequence: **no Schnorr signature can be
accepted until X03 lands the BIP341/342 sighash** — no false accepts,
by construction. (The Taproot inputs of the pipeline never reach
here anyway: `verifyInput` routes v1-witness programs to the
`unjudgedTaproot` lane before the checker.) -/
theorem realSchnorrEntry_fail_closed (sig pk : ByteArray) (v : SigVersion)
    (d : ScriptExecutionData) :
    realSchnorrEntry.checkSchnorrSignature sig pk v d = false := by
  simp only [realSchnorrEntry, schnorrEntry, schnorrVerdict]
  by_cases hV : (v = SigVersion.taproot || v = SigVersion.tapscript) = true
  · rw [if_pos hV]
    by_cases hP : pk.size = 32
    · rw [if_pos hP]
      -- the sigversion/key gates passed; the only remaining path dies at
      -- the missing-digest fail-closed: the stand-in sighash is
      -- `fun _ _ _ => none`, so `schnorrHashtype`'s match on it is `none`.
      cases hs : schnorrHashtype sig with
      | none => rfl
      | some p =>
        cases p with
        | mk body ht => rfl
    · rw [if_neg hP]
  · rw [if_neg hV]

/-- Same for the both-lanes assembly `realCheckerFullOf`: its Schnorr
lane is `schnorrVerdict` at X02's real `verifyImpl` with the stand-in
digest — also constantly `false`. -/
theorem realCheckerFullOf_schnorr_fail_closed (tx : Tx) (nIn : Nat) (amount : Amount)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    (realCheckerFullOf tx nIn amount).base.checkSchnorrSignature sig pk v d = false :=
  realSchnorrEntry_fail_closed sig pk v d

/-- The fail-closed Schnorr lane is execdata-independent for a trivial
reason (it is constantly `false`) — the honest form of TPR-072's
`schnorrEntry_execData_plumbed` at the current wiring: the plumbing is
real, the digest it would plumb does not exist yet. -/
theorem realCheckerFullOf_schnorr_execData_independent (tx : Tx) (nIn : Nat)
    (amount : Amount) (sig pk : ByteArray) (v : SigVersion)
    (d₁ d₂ : ScriptExecutionData) :
    (realCheckerFullOf tx nIn amount).base.checkSchnorrSignature sig pk v d₁
      = (realCheckerFullOf tx nIn amount).base.checkSchnorrSignature sig pk v d₂ := by
  rw [realCheckerFullOf_schnorr_fail_closed, realCheckerFullOf_schnorr_fail_closed]

/-! ## A5/A6 — X02-non-interference: `realCheckerFullOf` ≡
`realCheckerOf` at every interpreter verdict -/

/-- `realCheckerOf` (the checker `validateBlock` actually binds)
carries the fail-closed Schnorr slot: its `checkSchnorrSignature`
is literally the constant-`false` function. -/
theorem realCheckerOf_schnorr_is_const_false (tx : Tx) (nIn : Nat) (amount : Amount) :
    (realCheckerOf tx nIn amount).base.checkSchnorrSignature
      = (fun _ _ _ _ => false) := rfl

/-- **X02-non-interference (checker half)**: the both-real-entries
assembly `realCheckerFullOf` and ECDSA-only `realCheckerOf` are
the **same** `BaseSignatureChecker`. Their ECDSA entries are the same
`ecdsaEntry verifyImpl (sighashDispatch …) true` by definition; their
Schnorr entries are the same function by A4 (X02's stand-in-digest
`none` slot and constant-`false` slot agree on every argument).
This funext is the one point where the fail-closed totality pin is
load-bearing. -/
theorem realCheckerFullOf_base_eq (tx : Tx) (nIn : Nat) (amount : Amount) :
    (realCheckerFullOf tx nIn amount).base = (realCheckerOf tx nIn amount).base := by
  -- `checker_eq_of_entry_eq` (seam contract): two checkers agreeing
  -- pointwise on both entry points ARE the same checker.
  apply checker_eq_of_entry_eq (c₁ := (realCheckerFullOf tx nIn amount).base)
    (c₂ := (realCheckerOf tx nIn amount).base)
  · -- ECDSA entries: definitionally `ecdsaEntry verifyImpl dispatch true`
    -- (A0), both projections delta-beta-reduce to the same `ecdsaVerdict`.
    intro sig pk code v d; rfl
  · -- Schnorr entries: both constantly `false` (the slot by `rfl`,
    -- X02's slot by the fail-closed totality A4)
    intro sig pk v d
    exact realSchnorrEntry_fail_closed sig pk v d

/-- **X02-non-interference (checker, full record)**: same `base`, and the
`LocktimeEnv` is the same function of `(tx, nIn)` (real version,
locktime, this input's nSequence). -/
theorem realCheckerFullOf_eq (tx : Tx) (nIn : Nat) (amount : Amount) :
    realCheckerFullOf tx nIn amount = realCheckerOf tx nIn amount := by
  have hb := realCheckerFullOf_base_eq tx nIn amount
  have he : (realCheckerFullOf tx nIn amount).env
      = (realCheckerOf tx nIn amount).env := rfl
  -- both records are the same `ScriptChecker.mk` of the same `.base`
  -- (A5) and the same `.env` (the real locktime environment, `rfl`)
  rcases hF : realCheckerFullOf tx nIn amount with ⟨b₁, e₁⟩
  rcases hR : realCheckerOf tx nIn amount with ⟨b₂, e₂⟩
  rw [hF, hR] at hb he
  simp only [ScriptChecker.mk.injEq]
  exact ⟨hb, he⟩

/-- **X02-non-interference (THE pin)**: `verifyScriptFull` cannot
distinguish `realCheckerFullOf` from `realCheckerOf` — X02's Unit-3
Schnorr wiring (real BIP340 verifier behind gates, BIP342 sighash
still fail-closed) changed **zero** interpreter verdicts on any script,
witness stack, flags, policy or fuel. The one-parameter X03 flip of
`sighashSchnorr` is therefore the single verdict-visible change point of
the Taproot lane. -/
theorem verifyScriptFull_realCheckerFullOf_eq_realCheckerOf
    (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (w : WitnessStack) (tx : Tx) (nIn : Nat) (amount : Amount) :
    verifyScriptFull fuel flags pol ss spk w (realCheckerFullOf tx nIn amount)
      = verifyScriptFull fuel flags pol ss spk w (realCheckerOf tx nIn amount) := by
  rw [realCheckerFullOf_eq tx nIn amount]

/-! ## A7 — THM-051 purity composite for the real wiring -/

/-- **THM-051 (purity composite)**: the both-lanes real checker's
consensus-visible behavior is a pure function of
`(tx, nIn, amount, sig, pk, code, sigversion)` — the ECDSA entry by
congruence (A1), the Schnorr entry by fail-closed totality (A4).
`ScriptExecutionData` is invisible to both lanes (A2). Together with
`checker_eq_of_entry_eq` this is the "VerifySig-level determinism"
of the portfolio row, now over the REAL tower. -/
theorem realCheckerFullOf_pure (tx₁ tx₂ : Tx) (n₁ n₂ : Nat) (am₁ am₂ : Amount)
    (sig pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (htx : tx₁ = tx₂) (hn : n₁ = n₂) (ham : am₁ = am₂) :
    (realCheckerFullOf tx₁ n₁ am₁).base.checkECDSASignature sig pk code v d
      = (realCheckerFullOf tx₂ n₂ am₂).base.checkECDSASignature sig pk code v d := by
  rw [htx, hn, ham]

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realEcdsaEntry_verify_is_w14b' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realEcdsaEntry_verify_is_w14b
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realSchnorrEntry_verify_is_x02' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realSchnorrEntry_verify_is_x02
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realEcdsaEntry_pure' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realEcdsaEntry_pure
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realEcdsaEntry_congr_args' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realEcdsaEntry_congr_args
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realEcdsaEntry_execData_independent' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realEcdsaEntry_execData_independent
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realCheckerFullOf_ecdsa_execData_independent' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realCheckerFullOf_ecdsa_execData_independent
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realSchnorrEntry_size_gate' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realSchnorrEntry_size_gate
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realSchnorrEntry_ver_key_gate' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realSchnorrEntry_ver_key_gate
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realSchnorrEntry_default_hashtype_rejected' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realSchnorrEntry_default_hashtype_rejected
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realEcdsaEntry_empty_sig_false' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realEcdsaEntry_empty_sig_false
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realEcdsaEntry_badPubKey_false' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realEcdsaEntry_badPubKey_false
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realSchnorrEntry_fail_closed' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realSchnorrEntry_fail_closed
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realCheckerFullOf_schnorr_fail_closed' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realCheckerFullOf_schnorr_fail_closed
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realCheckerFullOf_schnorr_execData_independent' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realCheckerFullOf_schnorr_execData_independent
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realCheckerOf_schnorr_is_const_false' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realCheckerOf_schnorr_is_const_false
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realCheckerFullOf_base_eq' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realCheckerFullOf_base_eq
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realCheckerFullOf_eq' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realCheckerFullOf_eq
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.verifyScriptFull_realCheckerFullOf_eq_realCheckerOf' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyScriptFull_realCheckerFullOf_eq_realCheckerOf
/-- info: 'BitcoinProofs.Theorems.T3T4RealCheckerCor.realCheckerFullOf_pure' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realCheckerFullOf_pure

end BitcoinProofs.Theorems.T3T4RealCheckerCor
