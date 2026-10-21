---
# Cell push-encoding/C-L-w32-cscriptnum-minimal
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-w32-cscriptnum-minimal
family: push-encoding
tool_status: both-green (symbolic over every 0..4-byte operand and both minimality settings)
precondition: |
  - base sigversion; CScriptNum decode with nMaxNumSize = 4.
  - payload length n is symbolic 0..4; the four payload bytes are symbolic.
  - fRequireMinimal is symbolic (both values covered).
  - the cell is the decode primitive, not a whole numeric opcode: no
    stack-underflow or opcode-specific path is exercised.
postcondition: |
  - if fRequireMinimal is false: every 0..4-byte payload decodes.
  - if fRequireMinimal is true: a payload is rejected iff the top byte
    (b[n-1] & 0x7f) == 0 and (n <= 1 or (b[n-2] & 0x80) == 0); rejection is
    SCRIPT_ERR_SCRIPTNUM (4).
  - accepted value is the little-endian sign-magnitude number
    (script.h set_vch).
  - packed observable: valid(1) | error(4) | low 32 bits of value at bit 6;
    both legs agree for every input.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-050
scr_row_coverage: >-
  full — SCR-050 is exactly the CScriptNum minimality rule "top byte &0x7f==0
  requires size 1 or next-byte high bit (under fRequireMinimal)".  The cell
  covers every length 0..4 and every byte pattern symbolically, including the
  negative-zero encoding 0x80, the +-255 exception (0xff00/0xff80), and the
  non-minimal branch under both fRequireMinimal values.  The width guard
  (n > 4 => SCRIPTNUM, SCR-079/SCR-080) is present in the slice and in the
  out-of-domain path, but the SAW proof domain is n <= 4.
patches: none
source_citations:
  - script.h:246-268 (CScriptNum constructor, width + minimality guards)
  - script.h:376-391 (set_vch sign-magnitude decode)
  - interpreter.cpp:415-427 (getvch, the inverse encoder)
  - Numeric/Interface.lean:45-47 (decodeScriptNum)
  - twin/runtime.inc:165-185 (generated twin decode_num)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.h at the pin;
  the length loop in set_vch is unrolled over the 0..4 domain (the width
  guard rejects anything longer before the loop in the unsliced function).
  L is the Lean decode transcribed verbatim from the generated twin.  The
  cell proves the decode/minimality primitive, not the opcode call sites
  (SCR-081 and the numeric rows are separate).  No Core source patch is used.
---
