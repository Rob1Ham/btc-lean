import Bitcoin.Interpreter.Defs
import Bitcoin.Activation.Flags

/-! # PDW95 — row faces: SCR-059 (v0 MINIMALIF), SCR-182
(WITNESS_PUBKEYTYPE policy), SCR-154 (DISCOURAGE_OP_SUCCESS).

Each theorem is a P3pol/P2 flag-conditional face straight off the
executable definitions; no statement is weakened. -/

namespace BitcoinProofs.AF.PDW95
open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Activation Bitcoin.Crypto.Seam

theorem stack_len_pos {l : Stack} (h : l ≠ []) : 0 < l.length := by
  cases l with
  | nil => exact absurd rfl h
  | cons _ _ => simp

/-! ## SCR-059 — witness-v0 MINIMALIF is the same shape check, policy-gated -/

/-- SCR-059: under WITNESS_V0 the BIP141 MINIMALIF policy flag rejects
the same non-`∅`/non-`0x01` operands that tapscript rejects as
consensus (interpreter.cpp:632-637). -/
@[rule "SCR-059"]
theorem stepBody_minimalIf_witnessV0 (ctx : Ctx) (op : WireOp) (st : State)
    (w : Nat) (hw : w = 0x63 ∨ w = 0x64) (hwv : ctx.sv = .witnessV0)
    (hpol : ctx.pol.minimalIf = true) (hne : st.stack ≠ [])
    (hbad : 1 < (topAt st.stack 1).size ∨
            ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    stepBody.dispatchOp ctx op w true st = .error .minimalIf := by
  rcases hw with rfl | rfl
  · have hlen : ¬ (st.stack.length < 1) := by have := stack_len_pos hne; omega
    simp [stepBody.dispatchOp, hwv, hpol, hlen, hbad]
  · have hlen : ¬ (st.stack.length < 1) := by have := stack_len_pos hne; omega
    simp [stepBody.dispatchOp, hwv, hpol, hlen, hbad]

/-! ## SCR-182 — SCRIPT_VERIFY_WITNESS_PUBKEYTYPE is policy -/

/-- SCR-182 (gate direction): with the policy bit off the
compressed-key restriction is never reported. -/
@[rule "SCR-182"]
theorem checkPubKeyEncoding_witnessPubkeyType_off (flags : ScriptFlags)
    (pol : PolicyFlags) (sv : SigVersion) (pk : ByteArray)
    (hp : pol.witnessPubkeyType = false) :
    checkPubKeyEncoding flags pol sv pk ≠ some .witnessPubkeyType := by
  unfold checkPubKeyEncoding
  simp [hp]

/-- SCR-182 (fail direction): policy on + witness-v0 + uncompressed key
(and no earlier STRICTENC trip) ⇒ WITNESS_PUBKEYTYPE. -/
@[rule "SCR-182"]
theorem checkPubKeyEncoding_witnessPubkeyType_on (flags : ScriptFlags)
    (pol : PolicyFlags) (sv : SigVersion) (pk : ByteArray)
    (hp : pol.witnessPubkeyType = true) (hsv : sv = .witnessV0)
    (hc : isCompressedPubKey pk = false)
    (hse : pol.strictEnc = false ∨ isCompressedOrUncompressedPubKey pk = true) :
    checkPubKeyEncoding flags pol sv pk = some .witnessPubkeyType := by
  unfold checkPubKeyEncoding
  rcases hse with h | h <;> simp [hp, hsv, hc, h]

/-- SCR-182 (block-validation projection): the consensus-only flag view
assigns WITNESS_PUBKEYTYPE `false` for every consensus flag set, so
`GetBlockScriptFlags` never enables it. -/
@[rule "SCR-182"]
theorem witnessPubkeyType_absent_from_consensus (f : ScriptFlags) :
    (consensusFullFlags f).policy .witnessPubKeyType = false := rfl

/-! ## SCR-154 — DISCOURAGE_OP_SUCCESS is policy -/

/-- SCR-154 (fail direction): with DISCOURAGE_OP_SUCCESS set, an
OP_SUCCESSx-bearing tapscript fails in the pre-scan, before any size or
stack limit is consulted (interpreter.cpp:1857-1859). -/
@[rule "SCR-154"]
theorem executeWitnessScript_discourageOpSuccess
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (hscan : opSuccessScan exec = true) (hp : pol.discourageOpSuccess = true) :
    executeWitnessScript fuel items vwSer exec flags pol chk .tapscript
      = .fail .discourageOpSuccess := by
  unfold executeWitnessScript
  simp [hscan, hp]

/-- SCR-154 (pass direction, the consensus default): with the policy bit
off the same OP_SUCCESSx script succeeds silently, regardless of witness
items. -/
@[rule "SCR-154"]
theorem executeWitnessScript_opSuccess_policy_off
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (hscan : opSuccessScan exec = true) (hp : pol.discourageOpSuccess = false) :
    executeWitnessScript fuel items vwSer exec flags pol chk .tapscript = .ok := by
  unfold executeWitnessScript
  simp [hscan, hp]

end BitcoinProofs.AF.PDW95
