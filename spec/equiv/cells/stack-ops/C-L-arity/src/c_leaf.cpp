#include "twin_ops.h"
#include "twin_extras.h"
#include "leaf_common.h"
#include "arity_common.h"

// C leg — Bitcoin Core cce32b168 src/script/interpreter.cpp.
//
// SCR-074: "each op checks depth => INVALID_STACK_OPERATION" over the
// 2DROP..TUCK band (interpreter.cpp:705-875).  Every case starts with
//
//     if (stack.size() < K)
//         return set_error(serror, SCRIPT_ERR_INVALID_STACK_OPERATION);
//
// where K is the opcode's post-pop arity.  This leaf transcribes that guard
// for every (opcode, depth) row of table.csv:
//
//   * `underflow` rows evaluate the guard at a depth < K.  The only result is
//     the packed failure constant (res = 0, error = 18) -- the element bytes
//     are inputs to the function but the Core guard never reads them, which is
//     what the SAW spec proves.
//   * `boundary` rows evaluate the case at depth == K, i.e. the smallest
//     depth the guard admits.  The C side models ONLY the net stack effect of
//     the case body (the `(x1 x2 -- ...)` comment plus the popstack/push_back
//     pairs in the case), with the uniform one-byte seed 0x01.  Element
//     semantics and reordering are NOT claimed here; other stack-ops cells
//     carry them.
//
// The depth and arity in each function are row constants from table.csv.  The
// guard expression is written out as `size < K` rather than folded by hand, so
// a wrong threshold in either leg is observable in the Alive2 comparison.
namespace core {

// interpreter.cpp:<guard>-<guard+1>: size < K -> INVALID_STACK_OPERATION (18).
BINLINE uint64_t c_guard(uint32_t size, uint32_t K) {
  if (size < K) return pack_fail(EQUIV_ERR_INVALID_STACK_OPERATION);
  // Unreachable for an `underflow` row: a row with size >= K is mis-specified
  // and must not silently claim a pass.  The leaf-domain marker makes it loud.
  return pack_domain();
}

// Boundary model: the guard admitted depth == K, and the case body changes the
// depth by the documented net effect.  Seed elements are the uniform one-byte
// 0x01 (the PICK/ROLL index element is consumed by the case body, so the
// surviving stack is again uniform).
BINLINE void seed_uniform(LStack& s, uint32_t post) {
  ls_clear(s);
  if (post > 0) { s.len[0] = 1; s.e[0][0] = 1; }
  if (post > 1) { s.len[1] = 1; s.e[1][0] = 1; }
  if (post > 2) { s.len[2] = 1; s.e[2][0] = 1; }
  if (post > 3) { s.len[3] = 1; s.e[3][0] = 1; }
  if (post > 4) { s.len[4] = 1; s.e[4][0] = 1; }
  if (post > 5) { s.len[5] = 1; s.e[5][0] = 1; }
  s.n = post;
}

BINLINE uint64_t c_boundary(uint32_t post) {
  LStack s;
  seed_uniform(s, post);
  return arity_obs(1u, s);
}

}  // namespace core

// Every `underflow` row: depth < K, six symbolic seed bytes (unread).
#define ROW_FAIL(op, k, d)                                                    \
  extern "C" uint64_t cell_##op##_d##d(uint8_t b0, uint8_t b1, uint8_t b2,    \
                                       uint8_t b3, uint8_t b4, uint8_t b5) {  \
    (void)b0; (void)b1; (void)b2; (void)b3; (void)b4; (void)b5;               \
    return core::c_guard(d, k);                                               \
  }

// Every `boundary` row: depth == K, guard admits, net depth `post`.
#define ROW_OK(op, post)                                                      \
  extern "C" uint64_t cell_##op##_ok() { return core::c_boundary(post); }

// underflow rows: all depths 0..K-1 (interpreter.cpp:case/guard citations in
// table.csv).
ROW_FAIL(2drop, 2, 0)  // 705,708
ROW_FAIL(2drop, 2, 1)
ROW_FAIL(2dup, 2, 0)   // 715,718
ROW_FAIL(2dup, 2, 1)
ROW_FAIL(3dup, 3, 0)   // 727,730
ROW_FAIL(3dup, 3, 1)
ROW_FAIL(3dup, 3, 2)
ROW_FAIL(2over, 4, 0)  // 741,744
ROW_FAIL(2over, 4, 1)
ROW_FAIL(2over, 4, 2)
ROW_FAIL(2over, 4, 3)
ROW_FAIL(2rot, 6, 0)   // 753,756
ROW_FAIL(2rot, 6, 1)
ROW_FAIL(2rot, 6, 2)
ROW_FAIL(2rot, 6, 3)
ROW_FAIL(2rot, 6, 4)
ROW_FAIL(2rot, 6, 5)
ROW_FAIL(2swap, 4, 0)  // 766,769
ROW_FAIL(2swap, 4, 1)
ROW_FAIL(2swap, 4, 2)
ROW_FAIL(2swap, 4, 3)
ROW_FAIL(ifdup, 1, 0)  // 776,779
ROW_FAIL(drop, 1, 0)   // 795,798
ROW_FAIL(dup, 1, 0)    // 804,807
ROW_FAIL(nip, 2, 0)    // 814,817
ROW_FAIL(nip, 2, 1)
ROW_FAIL(over, 2, 0)   // 823,826
ROW_FAIL(over, 2, 1)
ROW_FAIL(pick, 2, 0)   // 833,838
ROW_FAIL(pick, 2, 1)
ROW_FAIL(roll, 2, 0)   // 834,838
ROW_FAIL(roll, 2, 1)
ROW_FAIL(rot, 3, 0)    // 851,856
ROW_FAIL(rot, 3, 1)
ROW_FAIL(rot, 3, 2)
ROW_FAIL(swap, 2, 0)   // 863,866
ROW_FAIL(swap, 2, 1)
ROW_FAIL(tuck, 2, 0)   // 872,875
ROW_FAIL(tuck, 2, 1)

// boundary rows: depth == K, expected net depth from table.csv.
ROW_OK(2drop, 0)  // (x1 x2 -- )
ROW_OK(2dup, 4)   // (x1 x2 -- x1 x2 x1 x2)
ROW_OK(3dup, 6)   // (x1 x2 x3 -- x1 x2 x3 x1 x2 x3)
ROW_OK(2over, 6)  // (x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2)
ROW_OK(2rot, 6)   // (x1..x6 -- x3 x4 x5 x6 x1 x2)
ROW_OK(2swap, 4)  // (x1 x2 x3 x4 -- x3 x4 x1 x2)
ROW_OK(ifdup, 2)  // (x - x x) with seed 0x01 truthy
ROW_OK(drop, 0)   // (x -- )
ROW_OK(dup, 2)    // (x -- x x)
ROW_OK(nip, 1)    // (x1 x2 -- x2)
ROW_OK(over, 3)   // (x1 x2 -- x1 x2 x1)
ROW_OK(pick, 2)   // (xn..x0 n -- xn..x0 xn), net 0
ROW_OK(roll, 1)   // (xn..x0 n -- ..x0 xn), net -1
ROW_OK(rot, 3)    // (x1 x2 x3 -- x2 x3 x1)
ROW_OK(swap, 2)   // (x1 x2 -- x2 x1)
ROW_OK(tuck, 3)   // (x1 x2 -- x2 x1 x2)
