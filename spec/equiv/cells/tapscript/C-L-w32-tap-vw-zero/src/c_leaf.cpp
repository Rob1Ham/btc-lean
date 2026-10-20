// C leg: line-cited source slice from Bitcoin Core cce32b16874e8
// src/script/interpreter.cpp, EvalChecksigTapscript (lines 359-410) and the
// accepted constant interpreter.h (VALIDATION_WEIGHT_PER_SIGOP_PASSED = 50).
//
// The slice keeps Core's consensus ordering exactly:
//   366  success = !sig.empty();
//   368-375  budget decrement, then `if (m_validation_weight_left < 0)`
//   376-388  pubkey-size dispatch (0 => fail, 32 => Schnorr, else upgradable)
// The signature/pubkey bytes are reduced to their lengths; the Schnorr
// verdict is a symbolic boolean (same-crypto premise, see spec.md).
#include <cstdint>

static constexpr int64_t VALIDATION_WEIGHT_PER_SIGOP_PASSED = 50;
// contract/error_kind.h:47,49,52
static constexpr uint32_t SCHNORR_SIG = 47;
static constexpr uint32_t TAPSCRIPT_VALIDATION_WEIGHT = 49;
static constexpr uint32_t TAPSCRIPT_EMPTY_PUBKEY = 52;
// Reachable budget domain: m_validation_weight_left is initialised to
// GetSerializeSize(witness.stack) + VALIDATION_WEIGHT_OFFSET
// (interpreter.cpp:1991); a witness stack is smaller than MAX_BLOCK_WEIGHT.
// The guard is cell harness: Core has no such branch (its caller contract
// guarantees the initialisation and the bound).
static constexpr int64_t VW_MAX = 4000050;
static constexpr uint64_t DOMAIN_REJECT = 0xdeadbeefULL;

// bit0 = script continues, bits 1..7 = error ordinal, bit 8 = CHECKSIG
// success out-parameter, bits 16..47 = m_validation_weight_left as int32
// two's complement.
static inline uint64_t pack(uint32_t cont, uint32_t err, uint32_t success,
                            int64_t vw) {
  uint64_t r = 0;
  r |= (uint64_t)(cont & 1u);
  r |= (uint64_t)(err & 0x3fu) << 1;
  r |= (uint64_t)(success & 1u) << 8;
  r |= (uint64_t)(uint32_t)(int32_t)vw << 16;
  return r;
}

extern "C" uint64_t cell_eval_checksig(uint32_t sig_len, uint32_t pk_len,
                                       int64_t vw, uint32_t schnorr_ok) {
  if (vw < 0 || vw > VW_MAX) return DOMAIN_REJECT;  // harness guard
  // interpreter.cpp:366
  const bool success = sig_len != 0;
  if (success) {
    // interpreter.cpp:371-375
    vw -= VALIDATION_WEIGHT_PER_SIGOP_PASSED;
    if (vw < 0) {
      return pack(0, TAPSCRIPT_VALIDATION_WEIGHT, 0, vw);
    }
  }
  // interpreter.cpp:376-388
  if (pk_len == 0) {
    return pack(0, TAPSCRIPT_EMPTY_PUBKEY, 0, vw);
  } else if (pk_len == 32) {
    if (success && !schnorr_ok) {
      return pack(0, SCHNORR_SIG, 0, vw);
    }
  } else {
    // SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_PUBKEYTYPE is a policy flag and
    // is clear at flags = 0; Core accepts the unknown key version.
  }
  return pack(1, 0, success ? 1u : 0u, vw);
}
