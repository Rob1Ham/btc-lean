#include "gate_common.h"
#include "twin_ops.h"
using namespace twinleaf;
BINLINE void l_init(State& st) {
  st.stack.n = 0; st.stack.len[0]=0; st.stack.len[1]=0; st.stack.len[2]=0; st.stack.len[3]=0; st.stack.len[4]=0; st.stack.len[5]=0;
  st.stack.e[0][0]=0; st.stack.e[1][0]=0; st.stack.e[2][0]=0; st.stack.e[3][0]=0; st.stack.e[4][0]=0; st.stack.e[5][0]=0;
  st.alt.n = 0; st.alt.len[0]=0; st.alt.len[1]=0; st.alt.len[2]=0; st.alt.len[3]=0; st.alt.len[4]=0; st.alt.len[5]=0;
  st.alt.e[0][0]=0; st.alt.e[1][0]=0; st.alt.e[2][0]=0; st.alt.e[3][0]=0; st.alt.e[4][0]=0; st.alt.e[5][0]=0;
  st.saved.n = 0; st.vf_n = 0; st.opCount = 0;
  st.codeSep = 0; st.codeSepPos = 0xffffffffu; st.opcodeIndex = 0;
  st.vwLeft = 0; st.has_vw = false;
}
BINLINE TwinErr l_push(State& st, uint32_t v) {
  uint8_t b = (uint8_t)v; return st_push(st.stack, &b, 1);
}
BINLINE TwinErr l_push_empty(State& st) {
  return st_push(st.stack, nullptr, 0);
}
BINLINE TwinErr l_step(State& st, uint32_t wire) {
  Ctx ctx{}; Decoded d{};
  d.kind = Kind::Op; d.data = nullptr; d.dlen = 0; d.wire = wire; d.next = 1;
  switch (wire) {
    case 0x6b: return op_OP_TOALTSTACK(st, ctx, d);
    case 0x6c: return op_OP_FROMALTSTACK(st, ctx, d);
    case 0x74: return op_OP_DEPTH(st, ctx, d);
    case 0x76: return op_OP_DUP(st, ctx, d);
    case 0x79: return op_OP_PICK(st, ctx, d);
    case 0x75: return op_OP_DROP(st, ctx, d);
    case 0x69: return op_OP_VERIFY(st, ctx, d);
    case 0x7b: return op_OP_ROT(st, ctx, d);
    case 0x7c: return op_OP_SWAP(st, ctx, d);
    case 0x87: return op_OP_EQUAL(st, ctx, d);
    default: return TWIN_INVALID_UNSUPPORTED;
  }
}
BINLINE void l_to_b(const State& st, BStack& s) {
  b_clear(s); s.n = st.stack.n;
  if (s.n >= 1) { s.len[0]=st.stack.len[0]; s.val[0]=st.stack.e[0][0]; }
  if (s.n >= 2) { s.len[1]=st.stack.len[1]; s.val[1]=st.stack.e[1][0]; }
  if (s.n >= 3) { s.len[2]=st.stack.len[2]; s.val[2]=st.stack.e[2][0]; }
  if (s.n >= 4) { s.len[3]=st.stack.len[3]; s.val[3]=st.stack.e[3][0]; }
  if (s.n >= 5) { s.len[4]=st.stack.len[4]; s.val[4]=st.stack.e[4][0]; }
  if (s.n >= 6) { s.len[5]=st.stack.len[5]; s.val[5]=st.stack.e[5][0]; }
}
BINLINE uint64_t l_fail(const State& st, TwinErr e) {
  BStack s; l_to_b(st, s); return b_pack(0, (uint32_t)core_ord(e), s);
}
BINLINE uint64_t l_finish(const State& st) {
  BStack s; l_to_b(st, s);
  if (st.alt.n != 0) return b_pack(3, 1, s);
  if (st.stack.n == 0) return b_pack(0, 2, s);
  uint32_t l = st.stack.len[st.stack.n - 1];
  if (!cast_to_bool(st.stack.e[st.stack.n - 1], l)) return b_pack(0, 2, s);
  return b_pack(1, 0, s);
}
#define LSTEP(x) do { TwinErr _e = (x); if (_e) return l_fail(st, _e); } while (0)
extern "C" uint64_t cell_swap_order() {
  State st; l_init(st);
  LSTEP(l_push(st,1)); LSTEP(l_push(st,2)); LSTEP(l_step(st,0x7c));
  LSTEP(l_push(st,1)); LSTEP(l_step(st,0x87));
  return l_finish(st);
}
extern "C" uint64_t cell_dup_order() {
  State st; l_init(st);
  LSTEP(l_push(st,1)); LSTEP(l_push(st,2)); LSTEP(l_step(st,0x76));
  LSTEP(l_push(st,2)); LSTEP(l_step(st,0x87));
  return l_finish(st);
}
extern "C" uint64_t cell_rot_direction() {
  State st; l_init(st);
  LSTEP(l_push(st,1)); LSTEP(l_push(st,2)); LSTEP(l_push(st,3));
  LSTEP(l_step(st,0x7b)); LSTEP(l_push(st,1)); LSTEP(l_step(st,0x87));
  return l_finish(st);
}
extern "C" uint64_t cell_roundtrip() {
  State st; l_init(st);
  LSTEP(l_push(st,1)); LSTEP(l_push(st,2));
  LSTEP(l_step(st,0x6b)); LSTEP(l_step(st,0x6c));
  LSTEP(l_push(st,2)); LSTEP(l_step(st,0x87));
  return l_finish(st);
}
extern "C" uint64_t cell_depth_count() {
  State st; l_init(st);
  LSTEP(l_push(st,1)); LSTEP(l_push(st,1)); LSTEP(l_step(st,0x74));
  LSTEP(l_push(st,2)); LSTEP(l_step(st,0x87));
  return l_finish(st);
}
extern "C" uint64_t cell_pick_depth() {
  State st; l_init(st);
  LSTEP(l_push(st,1)); LSTEP(l_push(st,2)); LSTEP(l_push(st,3));
  LSTEP(l_push(st,2)); LSTEP(l_step(st,0x79));
  LSTEP(l_push(st,1)); LSTEP(l_step(st,0x87));
  return l_finish(st);
}

// Broader C-L concrete edge functions (closed witnesses).
extern "C" uint64_t cell_verify_true() {
  State st; l_init(st);
  LSTEP(l_push(st,1)); LSTEP(l_step(st,0x69)); LSTEP(l_push(st,1));
  return l_finish(st);
}
extern "C" uint64_t cell_verify_false() {
  State st; l_init(st);
  LSTEP(l_push_empty(st)); LSTEP(l_step(st,0x69));
  return l_finish(st);
}
extern "C" uint64_t cell_verify_empty() {
  State st; l_init(st);
  LSTEP(l_step(st,0x69));
  return l_finish(st);
}
extern "C" uint64_t cell_dup_underflow() {
  State st; l_init(st);
  LSTEP(l_step(st,0x76));
  return l_finish(st);
}
extern "C" uint64_t cell_swap_underflow() {
  State st; l_init(st);
  LSTEP(l_step(st,0x7c));
  return l_finish(st);
}
extern "C" uint64_t cell_drop_underflow() {
  State st; l_init(st);
  LSTEP(l_step(st,0x75));
  return l_finish(st);
}
extern "C" uint64_t cell_alt_from_empty() {
  State st; l_init(st);
  LSTEP(l_step(st,0x6c));
  return l_finish(st);
}
extern "C" uint64_t cell_alt_to_empty() {
  State st; l_init(st);
  LSTEP(l_step(st,0x6b));
  return l_finish(st);
}
extern "C" uint64_t cell_alt_roundtrip() {
  State st; l_init(st);
  LSTEP(l_push(st,1)); LSTEP(l_push(st,2));
  LSTEP(l_step(st,0x6b)); LSTEP(l_step(st,0x6c));
  return l_finish(st);
}

extern "C" uint64_t cell_dup_drop_swap_ok() {
  State st; l_init(st);
  LSTEP(l_push(st,1)); LSTEP(l_push(st,2));
  LSTEP(l_step(st,0x76)); LSTEP(l_step(st,0x7c));
  LSTEP(l_push(st,2)); LSTEP(l_step(st,0x87)); LSTEP(l_step(st,0x75));
  return l_finish(st);
}
