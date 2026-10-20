#ifndef EQUIV_WAVE16_NUM_COMMON_H
#define EQUIV_WAVE16_NUM_COMMON_H
#include <cstdint>
#include <cstddef>

// Shared cell harness for the wave-16 numeric op cells (numeric family).
//
// This header is *not* engine code.  It holds the two observables both legs
// pack into a uint64 and the small helper that materialises a stack element
// from a symbolic (content word, length) pair.
//
// Bounded leaf domain: stack depth 4, element 8 bytes.  The element width is a
// representation constant of the bounded leaf, not a consensus limit (Core's
// MAX_SCRIPT_ELEMENT_SIZE is 520; no value pushed by these cells exceeds 5
// bytes, so the bound is never reached by a legal path).
#define NUM_MAX_DEPTH 4
#define NUM_MAX_ELEM 8

// Same inline convention as cells/_tools/e2/e2_common.h.
#define BINLINE static inline __attribute__((always_inline))

// Packed observable (55 bits):
//   result(2) | error_kind(6) | depth(3) | top_len(4) | top bytes 0..4 (40)
//   bit  0..1 result, 2..7 error, 8..10 depth, 11..14 len, 15..54 bytes.
// `top_len` is 4 bits because the equal-rawbytes cell observes elements up to
// 8 bytes.  Only the first five bytes of the top element are packed; no
// numeric opcode ever pushes more than five bytes (int64 result of a 4-byte
// operand), so the truncation is observable only on an untouched input
// element, which is documented in each cell's notes.
//
// ABI contract (contract/ABI.md, contract/error_enum.md): the observable
// postcondition is (verdict, error_kind).  The stack is observed only when
// the opcode sequence returned OK; after an error Core aborts the script and
// the stack contents are not part of the contract, so num_obs_err() packs no
// stack.  (Core and the twin do differ there: OP_NUMEQUALVERIFY pushes the
// comparison result before erroring, the twin returns first.  Execution has
// already failed in both, so that difference is not observable.)
template <class Stk>
static inline __attribute__((always_inline)) uint64_t num_obs(uint32_t res,
                                                             uint32_t err,
                                                             const Stk& s) {
  uint64_t r = 0;
  r |= static_cast<uint64_t>(res & 3u);
  r |= static_cast<uint64_t>(err & 0x3fu) << 2;
  r |= static_cast<uint64_t>(s.n & 7u) << 8;
  if (s.n != 0) {
    const uint32_t i = s.n - 1;
    const uint32_t len = s.len[i];
    r |= static_cast<uint64_t>(len & 0xfu) << 11;
    // Only the first `len` bytes are part of the element: a slot can retain
    // bytes from a previous (popped) element, exactly as Core's valtype would
    // not.  Reading byte k only when k < len keeps the observable equal to the
    // element's contents (same decision as cells/_tools/e2/e2_common.h).
    r |= static_cast<uint64_t>(len > 0 ? s.e[i][0] : 0u) << 15;
    r |= static_cast<uint64_t>(len > 1 ? s.e[i][1] : 0u) << 23;
    r |= static_cast<uint64_t>(len > 2 ? s.e[i][2] : 0u) << 31;
    r |= static_cast<uint64_t>(len > 3 ? s.e[i][3] : 0u) << 39;
    r |= static_cast<uint64_t>(len > 4 ? s.e[i][4] : 0u) << 47;
  }
  return r;
}

// Post-error observable: verdict 0 + error kind, no stack (see above).
static inline __attribute__((always_inline)) uint64_t num_obs_err(uint32_t err) {
  return static_cast<uint64_t>(err & 0x3fu) << 2;
}

// Constant-index byte select over a bounded element: stands in for
// `vch.back()` / `vch[len-1]` so neither tool has to reason about a symbolic
// address into a local array.  Exact for i <= 7.
static inline __attribute__((always_inline)) uint32_t num_byte(const uint8_t* d,
                                                              uint32_t i) {
  return (i == 0) ? d[0] : (i == 1) ? d[1] : (i == 2) ? d[2] : (i == 3) ? d[3]
       : (i == 4) ? d[4] : (i == 5) ? d[5] : (i == 6) ? d[6] : d[7];
}

// Materialise one element from a 4-byte little-endian content word and a
// length.  Bytes beyond the fourth are zero.  Applied identically to both
// legs, so the cell domain is exactly { all operands of length 0..7 }: for
// length <= 4 every CScriptNum operand appears once; length 5..7 is the
// `vch.size() > nMaxNumSize` reject edge (rejection depends on length only).
static inline __attribute__((always_inline)) void num_load(uint8_t* dst,
                                                           uint32_t word) {
  dst[0] = static_cast<uint8_t>(word & 0xffu);
  dst[1] = static_cast<uint8_t>((word >> 8) & 0xffu);
  dst[2] = static_cast<uint8_t>((word >> 16) & 0xffu);
  dst[3] = static_cast<uint8_t>((word >> 24) & 0xffu);
  dst[4] = 0;
  dst[5] = 0;
  dst[6] = 0;
  dst[7] = 0;
}

// 8-byte variant for the raw-byte cell (OP_EQUAL): the element is 8 bytes
// because the opcode compares raw bytes without any CScriptNum width cap.
static inline __attribute__((always_inline)) void num_load8(uint8_t* dst,
                                                            uint64_t word) {
  dst[0] = static_cast<uint8_t>(word & 0xffu);
  dst[1] = static_cast<uint8_t>((word >> 8) & 0xffu);
  dst[2] = static_cast<uint8_t>((word >> 16) & 0xffu);
  dst[3] = static_cast<uint8_t>((word >> 24) & 0xffu);
  dst[4] = static_cast<uint8_t>((word >> 32) & 0xffu);
  dst[5] = static_cast<uint8_t>((word >> 40) & 0xffu);
  dst[6] = static_cast<uint8_t>((word >> 48) & 0xffu);
  dst[7] = static_cast<uint8_t>((word >> 56) & 0xffu);
}

// Bounded element length for the raw-byte cell: the harness exposes a 4-bit
// length input and the bounded element is 8 bytes, so lengths 9..15 are folded
// to 8.  Applied identically to both legs and to the Cryptol spec.
static inline __attribute__((always_inline)) uint32_t num_len8(uint32_t l) {
  const uint32_t m = l & 0xfu;
  return m > 8u ? 8u : m;
}
#endif  // EQUIV_WAVE16_NUM_COMMON_H
