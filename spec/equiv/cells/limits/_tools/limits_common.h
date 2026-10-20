#ifndef SPEC_EQUIV_CELLS_LIMITS_COMMON_H
#define SPEC_EQUIV_CELLS_LIMITS_COMMON_H
// Cell harness for the `limits` family: packed observable, sigversion codes,
// and the exact Core constants the limit rows are written against.
//
// This header is NOT engine code and is not part of the trust base.  The C
// leg of each cell is a line-cited source-excerpt slice of Bitcoin Core
// cce32b168; the L leg is a reviewed transliteration of the Lean twin
// (spec/core/Bitcoin/Interpreter/Defs.lean) and, where the generated twin has
// the same structural code, of spec/equiv/twin/runtime.inc.  The packing
// below is shared harness so the two legs have one observable.

#include <cstdint>

#include "error_kind.h"

// script.h:29,32,41,44 at cce32b168.
#define LIM_MAX_SCRIPT_ELEMENT_SIZE 520u
#define LIM_MAX_OPS_PER_SCRIPT      201
#define LIM_MAX_SCRIPT_SIZE         10000u
#define LIM_MAX_STACK_SIZE          1000u

// SigVersion discriminants, as used by the cells.  Core's enum order at the
// pin is BASE=0, WITNESS_V0=1, TAPROOT=2, TAPSCRIPT=3; TAPROOT admits no
// script execution (interpreter.cpp:427-428 asserts it away), so the cells
// use 0=BASE, 1=WITNESS_V0, 2=TAPSCRIPT and reject other codes as out of
// domain (result 2).
enum LimSigVersion : uint8_t {
  LIM_SV_BASE = 0,
  LIM_SV_WITNESS_V0 = 1,
  LIM_SV_TAPSCRIPT = 2,
};

#define LIM_BINLINE static inline __attribute__((always_inline))

// Packed observable (harness, identical on both legs):
//   bits 0-1   result   (0 fail, 1 pass/admit, 2 bad input, 3 internal)
//   bits 2-7   error    (Core ScriptError ordinal, contract/error_kind.h)
//   bits 8-31  payload  (cell-specific state projection; 24 bits)
LIM_BINLINE uint64_t lim_pack(uint32_t res, uint32_t err, uint32_t payload) {
  return (uint64_t)(res & 3u) | ((uint64_t)(err & 0x3fu) << 2) |
         ((uint64_t)(payload & 0x00ffffffu) << 8);
}

// Out-of-domain input is result 2 with EQUIV_ERR_UNKNOWN_ERROR, per
// contract/ABI.md §2/§5.  Each cell states its domain in spec.md; the guard
// is harness (both legs use the same one) so a proof covers the whole input
// width rather than an assumed subset.
LIM_BINLINE uint64_t lim_bad_input(void) {
  return lim_pack(2, EQUIV_ERR_UNKNOWN_ERROR, 0);
}

LIM_BINLINE bool lim_in_sigversion_scope(uint8_t sv) {
  // EvalScript's 200-op and 10k-byte guards apply to BASE and WITNESS_V0 only.
  return sv == LIM_SV_BASE || sv == LIM_SV_WITNESS_V0;
}

LIM_BINLINE bool lim_valid_sigversion(uint8_t sv) {
  return sv == LIM_SV_BASE || sv == LIM_SV_WITNESS_V0 || sv == LIM_SV_TAPSCRIPT;
}

#endif
