#include "cell.h"
#include "twin_ops.h"
using namespace twinleaf;
// L leg: direct transcription of the Lean opcode-budget step,
// spec/core/Bitcoin/Interpreter/Defs.lean:824-829:
//
//   -- (2) opcode budget (interpreter.cpp:459-463)
//   let counts := (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < w
//   let opCount' := if counts then st.opCount + 1 else st.opCount
//   if counts ∧ MAX_OPS_PER_SCRIPT < opCount' then .error .opCount
//
// The error ordinal comes from core_ord(TWIN_OP_COUNT).

extern "C" uint64_t cell_opcount(uint32_t sv, uint8_t w, uint32_t opcount) {
  const bool counts = (sv == 0 || sv == 1) && w > 0x60u;
  const uint32_t nc = counts ? opcount + 1u : opcount;
  const uint32_t err =
      (counts && nc > 201u) ? (uint32_t)core_ord(TWIN_OP_COUNT) : 0u;
  return opc_pack(err, nc);
}
