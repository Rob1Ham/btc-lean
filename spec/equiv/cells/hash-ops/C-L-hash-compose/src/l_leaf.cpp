#include "hash_common.h"
// L leg: reviewed transliteration of the twin hash composition.
//
// Source of record: spec/equiv/twin/runtime.inc:555-564
//
//   static void hash160(const uint8_t* data, uint32_t len, uint8_t* out[20]) {
//     uint8_t s[32];
//     sha256(data, len, s);
//     ripemd160(s, 32, out);
//   }
//   static void hash256(const uint8_t* data, uint32_t len, uint8_t* out[32]) {
//     uint8_t s[32];
//     sha256(data, len, s);
//     sha256(s, 32, out);
//   }
//
// and the twin handlers for wires [0xa9] OP_HASH160 and [0xaa] OP_HASH256 in
// twin/ops_ir.py (Lean Defs.lean:637-643 hashForOp => hashHash160 /
// hashSha256d).  The handler body is verbatim:
//
//   if (st.stack.n < 1) return TWIN_INVALID_STACK_OPERATION;
//   uint32_t l = 0; const uint8_t* p = st_top(st.stack, 1, l);
//   uint8_t out[20|32]; hash160|hash256(p, l, out);
//   st.stack.n -= 1; return st_push(st.stack, out, 20|32);
//
// Only the cell stack representation is re-bound (32-byte slots, unrolled
// h_copy).  The two primitives are the same opaque externals the C leg calls.

extern "C" void sha256(const uint8_t* in, uint32_t len, uint8_t* out);
extern "C" void ripemd160(const uint8_t* in, uint32_t len, uint8_t* out);

namespace twinleaf_hash {

enum TwinErr : int32_t {
  TWIN_OK = 0,
  TWIN_PUSH_SIZE = 2,
  TWIN_STACK_SIZE = 4,
  TWIN_INVALID_STACK_OPERATION = 6,
};

BINLINE const uint8_t* st_top(const HStack& s, uint32_t k, uint32_t& len) {
  const uint32_t i = s.n - k;
  len = s.len[i];
  return s.e[i];
}

BINLINE int st_push(HStack& s, const uint8_t* data, uint32_t len) {
  if (len > HMAX_ELEM) return TWIN_PUSH_SIZE;
  if (s.n >= HMAX_DEPTH) return TWIN_STACK_SIZE;
  h_copy(s.e[s.n], data, len);
  s.len[s.n] = len;
  s.n += 1;
  return TWIN_OK;
}

// runtime.inc:555-559.
BINLINE void l_hash160(const uint8_t* data, uint32_t len, uint8_t out[20]) {
  uint8_t s[32];
  sha256(data, len, s);
  ripemd160(s, 32, out);
}

// runtime.inc:560-564.
BINLINE void l_hash256(const uint8_t* data, uint32_t len, uint8_t out[32]) {
  uint8_t s[32];
  sha256(data, len, s);
  sha256(s, 32, out);
}

BINLINE int op_hash160(HStack& st) {
  if (st.n < 1) return TWIN_INVALID_STACK_OPERATION;
  uint32_t l = 0;
  const uint8_t* p = st_top(st, 1, l);
  uint8_t out[20];
  l_hash160(p, l, out);
  st.n -= 1;
  return st_push(st, out, 20);
}

BINLINE int op_hash256(HStack& st) {
  if (st.n < 1) return TWIN_INVALID_STACK_OPERATION;
  uint32_t l = 0;
  const uint8_t* p = st_top(st, 1, l);
  uint8_t out[32];
  l_hash256(p, l, out);
  st.n -= 1;
  return st_push(st, out, 32);
}

}  // namespace twinleaf_hash

using namespace twinleaf_hash;

BINLINE uint32_t core_err(int e) {
  if (e == TWIN_PUSH_SIZE) return 6;
  if (e == TWIN_STACK_SIZE) return 8;
  if (e == TWIN_INVALID_STACK_OPERATION) return 18;
  return 1;
}

BINLINE uint64_t run_hash160(const uint8_t* pre, uint32_t len) {
  HStack st{};
  if (st_push(st, pre, len) != TWIN_OK) return h_pack(0, 1, st);
  const int e = op_hash160(st);
  return h_pack(e == TWIN_OK ? 1u : 0u, e == TWIN_OK ? 0u : core_err(e), st);
}
BINLINE uint64_t run_hash256(const uint8_t* pre, uint32_t len) {
  HStack st{};
  if (st_push(st, pre, len) != TWIN_OK) return h_pack(0, 1, st);
  const int e = op_hash256(st);
  return h_pack(e == TWIN_OK ? 1u : 0u, e == TWIN_OK ? 0u : core_err(e), st);
}

extern "C" uint64_t cell_hash160_empty() {
  const uint8_t pre[1] = {0};
  return run_hash160(pre, 0);
}
extern "C" uint64_t cell_hash160_a() {
  const uint8_t pre[1] = {0x61};
  return run_hash160(pre, 1);
}
extern "C" uint64_t cell_hash256_empty() {
  const uint8_t pre[1] = {0};
  return run_hash256(pre, 0);
}
extern "C" uint64_t cell_hash256_a() {
  const uint8_t pre[1] = {0x61};
  return run_hash256(pre, 1);
}

// ---- symbolic chain functions for Alive2 --------------------------------
// Twin handlers over 64-bit digest tokens.  The preimage is popped, the first
// primitive returns a token, the second primitive receives that token and the
// declared 32-byte intermediate length, and the second token fills the pushed
// element.  The handler body/width is the same as the real one above; only
// the digest bytes are tokenised (defined values).
extern "C" uint64_t sha256_pre(const uint8_t* in, uint32_t len);
extern "C" uint64_t ripemd160_mid(uint64_t mid, uint32_t len);
extern "C" uint64_t sha256_mid(uint64_t mid, uint32_t len);

BINLINE int op_hash160_chain(HStack& st) {
  if (st.n < 1) return TWIN_INVALID_STACK_OPERATION;
  uint32_t l = 0;
  const uint8_t* p = st_top(st, 1, l);
  const uint64_t mid = sha256_pre(p, l);
  const uint64_t tok = ripemd160_mid(mid, 32);
  uint8_t out[20];
  h_fill_token(out, 20, tok);
  st.n -= 1;
  return st_push(st, out, 20);
}
BINLINE int op_hash256_chain(HStack& st) {
  if (st.n < 1) return TWIN_INVALID_STACK_OPERATION;
  uint32_t l = 0;
  const uint8_t* p = st_top(st, 1, l);
  const uint64_t mid = sha256_pre(p, l);
  const uint64_t tok = sha256_mid(mid, 32);
  uint8_t out[32];
  h_fill_token(out, 32, tok);
  st.n -= 1;
  return st_push(st, out, 32);
}
BINLINE uint64_t run_chain160(const uint8_t* pre, uint32_t len) {
  HStack st{};
  if (st_push(st, pre, len) != TWIN_OK) return h_pack(0, 1, st);
  const int e = op_hash160_chain(st);
  return h_pack(e == TWIN_OK ? 1u : 0u, e == TWIN_OK ? 0u : core_err(e), st);
}
BINLINE uint64_t run_chain256(const uint8_t* pre, uint32_t len) {
  HStack st{};
  if (st_push(st, pre, len) != TWIN_OK) return h_pack(0, 1, st);
  const int e = op_hash256_chain(st);
  return h_pack(e == TWIN_OK ? 1u : 0u, e == TWIN_OK ? 0u : core_err(e), st);
}
extern "C" uint64_t cell_hash160_empty_chain() {
  const uint8_t pre[1] = {0};
  return run_chain160(pre, 0);
}
extern "C" uint64_t cell_hash160_a_chain() {
  const uint8_t pre[1] = {0x61};
  return run_chain160(pre, 1);
}
extern "C" uint64_t cell_hash256_empty_chain() {
  const uint8_t pre[1] = {0};
  return run_chain256(pre, 0);
}
extern "C" uint64_t cell_hash256_a_chain() {
  const uint8_t pre[1] = {0x61};
  return run_chain256(pre, 1);
}
