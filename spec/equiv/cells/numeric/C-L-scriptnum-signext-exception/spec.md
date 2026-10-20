---
# Cell numeric/C-L-scriptnum-signext-exception
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: numeric/C-L-scriptnum-signext-exception
family: numeric
tool_status: both-green (symbolic over the rank-8 magnitude and sign, and over all one- and two-byte payloads)
precondition: |
  - fRequireMinimal = true and nMaxNumSize = 4, the numeric-op default.
  - roundtrip entry point (`cell_signext_roundtrip`): value = +-m for a
    symbolic rank-8 magnitude m (0..255) and a symbolic sign bit.  m = 0 is
    the value 0 and serializes empty, as in Core.
  - predicate entry point (`cell_signext_pred`): the payload length selector
    is 1 or 2 and both payload bytes are symbolic.  Lengths > 2 are outside
    this row (the exception only inspects the two most-significant bytes);
    they are not claimed.
postcondition: |
  - roundtrip: for every magnitude m and sign, C `serialize` and L
    `encode_num` agree on the exact wire bytes and length:
      m = 0             -> n = 0 (empty)
      1 <= m < 128      -> n = 1, byte m, with 0x80 set iff negative
      128 <= m <= 255   -> n = 2, bytes (m, 0x00) positive and (m, 0x80)
                           negative.  Hence +255 -> 0xff00 and
                           -255 -> 0xff80 (little-endian on the wire).
    The real constructor guard accepts every one of these encodings and
    `set_vch` returns +-m, so both named vectors are minimal and round-trip.
    The counterfactual no-exception guard accepts exactly the m < 128
    encodings and rejects every sign-extension encoding (m >= 128): the
    "more than one byte and previous 0x80 set" clause is exactly what admits
    +-255.
  - predicate: for all one- and two-byte payloads (b0, b1), real acceptance
    is
      (top byte & 0x7f) != 0  or  (n = 2 and (b0 & 0x80) != 0),
    while the no-exception guard accepts iff (top byte & 0x7f) != 0.  Thus
    0xff00 and 0xff80 evaluate real=1, strict=0, and 0x7f00 evaluates
    real=0 (the exception requires the predecessor's high bit, not merely a
    second byte).
  - the packed observer is bit-identical on both legs; see src/c_leaf.cpp
    for the field layout.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-084
scr_row_coverage: >-
  full for the row as stated.  SCR-084 is the CScriptNum minimality
  sign-extension exception (script.h:259-268): +255 and -255 encode to
  0xff00/0xff80 and both are minimal, and the extra byte is required by the
  sign.  The cell proves this over the whole rank-8 magnitude domain, with
  the two named vectors as the m = 255 instances, and additionally proves
  that the exception clause (rather than merely the top-byte test) is what
  admits them, by evaluating the same payloads against the guard with the
  clause removed.  Bounds: |value| <= 255 and payload length <= 2;
  fRequireMinimal is fixed true.  The flag-off decode is SCR-050's cell;
  negative zero is SCR-083; widths/lengths above 2 and the numeric opcode
  call sites are not part of this row's statement and are not claimed here.
patches: none
source_citations:
  - script.h:246-271 (CScriptNum constructor; exception comment/guard 259-268)
  - script.h:342-373 (serialize/getvch, sign-extension byte)
  - script.h:376-391 (set_vch sign-magnitude decode)
  - interpreter.cpp:415-427 (CScriptNum::getvch)
  - Numeric/Interface.lean:45-54 (decodeScriptNum, encodeScriptNum)
  - Numeric/Interface.lean:222-231 (scriptNum_sign_extension_255, the Lean row target)
  - Numeric/ScriptNum.lean:493-500 (minimalOkBE), 534 (scriptNumBE)
  - twin/runtime.inc:141-157 (encode_num), 167-188 (decode_num)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.h at the
  pin.  L is a bounded transcription of the generated twin's encode_num /
  decode_num (twin/runtime.inc), which mirror Lean's encodeScriptNum /
  decodeScriptNum; the certificate pins runtime.inc so the transcription can
  be reviewed.  Both encoder and decoder loops are written as their single
  iteration bodies under the closed cell domain (0 < magnitude < 256,
  payload <= 2 bytes); guards, sign extension and value assembly are
  verbatim.  The `strict` bit is counterfactual harness, not engine code: it
  evaluates the minimality guard with the exception clause removed, and the
  real acceptance bit is produced by the actual decode routine.  Alive2
  checks C vs L bidirectionally; SAW checks each leg against the independent
  Cryptol model in src/cell.cry.  No Core, Lean, twin or contract patch is
  used.
---
