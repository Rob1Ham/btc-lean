#include "twin_ops.h"
#include "twin_extras.h"
#include "leaf_common.h"
#include "obs.h"

using namespace twinleaf;

// L leg — the twin's OP_DEPTH / OP_SIZE handlers, generated VERBATIM into
// build/twin_ops.h by cells/_tools/mk_leaf.py from twin/ops_ir.py, inside a
// mirror of twin/runtime.inc:594-652:
//   :610-616  opcode budget (BASE/WITNESS_V0, wire > 0x60)
//   :619      fExec = vf_all(st)
//   :647-650  dispatch only if fExec
//   :643-644  terminal STACK_SIZE guard
// Both entries are executed (fExec = 1), so no condition-stack frame is seeded.
// DEPTH's wire is 0x74 and SIZE's is 0x82; both are above OP_16.

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

BINLINE uint64_t l_depth(uint8_t d, uint8_t e0, uint8_t e1, uint8_t e2,
                         uint8_t opCount, uint8_t sv) {
  Ctx ctx{};
  ctx.sv = (sv == 0) ? SigVersion::Base
                     : (sv == 1) ? SigVersion::WitnessV0 : SigVersion::Tapscript;
  State st{}; l_init(st);
  st.opCount = opCount;
  if (d > 0) { TwinErr e = st_push(st.stack, &e0, 1); if (e != TWIN_OK) return pack_err(e); }
  if (d > 1) { TwinErr e = st_push(st.stack, &e1, 1); if (e != TWIN_OK) return pack_err(e); }
  if (d > 2) { TwinErr e = st_push(st.stack, &e2, 1); if (e != TWIN_OK) return pack_err(e); }

  if ((ctx.sv == SigVersion::Base || ctx.sv == SigVersion::WitnessV0) && 0x74 > 0x60) {
    st.opCount += 1;
    if (st.opCount > 201) return pack_err(TWIN_OP_COUNT);
  }
  if (vf_all(st)) {
    Decoded dd{};
    dd.wire = 0x74; dd.kind = Kind::Op; dd.data = nullptr; dd.dlen = 0; dd.next = 1;
    const TwinErr e = op_OP_DEPTH(st, ctx, dd);
    if (e != TWIN_OK) return pack_err(e);
  }
  if (st.stack.n + st.alt.n > MAX_STACK_SIZE) return pack_err(TWIN_STACK_SIZE);
  LStack m; ls_of(st.stack, m);
  return pack_dcount(1u, m);
}

// Mirror of the C seed: one element of exactly `len` bytes, first byte e0,
// remaining bytes already zeroed by l_init.
BINLINE void l_seed_len(State& st, uint32_t len, uint8_t e0) {
  st.stack.n = 1;
  st.stack.len[0] = len;
  if (len > 0) st.stack.e[0][0] = e0;
}

BINLINE uint64_t l_size(uint32_t len, uint8_t e0, uint8_t opCount,
                        uint8_t sv) {
  Ctx ctx{};
  ctx.sv = (sv == 0) ? SigVersion::Base
                     : (sv == 1) ? SigVersion::WitnessV0 : SigVersion::Tapscript;
  State st{}; l_init(st);
  st.opCount = opCount;
  l_seed_len(st, len, e0);

  if ((ctx.sv == SigVersion::Base || ctx.sv == SigVersion::WitnessV0) && 0x82 > 0x60) {
    st.opCount += 1;
    if (st.opCount > 201) return pack_err(TWIN_OP_COUNT);
  }
  if (vf_all(st)) {
    Decoded dd{};
    dd.wire = 0x82; dd.kind = Kind::Op; dd.data = nullptr; dd.dlen = 0; dd.next = 1;
    const TwinErr e = op_OP_SIZE(st, ctx, dd);
    if (e != TWIN_OK) return pack_err(e);
  }
  if (st.stack.n + st.alt.n > MAX_STACK_SIZE) return pack_err(TWIN_STACK_SIZE);
  LStack m; ls_of(st.stack, m);
  return pack_size(1u, m);
}

BINLINE uint64_t l_size_empty(uint8_t opCount, uint8_t sv) {
  Ctx ctx{};
  ctx.sv = (sv == 0) ? SigVersion::Base
                     : (sv == 1) ? SigVersion::WitnessV0 : SigVersion::Tapscript;
  State st{}; l_init(st);
  st.opCount = opCount;

  if ((ctx.sv == SigVersion::Base || ctx.sv == SigVersion::WitnessV0) && 0x82 > 0x60) {
    st.opCount += 1;
    if (st.opCount > 201) return pack_err(TWIN_OP_COUNT);
  }
  if (vf_all(st)) {
    Decoded dd{};
    dd.wire = 0x82; dd.kind = Kind::Op; dd.data = nullptr; dd.dlen = 0; dd.next = 1;
    const TwinErr e = op_OP_SIZE(st, ctx, dd);
    if (e != TWIN_OK) return pack_err(e);
  }
  if (st.stack.n + st.alt.n > MAX_STACK_SIZE) return pack_err(TWIN_STACK_SIZE);
  LStack m; ls_of(st.stack, m);
  return pack_size(1u, m);
}

extern "C" uint64_t cell_depth_d0(uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_depth(0, 0, 0, 0, opc, sv);
}
extern "C" uint64_t cell_depth_d1(uint8_t e0, uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_depth(1, e0, 0, 0, opc, sv);
}
extern "C" uint64_t cell_depth_d2(uint8_t e0, uint8_t e1, uint8_t opc,
                                  uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_depth(2, e0, e1, 0, opc, sv);
}
extern "C" uint64_t cell_depth_d3(uint8_t e0, uint8_t e1, uint8_t e2,
                                  uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_depth(3, e0, e1, e2, opc, sv);
}

#define SIZE_ARM(NAME, LEN)                                                 \
  extern "C" uint64_t NAME(uint8_t e0, uint8_t opc, uint8_t sv) {           \
    if (sv > 2) return pack_domain();                                       \
    return l_size(LEN, e0, opc, sv);                                        \
  }

SIZE_ARM(cell_size_l0, 0u)
SIZE_ARM(cell_size_l1, 1u)
SIZE_ARM(cell_size_l2, 2u)
SIZE_ARM(cell_size_l127, 127u)
SIZE_ARM(cell_size_l128, 128u)
SIZE_ARM(cell_size_l255, 255u)
SIZE_ARM(cell_size_l256, 256u)
SIZE_ARM(cell_size_l520, 520u)

extern "C" uint64_t cell_size_empty(uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_size_empty(opc, sv);
}
