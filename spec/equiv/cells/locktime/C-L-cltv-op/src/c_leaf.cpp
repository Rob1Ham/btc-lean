// C leg -- source-excerpt slice of Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Cited source (all line numbers at the pin):
//   src/script/interpreter.cpp:532-568   case OP_CHECKLOCKTIMEVERIFY
//   src/script/interpreter.cpp:1755-1788 GenericTransactionSignatureChecker::CheckLockTime
//   src/script/interpreter.cpp:30-41     set_success / set_error
//   src/script/script.h:47-48            LOCKTIME_THRESHOLD
//   src/script/script.h:227-291,326-336  CScriptNum (value, comparison operators)
//   src/primitives/transaction.h:62-119  CTxIn (nSequence + BIP65/68 constants)
//   src/primitives/transaction.h:299-300 CTransaction (version, nLockTime)
//   src/script/interpreter.h:48-160      script_verify_flags (bit i << flag index)
//   src/script/verify_flags.h:25         flag bit = 1 << enumerator index
//
// The slice keeps the engine text verbatim for CheckLockTime and for the
// CHECKLOCKTIMEVERIFY case body.  Two elisions are recorded in spec.md and
// notes.md:
//   * interpreter.cpp:537-539 (stack.size() < 1 -> INVALID_STACK_OPERATION):
//     the cell domain has exactly one operand, so the guard is statically
//     false; the stack row is SCR-051, not a locktime row.
//   * interpreter.cpp:557-558 (CScriptNum nLockTime(stacktop(-1), ...5)):
//     the operand arrives already decoded, which is the cell domain.
// `break` (continue execution) is spelled `return true`; the observable is
// the ScriptError the opcode leaves behind.
#include <cstdint>
#include <cstddef>
#include <compare>

#include "../../../../contract/error_kind.h"

namespace core_slice {

// ---- src/script/interpreter.h:102 + verify_flags.h:25 --------------------
// SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY is enumerator 9, so its bit is 1U << 9.
inline constexpr unsigned int SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY{1u << 9};

// ---- src/script/script.h:47-48 ------------------------------------------
// Threshold for nLockTime: below this value it is interpreted as block number,
// otherwise as UNIX timestamp.
inline constexpr unsigned int LOCKTIME_THRESHOLD{500'000'000};

// ---- src/script/interpreter.cpp:30-41 (verbatim) ------------------------
inline bool set_success(equiv_error_kind* ret)
{
    if (ret)
        *ret = EQUIV_ERR_OK;
    return true;
}

inline bool set_error(equiv_error_kind* ret, const equiv_error_kind serror)
{
    if (ret)
        *ret = serror;
    return false;
}

// ---- src/script/script.h:227-291 (value + the operators used here) ------
// The real class also carries the 4/5-byte vch constructor, set_vch and
// arithmetic; none of those are reached by the cited lines.
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

// ---- src/primitives/transaction.h:62-119 (fields + constants used) ------
class CTxIn
{
public:
    uint32_t nSequence;

    static constexpr uint32_t SEQUENCE_FINAL{0xffffffff};
    static constexpr uint32_t SEQUENCE_LOCKTIME_DISABLE_FLAG{1U << 31};
    static constexpr uint32_t SEQUENCE_LOCKTIME_TYPE_FLAG{1 << 22};
    static constexpr uint32_t SEQUENCE_LOCKTIME_MASK{0x0000ffff};
    static constexpr int SEQUENCE_LOCKTIME_GRANULARITY{9};
};

// ---- src/primitives/transaction.h:299-300 -------------------------------
// (Core holds vin in a std::vector; the cell fixes one input, so a one-element
// array carries the same read `txTo->vin[nIn]` with nIn == 0.)
struct CTransaction
{
    CTxIn vin[1];
    uint32_t version;
    uint32_t nLockTime;
};

// ---- src/script/interpreter.cpp (BaseSignatureChecker + template) -------
class BaseSignatureChecker
{
public:
    virtual bool CheckLockTime(const CScriptNum&) const { return false; }
    virtual bool CheckSequence(const CScriptNum&) const { return false; }
    virtual ~BaseSignatureChecker() = default;
};

template <class T>
class GenericTransactionSignatureChecker : public BaseSignatureChecker
{
public:
    const T* txTo;
    unsigned int nIn;

    GenericTransactionSignatureChecker(const T* txToIn, unsigned int nInIn) : txTo(txToIn), nIn(nInIn) {}

    // ---- interpreter.cpp:1755-1788 (verbatim body) ----
    bool CheckLockTime(const CScriptNum& nLockTime) const
    {
        // There are two kinds of nLockTime: lock-by-blockheight
        // and lock-by-blocktime, distinguished by whether
        // nLockTime < LOCKTIME_THRESHOLD.
        //
        // We want to compare apples to apples, so fail the script
        // unless the type of nLockTime being tested is the same as
        // the nLockTime in the transaction.
        if (!(
            (txTo->nLockTime <  LOCKTIME_THRESHOLD && nLockTime <  LOCKTIME_THRESHOLD) ||
            (txTo->nLockTime >= LOCKTIME_THRESHOLD && nLockTime >= LOCKTIME_THRESHOLD)
        ))
            return false;

        // Now that we know we're comparing apples-to-apples, the
        // comparison is a simple numeric one.
        if (nLockTime > (int64_t)txTo->nLockTime)
            return false;

        // Finally the nLockTime feature can be disabled in IsFinalTx()
        // and thus CHECKLOCKTIMEVERIFY bypassed if every txin has
        // been finalized by setting nSequence to maxint. The
        // transaction would be allowed into the blockchain, making
        // the opcode ineffective.
        //
        // Testing if this vin is not final is sufficient to
        // prevent this condition. Alternatively we could test all
        // inputs, but testing just this input minimizes the data
        // required to prove correct CHECKLOCKTIMEVERIFY execution.
        if (CTxIn::SEQUENCE_FINAL == txTo->vin[nIn].nSequence)
            return false;

        return true;
    }
};

// ---- interpreter.cpp:532-568, case OP_CHECKLOCKTIMEVERIFY ---------------
// (interpreter.cpp:537-539 stack guard and :557-558 operand decode elided.)
inline bool eval_op_checklocktimeverify(unsigned int flags,
                                        const BaseSignatureChecker& checker,
                                        const CScriptNum& nLockTime,
                                        equiv_error_kind* serror)
{
    set_success(serror);
    if (!(flags & SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY)) {
        // not enabled; treat as a NOP2
        return true;                    // Core: break;
    }

    // In the rare event that the argument may be < 0 due to
    // some arithmetic being done first, you can always use
    // 0 MAX CHECKLOCKTIMEVERIFY.
    if (nLockTime < 0)
        return set_error(serror, EQUIV_ERR_NEGATIVE_LOCKTIME);

    // Actually compare the specified lock time with the transaction.
    if (!checker.CheckLockTime(nLockTime))
        return set_error(serror, EQUIV_ERR_UNSATISFIED_LOCKTIME);

    return true;                        // Core: break;
}

}  // namespace core_slice

// ---------------------------------------------------------------------------
// Cell harness (not engine text): bind the symbolic inputs to one transaction
// with a single input (nIn == 0) and one pre-decoded 5-byte CScriptNum
// operand, then report the ScriptError the opcode leaves behind.
extern "C" int32_t cell_cltv(int64_t operand, bool cltv_flag,
                             uint32_t tx_locktime, uint32_t tx_sequence)
{
    using namespace core_slice;

    CTransaction tx{};
    tx.vin[0].nSequence = tx_sequence;
    tx.version = 1;                       // version is not read by CheckLockTime
    tx.nLockTime = tx_locktime;

    GenericTransactionSignatureChecker<CTransaction> checker(&tx, 0);
    const CScriptNum nLockTime(operand);  // the decoded operand (cell domain)

    equiv_error_kind serror = EQUIV_ERR_OK;
    const bool ok = eval_op_checklocktimeverify(
        cltv_flag ? SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY : 0u, checker, nLockTime, &serror);
    return ok ? static_cast<int32_t>(EQUIV_ERR_OK) : static_cast<int32_t>(serror);
}
