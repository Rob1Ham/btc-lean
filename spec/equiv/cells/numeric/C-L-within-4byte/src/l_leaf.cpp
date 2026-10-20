#include "num_common.h"
#include "twin_ops.h"

// L leg: the OP_WITHIN handler is copied verbatim from twin/ops_ir.py by the
// cell generator (build/twin_ops.h); its body is asserted byte-identical to
// cells/_tools/mk_leaf.py output.  The bounded runtime primitives
// (decode_num/encode_num/cast_to_bool/memcpy/memcmp) are the twin/runtime.inc
// bodies unrolled to an 8-byte element -- see
// findings/wave16/07-numeric-ops/tools/mk_num_leaf.py.
//
// The init/push/finish/pack code below is cell harness, not engine code: it
// builds the leaf's entry stack and applies the VerifyScript tail that
// runtime.inc:verify_script_full performs after EvalScript
// (interpreter.cpp:1877-1878).
using namespace twinleaf;

namespace {

BINLINE TwinErr l_push_pair(State& st, uint32_t w, uint32_t len) {
  uint8_t b[NUM_MAX_ELEM];
  num_load(b, w);
  return st_push(st.stack, b, len);
}

BINLINE uint64_t l_tail(const State& st) {
  if (st.stack.n == 0)
    return num_obs(0, static_cast<uint32_t>(core_ord(TWIN_EVAL_FALSE)), st.stack);
  const uint32_t i = st.stack.n - 1;
  const uint32_t len = st.stack.len[i];
  if (!cast_to_bool(st.stack.e[i], len))
    return num_obs(0, static_cast<uint32_t>(core_ord(TWIN_EVAL_FALSE)), st.stack);
  return num_obs(1, static_cast<uint32_t>(core_ord(TWIN_OK)), st.stack);
}

BINLINE uint64_t l_within(uint32_t wx, uint32_t lx, uint32_t wmn, uint32_t lmn,
                          uint32_t wmx, uint32_t lmx) {
  State st{};
  Ctx ctx{};
  Decoded d{};
  TwinErr e = l_push_pair(st, wx, lx & 7u);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  e = l_push_pair(st, wmn, lmn & 7u);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  e = l_push_pair(st, wmx, lmx & 7u);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  d.kind = Kind::Op;
  d.data = nullptr;
  d.dlen = 0;
  d.wire = 0xa4 + 1;  // OP_WITHIN
  d.next = 1;
  e = op_OP_WITHIN(st, ctx, d);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  return l_tail(st);
}

}  // namespace

extern "C" uint64_t cell_within(uint32_t wx, uint32_t lx, uint32_t wmn,
                                uint32_t lmn, uint32_t wmx, uint32_t lmx)
  { return l_within(wx, lx, wmn, lmn, wmx, lmx); }
