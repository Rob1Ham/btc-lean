#include "e2_common.h"
#include "twin_ops.h"
using namespace twinleaf;
// L leg: the OP_WITHIN handler is copied verbatim from twin/ops_ir.py by
// cells/_tools/mk_leaf.py (see build/twin_ops.h).  The bounded
// init/dispatch/finish/pack code below is cell harness, not engine code.

BINLINE void l_init(State& st) {
  st.stack.n = 0;
  for (int i = 0; i < 4; ++i) { st.stack.len[i] = 0; st.stack.e[i][0] = 0; st.stack.e[i][1] = 0; }
  st.alt.n = 0; st.saved.n = 0; st.vf_n = 0; st.opCount = 0;
  st.codeSep = 0; st.codeSepPos = 0xffffffffu; st.opcodeIndex = 0;
  st.vwLeft = 0; st.has_vw = false;
}
BINLINE TwinErr l_push1(State& st, uint32_t v) {
  uint8_t b = static_cast<uint8_t>(v);
  return st_push(st.stack, &b, 1);
}
BINLINE void l_to_b(const State& st, BStack& s) {
  s.n = st.stack.n;
  for (uint32_t i = 0; i < 4 && i < s.n; ++i) {
    s.len[i] = st.stack.len[i];
    s.val[i] = st.stack.e[i][0];
  }
}
BINLINE uint64_t l_fail(const State& st, TwinErr e) {
  BStack s{}; l_to_b(st, s);
  return b_pack(0, static_cast<uint32_t>(core_ord(e)), s);
}
BINLINE uint64_t l_finish(const State& st) {
  BStack s{}; l_to_b(st, s);
  if (st.alt.n != 0) return b_pack(3, 1, s);
  if (st.stack.n == 0) return b_pack(0, 2, s);
  const uint32_t l = st.stack.len[st.stack.n - 1];
  if (!cast_to_bool(st.stack.e[st.stack.n - 1], l)) return b_pack(0, 2, s);
  return b_pack(1, 0, s);
}
BINLINE TwinErr l_step(State& st, uint32_t wire) {
  Ctx ctx{}; Decoded d{};
  d.kind = Kind::Op; d.data = nullptr; d.dlen = 0; d.wire = wire; d.next = 1;
  if (wire == 0xa5) return op_OP_WITHIN(st, ctx, d);
  return TWIN_INVALID_UNSUPPORTED;
}
#define LSTEP(x) do { TwinErr _e = (x); if (_e) return l_fail(st, _e); } while (0)

extern "C" uint64_t cell_within(uint8_t av, uint8_t bv, uint8_t cv) {
  State st{}; l_init(st);
  LSTEP(l_push1(st, av)); LSTEP(l_push1(st, bv)); LSTEP(l_push1(st, cv));
  LSTEP(l_step(st, 0xa5));
  return l_finish(st);
}
