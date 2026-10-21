#ifndef CELLS_NUMERIC_NEGZERO_COMMON_H
#define CELLS_NUMERIC_NEGZERO_COMMON_H
#include <cstdint>

// Cell harness shared by both legs.  The packed observable is the only
// thing that is identical by construction; the decode and the CastToBool
// predicate are written independently in c_cell.cpp (Core slice) and
// l_cell.cpp (Lean transliteration), and both are checked against the
// independent Cryptol model in saw/cell.cry.
//
//   bits  0..7   err    (EQUIV_ERR_SCRIPTNUM = 4 iff len > 4)
//   bits  8..39  value  (low 32 bits of the decoded CScriptNum int64)
//   bit   40     cast   (CastToBool of the same wire bytes)
//
// value is exact in 32 bits because the cell's domain is the default
// four-byte CScriptNum operand (|v| <= 0x7fffffff).
#define NZ_INLINE static inline __attribute__((always_inline))

NZ_INLINE uint64_t nz_pack(uint32_t err, int64_t value, bool cast) {
  uint64_t r = 0;
  r |= static_cast<uint64_t>(err & 0xffu);
  r |= static_cast<uint64_t>(static_cast<uint32_t>(static_cast<int32_t>(value)))
       << 8;
  r |= static_cast<uint64_t>(cast ? 1u : 0u) << 40;
  return r;
}
#endif
