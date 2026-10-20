#include <cstdint>
// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
// OP_0 is a pushdata opcode (0 <= opcode <= OP_PUSHDATA4), so it takes the
// push branch at interpreter.cpp:499-503:
//     if (fExec && 0 <= opcode && opcode <= OP_PUSHDATA4) {
//         if (fRequireMinimal && !CheckMinimalPush(vchPushValue, opcode))
//             return set_error(SCRIPT_ERR_MINIMALDATA);
//         stack.push_back(vchPushValue);      // GetOp returned the empty vector
//     }
// OP_1NEGATE and OP_1..OP_16 take the switch at interpreter.cpp:527-546:
//     CScriptNum bn((int)opcode - (int)(OP_1 - 1));
//     stack.push_back(bn.getvch());
// OP_1 - 1 == 0x50, so OP_1NEGATE (0x4f) is -1 and OP_n is n.
// getvch() is CScriptNum::getvch (interpreter.cpp:415-427), canonical LE
// sign-magnitude; for this opcode range the value is -1..16, so the
// zero-length and multi-byte branches reduce to the closed form below.
//
// The cell also applies VerifyScript's EVAL_FALSE tail
// (interpreter.cpp:1876-1880): an empty top is EVAL_FALSE.

#define BINLINE static inline __attribute__((always_inline))

struct BStack { uint32_t n; uint32_t len[2]; uint8_t e[2][2]; };

// interpreter.cpp:415-427 getvch(), restricted to |v| <= 16.  Core's encoder
// is: |v| in little-endian magnitude, then a sign byte 0x80 appended if the
// top magnitude bit is set, else the sign bit ORed into the top byte.
BINLINE uint32_t core_getvch_small(int64_t v, uint8_t* out) {
  if (v == 0) return 0;
  const bool neg = v < 0;
  const uint64_t a = neg ? (static_cast<uint64_t>(-(v + 1)) + 1u)
                         : static_cast<uint64_t>(v);
  out[0] = static_cast<uint8_t>(a & 0xffu);
  if (out[0] & 0x80u) {
    out[1] = neg ? 0x80u : 0x00u;
    return 2;
  }
  if (neg) out[0] |= 0x80u;
  return 1;
}

BINLINE uint32_t core_push(BStack& s, const uint8_t* d, uint32_t l) {
  if (s.n >= 2) return 8;                    // SCRIPT_ERR_STACK_SIZE
  if (l > 2) return 6;                       // SCRIPT_ERR_PUSH_SIZE
  s.len[s.n] = l;
  s.e[s.n][0] = l > 0 ? d[0] : 0;
  s.e[s.n][1] = l > 1 ? d[1] : 0;
  s.n += 1;
  return 0;
}

BINLINE uint64_t c_pack(uint32_t res, uint32_t err, const BStack& s, uint32_t fin) {
  uint64_t r = 0;
  r |= static_cast<uint64_t>(res & 3u);
  r |= static_cast<uint64_t>(err & 0x3fu) << 2;
  r |= static_cast<uint64_t>(s.n & 3u) << 8;
  if (s.n > 0) {
    const uint32_t i = s.n - 1;
    r |= static_cast<uint64_t>(s.len[i] & 3u) << 10;
    r |= static_cast<uint64_t>(s.e[i][0]) << 12;
    r |= static_cast<uint64_t>(fin & 1u) << 20;
  }
  return r;
}

extern "C" uint64_t cell_pushnum(uint32_t sel, uint32_t minimalData) {
  // sel 0 -> OP_0; sel 1 -> OP_1NEGATE; sel 2..17 -> OP_1..OP_16.
  if (sel > 17) return 3;                    // out of cell domain
  const uint32_t wire = (sel == 0) ? 0x00u : (sel == 1) ? 0x4fu : (0x51u + sel - 2u);
  (void)minimalData;                         // no CheckMinimalPush on these paths
  BStack s{};
  uint8_t d[2] = {0, 0};
  uint32_t l = 0;
  if (wire == 0x00u) {
    l = 0;                                   // GetOp: OP_0 yields an empty vector
  } else {
    l = core_getvch_small(static_cast<int64_t>(wire) - 0x50, d);
  }
  const uint32_t e = core_push(s, d, l);
  if (e) return c_pack(0, e, s, 0);
  const uint32_t fin = (s.len[0] == 0) ? 0u
                     : ((s.e[0][0] == 0 || s.e[0][0] == 0x80) ? 0u : 1u);
  return c_pack(1, 0, s, fin);               // interpreter.cpp:1876-1880
}
