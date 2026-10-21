// L leg: the twin's eval-loop counter, using the OP_CODESEPARATOR handler
// body generated verbatim from twin/ops_ir.py by cells/_tools/mk_leaf.py.
//
//   twin/ops_ir.py OP_CODESEPARATOR (Lean Defs.lean:1031-1032):
//       st.codeSep = d.next;
//       st.codeSepPos = st.opcodeIndex;
//   twin/runtime.inc:216-217 (reset_eval): codeSepPos = 0xffffffff; opcodeIndex = 0
//   twin/runtime.inc:637-645 (eval_script tail):
//       if (fExec || (0x63 <= d.wire && d.wire <= 0x68)) dispatch(...)
//       ...
//       st.opcodeIndex += 1;
//   Interpreter/Defs.lean:1149 (evalFrom: opcodeIndex := opcodeIndex + 1)
//
// The stream is pre-decoded exactly as in the C leg: kind 0 = push of `len`
// payload bytes, kind 1 = one-byte opcode.  Parsing and vfExec are
// premises; only the counter and the handler assignment are modelled.
#include "twin_ops.h"

using namespace twinleaf;

extern "C" uint64_t cell_codesep_walk(
    uint32_t pend,
    uint32_t k0, uint32_t w0, uint32_t l0, uint32_t e0,
    uint32_t k1, uint32_t w1, uint32_t l1, uint32_t e1,
    uint32_t k2, uint32_t w2, uint32_t l2, uint32_t e2,
    uint32_t k3, uint32_t w3, uint32_t l3, uint32_t e3) {
  State st{};
  st.codeSepPos = 0xffffffffu;  // runtime.inc:216
  st.opcodeIndex = 0;           // runtime.inc:217
  Ctx ctx{};                    // flags = policy = 0
  uint32_t pc = 0;
#define L_STEP(k, w, l, e)                                          \
  if (pc < pend) {                                                  \
    if ((e) != 0 && (k) == 1 && (w) == 0xab) {                      \
      Decoded d{};                                                  \
      d.kind = Kind::Op; d.data = nullptr; d.dlen = 0;              \
      d.wire = (w); d.next = pc + 1;                                \
      (void)op_OP_CODESEPARATOR(st, ctx, d);                        \
    }                                                               \
    pc += ((k) == 0) ? (1u + (l)) : 1u;                             \
    st.opcodeIndex += 1;            /* runtime.inc:644 */           \
  }
  L_STEP(k0, w0, l0, e0)
  L_STEP(k1, w1, l1, e1)
  L_STEP(k2, w2, l2, e2)
  L_STEP(k3, w3, l3, e3)
#undef L_STEP
  return (uint64_t)st.codeSepPos | ((uint64_t)st.opcodeIndex << 32);
}
