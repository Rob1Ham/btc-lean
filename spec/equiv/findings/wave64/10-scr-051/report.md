# Wave 64 — task 10, SCR-051 call sites (push-encoding)

**Worktree:** `/tmp/opencode/wave64/10-scr-051`
**Branch:** `wave64/10-scr-051` (base `5946c02`)
**Row:** SCR-051 — "minimal numeric operands under MINIMALDATA (policy, not consensus)"
**Core ref:** `interpreter.cpp:556,584,1126,1140,1103@cce32b168`
**Pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Toolchain:** clang/LLVM 20.1.2, Alive2 v20.0, SAW 1.6 (68eed5f)

## Result

One new cell, **Alive2-green and SAW-green**, covering all five cited lines at
handler level:

| Cell | Row | Alive2 | SAW |
|---|---|---|---|
| `spec/equiv/cells/push-encoding/C-L-w32-num-callsites` | SCR-051 | `STATUS=alive2-green` — 4/4 functions, each `1 correct transformations`, 0 incorrect, 0 failed-to-prove, 0 errors | `STATUS=saw-green` — 8/8 `Proof succeeded!` (4 entry points x 2 legs), no `Proof failed` |

Entry points (`src/fns.txt`): `cell_cltv`, `cell_csv`, `cell_cms`,
`cell_checksigadd`.

### Evidence files and hashes

| Artifact | sha256 |
|---|---|
| `.../C-L-w32-num-callsites/alive2/certificate.sha256` | `f7f4747832f81f04ff9e7a2a4abdb94f5255eae9d1a2f775ad982c6fb684110e` |
| `.../C-L-w32-num-callsites/saw/certificate.sha256` | `4e64ba37a60d0a347cb94ed5cdc3160aba45cbb99e76b086462e4bcbe77ce0bc` |
| `.../alive2/result.txt` (raw alive-tv output) | `3763f774b7f4ffdde22285bdf1f22c68948c08b7331e8cffaae0f36450e4291d` |
| `.../saw/result.txt` (raw SAW output) | `bafca37d1fea4ed4512f3494f343eaf5ac5ecd378bfb0336bf9ca504c02a65f7` |

Both certificates were checked in place with `sha256sum -c` from the worktree
root: every listed file reports `OK`, including the tracked inputs
(`src/*`, `spec.md`, `notes.md`, `cells/_tools/w32-push/*`,
`twin/ops_ir.py`, `twin/gen.py`, `twin/runtime.inc`, `contract/error_kind.h`)
and the build artifacts (`build/twin.cpp`, `build/build.txt`,
`build/cell.cry`, `build/cell.saw`; `build/` is gitignored, as for every cell,
so a fresh checkout must run the scripts once).

## What the cell covers

Symbolic over five operand bytes and a three-bit operand length per decoded
operand (0..7 — lengths **3, 4, 5** are the widths where the caps differ),
`fRequireMinimal`, stack depth, opcode budget, locktime / version / input
sequence, and the activation flag:

- **CLTV** (`interpreter.cpp:556`, cap 5): flag-off NOP, stack underflow,
  decode, `n < 0` → NEGATIVE_LOCKTIME, `CheckLockTime` (threshold type match,
  `n <= txLockTime`, final-sequence rejection) → UNSATISFIED_LOCKTIME.
- **CSV** (`:584`, cap 5): same, then the `SEQUENCE_LOCKTIME_DISABLE_FLAG`
  NOP, then `CheckSequence` (version < 2, tx disable flag, type mask,
  masked compare).
- **CMS** (`:1126`, `:1140`, cap 4): key-count decode → PUBKEY_COUNT,
  `nOpCount + nKeys > 201` → OP_COUNT, `nKeys + 2` arity, sig-count decode →
  SIG_COUNT, `nKeys + nSigs + 3` arity.
- **CHECKSIGADD** (`:1103`, cap 4): base/witnessV0 → BAD_OPCODE,
  `stack.size() < 3`, then the number decode → SCRIPTNUM.

The decode itself is delegated to the generated `twin::decode_num`
(`runtime.inc:167-188`, dispatched on the concrete length so its symbolic-bound
loop unrolls); the Cryptol model restates the constructor and the call-site
ordering independently and is verified against both legs.

### Non-vacuity probe

A scratch copy of the C leaf with **only** the CLTV cap changed from 5 to 4
fails Alive2 against the cell's L bitcode:

```
0 correct transformations
1 incorrect transformations
Source value: #x0000000000000010 (16)
Target value: #x0000000000000001 (1)
```

So the length-5 branch and the cap choice are load-bearing. Log and mutant:
`mutation-cap5-to-4.log`, `mutation-cap5-to-4.cpp.txt` in this directory.

## Row status

**partial (narrowed).** The four handler call sites and lengths 3–5 that the
decoder cell did not cover are now compared. Still open:

1. **L-leg provenance (the blocker).** The L leg is a reviewed transcription of
   the Lean `Defs.lean` handler arms, not generated twin handler code, because
   the twin cannot express these sites:
   - `twin/ops_ir.py:42-50` (`OP_CLTV`) and `:52-61` (`OP_CSV`) return
     `TWIN_INVALID_UNSUPPORTED` when the activation flag is set — there is no
     decode, no NEGATIVE_LOCKTIME and no comparison.
   - `twin/gen.py:222-225` lists `CHECKMULTISIG`/`CHECKMULTISIGVERIFY` as
     unsupported; no handler is generated.
   - `Defs.lean:857-875`, `:1069-1090`, `:803-811` do model all four sites, and
     PDW98 already proves the non-minimal rejection at each, so the Lean side
     exists and only the twin generator lags.

   This is a shared-model edit (`twin/`), not made here. Closing it needs CLTV/CSV
   bodies with the decode step + checker calls, a CHECKMULTISIG count handler,
   and a locktime environment on the twin's `Ctx`/checker surface (the same seam
   as E3). The cell's `spec.md`/`notes.md` state the caveat explicitly; no
   generated-twin equivalence is claimed.
2. **CMS signature verification** (NULLDUMMY/NULLFAIL/FindAndDelete) is after
   the count decode and outside the row's operand decode.
3. **CHECKSIGADD** `EvalChecksig` is abstracted (same-crypto premise, E4 seam);
   the pushed value is not observed.
4. The R leg and whole-`EvalScript`/`VerifyScript` equivalence are not claimed.

**No ABI blocker:** the leaf ABI is per-cell, and adding locktime/version/
sequence/depth/budget as parameters was sufficient to build all four sites.

## Not done here (shared ledger)

Per the task's "no shared edits", this worktree did **not** touch
`spec/db/equiv-cells.yaml` or `spec/equiv/cells/INDEX.md`. For integration:

```yaml
- id: SCR-051
  cells:
  - push-encoding/C-L-w32-num-callsites
  alive2: {result: green, cell: push-encoding/C-L-w32-num-callsites,
           certificate: f7f4747832f81f04ff9e7a2a4abdb94f5255eae9d1a2f775ad982c6fb684110e}
  saw:    {result: green, cell: push-encoding/C-L-w32-num-callsites,
           certificate: 4e64ba37a60d0a347cb94ed5cdc3160aba45cbb99e76b086462e4bcbe77ce0bc}
  status: partial   # call sites green; L leg transcribed; CMS sig checks and
                    # CHECKSIGADD crypto outside the cell; twin handlers missing
```

## Reproduce

From the worktree root:

```sh
spec/equiv/cells/push-encoding/C-L-w32-num-callsites/alive2/run.sh
spec/equiv/cells/push-encoding/C-L-w32-num-callsites/saw/run.sh
sha256sum -c spec/equiv/cells/push-encoding/C-L-w32-num-callsites/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/push-encoding/C-L-w32-num-callsites/saw/certificate.sha256
```
