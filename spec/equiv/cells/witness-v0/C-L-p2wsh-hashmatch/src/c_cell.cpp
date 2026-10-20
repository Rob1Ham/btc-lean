#include "wv_common.h"

// C leg: line-cited slice of Bitcoin Core src/script/interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, the P2WSH program match
// (interpreter.cpp:1939-1945):
//
//   uint256 hash_exec_script;
//   CSHA256().Write(exec_script.data(), exec_script.size())
//            .Finalize(hash_exec_script.begin());
//   if (memcmp(hash_exec_script.begin(), program.data(), 32)) {
//       return set_error(serror, SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH);
//   }
//   return ExecuteWitnessScript(...);
//
// The cell begins AFTER the SHA256: `digest` is the 32-byte
// SHA256(witnessScript) output and `program` is the 32-byte witness program.
// The hash primitive is not modelled (same-hash premise; SCR-133 remains
// partial).  Since a 32-byte equality is invariant under any fixed byte
// permutation, the four little-endian 64-bit words below are an exact
// encoding of memcmp(...,32) == 0: all 32 bytes must agree.
//
// Observable: (0,40) SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH on any difference;
// result 2 is the ExecuteWitnessScript continuation sentinel (SCR-136/138).

extern "C" uint64_t cell_p2wsh_hashmatch(uint64_t d0, uint64_t d1,
                                         uint64_t d2, uint64_t d3,
                                         uint64_t p0, uint64_t p1,
                                         uint64_t p2, uint64_t p3) {
    const uint64_t diff = (d0 ^ p0) | (d1 ^ p1) | (d2 ^ p2) | (d3 ^ p3);
    if (diff != 0) return wv_pack(0, 40);   // SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH
    return wv_pack(2, 0);                   // match: continue to ExecuteWitnessScript
}
