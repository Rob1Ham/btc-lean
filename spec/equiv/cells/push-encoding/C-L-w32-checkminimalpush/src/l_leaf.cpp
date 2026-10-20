#include <cstdint>
// L leg: Lean `checkMinimalPush` at
//   spec/core/Bitcoin/Interpreter/Defs.lean:529-537
// transcribed verbatim (structure and branch order) from the generated twin
// `twin/runtime.inc:191-199`.  The twin mirrors Lean; it is not a Core
// transliteration.
//
// `data : ByteArray` is reduced to its read set, (size, first byte), exactly
// as on the C side.  No handler semantics are changed.

#define BINLINE static inline __attribute__((always_inline))

BINLINE bool lean_check_minimal_push(uint64_t n, uint8_t b0, uint32_t opcode) {
  if (n == 0) return opcode == 0;
  else if (n == 1 && 1 <= b0 && b0 <= 16) return false;
  else if (n == 1 && b0 == 0x81) return false;
  else if (n <= 75) return opcode == n;
  else if (n <= 0xff) return opcode == 0x4c;
  else if (n <= 0xffff) return opcode == 0x4d;
  else return true;
}

extern "C" uint64_t cell_minpush(uint64_t n, uint8_t b0, uint8_t opcode) {
  if (opcode > 0x4e) return 2;  // outside the Lean call-site gate too
  return lean_check_minimal_push(n, b0, opcode) ? 1 : 0;
}
