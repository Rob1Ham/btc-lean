// C leg: line-cited slice of Bitcoin Core cce32b16874e8
// src/script/interpreter.cpp, the EvalScript opcode counter:
//
//   444-446  uint32_t opcode_pos = 0;
//            execdata.m_codeseparator_pos = 0xFFFFFFFFUL;
//            ... for (; pc < pend; ++opcode_pos) {
//   1060-1066  case OP_CODESEPARATOR:
//                pbegincodehash = pc;
//                execdata.m_codeseparator_pos = opcode_pos;
//
// A bounded (4-opcode) unrolling.  The stream is *pre-decoded*: for each
// step, `kind` 0 = push of `len` payload bytes (pc advances 1+len, but
// opcode_pos advances by exactly 1), kind 1 = a one-byte opcode.
// `exec` is the caller-supplied fExec value at that opcode.  Parsing
// (GetScriptOp) and the vfExec computation are premises, not modelled.
#include <cstdint>

static constexpr uint32_t OP_CODESEPARATOR = 0xab;
static constexpr uint32_t INIT = 0xFFFFFFFFu;  // interpreter.cpp:445

extern "C" uint64_t cell_codesep_walk(
    uint32_t pend,
    uint32_t k0, uint32_t w0, uint32_t l0, uint32_t e0,
    uint32_t k1, uint32_t w1, uint32_t l1, uint32_t e1,
    uint32_t k2, uint32_t w2, uint32_t l2, uint32_t e2,
    uint32_t k3, uint32_t w3, uint32_t l3, uint32_t e3) {
  uint32_t codeSepPos = INIT;  // interpreter.cpp:445
  uint32_t pc = 0;
  uint32_t opcode_pos = 0;     // interpreter.cpp:444
#define C_STEP(k, w, l, e)                                    \
  if (pc < pend) {                                            \
    if ((e) != 0 && (k) == 1 && (w) == OP_CODESEPARATOR) {     \
      codeSepPos = opcode_pos;  /* interpreter.cpp:1065 */    \
    }                                                         \
    pc += ((k) == 0) ? (1u + (l)) : 1u;                       \
    opcode_pos += 1;            /* interpreter.cpp:446 */     \
  }
  C_STEP(k0, w0, l0, e0)
  C_STEP(k1, w1, l1, e1)
  C_STEP(k2, w2, l2, e2)
  C_STEP(k3, w3, l3, e3)
#undef C_STEP
  return (uint64_t)codeSepPos | ((uint64_t)opcode_pos << 32);
}
