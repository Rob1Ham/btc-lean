# `C-L-w65-taproot-bip9-window-model` — notes

Finding-scoped model cell for SCR-142. Deliberately not under `cells/`: it
must never be cited as ledger evidence for the row.

## Why a model is the only way to state the height clause

The pinned tree has no taproot height term:

- `validation.cpp:2249-2288 @cce32b168`: `flags{... | SCRIPT_VERIFY_TAPROOT}`
  at `:2261`; only the hash-keyed `script_flag_exceptions` clears it
  (`:2262-2265`); the four `DeploymentActiveAt` calls are all
  `BuriedDeployment` compares.
- `consensus/params.h:38-44`: `DeploymentPos` contains only `TESTDUMMY`.
- `kernel/chainparams.cpp:125`: 709632 survives only in the
  `MinBIP9WarningHeight = 711648; // taproot activation height + ...`
  comment.
- `interpreter.cpp:1959`: `if (!(flags & SCRIPT_VERIFY_TAPROOT))`, no height.

The historical record lives in `spec/core/Bitcoin/Activation/Taproot.lean`:
TPR-075 (minActivation 709632), TPR-076 (hash-keyed exception, any height),
TPR-078 (`deploymentActiveAt d height := d.minActivation <= height`). Both legs
here are transcriptions of that record; the C-shaped leg is *not* a Core
slice.

## Representations (the Alive2-closable difference)

| | C leg | L leg |
|---|---|---|
| flags | `uint64_t` bitmask, `1 << 17` | `bool` record |
| exception | equality on four `uint64_t` limbs | `Option`-shaped `{has, v}` |
| activation | `709632 <= height` | `709632 <= height` (TPR-078) |
| gate | bit test | `if !flags.taproot` |

Both legs use the same cell-local ABI:

```
cell_model_taproot(h0, h1, h2, h3, height, version, program_len, is_p2sh,
                   witness_n)
```

`h0..h3` are the block hash (big-endian limb grouping; equality only).
`height` is `uint32`. This is the ABI extension the gap record names; the
shared `contract/tape.md` is untouched.

## Raw tails

Alive2 (`alive2/result.txt`):

```
Transformation seems to be correct!
These functions seem to be equivalent!
Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green (model-only)
```

SAW (`saw/result.txt`):

```
Verifying cell_model_taproot...
Proof succeeded! cell_model_taproot
Verifying cell_model_taproot...
Proof succeeded! cell_model_taproot
CELL_w65_taproot_bip9_model_SAW_GREEN
STATUS=saw-green (2/2 proofs, model-only)
```

## Honesty notes

- Equivalence of two transcriptions of one specification is not evidence
  about Core. The row-relevant evidence is `../compare/`: the pinned slice
  and this model are **inequivalent at 709631** and equivalent at 709632 and
  at the exception block.
- TPR-078 is the height abstraction, not the BIP9 versionbits state machine.
  The real historical test was `versionbitscache.IsActiveAfter`; 709632 is
  the observed mainnet activation height. See `../report.md` residual R2.
- No claim is made about anyone-can-spend beyond the v1-32 non-P2SH arm's
  first branch; annex/key/script dispatch is sibling-row territory.
