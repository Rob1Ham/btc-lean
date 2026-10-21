// C leg -- source-excerpt slice of Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Cited source (all line numbers at the pin):
//   src/script/interpreter.cpp:1812-1833  CheckSequence's mask + comparisons
//   src/script/script.h:227-291           CScriptNum (value, comparison, operator&)
//   src/primitives/transaction.h:62-119   CTxIn (BIP68 constants)
//   src/consensus/tx_verify.cpp:74-97     CalculateSequenceLocks, time branch
//   src/consensus/tx_verify.cpp:103-111   EvaluateSequenceLocks
//
// Three entry points:
//   cell_csv_masked      -- the script-level comparison of raw masked values
//                           (CheckSequence's tail, no granularity scaling)
//   cell_csv_mask_probe  -- congruence: the verdict does not change when bits
//                           outside 0x0040ffff are toggled
//   cell_seq_granularity -- the SequenceLocks time conversion
//                           `(nSequence & MASK) << GRANULARITY`
#include <cstdint>
#include <cstddef>
#include <compare>
#include <algorithm>

namespace core_slice {

// ---- src/script/script.h:47-48 ------------------------------------------
inline constexpr unsigned int LOCKTIME_THRESHOLD{500'000'000};

// ---- src/script/script.h:227-291 (value + the operators used here) ------
class CScriptNum
{
public:
    explicit CScriptNum(const int64_t& n)
    {
        m_value = n;
    }

    inline bool operator==(const int64_t& rhs) const    { return m_value == rhs; }
    inline auto operator<=>(const int64_t& rhs) const   { return m_value <=> rhs; }

    inline bool operator==(const CScriptNum& rhs) const { return operator==(rhs.m_value); }
    inline auto operator<=>(const CScriptNum& rhs) const { return operator<=>(rhs.m_value); }

    inline CScriptNum operator&(   const int64_t& rhs)  const { return CScriptNum(m_value & rhs);}

    int64_t GetInt64() const { return m_value; }

private:
    int64_t m_value;
};

// ---- src/primitives/transaction.h:62-119 (constants used) --------------
class CTxIn
{
public:
    static constexpr uint32_t SEQUENCE_FINAL{0xffffffff};
    static constexpr uint32_t SEQUENCE_LOCKTIME_DISABLE_FLAG{1U << 31};
    static constexpr uint32_t SEQUENCE_LOCKTIME_TYPE_FLAG{1 << 22};
    static constexpr uint32_t SEQUENCE_LOCKTIME_MASK{0x0000ffff};
    static constexpr int SEQUENCE_LOCKTIME_GRANULARITY{9};
};

// ---- interpreter.cpp:1812-1833, the mask and both comparisons -----------
// This is CheckSequence's tail: the version gate (:1800-1801) and the
// transaction disable-flag gate (:1807-1808) have already passed.  The
// observable is SCRIPT_ERR_UNSATISFIED_LOCKTIME (22) on failure and OK (0) on
// success, i.e. the value `CheckSequence` returns as a ScriptError.
inline bool check_sequence_masked(const CScriptNum& nSequence, int64_t txToSequence)
{
    const uint32_t nLockTimeMask = CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG | CTxIn::SEQUENCE_LOCKTIME_MASK;
    const int64_t txToSequenceMasked = txToSequence & nLockTimeMask;
    const CScriptNum nSequenceMasked = nSequence & nLockTimeMask;

    if (!(
        (txToSequenceMasked <  CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG && nSequenceMasked <  CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG) ||
        (txToSequenceMasked >= CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG && nSequenceMasked >= CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG)
    )) {
        return false;
    }

    if (nSequenceMasked > txToSequenceMasked)
        return false;

    return true;
}

}  // namespace core_slice

// ---------------------------------------------------------------------------
// Cell harness (not engine text).
extern "C" int32_t cell_csv_masked(int64_t operand, uint32_t tx_sequence)
{
    using namespace core_slice;
    const CScriptNum nSequence(operand);
    return check_sequence_masked(nSequence, (int64_t)tx_sequence) ? 0 : 22;
}

// Congruence probe: toggling any bit outside the BIP68 mask (0x0040ffff) on
// either operand must not change the verdict.  Bits 16..21 and 23..30 are
// masked off by `nLockTimeMask`; bit 31 is the transaction disable flag and is
// checked before this slice, so it is excluded from the probe's junk mask.
extern "C" int32_t cell_csv_mask_probe(int64_t operand, uint32_t tx_sequence, uint32_t junk)
{
    using namespace core_slice;
    const uint32_t JUNK_MASK = 0x7fbf0000u;   // bits 16..21 and 23..30
    const uint32_t d = junk & JUNK_MASK;

    const CScriptNum a(operand);
    const CScriptNum b(operand ^ (int64_t)d);
    const int32_t va = check_sequence_masked(a, (int64_t)tx_sequence) ? 1 : 0;
    const int32_t vb = check_sequence_masked(b, (int64_t)(tx_sequence ^ d)) ? 1 : 0;
    return va == vb ? 1 : 0;
}

// tx_verify.cpp:94-95 (inside CalculateSequenceLocks, time branch): the masked
// relative lock-time converted to seconds by shifting up GRANULARITY bits.
extern "C" int64_t cell_seq_granularity(uint32_t tx_sequence)
{
    using namespace core_slice;
    return (int64_t)((tx_sequence & CTxIn::SEQUENCE_LOCKTIME_MASK) << CTxIn::SEQUENCE_LOCKTIME_GRANULARITY);
}

// tx_verify.cpp:79-97 (single-input reduction of the max fold) + 103-111:
// the time-based sequence lock is satisfied iff the last invalid time
// `nCoinTime + relative - 1` is strictly below the block's MTP.
extern "C" int32_t cell_seq_time_ok(uint32_t mtp_parent, uint32_t tx_sequence, uint32_t mtp_block)
{
    using namespace core_slice;
    int64_t nMinTime = -1;

    if (tx_sequence & CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG) {
        const int64_t nCoinTime = (int64_t)mtp_parent;
        nMinTime = std::max(nMinTime, nCoinTime + (int64_t)((tx_sequence & CTxIn::SEQUENCE_LOCKTIME_MASK) << CTxIn::SEQUENCE_LOCKTIME_GRANULARITY) - 1);
    }

    const int64_t nBlockTime = (int64_t)mtp_block;
    if (nMinTime >= nBlockTime)
        return 0;                           // EvaluateSequenceLocks -> false
    return 1;                               // -> true
}
