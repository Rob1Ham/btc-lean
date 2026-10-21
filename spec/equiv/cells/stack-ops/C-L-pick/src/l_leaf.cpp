#include "twin_ops.h"
#include "twin_extras.h"
#include "leaf_common.h"

using namespace twinleaf;

// L leg — the twin's OP_PICK / OP_ROLL handler, generated VERBATIM into
// build/twin_ops.h by cells/_tools/mk_leaf.py from twin/ops_ir.py, inside a
// mirror of twin/runtime.inc:594-652:
//   :610-616  opcode budget (BASE/WITNESS_V0, wire > 0x60)
//   :619      fExec = vf_all(st)
//   :647-650  dispatch only if fExec (or the 0x63..0x68 window)
//   :643-644  terminal STACK_SIZE guard
// fExec is represented as one false condition-stack frame when unexecuted, so
// the twin's own vf_all decides.
//
// Depth is a constant per entry; the index is symbolic only for PICK.  The
// twin ROLL arm shifts a data-dependent number of slots in a loop, so its
// index is constant too.

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

BINLINE uint64_t l_body(uint8_t wire, uint8_t d, uint8_t e0, uint8_t e1,
                        uint8_t e2, uint8_t idx, uint8_t opCount, uint8_t sv,
                        bool fExec) {
  Ctx ctx{};
  ctx.sv = (sv == 0) ? SigVersion::Base
                     : (sv == 1) ? SigVersion::WitnessV0 : SigVersion::Tapscript;
  State st{}; l_init(st);
  if (!fExec) { st.vf[0] = false; st.vf_n = 1; }
  st.opCount = opCount;
  if (d > 0) { TwinErr e = st_push(st.stack, &e0, 1); if (e != TWIN_OK) return pack_err(e); }
  if (d > 1) { TwinErr e = st_push(st.stack, &e1, 1); if (e != TWIN_OK) return pack_err(e); }
  if (d > 2) { TwinErr e = st_push(st.stack, &e2, 1); if (e != TWIN_OK) return pack_err(e); }
  { TwinErr e = st_push(st.stack, &idx, 1); if (e != TWIN_OK) return pack_err(e); }

  if ((ctx.sv == SigVersion::Base || ctx.sv == SigVersion::WitnessV0) && wire > 0x60) {
    st.opCount += 1;
    if (st.opCount > 201) return pack_err(TWIN_OP_COUNT);
  }
  if (vf_all(st)) {
    Decoded dd{};
    dd.wire = wire; dd.kind = Kind::Op; dd.data = nullptr; dd.dlen = 0; dd.next = 1;
    const TwinErr e = op_OP_PICK(st, ctx, dd);
    if (e != TWIN_OK) return pack_err(e);
  }
  if (st.stack.n + st.alt.n > MAX_STACK_SIZE) return pack_err(TWIN_STACK_SIZE);
  LStack m; ls_of(st.stack, m);
  return pack_obs(1u, m);
}

// Executed, symbolic index (PICK) and constant index (ROLL, IDXB is the
// one-byte same-value encoding).
#define PICK_ARM(NAME, WIRE, D)                                              \
  extern "C" uint64_t NAME(uint8_t e0, uint8_t e1, uint8_t e2, uint8_t idx,  \
                           uint8_t opc, uint8_t sv) {                        \
    if (sv > 2) return pack_domain();                                        \
    return l_body(WIRE, D, e0, e1, e2, idx, opc, sv, true);                  \
  }

#define ROLL_ARM(NAME, WIRE, D, IDXB)                                        \
  extern "C" uint64_t NAME(uint8_t e0, uint8_t e1, uint8_t e2, uint8_t opc,  \
                           uint8_t sv) {                                     \
    if (sv > 2) return pack_domain();                                        \
    return l_body(WIRE, D, e0, e1, e2, IDXB, opc, sv, true);                 \
  }

PICK_ARM(cell_pick_d3_sym, 0x79, 3)

extern "C" uint64_t cell_pick_d1_sym(uint8_t e0, uint8_t idx, uint8_t opc,
                                     uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_body(0x79, 1, e0, 0, 0, idx, opc, sv, true);
}

extern "C" uint64_t cell_pick_d2_sym(uint8_t e0, uint8_t e1, uint8_t idx,
                                     uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_body(0x79, 2, e0, e1, 0, idx, opc, sv, true);
}

ROLL_ARM(cell_roll_d3_k0, 0x7a, 3, 0x00)
ROLL_ARM(cell_roll_d3_k1, 0x7a, 3, 0x01)
ROLL_ARM(cell_roll_d3_k2, 0x7a, 3, 0x02)

extern "C" uint64_t cell_roll_d2_k0(uint8_t e0, uint8_t e1, uint8_t opc,
                                    uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_body(0x7a, 2, e0, e1, 0, 0x00, opc, sv, true);
}

extern "C" uint64_t cell_roll_d2_k1(uint8_t e0, uint8_t e1, uint8_t opc,
                                    uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_body(0x7a, 2, e0, e1, 0, 0x01, opc, sv, true);
}

// Depth 1 has no e1/e2 inputs, so this entry has its own three-argument ABI.
extern "C" uint64_t cell_roll_d1_k0(uint8_t e0, uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_body(0x7a, 1, e0, 0, 0, 0x00, opc, sv, true);
}

extern "C" uint64_t cell_pick_d0(uint8_t idx, uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_body(0x79, 0, 0, 0, 0, idx, opc, sv, true);
}

extern "C" uint64_t cell_roll_d0(uint8_t idx, uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_body(0x7a, 0, 0, 0, 0, idx, opc, sv, true);
}

extern "C" uint64_t cell_skip(uint8_t e0, uint8_t e1, uint8_t e2, uint8_t idx,
                              uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return l_body(0x79, 3, e0, e1, e2, idx, opc, sv, false);
}
