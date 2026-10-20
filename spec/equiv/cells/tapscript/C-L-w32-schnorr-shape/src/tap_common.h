#ifndef TAP_COMMON_H
#define TAP_COMMON_H
// Bounded tapscript cell ABI (cell harness, not engine code).
//
// An element is a scalar encoding that is injective over the declared
// bounded domain (len <= 5, bytes b0..b4):
//
//   bits  0..7   length
//   bits  8..47  byte 0 .. byte 4 (little-endian wire order)
//
// The same encoding is passed to the abstract Schnorr checker, so "same
// arguments" at the seam means "same element" for every element in the
// cell domain.  Nothing here models secp256k1, BIP340 or SHA256.
//
// Packed observable of a CHECKSIGADD step:
//
//   bit  0      result: 1 = opcode returned OK, 0 = error
//   bits 1..6   Core ScriptError ordinal (contract/error_kind.h)
//   bits 7..9   stack depth after the step
//   bits 10..12 top element length (0..5)
//   bits 13..52 top element bytes b0..b4
//
// The out-of-domain sentinel is all-ones and is identical in both legs;
// no scenario inside the declared domain can produce it.

#include <cstdint>

#define TPINLINE static inline __attribute__((always_inline))
#define TP_MAX_LEN 5u
#define TP_MAX_DEPTH 7u

#define TP_ERR_UNKNOWN_ERROR                 1u
#define TP_ERR_EVAL_FALSE                    2u
#define TP_ERR_SCRIPTNUM                     4u
#define TP_ERR_BAD_OPCODE                   16u
#define TP_ERR_INVALID_STACK_OPERATION       18u
#define TP_ERR_DISCOURAGE_UPGRADABLE_PUBKEYTYPE 37u
#define TP_ERR_SCHNORR_SIG_SIZE             45u
#define TP_ERR_SCHNORR_SIG_HASHTYPE         46u
#define TP_ERR_SCHNORR_SIG                  47u
#define TP_ERR_TAPSCRIPT_VALIDATION_WEIGHT  49u
#define TP_ERR_TAPSCRIPT_EMPTY_PUBKEY       52u

TPINLINE uint32_t tp_len(uint64_t e) { return (uint32_t)(e & 0xffu); }
TPINLINE uint32_t tp_byte(uint64_t e, uint32_t i) {
  return (uint32_t)((e >> (8u + 8u * i)) & 0xffu);
}
TPINLINE uint64_t tp_mk(uint32_t len, uint32_t b0, uint32_t b1,
                        uint32_t b2, uint32_t b3, uint32_t b4) {
  return (uint64_t)(len & 0xffu)
       | ((uint64_t)(b0 & 0xffu) << 8)
       | ((uint64_t)(b1 & 0xffu) << 16)
       | ((uint64_t)(b2 & 0xffu) << 24)
       | ((uint64_t)(b3 & 0xffu) << 32)
       | ((uint64_t)(b4 & 0xffu) << 40);
}
TPINLINE uint64_t tp_mkbytes(uint32_t len, uint64_t bytes) {
  return (uint64_t)(len & 0xffu) | ((bytes & 0xffffffffffULL) << 8);
}

TPINLINE uint64_t tp_pack(uint32_t ok, uint32_t err, uint32_t depth,
                          uint64_t top) {
  return (uint64_t)(ok & 1u)
       | ((uint64_t)(err & 0x3fu) << 1)
       | ((uint64_t)(depth & 7u) << 7)
       | ((uint64_t)(tp_len(top) & 7u) << 10)
       | (((top >> 8) & 0xffffffffffULL) << 13);
}
TPINLINE uint64_t tp_fail(uint32_t err) { return tp_pack(0, err, 0, 0); }
TPINLINE uint64_t tp_ood() { return 0xffffffffffffffffULL; }

// The shared tail of CheckSchnorrSignature after the shape checks:
// SignatureHashSchnorr + VerifySchnorr.  Returns 0 on success, otherwise a
// Core ScriptError ordinal (46 = SIGHASH_HASHTYPE, 47 = SCHNORR_SIG in the
// cell's scenarios).  Same symbol in both legs.  This cell proves nothing
// about the tail's crypto/sighash body; see spec.md trust_note.
extern "C" uint32_t btc_equiv_schnorr_tail(uint64_t body, uint32_t hashtype,
                                           uint32_t sig_len,
                                           uint32_t sigversion);

#endif
