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
// Unlike the older bounded cell (control-flow/C-L-casttobool), the loop is
// NOT specialised to a compile-time length: the exported wrapper takes the
// length as a symbolic 32-bit value.  The only addition is the consensus
// domain assumption n <= 520 (MAX_SCRIPT_ELEMENT_SIZE); the loop body and its
// per-iteration semantics are unchanged.

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

extern "C" uint32_t cell_cast_arb(const uint8_t* vch, uint32_t n) {
  __builtin_assume(n <= 520u);  // element domain, MAX_SCRIPT_ELEMENT_SIZE
  return core_cast_to_bool(vch, n) ? 1u : 0u;
}
