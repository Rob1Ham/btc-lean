#ifndef CELLS_EXEC_VERIFY_FLAGS_DOMAIN_COMMON_H
#define CELLS_EXEC_VERIFY_FLAGS_DOMAIN_COMMON_H
#include <cstdint>

#define EVINLINE static inline __attribute__((always_inline))

// Flag bits, contract/tape.md §5 (Core `script_verify_flag_name` ordinals at
// the pin, interpreter.h:50-150).  Only the three bits this cell reads are
// named here; MAX_SCRIPT_VERIFY_FLAGS is the 21-bit mask the ABI accepts.
#define SCRIPT_VERIFY_P2SH       0x000001ull
#define SCRIPT_VERIFY_CLEANSTACK 0x000100ull
#define SCRIPT_VERIFY_WITNESS    0x000800ull
#define MAX_SCRIPT_VERIFY_FLAGS  0x1fffffull

// Packed observable: result (2 bits) | error ordinal (6 bits) << 2.
// This cell's results are the boolean predicates 0/1 described in spec.md;
// the packing is cell harness, not engine semantics.
EVINLINE uint64_t ev_pack(uint64_t result, uint64_t error) {
  return (result & 3u) | ((error & 0x3fu) << 2);
}
#endif
