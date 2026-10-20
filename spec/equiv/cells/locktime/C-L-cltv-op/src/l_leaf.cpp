// L leg -- reviewed transliteration of the Lean model at 4d62a97e.
//
// Cited source (Lean identifiers, file `spec/core/Bitcoin/Interpreter/Defs.lean`
// of btc-lean-public @ 4d62a97e551082a69b13f495365bff0a903b0c99):
//   Defs.lean:77-79   LOCKTIME_THRESHOLD := 500000000
//   Defs.lean:235-243 LocktimeEnv (txVersion, txLockTime, txSequence)
//   Defs.lean:272-283 checkLockTimeDef  [rule "SCR-122".."SCR-125"]
//   Defs.lean:857-865 dispatchOp, wire 0xb1 (OP_CHECKLOCKTIMEVERIFY)
//
// The transliteration is line-by-line; src/lean_excerpt.md holds the Lean text
// this file mirrors.  The generated twin (twin/ops_ir.py OP_CLTV) is NOT the L
// leg: it has no transaction context and returns TWIN_INVALID_UNSUPPORTED for
// the flag-on path (see notes.md, finding F-LOCKTIME-001).
//
// Error ordinals: Lean `.negativeLocktime` / `.unsatisfiedLocktime` map to
// Core ScriptError ordinals through twin/gen.py's ERRORS table (TWIN_NEGATIVE_
// LOCKTIME core=NEGATIVE_LOCKTIME, TWIN_UNSATISFIED_LOCKTIME
// core=UNSATISFIED_LOCKTIME), which is the contract's error_kind.h value.
#include <cstdint>

#include "../../../../contract/error_kind.h"

namespace lean_slice {

// ---- Defs.lean:77-79 ----------------------------------------------------
inline constexpr int64_t LOCKTIME_THRESHOLD = 500000000;

// ---- Defs.lean:235-243: LocktimeEnv, only the fields this predicate reads
struct LocktimeEnv
{
    uint32_t txLockTime;   // := 0
    uint32_t txSequence;   // := 0xFFFFFFFF  (CTxIn::SEQUENCE_FINAL)
};

// ---- Defs.lean:272-283, checkLockTimeDef (transliterated) ---------------
//   let txlt : Int := env.txLockTime.toNat
//   if !((txlt < T ∧ n < T) ∨ (txlt ≥ T ∧ n ≥ T)) then false
//   else if n > txlt then false
//   else if env.txSequence.toNat = 0xFFFFFFFF then false
//   else true
inline bool check_lock_time_def(const LocktimeEnv& env, int64_t n)
{
    const int64_t txlt = static_cast<int64_t>(env.txLockTime);
    if (!((txlt <  LOCKTIME_THRESHOLD && n <  LOCKTIME_THRESHOLD) ||
          (txlt >= LOCKTIME_THRESHOLD && n >= LOCKTIME_THRESHOLD)))
        return false;
    else if (n > txlt)
        return false;
    else if (env.txSequence == 0xFFFFFFFFu)
        return false;
    else
        return true;
}

}  // namespace lean_slice

// ---------------------------------------------------------------------------
// Defs.lean:857-865, dispatchOp wire 0xb1:
//   if w = 0xb1 then
//     if !flags.cltv then .ok st
//     else if st.stack.length < 1 then .error .stackUnderflow
//     else match decodeNum pol (topAt st.stack 1) 5 with
//       | .error e => .error e
//       | .ok n =>
//         if n < 0 then .error .negativeLocktime
//         else if !checkLockTimeDef ctx.chk.env n then .error .unsatisfiedLocktime
//         else .ok st
// The stack-underflow and decodeNum branches are outside the cell domain (one
// already-decoded operand), exactly as on the C leg.
extern "C" int32_t cell_cltv(int64_t n, bool cltv_flag,
                             uint32_t tx_locktime, uint32_t tx_sequence)
{
    using namespace lean_slice;

    if (!cltv_flag)                                   // if !flags.cltv then .ok st
        return EQUIV_ERR_OK;

    if (n < 0)                                        // .error .negativeLocktime
        return EQUIV_ERR_NEGATIVE_LOCKTIME;

    const LocktimeEnv env{tx_locktime, tx_sequence};
    if (!check_lock_time_def(env, n))                  // .error .unsatisfiedLocktime
        return EQUIV_ERR_UNSATISFIED_LOCKTIME;

    return EQUIV_ERR_OK;                               // .ok st
}
