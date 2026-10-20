#include "w32_common.h"
// C leg: source-excerpt slices of Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// SCR-092: wire 0x8e is OP_2DIV (script.h:155-156), not a numeric opcode
// (there is no OP_NOTEQUAL).  Two execution contexts decide it:
//
//   legacy / witness-v0
//     src/script/interpreter.cpp:443-467  EvalScript prologue:
//         bool fExec = vfExec.all_true();
//         GetOp -> opcode
//         if (opcode == ... || opcode == OP_2MUL || opcode == OP_2DIV || ...)
//             return set_error(serror, SCRIPT_ERR_DISABLED_OPCODE);
//     The disabled check is before the fExec branch, so an opcode in an
//     unexecuted branch is rejected too (CVE-2010-5137 note at :467).
//     src/script/interpreter.cpp:155-157  SCRIPT_ERR_DISABLED_OPCODE = 17
//
//   tapscript
//     src/script/interpreter.cpp:1846-1862  ExecuteWitnessScript pre-scan:
//         while (pc < exec_script.end()) {
//             if (!exec_script.GetOp(pc, opcode)) return BAD_OPCODE;
//             if (IsOpSuccess(opcode)) {
//                 if (flags & SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS)
//                     return set_error(serror, SCRIPT_ERR_DISCOURAGE_OP_SUCCESS);
//                 return set_success(serror);
//             }
//         }
//     src/script/script.cpp:365-371  IsOpSuccess:
//         80 || 98 || 126..129 || 131..134 || 137..138 || 141..142 ||
//         149..153 || 187..254
//     142 = 0x8e is in 141..142, so a tapscript that decodes 0x8e as an
//     opcode succeeds before any stack check (even with an empty stack), or
//     fails with SCRIPT_ERR_DISCOURAGE_OP_SUCCESS = 36 (interpreter.cpp:70)
//     under SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS.
//
// The tapscript slice is a faithful GetOp + IsOpSuccess + pre-scan over a
// two-byte script, with constant-index decoding and no loops, so it also
// proves that the scan tests the *decoded opcode*, not raw bytes: 0x8e is
// OP_SUCCESS142 only when it is decoded as an opcode (a preceding direct
// push can consume it as data).  The cell observes the pre-scan only; when
// no OP_SUCCESS is found it returns the harness sentinel result=3, error=1
// ("remainder not modelled") rather than claiming an EvalScript outcome.

static constexpr uint32_t ERR_EVAL_FALSE = 2;
static constexpr uint32_t ERR_DISABLED_OPCODE = 17;
static constexpr uint32_t ERR_DISCOURAGE_OP_SUCCESS = 36;

// interpreter.cpp:447-467  the disabled-opcode wire list.
static __attribute__((always_inline)) bool core_is_disabled(uint32_t w) {
  return w == 0x7e || w == 0x7f || w == 0x80 || w == 0x81 ||
         w == 0x83 || w == 0x84 || w == 0x85 || w == 0x86 ||
         w == 0x8d || w == 0x8e || w == 0x95 || w == 0x96 ||
         w == 0x97 || w == 0x98 || w == 0x99;
}

// script.cpp:365-371  IsOpSuccess.
static __attribute__((always_inline)) bool core_is_op_success(uint32_t w) {
  return w == 80 || w == 98 || (126 <= w && w <= 129) ||
         (131 <= w && w <= 134) || (137 <= w && w <= 138) ||
         (141 <= w && w <= 142) || (149 <= w && w <= 153) ||
         (187 <= w && w <= 254);
}

// Legacy/witness-v0 EvalScript slice at the disabled check
// (interpreter.cpp:443-467), opcode fixed to OP_2DIV.  fExec is a real input
// because the claim is that the check does not depend on it.
extern "C" uint64_t cell_base(uint8_t fexec) {
  W32 s;
  w32_init(s);
  const bool fExec = fexec != 0;
  if (core_is_disabled(0x8e))       // OP_2DIV is in the disabled list
    return w32_pack(0, ERR_DISABLED_OPCODE, s);
  // Unreachable for 0x8e: the fExec branch comes after the disabled check.
  if (!fExec) return w32_pack(3, 1, s);
  return w32_pack(3, 1, s);
}

extern "C" uint64_t cell_witness_v0(uint8_t fexec) {
  W32 s;
  w32_init(s);
  const bool fExec = fexec != 0;
  // SigVersion::WITNESS_V0 shares the same disabled-opcode list; the check
  // is unconditional in EvalScript.
  if (core_is_disabled(0x8e))
    return w32_pack(0, ERR_DISABLED_OPCODE, s);
  if (!fExec) return w32_pack(3, 1, s);
  return w32_pack(3, 1, s);
}

// script.cpp:313-363  CScript::GetOp, loop-free for a two-byte buffer.
struct CoreGetOp {
  bool ok;
  uint32_t op;
  uint32_t next;
};

static CoreGetOp core_get_op(const uint8_t* b, uint32_t len, uint32_t i) {
  if (i >= len) return {false, 0, 0};
  const uint32_t c = b[i];
  if (c <= 0x4b) {                    // direct push of c bytes (OP_0 = empty)
    if (c > len - i - 1) return {false, 0, 0};
    return {true, c, i + 1 + c};
  }
  if (c == 0x4c) {                    // OP_PUSHDATA1
    if (i + 1 >= len) return {false, 0, 0};
    const uint32_t k = b[i + 1];
    if (k > len - i - 2) return {false, 0, 0};
    return {true, c, i + 2 + k};
  }
  if (c == 0x4d) {                    // OP_PUSHDATA2
    if (i + 2 >= len) return {false, 0, 0};
    const uint32_t k = b[i + 1] | (b[i + 2] << 8);
    if (k > len - i - 3) return {false, 0, 0};
    return {true, c, i + 3 + k};
  }
  if (c == 0x4e) {                    // OP_PUSHDATA4
    if (i + 4 >= len) return {false, 0, 0};
    const uint32_t k = b[i + 1] | (b[i + 2] << 8) | (b[i + 3] << 16) |
                       ((uint32_t)b[i + 4] << 24);
    if (k > len - i - 5) return {false, 0, 0};
    return {true, c, i + 5 + k};
  }
  return {true, c, i + 1};            // OP_1NEGATE..OP_16, all ops >= 0x61
}

// ExecuteWitnessScript's tapscript OP_SUCCESS pre-scan over a two-byte
// script.  Two unrolled steps suffice: every successful GetOp advances at
// least one byte.  Returns 1 iff an OP_SUCCESS opcode is decoded.
static bool core_op_success_scan2(const uint8_t* b, uint32_t len) {
  uint32_t i = 0;
  const CoreGetOp d0 = core_get_op(b, len, i);
  if (!d0.ok) return false;
  if (core_is_op_success(d0.op)) return true;
  i = d0.next;
  if (i >= len) return false;
  const CoreGetOp d1 = core_get_op(b, len, i);
  if (!d1.ok) return false;
  if (core_is_op_success(d1.op)) return true;
  return false;
}

// Tapscript arm: script = [b0, b1], empty initial stack.  The pre-scan runs
// before every stack-size/element-size check, so an empty stack is fine.
extern "C" uint64_t cell_tapscript(uint8_t b0, uint8_t b1, uint8_t discourage) {
  const uint8_t script[2] = {b0, b1};
  W32 s;
  w32_init(s);
  const bool found = core_op_success_scan2(script, 2);
  if (!found) return w32_pack(3, 1, s);   // no OP_SUCCESS decoded; remainder not modelled
  if (discourage != 0)
    return w32_pack(0, ERR_DISCOURAGE_OP_SUCCESS, s);
  return w32_pack(1, 0, s);               // set_success(serror)
}
