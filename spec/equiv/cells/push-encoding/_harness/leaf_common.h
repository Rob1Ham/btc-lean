#ifndef CELLS_PUSH_LEAF_COMMON_H
#define CELLS_PUSH_LEAF_COMMON_H
// Family-local bounded leaf harness (push-encoding).
//
// NOT engine code and not part of the trust base for a semantics claim: this
// header only holds the bounded stack storage, the 64-bit packed observable,
// and the leaf-domain marker.  Both legs call the *same* functions here, so a
// tool comparison sees engine behaviour, not harness drift.
//
// Include order in every leaf:
//     #include "twin_ops.h"        // cells/_tools/mk_leaf.py prelude+handlers
//     #include "twin_extras.h"     // verbatim twin/runtime.inc helpers
//     #include "leaf_common.h"      // this file
#include <cstdint>
#include <cstddef>
#include "error_kind.h"

#define BINLINE static inline __attribute__((always_inline))

// Leaf-domain marker: the input is outside the cell's stated domain.  It is
// harness, applied identically on both legs, and is never an engine verdict
// (ABI result 3 = internal/exception, error_kind UNKNOWN_ERROR).
static inline uint64_t pack_domain() { return 3u | (1u << 2); }

constexpr uint32_t LEAF_MAXD = twinleaf::MAX_STACK_SIZE;
constexpr uint32_t LEAF_MAXE = twinleaf::MAX_SCRIPT_ELEMENT_SIZE;
constexpr uint32_t LEAF_MAX_OPS_PER_SCRIPT = 201;  // Core/twin consensus constant

// Bounded stack: index 0 = bottom, n-1 = top (same orientation as Core and the
// twin).  Element length is bounded by LEAF_MAXE; storage is exact up to that
// bound and the runner asserts it (`mk_leaf --max-elem`).
struct LStack {
  uint32_t n;
  uint32_t len[LEAF_MAXD];
  uint8_t e[LEAF_MAXD][LEAF_MAXE];
};

static inline void ls_clear(LStack& s) {
  s.n = 0;
  for (uint32_t i = 0; i < LEAF_MAXD; ++i) {
    s.len[i] = 0;
    for (uint32_t j = 0; j < LEAF_MAXE; ++j) s.e[i][j] = 0;
  }
}

static inline void ls_push(LStack& s, const uint8_t* d, uint32_t l) {
  if (s.n >= LEAF_MAXD) return;              // harness bound, excluded by domain
  if (l != 0) {
    s.e[s.n][0] = d[0];
    if constexpr (LEAF_MAXE >= 2) { if (l >= 2) s.e[s.n][1] = d[1]; }
  }
  s.len[s.n] = l;
  s.n += 1;
}

// Copy a twinleaf::Stack (L leg) into the bounded observable stack.
static inline void ls_of(const twinleaf::Stack& src, LStack& dst) {
  ls_clear(dst);
  dst.n = src.n;
  for (uint32_t i = 0; i < src.n && i < LEAF_MAXD; ++i) {
    dst.len[i] = src.len[i];
    for (uint32_t j = 0; j < src.len[i] && j < LEAF_MAXE; ++j) dst.e[i][j] = src.e[i][j];
  }
}

// ---- packed observables ---------------------------------------------------
// All formats are explicit and identical on both legs.  Every helper is fully
// unrolled (no loop, no subtraction that the optimiser can turn into a
// saturating intrinsic): the tools get loop-free leaf IR.
//   bits 0-1  result (0 fail, 1 pass, 3 leaf-domain marker)
//   bits 2-7  error_kind ordinal (0..63)
//   bits 8-11 stack depth
// `pack_obs` then observes the BOTTOM four element slots as
// (len:1 | val-lo:8) each; for every cell whose depth is <= 4 that is the
// whole stack.  `pack_d2` observes the bottom two slots as (len:2 | val:16).
// `pack_vals` observes all six bottom slots as 8-bit values plus depth:3.
// On an error the stack is *not* part of the ABI observable (ABI §4: only the
// verdict and error_kind are returned), so `pack_fail` canonicalises the
// depth/element fields to zero.  This is a cell convention, applied
// identically to both legs.
static inline uint64_t pack_fail(uint32_t err) {
  return (uint64_t)(err & 0x3fu) << 2;
}

// The loads are unconditional and the "outside the stack" mask is applied
// afterwards.  A guarded load lets the optimiser prove the four slot reads are
// contiguous when depth >= 4 and re-base them as `(n - 4) + i`, which lowers to
// `llvm.usub.sat.i32` -- an intrinsic that SAW/abc cannot load.  Loading first
// and masking second keeps every index a compile-time constant.  The values are
// identical: storage at or above the depth is always zeroed by the bounded
// stack helpers, and the mask makes the observable independent of that anyway.
static inline uint32_t obs_len(const LStack& s, uint32_t idx) {
  const uint32_t v = s.len[idx];
  return idx < s.n ? v : 0u;
}
static inline uint32_t obs_lo(const LStack& s, uint32_t idx) {
  const uint32_t v = (uint32_t)s.e[idx][0];
  return (idx < s.n && s.len[idx] != 0) ? v : 0u;
}
static inline uint32_t obs_hi(const LStack& s, uint32_t idx) {
  if constexpr (LEAF_MAXE >= 2) {
    const uint32_t v = (uint32_t)s.e[idx][1];
    return (idx < s.n && s.len[idx] >= 2) ? v : 0u;
  } else {
    return 0u;
  }
}

static inline uint64_t pack_obs(uint32_t res, const LStack& s) {
  uint64_t r = (uint64_t)(res & 3u) | ((uint64_t)(s.n & 0xfu) << 8);
  r |= (uint64_t)(obs_len(s, 0) & 1u) << 12; r |= (uint64_t)obs_lo(s, 0) << 13;
  r |= (uint64_t)(obs_len(s, 1) & 1u) << 21; r |= (uint64_t)obs_lo(s, 1) << 22;
  r |= (uint64_t)(obs_len(s, 2) & 1u) << 30; r |= (uint64_t)obs_lo(s, 2) << 31;
  r |= (uint64_t)(obs_len(s, 3) & 1u) << 39; r |= (uint64_t)obs_lo(s, 3) << 40;
  return r;
}

static inline uint64_t pack_d2(uint32_t res, const LStack& s) {
  uint64_t r = (uint64_t)(res & 3u) | ((uint64_t)(s.n & 0xfu) << 8);
  r |= (uint64_t)(obs_len(s, 0) & 3u) << 12;
  r |= (uint64_t)((obs_lo(s, 0) | (obs_hi(s, 0) << 8)) & 0xffffu) << 14;
  r |= (uint64_t)(obs_len(s, 1) & 3u) << 30;
  r |= (uint64_t)((obs_lo(s, 1) | (obs_hi(s, 1) << 8)) & 0xffffu) << 32;
  return r;
}

static inline uint64_t pack_vals(uint32_t res, uint32_t err, const LStack& s) {
  uint64_t r = (uint64_t)(res & 3u) | ((uint64_t)(err & 0x3fu) << 2) |
               ((uint64_t)(s.n & 0x7u) << 8);
  r |= (uint64_t)obs_lo(s, 0) << 11;
  r |= (uint64_t)obs_lo(s, 1) << 19;
  r |= (uint64_t)obs_lo(s, 2) << 27;
  r |= (uint64_t)obs_lo(s, 3) << 35;
  r |= (uint64_t)obs_lo(s, 4) << 43;
  r |= (uint64_t)obs_lo(s, 5) << 51;
  return r;
}

// Numeric-operand observable: res:2 | err:6<<2 | sign:1<<8 | magnitude:15<<9.
// Sign and magnitude are kept apart (rather than a two's-complement field) so
// the Cryptol side never has to model a negative bit-vector.
static inline uint64_t pack_snum(uint32_t res, uint32_t err, int64_t v) {
  const uint64_t mag = (uint64_t)(v < 0 ? -v : v) & 0x7fffu;
  return (uint64_t)(res & 3u) | ((uint64_t)(err & 0x3fu) << 2) |
         ((uint64_t)(v < 0) << 8) | (mag << 9);
}

// Push-parse observable: res:2 | err:6<<2 | next:5<<8 | dlen:4<<13 |
// first payload byte:8<<17.  `next` is the parse cursor after the push (1..9),
// `dlen` the declared payload length, `first` the first payload byte (0 when
// dlen == 0).  A failed parse canonicalises the shape fields to zero.
static inline uint64_t pack_parse(uint32_t res, uint32_t err, uint32_t next,
                                  uint32_t dlen, uint32_t first) {
  return (uint64_t)(res & 3u) | ((uint64_t)(err & 0x3fu) << 2) |
         ((uint64_t)(next & 0x1fu) << 8) | ((uint64_t)(dlen & 0xfu) << 13) |
         ((uint64_t)(first & 0xffu) << 17);
}
#endif
