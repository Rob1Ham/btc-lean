#include <cstdint>

// C leg -- SCR-086: CScriptNum::getint() int32 clamp, isolated and at the
// OP_CHECKMULTISIG count call sites.
//
// Source of record: Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/script/script.h:326-333
//       int getint() const
//       {
//           if (m_value > std::numeric_limits<int>::max()) {
//               return std::numeric_limits<int>::max();
//           } else if (m_value < std::numeric_limits<int>::min()) {
//               return std::numeric_limits<int>::min();
//           }
//           return m_value;
//       }
//
//   src/script/interpreter.cpp:1126-1127, 1140-1142
//       int nKeysCount = CScriptNum(stacktop(-1), fRequireMinimal).getint();
//       int nSigsCount = CScriptNum(stacktop(-i), fRequireMinimal).getint();
//
//   src/script/script.h:246-271, 376-391
//       CScriptNum(vch, fRequireMinimal, nMaxNumSize = 4)
//       -> SCRIPT_ERR_SCRIPTNUM if vch.size() > 4
//       -> set_vch: little-endian sign-magnitude, top-byte 0x80 is the sign
//
// The clamp leaf is the exact Core function on an int64_t m_value.  It is
// deliberately independent of the decoder, so both firing arms (>INT_MAX and
// <INT_MIN) are reachable and proved, even though a 4-byte operand can never
// reach them.
//
// The CMS leaf decodes the two count operands exactly as the 4-byte
// CScriptNum constructor does (minimality is irrelevant to the clamp and is
// covered by push-encoding/C-L-w32-num-decode-minimal), applies getint(), and
// then executes the front-matter decision from interpreter.cpp:1122-1146 with
// Core's precedence order.  Both count operands are exactly four bytes: that
// is the widest value the call site accepts, so it is the boundary at which
// the clamp could first bind.
//
// Observable of cell_cms_counts4 (cell-local status codes, not contract
// ordinals; same packing as checkmultisig/C-L-cms-layout-sym):
//   status(3) | nKeys(5)<<3 | nSigs(5)<<8 | ikey2(6)<<13 | isig(6)<<19
// status: 0 ok, 1 pubkey_count, 2 op_count, 3 underflow, 4 sig_count.
// The derivation is widened to int64 in both legs: the EvalScript invariant
// is nOpCount <= 201 (interpreter.cpp:459-463), so this equals Core's `int`
// arithmetic on the cell domain and cannot overflow.

static inline int32_t core_getint(int64_t v) {          // script.h:326-333
  if (v > 2147483647LL) return 2147483647;
  if (v < -2147483648LL) return -2147483648;
  return static_cast<int32_t>(v);
}

// set_vch for a fixed four-byte little-endian operand (script.h:376-391).
// d3's 0x80 bit is the sign; the magnitude is the low 31 bits of d3 plus
// d0..d2.  (00 00 00 80 is negative zero and decodes to 0.)
static inline int64_t core_set_vch4(uint8_t d0, uint8_t d1, uint8_t d2,
                                    uint8_t d3) {
  const uint64_t mag = static_cast<uint64_t>(d0)
                     | (static_cast<uint64_t>(d1) << 8)
                     | (static_cast<uint64_t>(d2) << 16)
                     | (static_cast<uint64_t>(d3 & 0x7fu) << 24);
  return (d3 & 0x80u) ? -static_cast<int64_t>(mag)
                      : static_cast<int64_t>(mag);
}

static inline uint64_t cms_pack(uint32_t status, uint32_t nKeys,
                                uint32_t nSigs, uint32_t ikey2,
                                uint32_t isig) {
  return (uint64_t)(status & 7u)
       | ((uint64_t)(nKeys & 31u) << 3)
       | ((uint64_t)(nSigs & 31u) << 8)
       | ((uint64_t)(ikey2 & 63u) << 13)
       | ((uint64_t)(isig & 63u) << 19);
}

extern "C" int32_t cell_clamp_int32(int64_t x) {
  return core_getint(x);
}

extern "C" uint64_t cell_cms_counts4(uint8_t kb0, uint8_t kb1, uint8_t kb2,
                                     uint8_t kb3, uint8_t sb0, uint8_t sb1,
                                     uint8_t sb2, uint8_t sb3,
                                     uint32_t depth, uint32_t opCount) {
  // :1126-1127  nKeysCount is decoded first, then getint() clamps.
  const int32_t nKeysCount = core_getint(core_set_vch4(kb0, kb1, kb2, kb3));
  if (nKeysCount < 0 || nKeysCount > 20) {              // :1127-1128
    return cms_pack(1, 0, 0, 0, 0);                     // PUBKEY_COUNT
  }
  const int64_t nOpCount = (int64_t)opCount + nKeysCount;  // :1129
  if (nOpCount > 201) {                                 // :1130-1131
    return cms_pack(2, 0, 0, 0, 0);                     // OP_COUNT
  }
  // :1132-1138  ikey = ++i; ikey2 = nKeys + 2; i += nKeys; depth check.
  int64_t i = 1 + 1 + nKeysCount;
  const int64_t ikey2 = (int64_t)nKeysCount + 2;
  if ((int64_t)depth < i) return cms_pack(3, 0, 0, 0, 0);  // underflow
  // :1140-1142  nSigsCount is decoded only after the key-side depth check.
  const int32_t nSigsCount = core_getint(core_set_vch4(sb0, sb1, sb2, sb3));
  if (nSigsCount < 0 || nSigsCount > nKeysCount) {
    return cms_pack(4, 0, 0, 0, 0);                     // SIG_COUNT
  }
  // :1143-1146  isig = ++i; i += nSigs; depth check.
  i += 1;
  const int64_t isig = i;
  i += nSigsCount;
  if ((int64_t)depth < i) return cms_pack(3, 0, 0, 0, 0);  // underflow
  return cms_pack(0, (uint32_t)nKeysCount, (uint32_t)nSigsCount,
                  (uint32_t)ikey2, (uint32_t)isig);
}
