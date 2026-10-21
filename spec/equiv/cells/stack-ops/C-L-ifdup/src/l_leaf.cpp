#include "twin_ops.h"
#include "twin_extras.h"
#include "leaf_common.h"

using namespace twinleaf;

// L leg — the twin's OP_IFDUP handler, generated VERBATIM into
// build/twin_ops.h by cells/_tools/mk_leaf.py from twin/ops_ir.py, inside a
// mirror of twin/runtime.inc:594-652:
//   :610-616  opcode budget (BASE/WITNESS_V0, wire > 0x60)
//   :619      fExec = vf_all(st)
//   :647-650  dispatch only if fExec
//   :643-644  terminal STACK_SIZE guard
// OP_IFDUP's wire is 0x73 (> 0x60), so BASE/WITNESS_V0 charge one unit.

BINLINE void l_init(State& st) {
  st.stack.n = 0;
  for (uint32_t i = 0; i < MAX_STACK_SIZE; ++i) {
    st.stack.len[i] = 0;
    for (uint32_t j = 0; j < MAX_SCRIPT_ELEMENT_SIZE; ++j) st.stack.e[i][j] = 0;
  }
  st.alt.n = 0; st.saved.n = 0; st.vf_n = 0; st.opCount = 0;
  st.codeSep = 0; st.codeSepPos = 0xffffffffu; st.opcodeIndex = 0;
  st.vwLeft = 0; st.has_vw = false;
}

BINLINE uint64_t l_body(uint32_t bottoms, uint8_t e0, uint8_t e1, uint8_t v0,
                        uint32_t tl, bool has_top, uint8_t opCount, uint8_t sv) {
  Ctx ctx{};
  ctx.sv = (sv == 0) ? SigVersion::Base
                     : (sv == 1) ? SigVersion::WitnessV0 : SigVersion::Tapscript;
  State st{}; l_init(st);
  st.opCount = opCount;
  if (bottoms > 0) { TwinErr e = st_push(st.stack, &e0, 1); if (e != TWIN_OK) return pack_err(e); }
  if (bottoms > 1) { TwinErr e = st_push(st.stack, &e1, 1); if (e != TWIN_OK) return pack_err(e); }
  if (has_top) { TwinErr e = st_push(st.stack, &v0, tl); if (e != TWIN_OK) return pack_err(e); }

  if ((ctx.sv == SigVersion::Base || ctx.sv == SigVersion::WitnessV0) && 0x73 > 0x60) {
    st.opCount += 1;
    if (st.opCount > 201) return pack_err(TWIN_OP_COUNT);
  }
  if (vf_all(st)) {
    Decoded dd{};
    dd.wire = 0x73; dd.kind = Kind::Op; dd.data = nullptr; dd.dlen = 0; dd.next = 1;
    const TwinErr e = op_OP_IFDUP(st, ctx, dd);
    if (e != TWIN_OK) return pack_err(e);
  }
  if (st.stack.n + st.alt.n > MAX_STACK_SIZE) return pack_err(TWIN_STACK_SIZE);
  LStack m; ls_of(st.stack, m);
  return pack_l4(1u, m);
}

extern "C" uint64_t cell_ifdup_empty(uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_body(0, 0, 0, 0, 0, false, opc, sv);
}

// One zero-length element: the twin's cast_to_bool returns false.
extern "C" uint64_t cell_ifdup_len0(uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_body(0, 0, 0, 0, 0, true, opc, sv);
}

extern "C" uint64_t cell_ifdup_d1(uint8_t v0, uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_body(0, 0, 0, v0, 1, true, opc, sv);
}

extern "C" uint64_t cell_ifdup_d2(uint8_t e0, uint8_t e1, uint8_t v0,
                                  uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_body(2, e0, e1, v0, 1, true, opc, sv);
}
