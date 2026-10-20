#include "hash_common.h"
// L leg: reviewed transliteration of the twin hash handlers.
//
// Source of record: spec/equiv/twin/ops_ir.py, OPS entries for wires
// [0xa6] OP_RIPEMD160, [0xa8] OP_SHA256, [0xa9] OP_HASH160, [0xaa] OP_HASH256
// (Lean Defs.lean:1028-1030; generator.md:231).  Each body is copied
// verbatim:
//
//   if (st.stack.n < 1) return TWIN_INVALID_STACK_OPERATION;
//   uint32_t l = 0; const uint8_t* p = st_top(st.stack, 1, l);
//   uint8_t out[20|32]; <primitive>(p, l, out);
//   st.stack.n -= 1; return st_push(st.stack, out, 20|32);
//
// SHA1 (wire 0xa7) is the fifth arm and is CELL-LOCAL.  The pinned shared
// twin maps 0xa7 to OP_UNSUPPORTED_SHA1 (result 3), because twin/runtime.inc
// has no sha1 primitive.  This cell carries a reviewed cell-local body with
// the same plumbing as the four implemented operators, anchored to Lean
// Defs.lean:1028-1030 + hashForOp 0xa7 => hashSha1 (Hashes.lean:133+) and to
// Core interpreter.cpp:1043-1047 CSHA1.  The transform remains an opaque
// `sha1` external, shared by both legs; no SHA1 internals are implemented or
// claimed here.  This arm does not change the shared twin's declared subset.
//
// The only re-binding is the cell stack representation: element width 32 and
// the unrolled h_copy instead of mk_leaf's two-byte bounded_memcpy.  The
// handler semantics are unchanged.  The five primitives are the same opaque
// externals the C leg calls.

extern "C" void ripemd160(const uint8_t* in, uint32_t len, uint8_t* out);
extern "C" void sha1(const uint8_t* in, uint32_t len, uint8_t* out);
extern "C" void sha256(const uint8_t* in, uint32_t len, uint8_t* out);
extern "C" void hash160(const uint8_t* in, uint32_t len, uint8_t* out);
extern "C" void hash256(const uint8_t* in, uint32_t len, uint8_t* out);

namespace twinleaf_hash {

// TwinErr ids used by these handlers (twin/gen.py ERRORS).
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

BINLINE int op_ripemd160(HStack& st) {
  if (st.n < 1) return TWIN_INVALID_STACK_OPERATION;
  uint32_t l = 0;
  const uint8_t* p = st_top(st, 1, l);
  uint8_t out[20];
  ripemd160(p, l, out);
  st.n -= 1;
  return st_push(st, out, 20);
}

// Reviewed cell-local SHA1 handler.  Lean Defs.lean:1028-1030 folds wires
// 0xa6..0xaa into hashForOp; hashForOp 0xa7 = hashSha1 (Defs.lean:637-643,
// Hashes.lean:133+).  Core selects width 20 for SHA1 at interpreter.cpp:1042
// and dispatches CSHA1 at :1043-1047.  Body shape is identical to the four
// transliterated handlers; only the primitive symbol differs.
BINLINE int op_sha1(HStack& st) {
  if (st.n < 1) return TWIN_INVALID_STACK_OPERATION;
  uint32_t l = 0;
  const uint8_t* p = st_top(st, 1, l);
  uint8_t out[20];
  sha1(p, l, out);
  st.n -= 1;
  return st_push(st, out, 20);
}

BINLINE int op_sha256(HStack& st) {
  if (st.n < 1) return TWIN_INVALID_STACK_OPERATION;
  uint32_t l = 0;
  const uint8_t* p = st_top(st, 1, l);
  uint8_t out[32];
  sha256(p, l, out);
  st.n -= 1;
  return st_push(st, out, 32);
}

BINLINE int op_hash160(HStack& st) {
  if (st.n < 1) return TWIN_INVALID_STACK_OPERATION;
  uint32_t l = 0;
  const uint8_t* p = st_top(st, 1, l);
  uint8_t out[20];
  hash160(p, l, out);
  st.n -= 1;
  return st_push(st, out, 20);
}

BINLINE int op_hash256(HStack& st) {
  if (st.n < 1) return TWIN_INVALID_STACK_OPERATION;
  uint32_t l = 0;
  const uint8_t* p = st_top(st, 1, l);
  uint8_t out[32];
  hash256(p, l, out);
  st.n -= 1;
  return st_push(st, out, 32);
}

}  // namespace twinleaf_hash

using namespace twinleaf_hash;

// TwinErr -> Core ScriptError ordinal (contract/error_kind.h).
BINLINE uint32_t core_err(int e) {
  if (e == TWIN_PUSH_SIZE) return 6;
  if (e == TWIN_STACK_SIZE) return 8;
  if (e == TWIN_INVALID_STACK_OPERATION) return 18;
  return 1;  // UNKNOWN_ERROR
}

BINLINE uint64_t run_ripemd160(const uint8_t* pre, uint32_t len) {
  HStack st{};
  if (st_push(st, pre, len) != TWIN_OK) return h_pack(0, 1, st);
  const int e = op_ripemd160(st);
  return h_pack(e == TWIN_OK ? 1u : 0u, e == TWIN_OK ? 0u : core_err(e), st);
}
BINLINE uint64_t run_sha1(const uint8_t* pre, uint32_t len) {
  HStack st{};
  if (st_push(st, pre, len) != TWIN_OK) return h_pack(0, 1, st);
  const int e = op_sha1(st);
  return h_pack(e == TWIN_OK ? 1u : 0u, e == TWIN_OK ? 0u : core_err(e), st);
}
BINLINE uint64_t run_sha256(const uint8_t* pre, uint32_t len) {
  HStack st{};
  if (st_push(st, pre, len) != TWIN_OK) return h_pack(0, 1, st);
  const int e = op_sha256(st);
  return h_pack(e == TWIN_OK ? 1u : 0u, e == TWIN_OK ? 0u : core_err(e), st);
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

extern "C" uint64_t cell_ripemd160_empty() {
  const uint8_t pre[1] = {0};
  return run_ripemd160(pre, 0);
}
extern "C" uint64_t cell_sha1_empty() {
  const uint8_t pre[1] = {0};
  return run_sha1(pre, 0);
}
extern "C" uint64_t cell_sha256_empty() {
  const uint8_t pre[1] = {0};
  return run_sha256(pre, 0);
}
extern "C" uint64_t cell_hash160_empty() {
  const uint8_t pre[1] = {0};
  return run_hash160(pre, 0);
}
extern "C" uint64_t cell_hash256_empty() {
  const uint8_t pre[1] = {0};
  return run_hash256(pre, 0);
}
extern "C" uint64_t cell_ripemd160_a() {
  const uint8_t pre[1] = {0x61};
  return run_ripemd160(pre, 1);
}
extern "C" uint64_t cell_sha1_a() {
  const uint8_t pre[1] = {0x61};
  return run_sha1(pre, 1);
}
extern "C" uint64_t cell_sha256_a() {
  const uint8_t pre[1] = {0x61};
  return run_sha256(pre, 1);
}
extern "C" uint64_t cell_hash160_a() {
  const uint8_t pre[1] = {0x61};
  return run_hash160(pre, 1);
}
extern "C" uint64_t cell_hash256_a() {
  const uint8_t pre[1] = {0x61};
  return run_hash256(pre, 1);
}

// ---- meta-only twins for Alive2 -----------------------------------------
// Same handler, but the pushed bytes are not read into the observable.  The
// push length is defined and is what Alive2 compares; SAW checks the digest.
#define RUN_META(NAME, OP)                                                   \
  BINLINE uint64_t run_##NAME##_meta(const uint8_t* pre, uint32_t len) {     \
    HStack st{};                                                             \
    if (st_push(st, pre, len) != TWIN_OK) return h_pack_meta(0, 1, st);       \
    const int e = OP(st);                                                    \
    return h_pack_meta(e == TWIN_OK ? 1u : 0u,                                \
                       e == TWIN_OK ? 0u : core_err(e), st);                  \
  }
RUN_META(ripemd160, op_ripemd160)
RUN_META(sha1, op_sha1)
RUN_META(sha256, op_sha256)
RUN_META(hash160, op_hash160)
RUN_META(hash256, op_hash256)
#undef RUN_META

extern "C" uint64_t cell_ripemd160_empty_meta() {
  const uint8_t pre[1] = {0};
  return run_ripemd160_meta(pre, 0);
}
extern "C" uint64_t cell_sha1_empty_meta() {
  const uint8_t pre[1] = {0};
  return run_sha1_meta(pre, 0);
}
extern "C" uint64_t cell_sha256_empty_meta() {
  const uint8_t pre[1] = {0};
  return run_sha256_meta(pre, 0);
}
extern "C" uint64_t cell_hash160_empty_meta() {
  const uint8_t pre[1] = {0};
  return run_hash160_meta(pre, 0);
}
extern "C" uint64_t cell_hash256_empty_meta() {
  const uint8_t pre[1] = {0};
  return run_hash256_meta(pre, 0);
}
extern "C" uint64_t cell_ripemd160_a_meta() {
  const uint8_t pre[1] = {0x61};
  return run_ripemd160_meta(pre, 1);
}
extern "C" uint64_t cell_sha1_a_meta() {
  const uint8_t pre[1] = {0x61};
  return run_sha1_meta(pre, 1);
}
extern "C" uint64_t cell_sha256_a_meta() {
  const uint8_t pre[1] = {0x61};
  return run_sha256_meta(pre, 1);
}
extern "C" uint64_t cell_hash160_a_meta() {
  const uint8_t pre[1] = {0x61};
  return run_hash160_meta(pre, 1);
}
extern "C" uint64_t cell_hash256_a_meta() {
  const uint8_t pre[1] = {0x61};
  return run_hash256_meta(pre, 1);
}
