#include "limits_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/script.cpp at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   script.cpp:159-181  CScript::GetSigOpCount(bool fAccurate)
//       opcodetype lastOpcode = OP_INVALIDOPCODE;        // 0xff
//       while (pc < end()) {
//           opcodetype opcode;
//           if (!GetOp(pc, opcode)) break;
//           if (opcode == OP_CHECKSIG || opcode == OP_CHECKSIGVERIFY)
//               n++;
//           else if (opcode == OP_CHECKMULTISIG || opcode == OP_CHECKMULTISIGVERIFY) {
//               if (fAccurate && lastOpcode >= OP_1 && lastOpcode <= OP_16)
//                   n += DecodeOP_N(lastOpcode);
//               else
//                   n += MAX_PUBKEYS_PER_MULTISIG;
//           }
//           lastOpcode = opcode;
//       }
//
//   script.h:35   MAX_PUBKEYS_PER_MULTISIG = 20
//   opcode.h      OP_1 = 0x51, OP_16 = 0x60, OP_CHECKSIG = 0xac,
//                 OP_CHECKSIGVERIFY = 0xad, OP_CHECKMULTISIG = 0xae,
//                 OP_CHECKMULTISIGVERIFY = 0xaf
//
// This slice is the per-site contribution of the loop body: one iteration,
// given the current opcode and the `lastOpcode` carried by the previous
// iteration.  `opcodetype` is the wire byte (0..0xff; OP_INVALIDOPCODE is
// 0xff), so both arguments are 8-bit and the function is total over every
// real opcode pair.  The script walk (which sites exist, and where a
// malformed push terminates the loop) is not part of this cell.

constexpr uint8_t OP_1 = 0x51;
constexpr uint8_t OP_16 = 0x60;
constexpr uint8_t OP_CHECKSIG = 0xac;
constexpr uint8_t OP_CHECKSIGVERIFY = 0xad;
constexpr uint8_t OP_CHECKMULTISIG = 0xae;
constexpr uint8_t OP_CHECKMULTISIGVERIFY = 0xaf;
constexpr uint32_t MAX_PUBKEYS_PER_MULTISIG = 20;

LIMITS_INLINE uint32_t c_sigop_site_weight(uint8_t lastOpcode, uint8_t opcode, uint8_t fAccurate) {
    uint32_t n = 0;
    if (opcode == OP_CHECKSIG || opcode == OP_CHECKSIGVERIFY) {
        n++;                                                        // script.cpp:168
    } else if (opcode == OP_CHECKMULTISIG || opcode == OP_CHECKMULTISIGVERIFY) {
        if ((fAccurate != 0) && lastOpcode >= OP_1 && lastOpcode <= OP_16)
            n += (uint32_t)(lastOpcode - OP_1 + 1);                 // DecodeOP_N
        else
            n += MAX_PUBKEYS_PER_MULTISIG;                          // script.cpp:175-177
    }
    return n;
}

extern "C" uint32_t cell_sigop_site_weight(uint8_t lastOpcode, uint8_t opcode, uint8_t fAccurate) {
    return c_sigop_site_weight(lastOpcode, opcode, fAccurate);
}
