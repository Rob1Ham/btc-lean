#ifndef EQUIV_WAVE64_DFLT_CORE_H
#define EQUIV_WAVE64_DFLT_CORE_H
#include <cstdint>
#include <cstddef>
#include "dflt_common.h"
#include "error_kind.h"

// C-leg excerpt: Bitcoin Core's CScriptNum and the stack primitives the
// numeric/operand decode sites use.
//
// Source of record: bitcoin/bitcoin @ cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
//   src/script/script.h:227-394          CScriptNum
//   src/script/interpreter.cpp:109-124    stacktop() / popstack()
//
// The excerpt is a transcription, not an inclusion of the real headers: the
// real CScriptNum owns a std::vector and throws scriptnum_error, which the
// bounded leaf cannot model (an `invoke` makes the throw path inexpressible
// for Alive2).  Every branch below is line-cited at its site and each
// deviation is listed in the cell notes: (1) the vector is a bounded
// (value,len) pair, (2) the throw becomes a recorded error (m_err) that the
// call site turns into EvalScript's catch result, SCRIPT_ERR_SCRIPTNUM
// (interpreter.cpp:432-437, 1236-1238), (3) the decode loop is unrolled to the
// 8-byte element.
//
// The constructor signature is copied verbatim, including the default
// argument `nMaxNumSize = nDefaultMaxNumSize` (script.h:244-247).  That
// default is the statement SCR-080 asserts: every numeric-op decode site
// below calls the constructor with two arguments, so the cap is
// nDefaultMaxNumSize = 4.
namespace core {

struct Stack {
  uint32_t n;
  uint32_t len[DFLT_MAX_DEPTH];
  uint8_t e[DFLT_MAX_DEPTH][DFLT_MAX_ELEM];
};

// script.h:376-391 set_vch, with `vch.back()` replaced by a constant-index
// select over the bounded element (num_byte).
static inline __attribute__((always_inline)) int64_t set_vch(const uint8_t* vch,
                                                             uint32_t len) {
  if (len == 0) return 0;                        // script.h:378-379
  int64_t result = 0;
  if (len >= 1) result |= static_cast<int64_t>(vch[0]);          // :382-383
  if (len >= 2) result |= static_cast<int64_t>(vch[1]) << 8;
  if (len >= 3) result |= static_cast<int64_t>(vch[2]) << 16;
  if (len >= 4) result |= static_cast<int64_t>(vch[3]) << 24;
  if (len >= 5) result |= static_cast<int64_t>(vch[4]) << 32;
  if (len >= 6) result |= static_cast<int64_t>(vch[5]) << 40;
  if (len >= 7) result |= static_cast<int64_t>(vch[6]) << 48;
  if (len >= 8) result |= static_cast<int64_t>(vch[7]) << 56;
  const uint32_t top = num_byte(vch, len - 1);
  if ((top & 0x80u) != 0) {                      // script.h:386-388
    // ~(0x80ULL << (8*(len-1))) as a constant select chain: a symbolic shift
    // amount is not part of the semantics.
    const uint64_t mask = (len == 1) ? 0xffffffffffffff7fULL
                        : (len == 2) ? 0xffffffffffff7fffULL
                        : (len == 3) ? 0xffffffffff7fffffULL
                        : (len == 4) ? 0xffffffff7fffffffULL
                        : (len == 5) ? 0xffffff7fffffffffULL
                        : (len == 6) ? 0xffff7fffffffffffULL
                        : (len == 7) ? 0xff7fffffffffffffULL
                                     : 0x7fffffffffffffffULL;
    return -static_cast<int64_t>(static_cast<uint64_t>(result) & mask);
  }
  return result;
}

// script.h:229-271.  `m_err != 0` stands in for the throw; its value is
// SCRIPT_ERR_SCRIPTNUM (4), the error EvalScript's catch sets.  No caller in
// this cell inspects the value of a rejected operand.
class CScriptNum {
public:
    static constexpr size_t nDefaultMaxNumSize{4};   // script.h:242

    __attribute__((always_inline))
    explicit CScriptNum(const uint8_t* vch, uint32_t len, bool fRequireMinimal,
                        const size_t nMaxNumSize = nDefaultMaxNumSize)
        : m_value(0), m_err(0)
    {
        if (len > nMaxNumSize) {                     // script.h:247-249
            m_err = EQUIV_ERR_SCRIPTNUM;
            return;
        }
        if (fRequireMinimal && len > 0) {            // script.h:250-268
            const uint32_t top = num_byte(vch, len - 1);
            if ((top & 0x7fu) == 0) {
                const uint32_t second = num_byte(vch, len - 2);
                if (len <= 1 || (second & 0x80u) == 0) {
                    m_err = EQUIV_ERR_SCRIPTNUM;
                    return;
                }
            }
        }
        m_value = set_vch(vch, len);                 // script.h:270
    }

    __attribute__((always_inline)) int64_t getint() const { return m_value; }
    __attribute__((always_inline)) bool ok() const { return m_err == 0; }
    __attribute__((always_inline)) uint32_t error() const { return m_err; }

private:
    int64_t m_value;
    uint32_t m_err;
};

// interpreter.cpp:109-124 stacktop()/popstack().
static inline __attribute__((always_inline)) const uint8_t* stacktop(
    const Stack& s, uint32_t k, uint32_t& len) {
  const uint32_t i = s.n - k;                    // stacktop(-k)
  len = s.len[i];
  return s.e[i];
}

// Harness-only constructor for a non-script-number element (a stack filler
// such as a dummy pubkey).  Not an engine primitive.
static inline __attribute__((always_inline)) void fill_elem(Stack& s,
                                                            uint32_t idx,
                                                            uint8_t b) {
  s.len[idx] = 1;
  s.e[idx][0] = b;
}

}  // namespace core
#endif  // EQUIV_WAVE64_DFLT_CORE_H
