#include <cstdint>
#include "error_kind.h"

// L leg: the Lean numeric encode/decode as emitted by the generated twin
// spec/equiv/twin/runtime.inc at the pin (Lean source of record:
// spec/core/Bitcoin/Numeric/Interface.lean decodeScriptNum/encodeScriptNum,
// Numeric/ScriptNum.lean minimalOkBE).
//
//   twin/runtime.inc:141-157  encode_num(v, out)
//     if (v == 0) return 0;
//     const bool neg = v < 0;
//     uint64_t a = neg ? (uint64_t)(-(v + 1)) + 1 : (uint64_t)v;
//     while (a != 0) { out[n++] = a & 0xff; a >>= 8; }
//     if ((out[n - 1] & 0x80) != 0) out[n++] = neg ? 0x80 : 0x00;
//     else if (neg) out[n - 1] |= 0x80;
//
//   twin/runtime.inc:167-188  decode_num(b, len, minimal, maxSize, out)
//     if (len > maxSize) return TWIN_SCRIPTNUM;
//     if (minimal && len > 0) {
//       if ((b[len - 1] & 0x7f) == 0) {
//         if (len <= 1 || (b[len - 2] & 0x80) == 0) return TWIN_SCRIPTNUM;
//       }
//     }
//     if (len == 0) { out = 0; return TWIN_OK; }
//     uint64_t v = 0;
//     for (i = 0; i < len; ++i) {
//       byte = b[i]; if (i + 1 == len) byte &= 0x7f; v |= byte << 8i;
//     }
//     const bool neg = b[len - 1] & 0x80;
//     out = neg ? -(int64_t)v : (int64_t)v;
//
// Cell domain (mirrors the C leg): 0 < abs(v) < 256 and len <= 2, so the
// encoder's while loop runs at most once and the decoder's for loop is
// unrolled over its two iterations; guards and value assembly are verbatim.
// TWIN_OK / TWIN_SCRIPTNUM map to the contract ordinals EQUIV_ERR_OK (0) /
// EQUIV_ERR_SCRIPTNUM (4) (contract/error_kind.h; runtime.inc's own
// TwinErr -> Core map).
//
// The no-exception predicate below is counterfactual harness, NOT engine
// code: it names the bytes whose admission depends on the exception.  The
// real acceptance bit is produced by lean_decode_num.

#define BINLINE static inline __attribute__((always_inline))

// twin/runtime.inc:141-157 encode_num, bounded |v| <= 255.
BINLINE uint32_t lean_encode_num(int64_t v, uint8_t* out) {
  if (v == 0) return 0;
  const bool neg = v < 0;
  const uint64_t a = neg ? (static_cast<uint64_t>(-(v + 1)) + 1u)
                         : static_cast<uint64_t>(v);
  uint32_t n = 0;
  // while (a != 0) { out[n++] = a & 0xff; a >>= 8; } unrolled: a < 256.
  out[0] = static_cast<uint8_t>(a & 0xffu);
  n = 1;
  if ((out[n - 1] & 0x80u) != 0) {
    out[n++] = neg ? 0x80u : 0x00u;
  } else if (neg) {
    out[n - 1] = static_cast<uint8_t>(out[n - 1] | 0x80u);
  }
  return n;
}

// twin/runtime.inc:167-188 decode_num(b, len, true, 4, out), loop unrolled
// over len <= 2.
BINLINE uint32_t lean_decode_num(const uint8_t* b, uint32_t len, int64_t* out) {
  if (len > 4) return static_cast<uint32_t>(EQUIV_ERR_SCRIPTNUM);
  if (len > 0) {
    if ((b[len - 1] & 0x7fu) == 0) {
      if (len <= 1 || (b[len - 2] & 0x80u) == 0) {
        return static_cast<uint32_t>(EQUIV_ERR_SCRIPTNUM);
      }
    }
  }
  if (len == 0) {
    *out = 0;
    return static_cast<uint32_t>(EQUIV_ERR_OK);
  }
  uint64_t v = 0;
  {
    uint64_t byte = b[0];
    if (1u == len) byte &= 0x7fu;
    v |= byte;
  }
  if (len >= 2) {
    uint64_t byte = b[1];
    if (2u == len) byte &= 0x7fu;
    v |= byte << 8;
  }
  const bool neg = (b[len - 1] & 0x80u) != 0;
  *out = neg ? -static_cast<int64_t>(v) : static_cast<int64_t>(v);
  return static_cast<uint32_t>(EQUIV_ERR_OK);
}

// Counterfactual harness predicate (NOT engine code): the minimality test
// with the sign-extension exception removed.
BINLINE bool lean_minimal_no_exception(const uint8_t* b, uint32_t n) {
  if (n == 0) return true;
  return (b[n - 1] & 0x7fu) != 0;
}

// Packed observables: identical layout to the C leg.
extern "C" uint64_t cell_signext_roundtrip(uint32_t mag, uint32_t neg) {
  const uint8_t m = static_cast<uint8_t>(mag & 0xffu);
  const bool s = (neg & 1u) != 0;
  const int64_t value = s ? -static_cast<int64_t>(m) : static_cast<int64_t>(m);
  uint8_t b[2] = {0u, 0u};
  const uint32_t n = lean_encode_num(value, b);
  int64_t out = 0;
  const uint32_t e = lean_decode_num(b, n, &out);
  const bool real = (e == static_cast<uint32_t>(EQUIV_ERR_OK));
  const bool strict = lean_minimal_no_exception(b, n);
  const bool sx = (m & 0x80u) != 0;
  const uint16_t v16 = static_cast<uint16_t>(static_cast<uint64_t>(real ? out : 0));
  uint64_t r = 0;
  r |= real ? 1ull : 0ull;
  r |= static_cast<uint64_t>(e & 0xfu) << 1;
  r |= static_cast<uint64_t>(n & 7u) << 5;
  r |= static_cast<uint64_t>(b[0]) << 8;
  r |= static_cast<uint64_t>(b[1]) << 16;
  r |= static_cast<uint64_t>(v16) << 24;
  r |= (real ? 1ull : 0ull) << 40;
  r |= (strict ? 1ull : 0ull) << 41;
  r |= (sx ? 1ull : 0ull) << 42;
  return r;
}

extern "C" uint64_t cell_signext_pred(uint32_t two, uint32_t b0,
                                      uint32_t b1) {
  const uint32_t n = 1u + (two & 1u);
  uint8_t b[2];
  b[0] = static_cast<uint8_t>(b0 & 0xffu);
  b[1] = static_cast<uint8_t>(b1 & 0xffu);
  int64_t out = 0;
  const bool real = (lean_decode_num(b, n, &out) ==
                     static_cast<uint32_t>(EQUIV_ERR_OK));
  const bool strict = lean_minimal_no_exception(b, n);
  uint64_t r = 0;
  r |= real ? 1ull : 0ull;
  r |= (strict ? 1ull : 0ull) << 1;
  r |= static_cast<uint64_t>(n & 3u) << 2;
  r |= static_cast<uint64_t>(b[0]) << 4;
  r |= static_cast<uint64_t>(b[1]) << 12;
  return r;
}
