#include "w32_common.h"
#include "error_kind.h"

// C leg: line-cited source-excerpt slices of Bitcoin Core at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// VerifyScript's P2SH subscript call and its EVAL_FALSE checks
// (interpreter.cpp:2069-2086):
//
//   2069  swap(stack, stackCopy);
//   2074  assert(!stack.empty());
//   2076  const valtype& pubKeySerialized = stack.back();
//   2077  CScript pubKey2(pubKeySerialized.begin(), pubKeySerialized.end());
//   2078  popstack(stack);
//   2080  if (!EvalScript(stack, pubKey2, flags, checker, SigVersion::BASE, serror))
//   2081      return false;
//   2083  if (stack.empty())
//   2084      return set_error(serror, SCRIPT_ERR_EVAL_FALSE);
//   2085  if (!CastToBool(stack.back()))
//   2086      return set_error(serror, SCRIPT_ERR_EVAL_FALSE);
//
// The evaluated bytes are exactly `pubKeySerialized`, the last scriptSig
// stack element (the redeem script). This cell takes that element's bytes as
// the script, so the call target and the popped element are the same object
// -- the handoff itself is `exec-verify/C-L-p2sh-handoff`.
//
// EvalScript's per-instruction head, bounded to the leaf domain below
// (interpreter.cpp:449-493, 1231-1233):
//
//   449  for (; pc < pend; ++opcode_pos) {
//   455      if (!script.GetOp(pc, opcode, vchPushValue))
//   456          return set_error(serror, SCRIPT_ERR_BAD_OPCODE);
//   488      if (fExec && 0 <= opcode && opcode <= OP_PUSHDATA4) {
//   492      stack.push_back(vchPushValue);   (direct push)
//   493      } else if (fExec || ...)
//   494          switch (opcode) { ... }
//   1232     if (stack.size() + altstack.size() > MAX_STACK_SIZE)
//   1233         return set_error(serror, SCRIPT_ERR_STACK_SIZE);
//
// GetScriptOp's operand decoding (script.cpp:313-363) is transcribed by the
// parse cases: a direct push needs `opcode` payload bytes, PUSHDATA1/2/4 need
// 1/2/4 length bytes plus the payload, and an overrun is a parse failure
// (BAD_OPCODE at :456). OP_1NEGATE/OP_1..OP_16 push a CScriptNum
// (:499-523, push at :519): -1 -> 0x81, n -> 0x01..0x10. OP_RETURN is :677.
//
// LEAF DOMAIN (declared in spec.md, both legs return the out-of-model marker
// outside it). Subscript length 0..2, i.e. at most one parsed instruction:
//   len 0 : empty script
//   len 1 : 0x00 (OP_0), 0x4f (OP_1NEGATE), 0x51..0x60 (OP_1..OP_16),
//           0x6a (OP_RETURN), 0x01..0x4e (truncated push/PUSHDATA -> BAD_OPCODE)
//   len 2 : 0x01 b (direct 1-byte push), 0x4c 0x00 (PUSHDATA1 of zero bytes),
//           0x4c b>0 / 0x02..0x4b / 0x4d / 0x4e (truncated -> BAD_OPCODE)
// Anything else is out of model. The EvalScript loop is unrolled to one
// iteration because the leaf scripts contain at most one instruction.
//
// Sketch of the state: the eval stack is modelled by (depth, top element
// word, top element length); elements below the top are unobservable in this
// leaf (no instruction in the domain reads or pops them).

namespace {

struct BStack {
  uint64_t n;    // stack.size()
  uint64_t top;  // top element bytes (wire byte i at bits 8i..8i+7)
  uint64_t len;  // top element length
};

W32INLINE void bpush(BStack& s, uint64_t v, uint64_t l) {
  s.n += 1;
  s.top = v;
  s.len = l;
}

}  // namespace

extern "C" uint64_t cell_p2sh_subscript_leaf(uint64_t ss_depth, uint64_t ss_top,
                                             uint64_t ss_top_len,
                                             uint64_t prev_top, uint64_t prev_len) {
  // Cell domain guards. `ss_top_len > 2` is the bounded subscript; `prev_len
  // > 8` is the 8-byte element encoding bound; `ss_depth == 0` is Core's
  // assert(!stack.empty()) at :2074 (unreachable after a successful
  // scriptSig evaluation); `ss_depth > 1000` is outside EvalScript's stack
  // invariant (MAX_STACK_SIZE, :1231-1233).
  if (ss_top_len > 2 || prev_len > 8) {
    return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);
  }
  if (ss_depth < 1 || ss_depth > 1000) {
    return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);
  }

  const uint8_t op0 = (uint8_t)ss_top;         // pubKey2[0]
  const uint8_t op1 = (uint8_t)(ss_top >> 8);  // pubKey2[1]

  // swap(stack, stackCopy); popstack(stack): the redeem element is removed
  // and the element below it becomes the top.
  BStack stack{ss_depth - 1, prev_top, prev_len};

  bool pushed = false;
  uint64_t push_val = 0;
  uint64_t push_len = 0;
  uint64_t err = EQUIV_ERR_OK;

  if (ss_top_len == 0) {
    // Empty subscript: the loop body never runs.
  } else if (ss_top_len == 1) {
    // GetOp at script.cpp:327-359.
    if (op0 <= 0x4eu) {
      if (op0 == 0x00u) {
        pushed = true;  // OP_0: pushBytes(empty)
      } else {
        err = EQUIV_ERR_BAD_OPCODE;  // truncated push / PUSHDATA4 operands
      }
    } else if (op0 == 0x4fu) {
      pushed = true;  // OP_1NEGATE: CScriptNum(-1).getvch() == {0x81}
      push_val = 0x81u;
      push_len = 1;
    } else if (op0 >= 0x51u && op0 <= 0x60u) {
      pushed = true;  // OP_1..OP_16: CScriptNum(op0 - 0x50).getvch()
      push_val = (uint64_t)(op0 - 0x50u);
      push_len = 1;
    } else if (op0 == 0x6au) {
      err = EQUIV_ERR_OP_RETURN;  // interpreter.cpp:677
    } else {
      return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);  // outside the leaf
    }
  } else {  // ss_top_len == 2
    if (op0 == 0x01u) {
      pushed = true;  // direct 1-byte push (GetScriptOp nSize = 1)
      push_val = op1;
      push_len = 1;
    } else if (op0 == 0x4cu) {
      if (op1 == 0u) {
        pushed = true;  // PUSHDATA1 of zero bytes: pushBytes(empty)
      } else {
        err = EQUIV_ERR_BAD_OPCODE;  // PUSHDATA1 payload does not fit
      }
    } else if (op0 >= 0x02u && op0 <= 0x4bu) {
      err = EQUIV_ERR_BAD_OPCODE;  // direct push operand does not fit
    } else if (op0 == 0x4du || op0 == 0x4eu) {
      err = EQUIV_ERR_BAD_OPCODE;  // PUSHDATA2/4 length bytes do not fit
    } else {
      return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);  // second instruction
    }
  }

  if (err != EQUIV_ERR_OK) return w32_pack(0, err);
  if (pushed) {
    bpush(stack, push_val, push_len);
    // Post-op size limit, interpreter.cpp:1231-1233. With ss_depth <= 1000
    // this cannot fire (a pop followed by one push is net zero); it is kept
    // so the shape is Core's.
    if (stack.n > 1000) return w32_pack(0, EQUIV_ERR_STACK_SIZE);
  }

  // interpreter.cpp:2083-2086, on the stack EvalScript returned.
  if (stack.n == 0) return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  if (!w32_cast_bool_core(stack.top, stack.len)) {
    return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  }
  return w32_pack(1, EQUIV_ERR_OK);
}
