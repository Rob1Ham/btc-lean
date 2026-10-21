#ifndef C_SIGENC_H
#define C_SIGENC_H
// C-leg signature/pubkey encoding validators, bounded.
//
// Line-cited slice of Bitcoin Core v32.99
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   src/script/script.cpp:169-211              IsValidSignatureEncoding
//   src/script/interpreter.cpp:120-160         CheckSignatureEncoding
//   src/script/interpreter.cpp:162-167         IsDefinedHashtypeSignature
//   src/script/interpreter.cpp:74-92           IsCompressedOrUncompressedPubKey
//   src/script/interpreter.cpp:94-99           IsCompressedPubKey
//   src/script/interpreter.cpp:225-234         CheckPubKeyEncoding
//   pubkey.h CheckLowS (DER-level S <= n/2 form used by the twin)
//
// Bounded to element length <= 40 (a 32-byte S is the largest encoding any
// arm reads); bytes past `len` are never read on an executed path.
#include "e32_common.h"

E32INLINE bool core_valid_sig_enc(const E32Elem& sig) {
  const uint32_t len = sig.len;
  if (len < 9u || len > 73u) return false;
  if (sig.b[0] != 0x30u) return false;
  if (sig.b[1] != (uint8_t)(len - 3u)) return false;
  const uint32_t lenR = sig.b[3];
  if (5u + lenR >= len) return false;
  const uint32_t lenS = sig.b[5u + lenR];
  if (lenR + lenS + 7u != len) return false;
  if (sig.b[2] != 0x02u) return false;
  if (lenR == 0u) return false;
  if ((sig.b[4] & 0x80u) != 0u) return false;
  if (lenR > 1u && sig.b[4] == 0u && (sig.b[5] & 0x80u) == 0u) return false;
  if (sig.b[lenR + 4u] != 0x02u) return false;
  if (lenS == 0u) return false;
  if ((sig.b[lenR + 6u] & 0x80u) != 0u) return false;
  if (lenS > 1u && sig.b[lenR + 6u] == 0u &&
      (sig.b[lenR + 7u] & 0x80u) == 0u) return false;
  return true;
}

// S as an unsigned big-endian integer, compared with n/2 (SIG_S_HALF_ORDER).
E32INLINE bool core_low_s(const E32Elem& sig) {
  E32Elem t;
  e32_copy_elem(t, sig);
  if (t.len == 0u) return false;
  t.b[t.len - 1u] = 0x01u;              // sigNoHT.push(0x01)
  if (!core_valid_sig_enc(t)) return false;
  const uint32_t lenR = t.b[3];
  const uint32_t lenS = t.b[5u + lenR];
  static const uint8_t half[32] = {
      0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      0x5D, 0x57, 0x6E, 0x73, 0x57, 0xA4, 0x50, 0x1D,
      0xDF, 0xE9, 0x2F, 0x46, 0x68, 0x1B, 0x20, 0xA0};
  if (lenS > 32u) return false;
  if (lenS < 32u) return true;
  // Most significant wire byte first.
  for (uint32_t j = 0; j < 32u; ++j) {
    const uint8_t s = t.b[6u + lenR + (31u - j)];
    if (s < half[j]) return true;
    if (s > half[j]) return false;
  }
  return true;
}

E32INLINE bool core_defined_hashtype(const E32Elem& sig) {
  if (sig.len == 0u) return false;
  const uint32_t n = sig.b[sig.len - 1u] & 0x7fu;
  return 1u <= n && n <= 3u;
}

E32INLINE bool core_comp_or_uncomp_pk(const E32Elem& pk) {
  if (pk.len < 33u) return false;
  if (pk.b[0] == 0x04u) return pk.len == 65u;
  if (pk.b[0] == 0x02u || pk.b[0] == 0x03u) return pk.len == 33u;
  return false;
}

E32INLINE bool core_compressed_pk(const E32Elem& pk) {
  return pk.len == 33u && (pk.b[0] == 0x02u || pk.b[0] == 0x03u);
}

// 0 = pass, otherwise the Core ScriptError ordinal of the first failing gate.
E32INLINE uint32_t core_sig_enc_err(const E32Elem& sig, uint32_t flags) {
  if (sig.len == 0u) return 0u;
  if ((flags & (E32_F_DERSIG | E32_F_LOW_S | E32_F_STRICTENC)) != 0u &&
      !core_valid_sig_enc(sig))
    return EQUIV_ERR_SIG_DER;
  if ((flags & E32_F_LOW_S) != 0u && !core_low_s(sig))
    return EQUIV_ERR_SIG_HIGH_S;
  if ((flags & E32_F_STRICTENC) != 0u && !core_defined_hashtype(sig))
    return EQUIV_ERR_SIG_HASHTYPE;
  return 0u;
}

E32INLINE uint32_t core_pk_enc_err(const E32Elem& pk, uint32_t flags) {
  if ((flags & E32_F_STRICTENC) != 0u && !core_comp_or_uncomp_pk(pk))
    return EQUIV_ERR_PUBKEYTYPE;
  if ((flags & E32_F_WITPUBKEY) != 0u && (flags & E32_F_WITNESS_V0) != 0u &&
      !core_compressed_pk(pk))
    return EQUIV_ERR_WITNESS_PUBKEYTYPE;
  return 0u;
}

#endif
