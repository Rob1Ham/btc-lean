#include "w32_common.h"

// C legs: line-cited source-excerpt slices of Bitcoin Core
// src/script/interpreter.cpp at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
// Wave-32 witness-v0 row-closure cells; see each cell's spec.md.
//
// Shared error ordinals (contract/error_enum.md:68-70):
//   38 SCRIPT_ERR_WITNESS_PROGRAM_WRONG_LENGTH
//   39 SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY
//   40 SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH

// ---------------------------------------------------------------------------
// Cell C-L-w32-witness-v0-error-total  (SCR-134, SCR-135, SCR-137; SCR-133
// branch)
//
// interpreter.cpp:1933-1956, the whole v0 arm of VerifyWitnessProgram, with
// the two operations outside the dispatch kept as *inputs* instead of being
// fixed to success:
//
//   hash_ok  -- the value of `memcmp(hash_exec_script.begin(), program.data(),
//              32) == 0` at interpreter.cpp:1943, i.e. SHA256(witnessScript)
//              equals the 32-byte program.  SCR-133 is the computation of
//              this value; it is not proved here.
//   exec_res -- ExecuteWitnessScript's result (1 pass / 0 fail), and
//   exec_err -- its error ordinal.  interpreter.cpp:1946 and 1953.
//
// So the function is total and returns the exact (result, error) pair the v0
// arm returns for every input, with no success arm asserted.
W32INLINE uint64_t c_v0_error_total(uint64_t plen, uint64_t wn,
                                    uint64_t hash_ok, uint64_t exec_res,
                                    uint64_t exec_err) {
    if (plen == 32) {
        // interpreter.cpp:1933-1938: WITNESS_V0_SCRIPTHASH_SIZE (P2WSH).
        if (wn == 0) return w32_pack(0, 39);
        // interpreter.cpp:1939-1945: SHA256 match; memcmp result is the
        // hash_ok input.  A mismatch is WITNESS_PROGRAM_MISMATCH.
        if (hash_ok == 0) return w32_pack(0, 40);
        // interpreter.cpp:1946: ExecuteWitnessScript outcome.
        return w32_exec(exec_res, exec_err);
    } else if (plen == 20) {
        // interpreter.cpp:1947-1951: WITNESS_V0_KEYHASH_SIZE (P2WPKH).
        if (wn != 2) return w32_pack(0, 40);
        // interpreter.cpp:1953: ExecuteWitnessScript outcome.
        return w32_exec(exec_res, exec_err);
    }
    // interpreter.cpp:1954-1955: every other v0 program length.
    return w32_pack(0, 38);
}

extern "C" uint64_t cell_v0_error_total(uint64_t plen, uint64_t wn,
                                        uint64_t hash_ok, uint64_t exec_res,
                                        uint64_t exec_err) {
    return c_v0_error_total(plen, wn, hash_ok, exec_res, exec_err);
}

// ---------------------------------------------------------------------------
// Cell C-L-w32-witness-hash-compare  (SCR-133 comparison half)
//
// interpreter.cpp:1939-1945:
//
//   uint256 hash_exec_script;
//   CSHA256().Write(exec_script.data(), exec_script.size())
//            .Finalize(hash_exec_script.begin());
//   if (memcmp(hash_exec_script.begin(), program.data(), 32)) {
//       return set_error(serror, SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH);
//   }
//
// The digest is NOT computed here (that is the SCR-133 blocker); it is the
// 32-byte value h.  The cell proves that the comparison is exact over all 32
// bytes: mismatch (error 40) iff the digest and the program differ in any
// byte, otherwise the ExecuteWitnessScript input pair is passed through.
//
// Marshalling: the 32-byte digest and the 32-byte program are each carried
// as four little-endian u64 words.  This is a bijection between 256-bit byte
// strings and word tuples, not engine semantics, and it is the same packing
// on both legs.
W32INLINE uint64_t c_hash_compare(uint64_t h0, uint64_t h1, uint64_t h2,
                                  uint64_t h3, uint64_t p0, uint64_t p1,
                                  uint64_t p2, uint64_t p3, uint64_t exec_res,
                                  uint64_t exec_err) {
    const bool equal =
        ((h0 == p0) & (h1 == p1) & (h2 == p2) & (h3 == p3)) != 0;
    if (!equal) return w32_pack(0, 40);
    return w32_exec(exec_res, exec_err);
}

extern "C" uint64_t cell_hash_compare(uint64_t h0, uint64_t h1, uint64_t h2,
                                      uint64_t h3, uint64_t p0, uint64_t p1,
                                      uint64_t p2, uint64_t p3,
                                      uint64_t exec_res, uint64_t exec_err) {
    return c_hash_compare(h0, h1, h2, h3, p0, p1, p2, p3, exec_res, exec_err);
}

// ---------------------------------------------------------------------------
// Cell C-L-w32-p2wpkh-build  (SCR-136 reconstruction half)
//
// interpreter.cpp:1952, with the two expansions it relies on:
//
//   exec_script << OP_DUP << OP_HASH160 << program
//               << OP_EQUALVERIFY << OP_CHECKSIG;
//
// Opcode pushes are script.h:470-476 (`insert(end(), (unsigned char)opcode)`),
// so OP_DUP=0x76, OP_HASH160=0xa9, OP_EQUALVERIFY=0x88, OP_CHECKSIG=0xac each
// contribute one byte.  `<< program` is script.h:484-488 with a 20-byte span,
// whose data-size prefix is script.h:408-411 `size < OP_PUSHDATA1` => one
// byte 0x14, followed by the 20 program bytes (script.h:428-431).
//
// The resulting script is exactly the 25 bytes
//   76 a9 14 <program[0..19]> 88 ac
// which is the same list the Lean model builds (Defs.lean:1272-1274).
//
// Marshalling: program is three little-endian u64 words (20 bytes: p0=0..7,
// p1=8..15, p2=16..19 in the low 32 bits).  The 25 script bytes are returned
// as four little-endian u64 words (w0=0..7, w1=8..15, w2=16..23, w3=24 with
// bytes 25..31 zero).  Four scalar witnesses keep the functions free of
// aggregates and heap.
W32INLINE uint64_t c_le_byte(uint64_t w, unsigned i) {
    return (w >> (8u * i)) & 0xffu;
}

// bytes 0..7: 76 a9 14 p0[0] p0[1] p0[2] p0[3] p0[4]
W32INLINE uint64_t c_p2wpkh_w0(uint64_t p0, uint64_t p1, uint64_t p2) {
    (void)p1; (void)p2;
    return 0x76ull | (0xa9ull << 8) | (0x14ull << 16) |
           (c_le_byte(p0, 0) << 24) | (c_le_byte(p0, 1) << 32) |
           (c_le_byte(p0, 2) << 40) | (c_le_byte(p0, 3) << 48) |
           (c_le_byte(p0, 4) << 56);
}

// bytes 8..15: p0[5] p0[6] p0[7] p1[0] p1[1] p1[2] p1[3] p1[4]
W32INLINE uint64_t c_p2wpkh_w1(uint64_t p0, uint64_t p1, uint64_t p2) {
    (void)p2;
    return c_le_byte(p0, 5) | (c_le_byte(p0, 6) << 8) |
           (c_le_byte(p0, 7) << 16) | (c_le_byte(p1, 0) << 24) |
           (c_le_byte(p1, 1) << 32) | (c_le_byte(p1, 2) << 40) |
           (c_le_byte(p1, 3) << 48) | (c_le_byte(p1, 4) << 56);
}

// bytes 16..23: p1[5] p1[6] p1[7] p2[0] p2[1] p2[2] p2[3] 88
W32INLINE uint64_t c_p2wpkh_w2(uint64_t p0, uint64_t p1, uint64_t p2) {
    (void)p0;
    return c_le_byte(p1, 5) | (c_le_byte(p1, 6) << 8) |
           (c_le_byte(p1, 7) << 16) | (c_le_byte(p2, 0) << 24) |
           (c_le_byte(p2, 1) << 32) | (c_le_byte(p2, 2) << 40) |
           (c_le_byte(p2, 3) << 48) | (0x88ull << 56);
}

// bytes 24..31: ac 00 00 00 00 00 00 00
W32INLINE uint64_t c_p2wpkh_w3(uint64_t p0, uint64_t p1, uint64_t p2) {
    (void)p0; (void)p1; (void)p2;
    return 0xacull;
}

extern "C" uint64_t cell_p2wpkh_w0(uint64_t p0, uint64_t p1, uint64_t p2) {
    return c_p2wpkh_w0(p0, p1, p2);
}
extern "C" uint64_t cell_p2wpkh_w1(uint64_t p0, uint64_t p1, uint64_t p2) {
    return c_p2wpkh_w1(p0, p1, p2);
}
extern "C" uint64_t cell_p2wpkh_w2(uint64_t p0, uint64_t p1, uint64_t p2) {
    return c_p2wpkh_w2(p0, p1, p2);
}
extern "C" uint64_t cell_p2wpkh_w3(uint64_t p0, uint64_t p1, uint64_t p2) {
    return c_p2wpkh_w3(p0, p1, p2);
}
