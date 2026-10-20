// L leg -- reviewed transliteration of the Lean model at 4d62a97e.
//
// Cited source (btc-lean-public @ 4d62a97e551082a69b13f495365bff0a903b0c99,
// file `spec/core/Bitcoin/Interpreter/Defs.lean`):
//   Defs.lean:80-85   SEQUENCE_LOCKTIME_DISABLE_FLAG/TYPE_FLAG/MASK
//   Defs.lean:235-243 LocktimeEnv (txVersion, txLockTime, txSequence)
//   Defs.lean:285-297 checkSequenceDef
//   Defs.lean:866-875 dispatchOp, wire 0xb2 (OP_CHECKSEQUENCEVERIFY)
//
// The transliteration is line-by-line; src/lean_excerpt.md holds the Lean text
// this file mirrors.  The generated twin (twin/ops_ir.py OP_CSV) is NOT the L
// leg: it has no transaction context and returns TWIN_INVALID_UNSUPPORTED for
// the flag-on path (see notes.md, finding F-LOCKTIME-001).
#include <cstdint>

#include "../../../../contract/error_kind.h"

namespace lean_slice {

// ---- Defs.lean:80-85 ---------------------------------------------------
inline constexpr uint32_t SEQUENCE_LOCKTIME_DISABLE_FLAG = 0x80000000u;  // 1 << 31
inline constexpr uint32_t SEQUENCE_LOCKTIME_TYPE_FLAG    = 0x00400000u;  // 1 << 22
inline constexpr uint32_t SEQUENCE_LOCKTIME_MASK         = 0x0000ffffu;

// ---- Defs.lean:235-243: LocktimeEnv, only the fields this predicate reads
struct LocktimeEnv
{
    uint32_t txVersion;    // := 1
    uint32_t txSequence;   // := 0xFFFFFFFF  (CTxIn::SEQUENCE_FINAL)
};

// ---- Defs.lean:285-297, checkSequenceDef (transliterated) --------------
//   if env.txVersion.toUInt32 < 2 then false
//   else let txSeq := env.txSequence.toNat
//     if (txSeq &&& DISABLE_FLAG) != 0 then false
//     else let mask := TYPE_FLAG ||| MASK
//       let txMasked := txSeq &&& mask
//       let nMasked := n.toNat &&& mask      -- n >= 0 (caller checked)
//       if !((txMasked < TYPE_FLAG /\ nMasked < TYPE_FLAG) \/
//            (txMasked >= TYPE_FLAG /\ nMasked >= TYPE_FLAG)) then false
//       else !(nMasked > txMasked)
inline bool check_sequence_def(const LocktimeEnv& env, int64_t n)
{
    // env.txVersion.toUInt32 is the unsigned wire value; Core's
    // CTransaction::version is uint32_t at the pin, so `< 2` is unsigned there
    // too (primitives/transaction.h:299).
    if (env.txVersion < 2u)
        return false;

    const uint32_t txSeq = env.txSequence;
    if ((txSeq & SEQUENCE_LOCKTIME_DISABLE_FLAG) != 0u)
        return false;

    const uint32_t mask = SEQUENCE_LOCKTIME_TYPE_FLAG | SEQUENCE_LOCKTIME_MASK;
    const uint32_t txMasked = txSeq & mask;
    const uint32_t nMasked = static_cast<uint32_t>(n) & mask;   // n >= 0 here

    if (!((txMasked <  SEQUENCE_LOCKTIME_TYPE_FLAG && nMasked <  SEQUENCE_LOCKTIME_TYPE_FLAG) ||
          (txMasked >= SEQUENCE_LOCKTIME_TYPE_FLAG && nMasked >= SEQUENCE_LOCKTIME_TYPE_FLAG)))
        return false;

    return !(nMasked > txMasked);
}

}  // namespace lean_slice

// ---------------------------------------------------------------------------
// Defs.lean:866-875, dispatchOp wire 0xb2:
//   if w = 0xb2 then
//     if !flags.csv then .ok st
//     else if st.stack.length < 1 then .error .stackUnderflow
//     else match decodeNum pol (topAt st.stack 1) 5 with
//       | .error e => .error e
//       | .ok n =>
//         if n < 0 then .error .negativeLocktime
//         else if (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) != 0 then .ok st
//         else if !checkSequenceDef ctx.chk.env n then .error .unsatisfiedLocktime
//         else .ok st
// The stack-underflow and decodeNum branches are outside the cell domain (one
// already-decoded operand), exactly as on the C leg.
extern "C" int32_t cell_csv(int64_t n, bool csv_flag,
                            uint32_t tx_version, uint32_t tx_sequence)
{
    using namespace lean_slice;

    if (!csv_flag)                                    // if !flags.csv then .ok st
        return EQUIV_ERR_OK;

    if (n < 0)                                        // .error .negativeLocktime
        return EQUIV_ERR_NEGATIVE_LOCKTIME;

    // if (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) != 0 then .ok st
    if ((static_cast<uint64_t>(n) & SEQUENCE_LOCKTIME_DISABLE_FLAG) != 0u)
        return EQUIV_ERR_OK;

    const LocktimeEnv env{tx_version, tx_sequence};
    if (!check_sequence_def(env, n))                  // .error .unsatisfiedLocktime
        return EQUIV_ERR_UNSATISFIED_LOCKTIME;

    return EQUIV_ERR_OK;                              // .ok st
}
