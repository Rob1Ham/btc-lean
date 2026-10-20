---
# Cell C-L-w32-cms-getint-counts

contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c02
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: e2-numeric/C-L-w32-cms-getint-counts
family: numeric
tool_status: both-green (two bounded pure leaves, fully symbolic inputs)
precondition: |
  - `cell_clamp_int32(x)`: `x` is Core's `int64_t CScriptNum::m_value`,
    completely symbolic over all 64-bit values.  No decoder is in this leaf,
    so the firing arms `x > INT_MAX` and `x < INT_MIN` are reachable and
    proved.
  - `cell_cms_counts4(kb0..kb3, sb0..sb3, depth, opCount)`: the two
    OP_CHECKMULTISIG count operands are raw, exactly four-byte,
    little-endian CScriptNum elements with all eight bytes symbolic.
    `fRequireMinimal = false` (the consensus-relevant setting; the minimal
    subset is a restriction of this domain).  `depth` is the current stack
    size and `opCount` Core's EvalScript-local `nOpCount`; the cell domain
    assumes the maintained invariant `opCount <= 201`
    (interpreter.cpp:459-463).  Sigversion is BASE or WITNESS_V0; the
    tapscript ban is a different row.
postcondition: |
  - `cell_clamp_int32` returns Core `CScriptNum::getint()`
    (script.h:326-333): `INT_MAX` above the range, `INT_MIN` below it, the
    value itself in range.
  - `cell_cms_counts4` returns the packed front-matter decision
    `status(3) | nKeys(5)<<3 | nSigs(5)<<8 | ikey2(6)<<13 | isig(6)<<19`
    (cell-local status codes: 0 ok, 1 PUBKEY_COUNT, 2 OP_COUNT,
    3 INVALID_STACK_OPERATION, 4 SIG_COUNT), in Core's order
    interpreter.cpp:1122-1146.  `nKeysCount` and `nSigsCount` are
    `getint()` of the decoded operands.  The `opCount+nKeys` and cursor
    arithmetic is widened to int64 in both legs; it equals Core's `int`
    arithmetic on `opCount <= 201`, `0 <= nKeys <= 20`.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-086
scr_row_coverage: |
  partial for SCR-086, with the CMS count call site now proved.
  - The int32 clamp itself is isolated: both arms fire and are proved
    against an independent Cryptol statement of script.h:326-333.
  - The CHECKMULTISIG key-count and signature-count call sites are proved
    for every four-byte operand, including the derived cursors and the
    PUBKEY_COUNT / OP_COUNT / INVALID_STACK_OPERATION / SIG_COUNT order.
  - The clamp is vacuous at this site: a four-byte sign-magnitude operand
    has magnitude at most 2^31-1, so `getint()` is the identity.  This is
    what lets the unclamped Lean model match Core.  It is NOT a claim that
    the twin or Lean implements the clamp.
  - Remaining: OP_ROLL's depth read and the CHECKMULTISIG verification
    loops.  OP_ROLL's verbatim twin body contains a stack-shift loop and
    cannot be ingested by Alive2 without unrolling, which would break the
    `ops_ir.py` provenance gate; see notes.md for the exact blocker.
patches: none
source_citations:
  - "script.h:326-333 (getint int32 clamp)"
  - "script.h:246-271 (CScriptNum width check; nMaxNumSize = 4 here)"
  - "script.h:376-391 (set_vch, little-endian sign-magnitude)"
  - "interpreter.cpp:1122-1146 (CHECKMULTISIG front matter, count decode, precedence)"
  - "interpreter.cpp:459-463 (nOpCount invariant)"
  - "spec/core/Bitcoin/Numeric/ScriptNum.lean:741-744 (getIntClamped)"
  - "spec/core/Bitcoin/Numeric/ScriptNum.lean:444-460, 627-631 (setVchBE, decodeNum)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1071-1096 (checkMultiSig front matter)"
  - "spec/proofs/BitcoinProofs/AF/PDW86/PDW86Clamp.lean (clamp identity at all four sites)"
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.h and
  interpreter.cpp at the pin, not the whole EvalScript.  L for the clamp leaf
  is a reviewed transliteration of Lean `getIntClamped`; L for the CMS leaf
  is a reviewed transliteration of Lean `checkMultiSig` front matter, not a
  `twin/gen.py` output (the twin has no CHECKMULTISIG handler).  The L CMS
  leg deliberately has no clamp: Lean keeps an unbounded Int and PDW86Clamp
  proves the clamp identity at four-byte width.  Thus this cell proves the
  absence of an observable clamp difference at the call site; it does not
  claim the twin or the Lean model contains a clamp.  The int64 widening of
  the cursor/op-count arithmetic matches Core on the stated opCount domain.
  No Core, twin, Lean, or shared-harness file is modified.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - build/ (both legs' IR, build.txt, cell.cry, cell.saw)
mutant: >
  In the clamp leaf, change the upper arm from INT_MAX to INT_MAX-1 or drop
  the lower arm.  In the CMS leaf, change the key bound from 20 to 19 or
  return `nKeys+3` for ikey2.  Expected: Alive2 counterexample and SAW
  oracle failure; the clamp leaf's firing arm is exercised by the oracle,
  so a clamp-only mutation cannot hide behind the vacuous four-byte domain.
mutant_site: |
  e2-numeric/C-L-w32-cms-getint-counts/src/{c,l}_leaf.cpp (both listed
  functions), or the independent src/cell.cry for a spec-side mutation.
---
