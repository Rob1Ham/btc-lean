# Notes — C-L-w32-p2sh-23byte

**Verdict:** both tools green for two functions (pattern predicate and the
P2SH restore/re-evaluate arm). `scr_row_coverage` is **partial** for SCR-005:
the HASH160 transform is an explicit symbolic premise.

**Raw runs:**

```sh
bash spec/equiv/cells/exec-verify/C-L-w32-p2sh-23byte/alive2/run.sh
bash spec/equiv/cells/exec-verify/C-L-w32-p2sh-23byte/saw/run.sh
```

- `alive2/result.txt`: two `Transformation seems to be correct!` blocks, two
  `1 correct transformations`, `STATUS=alive2-green`.
- `saw/result.txt`: four `Proof succeeded!` (is_p2sh and p2sh_reeval on C and
  L), `STATUS=saw-green`.

**Function 1 — `cell_is_p2sh`.** Core's test (script.cpp:224-231) is
transcribed on symbolic `len`, `b0`, `b1`, `b22`. The L leg builds a 23-byte
buffer and runs the twin's `is_p2sh` over it, so the comparison also covers
that the twin's `n == 23 &&` guard short-circuits before the `b[22]` read.
Both are total over 64-bit inputs because the bytes are truncated to 8 bits on
both legs. This is what makes "23-byte HASH160 script" exact: length 23,
`0xa9` at 0, `0x14` at 1, `0x87` at 22, everything else irrelevant.

**Function 2 — `cell_p2sh_reeval`.** The stack sequence proved is Core's:

1. `EvalScript(scriptPubKey = OP_HASH160 <h> OP_EQUAL)` runs on the
   post-scriptSig stack — underflow is 18, and `hash_match = 0` leaves a false
   top and yields EVAL_FALSE (2). The hash computation is the seam.
2. Only then does the P2SH block run: `scriptSig.IsPushOnly()` (26 on a
   non-push op).
3. `swap(stack, stackCopy)` restores the post-scriptSig stack, the top
   (the serialized redeem script, i.e. the last scriptSig stack element) is
   removed, and the redeem script is evaluated on the remainder.
4. Empty stack or false top after the subscript is EVAL_FALSE; otherwise
   success.

The L leg is a different program shape (a `Saved` record, an explicit
`eval_stack.n -= 1` and the twin's `st_top`/`cast_to_bool` form), so Alive2 is
comparing two implementations, not the same text twice.

**What is not claimed.** `hash_match` is a premise, not a proved HASH160
result. The redeem-script bytes are not compared to the scriptSig push
(`WITNESS_MALLEATED_P2SH`, SCR-012), and sigop counting is out of scope. These
are the exact seams in `spec.md`.

**Certificate.** Hash lists include the pinned `contract/error_kind.h`, the
shared `_tools/w32-exec` harness, the twin sources, build artifacts and raw
result. Verify from the repository root with `sha256sum -c`.
