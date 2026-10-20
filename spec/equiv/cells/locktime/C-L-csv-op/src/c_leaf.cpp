// C leg -- source-excerpt slice of Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Cited source (all line numbers at the pin):
//   src/script/interpreter.cpp:571-603   case OP_CHECKSEQUENCEVERIFY
//   src/script/interpreter.cpp:1792-1836 GenericTransactionSignatureChecker::CheckSequence
//   src/script/interpreter.cpp:30-41     set_success / set_error
//   src/script/script.h:227-291          CScriptNum (value, comparison, operator&)
//   src/primitives/transaction.h:62-119  CTxIn (nSequence + BIP68 constants)
//   src/primitives/transaction.h:299-300 CTransaction (version, nLockTime are uint32_t)
//   src/script/interpreter.h:107 + verify_flags.h:25 (CSV flag bit = 1 << 10)
//
// Elisions, recorded in spec.md and notes.md:
//   * interpreter.cpp:575-577 (stack.size() < 1 -> INVALID_STACK_OPERATION):
//     the cell domain has exactly one operand, so the guard is statically
//     false; the stack row is SCR-051.
//   * interpreter.cpp:586-587 (CScriptNum nSequence(stacktop(-1), ...5)):
//     the operand arrives already decoded, which is the cell domain.
// `break` (continue execution / NOP) is spelled `return true`; the observable
// is the ScriptError the opcode leaves behind.
#include <cstdint>
#include <cstddef>
#include <compare>

#include "../../../../contract/error_kind.h"

namespace core_slice {

// ---- src/script/interpreter.h:107 + verify_flags.h:25 -------------------
// SCRIPT_VERIFY_CHECKSEQUENCEVERIFY is enumerator 10, so its bit is 1U << 10.
inline constexpr unsigned int SCRIPT_VERIFY_CHECKSEQUENCEVERIFY{1u << 10};

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

struct CTransaction
{
    CTxIn vin[1];
    uint32_t version;
    uint32_t nLockTime;
};

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

    // ---- interpreter.cpp:1792-1836 (verbatim body) ----
    bool CheckSequence(const CScriptNum& nSequence) const
    {
        // Relative lock times are supported by comparing the passed
        // in operand to the sequence number of the input.
        const int64_t txToSequence = (int64_t)txTo->vin[nIn].nSequence;

        // Fail if the transaction's version number is not set high
        // enough to trigger BIP 68 rules.
        if (txTo->version < 2)
            return false;

        // Sequence numbers with their most significant bit set are not
        // consensus constrained. Testing that the transaction's sequence
        // number do not have this bit set prevents using this property
        // to get around a CHECKSEQUENCEVERIFY check.
        if (txToSequence & CTxIn::SEQUENCE_LOCKTIME_DISABLE_FLAG)
            return false;

        // Mask off any bits that do not have consensus-enforced meaning
        // before doing the integer comparisons
        const uint32_t nLockTimeMask = CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG | CTxIn::SEQUENCE_LOCKTIME_MASK;
        const int64_t txToSequenceMasked = txToSequence & nLockTimeMask;
        const CScriptNum nSequenceMasked = nSequence & nLockTimeMask;

        // There are two kinds of nSequence: lock-by-blockheight
        // and lock-by-blocktime, distinguished by whether
        // nSequenceMasked < CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG.
        //
        // We want to compare apples to apples, so fail the script
        // unless the type of nSequenceMasked being tested is the same as
        // the nSequenceMasked in the transaction.
        if (!(
            (txToSequenceMasked <  CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG && nSequenceMasked <  CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG) ||
            (txToSequenceMasked >= CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG && nSequenceMasked >= CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG)
        )) {
            return false;
        }

        // Now that we know we're comparing apples-to-apples, the
        // comparison is a simple numeric one.
        if (nSequenceMasked > txToSequenceMasked)
            return false;

        return true;
    }
};

// ---- interpreter.cpp:571-603, case OP_CHECKSEQUENCEVERIFY ---------------
// (interpreter.cpp:575-577 stack guard and :586-587 operand decode elided.)
inline bool eval_op_checksequenceverify(unsigned int flags,
                                        const BaseSignatureChecker& checker,
                                        const CScriptNum& nSequence,
                                        equiv_error_kind* serror)
{
    set_success(serror);
    if (!(flags & SCRIPT_VERIFY_CHECKSEQUENCEVERIFY)) {
        // not enabled; treat as a NOP3
        return true;                    // Core: break;
    }

    // In the rare event that the argument may be < 0 due to
    // some arithmetic being done first, you can always use
    // 0 MAX CHECKSEQUENCEVERIFY.
    if (nSequence < 0)
        return set_error(serror, EQUIV_ERR_NEGATIVE_LOCKTIME);

    // To provide for future soft-fork extensibility, if the
    // operand has the disabled lock-time flag set,
    // CHECKSEQUENCEVERIFY behaves as a NOP.
    if ((nSequence & CTxIn::SEQUENCE_LOCKTIME_DISABLE_FLAG) != 0)
        return true;                    // Core: break;

    // Compare the specified sequence number with the input.
    if (!checker.CheckSequence(nSequence))
        return set_error(serror, EQUIV_ERR_UNSATISFIED_LOCKTIME);

    return true;                        // Core: break;
}

}  // namespace core_slice

// ---------------------------------------------------------------------------
// Cell harness (not engine text): bind the symbolic inputs to one transaction
// with a single input (nIn == 0) and one pre-decoded 5-byte CScriptNum
// operand, then report the ScriptError the opcode leaves behind.
extern "C" int32_t cell_csv(int64_t operand, bool csv_flag,
                            uint32_t tx_version, uint32_t tx_sequence)
{
    using namespace core_slice;

    CTransaction tx{};
    tx.vin[0].nSequence = tx_sequence;
    tx.version = tx_version;
    tx.nLockTime = 0;                     // not read by CheckSequence

    GenericTransactionSignatureChecker<CTransaction> checker(&tx, 0);
    const CScriptNum nSequence(operand);  // the decoded operand (cell domain)

    equiv_error_kind serror = EQUIV_ERR_OK;
    const bool ok = eval_op_checksequenceverify(
        csv_flag ? SCRIPT_VERIFY_CHECKSEQUENCEVERIFY : 0u, checker, nSequence, &serror);
    return ok ? static_cast<int32_t>(EQUIV_ERR_OK) : static_cast<int32_t>(serror);
}
