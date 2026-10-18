import Bitcoin.Interpreter.Rules
import Bitcoin.Interpreter.SigOps
import Bitcoin.Script.Tapscript.LeafVersion

/-! # PDW19.lean — items TOP-91..95
(PDW19, RC21, 2026-10-17; claim f216df2; resumed post
model-rotation from bank 522cd8d).

Four row-facing theorem groups, one per claimed `implemented`
rules.yaml row (tag-on-def / mismatch repair class, route B of
PDW11/12/16):

* **SCR-142** `verifyWitnessProgram_taproot_gate_silent_ok`
  (Interpreter/Rules.lean:379, untagged there) — TAPROOT flag off ⇒
  v1-32 non-P2SH spend returns `.ok` silently.
* **SCR-144** `verifyWitnessProgram_keypath` (Rules.lean:393;
  core twin carries a foreign `INV-072` tag) — key-path verdict =
  the BIP340 checker's, fail-closed `.fail .schnorrSig`.
* **SCR-149** `verifyTaprootLeafDispatch_upgradable_ok_face` /
  `_discourage_face` (LeafVersion.lean:179/:165; `interpreter.cpp`
  :1995-1998) — a non-0xc0 TAPROOT leaf version is upgradable: success
  under `discourageUpgradableTaprootVersion = false`, the named policy
  failure under `true`. (The earlier bug tagged the v ≥ 2 *witness
  version* arm as SCR-149; that arm is SCR-151 below.)
* **SCR-151** `verifyWitnessProgram_upgradable_leaf_ok` /
  `_discourage` / `_ok_iff` (Rules.lean:410) — witness version ≥ 2
  is upgradable under `discourageUpgradableWitnessProgram`.
* **SWT-026** `witnessSigOps_p2wsh` (SigOps.lean:206, untagged
  there; core tags sit on :92/:102) — v0-32 witness sigops = the
  last witness item's accurate count.

Each statement is the core target VERBATIM (auto-bound `flags` /
`version` made explicit; propositionally identical). Zero core
writes; the `@[rule]` tags ride these theorems. -/

open Bitcoin.Data Bitcoin.Activation
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)
open Bitcoin.Interpreter

namespace BitcoinProofs.AF.PDW19

open Bitcoin.Interpreter

/-- SCR-142: TAPROOT-gate silent activation (Rules.lean:379 verbatim). -/
@[rule "SCR-142"]
theorem verifyWitnessProgram_taproot_gate_silent_ok
    (fuel : Nat) (witness : WitnessStack) (program : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (isP2SH : Bool) (h32 : program.size = 32) (hp2 : isP2SH = false)
    (hnotap : flags.taproot = false) :
    verifyWitnessProgram fuel witness 1 program flags pol chk isP2SH
      = VerifyOutcome.ok := by
  simp [verifyWitnessProgram, hnotap, h32, hp2]

/-- SCR-144: key-path verdict = checker's (Rules.lean:393 verbatim),
plus the fail-closed face (rejection ⇒ `.fail .schnorrSig`). -/
@[rule "SCR-144"]
theorem verifyWitnessProgram_keypath
    (fuel : Nat) (sig program : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (isP2SH : Bool) (htap : flags.taproot = true)
    (h32 : program.size = 32) (hp2 : isP2SH = false) :
    verifyWitnessProgram fuel [sig] 1 program flags pol chk isP2SH
      = if chk.base.checkSchnorrSignature sig program SigVersion.taproot
              { (default : ScriptExecutionData) with
                annexInit := true, annexPresent := false,
                annexHash := (default : ScriptExecutionData).annexHash }
        then VerifyOutcome.ok else VerifyOutcome.fail .schnorrSig := by
  simp [verifyWitnessProgram, htap, h32, hp2]

theorem verifyWitnessProgram_keypath_fail_closed
    (fuel : Nat) (sig program : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (isP2SH : Bool) (htap : flags.taproot = true)
    (h32 : program.size = 32) (hp2 : isP2SH = false)
    (hchk : chk.base.checkSchnorrSignature sig program SigVersion.taproot
              { (default : ScriptExecutionData) with
                annexInit := true, annexPresent := false,
                annexHash := (default : ScriptExecutionData).annexHash }
            = false) :
    verifyWitnessProgram fuel [sig] 1 program flags pol chk isP2SH
      = VerifyOutcome.fail .schnorrSig := by
  simp [verifyWitnessProgram, htap, h32, hp2, hchk]

/-! ## SCR-149 — the non-0xc0 TAPROOT leaf-version fall-through
(Core `interpreter.cpp:1995-1998`)

The script-path tail masks the control byte with `0xfe` and compares it
to `0xc0`. Every other leaf version leaves the tapscript arm and reaches
the upgradable `else`: `DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` (policy)
fails, otherwise the spend succeeds. The prior version of this file
tagged the *witness version* ≥ 2 arm (SCR-151) as SCR-149; the row faces
below are the genuine leaf-version statements, re-exported from
`Bitcoin.Script.Tapscript.LeafVersion`. -/

/-- SCR-149: a non-0xc0 (upgradable) TAPROOT leaf version succeeds when
the DISCOURAGE policy hook is off. -/
@[rule "SCR-149"]
theorem verifyTaprootLeafDispatch_upgradable_ok_face
    (fuel : Nat) (items : WitnessStack) (control script : ByteArray)
    (witness : WitnessStack) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker)
    (hnot : Bitcoin.Script.Tapscript.isTapscriptLeaf control = false)
    (hnd : pol.discourageUpgradableTaprootVersion = false) :
    Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch fuel items control
        script witness flags pol chk
      = VerifyOutcome.ok :=
  Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_upgradable_ok fuel
    items control script witness flags pol chk hnot hnd

/-- SCR-149 (policy-on face): a non-0xc0 TAPROOT leaf version fails with
Core's exact `discourageUpgradableTaprootVersion` error when the policy
hook is set. -/
@[rule "SCR-149"]
theorem verifyTaprootLeafDispatch_upgradable_discourage_face
    (fuel : Nat) (items : WitnessStack) (control script : ByteArray)
    (witness : WitnessStack) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker)
    (hnot : Bitcoin.Script.Tapscript.isTapscriptLeaf control = false)
    (hd : pol.discourageUpgradableTaprootVersion = true) :
    Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch fuel items control
        script witness flags pol chk
      = VerifyOutcome.fail ExecError.discourageUpgradableTaprootVersion :=
  Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_upgradable_discourage
    fuel items control script witness flags pol chk hnot hd

/-- SCR-151: v ≥ 2 upgradable witness versions succeed
(Rules.lean:410 verbatim; Core interpreter.cpp:2002-2008). -/
@[rule "SCR-151"]
theorem verifyWitnessProgram_upgradable_leaf_ok
    (fuel : Nat) (witness : WitnessStack) (program : ByteArray)
    (version : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (hv2 : 2 ≤ version) (hpa : isPayToAnchor version program = false)
    (hnodisc : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel witness version program flags pol chk isP2SH
      = VerifyOutcome.ok := by
  have hv0 : ¬(version = 0) := by omega
  have hv1 : ¬(version = 1 ∧ program.size = 32 ∧ (!isP2SH) = true) := by
    intro h; rcases h with ⟨h1, _⟩; omega
  have hpa' : ¬((!isP2SH) = true ∧ isPayToAnchor version program = true) := by
    intro h; rcases h with ⟨_, h2⟩
    rw [hpa] at h2
    exact absurd h2 (by decide)
  have hnodisc' : ¬(pol.discourageUpgradableWitnessProgram = true) := by
    rw [hnodisc]; decide
  unfold verifyWitnessProgram
  rw [ite_eq_right hv0, ite_eq_right hv1, ite_eq_right hpa', ite_eq_right hnodisc']

/-- SCR-151 (discourage-on face): with the DISCOURAGE policy hook set, a
v ≥ 2 upgradable witness version fails with the exact Core error
`discourageUpgradableWitnessProgram` (interpreter.cpp:2002-2008). -/
@[rule "SCR-151"]
theorem verifyWitnessProgram_upgradable_leaf_discourage
    (fuel : Nat) (witness : WitnessStack) (program : ByteArray)
    (version : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (hv2 : 2 ≤ version) (hpa : isPayToAnchor version program = false)
    (hdisc : pol.discourageUpgradableWitnessProgram = true) :
    verifyWitnessProgram fuel witness version program flags pol chk isP2SH
      = VerifyOutcome.fail .discourageUpgradableWitnessProgram := by
  have hv0 : ¬(version = 0) := by omega
  have hv1 : ¬(version = 1 ∧ program.size = 32 ∧ (!isP2SH) = true) := by
    intro h; rcases h with ⟨h1, _⟩; omega
  have hpa' : ¬((!isP2SH) = true ∧ isPayToAnchor version program = true) := by
    intro h; rcases h with ⟨_, h2⟩
    rw [hpa] at h2
    exact absurd h2 (by decide)
  unfold verifyWitnessProgram
  rw [ite_eq_right hv0, ite_eq_right hv1, ite_eq_right hpa', ite_eq_left hdisc]

/-- SCR-151 (full row): for a v ≥ 2 non-P2A witness version the verdict
is `ok` exactly when the DISCOURAGE policy flag is off — the flag *is*
the policy, both directions. -/
@[rule "SCR-151"]
theorem verifyWitnessProgram_upgradable_leaf_ok_iff
    (fuel : Nat) (witness : WitnessStack) (program : ByteArray)
    (version : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (hv2 : 2 ≤ version) (hpa : isPayToAnchor version program = false) :
    verifyWitnessProgram fuel witness version program flags pol chk isP2SH
        = VerifyOutcome.ok
      ↔ pol.discourageUpgradableWitnessProgram = false := by
  cases hd : pol.discourageUpgradableWitnessProgram
  · exact ⟨fun _ => rfl, fun _ =>
      verifyWitnessProgram_upgradable_leaf_ok fuel witness program version
        flags pol chk isP2SH hv2 hpa hd⟩
  · constructor
    · intro hok
      have hf := verifyWitnessProgram_upgradable_leaf_discourage fuel witness
        program version flags pol chk isP2SH hv2 hpa hd
      rw [hf] at hok
      exact absurd hok (by decide)
    · intro hf
      exact absurd hf (by decide)

/-- SWT-026: v0-32 counts the last witness item (SigOps.lean:206
verbatim; empty witness = 0 total-model face). -/
@[rule "SWT-026"]
theorem witnessSigOps_p2wsh (program : ByteArray) (witness : List ByteArray)
    (h : program.size = 32) :
    Bitcoin.Interpreter.SigOps.witnessSigOps 0 program witness =
      (match witness.getLast? with
       | some script => Bitcoin.Interpreter.SigOps.witnessScriptSigOps script
       | none => 0) := by
  unfold Bitcoin.Interpreter.SigOps.witnessSigOps
  rw [ite_eq_left rfl, ite_eq_right (by intro hc; rw [h] at hc; simp at hc),
    ite_eq_left h]
  rfl

end BitcoinProofs.AF.PDW19
