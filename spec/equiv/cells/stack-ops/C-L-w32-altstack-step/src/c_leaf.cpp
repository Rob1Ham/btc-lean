#include <cstdint>
#include "w32_common.h"

// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/interpreter.cpp:521-523 (opcode budget, counted before the
//       disabled/executed checks and before the switch):
//       if (opcode > OP_16 && ++nOpCount > MAX_OPS_PER_SCRIPT)
//           return set_error(serror, SCRIPT_ERR_OP_COUNT);
//
//   src/script/interpreter.cpp:526-529 (fExec gate):
//       if (fExec || (OP_IF <= opcode && opcode <= OP_ENDIF))
//       switch (opcode) { ... }
//
//   src/script/interpreter.cpp:687-695  case OP_TOALTSTACK:
//       if (stack.size() < 1) return ...INVALID_STACK_OPERATION;
//       altstack.push_back(stacktop(-1));
//       popstack(stack);
//
//   src/script/interpreter.cpp:696-703  case OP_FROMALTSTACK:
//       if (altstack.size() < 1) return ...INVALID_ALTSTACK_OPERATION;
//       stack.push_back(altstacktop(-1));
//       popstack(altstack);
//
// The cell is a single EvalScript step: the loop's decode, opcodeIndex and
// the trailing stack-size guard are omitted.  The domain is sn, an <= 4, so
// the combined depth after any step is <= 5; the trailing
// stack.size()+altstack.size() > MAX_STACK_SIZE guard is unreachable here
// and is not part of the observable.
//
// Buffer layout (both legs): stack element i is 0x40+i except the top, which
// is s_top; altstack element i is 0x60+i except the top, which is a_top.
// Every element is one byte.

static void w32_init(W32Stack& s, uint32_t n, uint8_t top, uint8_t base) {
  s.n = n;
  if (n > 0) s.v[0] = static_cast<uint8_t>(base + 0);
  if (n > 1) s.v[1] = static_cast<uint8_t>(base + 1);
  if (n > 2) s.v[2] = static_cast<uint8_t>(base + 2);
  if (n > 3) s.v[3] = static_cast<uint8_t>(base + 3);
  if (n > 4) s.v[4] = static_cast<uint8_t>(base + 4);
  if (n > 0) s.v[n - 1] = top;
}

extern "C" uint64_t cell_altstep(uint8_t wire, uint8_t exec, uint32_t opc,
                                 uint8_t sn, uint8_t an, uint8_t s_top,
                                 uint8_t a_top) {
  if ((wire != 0x6b && wire != 0x6c) || sn > 4 || an > 4) {
    return W32_OUT_OF_DOMAIN;
  }
  W32Stack s{};
  W32Stack a{};
  w32_init(s, sn, s_top, 0x40);
  w32_init(a, an, a_top, 0x60);

  uint32_t nOpCount = opc;
  if (wire > 0x60) {
    nOpCount += 1;
    if (nOpCount > 201) {
      return w32_pack_alt(0, 7 /* EQUIV_ERR_OP_COUNT */, s, a);
    }
  }
  if (exec) {
    if (wire == 0x6b) {
      if (s.n < 1) {
        return w32_pack_alt(0, 18 /* INVALID_STACK_OPERATION */, s, a);
      }
      a.v[a.n] = s.v[s.n - 1];
      a.n += 1;
      s.n -= 1;
    } else {
      if (a.n < 1) {
        return w32_pack_alt(0, 19 /* INVALID_ALTSTACK_OPERATION */, s, a);
      }
      s.v[s.n] = a.v[a.n - 1];
      s.n += 1;
      a.n -= 1;
    }
  }
  return w32_pack_alt(1, 0 /* EQUIV_ERR_OK */, s, a);
}
