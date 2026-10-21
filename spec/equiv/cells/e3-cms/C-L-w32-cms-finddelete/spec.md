---
# Cell e3-cms/C-L-w32-cms-finddelete
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: the pinned rbitcoin render/error path is documented non-proof (F-HARNESS-002, F-TOOL-001)"
cell: C-L-w32-cms-finddelete
family: checkmultisig
tool_status: both-green (bounded script <= 8, needle <= 4; nSigs 0..20 chain)
precondition: |
  - The cell is CScript::FindAndDelete (script.cpp:239-265 at the pin) plus
    the OP_CHECKMULTISIG pre-loop (interpreter.cpp:1152-1160) that deletes
    the serialized push of every signature when sigversion == BASE.
  - Five exported functions, all symbolic over their inputs:
      cell_fd_found(script, slen, needle, nlen) -> nFound
      cell_fd_len(script, slen, needle, nlen)   -> resulting script length
      cell_fd_bytes(script, slen, needle, nlen) -> resulting bytes (8 bytes,
                                                   little-endian in the low 56 bits)
      cell_fd_chain(nSigs, script, slen, sig0, sig0len, sig1, sig1len)
          -> (length << 56) | bytes, applying the per-signature deletion
             loop for nSigs in {0,1,2} with caller-chosen signature bytes
      cell_fd_chain_n(nSigs, script, slen, salt, sv)
          -> (length << 56) | bytes, nSigs symbolic 0..20; signature k is
             the one-byte element (37*k + salt) & 0xff placed at a distinct
             position, and sv = 0 means BASE (delete), any other value
             means the loop makes no deletion.
  - Bounded domain: script length <= 8 bytes, needle length <= 4 bytes.
    Inputs outside it return 0xffffffffffffffff in both legs (the marker is
    also compared by Alive2, so out-of-domain input behaviour agrees).
  - The script is a byte string, not a Core CScript object with lazy
    parsing; GET_OP-equivalent boundary walking (direct push, PUSHDATA1/2/4,
    truncated-push failure) is part of the two legs.
  - No checker and no crypto is involved in this slice.
postcondition: |
  - FindAndDelete walks the script at opcode boundaries, and at each
    boundary greedily deletes every complete occurrence of the needle
    before advancing one opcode. If no occurrence is found the script is
    returned unchanged. Otherwise the result is the concatenation of the
    bytes kept so far plus the bytes after the last boundary.
  - The observable is exactly (found count), (result length), or
    (result bytes) of one application, and (length, bytes) for the chain.
    The chain applies one pop-push deletion per signature before any
    signature check, in signature order, and makes no deletion for a
    non-BASE sigversion.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-115
scr_row_coverage: partial
coverage: partial
patches: none
source_citations:
  - "script.cpp:239-265 (CScript::FindAndDelete: opcode walk + greedy match + accumulation)"
  - "script.cpp GetScriptOp (direct pushes, PUSHDATA1/2/4, truncation)"
  - "interpreter.cpp:1152-1160 (for k in [0,nSigs): FindAndDelete(CScript(vchSig)) only when sigversion == BASE)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:545-600 (findAndDeleteMatches, findAndDeleteAux, findAndDelete)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1090-1100 (pre-loop foldl over nSigs)"
trust_note: >
  C is a line-cited slice of pinned script.cpp plus the interpreter.cpp
  pre-loop. L is a reviewed transliteration of the Lean
  findAndDeleteMatches/findAndDeleteAux/findAndDelete recursion and the
  pre-loop foldl, written from the Lean equations (fuel-driven,
  accumulator list) rather than from the C iterator. Alive2 compares all
  five functions bidirectionally; SAW verifies both linked modules against
  64 oracle-derived scenarios (128 proofs).

  The bounded domain (script <= 8, needle <= 4) is a real restriction, not
  a tool limit: it covers every opcode-boundary case that fits (direct
  push shorter/equal/longer than the needle, PUSHDATA1/2/4 length walks,
  truncated pushes, greedy multi-match, a match spanning a boundary,
  no-match, empty needle) but it does not prove FindAndDelete for
  arbitrary-length scripts. `cell_fd_chain_n` proves the nSigs 0..20 loop
  with symbolic scripts but with one-byte signature elements; the
  general-needle chain is only shown for nSigs in {0,1,2}. This is why
  SCR-115 is marked partial. No Core patch, no R leg and no whole-engine
  claim is made.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - build/ (twin_ops.h, c_leaf.ll, l_leaf.ll, extracted per-function IR)
mutant: "drop the final tail copy (acc ++ extract lastPc2 end) in FindAndDelete, or stop the greedy delete after one match; expect Alive2/SAW to fail. Recorded in findings/wave32/20-cms-114-117/report.md"
mutant_site: "cells/_tools/w32cms/c_finddel.cpp (C leg) / l_finddel.cpp (L leg)"
---

# Cell `e3-cms/C-L-w32-cms-finddelete`

## What is proved

Five functions per leg, compared with Alive2 in both directions and checked
with SAW against 64 independently generated scenarios (128 proofs):

| Function | Observable |
|---|---|
| `cell_fd_found` | number of complete needle occurrences deleted |
| `cell_fd_len` | length of the resulting script |
| `cell_fd_bytes` | the resulting script bytes |
| `cell_fd_chain` | (length, bytes) after the nSigs in {0,1,2} deletion loop |
| `cell_fd_chain_n` | (length, bytes) after the symbolic nSigs 0..20 deletion loop, BASE vs non-BASE |

The script walk is at opcode boundaries: a match is only honoured at a
boundary, all consecutive matches at that boundary are deleted, and the
remaining bytes are accumulated. The cases exercised include a match inside
a push payload (not deleted), a match spanning a boundary (not deleted),
multiple adjacent matches (all deleted), truncated pushes (walk stops), and
the empty needle (no-op).

## SCR-115 is partial

`SCR-115 (all nSigsCount sigs FindAndDelete'd before any check (BASE))` is
covered for symbolic nSigs 0..20 with symbolic one-byte signature pushes,
and for arbitrary <= 4-byte needles with nSigs in {0,1,2}. The universal
quantification over script bytes is bounded at 8 bytes and the general
needle chain is not shown for large nSigs; a script longer than 8 bytes or a
needle longer than 4 is outside the evidence. The non-BASE no-op arm is
proved. No signature check is modelled here, so "before any check" is a
statement about this slice's position, not about a full EvalScript run.

## Directions

`alive2/result.txt` uses `alive-tv --bidirectional` (L ⊑ C and C ⊑ L) for
all five functions; both legs are compiled at -O2 for the Alive2 lane.
At -O1 clang tags the bounded loops with `llvm.loop.unroll.disable`, Alive2
v20.0 then does not unroll them, and a mutation that changes the returned
bytes came back "correct"; at -O2 the same mutation is caught (see the wave
report §4). SAW proves each leg against the same oracle constants (-O0). No
R leg or whole-engine claim is made.
