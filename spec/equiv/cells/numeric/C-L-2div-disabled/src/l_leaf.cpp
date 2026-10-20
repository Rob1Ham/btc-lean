#include "num_common.h"
#include "twin_ops.h"

// L leg: `disabled_wire` is copied verbatim from twin/runtime.inc by the cell
// generator (build/twin_ops.h) and is the exact predicate eval_script applies
// at runtime.inc:613-614 ("(3) disabled opcodes, unexecuted branches
// included", Defs.lean:831-833).  It is unconditional -- there is no
// sigversion test around it -- so the L gate is sigversion independent, like
// Core's check at interpreter.cpp:471-489.
//
// The gate observation tags (0 terminal error, 1 terminal success, 2 no
// terminal decision) are cell harness; they only name the three possible
// outcomes of the gate layer so both legs can be compared on one word.
using namespace twinleaf;

namespace {

BINLINE uint64_t gate_obs(uint32_t res, uint32_t err) {
  return static_cast<uint64_t>(res & 3u) | (static_cast<uint64_t>(err & 0x3fu) << 2);
}

}  // namespace

// EvalScript's gate (runtime.inc:613-614).
extern "C" uint64_t cell_gate(uint32_t wire) {
  if (disabled_wire(wire))
    return gate_obs(0, static_cast<uint32_t>(core_ord(TWIN_DISABLED_OPCODE)));
  return gate_obs(2, static_cast<uint32_t>(core_ord(TWIN_OK)));
}
