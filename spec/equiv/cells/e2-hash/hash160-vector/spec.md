---
# Cell e2-hash/hash160-vector
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: e2-hash/hash160-vector
family: hash-ops
tool_status: both-green (closed concrete HASH160 witness, opaque hash seam)
precondition: |
  - base sigversion; flags = 0; one input.
  - closed witness: the stack holds the single one-byte element 0x61 ("a");
    OP_HASH160 (wire 0xa9) is the only dispatched opcode.
  - the cryptographic transform is an opaque external `hash160` shared by
    both legs; its body is outside the cell.
  - bounded leaf domain: element length <= 20 for the result, stack depth 4.
postcondition: |
  - the op pops the 1-byte preimage and pushes a 20-byte digest.
  - concrete witness: HASH160(0x61) =
    994355199e516ff76c4fa4aab39337b9d84cf12b
    (SHA256 then RIPEMD160), so the packed observable is
    0x9e1955439900a101 (result=1, error=0, depth=1, length=20, and the
    first five digest bytes 99 43 55 19 9e).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-093, SCR-094
scr_row_coverage: >-
  partial — one concrete HASH160 witness establishes the
  20-byte output width (SCR-093's HASH160 arm) and the RIPEMD160(SHA256(x))
  composition seam (SCR-094) for that preimage. The SHA256/HASH256/RIPEMD160
  output widths, the empty-element row SCR-095, and the hash functions
  themselves are not proved: the transform is an opaque external on both
  legs and the SAW override supplies the concrete digest.
patches: none
source_citations:
  - interpreter.cpp:1032-1056 (hash opcode family)
  - interpreter.cpp:1049-1050 (CHash160().Write(vch).Finalize(vchHash))
  - interpreter.cpp:1042 (vchHash width: 20 for RIPEMD160/SHA1/HASH160)
  - interpreter.cpp:1053-1054 (popstack; push_back(vchHash))
  - twin/ops_ir.py OP_HASH160 (wires [0xa9], lean Defs.lean:1028-1030)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin. L is a reviewed transliteration of the twin OP_HASH160 body: the
  twin body is unchanged, but mk_leaf's bounded copy is hard-wired to two
  bytes, so the cell re-binds the stack element width to 32 and copies the
  20-byte digest with an unrolled sequence. The same opaque `hash160` symbol
  is called by both legs. Alive2 therefore proves the opcode plumbing
  (underflow, width, push/pop) with an uninterpreted hash; it does not prove
  the hash. SAW proves both legs against the concrete digest under an
  explicit override, so the digest value is an assumption with a recorded
  witness, not a derived result. No Core source patch is used.
---
