// L leg — reviewed transliteration of the btc-lean model at
// spec/core model_rev 4d62a97e551082a69b13f495365bff0a903b0c99.
//
//   spec/core/Bitcoin/Interpreter/SigOps.lean:54   LEGACY_SIGOP_SCALE = 4
//   spec/core/Bitcoin/Interpreter/SigOps.lean:400-416  InputSigOps, sigOpCost
//   spec/core/Bitcoin/TxValidation/SigOpsCost.lean:51-61  p2shSigOpsTx
//       (coinbase => 0; P2SH prevouts only)
//
// sigOpCost s = LEGACY_SIGOP_SCALE * (s.legacy + s.p2sh) + s.witness.
// GetTransactionSigOpCost's guards are: coinbase => legacy term only; the P2SH
// component present only under SCRIPT_VERIFY_P2SH.  The cell feeds the P2SH
// component through the gate and then applies the Lean formula.
#include "limits_common.h"

namespace {

static const uint64_t LEGACY_SIGOP_SCALE = 4;

struct InputSigOps {
  uint64_t legacy;
  uint64_t p2sh;
  uint64_t witness;
};

CLINLINE uint64_t lean_sigop_cost(const InputSigOps& s) {
  return LEGACY_SIGOP_SCALE * (s.legacy + s.p2sh) + s.witness;
}

CLINLINE int64_t lean_tx_sigop_cost(uint32_t legacy, uint32_t p2sh,
                                    uint32_t witness, uint32_t coinbase,
                                    uint32_t p2sh_flag) {
  if (coinbase) {
    return static_cast<int64_t>(LEGACY_SIGOP_SCALE * legacy);
  }
  InputSigOps s;
  s.legacy = legacy;
  s.p2sh = p2sh_flag ? p2sh : 0;
  s.witness = witness;
  return static_cast<int64_t>(lean_sigop_cost(s));
}

}  // namespace

extern "C" int64_t cell_sigop_cost(uint32_t legacy, uint32_t p2sh,
                                   uint32_t witness, uint32_t coinbase,
                                   uint32_t p2sh_flag) {
  return lean_tx_sigop_cost(legacy, p2sh, witness, coinbase, p2sh_flag);
}
