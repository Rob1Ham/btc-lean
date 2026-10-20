#include <cstdint>
// L leg: Lean stepBody translation, transcribed from the generated twin
// `twin/runtime.inc` (which mirrors Defs.lean:816-900; it is not a Core
// transliteration).
//
// Order in stepBody (Defs.lean:816-846):
//   (1) element size limit, executed or not
//   (2) op budget: wire > 0x60 under base/witnessV0
//   (3) disabled wires
//   (4) CONST_SCRIPTCODE + OP_CODESEPARATOR
//   (5) match op.ast:
//       .pushBytes d -> if !fExec skip
//                       else if minimalData && !checkMinimalPush -> MINIMALDATA
//                       else push
//       .op _       -> if !(fExec || 0x63 <= w <= 0x68) skip
//                      else dispatch (OP_IF/OP_NOTIF/OP_ENDIF here)
// The unexecuted non-minimal push is skipped, so it is not an error: SCR-049.
//
// The fixed script is [cond, OP_IF, push 0x01 0x01, OP_ENDIF, OP_1]; only
// `minimalData` is symbolic.  The final EVAL_FALSE tail is VerifyScript's.

#define BINLINE static inline __attribute__((always_inline))

struct S { uint32_t n; uint32_t len[4]; uint8_t e[4][1]; };

BINLINE bool l_all_true(const bool* vf, uint32_t n) {
  for (uint32_t i = 0; i < n; ++i) if (!vf[i]) return false;
  return true;
}
BINLINE bool l_cast_to_bool(const uint8_t* d, uint32_t l) {
  for (uint32_t i = 0; i < l; ++i) {
    if (d[i] != 0) {
      if (i + 1 == l && d[i] == 0x80u) return false;
      return true;
    }
  }
  return false;
}
BINLINE uint32_t l_push(S& s, const uint8_t* d, uint32_t l) {
  if (l > 1) return 6;                       // TWIN_PUSH_SIZE
  if (s.n >= 4) return 8;                    // TWIN_STACK_SIZE
  s.len[s.n] = l;
  s.e[s.n][0] = l ? d[0] : 0;
  s.n += 1;
  return 0;
}
BINLINE bool l_disabled(uint32_t w) {
  switch (w) {
    case 0x7e: case 0x7f: case 0x80: case 0x81: case 0x83: case 0x84:
    case 0x85: case 0x86: case 0x8d: case 0x8e: case 0x95: case 0x96:
    case 0x97: case 0x98: case 0x99:
      return true;
    default:
      return false;
  }
}
// Defs.lean:529-537 checkMinimalPush on a <=1-byte payload.
BINLINE bool l_check_minimal(const uint8_t* d, uint32_t l, uint32_t op) {
  if (l == 0) return op == 0;
  if (l == 1 && 1 <= d[0] && d[0] <= 16) return false;
  if (l == 1 && d[0] == 0x81) return false;
  if (l <= 75) return op == l;
  if (l <= 0xff) return op == 0x4c;
  if (l <= 0xffff) return op == 0x4d;
  return true;
}
// getOp at `pc` (Parser/Defs.lean:206-229), bounded script, <=1-byte payload.
BINLINE bool l_get(uint32_t& pc, const uint8_t* b, uint32_t n, uint32_t& wire,
                   uint32_t& dlen, uint8_t* data) {
  wire = 0; dlen = 0;
  if (pc >= n) return false;
  const uint32_t c = b[pc++];
  wire = c;
  if (c == 0x00u) return true;
  if (c < 0x4cu) {
    if (c > n - (pc - 1) - 1) return false;
    data[0] = c ? b[pc] : 0;                 // cell domain: c <= 1 byte
    if (c > 1) return false;
    dlen = c;
    pc += c;
    return true;
  }
  if (c == 0x4cu || c == 0x4du || c == 0x4eu) {
    const uint32_t width = 1u << ((c == 0x4eu) ? 2u : (c - 0x4cu));
    if (width > n - pc) return false;
    uint32_t k = b[pc];
    if (width > 1) k |= static_cast<uint32_t>(b[pc + 1]) << 8;
    if (width > 2) {
      k |= static_cast<uint32_t>(b[pc + 2]) << 16;
      k |= static_cast<uint32_t>(b[pc + 3]) << 24;
    }
    const uint32_t prefix = 1 + width;
    if (prefix > n || k > n - prefix) return false;
    if (k > 1) return false;                 // cell domain
    data[0] = k ? b[prefix] : 0;
    dlen = k;
    pc = prefix + k;
    return true;
  }
  return true;                               // pushNum or op
}

BINLINE uint32_t l_step(const uint8_t* b, uint32_t n, uint32_t& pc,
                        uint32_t& opCount, bool* vf, uint32_t& vf_n, S& st,
                        uint32_t minimalData) {
  const bool fExec = l_all_true(vf, vf_n);
  uint32_t wire = 0, dlen = 0;
  uint8_t data[2] = {0, 0};
  if (!l_get(pc, b, n, wire, dlen, data)) return 16;   // TWIN_BAD_OPCODE
  if (dlen > 520) return 6;                            // TWIN_PUSH_SIZE
  if (wire > 0x60) {
    opCount += 1;
    if (opCount > 201) return 7;                       // TWIN_OP_COUNT
  }
  if (l_disabled(wire)) return 17;                     // TWIN_DISABLED_OPCODE
  if (wire == 0xab) return 16;                         // not in this script
  if (wire <= 0x4eu) {                                 // .pushBytes / OP_0
    if (!fExec) return 0;
    if (minimalData && !l_check_minimal(data, dlen, wire)) return 25;
    return l_push(st, data, dlen);
  }
  if (wire == 0x4fu || (wire >= 0x51u && wire <= 0x60u)) {  // .pushNum
    if (!fExec) return 0;
    uint8_t d[1];
    d[0] = (wire == 0x4fu) ? 0x81u : static_cast<uint8_t>(wire - 0x50u);
    return l_push(st, d, 1);
  }
  if (!(fExec || (wire >= 0x63u && wire <= 0x68u))) return 0;
  if (wire == 0x63u || wire == 0x64u) {                // OP_IF / OP_NOTIF
    bool v = false;
    if (fExec) {
      if (st.n < 1) return 18;
      v = l_cast_to_bool(st.e[st.n - 1], st.len[st.n - 1]);
      st.n -= 1;
      if (wire == 0x64u) v = !v;
    }
    if (vf_n >= 4) return 20;
    vf[vf_n++] = v;
    return 0;
  }
  if (wire == 0x68u) {                                 // OP_ENDIF
    if (vf_n == 0) return 20;
    vf_n -= 1;
    return 0;
  }
  return 16;                                           // outside cell script
}

BINLINE uint64_t l_pack(uint32_t res, uint32_t err, const S& s) {
  uint64_t r = 0;
  r |= static_cast<uint64_t>(res & 3u);
  r |= static_cast<uint64_t>(err & 0x3fu) << 2;
  r |= static_cast<uint64_t>(s.n & 3u) << 8;
  if (s.n > 0) {
    const uint32_t i = s.n - 1;
    r |= static_cast<uint64_t>(s.len[i] & 3u) << 10;
    r |= static_cast<uint64_t>(s.e[i][0]) << 12;
  }
  return r;
}

BINLINE uint64_t l_run(const uint8_t* b, uint32_t n, uint32_t minimalData) {
  S st{}; uint32_t opCount = 0, vf_n = 0, pc = 0;
  bool vf[4] = {false, false, false, false};
  uint32_t e;
  e = l_step(b, n, pc, opCount, vf, vf_n, st, minimalData); if (e) return l_pack(0, e, st);
  e = l_step(b, n, pc, opCount, vf, vf_n, st, minimalData); if (e) return l_pack(0, e, st);
  e = l_step(b, n, pc, opCount, vf, vf_n, st, minimalData); if (e) return l_pack(0, e, st);
  e = l_step(b, n, pc, opCount, vf, vf_n, st, minimalData); if (e) return l_pack(0, e, st);
  e = l_step(b, n, pc, opCount, vf, vf_n, st, minimalData); if (e) return l_pack(0, e, st);
  if (vf_n != 0) return l_pack(0, 20, st);             // unbalanced conditional
  if (st.n == 0 || !l_cast_to_bool(st.e[st.n - 1], st.len[st.n - 1]))
    return l_pack(0, 2, st);                           // EVAL_FALSE
  return l_pack(1, 0, st);
}

extern "C" uint64_t cell_fexec_false(uint32_t minimalData) {
  const uint8_t script[6] = {0x00, 0x63, 0x01, 0x01, 0x68, 0x51};
  return l_run(script, 6, minimalData);
}
extern "C" uint64_t cell_fexec_true(uint32_t minimalData) {
  const uint8_t script[6] = {0x51, 0x63, 0x01, 0x01, 0x68, 0x51};
  return l_run(script, 6, minimalData);
}
