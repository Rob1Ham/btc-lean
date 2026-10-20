#include <cstdint>

// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/script.cpp:224-231  CScript::IsPayToScriptHash()
//       return (this->size() == 23 &&
//               (*this)[0] == OP_HASH160 &&
//               (*this)[1] == 0x14 &&
//               (*this)[22] == OP_EQUAL);
//
// Only the size and three bytes are read; the excerpt takes exactly those.
// OP_HASH160 = 0xa9, the 0x14 byte is the 20-byte direct-push length, and
// OP_EQUAL = 0x87.
extern "C" uint64_t cell_p2sh(uint8_t b0, uint8_t b1, uint8_t b22,
                              uint32_t n) {
  if (n != 23) return 0;
  if (b0 != 0xa9) return 0;
  if (b1 != 0x14) return 0;
  if (b22 != 0x87) return 0;
  return 1;
}
