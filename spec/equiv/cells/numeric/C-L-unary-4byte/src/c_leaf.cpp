#include "num_common.h"
#include "num_core.h"

// C leg: source-excerpt slice of Bitcoin Core
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/script/interpreter.cpp:929-953    case OP_1ADD .. OP_0NOTEQUAL
//   src/script/interpreter.cpp:1877-1878  VerifyScript tail (EVAL_FALSE)
//   src/script/script.h:227-394           CScriptNum (see num_core.h)
//
// Specialised to flags = 0: fRequireMinimal (MINIMALDATA) is false, so the
// CScriptNum minimality guard is statically off; nMaxNumSize keeps its
// default of 4 (script.h:242).  The operand vector, popstack and push_back
// are the bounded stand-ins in num_core.h; the case block itself is literal.
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

BINLINE uint64_t c_unary(uint32_t opcode, Stack& s) {
  // ---------- interpreter.cpp:929-953 ----------
  if (s.n < 1) return num_obs_err(EQUIV_ERR_INVALID_STACK_OPERATION);
  uint32_t len = 0;
  const uint8_t* p = stacktop(s, 1, len);
  int64_t bn = 0;
  uint32_t err = 0;
  // CScriptNum bn(stacktop(-1), fRequireMinimal)  [script.h:246-271]
  if (!decode_num(p, len, /*fRequireMinimal=*/false, 4, bn, err))
    return num_obs_err(err);
  switch (opcode) {
    case 0x8b: bn += 1; break;                       // OP_1ADD: bn += bnOne
    case 0x8c: bn -= 1; break;                       // OP_1SUB: bn -= bnOne
    case 0x8f: bn = -bn; break;                       // OP_NEGATE
    case 0x90: if (bn < 0) bn = -bn; break;           // OP_ABS
    case 0x91: bn = (bn == 0) ? 1 : 0; break;         // OP_NOT
    default:   bn = (bn != 0) ? 1 : 0; break;         // OP_0NOTEQUAL
  }
  s.n -= 1;                                          // popstack(stack)
  const uint32_t e = push_num(s, bn);                // stack.push_back(bn.getvch())
  if (e != 0) return num_obs_err(e);
  return c_tail(s);
  // ---------------------------------------------
}

BINLINE uint64_t c_entry(uint32_t opcode, uint32_t w, uint32_t lb) {
  Stack s{};
  s.len[0] = lb & 7u;   // harness domain: element length 0..7
  num_load(s.e[0], w);
  s.n = 1;
  return c_unary(opcode, s);
}

}  // namespace

extern "C" uint64_t cell_1add(uint32_t w, uint32_t lb)      { return c_entry(0x8b, w, lb); }
extern "C" uint64_t cell_1sub(uint32_t w, uint32_t lb)      { return c_entry(0x8c, w, lb); }
extern "C" uint64_t cell_negate(uint32_t w, uint32_t lb)    { return c_entry(0x8f, w, lb); }
extern "C" uint64_t cell_abs(uint32_t w, uint32_t lb)       { return c_entry(0x90, w, lb); }
extern "C" uint64_t cell_not(uint32_t w, uint32_t lb)       { return c_entry(0x91, w, lb); }
extern "C" uint64_t cell_0notequal(uint32_t w, uint32_t lb) { return c_entry(0x92, w, lb); }
