---
# Cell witness-v0/C-L-sigversion-findanddelete
cell: C-L-sigversion-findanddelete
family: witness-v0
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (sigversion branch and scriptCode identity, total)
precondition: |
  - `sigversion` is 0 (SigVersion::BASE) or 1 (SigVersion::WITNESS_V0), the
    two values admitted by Core's assert and by the Lean definition.  The C and
    L functions are total over u64; the semantic claim covers these two values
    (and the branches still agree outside them).
  - `found` is the FindAndDelete result count (Core `int`), modelled as a u64;
    only `found > 0` is observed.
  - `const_scriptcode_flag` encodes whether SCRIPT_VERIFY_CONST_SCRIPTCODE is
    set (nonzero = set).
  - `script_id` and `fd_script_id` are opaque identifiers of the two byte
    strings: the original scriptCode and FindAndDelete's result.  The
    FindAndDelete algorithm and the script bytes themselves are NOT modelled
    (different ledger row).
  - CheckSignatureEncoding / CheckPubKeyEncoding / the ECDSA checker that
    follow this branch are outside the cell (same-crypto premise,
    spec/equiv/README.md §7).
postcondition: |
  verdict:
    sigversion = BASE (0), found > 0, const_scriptcode_flag != 0
                                    -> (0, 54) SCRIPT_ERR_SIG_FINDANDDELETE
    every other input              -> (1, 0)
  scriptCode handed to the checker:
    sigversion = WITNESS_V0 (1)     -> script_id      (untouched)
    sigversion = BASE (0), no error -> fd_script_id   (FindAndDelete ran)
    sigversion = BASE (0), error    -> script_id      (unused; the error wins)
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-139
scr_row_coverage: |
  full for "sigversion != BASE skips deletion".  The row is the branch at
  interpreter.cpp:338-343: only BASE calls FindAndDelete and may replace the
  scriptCode, and only BASE with a positive found count plus CONST_SCRIPTCODE
  fails with ordinal 54.  Both the verdict and the scriptCode identity are
  proved for every input over the admitted sigversions and every found count /
  flag value.  FindAndDelete's internal algorithm and the bytes compared are a
  separate rule, not part of SCR-139.
patches: none
source_citations: |
  - interpreter.cpp:331-333 (EvalChecksigPreTapscript signature and
    sigversion assert: BASE or WITNESS_V0)
  - interpreter.cpp:336 (CScript scriptCode(pbegincodehash, pend))
  - interpreter.cpp:338-340 (FindAndDelete only when sigversion == BASE)
  - interpreter.cpp:341-342 (found > 0 && CONST_SCRIPTCODE ->
    SCRIPT_ERR_SIG_FINDANDDELETE)
  - interpreter.h:201-207 (SigVersion enum: BASE = 0, WITNESS_V0 = 1)
  - spec/core/Bitcoin/Interpreter/Defs.lean:720-739
    (Bitcoin.Interpreter.evalChecksigPreTapscript; `.base` branch)
  - contract/error_enum.md (ordinal 54 SCRIPT_ERR_SIG_FINDANDDELETE)
trust_note: >
  C is a line-cited source-excerpt slice of EvalChecksigPreTapscript, not the
  whole checksig path.  L is a REVIEWED TRANSLITERATION of the verified Lean
  definition.  scriptCode is represented by two opaque ids; FindAndDelete,
  encoding checks and ECDSA are inputs/not modelled, so no byte-level
  FindAndDelete or signature claim is made.  Both tools prove the same total
  dispatch.  No Core patch is used.
evidence:
  - alive2/result.txt (alive-tv v20, clang 20.1.2; two functions)
  - saw/result.txt (SAW 1.6, solver abc; four proofs)
  - alive2/certificate.sha256, saw/certificate.sha256
mutant: >
  Not executed here.  A useful mutant is dropping the `sigversion == BASE`
  guard, which would delete for WITNESS_V0 too and must fail on scriptCode
  identity at (sigversion=1, found>0, fd_script_id != script_id), or weakening
  `found > 0` to `found >= 0`, which must fail on the verdict at found=0.
---
# witness-v0/C-L-sigversion-findanddelete

BIP143's segwit v0 scriptCode is not passed through `FindAndDelete`
(interpreter.cpp:338).  The same signature would be deleted in a legacy (BASE)
spend, which is why the branch is consensus-relevant: a v0 checker must see
the untouched script bytes (including any `OP_CODESEPARATOR`-derived slice).

## What is proved

Two observables, both total over the admitted domain:

| sigversion | found | CONST_SCRIPTCODE | verdict | scriptCode |
|---:|---:|---:|---|---|
| 0 (BASE) | > 0 | set | (0, 54) | original (error path) |
| 0 (BASE) | > 0 | clear | (1, 0) | FindAndDelete result |
| 0 (BASE) | 0 | any | (1, 0) | FindAndDelete result |
| 1 (WITNESS_V0) | any | any | (1, 0) | original, untouched |

The C leg writes the branch as nested conditionals and the L leg as a
select/phi chain; Alive2 proves them equal.  SAW checks both modules against
the same Cryptol predicates `verdict` and `scriptcode`, four proofs.

## What is not proved

- FindAndDelete itself (the byte scan and deletion), and the actual scriptCode
  bytes: both strings are opaque ids.
- CheckSignatureEncoding, CheckPubKeyEncoding, NULLFAIL and the ECDSA checker
  that follow the branch.
- Any witness-program or stack behaviour.

SCR-139 is promoted for the sigversion branch only; it is not a claim that
legacy and segwit signature hashes were computed.
