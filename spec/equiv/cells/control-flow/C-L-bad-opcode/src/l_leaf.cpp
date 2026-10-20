#include "cell.h"
#include "twin_ops.h"
using namespace twinleaf;
// L leg: direct transcription of the Lean model's opcode budget and dispatch
// default, spec/core/Bitcoin/Interpreter/Defs.lean:824-829 (budget),
// :851-853 (the [0x63..0x68] gate), and :904-905 area (badOpcode arms).
//
//   -- (2) opcode budget (interpreter.cpp:459-463)
//   let counts := (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < w
//   let opCount' := if counts then st.opCount + 1 else st.opCount
//   if counts ∧ MAX_OPS_PER_SCRIPT < opCount' then .error .opCount
//   ...
//   | .op _ =>
//       if !(fExec ∨ (0x63 ≤ w ∧ w ≤ 0x68)) then .ok st₁
//       else dispatchOp ctx op w fExec st₁
//   ...
//   else if w = 0x65 ∨ w = 0x66 then .error .badOpcode      -- OP_VERIF / OP_VERNOTIF
//   ...
//   default: .error .badOpcode
//
// The wire selector and packed observable are cell harness; error ordinals
// come from core_ord.

BINLINE uint32_t l_wire(uint32_t op) {
  if (op == 1) return 0x62;  // OP_VER
  if (op == 2) return 0x65;  // OP_VERIF
  if (op == 3) return 0x66;  // OP_VERNOTIF
  return 0x50;               // OP_RESERVED
}

BINLINE uint32_t l_step(uint32_t op, uint32_t fexec, uint32_t sv,
                        uint32_t opcount) {
  const uint32_t w = l_wire(op & 3u);  // selector is 2 bits
  const bool counts = (sv == 0 || sv == 1) && w > 0x60u;
  const uint32_t nc = counts ? opcount + 1u : opcount;
  if (counts && nc > 201u)
    return (uint32_t)core_ord(TWIN_OP_COUNT);
  if (!(fexec != 0 || (0x63u <= w && w <= 0x68u)))
    return 0;  // skipped
  return (uint32_t)core_ord(TWIN_BAD_OPCODE);
}

extern "C" uint64_t cell_bad(uint32_t op, uint32_t fexec, uint32_t sv,
                              uint32_t opcount) {
  const uint32_t w = l_wire(op & 3u);  // selector is 2 bits
  const bool counts = (sv == 0 || sv == 1) && w > 0x60u;
  const uint32_t nc = counts ? opcount + 1u : opcount;
  const uint32_t e = l_step(op, fexec, sv, opcount);
  return bad_pack(e, nc);
}
