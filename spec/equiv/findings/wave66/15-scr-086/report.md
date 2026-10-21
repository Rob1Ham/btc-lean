# SCR-086 — clamp to int32 for depth/count uses

Status: **full green row, both tools.**  Base `8142cff`, branch
`wave66/15-scr-086`, worktree `/tmp/opencode/wave66/15-scr-086`.  Only a new
cell and this finding were added; no shared file (`spec/db/**`,
`spec/proofs/**`, `spec/core/**`, `PINS.lock`, `contract/**`, `results/**`,
`docs/**`, `twin/**`, existing cells, shared harness) was edited.

The row is `clamp to int32 for depth/count uses`,
`core_ref: script.h:326-333`, `check: getint clamping`, with Lean targets
`PDW86Clamp.stepBody_{pick,roll}_ok_clamped` and
`PDW86Clamp.checkMultiSig_{key,sig}_count_clamped`.  This cell is the C/L
machine-level counterpart at every depth/count consumer, with the operand,
both minimal-data settings, the stack depth and `nOpCount` symbolic.

## Artifacts

- New cell: `spec/equiv/cells/e2-numeric/C-L-w66-scr086-clamp-uses/`
  - `scr_rows: SCR-086`, `scr_row_coverage: full`, `tool_status: both-green`.
  - Contract hash `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
    (unchanged, cited in `spec.md`).
  - Five loop-free scalar leaves, each proved in both directions:
    `cell_clamp_int32`, `cell_depth_read`, `cell_cms_key_count`,
    `cell_cms_sig_prefix`, `cell_cms_sig_read`.
  - SAW 1.6 (`68eed5f release-1.6`, solver z3): **10/10**
    `Proof succeeded!`, 0 `Proof failed`.
    `saw/result.txt` sha256
    `afe37c77425284d3730e4908ce6d33b88b4bdac36570f6b36d40fee655c54ea6`,
    `STATUS=saw-green`.
    `saw/certificate.sha256` sha256
    `c75ed8949866dcd354d6896be67e49d800fe07b2199bb0afd5015fd0d264667d`,
    26/26 entries verify.
  - Alive2 (`Ubuntu LLVM 20.1.2`, clang 20.1.2, `alive-tv --bidirectional`):
    **5/5** leaf pairs, 5 × `Transformation seems to be correct!`,
    0 incorrect, 0 failed-to-prove, 0 Alive2 errors.
    `alive2/result.txt` sha256
    `94d4e31fc9996b3a5c2f9e2288f9c550bef43b03154801f54446b4124f9b417d`,
    `STATUS=alive2-green`.
    `alive2/certificate.sha256` sha256
    `a6c4be890ea9f0c40ac1b53182b7e3f3888372f18d4c41885ea8882292c78bf4`,
    22/22 entries verify.
  - Source hashes:
    `c_leaf.cpp` `ed8345d4d01f4c62ec9cbb576c44c9010ae23287573e8537475ec15437b50201`,
    `l_leaf.cpp` `7c9c2f81bd341f0f7b824da7efdcd4c12c4c350b3c70e0933c97b71749186be7`,
    `cell.cry` `4653eca0a95a60eb6ad45b96bdeacc7912be682ddf276650403b621d9a2408d9`,
    `cell.saw` `ec29d05dd7eca7d9d2f4325c825e44847f1855aa6e036f894cefe6e045f12352`,
    `spec.md` `10e7e665a74c6168bcd42564860115b7d6f46e97b512a3a95a27d175c6a10438`.
  - Both runners were executed twice; `result.txt` was byte-identical
    between runs (`cmp`), and both certificates verify from the repo root.

### Ledger derivation (read-only; the ledger itself is not edited)

```text
$ python3 spec/equiv/results/scripts/update_ledger.py --check
cells scanned: 165 (valid 165, malformed 0)
rows:    183
statuses: planned=0, alive2-green=0, saw-green=0, both-green=153, ...
changes: 1
  - SCR-086: gap -> both-green (2 cell(s))
```

The two cells are the pre-existing `e2-numeric/C-L-w32-cms-getint-counts`
and this cell; the derivation records this cell's certificates as the
alive2 and saw witnesses (result digests above).  `--check` exits 1 only
because the committed ledger still says `gap` (drift), which is the
orchestrator's integration step.

## Exact commands

```sh
cd /tmp/opencode/wave66/15-scr-086
bash spec/equiv/cells/e2-numeric/C-L-w66-scr086-clamp-uses/saw/run.sh
bash spec/equiv/cells/e2-numeric/C-L-w66-scr086-clamp-uses/alive2/run.sh

# from the repo root (certificate paths are root-relative)
sha256sum -c spec/equiv/cells/e2-numeric/C-L-w66-scr086-clamp-uses/saw/certificate.sha256
sha256sum -c spec/equiv/cells/e2-numeric/C-L-w66-scr086-clamp-uses/alive2/certificate.sha256

grep -c '^Proof succeeded!' spec/equiv/cells/e2-numeric/C-L-w66-scr086-clamp-uses/saw/result.txt   # 10
grep -c '^Proof failed'    spec/equiv/cells/e2-numeric/C-L-w66-scr086-clamp-uses/saw/result.txt   # 0

python3 spec/equiv/results/scripts/update_ledger.py --check
```

## What is proved

1. **The clamp itself** (`cell_clamp_int32`).  Core `CScriptNum::getint()`
   (script.h:326-333) equals Lean `getIntClamped`
   (Numeric/ScriptNum.lean:741-744) on every `int64_t`, including both
   firing arms (`> INT_MAX`, `< INT_MIN`).

2. **The depth consumer** (`cell_depth_read`).  One call site
   (`CScriptNum(stacktop(-1), fRequireMinimal).getint()`,
   interpreter.cpp:840) is textually shared by OP_PICK and OP_ROLL.  The
   leaf covers every operand length (`len > 4` width arm and 0..4), every
   operand byte, both minimal-data settings, every pre-pop depth in the
   engine domain, the `size() < 2`, width, minimal, `n < 0` and
   `n >= size()` error arms, and every in-range index.  The decoded `n` is
   exposed as a full 32-bit field, so a clamp difference cannot hide in the
   index.

3. **The count consumers** (`cell_cms_key_count`, `cell_cms_sig_prefix`,
   `cell_cms_sig_read`).  The `nKeysCount` read (interpreter.cpp:1126) and
   the `nSigsCount` read (:1140) are covered with arbitrary operands, both
   minimal-data settings, symbolic `depth` and `nOpCount`, every precedence
   arm, both derived cursors (`ikey2`, `isig`) and the accepted counts.
   Cursor arithmetic follows Core exactly: `i = 1`; `i += nKeysCount`
   (key gate `depth < 2 + nKeysCount`); `isig = ++i`; `i += nSigsCount`
   (signature gate `depth < isig + nSigsCount`).

4. **Composition of the signature path.**  The `nSigsCount` path is split
   at the signature read only so each solver query contains one decode.
   `cell_cms_sig_prefix` returns the full result whenever its status is
   nonzero; on status 0 it exposes the decoded key count and `ikey2`, and
   `cell_cms_sig_read` is applied to `(nKeys, depth, sig operand,
   minimal)`, recomputing `isig` from `nKeys`.  Both legs implement the same
   split, each leaf equals the independent Cryptol oracle pointwise, and
   `nKeys` outside `[0, 20]` is a marked unreachable-state arm that the
   composition never enters.  Hence the full path is equal on both legs.

## Why the clamp is unobservable at these sites

Core caps the operand at `nMaxNumSize = 4` before `set_vch`
(script.h:246-251).  A four-byte little-endian sign-magnitude value has
magnitude at most `0x7fffffff`, so the decoded `int64_t m_value` lies in
`[-2147483647, 2147483647]`, strictly inside `[INT_MIN, INT_MAX]`.  The
clamp is therefore the identity at every reachable depth/count read (Lean:
`PDW86Clamp.decodeNum_getIntClamped`).  The clamp leaf proves the two
firing arms anyway, so a change to either arm is rejected by the oracle
rather than hidden by the vacuous four-byte domain.

## Tool finding (oracle error caught by SAW)

The first SAW pass rejected the signature leaf on the **C leg only**, and
the counterexample was a real oracle bug: the oracle's final underflow gate
used `i + nSigsCount` with the pre-`isig` cursor `i = 2 + nKeysCount`, one
stack slot too shallow.  Core increments `i` again at `int isig = ++i`
before `i += nSigsCount` (interpreter.cpp:1145-1146), so the gate is
`depth < isig + nSigsCount`.  Witness: `nKeysCount = 15`, `depth = 19`,
`nSigsCount = 2` (Core underflows; the old oracle returned ok).  The oracle
was corrected; both legs then prove.  Alive2 compares the legs directly
and was unaffected.  This is evidence the SAW side is a real check, not a
rubber stamp.

A separate, purely environmental issue: the first unsplit 13-input
signature leaf was killed once under host memory pressure (other agents'
z3 processes) after having passed once.  The split into prefix/read removes
that flakiness; both runners now reproduce byte-identically.

## Residual / out of scope

- The OP_ROLL stack-shift loop (`for (i = idx; ...)`, twin/ops_ir.py
  wires `0x79,0x7a`) and the CHECKMULTISIG verification loops are
  stack-effect subjects (SCR-075 and SCR-114/116-121), not clamp
  consumers.  The clamp is applied to the decoded scalar before either loop
  is reached, and these leaves expose that scalar; the verbatim twin
  handler body is still present in the L leg and the harness provenance
  gate reports `provenance OK: 1 handler body/bodies verbatim in
  l_leaf.cpp`, with no twin edit.
- The L leg contains no clamp at the consumers, matching the twin/Lean
  model (unbounded `Int` / `int64_t`); the cell proves the clamp is
  unobservable, not that the twin supplies one.
- `depth > 1000` and `nOpCount > 201` (and `nk` outside `[0, 20]` in the
  read leaf) are explicitly marked unreachable-state sentinels, so every
  leaf is total without claiming unreachable engine states.
- The committed ledger/matrix still show `SCR-086: gap`; the read-only
  derivation above gives `gap -> both-green` with this cell.  The
  orchestrator integrates `spec/db/equiv-cells.yaml`, `results/**` and the
  matrix.
