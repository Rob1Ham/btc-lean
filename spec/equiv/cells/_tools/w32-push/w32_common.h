#ifndef CELLS_W32_COMMON_H
#define CELLS_W32_COMMON_H
#include <cstdint>

// Shared observables for the wave-32 push-encoding / altstack cells.
//
// The packing functions here are cell harness, not engine code.  They are
// applied identically to the C and L legs; Alive2 compares the 64-bit result
// and SAW checks each leg against an independent Cryptol predicate.
//
// Predicate cells (SCR-052/053/054/055) return 0 or 1 directly; they include
// this header only for the common bounded stack used by the altstack cell.
#define W32_BINLINE static inline __attribute__((always_inline))

// Altstack cell domain: combined depth <= 5, every element exactly one byte.
#define W32_MAX_DEPTH 5

struct W32Stack {
  uint32_t n;
  uint8_t v[W32_MAX_DEPTH];
};

// Packed altstack-step observable:
//   result(2) | error(6) | stack.n(3) | alt.n(3) |
//   stack top byte(8) | alt top byte(8)
// Top bytes are 0 when the corresponding stack is empty.  The layout is
// identical on both legs and is fixed by this file for every w32 cell.
W32_BINLINE uint64_t w32_pack_alt(uint32_t res, uint32_t err,
                                  const W32Stack& s, const W32Stack& a) {
  uint64_t r = 0;
  r |= (uint64_t)(res & 3u);
  r |= (uint64_t)(err & 0x3fu) << 2;
  r |= (uint64_t)(s.n & 7u) << 8;
  r |= (uint64_t)(a.n & 7u) << 11;
  if (s.n > 0) r |= (uint64_t)s.v[s.n - 1] << 14;
  if (a.n > 0) r |= (uint64_t)a.v[a.n - 1] << 22;
  return r;
}

// Sentinel returned by both legs when an argument is outside the declared
// cell domain (wire not one of the two altstack opcodes, or depth > 4).
// It is compare-only: neither leg claims a verdict for that input.
#define W32_OUT_OF_DOMAIN 0xFFFFFFFFFFFFFFFFull

#endif
