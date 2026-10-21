// One shared stub for the CHECKMULTISIG family's SAW lane.
//
// Both legs link the SAME stub instance, so a SAW proof is a point-wise
// comparison under one concrete checker/policy instance.  Alive2 quantifies
// over the checker instead; SAW's job here is the independent-oracle check.
// The stub is never part of either engine.
#include <cstdint>

#ifndef BTC_EQUIV_CHECK_SIG_MODE
#define BTC_EQUIV_CHECK_SIG_MODE 0
#endif
#ifndef BTC_EQUIV_SIG_ENC_MODE
#define BTC_EQUIV_SIG_ENC_MODE 0
#endif
#ifndef BTC_EQUIV_PK_ENC_MODE
#define BTC_EQUIV_PK_ENC_MODE 0
#endif

extern "C" uint8_t btc_equiv_check_sig(uint32_t sig, uint32_t pk,
                                       uint32_t script_code,
                                       uint32_t sigversion) {
  (void)script_code;
  (void)sigversion;
#if BTC_EQUIV_CHECK_SIG_MODE == 0
  (void)sig;
  (void)pk;
  return 0;
#elif BTC_EQUIV_CHECK_SIG_MODE == 1
  (void)sig;
  (void)pk;
  return 1;
#elif BTC_EQUIV_CHECK_SIG_MODE == 2
  return ((sig & 0xffu) == (pk & 0xffu)) ? 1u : 0u; /* diagonal */
#elif BTC_EQUIV_CHECK_SIG_MODE == 3
  return (((sig & 0xffu) + 1u) == (pk & 0xffu)) ? 1u : 0u; /* shifted */
#elif BTC_EQUIV_CHECK_SIG_MODE == 4
  return (((sig & 0xffu) + 2u) == (pk & 0xffu)) ? 1u : 0u;
#else
#error "unknown check_sig mode"
#endif
}

extern "C" uint32_t btc_equiv_check_sig_encoding(uint32_t sig, uint32_t flags) {
  (void)flags;
#if BTC_EQUIV_SIG_ENC_MODE == 0
  (void)sig;
  return 0;
#elif BTC_EQUIV_SIG_ENC_MODE == 1
  (void)sig;
  return 24; /* SIG_DER */
#elif BTC_EQUIV_SIG_ENC_MODE == 2
  return ((sig & 0xffu) == 0x41u) ? 24u : 0u; /* only sig index 1 */
#else
#error "unknown sig_enc mode"
#endif
}

extern "C" uint32_t btc_equiv_check_pubkey_encoding(uint32_t pk, uint32_t flags,
                                                    uint32_t sigversion) {
  (void)flags;
  (void)sigversion;
#if BTC_EQUIV_PK_ENC_MODE == 0
  (void)pk;
  return 0;
#elif BTC_EQUIV_PK_ENC_MODE == 1
  (void)pk;
  return 29; /* PUBKEYTYPE */
#elif BTC_EQUIV_PK_ENC_MODE == 2
  return ((pk & 0xffu) == 0x21u) ? 29u : 0u;
#else
#error "unknown pk_enc mode"
#endif
}

// Shared FindAndDelete stub for the SCR-115 SAW instance.  Concrete so SAW has
// a definition; Alive2 quantifies over the same symbol in both legs.
extern "C" uint64_t btc_equiv_find_and_delete(uint32_t script_id,
                                              uint32_t push) {
  const uint32_t found =
      ((script_id & 0xffffu) == (push & 0xffffu)) ? 1u : 0u;
  const uint32_t next = found ? (script_id + 0x100u) : script_id;
  return ((uint64_t)next << 32) | (uint64_t)found;
}
