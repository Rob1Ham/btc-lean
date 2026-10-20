#include "num_common.h"
#include "num_core.h"

// C leg: source-excerpt slice of Bitcoin Core
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/script/interpreter.cpp:1012-1026  case OP_WITHIN
//   src/script/interpreter.cpp:1877-1878  VerifyScript tail (EVAL_FALSE)
//   src/script/script.h:227-394           CScriptNum (see num_core.h)
//
// Specialised to flags = 0: fRequireMinimal (MINIMALDATA) is false, so the
// CScriptNum minimality guard is statically off; nMaxNumSize keeps its
// default of 4 (script.h:242).  The operand vectors, popstack and push_back
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

BINLINE uint64_t c_within(Stack& s) {
  // ---------- interpreter.cpp:1012-1026 ----------
  if (s.n < 3) return num_obs_err(EQUIV_ERR_INVALID_STACK_OPERATION);
  uint32_t l1 = 0, l2 = 0, l3 = 0;
  const uint8_t* p1 = stacktop(s, 3, l1);          // stacktop(-3)  x
  const uint8_t* p2 = stacktop(s, 2, l2);          // stacktop(-2)  min
  const uint8_t* p3 = stacktop(s, 1, l3);          // stacktop(-1)  max
  int64_t bn1 = 0, bn2 = 0, bn3 = 0;
  uint32_t err = 0;
  if (!decode_num(p1, l1, /*fRequireMinimal=*/false, 4, bn1, err))
    return num_obs_err(err);
  if (!decode_num(p2, l2, /*fRequireMinimal=*/false, 4, bn2, err))
    return num_obs_err(err);
  if (!decode_num(p3, l3, /*fRequireMinimal=*/false, 4, bn3, err))
    return num_obs_err(err);
  // interpreter.cpp:1020:  bool fValue = (bn2 <= bn1 && bn1 < bn3);
  const bool fValue = (bn2 <= bn1 && bn1 < bn3);
  s.n -= 3;                                        // popstack(stack) x3
  // interpreter.cpp:1025:  stack.push_back(fValue ? vchTrue : vchFalse);
  // interpreter.cpp:423-425:  vchTrue = {1},  vchFalse = {}
  const uint8_t vchTrue = 1;
  const uint32_t e = push(s, &vchTrue, fValue ? 1u : 0u);
  if (e != 0) return num_obs_err(e);
  return c_tail(s);
  // ---------------------------------------------
}

BINLINE uint64_t c_entry(uint32_t wx, uint32_t lx, uint32_t wmn, uint32_t lmn,
                         uint32_t wmx, uint32_t lmx) {
  Stack s{};
  s.len[0] = lx & 7u;    // harness domain: element length 0..7
  num_load(s.e[0], wx);
  s.n = 1;
  s.len[1] = lmn & 7u;
  num_load(s.e[1], wmn);
  s.n = 2;
  s.len[2] = lmx & 7u;
  num_load(s.e[2], wmx);
  s.n = 3;
  return c_within(s);
}

}  // namespace

extern "C" uint64_t cell_within(uint32_t wx, uint32_t lx, uint32_t wmn,
                                uint32_t lmn, uint32_t wmx, uint32_t lmx)
  { return c_entry(wx, lx, wmn, lmn, wmx, lmx); }
