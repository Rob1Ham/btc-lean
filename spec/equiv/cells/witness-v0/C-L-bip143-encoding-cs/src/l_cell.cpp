#include "wv_common.h"

#include <string.h>
#include <stdint.h>

// L leg: REVIEWED TRANSLITERATION of the verified Lean definitions at the
// pin (spec/core).
//
//   serU32L x = [x, x>>>8, x>>>16, x>>>24]          (Digest.lean:53-54)
//   serU64L x = [x, x>>>8, ..., x>>>56]             (Digest.lean:56-58)
//   serAmountL v = serU64L (UInt64.ofInt v)         (Digest.lean:64)
//   encCSL n  = if n < 0xfd then [n]
//               else if n <= 0xffff then 0xfd :: encU16L n
//               else if n <= 0xffffffff then 0xfe :: encU32L n
//               else 0xff :: encU64L n               (Interface.lean:493-500)
//   bip143MsgL tx nIn scriptCode ht amount =
//       serU32L tx.version.toUInt32
//     ++ hashPrevoutsL tx ht
//     ++ hashSequenceL tx ht
//     ++ serOutpointL i.prevout
//     ++ encCSL scriptCode.length ++ scriptCode
//     ++ serAmountL amount
//     ++ serU32L i.sequence
//     ++ hashOutputsL tx nIn ht
//     ++ serU32L tx.locktime
//     ++ serU32L ht                            (Digest.lean:288-302)
//
// The preimage function writes the same bytes at EXPLICIT ABSOLUTE OFFSETS
// (no running cursor), and integer encoders are loops over byte lanes rather
// than the C leg's unrolled shifts, so the Alive2 comparison is semantic.
// `amount` is the spent output's 8-byte LE value; `hashPrevouts`,
// `hashSequence`, `hashOutputs`, txid and vout stay opaque symbolic payloads
// (same-hash premise).  No transaction decode is claimed.
//
// scriptCode length is 253 = 0xfd, the first length with a three-byte
// CompactSize prefix: encCSL 253 = [0xfd, 0xfd, 0x00].  Field offsets after
// the script therefore shift by +2 relative to the one-byte-prefix cells:
// amount starts at 105 + 253 + 2 = 360.
//
// `noinline,optnone`: see c_cell.cpp (Alive2 v20 has no `nocapture`).

WV_INLINE void cell_loop_u16le(uint8_t *p, uint16_t v) {
    for (unsigned i = 0; i < 2; ++i)
        p[i] = (uint8_t)((v >> (8u * i)) & 0xffu);
}

WV_INLINE void cell_loop_u32le(uint8_t *p, uint32_t v) {
    for (unsigned i = 0; i < 4; ++i)
        p[i] = (uint8_t)((v >> (8u * i)) & 0xffu);
}

WV_INLINE void cell_loop_u64le(uint8_t *p, uint64_t v) {
    for (unsigned i = 0; i < 8; ++i)
        p[i] = (uint8_t)((v >> (8u * i)) & 0xffu);
}

extern "C" uint64_t cell_ser_u32le(uint8_t *out, uint32_t v)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_ser_u32le(uint8_t *out, uint32_t v) {
    cell_loop_u32le(out, v);  // serU32L
    return 4;
}

extern "C" uint64_t cell_ser_u64le(uint8_t *out, uint64_t v)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_ser_u64le(uint8_t *out, uint64_t v) {
    cell_loop_u64le(out, v);  // serU64L / serAmountL
    return 8;
}

// encCSL's branch structure, written as nested tests rather than the C leg's
// flat early returns; total over u64.
extern "C" uint64_t cell_cs_width(uint64_t n)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_cs_width(uint64_t n) {
    if (n <= 0xffffffffu) {
        if (n <= 0xffffu) {
            return (n < 0xfd) ? 1 : 3;
        }
        return 5;
    }
    return 9;
}

extern "C" uint64_t cell_cs1(uint8_t *out, uint64_t n)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_cs1(uint8_t *out, uint64_t n) {
    // encCSL n = [n] for n < 0xfd
    out[0] = (uint8_t)(n & 0xffu);
    return 1;
}

extern "C" uint64_t cell_cs3(uint8_t *out, uint64_t n)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_cs3(uint8_t *out, uint64_t n) {
    // encCSL n = 0xfd :: encU16L n
    out[0] = 0xfd;
    cell_loop_u16le(out + 1, (uint16_t)n);
    return 3;
}

extern "C" uint64_t cell_cs5(uint8_t *out, uint64_t n)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_cs5(uint8_t *out, uint64_t n) {
    // encCSL n = 0xfe :: encU32L n
    out[0] = 0xfe;
    cell_loop_u32le(out + 1, (uint32_t)n);
    return 5;
}

extern "C" uint64_t cell_cs9(uint8_t *out, uint64_t n)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_cs9(uint8_t *out, uint64_t n) {
    // encCSL n = 0xff :: encU64L n
    out[0] = 0xff;
    cell_loop_u64le(out + 1, n);
    return 9;
}

// 105 + script_len + (encCS width - 1), derived from the bip143MsgL
// concatenation: version(4)+hashPrevouts(32)+hashSequence(32)+outpoint(36)
// ends at 104, then encCSL(len) ++ scriptCode, then amount.
extern "C" uint64_t cell_bip143_amount_off(uint64_t script_len)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_bip143_amount_off(uint64_t script_len) {
    uint64_t cs = 1;
    if (script_len >= 0xfd) cs = 3;
    if (script_len > 0xffffu) cs = 5;
    if (script_len > 0xffffffffu) cs = 9;
    return 105u + script_len + (cs - 1u);
}

// Absolute-offset assembly of the 412-byte preimage for scriptCode len 253.
extern "C" uint64_t cell_bip143_preimage_e253(
    uint8_t *out, uint32_t version,
    const uint8_t *hashPrevouts, const uint8_t *hashSequence,
    const uint8_t *txid, const uint8_t *vout,
    const uint8_t *script, uint64_t amount,
    uint32_t nSequence, const uint8_t *hashOutputs,
    uint32_t nLockTime, uint32_t nHashType)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_bip143_preimage_e253(
    uint8_t *out, uint32_t version,
    const uint8_t *hashPrevouts, const uint8_t *hashSequence,
    const uint8_t *txid, const uint8_t *vout,
    const uint8_t *script, uint64_t amount,
    uint32_t nSequence, const uint8_t *hashOutputs,
    uint32_t nLockTime, uint32_t nHashType) {
    cell_loop_u32le(out + 0, version);              // serU32L version
    memcpy(out + 4, hashPrevouts, 32);              // hashPrevoutsL
    memcpy(out + 36, hashSequence, 32);             // hashSequenceL
    memcpy(out + 68, txid, 32);                     // serOutpointL: hash
    memcpy(out + 100, vout, 4);                     // serOutpointL: n
    out[104] = 0xfd; out[105] = 0xfd; out[106] = 0x00;  // encCSL 253
    memcpy(out + 107, script, 253);                 // scriptCode
    cell_loop_u64le(out + 360, amount);             // serAmountL
    cell_loop_u32le(out + 368, nSequence);          // serU32L sequence
    memcpy(out + 372, hashOutputs, 32);             // hashOutputsL
    cell_loop_u32le(out + 404, nLockTime);          // serU32L locktime
    cell_loop_u32le(out + 408, nHashType);          // serU32L ht
    return 412;                                     // 157 + 253 + 2
}
