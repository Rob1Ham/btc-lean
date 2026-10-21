#include "wv_common.h"

#include <string.h>
#include <stdint.h>

// L leg: REVIEWED TRANSLITERATION of the verified Lean definition
//   spec/core/Bitcoin/SigHash/Digest.lean:288-305 (`bip143MsgL`):
//
//   serU32L tx.version.toUInt32
//     ++ hashPrevoutsL tx ht
//     ++ hashSequenceL tx ht
//     ++ serOutpointL i.prevout
//     ++ encCSL scriptCode.length ++ scriptCode
//     ++ serAmountL amount
//     ++ serU32L i.sequence
//     ++ hashOutputsL tx nIn ht
//     ++ serU32L tx.locktime
//     ++ serU32L ht
//
// The concatenation is written with EXPLICIT absolute offsets (no running
// cursor), so the Alive2 comparison against the C cursor form is semantic:
// both legs must agree on every one of the 157+len preimage bytes.
//
// The three concrete lengths match the C leg: scriptCode is the one-byte
// CompactSize prefix (0x00 / 0x01 / 0x4b) followed by the script payload.
// `serU32L`/`serU64L`/`serOutpointL` widths are pinned in Digest.lean and
// Numeric/Serial.lean; the payloads themselves are symbolic byte arrays.
// SHA256d is opaque: the returned length is exactly the number of bytes it
// consumes.
//
// `noinline,optnone`: see c_cell.cpp (Alive2 v20 has no `nocapture`).

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
        memcpy(out + 0, version, 4);                    /* id 0: 0      */    \
        memcpy(out + 4, hashPrevouts, 32);              /* id 1: 4      */    \
        memcpy(out + 36, hashSequence, 32);             /* id 2: 36     */    \
        memcpy(out + 68, txid, 32);                     /* id 3: 68     */    \
        memcpy(out + 100, vout, 4);                     /* id 3: 100    */    \
        out[104] = (uint8_t)(L);                        /* id 4: 104    */    \
        memcpy(out + 105, script, (L));                 /* id 4: 105    */    \
        memcpy(out + (105 + (L)), amount, 8);           /* id 5          */    \
        memcpy(out + (113 + (L)), nSequence, 4);        /* id 6          */    \
        memcpy(out + (117 + (L)), hashOutputs, 32);     /* id 7          */    \
        memcpy(out + (149 + (L)), nLockTime, 4);        /* id 8          */    \
        memcpy(out + (153 + (L)), nHashType, 4);        /* id 9          */    \
        return (4 + 32 + 32 + 36) + (1 + (L)) + 8 + (4 + 32 + 4 + 4);         \
    }

CELL_BIP143_ASM(cell_bip143_preimage_l0, 0)
CELL_BIP143_ASM(cell_bip143_preimage_l1, 1)
CELL_BIP143_ASM(cell_bip143_preimage_l75, 75)
