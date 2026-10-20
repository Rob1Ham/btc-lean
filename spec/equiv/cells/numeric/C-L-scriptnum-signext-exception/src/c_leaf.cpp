#include <cstdint>
#include "error_kind.h"

// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/script.h:246-271
//       CScriptNum(const std::vector<unsigned char>& vch,
//                  bool fRequireMinimal, size_t nMaxNumSize = 4)
//     if (vch.size() > nMaxNumSize) throw scriptnum_error(...);
//     if (fRequireMinimal && vch.size() > 0) {
//         if ((vch.back() & 0x7f) == 0) {
//             // One exception: if there's more than one byte and the most
//             // significant bit of the second-most-significant-byte is set
//             // it would conflict with the sign bit. An example of this case
//             // is +-255, which encode to 0xff00 and 0xff80 respectively.
//             if (vch.size() <= 1 || (vch[vch.size() - 2] & 0x80) == 0)
//                 throw scriptnum_error("non-minimally encoded script number");
//         }
//     }
//     m_value = set_vch(vch);
//
//   src/script/script.h:342-373  serialize(getvch): canonical LE
//     sign-magnitude.  If the most significant byte has 0x80 set, append
//     0x00 (positive) or 0x80 (negative); the extra byte carries the sign.
//
//   src/script/script.h:376-391  set_vch: little-endian magnitude with the
//     most-significant byte's 0x80 as sign.
//
// Cell domain: rank-8 magnitude (0..255) and one sign bit, so the encoder's
// `while(absvalue)` loop runs at most once (0 < absvalue < 256) and the
// decoder sees at most two bytes (nMaxNumSize = 4).  Both loops are written
// as their single-iteration bodies under that domain; the guards, sign
// extension and value assembly are verbatim.  fRequireMinimal is the subject
// of the row and is fixed to true.

#define BINLINE static inline __attribute__((always_inline))

// script.h:342-373 serialize, bounded |value| <= 255.
BINLINE uint32_t core_encode_num(int64_t value, uint8_t* out) {
  if (value == 0) return 0;
  const bool neg = value < 0;
  const uint64_t absvalue = neg ? (~static_cast<uint64_t>(value) + 1u)
                                : static_cast<uint64_t>(value);
  uint32_t n = 0;
  // while (absvalue) { result.push_back(absvalue & 0xff); absvalue >>= 8; }
  // unrolled: the domain gives 0 < absvalue < 256, so exactly one byte.
  out[0] = static_cast<uint8_t>(absvalue & 0xffu);
  n = 1;
  if (out[n - 1] & 0x80u) {
    out[n++] = neg ? 0x80u : 0x00u;
  } else if (neg) {
    out[n - 1] = static_cast<uint8_t>(out[n - 1] | 0x80u);
  }
  return n;
}

// script.h:376-391 set_vch, exact lengths 0..2 (the cell domain).
BINLINE int64_t core_set_vch(const uint8_t* b, uint32_t n) {
  if (n == 0) return 0;
  if (n == 1) {
    const int64_t m = static_cast<int64_t>(b[0] & 0x7fu);
    return (b[0] & 0x80u) ? -m : m;
  }
  const int64_t m = static_cast<int64_t>(b[0]) |
                    (static_cast<int64_t>(b[1] & 0x7fu) << 8);
  return (b[1] & 0x80u) ? -m : m;
}

// script.h:246-271 CScriptNum(vch, true, 4): width guard, the minimality
// guard with the sign-extension exception, then set_vch.
BINLINE uint32_t core_decode_num(const uint8_t* b, uint32_t n, int64_t* out) {
  if (n > 4) return static_cast<uint32_t>(EQUIV_ERR_SCRIPTNUM);
  if (n > 0) {
    if ((b[n - 1] & 0x7fu) == 0) {
      if (n <= 1 || (b[n - 2] & 0x80u) == 0) {
        return static_cast<uint32_t>(EQUIV_ERR_SCRIPTNUM);
      }
    }
  }
  *out = core_set_vch(b, n);
  return static_cast<uint32_t>(EQUIV_ERR_OK);
}

// Counterfactual harness predicate (NOT engine code): the minimality test
// with the "more than one byte and the previous byte's 0x80 set" exception
// removed.  It labels the bytes the exception is responsible for admitting;
// the real acceptance bit in the observable comes from core_decode_num.
BINLINE bool core_minimal_no_exception(const uint8_t* b, uint32_t n) {
  if (n == 0) return true;
  return (b[n - 1] & 0x7fu) != 0;
}

// Packed observable for cell_signext_roundtrip:
//   ok(1) | err(4 at 1) | n(3 at 5) | b0(8 at 8) | b1(8 at 16) |
//   value16(16 at 24) | real(1 at 40) | strict(1 at 41) | sx(1 at 42)
// value16 is the 16-bit two's-complement image of the decoded value (all
// in-domain values are in [-255, 255]); sx records that serialize appended
// the sign-extension byte.
extern "C" uint64_t cell_signext_roundtrip(uint32_t mag, uint32_t neg) {
  const uint8_t m = static_cast<uint8_t>(mag & 0xffu);
  const bool s = (neg & 1u) != 0;
  const int64_t value = s ? -static_cast<int64_t>(m) : static_cast<int64_t>(m);
  uint8_t b[2] = {0u, 0u};
  const uint32_t n = core_encode_num(value, b);
  int64_t out = 0;
  const uint32_t e = core_decode_num(b, n, &out);
  const bool real = (e == static_cast<uint32_t>(EQUIV_ERR_OK));
  const bool strict = core_minimal_no_exception(b, n);
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

// Packed observable for cell_signext_pred (two-byte payloads, n in {1,2}):
//   real(1 at 0) | strict(1 at 1) | n(2 at 2) | b0(8 at 4) | b1(8 at 12)
extern "C" uint64_t cell_signext_pred(uint32_t two, uint32_t b0,
                                      uint32_t b1) {
  const uint32_t n = 1u + (two & 1u);
  uint8_t b[2];
  b[0] = static_cast<uint8_t>(b0 & 0xffu);
  b[1] = static_cast<uint8_t>(b1 & 0xffu);
  int64_t out = 0;
  const bool real = (core_decode_num(b, n, &out) ==
                     static_cast<uint32_t>(EQUIV_ERR_OK));
  const bool strict = core_minimal_no_exception(b, n);
  uint64_t r = 0;
  r |= real ? 1ull : 0ull;
  r |= (strict ? 1ull : 0ull) << 1;
  r |= static_cast<uint64_t>(n & 3u) << 2;
  r |= static_cast<uint64_t>(b[0]) << 4;
  r |= static_cast<uint64_t>(b[1]) << 12;
  return r;
}
