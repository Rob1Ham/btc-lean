#include "w32_common.h"

// L legs: REVIEWED TRANSLITERATIONS of the Lean twin.
//
// The twin has no VerifyWitnessProgram handler, so there is no generated body
// to copy.  These functions are hand-transliterated by review from the
// Verified Lean definitions cited below.  They are the L review artifact for
// the wave-32 witness-v0 cells, exactly as cells/_tools/e4/l_cell.cpp is for
// cell C-L-witness-v0-dispatch.
//
// Lean source:
//   spec/core/Bitcoin/Interpreter/Defs.lean:1259-1279
//     verifyWitnessProgram, v0 arm
//   spec/core/Bitcoin/Interpreter/Defs.lean:1272-1274
//     P2WPKH implied script: [0x76,0xa9,0x14] ++ program ++ [0x88,0xac]
//   spec/core/Bitcoin/Interpreter/Hashes.lean:125 (hashSha256), :235
//     (hashHash160)
//
// Error ordinals are the shared EQUIV_ERR_* values: 38 wrong length,
// 39 witness empty, 40 mismatch.

enum LVerdict { L_FAIL = 0, L_OK = 1 };
struct LOut { uint32_t result; uint32_t error; };

W32INLINE LOut l_exec(uint64_t exec_res, uint64_t exec_err) {
    const uint32_t r = (uint32_t)(exec_res & 1u);
    const uint32_t e = r ? 0u : (uint32_t)(exec_err & 0x3fu);
    return {r, e};
}

// ---------------------------------------------------------------------------
// Cell C-L-w32-witness-v0-error-total
//
// Defs.lean:1259-1280, branch order preserved:
//   if version = 0 then
//     if program.size = 32 then
//       if witness.length = 0 then .fail witnessProgramWitnessEmpty
//       else if hashSha256 script != program then .fail witnessProgramMismatch
//       else executeWitnessScript ...
//     else if program.size = 20 then
//       if witness.length != 2 then .fail witnessProgramMismatch
//       else executeWitnessScript ...
//     else .fail witnessProgramWrongLength
//
// `hashSha256 script != program` arrives as the hash_ok input, and
// `executeWitnessScript`'s outcome as (exec_res, exec_err); both are the
// declared seam of this cell (SCR-133 hash computation, ExecuteWitnessScript
// loop), not claimed results.
W32INLINE LOut l_v0_error_total(uint64_t plen, uint64_t wn, uint64_t hash_ok,
                                uint64_t exec_res, uint64_t exec_err) {
    if (plen == 32) {
        if (wn == 0) return {L_FAIL, 39};
        if (hash_ok == 0) return {L_FAIL, 40};
        return l_exec(exec_res, exec_err);
    } else if (plen == 20) {
        if (wn != 2) return {L_FAIL, 40};
        return l_exec(exec_res, exec_err);
    }
    return {L_FAIL, 38};
}

extern "C" uint64_t cell_v0_error_total(uint64_t plen, uint64_t wn,
                                        uint64_t hash_ok, uint64_t exec_res,
                                        uint64_t exec_err) {
    const LOut o = l_v0_error_total(plen, wn, hash_ok, exec_res, exec_err);
    return w32_pack(o.result, o.error);
}

// ---------------------------------------------------------------------------
// Cell C-L-w32-witness-hash-compare
//
// Defs.lean:1269 is `hashSha256 script != program` on two ByteArrays.  The
// transliteration compares the 32 bytes one at a time, which is the Lean
// byte-array inequality at this length; the C leg compares four u64 words.
// The cell proves those are the same predicate over all 2^256 inputs.
W32INLINE uint8_t l_byte_of(uint64_t w, unsigned i) {
    return (uint8_t)((w >> (8u * i)) & 0xffu);
}

W32INLINE bool l_bytes_equal(uint64_t x, uint64_t y) {
    // Unrolled comparison of the eight bytes carried by one u64 word.
    return l_byte_of(x, 0) == l_byte_of(y, 0) &&
           l_byte_of(x, 1) == l_byte_of(y, 1) &&
           l_byte_of(x, 2) == l_byte_of(y, 2) &&
           l_byte_of(x, 3) == l_byte_of(y, 3) &&
           l_byte_of(x, 4) == l_byte_of(y, 4) &&
           l_byte_of(x, 5) == l_byte_of(y, 5) &&
           l_byte_of(x, 6) == l_byte_of(y, 6) &&
           l_byte_of(x, 7) == l_byte_of(y, 7);
}

W32INLINE LOut l_hash_compare(uint64_t h0, uint64_t h1, uint64_t h2,
                              uint64_t h3, uint64_t p0, uint64_t p1,
                              uint64_t p2, uint64_t p3, uint64_t exec_res,
                              uint64_t exec_err) {
    // The Lean ByteArray inequality, byte by byte over all 32 bytes.
    const bool equal = l_bytes_equal(h0, p0) && l_bytes_equal(h1, p1) &&
                       l_bytes_equal(h2, p2) && l_bytes_equal(h3, p3);
    if (!equal) return {L_FAIL, 40};
    return l_exec(exec_res, exec_err);
}

extern "C" uint64_t cell_hash_compare(uint64_t h0, uint64_t h1, uint64_t h2,
                                      uint64_t h3, uint64_t p0, uint64_t p1,
                                      uint64_t p2, uint64_t p3,
                                      uint64_t exec_res, uint64_t exec_err) {
    const LOut o = l_hash_compare(h0, h1, h2, h3, p0, p1, p2, p3, exec_res,
                                  exec_err);
    return w32_pack(o.result, o.error);
}

// ---------------------------------------------------------------------------
// Cell C-L-w32-p2wpkh-build
//
// Defs.lean:1272-1274:
//   let exec : ByteArray :=
//     List.toByteArray [0x76, 0xa9, 0x14] ++ program ++
//       List.toByteArray [0x88, 0xac]
// The transliteration materialises the 32-byte buffer, appends the Lean byte
// list, and reads the four little-endian words it returns.
struct LScript { uint8_t b[32]; };

W32INLINE LScript l_p2wpkh_script(uint64_t p0, uint64_t p1, uint64_t p2) {
    LScript s{};
    s.b[0] = 0x76;
    s.b[1] = 0xa9;
    s.b[2] = 0x14;
    s.b[3] = l_byte_of(p0, 0);
    s.b[4] = l_byte_of(p0, 1);
    s.b[5] = l_byte_of(p0, 2);
    s.b[6] = l_byte_of(p0, 3);
    s.b[7] = l_byte_of(p0, 4);
    s.b[8] = l_byte_of(p0, 5);
    s.b[9] = l_byte_of(p0, 6);
    s.b[10] = l_byte_of(p0, 7);
    s.b[11] = l_byte_of(p1, 0);
    s.b[12] = l_byte_of(p1, 1);
    s.b[13] = l_byte_of(p1, 2);
    s.b[14] = l_byte_of(p1, 3);
    s.b[15] = l_byte_of(p1, 4);
    s.b[16] = l_byte_of(p1, 5);
    s.b[17] = l_byte_of(p1, 6);
    s.b[18] = l_byte_of(p1, 7);
    s.b[19] = l_byte_of(p2, 0);
    s.b[20] = l_byte_of(p2, 1);
    s.b[21] = l_byte_of(p2, 2);
    s.b[22] = l_byte_of(p2, 3);
    s.b[23] = 0x88;
    s.b[24] = 0xac;
    return s;
}

W32INLINE uint64_t l_word_le(const LScript& s, unsigned j) {
    const unsigned o = 8 * j;
    return (uint64_t)s.b[o] | ((uint64_t)s.b[o + 1] << 8) |
           ((uint64_t)s.b[o + 2] << 16) | ((uint64_t)s.b[o + 3] << 24) |
           ((uint64_t)s.b[o + 4] << 32) | ((uint64_t)s.b[o + 5] << 40) |
           ((uint64_t)s.b[o + 6] << 48) | ((uint64_t)s.b[o + 7] << 56);
}

extern "C" uint64_t cell_p2wpkh_w0(uint64_t p0, uint64_t p1, uint64_t p2) {
    return l_word_le(l_p2wpkh_script(p0, p1, p2), 0);
}
extern "C" uint64_t cell_p2wpkh_w1(uint64_t p0, uint64_t p1, uint64_t p2) {
    return l_word_le(l_p2wpkh_script(p0, p1, p2), 1);
}
extern "C" uint64_t cell_p2wpkh_w2(uint64_t p0, uint64_t p1, uint64_t p2) {
    return l_word_le(l_p2wpkh_script(p0, p1, p2), 2);
}
extern "C" uint64_t cell_p2wpkh_w3(uint64_t p0, uint64_t p1, uint64_t p2) {
    return l_word_le(l_p2wpkh_script(p0, p1, p2), 3);
}
