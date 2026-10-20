#include "num_common.h"
#include "num_core.h"

// C leg: source-excerpt slice of Bitcoin Core
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/script/interpreter.cpp:955-1010  case OP_ADD .. OP_MAX
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

BINLINE uint64_t c_binary(uint32_t opcode, Stack& s) {
  // ---------- interpreter.cpp:955-1010 ----------
  if (s.n < 2) return num_obs_err(EQUIV_ERR_INVALID_STACK_OPERATION);
  uint32_t la = 0, lb = 0;
  const uint8_t* pa = stacktop(s, 2, la);
  const uint8_t* pb = stacktop(s, 1, lb);
  int64_t a = 0, b = 0;
  uint32_t err = 0;
  // CScriptNum bn1(stacktop(-2), fRequireMinimal);  [script.h:246-271]
  if (!decode_num(pa, la, /*fRequireMinimal=*/false, 4, a, err))
    return num_obs_err(err);
  // CScriptNum bn2(stacktop(-1), fRequireMinimal);
  if (!decode_num(pb, lb, /*fRequireMinimal=*/false, 4, b, err))
    return num_obs_err(err);
  int64_t bn = 0;                                  // CScriptNum bn(0);
  switch (opcode) {
    case 0x93: bn = a + b; break;                  // OP_ADD:  bn = bn1 + bn2
    case 0x94: bn = a - b; break;                  // OP_SUB:  bn = bn1 - bn2
    case 0x9a: bn = (a != 0 && b != 0); break;     // OP_BOOLAND
    case 0x9b: bn = (a != 0 || b != 0); break;     // OP_BOOLOR
    case 0x9c:                                     // OP_NUMEQUAL
    case 0x9d: bn = (a == b); break;               // OP_NUMEQUALVERIFY
    case 0x9e: bn = (a != b); break;               // OP_NUMNOTEQUAL
    case 0x9f: bn = (a < b); break;                // OP_LESSTHAN
    case 0xa0: bn = (a > b); break;                // OP_GREATERTHAN
    case 0xa1: bn = (a <= b); break;               // OP_LESSTHANOREQUAL
    case 0xa2: bn = (a >= b); break;               // OP_GREATERTHANOREQUAL
    case 0xa3: bn = (a < b ? a : b); break;        // OP_MIN
    default:   bn = (a > b ? a : b); break;        // OP_MAX
  }
  s.n -= 2;                                        // popstack(stack) x2
  const uint32_t e = push_num(s, bn);              // stack.push_back(bn.getvch())
  if (e != 0) return num_obs_err(e);
  if (opcode == 0x9d) {                            // OP_NUMEQUALVERIFY
    uint32_t len = 0;
    const uint8_t* t = stacktop(s, 1, len);
    if (!cast_to_bool(t, len))                     // if (CastToBool(stacktop(-1)))
      return num_obs_err(EQUIV_ERR_NUMEQUALVERIFY);  //   popstack else NUMEQUALVERIFY
    s.n -= 1;
  }
  return c_tail(s);
  // ---------------------------------------------
}

BINLINE uint64_t c_entry(uint32_t opcode, uint32_t wa, uint32_t la,
                         uint32_t wb, uint32_t lb) {
  Stack s{};
  s.len[0] = la & 7u;   // harness domain: element length 0..7
  num_load(s.e[0], wa);
  s.n = 1;
  s.len[1] = lb & 7u;
  num_load(s.e[1], wb);
  s.n = 2;
  return c_binary(opcode, s);
}

}  // namespace

extern "C" uint64_t cell_add(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0x93, wa, la, wb, lb); }
extern "C" uint64_t cell_sub(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0x94, wa, la, wb, lb); }
extern "C" uint64_t cell_booland(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0x9a, wa, la, wb, lb); }
extern "C" uint64_t cell_boolor(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0x9b, wa, la, wb, lb); }
extern "C" uint64_t cell_numequal(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0x9c, wa, la, wb, lb); }
extern "C" uint64_t cell_numequalverify(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0x9d, wa, la, wb, lb); }
extern "C" uint64_t cell_numnotequal(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0x9e, wa, la, wb, lb); }
extern "C" uint64_t cell_lessthan(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0x9f, wa, la, wb, lb); }
extern "C" uint64_t cell_greaterthan(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0xa0, wa, la, wb, lb); }
extern "C" uint64_t cell_lessthanorequal(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0xa1, wa, la, wb, lb); }
extern "C" uint64_t cell_greaterthanorequal(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0xa2, wa, la, wb, lb); }
extern "C" uint64_t cell_min(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0xa3, wa, la, wb, lb); }
extern "C" uint64_t cell_max(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return c_entry(0xa4, wa, la, wb, lb); }
