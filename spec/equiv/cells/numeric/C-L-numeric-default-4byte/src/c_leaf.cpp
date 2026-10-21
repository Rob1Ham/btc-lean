#include "dflt_common.h"
#include "dflt_core.h"

// C leg: source-excerpt slices of Bitcoin Core
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66 for the seven CScriptNum decode
// sites that omit the size argument -- i.e. that take the default 4-byte
// operand limit of SCR-080.
//
//   site 1  interpreter.cpp:840        OP_PICK / OP_ROLL depth
//   site 2  interpreter.cpp:939        OP_1ADD .. OP_0NOTEQUAL (6 wires)
//   site 3  interpreter.cpp:972-973    OP_ADD .. OP_MAX (13 wires)
//   site 4  interpreter.cpp:1017-1019  OP_WITHIN (3 operands)
//   site 5  interpreter.cpp:1103       OP_CHECKSIGADD (tapscript)
//   site 6  interpreter.cpp:1126       OP_CHECKMULTISIG nKeysCount
//   site 7  interpreter.cpp:1140       OP_CHECKMULTISIG nSigsCount
//
// Each slice stops at the decode boundary: the operand(s) are constructed with
// `CScriptNum(vch, fRequireMinimal)` -- two arguments, so nMaxNumSize is the
// default -- and the observable is the decoded value.  Post-decode behaviour
// (the arithmetic, the depth/range checks, the signature checks) belongs to
// the rows that own those sites (SCR-078, SCR-086, SCR-087..090, SCR-114..117)
// and is deliberately out of this cell; see spec.md.
//
// flags = 0, so fRequireMinimal = false and the minimality guard is
// statically off; it is still present in the excerpt because it is part of
// the same constructor.
using namespace core;

namespace {

// CScriptNum's throw is modelled as the constructor recording
// EQUIV_ERR_SCRIPTNUM, which is what EvalScript's catch sets for
// scriptnum_error (interpreter.cpp:432-437, 1236-1238).  The call site below
// is the two-line shape of that catch: any rejected operand ends the script.

// site 1: interpreter.cpp:838-840
//   case OP_PICK:
//   case OP_ROLL:
//     if (stack.size() < 2) return ...INVALID_STACK_OPERATION;
//     int n = CScriptNum(stacktop(-1), fRequireMinimal).getint();
BINLINE uint64_t c_pick_roll(uint32_t w, uint32_t lb) {
  Stack s{};
  s.n = 2;
  fill_elem(s, 0, 0x00);                 // harness filler x (not read)
  s.len[1] = lb & 7u;                    // operand n (top)
  num_load(s.e[1], w);

  uint32_t len = 0;
  const uint8_t* p = stacktop(s, 1, len);
  CScriptNum n(p, len, /*fRequireMinimal=*/false);
  if (!n.ok()) return dflt_obs(1, n.error(), 0);
  return dflt_obs(1, 0, n.getint());
}

// site 2: interpreter.cpp:937-939
//   case OP_1ADD: ... case OP_0NOTEQUAL:
//     if (stack.size() < 1) return ...INVALID_STACK_OPERATION;
//     CScriptNum bn(stacktop(-1), fRequireMinimal);
BINLINE uint64_t c_unary(uint32_t w, uint32_t lb) {
  Stack s{};
  s.n = 1;
  s.len[0] = lb & 7u;
  num_load(s.e[0], w);

  uint32_t len = 0;
  const uint8_t* p = stacktop(s, 1, len);
  CScriptNum bn(p, len, /*fRequireMinimal=*/false);
  if (!bn.ok()) return dflt_obs(2, bn.error(), 0);
  return dflt_obs(2, 0, bn.getint());
}

// site 3: interpreter.cpp:970-973
//     CScriptNum bn1(stacktop(-2), fRequireMinimal);
//     CScriptNum bn2(stacktop(-1), fRequireMinimal);
BINLINE uint64_t c_binary(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb) {
  Stack s{};
  s.n = 2;
  s.len[0] = la & 7u;                    // a = stacktop(-2)
  num_load(s.e[0], wa);
  s.len[1] = lb & 7u;                    // b = stacktop(-1)
  num_load(s.e[1], wb);

  uint32_t l1 = 0, l2 = 0;
  const uint8_t* p1 = stacktop(s, 2, l1);
  CScriptNum bn1(p1, l1, /*fRequireMinimal=*/false);
  if (!bn1.ok()) return dflt_obs(3, bn1.error(), 0);
  const uint8_t* p2 = stacktop(s, 1, l2);
  CScriptNum bn2(p2, l2, /*fRequireMinimal=*/false);
  if (!bn2.ok()) return dflt_obs(3, bn2.error(), 0);
  return dflt_obs(3, 0, bn2.getint());
}

// site 4: interpreter.cpp:1015-1019
//     CScriptNum bn1(stacktop(-3), fRequireMinimal);
//     CScriptNum bn2(stacktop(-2), fRequireMinimal);
//     CScriptNum bn3(stacktop(-1), fRequireMinimal);
BINLINE uint64_t c_within(uint32_t wx, uint32_t lx, uint32_t wmn, uint32_t lmn,
                          uint32_t wmx, uint32_t lmx) {
  Stack s{};
  s.n = 3;
  s.len[0] = lx & 7u;  num_load(s.e[0], wx);   // x   = stacktop(-3)
  s.len[1] = lmn & 7u; num_load(s.e[1], wmn);  // min = stacktop(-2)
  s.len[2] = lmx & 7u; num_load(s.e[2], wmx);  // max = stacktop(-1)

  uint32_t l1 = 0, l2 = 0, l3 = 0;
  const uint8_t* p1 = stacktop(s, 3, l1);
  CScriptNum bn1(p1, l1, /*fRequireMinimal=*/false);
  if (!bn1.ok()) return dflt_obs(4, bn1.error(), 0);
  const uint8_t* p2 = stacktop(s, 2, l2);
  CScriptNum bn2(p2, l2, /*fRequireMinimal=*/false);
  if (!bn2.ok()) return dflt_obs(4, bn2.error(), 0);
  const uint8_t* p3 = stacktop(s, 1, l3);
  CScriptNum bn3(p3, l3, /*fRequireMinimal=*/false);
  if (!bn3.ok()) return dflt_obs(4, bn3.error(), 0);
  return dflt_obs(4, 0, bn3.getint());
}

// site 5: interpreter.cpp:1099-1103 (OP_CHECKSIGADD, tapscript only)
//     const valtype& sig = stacktop(-3);
//     const CScriptNum num(stacktop(-2), fRequireMinimal);
//     const valtype& pubkey = stacktop(-1);
BINLINE uint64_t c_checksigadd(uint32_t w, uint32_t lb) {
  Stack s{};
  s.n = 3;
  fill_elem(s, 0, 0x00);                 // harness sig filler (not read here)
  s.len[1] = lb & 7u;                    // num = stacktop(-2)
  num_load(s.e[1], w);
  fill_elem(s, 2, 0x00);                 // harness pubkey filler (not read here)

  uint32_t len = 0;
  const uint8_t* p = stacktop(s, 2, len);
  CScriptNum num(p, len, /*fRequireMinimal=*/false);
  if (!num.ok()) return dflt_obs(5, num.error(), 0);
  return dflt_obs(5, 0, num.getint());
}

// site 6: interpreter.cpp:1124-1126
//     int i = 1;
//     if ((int)stack.size() < i) return ...INVALID_STACK_OPERATION;
//     int nKeysCount = CScriptNum(stacktop(-i), fRequireMinimal).getint();
// The slice ends at the decode: the PUBKEY_COUNT range check and nOpCount are
// SCR-114's row.
BINLINE uint64_t c_cms_nkeys(uint32_t w, uint32_t lb) {
  Stack s{};
  s.n = 1;
  s.len[0] = lb & 7u;                    // nKeysCount (top)
  num_load(s.e[0], w);

  uint32_t len = 0;
  const uint8_t* p = stacktop(s, 1, len);
  CScriptNum nKeysCount(p, len, /*fRequireMinimal=*/false);
  if (!nKeysCount.ok()) return dflt_obs(6, nKeysCount.error(), 0);
  return dflt_obs(6, 0, nKeysCount.getint());
}

// site 7: interpreter.cpp:1124-1140.  To reach the second decode the harness
// fixes nKeysCount to the one-byte encoding of 0 ({0x00}), so the range check
// and the `stack.size() < i` test pass deterministically and `stacktop(-i)`
// with i = 2 + nKeysCount names the bottom element.  The stack is
// [nSigsCount, nKeysCount].
//     int nKeysCount = CScriptNum(stacktop(-i), fRequireMinimal).getint();
//     ...
//     i += nKeysCount;
//     if ((int)stack.size() < i) return ...INVALID_STACK_OPERATION;
//     int nSigsCount = CScriptNum(stacktop(-i), fRequireMinimal).getint();
BINLINE uint64_t c_cms_nsigs(uint32_t w, uint32_t lb) {
  Stack s{};
  s.n = 2;
  s.len[0] = lb & 7u;                    // nSigsCount
  num_load(s.e[0], w);
  fill_elem(s, 1, 0x00);                 // nKeysCount = 0 ({0x00})

  uint32_t lk = 0;
  const uint8_t* pk = stacktop(s, 1, lk);
  CScriptNum nKeysCount(pk, lk, /*fRequireMinimal=*/false);
  if (!nKeysCount.ok()) return dflt_obs(7, nKeysCount.error(), 0);
  if (nKeysCount.getint() < 0 || nKeysCount.getint() > 20) {
    return dflt_obs(7, EQUIV_ERR_PUBKEY_COUNT, 0);
  }
  const uint32_t i = 2u + static_cast<uint32_t>(nKeysCount.getint());
  if (s.n < i) return dflt_obs(7, EQUIV_ERR_INVALID_STACK_OPERATION, 0);

  uint32_t ls = 0;
  const uint8_t* ps = stacktop(s, i, ls);
  CScriptNum nSigsCount(ps, ls, /*fRequireMinimal=*/false);
  if (!nSigsCount.ok()) return dflt_obs(7, nSigsCount.error(), 0);
  return dflt_obs(7, 0, nSigsCount.getint());
}

}  // namespace

extern "C" uint64_t cell_pick_roll(uint32_t w, uint32_t lb) {
  return c_pick_roll(w, lb);
}
extern "C" uint64_t cell_unary(uint32_t w, uint32_t lb) {
  return c_unary(w, lb);
}
extern "C" uint64_t cell_binary(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb) {
  return c_binary(wa, la, wb, lb);
}
extern "C" uint64_t cell_within(uint32_t wx, uint32_t lx, uint32_t wmn,
                                uint32_t lmn, uint32_t wmx, uint32_t lmx) {
  return c_within(wx, lx, wmn, lmn, wmx, lmx);
}
extern "C" uint64_t cell_checksigadd(uint32_t w, uint32_t lb) {
  return c_checksigadd(w, lb);
}
extern "C" uint64_t cell_cms_nkeys(uint32_t w, uint32_t lb) {
  return c_cms_nkeys(w, lb);
}
extern "C" uint64_t cell_cms_nsigs(uint32_t w, uint32_t lb) {
  return c_cms_nsigs(w, lb);
}
