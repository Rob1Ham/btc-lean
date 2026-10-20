#include "dflt_common.h"
#include "twin_ops.h"

// L leg: the twin's own script-number decoder, called at the same seven sites
// and with the same literal arguments as the generated handlers in
// spec/equiv/twin/ops_ir.py.  Every handler that decodes an operand calls
//
//   decode_num(p, l, ctx.pol.minimalData, 4, n);
//
// with the cap 4 spelled out (the twin has no default argument).  This cell
// invokes that call directly at each site and stops at the decode boundary,
// exactly like the C leg; the handler bodies after the decode (the arithmetic,
// the stack shuffle, the signature checks) belong to other rows and are not
// re-run here.  The decoder itself is the TwinErr -> Core ordinal path from
// the generated header (core_ord), not a re-implementation.
//
// Cell harness (not engine code): the init/push code below builds each site's
// entry stack with the twin's st_push; the packed observable is dflt_obs.
using namespace twinleaf;

namespace {

BINLINE void l_push(State& st, uint32_t w, uint32_t len) {
  uint8_t b[DFLT_MAX_ELEM];
  num_load(b, w);
  st_push(st.stack, b, len);
}

BINLINE void l_push_fill(State& st, uint8_t byte) {
  const uint8_t b[1] = {byte};
  st_push(st.stack, b, 1);
}

// site 1: interpreter.cpp:840 -- OP_PICK / OP_ROLL depth (stacktop(-1)).
BINLINE uint64_t l_pick_roll(uint32_t w, uint32_t lb) {
  State st{};
  l_push_fill(st, 0x00);                 // harness filler x (not read)
  l_push(st, w, lb & 7u);
  uint32_t len = 0;
  const uint8_t* p = st_top(st.stack, 1, len);
  int64_t n = 0;
  const TwinErr e = decode_num(p, len, /*minimal=*/false, 4, n);
  if (e != TWIN_OK) return dflt_obs(1, static_cast<uint32_t>(core_ord(e)), 0);
  return dflt_obs(1, 0, n);
}

// site 2: interpreter.cpp:939 -- unary numeric ops (stacktop(-1)).
BINLINE uint64_t l_unary(uint32_t w, uint32_t lb) {
  State st{};
  l_push(st, w, lb & 7u);
  uint32_t len = 0;
  const uint8_t* p = st_top(st.stack, 1, len);
  int64_t n = 0;
  const TwinErr e = decode_num(p, len, /*minimal=*/false, 4, n);
  if (e != TWIN_OK) return dflt_obs(2, static_cast<uint32_t>(core_ord(e)), 0);
  return dflt_obs(2, 0, n);
}

// site 3: interpreter.cpp:972-973 -- binary numeric ops (stacktop(-2), (-1)).
BINLINE uint64_t l_binary(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb) {
  State st{};
  l_push(st, wa, la & 7u);
  l_push(st, wb, lb & 7u);
  uint32_t l1 = 0, l2 = 0;
  const uint8_t* p1 = st_top(st.stack, 2, l1);
  const uint8_t* p2 = st_top(st.stack, 1, l2);
  int64_t a = 0, b = 0;
  TwinErr e = decode_num(p1, l1, /*minimal=*/false, 4, a);
  if (e != TWIN_OK) return dflt_obs(3, static_cast<uint32_t>(core_ord(e)), 0);
  e = decode_num(p2, l2, /*minimal=*/false, 4, b);
  if (e != TWIN_OK) return dflt_obs(3, static_cast<uint32_t>(core_ord(e)), 0);
  return dflt_obs(3, 0, b);
}

// site 4: interpreter.cpp:1017-1019 -- OP_WITHIN (stacktop(-3), (-2), (-1)).
BINLINE uint64_t l_within(uint32_t wx, uint32_t lx, uint32_t wmn, uint32_t lmn,
                          uint32_t wmx, uint32_t lmx) {
  State st{};
  l_push(st, wx, lx & 7u);
  l_push(st, wmn, lmn & 7u);
  l_push(st, wmx, lmx & 7u);
  uint32_t l1 = 0, l2 = 0, l3 = 0;
  const uint8_t* p1 = st_top(st.stack, 3, l1);
  const uint8_t* p2 = st_top(st.stack, 2, l2);
  const uint8_t* p3 = st_top(st.stack, 1, l3);
  int64_t a = 0, b = 0, c = 0;
  TwinErr e = decode_num(p1, l1, /*minimal=*/false, 4, a);
  if (e != TWIN_OK) return dflt_obs(4, static_cast<uint32_t>(core_ord(e)), 0);
  e = decode_num(p2, l2, /*minimal=*/false, 4, b);
  if (e != TWIN_OK) return dflt_obs(4, static_cast<uint32_t>(core_ord(e)), 0);
  e = decode_num(p3, l3, /*minimal=*/false, 4, c);
  if (e != TWIN_OK) return dflt_obs(4, static_cast<uint32_t>(core_ord(e)), 0);
  return dflt_obs(4, 0, c);
}

// site 5: interpreter.cpp:1103 -- OP_CHECKSIGADD (stacktop(-2)).
BINLINE uint64_t l_checksigadd(uint32_t w, uint32_t lb) {
  State st{};
  l_push_fill(st, 0x00);                 // harness sig filler (not read here)
  l_push(st, w, lb & 7u);
  l_push_fill(st, 0x00);                 // harness pubkey filler (not read here)
  uint32_t len = 0;
  const uint8_t* p = st_top(st.stack, 2, len);
  int64_t n = 0;
  const TwinErr e = decode_num(p, len, /*minimal=*/false, 4, n);
  if (e != TWIN_OK) return dflt_obs(5, static_cast<uint32_t>(core_ord(e)), 0);
  return dflt_obs(5, 0, n);
}

// site 6: interpreter.cpp:1126 -- OP_CHECKMULTISIG nKeysCount (stacktop(-1)).
BINLINE uint64_t l_cms_nkeys(uint32_t w, uint32_t lb) {
  State st{};
  l_push(st, w, lb & 7u);
  uint32_t len = 0;
  const uint8_t* p = st_top(st.stack, 1, len);
  int64_t n = 0;
  const TwinErr e = decode_num(p, len, /*minimal=*/false, 4, n);
  if (e != TWIN_OK) return dflt_obs(6, static_cast<uint32_t>(core_ord(e)), 0);
  return dflt_obs(6, 0, n);
}

// site 7: interpreter.cpp:1140 -- OP_CHECKMULTISIG nSigsCount, reached after
// the nKeysCount decode of the same case block.  nKeysCount is the harness
// constant 0 ({0x00}), so stacktop(-(2+nKeysCount)) is the bottom element.
BINLINE uint64_t l_cms_nsigs(uint32_t w, uint32_t lb) {
  State st{};
  l_push(st, w, lb & 7u);                // nSigsCount
  l_push_fill(st, 0x00);                 // nKeysCount = 0 ({0x00})
  uint32_t lk = 0;
  const uint8_t* pk = st_top(st.stack, 1, lk);
  int64_t nk = 0;
  TwinErr e = decode_num(pk, lk, /*minimal=*/false, 4, nk);
  if (e != TWIN_OK) return dflt_obs(7, static_cast<uint32_t>(core_ord(e)), 0);
  if (nk < 0 || nk > 20)
    return dflt_obs(7, static_cast<uint32_t>(core_ord(TWIN_PUBKEY_COUNT)), 0);
  const uint32_t i = 2u + static_cast<uint32_t>(nk);
  if (st.stack.n < i)
    return dflt_obs(7,
                    static_cast<uint32_t>(core_ord(TWIN_INVALID_STACK_OPERATION)), 0);
  uint32_t ls = 0;
  const uint8_t* ps = st_top(st.stack, i, ls);
  int64_t ns = 0;
  e = decode_num(ps, ls, /*minimal=*/false, 4, ns);
  if (e != TWIN_OK) return dflt_obs(7, static_cast<uint32_t>(core_ord(e)), 0);
  return dflt_obs(7, 0, ns);
}

}  // namespace

extern "C" uint64_t cell_pick_roll(uint32_t w, uint32_t lb) {
  return l_pick_roll(w, lb);
}
extern "C" uint64_t cell_unary(uint32_t w, uint32_t lb) {
  return l_unary(w, lb);
}
extern "C" uint64_t cell_binary(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb) {
  return l_binary(wa, la, wb, lb);
}
extern "C" uint64_t cell_within(uint32_t wx, uint32_t lx, uint32_t wmn,
                                uint32_t lmn, uint32_t wmx, uint32_t lmx) {
  return l_within(wx, lx, wmn, lmn, wmx, lmx);
}
extern "C" uint64_t cell_checksigadd(uint32_t w, uint32_t lb) {
  return l_checksigadd(w, lb);
}
extern "C" uint64_t cell_cms_nkeys(uint32_t w, uint32_t lb) {
  return l_cms_nkeys(w, lb);
}
extern "C" uint64_t cell_cms_nsigs(uint32_t w, uint32_t lb) {
  return l_cms_nsigs(w, lb);
}
