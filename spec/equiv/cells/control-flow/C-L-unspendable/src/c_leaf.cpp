#include "cell.h"
// C leg: exact source slice from Bitcoin Core cce32b168
// src/script/script.h:564-567.
//
//   bool IsUnspendable() const
//   {
//       return (size() > 0 && *begin() == OP_RETURN) || (size() > MAX_SCRIPT_SIZE);
//   }
//
// OP_RETURN is 0x6a and MAX_SCRIPT_SIZE is 10000.  The cell takes the script
// size and its first byte directly, so it covers the whole 32-bit size range
// and every first byte without materialising the script.

extern "C" uint32_t cell_unspendable(uint32_t size, uint8_t first) {
  return ((size > 0 && first == 0x6a) || size > 10000) ? 1u : 0u;
}
