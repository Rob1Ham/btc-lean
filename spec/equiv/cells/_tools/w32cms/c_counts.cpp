// Wave-32 CHECKMULTISIG counts cell -- C leg (SCR-114).
//
// Line-cited slice of Bitcoin Core v32.99
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, src/script/interpreter.cpp
// OP_CHECKMULTISIG / OP_CHECKMULTISIGVERIFY argument prelude (1122-1146):
//   * first stack-depth check (stack.size() < i, i = 1);
//   * CScriptNum decode of nKeys (4-byte limit, fRequireMinimal = false);
//   * nKeys < 0 || nKeys > MAX_PUBKEYS_PER_MULTISIG (20)
//       -> SCRIPT_ERR_PUBKEY_COUNT;
//   * nOpCount += nKeys; nOpCount > MAX_OPS_PER_SCRIPT (201)
//       -> SCRIPT_ERR_OP_COUNT;
//   * second stack-depth check (i = nKeys + 2);
//   * CScriptNum decode of nSigs (4-byte limit);
//   * nSigs < 0 || nSigs > nKeys -> SCRIPT_ERR_SIG_COUNT;
//   * third stack-depth check (i = nKeys + nSigs + 3).
//
// The observable is the prelude result: (result, error, nKeys, nSigs,
// opCount, stack depth).  The loop body that runs after a successful
// prelude is outside this cell (SCR-116/117 cells).
#include "e32_common.h"

// Core's CScriptNum(vch, fRequireMinimal=false, nMaxNumSize=4):
// scriptnum_error if vch.size() > 4; otherwise little-endian sign-magnitude.
E32INLINE bool core_decode_num(uint64_t e, int64_t& out) {
  const uint32_t len = e32_len(e);
  if (len > 4u) return false;
  if (len == 0u) { out = 0; return true; }
  uint64_t v = 0;
  if (len >= 1u) v |= (uint64_t)e32_byte(e, 0);
  if (len >= 2u) v |= (uint64_t)e32_byte(e, 1) << 8;
  if (len >= 3u) v |= (uint64_t)e32_byte(e, 2) << 16;
  if (len >= 4u) v |= (uint64_t)e32_byte(e, 3) << 24;
  if ((e32_byte(e, len - 1u) & 0x80u) != 0u)
    out = -(int64_t)(v & ~((uint64_t)0x80u << (8u * (len - 1u))));
  else
    out = (int64_t)v;
  return true;
}

E32INLINE uint64_t core_counts(uint64_t n_raw, uint64_t keys_enc,
                               uint64_t sigs_enc, uint64_t ops_before_raw) {
  const uint32_t n = (uint32_t)n_raw;
  // interpreter.cpp:1123-1124 -- i = 1 depth check.
  if (n < 1u) return e32_err(EQUIV_ERR_INVALID_STACK_OPERATION);
  // interpreter.cpp:1126-1130 -- nKeys decode.
  // Initialised: on the len > 4 path nk is never read, but leaving it
  // uninitialised makes clang emit an `undef` phi incoming, which Alive2
  // treats as a free value at the join and loses the nKeys-count edge.
  int64_t nk = 0;
  if (!core_decode_num(keys_enc, nk)) return e32_err(EQUIV_ERR_SCRIPTNUM);
  // interpreter.cpp:1131-1132.
  if (nk < 0 || nk > 20) return e32_err(EQUIV_ERR_PUBKEY_COUNT);
  // interpreter.cpp:1133-1135 -- opCount.
  const uint32_t opcount = (uint32_t)ops_before_raw + (uint32_t)nk;
  if (opcount > 201u) return e32_err(EQUIV_ERR_OP_COUNT);
  // interpreter.cpp:1136-1138 -- ikey = 2, i = nKeys + 2 depth check.
  if (n < (uint32_t)nk + 2u) return e32_err(EQUIV_ERR_INVALID_STACK_OPERATION);
  // interpreter.cpp:1140 -- nSigs = CScriptNum(stacktop(-nKeys-2)).
  int64_t ns = 0;  // see nk above: keep the phi free of `undef`
  if (!core_decode_num(e32_top((uint32_t)nk + 2u, n, keys_enc, sigs_enc), ns))
    return e32_err(EQUIV_ERR_SCRIPTNUM);
  // interpreter.cpp:1140-1142.
  if (ns < 0 || ns > nk) return e32_err(EQUIV_ERR_SIG_COUNT);
  // interpreter.cpp:1143-1145 -- isig = nKeys + 3, i += nSigs, depth check.
  if (n < (uint32_t)nk + (uint32_t)ns + 3u)
    return e32_err(EQUIV_ERR_INVALID_STACK_OPERATION);
  return e32_out(1u, 0u, (uint32_t)nk, (uint32_t)ns, opcount, n);
}

extern "C" uint64_t cell_cms_counts(uint64_t n, uint64_t keys_enc,
                                    uint64_t sigs_enc, uint64_t ops_before) {
  return core_counts(n, keys_enc, sigs_enc, ops_before);
}
