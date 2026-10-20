#ifndef CELLS_TAPSCRIPT_KEYPATH_CHECKER_ABI_H
#define CELLS_TAPSCRIPT_KEYPATH_CHECKER_ABI_H
#include <cstdint>

// The single external Schnorr seam for the key-path cell.
//
// Both the C leg (Core's BaseSignatureChecker::CheckSchnorrSignature at
// interpreter.cpp:1972) and the L leg (Lean's
// checkSchnorrWithContext chk sig program .taproot ed, Defs.lean:1298) call
// THIS symbol with the same arguments.  This is the same-crypto premise of
// spec/equiv/docs/TRUST-BASE.md P12 and docs/DECISION-lax-ecdsa.md: the
// checker is assumed to agree on both legs; no BIP340/libsecp implementation
// is proved.
//
// Return encoding (harness ABI):
//   bit 0     = 1 success, 0 rejection
//   bits 1..6 = Core ScriptError ordinal on rejection (0 on success)
// so the caller can pass through the exact error kind without choosing one.
//
// Arguments: sig_id identifies the signature element, key_id identifies the
// 32-byte x-only output key (program), sigversion is 2 (SigVersion::TAPROOT),
// key_len is 32 (WITNESS_V1_TAPROOT_SIZE).
extern "C" uint32_t btc_equiv_check_schnorr(uint32_t sig_id, uint32_t key_id,
                                            uint32_t sigversion,
                                            uint32_t key_len);

#endif
