// C leg — source-excerpt slice of Bitcoin Core at pin cce32b168.
//
//   src/script/interpreter.cpp:2133-2147  static WitnessSigOps
//   src/script/interpreter.h             WITNESS_V0_KEYHASH_SIZE = 20,
//                                        WITNESS_V0_SCRIPTHASH_SIZE = 32
//   src/script/script.cpp:157-181        CScript::GetSigOpCount(bool)
//   src/script/script.cpp:313-360        GetScriptOp
//
// SCR-035: v0 with a 20-byte program contributes 1; v0 with a 32-byte program
// contributes the accurate static sigop count of the last witness stack item;
// every other version, program size, and an empty witness stack contribute 0.
//
// The cell passes the last witness item as a packed four-byte script
// (LIMITS_MAX_SCRIPT_BYTES) and a symbolic stack size (only zero/non-zero is
// observed by WitnessSigOps).  The program bytes are not read at all: only
// `witprogram.size()` is inspected, so the program is represented by its
// length.  The count walk is unrolled; no loop survives at -O1.
#include "limits_common.h"

namespace {

struct Op {
  bool ok;
  uint32_t code;
  uint32_t next;
};

// GetScriptOp over the virtual script [base, base + n).
CLINLINE Op core_get_op(const LimitsScript& s, uint32_t base, uint32_t n,
                        uint32_t pc) {
  Op o;
  o.ok = false;
  o.code = LOP_INVALIDOPCODE;
  o.next = pc;
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
    pos += nSize;
  }

  o.ok = true;
  o.code = opcode;
  o.next = pos;
  return o;
}

struct Count {
  bool live;
  uint32_t pc;
  uint32_t count;
  uint32_t lastOpcode;
};

CLINLINE void core_count_step(Count& st, const LimitsScript& s, uint32_t base,
                              uint32_t limit, bool accurate) {
  if (!st.live) return;
  if (st.pc >= limit) {
    st.live = false;
    return;
  }
  const Op o = core_get_op(s, base, limit, st.pc);
  if (!o.ok) {
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

// static WitnessSigOps(witversion, witprogram, witness).
CLINLINE uint32_t core_witness_sigops(uint32_t version, uint32_t prog_len,
                                      uint32_t stack_size, uint64_t w,
                                      uint32_t wit_len) {
  if (version != 0) return 0;
  if (prog_len == 20) return 1;
  if (prog_len != 32) return 0;
  if (stack_size == 0) return 0;  // witness.stack.size() > 0
  if (wit_len > LIMITS_MAX_SCRIPT_BYTES) return LIMITS_OUT_OF_DOMAIN;
  const LimitsScript s = limits_script(w, wit_len);
  return core_count(s, 0, wit_len, true);
}

}  // namespace

extern "C" uint32_t cell_witness_sigops(uint32_t version, uint32_t prog_len,
                                        uint32_t stack_size, uint64_t w,
                                        uint32_t wit_len) {
  return core_witness_sigops(version, prog_len, stack_size, w, wit_len);
}
