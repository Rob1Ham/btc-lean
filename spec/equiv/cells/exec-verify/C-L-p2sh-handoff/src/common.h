#ifndef CELLS_EXEC_VERIFY_P2SH_COMMON_H
#define CELLS_EXEC_VERIFY_P2SH_COMMON_H
#include <cstdint>

#define EVINLINE static inline __attribute__((always_inline))

// Error ordinals, contract/error_kind.h (Core ScriptError at the pin).
#define EV_UNKNOWN_ERROR            1
#define EV_SIG_PUSHONLY             26

// Observable: verdict (2 bits) | error (6 bits) << 2 |
//             depth (2 bits) << 8 | item0 << 10 | item1 << 18 | item2 << 26 |
//             redeem << 34 | restored << 42
// verdict: 0 = fail, 1 = handoff completed, 3 = out-of-model marker
// (the arm was not entered, or Core's `assert(!stack.empty())` arm).
// The packing and the bounded stack (3 one-byte items) are cell harness, not
// engine semantics; `depth`/`item*` describe the stack handed to the subscript
// EvalScript in Core's bottom-to-top order; `redeem` is the byte of the popped
// top element (the serialized redeemScript, bounded to one byte).
EVINLINE uint64_t ev_pack(uint64_t result, uint64_t error) {
  return (result & 3u) | ((error & 0x3fu) << 2);
}
EVINLINE uint64_t ev_pack_handoff(uint64_t result, uint64_t error, uint64_t n,
                                  uint64_t b0, uint64_t b1, uint64_t b2,
                                  uint64_t redeem, uint64_t restored) {
  return ev_pack(result, error) | ((n & 3u) << 8) | ((b0 & 0xffu) << 10) |
         ((b1 & 0xffu) << 18) | ((b2 & 0xffu) << 26) |
         ((redeem & 0xffu) << 34) | ((restored & 1u) << 42);
}
#endif
