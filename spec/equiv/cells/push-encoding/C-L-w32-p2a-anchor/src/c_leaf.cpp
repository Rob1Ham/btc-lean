#include <cstdint>

// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/script.cpp:207-222  IsPayToAnchor(int version, program)
//       return (version == 1 &&
//               program.size() == 2 &&
//               program[0] == 0x4e &&
//               program[1] == 0x73);
//
// The P2A witness program is the two bytes {0x4e, 0x73} under witness
// version 1; its serialized scriptPubKey is the four bytes
// 51 02 4e 73 (OP_1 PUSH2 4e73).  This excerpt is the predicate over the
// decoded (version, program) pair, which is what the row names.
extern "C" uint64_t cell_p2a(uint8_t version, uint8_t p0, uint8_t p1,
                             uint32_t plen) {
  if (version != 1) return 0;
  if (plen != 2) return 0;
  if (p0 != 0x4e) return 0;
  if (p1 != 0x73) return 0;
  return 1;
}
