import BitcoinProofs.Theorems.Ops.O02
import BitcoinProofs.Theorems.Ops.O09

/-!
# PDW80B — TOP-424..425: per-pair encoding checks + the 201-op budget

Route-B row faces over the W09 interpreter. Zero core writes.
Rows: SCR-117 (CheckSignatureEncoding + CheckPubKeyEncoding run inside
the CHECKMULTISIG matching loop, per (sig, key) pair) and SCR-022
(any opcode > OP_16 charges one unit of the 201 budget under
BASE/WITNESS_V0; over-budget ⇒ OP_COUNT before dispatch).
-/

namespace BitcoinProofs.AF.PDW80

open Bitcoin.Interpreter Bitcoin.Data
open BitcoinProofs.Theorems.Ops.O02

/-! ## SCR-117 — per-pair encoding gates inside `cmsLoop` -/

/-- A looping pair whose signature fails `checkSigEncoding` returns that
exact error; the pubkey gate is not even consulted. -/
@[rule "SCR-117"]
theorem scr117_sig_encoding_in_loop
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (sv : Bitcoin.Crypto.Seam.SigVersion)
    (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (scriptCode : ByteArray)
    (st : Stack) (f nKeys nSigs isig ikey : Nat) (e : ExecError)
    (hns : nSigs ≠ 0)
    (hsig : checkSigEncoding flags pol (st[isig-1]?.getD default) = some e) :
    cmsLoop flags pol sv chk ed scriptCode st (f+1) nKeys nSigs isig ikey
      = .error e := by
  simp [cmsLoop, hns, hsig]

/-- Same for the pubkey gate: with the signature gate clean, a failing
`checkPubKeyEncoding` aborts the pair with its error. -/
@[rule "SCR-117"]
theorem scr117_pubkey_encoding_in_loop
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (sv : Bitcoin.Crypto.Seam.SigVersion)
    (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (scriptCode : ByteArray)
    (st : Stack) (f nKeys nSigs isig ikey : Nat) (e : ExecError)
    (hns : nSigs ≠ 0)
    (hsig : checkSigEncoding flags pol (st[isig-1]?.getD default) = none)
    (hpk : checkPubKeyEncoding flags pol sv (st[ikey-1]?.getD default) = some e) :
    cmsLoop flags pol sv chk ed scriptCode st (f+1) nKeys nSigs isig ikey
      = .error e := by
  simp [cmsLoop, hns, hsig, hpk]

/-- SCR-117 (combined row face): inside the CHECKMULTISIG matching loop
BOTH encoding gates run per (sig, key) pair in Core's order —
`CheckSignatureEncoding` first, then `CheckPubKeyEncoding` — and either
failure aborts the loop with that exact error
(`interpreter.cpp:1171-1174`). -/
@[rule "SCR-117"]
theorem scr117_encoding_gates_per_pair
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (sv : Bitcoin.Crypto.Seam.SigVersion)
    (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (scriptCode : ByteArray)
    (st : Stack) (f nKeys nSigs isig ikey : Nat) (e : ExecError)
    (hns : nSigs ≠ 0) :
    (checkSigEncoding flags pol (st[isig-1]?.getD default) = some e →
      cmsLoop flags pol sv chk ed scriptCode st (f+1) nKeys nSigs isig ikey
        = .error e) ∧
    (checkSigEncoding flags pol (st[isig-1]?.getD default) = none →
      checkPubKeyEncoding flags pol sv (st[ikey-1]?.getD default) = some e →
      cmsLoop flags pol sv chk ed scriptCode st (f+1) nKeys nSigs isig ikey
        = .error e) := by
  constructor
  · intro hsig
    simp [cmsLoop, hns, hsig]
  · intro hsig hpk
    simp [cmsLoop, hns, hsig, hpk]

/-! ## SCR-022 — opcode > OP_16 charges the budget; over-budget ⇒ OP_COUNT -/

/-- Under BASE/WITNESS_V0 every non-push-shaped opcode with wire byte
above OP_16 (0x60) increments `opCount`; past 201 the step fails with
`OP_COUNT`, before the disabled table and before dispatch. -/
@[rule "SCR-022"]
theorem scr022_budget_exceeded (ctx : Ctx) (op : WireOp) (st : State)
    (c : Fin 256) (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0)
    (hast : op.ast = .op c) (hw : 0x60 < op.wire)
    (hbud : MAX_OPS_PER_SCRIPT < st.opCount + 1) :
    stepBody ctx op st = .error .opCount := by
  simp [stepBody, hast, hsv, hw, hbud]

/-- Executed or not, OP_NOP (0x61 > OP_16) pays one budget unit under
BASE: the step is an identity except for `opCount`. -/
@[rule "SCR-022"]
theorem scr022_nop_increments (ctx : Ctx) (op : WireOp) (st : State)
    (c : Fin 256) (hsv : ctx.sv = .base) (hast : op.ast = .op c)
    (hw : op.wire = 0x61) (hbud : st.opCount < MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st = .ok { st with opCount := st.opCount + 1 } := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  have hd : disabledWire 0x61 = false := by decide
  simp [stepBody, hast, hsv, hw, hb, hd, opNop_effect]

/-! ## Axiom pins -/

/-- info: 'BitcoinProofs.AF.PDW80.scr117_sig_encoding_in_loop' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms scr117_sig_encoding_in_loop

/-- info: 'BitcoinProofs.AF.PDW80.scr117_pubkey_encoding_in_loop' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms scr117_pubkey_encoding_in_loop

/-- info: 'BitcoinProofs.AF.PDW80.scr117_encoding_gates_per_pair' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms scr117_encoding_gates_per_pair

/-- info: 'BitcoinProofs.AF.PDW80.scr022_budget_exceeded' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms scr022_budget_exceeded

/-- info: 'BitcoinProofs.AF.PDW80.scr022_nop_increments' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms scr022_nop_increments

end BitcoinProofs.AF.PDW80
