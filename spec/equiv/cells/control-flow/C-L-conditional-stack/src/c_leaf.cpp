#include "cell.h"
// C leg: source-excerpt slice of Bitcoin Core cce32b168
// src/script/interpreter.cpp:493 (the [OP_IF..OP_ENDIF] dispatch gate),
// :647-653 (case OP_ELSE), :655-661 (case OP_ENDIF), and :1245-1246 (the
// loop-exit unbalanced-conditional check).
//
//   } else if (fExec || (OP_IF <= opcode && opcode <= OP_ENDIF))
//   switch (opcode) {
//     ...
//     case OP_ELSE:
//     {
//         if (vfExec.empty())
//             return set_error(serror, SCRIPT_ERR_UNBALANCED_CONDITIONAL);
//         vfExec.toggle_top();
//     }
//     break;
//
//     case OP_ENDIF:
//     {
//         if (vfExec.empty())
//             return set_error(serror, SCRIPT_ERR_UNBALANCED_CONDITIONAL);
//         vfExec.pop_back();
//     }
//     break;
//   ...
//   if (!vfExec.empty())
//       return set_error(serror, SCRIPT_ERR_UNBALANCED_CONDITIONAL);
//
// The cell models one dispatch followed by loop exit.  `op` selects the
// opcode class: 0 = OP_ELSE (0x67), 1 = OP_ENDIF (0x68), anything else =
// OP_NOP (0x61, a non-conditional opcode used to observe the gate).  The
// condition-stack depth is bounded at 2; n > 2 is outside the cell domain.

BINLINE uint32_t core_wire(uint32_t op) {
  if (op == 0) return 0x67;   // OP_ELSE
  if (op == 1) return 0x68;   // OP_ENDIF
  return 0x61;                // OP_NOP
}

BINLINE uint32_t core_step(uint32_t op, uint32_t fexec, uint32_t n,
                           uint32_t v0, uint32_t v1, CSt& out) {
  out = CSt{n, v0, v1, 0};
  const uint32_t w = core_wire(op);
  const bool fExec = fexec != 0;
  uint32_t err = 0;
  // interpreter.cpp:493
  if (fExec || (0x63u <= w && w <= 0x68u)) {
    switch (w) {
      case 0x67:  // OP_ELSE, interpreter.cpp:647-653
        if (n == 0)
          err = 20;  // SCRIPT_ERR_UNBALANCED_CONDITIONAL
        else
          out.v0 = (v0 == 0) ? 1u : 0u;  // vfExec.toggle_top()
        break;
      case 0x68:  // OP_ENDIF, interpreter.cpp:655-661
        if (n == 0)
          err = 20;  // SCRIPT_ERR_UNBALANCED_CONDITIONAL
        else {
          out.n = n - 1;  // vfExec.pop_back()
          out.v0 = v1;
          out.v1 = 0;
        }
        break;
      default:  // OP_NOP: proves the switch body ran, changes nothing
        out.executed = 1;
        break;
    }
  }
  // interpreter.cpp:1245-1246
  if (err == 0 && out.n != 0)
    err = 20;  // SCRIPT_ERR_UNBALANCED_CONDITIONAL
  return err;
}

extern "C" uint64_t cell_cond(uint32_t op, uint32_t fexec, uint32_t n,
                               uint32_t v0, uint32_t v1) {
  CSt st{n, v0, v1, 0};
  const uint32_t e = core_step(op, fexec, n, v0, v1, st);
  return cond_pack(e, st);
}
