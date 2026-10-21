# Wave 32 — `01-exec-001-005` (exec-verify, SCR-001…SCR-005)

**Family scope:** exec-verify
**Assigned rows:** SCR-001, SCR-002, SCR-003, SCR-004, SCR-005
**Worktree:** `/tmp/opencode/wave32/01-exec-001-005` (branch `wave32/01-exec-001-005`)
**Base:** PR #29 head `805c8042f92d3bed909ca40219a4d21fc9150cc1`
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`; contract
`f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6` (recipe
recomputed in this worktree)
**Tools:** Alive2 v20.0 (LLVM 20.1.2), SAW 1.6 (`68eed5f`), clang 20.1.2

## Row table

| SCR | status | cell | what was proved | what remains | exact blocker |
|---|---|---|---|---|---|
| SCR-001 | **partial** | `exec-verify/C-L-w32-verify-sequential` | scriptSig error short-circuits before the scriptPubKey evaluation; the scriptPubKey (`OP_DUP`) is evaluated on the post-scriptSig stack (depth/top carried in, not reset, not concatenated); DUP underflow (18) and MAX_STACK_SIZE (8) edges; final decision taken on the stack the second evaluation produced | the CVE-2010-5141 parse-boundary witness (a scriptSig push whose declared length runs into scriptPubKey bytes is truncated at the scriptSig end) | needs a bounded `CScript::GetOp` over a byte buffer with an explicit `end` plus the EvalScript loop. Next experiment: `C-L-w32-getop-boundary`, 8-byte symbolic buffer, symbolic split point, straight-line GetOp, prove split vs split+1 differ exactly when a push straddles the boundary |
| SCR-002 | **full** (bounded element width ≤ 8 bytes) | `exec-verify/C-L-w32-verify-final-truth` | empty stack → EVAL_FALSE(2); non-empty false top → EVAL_FALSE; truthy top → success; first-failure error precedence ss_err before spk_err; CastToBool including negative zero (lone wire-last `0x80`) and the empty element | that EvalScript actually produces those outcomes (row-face hypothesis `hss`/`hspk`, as in `PDW90.verifyScriptFull_sequential`); witness/P2SH/cleanstack tails (other cells) | not a blocker for the row: element **content** wider than 8 bytes is outside the cell encoding (UNKNOWN guard); the CastToBool rule itself is length-generic |
| SCR-003 | **partial** | `exec-verify/C-L-w32-verify-final-truth`, `…-witness-flag` | the post-evaluation consequence (empty/false top → EVAL_FALSE; empty scriptPubKey is the identity on a one-truthy-element stack, so the spend validates with WITNESS off) | "empty **and short** script evaluates to success with unchanged stack" at the EvaluScript level: the identity is a hypothesis (`PDW90.evalScriptBytes_empty`, lines 15-18), not an IR result | needs the same bounded GetOp + EvalScript loop as SCR-001 (script length 0 and 1..2, including a lone `0x01`-style short push). Smallest next experiment: straight-line 2-step bounded evaluator over an 8-byte buffer, postcondition `eval(empty, st) = ok st` and `eval(0x51, st) = ok (1::st)` |
| SCR-004 | **full** | `exec-verify/C-L-w32-witness-flag` | WITNESS off + empty scriptPubKey + one truthy element → success; WITNESS on + empty witness → success; WITNESS on + non-empty witness → WITNESS_UNEXPECTED(43); all arms also with CLEANSTACK on (the one-element arm the row marks unproved), with the cleanstack-before-unexpected order proved | scriptSig eval outcome and empty-script identity remain the row hypotheses (same as the Lean row face) | no row blocker; CLEANSTACK without WITNESS is Core-asserted and declared out of domain (UNKNOWN guard on both legs) |
| SCR-005 | **partial** | `exec-verify/C-L-w32-p2sh-23byte` | exact 23-byte HASH160/EQUAL template predicate over symbolic length and bytes (total, `a9 14 … 87`); P2SH arm restores `stackCopy`, removes exactly the last scriptSig stack element (the serialized redeem script) and evaluates it as the subscript; final truth decision; hash-equality gate and its precedence over the push-only check | HASH160 computation (`hash_match` is a symbolic premise); `scriptSig == CScript() << redeemScript` (WITNESS_MALLEATED_P2SH, SCR-012); BIP16 activation; sigop counting | crypto/hash premise is the same-crypto seam (`docs/DECISION-lax-ecdsa.md`, `contract/ABI.md` §7) — not provable inside a bounded cell; the serialized-push comparison needs the GetOp/push-encoding leaf (`ss_equals_push`, twin/runtime.inc:319) |

Rows closed: **2** (SCR-002, SCR-004). Rows partial: **3** (SCR-001,
SCR-003, SCR-005). Rows untouched: none.

Honest reading of the count: SCR-002 is `full` for the predicate the row
names, with a declared 8-byte element encoding bound; if a reviewer requires
the `520`-byte element width inside the cell, downgrade it to partial — the
rule is the same but the encoding is not. SCR-004 is full on every arm the
row text names, including the one-element CLEANSTACK arm the row marks
unproved, but keeps the row-face hypotheses (scriptSig outcome, empty-script
identity).

## Cells

| cell | functions | Alive2 | SAW | certificate |
|---|---|---|---|---|
| `spec/equiv/cells/exec-verify/C-L-w32-verify-final-truth` | `cell_verify_final` | green (`--always-verify`, 1 transformation) | 2 proofs | `alive2/certificate.sha256`, `saw/certificate.sha256` |
| `spec/equiv/cells/exec-verify/C-L-w32-verify-sequential` | `cell_verify_sequential` | green (1 transformation) | 2 proofs | both |
| `spec/equiv/cells/exec-verify/C-L-w32-witness-flag` | `cell_witness_flag` | green (1 transformation) | 2 proofs | both |
| `spec/equiv/cells/exec-verify/C-L-w32-p2sh-23byte` | `cell_is_p2sh`, `cell_p2sh_reeval` | green (2 transformations) | 4 proofs | both |

Shared harness (new, wave-32 only): `spec/equiv/cells/_tools/w32-exec/`
(`w32_common.h`, `build_cell.sh`, `run_alive2.sh`, `run_saw.sh`). No existing
cell, finding, tool, contract, pin, ledger or generated result was edited.

Legs: **C** = line-cited source-excerpt slices of Core at the pin
(`interpreter.cpp`, `script.cpp`), with the EvalScript/crypto outcomes as
explicit symbolic premises where named; **L** = reviewed transliterations of
the verified Lean `verifyScriptFull`/`p2shInner` structure and the twin's
`runtime.inc`/`ops_ir.py` shapes. The C and L bodies are deliberately
different programs (different CastToBool algorithms, different size-check
placement, different P2SH restore shapes), so Alive2 is doing a semantic
comparison, and `--always-verify` forbids the "syntactically equal" shortcut.

## Exact commands

From the repository root of the worktree:

```sh
for c in verify-final-truth verify-sequential witness-flag p2sh-23byte; do
  d=spec/equiv/cells/exec-verify/C-L-w32-$c
  bash $d/alive2/run.sh
  bash $d/saw/run.sh
done
```

Each runner rebuilds its cell with `/usr/bin/clang++-20 -std=c++17 -O1`
(the repo's robustness lane, same flags as the E2/E4 cells), extracts each
exported function recursively with `llvm-extract` (LLVM 20.1.2), and writes
`alive2/result.txt` / `saw/result.txt` plus a `sha256sum -c`-able certificate
list. Alive2 is invoked as:

```sh
alive-tv --always-verify build/c_<fn>.ll build/l_<fn>.ll
```

SAW is invoked as `saw cell.saw` (solver `abc`) on a spec that verifies each
leg against one Cryptol function. **No `llvm_unsafe_assume_spec` is used**;
the cell modules call no external function that would need an override.

## Raw outcomes

```
C-L-w32-verify-final-truth   alive2: Transformation seems to be correct! / 1 correct / STATUS=alive2-green
                             saw:    2x Proof succeeded! / CELL_W32_VERIFY_FINAL_SAW_GREEN / STATUS=saw-green
C-L-w32-verify-sequential    alive2: Transformation seems to be correct! / 1 correct / STATUS=alive2-green
                             saw:    2x Proof succeeded! / CELL_W32_VERIFY_SEQUENTIAL_SAW_GREEN / STATUS=saw-green
C-L-w32-witness-flag         alive2: Transformation seems to be correct! / 1 correct / STATUS=alive2-green
                             saw:    2x Proof succeeded! / CELL_W32_WITNESS_FLAG_SAW_GREEN / STATUS=saw-green
C-L-w32-p2sh-23byte          alive2: 2x Transformation seems to be correct! / 2x 1 correct / STATUS=alive2-green
                             saw:    4x Proof succeeded! / CELL_W32_P2SH_23BYTE_SAW_GREEN / STATUS=saw-green
```

Certificate verification (all four cells, from the repository root):

```sh
for c in verify-final-truth verify-sequential witness-flag p2sh-23byte; do
  d=spec/equiv/cells/exec-verify/C-L-w32-$c
  sha256sum -c $d/alive2/certificate.sha256
  sha256sum -c $d/saw/certificate.sha256
done
# observed: exit 0 for all eight lists (14, 14, 14, 14, 14, 14, 16, 14 entries OK)
```

The `build/` artifacts named in the certificates are gitignored and
regenerated by the runners (same convention as the existing E2/E4 cells), so
on a fresh checkout run the two runners first and then `sha256sum -c`.

## Tool findings from this wave

1. **Alive2 caught a real edge divergence in the sequential cell.** The first
   run reported a value mismatch at `ss_depth = 2^64-1`: the C leg's
   `stack.push_back` then post-op `stack.size() > 1000` wraps the 64-bit
   counter to 0, while the twin's pre-push `n >= 1000` returns STACK_SIZE.
   The state is unreachable (a successful scriptSig evaluation cannot leave
   > 1000 elements), so the cell now declares `ss_depth <= 1000` and returns
   UNKNOWN outside it. Recorded in the cell's `notes.md`; the cell is
   discriminating, not vacuous.
2. **Cryptol 1.6 literal widths.** In this SAW's Cryptol, hex literals are
   fixed at `[8]` and do not widen by annotation, and `&&` binds tighter than
   `==`; the specs use decimal masks and explicit parentheses. This cost two
   iterations and is noted so other wave-32 agents do not repeat it.
3. No infrastructure failure otherwise: both tools ran to completion on every
   cell; no timeouts, no solver crashes.

## No-go statements (smallest next experiments)

- **SCR-001 remainder / SCR-003:** both need one new leaf, not a new harness:
  a bounded `GetOp` + EvalScript loop over an 8-byte symbolic script buffer.
  Build it once as `C-L-w32-getop-boundary` and reuse it for the truncated-push
  witness (sequential-not-concatenated) and for the empty/short-script
  identity. Alive2 needs `--src-unroll/--tgt-unroll` or a straight-line
  unrolled body; SAW will need no invariant at that size.
- **SCR-005 remainder:** the HASH160 transform is the same-crypto premise and
  is not in scope for an IR cell; the `scriptSig == push(redeemScript)` byte
  equality is a push-encoding leaf (`ss_equals_push`) that can be added
  independently of the crypto seam.

## Files added by this task

```
spec/equiv/cells/_tools/w32-exec/{w32_common.h,build_cell.sh,run_alive2.sh,run_saw.sh}
spec/equiv/cells/exec-verify/C-L-w32-verify-final-truth/{spec.md,notes.md,src/*,alive2/*,saw/*}
spec/equiv/cells/exec-verify/C-L-w32-verify-sequential/{spec.md,notes.md,src/*,alive2/*,saw/*}
spec/equiv/cells/exec-verify/C-L-w32-witness-flag/{spec.md,notes.md,src/*,alive2/*,saw/*}
spec/equiv/cells/exec-verify/C-L-w32-p2sh-23byte/{spec.md,notes.md,src/*,alive2/*,saw/*}
spec/equiv/findings/wave32/01-exec-001-005/report.md
```
