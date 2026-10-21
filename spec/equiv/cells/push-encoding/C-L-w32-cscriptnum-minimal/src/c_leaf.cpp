#include <cstdint>
// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/script.h:246-268  CScriptNum(vch, fRequireMinimal, 4)
//     if (vch.size() > 4) throw scriptnum_error("script number overflow");
//     if (fRequireMinimal && vch.size() > 0) {
//         if ((vch.back() & 0x7f) == 0) {
//             if (vch.size() <= 1 || (vch[vch.size() - 2] & 0x80) == 0)
//                 throw scriptnum_error("non-minimally encoded script number");
//         }
//     }
//     m_value = set_vch(vch);
//
//   src/script/script.h:376-391  set_vch(vch)
//     little-endian sign-magnitude; the top byte's 0x80 is the sign and is
//     cleared from the magnitude before negation.
//
// EvalScript maps scriptnum_error to SCRIPT_ERR_SCRIPTNUM.  This cell is the
// decode primitive with nMaxNumSize = 4, the numeric-op default.  Length is
// bounded to 0..4, so every dynamic index/shift in the unsliced function is
// written as an explicit constant case; no semantics change.

#define BINLINE static inline __attribute__((always_inline))

BINLINE uint8_t core_top(const uint8_t* b, uint32_t n) {
  return (n == 1) ? b[0] : (n == 2) ? b[1] : (n == 3) ? b[2] : b[3];
}
BINLINE uint8_t core_prev(const uint8_t* b, uint32_t n) {
  return (n == 2) ? b[0] : (n == 3) ? b[1] : b[2];
}

// script.h:376-391 set_vch, by exact length (n <= 4).
BINLINE int64_t core_set_vch(const uint8_t* b, uint32_t n) {
  switch (n) {
    case 0: return 0;
    case 1: {
      const int64_t m = static_cast<int64_t>(b[0] & 0x7fu);
      return (b[0] & 0x80u) ? -m : m;
    }
    case 2: {
      const int64_t m = static_cast<int64_t>(b[0]) |
                        (static_cast<int64_t>(b[1] & 0x7fu) << 8);
      return (b[1] & 0x80u) ? -m : m;
    }
    case 3: {
      const int64_t m = static_cast<int64_t>(b[0]) |
                        (static_cast<int64_t>(b[1]) << 8) |
                        (static_cast<int64_t>(b[2] & 0x7fu) << 16);
      return (b[2] & 0x80u) ? -m : m;
    }
    default: {
      const int64_t m = static_cast<int64_t>(b[0]) |
                        (static_cast<int64_t>(b[1]) << 8) |
                        (static_cast<int64_t>(b[2]) << 16) |
                        (static_cast<int64_t>(b[3] & 0x7fu) << 24);
      return (b[3] & 0x80u) ? -m : m;
    }
  }
}

BINLINE uint64_t core_pack(uint32_t valid, uint32_t err, int64_t v) {
  uint64_t r = 0;
  r |= static_cast<uint64_t>(valid & 1u);
  r |= static_cast<uint64_t>(err & 0xfu) << 2;
  r |= (static_cast<uint64_t>(v) & 0xffffffffULL) << 6;
  return r;
}

// 0 = accepted, 4 = SCRIPT_ERR_SCRIPTNUM.
BINLINE uint32_t core_decode_scriptnum(const uint8_t* b, uint32_t n,
                                       uint32_t minimal, int64_t* out) {
  if (n > 4) return 4;                       // script number overflow
  if (minimal && n > 0) {
    if ((core_top(b, n) & 0x7fu) == 0) {
      if (n <= 1 || (core_prev(b, n) & 0x80u) == 0) return 4;
    }
  }
  *out = core_set_vch(b, n);
  return 0;
}

extern "C" uint64_t cell_cscriptnum(uint32_t n, uint8_t b0, uint8_t b1,
                                    uint8_t b2, uint8_t b3, uint32_t minimal) {
  const uint8_t b[4] = {b0, b1, b2, b3};
  if (n > 4) return core_pack(0, 4, 0);      // out-of-domain width
  int64_t v = 0;
  const uint32_t e = core_decode_scriptnum(b, n, minimal, &v);
  if (e) return core_pack(0, e, 0);
  return core_pack(1, 0, v);
}
