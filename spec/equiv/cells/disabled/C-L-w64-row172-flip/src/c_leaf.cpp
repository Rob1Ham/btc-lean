// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
// BASE/WITNESS_V0 disabled arm, src/script/interpreter.cpp:467-482 (inside
// EvalScript's loop after GetOp, the op-count arm and the push-size arm):
//
//   if (opcode == OP_CAT || opcode == OP_SUBSTR || ... ||
//       opcode == OP_RSHIFT)
//       return set_error(serror, SCRIPT_ERR_DISABLED_OPCODE);
//
// TAPSCRIPT OP_SUCCESSx pre-scan, src/script/interpreter.cpp:1846-1862
// (ExecuteWitnessScript, before EvalScript and before the stack/item checks):
//
//   while (pc < exec_script.end()) {
//       if (!exec_script.GetOp(pc, opcode)) return BAD_OPCODE;
//       if (IsOpSuccess(opcode)) {
//           if (flags & SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS)
//               return DISCOURAGE_OP_SUCCESS;
//           return set_success(serror);
//       }
//   }
//
// and src/script/script.cpp:365-371 (IsOpSuccess).
//
// Domain: the script is exactly one byte `w` with 0x4f <= w <= 0xff. Every
// such byte is a single opcode with no push payload, so GetOp consumes one
// byte and cannot fail; OP_1NEGATE (0x4f) is included, direct pushes
// (<= 0x4b) and PUSHDATA (0x4c-0x4e) are excluded (a one-byte script ending
// inside a push payload is BAD_OPCODE, a different row/F-DIV-001 edge).
// For BASE we assume the top-level context: fExec = true and nOpCount = 0,
// so one opcode is far below MAX_OPS_PER_SCRIPT. Only the disabled arm is
// classified; reaching the switch is reported as BASE_REACHES_SWITCH (64),
// which is a cell marker, not a script verdict.
//
// Flag bit: SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS is Core's
// script_verify_flag_name ordinal 19, i.e. 1 << 19 (script/interpreter.h:
// 143-144; verify_flags.h maps the name to that bit). It is a POLICY flag:
// without it tapscript returns OK; with it the same bytes return
// SCRIPT_ERR_DISCOURAGE_OP_SUCCESS (36), which is a standardness result,
// not a consensus disabled-opcode failure.
//
// Observable codes: 0 OK, 17 DISABLED_OPCODE, 36 DISCOURAGE_OP_SUCCESS,
// 64 base reaches EvalScript's switch (marker), 66 tapscript scan completes
// and EvalScript would run (marker), 254 out of the declared domain.
#include <cstdint>

#define BINLINE static inline __attribute__((always_inline))
namespace {
constexpr uint32_t OK = 0;
constexpr uint32_t DISABLED_OPCODE = 17;         // EQUIV_ERR_DISABLED_OPCODE
constexpr uint32_t DISCOURAGE_OP_SUCCESS = 36;   // EQUIV_ERR_DISCOURAGE_OP_SUCCESS
constexpr uint32_t BASE_REACHES_SWITCH = 64;     // cell marker, not a ScriptError
constexpr uint32_t TAPSCRIPT_SCAN_COMPLETE = 66; // cell marker, not a ScriptError
constexpr uint32_t OUT_OF_DOMAIN = 254;
constexpr uint64_t DISCOURAGE_OP_SUCCESS_BIT = uint64_t{1} << 19; // interpreter.h ordinal 19

// interpreter.cpp:467-482, the fifteen CVE-2010-5137 opcodes.
BINLINE bool core_disabled(uint32_t w) {
  return w == 0x7e || w == 0x7f || w == 0x80 || w == 0x81 ||
         w == 0x83 || w == 0x84 || w == 0x85 || w == 0x86 ||
         w == 0x8d || w == 0x8e || w == 0x95 || w == 0x96 ||
         w == 0x97 || w == 0x98 || w == 0x99;
}

// script.cpp:365-371 verbatim.
BINLINE bool core_is_op_success(uint32_t w) {
  return w == 80 || w == 98 ||
         (126 <= w && w <= 129) ||
         (131 <= w && w <= 134) ||
         (137 <= w && w <= 138) ||
         (141 <= w && w <= 142) ||
         (149 <= w && w <= 153) ||
         (187 <= w && w <= 254);
}

BINLINE uint32_t core_base_outcome(uint32_t w) {
  if (w < 0x4f) return OUT_OF_DOMAIN;
  if (core_disabled(w)) return DISABLED_OPCODE;
  return BASE_REACHES_SWITCH;
}

BINLINE uint32_t core_tapscript_outcome(uint32_t w, uint64_t flags) {
  if (w < 0x4f) return OUT_OF_DOMAIN;
  if (core_is_op_success(w)) {
    return (flags & DISCOURAGE_OP_SUCCESS_BIT) ? DISCOURAGE_OP_SUCCESS : OK;
  }
  return TAPSCRIPT_SCAN_COMPLETE;
}
}  // namespace

// Packed (base << 32) | tapscript: one proof covers both sigversions for the
// same wire and flag word.
extern "C" uint64_t cell_pair(uint8_t w, uint64_t flags) {
  return (static_cast<uint64_t>(core_base_outcome(w)) << 32) |
         core_tapscript_outcome(w, flags);
}

// 1 iff the same byte is a BASE disabled error and a TAPSCRIPT success
// (OK without the policy bit, DISCOURAGE_OP_SUCCESS with it).
extern "C" uint64_t cell_flip(uint8_t w, uint64_t flags) {
  const uint32_t base = core_base_outcome(w);
  const uint32_t tap = core_tapscript_outcome(w, flags);
  const bool tap_success = (tap == OK || tap == DISCOURAGE_OP_SUCCESS);
  return (base == DISABLED_OPCODE && tap_success) ? 1u : 0u;
}
