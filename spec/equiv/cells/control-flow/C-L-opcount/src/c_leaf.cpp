#include "cell.h"
// C leg: exact source slice from Bitcoin Core cce32b168
// src/script/interpreter.cpp:459-463.
//
//   if (sigversion == SigVersion::BASE || sigversion == SigVersion::WITNESS_V0) {
//       // Note how OP_RESERVED does not count towards the opcode limit.
//       if (opcode > OP_16 && ++nOpCount > MAX_OPS_PER_SCRIPT) {
//           return set_error(serror, SCRIPT_ERR_OP_COUNT);
//       }
//   }
//
// OP_16 is 0x60 and MAX_OPS_PER_SCRIPT is 201 (script.h).  The cell takes a
// symbolic wire opcode and a symbolic starting counter; it observes the
// post-increment counter and whether the limit tripped.  The counter input is
// meant for the reachable range 0..201; the proof covers all 32-bit values,
// and both legs use the same unsigned 32-bit increment.

extern "C" uint64_t cell_opcount(uint32_t sv, uint8_t w, uint32_t opcount) {
  uint32_t nOpCount = opcount;
  uint32_t err = 0;
  if (sv == 0 || sv == 1) {                 // BASE || WITNESS_V0
    if (w > 0x60u && ++nOpCount > 201u)     // opcode > OP_16
      err = 7;                              // SCRIPT_ERR_OP_COUNT
  }
  return opc_pack(err, nOpCount);
}
