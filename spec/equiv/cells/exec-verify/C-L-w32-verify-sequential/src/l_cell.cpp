#include "w32_common.h"
#include "error_kind.h"

// L leg: reviewed transliteration of the verified Lean `verifyScriptFull`
// (spec/core/Bitcoin/Interpreter/Defs.lean:1376-1383) and of the generated
// twin's `verify_script_full` (twin/runtime.inc:791-804), with the
// scriptPubKey of this cell being `OP_DUP` — the twin handler body
// `return st_push_copy(st.stack, 1);` (twin/ops_ir.py OP_DUP, Lean
// Defs.lean:957-959) and st_push_copy in twin/runtime.inc:117-128.
//
//   evalScriptBytes fuel flags pol ss [] chk .base default     -- scriptSig
//   match ... with .ok stack1 =>
//     evalScriptBytes fuel flags pol spk stack1 chk .base default
//     match ... with .ok stack =>
//       if stack = [] ∨ !castToBool stack[0]! then .fail .evalFalse else .ok
//
// The stack carried into the second evaluation is `stack1`: the L leg keeps
// the twin's `State` and its push-copy primitive, whose cap is
// `if (s.n >= MAX_STACK_SIZE) return TWIN_STACK_SIZE;` — so DUP fails at
// depth >= 1000 and the underflow arm is `st.n < 1`.

namespace l_w32_seq {

constexpr uint64_t MAX_STACK_SIZE = 1000;

struct State {
  uint64_t n;
  uint64_t top;
  uint64_t top_len;
};

// twin/ops_ir.py OP_DUP -> st_push_copy(st.stack, 1)
W32INLINE int32_t op_dup(State& st) {
  if (st.n < 1) return EQUIV_ERR_INVALID_STACK_OPERATION;  // TWIN_INVALID_STACK_OPERATION
  if (st.n >= MAX_STACK_SIZE) return EQUIV_ERR_STACK_SIZE; // TWIN_STACK_SIZE
  st.n += 1;                                               // copy of top, value unchanged
  return EQUIV_ERR_OK;
}

W32INLINE uint64_t verify_sequential(uint64_t ss_err, uint64_t ss_depth,
                                     uint64_t ss_top, uint64_t ss_top_len) {
  if (ss_err != 0) return w32_pack(0, (uint32_t)ss_err);
  State st{};
  st.n = ss_depth;
  st.top = ss_top;
  st.top_len = ss_top_len;
  // st.stack = st.saved; eval_script(spk, ...) -- same State, same stack.
  const int32_t e = op_dup(st);
  if (e != EQUIV_ERR_OK) return w32_pack(0, (uint32_t)e);
  if (st.n == 0) return w32_pack(0, EQUIV_ERR_EVAL_FALSE);          // stack = []
  if (!w32_cast_bool_lean(st.top, st.top_len)) {                    // !castToBool stack[0]!
    return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  }
  return w32_pack(1, EQUIV_ERR_OK);
}

}  // namespace l_w32_seq

extern "C" uint64_t cell_verify_sequential(uint64_t ss_err, uint64_t ss_depth,
                                           uint64_t ss_top, uint64_t ss_top_len) {
  // Same declared domain guards as the C leg (see src/c_cell.cpp).
  if (ss_top_len > 8 || ss_depth > 1000) return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);
  return l_w32_seq::verify_sequential(ss_err, ss_depth, ss_top, ss_top_len);
}
