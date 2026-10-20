// L leg: calls the twin's structural helper verbatim.
//
//   twin/runtime.inc:296-307  classify_push_only(b, size)
//       while (i < size) {
//         if (!decode_op(b, size, i, d)) return PushOnly::ParseFail;
//         if (d.wire > 0x60) return PushOnly::NotPush;
//         i = d.next;
//       }
//       return PushOnly::Ok;
//
// Both a parse failure and a wire > 0x60 make CScript::IsPushOnly false, so
// the L observable is `classify == Ok`.
//
// runtime.inc is rendered into build/twin.cpp by twin/gen.py; decode_op and
// classify_push_only are the twin's own code.  The one-byte buffer, the
// constant size and the call are cell harness.
#include "twin.cpp"

extern "C" uint64_t cell_po0() {
  const uint8_t b[1] = {0};
  return twin::classify_push_only(b, 0) == twin::PushOnly::Ok ? 1u : 0u;
}

extern "C" uint64_t cell_po1(uint8_t b0) {
  const uint8_t b[1] = {b0};
  return twin::classify_push_only(b, 1) == twin::PushOnly::Ok ? 1u : 0u;
}
