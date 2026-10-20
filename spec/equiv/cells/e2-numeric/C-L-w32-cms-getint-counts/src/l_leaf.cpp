#include <cstdint>

// L leg -- SCR-086: reviewed transliteration of the btc-lean model, NOT a
// twin handler.
//
// The twin (spec/equiv/twin) has no int32 clamp in decode_num and no
// CHECKMULTISIG handler at all.  This leg therefore does not claim to prove
// "the twin's clamp"; it transliterates
//
//   Bitcoin.Numeric.getIntClamped                 Numeric/ScriptNum.lean:741-744
//   Bitcoin.Numeric.decodeNum / setVchBE          Numeric/ScriptNum.lean:627-631,
//                                                 444-460
//   Bitcoin.Interpreter.checkMultiSig             Interpreter/Defs.lean:1071-1096
//
// and keeps Lean's unbounded `Int` for the decoded value.  The model has no
// clamp at the CMS count site: Lean reads `nkv`/`nsv` directly.  The C leg
// does clamp.  On a four-byte operand the two are equal because setVchBE is
// in [-2^31+1, 2^31-1] (PDW86Clamp.setVchBE_bounds_of_length_le_four), so
// this cell is a real C-L proof of the call site, not a claim that the twin
// implements getint().
//
// Observable of cell_cms_counts4: identical packing to the C leg (cell-local
// status codes 0..4).  Lean stack positions are top-first; the derived
// ikey2 = nKeys+2 and isig = nKeys+3 are the same positions as Core's
// bottom-first cursors, as in checkmultisig/C-L-cms-layout-sym.

// -- getIntClamped (Numeric/ScriptNum.lean:741-744).
static inline int32_t lean_getIntClamped(int64_t n) {
  if (2147483647LL < n) return 2147483647;
  if (n < -2147483648LL) return -2147483648;
  return static_cast<int32_t>(n);
}

// -- setVchBE on a four-byte little-endian operand (ScriptNum.lean:449-460).
//    Length is fixed at four, so the width guard cannot fire and minimality is
//    not consulted (the cell fixes fRequireMinimal = false; the minimal subset
//    is a restriction of this domain).
static inline int64_t lean_setVchBE4(uint8_t d0, uint8_t d1, uint8_t d2,
                                     uint8_t d3) {
  const uint64_t mag = static_cast<uint64_t>(d0)
                     | (static_cast<uint64_t>(d1) << 8)
                     | (static_cast<uint64_t>(d2) << 16)
                     | (static_cast<uint64_t>(d3 & 0x7fu) << 24);
  return (d3 & 0x80u) ? -static_cast<int64_t>(mag)
                      : static_cast<int64_t>(mag);
}

static inline uint64_t lean_cms_pack(uint32_t status, uint32_t nKeys,
                                     uint32_t nSigs, uint32_t ikey2,
                                     uint32_t isig) {
  return (uint64_t)(status & 7u)
       | ((uint64_t)(nKeys & 31u) << 3)
       | ((uint64_t)(nSigs & 31u) << 8)
       | ((uint64_t)(ikey2 & 63u) << 13)
       | ((uint64_t)(isig & 63u) << 19);
}

extern "C" int32_t cell_clamp_int32(int64_t x) {
  return lean_getIntClamped(x);
}

extern "C" uint64_t cell_cms_counts4(uint8_t kb0, uint8_t kb1, uint8_t kb2,
                                     uint8_t kb3, uint8_t sb0, uint8_t sb1,
                                     uint8_t sb2, uint8_t sb3,
                                     uint32_t depth, uint32_t opCount) {
  // decodeNum ... 4 -> .ok nkv; Lean keeps nkv as an unbounded Int.
  const int64_t nkv = lean_setVchBE4(kb0, kb1, kb2, kb3);
  if (nkv < 0 || 20 < nkv) {                            // Defs.lean:1077
    return lean_cms_pack(1, 0, 0, 0, 0);                // pubKeyCount
  }
  const uint64_t nKeys = static_cast<uint64_t>(nkv);    // nkv.toNat
  const uint64_t opCount2 = static_cast<uint64_t>(opCount) + nKeys;
  if (201u < opCount2) {                                // Defs.lean:1081
    return lean_cms_pack(2, 0, 0, 0, 0);                // opCount
  }
  if (static_cast<uint64_t>(depth) < nKeys + 2u) {      // Defs.lean:1083
    return lean_cms_pack(3, 0, 0, 0, 0);                // stackUnderflow
  }
  const int64_t nsv = lean_setVchBE4(sb0, sb1, sb2, sb3);
  if (nsv < 0 || nkv < nsv) {                           // Defs.lean:1086
    return lean_cms_pack(4, 0, 0, 0, 0);                // sigCount
  }
  const uint64_t nSigs = static_cast<uint64_t>(nsv);
  if (static_cast<uint64_t>(depth) < nKeys + nSigs + 3u) {  // Defs.lean:1089
    return lean_cms_pack(3, 0, 0, 0, 0);                // stackUnderflow
  }
  return lean_cms_pack(0, (uint32_t)nKeys, (uint32_t)nSigs,
                       (uint32_t)(nKeys + 2u), (uint32_t)(nKeys + 3u));
}
