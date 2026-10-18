import Bitcoin.Interpreter.Defs

/-!
# Bitcoin.Script.Tapscript.Delta — the BIP342 consensus deltas (the interpreter delta layer)

The tapscript layer of the script interpreter, stated as theorems OVER
interpreter (`Bitcoin.Interpreter.Defs`, where the delta code lives
next to its legacy counterparts exactly as Core keeps tapscript branches
inside `EvalScript`/`ExecuteWitnessScript`).

Ground truth: BIP342 (spec sections verified 2026-10-16 against
bip-0342.mediawiki @ master) and interpreter.cpp/script.cpp @ `cce32b168`:

* **OP_SUCCESSx** = {80, 98, 126-129, 131-134, 137-138, 141-142, 149-153,
  187-254} (`IsOpSuccess`, script.cpp:365-371): encountering ANY of these
  while decoding the tapscript succeeds validation unconditionally —
  ordered per-opcode with the decode itself, so it overrides the initial
  stack limits, the 520-byte element limit, unbalanced conditionals, and
  even a later truncated push (`opSuccessScan`).
* **Signature opcodes**: CHECKSIG/CHECKSIGVERIFY dispatch on SigVersion
  (`evalChecksigDispatch` = Core's `EvalChecksig`); under tapscript the
  rules are (in Core's consensus-critical order): empty sig ⇒ success :=
  false; nonempty sig ⇒ validation-weight budget −50 (fail below zero);
  empty pubkey ⇒ fail; 32-byte pubkey ⇒ Schnorr verify, and a FAILED
  verify fails the script (`.schnorrSig`); other nonempty pubkey sizes ⇒
  unknown key type, counted-but-always-success. OP_CHECKSIGADD (0xba) is
  tapscript-only and computes `n + {0,1}` with the num decoded FIRST
  (4-byte bound). CHECKMULTISIG/VERIFY (0xae/0xaf) are NOT OP_SUCCESSx —
  they fail when executed under tapscript and are ignored unexecuted.
* **Consensus re-imports**: MINIMALIF (unconditional under tapscript),
  CLEANSTACK (implicit inside witness execution), the NULLFAIL analogue
  (nonempty invalid signature). VERIFIED against Core: MINIMALDATA is
  NOT re-imported — `fRequireMinimal` stays the policy word
  (interpreter.cpp:442); the tapscript constraint on numeric operands is
  only the structural 4-byte `CScriptNum` bound, shared with OP_ADD.

VERIFIED vs PROPOSED: every definition in `Bitcoin.Interpreter.Defs`'s
tapsection is a VERIFIED transliteration (citation inline); the theorems
below are the PROVEN pin statements — sorry-free, standard-trio axioms
(pins in Test/Script/Tapscript/Delta.lean).
-/

namespace Bitcoin.Script.Tapscript

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Script.Parser Bitcoin.Activation
open Bitcoin.Numeric
open Bitcoin.Crypto.Seam (SigVersion ScriptExecutionData stubChecker)

deriving instance Inhabited for Bitcoin.Activation.ScriptFlags

set_option maxRecDepth 40000

/-! ## the abstraction layer — the OP_SUCCESSx redefinition of validation success -/

/-- Success-opcode totality: a tapscript whose byte-decode reaches an
OP_SUCCESSx passes NO MATTER WHAT the initial stack is — the scan
precedes the 1000-element initial-stack check and the 520-byte element
check (`executeWitnessScript`, tapscript branch; interpreter.cpp
1846-1862: "OP_SUCCESSx processing overrides everything, including stack
element size limits"). BIP342 §Spec step 2. -/
@[rule "INV-061", rule "TPR-061"]
theorem executeWitnessScript_success_total
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (h : opSuccessScan exec = true) :
    executeWitnessScript fuel items vwSer exec flags
      { pol with discourageOpSuccess := false } chk SigVersion.tapscript
      = VerifyOutcome.ok := by
  unfold executeWitnessScript
  rw [if_pos rfl, if_pos h]
  simp

/-- The DISCOURAGE_OP_SUCCESS variant: the policy bit turns the
short-circuit into the named failure (interpreter.cpp:1856-1859). -/
@[rule "TPR-062"]
theorem executeWitnessScript_success_discourage
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (h : opSuccessScan exec = true) :
    executeWitnessScript fuel items vwSer exec flags
      { pol with discourageOpSuccess := true } chk SigVersion.tapscript
      = VerifyOutcome.fail ExecError.discourageOpSuccess := by
  unfold executeWitnessScript
  rw [if_pos rfl, if_pos h]
  simp

/-- Load-bearing set fact: OP_CHECKSIGADD (0xba = 186) is NOT an
OP_SUCCESSx — 0xba sits just below the 187..254 block, so the two
"unconditional-ish" mechanisms never collide (BIP342 assigns 186
explicitly). -/
theorem checksigadd_not_success : isOpSuccessWire 0xba = false := by decide

/-- Every legacy-disabled wire opcode (the CVE-2010-5137 set) IS an
OP_SUCCESSx under tapscript: the disabled-failure rule is superseded by
the success redefinition (BIP342 renames exactly these to
OP_SUCCESS126..OP_SUCCESS153). -/
@[rule "TPR-074"]
theorem disabledWire_success (w : Nat) (h : disabledWire w = true) :
    isOpSuccessWire w = true := by
  have hm : w ∈ [0x7e, 0x7f, 0x80, 0x81, 0x83, 0x84, 0x85, 0x86,
                 0x8d, 0x8e, 0x95, 0x96, 0x97, 0x98, 0x99] := by
    simpa [disabledWire] using h
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  exact absurd hm (by simp)

/-- TPR-074 (scan witness): a one-opcode tapscript holding ANY
legacy-disabled byte is an OP_SUCCESSx program — the raw-byte scan
succeeds at that byte because `disabledWire_success` puts it in the
BIP342 success set (script.cpp:365-371). -/
@[rule "TPR-074"]
theorem opSuccessScan_disabledWire_singleton (w : Nat)
    (h : disabledWire w = true) :
    opSuccessScan (ByteArray.mk #[UInt8.ofNat w]) = true := by
  have hm : w ∈ [0x7e, 0x7f, 0x80, 0x81, 0x83, 0x84, 0x85, 0x86,
                 0x8d, 0x8e, 0x95, 0x96, 0x97, 0x98, 0x99] := by
    simpa [disabledWire] using h
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  rcases List.mem_cons.mp hm with rfl | hm
  · decide
  exact absurd hm (by simp)

/-- TPR-074 (observable short-circuit, general): whenever the tapscript
OP_SUCCESSx scan gate succeeds, `ExecuteWitnessScript` returns success
before the disabled-opcode table can be consulted — in particular the
result is never `SCRIPT_ERR_DISABLED_OPCODE` (interpreter.cpp:1846-1862
precedes :467-482). -/
@[rule "TPR-074"]
theorem executeWitnessScript_scan_ok_ne_disabledOpcode
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (h : opSuccessScan exec = true) :
    executeWitnessScript fuel items vwSer exec flags
        { pol with discourageOpSuccess := false } chk SigVersion.tapscript = VerifyOutcome.ok
      ∧ executeWitnessScript fuel items vwSer exec flags
        { pol with discourageOpSuccess := false } chk SigVersion.tapscript
          ≠ VerifyOutcome.fail ExecError.disabledOpcode := by
  have hok := executeWitnessScript_success_total fuel items vwSer exec flags pol chk h
  exact ⟨hok, by rw [hok]; simp⟩

/-- TPR-074 (disabled-byte instance): a tapscript program containing a
legacy-disabled byte that is also OP_SUCCESSx short-circuits to
success, not `DISABLED_OPCODE` — the disabled-failure path is
unreachable for that program. -/
@[rule "TPR-074"]
theorem executeWitnessScript_disabledWire_shortCircuit
    (fuel : Nat) (items : List ByteArray) (vwSer : Int)
    (w : Nat) (h : disabledWire w = true)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker) :
    executeWitnessScript fuel items vwSer (ByteArray.mk #[UInt8.ofNat w])
        flags { pol with discourageOpSuccess := false } chk SigVersion.tapscript = VerifyOutcome.ok
      ∧ executeWitnessScript fuel items vwSer (ByteArray.mk #[UInt8.ofNat w])
        flags { pol with discourageOpSuccess := false } chk SigVersion.tapscript
          ≠ VerifyOutcome.fail ExecError.disabledOpcode :=
  executeWitnessScript_scan_ok_ne_disabledOpcode fuel items vwSer
    (ByteArray.mk #[UInt8.ofNat w]) flags pol chk
    (opSuccessScan_disabledWire_singleton w h)

/-! ## the delta layer — signature-opcode deltas -/

/-- Mode dispatch NEVER conflates: on BASE the dispatch IS the
pre-tapscript ECDSA path with the budget slot passed through untouched
(interpreter.cpp:407-409). -/
theorem evalChecksigDispatch_base_arm (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (cs : Nat)
    (b sig pk : ByteArray) (vw : Option Int) :
    evalChecksigDispatch flags pol chk ed SigVersion.base cs b sig pk vw
      = (match evalChecksigPreTapscript flags pol chk ed SigVersion.base cs b sig pk with
         | .error e => .error e
         | .ok r => .ok (r, vw)) := by
  unfold evalChecksigDispatch; rfl

/-- …and on TAPSCRIPT it IS the Schnorr path (interpreter.cpp:410-411):
the two arms are definitionally disjoint code paths keyed on
`SigVersion` — legacy input can never reach tapscript rules or vice
versa. -/
@[rule "TPR-055"]
theorem evalChecksigDispatch_tapscript_arm (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (cs : Nat)
    (b sig pk : ByteArray) (vw : Option Int) :
    evalChecksigDispatch flags pol chk ed SigVersion.tapscript cs b sig pk vw
      = evalChecksigTapscript pol chk ed sig pk vw := by
  unfold evalChecksigDispatch; rfl

/-- Empty-signature-false: an empty signature under tapscript NEVER
fails on a 32-byte key — the verdict is success = false, no budget
decrement, budget slot returned unchanged (BIP342 signature-op rules,
final bullet; interpreter.cpp:372 `success = !sig.empty()`). -/
theorem evalChecksigTapscript_empty_sig_false (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (pk : ByteArray)
    (hpk : pk.size = 32) (vw : Option Int) :
    evalChecksigTapscript pol chk ed ByteArray.empty pk vw
      = .ok (false, vw) := by
  simp only [evalChecksigTapscript]
  simp [ByteArray.size_empty, hpk]

/-- The NULLFAIL-analogue consensus rule: a NON-EMPTY signature that
fails Schnorr verification fails the whole script with
`SCRIPT_ERR_SCHNORR_SIG` — the script does NOT continue with `false`
(that is legacy CHECKSIG semantics; BIP342: "Validation failure in this
case immediately terminates script execution with failure"). The budget
slot must be non-negative after the −50 decrement (the guard evaluated
first, per Core's consensus-critical ordering). -/
theorem evalChecksigTapscript_invalid_sig_fails
    (checkSchnorr : ByteArray → ByteArray → SigVersion → ScriptExecutionData → Bool)
    (ed : ScriptExecutionData) (sig pk : ByteArray)
    (hsig : sig.size ≠ 0) (hpk : pk.size = 32)
    (hbad : checkSchnorr sig pk SigVersion.tapscript ed = false)
    (vw : Option Int) (hvw : 0 ≤ vw.getD 0 - VALIDATION_WEIGHT_PER_SIGOP_PASSED) :
    evalChecksigTapscript default
      { base := { checkECDSASignature := fun _ _ _ _ _ => true
                  checkSchnorrSignature := checkSchnorr } }
      ed sig pk vw = .error ExecError.schnorrSig := by
  simp only [evalChecksigTapscript, VALIDATION_WEIGHT_PER_SIGOP_PASSED] at hvw ⊢
  simp only [if_pos hsig, if_neg (by omega : ¬(vw.getD 0 - 50 < 0)),
    if_neg (by omega : ¬(pk.size = 0)), if_pos hpk,
    if_pos (show (!checkSchnorr sig pk SigVersion.tapscript ed) = true by
      rw [hbad]; rfl)]

/-- CHECKSIGADD stack arithmetic: a successful step pushes exactly
`n` or `n + 1`, where `n` is the decoded `num` operand — the
`OP_ROT OP_SWAP OP_CHECKSIG OP_ADD` expansion's numeric core (BIP342;
interpreter.cpp:1110-1112). -/
@[rule "TPR-056"]
theorem checksigAddStep_result (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (sig num pk : ByteArray) (vw : Option Int)
    (h : checksigAddStep pol chk ed sig num pk vw = .ok (r, vw')) :
    ∃ n, decodeNum pol num 4 = .ok n ∧ (r = n ∨ r = n + 1) := by
  unfold checksigAddStep at h
  split at h
  · exact absurd h (by simp)
  · next n hn =>
    split at h
    · exact absurd h (by simp)
    · next b o heq =>
      rw [Except.ok.injEq, Prod.mk.injEq] at h
      obtain ⟨hr, -⟩ := h
      refine ⟨n, hn, ?_⟩
      by_cases hs : (b = true)
      · simp only [hs] at hr
        exact Or.inr hr.symm
      · have hf : b = false := by simpa using hs
        simp only [hf] at hr
        simp at hr
        exact Or.inl hr.symm

/-- CHECKMULTISIG disabled (NOT OP_SUCCESSx): under tapscript the opcode
fails immediately when executed (interpreter.cpp:1115-1118); in
unexecuted branches the generic conditional-window rule skips it. TPR-059. -/
@[rule "INV-062", rule "TPR-059"]
theorem checkMultiSig_tapscript_fails (ctx : Ctx) (w : Nat) (st : State)
    (hsv : ctx.sv = SigVersion.tapscript) :
    stepBody.checkMultiSig ctx w st = .error ExecError.tapscriptCheckMultiSig := by
  unfold stepBody.checkMultiSig
  rw [if_pos hsv]

/-- TPR-059 (unexecuted half): inside a non-executing conditional branch
the generic `fExec` gate skips opcode dispatch entirely, so
OP_CHECKMULTISIG/OP_CHECKMULTISIGVERIFY (0xae/0xaf) is ignored and
leaves the state unchanged — it does NOT raise
`SCRIPT_ERR_TAPSCRIPT_CHECKMULTISIG` (interpreter.cpp:467-482, :660-664;
the gate in `stepBody` is Defs.lean:802-815). -/
@[rule "TPR-059"]
theorem checkMultiSig_tapscript_unexecuted {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o)
    (hw : op.wire = 0xae ∨ op.wire = 0xaf)
    (hsv : ctx.sv = SigVersion.tapscript)
    (hfe : st.vf.all id = false) :
    stepBody ctx op st = .ok st := by
  obtain ⟨flags, pol, chk, sv, bytes, ed⟩ := ctx
  have hsv' : sv = SigVersion.tapscript := hsv
  subst hsv'
  rcases hw with hw | hw <;>
    (rw [stepBody]
     simp [ha, hw, hfe, disabledWire])

/-- TPR-059 (skip vs fail): the unexecuted tapscript arm and the executed
failure are disjoint — the same opcode cannot both skip and raise
`TAPSCRIPT_CHECKMULTISIG`. -/
@[rule "TPR-059"]
theorem checkMultiSig_tapscript_unexecuted_ne_fail
    {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o)
    (hw : op.wire = 0xae ∨ op.wire = 0xaf)
    (hsv : ctx.sv = SigVersion.tapscript)
    (hfe : st.vf.all id = false) :
    stepBody ctx op st ≠ .error ExecError.tapscriptCheckMultiSig := by
  rw [checkMultiSig_tapscript_unexecuted ha hw hsv hfe]
  simp

/-! ## U3 — consensus-preserved deltas / dropped limits -/

/-- The 10,000-byte script-size pre-check is structurally DROPPED for
tapscript: the guard reads `(sv = base ∨ sv = witnessV0) ∧ …`, so the
tapscript entry goes straight to parse+eval and the budget slot is
seeded from `ed` (BIP342 §Resource limits; TPR-064). -/
@[rule "TPR-064"]
theorem evalScriptBytes_tapscript_no_script_size
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags) (b : ByteArray)
    (st0 : Stack) (chk : ScriptChecker) (ed : ScriptExecutionData) :
    evalScriptBytes fuel flags pol b st0 chk SigVersion.tapscript ed =
      match parseWire b with
      | none => .error ExecError.badOpcode
      | some ops =>
        finalStack (evalFrom ⟨flags, pol, chk, SigVersion.tapscript, b, ed⟩ fuel ops
          { stack := st0, alt := [], vf := [], opCount := 0, codeSep := 0,
            vwLeft := some ed.validationWeightLeft }) := by
  unfold evalScriptBytes
  rfl

/-! ### U3 — the 201-opcode budget is structurally OFF under tapscript -/

/-- The budget-guard condition `(sv ∈ {base, witnessV0}) ∧ 0x60 < wire`
is FALSE for every tapscript opcode: the guard's conjunction is what
makes MAX_OPS_PER_SCRIPT (201) unreachable in tapscript (BIP342 drops
the 201-opcode limit; interpreter.cpp:459-463 keys `nOpCount` on the
segv1-negation). TPR-065. [TAGFIX] comment number was TPR-062 (stale
the interpreter delta layer draft numbering) — yaml lean_target maps this theorem to TPR-065. -/
@[rule "TPR-065"]
theorem tapscript_opcount_guard_off (ctx : Ctx) (op : WireOp)
    (hsv : ctx.sv = SigVersion.tapscript) :
    ¬((ctx.sv = SigVersion.base ∨ ctx.sv = SigVersion.witnessV0) ∧ 0x60 < op.wire) := by
  rw [hsv]; simp

/-- Concrete companion: after 500 counted-equivalent steps, a tapscript
step still executes and leaves `opCount` FROZEN at 500 (the base path
would have raised `.opCount` at 202; kernel-reduced, zero axioms). -/
theorem opBudget_frozen_tapscript : stepBody ⟨default, default, default, SigVersion.tapscript,
    ByteArray.empty, default⟩
    { ast := .op ⟨0x8b, by decide⟩, wire := 0x8b, next := 1 }
    { stack := [ByteArray.mk #[(0x05 : UInt8)]], alt := [], vf := [true],
      opCount := 500, codeSep := 0, vwLeft := none }
    = .ok { stack := [ByteArray.mk #[(0x06 : UInt8)]], alt := [], vf := [true],
            opCount := 500, codeSep := 0, vwLeft := none } := by rfl

/-! ### U3 — MINIMALIF: unconditional consensus under tapscript -/

/- Probe inputs: the non-minimal "true" value `0x02 0x01 0x00` and the
OP_IF wire op. -/

def b2 : ByteArray := ByteArray.mk #[(0x02 : UInt8), (0x01 : UInt8), (0x00 : UInt8)]
def ifOp : WireOp := { ast := .op ⟨0x63, by decide⟩, wire := 0x63, next := 1 }
def cltvOp : WireOp := { ast := .op ⟨0xb1, by decide⟩, wire := 0xb1, next := 1 }
def csvOp : WireOp := { ast := .op ⟨0xb2, by decide⟩, wire := 0xb2, next := 1 }
def st1 : State :=
  { stack := [b2], alt := [], vf := [true], opCount := 0, codeSep := 0, vwLeft := none }
def polIf : PolicyFlags := { minimalIf := true }
def flCltv : ScriptFlags := { cltv := true }
def flCsv : ScriptFlags := { csv := true }
/-- Checker environment: tx version 2, locktime 5, input NOT final —
so `CheckLockTime(5)` and `CheckSequence(5)` both pass. -/
def ck2 : ScriptChecker := ⟨stubChecker, ⟨2, 5, 0⟩⟩
/-- CSV variant: sequence 5 (disable bit clear, height-type, ≥ operand 5). -/
def ckCsv : ScriptChecker := ⟨stubChecker, ⟨2, 5, 5⟩⟩

/-- Under tapscript the IF-operand minimal-encoding check is
UNCONDITIONAL: it fires even with `minimalIf := false` in the policy
word — BIP342 re-imports MINIMALIF as consensus (named error
`SCRIPT_ERR_TAPSCRIPT_MINIMALIF`; interpreter.cpp:524-526). TPR-063.
[TAGFIX] comment number was TPR-055 (stale the interpreter delta layer draft numbering) — yaml
lean_target maps this theorem to TPR-063. -/
@[rule "TPR-063"]
theorem minimalif_tapscript_unconditional : stepBody ⟨default, default, default, SigVersion.tapscript,
    ByteArray.empty, default⟩ ifOp st1
    = .error ExecError.tapscriptMinimalIf := by rfl

/-- Contrast (same input, legacy witness v0): WITHOUT the policy bit the
non-minimal IF operand is accepted — the rule is policy-gated there
(interpreter.cpp:527-529). -/
theorem minimalif_witnessv0_policy_gated : (match stepBody ⟨default, default, default, SigVersion.witnessV0,
    ByteArray.empty, default⟩ ifOp st1 with
  | .error ExecError.minimalIf => true | _ => false) = false := by rfl

/-- …and WITH the MINIMALIF policy bit witness v0 raises exactly the
legacy `.minimalIf` — the tapscript arm is a separate, always-on rule. -/
theorem minimalif_witnessv0_policy_active : stepBody ⟨default, polIf, default, SigVersion.witnessV0,
    ByteArray.empty, default⟩ ifOp st1
    = .error ExecError.minimalIf := by rfl

/-! ### U3 — CLTV / CSV preserved verbatim under tapscript -/

/-- CLTV's negative-locktime failure is byte-identical under tapscript
(`checkLockTimeDef` / the 0xb1 arm never read `ctx.sv`)… -/
@[rule "TPR-073"]
theorem cltv_negative_tapscript : stepBody ⟨flCltv, default, ck2, SigVersion.tapscript,
    ByteArray.empty, default⟩ cltvOp
    { stack := [ByteArray.mk #[(0x81 : UInt8)]], alt := [], vf := [true],
      opCount := 0, codeSep := 0, vwLeft := none }
    = .error ExecError.negativeLocktime := by rfl

/-- …and under base — same verdict, same code path (BIP342: "OP_CHECKLOCKTIMEVERIFY
and OP_CHECKSEQUENCEVERIFY retain their semantics"). TPR-073. -/
theorem cltv_negative_base : stepBody ⟨flCltv, default, ck2, SigVersion.base,
    ByteArray.empty, default⟩ cltvOp
    { stack := [ByteArray.mk #[(0x81 : UInt8)]], alt := [], vf := [true],
      opCount := 0, codeSep := 0, vwLeft := none }
    = .error ExecError.negativeLocktime := by rfl

/-- CLTV satisfied passes under tapscript (env: version 2, locktime 5,
non-final input). -/
theorem cltv_satisfied_tapscript : (match stepBody ⟨flCltv, default, ck2, SigVersion.tapscript,
    ByteArray.empty, default⟩ cltvOp
    { stack := [ByteArray.mk #[(0x05 : UInt8)]], alt := [], vf := [true],
      opCount := 0, codeSep := 0, vwLeft := none } with
  | .ok _ => true | .error _ => false) = true := by rfl

/-- CSV satisfied passes under tapscript (flag on, env version 2,
sequence 5). TPR-073 face. [TAGFIX] comment number was TPR-058 (stale
the interpreter delta layer draft numbering) — yaml TPR-073 lean_target = cltv_negative_tapscript,
this satisfied-pass companion is the same CLTV/CSV-retained face. -/
theorem csv_satisfied_tapscript : (match stepBody ⟨flCsv, default, ckCsv, SigVersion.tapscript,
    ByteArray.empty, default⟩ csvOp
    { stack := [ByteArray.mk #[(0x05 : UInt8)]], alt := [], vf := [true],
      opCount := 0, codeSep := 0, vwLeft := none } with
  | .ok _ => true | .error _ => false) = true := by rfl

/-- CSV with the flag OFF is a literal nop under tapscript, exactly as
under base (interpreter.cpp:469-470 `if (!flags.verifyLockTimeSequence)
… success`). -/
theorem csv_flag_off_nop_tapscript : stepBody ⟨default, default, ck2, SigVersion.tapscript,
    ByteArray.empty, default⟩ csvOp
    { stack := [ByteArray.mk #[(0x05 : UInt8)]], alt := [], vf := [true],
      opCount := 0, codeSep := 0, vwLeft := none }
    = .ok { stack := [ByteArray.mk #[(0x05 : UInt8)]], alt := [], vf := [true],
            opCount := 0, codeSep := 0, vwLeft := none } := by rfl

/-! ### U3 — CLEANSTACK implicit in witness execution -/

/- Two witness items + a one-op script leave 2 stack elements: the
witness wrapper fails `.cleanstack` even with every policy bit off
(`pol.cleanstack = false` here) — witness scripts implicitly require
cleanstack (BIP342 §Spec step 5 / interpreter.cpp:1878-1881). [TAGFIX] comment number was TPR-063 (stale
the interpreter delta layer draft numbering) — no TPR row owns these theorems; faces =
SWT-012 (witness-implicit cleanstack) and SCR-183 (BIP342 §8 tapscript
consensus re-import). -/

/-- …for witness v0 (the shared wrapper). -/
theorem cleanstack_implicit_witnessv0 : executeWitnessScript 10 [ByteArray.empty, ByteArray.empty] 0
    (ByteArray.mk #[(0x51 : UInt8)]) default default default .witnessV0
    = VerifyOutcome.fail ExecError.cleanstack := by rfl

/-- …and for tapscript (the OP_SUCCESSx scan passes — 0x51 is not a
success opcode — then the same implicit cleanstack applies). -/
theorem cleanstack_implicit_tapscript : executeWitnessScript 10 [ByteArray.empty, ByteArray.empty] 0
    (ByteArray.mk #[(0x51 : UInt8)]) default default default .tapscript
    = VerifyOutcome.fail ExecError.cleanstack := by rfl

/-! ### U3 — the 4-byte CScriptNum bound (shared with OP_ADD) -/

/-- CHECKSIGADD's numeric operand is decoded with the SAME 4-byte
`CScriptNum` bound OP_ADD uses (`decodeNum pol num 4` in both): a 5-byte
operand fails `.scriptNum` even with MINIMALDATA off (`pol = default`,
and `pol.minimalData` is never read by the width check — `decodeBE`
checks `l.length > maxSize` first). BIP342: "If n is larger than 4
bytes, the script MUST fail". TPR-058. [TAGFIX] comment number was
TPR-060 (stale the interpreter delta layer draft numbering) — yaml lean_target maps this theorem
to TPR-058; TPR-060 (OP_SUCCESSx set) lives on Defs.isOpSuccessWire. -/
def num5 : ByteArray :=
  ByteArray.mk #[(0x01 : UInt8), (0x01 : UInt8), (0x01 : UInt8), (0x01 : UInt8), (0x01 : UInt8)]

/-- The bound is structural, not policy: `pol = default` (MINIMALDATA
off) still fails — kernel-reduced, zero axioms. -/
@[rule "TPR-058"]
theorem checksigadd_num4_bound :
    checksigAddStep default default default
      (ByteArray.mk #[(0x01 : UInt8)]) num5 (ByteArray.mk #[(0x02 : UInt8), (0x03 : UInt8)]) none
    = .error ExecError.scriptNum := by rfl

/-! ### U3 — retained witness limits under tapscript -/

/-- Initial witness-stack limit (1000 elements) is checked AFTER the
OP_SUCCESSx scan and BEFORE execution (interpreter.cpp:1864-1865). TPR-066. -/
theorem initial_stack_limit_tapscript :
    executeWitnessScript 10 (List.replicate 1001 ByteArray.empty) 0
      (ByteArray.mk #[(0x51 : UInt8)]) default default default .tapscript
    = VerifyOutcome.fail ExecError.stackSize := by
  set_option maxRecDepth 8000 in rfl

/-- The 520-byte element limit is retained for pushes DURING execution
(interpreter.cpp:457-458): a 521-byte push fails `.pushSize` under
tapscript. TPR-068. -/
theorem push_size_limit_tapscript :
    stepBody ⟨default, default, default, SigVersion.tapscript,
      ByteArray.empty, default⟩
      { ast := .pushBytes (ByteArray.mk (Array.replicate 521 (0x00 : UInt8))),
        wire := 0x4c, next := 522 }
      { stack := [], alt := [], vf := [true], opCount := 0, codeSep := 0, vwLeft := none }
    = .error ExecError.pushSize := by
  set_option maxRecDepth 8000 in rfl

/-- OP_CHECKSIGADD outside tapscript is BAD_OPCODE (interpreter.cpp:1097):
0xba is unassigned in the legacy wire — the 0xba arm's first guard. TPR-057. -/
@[rule "TPR-057"]
theorem checksigadd_outside_tapscript :
    stepBody ⟨default, default, default, SigVersion.base,
      ByteArray.empty, default⟩
      { ast := .op ⟨0xba, by decide⟩, wire := 0xba, next := 1 }
      { stack := [], alt := [], vf := [true], opCount := 0, codeSep := 0, vwLeft := none }
    = .error ExecError.badOpcode := by rfl

/-! ## Mode-dispatch determinism — legacy vs tapscript never conflate -/

/-- The interpreter entry is a pure function of `SigVersion`: equal
arguments with equal SigVersions give equal verdicts — the tapscript
branch is reached exactly when `sv = .tapscript`, never by any legacy
input (dispatch determinism at the mode seam). -/
theorem evalScriptBytes_sv_congr (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (b : ByteArray) (st0 : Stack) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (sv₁ sv₂ : SigVersion) (h : sv₁ = sv₂) :
    evalScriptBytes fuel flags pol b st0 chk sv₁ ed =
      evalScriptBytes fuel flags pol b st0 chk sv₂ ed := by
  subst h; rfl

/-! ## REM-03 — statement-fidelity strengthening of the TPR faces -/

/-- **TPR-055 (legacy arm, both legacy sigversions)**: under BASE and
WITNESS_V0 the dispatch is the pre-tapscript ECDSA path with the budget
slot passed through untouched (interpreter.cpp:402-415). The existing
`evalChecksigDispatch_base_arm` only pins BASE; this covers both legacy
sigversions in one statement. -/
@[rule "TPR-055"]
theorem evalChecksigDispatch_legacy_arm (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (cs : Nat)
    (sv : SigVersion) (b sig pk : ByteArray) (vw : Option Int)
    (hsv : sv = SigVersion.base ∨ sv = SigVersion.witnessV0) :
    evalChecksigDispatch flags pol chk ed sv cs b sig pk vw
      = (match evalChecksigPreTapscript flags pol chk ed sv cs b sig pk with
         | .error e => .error e
         | .ok r => .ok (r, vw)) := by
  rcases hsv with rfl | rfl <;> (unfold evalChecksigDispatch; rfl)

/-- **TPR-055 (mode split)**: the complete SigVersion dispatch — every
legacy sigversion is the ECDSA path, TAPSCRIPT is the Schnorr path
(interpreter.cpp:402-415/410-411). -/
@[rule "TPR-055"]
theorem evalChecksigDispatch_mode_split (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (cs : Nat)
    (b sig pk : ByteArray) (vw : Option Int) :
    (∀ sv, (sv = SigVersion.base ∨ sv = SigVersion.witnessV0) →
        evalChecksigDispatch flags pol chk ed sv cs b sig pk vw
          = (match evalChecksigPreTapscript flags pol chk ed sv cs b sig pk with
             | .error e => .error e
             | .ok r => .ok (r, vw)))
      ∧ evalChecksigDispatch flags pol chk ed SigVersion.tapscript cs b sig pk vw
          = evalChecksigTapscript pol chk ed sig pk vw := by
  refine ⟨?_, ?_⟩
  · intro sv hsv
    exact evalChecksigDispatch_legacy_arm flags pol chk ed cs sv b sig pk vw hsv
  · unfold evalChecksigDispatch; rfl

/-- **TPR-057 (generalized legacy arm)**: OP_CHECKSIGADD (0xba) is
BAD_OPCODE under BASE **and** WITNESS_V0, whenever the step is executed
and the opcode budget admits it (interpreter.cpp:1097). The released
witness is a concrete BASE-only pin; this is the general statement. -/
@[rule "TPR-057"]
theorem checksigadd_outside_tapscript_versions {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0xba)
    (hsv : ctx.sv = SigVersion.base ∨ ctx.sv = SigVersion.witnessV0)
    (hfe : st.vf.all id = true)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st = .error ExecError.badOpcode := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  obtain ⟨flags, pol, chk, sv, bytes, ed⟩ := ctx
  have hsv' : sv = SigVersion.base ∨ sv = SigVersion.witnessV0 := hsv
  rcases hsv' with hsv' | hsv' <;>
    (subst hsv'
     rw [stepBody]
     simp [ha, hw, hfe, hb, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

/-- **TPR-056 (exact stepBody arm)**: executed under TAPSCRIPT, the 0xba
arm runs `checksigAddStep` on the top three stack elements and replaces
them by the single result `n + {0,1}` (interpreter.cpp:1094-1113). This
pins the *whole* state transition, not merely the numeric result. -/
@[rule "TPR-056"]
theorem checksigadd_stepBody_tapscript {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0xba)
    (hsv : ctx.sv = SigVersion.tapscript) (hfe : st.vf.all id = true)
    (h3 : 3 ≤ st.stack.length) :
    stepBody ctx op st =
      (match checksigAddStep ctx.pol ctx.chk ctx.ed
          (topAt st.stack 3) (topAt st.stack 2) (topAt st.stack 1) st.vwLeft with
       | .error e => .error e
       | .ok (r, vw') => .ok { st with vwLeft := vw', stack := encodeScriptNum r false :: st.stack.drop 3 }) := by
  have h3' : ¬ st.stack.length < 3 := by omega
  obtain ⟨flags, pol, chk, sv, bytes, ed⟩ := ctx
  have hsv' : sv = SigVersion.tapscript := hsv
  subst hsv'
  rw [stepBody]
  simp only [ha, hw, hfe, h3', disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp]
  cases checksigAddStep pol chk ed (topAt st.stack 3) (topAt st.stack 2)
    (topAt st.stack 1) st.vwLeft <;> rfl

/-- **TPR-056 (stack effect)**: a successful 0xba step decodes the `num`
operand with the 4-byte bound FIRST and leaves exactly one stack element
`n` or `n + 1` in place of the three consumed operands — the
`OP_ROT OP_SWAP OP_CHECKSIG OP_ADD` expansion's shape. -/
@[rule "TPR-056"]
theorem checksigadd_stepBody_tapscript_stack_effect {ctx : Ctx} {op : WireOp}
    {st st' : State} {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0xba)
    (hsv : ctx.sv = SigVersion.tapscript) (hfe : st.vf.all id = true)
    (h3 : 3 ≤ st.stack.length)
    (h : stepBody ctx op st = .ok st') :
    ∃ n r vw', decodeNum ctx.pol (topAt st.stack 2) 4 = .ok n ∧
      (r = n ∨ r = n + 1) ∧
      st' = { st with vwLeft := vw', stack := encodeScriptNum r false :: st.stack.drop 3 } := by
  rw [checksigadd_stepBody_tapscript ha hw hsv hfe h3] at h
  cases hc : checksigAddStep ctx.pol ctx.chk ctx.ed
      (topAt st.stack 3) (topAt st.stack 2) (topAt st.stack 1) st.vwLeft with
  | error e => rw [hc] at h; simp at h
  | ok p =>
    obtain ⟨r, vw'⟩ := p
    rw [hc] at h
    simp only [Except.ok.injEq] at h
    obtain ⟨n, hn, hr⟩ :=
      Bitcoin.Script.Tapscript.checksigAddStep_result ctx.pol ctx.chk ctx.ed
        (topAt st.stack 3) (topAt st.stack 2) (topAt st.stack 1) st.vwLeft (by rw [hc])
    exact ⟨n, r, vw', hn, hr, h.symm⟩

/-- **TPR-058 (general 4-byte bound)**: ANY `num` operand longer than 4
bytes fails `.scriptNum` regardless of the MINIMALDATA policy word — the
width check is structural (`decodeBE` length > maxSize, script.cpp;
interpreter.cpp:1103). -/
@[rule "TPR-058"]
theorem checksigadd_num4_oversize (pol : PolicyFlags) (num : ByteArray)
    (h : 4 < num.size) :
    decodeNum pol num 4 = .error ExecError.scriptNum := by
  unfold decodeNum decodeScriptNum decodeBE
  have hlen : (bytesOf num).reverse.length > 4 := by
    rw [List.length_reverse, bytesOf_length]; exact h
  rw [ite_eq_left hlen]

/-- **TPR-058 (checksigAddStep corollary)**: the oversize `num` operand
short-circuits OP_CHECKSIGADD before signature evaluation. -/
@[rule "TPR-058"]
theorem checksigAddStep_num4_oversize (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (sig num pk : ByteArray) (vw : Option Int)
    (h : 4 < num.size) :
    checksigAddStep pol chk ed sig num pk vw = .error ExecError.scriptNum := by
  unfold checksigAddStep
  rw [checksigadd_num4_oversize pol num h]

/-- **TPR-063 (iff)**: under TAPSCRIPT, OP_IF/OP_NOTIF fails with
`.tapscriptMinimalIf` EXACTLY when the operand is neither empty nor the
single byte 0x01 (interpreter.cpp:624-629). This makes the consensus
MINIMALIF rule an iff, for both opcodes. -/
@[rule "TPR-063"]
theorem minimalif_tapscript_iff {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0x63 ∨ op.wire = 0x64)
    (hsv : ctx.sv = SigVersion.tapscript) (hfe : st.vf.all id = true)
    (hne : ¬ st.stack.length < 1) :
    (stepBody ctx op st = .error ExecError.tapscriptMinimalIf) ↔
      (1 < (topAt st.stack 1).size ∨
       ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) := by
  obtain ⟨flags, pol, chk, sv, bytes, ed⟩ := ctx
  have hsv' : sv = SigVersion.tapscript := hsv
  subst hsv'
  constructor
  · intro herr
    by_cases hb : 1 < (topAt st.stack 1).size ∨
        ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1)
    · exact hb
    · exfalso
      rcases hw with hw | hw <;>
        (rw [stepBody] at herr
         simp [ha, hw, hfe, hne, hb, disabledWire,
           Bitcoin.Interpreter.stepBody.dispatchOp] at herr)
  · intro hb
    rcases hw with hw | hw <;>
      (rw [stepBody]
       simp [ha, hw, hfe, hne, hb, disabledWire,
         Bitcoin.Interpreter.stepBody.dispatchOp])

/-- `Except.map` commutes with an `if` on a decidable proposition. -/
theorem exceptMap_ite {ε α β : Type} (f : α → β) (c : Prop) [Decidable c]
    (a b : Except ε α) :
    (if c then a else b).map f = if c then a.map f else b.map f := by
  by_cases h : c <;> simp [h]

/-- `Except.map` on a successful result. -/
theorem exceptMap_ok {ε α β : Type} (f : α → β) (a : α) :
    (Except.ok a : Except ε α).map f = Except.ok (f a) := rfl

/-- `Except.map` on a failed result. -/
theorem exceptMap_error {ε α β : Type} (f : α → β) (e : ε) :
    (Except.error e : Except ε α).map f = Except.error e := rfl

/-- **TPR-073 (agreement, projection form)**: for OP_CLTV/CSV the
tapscript and BASE runs agree on the whole observable state
`(stack, alt, vf, codeSep, vwLeft)`; only the legacy opcode counter
differs (tapscript freezes it, `counts`/`opCount'` in `stepBody`).
interpreter.cpp:560-603 has no TAPSCRIPT special case. -/
@[rule "TPR-073"]
theorem cltv_csv_tapscript_base_agree {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0xb1 ∨ op.wire = 0xb2)
    (hsv : ctx.sv = SigVersion.tapscript) (hfe : st.vf.all id = true)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    (stepBody ctx op st).map (fun s => (s.stack, s.alt, s.vf, s.codeSep, s.vwLeft)) =
    (stepBody { ctx with sv := SigVersion.base } op st).map
      (fun s => (s.stack, s.alt, s.vf, s.codeSep, s.vwLeft)) := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  obtain ⟨flags, pol, chk, sv, bytes, ed⟩ := ctx
  have hsv' : sv = SigVersion.tapscript := hsv
  subst hsv'
  rcases hw with hw | hw
  · rw [stepBody]
    rw [stepBody]
    simp [ha, hw, hfe, hb, disabledWire,
      Bitcoin.Interpreter.stepBody.dispatchOp, exceptMap_ite]
    simp only [exceptMap_ok, exceptMap_error]
    by_cases h1 : flags.cltv = false
    · simp [h1]
    · simp only [h1]
      by_cases h2 : st.stack = []
      · simp [h2]
      · simp only [h2]
        cases h3 : decodeNum pol (topAt st.stack 1) 5 with
        | error e => simp [h3]
        | ok n =>
          by_cases h4 : n < 0
          · simp [h3, h4]
          · simp only [h3, h4]
            by_cases h5 : checkLockTimeDef chk.env n = false
            · simp [h5]
            · simp [h5, exceptMap_ok, exceptMap_error]
  · rw [stepBody]
    rw [stepBody]
    simp [ha, hw, hfe, hb, disabledWire,
      Bitcoin.Interpreter.stepBody.dispatchOp, exceptMap_ite]
    simp only [exceptMap_ok, exceptMap_error]
    by_cases h1 : flags.csv = false
    · simp [h1]
    · simp only [h1]
      by_cases h2 : st.stack = []
      · simp [h2]
      · simp only [h2]
        cases h3 : decodeNum pol (topAt st.stack 1) 5 with
        | error e => simp [h3]
        | ok n =>
          by_cases h4 : n < 0
          · simp [h3, h4]
          · simp only [h3, h4]
            by_cases h6 : (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) = 0
            · simp only [h6]
              by_cases h5 : checkSequenceDef chk.env n = false
              · simp [h5]
              · simp [h5, exceptMap_ok, exceptMap_error]
            · simp [h6, exceptMap_ok, exceptMap_error]

end Bitcoin.Script.Tapscript
