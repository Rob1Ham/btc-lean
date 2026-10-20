# Wave 64 — task 21-scr-086

Family: numeric. Assigned row: SCR-086 (`clamp to int32 for depth/count uses`,
`script.h:326-333@cce32b168`).

Worktree: `/tmp/opencode/wave64/21-scr-086`, branch `wave64/21-scr-086`,
base `5946c02`. No shared file was edited; the only tree change is the new
cell (plus this report).

## Result

SCR-086 stays **partial**, but the two missing pieces named in the gap are
now closed for one additional call site:

- the **int32 clamp is isolated** as a total function on Core's `int64_t
  m_value`, with both firing arms proved against an independent Cryptol
  statement; and
- the **CHECKMULTISIG key-count and signature-count reads** are proved for
  every four-byte operand, including derived cursors and error precedence.

OP_ROLL remains blocked for the reason recorded below. No claim is made that
the twin or Lean implements a clamp.

| Leaf | Domain | Alive2 | SAW |
|---|---|---|---|
| `cell_clamp_int32` | all `int64_t`; both clamp arms fire | green, bidirectional | green, 2 proofs |
| `cell_cms_counts4` | both count operands exactly 4 bytes, all 8 bytes symbolic | green, bidirectional | green, 2 proofs |

## Cell

`spec/equiv/cells/e2-numeric/C-L-w32-cms-getint-counts`

- C leg: line-cited `script.h:326-333` clamp, `script.h:376-391` four-byte
  `set_vch`, and `interpreter.cpp:1122-1146` CMS front matter.
- L leg: reviewed transliteration of Lean `getIntClamped`
  (`Numeric/ScriptNum.lean:741-744`) and `checkMultiSig` front matter
  (`Interpreter/Defs.lean:1071-1096`). It deliberately contains no clamp at
  the CMS site, matching the Lean model; the cell proves that this is
  unobservable on the four-byte domain, not that a clamp exists.
- Build/run: reuses the existing wave-32 numeric harness read-only
  (`cells/_tools/w32-num/*`, `cells/_tools/mk_leaf.py`). `src/ops.txt` is
  empty, so no handler is generated and no provenance is claimed for a twin
  handler.

## Why the clamp is vacuous at the CMS site

A four-byte little-endian sign-magnitude operand has magnitude at most
`0x7fffffff`. The decoded value is therefore in `[-2147483647, 2147483647]`,
inside `[INT_MIN, INT_MAX]`, so `getint()` is the identity. The Lean
statement is `PDW86Clamp.setVchBE_bounds_of_length_le_four` and
`PDW86Clamp.decodeNum_getIntClamped`. The firing arms are reachable only from
an `int64_t` that the CMS/PICK/ROLL decoders cannot produce, which is exactly
why the absent L clamp is not an equivalence bug.

## Exact OP_ROLL blocker

The verbatim twin OP_ROLL branch is inside the shared `OP_PICK` handler in
`spec/equiv/twin/ops_ir.py` (wires `0x79, 0x7a`) and contains

```c
for (uint32_t i = idx; i + 1 < st.stack.n - 1; ++i) { ... }
```

The trip count is symbolic in the operand. Alive2 does not unroll it, and an
unrolled bounded body would no longer be the `ops_ir.py` body, so
`build_w32.sh`'s provenance gate would reject it. Closing ROLL requires either
a loop-aware Alive2 configuration accepted by the harness, or a separately
labelled unrolled transliteration — not a claim about the twin body. This is
a shape/provenance blocker, not a tool timeout.

## Raw hashes

```text
4072429d9e1e286abf3d157eecf01e0863755b93be297a60f85da50c2407292f  alive2/result.txt
c396c6a3dc37bf19232189f537204259f74557bcce1971fe2a17eda05b1561bb  saw/result.txt
600f1629d9815b8097957c1b70b0364a743c3db634c65286ef5da779b2b9b169  alive2/certificate.sha256
e82e01eb9b5e39b13288f7eded40ac4b21d4790c41cb039f336fd1ca594a805c  saw/certificate.sha256
```

Certificates verified with `sha256sum -c` from the worktree root: 21/21 and
25/25 files `OK`.

## Commands

```sh
cd /tmp/opencode/wave64/21-scr-086
./spec/equiv/cells/e2-numeric/C-L-w32-cms-getint-counts/alive2/run.sh
./spec/equiv/cells/e2-numeric/C-L-w32-cms-getint-counts/saw/run.sh
sha256sum -c spec/equiv/cells/e2-numeric/C-L-w32-cms-getint-counts/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/e2-numeric/C-L-w32-cms-getint-counts/saw/certificate.sha256
```

## Not done

No edits to `PINS.lock`, `contract/**`, `spec/db/*`, `results/**`,
`docs/STATE.md`, `README.md`, Lean proofs, the census, existing cells, the
shared ledger, or the shared wave-32 harness. `make equiv`, the ledger
updater, and any push were not run; the orchestrator integrates.
