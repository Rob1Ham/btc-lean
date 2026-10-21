#include "limits_common.h"
// L leg — reviewed transliteration of the Lean twin.
//
//   spec/core/Bitcoin/Interpreter/Defs.lean:817-833 (stepBody):
//     let counts := (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < w
//     let opCount' := if counts then st.opCount + 1 else st.opCount
//     if counts ∧ MAX_OPS_PER_SCRIPT < opCount' then .error .opCount
//     else if disabledWire w then .error .disabledOpcode
//     else ...
//   Defs.lean:455-457 (disabledWire list)
//
// The generated twin has the same three structural steps at
// spec/equiv/twin/runtime.inc:607-614:
//       if ((ctx.sv == Base || ctx.sv == WitnessV0) && d.wire > 0x60) {
//         st.opCount += 1;
//         if (st.opCount > MAX_OPS_PER_SCRIPT) return TWIN_OP_COUNT;
//       }
//       if (disabled_wire(d.wire)) return TWIN_DISABLED_OPCODE;
//   `vf_all(st)` (the fExec value) is read only AFTER those steps, which is
//   the flow-insensitivity of SCR-023.  There is no per-opcode handler for
//   this limit.

LIM_BINLINE bool lim_disabled_wire(uint8_t w) {
  // Defs.lean:455-457 / runtime.inc:396-407, the exact disabled set.
  return w == 0x7e || w == 0x7f || w == 0x80 || w == 0x81 ||
         w == 0x83 || w == 0x84 || w == 0x85 || w == 0x86 ||
         w == 0x8d || w == 0x8e || w == 0x95 || w == 0x96 ||
         w == 0x97 || w == 0x98 || w == 0x99;
}

extern "C" uint64_t cell_opcount(uint32_t opCount, uint8_t wire,
                                 uint8_t fExec, uint8_t sv) {
  if (!lim_valid_sigversion(sv) || fExec > 1 || opCount > 202) {
    return lim_bad_input();
  }

  // Defs.lean:827-828.
  const bool counts = (sv == LIM_SV_BASE || sv == LIM_SV_WITNESS_V0) &&
                      (0x60 < wire);
  const uint32_t opCount_next = counts ? opCount + 1u : opCount;

  // Defs.lean:829-830: budget check strictly before the disabled table.
  if (counts && LIM_MAX_OPS_PER_SCRIPT < opCount_next) {
    return lim_pack(0, EQUIV_ERR_OP_COUNT, 0);
  }
  // Defs.lean:831-832.
  if (lim_disabled_wire(wire)) {
    return lim_pack(0, EQUIV_ERR_DISABLED_OPCODE, 0);
  }

  return lim_pack(1, EQUIV_ERR_OK,
                  opCount_next | (static_cast<uint32_t>(fExec) << 12));
}
