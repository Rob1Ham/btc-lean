#include "cell.h"
#include "../../../../contract/error_kind.h"

// C leg: source-excerpt slice of Bitcoin Core cce32b168
// (src/script/interpreter.cpp, src/script/interpreter.h, src/script/script.h).
//
// The two pre-activation NOP branches and the shared op-count bump are kept
// verbatim:
//
//   460  if (sigversion == SigVersion::BASE || sigversion == SigVersion::WITNESS_V0) {
//   461      // Note how OP_RESERVED does not count towards the opcode limit.
//   462      if (opcode > OP_16 && ++nOpCount > MAX_OPS_PER_SCRIPT) {
//   463          return set_error(serror, SCRIPT_ERR_OP_COUNT);
//   464      }
//   465  }
//
//   532  case OP_CHECKLOCKTIMEVERIFY:
//   533  {
//   534      if (!(flags & SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY)) {
//   535          // not enabled; treat as a NOP2
//   536          break;
//   537      }
//   539      if (stack.size() < 1)
//   540          return set_error(serror, SCRIPT_ERR_INVALID_STACK_OPERATION);
//
//   571  case OP_CHECKSEQUENCEVERIFY:
//   572  {
//   573      if (!(flags & SCRIPT_VERIFY_CHECKSEQUENCEVERIFY)) {
//   574          // not enabled; treat as a NOP3
//   575          break;
//   576      }
//   578      if (stack.size() < 1)
//   579          return set_error(serror, SCRIPT_ERR_INVALID_STACK_OPERATION);
//
// `break` (continue execution) is `return CELL_CONT` and set_error is the
// ScriptError ordinal.  `opcode > OP_16` is statically true for the two wires
// 0xb1/0xb2, so the first conjunct is dropped from the slice text.  The
// flag-on non-empty-stack bodies (:542-568, :581-600) need the transaction
// context (CheckLockTime/CheckSequence); they are the locktime cells' rows
// (SCR-122..129), so this slice stops at the stack guard and reports
// CELL_BOUNDARY.  The slice is base-sigversion (the row's pre-activation
// setting); line 460's witness-V0 alternative is not exercised.

namespace core_slice {

// ---- src/script/interpreter.h:102 (flag indices 9 and 10) ---------------
inline constexpr uint32_t SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY{1u << 9};
inline constexpr uint32_t SCRIPT_VERIFY_CHECKSEQUENCEVERIFY{1u << 10};

// ---- src/script/script.h:32 ---------------------------------------------
inline constexpr uint32_t MAX_OPS_PER_SCRIPT{201};

struct op_result {
  uint32_t code;     // CELL_CONT, CELL_BOUNDARY or a ScriptError ordinal
  uint32_t opcount;  // the pre-switch counter (interpreter.cpp:462)
};

// ---- interpreter.cpp:460-465 + 532-540, case OP_CHECKLOCKTIMEVERIFY ----
BINLINE op_result core_cltv(uint32_t flags, uint32_t stack_size, uint32_t nOpCount) {
  ++nOpCount;                                  // interpreter.cpp:462
  if (nOpCount > MAX_OPS_PER_SCRIPT)           // dead in the cell domain (<= 200)
    return {EQUIV_ERR_OP_COUNT, nOpCount};

  if (!(flags & SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY)) {
    // not enabled; treat as a NOP2
    return {CELL_CONT, nOpCount};              // Core: break;
  }

  if (stack_size < 1)
    return {EQUIV_ERR_INVALID_STACK_OPERATION, nOpCount};

  return {CELL_BOUNDARY, nOpCount};            // decode/compare: locktime rows
}

// ---- interpreter.cpp:460-465 + 571-579, case OP_CHECKSEQUENCEVERIFY ----
BINLINE op_result core_csv(uint32_t flags, uint32_t stack_size, uint32_t nOpCount) {
  ++nOpCount;                                  // interpreter.cpp:462
  if (nOpCount > MAX_OPS_PER_SCRIPT)           // dead in the cell domain (<= 200)
    return {EQUIV_ERR_OP_COUNT, nOpCount};

  if (!(flags & SCRIPT_VERIFY_CHECKSEQUENCEVERIFY)) {
    // not enabled; treat as a NOP3
    return {CELL_CONT, nOpCount};              // Core: break;
  }

  if (stack_size < 1)
    return {EQUIV_ERR_INVALID_STACK_OPERATION, nOpCount};

  return {CELL_BOUNDARY, nOpCount};            // decode/compare: locktime rows
}

}  // namespace core_slice

// ---------------------------------------------------------------------------
// Cell harness (not engine text): bind the bounded state, run the slice with
// the row's flag setting, and pack the observable.
namespace {

BINLINE uint32_t h_depth(uint32_t depth_in) { return depth_in & 3u; }
BINLINE uint32_t h_opcount(uint32_t oc_in) { return oc_in > 200u ? 200u : oc_in; }

}  // namespace

extern "C" uint64_t cell_cltv_flagoff(uint32_t depth_in, uint8_t b0, uint32_t oc_in) {
  const uint32_t depth = h_depth(depth_in);
  const core_slice::op_result r = core_slice::core_cltv(0u, depth, h_opcount(oc_in));
  return nop_pack(r.code, depth, b0, r.opcount);
}

extern "C" uint64_t cell_csv_flagoff(uint32_t depth_in, uint8_t b0, uint32_t oc_in) {
  const uint32_t depth = h_depth(depth_in);
  const core_slice::op_result r = core_slice::core_csv(0u, depth, h_opcount(oc_in));
  return nop_pack(r.code, depth, b0, r.opcount);
}

extern "C" uint64_t cell_cltv_flagon(uint32_t depth_in, uint8_t b0, uint32_t oc_in) {
  const uint32_t depth = h_depth(depth_in);
  const core_slice::op_result r =
      core_slice::core_cltv(core_slice::SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY, depth, h_opcount(oc_in));
  return nop_pack(r.code, depth, b0, r.opcount);
}

extern "C" uint64_t cell_csv_flagon(uint32_t depth_in, uint8_t b0, uint32_t oc_in) {
  const uint32_t depth = h_depth(depth_in);
  const core_slice::op_result r =
      core_slice::core_csv(core_slice::SCRIPT_VERIFY_CHECKSEQUENCEVERIFY, depth, h_opcount(oc_in));
  return nop_pack(r.code, depth, b0, r.opcount);
}
