// L leg: calls the twin's structural helper verbatim.
//
//   twin/runtime.inc:309-311  is_p2sh(b, n)
//       return n == 23 && b[0] == 0xa9 && b[1] == 0x14 && b[22] == 0x87;
//
// runtime.inc is rendered into build/twin.cpp by twin/gen.py; this is the
// same helper the twin's VerifyScript calls.  The 23-byte buffer and the call
// are cell harness: the helper reads b[0], b[1] and b[22] only after n == 23,
// and every byte it can read is in-bounds.
#include "twin.cpp"

extern "C" uint64_t cell_p2sh(uint8_t b0, uint8_t b1, uint8_t b22,
                              uint32_t n) {
  uint8_t b[23] = {0};
  b[0] = b0;
  b[1] = b1;
  b[22] = b22;
  return twin::is_p2sh(b, n) ? 1u : 0u;
}
