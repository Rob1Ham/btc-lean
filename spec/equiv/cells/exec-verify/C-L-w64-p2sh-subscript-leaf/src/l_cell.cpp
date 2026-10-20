#include "w32_common.h"
#include "error_kind.h"

// L leg: reviewed transliteration of the verified Lean model at
// spec/core/Bitcoin/Interpreter/Defs.lean, at the pin.
//
//   - `parseWire` (Defs.lean:421-431) / `getOp` (Script/Parser/Defs.lean:206).
//     `none` means a malformed (truncated) push; `evalScriptBytes` maps it to
//     `.error .badOpcode` (Defs.lean:1163-1171).
//   - `evalFrom` (Defs.lean:1144-1150): one `stepChecked` application over the
//     singleton op list, then `finalStack` (Defs.lean:1154-1156).
//     `stepBody` (Defs.lean:817-930) executes `pushBytes` / `pushNum` and
//     OP_RETURN (`w = 0x6a` -> `.error .opReturn`); `pushNum 0` is -1, whose
//     `encodeScriptNum` is {0x81} (`wireOfAst`, Defs.lean:441).
//     `stepChecked` (Defs.lean:1131-1136) applies MAX_STACK_SIZE after the op.
//   - `p2shInner` (Defs.lean:1327-1350): after
//     `evalScriptBytes fuel flags pol pubKey2 rest chk .base default`,
//     `if stack = [] ∨ !castToBool stack[0]! then .fail .evalFalse`.
//     The Lean stack has head = top (Defs.lean:34-37), so `stack[0]!` is the
//     top element and `rest` is the post-scriptSig stack minus the redeem
//     element.
//
// The shapes deliberately differ from the C leg: a parse record with an
// explicit `next` index (Lean's `getOp` result) and a separate one-step
// evaluator, the Lean `castToBoolList` (w32_cast_bool_lean), and the combined
// `empty ∨ !castToBool` predicate that `p2shInner` uses.
//
// LEAF DOMAIN (same as the C leg): subscript size 0..2, at most one parsed
// instruction. Everything else returns the out-of-model marker.

namespace l_w64_subscript {

// Lean `Except`/parse outcome classes. PK_PARSE_FAIL is `parseWire = none`.
enum : uint64_t {
  PK_EMPTY = 0,
  PK_PUSH = 1,
  PK_OP = 2,
  PK_PARSE_FAIL = 3,
  PK_OUT_OF_MODEL = 4
};

// Lean's `getOp : ByteArray -> Nat -> Option (Opcode × Nat)` lifted to the
// cell's 2-byte script encoding. `next` is the index the op ends at.
struct Parsed {
  uint64_t kind;
  uint64_t wire;
  uint64_t data;
  uint64_t data_len;
  uint64_t next;
};

// Lean `Stack` projection used after `finalStack`: head = top element.
struct Stack {
  uint64_t length;
  uint64_t top;
  uint64_t top_len;
};

W32INLINE Parsed parse_fail() {
  Parsed p{PK_PARSE_FAIL, 0, 0, 0, 0};
  return p;
}

W32INLINE Parsed out_of_model() {
  Parsed p{PK_OUT_OF_MODEL, 0, 0, 0, 0};
  return p;
}

W32INLINE Parsed parse_wire(uint64_t script, uint64_t size) {
  const uint64_t c = script & 0xffu;
  const uint64_t c2 = (script >> 8) & 0xffu;
  if (size == 0) {
    Parsed p{PK_EMPTY, 0, 0, 0, 0};  // parseWire = some []
    return p;
  }
  if (c == 0) {
    // getOpAux: 0x00 -> pushBytes empty, one byte consumed.
    Parsed p{PK_PUSH, 0, 0, 0, 1};
    return p;
  }
  if (c <= 0x4b) {
    // Direct push: one opcode byte plus `c` payload bytes.
    if (size < 1 + c) return parse_fail();
    Parsed p{PK_PUSH, 0, c2, c, 1 + c};
    return p;
  }
  if (c == 0x4c) {
    // PUSHDATA1: one length byte, then `n` payload bytes.
    if (size < 2) return parse_fail();
    const uint64_t n = c2;
    if (size < 2 + n) return parse_fail();
    Parsed p{PK_PUSH, 0, 0, n, 2 + n};
    return p;
  }
  if (c == 0x4d) {
    // PUSHDATA2: two length bytes, then the payload. Unreachable with the
    // leaf's 2-byte encoding, so the well-formed arm is out of model.
    if (size < 3) return parse_fail();
    return out_of_model();
  }
  if (c == 0x4e) {
    // PUSHDATA4: four length bytes, then the payload.
    if (size < 5) return parse_fail();
    return out_of_model();
  }
  if (c == 0x4f) {
    Parsed p{PK_OP, 0x4f, 0, 0, 1};  // Opcode.pushNum 0 (OP_1NEGATE)
    return p;
  }
  if (c >= 0x51 && c <= 0x60) {
    Parsed p{PK_OP, c, 0, 0, 1};  // Opcode.pushNum (c - 0x50)
    return p;
  }
  if (c == 0x6a) {
    Parsed p{PK_OP, 0x6a, 0, 0, 1};  // OP_RETURN
    return p;
  }
  // 0x50 OP_RESERVED and every other opcode need the real dispatch.
  return out_of_model();
}

W32INLINE void push_element(Stack& st, uint64_t value, uint64_t len) {
  st.length += 1;
  st.top = value;
  st.top_len = len;
}

W32INLINE uint64_t verify_subscript(uint64_t ss_depth, uint64_t ss_top,
                                    uint64_t ss_top_len, uint64_t prev_top,
                                    uint64_t prev_len) {
  if (ss_top_len > 2 || prev_len > 8) {
    return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);
  }
  if (ss_depth < 1 || ss_depth > 1000) {
    return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);
  }

  const Parsed p = parse_wire(ss_top, ss_top_len);
  if (p.kind == PK_OUT_OF_MODEL) {
    return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);
  }
  // `parseWire` parses the whole buffer; a second instruction is outside the
  // leaf, because the leaf is a single `stepChecked`.
  if (p.kind != PK_PARSE_FAIL && p.next != ss_top_len) {
    return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);
  }
  if (p.kind == PK_PARSE_FAIL) {
    return w32_pack(0, EQUIV_ERR_BAD_OPCODE);  // evalScriptBytes on none
  }

  // `rest` after p2shInner's split: stackCopy minus its head element.
  Stack st{ss_depth - 1, prev_top, prev_len};
  bool executed = false;

  if (p.kind == PK_PUSH) {
    // stepBody `.pushBytes d` (the d :: stack case).
    push_element(st, p.data, p.data_len);
    executed = true;
  } else if (p.kind == PK_OP) {
    executed = true;
    if (p.wire == 0x6a) {
      return w32_pack(0, EQUIV_ERR_OP_RETURN);  // stepBody: .error .opReturn
    }
    // stepBody `.pushNum n`: encodeScriptNum (-1 or n).
    const uint64_t num = (p.wire == 0x4f) ? 0x81u : (p.wire - 0x50u);
    push_element(st, num, 1);
  }
  // stepChecked: MAX_STACK_SIZE after the instruction.
  if (executed && st.length > 1000) {
    return w32_pack(0, EQUIV_ERR_STACK_SIZE);
  }
  // p2shInner tail: `stack = [] ∨ !castToBool stack[0]!`.
  if (st.length == 0 || !w32_cast_bool_lean(st.top, st.top_len)) {
    return w32_pack(0, EQUIV_ERR_EVAL_FALSE);
  }
  return w32_pack(1, EQUIV_ERR_OK);
}

}  // namespace l_w64_subscript

extern "C" uint64_t cell_p2sh_subscript_leaf(uint64_t ss_depth, uint64_t ss_top,
                                             uint64_t ss_top_len,
                                             uint64_t prev_top, uint64_t prev_len) {
  return l_w64_subscript::verify_subscript(ss_depth, ss_top, ss_top_len,
                                           prev_top, prev_len);
}
