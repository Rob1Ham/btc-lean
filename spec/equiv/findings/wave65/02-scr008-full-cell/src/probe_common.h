#ifndef W65_SCR008_PROBE_COMMON_H
#define W65_SCR008_PROBE_COMMON_H
#include <cstdint>

#define EVINLINE static inline __attribute__((always_inline))

// contract/error_kind.h ordinals at the pin.
#define EV_CLEANSTACK               30
#define EV_WITNESS_MALLEATED        41
#define EV_WITNESS_MALLEATED_P2SH   42
#define EV_WITNESS_UNEXPECTED       43

EVINLINE uint64_t ev_pack(uint64_t result, uint64_t error) {
  return (result & 3u) | ((error & 0x3fu) << 2);
}
#endif
