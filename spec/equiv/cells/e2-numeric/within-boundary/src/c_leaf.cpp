#include "e2_common.h"
// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/interpreter.cpp:1012-1026  case OP_WITHIN
//       // (x min max -- out)
//       if (stack.size() < 3) return SCRIPT_ERR_INVALID_STACK_OPERATION;
//       CScriptNum bn1(stacktop(-3), fRequireMinimal);
//       CScriptNum bn2(stacktop(-2), fRequireMinimal);
//       CScriptNum bn3(stacktop(-1), fRequireMinimal);
//       bool fValue = (bn2 <= bn1 && bn1 < bn3);
//       popstack x3; stack.push_back(fValue ? vchTrue : vchFalse);
//   src/script/script.h:246-271           CScriptNum(vch, fRequireMinimal, 4)
//   src/script/interpreter.cpp:46-61       CastToBool (VerifyScript tail)
//
// This slice fixes vch.size() == 1 and fRequireMinimal == false, so the
// width guard (1 > 4 false) and minimality guard (skipped) are settled; the
// remaining CScriptNum step is sign-magnitude set_vch over one byte.

BINLINE int64_t core_set_vch_1byte(uint32_t b) {
  // script.h:376-391 set_vch, specialised to a one-byte vector: the top bit
  // is the sign, the low seven bits are the magnitude.
  const int64_t mag = static_cast<int64_t>(b & 0x7fu);
  return (b & 0x80u) ? -mag : mag;
}

BINLINE uint32_t core_push_raw(BStack& s, uint32_t v, uint32_t len) {
  if (s.n >= 4) return 8;                       // SCRIPT_ERR_STACK_SIZE
  s.len[s.n] = len; s.val[s.n] = v; s.n += 1;
  return 0;
}

extern "C" uint64_t cell_within(uint8_t av, uint8_t bv, uint8_t cv) {
  const int64_t a = core_set_vch_1byte(av);     // bn1 = stacktop(-3)
  const int64_t b = core_set_vch_1byte(bv);     // bn2 = stacktop(-2)
  const int64_t c = core_set_vch_1byte(cv);     // bn3 = stacktop(-1)
  const bool v = (b <= a && a < c);             // interpreter.cpp:1020
  BStack s{};
  // vchTrue is {1}; vchFalse is the empty vector (interpreter.cpp:423-425).
  const uint32_t e = v ? core_push_raw(s, 1u, 1u) : core_push_raw(s, 0u, 0u);
  if (e) return b_pack(0, e, s);
  // interpreter.cpp:1878: an empty/false top is EVAL_FALSE.
  if (s.n == 0) return b_pack(0, 2, s);
  if (!b_truth(s, s.n - 1)) return b_pack(0, 2, s);
  return b_pack(1, 0, s);
}
