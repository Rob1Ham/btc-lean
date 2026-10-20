// C leg -- SCR-121 CHECKMULTISIG is banned in tapscript (BIP342).
//
// Line-cited slice of Bitcoin Core v32.99 interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   1113-1116  case OP_CHECKMULTISIG / OP_CHECKMULTISIGVERIFY:
//              if (sigversion == SigVersion::TAPSCRIPT)
//                  return set_error(serror, SCRIPT_ERR_TAPSCRIPT_CHECKMULTISIG);
//
// The ban is the *first* statement of both opcode arms, before the stack
// arity, the count decode, the range checks and the opCount accounting.  That
// precedence is the row's content: with the ban moved after any of those, an
// otherwise-invalid stack would report a different ordinal.
//
// The rest of the front matter is included so the cell also proves the ban is
// NOT applied to base/witness-v0 (a "reject everything" slice would otherwise
// satisfy the tapscript half).  SigVersion encoding: 0 = BASE, 1 = WITNESS_V0,
// 2 = TAPSCRIPT (Core enum order).  Inputs outside 0..2 are not reachable from
// the engine; the function is total on them and both legs treat them as
// non-tapscript.
#include <cstdint>
#include "cms_obs.h"

enum {
  BAN_OK = 0,
  BAN_PUBKEY_COUNT = 1,
  BAN_OP_COUNT = 2,
  BAN_UNDERFLOW = 3,
  BAN_SIG_COUNT = 4
};

static const uint32_t SIGVERSION_TAPSCRIPT = 2;

extern "C" uint64_t cell_cms_tapscript_ban(uint32_t sigversion, uint32_t opcode,
                                           uint32_t stackSize, int32_t nKeysIn,
                                           int32_t nSigsIn) {
  (void)opcode;  // an obsolete upcode hint in Core's comment; both arms share it
  if (sigversion == SIGVERSION_TAPSCRIPT) {           // 1116
    return cms_pack6(CMS_TAPSCRIPT_CHECKMULTISIG, 0, 0, 0, 0);
  }
  int64_t i = 1;
  if ((int64_t)stackSize < i) {
    return cms_pack6(BAN_UNDERFLOW, 0, 0, 0, 0);
  }
  if (nKeysIn < 0 || nKeysIn > 20) {
    return cms_pack6(BAN_PUBKEY_COUNT, 0, 0, 0, 0);
  }
  const int64_t ikey2 = (int64_t)nKeysIn + 2;
  i += 1;
  i += nKeysIn;
  if ((int64_t)stackSize < i) {
    return cms_pack6(BAN_UNDERFLOW, 0, 0, 0, 0);
  }
  if (nSigsIn < 0 || nSigsIn > nKeysIn) {
    return cms_pack6(BAN_SIG_COUNT, 0, 0, 0, 0);
  }
  const int64_t isig = i + 1;
  i += 1;
  i += nSigsIn;
  if ((int64_t)stackSize < i) {
    return cms_pack6(BAN_UNDERFLOW, 0, 0, 0, 0);
  }
  return cms_pack6(BAN_OK, (uint32_t)nKeysIn, (uint32_t)nSigsIn,
                   (uint32_t)ikey2, (uint32_t)isig);
}
