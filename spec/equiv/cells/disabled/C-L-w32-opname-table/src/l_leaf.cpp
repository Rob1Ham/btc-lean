// L leg: the Lean twin's opcode-name table.
//
// Source: spec/proofs/BitcoinProofs/AF/PDW68/PDW68.lean:253-405
// (`opNameWire`), transcribed case-for-case into src/lean_names.txt.  The
// default arm is "OP_UNKNOWN".  Ids are assigned by src/gen_opname.py from
// the union of the Core and Lean name sets, so a spelling divergence between
// the two transcriptions is a different id, not a shared constant.
#include <cstdint>
#include "opname_lean.inc"

extern "C" uint64_t cell_opname(uint8_t w) {
  return static_cast<uint64_t>(lean_opname_id(w));
}
