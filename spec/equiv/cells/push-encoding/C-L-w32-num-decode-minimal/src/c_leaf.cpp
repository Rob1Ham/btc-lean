#include <cstdint>
#include "error_kind.h"

// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/script.h:246-271  CScriptNum(const std::vector<unsigned char>&,
//                                             bool fRequireMinimal,
//                                             size_t nMaxNumSize = 4)
//       if (vch.size() > nMaxNumSize)
//           throw scriptnum_error("script number overflow");
//       if (fRequireMinimal && vch.size() > 0) {
//           if ((vch.back() & 0x7f) == 0) {
//               if (vch.size() <= 1 || (vch[vch.size() - 2] & 0x80) == 0)
//                   throw scriptnum_error("non-minimally encoded number");
//           }
//       }
//       m_value = set_vch(vch);
//
//   src/script/script.h:376-391  set_vch: little-endian magnitude, sign bit
//       0x80 in the most-significant byte, negative zero decodes to 0.
//
// EvalScript catches scriptnum_error and reports SCRIPT_ERR_SCRIPTNUM
// (the sites named by SCR-051 are CLTV/CSV with nMaxNumSize = 5 and the
// CHECKMULTISIG key/sig counts with nMaxNumSize = 4; CHECKSIGADD's number
// uses the default 4).  The excerpt is the constructor, specialised to a
// five-byte operand: the set_vch loop is unrolled and guarded by `len`.
//
// Packed observable: result(2) | error(6) | value(56 at bit 8).  result=1
// means the constructor returned a value; result=0 means it threw.

static uint64_t w32_dec_pack(uint32_t res, uint32_t err, int64_t v) {
  return (uint64_t)(res & 3u) | ((uint64_t)(err & 0x3fu) << 2) |
         ((uint64_t)v << 8);
}

extern "C" uint64_t cell_decnum(uint8_t b0, uint8_t b1, uint8_t b2,
                                uint8_t b3, uint8_t b4, uint8_t len,
                                uint8_t minimal, uint8_t wide) {
  const uint8_t v[5] = {b0, b1, b2, b3, b4};
  // Cell domain: operand length is three bits (0..7).  Lengths 0..5 reach
  // the value path; 6 and 7 are wider than both maxSize choices and exercise
  // the width rejection.  Masking is identical on both legs.
  const uint32_t len_m = len & 7u;
  const uint32_t maxsize = wide ? 5u : 4u;
  if (len_m > maxsize) return w32_dec_pack(0, EQUIV_ERR_SCRIPTNUM, 0);
  if (minimal && len_m > 0) {
    if ((v[len_m - 1] & 0x7fu) == 0) {
      if (len_m <= 1 || (v[len_m - 2] & 0x80u) == 0) {
        return w32_dec_pack(0, EQUIV_ERR_SCRIPTNUM, 0);
      }
    }
  }
  if (len_m == 0) return w32_dec_pack(1, EQUIV_ERR_OK, 0);
  uint64_t mag = 0;
  if (len_m >= 1) mag |= (uint64_t)v[0];
  if (len_m >= 2) mag |= (uint64_t)v[1] << 8;
  if (len_m >= 3) mag |= (uint64_t)v[2] << 16;
  if (len_m >= 4) mag |= (uint64_t)v[3] << 24;
  if (len_m >= 5) mag |= (uint64_t)v[4] << 32;
  const bool neg = (v[len_m - 1] & 0x80u) != 0;
  if (neg) {
    mag &= ~(0x80ull << (8u * (len_m - 1)));
    return w32_dec_pack(1, EQUIV_ERR_OK, -(int64_t)mag);
  }
  return w32_dec_pack(1, EQUIV_ERR_OK, (int64_t)mag);
}
