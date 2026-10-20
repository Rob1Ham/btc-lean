#include "num_common.h"
#include "num_core.h"

// C leg: source-excerpt slice of Bitcoin Core
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/script/script.h:342-373  CScriptNum::serialize  (encode)
//   src/script/script.h:376-391  set_vch                 (decode)
//   src/script/script.h:337-340  getvch
//
// The excerpt itself lives in num_core.h (bounded transcription: bounded
// element instead of std::vector, error return instead of throw, loops
// unrolled).  Both functions are called directly here -- no EvalScript case
// block is sliced in -- because SCR-082 is exactly the byte<->number map:
//
//   * decode: the sign bit is bit 0x80 of the MOST SIGNIFICANT (wire-last)
//     byte; the magnitude is the remaining bits in little-endian order.  A
//     sign bit with zero magnitude ("negative zero", e.g. 0x80 or 00 80)
//     therefore decodes to the integer 0 (SCR-083, exercised here because the
//     same circuit decides it).
//   * encode: canonical little-endian sign-magnitude.  0 is the empty vector.
//     If the magnitude's top byte already has bit 7 set, a fresh 0x80
//     (negative) / 0x00 (positive) byte is appended; otherwise the sign bit
//     is OR-ed into the top magnitude byte.
//
// Domain: the bounded leaf's element is 8 bytes.  decode takes a symbolic
// length 0..7 (the CScriptNum width guard is off: maxSize is 8, so this cell
// observes set_vch itself; SCR-079/080 own the width guard).  encode and
// encode_decode take a 32-bit magnitude and a sign bit.  That is the closure
// of the numeric-op operand domain: a 4-byte CScriptNum has |v| <= 2^31-1,
// and OP_ADD/OP_SUB of two of them has |v| <= 2^32-2, so every value a
// numeric opcode can serialize is in the domain.  roundtrip decodes lengths
// 0..4 (every legal 4-byte operand) and re-encodes.
using namespace core;

namespace {

// Observable layout for the encode functions (44 bits):
//   len(4) << 0 | byte0 << 4 | byte1 << 12 | byte2 << 20 | byte3 << 28 |
//   byte4 << 36.  Five bytes is the widest output in this domain; the same
//   pack is used by both legs and by src/sign.cry.
BINLINE uint64_t pack_enc(uint32_t n, uint64_t packed) {
  return (static_cast<uint64_t>(n) & 0xfu) |
         ((packed & 0xffffffffffULL) << 4);
}

// |value| <= 2^32-1, so the negation is exact in int64.
BINLINE int64_t value_of(uint32_t mag, uint32_t neg) {
  return (neg & 1u) ? -static_cast<int64_t>(mag) : static_cast<int64_t>(mag);
}

// Inverse of the LE packing in num_core.h serialize(): constant indices.
BINLINE void unpack8(uint8_t* d, uint64_t packed) {
  d[0] = static_cast<uint8_t>(packed);
  d[1] = static_cast<uint8_t>(packed >> 8);
  d[2] = static_cast<uint8_t>(packed >> 16);
  d[3] = static_cast<uint8_t>(packed >> 24);
  d[4] = static_cast<uint8_t>(packed >> 32);
  d[5] = static_cast<uint8_t>(packed >> 40);
  d[6] = static_cast<uint8_t>(packed >> 48);
  d[7] = static_cast<uint8_t>(packed >> 56);
}

}  // namespace

// Decode every byte string of length 0..7 into the int64 value set_vch
// produces.  The raw int64 is the observable (bit pattern in uint64).
extern "C" uint64_t cell_decode(uint64_t w, uint32_t lb) {
  uint8_t b[NUM_MAX_ELEM];
  num_load8(b, w);
  const uint32_t len = lb & 7u;
  return static_cast<uint64_t>(set_vch(b, len));
}

// Canonical serialization of (magnitude, sign): the exact wire bytes and
// length, packed by pack_enc.  Covers both sign branches: sign bit OR-ed into
// the top magnitude byte, and a fresh sign/zero byte when the top magnitude
// byte already has bit 7 set.
extern "C" uint64_t cell_encode(uint64_t mag64, uint32_t neg) {
  const uint32_t mag = static_cast<uint32_t>(mag64 & 0xffffffffULL);
  uint64_t packed = 0;
  const uint32_t n = serialize(value_of(mag, neg), packed);
  return pack_enc(n, packed);
}

// encode then decode: the identity on the domain (the sign bit is recovered,
// including the fresh-byte form for magnitudes whose top byte is >= 0x80).
extern "C" uint64_t cell_encode_decode(uint64_t mag64, uint32_t neg) {
  const uint32_t mag = static_cast<uint32_t>(mag64 & 0xffffffffULL);
  uint64_t packed = 0;
  const uint32_t n = serialize(value_of(mag, neg), packed);
  uint8_t b[NUM_MAX_ELEM];
  unpack8(b, packed);
  return static_cast<uint64_t>(set_vch(b, n));
}

// decode then encode: canonicalisation of an arbitrary 4-byte operand.  A
// negative-zero operand (0x80, 00 80, ...) decodes to 0 and re-encodes to the
// empty vector, so it is observable as length 0.
extern "C" uint64_t cell_roundtrip(uint64_t w, uint32_t lb) {
  uint8_t b[NUM_MAX_ELEM];
  num_load8(b, w);
  const uint32_t len = lb & 3u;
  uint64_t packed = 0;
  const uint32_t n = serialize(set_vch(b, len), packed);
  return pack_enc(n, packed);
}
