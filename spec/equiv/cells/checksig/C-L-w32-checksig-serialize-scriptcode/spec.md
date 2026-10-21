---
# Cell checksig/C-L-w32-checksig-serialize-scriptcode
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: the pinned rbitcoin render/error path is documented non-proof (F-HARNESS-002, F-TOOL-001)"
cell: C-L-w32-checksig-serialize-scriptcode
family: checksig
tool_status: both-green (bounded symbolic source slice + closed scenarios)
precondition: |
  - scriptCode is exactly six bytes; every byte is symbolic.  It is a source
    slice of the bytes handed to CTransactionSignatureSerializer::
    SerializeScriptCode, not a whole transaction or sighash preimage.
  - The CompactSize prefix is the one-byte form (size ≤ 6), so the observable
    prefix is exactly size - number_of_parsed_OP_CODESEPARATORs.
  - The reachable scriptCode is fully parseable: EvalScript rejects a
    malformed push with BAD_OPCODE before any CHECKSIG can build scriptCode.
    The cell therefore abstains (sentinel 0xFFFFFFFFFFFFFFFF) on a malformed
    walk instead of modelling Core's writer-advances-pc tail behaviour; those
    inputs are outside the equivalence claim.
  - No tx fields, hash type, hash function or crypto routine is involved.
postcondition: |
  - prefix = 6 - nsep, where nsep counts parsed 1-byte OP_CODESEPARATOR
    opcodes (0xab) over the successfully parsed prefix.
  - out is the script with each parsed 0xab removed.  Bytes of a push payload
    (including direct pushes, PUSHDATA1, PUSHDATA2 and PUSHDATA4) are copied
    verbatim even when they equal 0xab.  After the last splice point, the
    remaining bytes are copied verbatim.
  - outn = length of the emitted body.  Both legs agree on (prefix, out) for
    every fully parseable input in the domain; malformed inputs return the
    shared sentinel in both legs and are outside the equivalence claim.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-101
scr_row_coverage: full — parsed 1-byte 0xab removals are exercised at offset 0,
  mid-script, at the end, twice and three times, and for an all-separator
  script (empty body, prefix 0).  0xab retention is exercised inside a direct
  push payload, a PUSHDATA1 payload, a PUSHDATA2 payload and a PUSHDATA4
  payload.  Malformed-tail abstention is exercised both before any separator
  and after a parsed separator (sentinel in both legs, outside the claim).
  Bounded to six bytes; every branch/edge named by SCR-101 is present.
coverage: full
patches: none
source_citations:
  - "interpreter.cpp:1282-1302 (SerializeScriptCode: count parsed OP_CODESEPARATORs; write CompactSize(size - n); splice each parsed 0xab; copy tail)"
  - "interpreter.cpp:1317 (scriptCode serialization call site)"
  - "script.cpp:313-363 (CScript::GetOp)"
  - "spec/core/Bitcoin/SigHash/Ops.lean:50-78 (getOpAt / walkOps)"
  - "spec/core/Bitcoin/SigHash/Ops.lean:133-141 (serializeScriptCodeL)"
  - "spec/core/Bitcoin/SigHash/Interface.lean:105-125 (SCR-101 byte-level splice and cleanliness)"
trust_note: >
  C is a line-cited source slice of SerializeScriptCode, not the whole legacy
  sighash serializer.  L is a reviewed transliteration of serializeScriptCodeL
  and walkOps.  The scalar GetOp/byte-select, Out sink and packing are cell
  harness.  This cell proves which scriptCode bytes are emitted and the
  one-byte CompactSize value; it makes no claim about the surrounding tx
  serialization, hash type, or SHA256.  No Core source patch is used.
---
