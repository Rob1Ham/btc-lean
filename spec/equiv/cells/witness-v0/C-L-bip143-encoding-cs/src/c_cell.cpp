#include "wv_common.h"

#include <string.h>
#include <stdint.h>

// C leg: line-cited slices of Bitcoin Core at the pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Integer wire encoders (serialize.h:61-80):
//   ser_writedata16/32/64 byte-swap to little-endian and write the object
//   bytes.  These are what `ss << version`, `ss << amount`, `ss << nSequence`,
//   `ss << nLockTime` and `ss << nHashType` reach through Serialize
//   (serialize.h:250-256).
//
// CompactSize (serialize.h:291-324):
//   GetSizeOfCompactSize: <253 -> 1, <=0xffff -> 3, <=0xffffffff -> 5,
//   else 9.
//   WriteCompactSize: one byte n, or 0xfd + u16 LE, 0xfe + u32 LE,
//   0xff + u64 LE.
//
// BIP143 preimage (interpreter.cpp:1655-1670): the ten fields in order,
// version, hashPrevouts, hashSequence, outpoint (txid||vout), scriptCode
// (CompactSize + bytes), amount (8-byte LE CAmount), nSequence,
// hashOutputs, nLockTime, then nHashType appended after the arm at
// interpreter.cpp:1673-1676.  `scriptCode` here is 253 bytes, i.e. exactly
// the first length whose CompactSize prefix is three bytes
// (serialize.h:304-312; encCSL 253 = fd fd 00, Lean
// Serialization/Interface.lean:493-500), so the field offsets after the
// script move by +2 relative to the one-byte-prefix cells.
//
// The C leg below is a serializer slice, not Core's HashWriter: the hash
// object is replaced by the returned input length.  The three sub-hashes and
// the txid/vout/hashOutputs payloads are opaque byte arrays (same-hash /
// same-serializer premise, spec/equiv/README.md §7).  No transaction decode
// is claimed: these are fixed-width wire slices.
//
// `noinline,optnone` keeps clang -O1 from attaching `nocapture` to the
// pointer parameters (Alive2 v20 rejects that attribute) and leaves memcpy
// as a memory intrinsic.

// ser_writedata32 on a little-endian host: htole32 is the identity, so the
// object bytes are the four LE significance bytes.
WV_INLINE void cell_wr_u16le(uint8_t *p, uint16_t v) {
    p[0] = (uint8_t)(v & 0xffu);
    p[1] = (uint8_t)((v >> 8) & 0xffu);
}

WV_INLINE void cell_wr_u32le(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)(v & 0xffu);
    p[1] = (uint8_t)((v >> 8) & 0xffu);
    p[2] = (uint8_t)((v >> 16) & 0xffu);
    p[3] = (uint8_t)((v >> 24) & 0xffu);
}

WV_INLINE void cell_wr_u64le(uint8_t *p, uint64_t v) {
    p[0] = (uint8_t)(v & 0xffu);
    p[1] = (uint8_t)((v >> 8) & 0xffu);
    p[2] = (uint8_t)((v >> 16) & 0xffu);
    p[3] = (uint8_t)((v >> 24) & 0xffu);
    p[4] = (uint8_t)((v >> 32) & 0xffu);
    p[5] = (uint8_t)((v >> 40) & 0xffu);
    p[6] = (uint8_t)((v >> 48) & 0xffu);
    p[7] = (uint8_t)((v >> 56) & 0xffu);
}

extern "C" uint64_t cell_ser_u32le(uint8_t *out, uint32_t v)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_ser_u32le(uint8_t *out, uint32_t v) {
    cell_wr_u32le(out, v);
    return 4;
}

extern "C" uint64_t cell_ser_u64le(uint8_t *out, uint64_t v)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_ser_u64le(uint8_t *out, uint64_t v) {
    cell_wr_u64le(out, v);
    return 8;
}

// GetSizeOfCompactSize (serialize.h:291-297), total over u64.
extern "C" uint64_t cell_cs_width(uint64_t n)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_cs_width(uint64_t n) {
    if (n < 253u) return 1;
    if (n <= 0xffffu) return 3;
    if (n <= 0xffffffffu) return 5;
    return 9;
}

// WriteCompactSize branches (serialize.h:302-324).  Each writer is claimed
// only on its own branch (the SAW precondition); the branch conditions
// themselves are the total cell_cs_width function above.
extern "C" uint64_t cell_cs1(uint8_t *out, uint64_t n)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_cs1(uint8_t *out, uint64_t n) {
    // n < 253: ser_writedata8(os, nSize)
    out[0] = (uint8_t)(n & 0xffu);
    return 1;
}

extern "C" uint64_t cell_cs3(uint8_t *out, uint64_t n)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_cs3(uint8_t *out, uint64_t n) {
    // 253 <= n <= 0xffff: 0xfd, ser_writedata16(os, nSize)
    out[0] = 0xfd;
    cell_wr_u16le(out + 1, (uint16_t)n);
    return 3;
}

extern "C" uint64_t cell_cs5(uint8_t *out, uint64_t n)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_cs5(uint8_t *out, uint64_t n) {
    // 0x10000 <= n <= 0xffffffff: 0xfe, ser_writedata32(os, nSize)
    out[0] = 0xfe;
    cell_wr_u32le(out + 1, (uint32_t)n);
    return 5;
}

extern "C" uint64_t cell_cs9(uint8_t *out, uint64_t n)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_cs9(uint8_t *out, uint64_t n) {
    // n > 0xffffffff: 0xff, ser_writedata64(os, nSize)
    out[0] = 0xff;
    cell_wr_u64le(out + 1, n);
    return 9;
}

// Offset of the 8-byte amount inside the BIP143 preimage, as a function of
// the scriptCode length:
//   104 (version..vout)
//   + CompactSize width
//   + script_len
//   = 105 + script_len + (width - 1)
// (interpreter.cpp:1664-1665; bip143MsgL, Digest.lean:288-302).
extern "C" uint64_t cell_bip143_amount_off(uint64_t script_len)
    __attribute__((noinline, optnone));
extern "C" uint64_t cell_bip143_amount_off(uint64_t script_len) {
    // The CompactSize width, inlined so the extracted IR of this function is
    // closed (an external cell_cs_width call would leave the function without
    // a return in Alive2's module-local comparison).
    uint64_t w;
    if (script_len < 253u) w = 1;
    else if (script_len <= 0xffffu) w = 3;
    else if (script_len <= 0xffffffffu) w = 5;
    else w = 9;
    return 105u + script_len + (w - 1u);
}

// Full 412-byte preimage for scriptCode length 253.  Fields:
//   [0,4)     version        u32 LE
//   [4,36)    hashPrevouts   32 opaque
//   [36,68)   hashSequence   32 opaque
//   [68,100)  txid           32 opaque
//   [100,104) vout           4 opaque
//   [104,107) CompactSize    0xfd 0xfd 0x00
//   [107,360) script         253 opaque
//   [360,368) amount         u64 LE (CAmount reinterprets int64_t)
//   [368,372) nSequence      u32 LE
//   [372,404) hashOutputs    32 opaque
//   [404,408) nLockTime      u32 LE
//   [408,412) nHashType      u32 LE
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
    uint64_t off = 0;
    cell_wr_u32le(out + off, version);           off += 4;   // version
    memcpy(out + off, hashPrevouts, 32);         off += 32;  // hashPrevouts
    memcpy(out + off, hashSequence, 32);         off += 32;  // hashSequence
    memcpy(out + off, txid, 32);                 off += 32;  // prevout.txid
    memcpy(out + off, vout, 4);                  off += 4;   // prevout.n
    out[off] = 0xfd; out[off + 1] = 0xfd; out[off + 2] = 0x00;
    off += 3;                                               // CompactSize(253)
    memcpy(out + off, script, 253);              off += 253; // scriptCode
    cell_wr_u64le(out + off, amount);            off += 8;   // amount
    cell_wr_u32le(out + off, nSequence);         off += 4;   // nSequence
    memcpy(out + off, hashOutputs, 32);          off += 32;  // hashOutputs
    cell_wr_u32le(out + off, nLockTime);         off += 4;   // nLockTime
    cell_wr_u32le(out + off, nHashType);         off += 4;   // nHashType
    return off;                                              // 412
}
