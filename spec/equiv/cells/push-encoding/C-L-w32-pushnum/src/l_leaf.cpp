#include <cstdint>
// L leg: Lean push semantics transcribed verbatim from the generated twin
// `twin/runtime.inc` (which mirrors Defs.lean; it is not a Core
// transliteration).
//
//   Defs.lean:836-846 stepBody
//     | .pushBytes d =>
//         if !fExec then .ok st1
//         else if ctx.pol.minimalData && !checkMinimalPush d w then
//           .error .minimalData
//         else .ok { st1 with stack := d :: st.stack }
//     | .pushNum n =>
//         if !fExec then .ok st1
//         else .ok { st1 with stack :=
//           encodeScriptNum (if n = 0 then -1 else n) false :: st.stack }
//
// OP_0 is `.pushBytes ∅`; OP_1NEGATE is `.pushNum 0`; OP_n is `.pushNum n`
// (Parser/Defs.lean:26-30, 200-221).  fExec is true here (the cell is the
// executed case), so the minimal gate runs for OP_0 only, where
// checkMinimalPush(∅, 0) = true.
//
// `encodeScriptNum` (Numeric/Interface.lean:55-56) is the canonical minimal
// LE sign-magnitude encoder.  For the reachable values -1..16 it reduces to
// the closed form below (twin/runtime.inc encode_num).

#define BINLINE static inline __attribute__((always_inline))

struct BStack { uint32_t n; uint32_t len[2]; uint8_t e[2][2]; };

BINLINE uint32_t lean_encode_small(int64_t v, uint8_t* out) {
  if (v == 0) return 0;
  const bool neg = v < 0;
  const uint64_t a = neg ? (static_cast<uint64_t>(-(v + 1)) + 1u)
                         : static_cast<uint64_t>(v);
  out[0] = static_cast<uint8_t>(a & 0xffu);
  if (out[0] & 0x80u) {
    out[1] = neg ? 0x80u : 0x00u;
    return 2;
  }
  if (neg) out[0] |= 0x80u;
  return 1;
}

BINLINE uint32_t lean_push(BStack& s, const uint8_t* d, uint32_t l) {
  if (l > 2) return 6;                       // TWIN_PUSH_SIZE
  if (s.n >= 2) return 8;                    // TWIN_STACK_SIZE
  s.len[s.n] = l;
  s.e[s.n][0] = l > 0 ? d[0] : 0;
  s.e[s.n][1] = l > 1 ? d[1] : 0;
  s.n += 1;
  return 0;
}

// twin runtime.inc cast_to_bool / Defs.lean castToBool: negative zero (a
// lone 0x80 byte in the top position) is false.
BINLINE uint32_t lean_cast_to_bool(const uint8_t* d, uint32_t l) {
  for (uint32_t i = 0; i < l; ++i) {
    if (d[i] != 0) {
      if (i + 1 == l && d[i] == 0x80u) return 0;
      return 1;
    }
  }
  return 0;
}

BINLINE uint64_t l_pack(uint32_t res, uint32_t err, const BStack& s, uint32_t fin) {
  uint64_t r = 0;
  r |= static_cast<uint64_t>(res & 3u);
  r |= static_cast<uint64_t>(err & 0x3fu) << 2;
  r |= static_cast<uint64_t>(s.n & 3u) << 8;
  if (s.n > 0) {
    const uint32_t i = s.n - 1;
    r |= static_cast<uint64_t>(s.len[i] & 3u) << 10;
    r |= static_cast<uint64_t>(s.e[i][0]) << 12;
    r |= static_cast<uint64_t>(fin & 1u) << 20;
  }
  return r;
}

extern "C" uint64_t cell_pushnum(uint32_t sel, uint32_t minimalData) {
  if (sel > 17) return 3;                    // out of cell domain
  const uint32_t wire = (sel == 0) ? 0x00u : (sel == 1) ? 0x4fu : (0x51u + sel - 2u);
  BStack s{};
  uint8_t d[2] = {0, 0};
  if (wire == 0x00u) {
    // .pushBytes ∅, fExec true; checkMinimalPush(∅, 0) is true for every
    // minimalData value, so the minimal gate never fires.
    (void)minimalData;
    const uint32_t e = lean_push(s, d, 0);
    if (e) return l_pack(0, e, s, 0);
  } else {
    (void)minimalData;                       // .pushNum has no minimal gate
    const int64_t v = (wire == 0x4fu) ? -1 : static_cast<int64_t>(wire - 0x50u);
    const uint32_t l = lean_encode_small(v, d);
    const uint32_t e = lean_push(s, d, l);
    if (e) return l_pack(0, e, s, 0);
  }
  const uint32_t fin = lean_cast_to_bool(s.e[0], s.len[0]);
  return l_pack(1, 0, s, fin);
}
