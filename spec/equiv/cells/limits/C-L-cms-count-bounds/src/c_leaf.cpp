#include "limits_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   interpreter.cpp:1120-1135  case OP_CHECKMULTISIG / OP_CHECKMULTISIGVERIFY
//       int nKeysCount = CScriptNum(stacktop(-i), fRequireMinimal).getint();
//       if (nKeysCount < 0 || nKeysCount > MAX_PUBKEYS_PER_MULTISIG)
//           return set_error(serror, SCRIPT_ERR_PUBKEY_COUNT);
//       nOpCount += nKeysCount;
//       if (nOpCount > MAX_OPS_PER_SCRIPT)
//           return set_error(serror, SCRIPT_ERR_OP_COUNT);
//       ...
//       int nSigsCount = CScriptNum(stacktop(-i), fRequireMinimal).getint();
//       if (nSigsCount < 0 || nSigsCount > nKeysCount)
//           return set_error(serror, SCRIPT_ERR_SIG_COUNT);
//
//   script.h:30-35   MAX_OPS_PER_SCRIPT = 201, MAX_PUBKEYS_PER_MULTISIG = 20
//   script.h:246-271 CScriptNum(vch, fRequireMinimal, 4).getint()
//
// The slice is entered with the already-decoded `int` results of getint()
// (Core's local variables are `int`; see interpreter.cpp:1127/1141).  The
// CScriptNum decode itself (width/minimality) is a numeric-family row and is
// NOT re-proved here.  The stack-size underflow checks between the limits are
// also outside these three rows; the cell's precondition supplies a stack
// that holds the CMS operand layout.
//
// Observable: result | error<<2 | nOpCount_after<<8, where nOpCount_after is
// the value of Core's local `nOpCount` after the excerpt's increment.  On the
// PUBKEY_COUNT path the increment has not run yet, so the pre-value is
// reported.  On SIG_COUNT/success it is the incremented value.
//
// Error ordinals (contract/error_kind.h):
//   7  OP_COUNT
//   9  SIG_COUNT
//   10 PUBKEY_COUNT

constexpr int MAX_OPS_PER_SCRIPT = 201;
constexpr int MAX_PUBKEYS_PER_MULTISIG = 20;

LIMITS_INLINE uint64_t c_cms_count_bounds(int32_t nKeysCount, int32_t nSigsCount, int32_t nOpCountIn) {
    int nOpCount = nOpCountIn;
    if (nKeysCount < 0 || nKeysCount > MAX_PUBKEYS_PER_MULTISIG)   // :1127-1128
        return lim_pack32(0, 10, (uint32_t)nOpCount);
    nOpCount += nKeysCount;                                       // :1129
    if (nOpCount > MAX_OPS_PER_SCRIPT)                            // :1130-1131
        return lim_pack32(0, 7, (uint32_t)nOpCount);
    if (nSigsCount < 0 || nSigsCount > nKeysCount)                // :1141-1142
        return lim_pack32(0, 9, (uint32_t)nOpCount);
    return lim_pack32(1, 0, (uint32_t)nOpCount);
}

extern "C" uint64_t cell_cms_count_bounds(int32_t nKeysCount, int32_t nSigsCount, int32_t nOpCountIn) {
    return c_cms_count_bounds(nKeysCount, nSigsCount, nOpCountIn);
}
