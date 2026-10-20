#include "cell.h"
// C leg: exact source slice from Bitcoin Core cce32b168
// src/script/interpreter.cpp:46-59.
//
//   bool CastToBool(const valtype& vch)
//   {
//       for (unsigned int i = 0; i < vch.size(); i++)
//       {
//           if (vch[i] != 0)
//           {
//               // Can be negative zero
//               if (i == vch.size()-1 && vch[i] == 0x80)
//                   return false;
//               return true;
//           }
//       }
//       return false;
//   }
//
// The loop is kept verbatim.  Each exported function fixes vch.size() to a
// compile-time constant (0, 1, 2) so the loop is fully unrolled and both
// tools see a loop-free leaf.  The cell domain is element length <= 2; that
// is the only difference from CastToBool over an arbitrary vector.

BINLINE bool core_cast_to_bool(const uint8_t* vch, unsigned int n) {
  for (unsigned int i = 0; i < n; i++) {
    if (vch[i] != 0) {
      if (i == n - 1 && vch[i] == 0x80)
        return false;
      return true;
    }
  }
  return false;
}

extern "C" uint32_t cell_cast_empty() {
  const uint8_t vch[1] = {0};
  return core_cast_to_bool(vch, 0) ? 1u : 0u;   // interpreter.cpp:46-59
}

extern "C" uint32_t cell_cast_len1(uint8_t b0) {
  const uint8_t vch[1] = {b0};
  return core_cast_to_bool(vch, 1) ? 1u : 0u;
}

extern "C" uint32_t cell_cast_len2(uint8_t b0, uint8_t b1) {
  const uint8_t vch[2] = {b0, b1};
  return core_cast_to_bool(vch, 2) ? 1u : 0u;
}
