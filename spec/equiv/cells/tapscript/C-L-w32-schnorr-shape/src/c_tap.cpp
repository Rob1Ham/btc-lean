// C leg of C-L-w32-schnorr-shape (SCR-161, SCR-162).
//
// Line-cited source slice of Bitcoin Core v32.99 pin cce32b168:
//   * script/interpreter.cpp:1726-1752 GenericTransactionSignatureChecker
//     ::CheckSchnorrSignature
//       - 1729 assert(sigversion == TAPROOT || TAPSCRIPT)
//       - 1731 assert(pubkey_in.size() == 32)  (caller-enforced)
//       - 1736 sig.size() != 64 && sig.size() != 65 -> SCHNORR_SIG_SIZE
//       - 1739-1744 65-byte sig pops the trailing hashtype; explicit
//         SIGHASH_DEFAULT (0x00) -> SCHNORR_SIG_HASHTYPE
//       - 1745-1749 SignatureHashSchnorr / VerifySchnorr (abstract tail)
//
// This cell proves ONLY the two shape gates and the body/hashtype split.
// The tail is the shared external symbol; no BIP340/SHA256 claim is made.

#include "tap_common.h"

// CheckSchnorrSignature shape prefix.  `sig_last` is byte 64 of a 65-byte
// signature (the ABI cannot carry 65 literal bytes; only this byte and
// equality of the abstract body matter).
TPINLINE uint64_t core_schnorr_shape(uint64_t sig, uint32_t sig_last,
                                     uint32_t pk_len) {
  if (pk_len != 32u) return tp_ood();            // 1731 assert, caller-enforced
  const uint32_t len = tp_len(sig);
  if (len != 64u && len != 65u)                  // 1736
    return tp_fail(TP_ERR_SCHNORR_SIG_SIZE);     // 45
  uint32_t hashtype = 0u;                        // SIGHASH_DEFAULT, 1740
  uint64_t body;
  if (len == 65u) {
    hashtype = sig_last & 0xffu;                 // SpanPopBack, 1742
    if (hashtype == 0u)                          // 1743
      return tp_fail(TP_ERR_SCHNORR_SIG_HASHTYPE); // 46
    body = tp_mk(64, tp_byte(sig, 0), tp_byte(sig, 1), tp_byte(sig, 2),
                 tp_byte(sig, 3), tp_byte(sig, 4));
  } else {
    body = sig;                                  // len 64, implicit DEFAULT
  }
  const uint32_t tail = btc_equiv_schnorr_tail(body, hashtype, len, 2u);
  if (tail != 0u) return tp_fail(tail);           // 1746-1749
  return tp_pack(1, 0, 0, 0);
}

extern "C" uint64_t cell_schnorr_shape(uint64_t sig, uint32_t sig_last,
                                       uint32_t pk_len) {
  if (tp_len(sig) > 255u || sig_last > 255u || pk_len > 255u)
    return tp_ood();
  return core_schnorr_shape(sig, sig_last, pk_len);
}
