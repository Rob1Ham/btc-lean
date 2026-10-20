#include "twin_ops.h"
#include "twin_extras.h"
#include "leaf_common.h"

// C leg — Bitcoin Core cce32b168.
//   src/script/script.cpp:313-363  GetScriptOp (the GetOp used below)
//   src/script/script.cpp:266-286  IsPushOnly
//
// SCR-052: an opcode <= OP_16 counts as push-type, including OP_RESERVED
// (0x50).  IsPushOnly's `while (pc < end())` is unrolled twice here: this cell
// only feeds 1- and 2-byte scripts, and GetScriptOp advances pc by at least one
// byte per step, so two guarded steps are exactly the loop.  Truncation and
// the OP_16 test are the two failure arms.
namespace core {

constexpr uint32_t OP_PUSHDATA1 = 0x4c;
constexpr uint32_t OP_PUSHDATA2 = 0x4d;
constexpr uint32_t OP_PUSHDATA4 = 0x4e;
constexpr uint32_t OP_16 = 0x60;

BINLINE bool get_script_op(const uint8_t* b, uint32_t size, uint32_t& pc,
                           uint32_t& opcode_ret, uint32_t& nsize) {
  opcode_ret = 0xff;
  nsize = 0;
  if (pc >= size) return false;
  const uint32_t opcode = b[pc];
  pc += 1;
  if (opcode <= OP_PUSHDATA4) {
    uint32_t n = 0;
    if (opcode < OP_PUSHDATA1) {
      n = opcode;
    } else if (opcode == OP_PUSHDATA1) {
      if (size - pc < 1) return false;
      n = b[pc]; pc += 1;
    } else if (opcode == OP_PUSHDATA2) {
      if (size - pc < 2) return false;
      n = (uint32_t)b[pc] | ((uint32_t)b[pc + 1] << 8); pc += 2;
    } else {
      if (size - pc < 4) return false;
      n = (uint32_t)b[pc] | ((uint32_t)b[pc + 1] << 8) |
          ((uint32_t)b[pc + 2] << 16) | ((uint32_t)b[pc + 3] << 24); pc += 4;
    }
    if ((size - pc) < n) return false;
    pc += n;
    nsize = n;
  }
  opcode_ret = opcode;
  return true;
}

// Unrolled IsPushOnly for script size <= 2.
BINLINE bool is_push_only(const uint8_t* b, uint32_t size) {
  uint32_t pc = 0, opcode = 0, nsize = 0;
  if (pc < size) {
    if (!get_script_op(b, size, pc, opcode, nsize)) return false;
    if (opcode > OP_16) return false;
    if (pc < size) {
      if (!get_script_op(b, size, pc, opcode, nsize)) return false;
      if (opcode > OP_16) return false;
    }
  }
  return true;
}

}  // namespace core

extern "C" uint64_t cell_pushonly1(uint8_t w) {
  uint8_t b[8] = {}; b[0] = w;   // 8 bytes: branch-free reads stay in bounds
  return core::is_push_only(b, 1) ? 1u : 0u;
}

extern "C" uint64_t cell_pushonly2(uint8_t w0, uint8_t w1) {
  uint8_t b[8] = {}; b[0] = w0; b[1] = w1;
  return core::is_push_only(b, 2) ? 1u : 0u;
}
