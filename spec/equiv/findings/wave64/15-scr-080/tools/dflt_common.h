#ifndef EQUIV_WAVE64_DFLT_COMMON_H
#define EQUIV_WAVE64_DFLT_COMMON_H
#include <cstdint>
#include <cstddef>

// Shared cell harness for numeric/C-L-numeric-default-4byte (SCR-080).
//
// This header is *not* engine code.  It holds the packed observable both legs
// return, the constant-index byte select, and the element loader.
//
// Bounded leaf domain: stack depth 8, element 8 bytes.  The element width is a
// representation constant of the bounded leaf, not a consensus limit (Core's
// MAX_SCRIPT_ELEMENT_SIZE is 520); no operand decoded here is longer than the
// symbolic harness length 0..7.
#define DFLT_MAX_DEPTH 8
#define DFLT_MAX_ELEM 8

// Same inline convention as cells/_tools/e2/e2_common.h.
#define BINLINE static inline __attribute__((always_inline))

// ABI v2 observable, packed into one uint64:
//
//   bit  0..1   status      1 = operand accepted, 0 = rejected
//   bit  2..7   error_kind  contract/error_kind.h ordinal (4 = SCRIPTNUM)
//   bit  8..11  site        the CScriptNum call site, 1..7 (see spec.md)
//   bit 12..44  value       decoded int64, low 33 bits (two's complement)
//
// The accepted arm carries the value the site consumes; the reject arm carries
// error 4 and value 0.  The value width is 33 bits because a 4-byte CScriptNum
// is in [-(2^31-1), 2^31-1]; lengths 5..7 never reach set_vch.
static inline __attribute__((always_inline)) uint64_t dflt_obs(uint32_t site,
                                                               uint32_t err,
                                                               int64_t v) {
  uint64_t r = (err == 0) ? 1u : 0u;
  r |= static_cast<uint64_t>(err & 0x3fu) << 2;
  r |= static_cast<uint64_t>(site & 0xfu) << 8;
  r |= (static_cast<uint64_t>(v) & 0x1ffffffffULL) << 12;
  return r;
}

// Constant-index byte select over a bounded element: stands in for
// `vch.back()` / `vch[len-1]` so neither tool reasons about a symbolic address
// into a local array.  Exact for i <= 7.
static inline __attribute__((always_inline)) uint32_t num_byte(const uint8_t* d,
                                                              uint32_t i) {
  return (i == 0) ? d[0] : (i == 1) ? d[1] : (i == 2) ? d[2] : (i == 3) ? d[3]
       : (i == 4) ? d[4] : (i == 5) ? d[5] : (i == 6) ? d[6] : d[7];
}

// Materialise one element from a 4-byte little-endian content word and a
// length.  Bytes beyond the fourth are zero.  Applied identically to both legs,
// so the cell domain is exactly { all operands of length 0..7 }: for length
// <= 4 every CScriptNum operand appears once; lengths 5..7 are the
// `vch.size() > nMaxNumSize` reject edge.
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
#endif  // EQUIV_WAVE64_DFLT_COMMON_H
