#ifndef CELLS_W32_EXEC_006_009_COMMON_H
#define CELLS_W32_EXEC_006_009_COMMON_H

// Shared bounded harness for the wave-32 exec-verify cells
// (C-L-w32-p2sh-pushonly, C-L-w32-p2sh-stackcopy, C-L-w32-cleanstack,
// C-L-w32-flag-combo).  Nothing here is engine code: the helpers are the
// cell representation of a stack of at most two 1-byte elements and the
// packed observable that both tools compare.

#include <cstdint>

#define XINLINE static inline __attribute__((always_inline))

// ABI-shaped observable: result(2 bits) | error ordinal(6 bits) << 2.
// This is exactly the contract's (result, error_kind) pair.
XINLINE uint64_t x_pack2(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

// SCR-007 observable: what the P2SH subscript evaluation is handed.
//   result(2) | error(6)<<2 | redeem(8)<<8 | sub_n(2)<<16
//   | sub_e0(8)<<18 | sub_e1(8)<<26
// redeem is the top element of the restored scriptSig stack (Core
// `stack.back()`, the serialized redeemScript, one byte in this cell);
// sub_n/sub_e0/sub_e1 are the depth and the two element bytes of the stack
// passed to `EvalScript(pubKey2, stack)` at interpreter.cpp:2080.
XINLINE uint64_t x_pack_stack(uint32_t result, uint32_t error, uint32_t redeem,
                              uint32_t n, uint32_t e0, uint32_t e1) {
  return x_pack2(result, error)
       | ((uint64_t)(redeem & 0xffu) << 8)
       | ((uint64_t)(n & 3u) << 16)
       | ((uint64_t)(e0 & 0xffu) << 18)
       | ((uint64_t)(e1 & 0xffu) << 26);
}

// Cell stack, head = TOP.  Core's stack is a vector whose `back()` is the
// top; the Lean model is a list whose head is the top.  Depth is capped at
// two elements: the cell domain is n in [0,2], and the cap only projects
// inputs outside that domain (both legs project identically).
struct XStack {
  uint32_t n;
  uint8_t e[2];
};

XINLINE uint32_t x_clamp2(uint64_t n) {
  return n > 2u ? 2u : (uint32_t)n;
}

XINLINE XStack x_stack(uint64_t n, uint64_t e0, uint64_t e1) {
  XStack s;
  s.n = x_clamp2(n);
  s.e[0] = (uint8_t)(e0 & 0xffu);
  s.e[1] = (uint8_t)(e1 & 0xffu);
  return s;
}

// CastToBool for a one-byte element (interpreter.cpp:466-479): a lone 0x80
// (negative zero) is false.  For size 1 this is exactly `(b & 0x7f) != 0`.
XINLINE bool x_cast_to_bool1(uint8_t b) { return (b & 0x7f) != 0; }

// Core `popstack` (interpreter.cpp:479 `stack.pop_back()`): drop the top
// element.  Head = top means shifting the remaining element down.
XINLINE XStack x_popstack(XStack s) {
  XStack r;
  r.n = s.n == 0u ? 0u : s.n - 1u;
  r.e[0] = r.n >= 1u ? s.e[1] : 0u;
  r.e[1] = 0u;
  return r;
}

#endif
