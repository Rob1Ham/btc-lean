# limits/C-L-cms-count-bounds

SCR-026/027/028: the three OP_CHECKMULTISIG limit checks, both tools green.

## Source (pin cce32b168)

- `src/script/interpreter.cpp:1120-1142` — key-count decode, PUBKEY_COUNT,
  `nOpCount += nKeysCount`, OP_COUNT, sig-count decode, SIG_COUNT.
- `src/script/interpreter.cpp:459-463` — the per-opcode `nOpCount > 201`
  check that maintains the 0..201 entry invariant used as the precondition.
- `src/script/script.h:30-35` — `MAX_OPS_PER_SCRIPT = 201`,
  `MAX_PUBKEYS_PER_MULTISIG = 20`.
- `src/script/script.h:246-271` — `CScriptNum` width/minimality. The decoded
  `int` is an input; decode is a numeric-family row.

## Model

C is a line-cited slice with the decoded `int` counters as inputs. L is a
reviewed transliteration of `checkMultiSig`'s limit prefix from
`spec/core/Bitcoin/Interpreter/Defs.lean:1071-1088`. Both keep Core's `int`
width, so the comparisons and the `+=` are the engine's, not widened.

Observable: `result | error << 2 | nOpCount_after << 8`.

## Symbolic claim

- Alive2: `alive-tv build/c_cell_cms_count_bounds.ll build/l_cell_cms_count_bounds.ll`
  proves the two IR functions equal for every i32 triple.
- SAW: `src/cell.saw` verifies both modules against `cms_count_bounds` in
  `src/cell.cry`, for every signed i32 key/sig count and every
  `0 <= nOpCount <= 201`.

## Commands

```sh
cd /tmp/opencode/wave16/03-limits-accounting
bash spec/equiv/cells/limits/C-L-cms-count-bounds/alive2/run.sh
bash spec/equiv/cells/limits/C-L-cms-count-bounds/saw/run.sh
sha256sum -c spec/equiv/cells/limits/C-L-cms-count-bounds/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/limits/C-L-cms-count-bounds/saw/certificate.sha256
```

## Raw tails

`alive2/result.txt`:

```text
Transformation seems to be correct!
Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

`saw/result.txt`:

```text
Proof succeeded! cell_cms_count_bounds
Proof succeeded! cell_cms_count_bounds
CELL_limits_cms_count_bounds_SAW_GREEN
STATUS=saw-green
```

## Limits

- CScriptNum decoding (width/minimality) and the operand-stack underflow
  checks are outside these rows and are not proved.
- The signature loop after the limits is not modelled.
- No Core patch (`patches: none`).
