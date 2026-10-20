#include "common.h"

// C leg — line-cited source-excerpt slice of Core at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// SCR-005 (shape): script.cpp:224-232
//
//   bool CScript::IsPayToScriptHash() const
//   {
//       return (this->size() == 23 &&
//               (*this)[0] == OP_HASH160 &&      // 0xa9
//               (*this)[1] == 0x14 &&            // push 20 bytes
//               (*this)[22] == OP_EQUAL);        // 0x87
//   }
//
// SCR-007 (handoff): interpreter.cpp:2032-2033, 2062-2078
//
//   2032  if (flags & SCRIPT_VERIFY_P2SH)
//   2033      stackCopy = stack;                 // capture after scriptSig eval
//   ...
//   2062  if ((flags & SCRIPT_VERIFY_P2SH) && scriptPubKey.IsPayToScriptHash())
//   2065      if (!scriptSig.IsPushOnly()) ...   // C-L-pushonly cell
//   2069      swap(stack, stackCopy);            // restore the scriptSig stack
//   2074      assert(!stack.empty());            // unreachable: spk eval fails
//   2076      const valtype& pubKeySerialized = stack.back();
//   2077      CScript pubKey2(pubKeySerialized.begin(), pubKeySerialized.end());
//   2078      popstack(stack);                   // leftover = stackCopy minus top
//
// The cell models the post-scriptSig stack as `sn` one-byte elements
// t0..t_{sn-1} in Core's bottom-to-top vector order.  `swap` exchanges the two
// vectors, so the stack handed to the subscript EvalScript is exactly the
// captured copy; `stack.back()` is its last element (the serialized
// redeemScript) and `popstack` removes it, leaving the prefix in order.  The
// post-scriptPubKey stack is not an input: after the swap Core parks it in
// `stackCopy` and never reads it again.  The `assert(!stack.empty())` arm is
// Core's (unreachable) precondition, reported as the out-of-model marker.

EVINLINE uint64_t c_p2sh_shape(uint64_t len, uint64_t b0, uint64_t b1,
                               uint64_t b_last) {
    // script.cpp:224-232, byte-for-byte.
    return (len == 23) & (b0 == 0xa9) & (b1 == 0x14) & (b_last == 0x87);
}

EVINLINE uint64_t c_elem(uint64_t t0, uint64_t t1, uint64_t t2, uint64_t n,
                         uint64_t i) {
    // Reads stack[i] from the bounded bottom-to-top vector; only called with
    // i < n <= 3.
    if (i == 0) return t0;
    if (i == 1) return t1;
    return t2;
}

EVINLINE uint64_t c_p2sh_handoff(uint64_t p2sh, uint64_t spk_shape,
                                 uint64_t sn, uint64_t t0, uint64_t t1,
                                 uint64_t t2) {
    // 2062 — the arm is entered only under the P2SH flag and the shape test.
    if (!(p2sh && spk_shape)) return ev_pack_handoff(3, 0, 0, 0, 0, 0, 0, 0);

    // 2069 swap(stack, stackCopy): the local `stack` becomes the captured
    // post-scriptSig stack.  2074 assert(!stack.empty()).
    if (sn == 0) return ev_pack_handoff(3, 0, 0, 0, 0, 0, 0, 0);

    // 2076 stack.back(); 2077 pubKey2 = those bytes.
    const uint64_t redeem = c_elem(t0, t1, t2, sn, sn - 1);

    // 2078 popstack(stack): the prefix, order preserved.
    const uint64_t rest_n = sn - 1;
    const uint64_t b0 = (rest_n >= 1) ? c_elem(t0, t1, t2, rest_n, 0) : 0;
    const uint64_t b1 = (rest_n >= 2) ? c_elem(t0, t1, t2, rest_n, 1) : 0;
    const uint64_t b2 = 0;   // rest_n <= 2

    return ev_pack_handoff(1, 0, rest_n, b0, b1, b2, redeem, 1);
}

extern "C" uint64_t cell_p2sh_shape(uint64_t len, uint64_t b0, uint64_t b1,
                                    uint64_t b_last) {
    return c_p2sh_shape(len & 0x3fu, b0 & 0xffu, b1 & 0xffu, b_last & 0xffu);
}

extern "C" uint64_t cell_p2sh_handoff(uint64_t p2sh, uint64_t spk_shape,
                                      uint64_t sn, uint64_t t0, uint64_t t1,
                                      uint64_t t2) {
    return c_p2sh_handoff(p2sh & 1u, spk_shape & 1u, sn & 3u, t0 & 0xffu,
                          t1 & 0xffu, t2 & 0xffu);
}
