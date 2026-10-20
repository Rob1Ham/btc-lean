#include "gate_common.h"
#include "twin_ops.h"
using namespace twinleaf;
// L leg: handler bodies are copied verbatim from twin/ops_ir.py by
// cells/_tools/mk_leaf.py.  Every function starts with an empty stack, so the
// per-op arity guard is the branch under test; the packed observable is
// (result=0, error=INVALID_STACK_OPERATION=18, n=0).
BINLINE void l_init(State& st) {
  st.stack.n = 0; for (int i = 0; i < 6; ++i) { st.stack.len[i] = 0; st.stack.e[i][0] = 0; }
  st.alt.n = 0; for (int i = 0; i < 6; ++i) { st.alt.len[i] = 0; st.alt.e[i][0] = 0; }
  st.saved.n = 0; st.vf_n = 0; st.opCount = 0;
  st.codeSep = 0; st.codeSepPos = 0xffffffffu; st.opcodeIndex = 0;
  st.vwLeft = 0; st.has_vw = false;
}
BINLINE TwinErr l_step(State& st, uint32_t wire) {
  Ctx ctx{}; Decoded d{};
  d.kind = Kind::Op; d.data = nullptr; d.dlen = 0; d.wire = wire; d.next = 1;
  switch (wire) {
    case 0x6d: return op_OP_2DROP(st, ctx, d);
    case 0x6e: return op_OP_2DUP(st, ctx, d);
    case 0x6f: return op_OP_3DUP(st, ctx, d);
    case 0x70: return op_OP_2OVER(st, ctx, d);
    case 0x71: return op_OP_2ROT(st, ctx, d);
    case 0x72: return op_OP_2SWAP(st, ctx, d);
    case 0x73: return op_OP_IFDUP(st, ctx, d);
    case 0x75: return op_OP_DROP(st, ctx, d);
    case 0x76: return op_OP_DUP(st, ctx, d);
    case 0x77: return op_OP_NIP(st, ctx, d);
    case 0x78: return op_OP_OVER(st, ctx, d);
    case 0x79: case 0x7a: return op_OP_PICK(st, ctx, d);
    case 0x7b: return op_OP_ROT(st, ctx, d);
    case 0x7c: return op_OP_SWAP(st, ctx, d);
    case 0x7d: return op_OP_TUCK(st, ctx, d);
    default: return TWIN_INVALID_UNSUPPORTED;
  }
}
BINLINE uint64_t l_fail(const State& st, TwinErr e) {
  BStack s; b_clear(s); s.n = st.stack.n;
  return b_pack(0, (uint32_t)core_ord(e), s);
}
#define CELL(name, wire) \
  extern "C" uint64_t name() { \
    State st; l_init(st); \
    TwinErr e = l_step(st, wire); \
    if (e) return l_fail(st, e); \
    BStack out; b_clear(out); return b_pack(0, 0, out); \
  }
CELL(cell_2drop, 0x6d)
CELL(cell_2dup,  0x6e)
CELL(cell_3dup,  0x6f)
CELL(cell_2over, 0x70)
CELL(cell_2rot,  0x71)
CELL(cell_2swap, 0x72)
CELL(cell_ifdup, 0x73)
CELL(cell_drop,  0x75)
CELL(cell_dup,   0x76)
CELL(cell_nip,   0x77)
CELL(cell_over,  0x78)
CELL(cell_pick,  0x79)
CELL(cell_roll,  0x7a)
CELL(cell_rot,   0x7b)
CELL(cell_swap,  0x7c)
CELL(cell_tuck,  0x7d)
