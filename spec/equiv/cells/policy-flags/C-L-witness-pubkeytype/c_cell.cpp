#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
// bool static IsCompressedPubKey(const valtype &vchPubKey) {          // :96
//     if (vchPubKey.size() != CPubKey::COMPRESSED_SIZE) return false; // :97-100
//     if (vchPubKey[0] != 0x02 && vchPubKey[0] != 0x03) return false; // :101-104
//     return true;                                                    // :105
// }
//
// bool static CheckPubKeyEncoding(const valtype &vchPubKey, script_verify_flags flags,
//                                 const SigVersion &sigversion, ScriptError* serror) {
//     if ((flags & SCRIPT_VERIFY_STRICTENC) != 0 && !IsCompressedOrUncompressedPubKey(...))
//         return set_error(serror, SCRIPT_ERR_PUBKEYTYPE);                            // :229-231
//     // Only compressed keys are accepted in segwit
//     if ((flags & SCRIPT_VERIFY_WITNESS_PUBKEYTYPE) != 0 &&
//         sigversion == SigVersion::WITNESS_V0 && !IsCompressedPubKey(vchPubKey))
//         return set_error(serror, SCRIPT_ERR_WITNESS_PUBKEYTYPE);                    // :233-235
// }
//
// Precondition: the STRICTENC branch above did not fire (strictEnc clear).

uint64_t c_witness_pubkeytype(uint64_t flags, uint64_t sigversion,
                              uint64_t pkLen, uint64_t pk0Arg) {
    if (sigversion > SV_TAPSCRIPT) return OUT_OF_DOMAIN;   // cell guard (harness)
    const uint64_t b0 = byte_of(pk0Arg);
    const bool compressed = (pkLen == 33) && (b0 == 0x02 || b0 == 0x03);
    if ((flags & WITNESS_PUBKEYTYPE) != 0 && sigversion == SV_WITNESS_V0 && !compressed) {
        return ERR_WITNESS_PUBKEYTYPE;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_witness_pubkeytype(uint64_t flags, uint64_t sigversion,
                                            uint64_t pkLen, uint64_t pk0Arg) {
    return c_witness_pubkeytype(flags, sigversion, pkLen, pk0Arg);
}
