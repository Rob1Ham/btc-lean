#include "w32_common.h"
#include "error_kind.h"

// C leg: line-cited source-excerpt slices of Bitcoin Core at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// 1. CScript::IsPayToScriptHash, src/script/script.cpp:224-231:
//
//      return (this->size() == 23 &&
//              (*this)[0] == OP_HASH160 &&
//              (*this)[1] == 0x14 &&
//              (*this)[22] == OP_EQUAL);
//
//    OP_HASH160 = 0xa9, OP_EQUAL = 0x87 (script.h opcode table); 0x14 is the
//    20-byte push that fixes the total length at 23.
//
// 2. VerifyScript's P2SH arm, interpreter.cpp:2062-2086:
//
//      2062  if ((flags & SCRIPT_VERIFY_P2SH) && scriptPubKey.IsPayToScriptHash())
//      2065  if (!scriptSig.IsPushOnly()) return SCRIPT_ERR_SIG_PUSHONLY;
//      2069  swap(stack, stackCopy);          // restore post-scriptSig stack
//      2076  const valtype& pubKeySerialized = stack.back();
//      2078  popstack(stack);
//      2080  if (!EvalScript(stack, pubKey2, ...)) return false;
//      2083  if (stack.empty()) return SCRIPT_ERR_EVAL_FALSE;
//      2085  if (!CastToBool(stack.back())) return SCRIPT_ERR_EVAL_FALSE;
//
// The scriptPubKey evaluation that precedes the arm is `OP_HASH160 <h>
// OP_EQUAL` on the same post-scriptSig stack: one element is popped and hashed
// (underflow -> SCRIPT_ERR_INVALID_STACK_OPERATION) and OP_EQUAL leaves a
// boolean. Whether that boolean is true is the crypto seam of the cell: it is
// the symbolic input `hash_match`, i.e. HASH160(redeemScript) == h for the
// concrete 20-byte committed hash. The HASH160 computation itself is not part
// of the cell.
//
// The redeem-script evaluation outcome (error or success with a final stack)
// is the declared seam, exactly `p2shInner`'s `evalScriptBytes ... pubKey2
// rest` (Defs.lean:1341-1344). `pushonly_ok == 0` is the reachable
// non-literal case; a parse failure cannot reach here after a successful
// scriptSig evaluation (EvalScript would have returned BAD_OPCODE first).

W32INLINE uint64_t c_p2sh_reeval(uint64_t ss_err, uint64_t ss_depth,
                                 uint64_t ss_top, uint64_t ss_top_len,
                                 uint64_t hash_match, uint64_t pushonly_ok,
                                 uint64_t redeem_err, uint64_t redeem_depth,
                                 uint64_t redeem_top, uint64_t redeem_top_len) {
  if (ss_err != 0) return w32_pack(0, (uint32_t)ss_err);
  // scriptPubKey = OP_HASH160 <h> OP_EQUAL on the post-scriptSig stack.
  struct CStack { uint64_t n, top, top_len; };
  CStack stack{ss_depth, ss_top, ss_top_len};
  CStack stackCopy = stack;                        // interpreter.cpp:2032-2033
  if (stack.n < 1) return w32_pack(0, EQUIV_ERR_INVALID_STACK_OPERATION);
  if (hash_match == 0) return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  // interpreter.cpp:2062-2066
  if (pushonly_ok == 0) return w32_pack(0, EQUIV_ERR_SIG_PUSHONLY);
  // interpreter.cpp:2069-2078
  stack = stackCopy;                               // swap(stack, stackCopy)
  stack.n -= 1;                                    // popstack(stack)
  stack.top = 0;
  stack.top_len = 0;
  // interpreter.cpp:2080-2086 -- EvalScript(pubKey2, stack)
  if (redeem_err != 0) return w32_pack(0, (uint32_t)redeem_err);
  if (redeem_depth == 0) return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  if (!w32_cast_bool_core(redeem_top, redeem_top_len)) {
    return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  }
  return w32_pack(1, EQUIV_ERR_OK);
}

extern "C" uint64_t cell_is_p2sh(uint64_t len, uint64_t b0, uint64_t b1, uint64_t b22) {
  // Bytes are modelled as the low 8 bits of the arguments (the cell's byte
  // abstraction); the pattern check is Core's, verbatim.
  const uint8_t c0 = (uint8_t)b0, c1 = (uint8_t)b1, c22 = (uint8_t)b22;
  return (len == 23 && c0 == 0xa9u && c1 == 0x14u && c22 == 0x87u) ? 1u : 0u;
}

extern "C" uint64_t cell_p2sh_reeval(uint64_t ss_err, uint64_t ss_depth,
                                     uint64_t ss_top, uint64_t ss_top_len,
                                     uint64_t hash_match, uint64_t pushonly_ok,
                                     uint64_t redeem_err, uint64_t redeem_depth,
                                     uint64_t redeem_top, uint64_t redeem_top_len) {
  if (ss_top_len > 8 || redeem_top_len > 8) {
    return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);   // cell encoding guard
  }
  return c_p2sh_reeval(ss_err, ss_depth, ss_top, ss_top_len, hash_match,
                       pushonly_ok, redeem_err, redeem_depth, redeem_top,
                       redeem_top_len);
}
