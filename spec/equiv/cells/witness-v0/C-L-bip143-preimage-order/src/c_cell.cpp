#include "wv_common.h"

#include <string.h>
#include <stdint.h>

// C leg: line-cited byte-level slice of Bitcoin Core
// src/script/interpreter.cpp at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66,
// SignatureHash SigVersion::WITNESS_V0 (interpreter.cpp:1655-1670):
//
//   ss << txTo.version;              // int32       -> 4 bytes   @ 0
//   ss << hashPrevouts;              // uint256     -> 32        @ 4
//   ss << hashSequence;              // uint256     -> 32        @ 36
//   ss << txTo.vin[nIn].prevout;     // COutPoint   -> 32 + 4    @ 68
//   ss << scriptCode;                // CScript     -> CompactSize(len) + len  @ 104
//   ss << amount;                    // CAmount     -> 8         @ 105+len
//   ss << txTo.vin[nIn].nSequence;   // uint32      -> 4         @ 113+len
//   ss << hashOutputs;               // uint256     -> 32        @ 117+len
//   ss << txTo.nLockTime;            // uint32      -> 4         @ 149+len
//   ss << nHashType;                 // int32       -> 4         @ 153+len
//
// The cell assembles the preimage bytes, not a descriptor table.  Each of the
// ten field payloads is a symbolic byte array supplied by the caller; the cell
// writes them through `out` in Core's `ss << ...` order with a running cursor,
// and returns the number of bytes written (157 + script_len), which is exactly
// the input length SHA256d will consume.  SHA256d itself is opaque:
// out[0 .. 157+len) is its complete input and this cell proves those bytes.
//
// The scriptCode CompactSize prefix is the single byte `script_len` for
// script_len in {0, 1, 75} (one-byte CompactSize, minimum-push boundary).
// Those are the three concrete lengths this cell checks; the sibling
// C-L-bip143-layout cell proves the width/offset table for every
// 0 <= script_len <= 75, so the two cells together cover the length domain.
//
// `noinline,optnone` keeps clang -O1 from attaching `nocapture` to the pointer
// parameters (Alive2 v20 rejects that attribute) and leaves each memcpy in the
// IR as a memory intrinsic.

extern "C" uint64_t cell_bip143_preimage_l0(
    uint8_t *out,
    const uint8_t *version, const uint8_t *hashPrevouts,
    const uint8_t *hashSequence, const uint8_t *txid, const uint8_t *vout,
    const uint8_t *script, const uint8_t *amount, const uint8_t *nSequence,
    const uint8_t *hashOutputs, const uint8_t *nLockTime,
    const uint8_t *nHashType) __attribute__((noinline, optnone));
extern "C" uint64_t cell_bip143_preimage_l1(
    uint8_t *out,
    const uint8_t *version, const uint8_t *hashPrevouts,
    const uint8_t *hashSequence, const uint8_t *txid, const uint8_t *vout,
    const uint8_t *script, const uint8_t *amount, const uint8_t *nSequence,
    const uint8_t *hashOutputs, const uint8_t *nLockTime,
    const uint8_t *nHashType) __attribute__((noinline, optnone));
extern "C" uint64_t cell_bip143_preimage_l75(
    uint8_t *out,
    const uint8_t *version, const uint8_t *hashPrevouts,
    const uint8_t *hashSequence, const uint8_t *txid, const uint8_t *vout,
    const uint8_t *script, const uint8_t *amount, const uint8_t *nSequence,
    const uint8_t *hashOutputs, const uint8_t *nLockTime,
    const uint8_t *nHashType) __attribute__((noinline, optnone));

#define CELL_BIP143_ASM(NAME, L)                                              \
    extern "C" uint64_t NAME(                                                 \
        uint8_t *out,                                                         \
        const uint8_t *version, const uint8_t *hashPrevouts,                  \
        const uint8_t *hashSequence, const uint8_t *txid,                     \
        const uint8_t *vout, const uint8_t *script, const uint8_t *amount,    \
        const uint8_t *nSequence, const uint8_t *hashOutputs,                 \
        const uint8_t *nLockTime, const uint8_t *nHashType) {                 \
        uint64_t off = 0;                                                     \
        memcpy(out + off, version, 4);          off += 4;   /* id 0  */        \
        memcpy(out + off, hashPrevouts, 32);    off += 32;  /* id 1  */        \
        memcpy(out + off, hashSequence, 32);    off += 32;  /* id 2  */        \
        memcpy(out + off, txid, 32);            off += 32;  /* id 3a */        \
        memcpy(out + off, vout, 4);             off += 4;   /* id 3b */        \
        out[off] = (uint8_t)(L);                off += 1;   /* id 4a */        \
        memcpy(out + off, script, (L));         off += (L); /* id 4b */        \
        memcpy(out + off, amount, 8);           off += 8;   /* id 5  */        \
        memcpy(out + off, nSequence, 4);        off += 4;   /* id 6  */        \
        memcpy(out + off, hashOutputs, 32);     off += 32;  /* id 7  */        \
        memcpy(out + off, nLockTime, 4);        off += 4;   /* id 8  */        \
        memcpy(out + off, nHashType, 4);        off += 4;   /* id 9  */        \
        return off;                                                            \
    }

CELL_BIP143_ASM(cell_bip143_preimage_l0, 0)
CELL_BIP143_ASM(cell_bip143_preimage_l1, 1)
CELL_BIP143_ASM(cell_bip143_preimage_l75, 75)
