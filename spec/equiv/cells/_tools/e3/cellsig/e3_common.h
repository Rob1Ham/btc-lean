#ifndef E3_COMMON_H
#define E3_COMMON_H
// E3 CHECKSIG/CHECKMULTISIG cell harness.
//
// Shared by the C leg (line-cited Core slice) and the L leg (reviewed
// transliteration of the Lean stepBody).  This is cell harness, not engine
// code: bounded stack, packed observable, and the domain guard.
//
// Element encoding used at the cell ABI and at the checker seam:
//   bits  0..7   byte 0
//   bits  8..15  byte 1
//   bits 16..23  length (declared domain: 0 or 1)
//   bits 24..31  zero / reserved
// This is injective over len <= 2, so passing it to the abstract checker is
// passing the same element Core/Lean pass to CheckECDSASignature.
#include <cstdint>

#define E3INLINE static inline __attribute__((always_inline))

struct E3Stack { uint32_t n; uint32_t len[6]; uint32_t val[6]; };

E3INLINE void e3_clear(E3Stack& s) {
  s.n = 0;
  for (int i = 0; i < 6; ++i) { s.len[i] = 0; s.val[i] = 0; }
}

E3INLINE uint32_t e3_elen(uint32_t enc) { return (enc >> 16) & 0xffu; }
E3INLINE uint32_t e3_ebyte(uint32_t enc, uint32_t k) { return (enc >> (8u * k)) & 0xffu; }
E3INLINE uint32_t e3_eval(uint32_t enc) { return enc & 0xffffu; }

// Encoding reconstructed from a stored stack element (the cell ABI above).
E3INLINE uint32_t e3_enc(const E3Stack& s, uint32_t i) {
  // An empty element carries no bytes; never expose a stale payload.
  const uint32_t v = s.len[i] == 0 ? 0u : (s.val[i] & 0xffffu);
  return (s.len[i] << 16) | v;
}

E3INLINE uint32_t e3_truth_elem(uint32_t len, uint32_t val) {
  if (len == 0) return 0;
  if (len == 1) return (val & 0xffu) == 0 || (val & 0xffu) == 0x80u ? 0u : 1u;
  if ((val & 0xffu) != 0) return 1;
  return ((val >> 8) & 0xffu) == 0 || ((val >> 8) & 0xffu) == 0x80u ? 0u : 1u;
}

// Core vchTrue = {1}; vchFalse = {} (interpreter.cpp:static const valtype).
E3INLINE void e3_push_bool(E3Stack& s, bool v) {
  s.len[s.n] = v ? 1u : 0u;
  s.val[s.n] = v ? 1u : 0u;
  s.n += 1;
}

// Packed observable (same layout as cells/_tools/gate/gate_common.h):
// result (2) | error ordinal (6) | depth (3) | top three (len 2, val 8 each).
E3INLINE uint64_t e3_pack(uint32_t res, uint32_t err, const E3Stack& s) {
  const uint32_t m = s.n > 3 ? 3u : s.n;
  uint32_t k = 0;
  if (s.n == 4) k = 1;
  else if (s.n == 5) k = 2;
  else if (s.n >= 6) k = 3;
  uint64_t r = 0;
  r |= (uint64_t)(res & 3u);
  r |= (uint64_t)(err & 0x3fu) << 2;
  r |= (uint64_t)(s.n & 7u) << 8;
  if (m > 0) { r |= (uint64_t)(s.len[k] & 3u) << 11;     r |= (uint64_t)(s.val[k] & 0xffu) << 13; }
  if (m > 1) { r |= (uint64_t)(s.len[k + 1] & 3u) << 21; r |= (uint64_t)(s.val[k + 1] & 0xffu) << 23; }
  if (m > 2) { r |= (uint64_t)(s.len[k + 2] & 3u) << 31; r |= (uint64_t)(s.val[k + 2] & 0xffu) << 33; }
  return r;
}

// Harness finish (= VerifyScript's EVAL_FALSE tail, interpreter.cpp:1876-1880).
// Failure observable.  ABI v2 exposes result + error_kind only on failure;
// the stack is not part of the observable.  Both legs therefore pack an empty
// stack on error (Core mutates the stack before returning false; Lean's
// Except error carries no state, so comparing stacks here would compare an
// unobservable implementation detail).
E3INLINE uint64_t e3_fail(uint32_t err) { E3Stack s; e3_clear(s); return e3_pack(0, err, s); }

E3INLINE uint64_t e3_finish(const E3Stack& s, uint32_t alt_n) {
  if (alt_n != 0) return e3_pack(3, 1, s);
  if (s.n == 0) return e3_pack(0, 2, s);
  if (!e3_truth_elem(s.len[s.n - 1], s.val[s.n - 1])) return e3_pack(0, 2, s);
  return e3_pack(1, 0, s);
}

// Out-of-domain sentinel, returned identically by both legs.  The declared
// domain is: wire IN {0xac,0xad}, stack_n <= 2, element len <= 1,
// sigversion IN {BASE, WITNESS_V0}.  Values outside it are not evidence.
E3INLINE uint64_t e3_ood() { E3Stack s; e3_clear(s); return e3_pack(3, 1, s); }

E3INLINE bool e3_in_domain(uint32_t wire, uint32_t stack_n, uint32_t sig,
                           uint32_t pk, uint32_t sv) {
  return (wire == 0xac || wire == 0xad) && stack_n <= 2 &&
         e3_elen(sig) <= 1 && e3_elen(pk) <= 1 && sv <= 1;
}

// Build the cell's two stack elements: bottom = sig, top = pubkey
// (Core: stacktop(-2) = vchSig, stacktop(-1) = vchPubKey, 1076-1077).
E3INLINE void e3_push_two(E3Stack& s, uint32_t n, uint32_t sig, uint32_t pk) {
  if (n >= 1) { s.len[0] = e3_elen(sig); s.val[0] = e3_eval(sig); s.n = 1; }
  if (n >= 2) { s.len[1] = e3_elen(pk);  s.val[1] = e3_eval(pk);  s.n = 2; }
}

#endif
