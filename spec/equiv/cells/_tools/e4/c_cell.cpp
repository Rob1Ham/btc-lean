#include "e4_common.h"

// C leg: a line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// The slice is the v0 arm of VerifyWitnessProgram (interpreter.cpp:1927,
// 1933-1956).  Two operations in that arm are deliberately abstracted:
//
//   * interpreter.cpp:1939-1945, SHA256(witnessScript) == program.  The cell
//     does not model SHA256; a non-empty P2WSH witness is taken to reach the
//     successful end of the branch.
//   * interpreter.cpp:1946 / 1953, ExecuteWitnessScript (hash/checksig,
//     cleanstack, EVAL_FALSE).  Taken to return success.
//
// Neither abstraction is part of SCR-134, SCR-135 or SCR-137, which are the
// length/arity dispatch predicates proved here.  Crypto and script execution
// are therefore symbolic-free inputs of the model, not claimed results.
//
// Error ordinals are Core's ScriptError ordinals at the pin
// (contract/error_enum.md):
//   38 SCRIPT_ERR_WITNESS_PROGRAM_WRONG_LENGTH
//   39 SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY
//   40 SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH

E4INLINE uint64_t c_v0_dispatch(uint64_t program_len, uint64_t witness_n) {
    if (program_len == 32) {
        // interpreter.cpp:1934-1938: WITNESS_V0_SCRIPTHASH_SIZE / P2WSH.
        if (witness_n == 0) return e4_pack(0, 39);
        // interpreter.cpp:1939-1946: SHA256 match and ExecuteWitnessScript
        // abstracted to success (see header comment).
        return e4_pack(1, 0);
    } else if (program_len == 20) {
        // interpreter.cpp:1947-1951: WITNESS_V0_KEYHASH_SIZE / P2WPKH.
        if (witness_n != 2) return e4_pack(0, 40);
        // interpreter.cpp:1952-1953: implied P2WPKH script executed;
        // ExecuteWitnessScript abstracted to success.
        return e4_pack(1, 0);
    } else {
        // interpreter.cpp:1954-1955: every other v0 program length.
        return e4_pack(0, 38);
    }
}

extern "C" uint64_t cell_v0_dispatch(uint64_t program_len, uint64_t witness_n) {
    return c_v0_dispatch(program_len, witness_n);
}
