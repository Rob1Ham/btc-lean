#ifndef CELLS_EXEC_VERIFY_EVAL_EMPTY_COMMON_H
#define CELLS_EXEC_VERIFY_EVAL_EMPTY_COMMON_H
#include <cstdint>

#define EVINLINE static inline __attribute__((always_inline))

// Observable: verdict (2 bits) | error ordinal (6 bits) << 2 |
//             depth (2 bits) << 8 | item0 << 10 | item1 << 18 |
//             item2 << 26 | item3 << 34
// verdict: 0 = fail, 1 = ok, 3 = out-of-model marker.  The packing and the
// bounded stack (4 one-byte items, head = top) are cell harness, not engine
// semantics; the error field is the contract/error_kind.h ordinal.
EVINLINE uint64_t ev_pack(uint64_t result, uint64_t error) {
  return (result & 3u) | ((error & 0x3fu) << 2);
}
EVINLINE uint64_t ev_pack_stack4(uint64_t result, uint64_t error, uint64_t n,
                                 uint64_t b0, uint64_t b1, uint64_t b2, uint64_t b3) {
  return ev_pack(result, error) | ((n & 3u) << 8) | ((b0 & 0xffu) << 10) |
         ((b1 & 0xffu) << 18) | ((b2 & 0xffu) << 26) | ((b3 & 0xffu) << 34);
}
#endif
