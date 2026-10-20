#include "num_common.h"
#include "twin_ops.h"

// L leg: the OP_1ADD handler is copied verbatim from twin/ops_ir.py by the
// cell generator (build/twin_ops.h), with every handler body asserted
// byte-identical to cells/_tools/mk_leaf.py output.  The bounded runtime
// primitives (decode_num/encode_num/cast_to_bool/memcpy/memcmp) are the
// twin/runtime.inc bodies unrolled to an 8-byte element -- see
// findings/wave16/07-numeric-ops/tools/mk_num_leaf.py.
//
// The raw push below is the twin's st_push (the runtime.inc push path), not a
// CScriptNum decode.  It is deliberately the same primitive Core's
// stack.push_back(vchPushValue) denotes: no width guard.  Init/push/tail/pack
// is cell harness; the VerifyScript tail is what
// runtime.inc:verify_script_full performs after EvalScript
// (interpreter.cpp:1877-1878).
using namespace twinleaf;

namespace {

BINLINE uint64_t l_tail(const State& st) {
  if (st.stack.n == 0)
    return num_obs(0, static_cast<uint32_t>(core_ord(TWIN_EVAL_FALSE)), st.stack);
  const uint32_t i = st.stack.n - 1;
  const uint32_t len = st.stack.len[i];
  if (!cast_to_bool(st.stack.e[i], len))
    return num_obs(0, static_cast<uint32_t>(core_ord(TWIN_EVAL_FALSE)), st.stack);
  return num_obs(1, static_cast<uint32_t>(core_ord(TWIN_OK)), st.stack);
}

BINLINE TwinErr l_push_raw(State& st, uint64_t w, uint32_t len) {
  uint8_t b[NUM_MAX_ELEM];
  num_load8(b, w);
  return st_push(st.stack, b, len);
}

BINLINE TwinErr l_step_1add(State& st) {
  Ctx ctx{};
  Decoded d{};
  d.kind = Kind::Op;
  d.data = nullptr;
  d.dlen = 0;
  d.wire = 0x8b;   // OP_1ADD
  d.next = 1;
  return op_OP_1ADD(st, ctx, d);
}

}  // namespace

extern "C" uint64_t cell_push_raw(uint64_t w, uint32_t l) {
  State st{};
  const TwinErr e = l_push_raw(st, w, num_len8(l));
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  return l_tail(st);
}

extern "C" uint64_t cell_reinterpret(uint64_t w, uint32_t l) {
  State st{};
  TwinErr e = l_push_raw(st, w, num_len8(l));
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  e = l_step_1add(st);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  return l_tail(st);
}

extern "C" uint64_t cell_add4_observe(uint64_t w) {
  State st{};
  TwinErr e = l_push_raw(st, w, 4);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  e = l_step_1add(st);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  return l_tail(st);
}

extern "C" uint64_t cell_add4_readd(uint64_t w) {
  State st{};
  TwinErr e = l_push_raw(st, w, 4);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  e = l_step_1add(st);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  e = l_step_1add(st);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  return l_tail(st);
}
