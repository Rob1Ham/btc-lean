#include <cstdint>
// L leg: Lean wire parser at
//   spec/core/Bitcoin/Script/Parser/Defs.lean:206-229 (getOpAux/getOp)
// transcribed from the generated twin `twin/runtime.inc:242-283`
// (decode_op), restricted to offset 0.
//
// Lean:
//   getOpAux b i c =
//     if c = 0 then some (pushBytes empty, i+1)
//     else if c < 0x4c then
//       (sliceOpt b (i+1) c).map (fun d => (pushBytes d, i+1+c))
//     else if c = 0x4c then
//       (getOpt b (i+1)).bind (fun k =>
//         (sliceOpt b (i+2) k).map (fun d => (pushBytes d, i+2+k)))
//     else if c = 0x4d then ... i+3 ...
//     else if c = 0x4e then ... i+5 ...
//     else if c = 0x4f then some (pushNum 0, i+1)
//     else if c <= 0x60 then some (pushNum (c-0x50), i+1)
//     else some (op c, i+1)
//
// `parseWire` is all-or-nothing, but this cell parses ONE opcode at offset 0,
// so eager and streaming order agree.  A decode failure is BAD_OPCODE
// (Defs.lean evalScriptBytes:1163-1178; interpreter.cpp:487-488).

#define BINLINE static inline __attribute__((always_inline))

struct Decoded {
  bool ok;
  uint32_t wire;
  uint32_t dlen;
  uint32_t next;
  uint8_t data[8];
};

BINLINE bool lean_get_op(const uint8_t* b, uint32_t n, Decoded& d) {
  d.ok = false; d.wire = 0; d.dlen = 0; d.next = 0;
  for (uint32_t i = 0; i < 8; ++i) d.data[i] = 0;
  if (n < 1) return false;
  const uint32_t c = b[0];
  d.wire = c;
  if (c == 0x00u) { d.ok = true; d.next = 1; return true; }
  if (c < 0x4cu) {
    if (c > n - 1) return false;             // sliceOpt b 1 c failed
    for (uint32_t i = 0; i < 8; ++i) d.data[i] = (i < c) ? b[1 + i] : 0;
    d.ok = true; d.dlen = c; d.next = 1 + c; return true;
  }
  if (c == 0x4cu || c == 0x4du || c == 0x4eu) {
    // width is 1, 2 or 4: written arithmetically so the compiler does not
    // emit a constant jump table (Alive2 compares the two modules' globals;
    // a table present on one side alone is uninitialised memory).
    const uint32_t width = 1u << ((c == 0x4eu) ? 2u : (c - 0x4cu));
    const uint32_t at = 1;
    if (width > n - at) return false;        // getOpt/read of the length failed
    uint32_t k = static_cast<uint32_t>(b[at]);
    if (width > 1) k |= static_cast<uint32_t>(b[at + 1]) << 8;
    if (width > 2) {
      k |= static_cast<uint32_t>(b[at + 2]) << 16;
      k |= static_cast<uint32_t>(b[at + 3]) << 24;
    }
    const uint32_t prefix = 1 + width;
    if (prefix > n || k > n - prefix) return false;  // sliceOpt failed
    for (uint32_t i = 0; i < 8; ++i) d.data[i] = (i < k) ? b[prefix + i] : 0;
    d.ok = true; d.dlen = k; d.next = prefix + k; return true;
  }
  d.ok = true; d.next = 1;                   // pushNum or op
  return true;
}

BINLINE uint64_t lean_meta_pack(uint32_t res, uint32_t err, uint32_t wire,
                                uint32_t dlen, uint32_t next) {
  uint64_t r = 0;
  r |= static_cast<uint64_t>(res & 3u);
  r |= static_cast<uint64_t>(err & 0x3fu) << 2;
  r |= static_cast<uint64_t>(wire & 0xffu) << 8;
  r |= static_cast<uint64_t>(dlen & 0xffffu) << 16;
  r |= static_cast<uint64_t>(next & 0xffffu) << 32;
  return r;
}

extern "C" uint64_t cell_parse_meta(uint32_t n, uint8_t b0, uint8_t b1,
                                    uint8_t b2, uint8_t b3, uint8_t b4,
                                    uint8_t b5, uint8_t b6, uint8_t b7) {
  if (n > 8) return 3;
  const uint8_t b[16] = {b0, b1, b2, b3, b4, b5, b6, b7, 0, 0, 0, 0, 0, 0, 0, 0};
  Decoded d;
  const bool ok = lean_get_op(b, n, d);
  if (!ok) return lean_meta_pack(0, 16, n ? b[0] : 0, 0, 0);  // BAD_OPCODE
  return lean_meta_pack(1, 0, d.wire, d.dlen, d.next);
}

extern "C" uint64_t cell_parse_payload(uint32_t n, uint8_t b0, uint8_t b1,
                                       uint8_t b2, uint8_t b3, uint8_t b4,
                                       uint8_t b5, uint8_t b6, uint8_t b7) {
  if (n > 8) return 3;
  const uint8_t b[16] = {b0, b1, b2, b3, b4, b5, b6, b7, 0, 0, 0, 0, 0, 0, 0, 0};
  Decoded d;
  const bool ok = lean_get_op(b, n, d);
  if (!ok) return 0;
  uint64_t r = 0;
  for (uint32_t i = 0; i < 8; ++i) r |= static_cast<uint64_t>(d.data[i]) << (8u * i);
  return r;
}
