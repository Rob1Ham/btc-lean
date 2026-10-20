#include "w32_common.h"
#include "error_kind.h"

// L leg: reviewed transliteration of the tail of the verified Lean
// `verifyScriptFull` (spec/core/Bitcoin/Interpreter/Defs.lean:1363-1446),
// which is also the structure of the generated twin's
// `verify_script_full` (twin/runtime.inc:784-804):
//
//   match evalScriptBytes fuel flags pol ss [] chk .base default with
//   | .error e => .fail e
//   | .ok stack1 =>
//     match evalScriptBytes fuel flags pol spk stack1 chk .base default with
//     | .error e => .fail e
//     | .ok stack =>
//       if stack = [] ∨ !castToBool stack[0]! then .fail .evalFalse
//       else ... (witness / P2SH / cleanstack tails: not reached here)
//
// `stack = []` is `state.stack.n = 0`; `stack[0]!` is the Lean top
// (head of the list), carried here by `top`/`top_len`. `!castToBool` is the
// Lean `castToBool` (Numeric/Interface.lean:64), whose reversed-list shape
// differs from Core's loop; w32_cast_bool_lean is that shape.
//
// This leg deliberately keeps the Lean list shape (a two-field `LStack`
// record and the `n == 0 ∨ !castToBool` disjunction) rather than copying the
// C text, so Alive2 has to reconcile two different programs and two
// different CastToBool implementations.

namespace l_w32_final {

struct LStack {
  uint64_t n;        // stack.length
  uint64_t top;      // stack[0]! as a 0..8-byte little-endian word
  uint64_t top_len;
};

W32INLINE uint64_t l_verify_final(uint64_t ss_err, uint64_t spk_err,
                                  uint64_t n, uint64_t top, uint64_t top_len) {
  if (ss_err != 0) return w32_pack(0, (uint32_t)ss_err);   // .error e => .fail e
  if (spk_err != 0) return w32_pack(0, (uint32_t)spk_err);
  const LStack stack{n, top, top_len};
  if (stack.n == 0 || !w32_cast_bool_lean(stack.top, stack.top_len)) {
    return w32_pack(0, EQUIV_ERR_EVAL_FALSE);             // .fail .evalFalse
  }
  return w32_pack(1, EQUIV_ERR_OK);
}

}  // namespace l_w32_final

extern "C" uint64_t cell_verify_final(uint64_t ss_err, uint64_t spk_err,
                                      uint64_t n, uint64_t top, uint64_t top_len) {
  if (top_len > 8) return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);
  return l_w32_final::l_verify_final(ss_err, spk_err, n, top, top_len);
}
