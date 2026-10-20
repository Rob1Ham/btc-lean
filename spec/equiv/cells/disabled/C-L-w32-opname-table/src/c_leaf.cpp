// C leg: Bitcoin Core cce32b168 src/script/script.cpp:19-157 GetOpName.
//
// The cell returns the name id assigned by src/gen_opname.py from
// src/core_names.txt, a case-for-case transcription of the switch.  The
// literal strings are in that data file; 0 is GetOpName's fall-through
// "OP_UNKNOWN" (there is no `default:` case in the pinned source; control
// falls out of the switch to `return "OP_UNKNOWN";`).
//
// Notable edges preserved: direct-push bytes 0x01..0x4b have no case and are
// OP_UNKNOWN; 0xbb..0xfe have no case and are OP_UNKNOWN; 0xff is the named
// OP_INVALIDOPCODE.  0x00 and the PUSHDATA/OP_N bytes are named.
#include <cstdint>
#include "opname_core.inc"

extern "C" uint64_t cell_opname(uint8_t w) {
  return static_cast<uint64_t>(core_opname_id(w));
}
