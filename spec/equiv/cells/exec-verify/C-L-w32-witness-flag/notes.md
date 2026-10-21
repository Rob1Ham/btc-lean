# Notes — C-L-w32-witness-flag

**Verdict:** both tools green. This is the strongest row of the wave-32
`exec-verify` batch: SCR-004 is covered on every arm the row names, including
the one-element CLEANSTACK arm that the row text marks as previously unproved.

**Raw runs:**

```sh
bash spec/equiv/cells/exec-verify/C-L-w32-witness-flag/alive2/run.sh
bash spec/equiv/cells/exec-verify/C-L-w32-witness-flag/saw/run.sh
```

- `alive2/result.txt`: `Transformation seems to be correct!`,
  `1 correct transformations`, `STATUS=alive2-green` (`--always-verify`).
- `saw/result.txt`: two `Proof succeeded!` (C and L), `STATUS=saw-green`.

**The row, arm by arm (all symbolic in the proof):**

| flags | witness | result |
|---|---|---|
| WITNESS off | any | `(1, 0)` success (the empty-spk spend) |
| WITNESS on | empty | `(1, 0)` success |
| WITNESS on | non-empty | `(0, 43)` WITNESS_UNEXPECTED |
| WITNESS on + CLEANSTACK on | empty | `(1, 0)` (n == 1 passes cleanstack) |
| WITNESS on + CLEANSTACK on | non-empty | `(0, 43)` (cleanstack passes, then unexpected) |
| CLEANSTACK on, WITNESS off | any | out of domain (Core assert); UNKNOWN guard |

**Why WITNESS_UNEXPECTED and not CLEANSTACK.** Core runs the cleanstack check
(2115-2118) before the unexpected-witness tail (2125-2127). With exactly one
element on the stack the cleanstack check passes, so the observable error is
43. A cell that reordered the two would fail Alive2 immediately; the order is
therefore part of what is proved.

**What is not claimed.** The scriptSig evaluation result is an input
(`hss`), and the empty scriptPubKey evaluation is the Lean identity
(`evalScriptBytes_empty`). This cell does not prove that a real scriptSig
reaches that stack, nor the EvalScript loop. Those are the same seams as the
Lean row face.

**Certificate.** Hash lists include the pinned `contract/error_kind.h`, the
shared `_tools/w32-exec` harness, the twin sources, build artifacts and raw
result. Verify from the repository root with `sha256sum -c`.
