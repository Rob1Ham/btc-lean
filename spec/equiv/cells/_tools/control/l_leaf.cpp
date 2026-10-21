#include "gate_common.h"
#include "twin_ops.h"
using namespace twinleaf;
// L leg: handlers are copied verbatim from twin/ops_ir.py by
// cells/_tools/mk_leaf.py.  The dispatch below selects the same wires as the
// closed witnesses; the shared bounded init/pack code is cell harness.
BINLINE void l_init(State& st) {
  st.stack.n = 0; for (int i = 0; i < 6; ++i) { st.stack.len[i] = 0; st.stack.e[i][0] = 0; }
  st.alt.n = 0; for (int i = 0; i < 6; ++i) { st.alt.len[i] = 0; st.alt.e[i][0] = 0; }
  st.saved.n = 0; st.vf_n = 0; st.opCount = 0;
  st.codeSep = 0; st.codeSepPos = 0xffffffffu; st.opcodeIndex = 0;
  st.vwLeft = 0; st.has_vw = false;
}
BINLINE TwinErr l_push(State& st, uint32_t v) {
  uint8_t b = (uint8_t)v; return st_push(st.stack, &b, 1);
}
BINLINE TwinErr l_step(State& st, uint32_t wire) {
  Ctx ctx{}; Decoded d{};
  d.kind = Kind::Op; d.data = nullptr; d.dlen = 0; d.wire = wire; d.next = 1;
  switch (wire) {
    case 0x61: return op_OP_NOP(st, ctx, d);
    case 0x6a: return op_OP_RETURN(st, ctx, d);
    case 0xb0: case 0xb3: case 0xb4: case 0xb5:
    case 0xb6: case 0xb7: case 0xb8: case 0xb9:
      return op_OP_NOP_UPGRADABLE(st, ctx, d);
    default: return TWIN_INVALID_UNSUPPORTED;
  }
}
BINLINE void l_to_b(const State& st, BStack& s) {
  b_clear(s); s.n = st.stack.n;
  for (uint32_t i = 0; i < 6 && i < s.n; ++i) { s.len[i] = st.stack.len[i]; s.val[i] = st.stack.e[i][0]; }
}
BINLINE uint64_t l_fail(const State& st, TwinErr e) {
  BStack s; l_to_b(st, s); return b_pack(0, (uint32_t)core_ord(e), s);
}
BINLINE uint64_t l_finish(const State& st) {
  BStack s; l_to_b(st, s);
  if (st.alt.n != 0) return b_pack(3, 1, s);
  if (st.stack.n == 0) return b_pack(0, 2, s);
  const uint32_t l = st.stack.len[st.stack.n - 1];
  if (!cast_to_bool(st.stack.e[st.stack.n - 1], l)) return b_pack(0, 2, s);
  return b_pack(1, 0, s);
}
#define LSTEP(x) do { TwinErr _e = (x); if (_e) return l_fail(st, _e); } while (0)
extern "C" uint64_t cell_op_return() {
  State st; l_init(st);
  LSTEP(l_step(st, 0x6a));
  return l_finish(st);
}
extern "C" uint64_t cell_plain_nop() {
  State st; l_init(st);
  LSTEP(l_push(st, 1)); LSTEP(l_step(st, 0x61));
  return l_finish(st);
}
extern "C" uint64_t cell_nop1() {
  State st; l_init(st);
  LSTEP(l_push(st, 1)); LSTEP(l_step(st, 0xb0));
  return l_finish(st);
}
extern "C" uint64_t cell_nop4_to_10() {
  State st; l_init(st);
  LSTEP(l_push(st, 1));
  // OP_NOP4..OP_NOP10, straight-line so Alive2 sees a return.
  LSTEP(l_step(st, 0xb3)); LSTEP(l_step(st, 0xb4));
  LSTEP(l_step(st, 0xb5)); LSTEP(l_step(st, 0xb6));
  LSTEP(l_step(st, 0xb7)); LSTEP(l_step(st, 0xb8));
  LSTEP(l_step(st, 0xb9));
  return l_finish(st);
}
