#include "common.h"

// C leg — line-cited source-excerpt slice at Core pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// SCR-009 cites `assert((flags & SCRIPT_VERIFY_P2SH) != 0);` and
// `assert((flags & SCRIPT_VERIFY_WITNESS) != 0);` inside the CLEANSTACK arm
// (interpreter.cpp:2113-2114).  SCR-014 cites
// `assert((flags & SCRIPT_VERIFY_P2SH) != 0);` inside the WITNESS arm
// (interpreter.cpp:2124).  An assert is not a verdict, and a debug-build
// abort is outside the transfer contract.  contract/tape.md §5 fixes the
// totalization instead:
//
//   "Core's `VerifyScript` also asserts two implications; to keep the ABI
//    total instead of aborting a debug build, violations are 2:
//      WITNESS ⇒ P2SH
//      CLEANSTACK ⇒ P2SH and WITNESS"
//
// The C shim implements exactly that guard before it calls VerifyScript
// (shims/core/entry.cpp:93-102).  This leg is that guard, cited line by line.
//
// `c_flags_guard`    : 1 iff the ABI accepts the mask (i.e. VerifyScript is
//                      called at all), else 0.
// `c_flags_assertsafe`: 1 iff both assert predicates hold for the mask.
// `c_flags_implication`: 1 iff "accepted ⇒ assert-safe".  The postcondition
//                      proved by SAW is the constant 1 for every 64-bit mask.

EVINLINE uint64_t c_flags_guard(uint64_t flags) {
    // shims/core/entry.cpp:93-98 — only the 21 defined bits may be set.
    if ((flags & ~(uint64_t)MAX_SCRIPT_VERIFY_FLAGS) != 0) return 0;
    // shims/core/entry.cpp:101 / interpreter.cpp:2124 (WITNESS arm assert).
    if ((flags & SCRIPT_VERIFY_WITNESS) != 0 &&
        (flags & SCRIPT_VERIFY_P2SH) == 0) return 0;
    // shims/core/entry.cpp:102 / interpreter.cpp:2113-2114 (CLEANSTACK arm
    // asserts both P2SH and WITNESS).
    if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0 &&
        ((flags & SCRIPT_VERIFY_P2SH) == 0 ||
         (flags & SCRIPT_VERIFY_WITNESS) == 0)) return 0;
    return 1;
}

EVINLINE uint64_t c_flags_assertsafe(uint64_t flags) {
    // interpreter.cpp:2124: WITNESS ⇒ P2SH.
    if ((flags & SCRIPT_VERIFY_WITNESS) != 0 &&
        (flags & SCRIPT_VERIFY_P2SH) == 0) return 0;
    // interpreter.cpp:2113-2114: CLEANSTACK ⇒ P2SH ∧ WITNESS.
    if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0 &&
        ((flags & SCRIPT_VERIFY_P2SH) == 0 ||
         (flags & SCRIPT_VERIFY_WITNESS) == 0)) return 0;
    return 1;
}

EVINLINE uint64_t c_flags_implication(uint64_t flags) {
    const uint64_t accepted = c_flags_guard(flags);
    const uint64_t safe = c_flags_assertsafe(flags);
    // Out-of-domain masks are rejected before VerifyScript, so the asserts
    // are unreachable there; in-domain masks must satisfy both predicates.
    return (accepted == 0) | safe;
}

extern "C" uint64_t cell_flags_guard(uint64_t flags) {
    return c_flags_guard(flags) & 1u;
}

extern "C" uint64_t cell_flags_assertsafe(uint64_t flags) {
    return c_flags_assertsafe(flags) & 1u;
}

extern "C" uint64_t cell_flags_implication(uint64_t flags) {
    return c_flags_implication(flags) & 1u;
}
