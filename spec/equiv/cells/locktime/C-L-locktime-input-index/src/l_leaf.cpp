// L leg -- reviewed transliteration of the Lean model at 4d62a97e.
//
// Cited source (btc-lean-public @ 4d62a97e551082a69b13f495365bff0a903b0c99):
//   spec/core/Bitcoin/Interpreter/Defs.lean:235-243  LocktimeEnv
//   spec/core/Bitcoin/Interpreter/Defs.lean:272-283  checkLockTimeDef
//   spec/core/Bitcoin/Interpreter/Defs.lean:285-297  checkSequenceDef
//   spec/core/Bitcoin/Interpreter/Rules.lean:87-129  locktimeEnvOf,
//       locktimeEnvOf_congr, checkLockTime_perInput, checkSequence_perInput
//
// SCR-132's Lean face is `locktimeEnvOf tx nIn`: the environment is
// (tx.version, tx.locktime, tx.vin[nIn].sequence).  The transliteration below
// builds exactly that environment from the selected slot and never mentions
// the other one -- which is what makes the C=L equality a per-input proof.
#include <cstdint>

namespace lean_slice {

// ---- Defs.lean:77-85 ---------------------------------------------------
inline constexpr int64_t LOCKTIME_THRESHOLD = 500'000'000;
inline constexpr uint32_t SEQUENCE_LOCKTIME_DISABLE_FLAG = 0x80000000u;
inline constexpr uint32_t SEQUENCE_LOCKTIME_TYPE_FLAG    = 0x00400000u;
inline constexpr uint32_t SEQUENCE_LOCKTIME_MASK         = 0x0000ffffu;

// ---- Defs.lean:235-243 (LocktimeEnv) -----------------------------------
struct LocktimeEnv {
    uint32_t txVersion;
    uint32_t txLockTime;
    uint32_t txSequence;
};

// ---- Rules.lean:87-93 (locktimeEnvOf) ----------------------------------
//   txSequence := (tx.vin.getD nIn default).sequence
// The cell's transaction has two inputs and nIn is the boolean index, so the
// `getD` default is never taken.
inline uint32_t vin_at(const uint32_t vin[2], bool nIn)
{
    return nIn ? vin[1] : vin[0];
}

// ---- Defs.lean:272-283 (checkLockTimeDef) ------------------------------
inline bool check_lock_time(const LocktimeEnv& env, int64_t n)
{
    const int64_t txlt = static_cast<int64_t>(env.txLockTime);
    if (!((txlt < LOCKTIME_THRESHOLD && n < LOCKTIME_THRESHOLD) ||
          (txlt >= LOCKTIME_THRESHOLD && n >= LOCKTIME_THRESHOLD)))
        return false;
    if (n > txlt)
        return false;
    if (env.txSequence == 0xffffffffu)   // input final
        return false;
    return true;
}

// ---- Defs.lean:285-297 (checkSequenceDef) ------------------------------
inline bool check_sequence(const LocktimeEnv& env, int64_t n)
{
    if (env.txVersion < 2u)
        return false;
    if ((env.txSequence & SEQUENCE_LOCKTIME_DISABLE_FLAG) != 0u)
        return false;

    const uint32_t mask = SEQUENCE_LOCKTIME_TYPE_FLAG | SEQUENCE_LOCKTIME_MASK;
    const uint32_t tx_masked = env.txSequence & mask;
    const uint32_t n_masked = static_cast<uint32_t>(n) & mask;

    const bool same_type =
        (tx_masked <  SEQUENCE_LOCKTIME_TYPE_FLAG && n_masked <  SEQUENCE_LOCKTIME_TYPE_FLAG) ||
        (tx_masked >= SEQUENCE_LOCKTIME_TYPE_FLAG && n_masked >= SEQUENCE_LOCKTIME_TYPE_FLAG);
    if (!same_type) return false;
    if (n_masked > tx_masked) return false;
    return true;
}

}  // namespace lean_slice

extern "C" int32_t cell_cltv_input_index(uint32_t tx_locktime, int64_t operand,
                                         uint32_t seq0, uint32_t seq1, bool nIn)
{
    using namespace lean_slice;
    if (operand < 0) return -1;   // opcode rejects n < 0 before the checker
    const uint32_t vin[2] = {seq0, seq1};
    const LocktimeEnv env{1u, tx_locktime, vin_at(vin, nIn)};
    return check_lock_time(env, operand) ? 1 : 0;
}

extern "C" int32_t cell_csv_input_index(uint32_t tx_version, int64_t operand,
                                        uint32_t seq0, uint32_t seq1, bool nIn)
{
    using namespace lean_slice;
    if (operand < 0) return -1;   // opcode rejects n < 0 before the checker
    const uint32_t vin[2] = {seq0, seq1};
    const LocktimeEnv env{tx_version, 0u, vin_at(vin, nIn)};
    return check_sequence(env, operand) ? 1 : 0;
}
