// C leg -- source-excerpt slice of Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Cited source (all line numbers at the pin):
//   src/script/interpreter.cpp:1754-1788  CheckLockTime
//   src/script/interpreter.cpp:1791-1836  CheckSequence
//   src/primitives/transaction.h:62-119   CTxIn (BIP68 constants, SEQUENCE_FINAL)
//   src/primitives/transaction.h:277-300  CTransaction (version, nLockTime, vin)
//   src/script/script.h:47-48,227-291     LOCKTIME_THRESHOLD, CScriptNum
//
// SCR-132 is the per-input row: both checkers take `nIn` and read
// `txTo->vin[nIn]` (CLTV only for the SEQUENCE_FINAL test, CSV for the whole
// relative lock-time), and they read no other input.  The two entry points
// below are the checker bodies, transcribed line for line; the transaction is
// built from a 2-input vin and the boolean index selects the slot.
#include <cstdint>
#include <cstddef>
#include <compare>

namespace core_slice {

// ---- src/script/script.h:47-48 ------------------------------------------
inline constexpr int64_t LOCKTIME_THRESHOLD{500'000'000};

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

    uint32_t nSequence{SEQUENCE_FINAL};
};

// ---- src/primitives/transaction.h:277-300 (fields the checkers read) ----
class CTransaction
{
public:
    uint32_t version{1};
    uint32_t nLockTime{0};
    const CTxIn* vin{nullptr};
};

// ---- interpreter.cpp:1754-1788 (GenericTransactionSignatureChecker) ------
// Reads txTo->nLockTime and txTo->vin[nIn].nSequence; no other input.
inline bool check_lock_time(const CTransaction& txTo, unsigned int nIn, const CScriptNum& nLockTime)
{
    if (!(
        (txTo.nLockTime <  LOCKTIME_THRESHOLD && nLockTime <  LOCKTIME_THRESHOLD) ||
        (txTo.nLockTime >= LOCKTIME_THRESHOLD && nLockTime >= LOCKTIME_THRESHOLD)
    ))
        return false;

    if (nLockTime > (int64_t)txTo.nLockTime)
        return false;

    if (CTxIn::SEQUENCE_FINAL == txTo.vin[nIn].nSequence)
        return false;

    return true;
}

// ---- interpreter.cpp:1791-1836 ------------------------------------------
// The only transaction data read is txTo->version and
// txTo->vin[nIn].nSequence.
inline bool check_sequence(const CTransaction& txTo, unsigned int nIn, const CScriptNum& nSequence)
{
    const int64_t txToSequence = (int64_t)txTo.vin[nIn].nSequence;

    if (txTo.version < 2)
        return false;

    if (txToSequence & CTxIn::SEQUENCE_LOCKTIME_DISABLE_FLAG)
        return false;

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
//
// The opcode rejects a negative operand before the checker is called
// (interpreter.cpp:582-584 NEGATIVE_LOCKTIME for CLTV, :589-590 for CSV), so
// the cell's domain is operand >= 0; the harness marks the excluded case with
// -1 on both legs instead of pretending the checker sees it.  The verdict is
// the checker's boolean as 1/0.
//
// `nIn` is the input index.  The cell models a 2-input transaction, so the
// index is a boolean; both values are symbolic, and the *unselected* slot is
// also fully symbolic, so the equality proved here says the verdict cannot
// depend on it.
namespace {
constexpr int32_t CELL_OPERAND_UNREACHABLE = -1;
}

extern "C" int32_t cell_cltv_input_index(uint32_t tx_locktime, int64_t operand,
                                         uint32_t seq0, uint32_t seq1, bool nIn)
{
    using namespace core_slice;
    if (operand < 0) return CELL_OPERAND_UNREACHABLE;
    const CTxIn vin[2] = {CTxIn{seq0}, CTxIn{seq1}};
    const CTransaction tx{1u, tx_locktime, vin};
    const CScriptNum n(operand);
    return check_lock_time(tx, nIn ? 1u : 0u, n) ? 1 : 0;
}

extern "C" int32_t cell_csv_input_index(uint32_t tx_version, int64_t operand,
                                        uint32_t seq0, uint32_t seq1, bool nIn)
{
    using namespace core_slice;
    if (operand < 0) return CELL_OPERAND_UNREACHABLE;
    const CTxIn vin[2] = {CTxIn{seq0}, CTxIn{seq1}};
    const CTransaction tx{tx_version, 0u, vin};
    const CScriptNum n(operand);
    return check_sequence(tx, nIn ? 1u : 0u, n) ? 1 : 0;
}
