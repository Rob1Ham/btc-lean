// C leg (general vin) -- source-excerpt slice of Bitcoin Core
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Cited source (all line numbers at the pin):
//   src/script/interpreter.cpp:1754-1788  GenericTransactionSignatureChecker::CheckLockTime
//   src/script/interpreter.cpp:1791-1836  GenericTransactionSignatureChecker::CheckSequence
//   src/primitives/transaction.h:62-119   CTxIn (BIP68 constants, SEQUENCE_FINAL)
//   src/primitives/transaction.h:277-300  CTransaction (version, nLockTime, vin)
//   src/script/script.h:47-48,227-291     LOCKTIME_THRESHOLD, CScriptNum
//
// SCR-132 is the per-input row.  The checker bodies read `txTo->vin[nIn]`
// and no other input.  Here `vin` is an arbitrary-length run of sequence
// fields; `len` is its length and `nIn` is any uint32 (Core's `unsigned int`).
//
// Core's `txTo->vin[nIn]` carries `assert(nIn < vin.size())` (release builds
// omit the check); consensus callers guarantee the index.  The exported
// entry points materialise that assert as the same guard Lean's
// `locktimeEnvOf` uses (`List.getD`), so the out-of-range case is total and
// returns the getD default instead of an out-of-bounds read.  On the
// reachable domain (`nIn < len`) the read is literally `txTo->vin[nIn]`.
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

    // The only field the two checkers read.  The cell is about slot identity,
    // not the byte layout of CTxIn; `prevout`/`scriptSig` are not modelled.
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

// Same body on an already-selected sequence field.  Used only for the
// materialised-assert branch, where Core's context would be the getD default
// input instead of `vin[nIn]`.
inline bool check_lock_time_on_sequence(uint32_t txLockTime, uint32_t sequence, const CScriptNum& nLockTime)
{
    if (!(
        (txLockTime <  LOCKTIME_THRESHOLD && nLockTime <  LOCKTIME_THRESHOLD) ||
        (txLockTime >= LOCKTIME_THRESHOLD && nLockTime >= LOCKTIME_THRESHOLD)
    ))
        return false;

    if (nLockTime > (int64_t)txLockTime)
        return false;

    if (CTxIn::SEQUENCE_FINAL == sequence)
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

inline bool check_sequence_on_sequence(uint32_t txVersion, uint32_t txToSequence, const CScriptNum& nSequence)
{
    if (txVersion < 2)
        return false;

    if (txToSequence & CTxIn::SEQUENCE_LOCKTIME_DISABLE_FLAG)
        return false;

    const uint32_t nLockTimeMask = CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG | CTxIn::SEQUENCE_LOCKTIME_MASK;
    const int64_t txToSequenceMasked = (int64_t)txToSequence & nLockTimeMask;
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

// The materialised `assert(nIn < vin.size())` and Lean's `List.getD nIn`.
// This is exactly `(tx.vin.getD nIn default).sequence` from Rules.lean:92-95,
// with `default.sequence = 0` supplied by the caller (`def`).
inline uint32_t getd_sequence(const uint32_t* vin, uint64_t len, uint32_t def, uint32_t nIn)
{
    return ((uint64_t)nIn < len) ? vin[nIn] : def;
}

}  // namespace core_slice

// ---------------------------------------------------------------------------
// Cell harness (not engine text).
//
// `operand < 0` is rejected by the opcode before the checker
// (interpreter.cpp:582-584 for CLTV, :589-590 for CSV); the harness returns
// the sentinel -1 on both legs instead of pretending the checker sees it.
// The observable is the checker's boolean verdict as 1/0.
namespace {
constexpr int32_t CELL_OPERAND_UNREACHABLE = -1;
}

// Core body on an arbitrary-length vin.  In range this is the verbatim
// `txTo->vin[nIn]` read; out of range it is the getD default input.
extern "C" int32_t cell_cltv_general(const uint32_t* vin, uint64_t len, uint32_t def,
                                     uint32_t nIn, uint32_t tx_locktime, int64_t operand)
{
    using namespace core_slice;
    if (operand < 0) return CELL_OPERAND_UNREACHABLE;
    const CScriptNum n(operand);
    // The selected-slot read is performed once, here; the verdict below is
    // the Core body on that value.  (Core orders the same read after the
    // type/threshold tests; every transaction has a live vin, so the order
    // is unobservable on the row's domain.)
    const uint32_t seq = getd_sequence(vin, len, def, nIn);
    return check_lock_time_on_sequence(tx_locktime, seq, n) ? 1 : 0;
}

extern "C" int32_t cell_csv_general(const uint32_t* vin, uint64_t len, uint32_t def,
                                    uint32_t nIn, uint32_t tx_version, int64_t operand)
{
    using namespace core_slice;
    if (operand < 0) return CELL_OPERAND_UNREACHABLE;
    const CScriptNum n(operand);
    const uint32_t seq = getd_sequence(vin, len, def, nIn);
    return check_sequence_on_sequence(tx_version, seq, n) ? 1 : 0;
}

// Raw Core read, no materialised assert: `txTo->vin[nIn]` is executed
// unconditionally.  Equal to the general entry point on the in-range domain.
extern "C" int32_t cell_cltv_raw(const uint32_t* vin, uint64_t len, uint32_t def,
                                 uint32_t nIn, uint32_t tx_locktime, int64_t operand)
{
    using namespace core_slice;
    (void)def;
    if (operand < 0) return CELL_OPERAND_UNREACHABLE;
    if ((uint64_t)nIn >= len) return 2;   // harness domain guard (assert materialised)
    const CScriptNum n(operand);
    const CTransaction tx{1u, tx_locktime, reinterpret_cast<const CTxIn*>(vin)};
    const uint32_t seq = tx.vin[nIn].nSequence;   // verbatim txTo->vin[nIn] read
    return check_lock_time_on_sequence(tx_locktime, seq, n) ? 1 : 0;
}

extern "C" int32_t cell_csv_raw(const uint32_t* vin, uint64_t len, uint32_t def,
                                uint32_t nIn, uint32_t tx_version, int64_t operand)
{
    using namespace core_slice;
    (void)def;
    if (operand < 0) return CELL_OPERAND_UNREACHABLE;
    if ((uint64_t)nIn >= len) return 2;   // harness domain guard (assert materialised)
    const CScriptNum n(operand);
    const CTransaction tx{tx_version, 0u, reinterpret_cast<const CTxIn*>(vin)};
    const uint32_t seq = tx.vin[nIn].nSequence;   // verbatim txTo->vin[nIn] read
    return check_sequence_on_sequence(tx_version, seq, n) ? 1 : 0;
}

// Non-interference product: two arbitrary vins that agree on the selected
// slot (including both out of range, where both take the default) must give
// the same verdict.  `_a` reads the verdict of the first vin, `_b` of the
// second; the equality of the two exports is the row statement.
extern "C" int32_t cell_cltv_noninterf_a(const uint32_t* a, const uint32_t* b,
                                         uint64_t len, uint32_t def, uint32_t nIn,
                                         uint32_t tx_locktime, int64_t operand)
{
    using namespace core_slice;
    if (operand < 0) return CELL_OPERAND_UNREACHABLE;
    const uint32_t sa = getd_sequence(a, len, def, nIn);
    const uint32_t sb = getd_sequence(b, len, def, nIn);
    if (sa != sb) return 2;
    return check_lock_time_on_sequence(tx_locktime, sa, CScriptNum(operand)) ? 1 : 0;
}

extern "C" int32_t cell_cltv_noninterf_b(const uint32_t* a, const uint32_t* b,
                                         uint64_t len, uint32_t def, uint32_t nIn,
                                         uint32_t tx_locktime, int64_t operand)
{
    using namespace core_slice;
    if (operand < 0) return CELL_OPERAND_UNREACHABLE;
    const uint32_t sa = getd_sequence(a, len, def, nIn);
    const uint32_t sb = getd_sequence(b, len, def, nIn);
    if (sa != sb) return 2;
    return check_lock_time_on_sequence(tx_locktime, sb, CScriptNum(operand)) ? 1 : 0;
}

extern "C" int32_t cell_csv_noninterf_a(const uint32_t* a, const uint32_t* b,
                                        uint64_t len, uint32_t def, uint32_t nIn,
                                        uint32_t tx_version, int64_t operand)
{
    using namespace core_slice;
    if (operand < 0) return CELL_OPERAND_UNREACHABLE;
    const uint32_t sa = getd_sequence(a, len, def, nIn);
    const uint32_t sb = getd_sequence(b, len, def, nIn);
    if (sa != sb) return 2;
    return check_sequence_on_sequence(tx_version, sa, CScriptNum(operand)) ? 1 : 0;
}

extern "C" int32_t cell_csv_noninterf_b(const uint32_t* a, const uint32_t* b,
                                        uint64_t len, uint32_t def, uint32_t nIn,
                                        uint32_t tx_version, int64_t operand)
{
    using namespace core_slice;
    if (operand < 0) return CELL_OPERAND_UNREACHABLE;
    const uint32_t sa = getd_sequence(a, len, def, nIn);
    const uint32_t sb = getd_sequence(b, len, def, nIn);
    if (sa != sb) return 2;
    return check_sequence_on_sequence(tx_version, sb, CScriptNum(operand)) ? 1 : 0;
}

// The getD fallback depends on the length only through the `nIn < len`
// predicate: for any two lengths on the same side of `nIn`, the selected
// sequence is identical (in particular, every out-of-range length yields the
// default and reads no slot at all).
extern "C" int32_t cell_getd_len_a(const uint32_t* vin, uint64_t len1, uint64_t len2,
                                   uint32_t def, uint32_t nIn)
{
    using namespace core_slice;
    const bool in1 = (uint64_t)nIn < len1;
    const bool in2 = (uint64_t)nIn < len2;
    if (in1 != in2) return 2;
    return getd_sequence(vin, len1, def, nIn) == getd_sequence(vin, len2, def, nIn) ? 1 : 0;
}

extern "C" int32_t cell_getd_len_b(const uint32_t* vin, uint64_t len1, uint64_t len2,
                                   uint32_t def, uint32_t nIn)
{
    (void)vin; (void)def;
    const bool in1 = (uint64_t)nIn < len1;
    const bool in2 = (uint64_t)nIn < len2;
    if (in1 != in2) return 2;
    return 1;
}
