#include "wv_common.h"

// C leg: line-cited layout slice of Bitcoin Core
// src/script/interpreter.cpp at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66,
// SignatureHash SigVersion::WITNESS_V0 (interpreter.cpp:1658-1670):
//
//   ss << txTo.version;              // int32       -> 4 bytes
//   ss << hashPrevouts;              // uint256     -> 32
//   ss << hashSequence;              // uint256     -> 32
//   ss << txTo.vin[nIn].prevout;     // COutPoint   -> 32 + 4
//   ss << scriptCode;                // CScript     -> CompactSize(len) + len
//   ss << amount;                    // CAmount     -> 8
//   ss << txTo.vin[nIn].nSequence;   // uint32      -> 4
//   ss << hashOutputs;               // uint256     -> 32
//   ss << txTo.nLockTime;            // uint32      -> 4
//   ss << nHashType;                 // int32       -> 4 (appended at 1670)
//
// The cell observes the byte layout of that preimage, not its contents:
// field id i (0..9) maps to a descriptor `width | offset << 8`, and a second
// function returns the total preimage length.  Widths come from the Core
// serializer types (serialize.h: WriteLE16/32/64, CompactSizeWriter,
// uint256/COutPoint writers); the three sub-hashes and SHA256d are opaque and
// are not modelled.
//
// Precondition: 0 <= script_len <= 75, so the CompactSize prefix is one byte
// (script_len <= 252 is one byte; 75 is the minimal-push boundary and keeps the
// offset table inside 8 bits).

extern "C" uint64_t cell_bip143_field(uint64_t field, uint64_t script_len) {
    uint64_t off = 0;
    const uint64_t scw = 1 + script_len;   // CompactSize(1 byte) + scriptCode
    // (id, width) in Core's << order.
#define FIELD(id, width) do { if (field == (id)) return (width) + (off << 8); off += (width); } while (0)
    FIELD(0, 4);    // version
    FIELD(1, 32);   // hashPrevouts
    FIELD(2, 32);   // hashSequence
    FIELD(3, 36);   // outpoint (txid 32 + vout 4)
    FIELD(4, scw);  // scriptCode with its CompactSize prefix
    FIELD(5, 8);    // amount  <- BIP143's added field
    FIELD(6, 4);    // nSequence
    FIELD(7, 32);   // hashOutputs
    FIELD(8, 4);    // nLockTime
    FIELD(9, 4);    // nHashType
#undef FIELD
    return 0;       // no such field
}

extern "C" uint64_t cell_bip143_total_len(uint64_t script_len) {
    return 4 + 32 + 32 + 36 + (1 + script_len) + 8 + 4 + 32 + 4 + 4;
}
