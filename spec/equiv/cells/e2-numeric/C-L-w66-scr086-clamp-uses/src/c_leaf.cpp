#include "w32_common.h"

// C leg -- SCR-086 ("clamp to int32 for depth/count uses", script.h:326-333)
// at every depth/count consumer.
//
// Source-excerpt slice of Bitcoin Core
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//
//   src/script/script.h:326-333
//       int CScriptNum::getint() const
//         if (m_value > INT_MAX) return INT_MAX;
//         else if (m_value < INT_MIN) return INT_MIN;
//         return m_value;
//   src/script/script.h:246-271
//       CScriptNum(vch, fRequireMinimal, nMaxNumSize=4)
//         size > 4                         -> throw scriptnum_error
//         fRequireMinimal && !minimal      -> throw scriptnum_error
//   src/script/script.h:376-391
//       set_vch: little-endian sign-magnitude
//   src/script/interpreter.cpp:833-849 (OP_PICK / OP_ROLL)
//       if (stack.size() < 2) return INVALID_STACK_OPERATION;
//       int n = CScriptNum(stacktop(-1), fRequireMinimal).getint();
//       popstack(stack);
//       if (n < 0 || n >= (int)stack.size()) return INVALID_STACK_OPERATION;
//       valtype vch = stacktop(-n-1);
//   src/script/interpreter.cpp:1122-1146 (OP_CHECKMULTISIG front matter)
//       int nKeysCount = CScriptNum(stacktop(-1), fRequireMinimal).getint();
//       int nSigsCount  = CScriptNum(stacktop(-i), fRequireMinimal).getint();
//
// Five leaves, all loop-free and scalar (no script bytecode is executed):
//
//   cell_clamp_int32      Core getint() on an arbitrary int64 m_value.  Both
//                         firing arms are reachable here.
//   cell_depth_read       the OP_PICK/OP_ROLL depth read for an arbitrary
//                         operand (length 0.., four bytes, both minimal-data
//                         settings), arbitrary pre-pop stack depth and the
//                         post-pop guard/index.
//   cell_cms_key_count    the CHECKMULTISIG nKeysCount read and the
//                         PUBKEY_COUNT / OP_COUNT arms.
//   cell_cms_sig_prefix   the same key-side read in the nSigsCount path,
//                         including the key-side depth gate.
//   cell_cms_sig_read     the nSigsCount read and its gates, given the
//                         decoded key count from the prefix leaf.
//
// The nSigsCount path is split at the signature read only so that each leaf
// contains one decode; spec.md records the (trivial) composition.
//
// The clamp is a pure function of the decoded operand, applied before any
// stack movement.  The OP_ROLL stack-shift loop is downstream of the value
// these leaves expose and is not part of SCR-086 (it is SCR-075).
//
// Domain notes (stated in spec.md):
//   * 0 <= depth <= 1000 (MAX_STACK_SIZE, script.h:44) and
//     0 <= opCount <= 201 (MAX_OPS_PER_SCRIPT, script.h:32) at opcode entry;
//     out-of-domain values return a distinct sentinel so the leaves are total.
//   * fRequireMinimal is the bool derived from the MINIMALDATA flag; any
//     nonzero `minimal` models it.

// -- getint (script.h:326-333), exact Core function on int64_t.
static inline __attribute__((always_inline)) int32_t core_getint(int64_t v) {
  if (v > 2147483647LL) return 2147483647;
  if (v < -2147483648LL) return -2147483648;
  return static_cast<int32_t>(v);
}

// -- set_vch (script.h:376-391), scalar form for len <= 4.  Reads use
//    constants only, so the extracted IR has no symbolic-index memory access.
static inline __attribute__((always_inline)) uint8_t last_byte(uint32_t len, uint8_t b0, uint8_t b1,
                                uint8_t b2, uint8_t b3) {
  return (len == 1) ? b0 : (len == 2) ? b1 : (len == 3) ? b2 : b3;
}
static inline __attribute__((always_inline)) int64_t core_set_vch(uint32_t len, uint8_t b0, uint8_t b1,
                                   uint8_t b2, uint8_t b3) {
  if (len == 0) return 0;
  uint64_t result = b0;
  if (len >= 2) result |= static_cast<uint64_t>(b1) << 8;
  if (len >= 3) result |= static_cast<uint64_t>(b2) << 16;
  if (len >= 4) result |= static_cast<uint64_t>(b3) << 24;
  if (last_byte(len, b0, b1, b2, b3) & 0x80u) {
    const uint32_t sh = 8u * (len - 1u);
    result &= ~(0x80ull << sh);
    return -static_cast<int64_t>(result);
  }
  return static_cast<int64_t>(result);
}

// -- minimal-encoding check (script.h:252-268), scalar form.
static inline __attribute__((always_inline)) bool core_minimal_fail(uint32_t len, uint8_t b0, uint8_t b1,
                                     uint8_t b2, uint8_t b3) {
  if (len == 0) return false;
  const uint8_t last = last_byte(len, b0, b1, b2, b3);
  if ((last & 0x7fu) != 0) return false;
  if (len <= 1) return true;
  const uint8_t second = (len == 2) ? b0 : (len == 3) ? b1 : b2;
  return (second & 0x80u) == 0;
}

static inline uint64_t depth_pack(uint32_t status, uint32_t err, uint32_t idx,
                                  int32_t n) {
  return (uint64_t)(status & 3u)
       | ((uint64_t)(err & 0x3fu) << 2)
       | ((uint64_t)(idx & 0xffffu) << 8)
       | ((uint64_t)static_cast<uint32_t>(n) << 24);
}

// ---------------------------------------------------------------------------
// cell_clamp_int32: script.h:326-333 on an arbitrary int64_t.
extern "C" int32_t cell_clamp_int32(int64_t x) {
  return core_getint(x);
}

// ---------------------------------------------------------------------------
// cell_depth_read: the OP_PICK/OP_ROLL depth read (interpreter.cpp:838-844).
// status 0 = ok, 1 = SCRIPTNUM (width/minimal), 2 = INVALID_STACK_OPERATION,
// 3 = out of the stated depth domain.  `idx` is stacktop(-n-1)'s index after
// the pop; n is the clamped depth value.
extern "C" uint64_t cell_depth_read(uint32_t len, uint8_t b0, uint8_t b1,
                                    uint8_t b2, uint8_t b3, uint8_t b4,
                                    uint32_t depth, uint32_t minimal) {
  (void)b4;  // len > 4 is rejected before any byte is read
  if (depth > 1000u) return depth_pack(3, 0, 0, 0);   // MAX_STACK_SIZE
  if (depth < 2u) return depth_pack(2, 18, 0, 0);     // :838-839
  if (len > 4u) return depth_pack(1, 4, 0, 0);        // script.h:249-251
  if (minimal != 0u && core_minimal_fail(len, b0, b1, b2, b3))
    return depth_pack(1, 4, 0, 0);                    // script.h:252-268
  const int32_t n = core_getint(core_set_vch(len, b0, b1, b2, b3));
  const uint32_t m = depth - 1u;                      // popstack
  if (n < 0 || static_cast<uint32_t>(n) >= m)
    return depth_pack(2, 18, 0, 0);                   // :842-843
  const uint32_t idx = m - 1u - static_cast<uint32_t>(n);  // :844
  return depth_pack(0, 0, idx, n);
}

// ---------------------------------------------------------------------------
// CHECKMULTISIG front matter (interpreter.cpp:1122-1146).
// key_pack: status(3) | nKeys32(32)<<3 | ikey2(6)<<35
// status 0 ok, 1 PUBKEY_COUNT, 2 OP_COUNT, 5 SCRIPTNUM, 7 out of domain.
static inline uint64_t key_pack(uint32_t status, int32_t n, uint32_t ikey2) {
  return (uint64_t)(status & 7u)
       | ((uint64_t)static_cast<uint32_t>(n) << 3)
       | ((uint64_t)(ikey2 & 0x3fu) << 35);
}

// sig_pack: status(3) | nSigs32(32)<<3 | ikey2(6)<<35 | isig(6)<<41 |
//           nKeys(5)<<47
// status 0 ok, 1 PUBKEY_COUNT, 2 OP_COUNT, 3 underflow, 4 SIG_COUNT,
// 5 SCRIPTNUM, 7 out of domain.
static inline uint64_t sig_pack(uint32_t status, int32_t ns, uint32_t ikey2,
                                uint32_t isig, uint32_t nkeys) {
  return (uint64_t)(status & 7u)
       | ((uint64_t)static_cast<uint32_t>(ns) << 3)
       | ((uint64_t)(ikey2 & 0x3fu) << 35)
       | ((uint64_t)(isig & 0x3fu) << 41)
       | ((uint64_t)(nkeys & 0x1fu) << 47);
}

extern "C" uint64_t cell_cms_key_count(uint32_t len, uint8_t b0, uint8_t b1,
                                       uint8_t b2, uint8_t b3,
                                       uint32_t opCount, uint32_t minimal) {
  if (opCount > 201u) return key_pack(7, 0, 0);       // MAX_OPS_PER_SCRIPT
  if (len > 4u) return key_pack(5, 0, 0);
  if (minimal != 0u && core_minimal_fail(len, b0, b1, b2, b3))
    return key_pack(5, 0, 0);
  const int32_t nKeysCount = core_getint(core_set_vch(len, b0, b1, b2, b3));
  if (nKeysCount < 0 || nKeysCount > 20)              // :1127-1128
    return key_pack(1, nKeysCount, 0);
  const int64_t nOpCount = static_cast<int64_t>(opCount) + nKeysCount;
  if (nOpCount > 201)                                 // :1129-1131
    return key_pack(2, nKeysCount, 0);
  return key_pack(0, nKeysCount,
                  static_cast<uint32_t>(nKeysCount) + 2u);  // ikey2 :1136
}

// CHECKMULTISIG nSigsCount path, split at the signature read so each leaf has
// a single decode and a small solver query.  `cell_cms_sig_prefix` is Core
// :1126-1138 plus the key-side depth gate; status 0 means "reached the
// nSigsCount read" and the pack carries the decoded key count and ikey2.
// `cell_cms_sig_read` is Core :1140-1146 given that decoded key count.  The
// composition is argued in spec.md: prefix status != 0 is the full result,
// otherwise the full result is the read leaf on the prefix's (nk, depth).
//
// Cursor arithmetic in these two leaves is uint32.  Core's `int i` is exact
// on the reachable key-count domain 0..20; the read leaf's explicit
// out-of-domain arm keeps it total, and both legs and the oracle use the
// same modular form (the composition never enters that arm).
extern "C" uint64_t cell_cms_sig_prefix(uint32_t lk, uint8_t kb0, uint8_t kb1,
                                        uint8_t kb2, uint8_t kb3,
                                        uint32_t depth, uint32_t opCount,
                                        uint32_t minimal) {
  if (depth > 1000u || opCount > 201u) return sig_pack(7, 0, 0, 0, 0);
  if (lk > 4u) return sig_pack(5, 0, 0, 0, 0);
  if (minimal != 0u && core_minimal_fail(lk, kb0, kb1, kb2, kb3))
    return sig_pack(5, 0, 0, 0, 0);
  const int32_t nk = core_getint(core_set_vch(lk, kb0, kb1, kb2, kb3));
  if (nk < 0 || nk > 20) return sig_pack(1, 0, 0, 0, static_cast<uint32_t>(nk));
  const int64_t total = static_cast<int64_t>(opCount) + nk;
  if (total > 201) return sig_pack(2, 0, 0, 0, static_cast<uint32_t>(nk));
  const uint32_t ikey2 = static_cast<uint32_t>(nk) + 2u;
  const uint32_t i = 2u + static_cast<uint32_t>(nk);   // i = 1; ++i; i += nk
  if (depth < i) return sig_pack(3, 0, ikey2, 0, static_cast<uint32_t>(nk));
  return sig_pack(0, 0, ikey2, 0, static_cast<uint32_t>(nk));  // reached read
}

extern "C" uint64_t cell_cms_sig_read(int32_t nk, uint32_t depth, uint32_t ls,
                                      uint8_t sb0, uint8_t sb1, uint8_t sb2,
                                      uint8_t sb3, uint32_t minimal) {
  // Only reached from the prefix with 0 <= nk <= 20; other values are the
  // unreachable-state domain arm (same on both legs).
  if (nk < 0 || nk > 20) return sig_pack(7, 0, 0, 0, 0);
  const uint32_t ikey2 = static_cast<uint32_t>(nk) + 2u;
  const uint32_t unk = static_cast<uint32_t>(nk);
  if (ls > 4u) return sig_pack(5, 0, ikey2, 0, unk);
  if (minimal != 0u && core_minimal_fail(ls, sb0, sb1, sb2, sb3))
    return sig_pack(5, 0, ikey2, 0, unk);
  const int32_t ns = core_getint(core_set_vch(ls, sb0, sb1, sb2, sb3));
  if (ns < 0 || ns > nk) return sig_pack(4, ns, ikey2, 0, unk);
  const uint32_t isig = 3u + unk;                      // isig = ++i
  if (depth < isig + static_cast<uint32_t>(ns))
    return sig_pack(3, ns, ikey2, isig, unk);
  return sig_pack(0, ns, ikey2, isig, unk);
}
