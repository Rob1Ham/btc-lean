#include "w32_common.h"
#include "error_kind.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Slice: VerifyScript's sequential evaluation (interpreter.cpp:2026-2040)
// with a one-opcode scriptPubKey, OP_DUP (0x76), taken from the real
// EvalScript case at interpreter.cpp:804-811 and the loop's size check at
// interpreter.cpp:1231-1233.
//
//   2026-2028  // scriptSig and scriptPubKey must be evaluated sequentially
//              // on the same stack rather than being simply concatenated
//              // (see CVE-2010-5141)
//   2029-2031  if (!EvalScript(stack, scriptSig, ...)) return false;
//   2032-2033  if (flags & SCRIPT_VERIFY_P2SH) stackCopy = stack;
//   2034-2036  if (!EvalScript(stack, scriptPubKey, ...)) return false;
//   2037-2040  empty/false top -> SCRIPT_ERR_EVAL_FALSE
//
// The scriptSig EvalScript outcome is the declared seam (as in the Lean row
// face `verifyScriptFull_sequential`, PDW90.lean:39-50). The scriptPubKey
// evaluation is *not* abstracted away: it is the OP_DUP handler applied to
// the post-scriptSig stack, so the proof is about the same stack being
// carried from the first evaluation into the second.
//
// Bounded encoding: the stack is `n` elements; only the top is carried
// (0..8-byte little-endian word). DUP duplicates the top, so the top value
// and length are unchanged. MAX_STACK_SIZE is Core's 1000.

W32INLINE int32_t c_op_dup(uint64_t& n) {
  // interpreter.cpp:804-811
  // case OP_DUP: if (stack.size() < 1) return SCRIPT_ERR_INVALID_STACK_OPERATION;
  //              valtype vch = stacktop(-1); stack.push_back(vch);
  if (n < 1) return EQUIV_ERR_INVALID_STACK_OPERATION;
  n += 1;
  // interpreter.cpp:1231-1233  // Size limits
  if (n > 1000) return EQUIV_ERR_STACK_SIZE;
  return EQUIV_ERR_OK;
}

W32INLINE uint64_t c_verify_sequential(uint64_t ss_err, uint64_t ss_depth,
                                       uint64_t ss_top, uint64_t ss_top_len) {
  // interpreter.cpp:2029-2031 -- EvalScript(scriptSig)
  if (ss_err != 0) return w32_pack(0, (uint32_t)ss_err);
  // Post-scriptSig stack: depth ss_depth, top (ss_top, ss_top_len).
  uint64_t stack_n = ss_depth;
  const uint64_t stack_top = ss_top;          // stackCopy save is P2SH-only
  const uint64_t stack_top_len = ss_top_len;
  // interpreter.cpp:2034-2036 -- EvalScript(scriptPubKey = OP_DUP) on the
  // SAME stack (not a fresh one, not a concatenated parse).
  const int32_t e = c_op_dup(stack_n);
  if (e != EQUIV_ERR_OK) return w32_pack(0, (uint32_t)e);
  // interpreter.cpp:2037-2040
  if (stack_n == 0) return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  if (!w32_cast_bool_core(stack_top, stack_top_len)) {
    return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  }
  return w32_pack(1, EQUIV_ERR_OK);
}

extern "C" uint64_t cell_verify_sequential(uint64_t ss_err, uint64_t ss_depth,
                                           uint64_t ss_top, uint64_t ss_top_len) {
  // Out-of-domain guards: the encoding carries 8-byte elements, and a
  // post-scriptSig stack of more than MAX_STACK_SIZE (1000) elements cannot
  // be reached (the first EvalScript would already have failed with
  // SCRIPT_ERR_STACK_SIZE). Both legs return UNKNOWN outside the domain.
  if (ss_top_len > 8 || ss_depth > 1000) return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);
  return c_verify_sequential(ss_err, ss_depth, ss_top, ss_top_len);
}
