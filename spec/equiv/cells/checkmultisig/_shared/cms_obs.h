#ifndef CMS_OBS_H
#define CMS_OBS_H
// Wave16 CHECKMULTISIG cell harness -- packed observable only.
//
// This header is *harness*, not engine code: it packs the cell's observable
// into one uint64_t and defines the failure sentinel.  No CHECKMULTISIG
// semantics live here; each leg implements the rule itself (C leg: line-cited
// slice of Bitcoin Core interpreter.cpp@cce32b168; L leg: reviewed
// transliteration of spec/core/Bitcoin/Interpreter/Defs.lean).
//
// Observable layout (same discipline as cells/_tools/e3/cellsig/e3_common.h):
//   bits  0..1   result  (0 fail, 1 pass, 3 harness/out-of-domain)
//   bits  2..7   error ordinal (contract/error_kind.h, 0..55)
//   bits  8..10  stack depth (0..7)
//   bits 11..12  element 0 length (0..3)
//   bits 13..20  element 0 first byte
//   bits 21..22  element 1 length
//   bits 23..30  element 1 first byte
//   bits 31..32  element 2 length
//   bits 33..40  element 2 first byte
// Cells with a wider structural observable use the *_pack helpers below and
// document the field map in their spec.md.
#include <cstdint>

// contract/error_kind.h ordinals used by this family (v2 enum, Core 1:1).
#define CMS_OK 0
#define CMS_EVAL_FALSE 2
#define CMS_OP_COUNT 7
#define CMS_SIG_COUNT 9
#define CMS_PUBKEY_COUNT 10
#define CMS_CHECKMULTISIGVERIFY 13
#define CMS_INVALID_STACK_OPERATION 18
#define CMS_SIG_NULLDUMMY 28
#define CMS_TAPSCRIPT_CHECKMULTISIG 50 /* SCRIPT_ERR_TAPSCRIPT_CHECKMULTISIG */

// Packed observable: result | error | depth | top-three elements.
static inline uint64_t cms_pack(uint32_t res, uint32_t err, uint32_t depth,
                                const uint32_t *len, const uint32_t *val) {
  uint64_t r = 0;
  r |= (uint64_t)(res & 3u);
  r |= (uint64_t)(err & 0x3fu) << 2;
  r |= (uint64_t)(depth & 7u) << 8;
  if (depth > 0) {
    // Element fields are the *top three* elements in ascending index order
    // (for depth <= 3 that is every element).  Lengths are clamped to 2 bits
    // and payloads to the first byte; cells that need more use their own
    // packer and say so in spec.md.
    uint32_t base = depth > 3 ? depth - 3 : 0;
    if (depth > 0) {
      r |= (uint64_t)(len[base] & 3u) << 11;
      r |= (uint64_t)(val[base] & 0xffu) << 13;
    }
    if (depth > 1) {
      r |= (uint64_t)(len[base + 1] & 3u) << 21;
      r |= (uint64_t)(val[base + 1] & 0xffu) << 23;
    }
    if (depth > 2) {
      r |= (uint64_t)(len[base + 2] & 3u) << 31;
      r |= (uint64_t)(val[base + 2] & 0xffu) << 33;
    }
  }
  return r;
}

// Layout-cell observable (SCR-114): the decision plus the derived layout
// numbers, so a wrong decode/limit/depth decision cannot hide behind a common
// status.  Fields are zero unless the rule reached the OK outcome.
//   bits 0..2 status | 3..7 nKeys | 8..12 nSigs | 13..18 ikey2 | 19..24 isig
static inline uint64_t cms_pack_layout(uint32_t status, uint32_t nKeys,
                                       uint32_t nSigs, uint32_t ikey2,
                                       uint32_t isig) {
  uint64_t r = 0;
  r |= (uint64_t)(status & 7u);
  r |= (uint64_t)(nKeys & 0x1fu) << 3;
  r |= (uint64_t)(nSigs & 0x1fu) << 8;
  r |= (uint64_t)(ikey2 & 0x3fu) << 13;
  r |= (uint64_t)(isig & 0x3fu) << 19;
  return r;
}

// Six-bit-code observable used by cells whose code word includes a contract
// error ordinal (> 7): bits 0..5 code | 6..10 a | 11..15 b | 16..21 c |
// 22..27 d.  Cells that use it document the field meanings in spec.md.
static inline uint64_t cms_pack6(uint32_t code, uint32_t a, uint32_t b,
                                 uint32_t c, uint32_t d) {
  uint64_t r = 0;
  r |= (uint64_t)(code & 0x3fu);
  r |= (uint64_t)(a & 0x1fu) << 6;
  r |= (uint64_t)(b & 0x1fu) << 11;
  r |= (uint64_t)(c & 0x3fu) << 16;
  r |= (uint64_t)(d & 0x3fu) << 22;
  return r;
}

// Tail-cell observable (SCR-118/119/120).  The cell's test stack is
// *canonical*: `extra` items sit below the CHECKMULTISIG arguments, element i
// having length 1 and value (i + 2), so a surviving prefix is identifiable and
// the pushed boolean (length 1, value 0/1) cannot alias an element.
// Fields, top-down:
//   bit 0      result (0 fail / 1 pass)
//   bits 1..6  error ordinal
//   bits 7..12 final stack depth
//   bits 13..14 topmost length      bits 15..22 topmost value
//   bits 23..24 second length       bits 25..32 second value
//   bits 33..34 third length        bits 35..42 third value
// `pushed` is 0 or 1 for the boolean the op left on top, 2 when none is left.
static inline uint64_t cms_pack_tail(uint32_t res, uint32_t err,
                                     uint32_t remain, uint32_t pushed) {
  const uint32_t depth = remain + (pushed == 2u ? 0u : 1u);
  uint32_t gl[3] = {0u, 0u, 0u};
  uint32_t gv[3] = {0u, 0u, 0u};
  const uint32_t base = (pushed == 2u) ? 0u : 1u;
  for (uint32_t k = 0; k < 3u; ++k) {
    if (pushed != 2u && k == 0u) {
      gl[0] = pushed ? 1u : 0u;
      gv[0] = pushed ? 1u : 0u;
    } else {
      const uint32_t off = k - base;   // elements below the pushed boolean
      if (remain > off) {
        gl[k] = 1u;
        gv[k] = ((remain - off - 1u) + 2u) & 0xffu;
      }
    }
  }
  uint64_t r = 0;
  r |= (uint64_t)(res & 1u);
  r |= (uint64_t)(err & 0x3fu) << 1;
  r |= (uint64_t)(depth & 0x3fu) << 7;
  for (uint32_t k = 0; k < 3u; ++k) {
    const uint32_t lo = 13u + 10u * k;
    r |= (uint64_t)(gl[k] & 3u) << lo;
    r |= (uint64_t)(gv[k] & 0xffu) << (lo + 2u);
  }
  return r;
}

// Tail-cell failure observable: result 0 and the error ordinal in bits 1..6
// (the cms_pack_tail layout); hard errors expose no stack per contract/ABI.md.
static inline uint64_t cms_fail_tail(uint32_t err) {
  return (uint64_t)(err & 0x3fu) << 1;
}

// Order-cell observable (SCR-116): the verification loop's *trace*, so a
// matcher that checks the right pairs in the wrong order, or that keeps going
// after "more signatures than keys remain", cannot hide behind a common
// fSuccess.  Fields:
//   bits 0..2 keys examined | 3..6 matched-key mask | bit 7 early-fail taken |
//   bit 8 fSuccess.   0xFFFF is the cell's out-of-domain sentinel.
static inline uint64_t cms_pack_order(uint32_t examined, uint32_t mask,
                                      uint32_t earlyFail, uint32_t success) {
  uint64_t r = 0;
  r |= (uint64_t)(examined & 7u);
  r |= (uint64_t)(mask & 0xfu) << 3;
  r |= (uint64_t)(earlyFail & 1u) << 7;
  r |= (uint64_t)(success & 1u) << 8;
  return r;
}

// Enc-loop observable (SCR-117): the encoding gates' *position* in the
// verification loop, per pair.  A gate evaluated outside the loop, in the
// wrong order, or after the checker call would move these bits.
//   bit 0       result (1 = fSuccess at loop exit, 0 = false)
//   bits 1..6   error ordinal from the first encoding gate that fired (0 none)
//   bits 7..8   loop bodies entered (0..2)
//   per iteration t in {0,1}: bits 9+5t .. 13+5t
//     +0 body entered (the gate pair was evaluated for this pair)
//     +1 signature-encoding gate fired (CheckSignatureEncoding error)
//     +2 pubkey-encoding gate fired (CheckPubKeyEncoding error)
//     +3 checker called (only when both gates accepted)
//     +4 checker returned true
static inline uint64_t cms_pack_enc(uint32_t res, uint32_t err,
                                    uint32_t bodies, uint32_t entered,
                                    uint32_t sigRej, uint32_t pkRej,
                                    uint32_t chkCalled, uint32_t chkTrue) {
  uint64_t r = 0;
  r |= (uint64_t)(res & 1u);
  r |= (uint64_t)(err & 0x3fu) << 1;
  r |= (uint64_t)(bodies & 3u) << 7;
  for (uint32_t t = 0; t < 2u; ++t) {
    const uint32_t b = 9u + 5u * t;
    r |= (uint64_t)((entered >> t) & 1u) << b;
    r |= (uint64_t)((sigRej >> t) & 1u) << (b + 1u);
    r |= (uint64_t)((pkRej >> t) & 1u) << (b + 2u);
    r |= (uint64_t)((chkCalled >> t) & 1u) << (b + 3u);
    r |= (uint64_t)((chkTrue >> t) & 1u) << (b + 4u);
  }
  return r;
}

// FindAndDelete-order observable (SCR-115).
//   bits 0..1   result (0 fSuccess false, 1 true, 3 error latched)
//   bits 2..7   error ordinal (0 or 54 = SIG_FINDANDDELETE)
//   bits 8..9   checker calls (0..2)
//   bits 10..11 deletion calls applied (0..2)
//   bits 12..43 script id after the deletion fold
//   bit 44      call 0's script id equals the post-fold script id
//   bit 45      call 1's script id equals call 0's
//   bits 46..47 deletion calls that reported found > 0 (0..2)
//   bit 48      1 when sigversion is BASE (the only version that deletes)
static inline uint64_t cms_pack_fad(uint32_t res, uint32_t err,
                                    uint32_t calls, uint32_t applied,
                                    uint32_t final_sc, uint32_t c0_eq_final,
                                    uint32_t c1_eq_c0, uint32_t foundpos,
                                    uint32_t is_base) {
  uint64_t r = 0;
  r |= (uint64_t)(res & 3u);
  r |= (uint64_t)(err & 0x3fu) << 2;
  r |= (uint64_t)(calls & 3u) << 8;
  r |= (uint64_t)(applied & 3u) << 10;
  r |= (uint64_t)final_sc << 12;
  r |= (uint64_t)(c0_eq_final & 1u) << 44;
  r |= (uint64_t)(c1_eq_c0 & 1u) << 45;
  r |= (uint64_t)(foundpos & 3u) << 46;
  r |= (uint64_t)(is_base & 1u) << 48;
  return r;
}

// Failure observable.  Per contract/ABI.md the observable on failure is the
// verdict plus the error_kind; the mutated stack is not observable (Core
// mutates it before returning false, Lean's Except carries no state), so both
// legs pack an empty stack on error.
static inline uint64_t cms_fail(uint32_t err) {
  uint32_t z = 0;
  return cms_pack(0, err, 0, &z, &z);
}

#endif
