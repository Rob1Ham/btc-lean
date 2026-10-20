#include "wv_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Slice: the witness-v0 arm of VerifyWitnessProgram
//   interpreter.cpp:1927      signature
//   interpreter.cpp:1933-1938 32-byte program (P2WSH), stack.size()==0 -> 39
//   interpreter.cpp:1939-1945 SHA256(exec_script) vs program, mismatch -> 40
//   interpreter.cpp:1946      ExecuteWitnessScript (continuation)
//   interpreter.cpp:1949-1951 20-byte program (P2WPKH), stack.size()!=2 -> 40
//   interpreter.cpp:1953      ExecuteWitnessScript (continuation)
//   interpreter.cpp:1954-1956 every other v0 length -> 38
//
// Declared abstractions (not part of SCR-134/135/137):
//   * `hash_match` is the result of the 32-byte SHA256 comparison at
//     1939-1945.  SHA256 itself is not modelled (SCR-133 is filed by its own
//     bounded compare cell and remains partial).
//   * both ExecuteWitnessScript call sites are represented by the cell
//     sentinel 2 ("continuation"), never by a success claim (SCR-136/138 are
//     separate rows).
//
// Error ordinals (contract/error_enum.md):
//   38 SCRIPT_ERR_WITNESS_PROGRAM_WRONG_LENGTH
//   39 SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY
//   40 SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH

extern "C" uint64_t cell_v0_dispatch(uint64_t program_len, uint64_t witness_n,
                                     uint64_t hash_match) {
    if (program_len == 32) {
        // 1934-1938: WITNESS_V0_SCRIPTHASH_SIZE / P2WSH.
        if (witness_n == 0) return wv_pack(0, 39);
        // 1939-1945: memcmp(CSHA256(exec_script), program, 32) != 0.
        if (!hash_match) return wv_pack(0, 40);
        // 1946: return ExecuteWitnessScript(...) -- continuation sentinel.
        return wv_pack(2, 0);
    } else if (program_len == 20) {
        // 1949-1951: WITNESS_V0_KEYHASH_SIZE / P2WPKH, exactly two items.
        if (witness_n != 2) return wv_pack(0, 40);
        // 1952-1953: implied P2WPKH script; ExecuteWitnessScript continuation.
        return wv_pack(2, 0);
    }
    // 1954-1956: every other v0 program length.
    return wv_pack(0, 38);
}
