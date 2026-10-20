// L leg of C-L-w32-schnorr-shape (SCR-161, SCR-162).
//
// Reviewed transliteration of the Lean model at repo head
// 4d62a97e551082a69b13f495365bff0a903b0c99:
//   * spec/core/Bitcoin/Capstone/RealChecker.lean:119-142
//     checkSchnorrForInput, shape/prefix fragment:
//       - 122-123  sv must be taproot/tapscript and pk.size = 32
//       - 124-125  sig.size != 64 && sig.size != 65 -> schnorrSigSize
//       - 126-128  schnorrHashtype: none -> schnorrSigHashtype
//       - 129-130  hashtypeValid ht (tail)
//       - 131-132  htSingle bound (tail)
//       - 133-141  spent outputs / annex / leaf-hash availability (tail)
//       - 142      sighashTaproot + verifyImpl (tail)
//   * spec/core/Bitcoin/Crypto/Seam/Entry.lean:156-161 schnorrHashtype
//     (64-byte sig -> (sig, SIGHASH_DEFAULT); 65-byte -> last byte must not
//     be SIGHASH_DEFAULT; any other size -> none).
//
// The `sv = .tapscript` pin and `pk.size = 32` are the caller contract:
// EvalChecksigTapscript (interpreter.cpp:357-400) invokes the checker only
// with SigVersion::TAPSCRIPT, and interpreter.cpp:1731 asserts the 32-byte
// x-only key.  A non-32 pk_len is therefore OUT OF CONTRACT, not an
// ExecError; both legs return the same out-of-domain sentinel and the cell
// domain is pk_len = 32.
//
// Everything after the hashtype split is the shared tail symbol
// btc_equiv_schnorr_tail, exactly as the C leg calls it.  This cell makes
// no claim about the tail's sighash/crypto body.

#include "tap_common.h"

// checkSchnorrForInput prefix (RealChecker.lean:122-128), pinned caller
// contract, tail delegated to the shared symbol.
TPINLINE uint64_t lean_schnorr_shape(uint64_t sig, uint32_t sig_last,
                                     uint32_t pk_len) {
  if (pk_len != 32u) return tp_ood();              // 122-123, caller contract
  const uint32_t len = tp_len(sig);
  if (len != 64u && len != 65u)                    // 124-125
    return tp_fail(TP_ERR_SCHNORR_SIG_SIZE);       // 45

  uint32_t ht = 0u;                                // SIGHASH_DEFAULT
  uint64_t body;
  if (len == 64u) {
    body = sig;                                    // schnorrHashtype: some (sig, 0)
  } else {
    ht = sig_last & 0xffu;                         // sig[64]!
    if (ht == 0u)                                  // Entry.lean:159-160
      return tp_fail(TP_ERR_SCHNORR_SIG_HASHTYPE); // 46
    body = tp_mk(64, tp_byte(sig, 0), tp_byte(sig, 1), tp_byte(sig, 2),
                 tp_byte(sig, 3), tp_byte(sig, 4)); // sig.extract 0 64
  }

  const uint32_t tail = btc_equiv_schnorr_tail(body, ht, len, 2u);
  if (tail != 0u) return tp_fail(tail);            // 129-142
  return tp_pack(1, 0, 0, 0);
}

extern "C" uint64_t cell_schnorr_shape(uint64_t sig, uint32_t sig_last,
                                       uint32_t pk_len) {
  if (tp_len(sig) > 255u || sig_last > 255u || pk_len > 255u)
    return tp_ood();
  return lean_schnorr_shape(sig, sig_last, pk_len);
}
