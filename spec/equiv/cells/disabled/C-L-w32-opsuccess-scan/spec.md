---
# Cell disabled/C-L-w32-opsuccess-scan
contract: b547fafb5fc5a6c3370f916d800418db37dec7c78d88fc4cd209a436a6a6e187
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: disabled/C-L-w32-opsuccess-scan
family: disabled-opcodes
tool_status: both-green (symbolic, all 2^8 map bytes; all 2^16 opcode pairs x flag)
precondition: |
  - cell_isopsuccess: `w` is any wire byte 0x00..0xff; no script context.
  - cell_scan: a tapscript whose bytes are exactly two non-push opcodes
    (w0, w1 >= 0x4f), so GetOp consumes one byte per opcode and cannot fail.
    `discourage` is the DISCOURAGE_OP_SUCCESS policy flag (bit 0).
  - the surrounding ExecuteWitnessScript stack/item checks are not modelled;
    the pre-scan is the first thing that runs on the tapscript path.
postcondition: |
  - cell_isopsuccess(w) = 1 iff w is in script.cpp:365-371's set:
    {80, 98, 126-129, 131-134, 137-138, 141-142, 149-153, 187-254}.
  - cell_scan(w0,w1,discourage):
      0   (OK) when a success byte is found and the policy flag is clear;
      36  (DISCOURAGE_OP_SUCCESS) when found and the flag is set;
      66  when neither byte is a success byte (scan completes, EvalScript runs);
      254 when either byte is a push byte (outside the declared domain).
    The first success byte wins; a success at w0 makes w1 irrelevant.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-172
scr_row_coverage: >-
  partial. (a) The wire mapping is full: IsOpSuccess is proved over every
  byte 0x00..0xff, including all fifteen disabled bytes. (b) The success
  mechanism is proved for scripts of exactly two non-push opcodes: the scan
  returns success at the first success byte, in either position, before any
  evaluation, with the DISCOURAGE_OP_SUCCESS policy arm. Not machine-checked:
  the n-opcode induction for arbitrary script length (the scan is a fold of
  the same per-byte predicate), push-payload decode ordering (F-DIV-001), and
  the rest of ExecuteWitnessScript (item/stack limits, annex, control block),
  which is SCR-153/157/168 territory.
patches: none
source_citations:
  - script.cpp:365-371 (IsOpSuccess)
  - interpreter.cpp:1846-1862 (ExecuteWitnessScript OP_SUCCESSx pre-scan)
  - BIP342 OP_SUCCESSx numbering: the fifteen disabled bytes occupy
    OP_SUCCESS126..OP_SUCCESS153 (126-129, 131-134, 137-138, 141-142,
    149-153); 0x7e is OP_SUCCESS126 and 0x99 is OP_SUCCESS153
  - Defs.lean:463-466 (isOpSuccessWire)
  - Defs.lean:468-490 (opSuccessScanFrom)
  - Defs.lean:1207-1216 (executeWitnessScript tapscript arm)
  - PDW93.lean:16-40 (isOpSuccessWire_iff/matrix row face)
trust_note: >
  C is a line-cited source-excerpt slice: IsOpSuccess verbatim plus the
  pre-scan specialised to two non-push opcodes. L is a literal transcription
  of the Lean definitions isOpSuccessWire/opSuccessScanFrom and the
  executeWitnessScript tapscript arm; the twin's generated dispatch table has
  no pre-scan handler because the scan runs before EvalScript. Both sides are
  compared by Alive2 over symbolic bytes and independently checked against a
  Cryptol predicate by SAW. No hash/crypto/tx context is involved. The
  DISCOURAGE_OP_SUCCESS mapping is contract error 36; the "success" result is
  the .ok/true path, not a whole verification verdict.
---
