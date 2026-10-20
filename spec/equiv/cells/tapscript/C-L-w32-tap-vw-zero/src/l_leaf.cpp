// L leg: reviewed transliteration of the Lean twin's tapscript checksig
// budget branch.
//
//   Interpreter/Defs.lean:757-779  evalChecksigTapscript
//   Interpreter/Defs.lean:90-93    VALIDATION_WEIGHT_PER_SIGOP_PASSED = 50
//   Interpreter/Rules.lean:467-477 evalChecksigTapscript_budget_exactly_zero
//   contract/error_kind.h          47/49/52
//
// The signature/pubkey ByteArrays are reduced to their sizes; the
// checkSchnorrWithContext call is the symbolic verdict (same-crypto
// premise).  The packing is cell harness.
#include <cstdint>

static constexpr int64_t VALIDATION_WEIGHT_PER_SIGOP_PASSED = 50;
static constexpr uint32_t SCHNORR_SIG = 47;
static constexpr uint32_t TAPSCRIPT_VALIDATION_WEIGHT = 49;
static constexpr uint32_t TAPSCRIPT_EMPTY_PUBKEY = 52;
static constexpr int64_t VW_MAX = 4000050;
static constexpr uint64_t DOMAIN_REJECT = 0xdeadbeefULL;

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
  // Defs.lean:760
  const bool success = sig_len != 0;
  if (success) {
    // Defs.lean:762-763
    const int64_t vw2 = vw - VALIDATION_WEIGHT_PER_SIGOP_PASSED;
    if (vw2 < 0) {
      return pack(0, TAPSCRIPT_VALIDATION_WEIGHT, 0, vw2);
    }
    // Defs.lean:764-772
    if (pk_len == 0) {
      return pack(0, TAPSCRIPT_EMPTY_PUBKEY, 0, vw2);
    } else if (pk_len == 32) {
      if (!schnorr_ok) {
        return pack(0, SCHNORR_SIG, 0, vw2);
      }
    }
    return pack(1, 0, 1, vw2);
  }
  // Defs.lean:774-778
  if (pk_len == 0) {
    return pack(0, TAPSCRIPT_EMPTY_PUBKEY, 0, vw);
  }
  return pack(1, 0, 0, vw);
}
