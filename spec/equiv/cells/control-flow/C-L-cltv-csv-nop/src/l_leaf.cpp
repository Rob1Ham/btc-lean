#include "cell.h"
#include "../../../../contract/error_kind.h"

// L leg: direct transcription of the Lean model of record at
// 4d62a97e551082a69b13f495365bff0a903b0c99
// (spec/core/Bitcoin/Interpreter/Defs.lean).
//
//   stepBody (Defs.lean:817-848) bumps the op-count budget before dispatch:
//     let counts := (ctx.sv = .base \/ ctx.sv = .witnessV0) /\ 0x60 < w
//     let opCount' := if counts then st.opCount + 1 else st.opCount
//     ...
//     let st1 := { st with opCount := opCount' }
//     ... dispatchOp ctx op w fExec st1
//
//   dispatchOp (Defs.lean:857-865, wire 0xb1):
//     else if w = 0xb1 then                                   -- OP_CHECKLOCKTIMEVERIFY
//       if !flags.cltv then .ok st
//       else if st.stack.length < 1 then .error .stackUnderflow
//       else match decodeNum pol (topAt st.stack 1) 5 with ...
//   dispatchOp (Defs.lean:866-875, wire 0xb2) has the same shape with
//   `flags.csv`.
//
//   PDW73.lean:31-47 (`stepBody_cltv_csv_noflag_nop`) is the row's Lean face:
//   with both flags clear the step is `.ok { st with opCount := st.opCount + 1 }`,
//   i.e. the state is unchanged -- stack included -- and only the op-count
//   budget moves.
//
// `.stackUnderflow` reaches the ABI ordinal through twin/gen.py's ERRORS table
// (TWIN_INVALID_STACK_OPERATION, core = INVALID_STACK_OPERATION), which is
// EQUIV_ERR_INVALID_STACK_OPERATION = 18 in contract/error_kind.h.  The
// decodeNum/checkLockTimeDef continuation is the same declared boundary as on
// the C leg; it is covered by locktime/C-L-cltv-op and locktime/C-L-csv-op.
//
// The op-count bump is modelled before the dispatch decision, exactly as
// stepBody does.  On the error path both Core and Lean drop the state (Lean
// returns `.error`, which carries none), so the packed counter on that path is
// harness bookkeeping and carries no claim.

namespace lean_slice {

struct op_result {
  uint32_t code;     // CELL_CONT, CELL_BOUNDARY or a ScriptError ordinal
  uint32_t opcount;
};

// ---- Defs.lean:857-865, dispatchOp wire 0xb1 ---------------------------
BINLINE op_result lean_cltv(bool cltv_flag, uint32_t stack_length, uint32_t opCount) {
  opCount = opCount + 1;                       // st1 := { st with opCount := opCount' }
  if (!cltv_flag)
    return {CELL_CONT, opCount};               // .ok st
  if (stack_length < 1)
    return {EQUIV_ERR_INVALID_STACK_OPERATION, opCount};  // .error .stackUnderflow
  return {CELL_BOUNDARY, opCount};             // decodeNum / checkLockTimeDef
}

// ---- Defs.lean:866-875, dispatchOp wire 0xb2 ---------------------------
BINLINE op_result lean_csv(bool csv_flag, uint32_t stack_length, uint32_t opCount) {
  opCount = opCount + 1;                       // st1 := { st with opCount := opCount' }
  if (!csv_flag)
    return {CELL_CONT, opCount};               // .ok st
  if (stack_length < 1)
    return {EQUIV_ERR_INVALID_STACK_OPERATION, opCount};  // .error .stackUnderflow
  return {CELL_BOUNDARY, opCount};             // decodeNum / checkSequenceDef
}

}  // namespace lean_slice

// ---------------------------------------------------------------------------
// Cell harness (not engine text), shared shape with the C leg.
namespace {

BINLINE uint32_t h_depth(uint32_t depth_in) { return depth_in & 3u; }
BINLINE uint32_t h_opcount(uint32_t oc_in) { return oc_in > 200u ? 200u : oc_in; }

}  // namespace

extern "C" uint64_t cell_cltv_flagoff(uint32_t depth_in, uint8_t b0, uint32_t oc_in) {
  const uint32_t depth = h_depth(depth_in);
  const lean_slice::op_result r = lean_slice::lean_cltv(false, depth, h_opcount(oc_in));
  return nop_pack(r.code, depth, b0, r.opcount);
}

extern "C" uint64_t cell_csv_flagoff(uint32_t depth_in, uint8_t b0, uint32_t oc_in) {
  const uint32_t depth = h_depth(depth_in);
  const lean_slice::op_result r = lean_slice::lean_csv(false, depth, h_opcount(oc_in));
  return nop_pack(r.code, depth, b0, r.opcount);
}

extern "C" uint64_t cell_cltv_flagon(uint32_t depth_in, uint8_t b0, uint32_t oc_in) {
  const uint32_t depth = h_depth(depth_in);
  const lean_slice::op_result r = lean_slice::lean_cltv(true, depth, h_opcount(oc_in));
  return nop_pack(r.code, depth, b0, r.opcount);
}

extern "C" uint64_t cell_csv_flagon(uint32_t depth_in, uint8_t b0, uint32_t oc_in) {
  const uint32_t depth = h_depth(depth_in);
  const lean_slice::op_result r = lean_slice::lean_csv(true, depth, h_opcount(oc_in));
  return nop_pack(r.code, depth, b0, r.opcount);
}
