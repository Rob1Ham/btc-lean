#include "w32_common.h"
#include "error_kind.h"

// L leg: reviewed transliteration of the verified Lean `p2shInner`
// (spec/core/Bitcoin/Interpreter/Defs.lean:1327-1353) and of the twin's
// `verify_script_full` P2SH block plus its `is_p2sh` template test
// (twin/runtime.inc:309-311, 812-841).
//
// Twin shape:
//   static bool is_p2sh(const uint8_t* b, uint32_t n) {
//     return n == 23 && b[0] == 0xa9 && b[1] == 0x14 && b[22] == 0x87;
//   }
//   ...
//   if (ctx.flags.p2sh && is_p2sh(spk, spk_len)) {
//     const PushOnly po = classify_push_only(tx.ss, tx.ss_len);
//     if (po == PushOnly::ParseFail) return TWIN_BAD_OPCODE;
//     if (po == PushOnly::NotPush) return TWIN_SIG_PUSHONLY;
//     if (st.saved.n == 0) return TWIN_UNKNOWN_ERROR;   // Core assert
//     const uint32_t rlen = st.saved.len[st.saved.n - 1];
//     const uint8_t* redeem = st.saved.e[st.saved.n - 1];
//     st.stack = st.saved;                              // restore stackCopy
//     st.stack.n -= 1;                                  // popstack
//     reset_eval(st);
//     e = eval_script(redeem, rlen, ctx, st);
//     if (e != TWIN_OK) return e;
//     if (st.stack.n == 0) return TWIN_EVAL_FALSE;
//     top = st_top(st.stack, 1, tl);
//     if (!cast_to_bool(top, tl)) return TWIN_EVAL_FALSE;
//     ...
//   }
//
// The Lean `p2shInner` restores `stackCopy`, splits it into
// `pubKeySerialized :: rest`, and evaluates `pubKeySerialized` on `rest`.
// The HASH160 preimage check is the crypto seam (symbolic `hash_match`); the
// redeem-script evaluation is the declared seam (symbolic outcome). As on the
// C leg, `pushonly_ok == 0` is the reachable NotPush case.

namespace l_w32_p2sh {

struct Stack {
  uint64_t n;
  uint64_t len;    // top element length
  uint64_t top;
};

// twin/runtime.inc:309-311, over a 23-byte script buffer whose bytes are the
// low 8 bits of the arguments.
W32INLINE bool is_p2sh(uint64_t n, const uint8_t* b) {
  return n == 23 && b[0] == 0xa9 && b[1] == 0x14 && b[22] == 0x87;
}

struct Saved {
  Stack saved;     // st.saved: the post-scriptSig stack
};

W32INLINE uint64_t verify_p2sh(uint64_t ss_err, uint64_t ss_depth,
                               uint64_t ss_top, uint64_t ss_top_len,
                               uint64_t hash_match, uint64_t pushonly_ok,
                               uint64_t redeem_err, uint64_t redeem_depth,
                               uint64_t redeem_top, uint64_t redeem_top_len) {
  if (ss_err != 0) return w32_pack(0, (uint32_t)ss_err);
  Stack stack{ss_depth, ss_top_len, ss_top};
  Saved st{stack};
  // scriptPubKey evaluation (OP_HASH160 <h> OP_EQUAL) on the same stack.
  if (stack.n < 1) return w32_pack(0, EQUIV_ERR_INVALID_STACK_OPERATION);
  if (hash_match == 0) return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  // P2SH block.
  if (pushonly_ok == 0) return w32_pack(0, EQUIV_ERR_SIG_PUSHONLY);
  if (st.saved.n == 0) return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);  // Core assert
  Stack eval_stack = st.saved;
  eval_stack.len = 0;      // st.stack.n -= 1; the top (redeem script) is split off
  eval_stack.top = 0;
  eval_stack.n -= 1;
  if (redeem_err != 0) return w32_pack(0, (uint32_t)redeem_err);
  Stack out{redeem_depth, redeem_top_len, redeem_top};
  if (out.n == 0) return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  if (!w32_cast_bool_lean(out.top, out.len)) return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  return w32_pack(1, EQUIV_ERR_OK);
}

}  // namespace l_w32_p2sh

extern "C" uint64_t cell_is_p2sh(uint64_t len, uint64_t b0, uint64_t b1, uint64_t b22) {
  uint8_t script[23] = {};
  script[0] = (uint8_t)b0;
  script[1] = (uint8_t)b1;
  script[22] = (uint8_t)b22;
  return l_w32_p2sh::is_p2sh(len, script) ? 1u : 0u;
}

extern "C" uint64_t cell_p2sh_reeval(uint64_t ss_err, uint64_t ss_depth,
                                     uint64_t ss_top, uint64_t ss_top_len,
                                     uint64_t hash_match, uint64_t pushonly_ok,
                                     uint64_t redeem_err, uint64_t redeem_depth,
                                     uint64_t redeem_top, uint64_t redeem_top_len) {
  if (ss_top_len > 8 || redeem_top_len > 8) {
    return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);   // cell encoding guard
  }
  return l_w32_p2sh::verify_p2sh(ss_err, ss_depth, ss_top, ss_top_len,
                                 hash_match, pushonly_ok, redeem_err,
                                 redeem_depth, redeem_top, redeem_top_len);
}
