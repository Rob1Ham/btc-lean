#include <cstdint>
#include "w32_common.h"
#include "twin_ops.h"
using namespace twinleaf;

// L leg: handler bodies verbatim from twin/ops_ir.py through mk_leaf.py
// (OP_TOALTSTACK at ops_ir.py:150-164, OP_FROMALTSTACK at 166-179).
//
// The two gates around the handler are copied verbatim from the twin's
// EvalScript (twin/runtime.inc:612-625):
//
//   // (2) 201-op budget: wire > 0x60 in BASE/WITNESS_V0 (Defs.lean:826-829)
//   if ((ctx.sv == SigVersion::Base || ctx.sv == SigVersion::WitnessV0) &&
//       d.wire > 0x60) {
//     st.opCount += 1;
//     if (st.opCount > MAX_OPS_PER_SCRIPT) return TWIN_OP_COUNT;
//   }
//   ...
//   const bool fExec = vf_all(st);
//   ...
//   if (fExec || (0x63 <= d.wire && d.wire <= 0x68)) {
//     const TwinErr e = dispatch(st, ctx, d);
//     if (e != TWIN_OK) return e;
//   }
//
// This cell is a single step, so the loop iteration/index bookkeeping is
// omitted; the two gates above are the part of EvalScript the row names.
// The bounded stack init, the direct handler call and the packing are cell
// harness.

static void w32_init(W32Stack& s, uint32_t n, uint8_t top, uint8_t base) {
  s.n = n;
  if (n > 0) s.v[0] = static_cast<uint8_t>(base + 0);
  if (n > 1) s.v[1] = static_cast<uint8_t>(base + 1);
  if (n > 2) s.v[2] = static_cast<uint8_t>(base + 2);
  if (n > 3) s.v[3] = static_cast<uint8_t>(base + 3);
  if (n > 4) s.v[4] = static_cast<uint8_t>(base + 4);
  if (n > 0) s.v[n - 1] = top;
}

static void w32_from_state(W32Stack& s, const Stack& src) {
  s.n = src.n;
  if (src.n > 0) s.v[0] = src.e[0][0];
  if (src.n > 1) s.v[1] = src.e[1][0];
  if (src.n > 2) s.v[2] = src.e[2][0];
  if (src.n > 3) s.v[3] = src.e[3][0];
  if (src.n > 4) s.v[4] = src.e[4][0];
}

extern "C" uint64_t cell_altstep(uint8_t wire, uint8_t exec, uint32_t opc,
                                 uint8_t sn, uint8_t an, uint8_t s_top,
                                 uint8_t a_top) {
  if ((wire != 0x6b && wire != 0x6c) || sn > 4 || an > 4) {
    return W32_OUT_OF_DOMAIN;
  }
  State st{};
  Ctx ctx{};
  ctx.sv = SigVersion::Base;  // flags/policy all false: not read by this row
  Decoded d{};
  d.kind = Kind::Op;
  d.data = nullptr;
  d.dlen = 0;
  d.wire = wire;
  d.next = 1;

  // Initial bounded stacks: every element one byte, 0x40+i / 0x60+i with the
  // top replaced by the symbolic byte.
  W32Stack si{};
  W32Stack ai{};
  w32_init(si, sn, s_top, 0x40);
  w32_init(ai, an, a_top, 0x60);
  st.stack.n = si.n;
  st.alt.n = ai.n;
  for (uint32_t i = 0; i < W32_MAX_DEPTH; ++i) {
    st.stack.len[i] = 1;
    st.stack.e[i][0] = si.v[i];
    st.alt.len[i] = 1;
    st.alt.e[i][0] = ai.v[i];
  }
  st.vf_n = 1;
  st.vf[0] = exec != 0;
  st.opCount = opc;

  W32Stack sf{};
  W32Stack af{};
  if (wire > 0x60) {
    st.opCount += 1;
    if (st.opCount > 201) {
      w32_from_state(sf, st.stack);
      w32_from_state(af, st.alt);
      return w32_pack_alt(0, core_ord(TWIN_OP_COUNT), sf, af);
    }
  }
  if (exec) {
    const TwinErr e = (wire == 0x6b) ? op_OP_TOALTSTACK(st, ctx, d)
                                     : op_OP_FROMALTSTACK(st, ctx, d);
    if (e != TWIN_OK) {
      w32_from_state(sf, st.stack);
      w32_from_state(af, st.alt);
      return w32_pack_alt(0, core_ord(e), sf, af);
    }
  }
  w32_from_state(sf, st.stack);
  w32_from_state(af, st.alt);
  return w32_pack_alt(1, 0, sf, af);
}
