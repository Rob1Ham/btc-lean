#include <cstdint>

// C leg: source-excerpt slice of Bitcoin Core @
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/script/interpreter.cpp:556
//     const CScriptNum nLockTime(stacktop(-1), fRequireMinimal, 5);
//   src/script/interpreter.cpp:561-562
//     if (nLockTime < 0) return set_error(serror, SCRIPT_ERR_NEGATIVE_LOCKTIME);
//   src/script/interpreter.cpp:565-566
//     if (!checker.CheckLockTime(nLockTime)) ...   [comparison is SCR-124]
//   src/script/interpreter.cpp:584
//     const CScriptNum nSequence(stacktop(-1), fRequireMinimal, 5);
//   src/script/interpreter.cpp:589-590
//     if (nSequence < 0) return set_error(serror, SCRIPT_ERR_NEGATIVE_LOCKTIME);
//   src/script/interpreter.cpp:595-596
//     if ((nSequence & CTxIn::SEQUENCE_LOCKTIME_DISABLE_FLAG) != 0) break;
//   src/script/interpreter.cpp:599-600
//     if (!checker.CheckSequence(nSequence)) ...    [comparison is SCR-129]
//   src/script/interpreter.cpp:1236-1238
//     catch (const scriptnum_error&) { return set_error(serror,
//                                          SCRIPT_ERR_SCRIPTNUM); }
//   src/script/script.h:246-271
//     CScriptNum(vch, fRequireMinimal, nMaxNumSize)
//       if (vch.size() > nMaxNumSize) throw scriptnum_error(...);
//       if (fRequireMinimal && vch.size() > 0 && (vch.back() & 0x7f) == 0 &&
//           (vch.size() <= 1 || (vch[vch.size()-2] & 0x80) == 0))
//         throw scriptnum_error(...);
//       m_value = set_vch(vch);
//   src/script/script.h:376-391  set_vch (LE sign-magnitude)
//   src/script/interpreter.cpp:442  fRequireMinimal = flags & MINIMALDATA
//   src/primitives/transaction.h:94  SEQUENCE_LOCKTIME_DISABLE_FLAG = 1u << 31
//
// The real CScriptNum owns a std::vector and throws; here the vector is the
// bounded 5-byte element of the leaf and the throw is the error return that
// EvalScript's catch block turns into SCRIPT_ERR_SCRIPTNUM (4).  Length is a
// symbolic uint32, so lengths above 5 are covered by the width guard, which
// runs before any byte is read.  Every dynamic index/shift of the unsliced
// function is written as an explicit constant case; no semantics change.
//
// Observable (packed into uint64):
//   err(6) | value40(40) << 6 | outcome(2) << 46
// value40 is the two's-complement 40-bit pattern of the decoded CScriptNum;
// it is observable for every successful decode, including the negative-locktime
// branch.  outcome: 0 = no further execution (error), 1 = continue to the
// CheckLockTime/CheckSequence call, 2 = CSV disable-flag NOP.

#define BINLINE static inline __attribute__((always_inline))

namespace {

// Constant-index select over the bounded 5-byte element.  Stands in for
// vch.back() / vch[vch.size()-2]; exact for i <= 4.
BINLINE uint8_t c_byte(const uint8_t b[5], uint32_t i) {
  return (i == 0) ? b[0] : (i == 1) ? b[1] : (i == 2) ? b[2]
       : (i == 3) ? b[3] : b[4];
}
BINLINE uint8_t c_top(const uint8_t b[5], uint32_t n) {
  return c_byte(b, n - 1);                    // vch.back()
}
BINLINE uint8_t c_prev(const uint8_t b[5], uint32_t n) {
  return c_byte(b, n - 2);                    // vch[vch.size()-2]
}

// script.h:376-391 set_vch, by exact length (n <= 5 on every legal call).
BINLINE int64_t c_set_vch(const uint8_t b[5], uint32_t n) {
  switch (n) {
    case 0:
      return 0;                               // if (vch.empty()) return 0
    case 1: {
      const int64_t m = static_cast<int64_t>(b[0]) & 0x7f;
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
    case 4: {
      const int64_t m = static_cast<int64_t>(b[0]) |
                        (static_cast<int64_t>(b[1]) << 8) |
                        (static_cast<int64_t>(b[2]) << 16) |
                        (static_cast<int64_t>(b[3] & 0x7fu) << 24);
      return (b[3] & 0x80u) ? -m : m;
    }
    default: {                                // n == 5
      const int64_t m = static_cast<int64_t>(b[0]) |
                        (static_cast<int64_t>(b[1]) << 8) |
                        (static_cast<int64_t>(b[2]) << 16) |
                        (static_cast<int64_t>(b[3]) << 24) |
                        (static_cast<int64_t>(b[4] & 0x7fu) << 32);
      return (b[4] & 0x80u) ? -m : m;
    }
  }
}

// script.h:246-271 CScriptNum(vch, fRequireMinimal, nMaxNumSize).
// Returns 0 on success, EQUIV_ERR_SCRIPTNUM (4) on scriptnum_error.
BINLINE uint32_t c_decode(const uint8_t b[5], uint32_t n, uint32_t md,
                          uint32_t max_num, int64_t* out) {
  if (n > max_num) return 4;                  // script number overflow
  if (md && n > 0) {                          // fRequireMinimal
    if ((c_top(b, n) & 0x7fu) == 0) {
      if (n <= 1 || (c_prev(b, n) & 0x80u) == 0) return 4;
    }
  }
  *out = c_set_vch(b, n);
  return 0;
}

BINLINE uint64_t c_pack(uint32_t err, int64_t v, uint32_t outcome) {
  uint64_t r = static_cast<uint64_t>(err & 0x3fu);
  r |= (static_cast<uint64_t>(v) & 0xffffffffffULL) << 6;
  r |= static_cast<uint64_t>(outcome & 0x3u) << 46;
  return r;
}

}  // namespace

// interpreter.cpp:556 + 561-562 + "proceeds to CheckLockTime" (565).
extern "C" uint64_t cell_cltv(uint32_t len, uint8_t b0, uint8_t b1, uint8_t b2,
                              uint8_t b3, uint8_t b4, uint32_t md) {
  const uint8_t b[5] = {b0, b1, b2, b3, b4};
  int64_t nLockTime = 0;
  const uint32_t err = c_decode(b, len, md, 5, &nLockTime);
  if (err != 0) return c_pack(err, 0, 0);     // catch -> SCRIPT_ERR_SCRIPTNUM
  if (nLockTime < 0) return c_pack(21, nLockTime, 0);  // NEGATIVE_LOCKTIME
  return c_pack(0, nLockTime, 1);             // continues to CheckLockTime
}

// interpreter.cpp:584 + 589-590 + 595-596 + 599.
extern "C" uint64_t cell_csv(uint32_t len, uint8_t b0, uint8_t b1, uint8_t b2,
                             uint8_t b3, uint8_t b4, uint32_t md) {
  const uint8_t b[5] = {b0, b1, b2, b3, b4};
  int64_t nSequence = 0;
  const uint32_t err = c_decode(b, len, md, 5, &nSequence);
  if (err != 0) return c_pack(err, 0, 0);     // catch -> SCRIPT_ERR_SCRIPTNUM
  if (nSequence < 0) return c_pack(21, nSequence, 0);   // NEGATIVE_LOCKTIME
  // CTxIn::SEQUENCE_LOCKTIME_DISABLE_FLAG (1u << 31), script.h:287 operator&.
  if ((nSequence & 0x80000000LL) != 0) return c_pack(0, nSequence, 2);  // NOP
  return c_pack(0, nSequence, 1);             // continues to CheckSequence
}

// Control leg for the "special case": the default 4-byte CScriptNum decode
// (script.h:242 nDefaultMaxNumSize = 4) applied to the same operand, so that
// the length-5 contrast is proved rather than asserted.  SCR-079/080 own the
// width-4 row; this entry point claims no coverage for it.
extern "C" uint64_t cell_default4(uint32_t len, uint8_t b0, uint8_t b1,
                                  uint8_t b2, uint8_t b3, uint8_t b4,
                                  uint32_t md) {
  const uint8_t b[5] = {b0, b1, b2, b3, b4};
  int64_t v = 0;
  const uint32_t err = c_decode(b, len, md, 4, &v);
  if (err != 0) return c_pack(err, 0, 0);
  return c_pack(0, v, 0);
}
