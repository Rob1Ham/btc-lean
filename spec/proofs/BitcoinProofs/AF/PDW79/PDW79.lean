import Bitcoin.Interpreter.Defs

/-! PDW79 — SCR-022/025/074/077/090: the `stepBody` opcode-budget,
stack-depth and numeric-dispatch gates (interpreter.cpp:423-570). -/

namespace BitcoinProofs.AF.PDW79
open Bitcoin.Interpreter Bitcoin.Numeric

/-- `CScriptNum 0` (the empty vector) casts false. -/
theorem castToBool_encodeScriptNum_zero :
    castToBool (encodeScriptNum 0 false) = false := by decide

/-! ## Support (SCR-022 lane yielded to PDW80): op-count increment/reject -/

theorem stepBody_opCount_reject {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : 0x60 < op.wire)
    (hsv : ctx.sv = .base)
    (hoc : MAX_OPS_PER_SCRIPT < st.opCount + 1) :
    stepBody ctx op st = .error .opCount := by
  rw [stepBody]
  simp [ha, hw, hsv, hoc]

theorem stepBody_opCount_tapscript_uncounted {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x73)
    (hsv : ctx.sv = .tapscript) (hfe : st.vf.all id = true)
    (hstack : 0 < st.stack.length)
    (hc : castToBool (topAt st.stack 1) = true) :
    stepBody ctx op st =
    .ok { st with stack := topAt st.stack 1 :: st.stack } := by
  have hs : ¬ (st.stack.length < 1) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hc]

/-! ## SCR-025 — the op-count gate precedes the disabled-opcode gate -/

@[rule "SCR-025"]
theorem stepBody_opCount_precedes_disabled {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x7e)
    (hsv : ctx.sv = .base)
    (hoc : MAX_OPS_PER_SCRIPT < st.opCount + 1) :
    stepBody ctx op st = .error .opCount := by
  rw [stepBody]
  simp [ha, hw, hsv, hoc]

/-! ## SCR-074 — depth pre-check rejects with INVALID_STACK_OPERATION -/

@[rule "SCR-074"]
theorem stepBody_depth_check {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x6d)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 2) :
    stepBody ctx op st = .error .stackUnderflow := by
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp]

/-! ## SCR-077 — OP_IFDUP duplicates iff CastToBool -/

@[rule "SCR-077"]
theorem stepBody_ifdup_true {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x73)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : 0 < st.stack.length)
    (hc : castToBool (topAt st.stack 1) = true) :
    stepBody ctx op st =
    .ok { st with opCount := st.opCount + 1, stack := topAt st.stack 1 :: st.stack } := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  have hs : ¬ (st.stack.length < 1) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hc]

@[rule "SCR-077"]
theorem stepBody_ifdup_false {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x73)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : 0 < st.stack.length)
    (hc : castToBool (topAt st.stack 1) = false) :
    stepBody ctx op st = .ok { st with opCount := st.opCount + 1 } := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  have hs : ¬ (st.stack.length < 1) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hc]

/-! ## SCR-090 — OP_NUMEQUALVERIFY false ⇒ NUMEQUALVERIFY error -/

@[rule "SCR-090"]
theorem stepBody_numequalverify_false {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} {bn1 bn2 : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x9d)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : 1 < st.stack.length)
    (h1 : decodeNum ctx.pol (topAt st.stack 2) 4 = .ok bn1)
    (h2 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok bn2)
    (hne : bn1 ≠ bn2) :
    stepBody ctx op st = .error .numEqualVerifyFailed := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  have hs : ¬ (st.stack.length < 2) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, h1, h2, hne, binOp,
    castToBool_encodeScriptNum_zero]



/-! ## SCR-075 — OP_PICK/OP_ROLL index out of range ⇒ INVALID_STACK_OPERATION -/

@[rule "SCR-075"]
theorem stepBody_pickroll_oob {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x7a)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hoob : n < 0 ∨ (st.stack.tail).length ≤ n.toNat) :
    stepBody ctx op st = .error .stackUnderflow := by
  have hs : ¬ (st.stack.length < 2) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hdec, List.length_tail]
  have hlen : st.stack.length = (List.tail st.stack).length + 1 := by
    rw [List.length_tail]
    omega
  intro hn
  have htail : (List.tail st.stack).length ≤ n.toNat := by
    rcases hoob with h | h
    · exact absurd h (Int.not_lt.mpr hn)
    · exact h
  omega

/-- **SCR-075**: OP_PICK's depth check — the same `ScriptNum(top)` /
`n ∈ [0, tail.length)` range gate as ROLL, else INVALID_STACK_OPERATION. -/
@[rule "SCR-075"]
theorem stepBody_pick_oob {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x79)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hoob : n < 0 ∨ (st.stack.tail).length ≤ n.toNat) :
    stepBody ctx op st = .error .stackUnderflow := by
  have hs : ¬ (st.stack.length < 2) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hdec, List.length_tail]
  have hlen : st.stack.length = (List.tail st.stack).length + 1 := by
    rw [List.length_tail]
    omega
  intro hn
  have htail : (List.tail st.stack).length ≤ n.toNat := by
    rcases hoob with h | h
    · exact absurd h (Int.not_lt.mpr hn)
    · exact h
  omega

/-- **SCR-075**, PICK success arm: an in-range index pushes the selected
item back on top, leaving the rest of the stack (and the index entry)
behind — no erasure. -/
@[rule "SCR-075"]
theorem stepBody_pick_ok {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x79)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hnn : 0 ≤ n) (hbound : n.toNat < (st.stack.tail).length) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1, stack := st.stack.tail[n.toNat]! :: st.stack.tail } := by
  have hs : ¬ (st.stack.length < 2) := by omega
  have hlen : st.stack.length = (List.tail st.stack).length + 1 := by
    rw [List.length_tail]
    omega
  have hcond : ¬ (n < 0 ∨ st.stack.length ≤ n.toNat + 1) := by
    rintro (h | h)
    · exact (Int.not_lt.mpr hnn) h
    · omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hdec, hcond]

/-- **SCR-075**, ROLL success arm: an in-range index pushes the selected
item on top AND erases it from its old position (the `take`/`drop`
splice). -/
@[rule "SCR-075"]
theorem stepBody_roll_ok {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x7a)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hnn : 0 ≤ n) (hbound : n.toNat < (st.stack.tail).length) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1, stack := st.stack.tail[n.toNat]! :: (st.stack.tail.take n.toNat ++ st.stack.tail.drop (n.toNat + 1)) } := by
  have hs : ¬ (st.stack.length < 2) := by omega
  have hlen : st.stack.length = (List.tail st.stack).length + 1 := by
    rw [List.length_tail]
    omega
  have hcond : ¬ (n < 0 ∨ st.stack.length ≤ n.toNat + 1) := by
    rintro (h | h)
    · exact (Int.not_lt.mpr hnn) h
    · omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hdec, hcond]

/-! ### SCR-075 — the witness-v0 / tapscript arms and the unexecuted skip

Core's OP_PICK/OP_ROLL case (interpreter.cpp:833-849) has no signature-
version branch: after popping the index it checks `n < 0 || n >=
stack.size()` against the *remaining* stack, so the same transition runs
in BASE, WITNESS_V0 and TAPSCRIPT. The only difference is the surrounding
opcode counter: BASE/WITNESS_V0 count 0x79/0x7a toward the 201-op budget,
tapscript does not (Defs.lean:793-798). The lemmas below add those arms
without changing the four base-row declarations. -/

@[rule "SCR-075"]
theorem stepBody_pickroll_oob_witnessV0 {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x7a)
    (hsv : ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hoob : n < 0 ∨ (st.stack.tail).length ≤ n.toNat) :
    stepBody ctx op st = .error .stackUnderflow := by
  have hs : ¬ (st.stack.length < 2) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hdec, List.length_tail]
  have hlen : st.stack.length = (List.tail st.stack).length + 1 := by
    rw [List.length_tail]
    omega
  intro hn
  have htail : (List.tail st.stack).length ≤ n.toNat := by
    rcases hoob with h | h
    · exact absurd h (Int.not_lt.mpr hn)
    · exact h
  omega

@[rule "SCR-075"]
theorem stepBody_pickroll_oob_tapscript {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x7a)
    (hsv : ctx.sv = .tapscript) (hfe : st.vf.all id = true)
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hoob : n < 0 ∨ (st.stack.tail).length ≤ n.toNat) :
    stepBody ctx op st = .error .stackUnderflow := by
  have hs : ¬ (st.stack.length < 2) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hdec, List.length_tail]
  have hlen : st.stack.length = (List.tail st.stack).length + 1 := by
    rw [List.length_tail]
    omega
  intro hn
  have htail : (List.tail st.stack).length ≤ n.toNat := by
    rcases hoob with h | h
    · exact absurd h (Int.not_lt.mpr hn)
    · exact h
  omega

@[rule "SCR-075"]
theorem stepBody_pick_oob_witnessV0 {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x79)
    (hsv : ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hoob : n < 0 ∨ (st.stack.tail).length ≤ n.toNat) :
    stepBody ctx op st = .error .stackUnderflow := by
  have hs : ¬ (st.stack.length < 2) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hdec, List.length_tail]
  have hlen : st.stack.length = (List.tail st.stack).length + 1 := by
    rw [List.length_tail]
    omega
  intro hn
  have htail : (List.tail st.stack).length ≤ n.toNat := by
    rcases hoob with h | h
    · exact absurd h (Int.not_lt.mpr hn)
    · exact h
  omega

@[rule "SCR-075"]
theorem stepBody_pick_oob_tapscript {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x79)
    (hsv : ctx.sv = .tapscript) (hfe : st.vf.all id = true)
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hoob : n < 0 ∨ (st.stack.tail).length ≤ n.toNat) :
    stepBody ctx op st = .error .stackUnderflow := by
  have hs : ¬ (st.stack.length < 2) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hdec, List.length_tail]
  have hlen : st.stack.length = (List.tail st.stack).length + 1 := by
    rw [List.length_tail]
    omega
  intro hn
  have htail : (List.tail st.stack).length ≤ n.toNat := by
    rcases hoob with h | h
    · exact absurd h (Int.not_lt.mpr hn)
    · exact h
  omega

@[rule "SCR-075"]
theorem stepBody_pick_ok_witnessV0 {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x79)
    (hsv : ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hnn : 0 ≤ n) (hbound : n.toNat < (st.stack.tail).length) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1, stack := st.stack.tail[n.toNat]! :: st.stack.tail } := by
  have hs : ¬ (st.stack.length < 2) := by omega
  have hlen : st.stack.length = (List.tail st.stack).length + 1 := by
    rw [List.length_tail]
    omega
  have hcond : ¬ (n < 0 ∨ st.stack.length ≤ n.toNat + 1) := by
    rintro (h | h)
    · exact (Int.not_lt.mpr hnn) h
    · omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hdec, hcond]

@[rule "SCR-075"]
theorem stepBody_pick_ok_tapscript {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x79)
    (hsv : ctx.sv = .tapscript) (hfe : st.vf.all id = true)
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hnn : 0 ≤ n) (hbound : n.toNat < (st.stack.tail).length) :
    stepBody ctx op st =
      .ok { st with stack := st.stack.tail[n.toNat]! :: st.stack.tail } := by
  have hs : ¬ (st.stack.length < 2) := by omega
  have hlen : st.stack.length = (List.tail st.stack).length + 1 := by
    rw [List.length_tail]
    omega
  have hcond : ¬ (n < 0 ∨ st.stack.length ≤ n.toNat + 1) := by
    rintro (h | h)
    · exact (Int.not_lt.mpr hnn) h
    · omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hdec, hcond]

@[rule "SCR-075"]
theorem stepBody_roll_ok_witnessV0 {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x7a)
    (hsv : ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hnn : 0 ≤ n) (hbound : n.toNat < (st.stack.tail).length) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1, stack := st.stack.tail[n.toNat]! :: (st.stack.tail.take n.toNat ++ st.stack.tail.drop (n.toNat + 1)) } := by
  have hs : ¬ (st.stack.length < 2) := by omega
  have hlen : st.stack.length = (List.tail st.stack).length + 1 := by
    rw [List.length_tail]
    omega
  have hcond : ¬ (n < 0 ∨ st.stack.length ≤ n.toNat + 1) := by
    rintro (h | h)
    · exact (Int.not_lt.mpr hnn) h
    · omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hdec, hcond]

@[rule "SCR-075"]
theorem stepBody_roll_ok_tapscript {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x7a)
    (hsv : ctx.sv = .tapscript) (hfe : st.vf.all id = true)
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hnn : 0 ≤ n) (hbound : n.toNat < (st.stack.tail).length) :
    stepBody ctx op st =
      .ok { st with stack := st.stack.tail[n.toNat]! :: (st.stack.tail.take n.toNat ++ st.stack.tail.drop (n.toNat + 1)) } := by
  have hs : ¬ (st.stack.length < 2) := by omega
  have hlen : st.stack.length = (List.tail st.stack).length + 1 := by
    rw [List.length_tail]
    omega
  have hcond : ¬ (n < 0 ∨ st.stack.length ≤ n.toNat + 1) := by
    rintro (h | h)
    · exact (Int.not_lt.mpr hnn) h
    · omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hdec, hcond]

/-- SCR-075 unexecuted arm (BASE/WITNESS_V0): a dead PICK/ROLL is skipped
but still burns one opcode-budget unit (interpreter.cpp:459-464, :493). -/
@[rule "SCR-075"]
theorem stepBody_pickroll_unexecuted_base {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x79 ∨ op.wire = 0x7a)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = false)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1)) :
    stepBody ctx op st = .ok { st with opCount := st.opCount + 1 } := by
  rcases hw with hw | hw
  · rcases hsv with hsv | hsv
    · rw [stepBody]; simp [ha, hsv, hfe, hb, disabledWire, hw]
    · rw [stepBody]; simp [ha, hsv, hfe, hb, disabledWire, hw]
  · rcases hsv with hsv | hsv
    · rw [stepBody]; simp [ha, hsv, hfe, hb, disabledWire, hw]
    · rw [stepBody]; simp [ha, hsv, hfe, hb, disabledWire, hw]

/-- SCR-075 unexecuted arm (TAPSCRIPT): a dead PICK/ROLL is skipped and,
unlike BASE/WITNESS_V0, does not touch the opcode counter or its budget
(interpreter.cpp:459-464 counts only BASE/WITNESS_V0). -/
@[rule "SCR-075"]
theorem stepBody_pickroll_unexecuted_tapscript {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x79 ∨ op.wire = 0x7a)
    (hsv : ctx.sv = .tapscript) (hfe : st.vf.all id = false) :
    stepBody ctx op st = .ok st := by
  rcases hw with hw | hw
  · rw [stepBody]; simp [ha, hsv, hfe, disabledWire, hw]
  · rw [stepBody]; simp [ha, hsv, hfe, disabledWire, hw]

/-! ## Axiom pins -/

/-- info: 'BitcoinProofs.AF.PDW79.stepBody_pickroll_oob' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW79.stepBody_pickroll_oob
/-- info: 'BitcoinProofs.AF.PDW79.stepBody_opCount_tapscript_uncounted' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW79.stepBody_opCount_tapscript_uncounted
/-- info: 'BitcoinProofs.AF.PDW79.stepBody_opCount_precedes_disabled' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW79.stepBody_opCount_precedes_disabled
/-- info: 'BitcoinProofs.AF.PDW79.stepBody_depth_check' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW79.stepBody_depth_check
/-- info: 'BitcoinProofs.AF.PDW79.stepBody_ifdup_true' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW79.stepBody_ifdup_true
/-- info: 'BitcoinProofs.AF.PDW79.stepBody_ifdup_false' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW79.stepBody_ifdup_false
/-- info: 'BitcoinProofs.AF.PDW79.stepBody_numequalverify_false' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW79.stepBody_numequalverify_false

end BitcoinProofs.AF.PDW79
