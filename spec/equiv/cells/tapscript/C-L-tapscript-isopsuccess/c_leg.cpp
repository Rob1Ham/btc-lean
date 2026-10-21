#include "cell_common.h"

// C leg: exact source excerpt, Bitcoin Core src/script/script.cpp:365-371 at
// pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   bool IsOpSuccess(const opcodetype& opcode)
//   {
//       return opcode == 80 || opcode == 98 || (opcode >= 126 && opcode <= 129) ||
//              (opcode >= 131 && opcode <= 134) || (opcode >= 137 && opcode <= 138) ||
//              (opcode >= 141 && opcode <= 142) || (opcode >= 149 && opcode <= 153) ||
//              (opcode >= 187 && opcode <= 254);
//   }
//
// The parameter is `opcodetype` (an enum over int), so a value outside
// 0..255 matches no range and returns false; the cell is therefore total over
// all 64-bit harness inputs.
TAP_INLINE uint64_t c_is_op_success(uint64_t opcode) {
  return tap_bool(opcode == 80u || opcode == 98u ||
                  (opcode >= 126u && opcode <= 129u) ||
                  (opcode >= 131u && opcode <= 134u) ||
                  (opcode >= 137u && opcode <= 138u) ||
                  (opcode >= 141u && opcode <= 142u) ||
                  (opcode >= 149u && opcode <= 153u) ||
                  (opcode >= 187u && opcode <= 254u));
}

extern "C" uint64_t cell_is_op_success(uint64_t opcode) {
  return c_is_op_success(opcode);
}
