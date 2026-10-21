#include "num_common.h"
#include "twin_ops.h"

// L leg: the OP_EQUAL / OP_EQUALVERIFY handler is copied verbatim from
// twin/ops_ir.py by the cell generator (build/twin_ops.h), with every handler
// body asserted byte-identical to cells/_tools/mk_leaf.py output.  The
// bounded runtime primitives (st_push / bounded_memcmp) are the
// twin/runtime.inc bodies unrolled to an 8-byte element -- see
// findings/wave16/07-numeric-ops/tools/mk_num_leaf.py.
//
// The handler dispatches on d.wire (0x87 = OP_EQUAL, 0x88 = OP_EQUALVERIFY);
// the init/push/finish code below is cell harness, not engine code: it builds
// the leaf's entry stack and applies the VerifyScript tail that
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

BINLINE uint64_t l_equal(uint32_t wire, uint64_t wa, uint32_t la,
                         uint64_t wb, uint32_t lb) {
  State st{};
  Ctx ctx{};
  Decoded d{};
  uint8_t b[NUM_MAX_ELEM];
  num_load8(b, wa);
  TwinErr e = st_push(st.stack, b, num_len8(la));
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  num_load8(b, wb);
  e = st_push(st.stack, b, num_len8(lb));
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  d.kind = Kind::Op;
  d.data = nullptr;
  d.dlen = 0;
  d.wire = wire;
  d.next = 2;
  e = op_OP_EQUAL(st, ctx, d);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  return l_tail(st);
}

}  // namespace

extern "C" uint64_t cell_equal(uint64_t wa, uint32_t la, uint64_t wb,
                               uint32_t lb) {
  return l_equal(0x87, wa, la, wb, lb);
}

extern "C" uint64_t cell_equalverify(uint64_t wa, uint32_t la, uint64_t wb,
                                     uint32_t lb) {
  return l_equal(0x88, wa, la, wb, lb);
}
