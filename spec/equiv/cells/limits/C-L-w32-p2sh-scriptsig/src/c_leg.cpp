// C leg — source-excerpt slice of Bitcoin Core at pin cce32b168.
//
//   src/script/script.cpp:183-205  CScript::GetSigOpCount(const CScript&)
//   src/script/script.cpp:266-286  CScript::IsPushOnly
//   src/script/script.cpp:313-360  GetScriptOp (payload register pvchRet)
//   src/script/script.cpp:157-181  CScript::GetSigOpCount(bool)
//
// The cell fixes the scriptSig domain to four bytes (LIMITS_MAX_SCRIPT_BYTES)
// and assumes the caller is in the P2SH branch (`this->IsPayToScriptHash()`,
// script.cpp:183-185).  The slice is the P2SH arm only: parse the scriptSig
// all-or-nothing, reject every opcode above OP_16, keep the final GetOp payload
// register, then take the accurate static sigop count of that payload's valid
// prefix.
//
// SCR-034: malformed or non-push-only scriptSig returns zero; otherwise the
//          final push data's valid script prefix is counted accurately.
//
// Every walk is unrolled to the four-byte bound with an explicit live flag:
// Alive2 does not give a trustworthy result on a residual loop, so no loop
// survives at -O1.
#include "limits_common.h"

namespace {

struct Op {
  bool ok;
  bool push;
  uint32_t code;
  uint32_t next;
  uint32_t dstart;  // payload start
  uint32_t dlen;    // payload length
};

// GetScriptOp over a virtual script [base, base + n).  `pvchRet` is the
// final payload register: it is cleared for every non-push opcode and set to
// the payload for a push (script.cpp:316-319, 353-354).
CLINLINE Op core_get_op(const LimitsScript& s, uint32_t base, uint32_t n,
                        uint32_t pc) {
  Op o;
  o.ok = false;
  o.push = false;
  o.code = LOP_INVALIDOPCODE;
  o.next = pc;
  o.dstart = 0;
  o.dlen = 0;
  if (pc >= n) return o;

  uint32_t pos = pc;
  const uint32_t opcode = limits_byte(s, base + pos);
  pos += 1;

  if (opcode <= LOP_PUSHDATA4) {
    uint32_t nSize = 0;
    if (opcode < LOP_PUSHDATA1) {
      nSize = opcode;
    } else if (opcode == LOP_PUSHDATA1) {
      if (n - pos < 1) return o;
      nSize = limits_byte(s, base + pos);
      pos += 1;
    } else if (opcode == LOP_PUSHDATA2) {
      if (n - pos < 2) return o;
      nSize = limits_byte(s, base + pos) |
              (limits_byte(s, base + pos + 1) << 8);
      pos += 2;
    } else {
      if (n - pos < 4) return o;
      nSize = limits_byte(s, base + pos) |
              (limits_byte(s, base + pos + 1) << 8) |
              (limits_byte(s, base + pos + 2) << 16) |
              (limits_byte(s, base + pos + 3) << 24);
      pos += 4;
    }
    if (nSize > n - pos) return o;
    o.ok = true;
    o.push = true;
    o.code = opcode;
    o.dstart = pos;
    o.dlen = nSize;
    o.next = pos + nSize;
    return o;
  }

  // Non-push opcode: pvchRet stays cleared.
  o.ok = true;
  o.push = false;
  o.code = opcode;
  o.next = pos;
  return o;
}

// GetSigOpCount(bool) loop state; one core_count_step per loop body.
struct Count {
  bool live;
  uint32_t pc;
  uint32_t count;
  uint32_t lastOpcode;
};

CLINLINE void core_count_step(Count& st, const LimitsScript& s, uint32_t base,
                              uint32_t limit, bool accurate) {
  if (!st.live) return;
  if (st.pc >= limit) {  // while (pc < end())
    st.live = false;
    return;
  }
  const Op o = core_get_op(s, base, limit, st.pc);
  if (!o.ok) {  // if (!GetOp(pc, opcode)) break;
    st.live = false;
    return;
  }
  if (o.code == LOP_CHECKSIG || o.code == LOP_CHECKSIGVERIFY) {
    st.count += 1;
  } else if (o.code == LOP_CHECKMULTISIG ||
             o.code == LOP_CHECKMULTISIGVERIFY) {
    if (accurate && st.lastOpcode >= LOP_1 && st.lastOpcode <= LOP_16) {
      st.count += st.lastOpcode - (LOP_1 - 1u);
    } else {
      st.count += LIMITS_MAX_PUBKEYS_PER_MULTISIG;
    }
  }
  st.lastOpcode = o.code;
  st.pc = o.next;
}

// GetSigOpCount(bool) over a virtual script [base, base + limit), unrolled.
CLINLINE uint32_t core_count(const LimitsScript& s, uint32_t base,
                             uint32_t limit, bool accurate) {
  Count st;
  st.live = true;
  st.pc = 0;
  st.count = 0;
  st.lastOpcode = LOP_INVALIDOPCODE;
  core_count_step(st, s, base, limit, accurate);
  core_count_step(st, s, base, limit, accurate);
  core_count_step(st, s, base, limit, accurate);
  core_count_step(st, s, base, limit, accurate);
  return st.count;
}

// First loop of the P2SH arm: parse all-or-nothing and keep the last payload.
struct PState {
  bool live;
  bool ok;
  uint32_t pc;
  uint32_t dstart;
  uint32_t dlen;
};

CLINLINE void core_p2sh_step(PState& st, const LimitsScript& s, uint32_t limit) {
  if (!st.live) return;
  if (st.pc >= limit) {
    st.live = false;
    return;
  }
  const Op o = core_get_op(s, 0, limit, st.pc);
  if (!o.ok || o.code > LOP_16) {  // GetOp failure or opcode > OP_16
    st.live = false;
    st.ok = false;
    return;
  }
  if (o.push) {
    st.dstart = o.dstart;
    st.dlen = o.dlen;
  } else {
    st.dstart = 0;
    st.dlen = 0;
  }
  st.pc = o.next;
}

// CScript::GetSigOpCount(const CScript&) in the P2SH branch.
CLINLINE uint32_t core_p2sh_sigops(uint64_t w, uint32_t len) {
  if (len > LIMITS_MAX_SCRIPT_BYTES) return LIMITS_OUT_OF_DOMAIN;
  const LimitsScript s = limits_script(w, len);

  PState st;
  st.live = true;
  st.ok = true;
  st.pc = 0;
  st.dstart = 0;
  st.dlen = 0;
  core_p2sh_step(st, s, s.len);
  core_p2sh_step(st, s, s.len);
  core_p2sh_step(st, s, s.len);
  core_p2sh_step(st, s, s.len);
  if (!st.ok || st.pc < s.len) return 0;

  // Second loop: accurate count of the subscript built from the final data.
  return core_count(s, st.dstart, st.dlen, true);
}

}  // namespace

extern "C" uint32_t cell_p2sh_sigops(uint64_t w, uint32_t len) {
  return core_p2sh_sigops(w, len);
}
