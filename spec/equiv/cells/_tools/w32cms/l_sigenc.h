#ifndef L_SIGENC_H
#define L_SIGENC_H
// L-leg signature/pubkey encoding validators (reviewed transliteration).
//
// Source: spec/core/Bitcoin/Interpreter/Defs.lean
//   isValidSigEncoding     :320-341   (SCR-102)
//   isDefinedHashtype      :343-348   (SCR-105)
//   checkLowS              :355-362   (SCR-104)
//   checkSigEncoding       :373-385   (SCR-108, SWT-058/060)
//   isCompressedOrUncompressedPubKey :390-395
//   isCompressedPubKey     :397-400
//   checkPubKeyEncoding    :398-411   (SCR-106/107, SWT-056)
//
// Written from the Lean equations (byteOr-total indexing, Option/TwinErr
// error ordering); deliberately not a copy of the C slice.
#include "e32_common.h"
#include "twin_ops.h"

using namespace twinleaf;

// Lean `byteOr b i`: in-bounds byte or 0x00.
E32INLINE uint32_t l_byte(const E32Elem& e, uint32_t i) {
  return i < e.len ? (uint32_t)e.b[i] : 0u;
}

E32INLINE bool lean_valid_sig_enc(const E32Elem& sig) {
  if (sig.len < 9u || 73u < sig.len) return false;
  if (l_byte(sig, 0) != 0x30u) return false;
  if (l_byte(sig, 1) != sig.len - 3u) return false;
  const uint32_t lenR = l_byte(sig, 3);
  if (5u + lenR >= sig.len) return false;
  const uint32_t lenS = l_byte(sig, 5u + lenR);
  if (lenR + lenS + 7u != sig.len) return false;
  if (l_byte(sig, 2) != 0x02u) return false;
  if (lenR == 0u) return false;
  if ((l_byte(sig, 4) & 0x80u) != 0u) return false;
  if (lenR > 1u && l_byte(sig, 4) == 0u &&
      (l_byte(sig, 5) & 0x80u) == 0u) return false;
  if (l_byte(sig, lenR + 4u) != 0x02u) return false;
  if (lenS == 0u) return false;
  if ((l_byte(sig, lenR + 6u) & 0x80u) != 0u) return false;
  if (lenS > 1u && l_byte(sig, lenR + 6u) == 0u &&
      (l_byte(sig, lenR + 7u) & 0x80u) == 0u) return false;
  return true;
}

E32INLINE bool lean_defined_hashtype(const E32Elem& sig) {
  if (sig.len == 0u) return false;
  const uint32_t n = l_byte(sig, sig.len - 1u) & 0x7fu;
  return 1u <= n && n <= 3u;
}

E32INLINE bool lean_low_s(const E32Elem& sig) {
  if (sig.len == 0u) return false;
  E32Elem t;
  e32_copy_elem(t, sig);
  t.b[t.len - 1u] = 0x01u;                    // (sig.extract 0 (size-1)).push 0x01
  if (!lean_valid_sig_enc(t)) return false;
  const uint32_t lenR = l_byte(t, 3);
  const uint32_t lenS = l_byte(t, 5u + lenR);
  static const uint8_t half[32] = {
      0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      0x5D, 0x57, 0x6E, 0x73, 0x57, 0xA4, 0x50, 0x1D,
      0xDF, 0xE9, 0x2F, 0x46, 0x68, 0x1B, 0x20, 0xA0};
  // sval is the big-endian N(S); n/2 < 2^255, so width decides below 32.
  if (lenS > 32u) return false;
  if (lenS < 32u) return true;
  for (uint32_t j = 0; j < 32u; ++j) {
    const uint32_t s = l_byte(t, 6u + lenR + (31u - j));
    if (s < (uint32_t)half[j]) return true;
    if (s > (uint32_t)half[j]) return false;
  }
  return true;
}

E32INLINE bool lean_comp_or_uncomp_pk(const E32Elem& pk) {
  if (pk.len < 33u) return false;
  if (l_byte(pk, 0) == 0x04u) return pk.len == 65u;
  if (l_byte(pk, 0) == 0x02u || l_byte(pk, 0) == 0x03u) return pk.len == 33u;
  return false;
}

E32INLINE bool lean_compressed_pk(const E32Elem& pk) {
  return pk.len == 33u && (l_byte(pk, 0) == 0x02u || l_byte(pk, 0) == 0x03u);
}

E32INLINE TwinErr lean_sig_enc_err(const E32Elem& sig, uint32_t flags) {
  if (sig.len == 0u) return TWIN_OK;
  if (((flags & (E32_F_DERSIG | E32_F_LOW_S | E32_F_STRICTENC)) != 0u) &&
      !lean_valid_sig_enc(sig))
    return TWIN_SIG_DER;
  if ((flags & E32_F_LOW_S) != 0u && !lean_low_s(sig))
    return TWIN_SIG_HIGH_S;
  if ((flags & E32_F_STRICTENC) != 0u && !lean_defined_hashtype(sig))
    return TWIN_SIG_HASHTYPE;
  return TWIN_OK;
}

E32INLINE TwinErr lean_pk_enc_err(const E32Elem& pk, uint32_t flags) {
  if ((flags & E32_F_STRICTENC) != 0u && !lean_comp_or_uncomp_pk(pk))
    return TWIN_PUBKEYTYPE;
  if ((flags & E32_F_WITPUBKEY) != 0u && (flags & E32_F_WITNESS_V0) != 0u &&
      !lean_compressed_pk(pk))
    return TWIN_WITNESS_PUBKEYTYPE;
  return TWIN_OK;
}

#endif
