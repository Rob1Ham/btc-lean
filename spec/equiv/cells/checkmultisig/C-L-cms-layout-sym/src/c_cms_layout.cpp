// C leg -- SCR-114 CHECKMULTISIG stack layout, limits and depth checks.
//
// Line-cited slice of Bitcoin Core v32.99 interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, OP_CHECKMULTISIG/
// OP_CHECKMULTISIGVERIFY front matter:
//   1115-1116  the tapscript ban (separate cell: C-L-cms-tapscript-ban)
//   1118-1124  i = 1; stack.size() < i -> INVALID_STACK_OPERATION
//   1126-1127  nKeysCount = CScriptNum(stacktop(-1), fRequireMinimal).getint()
//   1127-1128  nKeysCount < 0 || nKeysCount > MAX_PUBKEYS_PER_MULTISIG(20)
//              -> PUBKEY_COUNT
//   1129-1131  nOpCount += nKeysCount; nOpCount > MAX_OPS_PER_SCRIPT(201)
//              -> OP_COUNT
//   1132-1135  ikey = ++i; ikey2 = nKeysCount + 2
//   1136-1138  i += nKeysCount; stack.size() < i -> INVALID_STACK_OPERATION
//   1140-1142  nSigsCount = CScriptNum(stacktop(-i), fRequireMinimal).getint();
//              nSigsCount < 0 || nSigsCount > nKeysCount -> SIG_COUNT
//   1143-1146  isig = ++i; i += nSigsCount; stack.size() < i ->
//              INVALID_STACK_OPERATION
//
// Domain: the two count elements are already-decoded 4-byte CScriptNum values
// (decodeNum itself is out of scope here; with max 4 bytes and MINIMALDATA off
// the decode is the identity on int32).  stackSize and opCount are the engine's
// current stack size and opCount.  Sigversion is base or witness-v0; the
// tapscript ban is a separate cell, so this slice omits line 1116 by domain.
//
// The cell's job is the *decision function*: which of the five outcomes, in
// which precedence order, with which derived layout numbers.  It deliberately
// does not run cmsLoop (that is SCR-116's cell).
#include <cstdint>
#include "cms_obs.h"

// status codes of the layout decision (cell-local; not contract ordinals)
enum {
  LAY_OK = 0,
  LAY_PUBKEY_COUNT = 1,
  LAY_OP_COUNT = 2,
  LAY_UNDERFLOW = 3,
  LAY_SIG_COUNT = 4
};

extern "C" uint64_t cell_cms_layout(int32_t nKeysIn, int32_t nSigsIn,
                                    uint32_t stackSize, uint32_t opCount) {
  int64_t i = 1;
  if ((int64_t)stackSize < i) {                       // 1122-1124
    return cms_pack_layout(LAY_UNDERFLOW, 0, 0, 0, 0);
  }
  const int32_t nKeysCount = nKeysIn;
  if (nKeysCount < 0 || nKeysCount > 20) {             // 1127-1128
    return cms_pack_layout(LAY_PUBKEY_COUNT, 0, 0, 0, 0);
  }
  const int64_t nOpCount = (int64_t)opCount + (int64_t)nKeysCount;  // 1129
  if (nOpCount > 201) {                                // 1130-1131
    return cms_pack_layout(LAY_OP_COUNT, 0, 0, 0, 0);
  }
  const int64_t ikey2 = (int64_t)nKeysCount + 2;       // 1134
  i += 1;                                              // 1132 ikey = ++i
  i += nKeysCount;                                     // 1136
  if ((int64_t)stackSize < i) {                        // 1136-1138
    return cms_pack_layout(LAY_UNDERFLOW, 0, 0, 0, 0);
  }
  const int32_t nSigsCount = nSigsIn;                  // 1140
  if (nSigsCount < 0 || nSigsCount > nKeysCount) {     // 1141-1142
    return cms_pack_layout(LAY_SIG_COUNT, 0, 0, 0, 0);
  }
  i += 1;                                              // 1143 isig = ++i
  const int64_t isig = i;
  i += nSigsCount;                                     // 1144
  if ((int64_t)stackSize < i) {                        // 1145-1146
    return cms_pack_layout(LAY_UNDERFLOW, 0, 0, 0, 0);
  }
  return cms_pack_layout(LAY_OK, (uint32_t)nKeysCount, (uint32_t)nSigsCount,
                         (uint32_t)ikey2, (uint32_t)isig);
}
