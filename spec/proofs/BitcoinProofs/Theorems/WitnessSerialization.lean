import Bitcoin.Interpreter.Defs
import Bitcoin.Serialization.Interface

/-! The BIP342 budget size is the actual BIP144 stack encoder length. -/
namespace BitcoinProofs.Theorems.WitnessSerialization
open Bitcoin.Data Bitcoin.Serialization Bitcoin.Crypto.Taproot.Program

private theorem count_size (n : Nat) : (encCSL n).length = (compactSizeEnc n).size := by
  rw [← bL_compactSizeEnc]
  rfl

private theorem payload_size (items : List ByteArray) (seed : Int) :
    items.foldl (fun acc d => acc + Int.ofNat ((compactSizeEnc d.size).size + d.size)) seed =
      seed + Int.ofNat (items.flatMap (fun item => encCSL item.size ++ bL item)).length := by
  induction items generalizing seed with
  | nil => simp
  | cons d rest ih =>
    simp only [List.foldl_cons, List.flatMap_cons, List.length_append, count_size]
    rw [ih]
    have hd : (bL d).length = d.size := rfl
    simp only [hd, Int.ofNat_eq_natCast, Int.natCast_add]
    omega

@[rule "TPR-022", rule "TPR-071", rule "SCR-040"]
theorem witnessSerSize_eq_encoder (items : List ByteArray) :
    witnessSerSize items = Int.ofNat (encStackL items).length := by
  unfold witnessSerSize witnessPayloadSize encStackL
  rw [payload_size]
  simp only [List.length_append, count_size, Int.ofNat_eq_natCast, Int.natCast_add, Int.zero_add]

/-- The live interpreter uses precisely the same size, including annex and
count prefix; no second item-only size definition survives. -/
theorem interpreter_size_eq_encoder (items : List ByteArray) :
    Bitcoin.Interpreter.witnessSerSize items = Int.ofNat (encStackL items).length :=
  witnessSerSize_eq_encoder items
/-- Exact BIP342 initial budget in bytes of the actual witness encoder. -/
@[rule "SCR-040", rule "TPR-022"]
theorem validationWeightInit_eq_encoder (items : List ByteArray) :
    validationWeightInit items = Int.ofNat (encStackL items).length + 50 := by
  rw [validationWeightInit, witnessSerSize_eq_encoder]
  rfl

/-- The size argument sent to the live witness execution is that full
encoder length; annex removal from the execution items cannot change it. -/
theorem executeWitnessScript_encoder_budget (fuel : Nat) (items witness : List ByteArray)
    (script : ByteArray) (flags : Bitcoin.Activation.ScriptFlags)
    (policy : Bitcoin.Interpreter.PolicyFlags) (checker : Bitcoin.Interpreter.ScriptChecker)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData) :
    Bitcoin.Interpreter.executeWitnessScript fuel items
        (Bitcoin.Interpreter.witnessSerSize witness) script flags policy checker .tapscript ed =
      Bitcoin.Interpreter.executeWitnessScript fuel items
        (Int.ofNat (encStackL witness).length) script flags policy checker .tapscript ed := by
  rw [interpreter_size_eq_encoder]

/-- The live execution body supplies the exact full-encoder budget to
EvalScript, preserving the caller's annex/tapleaf data. The three premises
are precisely the early OP_SUCCESS/stack-size/element-size gates. -/
@[rule "SCR-040"]
theorem executeWitnessScript_exact_seed (fuel : Nat) (items witness : List ByteArray)
    (script : ByteArray) (flags : Bitcoin.Activation.ScriptFlags)
    (policy : Bitcoin.Interpreter.PolicyFlags) (checker : Bitcoin.Interpreter.ScriptChecker)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (hscan : Bitcoin.Interpreter.opSuccessScan script = false)
    (hcount : items.length ≤ Bitcoin.Interpreter.MAX_STACK_SIZE)
    (hsizes : items.any (fun d => Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE < d.size) = false) :
    Bitcoin.Interpreter.executeWitnessScript fuel items
        (Bitcoin.Interpreter.witnessSerSize witness) script flags policy checker .tapscript ed =
      match Bitcoin.Interpreter.evalScriptBytes fuel flags policy script items.reverse checker .tapscript
          { ed with
            validationWeightLeftInit := true
            validationWeightLeft := Int.ofNat (encStackL witness).length + 50 } with
      | .error .taprootDataUnavailable => .unjudged
      | .error e => .fail e
      | .ok stack =>
        if stack.length ≠ 1 then .fail .cleanstack
        else if Bitcoin.Numeric.castToBool stack[0]! then .ok else .fail .evalFalse := by
  simp [Bitcoin.Interpreter.executeWitnessScript, Bitcoin.Interpreter.executeWitnessScript.runExec, hscan,
    show ¬Bitcoin.Interpreter.MAX_STACK_SIZE < items.length by omega,
    hsizes, interpreter_size_eq_encoder, Bitcoin.Interpreter.VALIDATION_WEIGHT_OFFSET]
  rfl

end BitcoinProofs.Theorems.WitnessSerialization
