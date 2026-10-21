#include "num_common.h"
#include "num_core.h"

// C leg: source-excerpt slice of Bitcoin Core
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/script/script.h:246-271      CScriptNum(vch, fRequireMinimal, 4)
//   src/script/script.h:376-391      set_vch sign-magnitude decode
//   src/script/interpreter.cpp:432-437  catch (scriptnum_error) ->
//                                        SCRIPT_ERR_SCRIPTNUM
//   src/script/interpreter.cpp:1120  case OP_1ADD (unary numeric site)
//   src/script/interpreter.cpp:1877-1878  VerifyScript tail (EVAL_FALSE)
//
// num_core.h is the bounded transcription: decode_num returns false with
// EQUIV_ERR_SCRIPTNUM (Core ordinal 4) exactly where Core's constructor
// clears the result and the caller raises scriptnum_error.  flags = 0, so
// fRequireMinimal is false; nMaxNumSize keeps its default of 4
// (script.h:242,244).  The width guard is script.h:247-249 and precedes the
// minimality guard, so the reject decision depends on the length alone.
//
// Two entry points over the same bounded element:
//   cell_scriptnum -- the constructor in isolation: decode (word,len), then
//                     push bn.getvch() and run the VerifyScript tail.
//   cell_1add      -- OP_1ADD: the constructor on stacktop(-1), then bn+1.
// Both observe the SCRIPTNUM ordinal on len > 4.
using namespace core;

namespace {

// interpreter.cpp:1877-1878 (VerifyScript after EvalScript returned true).
BINLINE uint64_t c_tail(Stack& s) {
  if (s.n == 0) return num_obs(0, EQUIV_ERR_EVAL_FALSE, s);
  uint32_t len = 0;
  const uint8_t* top = stacktop(s, 1, len);
  if (!cast_to_bool(top, len)) return num_obs(0, EQUIV_ERR_EVAL_FALSE, s);
  return num_obs(1, EQUIV_ERR_OK, s);
}

// CScriptNum(vch, fRequireMinimal=false, nMaxNumSize=4), then
// stack.push_back(bn.getvch()) (script.h:337-340, interpreter.cpp:955-1010
// push bn.getvch(); here the caller has popped the operand).
BINLINE uint64_t c_num(uint64_t word, uint32_t len) {
  uint8_t d[NUM_MAX_ELEM];
  num_load8(d, word);
  const uint32_t L = num_len8(len);          // harness domain: length 0..8
  int64_t bn = 0;
  uint32_t err = 0;
  if (!decode_num(d, L, /*fRequireMinimal=*/false, 4, bn, err))
    return num_obs_err(err);                 // EQUIV_ERR_SCRIPTNUM = 4
  Stack s{};
  const uint32_t e = push_num(s, bn);
  if (e != 0) return num_obs_err(e);
  return c_tail(s);
}

// interpreter.cpp:1120-1122, case OP_1ADD:
//   CScriptNum bn(stacktop(-1), fRequireMinimal);
//   bn += 1;
//   popstack(stack);
//   stack.push_back(bn.getvch());
BINLINE uint64_t c_1add(uint64_t word, uint32_t len) {
  uint8_t d[NUM_MAX_ELEM];
  num_load8(d, word);
  Stack s{};
  const uint32_t e0 = push(s, d, num_len8(len));
  if (e0 != 0) return num_obs_err(e0);
  if (s.n < 1) return num_obs_err(EQUIV_ERR_INVALID_STACK_OPERATION);
  uint32_t l = 0;
  const uint8_t* p = stacktop(s, 1, l);
  int64_t bn = 0;
  uint32_t err = 0;
  if (!decode_num(p, l, /*fRequireMinimal=*/false, 4, bn, err))
    return num_obs_err(err);                 // EQUIV_ERR_SCRIPTNUM = 4
  s.n -= 1;                                  // popstack(stack)
  const uint32_t e = push_num(s, bn + 1);
  if (e != 0) return num_obs_err(e);
  return c_tail(s);
}

}  // namespace

extern "C" uint64_t cell_scriptnum(uint64_t word, uint32_t len)
  { return c_num(word, len); }

extern "C" uint64_t cell_1add(uint64_t word, uint32_t len)
  { return c_1add(word, len); }
