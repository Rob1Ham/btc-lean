#include <cstdint>

// C leg: source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/script.cpp:250-264  CScript::IsWitnessProgram(int& version,
//                                                          CScript& program)
//       if (this->size() < 4 || this->size() > 42) return false;
//       CScript::const_iterator pc = begin();
//       opcodetype opcode;
//       if (!GetOp(pc, opcode)) return false;
//       if (opcode < OP_0 || opcode > OP_16) return false;
//       if (!GetOp(pc, opcode)) return false;
//       if (opcode < OP_PUSHBYTES_2 || opcode > OP_PUSHBYTES_40) return false;
//       program = CScript(pc, end());
//       version = DecodeOP_N(opcode);
//       return true;
//
// The excerpt is specialised to the two bytes that IsWitnessProgram reads:
// the first byte is the version opcode, the second byte is the direct-push
// length.  "exact-length push" is the `plen + 2 == size` condition; it also
// forces program size 2..40 because size is in [4, 42].  version decoding
// (SWT-002) is not part of this cell's observable.
extern "C" uint64_t cell_wp(uint8_t v, uint8_t plen, uint32_t n) {
  if (n < 4 || n > 42) return 0;
  if (!(v == 0x00 || (v >= 0x51 && v <= 0x60))) return 0;
  if (static_cast<uint32_t>(plen) + 2u != n) return 0;
  return 1;
}
