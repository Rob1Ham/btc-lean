# Notes — C-L-w32-verify-sequential

**Verdict:** both tools green over fully symbolic inputs.
`scr_row_coverage` is **partial** for SCR-001: the sequential stack threading
is proved, the CVE-2010-5141 parse boundary is not.

**Raw runs:**

```sh
bash spec/equiv/cells/exec-verify/C-L-w32-verify-sequential/alive2/run.sh
bash spec/equiv/cells/exec-verify/C-L-w32-verify-sequential/saw/run.sh
```

## The first Alive2 run found a divergence (kept as evidence)

The initial version had no depth guard. Alive2 produced a counterexample:

```
i64 %ss_err = 0
i64 %ss_depth = #xffffffffffffffff (2^64-1)
i64 %ss_top = 0
i64 %ss_top_len = 0
Source value: #x0000000000000008 (8)     <- C: n+1 wraps to 0 -> EVAL_FALSE
Target value: #x0000000000000020 (32)    <- L: n >= 1000 -> STACK_SIZE
```

That is a real difference between Core's `stack.push_back` + post-op
`stack.size() > MAX_STACK_SIZE` check and the twin's pre-push
`s.n >= MAX_STACK_SIZE` check — but only for depth > 1000, which no successful
EvalScript can produce (the first evaluation would already have failed with
SCRIPT_ERR_STACK_SIZE). The cell therefore now declares the reachable domain
`ss_depth <= 1000` and returns the UNKNOWN guard outside it on both legs. The
run is recorded here rather than hidden; the cell is discriminating, not
vacuous.

## What is proved

1. A scriptSig EvalScript error is returned before the scriptPubKey runs.
2. The scriptPubKey evaluation receives the post-scriptSig stack: its depth
   drives the DUP underflow arm (depth 0 -> 18), its depth drives the size
   arm (1000 -> 8), and its top drives the final truth decision. A version
   that reset the stack between the two evaluations, or that evaluated the
   scriptPubKey on an empty stack, fails the SAW spec.
3. The two legs agree for every input in the domain, including two different
   CastToBool implementations (Core first-nonzero loop vs Lean reversed-list)
   and two different size-check placements.

## What is not proved (exact blocker)

SCR-001 is "sequential evaluation, not concatenation", with CVE-2010-5141. The
discriminating witness is a scriptSig ending in a push opcode whose declared
data length runs past the scriptSig end: sequential evaluation truncates at
the scriptSig boundary and fails with BAD_OPCODE (16), while a concatenated
evaluation would consume scriptPubKey bytes as push data and could succeed.
Proving that needs:

- a bounded `GetScriptOp`/`CScript::GetOp` over a byte buffer with an explicit
  `end` pointer (push length vs remaining bytes), and
- the EvalScript loop over that buffer (alive-tv `--src-unroll`/`--tgt-unroll`
  or a straight-line unrolled bounded evaluator for a fixed small buffer),

neither of which is in this cell. The smallest next experiment: a
`C-L-w32-getop-boundary` cell with an 8-byte symbolic script buffer, a
symbolic split point, and a straight-line `GetOp` that returns
`(opcode, push_len, next)` or parse-failure; prove `split` and `split+1`
behave differently exactly when the push straddles the boundary.

**Certificate.** `alive2/certificate.sha256` and `saw/certificate.sha256`
hash the spec, sources, shared `_tools/w32-exec` harness, pinned
`contract/error_kind.h`, twin sources, build artifacts and raw result; verify
from the repository root with `sha256sum -c`.
