#include "w32_twin.h"
using namespace twinleaf;
// L leg: reviewed transliteration of the Lean interpreter definitions, not a
// twin/ops_ir.py handler (the twin has no tapscript OP_SUCCESS pre-scan and
// its disabled_wire is applied under every sigversion).  The cell therefore
// leaves src/ops.txt empty; the transliterated sources are:
//
//   Bitcoin/Interpreter/Defs.lean:455-462  disabledWire
//   Bitcoin/Interpreter/Defs.lean:463-476  isOpSuccessWire
//   Bitcoin/Interpreter/Defs.lean:479-492  opSuccessScanFrom / opSuccessScan
//   Bitcoin/Interpreter/Defs.lean:815-845  stepBody, check (3): disabled
//                                          opcodes are rejected before fExec
//   Bitcoin/Interpreter/Defs.lean:1211-1216 executeWitnessScript tapscript
//                                          pre-scan: OP_SUCCESS overrides
//                                          everything, then
//                                          DISCOURAGE_OP_SUCCESS
//   Bitcoin/Script/Parser/Defs.lean:206-229 getOpAux / getOp
//
// The transliteration is bounded to the two-byte tapscript slice below and
// is loop-free (every step advances at least one byte), so Alive2 can execute
// it symbolically.  The packed observable is the shared w32 one; it is the
// pre-scan outcome only, so "no OP_SUCCESS found" is the harness sentinel
// result=3, error=1 instead of a claimed EvalScript outcome.

// Defs.lean:455-462  disabledWire.
static __attribute__((always_inline)) bool l_disabled_wire(uint32_t w) {
  return w == 0x7e || w == 0x7f || w == 0x80 || w == 0x81 ||
         w == 0x83 || w == 0x84 || w == 0x85 || w == 0x86 ||
         w == 0x8d || w == 0x8e || w == 0x95 || w == 0x96 ||
         w == 0x97 || w == 0x98 || w == 0x99;
}

// Defs.lean:463-476  isOpSuccessWire.
static __attribute__((always_inline)) bool l_is_op_success_wire(uint8_t w) {
  return w == 80 || w == 98 || (126 <= w && w <= 129) ||
         (131 <= w && w <= 134) || (137 <= w && w <= 138) ||
         (141 <= w && w <= 142) || (149 <= w && w <= 153) ||
         (187 <= w && w <= 254);
}

// Defs.lean:815-845  stepBody's check (3): disabledWire w is tested before
// fExec is computed, so the result does not depend on the executed state.
static TwinErr l_step_body_disabled(uint32_t w) {
  if (l_disabled_wire(w)) return TWIN_DISABLED_OPCODE;
  return TWIN_INVALID_UNSUPPORTED;   // no other behaviour is modelled here
}

// Parser/Defs.lean:206-229  getOpAux / getOp for a two-byte buffer.
struct LGetOp {
  bool ok;
  uint32_t wire;
  uint32_t next;
};

static LGetOp l_get_op(const uint8_t* b, uint32_t len, uint32_t i) {
  if (i >= len) return {false, 0, 0};          // getOpt -> none
  const uint32_t c = b[i];
  if (c == 0) return {true, c, i + 1};         // pushBytes empty
  if (c <= 0x4b) {                             // direct push
    if (c > len - i - 1) return {false, 0, 0}; // sliceOpt -> none
    return {true, c, i + 1 + c};
  }
  if (c == 0x4c) {                             // PUSHDATA1
    if (i + 1 >= len) return {false, 0, 0};    // readLE -> none
    const uint32_t k = b[i + 1];
    if (k > len - i - 2) return {false, 0, 0};
    return {true, c, i + 2 + k};
  }
  if (c == 0x4d) {                             // PUSHDATA2
    if (i + 2 >= len) return {false, 0, 0};
    const uint32_t k = b[i + 1] | (b[i + 2] << 8);
    if (k > len - i - 3) return {false, 0, 0};
    return {true, c, i + 3 + k};
  }
  if (c == 0x4e) {                             // PUSHDATA4
    if (i + 4 >= len) return {false, 0, 0};
    const uint32_t k = b[i + 1] | (b[i + 2] << 8) | (b[i + 3] << 16) |
                       ((uint32_t)b[i + 4] << 24);
    if (k > len - i - 5) return {false, 0, 0};
    return {true, c, i + 5 + k};
  }
  return {true, c, i + 1};                     // pushNum / op
}

// opSuccessScanFrom tests only `.op` payloads (Defs.lean:487).  Wire 0x50 is
// Opcode.op (OP_RESERVED); 0x4f and 0x51..0x60 are pushNum and are skipped.
static __attribute__((always_inline)) bool l_is_op_payload(uint8_t c) {
  return c == 0x50 || c >= 0x61;
}

// Defs.lean:479-492  opSuccessScan over a two-byte script.  Two unrolled
// steps suffice: each successful getOp advances at least one byte.
static bool l_op_success_scan2(const uint8_t* b, uint32_t len) {
  uint32_t i = 0;
  const LGetOp d0 = l_get_op(b, len, i);
  if (!d0.ok) return false;                    // getOp none -> false
  if (l_is_op_payload(d0.wire) && l_is_op_success_wire(d0.wire)) return true;
  i = d0.next;
  if (i >= len) return false;
  const LGetOp d1 = l_get_op(b, len, i);
  if (!d1.ok) return false;
  return l_is_op_payload(d1.wire) && l_is_op_success_wire(d1.wire);
}

extern "C" uint64_t cell_base(uint8_t fexec) {
  (void)fexec;                                 // check precedes the fExec branch
  State st{};
  l_init(st);
  const TwinErr e = l_step_body_disabled(0x8e);
  if (e == TWIN_INVALID_UNSUPPORTED) return l_unsupported(st);
  return l_fail(st, e);
}

extern "C" uint64_t cell_witness_v0(uint8_t fexec) {
  (void)fexec;
  State st{};
  l_init(st);
  const TwinErr e = l_step_body_disabled(0x8e);
  if (e == TWIN_INVALID_UNSUPPORTED) return l_unsupported(st);
  return l_fail(st, e);
}

// Defs.lean:1211-1216  executeWitnessScript tapscript branch.  On a found
// OP_SUCCESS: discourage => .fail .discourageOpSuccess, else .ok; the
// initial stack is irrelevant (the scan runs first).
extern "C" uint64_t cell_tapscript(uint8_t b0, uint8_t b1, uint8_t discourage) {
  const uint8_t script[2] = {b0, b1};
  State st{};
  l_init(st);
  const bool found = l_op_success_scan2(script, 2);
  if (!found) return l_unsupported(st);
  if (discourage != 0) return l_fail(st, TWIN_DISCOURAGE_OP_SUCCESS);
  W32 s;
  l_to_w32(st, s);
  return w32_pack(1, 0, s);                    // .ok
}
