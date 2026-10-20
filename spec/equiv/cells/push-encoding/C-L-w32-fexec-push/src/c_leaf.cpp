#include <cstdint>
// C leg: source-excerpt slice of Bitcoin Core cce32b168 EvalScript.
//
// Script (6 bytes):
//   [0] condition  : OP_0 (0x00, false) or OP_1 (0x51, true)
//   [1] OP_IF      : 0x63
//   [2..3] 0x01 0x01 : direct push of the one-byte value {1} -- NOT minimal
//                      (canonical is OP_1)
//   [4] OP_ENDIF   : 0x68
//   [5] OP_1       : 0x51
//
// Executed-checks order (interpreter.cpp:476-523):
//   GetOp -> element size -> op budget -> disabled -> CONST_SCRIPTCODE
//   -> [if (fExec && opcode <= OP_PUSHDATA4)] { MINIMALDATA gate; push }
//   -> [else if (fExec || OP_IF..OP_ENDIF)] switch
// The MINIMALDATA gate is `if (fRequireMinimal && !CheckMinimalPush(...))`.
// An unexecuted push is skipped entirely, so its non-minimal encoding is not
// an error.  This is SCR-049.
//
// EVAL_FALSE is applied at the end as VerifyScript does
// (interpreter.cpp:1876-1880).

#define BINLINE static inline __attribute__((always_inline))

struct S { uint32_t n; uint32_t len[4]; uint8_t e[4][1]; };

BINLINE bool c_all_true(const bool* vf, uint32_t n) {
  for (uint32_t i = 0; i < n; ++i) if (!vf[i]) return false;
  return true;
}
BINLINE bool c_cast_to_bool(const uint8_t* d, uint32_t l) {
  for (uint32_t i = 0; i < l; ++i) {
    if (d[i] != 0) {
      if (i + 1 == l && d[i] == 0x80u) return false;
      return true;
    }
  }
  return false;
}
BINLINE uint32_t c_push(S& s, const uint8_t* d, uint32_t l) {
  if (l > 1) return 6;                       // PUSH_SIZE
  if (s.n >= 4) return 8;                    // STACK_SIZE
  s.len[s.n] = l;
  s.e[s.n][0] = l ? d[0] : 0;
  s.n += 1;
  return 0;
}
BINLINE bool c_disabled(uint32_t w) {
  switch (w) {
    case 0x7e: case 0x7f: case 0x80: case 0x81: case 0x83: case 0x84:
    case 0x85: case 0x86: case 0x8d: case 0x8e: case 0x95: case 0x96:
    case 0x97: case 0x98: case 0x99:
      return true;
    default:
      return false;
  }
}
// script.cpp:373-396 CheckMinimalPush on a <=1-byte payload.
BINLINE bool c_check_minimal(const uint8_t* d, uint32_t l, uint32_t op) {
  if (l == 0) return op == 0;
  if (l == 1 && d[0] >= 1 && d[0] <= 16) return false;
  if (l == 1 && d[0] == 0x81) return false;
  if (l <= 75) return op == l;
  if (l <= 255) return op == 0x4c;
  if (l <= 65535) return op == 0x4d;
  return true;
}
// script.cpp:313-363 GetScriptOp, bounded script and <=1-byte payload.
BINLINE bool c_get(uint32_t& pc, const uint8_t* b, uint32_t n, uint32_t& wire,
                   uint32_t& dlen, uint8_t* data) {
  wire = 0xff; dlen = 0;
  if (pc >= n) return false;
  const uint32_t op = b[pc++];
  if (op <= 0x4eu) {
    uint32_t nSize = 0;
    if (op < 0x4cu) {
      nSize = op;
    } else if (op == 0x4cu) {
      if (n - pc < 1) { wire = op; return false; }
      nSize = b[pc++];
    } else if (op == 0x4du) {
      if (n - pc < 2) { wire = op; return false; }
      nSize = static_cast<uint32_t>(b[pc]) |
              (static_cast<uint32_t>(b[pc + 1]) << 8);
      pc += 2;
    } else {
      if (n - pc < 4) { wire = op; return false; }
      nSize = static_cast<uint32_t>(b[pc]) |
              (static_cast<uint32_t>(b[pc + 1]) << 8) |
              (static_cast<uint32_t>(b[pc + 2]) << 16) |
              (static_cast<uint32_t>(b[pc + 3]) << 24);
      pc += 4;
    }
    if (n - pc < nSize) { wire = op; return false; }
    // cell domain: a successful push carries 0 or 1 byte
    if (nSize > 1) return false;
    data[0] = nSize ? b[pc] : 0;
    dlen = nSize;
    pc += nSize;
  }
  wire = op;
  return true;
}

BINLINE uint32_t c_step(const uint8_t* b, uint32_t n, uint32_t& pc,
                        uint32_t& opCount, bool* vf, uint32_t& vf_n, S& st,
                        uint32_t minimalData) {
  const bool fExec = c_all_true(vf, vf_n);
  uint32_t wire = 0, dlen = 0;
  uint8_t data[2] = {0, 0};
  if (!c_get(pc, b, n, wire, dlen, data)) return 16;   // BAD_OPCODE
  if (dlen > 520) return 6;                            // PUSH_SIZE
  if (wire > 0x60) {                                   // op budget
    opCount += 1;
    if (opCount > 201) return 7;
  }
  if (c_disabled(wire)) return 17;                     // DISABLED_OPCODE
  if (fExec && wire <= 0x4eu) {                        // interpreter.cpp:499
    if (minimalData && !c_check_minimal(data, dlen, wire)) return 25;
    return c_push(st, data, dlen);
  }
  if (fExec && (wire == 0x4fu ||                         // interpreter.cpp:527
                (wire >= 0x51u && wire <= 0x60u))) {
    uint8_t d[1];
    d[0] = (wire == 0x4fu) ? 0x81u : static_cast<uint8_t>(wire - 0x50u);
    return c_push(st, d, 1);
  }
  if (fExec || (wire >= 0x63u && wire <= 0x68u)) {
    if (wire == 0x63u || wire == 0x64u) {              // OP_IF / OP_NOTIF
      bool v = false;
      if (fExec) {
        if (st.n < 1) return 18;
        v = c_cast_to_bool(st.e[st.n - 1], st.len[st.n - 1]);
        st.n -= 1;
        if (wire == 0x64u) v = !v;
      }
      if (vf_n >= 4) return 20;
      vf[vf_n++] = v;
      return 0;
    }
    if (wire == 0x68u) {                               // OP_ENDIF
      if (vf_n == 0) return 20;
      vf_n -= 1;
      return 0;
    }
    // Other opcodes are outside this cell's script.
    return 16;
  }
  return 0;                                            // unexecuted: skip
}

BINLINE uint64_t c_pack(uint32_t res, uint32_t err, const S& s) {
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

BINLINE uint64_t c_run(const uint8_t* b, uint32_t n, uint32_t minimalData) {
  S st{}; uint32_t opCount = 0, vf_n = 0, pc = 0;
  bool vf[4] = {false, false, false, false};
  uint32_t e;                                          // fixed 5-opcode script
  e = c_step(b, n, pc, opCount, vf, vf_n, st, minimalData); if (e) return c_pack(0, e, st);
  e = c_step(b, n, pc, opCount, vf, vf_n, st, minimalData); if (e) return c_pack(0, e, st);
  e = c_step(b, n, pc, opCount, vf, vf_n, st, minimalData); if (e) return c_pack(0, e, st);
  e = c_step(b, n, pc, opCount, vf, vf_n, st, minimalData); if (e) return c_pack(0, e, st);
  e = c_step(b, n, pc, opCount, vf, vf_n, st, minimalData); if (e) return c_pack(0, e, st);
  if (vf_n != 0) return c_pack(0, 20, st);             // UNBALANCED
  if (st.n == 0 || !c_cast_to_bool(st.e[st.n - 1], st.len[st.n - 1]))
    return c_pack(0, 2, st);                           // EVAL_FALSE
  return c_pack(1, 0, st);
}

extern "C" uint64_t cell_fexec_false(uint32_t minimalData) {
  const uint8_t script[6] = {0x00, 0x63, 0x01, 0x01, 0x68, 0x51};
  return c_run(script, 6, minimalData);
}
extern "C" uint64_t cell_fexec_true(uint32_t minimalData) {
  const uint8_t script[6] = {0x51, 0x63, 0x01, 0x01, 0x68, 0x51};
  return c_run(script, 6, minimalData);
}
