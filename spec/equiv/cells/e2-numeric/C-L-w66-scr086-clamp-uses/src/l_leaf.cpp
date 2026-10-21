#include "w32_twin.h"

// L leg -- SCR-086 at the depth/count consumers.
//
// The handler body below is copied VERBATIM from spec/equiv/twin/ops_ir.py
// (wires 0x79, 0x7a); build_w32.sh's provenance gate enforces byte-for-byte
// equality after mk_leaf.py's std::memcpy -> bounded_memcpy re-binding.  It
// contains the twin's stack-shift loop, which is present here only so the
// gate can attest the twin handler; the leaves exported by this file call
// the twin's own `decode_num` (w32_twin.h) and the handler's guard/index
// prefix, exactly the part of the body that reads the depth.  The clamp row
// ends at that value: the loop is downstream and is SCR-075's subject.
//
// The twin has no int32 clamp: decode_num returns an int64 and Lean keeps an
// unbounded Int.  These leaves therefore compare Core's clamped read (C leg)
// with the twin/Lean unclamped read (L leg) and prove the clamp is
// unobservable on every operand the call sites can accept.
using namespace twinleaf;

// OP_PICK/OP_ROLL handler -- verbatim twin/ops_ir.py body (wires 0x79, 0x7a).
static inline __attribute__((always_inline)) TwinErr op_OP_PICK(State& st, const Ctx& ctx, const Decoded& d) {
if (st.stack.n < 2) return TWIN_INVALID_STACK_OPERATION;
uint32_t nl = 0;
const uint8_t* nd = st_top(st.stack, 1, nl);
int64_t k = 0;
TwinErr e = decode_num(nd, nl, ctx.pol.minimalData, 4, k);
if (e != TWIN_OK) return e;
const uint32_t m = st.stack.n - 1;
if (k < 0 || static_cast<uint64_t>(k) >= m) return TWIN_INVALID_STACK_OPERATION;
const uint32_t idx = m - 1 - static_cast<uint32_t>(k);
if (d.wire == 0x79) {
  st.stack.n -= 1;
  return st_push(st.stack, st.stack.e[idx], st.stack.len[idx]);
}
uint8_t tmp[MAX_SCRIPT_ELEMENT_SIZE];
uint32_t tl = st.stack.len[idx];
bounded_memcpy(tmp, st.stack.e[idx], tl);
#pragma clang loop unroll(full)
for (uint32_t i = idx; i + 1 < st.stack.n - 1; ++i) {
  bounded_memcpy(st.stack.e[i], st.stack.e[i + 1], st.stack.len[i + 1]);
  st.stack.len[i] = st.stack.len[i + 1];
}
bounded_memcpy(st.stack.e[st.stack.n - 2], tmp, tl);
st.stack.len[st.stack.n - 2] = tl;
st.stack.n -= 1;
return TWIN_OK;
}

// -- getIntClamped (Numeric/ScriptNum.lean:741-744).  Proved for all int64 by
//    this leaf; the model itself does not apply it at these sites.
static inline __attribute__((always_inline)) int32_t lean_getIntClamped(int64_t n) {
  if (2147483647LL < n) return 2147483647;
  if (n < -2147483648LL) return -2147483648;
  return static_cast<int32_t>(n);
}

// -- decode_num (twin runtime.inc:167-188) is included from w32_twin.h.  This
//    wrapper materialises the cell's four scalar operand bytes so the twin
//    decoder itself (width check, minimality, set_vch) is what L executes.
static inline __attribute__((always_inline)) TwinErr twin_decode(uint32_t len, uint8_t b0, uint8_t b1,
                                  uint8_t b2, uint8_t b3, uint32_t minimal,
                                  int64_t& out) {
  const uint8_t d[5] = {b0, b1, b2, b3, 0};
  return decode_num(d, len, minimal != 0u, 4, out);
}

static inline uint64_t depth_pack(uint32_t status, uint32_t err, uint32_t idx,
                                  int32_t n) {
  return (uint64_t)(status & 3u)
       | ((uint64_t)(err & 0x3fu) << 2)
       | ((uint64_t)(idx & 0xffffu) << 8)
       | ((uint64_t)static_cast<uint32_t>(n) << 24);
}

static inline uint64_t key_pack(uint32_t status, int32_t n, uint32_t ikey2) {
  return (uint64_t)(status & 7u)
       | ((uint64_t)static_cast<uint32_t>(n) << 3)
       | ((uint64_t)(ikey2 & 0x3fu) << 35);
}

static inline uint64_t sig_pack(uint32_t status, int32_t ns, uint32_t ikey2,
                                uint32_t isig, uint32_t nkeys) {
  return (uint64_t)(status & 7u)
       | ((uint64_t)static_cast<uint32_t>(ns) << 3)
       | ((uint64_t)(ikey2 & 0x3fu) << 35)
       | ((uint64_t)(isig & 0x3fu) << 41)
       | ((uint64_t)(nkeys & 0x1fu) << 47);
}

extern "C" int32_t cell_clamp_int32(int64_t x) {
  return lean_getIntClamped(x);
}

// Twin decode + the handler's guard/index prefix, no clamp.  The negative and
// non-negative guard arms are split for the same reason as in the wave-65
// cell: a single `k < 0 || (uint64_t)k >= m` lets clang hoist a trunc-nuw of
// the int64 k above the negative test, which is immediate UB in the extracted
// IR.  The control flow that reaches the index is the twin handler's.
extern "C" uint64_t cell_depth_read(uint32_t len, uint8_t b0, uint8_t b1,
                                    uint8_t b2, uint8_t b3, uint8_t b4,
                                    uint32_t depth, uint32_t minimal) {
  (void)b4;
  if (depth > 1000u) return depth_pack(3, 0, 0, 0);
  if (depth < 2u) return depth_pack(2, 18, 0, 0);
  int64_t k = 0;
  const TwinErr e = twin_decode(len, b0, b1, b2, b3, minimal, k);
  if (e != TWIN_OK) return depth_pack(1, 4, 0, 0);
  const uint32_t m = depth - 1u;
  if (k < 0) return depth_pack(2, 18, 0, 0);
  if (static_cast<uint64_t>(k) >= m) return depth_pack(2, 18, 0, 0);
  const uint32_t idx = m - 1u - static_cast<uint32_t>(k);
  return depth_pack(0, 0, idx, static_cast<int32_t>(k));
}

extern "C" uint64_t cell_cms_key_count(uint32_t len, uint8_t b0, uint8_t b1,
                                       uint8_t b2, uint8_t b3,
                                       uint32_t opCount, uint32_t minimal) {
  if (opCount > 201u) return key_pack(7, 0, 0);
  int64_t nkv = 0;
  const TwinErr e = twin_decode(len, b0, b1, b2, b3, minimal, nkv);
  if (e != TWIN_OK) return key_pack(5, 0, 0);
  if (nkv < 0 || 20 < nkv) return key_pack(1, static_cast<int32_t>(nkv), 0);
  const int64_t nOpCount = static_cast<int64_t>(opCount) + nkv;
  if (201 < nOpCount) return key_pack(2, static_cast<int32_t>(nkv), 0);
  return key_pack(0, static_cast<int32_t>(nkv),
                  static_cast<uint32_t>(nkv) + 2u);
}

// CHECKMULTISIG nSigsCount path, split at the signature read (see c_leaf.cpp).
// The key-side read is the twin's decode_num plus the handler's cursor and
// depth gate, with no clamp; the signature-side read is the same shape.  Both
// legs and the oracle use uint32 cursors (exact on the reachable key-count
// domain 0..20; the read leaf's out-of-domain arm is the same on both legs).
extern "C" uint64_t cell_cms_sig_prefix(uint32_t lk, uint8_t kb0, uint8_t kb1,
                                        uint8_t kb2, uint8_t kb3,
                                        uint32_t depth, uint32_t opCount,
                                        uint32_t minimal) {
  if (depth > 1000u || opCount > 201u) return sig_pack(7, 0, 0, 0, 0);
  int64_t nkv = 0;
  TwinErr e = twin_decode(lk, kb0, kb1, kb2, kb3, minimal, nkv);
  if (e != TWIN_OK) return sig_pack(5, 0, 0, 0, 0);
  if (nkv < 0 || 20 < nkv)
    return sig_pack(1, 0, 0, 0, static_cast<uint32_t>(nkv));
  const int64_t total = static_cast<int64_t>(opCount) + nkv;
  if (201 < total) return sig_pack(2, 0, 0, 0, static_cast<uint32_t>(nkv));
  const uint32_t ikey2 = static_cast<uint32_t>(nkv) + 2u;
  const uint32_t i = 2u + static_cast<uint32_t>(nkv);
  if (depth < i) return sig_pack(3, 0, ikey2, 0, static_cast<uint32_t>(nkv));
  return sig_pack(0, 0, ikey2, 0, static_cast<uint32_t>(nkv));  // reached read
}

extern "C" uint64_t cell_cms_sig_read(int32_t nk, uint32_t depth, uint32_t ls,
                                      uint8_t sb0, uint8_t sb1, uint8_t sb2,
                                      uint8_t sb3, uint32_t minimal) {
  // Only reached from the prefix with 0 <= nk <= 20 (same domain arm as C).
  if (nk < 0 || nk > 20) return sig_pack(7, 0, 0, 0, 0);
  const uint32_t ikey2 = static_cast<uint32_t>(nk) + 2u;
  const uint32_t unk = static_cast<uint32_t>(nk);
  int64_t nsv = 0;
  const TwinErr e = twin_decode(ls, sb0, sb1, sb2, sb3, minimal, nsv);
  if (e != TWIN_OK) return sig_pack(5, 0, ikey2, 0, unk);
  if (nsv < 0 || static_cast<int64_t>(nk) < nsv)
    return sig_pack(4, static_cast<int32_t>(nsv), ikey2, 0, unk);
  const uint32_t isig = 3u + unk;
  if (depth < isig + static_cast<uint32_t>(nsv))
    return sig_pack(3, static_cast<int32_t>(nsv), ikey2, isig, unk);
  return sig_pack(0, static_cast<int32_t>(nsv), ikey2, isig, unk);
}
