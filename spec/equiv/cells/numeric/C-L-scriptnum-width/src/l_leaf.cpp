#include "num_common.h"
#include "twin_ops.h"

// L leg: the twin (Lean-derived) imperative IR from spec/equiv/twin.
//
//   decode_num          -- twin/runtime.inc:167-193, the CScriptNum ctor
//                          (script.h:246-271): `len > maxSize` ->
//                          TWIN_SCRIPTNUM, which core_ord maps to Core
//                          ordinal 4 (SCRIPT_ERR_SCRIPTNUM).  This is the
//                          body mk_num_leaf.py re-binds to an 8-byte element.
//   st_push_num         -- twin/runtime.inc:160-164 encode_num + st_push
//                          (script.h:342-373 serialize, the bn.getvch() push).
//   op_OP_1ADD          -- verbatim from twin/ops_ir.py (Defs.lean:1003-1007),
//                          the first opcode that consumes the constructor.
//
// The init/push/finish/pack code is cell harness, not engine code: it builds
// the entry stack and applies the VerifyScript tail that
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

BINLINE uint64_t l_num(uint64_t word, uint32_t len) {
  uint8_t d[NUM_MAX_ELEM];
  num_load8(d, word);
  const uint32_t L = num_len8(len);          // same harness projection as C
  int64_t bn = 0;
  TwinErr e = decode_num(d, L, /*minimal=*/false, 4, bn);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  State st{};
  e = st_push_num(st.stack, bn);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  return l_tail(st);
}

BINLINE uint64_t l_1add(uint64_t word, uint32_t len) {
  State st{};
  uint8_t d[NUM_MAX_ELEM];
  num_load8(d, word);
  TwinErr e = st_push(st.stack, d, num_len8(len));
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  Ctx ctx{};
  Decoded dd{};
  dd.kind = Kind::Op;
  dd.data = nullptr;
  dd.dlen = 0;
  dd.wire = 0x8b;                            // OP_1ADD
  dd.next = 1;
  e = op_OP_1ADD(st, ctx, dd);
  if (e != TWIN_OK) return num_obs_err(static_cast<uint32_t>(core_ord(e)));
  return l_tail(st);
}

}  // namespace

extern "C" uint64_t cell_scriptnum(uint64_t word, uint32_t len)
  { return l_num(word, len); }

extern "C" uint64_t cell_1add(uint64_t word, uint32_t len)
  { return l_1add(word, len); }
