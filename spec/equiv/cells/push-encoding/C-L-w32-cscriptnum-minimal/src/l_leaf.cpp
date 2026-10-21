#include <cstdint>
// L leg: Lean `decodeScriptNum` (Numeric/Interface.lean:45-47) as emitted by
// the generated twin `twin/runtime.inc:165-185` (decode_num):
//
//     if (len > maxSize) return TWIN_SCRIPTNUM;
//     if (minimal && len > 0) {
//       if ((b[len-1] & 0x7f) == 0) {
//         if (len <= 1 || (b[len-2] & 0x80) == 0) return TWIN_SCRIPTNUM;
//       }
//     }
//     // sign-magnitude LE decode
//
// The twin mirrors Lean; it is not a Core transliteration.  maxSize = 4,
// len bounded to 0..4, and the byte walk is written as exact-length cases
// (the unsliced loop is over <= 4 bytes).

#define BINLINE static inline __attribute__((always_inline))

BINLINE uint8_t lean_top(const uint8_t* b, uint32_t n) {
  return (n == 1) ? b[0] : (n == 2) ? b[1] : (n == 3) ? b[2] : b[3];
}
BINLINE uint8_t lean_prev(const uint8_t* b, uint32_t n) {
  return (n == 2) ? b[0] : (n == 3) ? b[1] : b[2];
}

BINLINE int64_t lean_decode_value(const uint8_t* b, uint32_t n) {
  switch (n) {
    case 0: return 0;
    case 1: {
      const uint64_t m = static_cast<uint64_t>(b[0] & 0x7fu);
      return (b[0] & 0x80u) ? -static_cast<int64_t>(m) : static_cast<int64_t>(m);
    }
    case 2: {
      const uint64_t m = static_cast<uint64_t>(b[0]) |
                         (static_cast<uint64_t>(b[1] & 0x7fu) << 8);
      return (b[1] & 0x80u) ? -static_cast<int64_t>(m) : static_cast<int64_t>(m);
    }
    case 3: {
      const uint64_t m = static_cast<uint64_t>(b[0]) |
                         (static_cast<uint64_t>(b[1]) << 8) |
                         (static_cast<uint64_t>(b[2] & 0x7fu) << 16);
      return (b[2] & 0x80u) ? -static_cast<int64_t>(m) : static_cast<int64_t>(m);
    }
    default: {
      const uint64_t m = static_cast<uint64_t>(b[0]) |
                         (static_cast<uint64_t>(b[1]) << 8) |
                         (static_cast<uint64_t>(b[2]) << 16) |
                         (static_cast<uint64_t>(b[3] & 0x7fu) << 24);
      return (b[3] & 0x80u) ? -static_cast<int64_t>(m) : static_cast<int64_t>(m);
    }
  }
}

BINLINE uint32_t lean_decode_num(const uint8_t* b, uint32_t n, uint32_t minimal,
                                 int64_t* out) {
  if (n > 4) return 4;                       // TWIN_SCRIPTNUM
  if (minimal && n > 0) {
    if ((lean_top(b, n) & 0x7fu) == 0) {
      if (n <= 1 || (lean_prev(b, n) & 0x80u) == 0) return 4;
    }
  }
  *out = lean_decode_value(b, n);
  return 0;
}

BINLINE uint64_t lean_pack(uint32_t valid, uint32_t err, int64_t v) {
  uint64_t r = 0;
  r |= static_cast<uint64_t>(valid & 1u);
  r |= static_cast<uint64_t>(err & 0xfu) << 2;
  r |= (static_cast<uint64_t>(v) & 0xffffffffULL) << 6;
  return r;
}

extern "C" uint64_t cell_cscriptnum(uint32_t n, uint8_t b0, uint8_t b1,
                                    uint8_t b2, uint8_t b3, uint32_t minimal) {
  const uint8_t b[4] = {b0, b1, b2, b3};
  if (n > 4) return lean_pack(0, 4, 0);
  int64_t v = 0;
  const uint32_t e = lean_decode_num(b, n, minimal, &v);
  if (e) return lean_pack(0, e, 0);
  return lean_pack(1, 0, v);
}
