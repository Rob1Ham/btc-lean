#ifndef CELLS_STACK_OPS_ARITY_COMMON_H
#define CELLS_STACK_OPS_ARITY_COMMON_H
// Cell-local harness for SCR-074's bounded arity table.
//
// Both legs use the SAME observable function, so an Alive2 comparison sees
// engine behaviour rather than packer drift.  It is deliberately written with
// the family header's always-inline attribute: the shared pack_vals helper is
// plain `static inline`, which clang leaves as a call at -O1 and alive-tv then
// treats as an unknown libcall ("Alive2 approximated the semantics").
//
// Format (identical to leaf_common.h pack_vals):
//   bits 0-1   result (0 fail, 1 pass, 3 leaf-domain marker)
//   bits 2-7   error_kind ordinal
//   bits 8-10  stack depth
//   bits 11+8i low byte of slot i (0 when slot i is outside the depth or has
//              zero length).  i = 0..5, bottom-up.
#include "leaf_common.h"

BINLINE uint32_t arity_val(const LStack& s, uint32_t i) {
  return (i < s.n && s.len[i] != 0) ? (uint32_t)s.e[i][0] : 0u;
}

BINLINE uint64_t arity_obs(uint32_t res, const LStack& s) {
  uint64_t r = (uint64_t)(res & 3u) | ((uint64_t)(s.n & 7u) << 8);
  r |= (uint64_t)arity_val(s, 0) << 11;
  r |= (uint64_t)arity_val(s, 1) << 19;
  r |= (uint64_t)arity_val(s, 2) << 27;
  r |= (uint64_t)arity_val(s, 3) << 35;
  r |= (uint64_t)arity_val(s, 4) << 43;
  r |= (uint64_t)arity_val(s, 5) << 51;
  return r;
}

#endif
