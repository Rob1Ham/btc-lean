#ifndef CELL_DEPTH_SIZE_OBS_H
#define CELL_DEPTH_SIZE_OBS_H
// Cell-local observables for stack-ops/C-L-depth-size.
//
// DEPTH: res:2 | depth:3<<8 | four slots, each (len:1 | b0:8) at 11+9i
//   The top slot is the CScriptNum that DEPTH just pushed.
// SIZE:  res:2 | depth:2<<8 | original len:10<<10 | original b0:8<<20 |
//        result len:2<<28 | result b0:8<<30 | result b1:8<<38
//   The original element (slot 0) is preserved by SIZE; slot 1 is the size.
// Ten bits hold the full 0..520 element-size range.  Both helpers read fixed
// slots, or the current top for DEPTH, and mask after loading.
#include "leaf_common.h"

BINLINE uint64_t pack_dcount(uint32_t res, const LStack& s) {
  // Four fixed slots, exactly like pack_obs: no dynamic top index, so the
  // optimiser cannot lower a guard into llvm.usub.sat.
  uint64_t r = (uint64_t)(res & 3u) | ((uint64_t)(s.n & 7u) << 8);
  r |= (uint64_t)(obs_len(s, 0) & 1u) << 11; r |= (uint64_t)obs_lo(s, 0) << 12;
  r |= (uint64_t)(obs_len(s, 1) & 1u) << 20; r |= (uint64_t)obs_lo(s, 1) << 21;
  r |= (uint64_t)(obs_len(s, 2) & 1u) << 29; r |= (uint64_t)obs_lo(s, 2) << 30;
  r |= (uint64_t)(obs_len(s, 3) & 1u) << 38; r |= (uint64_t)obs_lo(s, 3) << 39;
  return r;
}

BINLINE uint64_t pack_size(uint32_t res, const LStack& s) {
  // Success shape only: slot 0 is the original element, slot 1 the size.
  const uint32_t ol = s.len[0];
  const uint32_t ob = s.e[0][0];
  const uint32_t sl = s.len[1];
  const uint32_t sb0 = s.e[1][0];
  const uint32_t sb1 = s.e[1][1];
  uint64_t r = (uint64_t)(res & 3u) | ((uint64_t)(s.n & 3u) << 8);
  r |= (uint64_t)(ol & 0x3ffu) << 10;
  r |= (uint64_t)(ob & 0xffu) << 20;
  r |= (uint64_t)(sl & 3u) << 28;
  r |= (uint64_t)(sb0 & 0xffu) << 30;
  r |= (uint64_t)(sb1 & 0xffu) << 38;
  return r;
}

#endif
