// Shared checker stubs for SAW lanes.
//
// The ECDSA/pubkey checks stay abstract per docs/DECISION-lax-ecdsa.md.  In
// the Alive2 lane the same symbols are bare declarations in both modules, so
// Alive2 quantifies over their return values; here they are concrete stubs so
// a closed symbolic proof can be discharged.  No libsecp256k1 behavior is
// claimed.
#include <stdint.h>

extern "C" uint8_t btc_equiv_check_sig(uint32_t sig, uint32_t pk,
                                       uint32_t script_code,
                                       uint32_t sigversion) {
    (void)sig; (void)pk; (void)script_code; (void)sigversion;
    return 0;  // arbitrary verdict; cells that depend on it pin it separately
}

// Structural pubkey parse (CPubKey::IsValid).  Modelled as "not on curve":
// the structural encoding rules are separate rows (SCR-106/107).
extern "C" uint8_t btc_equiv_pubkey_valid(const uint8_t* pk, uint32_t len) {
    (void)pk; (void)len;
    return 0;
}
