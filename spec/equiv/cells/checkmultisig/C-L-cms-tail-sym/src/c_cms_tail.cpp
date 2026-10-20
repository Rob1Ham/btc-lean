// C leg -- SCR-118 / SCR-119 / SCR-120, the CHECKMULTISIG tail.
//
// Line-cited slice of Bitcoin Core v32.99 interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, starting from the state just
// after the verification loop (fSuccess is an input here -- it is what the
// loop computed, and program order does not matter to these rules):
//   1194-1205  while (i-- > 1) { NULLFAIL arm; if (ikey2 > 0) ikey2--;
//                              popstack(stack); }   -- pops i-1 items
//   1209-1210  if (stack.size() < 1) -> INVALID_STACK_OPERATION
//   1211-1212  if ((flags & SCRIPT_VERIFY_NULLDUMMY) && stacktop(-1).size())
//                  -> SIG_NULLDUMMY
//   1213       popstack(stack);            // the extra, otherwise unchecked item
//   1215       stack.push_back(fSuccess ? vchTrue : vchFalse)
//   1217-1223  if (opcode == OP_CHECKMULTISIGVERIFY) { if (fSuccess) popstack;
//                                                  else -> CHECKMULTISIGVERIFY }
//   1876-1880  (harness finish) script ends: top element false -> EVAL_FALSE
//
// Domain of this cell (see spec.md): base/witness-v0, NULLFAIL and every other
// policy flag off; SCRIPT_VERIFY_NULLDUMMY is the only modelled flag.  The
// cleanup pop count is i-1 with i = nKeys+nSigs+3, which the front matter has
// already guaranteed is <= stack.size(); the slice computes the resulting depth
// arithmetically instead of looping (same effect, no symbolic-trip-count loop).
//
// The stack is the canonical test stack: `extra` items below the CMS arguments,
// element i being (len 1, value i+2).  The dummy's *bytes* are symbolic and are
// never read: only its size enters the NULLDUMMY gate, and with the gate off
// the item is consumed without any inspection.
#include <cstdint>
#include "cms_obs.h"

#define WIRE_CHECKMULTISIG 0xaeu
#define WIRE_CHECKMULTISIGVERIFY 0xafu

extern "C" uint64_t cell_cms_tail(uint32_t nkeys, uint32_t nsigs,
                                  uint32_t extra, uint32_t fsuccess,
                                  uint32_t nulldummy, uint32_t wire,
                                  uint32_t dummyLen, uint32_t dummyBytes) {
  (void)dummyBytes;  // never inspected: the rule only reads stacktop(-1).size()

  // i after the front matter: ikey = ++i (2), i += nKeys; isig = ++i;
  // i += nSigs  ->  i = nKeys + nSigs + 3.
  uint64_t i = 1;
  i += 1;                          // ikey = ++i
  i += (uint64_t)nkeys;
  i += 1;                          // isig = ++i
  i += (uint64_t)nsigs;
  uint64_t depth = (uint64_t)extra + i;   // front matter guarantees depth >= i

  // 1194-1205: pop i-1 items, leaving the extra argument on top.
  if (i >= 1u) depth -= (i - 1u);

  if (depth < 1u) {                // 1209-1210 (unreachable in domain)
    return cms_fail_tail(CMS_INVALID_STACK_OPERATION);
  }
  // 1211-1212: the only thing read about the extra item is its size.
  if (nulldummy != 0u && dummyLen != 0u) {
    return cms_fail_tail(CMS_SIG_NULLDUMMY);
  }
  depth -= 1u;                     // 1213 popstack: contents never checked

  if (wire == WIRE_CHECKMULTISIGVERIFY) {
    if (fsuccess == 0u) {          // 1222
      return cms_fail_tail(CMS_CHECKMULTISIGVERIFY);
    }
    // 1219-1220: the pushed true is popped again, so the net depth is `extra`.
    return cms_pack_tail(1u, CMS_OK, (uint32_t)depth, 2u);
  }

  // 1215-1216: push vchTrue / vchFalse, then the script's EVAL_FALSE tail.
  if (fsuccess != 0u) return cms_pack_tail(1u, CMS_OK, (uint32_t)depth, 1u);
  return cms_pack_tail(0u, CMS_EVAL_FALSE, (uint32_t)depth, 0u);
}
