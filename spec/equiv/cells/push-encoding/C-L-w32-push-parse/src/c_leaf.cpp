#include <cstdint>
// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/script.cpp:313-363  GetScriptOp(pc, end, opcodeRet, pvchRet)
//
// The slice starts at offset 0 (`pc == begin`) and reports:
//   ok, opcode, data length, next offset (pc - begin), data bytes.
// EvalScript's loop maps a decode failure to SCRIPT_ERR_BAD_OPCODE
// (interpreter.cpp:487-488).  This cell is the single-opcode case, so the
// Lean eager-parse/streaming order seam (F-DIV-001) cannot fire: there is no
// earlier runtime error to report first.
//
// All other GetScriptOp edges are preserved:
//   opcode <  OP_PUSHDATA1 : nSize = opcode
//   opcode == OP_PUSHDATA1 : 1 length byte, little-endian nSize
//   opcode == OP_PUSHDATA2 : 2 length bytes, little-endian nSize
//   opcode == OP_PUSHDATA4 : 4 length bytes, little-endian nSize
//   `end - pc < nSize`  : false (truncated push)
// A non-push opcode consumes one byte and carries no data.
//
// The script buffer is 8 bytes; a successful push in this domain therefore
// has nSize <= 7, and the payload copy is the 8 constant lanes below.

#define BINLINE static inline __attribute__((always_inline))

// GetScriptOp body with the read set (b[0..n-1]) and an 8-byte payload sink.
BINLINE bool core_get_script_op(const uint8_t* b, uint32_t n, uint32_t& opcode,
                                uint32_t& dlen, uint32_t& next,
                                uint8_t* payload) {
  opcode = 0xffu; dlen = 0; next = 0;
  if (n < 1) return false;                   // pc >= end
  const uint32_t op = b[0];
  uint32_t pc = 1;
  if (op <= 0x4eu) {
    uint32_t nSize = 0;
    if (op < 0x4cu) {
      nSize = op;
    } else if (op == 0x4cu) {
      if (n - pc < 1) { opcode = op; return false; }
      nSize = b[pc]; pc += 1;
    } else if (op == 0x4du) {
      if (n - pc < 2) { opcode = op; return false; }
      nSize = static_cast<uint32_t>(b[pc]) |
              (static_cast<uint32_t>(b[pc + 1]) << 8);
      pc += 2;
    } else {
      if (n - pc < 4) { opcode = op; return false; }
      nSize = static_cast<uint32_t>(b[pc]) |
              (static_cast<uint32_t>(b[pc + 1]) << 8) |
              (static_cast<uint32_t>(b[pc + 2]) << 16) |
              (static_cast<uint32_t>(b[pc + 3]) << 24);
      pc += 4;
    }
    if (n - pc < nSize) { opcode = op; return false; }  // truncated push
    for (uint32_t i = 0; i < 8; ++i) payload[i] = (i < nSize) ? b[pc + i] : 0;
    pc += nSize;
    opcode = op; dlen = nSize; next = pc;
    return true;
  }
  opcode = op;                               // non-push opcode
  next = pc;                                 // pc has advanced past the opcode
  return true;
}

BINLINE uint64_t core_meta_pack(uint32_t res, uint32_t err, uint32_t wire,
                                uint32_t dlen, uint32_t next) {
  uint64_t r = 0;
  r |= static_cast<uint64_t>(res & 3u);
  r |= static_cast<uint64_t>(err & 0x3fu) << 2;
  r |= static_cast<uint64_t>(wire & 0xffu) << 8;
  r |= static_cast<uint64_t>(dlen & 0xffffu) << 16;
  r |= static_cast<uint64_t>(next & 0xffffu) << 32;
  return r;
}

extern "C" uint64_t cell_parse_meta(uint32_t n, uint8_t b0, uint8_t b1,
                                    uint8_t b2, uint8_t b3, uint8_t b4,
                                    uint8_t b5, uint8_t b6, uint8_t b7) {
  if (n > 8) return 3;                       // out of cell domain
  const uint8_t b[16] = {b0, b1, b2, b3, b4, b5, b6, b7, 0, 0, 0, 0, 0, 0, 0, 0};
  uint32_t opcode = 0, dlen = 0, next = 0;
  uint8_t payload[8] = {0, 0, 0, 0, 0, 0, 0, 0};
  const bool ok = core_get_script_op(b, n, opcode, dlen, next, payload);
  if (!ok) return core_meta_pack(0, 16, n ? b[0] : 0, 0, 0);  // BAD_OPCODE
  return core_meta_pack(1, 0, opcode, dlen, next);
}

extern "C" uint64_t cell_parse_payload(uint32_t n, uint8_t b0, uint8_t b1,
                                       uint8_t b2, uint8_t b3, uint8_t b4,
                                       uint8_t b5, uint8_t b6, uint8_t b7) {
  if (n > 8) return 3;                       // out of cell domain
  const uint8_t b[16] = {b0, b1, b2, b3, b4, b5, b6, b7, 0, 0, 0, 0, 0, 0, 0, 0};
  uint32_t opcode = 0, dlen = 0, next = 0;
  uint8_t payload[8] = {0, 0, 0, 0, 0, 0, 0, 0};
  const bool ok = core_get_script_op(b, n, opcode, dlen, next, payload);
  if (!ok) return 0;
  uint64_t r = 0;
  for (uint32_t i = 0; i < 8; ++i) r |= static_cast<uint64_t>(payload[i]) << (8u * i);
  return r;
}
