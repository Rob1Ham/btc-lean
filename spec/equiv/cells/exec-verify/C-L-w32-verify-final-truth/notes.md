# Notes — C-L-w32-verify-final-truth

**Verdict:** both tools green. Alive2 compares the C slice with the Lean-shaped
transliteration over fully symbolic inputs; SAW verifies each leg against one
Cryptol function. No `llvm_unsafe_assume_spec` is used (there are no externals
to override: the EvalScript outcome is a plain argument of the model).

**Raw runs (this cell):**

```sh
bash spec/equiv/cells/exec-verify/C-L-w32-verify-final-truth/alive2/run.sh
bash spec/equiv/cells/exec-verify/C-L-w32-verify-final-truth/saw/run.sh
```

- `alive2/result.txt` — `Transformation seems to be correct!`,
  `1 correct transformations`, `STATUS=alive2-green`. `--always-verify` forces
  the SMT obligation even though the two modules are not syntactically equal.
- `saw/result.txt` — two `Proof succeeded!` lines (C module and L module),
  `CELL_W32_VERIFY_FINAL_SAW_GREEN`, `STATUS=saw-green`.

**What the two legs are.**

| leg | source | shape |
|---|---|---|
| C | `interpreter.cpp:2037-2040` transcript | `stack.empty()` then `CastToBool(stack.back())`; CastToBool is Core's first-nonzero loop (`interpreter.cpp:46-59`) |
| L | Lean `verifyScriptFull` tail (`Defs.lean:1382-1383`) | `stack = [] ∨ !castToBool stack[0]!`; CastToBool is the reversed-list form (`castToBoolList`, ScriptNum.lean:648) |

The two CastToBool implementations are different algorithms; their agreement
is part of what Alive2 proves. The negative-zero corner (`0x80` as the only,
wire-last, nonzero byte) is inside the proved domain because `top_len` and
`top` are symbolic.

**Seam / what is not claimed.** The outcome of the two EvalScript calls is an
input. This cell therefore proves the *post-evaluation* check that SCR-002
names, not that any particular script reaches it. The witness, P2SH and
cleanstack tails are separate cells (`C-L-w32-witness-flag`,
`C-L-w32-p2sh-23byte`).

**Domain bound.** The stack element encoding is 8 bytes. `top_len > 8`
returns the UNKNOWN guard on both legs and is out of domain; longer elements
obey the same first-nonzero/last-0x80 rule, so the missing part is encoding
width, not a rule branch. Stated in `spec.md` and in the wave-32 report.

**Certificate.** `alive2/certificate.sha256` and `saw/certificate.sha256`
hash the spec, this cell's sources, the shared `_tools/w32-exec` harness, the
pinned `contract/error_kind.h`, the twin sources the L shape is reviewed
against, the build artifacts and the raw result. Verify from the repository
root with `sha256sum -c`.
