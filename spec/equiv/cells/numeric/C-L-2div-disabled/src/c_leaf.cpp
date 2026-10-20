#include "num_common.h"
#include "error_kind.h"

// C leg: source-excerpt slice of Bitcoin Core
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/script/interpreter.cpp:471-489   disabled-opcode check (EvalScript)
//   src/script/script.cpp:365-371        IsOpSuccess
//   src/script/interpreter.cpp:1846-1862 ExecuteWitnessScript OP_SUCCESSx prepass
//   src/script/script.h:140-160          opcode values (OP_CAT .. OP_RSHIFT)
//
// SCR-092 is about wire 0x8e: OP_2DIV.  Two independent facts are modelled.
//
// 1. cell_gate -- the EvalScript gate.  The check at 471-489 is a plain
//    disjunction, *not* guarded by a sigversion test, so 0x8e is rejected in
//    every sigversion EvalScript runs in (BASE, WITNESS_V0, and TAPSCRIPT if
//    it were reached).  It also runs before the opcode switch, so 0x8e can
//    never reach the OP_EQUAL/OP_EQUALVERIFY block at 897-923 (where the
//    `case OP_NOTEQUAL` is commented out: there is no OP_NOTEQUAL opcode).
//
// 2. cell_tap_scan -- ExecuteWitnessScript's pre-pass over raw tapscript
//    bytes.  IsOpSuccess(0x8e) is true (OP_SUCCESS142), and the pre-pass
//    returns success before EvalScript is entered, which is why the same wire
//    succeeds in tapscript.  With DISCOURAGE_OP_SUCCESS clear (flags = 0,
//    the cell domain) the pre-pass calls set_success.

namespace {

// script.h:140-160.  Spelled out so the disjunction below reads like the
// source; the numeric values are what the excerpt actually compares.
constexpr uint32_t OP_CAT = 0x7e, OP_SUBSTR = 0x7f, OP_LEFT = 0x80,
                   OP_RIGHT = 0x81, OP_INVERT = 0x83, OP_AND = 0x84,
                   OP_OR = 0x85, OP_XOR = 0x86, OP_2MUL = 0x8d,
                   OP_2DIV = 0x8e, OP_MUL = 0x95, OP_DIV = 0x96,
                   OP_MOD = 0x97, OP_LSHIFT = 0x98, OP_RSHIFT = 0x99;

// Gate observable: result(2) | error_kind(6).  Tags: 0 terminal error,
// 1 terminal success, 2 no terminal decision at this layer.
BINLINE uint64_t gate_obs(uint32_t res, uint32_t err) {
  return static_cast<uint64_t>(res & 3u) | (static_cast<uint64_t>(err & 0x3fu) << 2);
}

// ---------- interpreter.cpp:471-489 ----------
BINLINE bool is_disabled(uint32_t opcode) {
  if (opcode == OP_CAT ||
      opcode == OP_SUBSTR ||
      opcode == OP_LEFT ||
      opcode == OP_RIGHT ||
      opcode == OP_INVERT ||
      opcode == OP_AND ||
      opcode == OP_OR ||
      opcode == OP_XOR ||
      opcode == OP_2MUL ||
      opcode == OP_2DIV ||
      opcode == OP_MUL ||
      opcode == OP_DIV ||
      opcode == OP_MOD ||
      opcode == OP_LSHIFT ||
      opcode == OP_RSHIFT)
    return true;                    // SCRIPT_ERR_DISABLED_OPCODE (CVE-2010-5137)
  return false;
}

// ---------- script.cpp:365-371 ----------
BINLINE bool is_op_success(uint32_t opcode) {
  return opcode == 80 || opcode == 98 || (opcode >= 126 && opcode <= 129) ||
         (opcode >= 131 && opcode <= 134) || (opcode >= 137 && opcode <= 138) ||
         (opcode >= 141 && opcode <= 142) || (opcode >= 149 && opcode <= 153) ||
         (opcode >= 187 && opcode <= 254);
}

}  // namespace

// EvalScript's gate for one already-decoded wire (interpreter.cpp:471-489).
// A disabled wire returns SCRIPT_ERR_DISABLED_OPCODE; anything else returns
// "no terminal decision" because the opcode itself is out of this cell.
extern "C" uint64_t cell_gate(uint32_t wire) {
  if (is_disabled(wire)) return gate_obs(0, EQUIV_ERR_DISABLED_OPCODE);
  return gate_obs(2, EQUIV_ERR_OK);
}

// ExecuteWitnessScript's OP_SUCCESSx pre-pass over a one-opcode tapscript
// (interpreter.cpp:1846-1862, DISCOURAGE_OP_SUCCESS clear).
extern "C" uint64_t cell_tap_scan(uint32_t wire) {
  if (is_op_success(wire)) return gate_obs(1, EQUIV_ERR_OK);   // set_success
  return gate_obs(2, EQUIV_ERR_OK);   // not a success wire; EvalScript runs
}
