# cells/_tools/w32 — wave-32 bounded numeric-cell tooling

Additive tooling for task `15-numeric-086-092` (SCR-086..SCR-092). It does
not modify `cells/_tools/mk_leaf.py`, `cells/_tools/e2/**`, or any existing
cell. Only the new `C-L-w32-*` cells use it.

## Why a second numeric harness

`cells/_tools/e2/e2_common.h` packs a stack of at most 4 elements whose value
is a `uint32` truncated to one observable byte, and mk_leaf's bounded copy is
hard-wired to 1–2 byte elements. The rows in this task are about CScriptNum
semantics at the full 4-byte operand width, where results may be 5 bytes
(overflow is legal: `script.h:220-236`). `w32_common.h` therefore uses a
4-deep stack of 5-byte elements and packs

```
result(2) | error(6) | depth(3) | top.len(9) | top.val(40 LE)
```

where `result` is the VerifyScript tail (`interpreter.cpp:1878`), `error` is a
contract `EQUIV_ERR_*` ordinal, and an empty element canonicalises to value 0.
The packer is shared by both legs, so the observable cannot differ by
construction.

## L-leg provenance

The L leg carries the twin handler bodies **verbatim** from
`twin/ops_ir.py` (the same strings `twin/gen.py` emits). Only the bounded
stack primitives are re-bound (5-byte elements, `decode_num` cap 4 bytes,
5-byte `encode_num`); `std::memcpy`/`std::memcmp` are re-bound to the bounded
forms exactly as `mk_leaf.py` does. `build_w32.sh` emits `build/twin_ops.h`
with `mk_leaf.py` for provenance *and* runs a provenance gate that fails the
build if any selected handler body is not present verbatim (after that same
re-binding) in `src/l_leaf.cpp`.

Cells with no `twin/ops_ir.py` handler (the tapscript OP_SUCCESS pre-scan)
leave `src/ops.txt` empty and are labelled as reviewed transliterations of
`Interpreter/Defs.lean` in their `spec.md`/`notes.md`.

## Scripts

- `build_w32.sh CELL_DIR` — reads `src/ops.txt` and `src/fns.txt`, emits and
  drift-checks `build/twin_ops.h`, runs the provenance gate, compiles
  `src/{c,l}_leaf.cpp`, extracts `build/{c,l}_<fn>.{bc,ll}`, writes
  `build/build.txt`.
- `run_alive2_w32.sh CELL_DIR CELL_ID FN...` — `alive-tv --bidirectional`, so
  both `L ⊑ C` and `C ⊑ L` are real results; requires "Transformation seems
  to be correct", a `1`/`2 correct transformations` summary (alive-tv prints
  one line when the functions are equivalent), `0 incorrect transformations`,
  and no mismatch/error line.
- `run_saw_w32.sh CELL_DIR CELL_ID MIN_PROOFS` — runs `src/cell.saw` with the
  pinned SAW 1.6, requires `MIN_PROOFS` `Proof succeeded!` lines and no
  `Proof failed`.

Certificates are written relative to the worktree root and include
`spec.md`, the cell `run.sh`/`src/`, this tool directory (`w32_common.h` and
`w32_twin.h`), `mk_leaf.py`, `twin/ops_ir.py`, `twin/gen.py`,
`contract/error_kind.h`, the build outputs, and the raw result.

Error paths whose post-error stack can differ between Core and the twin are
packed with `w32_pack_err`/`l_fail_err` (error ordinal only, no stack): once
EvalScript returns an error the stack is unspecified, so comparing it would
compare an artifact rather than semantics.

Verify with `sha256sum -c` from the repository root.
