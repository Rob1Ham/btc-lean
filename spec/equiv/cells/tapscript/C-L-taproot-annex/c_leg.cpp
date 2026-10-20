#include "cell_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Excerpt -- annex detection and removal, interpreter.cpp:1961-1969:
//
//   if (stack.size() >= 2 && !stack.back().empty() && stack.back()[0] == ANNEX_TAG) {
//       // Drop annex (this is non-standard; see IsWitnessStandard)
//       const valtype& annex = SpanPopBack(stack);
//       execdata.m_annex_hash = (HashWriter{} << annex).GetSHA256();
//       execdata.m_annex_present = true;
//   } else {
//       execdata.m_annex_present = false;
//   }
//   execdata.m_annex_init = true;
//
// ANNEX_TAG is script.h:59 (`inline constexpr unsigned int ANNEX_TAG = 0x50;`).
// The annex *hash* is a sighash input and is not part of this row; this cell
// proves only the detection predicate and the resulting stack size.
//
// `stack.back()[0]` is an unsigned char.  The harness input `last_first` is
// that byte's value and `& 0xff` only totalises the 64-bit argument.
TAP_INLINE uint64_t c_annex_detected(uint64_t witness_n, uint64_t last_len,
                                     uint64_t last_first) {
  const uint64_t first = last_first & 0xffu;
  return (witness_n >= 2u && last_len != 0u && first == TAP_ANNEX_TAG) ? 1u
                                                                      : 0u;
}

// :1965 SpanPopBack(stack) removes exactly one item when the predicate holds.
// witness_n >= 2 is part of the guard, so the subtraction cannot wrap.
TAP_INLINE uint64_t c_annex_remaining(uint64_t witness_n, uint64_t last_len,
                                      uint64_t last_first) {
  return c_annex_detected(witness_n, last_len, last_first) ? witness_n - 1u
                                                           : witness_n;
}

extern "C" uint64_t cell_annex_detected(uint64_t witness_n, uint64_t last_len,
                                        uint64_t last_first) {
  return c_annex_detected(witness_n, last_len, last_first);
}

extern "C" uint64_t cell_annex_remaining(uint64_t witness_n, uint64_t last_len,
                                         uint64_t last_first) {
  return c_annex_remaining(witness_n, last_len, last_first);
}
