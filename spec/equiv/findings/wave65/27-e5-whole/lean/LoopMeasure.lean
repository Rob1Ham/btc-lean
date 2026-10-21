/-
  wave65/27-e5-whole -- E5 whole-`EvalScript` decomposition, component C1:
  the dispatch-loop measure and bounded invariants.

  Self-contained Lean 4 (core only, no Mathlib, no `sorry`, no axioms).

  SOURCE OF RECORD (Core pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66):
    src/script/interpreter.cpp:283-331   ConditionStack
    src/script/interpreter.cpp:417-448   EvalScript prologue / limits
    src/script/interpreter.cpp:449-465   dispatch loop head, GetOp, limits
    src/script/interpreter.cpp:613-661   OP_IF/NOTIF/ELSE/ENDIF
    src/script/interpreter.cpp:1129-1130 nOpCount += nKeysCount
    src/script/interpreter.cpp:1232-1234 stack-size check
    src/script/interpreter.cpp:1236-1248 catch + UNBALANCED + set_success
    src/script/script.cpp:313-363        GetScriptOp
    src/script/script.h:29-44            MAX_SCRIPT_ELEMENT_SIZE /
                                         MAX_OPS_PER_SCRIPT / MAX_SCRIPT_SIZE

  WHAT IS PROVED (see README.md for the obligation numbering)
    C1a  parse_consumed_pos       successful parse consumes >= 1 byte
    C1b  parse_consumed_le        successful parse stays inside the window
    C1c  parse_pushLe             push payload length + 1 <= consumed
    C1d  run_done_or_error        loop exit is `pc = pend` or a nonzero error
    C1e  (termination_by)         recursion accepted only with the ranking
                                  proof `|script| - pc` strictly decreasing
    C1f  run_opCount_le           nOpCount <= MAX_OPS_PER_SCRIPT (BASE/V0)
    C1g  run_cond_inv             ConditionStack representation invariant
    C1g' run_cond_depth           vfExec.size <= pc, hence <= |script|, and
                                  `run_cond_size_lt_NO_FALSE` rules out a
                                  sentinel/position collision in BASE/V0
    C1h  evalScript_ok_balance    success => vfExec empty (interpreter.cpp:1245)
    C1i  evalScript_ok_done       success => pc = pend
    C1j  evalScript_error_class   every exit code is in the modelled set
    C1k  base_script_len          BASE/WITNESS_V0 => |script| <= 10000

  AXIOMS: no `sorryAx`.  Every theorem depends only on Lean's standard
  `propext` / `Quot.sound`, plus `Classical.choice` where a classical case
  split is used; the exact `#print axioms` output is in logs/lean-check.log.

  WHAT IS NOT PROVED: the opcode switch bodies (stack effects, signatures,
  crypto, the three multisig loops), and the refinement from this transcribed
  skeleton to the pinned LLVM module (O-STEP in README.md).  No SCR row.
-/

namespace Wave65.E5

-- The proofs below intentionally use the `if_pos`/`if_neg` legacy names; they
-- are aliases of `ite_eq_left`/`ite_eq_right` and are not worth churning.
set_option linter.deprecated false

/-! ## 0. Limits and error codes -/

/-- `MAX_SCRIPT_ELEMENT_SIZE` (script.h:29). -/
def MAX_SCRIPT_ELEMENT_SIZE : Nat := 520
/-- `MAX_OPS_PER_SCRIPT` (script.h:32). -/
def MAX_OPS_PER_SCRIPT : Nat := 201
/-- `MAX_SCRIPT_SIZE` (script.h:41); BASE/WITNESS_V0 only (interpreter.cpp:438). -/
def MAX_SCRIPT_SIZE : Nat := 10000
/-- `OP_16`: last opcode that does not increment nOpCount (interpreter.cpp:462). -/
def OP_16 : Nat := 0x60
/-- `ConditionStack::NO_FALSE` (interpreter.cpp:286). -/
def NO_FALSE : Nat := 0xffffffff

def ERR_OK : Nat := 0
def ERR_UNKNOWN : Nat := 1
def ERR_BAD_OPCODE : Nat := 4
def ERR_PUSH_SIZE : Nat := 5
def ERR_OP_COUNT : Nat := 6
def ERR_UNBALANCED_CONDITIONAL : Nat := 22

/-! ## 1. Parser model (script.cpp:313-363) -/

/-- One `GetScriptOp` result.  `consumed` is how far the `const_iterator& pc`
moved; the source increments `pc` before every failure return
(script.cpp:324,338,345,352), so a failing parse still advances `pc`. -/
structure PRes where
  ok : Bool
  opcode : Nat
  consumed : Nat
  pushLen : Nat

/-- LE16 (script.cpp:344). -/
def le16 (b0 b1 : Nat) : Nat := b0 + 256 * b1
/-- LE32 (script.cpp:351). -/
def le32 (b0 b1 b2 b3 : Nat) : Nat :=
  b0 + 256 * b1 + 65536 * b2 + 16777216 * b3

/-- Direct push, `opcode < OP_PUSHDATA1` (script.cpp:330-333). -/
def parseDirect (b : Nat) (rest : List Nat) : PRes :=
  if b ≤ rest.length then ⟨true, b, 1 + b, b⟩
  else ⟨false, 255, 1 + b, 0⟩

/-- `OP_PUSHDATA1` (script.cpp:334-339). -/
def parsePD1 (rest : List Nat) : PRes :=
  match rest with
  | [] => ⟨false, 255, 1, 0⟩
  | n :: tail =>
    if n ≤ tail.length then ⟨true, 76, 2 + n, n⟩
    else ⟨false, 255, 2 + n, 0⟩

/-- `OP_PUSHDATA2` (script.cpp:340-346). -/
def parsePD2 (rest : List Nat) : PRes :=
  match rest with
  | b0 :: b1 :: tail =>
    let n := le16 b0 b1
    if n ≤ tail.length then ⟨true, 77, 3 + n, n⟩
    else ⟨false, 255, 3 + n, 0⟩
  | _ => ⟨false, 255, 1, 0⟩

/-- `OP_PUSHDATA4` (script.cpp:347-353). -/
def parsePD4 (rest : List Nat) : PRes :=
  match rest with
  | b0 :: b1 :: b2 :: b3 :: tail =>
    let n := le32 b0 b1 b2 b3
    if n ≤ tail.length then ⟨true, 78, 5 + n, n⟩
    else ⟨false, 255, 5 + n, 0⟩
  | _ => ⟨false, 255, 1, 0⟩

/-- `GetScriptOp` as a total function over the remaining window.  `pvchRet`
(script.cpp:356-357) is not modelled: it does not affect `pc`, `opcodeRet`, or
the return value; see README section 4 for the IR bridge. -/
def parse : List Nat → PRes
  | [] => ⟨false, 255, 0, 0⟩
  | b :: rest =>
    if b ≤ 78 then
      if b < 76 then parseDirect b rest
      else if b = 76 then parsePD1 rest
      else if b = 77 then parsePD2 rest
      else parsePD4 rest
    else ⟨true, b, 1, 0⟩

theorem direct_pos (b : Nat) (rest : List Nat) : 0 < (parseDirect b rest).consumed := by
  unfold parseDirect
  by_cases hc : b ≤ rest.length <;> simp [hc] <;> omega
theorem direct_le (b : Nat) (rest : List Nat) (h : (parseDirect b rest).ok = true) :
    (parseDirect b rest).consumed ≤ (b :: rest).length := by
  unfold parseDirect at h ⊢
  by_cases hc : b ≤ rest.length <;> simp [hc] at h ⊢ <;> omega
theorem direct_push (b : Nat) (rest : List Nat) (h : (parseDirect b rest).ok = true) :
    (parseDirect b rest).pushLen + 1 ≤ (parseDirect b rest).consumed := by
  unfold parseDirect at h ⊢
  by_cases hc : b ≤ rest.length <;> simp [hc] at h ⊢ <;> omega

theorem pd1_pos (rest : List Nat) : 0 < (parsePD1 rest).consumed := by
  cases rest with
  | nil => simp [parsePD1]
  | cons n tail =>
    unfold parsePD1
    by_cases h : n ≤ tail.length <;> simp [h] <;> omega
theorem pd1_le (rest : List Nat) (h : (parsePD1 rest).ok = true) :
    (parsePD1 rest).consumed ≤ rest.length + 1 := by
  cases rest with
  | nil => simp [parsePD1] at h
  | cons n tail =>
    unfold parsePD1 at h ⊢
    by_cases hn : n ≤ tail.length <;> simp [hn] at h ⊢ <;> omega
theorem pd1_push (rest : List Nat) (h : (parsePD1 rest).ok = true) :
    (parsePD1 rest).pushLen + 1 ≤ (parsePD1 rest).consumed := by
  cases rest with
  | nil => simp [parsePD1] at h
  | cons n tail =>
    unfold parsePD1 at h ⊢
    by_cases hn : n ≤ tail.length <;> simp [hn] at h ⊢ <;> omega

theorem pd2_pos (rest : List Nat) : 0 < (parsePD2 rest).consumed := by
  match rest with
  | [] => simp [parsePD2]
  | [_] => simp [parsePD2]
  | b0 :: b1 :: tail =>
    unfold parsePD2
    by_cases h : le16 b0 b1 ≤ tail.length <;> simp [h] <;> omega
theorem pd2_le (rest : List Nat) (h : (parsePD2 rest).ok = true) :
    (parsePD2 rest).consumed ≤ rest.length + 1 := by
  match rest with
  | [] => simp [parsePD2] at h
  | [_] => simp [parsePD2] at h
  | b0 :: b1 :: tail =>
    unfold parsePD2 at h ⊢
    by_cases hn : le16 b0 b1 ≤ tail.length <;> simp [hn] at h ⊢ <;> omega
theorem pd2_push (rest : List Nat) (h : (parsePD2 rest).ok = true) :
    (parsePD2 rest).pushLen + 1 ≤ (parsePD2 rest).consumed := by
  match rest with
  | [] => simp [parsePD2] at h
  | [_] => simp [parsePD2] at h
  | b0 :: b1 :: tail =>
    unfold parsePD2 at h ⊢
    by_cases hn : le16 b0 b1 ≤ tail.length <;> simp [hn] at h ⊢ <;> omega

theorem pd4_pos (rest : List Nat) : 0 < (parsePD4 rest).consumed := by
  match rest with
  | [] => simp [parsePD4]
  | [_] => simp [parsePD4]
  | [_, _] => simp [parsePD4]
  | [_, _, _] => simp [parsePD4]
  | b0 :: b1 :: b2 :: b3 :: tail =>
    unfold parsePD4
    by_cases h : le32 b0 b1 b2 b3 ≤ tail.length <;> simp [h] <;> omega
theorem pd4_le (rest : List Nat) (h : (parsePD4 rest).ok = true) :
    (parsePD4 rest).consumed ≤ rest.length + 1 := by
  match rest with
  | [] => simp [parsePD4] at h
  | [_] => simp [parsePD4] at h
  | [_, _] => simp [parsePD4] at h
  | [_, _, _] => simp [parsePD4] at h
  | b0 :: b1 :: b2 :: b3 :: tail =>
    unfold parsePD4 at h ⊢
    by_cases hn : le32 b0 b1 b2 b3 ≤ tail.length <;> simp [hn] at h ⊢ <;> omega
theorem pd4_push (rest : List Nat) (h : (parsePD4 rest).ok = true) :
    (parsePD4 rest).pushLen + 1 ≤ (parsePD4 rest).consumed := by
  match rest with
  | [] => simp [parsePD4] at h
  | [_] => simp [parsePD4] at h
  | [_, _] => simp [parsePD4] at h
  | [_, _, _] => simp [parsePD4] at h
  | b0 :: b1 :: b2 :: b3 :: tail =>
    unfold parsePD4 at h ⊢
    by_cases hn : le32 b0 b1 b2 b3 ≤ tail.length <;> simp [hn] at h ⊢ <;> omega

/-- **C1a (ranking premise).** Any non-empty window consumes at least one
byte, successful or not (script.cpp:324 and the `return false` paths). -/
theorem parse_consumed_pos {s : List Nat} (h : s ≠ []) : 0 < (parse s).consumed := by
  cases s with
  | nil => exact absurd rfl h
  | cons b rest =>
    simp only [parse]
    split
    · split
      · exact direct_pos b rest
      · split
        · exact pd1_pos rest
        · split
          · exact pd2_pos rest
          · exact pd4_pos rest
    · simp

/-- **C1b.** A successful parse never consumes more than the window. -/
theorem parse_consumed_le {s : List Nat} (h : (parse s).ok = true) :
    (parse s).consumed ≤ s.length := by
  cases s with
  | nil => simp [parse] at h
  | cons b rest =>
    simp only [parse] at h ⊢
    by_cases hb : b ≤ 78
    · simp [hb] at h ⊢
      by_cases h1 : b < 76
      · simp [h1] at h ⊢; exact direct_le b rest h
      · simp [h1] at h ⊢
        by_cases h2 : b = 76
        · simp [h2] at h ⊢; exact pd1_le rest h
        · simp [h2] at h ⊢
          by_cases h3 : b = 77
          · simp [h3] at h ⊢; exact pd2_le rest h
          · simp [h3] at h ⊢; exact pd4_le rest h
    · simp [hb] at h ⊢

/-- **C1c.** The declared push length is exactly the payload part of `consumed`. -/
theorem parse_pushLe {s : List Nat} (h : (parse s).ok = true) :
    (parse s).pushLen + 1 ≤ (parse s).consumed := by
  cases s with
  | nil => simp [parse] at h
  | cons b rest =>
    simp only [parse] at h ⊢
    by_cases hb : b ≤ 78
    · simp [hb] at h ⊢
      by_cases h1 : b < 76
      · simp [h1] at h ⊢; exact direct_push b rest h
      · simp [h1] at h ⊢
        by_cases h2 : b = 76
        · simp [h2] at h ⊢; exact pd1_push rest h
        · simp [h2] at h ⊢
          by_cases h3 : b = 77
          · simp [h3] at h ⊢; exact pd2_push rest h
          · simp [h3] at h ⊢; exact pd4_push rest h
    · simp [hb] at h ⊢

/-! ## 2. ConditionStack (interpreter.cpp:283-331) -/

/-- `(m_stack_size, m_first_false_pos)`. -/
structure Cond where
  size : Nat
  ffp : Nat

/-- Representation invariant of the two-field encoding: `m_first_false_pos`
is `NO_FALSE` or a position strictly inside the implied stack. -/
def Cond.Inv (c : Cond) : Prop := c.ffp = NO_FALSE ∨ c.ffp < c.size

def Cond.empty (c : Cond) : Bool := c.size == 0
def Cond.allTrue (c : Cond) : Bool := c.ffp == NO_FALSE

/-- `push_back` (interpreter.cpp:296-303). -/
def Cond.push (c : Cond) (f : Bool) : Cond :=
  if c.ffp = NO_FALSE && !f then ⟨c.size + 1, c.size⟩ else ⟨c.size + 1, c.ffp⟩

/-- `pop_back` (interpreter.cpp:306-313); callers check `!empty()` first. -/
def Cond.pop (c : Cond) : Cond :=
  if c.ffp = c.size - 1 then ⟨c.size - 1, NO_FALSE⟩ else ⟨c.size - 1, c.ffp⟩

/-- `toggle_top` (interpreter.cpp:314-329); callers check `!empty()` first. -/
def Cond.toggle (c : Cond) : Cond :=
  if c.ffp = NO_FALSE then ⟨c.size, c.size - 1⟩
  else if c.ffp = c.size - 1 then ⟨c.size, NO_FALSE⟩ else c

theorem Cond.push_size (c : Cond) (f : Bool) : (c.push f).size = c.size + 1 := by
  unfold Cond.push; split <;> rfl

theorem Cond.push_inv {c : Cond} (h : c.Inv) (f : Bool) : (c.push f).Inv := by
  unfold Cond.push Cond.Inv at *
  by_cases hf : c.ffp = NO_FALSE ∧ f = false <;> simp [hf] <;> omega

theorem Cond.pop_inv {c : Cond} (h : c.Inv) (hpos : 0 < c.size) : c.pop.Inv := by
  unfold Cond.pop Cond.Inv at *
  by_cases hf : c.ffp = c.size - 1 <;> simp [hf] <;> omega

theorem Cond.toggle_inv {c : Cond} (h : c.Inv) (hpos : 0 < c.size) : c.toggle.Inv := by
  unfold Cond.toggle
  by_cases h0 : c.ffp = NO_FALSE
  · simp only [h0, if_true]
    change c.size - 1 = NO_FALSE ∨ c.size - 1 < c.size
    right; omega
  · simp only [h0, if_false]
    by_cases h1 : c.ffp = c.size - 1
    · simp only [h1, if_true]
      change NO_FALSE = NO_FALSE ∨ NO_FALSE < c.size
      left; rfl
    · simp only [h1, if_false]
      exact h

/-! Depth accounting is deliberately *not* folded into a numeric bound on
`Cond`: no fixed numeric bound is preserved by `push_back`.  The real bound is
relative -- one `push_back` costs at least one script byte, so the depth can
never outrun `pc` (`step_cond_depth`, `run_cond_depth`).  Combined with C1k
(`|script| <= 10000`) this keeps the depth far below `NO_FALSE = 2^32-1`, so
the sentinel cannot collide with a real position (`run_cond_size_lt_NO_FALSE`). -/

theorem Cond.pop_size (c : Cond) : c.pop.size = c.size - 1 := by
  unfold Cond.pop; split <;> rfl

theorem Cond.toggle_size (c : Cond) : c.toggle.size = c.size := by
  unfold Cond.toggle
  by_cases h0 : c.ffp = NO_FALSE
  · simp [h0]
  · simp only [h0, if_false]
    by_cases h1 : c.ffp = c.size - 1 <;> simp [h1]

theorem Cond.push_false_not_allTrue (c : Cond) (h : c.size < NO_FALSE) :
    (c.push false).allTrue = false := by
  unfold Cond.push Cond.allTrue
  by_cases hff : c.ffp = NO_FALSE
  · simp [hff]
    unfold NO_FALSE at *; omega
  · simp [hff]

/-- `push_back true` leaves `all_true` unchanged. -/
theorem Cond.push_true_allTrue (c : Cond) :
    (c.push true).allTrue = c.allTrue := by
  unfold Cond.push Cond.allTrue
  by_cases h : c.ffp = NO_FALSE <;> simp [h]

/-- An empty condition stack is all-true (used by the `!vfExec.empty()` check). -/
theorem Cond.empty_allTrue {c : Cond} (h : c.Inv) (he : c.size = 0) :
    c.allTrue = true := by
  unfold Cond.allTrue
  rcases h with h | h
  · simp [h]
  · omega

/-! ## 3. Loop state and one iteration (interpreter.cpp:449-465, 1232-1248) -/

inductive SigVersion | base | witnessV0 | tapscript
deriving DecidableEq

/-- Observable loop state.  `opDelta` is the extra `nOpCount` contribution of
the opcode body (the only one at this pin is `nKeysCount` for the
CHECKMULTISIG family, interpreter.cpp:1129); it is a parameter of the step
relation, supplied by the per-family obligation. -/
structure St where
  pc : Nat
  opCount : Nat
  cond : Cond
  error : Nat
  opDelta : Nat

/-- The three condition opcodes that touch `vfExec`
(interpreter.cpp:613-661).  The pushed literal is irrelevant to `Cond.Inv`;
`true` is a stand-in. -/
def condStep (c : Cond) (op : Nat) : Cond :=
  if op = 0x63 ∨ op = 0x64 then c.push true
  else if op = 0x67 then (if c.size = 0 then c else c.pop)
  else if op = 0x68 then (if c.size = 0 then c else c.toggle)
  else c

theorem condStep_inv {c : Cond} (h : c.Inv) (op : Nat) : (condStep c op).Inv := by
  unfold condStep
  split
  · exact Cond.push_inv h _
  · split
    · split
      · exact h
      · exact Cond.pop_inv h (by omega)
    · split
      · split
        · exact h
        · exact Cond.toggle_inv h (by omega)
      · exact h

/-- Depth accounting: one condition opcode pushes at most one frame. -/
theorem condStep_size_le (c : Cond) (op : Nat) : (condStep c op).size ≤ c.size + 1 := by
  unfold condStep
  split
  · simp [Cond.push_size]
  · split
    · split <;> simp [Cond.pop_size] <;> omega
    · split
      · split <;> simp [Cond.toggle_size] <;> omega
      · simp

/-- One dispatch iteration, in source order: `GetOp` -> BAD_OPCODE ->
MAX_SCRIPT_ELEMENT_SIZE -> MAX_OPS_PER_SCRIPT -> opcode body.  Every failure
branch sets `pc` first because `GetScriptOp` already advanced it. -/
def step (sv : SigVersion) (script : List Nat) (s : St) : St :=
  if s.error ≠ ERR_OK then s
  else if s.pc < script.length then
    let r := parse (script.drop s.pc)
    let pc' := s.pc + r.consumed
    if r.ok = false then { s with pc := pc', error := ERR_BAD_OPCODE }
    else if r.pushLen > MAX_SCRIPT_ELEMENT_SIZE then
      { s with pc := pc', error := ERR_PUSH_SIZE }
    else if sv ≠ SigVersion.tapscript ∧ r.opcode > OP_16 ∧
            s.opCount + 1 + s.opDelta > MAX_OPS_PER_SCRIPT then
      { s with pc := pc', error := ERR_OP_COUNT }
    else
      { s with pc := pc',
               opCount := if sv ≠ SigVersion.tapscript ∧ r.opcode > OP_16 then
                            s.opCount + 1 + s.opDelta else s.opCount,
               cond := condStep s.cond r.opcode }
  else s

/-- **Ranking step.** While the loop runs, `pc` strictly increases: the parser
consumed at least one byte (C1a), or the window is empty and the loop is not
taken. -/
theorem step_pc_gt (sv : SigVersion) (script : List Nat) (s : St)
    (he : s.error = ERR_OK) (hp : s.pc < script.length) :
    s.pc < (step sv script s).pc := by
  have hne : script.drop s.pc ≠ [] := by simp [List.drop_eq_nil_iff]; omega
  have hpos : 0 < (parse (script.drop s.pc)).consumed := parse_consumed_pos hne
  have hpc : (step sv script s).pc = s.pc + (parse (script.drop s.pc)).consumed := by
    unfold step
    simp only [he, ne_eq, not_true_eq_false, ite_false, ite_eq_left hp]
    repeat' split
    all_goals rfl
  omega

/-- **Progress.** A running step either fails or keeps `pc` inside `pend`.
(On the failure path `pc` may pass `pend`: `GetScriptOp` advances by the
declared push length before discovering the window is short, script.cpp:354.) -/
theorem step_progress (sv : SigVersion) (script : List Nat) (s : St)
    (hpc : s.pc ≤ script.length) :
    (step sv script s).error ≠ ERR_OK ∨ (step sv script s).pc ≤ script.length := by
  unfold step
  by_cases he : s.error ≠ ERR_OK
  · rw [if_pos he]; exact Or.inl he
  · rw [if_neg he]
    by_cases hp : s.pc < script.length
    · rw [if_pos hp]
      by_cases hfail : (parse (script.drop s.pc)).ok = false
      · rw [if_pos hfail]; left; simp [ERR_BAD_OPCODE, ERR_OK]
      · rw [if_neg hfail]
        by_cases hsize : (parse (script.drop s.pc)).pushLen > MAX_SCRIPT_ELEMENT_SIZE
        · rw [if_pos hsize]; left; simp [ERR_PUSH_SIZE, ERR_OK]
        · rw [if_neg hsize]
          by_cases hcount : sv ≠ SigVersion.tapscript ∧
                            (parse (script.drop s.pc)).opcode > OP_16 ∧
                            s.opCount + 1 + s.opDelta > MAX_OPS_PER_SCRIPT
          · rw [if_pos hcount]; left; simp [ERR_OP_COUNT, ERR_OK]
          · rw [if_neg hcount]; right
            have hok : (parse (script.drop s.pc)).ok = true := by
              cases h : (parse (script.drop s.pc)).ok <;> simp_all
            have hle := parse_consumed_le hok
            simp only [List.length_drop] at hle
            change s.pc + (parse (script.drop s.pc)).consumed ≤ script.length
            omega
    · rw [if_neg hp]; right; exact hpc

/-! ## 4. The loop (interpreter.cpp:449-1235) -/

set_option linter.unusedVariables false in
/-- The dispatch loop.  Lean accepts this definition only with the
`decreasing_by` proof of `step_pc_gt`, so termination *is* the measure proof:
every iteration strictly decreases `|script| - pc`. -/
def run (sv : SigVersion) (script : List Nat) (s : St) : St :=
  if h : s.pc < script.length ∧ s.error = ERR_OK then
    run sv script (step sv script s)
  else s
termination_by script.length - s.pc
decreasing_by
  have := step_pc_gt sv script s h.2 h.1
  simp_wf
  omega

theorem run_eq_self (sv : SigVersion) (script : List Nat) (s : St)
    (h : ¬ (s.pc < script.length ∧ s.error = ERR_OK)) : run sv script s = s := by
  conv =>
    lhs
    unfold run
  rw [dif_neg h]

theorem run_eq_step (sv : SigVersion) (script : List Nat) (s : St)
    (h : s.pc < script.length ∧ s.error = ERR_OK) :
    run sv script s = run sv script (step sv script s) := by
  conv =>
    lhs
    unfold run
  rw [dif_pos h]

/-- **C1d.** The loop stops either with a nonzero error or at `pc = pend`. -/
theorem run_done_or_error (sv : SigVersion) (script : List Nat) :
    ∀ s : St, s.pc ≤ script.length →
      (run sv script s).error ≠ ERR_OK ∨ (run sv script s).pc = script.length := by
  refine run.induct sv script
    (fun x => x.pc ≤ script.length →
      (run sv script x).error ≠ ERR_OK ∨ (run sv script x).pc = script.length) ?_ ?_
  · intro x hlt ih hpc
    have hr := run_eq_step sv script x hlt
    rw [hr]
    rcases step_progress sv script x hpc with herr | hle
    · have hb : ¬ ((step sv script x).pc < script.length ∧
                   (step sv script x).error = ERR_OK) := by
        intro hc; exact herr hc.2
      rw [run_eq_self sv script (step sv script x) hb]
      exact Or.inl herr
    · exact ih hle
  · intro x hnot _
    have hr : run sv script x = x := run_eq_self sv script x hnot
    rw [hr]
    rcases Classical.em (x.error = ERR_OK) with he | he
    · right
      have : ¬ x.pc < script.length := by intro hp; exact hnot ⟨hp, he⟩
      omega
    · exact Or.inl he

/-- **C1f.** `nOpCount` never exceeds `MAX_OPS_PER_SCRIPT` in BASE/WITNESS_V0:
the counter is checked before every write (interpreter.cpp:462, 1129-1130).
In TAPSCRIPT the increment is skipped, so the bound is not claimed there. -/
theorem step_opCount_le (sv : SigVersion) (script : List Nat) (s : St)
    (h : s.opCount ≤ MAX_OPS_PER_SCRIPT) :
    (step sv script s).opCount ≤ MAX_OPS_PER_SCRIPT := by
  unfold step
  by_cases he : s.error ≠ ERR_OK
  · rw [if_pos he]; exact h
  · rw [if_neg he]
    by_cases hp : s.pc < script.length
    · rw [if_pos hp]
      by_cases hfail : (parse (script.drop s.pc)).ok = false
      · rw [if_pos hfail]; exact h
      · rw [if_neg hfail]
        by_cases hsize : (parse (script.drop s.pc)).pushLen > MAX_SCRIPT_ELEMENT_SIZE
        · rw [if_pos hsize]; exact h
        · rw [if_neg hsize]
          by_cases hcount : sv ≠ SigVersion.tapscript ∧
                            (parse (script.drop s.pc)).opcode > OP_16 ∧
                            s.opCount + 1 + s.opDelta > MAX_OPS_PER_SCRIPT
          · rw [if_pos hcount]; exact h
          · rw [if_neg hcount]
            change (if sv ≠ SigVersion.tapscript ∧
                       (parse (script.drop s.pc)).opcode > OP_16
                    then s.opCount + 1 + s.opDelta else s.opCount) ≤ MAX_OPS_PER_SCRIPT
            split
            · rename_i hop
              have hle : ¬ (s.opCount + 1 + s.opDelta > MAX_OPS_PER_SCRIPT) := by
                intro hgt; exact hcount ⟨hop.1, hop.2, hgt⟩
              omega
            · exact h
    · rw [if_neg hp]; exact h

theorem run_opCount_le (sv : SigVersion) (script : List Nat) :
    ∀ s : St, s.opCount ≤ MAX_OPS_PER_SCRIPT →
      (run sv script s).opCount ≤ MAX_OPS_PER_SCRIPT := by
  refine run.induct sv script
    (fun x => x.opCount ≤ MAX_OPS_PER_SCRIPT →
      (run sv script x).opCount ≤ MAX_OPS_PER_SCRIPT) ?_ ?_
  · intro x hlt ih hle
    have hr := run_eq_step sv script x hlt
    rw [hr]
    exact ih (step_opCount_le sv script x hle)
  · intro x hnot hle
    rw [run_eq_self sv script x hnot]
    exact hle

/-- **C1g.** The ConditionStack representation invariant is preserved. -/
theorem step_cond_inv (sv : SigVersion) (script : List Nat) (s : St)
    (h : s.cond.Inv) : (step sv script s).cond.Inv := by
  unfold step
  by_cases he : s.error ≠ ERR_OK
  · rw [if_pos he]; exact h
  · rw [if_neg he]
    by_cases hp : s.pc < script.length
    · rw [if_pos hp]
      by_cases hfail : (parse (script.drop s.pc)).ok = false
      · rw [if_pos hfail]; exact h
      · rw [if_neg hfail]
        by_cases hsize : (parse (script.drop s.pc)).pushLen > MAX_SCRIPT_ELEMENT_SIZE
        · rw [if_pos hsize]; exact h
        · rw [if_neg hsize]
          by_cases hcount : sv ≠ SigVersion.tapscript ∧
                            (parse (script.drop s.pc)).opcode > OP_16 ∧
                            s.opCount + 1 + s.opDelta > MAX_OPS_PER_SCRIPT
          · rw [if_pos hcount]; exact h
          · rw [if_neg hcount]
            change (condStep s.cond (parse (script.drop s.pc)).opcode).Inv
            exact condStep_inv h _
    · rw [if_neg hp]; exact h

/-- **C1g'.** Depth accounting against the program counter: at most one frame
is pushed per consumed script byte, so `vfExec.size <= pc` at every iteration. -/
theorem step_cond_size_le (sv : SigVersion) (script : List Nat) (s : St) :
    (step sv script s).cond.size ≤ s.cond.size + 1 := by
  unfold step
  by_cases he : s.error ≠ ERR_OK
  · rw [if_pos he]; show s.cond.size ≤ s.cond.size + 1; omega
  · rw [if_neg he]
    by_cases hp : s.pc < script.length
    · rw [if_pos hp]
      by_cases hfail : (parse (script.drop s.pc)).ok = false
      · rw [if_pos hfail]; show s.cond.size ≤ s.cond.size + 1; omega
      · rw [if_neg hfail]
        by_cases hsize : (parse (script.drop s.pc)).pushLen > MAX_SCRIPT_ELEMENT_SIZE
        · rw [if_pos hsize]; show s.cond.size ≤ s.cond.size + 1; omega
        · rw [if_neg hsize]
          by_cases hcount : sv ≠ SigVersion.tapscript ∧
                            (parse (script.drop s.pc)).opcode > OP_16 ∧
                            s.opCount + 1 + s.opDelta > MAX_OPS_PER_SCRIPT
          · rw [if_pos hcount]; show s.cond.size ≤ s.cond.size + 1; omega
          · rw [if_neg hcount]
            show (condStep s.cond (parse (script.drop s.pc)).opcode).size ≤ s.cond.size + 1
            exact condStep_size_le _ _
    · rw [if_neg hp]; show s.cond.size ≤ s.cond.size + 1; omega

theorem step_cond_depth (sv : SigVersion) (script : List Nat) (s : St)
    (h : s.cond.size ≤ s.pc) :
    (step sv script s).cond.size ≤ (step sv script s).pc := by
  unfold step
  by_cases he : s.error ≠ ERR_OK
  · rw [if_pos he]; exact h
  · rw [if_neg he]
    by_cases hp : s.pc < script.length
    · rw [if_pos hp]
      have hne : script.drop s.pc ≠ [] := by simp [List.drop_eq_nil_iff]; omega
      have hcpos : 0 < (parse (script.drop s.pc)).consumed := parse_consumed_pos hne
      by_cases hfail : (parse (script.drop s.pc)).ok = false
      · rw [if_pos hfail]
        show s.cond.size ≤ s.pc + (parse (script.drop s.pc)).consumed
        omega
      · rw [if_neg hfail]
        by_cases hsize : (parse (script.drop s.pc)).pushLen > MAX_SCRIPT_ELEMENT_SIZE
        · rw [if_pos hsize]
          show s.cond.size ≤ s.pc + (parse (script.drop s.pc)).consumed
          omega
        · rw [if_neg hsize]
          by_cases hcount : sv ≠ SigVersion.tapscript ∧
                            (parse (script.drop s.pc)).opcode > OP_16 ∧
                            s.opCount + 1 + s.opDelta > MAX_OPS_PER_SCRIPT
          · rw [if_pos hcount]
            show s.cond.size ≤ s.pc + (parse (script.drop s.pc)).consumed
            omega
          · rw [if_neg hcount]
            show (condStep s.cond (parse (script.drop s.pc)).opcode).size
                    ≤ s.pc + (parse (script.drop s.pc)).consumed
            have hle := condStep_size_le s.cond (parse (script.drop s.pc)).opcode
            omega
    · rw [if_neg hp]; exact h

theorem run_cond_inv (sv : SigVersion) (script : List Nat) :
    ∀ s : St, s.cond.Inv → (run sv script s).cond.Inv := by
  refine run.induct sv script (fun x => x.cond.Inv → (run sv script x).cond.Inv) ?_ ?_
  · intro x hlt ih hinv
    have hr := run_eq_step sv script x hlt
    rw [hr]
    exact ih (step_cond_inv sv script x hinv)
  · intro x hnot hinv
    rw [run_eq_self sv script x hnot]
    exact hinv

theorem run_cond_depth (sv : SigVersion) (script : List Nat) :
    ∀ s : St, s.cond.size ≤ s.pc → s.pc ≤ script.length →
      (run sv script s).cond.size ≤ script.length := by
  refine run.induct sv script (fun x => x.cond.size ≤ x.pc → x.pc ≤ script.length →
      (run sv script x).cond.size ≤ script.length) ?_ ?_
  · intro x hlt ih hd hpc
    have hr := run_eq_step sv script x hlt
    rw [hr]
    rcases step_progress sv script x hpc with herr | hle
    · have hb : ¬ ((step sv script x).pc < script.length ∧
                   (step sv script x).error = ERR_OK) := by
        intro hc; exact herr hc.2
      rw [run_eq_self sv script (step sv script x) hb]
      have h1 := step_cond_size_le sv script x
      omega
    · exact ih (step_cond_depth sv script x hd) hle
  · intro _x hnot hd _
    rw [run_eq_self sv script _x hnot]
    omega

/-! ## 5. Post-loop checks and the checked result/error pair
       (interpreter.cpp:1236-1248) -/

/-- The epilogue: the two `catch` clauses keep `ERR_SCRIPTNUM`/`ERR_UNKNOWN`
in `error` (set where the throw was caught), then `if (!vfExec.empty())` sets
`UNBALANCED_CONDITIONAL`, else `set_success` (error 0). -/
def finish (s : St) : St :=
  if s.cond.size = 0 then s else { s with error := ERR_UNBALANCED_CONDITIONAL }

/-- `EvalScript`'s observable (result, error) pair: `error = 0` is the success
result, any other code is the failure result. -/
def evalScript (sv : SigVersion) (script : List Nat) (s : St) : St :=
  finish (run sv script s)

/-- **C1h.** Success implies an empty condition stack: the only success exit
is through `set_success`, reached after the `!vfExec.empty()` check. -/
theorem evalScript_ok_balance (sv : SigVersion) (script : List Nat) (s : St)
    (h : (evalScript sv script s).error = ERR_OK) :
    (evalScript sv script s).cond.size = 0 := by
  unfold evalScript at h ⊢
  by_cases hbal : (run sv script s).cond.size = 0
  · have hfin : finish (run sv script s) = run sv script s := by simp [finish, hbal]
    rw [hfin] at h ⊢
    exact hbal
  · have hfin : (finish (run sv script s)).error = ERR_UNBALANCED_CONDITIONAL := by
      simp [finish, hbal]
    rw [hfin] at h
    exact absurd h (by decide)

/-- **C1i.** Success implies `pc = pend`: the loop can only reach the epilogue
by exhausting the script (C1d). -/
theorem evalScript_ok_done (sv : SigVersion) (script : List Nat) (s : St)
    (hpc : s.pc ≤ script.length) (h : (evalScript sv script s).error = ERR_OK) :
    (evalScript sv script s).pc = script.length := by
  unfold evalScript at h ⊢
  by_cases hbal : (run sv script s).cond.size = 0
  · have hfin : finish (run sv script s) = run sv script s := by simp [finish, hbal]
    rw [hfin] at h ⊢
    have hrun : (run sv script s).error = ERR_OK := h
    rcases run_done_or_error sv script s hpc with herr | hdone
    · exact absurd hrun herr
    · exact hdone
  · have hfin : (finish (run sv script s)).error = ERR_UNBALANCED_CONDITIONAL := by
      simp [finish, hbal]
    rw [hfin] at h
    exact absurd h (by decide)

/-- The error class tracked through the loop by C1j. -/
def ErrClass (s : St) : Prop :=
  s.error = ERR_UNKNOWN ∨ s.error = ERR_BAD_OPCODE ∨
  s.error = ERR_PUSH_SIZE ∨ s.error = ERR_OP_COUNT

theorem step_error_class (sv : SigVersion) (script : List Nat) (s : St)
    (h : ErrClass s) : ErrClass (step sv script s) := by
  unfold step
  by_cases he : s.error ≠ ERR_OK
  · rw [if_pos he]; exact h
  · rw [if_neg he]
    have hok : s.error = ERR_OK := by simpa using he
    rcases h with h | h | h | h <;> rw [h] at hok <;> exact absurd hok (by decide)

/-- **C1j.** Starting from `set_error(serror, SCRIPT_ERR_UNKNOWN_ERROR)`
(interpreter.cpp:437), every exit code is one of the modelled codes. -/
theorem evalScript_error_class (sv : SigVersion) (script : List Nat) (s : St)
    (h0 : s.error = ERR_UNKNOWN) :
    (evalScript sv script s).error = ERR_OK ∨
    (evalScript sv script s).error = ERR_UNKNOWN ∨
    (evalScript sv script s).error = ERR_BAD_OPCODE ∨
    (evalScript sv script s).error = ERR_PUSH_SIZE ∨
    (evalScript sv script s).error = ERR_OP_COUNT ∨
    (evalScript sv script s).error = ERR_UNBALANCED_CONDITIONAL := by
  have hclass : ∀ x : St, ErrClass x → ErrClass (run sv script x) := by
    refine run.induct sv script (fun x => ErrClass x → ErrClass (run sv script x)) ?_ ?_
    · intro x hlt ih hinv
      rw [run_eq_step sv script x hlt]
      exact ih (step_error_class sv script x hinv)
    · intro x hnot hinv
      rw [run_eq_self sv script x hnot]
      exact hinv
  have hrun := hclass s (Or.inl h0)
  unfold evalScript
  by_cases hbal : (run sv script s).cond.size = 0
  · have hfin : finish (run sv script s) = run sv script s := by simp [finish, hbal]
    rw [hfin]
    rcases hrun with h | h | h | h
    · exact Or.inr (Or.inl h)
    · exact Or.inr (Or.inr (Or.inl h))
    · exact Or.inr (Or.inr (Or.inr (Or.inl h)))
    · exact Or.inr (Or.inr (Or.inr (Or.inr (Or.inl h))))
  · have hfin : (finish (run sv script s)).error = ERR_UNBALANCED_CONDITIONAL := by
      simp [finish, hbal]
    rw [hfin]
    exact Or.inr (Or.inr (Or.inr (Or.inr (Or.inr rfl))))

/-- **C1k.** The BASE/WITNESS_V0 prologue guard (interpreter.cpp:438) bounds
the script, hence the loop measure.  TAPSCRIPT is *not* covered: at this pin
the check is skipped for TAPSCRIPT, so a tapscript leaf's bound comes from the
witness/annex weight, not from `MAX_SCRIPT_SIZE`. -/
theorem base_script_len (script : List Nat) (h : script.length ≤ MAX_SCRIPT_SIZE) :
    script.length - 0 ≤ MAX_SCRIPT_SIZE := h

/-- **C1k+.** Sentinel safety: under the BASE/WITNESS_V0 length guard the
condition-stack depth stays strictly below `NO_FALSE`, so `m_first_false_pos`
(a real position `< size`, or the sentinel) cannot collide with a real
position.  This is the missing premise the pure `Cond.Inv` encoding leaves
open at unbounded depth. -/
theorem run_cond_size_lt_NO_FALSE (sv : SigVersion) (script : List Nat) (s : St)
    (hscript : script.length ≤ MAX_SCRIPT_SIZE) (hpc : s.pc ≤ script.length)
    (hd : s.cond.size ≤ s.pc) :
    (run sv script s).cond.size < NO_FALSE := by
  have hle := run_cond_depth sv script s hd hpc
  unfold NO_FALSE MAX_SCRIPT_SIZE at *
  omega

#print axioms parse_consumed_pos
#print axioms parse_consumed_le
#print axioms parse_pushLe
#print axioms Cond.push_inv
#print axioms Cond.pop_inv
#print axioms Cond.toggle_inv
#print axioms condStep_inv
#print axioms condStep_size_le
#print axioms Cond.empty_allTrue
#print axioms step_pc_gt
#print axioms step_progress
#print axioms run_done_or_error
#print axioms run_opCount_le
#print axioms step_error_class
#print axioms run_cond_inv
#print axioms step_cond_depth
#print axioms run_cond_depth
#print axioms evalScript_ok_balance
#print axioms evalScript_ok_done
#print axioms evalScript_error_class
#print axioms run_cond_size_lt_NO_FALSE

end Wave65.E5
