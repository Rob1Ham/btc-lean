#include "gate_common.h"
// C leg: exact source slices from Bitcoin Core cce32b168
// src/script/interpreter.cpp.  Line cites are in each function and spec.md.
BINLINE uint32_t core_push(BStack& s, uint32_t v) {
  if (s.n >= 6) return 8;                       // SCRIPT_ERR_STACK_SIZE
  s.len[s.n] = 1; s.val[s.n] = v; s.n += 1;     // OP_1..OP_16 (500-529)
  return 0;
}
BINLINE uint32_t core_push_empty(BStack& s) {
  if (s.n >= 6) return 8;
  s.len[s.n] = 0; s.val[s.n] = 0; s.n += 1;       // OP_0
  return 0;
}
BINLINE uint32_t core_verify(BStack& s) {
  if (s.n < 1) return 18;                         // 663-674
  if (!b_truth(s, s.n - 1)) return 11;            // SCRIPT_ERR_VERIFY
  s.n -= 1;                                        // success pops
  return 0;
}
BINLINE uint32_t core_drop(BStack& s) {
  if (s.n < 1) return 18;                         // 795-802
  s.n -= 1;
  return 0;
}
BINLINE uint32_t core_equal(BStack& s) {
  if (s.n < 2) return 18;                       // 897-910
  const uint32_t a = s.n - 2, b = s.n - 1;
  uint32_t eq = (s.len[a] == s.len[b]);
  if (eq && s.len[a] >= 1 && b_byte(s,a,0) != b_byte(s,b,0)) eq = 0;
  if (eq && s.len[a] >= 2 && b_byte(s,a,1) != b_byte(s,b,1)) eq = 0;
  s.n -= 2;
  // Core pushes vchTrue={1} on equality and vchFalse={} (empty) otherwise.
  s.len[s.n] = eq ? 1u : 0u; s.val[s.n] = eq ? 1u : 0u; s.n += 1;
  return 0;
}
BINLINE void core_move(BStack& d, uint32_t di, const BStack& s, uint32_t si) {
  d.len[di] = s.len[si]; d.val[di] = s.val[si];
}
BINLINE uint32_t core_swap(BStack& s) {
  if (s.n < 2) return 18;                       // 863-869
  const uint32_t a = s.n - 2, b = s.n - 1;
  const uint32_t la=s.len[a], va=s.val[a];
  s.len[a]=s.len[b]; s.val[a]=s.val[b];
  s.len[b]=la; s.val[b]=va;
  return 0;
}
BINLINE uint32_t core_dup(BStack& s) {
  if (s.n < 1) return 18;                       // 804-810
  if (s.n >= 6) return 8;
  core_move(s, s.n, s, s.n - 1); s.n += 1;
  return 0;
}
BINLINE uint32_t core_rot(BStack& s) {
  if (s.n < 3) return 18;                       // 851-861
  const uint32_t c=s.n-3, b=s.n-2, a=s.n-1;
  const uint32_t lc=s.len[c], vc=s.val[c];
  s.len[c]=s.len[b]; s.val[c]=s.val[b];
  s.len[b]=s.len[a]; s.val[b]=s.val[a];
  s.len[a]=lc; s.val[a]=vc;
  return 0;
}
BINLINE uint32_t core_depth(BStack& s) {
  if (s.n >= 6) return 8;                       // 787-792
  const uint32_t d = s.n;
  s.len[s.n] = d == 0 ? 0u : 1u;
  s.val[s.n] = d;
  s.n += 1;
  return 0;
}
BINLINE uint32_t core_pick(BStack& s) {
  if (s.n < 2) return 18;                       // 833-849 (PICK only)
  const uint32_t nl = s.len[s.n-1];
  if (nl > 1) return 18;                        // bounded cell: numeric len <= 1
  int64_t k = (int64_t)(s.val[s.n-1] & 0xffu);
  if (nl == 1 && (s.val[s.n-1] & 0x80u)) k = -(int64_t)(s.val[s.n-1] & 0x7fu);
  s.n -= 1;
  if (k < 0 || (uint64_t)k >= (uint64_t)s.n) return 18;
  const uint32_t idx = s.n - 1 - (uint32_t)k;
  if (s.n >= 6) return 8;
  core_move(s, s.n, s, idx); s.n += 1;
  return 0;
}
BINLINE uint32_t core_toalt(BStack& s, BStack& a) {
  if (s.n < 1) return 18;                       // 687-694
  if (a.n >= 4) return 8;
  core_move(a, a.n, s, s.n - 1); a.n += 1; s.n -= 1;
  return 0;
}
BINLINE uint32_t core_fromalt(BStack& s, BStack& a) {
  if (a.n < 1) return 19;                       // 696-703
  if (s.n >= 6) return 8;
  core_move(s, s.n, a, a.n - 1); s.n += 1; a.n -= 1;
  return 0;
}
BINLINE uint64_t core_finish(BStack& s, BStack& a) {
  if (a.n != 0) return b_pack(3, 1, s);         // harness: alt must be empty
  if (s.n == 0) return b_pack(0, 2, s);         // 1876-1880 EVAL_FALSE
  if (!b_truth(s, s.n - 1)) return b_pack(0, 2, s);
  return b_pack(1, 0, s);
}
#define CSTEP(x) do { uint32_t _e = (x); if (_e) return b_pack(0, _e, s); } while (0)
extern "C" uint64_t cell_swap_order() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_push(s, 1)); CSTEP(core_push(s, 2)); CSTEP(core_swap(s));
  CSTEP(core_push(s, 1)); CSTEP(core_equal(s));
  return core_finish(s, a);
}
extern "C" uint64_t cell_dup_order() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_push(s, 1)); CSTEP(core_push(s, 2)); CSTEP(core_dup(s));
  CSTEP(core_push(s, 2)); CSTEP(core_equal(s));
  return core_finish(s, a);
}
extern "C" uint64_t cell_rot_direction() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_push(s, 1)); CSTEP(core_push(s, 2)); CSTEP(core_push(s, 3));
  CSTEP(core_rot(s)); CSTEP(core_push(s, 1)); CSTEP(core_equal(s));
  return core_finish(s, a);
}
extern "C" uint64_t cell_roundtrip() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_push(s, 1)); CSTEP(core_push(s, 2));
  CSTEP(core_toalt(s, a)); CSTEP(core_fromalt(s, a));
  CSTEP(core_push(s, 2)); CSTEP(core_equal(s));
  return core_finish(s, a);
}
extern "C" uint64_t cell_depth_count() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_push(s, 1)); CSTEP(core_push(s, 1)); CSTEP(core_depth(s));
  CSTEP(core_push(s, 2)); CSTEP(core_equal(s));
  return core_finish(s, a);
}
extern "C" uint64_t cell_pick_depth() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_push(s, 1)); CSTEP(core_push(s, 2)); CSTEP(core_push(s, 3));
  CSTEP(core_push(s, 2)); CSTEP(core_pick(s));
  CSTEP(core_push(s, 1)); CSTEP(core_equal(s));
  return core_finish(s, a);
}

// Broader C-L concrete edge functions.  These are still closed witnesses,
// not the symbolic broader cells described in findings/cells/E1-report.md.
extern "C" uint64_t cell_verify_true() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_push(s, 1)); CSTEP(core_verify(s)); CSTEP(core_push(s, 1));
  return core_finish(s, a);
}
extern "C" uint64_t cell_verify_false() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_push_empty(s)); CSTEP(core_verify(s));
  return core_finish(s, a);
}
extern "C" uint64_t cell_verify_empty() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_verify(s));
  return core_finish(s, a);
}
extern "C" uint64_t cell_dup_underflow() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_dup(s));
  return core_finish(s, a);
}
extern "C" uint64_t cell_swap_underflow() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_swap(s));
  return core_finish(s, a);
}
extern "C" uint64_t cell_drop_underflow() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_drop(s));
  return core_finish(s, a);
}
extern "C" uint64_t cell_alt_from_empty() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_fromalt(s, a));
  return core_finish(s, a);
}
extern "C" uint64_t cell_alt_to_empty() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_toalt(s, a));
  return core_finish(s, a);
}
extern "C" uint64_t cell_alt_roundtrip() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_push(s, 1)); CSTEP(core_push(s, 2));
  CSTEP(core_toalt(s, a)); CSTEP(core_fromalt(s, a));
  return core_finish(s, a);
}

extern "C" uint64_t cell_dup_drop_swap_ok() {
  BStack s, a; b_clear(s); b_clear(a);
  CSTEP(core_push(s, 1)); CSTEP(core_push(s, 2));
  CSTEP(core_dup(s)); CSTEP(core_swap(s));
  CSTEP(core_push(s, 2)); CSTEP(core_equal(s)); CSTEP(core_drop(s));
  return core_finish(s, a);
}
