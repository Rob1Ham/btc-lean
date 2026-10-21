#ifndef CELLS_EXEC_VERIFY_TAIL_COMMON_H
#define CELLS_EXEC_VERIFY_TAIL_COMMON_H
#include <cstdint>

#define EVINLINE static inline __attribute__((always_inline))

// Error ordinals, contract/error_kind.h (Core ScriptError at the pin).
#define EV_EVAL_FALSE               2
#define EV_CLEANSTACK               30
#define EV_WITNESS_MALLEATED        41
#define EV_WITNESS_MALLEATED_P2SH   42
#define EV_WITNESS_UNEXPECTED       43

// Packed observable: result (2 bits) | error ordinal (6 bits) << 2.
// result 0 = fail, 1 = pass / "check accepted".  Packing is cell harness.
EVINLINE uint64_t ev_pack(uint64_t result, uint64_t error) {
  return (result & 3u) | ((error & 0x3fu) << 2);
}
#endif
