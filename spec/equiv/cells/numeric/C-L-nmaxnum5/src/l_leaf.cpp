#include <cstdint>

// L leg: reviewed transliteration of the pinned Lean model.
//
//   spec/core/Bitcoin/Numeric/Interface.lean:45-47
//     decodeScriptNum b minimal maxSize =
//       decodeBE minimal maxSize (bytesOf b).reverse
//   spec/core/Bitcoin/Numeric/ScriptNum.lean:628-631
//     decodeBE minimal maxSize l =
//       if l.length > maxSize then none
//       else if minimal && !minimalOkBE l then none
//       else some (setVchBE l)
//   spec/core/Bitcoin/Numeric/ScriptNum.lean (minimalOkBE)
//     minimalOkBE [] = true
//     minimalOkBE (d :: t) =
//       if d % 128 = 0 then (match t with [] => false | e :: _ => e >= 128)
//       else true
//   spec/core/Bitcoin/Numeric/ScriptNum.lean (setVchBE)
//     setVchBE [] = 0
//     setVchBE (d :: t) =
//       if d < 128 then ((d * 256^|t| + magOfBE t : Nat) : Int)
//       else -(((d - 128) * 256^|t| + magOfBE t : Nat) : Int)
//   spec/core/Bitcoin/Interpreter/Defs.lean:629-632
//     decodeNum pol b maxSize = match decodeScriptNum b pol.minimalData maxSize
//       with some n => .ok n | none => .error .scriptNum
//   spec/core/Bitcoin/Interpreter/Defs.lean:857-873
//     CLTV/CSV dispatchOp branches: decodeNum ctx.pol (topAt st.stack 1) 5,
//       then n < 0 -> .negativeLocktime, then (CSV) the disable-flag NOP,
//       then the checker.
//
// The wire bytes are little-endian, so the BE list is the reverse of the wire
// element: the BE head d is the *wire-last* byte and the BE tail t is the
// remaining wire bytes.  Length is bounded to 0..5 on every path that reads a
// byte (the width guard is first), and the byte walk is written as exact-length
// cases instead of the unsliced loop; magOfBE t is b0 + b1*256 + ...
//
// Observable identical to the C leg:
//   err(6) | value40(40) << 6 | outcome(2) << 46

#define BINLINE static inline __attribute__((always_inline))

namespace {

// Constant-index select over the bounded 5-byte element.
BINLINE uint8_t l_byte(const uint8_t b[5], uint32_t i) {
  return (i == 0) ? b[0] : (i == 1) ? b[1] : (i == 2) ? b[2]
       : (i == 3) ? b[3] : b[4];
}

// setVchBE (bytesOf b).reverse, exact-length cases.
// d = BE head (wire last byte), t = BE tail (wire bytes 0..n-2).
BINLINE int64_t l_set_vch_be(const uint8_t b[5], uint32_t n) {
  switch (n) {
    case 0:
      return 0;                                     // setVchBE [] = 0
    case 1: {                                       // d = b0, t = []
      const uint64_t d = b[0];
      const uint64_t mag = d & 0x7fu;               // (d % 128) * 256^0
      return (d < 128u) ? static_cast<int64_t>(mag)
                        : -static_cast<int64_t>(mag);
    }
    case 2: {                                       // d = b1, t = [b0]
      const uint64_t d = b[1];
      const uint64_t mag = (d & 0x7fu) * 256u + static_cast<uint64_t>(b[0]);
      return (d < 128u) ? static_cast<int64_t>(mag)
                        : -static_cast<int64_t>(mag);
    }
    case 3: {                                       // d = b2, t = [b1,b0]
      const uint64_t d = b[2];
      const uint64_t mag = (d & 0x7fu) * 65536u
                         + static_cast<uint64_t>(b[1]) * 256u
                         + static_cast<uint64_t>(b[0]);
      return (d < 128u) ? static_cast<int64_t>(mag)
                        : -static_cast<int64_t>(mag);
    }
    case 4: {                                       // d = b3, t = [b2,b1,b0]
      const uint64_t d = b[3];
      const uint64_t mag = (d & 0x7fu) * 16777216u
                         + static_cast<uint64_t>(b[2]) * 65536u
                         + static_cast<uint64_t>(b[1]) * 256u
                         + static_cast<uint64_t>(b[0]);
      return (d < 128u) ? static_cast<int64_t>(mag)
                        : -static_cast<int64_t>(mag);
    }
    default: {                                      // n == 5
      const uint64_t d = b[4];
      const uint64_t mag = (d & 0x7fu) * 4294967296ULL
                         + static_cast<uint64_t>(b[3]) * 16777216u
                         + static_cast<uint64_t>(b[2]) * 65536u
                         + static_cast<uint64_t>(b[1]) * 256u
                         + static_cast<uint64_t>(b[0]);
      return (d < 128u) ? static_cast<int64_t>(mag)
                        : -static_cast<int64_t>(mag);
    }
  }
}

// minimalOkBE (bytesOf b).reverse.
BINLINE bool l_minimal_ok_be(const uint8_t b[5], uint32_t n) {
  if (n == 0) return true;                          // minimalOkBE [] = true
  const uint8_t d = l_byte(b, n - 1);               // BE head = wire last
  if ((d & 0x7fu) != 0) return true;                // d % 128 != 0
  if (n <= 1) return false;                         // match t with [] => false
  return (l_byte(b, n - 2) & 0x80u) != 0;           // e >= 128
}

// decodeNum pol b maxSize (minimal = pol.minimalData); false = .error .scriptNum.
BINLINE bool l_decode(const uint8_t b[5], uint32_t n, uint32_t minimal,
                      uint32_t max_size, int64_t* out) {
  if (n > max_size) return false;                   // l.length > maxSize
  if (minimal && !l_minimal_ok_be(b, n)) return false;
  *out = l_set_vch_be(b, n);                        // some (setVchBE l)
  return true;
}

BINLINE uint64_t l_pack(uint32_t err, int64_t v, uint32_t outcome) {
  uint64_t r = static_cast<uint64_t>(err & 0x3fu);
  r |= (static_cast<uint64_t>(v) & 0xffffffffffULL) << 6;
  r |= static_cast<uint64_t>(outcome & 0x3u) << 46;
  return r;
}

}  // namespace

// Defs.lean:857-866 (wire 0xb1): decodeNum ... 5, negative-locktime, checker.
extern "C" uint64_t cell_cltv(uint32_t len, uint8_t b0, uint8_t b1, uint8_t b2,
                              uint8_t b3, uint8_t b4, uint32_t md) {
  const uint8_t b[5] = {b0, b1, b2, b3, b4};
  int64_t n = 0;
  if (!l_decode(b, len, md, 5, &n)) return l_pack(4, 0, 0);  // .scriptNum
  if (n < 0) return l_pack(21, n, 0);                        // .negativeLocktime
  return l_pack(0, n, 1);                        // checkLockTimeDef / .ok
}

// Defs.lean:868-875 (wire 0xb2): decodeNum ... 5, negative, disable flag,
// checkSequenceDef.
extern "C" uint64_t cell_csv(uint32_t len, uint8_t b0, uint8_t b1, uint8_t b2,
                             uint8_t b3, uint8_t b4, uint32_t md) {
  const uint8_t b[5] = {b0, b1, b2, b3, b4};
  int64_t n = 0;
  if (!l_decode(b, len, md, 5, &n)) return l_pack(4, 0, 0);  // .scriptNum
  if (n < 0) return l_pack(21, n, 0);                        // .negativeLocktime
  // (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) != 0 -> .ok st (NOP).
  if ((n & 0x80000000LL) != 0) return l_pack(0, n, 2);
  return l_pack(0, n, 1);                        // checkSequenceDef / .ok
}

// Width-4 control (decodeNum ... 4, the numeric-op default).  No Lean call
// site of this cell uses it; it exists only to prove the length-5 contrast.
extern "C" uint64_t cell_default4(uint32_t len, uint8_t b0, uint8_t b1,
                                  uint8_t b2, uint8_t b3, uint8_t b4,
                                  uint32_t md) {
  const uint8_t b[5] = {b0, b1, b2, b3, b4};
  int64_t n = 0;
  if (!l_decode(b, len, md, 4, &n)) return l_pack(4, 0, 0);
  return l_pack(0, n, 0);
}
