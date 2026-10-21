#include "limits_common.h"
// C leg — source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/interpreter.cpp:441
//       int nOpCount = 0;
//   src/script/interpreter.cpp:460-464
//       if (sigversion == SigVersion::BASE || sigversion == SigVersion::WITNESS_V0) {
//           // Note how OP_RESERVED does not count towards the opcode limit.
//           if (opcode > OP_16 && ++nOpCount > MAX_OPS_PER_SCRIPT) {
//               return set_error(serror, SCRIPT_ERR_OP_COUNT);
//           }
//       }
//   src/script/interpreter.cpp:467-482  (disabled table, unexecuted included)
//   src/script/script.h:32               MAX_OPS_PER_SCRIPT = 201
//
// The cell is one decoded, fully parsed instruction (`wire` is the opcode
// byte; no push value, so the :457-458 PUSH_SIZE check cannot fire) with the
// incoming nOpCount symbolic in [0, 202].  `sv` selects BASE (0),
// WITNESS_V0 (1) or TAPSCRIPT (2): the budget block is skipped entirely for
// TAPSCRIPT, so a disabled opcode there reaches the disabled table.
// `fExec` is the enclosing condition-stack value; the budget block is
// upstream of it (the flow-insensitivity of SCR-023).

LIM_BINLINE bool core_disabled_opcode(uint8_t opcode) {
  // interpreter.cpp:467-482, the exact disabled set at the pin.
  return opcode == 0x7e || opcode == 0x7f || opcode == 0x80 ||
         opcode == 0x81 || opcode == 0x83 || opcode == 0x84 ||
         opcode == 0x85 || opcode == 0x86 || opcode == 0x8d ||
         opcode == 0x8e || opcode == 0x95 || opcode == 0x96 ||
         opcode == 0x97 || opcode == 0x98 || opcode == 0x99;
}

extern "C" uint64_t cell_opcount(uint32_t opCount, uint8_t wire,
                                 uint8_t fExec, uint8_t sv) {
  // Cell domain: opCount <= 202 keeps `++nOpCount` inside the range the row
  // is about; Core's `int` cannot overflow in this domain.
  if (!lim_valid_sigversion(sv) || fExec > 1 || opCount > 202) {
    return lim_bad_input();
  }
  int nOpCount = static_cast<int>(opCount);

  // interpreter.cpp:460-464.  OP_16 is 0x60; OP_RESERVED (0x50) and every
  // push wire 0x00-0x60 are exempt.  The increment and check happen before
  // the disabled table and before fExec is used.
  if (sv == LIM_SV_BASE || sv == LIM_SV_WITNESS_V0) {
    if (wire > 0x60) {
      ++nOpCount;
      if (nOpCount > LIM_MAX_OPS_PER_SCRIPT) {
        return lim_pack(0, EQUIV_ERR_OP_COUNT, 0);
      }
    }
  }

  // interpreter.cpp:467-482.  For a disabled opcode whose charge exhausted
  // the budget, the OP_COUNT return above wins (SCR-025).
  if (core_disabled_opcode(wire)) {
    return lim_pack(0, EQUIV_ERR_DISABLED_OPCODE, 0);
  }

  // payload: charged count (low 11 bits) | executed bit at 12.
  const uint32_t charged = static_cast<uint32_t>(nOpCount);
  return lim_pack(1, EQUIV_ERR_OK, charged | (static_cast<uint32_t>(fExec) << 12));
}
