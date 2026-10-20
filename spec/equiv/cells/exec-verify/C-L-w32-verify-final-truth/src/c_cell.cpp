#include "w32_common.h"
#include "error_kind.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Sliced statements (VerifyScript, interpreter.cpp:2012-2040):
//
//   2029-2031  if (!EvalScript(stack, scriptSig, ...)) return false;   // serror set
//   2034-2036  if (!EvalScript(stack, scriptPubKey, ...)) return false;
//   2037-2038  if (stack.empty()) return set_error(serror, SCRIPT_ERR_EVAL_FALSE);
//   2039-2040  if (CastToBool(stack.back()) == false) return set_error(..., EVAL_FALSE);
//
// The two EvalScript calls are the declared seam of this cell: their outcome
// (error ordinal, or success with a final stack) is a symbolic input of the
// model, exactly the hypotheses `hss`/`hspk` of the Lean row face
// (spec/proofs/BitcoinProofs/AF/PDW90/PDW90.lean:39-50). The final-stack
// check, which is what SCR-002 names, is transcribed verbatim.
//
// Bounded stack encoding (cell harness, see cells/_tools/w32-exec/
// w32_common.h): the post-scriptPubKey stack is `n` elements, of which only
// the top is needed by lines 2037-2040; its value is a 0..8-byte little-
// endian word. `ss_err`/`spk_err` are Core ScriptError ordinals (0 = ok).

W32INLINE uint64_t c_verify_final(uint64_t ss_err, uint64_t spk_err,
                                  uint64_t n, uint64_t top, uint64_t top_len) {
  // interpreter.cpp:2029-2031 -- EvalScript(scriptSig) failure wins first.
  if (ss_err != 0) return w32_pack(0, (uint32_t)ss_err);
  // interpreter.cpp:2034-2036 -- EvalScript(scriptPubKey) failure.
  if (spk_err != 0) return w32_pack(0, (uint32_t)spk_err);
  // interpreter.cpp:2037-2038 -- stack.empty().
  if (n == 0) return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  // interpreter.cpp:2039-2040 -- CastToBool(stack.back()).
  if (!w32_cast_bool_core(top, top_len)) return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  return w32_pack(1, EQUIV_ERR_OK);
}

extern "C" uint64_t cell_verify_final(uint64_t ss_err, uint64_t spk_err,
                                      uint64_t n, uint64_t top, uint64_t top_len) {
  // Element wider than the cell encoding: declared out-of-domain guard.
  if (top_len > 8) return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);
  return c_verify_final(ss_err, spk_err, n, top, top_len);
}
