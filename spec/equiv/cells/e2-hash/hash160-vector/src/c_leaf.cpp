#include "e2_common.h"
// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/interpreter.cpp:1032-1056  hash opcode family
//       case OP_HASH160:
//       if (stack.size() < 1) return SCRIPT_ERR_INVALID_STACK_OPERATION;
//       valtype& vch = stacktop(-1);
//       valtype vchHash(20);          // interpreter.cpp:1042 (20 for RIPEMD160/SHA1/HASH160)
//       CHash160().Write(vch).Finalize(vchHash);
//       popstack(stack);              // interpreter.cpp:1053
//       stack.push_back(vchHash);     // interpreter.cpp:1054
//
// The cryptographic transform is an opaque external at the signed-hash seam.
// The same `hash160` symbol is called by the L leg, so the cell proves the
// opcode plumbing (underflow, output width, push/pop) while the digest itself
// is an assumption, supplied concretely by the SAW override.
extern "C" void hash160(const uint8_t* in, uint32_t len, uint8_t* out);

extern "C" uint64_t cell_hash160() {
  const uint8_t pre[1] = {0x61};     // (in) vch: closed witness "a"
  uint8_t out[20];                   // vchHash is 20 bytes for HASH160
  hash160(pre, 1, out);              // CHash160().Write(vch).Finalize(vchHash)
  HStack s{};
  s.len[0] = 20;
  s.e[0][0]  = out[0];  s.e[0][1]  = out[1];  s.e[0][2]  = out[2];  s.e[0][3]  = out[3];
  s.e[0][4]  = out[4];  s.e[0][5]  = out[5];  s.e[0][6]  = out[6];  s.e[0][7]  = out[7];
  s.e[0][8]  = out[8];  s.e[0][9]  = out[9];  s.e[0][10] = out[10]; s.e[0][11] = out[11];
  s.e[0][12] = out[12]; s.e[0][13] = out[13]; s.e[0][14] = out[14]; s.e[0][15] = out[15];
  s.e[0][16] = out[16]; s.e[0][17] = out[17]; s.e[0][18] = out[18]; s.e[0][19] = out[19];
  s.n = 1;
  return h_pack(1, 0, s);
}
