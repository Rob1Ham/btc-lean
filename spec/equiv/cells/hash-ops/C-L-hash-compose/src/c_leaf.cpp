#include "hash_common.h"
// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/interpreter.cpp:1032-1056  hash opcode family
//   src/script/interpreter.cpp:1049-1052  OP_HASH160 / OP_HASH256 arms
//       valtype vchHash(20|32);
//       CHash160().Write(vch).Finalize(vchHash);      // :1049-1050
//       CHash256().Write(vch).Finalize(vchHash);      // :1051-1052
//
// The compositions are the ones in src/hash.h at the pin:
//
//   CHash160::Finalize (hash.h:57-78)
//       unsigned char buf[CSHA256::OUTPUT_SIZE];
//       sha.Finalize(buf);
//       CRIPEMD160().Write(buf, CSHA256::OUTPUT_SIZE).Finalize(output.data());
//
//   CHash256::Finalize (hash.h:32-55)
//       unsigned char buf[CSHA256::OUTPUT_SIZE];
//       sha.Finalize(buf);
//       sha.Reset().Write(buf, CSHA256::OUTPUT_SIZE).Finalize(output.data());
//
// The streaming hasher objects are abstracted to the two opaque externals
// sha256 and ripemd160 (same-hash premise).  What remains inside the cell is
// the composition skeleton: SHA256 into a 32-byte intermediate, then
// RIPEMD160 (HASH160) or a second SHA256 (HASH256) over exactly those 32
// bytes, then a 20/32-byte push.  That skeleton is what the row names; the
// primitive algorithms are not proved.

extern "C" void sha256(const uint8_t* in, uint32_t len, uint8_t* out);
extern "C" void ripemd160(const uint8_t* in, uint32_t len, uint8_t* out);

// hash.h:57-78, with the streaming SHA256 object as one call.
BINLINE void chash160(const uint8_t* in, uint32_t len, uint8_t out[20]) {
  uint8_t mid[32];
  sha256(in, len, mid);              // sha.Finalize(buf)
  ripemd160(mid, 32, out);           // CRIPEMD160().Write(buf, 32).Finalize(out)
}

// hash.h:32-55, with sha.Reset().Write(buf, 32) as the second call.
BINLINE void chash256(const uint8_t* in, uint32_t len, uint8_t out[32]) {
  uint8_t mid[32];
  sha256(in, len, mid);
  sha256(mid, 32, out);
}

// Cell harness encoding `popstack; stack.push_back(vchHash)`.
BINLINE uint64_t finish(const uint8_t* out, uint32_t width) {
  HStack s{};
  s.n = 1;
  s.len[0] = width;
  h_copy(s.e[0], out, width);
  return h_pack(1, 0, s);
}

extern "C" uint64_t cell_hash160_empty() {
  const uint8_t pre[1] = {0};
  uint8_t out[20];
  chash160(pre, 0, out);
  return finish(out, 20);
}
extern "C" uint64_t cell_hash160_a() {
  const uint8_t pre[1] = {0x61};
  uint8_t out[20];
  chash160(pre, 1, out);
  return finish(out, 20);
}
extern "C" uint64_t cell_hash256_empty() {
  const uint8_t pre[1] = {0};
  uint8_t out[32];
  chash256(pre, 0, out);
  return finish(out, 32);
}
extern "C" uint64_t cell_hash256_a() {
  const uint8_t pre[1] = {0x61};
  uint8_t out[32];
  chash256(pre, 1, out);
  return finish(out, 32);
}

// ---- symbolic chain functions for Alive2 --------------------------------
// Alive2 models an external write as unmodelled memory, so the digest-bearing
// functions above return a poisoned aggregate and cannot be compared
// meaningfully.  These functions abstract each digest to a defined 64-bit
// token returned by the primitive.  The first token is passed to the second
// primitive together with the declared 32-byte intermediate length; the
// second token fills the pushed element.  This makes the chain, order,
// intermediate width and final width concrete and Alive2-checkable.  SAW
// still proves the real digest composition above with concrete overrides.
extern "C" uint64_t sha256_pre(const uint8_t* in, uint32_t len);
extern "C" uint64_t ripemd160_mid(uint64_t mid, uint32_t len);
extern "C" uint64_t sha256_mid(uint64_t mid, uint32_t len);

BINLINE uint64_t cchain160(const uint8_t* in, uint32_t len) {
  const uint64_t mid = sha256_pre(in, len);
  const uint64_t tok = ripemd160_mid(mid, 32);
  return h_pack_token(tok, 20);
}
BINLINE uint64_t cchain256(const uint8_t* in, uint32_t len) {
  const uint64_t mid = sha256_pre(in, len);
  const uint64_t tok = sha256_mid(mid, 32);
  return h_pack_token(tok, 32);
}
extern "C" uint64_t cell_hash160_empty_chain() {
  const uint8_t pre[1] = {0};
  return cchain160(pre, 0);
}
extern "C" uint64_t cell_hash160_a_chain() {
  const uint8_t pre[1] = {0x61};
  return cchain160(pre, 1);
}
extern "C" uint64_t cell_hash256_empty_chain() {
  const uint8_t pre[1] = {0};
  return cchain256(pre, 0);
}
extern "C" uint64_t cell_hash256_a_chain() {
  const uint8_t pre[1] = {0x61};
  return cchain256(pre, 1);
}
