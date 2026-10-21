#ifndef CELLS_EXEC_VERIFY_PUSHONLY_COMMON_H
#define CELLS_EXEC_VERIFY_PUSHONLY_COMMON_H
#include <cstdint>

#define EVINLINE static inline __attribute__((always_inline))

// Error ordinals, contract/error_kind.h (Core ScriptError at the pin).
#define EV_SIG_PUSHONLY 26

// Observable: verdict (2 bits) | error (6 bits) << 2.
// verdict: 0 = fail (Core would set SIG_PUSHONLY), 1 = check passed / arm not
// applicable, 3 = out-of-model (script longer than the 8-byte bound).
// The packing is cell harness; the error ordinal is contract/error_kind.h.
EVINLINE uint64_t ev_pack(uint64_t result, uint64_t error) {
  return (result & 3u) | ((error & 0x3fu) << 2);
}

// Script length bound: the cell packs at most 8 script bytes into one u64.
#define EV_SCRIPT_MAX 8u

// Byte i of the packed script (i = 0 is the first byte of the script).
EVINLINE uint64_t ev_script_byte(uint64_t script, uint64_t i) {
  return (script >> (8u * i)) & 0xffu;
}
#endif
