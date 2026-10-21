#ifndef EQUIV_WAVE16_NUM_CORE_H
#define EQUIV_WAVE16_NUM_CORE_H
#include <cstdint>
#include <cstddef>
#include "num_common.h"
#include "error_kind.h"

// C leg shared excerpt: Bitcoin Core's CScriptNum and the stack primitives the
// numeric case blocks use.
//
// Source of record: bitcoin/bitcoin @ cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
//   src/script/script.h:227-394   CScriptNum (constructor, set_vch, serialize)
//   src/script/interpreter.cpp:109-124  stacktop()/popstack()
//
// The excerpt is a transcription, not an inclusion of the real headers: the
// real CScriptNum owns a std::vector and throws (scriptnum_error), which the
// bounded leaf cannot model.  Every branch below is line-cited at its site and
// each deviation is listed in the cell notes: (1) the vector is a bounded
// (value,len) pair, (2) the throw becomes an error return carrying
// EQUIV_ERR_SCRIPTNUM, which is what EvalScript's catch block sets
// (interpreter.cpp:432-437), (3) the loops are unrolled to the 8-byte element.
namespace core {

struct Stack {
  uint32_t n;
  uint32_t len[NUM_MAX_DEPTH];
  uint8_t e[NUM_MAX_DEPTH][NUM_MAX_ELEM];
};

// script.h:376-391 set_vch, with `vch.back()` replaced by a constant-index
// select over the bounded element (num_byte).
static inline __attribute__((always_inline)) int64_t set_vch(const uint8_t* vch,
                                                             uint32_t len) {
  if (len == 0) return 0;                        // script.h:378-379
  int64_t result = 0;
  if (len >= 1) result |= static_cast<int64_t>(vch[0]);          // :382-383
  if (len >= 2) result |= static_cast<int64_t>(vch[1]) << 8;
  if (len >= 3) result |= static_cast<int64_t>(vch[2]) << 16;
  if (len >= 4) result |= static_cast<int64_t>(vch[3]) << 24;
  if (len >= 5) result |= static_cast<int64_t>(vch[4]) << 32;
  if (len >= 6) result |= static_cast<int64_t>(vch[5]) << 40;
  if (len >= 7) result |= static_cast<int64_t>(vch[6]) << 48;
  if (len >= 8) result |= static_cast<int64_t>(vch[7]) << 56;
  const uint32_t top = num_byte(vch, len - 1);
  if ((top & 0x80u) != 0) {                      // script.h:386-388
    // ~(0x80ULL << (8*(len-1))) as a constant select chain: a symbolic shift
    // amount makes the leaf needlessly hard for Alive2/SAW and is not part of
    // the semantics.
    const uint64_t mask = (len == 1) ? 0xffffffffffffff7fULL
                        : (len == 2) ? 0xffffffffffff7fffULL
                        : (len == 3) ? 0xffffffffff7fffffULL
                        : (len == 4) ? 0xffffffff7fffffffULL
                        : (len == 5) ? 0xffffff7fffffffffULL
                        : (len == 6) ? 0xffff7fffffffffffULL
                        : (len == 7) ? 0xff7fffffffffffffULL
                                     : 0x7fffffffffffffffULL;
    return -static_cast<int64_t>(static_cast<uint64_t>(result) & mask);
  }
  return result;
}

// script.h:246-271 CScriptNum(vch, fRequireMinimal, nMaxNumSize).  Returns
// true on success; on failure `err` is EQUIV_ERR_SCRIPTNUM (the error
// EvalScript's catch sets for scriptnum_error, interpreter.cpp:432-437).
static inline __attribute__((always_inline)) bool decode_num(const uint8_t* vch,
                                                             uint32_t len,
                                                             bool fRequireMinimal,
                                                             uint32_t maxnum,
                                                             int64_t& out,
                                                             uint32_t& err) {
  if (len > maxnum) {                            // script.h:247-249
    err = EQUIV_ERR_SCRIPTNUM;
    return false;
  }
  if (fRequireMinimal && len > 0) {              // script.h:250-268
    const uint32_t top = num_byte(vch, len - 1);
    if ((top & 0x7fu) == 0) {
      const uint32_t second = num_byte(vch, len - 2);
      if (len <= 1 || (second & 0x80u) == 0) {
        err = EQUIV_ERR_SCRIPTNUM;
        return false;
      }
    }
  }
  out = set_vch(vch, len);
  return true;
}

// script.h:342-373 CScriptNum::serialize, while loop unrolled.
//
// The real body writes through `out[n++]` and then reads `out[n-1]`, i.e.
// through a symbolic index.  That one symbolic GEP is what keeps the caller's
// scratch array in memory and turns Alive2's UB query into a quantified
// formula over block addresses (see the wave-16 report).  The bytes are
// unchanged; they are assembled here in a little-endian uint64 so every access
// has a constant index.  Domain: the numeric cells pass |value| < 2^33, so at
// most 5 bytes are produced; the 8-byte case is unrolled for completeness.
static inline __attribute__((always_inline)) uint32_t serialize(int64_t value,
                                                               uint64_t& packed) {
  packed = 0;
  if (value == 0) return 0;                      // script.h:344-345
  const bool neg = value < 0;
  uint64_t a = neg ? static_cast<uint64_t>(-(value + 1)) + 1u
                   : static_cast<uint64_t>(value);
  uint8_t b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0, b7 = 0;
  uint32_t n = 0;
  if (a != 0) { b0 = static_cast<uint8_t>(a & 0xffu); n = 1; a >>= 8; }
  if (a != 0) { b1 = static_cast<uint8_t>(a & 0xffu); n = 2; a >>= 8; }
  if (a != 0) { b2 = static_cast<uint8_t>(a & 0xffu); n = 3; a >>= 8; }
  if (a != 0) { b3 = static_cast<uint8_t>(a & 0xffu); n = 4; a >>= 8; }
  if (a != 0) { b4 = static_cast<uint8_t>(a & 0xffu); n = 5; a >>= 8; }
  if (a != 0) { b5 = static_cast<uint8_t>(a & 0xffu); n = 6; a >>= 8; }
  if (a != 0) { b6 = static_cast<uint8_t>(a & 0xffu); n = 7; a >>= 8; }
  if (a != 0) { b7 = static_cast<uint8_t>(a & 0xffu); n = 8; a >>= 8; }
  const uint8_t last = (n == 1) ? b0 : (n == 2) ? b1 : (n == 3) ? b2 :
                       (n == 4) ? b3 : (n == 5) ? b4 : (n == 6) ? b5 :
                       (n == 7) ? b6 : b7;
  if ((last & 0x80u) != 0) {                     // script.h:365-369
    const uint8_t sgn = neg ? 0x80u : 0x00u;
    if (n == 1) b1 = sgn;
    else if (n == 2) b2 = sgn;
    else if (n == 3) b3 = sgn;
    else if (n == 4) b4 = sgn;
    else if (n == 5) b5 = sgn;
    else if (n == 6) b6 = sgn;
    else b7 = sgn;
    n += 1;
  } else if (neg) {
    if (n == 1) b0 = static_cast<uint8_t>(b0 | 0x80u);
    else if (n == 2) b1 = static_cast<uint8_t>(b1 | 0x80u);
    else if (n == 3) b2 = static_cast<uint8_t>(b2 | 0x80u);
    else if (n == 4) b3 = static_cast<uint8_t>(b3 | 0x80u);
    else if (n == 5) b4 = static_cast<uint8_t>(b4 | 0x80u);
    else if (n == 6) b5 = static_cast<uint8_t>(b5 | 0x80u);
    else if (n == 7) b6 = static_cast<uint8_t>(b6 | 0x80u);
    else b7 = static_cast<uint8_t>(b7 | 0x80u);
  }
  packed = static_cast<uint64_t>(b0)
         | (static_cast<uint64_t>(b1) << 8)  | (static_cast<uint64_t>(b2) << 16)
         | (static_cast<uint64_t>(b3) << 24) | (static_cast<uint64_t>(b4) << 32)
         | (static_cast<uint64_t>(b5) << 40) | (static_cast<uint64_t>(b6) << 48)
         | (static_cast<uint64_t>(b7) << 56);
  return n;
}

// interpreter.cpp:109-124 stacktop()/popstack() plus the vector push_back.
static inline __attribute__((always_inline)) const uint8_t* stacktop(
    const Stack& s, uint32_t k, uint32_t& len) {
  const uint32_t i = s.n - k;                    // stacktop(-k)
  len = s.len[i];
  return s.e[i];
}

static inline __attribute__((always_inline)) uint32_t push(Stack& s,
                                                           const uint8_t* d,
                                                           uint32_t len) {
  if (len > NUM_MAX_ELEM) return EQUIV_ERR_PUSH_SIZE;  // bounded stand-in
  if (s.n >= NUM_MAX_DEPTH) return EQUIV_ERR_STACK_SIZE;
  s.len[s.n] = len;
  if (len >= 1) s.e[s.n][0] = d[0];
  if (len >= 2) s.e[s.n][1] = d[1];
  if (len >= 3) s.e[s.n][2] = d[2];
  if (len >= 4) s.e[s.n][3] = d[3];
  if (len >= 5) s.e[s.n][4] = d[4];
  if (len >= 6) s.e[s.n][5] = d[5];
  if (len >= 7) s.e[s.n][6] = d[6];
  if (len >= 8) s.e[s.n][7] = d[7];
  s.n += 1;
  return 0;
}

// script.h:337-340 getvch() -> serialize(m_value); interpreter.cpp:955-1010
// `stack.push_back(bn.getvch())`.  push_num takes the serialization packed
// into a little-endian word (see serialize) so no scratch array is needed.
static inline __attribute__((always_inline)) uint32_t push_packed(Stack& s,
                                                                  uint64_t packed,
                                                                  uint32_t len) {
  if (len > NUM_MAX_ELEM) return EQUIV_ERR_PUSH_SIZE;  // bounded stand-in
  if (s.n >= NUM_MAX_DEPTH) return EQUIV_ERR_STACK_SIZE;
  s.len[s.n] = len;
  if (len >= 1) s.e[s.n][0] = static_cast<uint8_t>(packed);
  if (len >= 2) s.e[s.n][1] = static_cast<uint8_t>(packed >> 8);
  if (len >= 3) s.e[s.n][2] = static_cast<uint8_t>(packed >> 16);
  if (len >= 4) s.e[s.n][3] = static_cast<uint8_t>(packed >> 24);
  if (len >= 5) s.e[s.n][4] = static_cast<uint8_t>(packed >> 32);
  if (len >= 6) s.e[s.n][5] = static_cast<uint8_t>(packed >> 40);
  if (len >= 7) s.e[s.n][6] = static_cast<uint8_t>(packed >> 48);
  if (len >= 8) s.e[s.n][7] = static_cast<uint8_t>(packed >> 56);
  s.n += 1;
  return 0;
}

static inline __attribute__((always_inline)) uint32_t push_num(Stack& s,
                                                               int64_t v) {
  uint64_t packed = 0;
  const uint32_t n = serialize(v, packed);
  return push_packed(s, packed, n);
}

// interpreter.cpp:46-59 CastToBool, unrolled to the 8-byte element.
static inline __attribute__((always_inline)) bool cast_to_bool(
    const uint8_t* d, uint32_t len) {
  if (len >= 1 && d[0] != 0) return !(len == 1 && d[0] == 0x80);
  if (len >= 2 && d[1] != 0) return !(len == 2 && d[1] == 0x80);
  if (len >= 3 && d[2] != 0) return !(len == 3 && d[2] == 0x80);
  if (len >= 4 && d[3] != 0) return !(len == 4 && d[3] == 0x80);
  if (len >= 5 && d[4] != 0) return !(len == 5 && d[4] == 0x80);
  if (len >= 6 && d[5] != 0) return !(len == 6 && d[5] == 0x80);
  if (len >= 7 && d[6] != 0) return !(len == 7 && d[6] == 0x80);
  if (len >= 8 && d[7] != 0) return !(len == 8 && d[7] == 0x80);
  return false;
}

}  // namespace core
#endif  // EQUIV_WAVE16_NUM_CORE_H
