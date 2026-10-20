#include <cstdint>
// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/script.cpp:373-396  CheckMinimalPush(const valtype& data,
//                                                   opcodetype opcode)
//
// The function reads only `data.size()` and `data[0]`; those are the cell's
// `n` and `b0` arguments.  The call site (interpreter.cpp:499-503) invokes it
// only for `0 <= opcode <= OP_PUSHDATA4` (0x4e); that is the cell domain.
//
// This is a bounded decision-function cell, not a whole-EvalScript result.

#define BINLINE static inline __attribute__((always_inline))

// script.cpp:373-396, verbatim control flow with data.size() -> n and
// data[0] -> b0.  `opcode` is uint32_t because CScriptNum/opcodetype are
// integer-sized at the call site.
BINLINE bool core_check_minimal_push(uint64_t n, uint8_t b0, uint32_t opcode) {
  if (n == 0) {
    // Should have used OP_0.
    return opcode == 0;
  } else if (n == 1 && b0 >= 1 && b0 <= 16) {
    // Should have used OP_1 .. OP_16.
    return false;
  } else if (n == 1 && b0 == 0x81) {
    // Should have used OP_1NEGATE.
    return false;
  } else if (n <= 75) {
    // Direct push.
    return opcode == n;
  } else if (n <= 255) {
    // OP_PUSHDATA1.
    return opcode == 0x4c;
  } else if (n <= 65535) {
    // OP_PUSHDATA2.
    return opcode == 0x4d;
  }
  // PUSHDATA4 payload; a 4-byte length can express anything above.
  return true;
}

extern "C" uint64_t cell_minpush(uint64_t n, uint8_t b0, uint8_t opcode) {
  // Out of the CheckMinimalPush call-site domain (assert in Core):
  // both legs return the same sentinel so the tools prove nothing outside it.
  if (opcode > 0x4e) return 2;
  return core_check_minimal_push(n, b0, opcode) ? 1 : 0;
}
