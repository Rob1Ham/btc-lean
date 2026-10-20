#include "num_common.h"
#include "num_core.h"

// C leg: source-excerpt slice of Bitcoin Core
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/script/interpreter.cpp:455-458  per-instruction MAX_SCRIPT_ELEMENT_SIZE guard
//   src/script/interpreter.cpp:487-492  raw push path: stack.push_back(vchPushValue)
//   src/script/interpreter.cpp:924-953  case OP_1ADD (CScriptNum decode / getvch push)
//   src/script/interpreter.cpp:1877-1878 VerifyScript tail (EVAL_FALSE)
//   src/script/script.h:227-236        numeric-op width comment (SCR-085)
//   src/script/script.h:246-249,337-340,342-373 CScriptNum ctor / getvch / serialize
//
// The cell isolates three sites that the row distinguishes:
//   * the raw push path never constructs a CScriptNum and never applies the
//     4-byte width guard (only MAX_SCRIPT_ELEMENT_SIZE = 520);
//   * OP_1ADD re-interprets its top operand through
//     CScriptNum(vch, fRequireMinimal, nMaxNumSize = 4), so a >4-byte element
//     is rejected at that site;
//   * CScriptNum::serialize has no width parameter, so a 4-byte operand can
//     push a 5-byte result, which is accepted as a raw stack element until a
//     later numeric opcode re-interprets it.
//
// Specialised to flags = 0 (fRequireMinimal = false), so the minimality guard
// is statically off.  The operand vector, popstack and push_back are the
// bounded stand-ins in num_core.h; the case block itself is literal.
using namespace core;

namespace {

// interpreter.cpp:1877-1878 (VerifyScript after EvalScript returned true):
//   if (stack.size() != 1) ...   [cleanstack is off under flags = 0]
//   if (!CastToBool(stack.back())) return EVAL_FALSE;
BINLINE uint64_t c_tail(Stack& s) {
  if (s.n == 0) return num_obs(0, EQUIV_ERR_EVAL_FALSE, s);
  uint32_t len = 0;
  const uint8_t* top = stacktop(s, 1, len);
  if (!cast_to_bool(top, len)) return num_obs(0, EQUIV_ERR_EVAL_FALSE, s);
  return num_obs(1, EQUIV_ERR_OK, s);
}

// interpreter.cpp:487-492: the push path is guarded only by
// MAX_SCRIPT_ELEMENT_SIZE (line 457) and never decodes a CScriptNum.
BINLINE void c_push_raw(Stack& s, uint64_t w, uint32_t len) {
  s.len[0] = len;
  num_load8(s.e[0], w);
  s.n = 1;
}

// interpreter.cpp:929-953, OP_1ADD arm only:
//   CScriptNum bn(stacktop(-1), fRequireMinimal);   [script.h:246-249 width guard]
//   bn += bnOne;
//   popstack(stack);
//   stack.push_back(bn.getvch());                   [script.h:337-373, no width guard]
// Returns the ScriptError ordinal on failure, 0 on success.
BINLINE uint32_t c_step_1add(Stack& s) {
  if (s.n < 1) return EQUIV_ERR_INVALID_STACK_OPERATION;
  uint32_t len = 0;
  const uint8_t* p = stacktop(s, 1, len);
  int64_t bn = 0;
  uint32_t err = 0;
  if (!decode_num(p, len, /*fRequireMinimal=*/false, 4, bn, err))
    return err;
  bn += 1;
  s.n -= 1;
  return push_num(s, bn);
}

}  // namespace

// Raw byte push: element length is a symbolic harness input 0..8 (num_len8).
// No CScriptNum is constructed, so no SCRIPTNUM error is reachable.
extern "C" uint64_t cell_push_raw(uint64_t w, uint32_t l) {
  Stack s{};
  c_push_raw(s, w, num_len8(l));
  return c_tail(s);
}

// The same raw element, immediately re-interpreted by OP_1ADD.  The width
// guard fires exactly when the element is longer than four bytes.
extern "C" uint64_t cell_reinterpret(uint64_t w, uint32_t l) {
  Stack s{};
  c_push_raw(s, w, num_len8(l));
  const uint32_t e = c_step_1add(s);
  if (e != 0) return num_obs_err(e);
  return c_tail(s);
}

// Four-byte operand: OP_1ADD may push a five-byte result (w = 0x7fffffff
// gives 2^31 -> 00 00 00 80 00).  The tail observes it as a raw element.
extern "C" uint64_t cell_add4_observe(uint64_t w) {
  Stack s{};
  c_push_raw(s, w, 4);
  const uint32_t e = c_step_1add(s);
  if (e != 0) return num_obs_err(e);
  return c_tail(s);
}

// Four-byte operand, OP_1ADD, then a second OP_1ADD re-interprets the result.
// The second decode rejects exactly the values whose first result needed five
// bytes (only w = 0x7fffffff in this domain).
extern "C" uint64_t cell_add4_readd(uint64_t w) {
  Stack s{};
  c_push_raw(s, w, 4);
  uint32_t e = c_step_1add(s);
  if (e != 0) return num_obs_err(e);
  e = c_step_1add(s);
  if (e != 0) return num_obs_err(e);
  return c_tail(s);
}
