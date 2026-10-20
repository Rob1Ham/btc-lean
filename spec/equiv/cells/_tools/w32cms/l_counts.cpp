// Wave-32 CHECKMULTISIG counts cell -- L leg (SCR-114).
//
// REVIEWED TRANSLITERATION of Bitcoin.Interpreter.Defs.checkMultiSig
// (spec/core/Bitcoin/Interpreter/Defs.lean:1071-1105, the prelude before
// cmsLoop), with decodeNum = decodeScriptNum b minimalData=false maxSize=4
// (Defs.lean:629-635, Numeric/Interface.lean:45-49).
//
// This leg is deliberately written from the Lean equations (big-endian
// digit view, Except-style error ordering) rather than copied from the C
// slice, so the Alive2/SAW comparison is between two independent
// formulations of the same rule.
#include "e32_common.h"
#include "twin_ops.h"

using namespace twinleaf;

// decodeScriptNum (Defs.lean:629): decodeBE minimal=false maxSize=4 on the
// big-endian view of the wire bytes.  Written as a big-endian fold.
E32INLINE bool lean_decode_num(uint64_t e, int64_t& out) {
  const uint32_t len = e32_len(e);
  if (len > 4u) return false;                 // l.length > maxSize -> none
  // digits of the reversed (big-endian) list, d[i] = wire byte[len-1-i]
  uint64_t acc = 0;
  for (uint32_t i = 0; i < 4u; ++i) {
    if (i < len) acc = acc * 256u + (uint64_t)e32_byte(e, len - 1u - i);
  }
  if (len == 0u) { out = 0; return true; }
  // setVchBE: sign digit is the most significant (wire-last) byte.
  if ((e32_byte(e, len - 1u) & 0x80u) != 0u)
    out = -(int64_t)(acc & ~((uint64_t)0x80u << (8u * (len - 1u))));
  else
    out = (int64_t)acc;
  return true;
}

// Except ExecError State, projected onto the cell observable.
E32INLINE uint64_t l_counts(uint64_t n_raw, uint64_t keys_enc,
                            uint64_t sigs_enc, uint64_t ops_before_raw) {
  const uint32_t n = (uint32_t)n_raw;
  const uint32_t ops0 = (uint32_t)ops_before_raw;
  TwinErr err = TWIN_OK;
  int64_t nk = 0, ns = 0;
  uint32_t opcount = 0;
  if (n < 1u) {
    err = TWIN_INVALID_STACK_OPERATION;              // stackUnderflow
  } else {
    int64_t nkv = 0;
    if (!lean_decode_num(keys_enc, nkv)) {
      err = TWIN_SCRIPTNUM;                          // .scriptNum
    } else if (nkv < 0 || 20 < nkv) {
      err = TWIN_PUBKEY_COUNT;                       // .pubKeyCount
    } else {
      nk = nkv;
      opcount = ops0 + (uint32_t)nk;
      if (201u < opcount) {
        err = TWIN_OP_COUNT;                         // .opCount
      } else if (n < (uint32_t)nk + 2u) {
        err = TWIN_INVALID_STACK_OPERATION;          // stackUnderflow
      } else {
        int64_t nsv = 0;
        if (!lean_decode_num(e32_top((uint32_t)nk + 2u, n, keys_enc, sigs_enc),
                             nsv)) {
          err = TWIN_SCRIPTNUM;
        } else if (nsv < 0 || nk < nsv) {
          err = TWIN_SIG_COUNT;                      // .sigCount
        } else {
          ns = nsv;
          if (n < (uint32_t)nk + (uint32_t)ns + 3u)
            err = TWIN_INVALID_STACK_OPERATION;      // stackUnderflow
        }
      }
    }
  }
  if (err != TWIN_OK) return e32_err((uint32_t)core_ord(err));
  return e32_out(1u, 0u, (uint32_t)nk, (uint32_t)ns, opcount, n);
}

extern "C" uint64_t cell_cms_counts(uint64_t n, uint64_t keys_enc,
                                    uint64_t sigs_enc, uint64_t ops_before) {
  return l_counts(n, keys_enc, sigs_enc, ops_before);
}
