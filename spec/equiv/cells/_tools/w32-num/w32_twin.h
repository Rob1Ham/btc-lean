#ifndef CELLS_W32_TWIN_H
#define CELLS_W32_TWIN_H
// Wave-32 L-leg harness: the twin's imperative IR types and bounded stack
// primitives, re-bound to the w32 domain (4-deep stack, 5-byte elements).
//
// This file is cell harness, not engine semantics.  It mirrors
// cells/_tools/mk_leaf.py's generated prologue, with exactly two re-bindings
// required by the 4-byte CScriptNum rows:
//   * element width 5 (core results may be 5 bytes) and bounded copies over 5
//     bytes instead of 2;
//   * decode_num accepts up to 4 bytes instead of 2 (Core's nMaxNumSize).
// Like mk_leaf.py's prologue, every primitive is loop-free over the fixed
// bounded width so Alive2 can execute the leaves symbolically without a loop
// unrolling assumption.  The handler bodies in each cell's src/l_leaf.cpp are
// verbatim from twin/ops_ir.py; build_w32.sh enforces that.
#include <cstdint>
#include <cstring>
#include "w32_common.h"
#include "twin_err.h"

namespace twinleaf {

constexpr uint32_t MAX_SCRIPT_ELEMENT_SIZE = W32_ELEM;
constexpr uint32_t MAX_STACK_SIZE = W32_DEPTH;

struct ScriptFlags { bool p2sh, dersig, cltv, csv, nullDummy, witness, taproot; };
struct PolicyFlags {
  bool minimalData, minimalIf, nullFail, strictEnc, constScriptCode, cleanstack;
  bool sigPushOnly, lowS, witnessPubkeyType, discourageUpgradableNops;
  bool discourageUpgradableWitnessProgram, discourageUpgradablePubkeyType;
  bool discourageOpSuccess, discourageUpgradableTaprootVersion;
};
enum class SigVersion : uint8_t { Base, WitnessV0, Tapscript };
struct Ctx { ScriptFlags flags; PolicyFlags pol; SigVersion sv; };
enum class Kind : uint8_t { PushBytes, PushNum, Op };
struct Decoded { Kind kind; const uint8_t* data; uint32_t dlen; uint32_t wire; uint32_t next; };
struct Stack {
  uint32_t n;
  uint32_t len[W32_DEPTH];
  uint8_t e[W32_DEPTH][W32_ELEM];
};
struct State {
  Stack stack;
  Stack alt;
  Stack saved;
  bool vf[1];
  uint32_t vf_n, opCount;
  uint32_t codeSep, codeSepPos, opcodeIndex;
  int64_t vwLeft;
  bool has_vw;
};

// Bounded, loop-free memory primitives.  Extensionally equal to
// std::memcpy/std::memcmp for len <= MAX_SCRIPT_ELEMENT_SIZE (5).
W32_BINLINE void bounded_memcpy(uint8_t* d, const uint8_t* s, uint32_t len) {
  if (len >= 1) d[0] = s[0];
  if (len >= 2) d[1] = s[1];
  if (len >= 3) d[2] = s[2];
  if (len >= 4) d[3] = s[3];
  if (len >= 5) d[4] = s[4];
}
W32_BINLINE int bounded_memcmp(const uint8_t* a, const uint8_t* b, uint32_t len) {
  if (len >= 1 && a[0] != b[0]) return (int)a[0] - (int)b[0];
  if (len >= 2 && a[1] != b[1]) return (int)a[1] - (int)b[1];
  if (len >= 3 && a[2] != b[2]) return (int)a[2] - (int)b[2];
  if (len >= 4 && a[3] != b[3]) return (int)a[3] - (int)b[3];
  if (len >= 5 && a[4] != b[4]) return (int)a[4] - (int)b[4];
  return 0;
}
W32_BINLINE TwinErr st_push(Stack& s, const uint8_t* data, uint32_t len) {
  if (len > MAX_SCRIPT_ELEMENT_SIZE) return TWIN_PUSH_SIZE;
  if (s.n >= MAX_STACK_SIZE) return TWIN_STACK_SIZE;
  if (len != 0) bounded_memcpy(s.e[s.n], data, len);
  s.len[s.n] = len;
  s.n += 1;
  return TWIN_OK;
}
W32_BINLINE const uint8_t* st_top(const Stack& s, uint32_t k, uint32_t& len) {
  const uint32_t i = s.n - k;
  len = s.len[i];
  return s.e[i];
}
W32_BINLINE TwinErr st_push_copy(Stack& s, uint32_t k) {
  if (s.n < k) return TWIN_INVALID_STACK_OPERATION;
  const uint32_t i = s.n - k;
  const uint32_t l = s.len[i];
  if (l > MAX_SCRIPT_ELEMENT_SIZE) return TWIN_PUSH_SIZE;
  if (s.n >= MAX_STACK_SIZE) return TWIN_STACK_SIZE;
  bounded_memcpy(s.e[s.n], s.e[i], l);
  s.len[s.n] = l;
  s.n += 1;
  return TWIN_OK;
}
// CScriptNum::serialize (script.h:337-372) as mk_leaf.py's bounded form:
// a straight-line 4-byte magnitude plus the sign rule, writing all five
// output bytes at constant indices.  Values this cell can emit have
// |v| < 2^32, so the magnitude is at most four bytes (the mk_leaf form's
// four steps).  Writing the unused tail bytes too is representation only:
// st_push copies exactly n bytes.
W32_BINLINE uint32_t encode_num(int64_t v, uint8_t* out) {
  const bool neg = v < 0;
  const uint64_t a = neg ? (static_cast<uint64_t>(-(v + 1)) + 1u) : static_cast<uint64_t>(v);
  const uint8_t m0 = static_cast<uint8_t>(a & 0xffu);
  const uint8_t m1 = static_cast<uint8_t>((a >> 8) & 0xffu);
  const uint8_t m2 = static_cast<uint8_t>((a >> 16) & 0xffu);
  const uint8_t m3 = static_cast<uint8_t>((a >> 24) & 0xffu);
  uint8_t o0 = 0, o1 = 0, o2 = 0, o3 = 0, o4 = 0;
  uint32_t n = 0;
  if (v != 0) {
    const uint32_t k = (a >> 24) ? 4 : (a >> 16) ? 3 : (a >> 8) ? 2 : 1;
    const uint8_t top = (k == 4) ? m3 : (k == 3) ? m2 : (k == 2) ? m1 : m0;
    const uint8_t sgn = neg ? 0x80u : 0x00u;
    o0 = m0; o1 = m1; o2 = m2; o3 = m3;
    if (top & 0x80u) {
      if (k == 1) o1 = sgn; else if (k == 2) o2 = sgn;
      else if (k == 3) o3 = sgn; else o4 = sgn;
      n = k + 1;
    } else {
      if (neg) {
        if (k == 1) o0 = static_cast<uint8_t>(o0 | 0x80u);
        else if (k == 2) o1 = static_cast<uint8_t>(o1 | 0x80u);
        else if (k == 3) o2 = static_cast<uint8_t>(o2 | 0x80u);
        else o3 = static_cast<uint8_t>(o3 | 0x80u);
      }
      n = k;
    }
  }
  out[0] = o0; out[1] = o1; out[2] = o2; out[3] = o3; out[4] = o4;
  return n;
}
W32_BINLINE TwinErr st_push_num(Stack& s, int64_t v) {
  uint8_t tmp[W32_ELEM];
  const uint32_t n = encode_num(v, tmp);
  return st_push(s, tmp, n);
}
// Bounded CScriptNum decode for len <= 4 (Core's nDefaultMaxNumSize).
W32_BINLINE TwinErr decode_num(const uint8_t* d, uint32_t len, bool minimal,
                              uint32_t maxlen, int64_t& out) {
  if (len > maxlen || len > 4) return TWIN_SCRIPTNUM;
  if (len == 0) { out = 0; return TWIN_OK; }
  const bool neg = (d[len - 1] & 0x80u) != 0;
  if (minimal && (d[len - 1] & 0x7fu) == 0 && (len == 1 || (d[len - 2] & 0x80u) == 0))
    return TWIN_SCRIPTNUM;
  uint64_t v = d[0];
  if (len >= 2) v |= static_cast<uint64_t>(d[1]) << 8;
  if (len >= 3) v |= static_cast<uint64_t>(d[2]) << 16;
  if (len >= 4) v |= static_cast<uint64_t>(d[3]) << 24;
  if (neg) { v &= ~(0x80ull << (8u * (len - 1))); out = -static_cast<int64_t>(v); }
  else out = static_cast<int64_t>(v);
  return TWIN_OK;
}
W32_BINLINE bool cast_to_bool(const uint8_t* d, uint32_t len) {
  return w32_truth(d, len);
}

W32_BINLINE void l_init(State& st) {
  st = State{};
  st.codeSepPos = 0xffffffffu;
}
W32_BINLINE void l_put(State& st, const uint8_t* d, uint32_t l) {
  const uint32_t i = st.stack.n;
  st.stack.len[i] = l;
  st.stack.e[i][0] = (0 < l) ? d[0] : 0;
  st.stack.e[i][1] = (1 < l) ? d[1] : 0;
  st.stack.e[i][2] = (2 < l) ? d[2] : 0;
  st.stack.e[i][3] = (3 < l) ? d[3] : 0;
  st.stack.e[i][4] = (4 < l) ? d[4] : 0;
  st.stack.n += 1;
}
W32_BINLINE void l_to_w32(const State& st, W32& s) {
  s = W32{};
  s.n = st.stack.n;
  // n <= W32_DEPTH by construction; copy all four slots straight-line.
  s.len[0] = st.stack.len[0];
  s.len[1] = st.stack.len[1];
  s.len[2] = st.stack.len[2];
  s.len[3] = st.stack.len[3];
  s.e[0][0] = st.stack.e[0][0]; s.e[0][1] = st.stack.e[0][1];
  s.e[0][2] = st.stack.e[0][2]; s.e[0][3] = st.stack.e[0][3];
  s.e[0][4] = st.stack.e[0][4];
  s.e[1][0] = st.stack.e[1][0]; s.e[1][1] = st.stack.e[1][1];
  s.e[1][2] = st.stack.e[1][2]; s.e[1][3] = st.stack.e[1][3];
  s.e[1][4] = st.stack.e[1][4];
  s.e[2][0] = st.stack.e[2][0]; s.e[2][1] = st.stack.e[2][1];
  s.e[2][2] = st.stack.e[2][2]; s.e[2][3] = st.stack.e[2][3];
  s.e[2][4] = st.stack.e[2][4];
  s.e[3][0] = st.stack.e[3][0]; s.e[3][1] = st.stack.e[3][1];
  s.e[3][2] = st.stack.e[3][2]; s.e[3][3] = st.stack.e[3][3];
  s.e[3][4] = st.stack.e[3][4];
}
W32_BINLINE uint64_t l_fail(const State& st, TwinErr e) {
  W32 s;
  l_to_w32(st, s);
  return w32_pack(0, static_cast<uint32_t>(core_ord(e)), s);
}
// Error path with no stack observable (see w32_pack_err): the twin's handler
// may return before applying every pop that Core performs before the error.
W32_BINLINE uint64_t l_fail_err(TwinErr e) {
  return w32_pack_err(static_cast<uint32_t>(core_ord(e)));
}
W32_BINLINE uint64_t l_finish(const State& st) {
  W32 s;
  l_to_w32(st, s);
  return w32_finish(s);
}
// Cell-domain sentinel: an opcode this leaf does not implement (mk_leaf's
// TWIN_INVALID_UNSUPPORTED -> result 3, error UNKNOWN_ERROR=1).
W32_BINLINE uint64_t l_unsupported(const State& st) {
  W32 s;
  l_to_w32(st, s);
  return w32_pack(3, 1, s);
}
}  // namespace twinleaf
#endif
