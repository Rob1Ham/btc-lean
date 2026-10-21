// L leg: calls the twin's structural helper verbatim.
//
//   twin/runtime.inc:312-320  is_witness_program(b, n)
//       if (n < 4 || n > 42) return false;
//       const uint8_t v = b[0];
//       if (!(v == 0x00 || (0x51 <= v && v <= 0x60))) return false;
//       return static_cast<uint32_t>(b[1]) + 2u == n;
//
// runtime.inc is rendered into build/twin.cpp by twin/gen.py; the helper is
// the same code the twin's VerifyScript calls.  The two-byte buffer and the
// call are cell harness: only b[0] and b[1] are read, and only after the
// length guard, so a two-byte object is in-bounds for every n.
#include "twin.cpp"

extern "C" uint64_t cell_wp(uint8_t v, uint8_t plen, uint32_t n) {
  const uint8_t b[2] = {v, plen};
  return twin::is_witness_program(b, n) ? 1u : 0u;
}
