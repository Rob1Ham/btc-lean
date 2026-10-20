#ifndef CELLS_W32_COMMON_H
#define CELLS_W32_COMMON_H
#include <cstdint>

// Wave-32 (task 15-numeric-086-092) bounded numeric-cell observables.
//
// Element width is 5 bytes so a 4-byte CScriptNum operand can produce the
// 5-byte overflow result that Core's CScriptNum::getvch() is allowed to emit
// (script.h:220-236: results may overflow; only re-interpretation is capped).
// Stack depth is 4 (WITHIN is the widest op, 3 operands -> 1 result).
//
// The packed observable is identical on both legs:
//   result(2) | error(6) | depth(3) | top.len(9) | top.val(40, LE)
// with an empty element canonicalised to value 0 (Core's vchFalse is the
// empty vector; stale slot bytes are not part of the element).  `result` is
// the VerifyScript tail: 1 iff the final stack is non-empty and its top is
// CastToBool-true (interpreter.cpp:1878); `error` is a contract
// EQUIV_ERR_* ordinal (contract/error_kind.h).
//
// This header is cell harness, not engine code.  It is shared by the C and L
// legs so the observable cannot differ between them by construction.
//
// Every helper is loop-free over the fixed width W32_ELEM = 5, like
// cells/_tools/mk_leaf.py's bounded prologue, so Alive2 can symbolically
// execute the extracted leaves with no loop-unrolling assumption.

#define W32_DEPTH 4
#define W32_ELEM 5
#define W32_BINLINE static inline __attribute__((always_inline))

struct W32 {
  uint32_t n;
  uint32_t len[W32_DEPTH];
  uint8_t e[W32_DEPTH][W32_ELEM];
};

W32_BINLINE void w32_init(W32& s) { s = W32{}; }

// Element push used by the harness to build the precondition stack.  It is
// not a script push: it materialises an existing stack element.  Bytes at or
// beyond `l` are zeroed, so the packed 40-bit value cannot leak arbitrary
// caller bytes.
W32_BINLINE void w32_put(W32& s, const uint8_t* d, uint32_t l) {
  const uint32_t i = s.n;
  s.len[i] = l;
  s.e[i][0] = (0 < l) ? d[0] : 0;
  s.e[i][1] = (1 < l) ? d[1] : 0;
  s.e[i][2] = (2 < l) ? d[2] : 0;
  s.e[i][3] = (3 < l) ? d[3] : 0;
  s.e[i][4] = (4 < l) ? d[4] : 0;
  s.n += 1;
}

// CastToBool (interpreter.cpp:46-61): a zero-length element is false; any
// non-zero byte other than a leading/only 0x80 is true.
W32_BINLINE bool w32_truth(const uint8_t* d, uint32_t l) {
  if (l == 0) return false;
  if (d[0] != 0) return !(l == 1 && d[0] == 0x80);
  if (1 < l && d[1] != 0) return !(l == 2 && d[1] == 0x80);
  if (2 < l && d[2] != 0) return !(l == 3 && d[2] == 0x80);
  if (3 < l && d[3] != 0) return !(l == 4 && d[3] == 0x80);
  if (4 < l && d[4] != 0) return !(l == 5 && d[4] == 0x80);
  return false;
}

W32_BINLINE uint64_t w32_pack(uint32_t res, uint32_t err, const W32& s) {
  uint64_t r = 0;
  r |= (uint64_t)(res & 3u);
  r |= (uint64_t)(err & 0x3fu) << 2;
  r |= (uint64_t)(s.n & 7u) << 8;
  if (s.n > 0) {
    const uint32_t i = s.n - 1;
    const uint32_t l = s.len[i];
    r |= (uint64_t)(l & 0x1ffu) << 11;
    if (l != 0) {
      const uint64_t v = (uint64_t)s.e[i][0]
                       | ((uint64_t)s.e[i][1] << 8)
                       | ((uint64_t)s.e[i][2] << 16)
                       | ((uint64_t)s.e[i][3] << 24)
                       | ((uint64_t)s.e[i][4] << 32);
      // The element is exactly its l bytes: bytes past l are not part of
      // the value.  (The C leg's push zeroes them; the twin's st_push only
      // copies l bytes, so masking here makes the observable independent of
      // the representation choice on either leg.)
      const uint64_t mask = (l >= 5) ? 0xffffffffffull : ((1ull << (8u * l)) - 1ull);
      r |= (v & mask) << 20;
    }
  }
  return r;
}

// Apply the VerifyScript tail to a successfully executed op: exactly the
// empty/false-top check at interpreter.cpp:1878 (CLEANSTACK is off in the
// cell precondition, and the L twin's l_finish uses the same rule).
W32_BINLINE uint64_t w32_finish(const W32& s) {
  if (s.n == 0) return w32_pack(0, 2 /*EVAL_FALSE*/, s);
  if (!w32_truth(s.e[s.n - 1], s.len[s.n - 1])) return w32_pack(0, 2, s);
  return w32_pack(1, 0, s);
}

// Error observable without a stack.  After a script error Core's EvalScript
// returns SCRIPT_ERR_* and the caller discards the stack; the twin may not
// have applied the same pops before returning.  Cells whose error arm has
// this asymmetry pack result=0, the contract error ordinal, and an empty
// stack on both legs, so the observable is the error itself and not an
// unspecified post-error stack.  (Successful results keep the full stack.)
W32_BINLINE uint64_t w32_pack_err(uint32_t err) {
  const W32 empty = W32{};
  return w32_pack(0, err, empty);
}
#endif
