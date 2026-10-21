# exec-verify/C-L-w64-p2sh-single-push — notes

## What the cell is

Three bounded leaves covering SCR-012 (`interpreter.cpp:2092-2096` at
`cce32b168`), the P2SH-wrapped witness-program malleability guard:

- `cell_canon_prefix` — `CScript::AppendDataSize` (script.h:408-424) /
  Lean `lenBytes` (Script/Parser/Defs.lean:367-377): kind, prefix length and
  the five prefix bytes, for every 32-bit length.  All four encodings,
  including the PUSHDATA1/2/4 branches the row domain does not reach.
- `cell_sig_push` — the producing scriptSig evaluation for a one-op script:
  `GetScriptOp` at pc = 0 (script.cpp:313-363), `single` = one complete push,
  the pushed element length, the MINIMALDATA gate (interpreter.cpp:489-490)
  and the BAD_OPCODE result of a failed decode (455-456).
- `cell_p2sh_guard` — the 2092 guard itself: recompute
  `IsWitnessProgram(pubKey2)` from the bytes (script.cpp:250-264), compare the
  *whole* scriptSig byte for byte with `[plen] ++ pubKey2`, and return
  pass / 16 / 25 / 42 with Core's precedence.

## Two independent encodings

- C leg (`src/c_leaf.cpp`): a line-cited source-excerpt slice in Core's
  control-flow order.  The 2092 comparison is field-wise, exactly like
  `CScript::operator==` on a `prevector` (prevector.h:429): size equality,
  then first-byte and payload byte equality.
- L leg (`src/l_leaf.cpp`): a reviewed transliteration of Lean's
  `p2shInner` shape (Interpreter/Defs.lean:1327-1356): encode first
  (`pushBytesWire pubKey2` = `lenBytes plen ++ pubKey2`) and compare the whole
  wire byte string; decode with a `getOpAux`-shaped read (`readLE`,
  `sliceOpt`-style bounds checks); `checkMinimalPush` (Defs.lean:529-537);
  `isWitnessProgram` (Defs.lean:510-526).  It is not twin-generated.

Both legs take script bytes as little-endian u64 chunks (byte `8k+j` is
`chunk[k] >> 8j`): 42 redeemScript bytes fit in 6 chunks, 56 bytes of
scriptSig storage in 7.  Every loop is fully unrolled so the leaves are
straight-line code.

## Findings recorded during development

1. **Normalized observables on a failed decode (F-DIV-001 seam).**  Core's
   `GetScriptOp` writes `opcodeRet` (and may write the partial length) before
   it fails; `EvalScript` returns BAD_OPCODE immediately and never observes
   those fields (interpreter.cpp:455-456).  Lean's `getOp` returns `none`.
   Both legs therefore set `op = is_push = dlen = next = 0` on failure and
   report only `ok = 0, err = 16`.  The Cryptol statement does the same.  This
   is a deliberate, disclosed normalization of unobservable state, not a
   semantic difference.

2. **`min_ok` is a conjunction, not a guard.**  Core computes
   `d.ok && CheckMinimalPush(dlen, first, op)` after zeroing the fields on
   failure, so `CheckMinimalPush(0, 0, 0)` is *true* while `min_ok` is false.
   The spec keeps the bitwise conjunction (`ok && minimal ...`), not
   `if ok then minimal ... else false`; the two differ on the failed-decode
   row of the packed output.

3. **Cryptol literal widths.**  In the pinned `cryptol 3.6.0 (61dd17b)`, a hex
   literal has type `[8]` and does not unify with `[64]` even under an
   annotation, and `let` is not accepted in these declaration positions.  The
   spec therefore uses named decimal `[64]` constants for word-width magic
   numbers (`c76`, `c255`, ...) and keeps hex only in byte-width positions.
   Not a semantics issue; recorded so the next cell does not re-discover it.

4. **SAW simulation of branchy unrolled folds.**  The first C leg wrote the
   byte windows as
   `for (...) { if (r && i < dlen && a != b) r = 0; }`.  The IR was ~2.7k
   lines with ~450 branches and SAW's *simulation* (before any solver call)
   grew past 25 GB / 13 min, and 57 GB with z3, even when the postcondition
   was only `plen`.  Rewriting the two loops as branchless XOR accumulators
   (`diff |= (i < dlen) ? (a ^ b) : 0`) reduced the IR to ~1.9k lines and the
   whole six-proof SAW run to ~15 s / 240 MB.  The rewritten C leg was
   re-checked by Alive2 against the unchanged L leg.  This is a harness
   effect, not a semantics change: the folded value is the same predicate.

5. **Scratch cross-check (not evidence).**  A throwaway C++ harness in
   `/tmp` drove both legs over: the canon boundaries 0/75/76/255/256/65535/
   65536, canonical pushes of 4..42 bytes, PUSHDATA1/2/4 encodings of the same
   programs (42 with `minimaldata = 0`, 25 with `minimaldata = 1`),
   `elem_eq = 1` for those non-canonical encodings, truncated pushes (16), and
   trailing bytes after one push (sentinel 3).  C and L agreed on every case.
   It is not tracked; the committed evidence is Alive2 + SAW.

## Why 4..42 is the whole row

`IsWitnessProgram` (script.cpp:250-264) is false for `size() < 4` and
`size() > 42`, and the 2092 comparison sits inside
`if (pubKey2.IsWitnessProgram(...))`.  So no redeemScript outside 4..42 can
reach the guard, and a single push of one is at most `5 + 42 = 47` bytes
(PUSHDATA4 prefix).  49 bytes of scriptSig storage is therefore a superset of
every wire form the row can see.  The domain bound is on the *input* scriptSig,
not a weakened predicate: every byte is symbolic.

## Non-canonical pushes are the point

A `PUSHDATA1/2/4` encoding of the same 42-byte program produces the same stack
element, so it passes the subscript `EvalScript` and reaches 2092 — but it is
not `CScript() << pubKey2`.  The cell shows:

- `eq = 0` and `elem_eq = 1` for such a scriptSig;
- with `minimaldata = 0` the guard returns 42 (the malleability rejection);
- with `minimaldata = 1` it returns 25 earlier, because `EvalScript(scriptSig)`
  checks minimality at 489-490, before 2092.

Both are Core's order.  This is exactly the "scriptSig must be *exactly* a
single push" property, not merely "the pushed element equals the redeemScript".

## What is not modelled

- The subscript `EvalScript(stack, pubKey2, ...)` (2080-2082) and its
  EVAL_FALSE checks; the cell starts where the guard is reached.
- `VerifyWitnessProgram` (2097-2098).
- ScriptSigs that are not one complete push: `verdict = 3`.  The EvalScript
  loop is the E5 residual, and such an input cannot produce 42 anyway.
- Everything else in `VerifyScript` (other rows; the tail is
  `cells/exec-verify/C-L-verifyscript-tail`), plus crypto/hash/signature.

## Exact commands and results

```sh
bash spec/equiv/cells/exec-verify/C-L-w64-p2sh-single-push/alive2/run.sh
bash spec/equiv/cells/exec-verify/C-L-w64-p2sh-single-push/saw/run.sh
```

Alive2: `1 correct transformations`, `0 incorrect`, `0 Alive2 errors` for each
of the three functions (C vs L), `STATUS=alive2-green`.

SAW: six `Proof succeeded!` (three functions x C/L) against `src/cell.cry` with
preconditions `plen <= 42`, `slen <= 49`, `minimaldata <= 1` (and
`dlen < 2^32` for the prefix leaf), `STATUS=saw-green`.  Raw logs are
`alive2/result.txt` and `saw/result.txt`; the certificates hash the tracked
inputs plus the generated IR and both results.
