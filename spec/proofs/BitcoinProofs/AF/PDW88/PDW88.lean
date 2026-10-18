import Bitcoin.Interpreter.Defs

/-! PDW88 — INV-043 / INV-059 / SCR-067: the `stepBody` op-count gate,
tapscript MINIMALIF and IF op-count rows (interpreter.cpp @cce32b168). -/

namespace BitcoinProofs.AF.PDW88
open Bitcoin.Interpreter Bitcoin.Numeric

/-- INV-043 (gate half): a non-push opcode (wire > 0x60) on the
BASE/WITNESS_V0 budget path is rejected with OP_COUNT when the charged
`nOpCount` would exceed 201 (interpreter.cpp:461-463). Both counting
sigversions are covered; TAPSCRIPT has no op-count budget. -/
@[rule "INV-043"]
theorem stepBody_opCount_gate (ctx : Ctx) (op : WireOp) (st : State)
    (hsize : (match op.ast with
      | .pushBytes d => d.size ≤ MAX_SCRIPT_ELEMENT_SIZE
      | _ => true) = true)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hw : 0x60 < op.wire)
    (hcnt : MAX_OPS_PER_SCRIPT < st.opCount + 1) :
    stepBody ctx op st = .error .opCount := by
  rcases hsv with hsv | hsv <;>
    (simp [stepBody, hsv, hw, hcnt]
     exact hsize)

/-- INV-043 (CHECKMULTISIG half): the key count is charged wholesale —
`opCount + nKeys > 201` ⇒ OP_COUNT (interpreter.cpp:1126-1131). -/
@[rule "INV-043"]
theorem cms_opCount_charge (ctx : Ctx) (st : State) (nkv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hcond : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = true) :
    stepBody.checkMultiSig ctx 0xae st = .error .opCount := by
  simp [stepBody.checkMultiSig, hsv, hne0, hd, hrange, hcond]

/-- INV-059: in TAPSCRIPT the OP_IF/OP_NOTIF argument is mandatory-minimal —
a non-minimal `vch` fails with TAPSCRIPT_MINIMALIF (interpreter.cpp:620-639). -/
@[rule "INV-059"]
theorem stepBody_tapscript_minimalif_reject {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0x63)
    (hsv : ctx.sv = .tapscript) (hfe : st.vf.all id = true)
    (hs : ¬ (st.stack.length < 1))
    (hbad : 1 < (topAt st.stack 1).size ∨
      ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    stepBody ctx op st = .error .tapscriptMinimalIf := by
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hbad]

/-- SCR-067: an executed IF counts one opcode toward the 201 budget — a
successful step increments `opCount` by exactly 1 in both counting
sigversions, BASE and WITNESS_V0 (interpreter.cpp:460-464). -/
@[rule "SCR-067"]
theorem stepBody_if_counts_opcode {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0x63)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hs : 0 < st.stack.length)
    (hempty : topAt st.stack 1 = ByteArray.empty) :
    stepBody ctx op st = .ok { st with opCount := st.opCount + 1, vf := castToBool (topAt st.stack 1) :: st.vf, stack := st.stack.tail } := by
  have hb' : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  have hs' : ¬ (st.stack.length < 1) := by omega
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb', hs', disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp, hempty])

end BitcoinProofs.AF.PDW88

/-- info: 'BitcoinProofs.AF.PDW88.stepBody_opCount_gate' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW88.stepBody_opCount_gate
/-- info: 'BitcoinProofs.AF.PDW88.cms_opCount_charge' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW88.cms_opCount_charge
/-- info: 'BitcoinProofs.AF.PDW88.stepBody_tapscript_minimalif_reject' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW88.stepBody_tapscript_minimalif_reject
/-- info: 'BitcoinProofs.AF.PDW88.stepBody_if_counts_opcode' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW88.stepBody_if_counts_opcode
