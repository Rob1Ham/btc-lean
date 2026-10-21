#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core @ pin cce32b168.
//
// bool CheckMinimalPush(const std::vector<unsigned char>& data, opcodetype opcode) {  // script.cpp:373
//     assert(0 <= opcode && opcode <= OP_PUSHDATA4);
//     if (data.size() == 0) return opcode == OP_0;                                     // :375-377
//     else if (data.size() == 1 && data[0] >= 1 && data[0] <= 16) return false;         // :378-380
//     else if (data.size() == 1 && data[0] == 0x81) return false;                       // :381-383
//     else if (data.size() <= 75) return opcode == data.size();                         // :384-386
//     else if (data.size() <= 255) return opcode == OP_PUSHDATA1;                       // :387-389
//     else if (data.size() <= 65535) return opcode == OP_PUSHDATA2;                     // :390-392
//     return true;                                                                      // :393
// }
//
// EvalScript:                                                                          // interpreter.cpp:442
//   bool fRequireMinimal = (flags & SCRIPT_VERIFY_MINIMALDATA) != 0;
//   ...
//   if (fExec && 0 <= opcode && opcode <= OP_PUSHDATA4) {                               // :487-488
//       if (fRequireMinimal && !CheckMinimalPush(vchPushValue, opcode)) {               // :489
//           return set_error(serror, SCRIPT_ERR_MINIMALDATA);                           // :490
//       }
//       stack.push_back(vchPushValue);
//   }

uint64_t c_minimaldata_push(uint64_t flags, uint64_t fExec, uint64_t opcode,
                            uint64_t dataLen, uint64_t b0Arg) {
    const uint64_t b0 = byte_of(b0Arg);

    if (fExec != 0 && opcode <= OP_PUSHDATA4) {
        bool ok;
        if (dataLen == 0) {
            ok = (opcode == OP_0);
        } else if (dataLen == 1 && b0 >= 1 && b0 <= 16) {
            ok = false;
        } else if (dataLen == 1 && b0 == 0x81) {
            ok = false;
        } else if (dataLen <= 75) {
            ok = (opcode == dataLen);
        } else if (dataLen <= 0xff) {
            ok = (opcode == OP_PUSHDATA1);
        } else if (dataLen <= 0xffff) {
            ok = (opcode == OP_PUSHDATA2);
        } else {
            ok = true;
        }
        if ((flags & MINIMALDATA) != 0 && !ok) return ERR_MINIMALDATA;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_minimaldata_push(uint64_t flags, uint64_t fExec, uint64_t opcode,
                                          uint64_t dataLen, uint64_t b0Arg) {
    return c_minimaldata_push(flags, fExec, opcode, dataLen, b0Arg);
}
