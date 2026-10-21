#include "w32_common.h"
#include "error_kind.h"

// L leg: reviewed transliteration of the generated twin's parser and
// VerifyScript shape:
//   twin/runtime.inc:240-280  read_le / decode_op (GetOp boundary)
//   twin/runtime.inc:592-608  eval_script (validate then push)
//   twin/runtime.inc:781-805  verify_script_full (scriptSig then spk, same
//                             State; final stack truth)
// which mirror spec/core/Bitcoin/Script/Parser/Defs.lean getOp / parseWire and
// spec/core/Bitcoin/Interpreter/Defs.lean evalScriptBytes / verifyScriptFull
// (Defs.lean:1163-1178, 1363-1390).
//
// The payload contents are abstract; `truthy` is CastToBool of the pushed
// element.  The boundary arithmetic is the twin's own `size - i - prefix`
// form, deliberately a different expression from the C leg's
// `end - pc < nSize`.

namespace l_seq_boundary {

// twin/runtime.inc:240-247 -- read_le(b, size, at, width, out), unrolled for
// the three widths so the extracted leaf carries no jump table.
W32INLINE bool read_le(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3,
                       uint64_t size, uint64_t at, uint64_t width,
                       uint64_t& out) {
  if (at > size || width > size - at) return false;
  if (width == 1) {
    out = b0;
    return true;
  }
  if (width == 2) {
    out = (uint64_t)b0 | ((uint64_t)b1 << 8);
    return true;
  }
  out = (uint64_t)b0 | ((uint64_t)b1 << 8) | ((uint64_t)b2 << 16) |
        ((uint64_t)b3 << 24);
  return true;
}

// twin/runtime.inc:250-280 -- decode_op(b, size, i, d), boundary decision.
W32INLINE bool decode_boundary(uint8_t op, uint8_t b0, uint8_t b1, uint8_t b2,
                               uint8_t b3, uint64_t size, uint64_t i) {
  if (i >= size) return false;
  if (op == 0x00) return true;                 // PushBytes empty
  if (op <= 0x4b) {
    // runtime.inc:261 -- if (c > size - (i + 1)) return false;
    return !(op > size - (i + 1));
  }
  if (op == 0x4c || op == 0x4d || op == 0x4e) {
    // runtime.inc:263 -- width = 1 / 2 / 4 for OP_PUSHDATA1/2/4.  Written as
    // a shift so the extracted leaf carries no switch table.
    const uint64_t width = 1u << (op - 0x4c);
    uint64_t k = 0;
    if (!read_le(b0, b1, b2, b3, size, i + 1, width, k)) return false;
    const uint64_t prefix = 1u + width;
    // runtime.inc:272 -- if (prefix > size - i || k > size - i - prefix)
    if (prefix > size - i) return false;
    if (k > size - i - prefix) return false;
    return true;
  }
  return true;                                 // PushNum / Op: next = i+1
}

// Length-prefix width of the canonical push encoding (0 / 1 / 2 bytes).
W32INLINE uint64_t header_len(uint64_t declared) {
  if (declared <= 75) return 0;
  if (declared <= 0xff) return 1;
  return 2;
}

// canonical push header of `declared` bytes; declared <= 10000 -> direct,
// PUSHDATA1 or PUSHDATA2 (identical table to the C leg, different code shape).
W32INLINE void length_header(uint64_t declared, uint8_t& op, uint8_t& b0,
                             uint8_t& b1) {
  // See the C leg: masking before narrowing keeps clang from hoisting an
  // out-of-range `trunc nuw` out of the declared <= 75 branch.
  const uint8_t lo = static_cast<uint8_t>(declared & 0xffu);
  const uint8_t hi = static_cast<uint8_t>((declared >> 8) & 0xffu);
  if (declared <= 75) {
    op = lo;
    b0 = 0;
    b1 = 0;
  } else if (declared <= 0xff) {
    op = 0x4c;
    b0 = lo;
    b1 = 0;
  } else {
    op = 0x4d;
    b0 = lo;
    b1 = hi;
  }
}

// twin/runtime.inc:592-608 -- eval_script over one complete push; the
// observable is the resulting stack (one element).
struct State {
  uint64_t n;
  uint64_t top;
  uint64_t top_len;
};

W32INLINE bool eval_one_push(uint64_t declared, uint64_t present,
                             uint64_t truthy, State& st) {
  uint8_t op, b0, b1;
  length_header(declared, op, b0, b1);
  // The buffer is the opcode, the length prefix and the payload bytes that
  // are actually present: size = 1 + header_len + present.
  const uint64_t size = 1 + header_len(declared) + present;
  if (!decode_boundary(op, b0, b1, 0, 0, size, 0)) return false;
  st.n = 1;
  st.top = truthy;
  st.top_len = 1;                              // abstract 1-byte payload
  return true;
}

// twin/runtime.inc:781-805 -- empty/false top fails; else OK.
W32INLINE uint64_t final_verdict(const State& st) {
  if (st.n == 0) return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  return w32_cast_bool_lean(st.top, st.top_len) ? w32_pack(1, EQUIV_ERR_OK)
                                                : w32_pack(0, EQUIV_ERR_EVAL_FALSE);
}

W32INLINE uint64_t pair(uint64_t seq, uint64_t cat) {
  return (seq & 0xffu) | (((seq >> 2) & 0x3fu) << 8) | ((cat & 0xffu) << 16) |
         (((cat >> 2) & 0x3fu) << 24);
}

W32INLINE uint64_t split_pair(uint64_t declared, uint64_t after_op,
                              uint64_t truthy) {
  if (declared == 0 || declared > 10000 || after_op > declared || truthy > 1) {
    return 2;
  }
  // MAX_SCRIPT_SIZE pre-check (interpreter.cpp:419-421) on the larger,
  // concatenated buffer: 1 opcode + length prefix + declared payload bytes.
  if (1 + header_len(declared) + declared > 10000) return 2;
  // Sequential eval_script(scriptSig): only `after_op` payload bytes present.
  State ss{};
  const uint64_t seq = eval_one_push(declared, after_op, truthy, ss)
                           ? final_verdict(ss)
                           : w32_pack(0, EQUIV_ERR_BAD_OPCODE);
  // Concatenated eval_script(scriptSig ++ scriptPubKey): the spk supplies
  // the missing payload bytes, so all `declared` payload bytes are present.
  State cat{};
  const uint64_t cat_verdict = eval_one_push(declared, declared, truthy, cat)
                                   ? final_verdict(cat)
                                   : w32_pack(0, EQUIV_ERR_BAD_OPCODE);
  return pair(seq, cat_verdict);
}

}  // namespace l_seq_boundary

extern "C" uint64_t cell_push_boundary(uint8_t op, uint8_t b0, uint8_t b1,
                                       uint8_t b2, uint8_t b3,
                                       uint64_t after_op) {
  if (after_op > 10000) return 2;              // MAX_SCRIPT_SIZE pre-check
  const uint64_t size = 1 + after_op;          // whole scriptSig buffer
  return l_seq_boundary::decode_boundary(op, b0, b1, b2, b3, size, 0) ? 0 : 1;
}

extern "C" uint64_t cell_split_verdict(uint64_t declared, uint64_t after_op,
                                       uint64_t truthy) {
  return l_seq_boundary::split_pair(declared, after_op, truthy);
}

extern "C" uint64_t cell_split_diff(uint64_t declared, uint64_t after_op,
                                    uint64_t truthy) {
  const uint64_t v = l_seq_boundary::split_pair(declared, after_op, truthy);
  if (v == 2) return 2;
  const uint64_t seq = (v & 0xffu) | (((v >> 8) & 0x3fu) << 2);
  const uint64_t cat = ((v >> 16) & 0xffu) | (((v >> 24) & 0x3fu) << 2);
  return (seq != cat) ? 1 : 0;
}

extern "C" uint64_t cell_verify_tail(uint64_t trunc, uint64_t word, uint64_t len,
                                     uint64_t kind) {
  using namespace l_seq_boundary;
  if (trunc > 1 || len > 8 || kind > 2) return 2;
  // runtime.inc:793-798 -- eval_script(scriptSig) failed -> return.
  if (trunc == 1) return w32_pack(0, EQUIV_ERR_BAD_OPCODE);
  // runtime.inc:799 -- eval_script(scriptPubKey) on the SAME State.
  State st{1, word, len};
  if (kind == 1) {                             // OP_1 -> st_push_num(1)
    st.n = 2;
    st.top = 1;
    st.top_len = 1;
  } else if (kind == 2) {                      // OP_0 -> st_push(empty)
    st.n = 2;
    st.top = 0;
    st.top_len = 0;
  }
  return final_verdict(st);
}
