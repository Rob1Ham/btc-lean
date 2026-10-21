// C leg — source-excerpt slice of Bitcoin Core at pin cce32b168.
//
//   src/script/script.cpp:313-360   GetScriptOp(pc, end, opcodeRet, pvchRet)
//   src/script/script.cpp:157-181   CScript::GetSigOpCount(bool fAccurate)
//   src/script/script.h:507-514     CScript::DecodeOP_N (OP_1..OP_16 range)
//   src/script/interpreter.h        MAX_PUBKEYS_PER_MULTISIG = 20
//
// The slice fixes the script domain to four bytes (LIMITS_MAX_SCRIPT_BYTES in
// cells/_tools/limits) and drops the recovered push payload: GetSigOpCount
// only inspects the decoded opcode, never the payload bytes.
//
// SCR-032: CHECKSIG/CHECKSIGVERIFY count 1; CHECKMULTISIG/CHECKMULTISIGVERIFY
//          count MAX_PUBKEYS_PER_MULTISIG = 20 when fAccurate is false.
// SCR-033: with fAccurate, a CHECKMULTISIG family opcode counts the value of
//          the immediately preceding OP_1..OP_16 opcode, else 20.
#include "limits_common.h"

namespace {

struct Op {
  bool ok;
  uint32_t code;
  uint32_t next;
};

// GetScriptOp, bounded: reads from the packed cell script instead of a
// prevector.  The control flow and the length checks are Core's.
CLINLINE Op core_get_script_op(const LimitsScript& s, uint32_t pc) {
  Op o;
  o.ok = false;
  o.code = LOP_INVALIDOPCODE;
  o.next = pc;
  if (pc >= s.len) return o;

  uint32_t pos = pc;
  const uint32_t opcode = limits_byte(s, pos);  // *pc++
  pos += 1;

  if (opcode <= LOP_PUSHDATA4) {
    uint32_t nSize = 0;
    if (opcode < LOP_PUSHDATA1) {
      nSize = opcode;                              // script.cpp:327
    } else if (opcode == LOP_PUSHDATA1) {
      if (s.len - pos < 1) return o;               // script.cpp:331
      nSize = limits_byte(s, pos);
      pos += 1;
    } else if (opcode == LOP_PUSHDATA2) {
      if (s.len - pos < 2) return o;               // script.cpp:337
      nSize = limits_byte(s, pos) | (limits_byte(s, pos + 1) << 8);
      pos += 2;
    } else {                                       // OP_PUSHDATA4
      if (s.len - pos < 4) return o;               // script.cpp:344
      nSize = limits_byte(s, pos) | (limits_byte(s, pos + 1) << 8) |
              (limits_byte(s, pos + 2) << 16) |
              (limits_byte(s, pos + 3) << 24);
      pos += 4;
    }
    // script.cpp:349: (unsigned int)(end - pc) < nSize
    if (nSize > s.len - pos) return o;
    pos += nSize;
  }

  o.ok = true;
  o.code = opcode;
  o.next = pos;
  return o;
}

// CScript::GetSigOpCount(bool) loop state; one iteration per core_sigop_step.
struct Count {
  bool live;
  uint32_t pc;
  uint32_t n;
  uint32_t lastOpcode;
};

// script.cpp:157-181, exactly one loop body:
//   while (pc < end()) {
//     opcodetype opcode;
//     if (!GetOp(pc, opcode)) break;
//     if (opcode == OP_CHECKSIG || opcode == OP_CHECKSIGVERIFY) n++;
//     else if (opcode == OP_CHECKMULTISIG || opcode == OP_CHECKMULTISIGVERIFY) {
//       if (fAccurate && lastOpcode >= OP_1 && lastOpcode <= OP_16)
//         n += DecodeOP_N(lastOpcode);
//       else n += MAX_PUBKEYS_PER_MULTISIG;
//     }
//     lastOpcode = opcode;
//   }
CLINLINE void core_sigop_step(Count& st, const LimitsScript& s, bool accurate) {
  if (!st.live) return;                    // loop already left (break/end)
  if (st.pc >= s.len) {                    // while (pc < end())
    st.live = false;
    return;
  }
  const Op o = core_get_script_op(s, st.pc);
  if (!o.ok) {                             // if (!GetOp(pc, opcode)) break;
    st.live = false;
    return;
  }
  if (o.code == LOP_CHECKSIG || o.code == LOP_CHECKSIGVERIFY) {
    st.n += 1;
  } else if (o.code == LOP_CHECKMULTISIG || o.code == LOP_CHECKMULTISIGVERIFY) {
    if (accurate && st.lastOpcode >= LOP_1 && st.lastOpcode <= LOP_16) {
      st.n += st.lastOpcode - (LOP_1 - 1u);  // DecodeOP_N: opcode - OP_1 + 1
    } else {
      st.n += LIMITS_MAX_PUBKEYS_PER_MULTISIG;
    }
  }
  st.lastOpcode = o.code;
  st.pc = o.next;
}

// GetSigOpCount with the loop unrolled to the cell bound: every decoded
// opcode consumes at least one byte, so a four-byte script needs at most
// four iterations.  The unrolling is harness (no engine semantics).
CLINLINE uint32_t core_get_sigop_count(uint64_t w, uint32_t len,
                                       bool accurate) {
  if (len > LIMITS_MAX_SCRIPT_BYTES) return LIMITS_OUT_OF_DOMAIN;
  const LimitsScript s = limits_script(w, len);
  Count st;
  st.live = true;
  st.pc = 0;
  st.n = 0;
  st.lastOpcode = LOP_INVALIDOPCODE;       // script.cpp:155
  core_sigop_step(st, s, accurate);
  core_sigop_step(st, s, accurate);
  core_sigop_step(st, s, accurate);
  core_sigop_step(st, s, accurate);
  return st.n;
}

}  // namespace

extern "C" uint32_t cell_sigop_accurate(uint64_t w, uint32_t len) {
  return core_get_sigop_count(w, len, true);
}

extern "C" uint32_t cell_sigop_inaccurate(uint64_t w, uint32_t len) {
  return core_get_sigop_count(w, len, false);
}
