#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
// bool static IsCompressedOrUncompressedPubKey(const valtype &vchPubKey) {   // :74
//     if (vchPubKey.size() < CPubKey::COMPRESSED_SIZE) return false;          // :75-78
//     if (vchPubKey[0] == 0x04) {                                             // :79
//         if (vchPubKey.size() != CPubKey::SIZE) return false;                // :80-83
//     } else if (vchPubKey[0] == 0x02 || vchPubKey[0] == 0x03) {              // :84
//         if (vchPubKey.size() != CPubKey::COMPRESSED_SIZE) return false;     // :85-88
//     } else {                                                                // :89
//         return false;                                                       // :90-92
//     }
//     return true;                                                            // :93
// }
//
// bool static CheckPubKeyEncoding(const valtype &vchPubKey, script_verify_flags flags,
//                                 const SigVersion &sigversion, ScriptError* serror) {
//     if ((flags & SCRIPT_VERIFY_STRICTENC) != 0 && !IsCompressedOrUncompressedPubKey(vchPubKey))
//         return set_error(serror, SCRIPT_ERR_PUBKEYTYPE);                    // :229-231
//     ...
// }

uint64_t c_strictenc_pubkey(uint64_t flags, uint64_t pkLen, uint64_t pk0) {
    const uint64_t len = pkLen;
    const uint64_t b0  = byte_of(pk0);

    bool enc_ok;
    if (len < 33) {                       // CPubKey::COMPRESSED_SIZE
        enc_ok = false;
    } else if (b0 == 0x04) {
        enc_ok = (len == 65);             // CPubKey::SIZE
    } else if (b0 == 0x02 || b0 == 0x03) {
        enc_ok = (len == 33);
    } else {
        enc_ok = false;
    }

    if ((flags & STRICTENC) != 0 && !enc_ok) return ERR_PUBKEYTYPE;
    return ERR_OK;
}

extern "C" uint64_t cell_strictenc_pubkey(uint64_t flags, uint64_t pkLen, uint64_t pk0) {
    return c_strictenc_pubkey(flags, pkLen, pk0);
}
