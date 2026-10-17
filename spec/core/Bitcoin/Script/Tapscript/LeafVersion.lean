import Bitcoin.Interpreter.Defs
import Bitcoin.Crypto.Taproot.Program
import Bitcoin.Script.Tapscript.Delta

/-!
# Bitcoin.Script.Tapscript.LeafVersion — the 0xc0 leaf-version dispatch
# (SCR-148, recovery review 2 / contributor SCR3)

Core `VerifyWitnessProgram`'s script-path TAIL, interpreter.cpp @
`cce32b168` **:1988-1994** (row pin @cce32b168 :1988-1994 — line-verified
identical at the suite ground truth `cce32b168`; the cce32b168 pins are
stale-commit-labels only, cf. audit F-TS02-006):

    if ((control[0] & TAPROOT_LEAF_MASK) == TAPROOT_LEAF_TAPSCRIPT) {
        // Tapscript (leaf version 0xc0)
        exec_script = CScript(script.begin(), script.end());      // :1990
        execdata.m_validation_weight_left =
            ::GetSerializeSize(witness.stack) + VALIDATION_WEIGHT_OFFSET;  // :1991
        execdata.m_validation_weight_left_init = true;            // :1992
        return ExecuteWitnessScript(stack, exec_script, flags,
                                    SigVersion::TAPSCRIPT, checker,
                                    execdata, serror);             // :1993
    }

`control[0] & 0xfe == 0xc0` ⇒ the popped script executes as TAPSCRIPT.
Every other (even) leaf version leaves this arm — the upgradable
`else` tail :1995-1998, which is **SCR-149's** ground
(`verifyWitnessProgram_upgradable_leaf_ok`, X07) and is pinned here as
the fall-through only.

## Disposition: B (implement), X07's wrapper-over-seam idiom

This row's three blocked-origin neighbours closed WITHOUT touching
W09's `verifyWitnessProgram` (still `.unjudged` at the CheckTapTweak EC
step, Defs.lean:1245): SCR-146/147 = wrapper pins over X02's
`taggedHash`/X03's `tweakPoint` (Interpreter/Rules.lean §11), SCR-149 =
the wrapper theorem over the def. This module pins the last blocked
piece the same way — **the 0xc0 dispatch** — as
`verifyTaprootLeafDispatch`, with:

* the leaf-version test = X06's `leafVersionOf`
  (`control[0] & 0xfe`, TPR-010, `@[rule "TPR-010"]` in
  `Crypto/Taproot/Program.lean`) compared to `TAPROOT_LEAF_TAPSCRIPT`
  (interpreter.h:243 = 0xc0) — Core's exact `:1988` expression, nothing
  re-implemented;
* the executed script = the popped `script` param (:1990
  `exec_script = CScript(script)`);
* the validation weight = `witnessSerSize witness` over the **FULL**
  witness stack (:1991 `GetSerializeSize(witness.stack)` — annex,
  control block, script and stack items included; W09's Defs.lean:1142
  `witnessSerSize` = the same CompactSize-per-item fold) — the `:1992`
  init lands inside `executeWitnessScript` (X04's U2/SCR-040 wiring,
  Defs.lean:1170-1174);
* `SigVersion.tapscript` (:1993) — the one-parameter mode switch that
  turns on the whole X04 delta layer (OP_SUCCESSx pre-scan, budget,
  MINIMALIF, …) inside `executeWitnessScript`.

The CheckTapTweak commitment verdict (Core :1983-1987) is OUTSIDE this
row (SCR-146/147 = the wrapper pins; W09 stays `.unjudged` at that EC
step): `verifyTaprootLeafDispatch` composes with it downstream exactly
as X03's Crypto-side `Taproot/Verify.scriptPathSpend` (Unit 4) exposes
the same dispatch as its third `Bool` (`ts = leafVersionOf control =
TAPROOT_LEAF_TAPSCRIPT`, `scriptPathSpend_dispatch` @ :1988) — the
Crypto lane's verdict bit vs this module's Interpreter-lane execution
wiring, one Core line each side of the seam.

Honest gaps carried in the row notes (NOT fixed here, other contributors'
frozen lanes): (a) `verifyWitnessProgram`'s own script-path arm still
returns `.unjudged` (X07/SCR-146 protocol) — this def is the faithful
`:1988-1994` arm, not yet wired into W09's def; (b) audit F-TS02-008
(MOD): the tapscript `ed` (`tapleafHashInit`/`codesepPosInit`/
`codesepPos`) is not threaded from `VerifyWitnessProgram`/
`EvalScript` into the sighash seam (Core :444-445 init 0xFFFFFFFF /
:1065 records `opcode_pos` = the INSTRUCTION index — vs SCR-167's
`op.next` byte-offset recording; TPR-045 = the index semantics) —
X04's one-parameter seam change; (c) `realSchnorrEntry`
(Capstone/RealChecker.lean) still holds the fail-closed
`fun _ _ _ => none` sighash stand-in (X04's flip; S03's banked
dead-contributor `EcdsaDeep/SchnorrEntry2.realSchnorrEntry2` carries the
drop-in).

Conformance: `Test/Script/Tapscript/LeafVersionTest.lean`
(Test-scoped, native_decide per the D2 gate) — the 0xc0/0xc1/0xc2/
0x00/0x80/0xbf/0xfa/0xfe/0xff leaf-version matrix, the 0xc0-arm
executing into X04's `executeWitnessScript` tapscript lanes
(OP_SUCCESS `.ok` / OP_1 `.ok` / 2-item `.fail .cleanstack`), and the
`:1995-1998` fall-through (discourage `.fail` / default `.ok`).
No official Core dispatch vectors exist for script-path spends
(documented in X03's Verify.lean for the same arm); the matrix is
Core-:1988-by-inspection.

No `sorry`, no `native_decide` (this file); axiom pins at the bottom,
footprints ⊆ the standard trio.
-/

namespace Bitcoin.Script.Tapscript

open Bitcoin.Interpreter (VerifyOutcome ExecError PolicyFlags
  ScriptChecker executeWitnessScript witnessSerSize opSuccessScan)
open Bitcoin.Activation (ScriptFlags)
open Bitcoin.Data (WitnessStack)
open Bitcoin.Crypto.Taproot.Program (leafVersionOf TAPROOT_LEAF_TAPSCRIPT)
open Bitcoin.Crypto.Seam (SigVersion)

/-! ## The leaf-version test (interpreter.cpp:1988) -/

/-- SCR-148 (interpreter.cpp:1988): `control[0] & TAPROOT_LEAF_MASK ==
TAPROOT_LEAF_TAPSCRIPT` — the tapscript leaf-version 0xc0 test. X06's
`leafVersionOf` (TPR-010) IS the masked left side, `TAPROOT_LEAF_TAPSCRIPT`
(interpreter.h:243) the constant; bit 0 of the control byte is the
output-key parity (TPR-011), so `0xc0` and `0xc1` both dispatch (the
`leafVersionOf_even` pin). Nothing re-implemented. -/
@[rule "SCR-148"]
def isTapscriptLeaf (control : ByteArray) : Bool :=
  leafVersionOf control = TAPROOT_LEAF_TAPSCRIPT

/-! ## The dispatch (interpreter.cpp:1988-1994) -/

/-- SCR-148 (interpreter.cpp:1988-1994), the X07 wrapper-over-seam pin:
`control[0] & 0xfe == 0xc0` ⇒ the popped `script` executes via
`executeWitnessScript` at `SigVersion.tapscript`, the validation weight
seeded from the FULL witness (`witnessSerSize witness` = Core
:1991's `GetSerializeSize(witness.stack)`, annex + control + script
included; the `:1992` init + `VALIDATION_WEIGHT_OFFSET` live inside
`executeWitnessScript`, X04's U2/SCR-040 wiring). `items` = the witness
stack AFTER the annex strip and the control/script pops (Core's `stack`
at :1993). The non-0xc0 arm is the `:1995-1998` upgradable fall-through
(SCR-149's ground): DISCOURAGE_UPGRADABLE_TAPROOT_VERSION policy fail
else success. The CheckTapTweak verdict (Core :1983-1987) enters
downstream of this row — W09's def stays `.unjudged` at that EC step
(SCR-146/147 protocol). -/
@[rule "SCR-148"]
def verifyTaprootLeafDispatch (fuel : Nat) (items : WitnessStack)
    (control script : ByteArray) (witness : WitnessStack)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker) :
    VerifyOutcome :=
  if isTapscriptLeaf control then
    executeWitnessScript fuel items (witnessSerSize witness) script
      flags pol chk SigVersion.tapscript
  else if pol.discourageUpgradableTaprootVersion then
    .fail ExecError.discourageUpgradableTaprootVersion
  else .ok

/-! ## T1-T3 — the dispatch equations -/

/-- T1 (the row statement, :1988-1994): a 0xc0 leaf version dispatches
into `executeWitnessScript` at `SigVersion.tapscript` with `script` as
the executed script (:1990) and the FULL-witness serialized size as the
budget seed (:1991). -/
@[rule "SCR-148"]
theorem verifyTaprootLeafDispatch_tapscript (fuel : Nat)
    (items : WitnessStack) (control script : ByteArray)
    (witness : WitnessStack) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (hleaf : isTapscriptLeaf control = true) :
    verifyTaprootLeafDispatch fuel items control script witness flags pol chk
      = executeWitnessScript fuel items (witnessSerSize witness) script
          flags pol chk SigVersion.tapscript := by
  unfold verifyTaprootLeafDispatch
  rw [if_pos hleaf]

/-- T2 (the non-0xc0 fall-through, :1995-1997): an upgradable (non-0xc0)
leaf version with the DISCOURAGE_UPGRADABLE_TAPROOT_VERSION policy bit
fails with the named error — policy, not consensus. -/
@[rule "SCR-148"]
theorem verifyTaprootLeafDispatch_upgradable_discourage (fuel : Nat)
    (items : WitnessStack) (control script : ByteArray)
    (witness : WitnessStack) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (hnot : isTapscriptLeaf control = false)
    (hd : pol.discourageUpgradableTaprootVersion = true) :
    verifyTaprootLeafDispatch fuel items control script witness flags pol chk
      = VerifyOutcome.fail ExecError.discourageUpgradableTaprootVersion := by
  unfold verifyTaprootLeafDispatch
  rw [if_neg (by simp [hnot]), if_pos hd]

/-- T3 (the non-0xc0 fall-through, :1998): without the policy bit every
other leaf version succeeds — the softfork upgradability hook
(SCR-149's ground, pinned as the fall-through here). -/
@[rule "SCR-148"]
theorem verifyTaprootLeafDispatch_upgradable_ok (fuel : Nat)
    (items : WitnessStack) (control script : ByteArray)
    (witness : WitnessStack) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (hnot : isTapscriptLeaf control = false)
    (hnd : pol.discourageUpgradableTaprootVersion = false) :
    verifyTaprootLeafDispatch fuel items control script witness flags pol chk
      = VerifyOutcome.ok := by
  unfold verifyTaprootLeafDispatch
  rw [if_neg (by simp [hnot]), if_neg (by simp [hnd])]

/-! ## T4 — the leaf-version matrix (Core :1988 by inspection) -/

/-- One-byte control-block probes. -/
def ctl (b : UInt8) : ByteArray := ByteArray.mk #[b]

/-- T4a: leaf version 0xc0 dispatches (the row's own case). -/
@[rule "SCR-148"]
theorem isTapscriptLeaf_c0 : isTapscriptLeaf (ctl 0xc0) = true := by
  decide

/-- T4b: leaf version 0xc0 with the PARITY bit set (control[0] = 0xc1)
still dispatches — bit 0 is the output-key parity (TPR-011), stripped by
the `& 0xfe` mask (X06's `leafVersionOf_even`). -/
@[rule "SCR-148"]
theorem isTapscriptLeaf_c1_parity : isTapscriptLeaf (ctl 0xc1) = true := by
  decide

/-- T4c: the non-tapscript family does NOT dispatch — 0xc2 (the next
even version), 0x00, 0x80, 0xbf (last pre-0xc0), 0xfa (the
wallet-vectors' future version), 0xfe (the mask itself) and 0xff
(parity of 0xfe). -/
@[rule "SCR-148"]
theorem isTapscriptLeaf_matrix :
    isTapscriptLeaf (ctl 0xc2) = false ∧
    isTapscriptLeaf (ctl 0x00) = false ∧
    isTapscriptLeaf (ctl 0x80) = false ∧
    isTapscriptLeaf (ctl 0xbf) = false ∧
    isTapscriptLeaf (ctl 0xfa) = false ∧
    isTapscriptLeaf (ctl 0xfe) = false ∧
    isTapscriptLeaf (ctl 0xff) = false := by
  decide

/-! ## T5 — vectors: the 0xc0 arm executes the X04 tapscript lanes

`verifyTaprootLeafDispatch` at `control[0] = 0xc0` IS
`executeWitnessScript … SigVersion.tapscript` (T1), so the 0xc0 arm
inherits X04's whole delta layer; these outcome pins make that concrete
(kernel-reduced, `rfl` — the same shapes as Delta.lean's
`cleanstack_implicit_*` / `executeWitnessScript_success_total`
neighbours). -/

/-- V1 (:1988 + :1993 + BIP342 OP_SUCCESS): a 0xc0 control block with an
OP_SUCCESSx script (0xbb = OP_SUCCESS187, the 0xbb..0xfe block) — the
dispatch reaches the tapscript OP_SUCCESSx pre-scan, which overrides
everything and succeeds, no matter the initial stack. `hops` : the
one-byte script scans as OP_SUCCESSx (Test-scoped pin in
`LeafVersionTest.lean`). -/
@[rule "SCR-148"]
theorem dispatch_v1_0xc0_opsuccess_ok (items : WitnessStack)
    (witness : WitnessStack) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker)
    (hops : opSuccessScan (ByteArray.mk #[0xbb]) = true) :
    verifyTaprootLeafDispatch 10 items (ctl 0xc0)
      (ByteArray.mk #[0xbb]) witness flags
      { pol with discourageOpSuccess := false } chk
      = VerifyOutcome.ok := by
  rw [verifyTaprootLeafDispatch_tapscript 10 items (ctl 0xc0)
      (ByteArray.mk #[0xbb]) witness flags
      { pol with discourageOpSuccess := false } chk (by decide)]
  exact Bitcoin.Script.Tapscript.executeWitnessScript_success_total
    10 items (witnessSerSize witness) (ByteArray.mk #[0xbb]) flags
    { pol with discourageOpSuccess := false } chk hops

/-- V2 (failure lane): 0xc0 + a one-op OP_1 script + a 2-item initial
stack — the tapscript cleanstack check fails (BIP342 §Spec step 5:
witness scripts implicitly require exactly one truthy final item). The
`:1988` dispatch hands the execution over verbatim, failures included
(`Delta.cleanstack_implicit_tapscript`'s exact shape on the dispatch
side). A `by decide` pin of V1's `hops` hypothesis lives Test-scoped
(`LeafVersionTest.lean`). -/
@[rule "SCR-148"]
theorem dispatch_v2_0xc0_cleanstack_fail :
    verifyTaprootLeafDispatch 10 [ByteArray.empty, ByteArray.empty] (ctl 0xc0)
      (ByteArray.mk #[(0x51 : UInt8)]) [] default default default
      = VerifyOutcome.fail ExecError.cleanstack := by
  rw [verifyTaprootLeafDispatch_tapscript 10 [ByteArray.empty, ByteArray.empty]
      (ctl 0xc0) (ByteArray.mk #[(0x51 : UInt8)]) [] default default default
      (by decide)]
  exact Bitcoin.Script.Tapscript.cleanstack_implicit_tapscript

/-- V3 (the :1995-1997 fall-through): a non-0xc0 leaf version (0xc2 =
the next even version) with the DISCOURAGE bit fails the named policy
error. -/
@[rule "SCR-148"]
theorem dispatch_v3_0xc2_discourage_fail (items : WitnessStack)
    (control script : ByteArray) (witness : WitnessStack)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker) :
    verifyTaprootLeafDispatch 10 items (ctl 0xc2) script witness flags
      { pol with discourageUpgradableTaprootVersion := true } chk
      = VerifyOutcome.fail ExecError.discourageUpgradableTaprootVersion :=
    verifyTaprootLeafDispatch_upgradable_discourage 10 items (ctl 0xc2)
      script witness flags { pol with discourageUpgradableTaprootVersion := true }
      chk (by decide) (by simp)

/-- V4 (the :1998 fall-through): 0xc2 without the DISCOURAGE bit
succeeds — upgradability (SCR-149's ground). -/
@[rule "SCR-148"]
theorem dispatch_v4_0xc2_upgradable_ok (items : WitnessStack)
    (script : ByteArray) (witness : WitnessStack)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker) :
    verifyTaprootLeafDispatch 10 items (ctl 0xc2) script witness flags
      { pol with discourageUpgradableTaprootVersion := false } chk
      = VerifyOutcome.ok :=
    verifyTaprootLeafDispatch_upgradable_ok 10 items (ctl 0xc2) script
      witness flags { pol with discourageUpgradableTaprootVersion := false }
      chk (by decide) (by simp)

/-- V5 (the wallet-vectors' future leaf version 0xfa): same
`:1995-1998` success — BIP341's softfork hook. -/
@[rule "SCR-148"]
theorem dispatch_v5_0xfa_upgradable_ok (items : WitnessStack)
    (script : ByteArray) (witness : WitnessStack)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker) :
    verifyTaprootLeafDispatch 10 items (ctl 0xfa) script witness flags
      { pol with discourageUpgradableTaprootVersion := false } chk
      = VerifyOutcome.ok :=
    verifyTaprootLeafDispatch_upgradable_ok 10 items (ctl 0xfa) script
      witness flags { pol with discourageUpgradableTaprootVersion := false }
      chk (by decide) (by simp)

/-! ## T6 — determinism (W14b discipline) -/

/-- Determinism: the dispatch is a pure function of its inputs —
equal leaf versions (equal control blocks), scripts, items, witnesses,
flags, policies and checkers give equal verdicts. -/
@[rule "SCR-148"]
theorem verifyTaprootLeafDispatch_congr (fuel : Nat) (items items' : WitnessStack)
    (control control' script script' : ByteArray)
    (witness witness' : WitnessStack) (flags flags' : ScriptFlags)
    (pol pol' : PolicyFlags) (chk chk' : ScriptChecker)
    (hi : items = items') (hc : control = control') (hs : script = script')
    (hw : witness = witness') (hf : flags = flags') (hp : pol = pol')
    (hch : chk = chk') :
    verifyTaprootLeafDispatch fuel items control script witness flags pol chk
      = verifyTaprootLeafDispatch fuel items' control' script' witness'
          flags' pol' chk' := by
  subst hi; subst hc; subst hs; subst hw; subst hf; subst hp; subst hch; rfl

/-! ## Axiom footprints (X02/X03 style: `#guard_msgs in #print axioms`)

All sorry-free; footprints ⊆ the standard trio `[propext,
Classical.choice, Quot.sound]`. Pinned by the guard block below.
-/

/-- info: 'Bitcoin.Script.Tapscript.isTapscriptLeaf_c0' depends on axioms: [propext] -/
#guard_msgs in #print axioms isTapscriptLeaf_c0

/-- info: 'Bitcoin.Script.Tapscript.isTapscriptLeaf_c1_parity' depends on axioms: [propext] -/
#guard_msgs in #print axioms isTapscriptLeaf_c1_parity

/-- info: 'Bitcoin.Script.Tapscript.isTapscriptLeaf_matrix' depends on axioms: [propext] -/
#guard_msgs in #print axioms isTapscriptLeaf_matrix

/-- info: 'Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_tapscript' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyTaprootLeafDispatch_tapscript

/-- info: 'Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_upgradable_discourage' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyTaprootLeafDispatch_upgradable_discourage

/-- info: 'Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_upgradable_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyTaprootLeafDispatch_upgradable_ok

/-- info: 'Bitcoin.Script.Tapscript.dispatch_v1_0xc0_opsuccess_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms dispatch_v1_0xc0_opsuccess_ok

/-- info: 'Bitcoin.Script.Tapscript.dispatch_v2_0xc0_cleanstack_fail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms dispatch_v2_0xc0_cleanstack_fail

/-- info: 'Bitcoin.Script.Tapscript.dispatch_v3_0xc2_discourage_fail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms dispatch_v3_0xc2_discourage_fail

/-- info: 'Bitcoin.Script.Tapscript.dispatch_v4_0xc2_upgradable_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms dispatch_v4_0xc2_upgradable_ok

/-- info: 'Bitcoin.Script.Tapscript.dispatch_v5_0xfa_upgradable_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms dispatch_v5_0xfa_upgradable_ok

/-- info: 'Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_congr' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyTaprootLeafDispatch_congr

end Bitcoin.Script.Tapscript
