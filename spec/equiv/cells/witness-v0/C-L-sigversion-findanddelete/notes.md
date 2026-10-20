# witness-v0/C-L-sigversion-findanddelete

SCR-139: in `EvalChecksigPreTapscript`, segwit v0 does not delete the signature
from the scriptCode; only the legacy BASE sigversion runs FindAndDelete
(interpreter.cpp:338-343).

## Design

Two observables:

- `cell_checksig_verdict(sigversion, found, const_scriptcode_flag)` returns
  `(0, 54)` exactly for BASE + found > 0 + the flag, else `(1, 0)`.
- `cell_checksig_scriptcode(sigversion, found, const_scriptcode_flag,
  script_id, fd_script_id)` returns the original id for WITNESS_V0 and the
  FindAndDelete result id for a successful BASE branch (the error branch
  returns the original id, unused).

`script_id`/`fd_script_id` are opaque identifiers of the two byte strings;
FindAndDelete's scan is not modelled (a separate ledger rule).  The C leg is a
line-cited excerpt of `EvalChecksigPreTapscript`; the L leg is a reviewed
transliteration of the `.base` branch of `evalChecksigPreTapscript`
(`spec/core/Bitcoin/Interpreter/Defs.lean:720-739`).  `sigversion` uses the
Core enum values BASE=0, WITNESS_V0=1 (interpreter.h:201-207).

The C leg spells the branch as nested conditionals; the L leg compiles to a
select chain.

## Exact commands

```sh
bash spec/equiv/cells/witness-v0/C-L-sigversion-findanddelete/alive2/run.sh
bash spec/equiv/cells/witness-v0/C-L-sigversion-findanddelete/saw/run.sh
sha256sum -c spec/equiv/cells/witness-v0/C-L-sigversion-findanddelete/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/witness-v0/C-L-sigversion-findanddelete/saw/certificate.sha256
```

## Versions

Alive2 v20.0 (`/opt/equiv-tools/alive-tv-v20.0`, LLVM 20.1.2), SAW 1.6
(68eed5f, solver abc), clang 20.1.2.

## Result

- Alive2: both functions `Transformation seems to be correct! (syntactically
  equal)`, `STATUS=alive2-green`.
- SAW: four `Proof succeeded!` (2 functions x C and L), `STATUS=saw-green`.

## Limits / blockers

- The semantic domain is BASE/WITNESS_V0 (Core asserts only those values).  The
  functions are total, but TAPROOT/TAPSCRIPT are not part of the claim.
- FindAndDelete's byte algorithm and the scriptCode contents are abstract ids;
  no byte-level deletion claim is made.
- `CheckSignatureEncoding`, `CheckPubKeyEncoding`, NULLFAIL and ECDSA are
  outside the cell (same-crypto premise, `spec/equiv/README.md` §7).
