#include "w32_common.h"

// C leg: the body of Bitcoin Core's `IsOpSuccess`, copied verbatim from
// src/script/script.cpp:365-371 at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, in a uint32 wrapper for the
// opcodetype argument (`opcodetype` is an enum over int; only the numeric value
// is observed).
//
// The cell function takes a uint8_t, i.e. every wire byte 0x00..0xff, and
// returns 1 if the byte is an OP_SUCCESSx, else 0.  No parse, no execution and
// no flags are involved; SCR-152 is exactly this membership test.

W32INLINE bool c_is_op_success(uint32_t opcode) {
    return opcode == 80 || opcode == 98 || (opcode >= 126 && opcode <= 129) ||
           (opcode >= 131 && opcode <= 134) || (opcode >= 137 && opcode <= 138) ||
           (opcode >= 141 && opcode <= 142) || (opcode >= 149 && opcode <= 153) ||
           (opcode >= 187 && opcode <= 254);
}

extern "C" uint32_t cell_is_op_success(uint8_t opcode) {
    return c_is_op_success((uint32_t)opcode) ? 1u : 0u;
}
