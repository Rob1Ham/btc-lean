#include <cstdint>

// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/script.cpp:266-286  CScript::IsPushOnly()
//       CScript::const_iterator pc = begin();
//       opcodetype opcode;
//       do {
//           if (pc == end()) break;
//           if (!GetOp(pc, opcode)) return false;
//           if (opcode > OP_16) return false;
//       } while (pc < end());
//       return true;
//
// and the GetOp decode (script.h): a direct push needs its data bytes; the
// PUSHDATA1/2/4 forms need their length field and data.  A one-byte script
// therefore fails GetOp for every push form, which is the truncated-tail
// behaviour Core reports as "not push-only" here (no error kind is produced).
static bool core_get_op(const uint8_t* b, uint32_t size, uint32_t& pc,
                        uint32_t& opcode) {
  if (pc >= size) return false;
  opcode = b[pc++];
  if (opcode <= 0x4b) {
    if (opcode > size - pc) return false;
    pc += opcode;
  } else if (opcode == 0x4c) {
    if (1u > size - pc) return false;
    const uint32_t k = b[pc];
    pc += 1;
    if (k > size - pc) return false;
    pc += k;
  } else if (opcode == 0x4d) {
    if (2u > size - pc) return false;
    const uint32_t k = (uint32_t)b[pc] | ((uint32_t)b[pc + 1] << 8);
    pc += 2;
    if (k > size - pc) return false;
    pc += k;
  } else if (opcode == 0x4e) {
    if (4u > size - pc) return false;
    const uint32_t k = (uint32_t)b[pc] | ((uint32_t)b[pc + 1] << 8) |
                       ((uint32_t)b[pc + 2] << 16) |
                       ((uint32_t)b[pc + 3] << 24);
    pc += 4;
    if (k > size - pc) return false;
    pc += k;
  }
  return true;
}

static bool core_is_push_only(const uint8_t* b, uint32_t size) {
  uint32_t pc = 0;
  while (pc < size) {
    uint32_t opcode = 0;
    if (!core_get_op(b, size, pc, opcode)) return false;
    if (opcode > 0x60) return false;  // OP_16; OP_RESERVED (0x50) counts
  }
  return true;
}

extern "C" uint64_t cell_po0() {
  return core_is_push_only(nullptr, 0) ? 1u : 0u;
}

extern "C" uint64_t cell_po1(uint8_t b0) {
  const uint8_t b[1] = {b0};
  return core_is_push_only(b, 1) ? 1u : 0u;
}
