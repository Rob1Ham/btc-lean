#include "hash_common.h"
// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/interpreter.cpp:1032-1056  hash opcode family
//       case OP_RIPEMD160: ... case OP_HASH256:
//       if (stack.size() < 1) return SCRIPT_ERR_INVALID_STACK_OPERATION;
//       valtype& vch = stacktop(-1);
//       valtype vchHash((opcode == OP_RIPEMD160 || opcode == OP_SHA1 ||
//                        opcode == OP_HASH160) ? 20 : 32);      // :1042
//       ... CRIPEMD160 / CSHA256 / CHash160 / CHash256 ...     // :1043-1052
//       popstack(stack);                                       // :1053
//       stack.push_back(vchHash);                              // :1054
//
// The four cryptographic transforms are opaque externals shared with the L
// leg.  The cell therefore proves the opcode plumbing -- the element is
// consumed, the output width is 20 or 32 as selected by :1042, and the digest
// is pushed -- for every possible transform output.  It does not prove the
// hash functions themselves; that is the same-hash premise.
//
// `finish` is cell harness that encodes exactly `popstack; push_back(vchHash)`
// on the bounded HStack.  The closed preimage is passed as (pointer, length),
// including length 0 for the empty element; the pointer is a valid one-byte
// buffer so no null-pointer semantics are assumed at the seam.

extern "C" void ripemd160(const uint8_t* in, uint32_t len, uint8_t* out);
extern "C" void sha256(const uint8_t* in, uint32_t len, uint8_t* out);
extern "C" void hash160(const uint8_t* in, uint32_t len, uint8_t* out);
extern "C" void hash256(const uint8_t* in, uint32_t len, uint8_t* out);

BINLINE uint64_t finish(const uint8_t* out, uint32_t width) {
  HStack s{};
  s.n = 1;                        // popstack then push_back(vchHash)
  s.len[0] = width;               // vchHash size from interpreter.cpp:1042
  h_copy(s.e[0], out, width);
  return h_pack(1, 0, s);
}

// Empty element: vch is a zero-length valtype; Core's hash writers accept a
// zero length and never dereference the input pointer.
extern "C" uint64_t cell_ripemd160_empty() {
  const uint8_t pre[1] = {0};
  uint8_t out[20];
  ripemd160(pre, 0, out);
  return finish(out, 20);
}
extern "C" uint64_t cell_sha256_empty() {
  const uint8_t pre[1] = {0};
  uint8_t out[32];
  sha256(pre, 0, out);
  return finish(out, 32);
}
extern "C" uint64_t cell_hash160_empty() {
  const uint8_t pre[1] = {0};
  uint8_t out[20];
  hash160(pre, 0, out);
  return finish(out, 20);
}
extern "C" uint64_t cell_hash256_empty() {
  const uint8_t pre[1] = {0};
  uint8_t out[32];
  hash256(pre, 0, out);
  return finish(out, 32);
}

// One-byte element 0x61 ("a"), the existing e2-hash witness.
extern "C" uint64_t cell_ripemd160_a() {
  const uint8_t pre[1] = {0x61};
  uint8_t out[20];
  ripemd160(pre, 1, out);
  return finish(out, 20);
}
extern "C" uint64_t cell_sha256_a() {
  const uint8_t pre[1] = {0x61};
  uint8_t out[32];
  sha256(pre, 1, out);
  return finish(out, 32);
}
extern "C" uint64_t cell_hash160_a() {
  const uint8_t pre[1] = {0x61};
  uint8_t out[20];
  hash160(pre, 1, out);
  return finish(out, 20);
}
extern "C" uint64_t cell_hash256_a() {
  const uint8_t pre[1] = {0x61};
  uint8_t out[32];
  hash256(pre, 1, out);
  return finish(out, 32);
}

// ---- meta-only twins for Alive2 -----------------------------------------
// Alive2 treats the external write as unmodelled memory, so a function that
// reads the digest would return a poisoned packed value.  These functions
// keep the same call and the same pop/push, but the observable is only the
// defined meta fields (result, error, depth, pushed length).  SAW checks the
// full digest-bearing observable above.
BINLINE uint64_t finish_meta(const uint8_t* out, uint32_t width) {
  (void)out;
  HStack s{};
  s.n = 1;
  s.len[0] = width;
  return h_pack_meta(1, 0, s);
}
extern "C" uint64_t cell_ripemd160_empty_meta() {
  const uint8_t pre[1] = {0};
  uint8_t out[20];
  ripemd160(pre, 0, out);
  return finish_meta(out, 20);
}
extern "C" uint64_t cell_sha256_empty_meta() {
  const uint8_t pre[1] = {0};
  uint8_t out[32];
  sha256(pre, 0, out);
  return finish_meta(out, 32);
}
extern "C" uint64_t cell_hash160_empty_meta() {
  const uint8_t pre[1] = {0};
  uint8_t out[20];
  hash160(pre, 0, out);
  return finish_meta(out, 20);
}
extern "C" uint64_t cell_hash256_empty_meta() {
  const uint8_t pre[1] = {0};
  uint8_t out[32];
  hash256(pre, 0, out);
  return finish_meta(out, 32);
}
extern "C" uint64_t cell_ripemd160_a_meta() {
  const uint8_t pre[1] = {0x61};
  uint8_t out[20];
  ripemd160(pre, 1, out);
  return finish_meta(out, 20);
}
extern "C" uint64_t cell_sha256_a_meta() {
  const uint8_t pre[1] = {0x61};
  uint8_t out[32];
  sha256(pre, 1, out);
  return finish_meta(out, 32);
}
extern "C" uint64_t cell_hash160_a_meta() {
  const uint8_t pre[1] = {0x61};
  uint8_t out[20];
  hash160(pre, 1, out);
  return finish_meta(out, 20);
}
extern "C" uint64_t cell_hash256_a_meta() {
  const uint8_t pre[1] = {0x61};
  uint8_t out[32];
  hash256(pre, 1, out);
  return finish_meta(out, 32);
}
