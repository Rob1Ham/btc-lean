#include "compare_common.h"

// Six fixed-context variants of one exported symbol.  Compiled with
// -DVARIANT=n so an Alive2 pair always sees the same function name/signature.

#if VARIANT == 1
// pinned slice at the last pre-activation height
extern "C" uint64_t cell_compare(uint64_t h0, uint64_t h1, uint64_t h2,
                                 uint64_t h3, uint64_t version, uint64_t plen,
                                 uint64_t p2sh, uint64_t wn) {
  return gate_and_pack(pin_flags(h0, h1, h2, h3, H709631), version, plen, p2sh, wn);
}
#elif VARIANT == 2
// pinned slice at the activation height
extern "C" uint64_t cell_compare(uint64_t h0, uint64_t h1, uint64_t h2,
                                 uint64_t h3, uint64_t version, uint64_t plen,
                                 uint64_t p2sh, uint64_t wn) {
  return gate_and_pack(pin_flags(h0, h1, h2, h3, H709632), version, plen, p2sh, wn);
}
#elif VARIANT == 3
// BIP9 model at the last pre-activation height
extern "C" uint64_t cell_compare(uint64_t h0, uint64_t h1, uint64_t h2,
                                 uint64_t h3, uint64_t version, uint64_t plen,
                                 uint64_t p2sh, uint64_t wn) {
  return gate_and_pack(model_flags(h0, h1, h2, h3, H709631), version, plen, p2sh, wn);
}
#elif VARIANT == 4
// BIP9 model at the activation height
extern "C" uint64_t cell_compare(uint64_t h0, uint64_t h1, uint64_t h2,
                                 uint64_t h3, uint64_t version, uint64_t plen,
                                 uint64_t p2sh, uint64_t wn) {
  return gate_and_pack(model_flags(h0, h1, h2, h3, H709632), version, plen, p2sh, wn);
}
#elif VARIANT == 5
// pinned slice at the taproot exception block (hash fixed), height 692261
extern "C" uint64_t cell_compare(uint64_t, uint64_t, uint64_t, uint64_t,
                                 uint64_t version, uint64_t plen,
                                 uint64_t p2sh, uint64_t wn) {
  return gate_and_pack(pin_flags(TAP_TR_H0, TAP_TR_H1, TAP_TR_H2, TAP_TR_H3,
                                 H_EXC),
                       version, plen, p2sh, wn);
}
#elif VARIANT == 6
// BIP9 model at the taproot exception block (hash fixed), height 692261
extern "C" uint64_t cell_compare(uint64_t, uint64_t, uint64_t, uint64_t,
                                 uint64_t version, uint64_t plen,
                                 uint64_t p2sh, uint64_t wn) {
  return gate_and_pack(model_flags(TAP_TR_H0, TAP_TR_H1, TAP_TR_H2, TAP_TR_H3,
                                   H_EXC),
                       version, plen, p2sh, wn);
}
#else
#error "define -DVARIANT=1..6"
#endif
