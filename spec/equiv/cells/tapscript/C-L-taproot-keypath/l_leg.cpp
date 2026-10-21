#include "cell_common.h"
#include "checker_abi.h"

// L leg: REVIEWED TRANSLITERATION, not generated from the twin.
//
// At repo_head 805c804 the twin has no VerifyWitnessProgram handler, so this
// file restates the Verified Lean key-path arm
// (spec/core/Bitcoin/Interpreter/Defs.lean:1300):
//
//   if stack.length = 1 then
//     -- key path spend
//     schnorrOutcome (checkSchnorrWithContext chk stack[0]! program
//                       .taproot ed)
//   else
//     ... script path ...
//
// and schnorrOutcome (Defs.lean:1190-1193):
//
//   | .ok ()      => .ok
//   | .error e    => .fail e
//
// `checkSchnorrWithContext` is the Lean ScriptChecker seam; the shared
// external symbol below is that checker.  Encoding of its result is in
// checker_abi.h.  The error ordinal is passed through, not chosen here.
enum LSchnorr { L_FAIL = 0, L_OK = 1, L_SCRIPT_PATH = 2 };

TAP_INLINE uint64_t l_keypath(uint64_t stack_len, uint32_t sig_id,
                              uint32_t program_key_id) {
  if (stack_len == 1u) {
    const uint32_t r =
        btc_equiv_check_schnorr(sig_id, program_key_id, 2u /*taproot*/, 32u);
    // schnorrOutcome: .ok -> .ok; .error e -> .fail e
    if ((r & 1u) == 0u) return tap_pack(L_FAIL, (r >> 1) & 0x3fu);
    return tap_pack(L_OK, 0u);
  }
  return tap_pack(L_SCRIPT_PATH, 0u);
}

extern "C" uint64_t cell_keypath(uint64_t stack_n, uint32_t sig_id,
                                 uint32_t program_key_id) {
  return l_keypath(stack_n, sig_id, program_key_id);
}
