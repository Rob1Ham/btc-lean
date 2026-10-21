#ifndef CELLS_EXEC_VERIFY_FAILPROP_COMMON_H
#define CELLS_EXEC_VERIFY_FAILPROP_COMMON_H
#include <cstdint>

#define EVINLINE static inline __attribute__((always_inline))

// Observable: verdict (2 bits) | error (6 bits) << 2 | site (3 bits) << 8.
// verdict: 0 = VerifyScript returns false (input invalid), 1 = no reached
// callee failed (the tail checks are not modelled here), 3 = out-of-model.
// site: 0 = none, 1..5 = the first failing call site in Core's order.
// The packing is cell harness; the error ordinal is contract/error_kind.h and
// is the callee's own value, passed through unchanged.
EVINLINE uint64_t ev_pack(uint64_t result, uint64_t error, uint64_t site) {
  return (result & 3u) | ((error & 0x3fu) << 2) | ((site & 7u) << 8);
}
#endif
