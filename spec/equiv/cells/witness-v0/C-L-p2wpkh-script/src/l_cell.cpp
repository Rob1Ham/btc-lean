#include "wv_common.h"

// L leg: REVIEWED TRANSLITERATION of the verified Lean construction
//   spec/core/Bitcoin/Interpreter/Defs.lean:1297-1303
// (`Bitcoin.SigHash.p2wpkhScriptCodeL`, used by
// `Bitcoin.Interpreter.verifyWitnessProgram` at Defs.lean:1283-1285):
//
//   let exec : ByteArray :=
//     List.toByteArray [0x76, 0xa9, 0x14] ++ program ++
//       List.toByteArray [0x88, 0xac]
//
// The store order below is suffix-first, deliberately different from the C
// slice, so the Alive2 comparison is not a syntactic self-comparison.  The
// same four-word little-endian encoding as the C leg is documented there.


WV_INLINE void build_script(uint64_t p0, uint64_t p1, uint64_t p2,
                           uint8_t program[20], uint8_t s[32]) {
    program[0] = (uint8_t)(p0 >> 0);
    program[1] = (uint8_t)(p0 >> 8);
    program[2] = (uint8_t)(p0 >> 16);
    program[3] = (uint8_t)(p0 >> 24);
    program[4] = (uint8_t)(p0 >> 32);
    program[5] = (uint8_t)(p0 >> 40);
    program[6] = (uint8_t)(p0 >> 48);
    program[7] = (uint8_t)(p0 >> 56);
    program[8] = (uint8_t)(p1 >> 0);
    program[9] = (uint8_t)(p1 >> 8);
    program[10] = (uint8_t)(p1 >> 16);
    program[11] = (uint8_t)(p1 >> 24);
    program[12] = (uint8_t)(p1 >> 32);
    program[13] = (uint8_t)(p1 >> 40);
    program[14] = (uint8_t)(p1 >> 48);
    program[15] = (uint8_t)(p1 >> 56);
    program[16] = (uint8_t)(p2 >> 0);
    program[17] = (uint8_t)(p2 >> 8);
    program[18] = (uint8_t)(p2 >> 16);
    program[19] = (uint8_t)(p2 >> 24);
    s[24] = 0xac;  // OP_CHECKSIG
    s[23] = 0x88;  // OP_EQUALVERIFY
    s[22] = program[19];
    s[21] = program[18];
    s[20] = program[17];
    s[19] = program[16];
    s[18] = program[15];
    s[17] = program[14];
    s[16] = program[13];
    s[15] = program[12];
    s[14] = program[11];
    s[13] = program[10];
    s[12] = program[9];
    s[11] = program[8];
    s[10] = program[7];
    s[9] = program[6];
    s[8] = program[5];
    s[7] = program[4];
    s[6] = program[3];
    s[5] = program[2];
    s[4] = program[1];
    s[3] = program[0];
    s[2] = 0x14;   // push 20 bytes
    s[1] = 0xa9;   // OP_HASH160
    s[0] = 0x76;   // OP_DUP
    s[25] = 0;
    s[26] = 0;
    s[27] = 0;
    s[28] = 0;
    s[29] = 0;
    s[30] = 0;
    s[31] = 0;
}

extern "C" uint64_t cell_p2wpkh_script_w0(uint64_t p0, uint64_t p1, uint64_t p2) {
    uint8_t program[20];
    uint8_t s[32];
    build_script(p0, p1, p2, program, s);
    return (uint64_t)s[0] |
           ((uint64_t)s[1] << 8) |
           ((uint64_t)s[2] << 16) |
           ((uint64_t)s[3] << 24) |
           ((uint64_t)s[4] << 32) |
           ((uint64_t)s[5] << 40) |
           ((uint64_t)s[6] << 48) |
           ((uint64_t)s[7] << 56);
}

extern "C" uint64_t cell_p2wpkh_script_w1(uint64_t p0, uint64_t p1, uint64_t p2) {
    uint8_t program[20];
    uint8_t s[32];
    build_script(p0, p1, p2, program, s);
    return (uint64_t)s[8] |
           ((uint64_t)s[9] << 8) |
           ((uint64_t)s[10] << 16) |
           ((uint64_t)s[11] << 24) |
           ((uint64_t)s[12] << 32) |
           ((uint64_t)s[13] << 40) |
           ((uint64_t)s[14] << 48) |
           ((uint64_t)s[15] << 56);
}

extern "C" uint64_t cell_p2wpkh_script_w2(uint64_t p0, uint64_t p1, uint64_t p2) {
    uint8_t program[20];
    uint8_t s[32];
    build_script(p0, p1, p2, program, s);
    return (uint64_t)s[16] |
           ((uint64_t)s[17] << 8) |
           ((uint64_t)s[18] << 16) |
           ((uint64_t)s[19] << 24) |
           ((uint64_t)s[20] << 32) |
           ((uint64_t)s[21] << 40) |
           ((uint64_t)s[22] << 48) |
           ((uint64_t)s[23] << 56);
}

extern "C" uint64_t cell_p2wpkh_script_w3(uint64_t p0, uint64_t p1, uint64_t p2) {
    uint8_t program[20];
    uint8_t s[32];
    build_script(p0, p1, p2, program, s);
    return (uint64_t)s[24] |
           ((uint64_t)s[25] << 8) |
           ((uint64_t)s[26] << 16) |
           ((uint64_t)s[27] << 24) |
           ((uint64_t)s[28] << 32) |
           ((uint64_t)s[29] << 40) |
           ((uint64_t)s[30] << 48) |
           ((uint64_t)s[31] << 56);
}
