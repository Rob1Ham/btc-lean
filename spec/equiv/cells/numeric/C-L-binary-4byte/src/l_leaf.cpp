#include "num_common.h"
#include "twin_ops.h"

// L leg: the thirteen binary numeric handlers are copied verbatim from
// twin/ops_ir.py by the cell generator (build/twin_ops.h); every handler body
// is asserted byte-identical to cells/_tools/mk_leaf.py output.  The bounded
// runtime primitives (decode_num/encode_num/cast_to_bool/memcpy/memcmp) are
// the twin/runtime.inc bodies unrolled to an 8-byte element -- see
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

BINLINE uint64_t l_binary(uint32_t wire, uint32_t wa, uint32_t la,
                          uint32_t wb, uint32_t lb) {
  State st{};
  Ctx ctx{};
  Decoded d{};
  TwinErr e = l_push_pair(st, wa, la & 7u);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  e = l_push_pair(st, wb, lb & 7u);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  d.kind = Kind::Op;
  d.data = nullptr;
  d.dlen = 0;
  d.wire = wire;
  d.next = 1;
  switch (wire) {
    case 0x93: e = op_OP_ADD(st, ctx, d); break;
    case 0x94: e = op_OP_SUB(st, ctx, d); break;
    case 0x9a: e = op_OP_BOOLAND(st, ctx, d); break;
    case 0x9b: e = op_OP_BOOLOR(st, ctx, d); break;
    case 0x9c: e = op_OP_NUMEQUAL(st, ctx, d); break;
    case 0x9d: e = op_OP_NUMEQUALVERIFY(st, ctx, d); break;
    case 0x9e: e = op_OP_NUMNOTEQUAL(st, ctx, d); break;
    case 0x9f: e = op_OP_LESSTHAN(st, ctx, d); break;
    case 0xa0: e = op_OP_GREATERTHAN(st, ctx, d); break;
    case 0xa1: e = op_OP_LESSTHANOREQUAL(st, ctx, d); break;
    case 0xa2: e = op_OP_GREATERTHANOREQUAL(st, ctx, d); break;
    case 0xa3: e = op_OP_MIN(st, ctx, d); break;
    default:   e = op_OP_MAX(st, ctx, d); break;
  }
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  return l_tail(st);
}

}  // namespace

extern "C" uint64_t cell_add(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0x93, wa, la, wb, lb); }
extern "C" uint64_t cell_sub(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0x94, wa, la, wb, lb); }
extern "C" uint64_t cell_booland(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0x9a, wa, la, wb, lb); }
extern "C" uint64_t cell_boolor(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0x9b, wa, la, wb, lb); }
extern "C" uint64_t cell_numequal(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0x9c, wa, la, wb, lb); }
extern "C" uint64_t cell_numequalverify(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0x9d, wa, la, wb, lb); }
extern "C" uint64_t cell_numnotequal(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0x9e, wa, la, wb, lb); }
extern "C" uint64_t cell_lessthan(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0x9f, wa, la, wb, lb); }
extern "C" uint64_t cell_greaterthan(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0xa0, wa, la, wb, lb); }
extern "C" uint64_t cell_lessthanorequal(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0xa1, wa, la, wb, lb); }
extern "C" uint64_t cell_greaterthanorequal(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0xa2, wa, la, wb, lb); }
extern "C" uint64_t cell_min(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0xa3, wa, la, wb, lb); }
extern "C" uint64_t cell_max(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb)
  { return l_binary(0xa4, wa, la, wb, lb); }
