import Bitcoin.Interpreter.Defs

/-! # PDW86.lean — TOP-451..455, `stepBody` numeric/stack/op-count faces

Route B: row-face theorems on `Bitcoin.Interpreter.stepBody`; zero core writes. -/

namespace BitcoinProofs.AF.PDW86
open Bitcoin.Interpreter Bitcoin.Numeric

@[rule "SCR-087"]
theorem stepBody_unop {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256} {bn : ScriptNum}
    (ha : op.ast = .op o)
    (hw : op.wire = 0x8b ∨ op.wire = 0x8c ∨ op.wire = 0x8f ∨
          op.wire = 0x90 ∨ op.wire = 0x91 ∨ op.wire = 0x92)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : st.stack ≠ [])
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok bn) :
    stepBody ctx op st =
      .ok { st with
        opCount := st.opCount + 1
        stack := encodeScriptNum (unOp op.wire bn) false :: st.stack.tail } := by
  rcases hw with h | h | h | h | h | h <;>
    (rw [stepBody]; simp [h, ha, hsv, hfe, hbudget, hstack, hdec,
      Nat.not_lt.mpr hbudget, Bitcoin.Interpreter.stepBody.dispatchOp,
      disabledWire, unOp])

@[rule "SCR-088"]
theorem stepBody_binop {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {bn1 bn2 : ScriptNum}
    (ha : op.ast = .op o)
    (hw : op.wire ∈ [0x93, 0x94, 0x9a, 0x9b, 0x9c, 0x9e, 0x9f,
                     0xa0, 0xa1, 0xa2, 0xa3, 0xa4])
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : 2 ≤ st.stack.length)
    (h1 : decodeNum ctx.pol (topAt st.stack 2) 4 = .ok bn1)
    (h2 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok bn2) :
    stepBody ctx op st =
      .ok { st with
        opCount := st.opCount + 1
        stack := encodeScriptNum (binOp op.wire bn1 bn2) false :: st.stack.drop 2 } := by
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
  rcases hw with h | h | h | h | h | h | h | h | h | h | h | h <;>
    (rw [stepBody]; simp [h, ha, hsv, hfe, hbudget, hstack, h1, h2,
      Nat.not_lt.mpr hbudget, Nat.not_lt.mpr hstack,
      Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire, binOp])

@[rule "SCR-089"]
theorem stepBody_within {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    {x mn mx : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0xa5)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : 3 ≤ st.stack.length)
    (h1 : decodeNum ctx.pol (topAt st.stack 3) 4 = .ok x)
    (h2 : decodeNum ctx.pol (topAt st.stack 2) 4 = .ok mn)
    (h3 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok mx) :
    stepBody ctx op st =
      .ok { st with
        opCount := st.opCount + 1
        stack := pushBoolV (mn ≤ x ∧ x < mx) :: st.stack.drop 3 } := by
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hbudget, hstack, h1, h2, h3,
    Nat.not_lt.mpr hbudget, Nat.not_lt.mpr hstack,
    Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire, pushBoolV]

@[rule "SCR-091"]
theorem stepBody_size_raw {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x82)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : 1 ≤ st.stack.length) :
    stepBody ctx op st =
      .ok { st with
        opCount := st.opCount + 1
        stack := encodeScriptNum ((topAt st.stack 1).size : ScriptNum) false
                   :: st.stack } := by
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hbudget, hstack,
    Nat.not_lt.mpr hbudget, Nat.not_lt.mpr hstack,
    Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire]

/-! ## SCR-113 — the 201-op counter for every counted opcode -/

set_option maxHeartbeats 4000000

/-- Every `dispatchOp` success branch except `CHECKMULTISIG(VERIFY)` leaves
`opCount` untouched: the `stepBody` counter was already charged before the
dispatch (interpreter.cpp:459-463), and only `checkMultiSig` adds `nKeys`. -/
theorem dispatchOp_opCount {ctx : Ctx} {op : WireOp} {w : Nat} {fExec : Bool}
    {st st' : State}
    (hw : w ≠ 0xae ∧ w ≠ 0xaf)
    (h : stepBody.dispatchOp ctx op w fExec st = .ok st') :
    st'.opCount = st.opCount := by
  unfold Bitcoin.Interpreter.stepBody.dispatchOp at h
  simp only [] at h
  by_cases h1 : w = 0x61
  · rw [if_pos h1] at h; cases h <;> rfl
  · rw [if_neg h1] at h
    by_cases h2 : w = 0xb1
    · rw [if_pos h2] at h
      repeat' (split at h)
      all_goals (try cases h); all_goals (try rfl)
    · rw [if_neg h2] at h
      by_cases h3 : w = 0xb2
      · rw [if_pos h3] at h
        repeat' (split at h)
        all_goals (try cases h); all_goals (try rfl)
      · rw [if_neg h3] at h
        by_cases h4 : w = 0xb0 ∨ (0xb3 ≤ w ∧ w ≤ 0xb9)
        · rw [if_pos h4] at h
          repeat' (split at h)
          all_goals (try cases h); all_goals (try rfl)
        · rw [if_neg h4] at h
          by_cases h5 : w = 0x63 ∨ w = 0x64
          · rw [if_pos h5] at h
            repeat' (split at h)
            all_goals (try cases h); all_goals (try rfl)
          · rw [if_neg h5] at h
            by_cases h6 : w = 0x65 ∨ w = 0x66
            · rw [if_pos h6] at h; cases h <;> rfl
            · rw [if_neg h6] at h
              by_cases h7 : w = 0x67
              · rw [if_pos h7] at h
                repeat' (split at h)
                all_goals (try cases h); all_goals (try rfl)
              · rw [if_neg h7] at h
                by_cases h8 : w = 0x68
                · rw [if_pos h8] at h
                  repeat' (split at h)
                  all_goals (try cases h); all_goals (try rfl)
                · rw [if_neg h8] at h
                  by_cases h9 : w = 0x69
                  · rw [if_pos h9] at h
                    repeat' (split at h)
                    all_goals (try cases h); all_goals (try rfl)
                  · rw [if_neg h9] at h
                    by_cases h10 : w = 0x6a
                    · rw [if_pos h10] at h; cases h <;> rfl
                    · rw [if_neg h10] at h
                      by_cases h11 : w = 0x6b
                      · rw [if_pos h11] at h
                        repeat' (split at h)
                        all_goals (try cases h); all_goals (try rfl)
                      · rw [if_neg h11] at h
                        by_cases h12 : w = 0x6c
                        · rw [if_pos h12] at h
                          repeat' (split at h)
                          all_goals (try cases h); all_goals (try rfl)
                        · rw [if_neg h12] at h
                          by_cases h13 : w = 0x6d
                          · rw [if_pos h13] at h
                            repeat' (split at h)
                            all_goals (try cases h); all_goals (try rfl)
                          · rw [if_neg h13] at h
                            by_cases h14 : w = 0x6e
                            · rw [if_pos h14] at h
                              repeat' (split at h)
                              all_goals (try cases h); all_goals (try rfl)
                            · rw [if_neg h14] at h
                              by_cases h15 : w = 0x6f
                              · rw [if_pos h15] at h
                                repeat' (split at h)
                                all_goals (try cases h); all_goals (try rfl)
                              · rw [if_neg h15] at h
                                by_cases h16 : w = 0x70
                                · rw [if_pos h16] at h
                                  repeat' (split at h)
                                  all_goals (try cases h); all_goals (try rfl)
                                · rw [if_neg h16] at h
                                  by_cases h17 : w = 0x71
                                  · rw [if_pos h17] at h
                                    repeat' (split at h)
                                    all_goals (try cases h); all_goals (try rfl)
                                  · rw [if_neg h17] at h
                                    by_cases h18 : w = 0x72
                                    · rw [if_pos h18] at h
                                      repeat' (split at h)
                                      all_goals (try cases h); all_goals (try rfl)
                                    · rw [if_neg h18] at h
                                      by_cases h19 : w = 0x73
                                      · rw [if_pos h19] at h
                                        repeat' (split at h)
                                        all_goals (try cases h); all_goals (try rfl)
                                      · rw [if_neg h19] at h
                                        by_cases h20 : w = 0x74
                                        · rw [if_pos h20] at h
                                          repeat' (split at h)
                                          all_goals (try cases h); all_goals (try rfl)
                                        · rw [if_neg h20] at h
                                          by_cases h21 : w = 0x75
                                          · rw [if_pos h21] at h
                                            repeat' (split at h)
                                            all_goals (try cases h); all_goals (try rfl)
                                          · rw [if_neg h21] at h
                                            by_cases h22 : w = 0x76
                                            · rw [if_pos h22] at h
                                              repeat' (split at h)
                                              all_goals (try cases h); all_goals (try rfl)
                                            · rw [if_neg h22] at h
                                              by_cases h23 : w = 0x77
                                              · rw [if_pos h23] at h
                                                repeat' (split at h)
                                                all_goals (try cases h); all_goals (try rfl)
                                              · rw [if_neg h23] at h
                                                by_cases h24 : w = 0x78
                                                · rw [if_pos h24] at h
                                                  repeat' (split at h)
                                                  all_goals (try cases h); all_goals (try rfl)
                                                · rw [if_neg h24] at h
                                                  by_cases h25 : w = 0x79 ∨ w = 0x7a
                                                  · rw [if_pos h25] at h
                                                    repeat' (split at h)
                                                    all_goals (try cases h); all_goals (try rfl)
                                                  · rw [if_neg h25] at h
                                                    by_cases h26 : w = 0x7b
                                                    · rw [if_pos h26] at h
                                                      repeat' (split at h)
                                                      all_goals (try cases h); all_goals (try rfl)
                                                    · rw [if_neg h26] at h
                                                      by_cases h27 : w = 0x7c
                                                      · rw [if_pos h27] at h
                                                        repeat' (split at h)
                                                        all_goals (try cases h); all_goals (try rfl)
                                                      · rw [if_neg h27] at h
                                                        by_cases h28 : w = 0x7d
                                                        · rw [if_pos h28] at h
                                                          repeat' (split at h)
                                                          all_goals (try cases h); all_goals (try rfl)
                                                        · rw [if_neg h28] at h
                                                          by_cases h29 : w = 0x82
                                                          · rw [if_pos h29] at h
                                                            repeat' (split at h)
                                                            all_goals (try cases h); all_goals (try rfl)
                                                          · rw [if_neg h29] at h
                                                            by_cases h30 : w = 0x87 ∨ w = 0x88
                                                            · rw [if_pos h30] at h
                                                              repeat' (split at h)
                                                              all_goals (try cases h); all_goals (try rfl)
                                                            · rw [if_neg h30] at h
                                                              by_cases h31 : w = 0x8b ∨ w = 0x8c ∨ w = 0x8f ∨ w = 0x90 ∨ w = 0x91 ∨ w = 0x92
                                                              · rw [if_pos h31] at h
                                                                repeat' (split at h)
                                                                all_goals (try cases h); all_goals (try rfl)
                                                              · rw [if_neg h31] at h
                                                                by_cases h32 : w = 0x93 ∨ w = 0x94 ∨ (0x9a ≤ w ∧ w ≤ 0xa4)
                                                                · rw [if_pos h32] at h
                                                                  repeat' (split at h)
                                                                  all_goals (try cases h); all_goals (try rfl)
                                                                · rw [if_neg h32] at h
                                                                  by_cases h33 : w = 0xa5
                                                                  · rw [if_pos h33] at h
                                                                    repeat' (split at h)
                                                                    all_goals (try cases h); all_goals (try rfl)
                                                                  · rw [if_neg h33] at h
                                                                    by_cases h34 : 0xa6 ≤ w ∧ w ≤ 0xaa
                                                                    · rw [if_pos h34] at h
                                                                      repeat' (split at h)
                                                                      all_goals (try cases h); all_goals (try rfl)
                                                                    · rw [if_neg h34] at h
                                                                      by_cases h35 : w = 0xab
                                                                      · rw [if_pos h35] at h
                                                                        repeat' (split at h)
                                                                        all_goals (try cases h); all_goals (try rfl)
                                                                      · rw [if_neg h35] at h
                                                                        by_cases h36 : w = 0xac ∨ w = 0xad
                                                                        · rw [if_pos h36] at h
                                                                          repeat' (split at h)
                                                                          all_goals (try cases h); all_goals (try rfl)
                                                                        · rw [if_neg h36] at h
                                                                          by_cases h37 : w = 0xba
                                                                          · rw [if_pos h37] at h
                                                                            repeat' (split at h)
                                                                            all_goals (try cases h); all_goals (try rfl)
                                                                          · rw [if_neg h37] at h
                                                                            by_cases h38 : w = 0xae ∨ w = 0xaf
                                                                            · rw [if_pos h38] at h
                                                                              rcases h38 with h | h
                                                                              · exact absurd h hw.1
                                                                              · exact absurd h hw.2
                                                                            · rw [if_neg h38] at h
                                                                              simp at h

theorem stepBody_opCount_succ {ctx : Ctx} {op : WireOp} {st st' : State}
    (hsv : ctx.sv = .base)
    (hw : 0x60 < op.wire)
    (hwae : op.wire ≠ 0xae ∧ op.wire ≠ 0xaf)
    (h : stepBody ctx op st = .ok st') :
    st'.opCount = st.opCount + 1 := by
  unfold stepBody at h
  simp only [hsv, hw, decide_true, true_or, or_true, true_and, and_true,
    if_true, if_pos rfl] at h
  repeat' (split at h)
  all_goals (try cases h)
  all_goals (try rfl)
  all_goals (try (rw [dispatchOp_opCount hwae h]))

/-- **SCR-113**: every counted opcode (`0x60 < wire`) that `stepBody` accepts
in base mode increments the 201-op counter by exactly one. This is the
per-opcode accounting rule `fExec`-independent in the model (and hence holds
for every executed op); `CHECKMULTISIG(VERIFY)` is excluded only because it
additionally charges `nKeys` on top of the +1. -/
@[rule "SCR-113"]
theorem stepBody_counted_opCount_succ {ctx : Ctx} {op : WireOp} {st st' : State}
    (hsv : ctx.sv = .base)
    (hw : 0x60 < op.wire)
    (hwae : op.wire ≠ 0xae ∧ op.wire ≠ 0xaf)
    (h : stepBody ctx op st = .ok st') :
    st'.opCount = st.opCount + 1 :=
  stepBody_opCount_succ hsv hw hwae h

/-- **SCR-113** CHECKSIG face: `OP_CHECKSIG` / `OP_CHECKSIGVERIFY` each add
exactly one to the 201-op counter (the row's `check` label). -/
@[rule "SCR-113"]
theorem stepBody_checksig_opCount_succ {ctx : Ctx} {op : WireOp} {st st' : State}
    (hw : op.wire = 0xac ∨ op.wire = 0xad)
    (hsv : ctx.sv = .base)
    (h : stepBody ctx op st = .ok st') :
    st'.opCount = st.opCount + 1 := by
  refine stepBody_counted_opCount_succ hsv ?_ ?_ h
  · rcases hw with h | h <;> rw [h] <;> decide
  · rcases hw with h | h <;> rw [h] <;> decide

@[rule "SCR-113"]
theorem stepBody_nop_opCount {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x61)
    (hsv : ctx.sv = .base)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st = .ok { st with opCount := st.opCount + 1 } := by
  rw [stepBody]
  simp [ha, hw, hsv, hbudget, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp]

@[rule "SCR-113"]
theorem stepBody_push16_opCount {ctx : Ctx} {op : WireOp} {st : State}
    (ha : op.ast = .pushNum 16) (hw : op.wire = 0x60)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true) :
    stepBody ctx op st =
      .ok { st with stack := encodeScriptNum (16 : ScriptNum) false :: st.stack } := by
  rw [stepBody]
  simp [ha, hw, hsv, hfe, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp]

end BitcoinProofs.AF.PDW86

#print axioms BitcoinProofs.AF.PDW86.stepBody_unop
#print axioms BitcoinProofs.AF.PDW86.stepBody_binop
#print axioms BitcoinProofs.AF.PDW86.stepBody_within
#print axioms BitcoinProofs.AF.PDW86.stepBody_size_raw
#print axioms BitcoinProofs.AF.PDW86.stepBody_nop_opCount
#print axioms BitcoinProofs.AF.PDW86.stepBody_push16_opCount
#print axioms BitcoinProofs.AF.PDW86.stepBody_counted_opCount_succ
#print axioms BitcoinProofs.AF.PDW86.stepBody_checksig_opCount_succ
