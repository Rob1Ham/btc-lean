#ifndef CMS_SEAM_H
#define CMS_SEAM_H
// The family's ONE shared abstract checker (same-crypto premise) plus the
// abstract policy/encoding validators used by the SCR-117 cell.
//
// Alive2 lane: the symbols are bare declarations in both legs, so equal calls
// return equal values and the checker's behaviour is quantified, not assumed.
// SAW lane: one stub definition is linked into both modules per case.
//
// SAME-CRYPTO PREMISE (docs/DECISION-lax-ecdsa.md): nothing here proves
// ECDSA/secp256k1 agreement.  Both legs call the same symbol with the same
// element encodings, so the cell's claim is "if the two checkers agree, the
// two engines agree".  Same for the encoding validators: they are abstract
// policy, and the cell proves where the *engine* calls them, not what BIP66
// says.
#include <cstdint>

// Element encoding at the seam is injective for len <= 2:
//   bits 0..7 byte 0, bits 8..15 byte 1, bits 16..23 length.
// (Identical to cells/_tools/e3/cellsig/checker_abi.h.)
extern "C" uint8_t btc_equiv_check_sig(uint32_t sig, uint32_t pk,
                                       uint32_t script_code,
                                       uint32_t sigversion);

// Abstract CheckSignatureEncoding / CheckPubKeyEncoding: 0 means accepted,
// any other value is the contract error ordinal to raise.  Only the SCR-117
// cell calls these.
extern "C" uint32_t btc_equiv_check_sig_encoding(uint32_t sig,
                                                 uint32_t flags);
extern "C" uint32_t btc_equiv_check_pubkey_encoding(uint32_t pk,
                                                    uint32_t flags,
                                                    uint32_t sigversion);


// Abstract FindAndDelete (SCR-115 same-symbol premise).  Returns
// (new_script_id << 32) | found.  The byte-walking algorithm itself is NOT
// proved here (see cells/.../SCR-098 / INV-056); this cell proves the engine's
// fold order, its BASE-only gate, and the CONST_SCRIPTCODE latch around it.
extern "C" uint64_t btc_equiv_find_and_delete(uint32_t script_id,
                                              uint32_t push);
#endif
