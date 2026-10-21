#include "limits_common.h"
// C leg — source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/interpreter.cpp:455-458
//       if (!script.GetOp(pc, opcode, vchPushValue))
//           return set_error(serror, SCRIPT_ERR_BAD_OPCODE);
//       if (vchPushValue.size() > MAX_SCRIPT_ELEMENT_SIZE)
//           return set_error(serror, SCRIPT_ERR_PUSH_SIZE);
//   src/script/interpreter.cpp:488-493
//       if (fExec && 0 <= opcode && opcode <= OP_PUSHDATA4) { ... stack.push_back(vchPushValue); }
//   src/script/script.h:29   MAX_SCRIPT_ELEMENT_SIZE = 520
//
// `kind` is the decoded-instruction class after a successful GetOp:
//   0 = byte push (PUSHDATA; vchPushValue holds dlen bytes)
//   1 = numeric push (OP_1NEGATE..OP_16; vchPushValue is empty)
//   2 = any other opcode (vchPushValue is empty)
// The check is upstream of every use of fExec, so an over-size push value is
// rejected even in an unexecuted branch.  GetOp is assumed to have succeeded
// (fully parseable instruction); the truncated-push tail is F-DIV-001 and not
// part of this row.

extern "C" uint64_t cell_push_size(uint16_t dlen, uint8_t fExec, uint8_t kind) {
  if (kind > 2 || fExec > 1) return lim_bad_input();
  const uint32_t vch_push_value_size = (kind == 0) ? dlen : 0u;

  // interpreter.cpp:457-458, before fExec is read (it is read at :488).
  if (vch_push_value_size > LIM_MAX_SCRIPT_ELEMENT_SIZE) {
    return lim_pack(0, EQUIV_ERR_PUSH_SIZE, 0);
  }

  // interpreter.cpp:488-493: the push itself only happens when executed.
  const uint32_t depth = (kind != 2 && fExec == 1) ? 1u : 0u;
  return lim_pack(1, EQUIV_ERR_OK, depth);
}
