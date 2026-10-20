#include "num_common.h"
#include "num_core.h"

// C leg: source-excerpt slice of Bitcoin Core
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/script/interpreter.cpp:897-923  case OP_EQUAL / OP_EQUALVERIFY
//   src/script/interpreter.cpp:1877-1878  VerifyScript tail (EVAL_FALSE)
//   src/script/interpreter.cpp:109-124   stacktop()/popstack()
//   src/script/script.h:227-394         CScriptNum (see num_core.h)
//
// OP_EQUAL/OP_EQUALVERIFY never decode a CScriptNum: interpreter.cpp:906 is
// `bool fEqual = (vch1 == vch2)`, a raw valtype comparison under the length
// domain only.  That is why this cell is unbounded in *content*: every byte
// string of length 0..8 is in the domain, with no 4-byte width cap and no
// sign-bit rule.  num_core.h is included only for the bounded Stack type and
// the push/pop/stacktop helpers; no numeric primitive is used.
//
// The operand vectors and popstack are the bounded stand-ins in num_core.h.
using namespace core;

namespace {

// `vch1 == vch2` for a bounded element.  A std::vector compare is length
// first, then the `len` bytes; a constant-index chain guarded by the length
// expresses exactly that without a symbolic memcmp length.
BINLINE bool c_valtype_eq(const uint8_t* a, uint32_t la,
                          const uint8_t* b, uint32_t lb) {
  if (la != lb) return false;
  if (la < 1 || a[0] != b[0]) return la < 1;
  if (la < 2 || a[1] != b[1]) return la < 2;
  if (la < 3 || a[2] != b[2]) return la < 3;
  if (la < 4 || a[3] != b[3]) return la < 4;
  if (la < 5 || a[4] != b[4]) return la < 5;
  if (la < 6 || a[5] != b[5]) return la < 6;
  if (la < 7 || a[6] != b[6]) return la < 7;
  if (la < 8 || a[7] != b[7]) return la < 8;
  return true;
}

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

BINLINE uint64_t c_equal(uint32_t opcode, Stack& s) {
  // ---------- interpreter.cpp:897-923 ----------
  if (s.n < 2) return num_obs_err(EQUIV_ERR_INVALID_STACK_OPERATION);
  uint32_t l1 = 0, l2 = 0;
  const uint8_t* p1 = stacktop(s, 2, l1);          // stacktop(-2)  vch1
  const uint8_t* p2 = stacktop(s, 1, l2);          // stacktop(-1)  vch2
  const bool fEqual = c_valtype_eq(p1, l1, p2, l2);  // bool fEqual = (vch1 == vch2);
  s.n -= 2;                                        // popstack(stack) x2
  // interpreter.cpp:916:  stack.push_back(fEqual ? vchTrue : vchFalse);
  // interpreter.cpp:423-425:  vchTrue = {1},  vchFalse = {}
  const uint8_t vchTrue = 1;
  const uint32_t e = push(s, &vchTrue, fEqual ? 1u : 0u);
  if (e != 0) return num_obs_err(e);
  if (opcode == 0x88) {                            // OP_EQUALVERIFY
    if (fEqual) s.n -= 1;                          // interpreter.cpp:920 popstack
    else return num_obs_err(EQUIV_ERR_EQUALVERIFY);  // interpreter.cpp:922
  }
  return c_tail(s);
  // ---------------------------------------------
}

BINLINE uint64_t c_entry(uint32_t opcode, uint64_t wa, uint32_t la,
                         uint64_t wb, uint32_t lb) {
  Stack s{};
  s.len[0] = num_len8(la);   // harness domain: element length 0..8
  num_load8(s.e[0], wa);
  s.n = 1;
  s.len[1] = num_len8(lb);
  num_load8(s.e[1], wb);
  s.n = 2;
  return c_equal(opcode, s);
}

}  // namespace

extern "C" uint64_t cell_equal(uint64_t wa, uint32_t la, uint64_t wb,
                               uint32_t lb) {
  return c_entry(0x87, wa, la, wb, lb);
}

extern "C" uint64_t cell_equalverify(uint64_t wa, uint32_t la, uint64_t wb,
                                     uint32_t lb) {
  return c_entry(0x88, wa, la, wb, lb);
}
