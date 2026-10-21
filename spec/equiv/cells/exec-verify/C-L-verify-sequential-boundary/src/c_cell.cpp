#include "w32_common.h"
#include "error_kind.h"

// The canonical encoding's length-prefix width (bytes) for a declared payload
// length: 0 for a direct push, 1 for OP_PUSHDATA1, 2 for OP_PUSHDATA2.
W32INLINE uint64_t c_header_len(uint64_t declared) {
  if (declared <= 75) return 0;
  if (declared <= 0xff) return 1;
  return 2;
}

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp and src/script/script.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Slices:
//   script.cpp:313-363        GetScriptOp -- the script-buffer boundary.
//   interpreter.cpp:455-456   EvalScript: GetOp failure -> BAD_OPCODE.
//   interpreter.cpp:419-421   EvalScript script-size pre-check.
//   interpreter.cpp:2026-2040 VerifyScript: scriptSig then scriptPubKey,
//                             same stack, first error wins, final truth on
//                             the stack the second evaluation produced.
//
// The point of the cell is the CVE-2010-5141 distinction that the earlier
// exec-verify cells declared as their one residual: a push in scriptSig whose
// declared payload length runs past the *end of the scriptSig buffer*.
// Sequentially, GetScriptOp is handed `end = scriptSig.end()` and rejects the
// push; a concatenation of scriptSig ++ scriptPubKey would hand it the larger
// end and accept the same bytes.
//
// Exports:
//   cell_push_boundary  -- Core's GetScriptOp boundary decision for one push
//                          header, complete over the declared length.
//   cell_split_verdict  -- sequential vs concatenated verdict for the
//                          straddling-push family.
//   cell_verify_tail    -- VerifyScript call order / stack handoff / final
//                          truth for a complete scriptSig push.

// ---------------------------------------------------------------------------
// script.cpp:313-363 -- GetScriptOp.  `op` is the opcode byte and
// `after_op = end - pc` is measured after the opcode has been read
// (script.cpp:324 `unsigned int opcode = *pc++;`).
// Returns 0 when GetScriptOp succeeds, 1 when it returns false.
// ---------------------------------------------------------------------------
W32INLINE uint64_t c_push_boundary(uint8_t op, uint8_t b0, uint8_t b1,
                                   uint8_t b2, uint8_t b3, uint64_t after_op) {
  if (op <= 0x4e) {                    // opcode <= OP_PUSHDATA4
    unsigned int nSize = 0;
    if (op < 0x4c) {
      // script.cpp:332-334 -- direct push: nSize = opcode (OP_0 -> 0).
      nSize = (unsigned int)op;
    } else if (op == 0x4c) {
      // script.cpp:335-340 -- OP_PUSHDATA1.
      if (after_op < 1) return 1;      // end - pc < 1
      nSize = (unsigned int)b0;
      after_op -= 1;
    } else if (op == 0x4d) {
      // script.cpp:341-347 -- OP_PUSHDATA2 (ReadLE16).
      if (after_op < 2) return 1;      // end - pc < 2
      nSize = (unsigned int)b0 | ((unsigned int)b1 << 8);
      after_op -= 2;
    } else {
      // script.cpp:348-354 -- OP_PUSHDATA4 (ReadLE32).
      if (after_op < 4) return 1;      // end - pc < 4
      nSize = (unsigned int)b0 | ((unsigned int)b1 << 8) |
              ((unsigned int)b2 << 16) | ((unsigned int)b3 << 24);
      after_op -= 4;
    }
    // script.cpp:355-356:
    //   if (end - pc < 0 || (unsigned int)(end - pc) < nSize) return false;
    // In domain end - pc <= MAX_SCRIPT_SIZE, so the cast is exact.
    if (after_op < (uint64_t)nSize) return 1;
    return 0;
  }
  return 0;                            // opcode > OP_PUSHDATA4: no operand
}

W32INLINE uint64_t c_pack(uint32_t result, uint32_t error) {
  return w32_pack(result, error);
}

W32INLINE uint64_t c_pair(uint64_t seq, uint64_t cat) {
  // bits 0-7 seq_result, 8-15 seq_err, 16-23 cat_result, 24-31 cat_err
  return (seq & 0xffu) | (((seq >> 2) & 0x3fu) << 8) | ((cat & 0xffu) << 16) |
         (((cat >> 2) & 0x3fu) << 24);
}

// The canonical push encoding of `declared` bytes (CheckMinimalPush form):
// the same header the family puts at the head of scriptSig.  declared <=
// 10000 in this cell, so only direct / PUSHDATA1 / PUSHDATA2 occur.
W32INLINE void c_length_header(uint64_t declared, uint8_t& op, uint8_t& b0,
                               uint8_t& b1) {
  // Mask before narrowing.  A bare (uint8_t)declared lets clang hoist a
  // `trunc nuw` out of the branch (it is only in range under declared <= 75),
  // which is poison for a large declared; the mask makes the narrowing sound
  // on every path.
  const uint8_t lo = (uint8_t)(declared & 0xffu);
  const uint8_t hi = (uint8_t)((declared >> 8) & 0xffu);
  if (declared <= 75) {
    op = lo;
    b0 = 0;
    b1 = 0;
  } else if (declared <= 0xff) {
    op = 0x4c;                         // OP_PUSHDATA1
    b0 = lo;
    b1 = 0;
  } else {
    op = 0x4d;                         // OP_PUSHDATA2
    b0 = lo;
    b1 = hi;
  }
}

// ---------------------------------------------------------------------------
// Sequential vs concatenated verdict, straddling-push family.
//
// Family: scriptSig is the canonical push of `declared` payload bytes, but
// only `after_op` payload bytes are present before the scriptSig buffer ends.
// scriptPubKey is the remaining `declared - after_op` bytes, i.e. exactly the
// bytes a concatenated parse would consume.  `truthy` is CastToBool of the
// pushed element (abstract: payload byte semantics are SCR-057, not this row).
// ---------------------------------------------------------------------------
W32INLINE uint64_t c_split_pair(uint64_t declared, uint64_t after_op,
                                uint64_t truthy) {
  if (declared == 0 || declared > 10000 || after_op > declared || truthy > 1) {
    return 2;
  }
  const uint64_t hdr = c_header_len(declared);
  // interpreter.cpp:419-421 -- EvalScript rejects a script longer than
  // MAX_SCRIPT_SIZE before the loop.  The concatenated buffer (the larger
  // one) is 1 opcode + hdr + declared payload bytes; if it is already over
  // the limit the family is out of domain.
  if (1 + hdr + declared > 10000) return 2;
  uint8_t op, b0, b1;
  c_length_header(declared, op, b0, b1);
  // Sequential: scriptSig.end() is 1 + hdr + after_op bytes in; `end - pc`
  // after the opcode byte is hdr + after_op.
  const bool seq_fits =
      (c_push_boundary(op, b0, b1, 0, 0, hdr + after_op) == 0);
  // Concatenated: scriptPubKey supplies the remaining declared - after_op
  // bytes, so the buffer is 1 + hdr + declared bytes and `end - pc` after the
  // opcode byte is hdr + declared.
  const bool cat_fits =
      (c_push_boundary(op, b0, b1, 0, 0, hdr + declared) == 0);
  // interpreter.cpp:2037-2040 -- decision on the pushed element.
  const uint64_t ok = c_pack(1, EQUIV_ERR_OK);
  const uint64_t eval_false = c_pack(0, EQUIV_ERR_EVAL_FALSE);
  const uint64_t elem = truthy ? ok : eval_false;
  // interpreter.cpp:456 -- GetOp failure -> BAD_OPCODE, evaluation stops.
  const uint64_t bad = c_pack(0, EQUIV_ERR_BAD_OPCODE);
  return c_pair(seq_fits ? elem : bad, cat_fits ? elem : bad);
}

W32INLINE uint64_t c_split_verdict(uint64_t declared, uint64_t after_op,
                                   uint64_t truthy) {
  return c_split_pair(declared, after_op, truthy);
}

// The row's distinction on its own: 1 iff the sequential and concatenated
// verdicts differ.  Derived from the two packed verdicts, not restated.
W32INLINE uint64_t c_split_diff(uint64_t declared, uint64_t after_op,
                                uint64_t truthy) {
  const uint64_t v = c_split_pair(declared, after_op, truthy);
  if (v == 2) return 2;
  const uint64_t seq = (v & 0xffu) | (((v >> 8) & 0x3fu) << 2);
  const uint64_t cat = ((v >> 16) & 0xffu) | (((v >> 24) & 0x3fu) << 2);
  return (seq != cat) ? 1 : 0;
}

// ---------------------------------------------------------------------------
// VerifyScript order + stack handoff + final truth for a complete scriptSig
// push.  `trunc` = the scriptSig push was rejected (EvalScript -> BAD_OPCODE).
// `word`/`len` = the single element the scriptSig left on the stack (0..8
// bytes, the sibling cells' encoding).  `kind` names scriptPubKey:
//   0 = empty script  (identity: decision on the scriptSig stack)
//   1 = OP_1 0x51     (pushes true; decision on the spk stack)
//   2 = OP_0 0x00     (pushes empty -> EVAL_FALSE)
// ---------------------------------------------------------------------------
W32INLINE uint64_t c_verify_tail(uint64_t trunc, uint64_t word, uint64_t len,
                                 uint64_t kind) {
  if (trunc > 1 || len > 8 || kind > 2) return 2;
  // interpreter.cpp:2029-2031 -- EvalScript(scriptSig) failed; scriptPubKey
  // is never evaluated.
  if (trunc == 1) return c_pack(0, EQUIV_ERR_BAD_OPCODE);
  // interpreter.cpp:2034-2036 -- EvalScript(scriptPubKey) on the SAME stack.
  if (kind == 0) {
    return w32_cast_bool_core(word, len) ? c_pack(1, EQUIV_ERR_OK)
                                         : c_pack(0, EQUIV_ERR_EVAL_FALSE);
  }
  if (kind == 1) return c_pack(1, EQUIV_ERR_OK);   // OP_1 -> top {1}
  return c_pack(0, EQUIV_ERR_EVAL_FALSE);          // OP_0 -> top empty
}

extern "C" uint64_t cell_push_boundary(uint8_t op, uint8_t b0, uint8_t b1,
                                       uint8_t b2, uint8_t b3,
                                       uint64_t after_op) {
  // interpreter.cpp:419-421 rejects scripts > MAX_SCRIPT_SIZE = 10000 before
  // the loop, so GetScriptOp is only reached with after_op <= 10000.
  if (after_op > 10000) return 2;
  return c_push_boundary(op, b0, b1, b2, b3, after_op);
}

extern "C" uint64_t cell_split_verdict(uint64_t declared, uint64_t after_op,
                                       uint64_t truthy) {
  return c_split_verdict(declared, after_op, truthy);
}

extern "C" uint64_t cell_split_diff(uint64_t declared, uint64_t after_op,
                                    uint64_t truthy) {
  return c_split_diff(declared, after_op, truthy);
}

extern "C" uint64_t cell_verify_tail(uint64_t trunc, uint64_t word, uint64_t len,
                                     uint64_t kind) {
  return c_verify_tail(trunc, word, len, kind);
}
