#include "wv_common.h"

// C leg: line-cited slice of Bitcoin Core src/script/interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, the P2WPKH implied-script
// construction (interpreter.cpp:1952-1953):
//
//   exec_script << OP_DUP << OP_HASH160 << program << OP_EQUALVERIFY
//               << OP_CHECKSIG;
//   return ExecuteWitnessScript(stack, exec_script, ...);
//
// `CScript::operator<<(std::vector<unsigned char>)` writes a minimal push, so
// the implied script is the 25 bytes
//
//   76 a9 14 <program[0..19]> 88 ac
//
// Only the construction is modelled; ExecuteWitnessScript (line 1953) is the
// EvalScript/HASH160/CHECKSIG seam and is outside this cell.
//
// Encoding: the 20-byte program arrives as three little-endian u64 words
// (p0 = bytes 0..7, p1 = bytes 8..15, p2 = bytes 16..19 in its low 32 bits)
// and the 25-byte script leaves as four little-endian u64 words (bytes 0..7,
// 8..15, 16..23, 24 plus zero padding).  This is a bijection, adopted because
// Alive2 v20 rejects pointer parameters carrying the `nocapture`/`noalias`
// attributes and runs out of memory on a 20-byte symbolic memory input.


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
    s[0] = 0x76;   // OP_DUP
    s[1] = 0xa9;   // OP_HASH160
    s[2] = 0x14;   // push 20 bytes
    s[3] = program[0];
    s[4] = program[1];
    s[5] = program[2];
    s[6] = program[3];
    s[7] = program[4];
    s[8] = program[5];
    s[9] = program[6];
    s[10] = program[7];
    s[11] = program[8];
    s[12] = program[9];
    s[13] = program[10];
    s[14] = program[11];
    s[15] = program[12];
    s[16] = program[13];
    s[17] = program[14];
    s[18] = program[15];
    s[19] = program[16];
    s[20] = program[17];
    s[21] = program[18];
    s[22] = program[19];
    s[23] = 0x88;  // OP_EQUALVERIFY
    s[24] = 0xac;  // OP_CHECKSIG
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
