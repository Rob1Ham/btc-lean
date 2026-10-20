#include "w32_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Slices:
//   interpreter.cpp:455-464  nOpCount declaration and the opcode-budget guard
//                            (sigversion BASE/WITNESS_V0 only, opcode > OP_16)
//   interpreter.cpp:529-530  case OP_NOP: break;  (no stack/altstack change)
//   interpreter.cpp:1870-1879  EvalScript return + cleanstack + CastToBool tail
//   script.h:32              MAX_OPS_PER_SCRIPT = 201
//   script.h:29              MAX_SCRIPT_ELEMENT_SIZE = 520 (not used here)
//
// The cell's declared domain is nOpCount <= 10000: a script is at most 10000
// bytes and nOpCount is incremented at most once per opcode (plus at most 20
// per CHECKMULTISIG key), so a larger value is unreachable.  Inputs outside the
// domain return the harness bad-input marker and are not compared.
//
// SigVersion encoding is the cell's: 0 = BASE, 1 = WITNESS_V0, 2 = TAPSCRIPT.
// The two functions are deliberately minimal:
//   * cell_opcount_guard isolates the guard itself (any wire byte).
//   * cell_nop_overbudget runs one OP_NOP through the guard plus the witness
//     post-checks for a one-item stack, so "the tapscript OP_NOP still
//     succeeds and leaves opCount untouched" is an observable, not a comment.

// script.h:32
#define W32_MAX_OPS_PER_SCRIPT 201
// interpreter.cpp:460 uses OP_16 == 0x60.
#define W32_OP_16 0x60
// OP_NOP is interpreter.cpp:529.
#define W32_OP_NOP 0x61

// Error ordinals (contract/error_kind.h):
//   2 EQUIV_ERR_EVAL_FALSE, 7 EQUIV_ERR_OP_COUNT

W32INLINE uint64_t c_opcount_guard(uint32_t sv, uint8_t wire,
                                   uint32_t opcount_in) {
    if (sv > 2 || opcount_in > 10000) return w32_bad_domain();
    uint32_t nOpCount = opcount_in;
    // interpreter.cpp:460-464
    if (sv == 0 || sv == 1) {  // SigVersion::BASE || SigVersion::WITNESS_V0
        if (wire > W32_OP_16) {
            ++nOpCount;
            if (nOpCount > W32_MAX_OPS_PER_SCRIPT) {
                return w32_pack_aux(0, 7, nOpCount);
            }
        }
    }
    return w32_pack_aux(1, 0, nOpCount);
}

W32INLINE uint64_t c_nop_overbudget(uint32_t sv, uint32_t opcount_in,
                                    uint32_t top_true) {
    if (sv > 2 || opcount_in > 10000) return w32_bad_domain();
    uint32_t nOpCount = opcount_in;
    // interpreter.cpp:460-464, with opcode == OP_NOP (0x61 > 0x60).
    if (sv == 0 || sv == 1) {
        ++nOpCount;
        if (nOpCount > W32_MAX_OPS_PER_SCRIPT) {
            return w32_pack_aux(0, 7, nOpCount);
        }
    }
    // interpreter.cpp:529-530: OP_NOP does nothing.  The stack is exactly one
    // item (cleanstack, interpreter.cpp:1877) whose CastToBool is top_true.
    if (top_true == 0) return w32_pack_aux(0, 2, nOpCount);
    return w32_pack_aux(1, 0, nOpCount);
}

extern "C" uint64_t cell_opcount_guard(uint32_t sv, uint8_t wire,
                                       uint32_t opcount_in) {
    return c_opcount_guard(sv, wire, opcount_in);
}

extern "C" uint64_t cell_nop_overbudget(uint32_t sv, uint32_t opcount_in,
                                        uint32_t top_true) {
    return c_nop_overbudget(sv, opcount_in, top_true);
}
