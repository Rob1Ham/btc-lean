#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
//   def isCompressedOrUncompressedPubKey (pk : ByteArray) : Bool :=   -- :382-387
//     if pk.size < 33 then false
//     else if byteOr pk 0 = 0x04 then pk.size = 65
//     else if byteOr pk 0 = 0x02 ∨ byteOr pk 0 = 0x03 then pk.size = 33
//     else false
//
//   def checkPubKeyEncoding (_flags : ScriptFlags) (pol : PolicyFlags) -- :398-403
//       (sv : SigVersion) (pk : ByteArray) : Option ExecError :=
//     if pol.strictEnc ∧ !isCompressedOrUncompressedPubKey pk then some .pubKeyType
//     else if pol.witnessPubkeyType ∧ sv = .witnessV0 ∧ !isCompressedPubKey pk
//       then some .witnessPubkeyType
//     else none
//
// `pol.strictEnc` is PolicyFlags.strictEnc (Defs.lean:187-205), fed by
// parsePolicyFlags from the corpus "STRICTENC" string; Core carries the same
// bit in its script_verify_flags word.

uint64_t l_strictenc_pubkey(uint64_t flags, uint64_t pkLen, uint64_t pk0) {
    const uint64_t len = pkLen;
    const uint64_t b0  = byte_of(pk0);

    bool enc_ok;
    if (len < 33) {
        enc_ok = false;
    } else if (b0 == 0x04) {
        enc_ok = (len == 65);
    } else if (b0 == 0x02 || b0 == 0x03) {
        enc_ok = (len == 33);
    } else {
        enc_ok = false;
    }

    const bool strictEnc = (flags & STRICTENC) != 0;
    if (strictEnc && !enc_ok) return ERR_PUBKEYTYPE;
    return ERR_OK;
}

extern "C" uint64_t cell_strictenc_pubkey(uint64_t flags, uint64_t pkLen, uint64_t pk0) {
    return l_strictenc_pubkey(flags, pkLen, pk0);
}
