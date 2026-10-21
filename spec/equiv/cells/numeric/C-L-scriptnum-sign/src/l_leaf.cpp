#include "num_common.h"
#include "twin_ops.h"

// L leg: decode_num / encode_num are the twin/runtime.inc bodies unrolled to
// an 8-byte element by findings/wave16/07-numeric-ops/tools/mk_num_leaf.py.
// They are the lowering of the Lean model:
//
//   runtime.inc:167-191  decode_num  <-> ScriptNum.setVchBE
//   runtime.inc:141-158  encode_num  <-> ScriptNum.encodeSignBE . magBE
//
// The generated header is produced from twin/ops_ir.py + runtime.inc; the
// selected OP_1ADD handler is unused (build.cfg explains why it is selected).
// No handler is dispatched: the two runtime primitives are called directly,
// exactly as the numeric op handlers call them.
using namespace twinleaf;

namespace {

BINLINE uint64_t l_pack_enc(uint32_t n, uint64_t packed) {
  return (static_cast<uint64_t>(n) & 0xfu) |
         ((packed & 0xffffffffffULL) << 4);
}

BINLINE int64_t l_value(uint32_t mag, uint32_t neg) {
  return (neg & 1u) ? -static_cast<int64_t>(mag) : static_cast<int64_t>(mag);
}

BINLINE void l_unpack8(uint8_t* d, uint64_t packed) {
  d[0] = static_cast<uint8_t>(packed);
  d[1] = static_cast<uint8_t>(packed >> 8);
  d[2] = static_cast<uint8_t>(packed >> 16);
  d[3] = static_cast<uint8_t>(packed >> 24);
  d[4] = static_cast<uint8_t>(packed >> 32);
  d[5] = static_cast<uint8_t>(packed >> 40);
  d[6] = static_cast<uint8_t>(packed >> 48);
  d[7] = static_cast<uint8_t>(packed >> 56);
}

}  // namespace

extern "C" uint64_t cell_decode(uint64_t w, uint32_t lb) {
  uint8_t b[NUM_MAX_ELEM];
  num_load8(b, w);
  const uint32_t len = lb & 7u;
  int64_t out = 0;
  // maxSize = 8 and minimal = false: this cell observes the sign-magnitude
  // map only.  len <= 7, so the call cannot fail; TWIN_OK is still checked so
  // a failure cannot silently read an unset `out`.
  const TwinErr e = decode_num(b, len, /*minimal=*/false, /*maxSize=*/8, out);
  return (e == TWIN_OK) ? static_cast<uint64_t>(out) : 0;
}

extern "C" uint64_t cell_encode(uint64_t mag64, uint32_t neg) {
  const uint32_t mag = static_cast<uint32_t>(mag64 & 0xffffffffULL);
  uint64_t packed = 0;
  const uint32_t n = encode_num(l_value(mag, neg), packed);
  return l_pack_enc(n, packed);
}

extern "C" uint64_t cell_encode_decode(uint64_t mag64, uint32_t neg) {
  const uint32_t mag = static_cast<uint32_t>(mag64 & 0xffffffffULL);
  uint64_t packed = 0;
  const uint32_t n = encode_num(l_value(mag, neg), packed);
  uint8_t b[NUM_MAX_ELEM];
  l_unpack8(b, packed);
  int64_t out = 0;
  const TwinErr e = decode_num(b, n, /*minimal=*/false, /*maxSize=*/8, out);
  return (e == TWIN_OK) ? static_cast<uint64_t>(out) : 0;
}

extern "C" uint64_t cell_roundtrip(uint64_t w, uint32_t lb) {
  uint8_t b[NUM_MAX_ELEM];
  num_load8(b, w);
  const uint32_t len = lb & 3u;
  int64_t v = 0;
  const TwinErr e = decode_num(b, len, /*minimal=*/false, /*maxSize=*/8, v);
  if (e != TWIN_OK) return 0;
  uint64_t packed = 0;
  const uint32_t n = encode_num(v, packed);
  return l_pack_enc(n, packed);
}
