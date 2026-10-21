// L leg (general vin) -- reviewed transliteration of the Lean model at
// 4d62a97e551082a69b13f495365bff0a903b0c99.
//
// Cited source:
//   spec/core/Bitcoin/Interpreter/Defs.lean:235-243  LocktimeEnv
//   spec/core/Bitcoin/Interpreter/Defs.lean:272-283  checkLockTimeDef
//   spec/core/Bitcoin/Interpreter/Defs.lean:285-297  checkSequenceDef
//   spec/core/Bitcoin/Interpreter/Rules.lean:87-129  locktimeEnvOf + congruence
//
// SCR-132's Lean face is `locktimeEnvOf tx nIn`, whose sequence component is
// `(tx.vin.getD nIn default).sequence` -- `List.getD` reads the `nIn`-th slot
// when it exists and the default input (sequence 0) otherwise.  The
// transliteration below builds exactly that environment from the selected
// slot and never names another one.
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

// ---- Rules.lean:92-95 (locktimeEnvOf, sequence component) --------------
//   txSequence := (tx.vin.getD nIn default).sequence
// The default input's sequence is 0 (Rules.lean:92-94), passed as `def`.
inline uint32_t vin_getd(const uint32_t* vin, uint64_t len, uint32_t def, uint32_t nIn)
{
    return ((uint64_t)nIn < len) ? vin[nIn] : def;
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

extern "C" int32_t cell_cltv_general(const uint32_t* vin, uint64_t len, uint32_t def,
                                     uint32_t nIn, uint32_t tx_locktime, int64_t operand)
{
    using namespace lean_slice;
    if (operand < 0) return -1;   // opcode rejects n < 0 before the checker
    const LocktimeEnv env{1u, tx_locktime, vin_getd(vin, len, def, nIn)};
    return check_lock_time(env, operand) ? 1 : 0;
}

extern "C" int32_t cell_csv_general(const uint32_t* vin, uint64_t len, uint32_t def,
                                    uint32_t nIn, uint32_t tx_version, int64_t operand)
{
    using namespace lean_slice;
    if (operand < 0) return -1;
    const LocktimeEnv env{tx_version, 0u, vin_getd(vin, len, def, nIn)};
    return check_sequence(env, operand) ? 1 : 0;
}

// Non-interference, second array: the Lean checker on `b`.  Paired with the C
// checker on `a`; equality of the two exports under `selected(a)=selected(b)`
// is the locality statement on two arbitrary vins.
extern "C" int32_t cell_cltv_noninterf_b(const uint32_t* a, const uint32_t* b,
                                         uint64_t len, uint32_t def, uint32_t nIn,
                                         uint32_t tx_locktime, int64_t operand)
{
    using namespace lean_slice;
    if (operand < 0) return -1;
    const uint32_t sa = vin_getd(a, len, def, nIn);
    const uint32_t sb = vin_getd(b, len, def, nIn);
    if (sa != sb) return 2;
    const LocktimeEnv env{1u, tx_locktime, sb};
    return check_lock_time(env, operand) ? 1 : 0;
}

extern "C" int32_t cell_csv_noninterf_b(const uint32_t* a, const uint32_t* b,
                                        uint64_t len, uint32_t def, uint32_t nIn,
                                        uint32_t tx_version, int64_t operand)
{
    using namespace lean_slice;
    if (operand < 0) return -1;
    const uint32_t sa = vin_getd(a, len, def, nIn);
    const uint32_t sb = vin_getd(b, len, def, nIn);
    if (sa != sb) return 2;
    const LocktimeEnv env{tx_version, 0u, sb};
    return check_sequence(env, operand) ? 1 : 0;
}

// Raw-reference Lean leaves for the in-domain (verbatim Core read) transform:
// the harness guard makes the domain explicit and both sides return the same
// sentinel out of range.
extern "C" int32_t cell_cltv_raw_l(const uint32_t* vin, uint64_t len, uint32_t def,
                                   uint32_t nIn, uint32_t tx_locktime, int64_t operand)
{
    using namespace lean_slice;
    (void)def;
    if (operand < 0) return -1;
    if ((uint64_t)nIn >= len) return 2;
    const LocktimeEnv env{1u, tx_locktime, vin[nIn]};
    return check_lock_time(env, operand) ? 1 : 0;
}

extern "C" int32_t cell_csv_raw_l(const uint32_t* vin, uint64_t len, uint32_t def,
                                  uint32_t nIn, uint32_t tx_version, int64_t operand)
{
    using namespace lean_slice;
    (void)def;
    if (operand < 0) return -1;
    if ((uint64_t)nIn >= len) return 2;
    const LocktimeEnv env{tx_version, 0u, vin[nIn]};
    return check_sequence(env, operand) ? 1 : 0;
}

// `List.getD` reads the length only through the `nIn < len` test; this is the
// Lean-side reference for the length-irrelevance transform.
extern "C" int32_t cell_getd_len_b(const uint32_t* vin, uint64_t len1, uint64_t len2,
                                   uint32_t def, uint32_t nIn)
{
    using namespace lean_slice;
    const bool in1 = (uint64_t)nIn < len1;
    const bool in2 = (uint64_t)nIn < len2;
    if (in1 != in2) return 2;
    (void)vin; (void)def;
    return 1;
}
