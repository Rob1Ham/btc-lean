---
# Cell numeric/C-L-scriptnum-sign
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c02
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: numeric/C-L-scriptnum-sign
family: numeric
tool_status: both-green
precondition: |
  Pure CScriptNum byte<->number map; no EvalScript flag is read by either
  function, so the cell models the two script.h routines directly.

  Bounded leaf (wave-16 numeric harness): element width 8 bytes, stack depth 4.
  Four entry points:

  - cell_decode(w, lb): w is a symbolic 64-bit content word (bytes 0..7 in
    little-endian order), lb symbolic 32-bit, decoded length = lb & 7 (0..7).
    The CScriptNum width guard is deliberately off: the C leg calls set_vch
    directly and the L leg calls decode_num with maxSize = 8, minimal = false,
    so this cell observes the sign-magnitude map rather than SCR-079/080's
    length reject.
  - cell_encode(mag, neg): mag is a symbolic 64-bit word masked to its low 32
    bits, neg a symbolic 32-bit word of which bit 0 is used; the value is
    v = -mag (neg odd) or +mag.  Domain: |v| <= 2^32-1, the closure of the
    numeric-op operand domain (a 4-byte CScriptNum has |v| <= 2^31-1; OP_ADD
    or OP_SUB of two of them reaches 2^32-2).  Serialization of such a value
    is at most 5 bytes, which fits the 8-byte leaf.
  - cell_encode_decode(mag, neg): same domain; observable is the value
    recovered by decoding the bytes just serialized.
  - cell_roundtrip(w, lb): same w, length = lb & 3 (0..4), every legal
    4-byte CScriptNum operand; decode then re-encode.
postcondition: |
  cell_decode returns the int64 bit pattern produced by set_vch:

  - length 0 -> 0;
  - sign iff bit 0x80 of the most significant (wire-last) byte is set;
  - magnitude = the low seven bits of that byte (in its wire position) plus
    all lower bytes, little-endian;
  - a sign bit over a zero magnitude is a negative-zero wire form and decodes
    to the integer 0 (e.g. 0x80 at length 1, 00 80 at length 2).

  For every (w, length) the C result, the L decode_num result and the
  independent model (src/sign.cry:decode) are equal.

  cell_encode returns len(4) << 0 | b0 << 4 | b1 << 12 | b2 << 20 |
  b3 << 28 | b4 << 36 (44-bit observable), where the bytes are
  CScriptNum::serialize(|v|, sign):

  - 0 serializes to the empty vector (len 0; there is no canonical -0);
  - if the magnitude's most significant byte has bit 7 set, a fresh 0x80
    (negative) / 0x00 (positive) byte is appended;
  - otherwise the sign bit 0x80 is OR-ed into the most significant magnitude
    byte for negative values.

  For every value in the domain the C serialize result, the L encode_num
  result and src/sign.cry:encPackV are equal.

  cell_encode_decode returns v bit-for-bit: the fresh-sign-byte and OR-ed-sign
  forms are both recovered by the decoder.

  cell_roundtrip returns encPackV(decode(w, length)): decoding any 4-byte
  operand and re-encoding it is the canonicalizer, and every negative-zero
  operand (0x80, 00 80, 00 00 80, ...) returns length 0 (the empty vector).

  Directions: Alive2 is run c->l and l->c for all four entry points; SAW
  verifies the C module and the L module separately against the same model.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-082
scr_row_coverage: >-
  full for the bounded leaf — encode and decode, both directions.  Decode is
  total over every byte string of length 0..7 (w symbolic over 2^64 per
  length), which includes every negative-zero wire form in the element.
  Encode is total over the value domain |v| <= 2^32-1, which contains every
  value a numeric opcode can serialize; encode->decode is proved to be the
  identity on that domain and decode->encode is proved to be the canonical
  encoder on every 4-byte operand.  Not covered here: the width guard
  (SCR-079/080) and the minimal-encoding reject including its negative-zero
  instance (SCR-083/084); those rows have their own cells, and selecting
  them is not claimed by this cell.  The observable for decode is the int64
  value, so this cell does not additionally pin CastToBool(0x80) (SCR-083).
patches: none
source_citations:
  - src/script/script.h:342-373 (CScriptNum::serialize)
  - src/script/script.h:376-391 (set_vch sign-magnitude decode)
  - src/script/script.h:337-340 (getvch)
  - spec/core/Bitcoin/Numeric/ScriptNum.lean:385-423 (encodeSignBE, magBE)
  - spec/core/Bitcoin/Numeric/ScriptNum.lean:449-467 (setVchBE, setVchBE_neg_zero,
    setVchBE_encodeSignBE)
  - spec/core/Bitcoin/Numeric/Interface.lean:45-56 (decodeScriptNum /
    encodeScriptNum), :306-308 (decodeScriptNum_value = setVchBE)
  - spec/equiv/twin/runtime.inc:141-191 (L encode_num / decode_num)
trust_note: >
  C is the line-cited bounded transcription in the shared wave-16 numeric
  tooling (num_core.h: set_vch, serialize), not the whole EvalScript and not
  a whole-engine equivalence proof.  The transcription replaces the
  std::vector with an 8-byte element, the scriptnum_error throw with an error
  return, and unrolls the loops; the byte semantics are unchanged and both
  functions are called directly (no case block is sliced in).  L is the
  twin/runtime.inc encode_num/decode_num bodies unrolled to an 8-byte element
  by findings/wave16/07-numeric-ops/tools/mk_num_leaf.py from twin/ops_ir.py
  + runtime.inc.  SAW checks each leg against src/sign.cry, a model written
  separately from script.h and the Lean equations in Numeric/ScriptNum.lean;
  it is not generated from either leg.  Alive2 compares the clang-20 -O2
  extracts directly.  No Core source patch is used.  The harness is a bounded
  leaf: element 8 bytes, decode length 0..7, encode |v| <= 2^32-1,
  roundtrip length 0..4 (see notes.md for why each bound is outside every
  consensus-relevant CScriptNum path in this cell).
---
