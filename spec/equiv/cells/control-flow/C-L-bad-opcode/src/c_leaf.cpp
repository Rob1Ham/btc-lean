#include "cell.h"
// C leg: source-excerpt slice of Bitcoin Core cce32b168
// src/script/interpreter.cpp:459-463 (opcode budget), :493 (the
// [OP_IF..OP_ENDIF] dispatch gate), and :1227-1228 (default: BAD_OPCODE).
//
//   if (sigversion == SigVersion::BASE || sigversion == SigVersion::WITNESS_V0) {
//       // Note how OP_RESERVED does not count towards the opcode limit.
//       if (opcode > OP_16 && ++nOpCount > MAX_OPS_PER_SCRIPT) {
//           return set_error(serror, SCRIPT_ERR_OP_COUNT);
//       }
//   }
//   ...
//   } else if (fExec || (OP_IF <= opcode && opcode <= OP_ENDIF))
//   switch (opcode)
//   {
//       ...
//       default:
//           return set_error(serror, SCRIPT_ERR_BAD_OPCODE);
//   }
//
// `op` selects the wire opcode: 0 = OP_RESERVED (0x50), 1 = OP_VER (0x62),
// 2 = OP_VERIF (0x65), 3 = OP_VERNOTIF (0x66).  Every one of these reaches
// the `default:` arm when it is dispatched: OP_VERIF/OP_VERNOTIF are inside
// [OP_IF..OP_ENDIF] so they are dispatched even when fExec is false, while
// OP_RESERVED/OP_VER are skipped when fExec is false.  The opcode budget is
// evaluated first, so an exhausted budget reports OP_COUNT (7), not
// BAD_OPCODE (16).

BINLINE uint32_t core_wire(uint32_t op) {
  if (op == 1) return 0x62;  // OP_VER
  if (op == 2) return 0x65;  // OP_VERIF
  if (op == 3) return 0x66;  // OP_VERNOTIF
  return 0x50;               // OP_RESERVED
}

BINLINE uint32_t core_step(uint32_t op, uint32_t fexec, uint32_t sv,
                           uint32_t opcount) {
  const uint32_t w = core_wire(op & 3u);  // selector is 2 bits
  // interpreter.cpp:459-463
  const bool counts =
      (sv == 0 || sv == 1) && w > 0x60u;  // BASE/WITNESS_V0, opcode > OP_16
  const uint32_t nc = counts ? opcount + 1u : opcount;
  if (counts && nc > 201u)
    return 7;  // SCRIPT_ERR_OP_COUNT (MAX_OPS_PER_SCRIPT == 201)
  // interpreter.cpp:493
  if (fexec != 0 || (0x63u <= w && w <= 0x68u))
    return 16;  // default: SCRIPT_ERR_BAD_OPCODE, interpreter.cpp:1227-1228
  return 0;
}

extern "C" uint64_t cell_bad(uint32_t op, uint32_t fexec, uint32_t sv,
                              uint32_t opcount) {
  const uint32_t w = core_wire(op & 3u);  // selector is 2 bits
  const bool counts = (sv == 0 || sv == 1) && w > 0x60u;
  const uint32_t nc = counts ? opcount + 1u : opcount;
  const uint32_t e = core_step(op, fexec, sv, opcount);
  return bad_pack(e, nc);
}
