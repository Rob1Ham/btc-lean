# Wave 32 — task 15-numeric-086-092

Family: numeric. Assigned rows: SCR-086, SCR-087, SCR-088, SCR-089, SCR-090,
SCR-091, SCR-092.

Pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
Contract: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
Branch: `wave32/15-numeric-086-092`, cut from `805c804` (PR #29). Not pushed.

All cells live under `spec/equiv/cells/e2-numeric/C-L-w32-*` and share the
additive harness `spec/equiv/cells/_tools/w32/` (it does not modify
`cells/_tools/mk_leaf.py`, `cells/_tools/e2/**`, or any existing cell).
Every leaf is loop-free with constant-index byte writes; every Alive2 run is
`alive-tv --bidirectional`; every SAW run uses solver `z3`. Certificates were
verified with `sha256sum -c` from the worktree root.

## Row table

| SCR | status | cell | proved | remains | blocker |
|---|---|---|---|---|---|
| SCR-086 | partial | `e2-numeric/C-L-w32-getint-pick` | OP_PICK's `CScriptNum::getint()` depth use for every four-byte operand: clamp cannot change the observable behaviour; `n = 0` picks, every other `n` gives error 18; both tools green | OP_ROLL's identical getint call; CHECKMULTISIG `nKeysCount`/`nSigsCount`; a C-L pair for a *firing* clamp arm | The verbatim twin OP_ROLL body has a stack-shift loop (not loop-free for Alive2); CMS needs its sig/pubkey loops and a symbolic-count stack; neither twin `decode_num` nor Lean's decoder models an int32 clamp (Lean keeps an unbounded `Int`), so a firing clamp arm is unstateable without changing the L model. The clamp is vacuous at all three sites because the constructor caps operands at 4 bytes. |
| SCR-087 | full | `e2-numeric/C-L-w32-numeric-unary` | 1ADD/1SUB/NEGATE/ABS/NOT/0NOTEQUAL over every four-byte CScriptNum, including the legal 5-byte overflow result; both tools green | — | — |
| SCR-088 | full | `e2-numeric/C-L-w32-numeric-binary` | ADD/SUB/BOOLAND/BOOLOR/NUMEQUAL/NUMNOTEQUAL/LT/GT/LE/GE/MIN/MAX over every pair of four-byte CScriptNum; both tools green | — | — (0x9d is SCR-090) |
| SCR-089 | full | `e2-numeric/C-L-w32-within-4byte` | `min <= x < max` for OP_WITHIN over every triple of four-byte CScriptNum, both outcomes, both tools green | — | — (underflow is SCR-078, >4-byte cap SCR-079/080) |
| SCR-090 | full | `e2-numeric/C-L-w32-numequalverify` | both arms: numeric mismatch ⇒ error 15 with the stack untouched; equal ⇒ both operands dropped, VERIFY tail pops the pushed boolean; all four-byte pairs; both tools green | — | — |
| SCR-091 | full | `e2-numeric/C-L-w32-equal-bytes` | raw serialized-byte equality (length, then bytes) for every pair of 0..5-byte elements, including numeric-equal/byte-unequal (0x01 vs 0x0100) and empty-vs-empty; both tools green | — | — (OP_EQUALVERIFY is not this row) |
| SCR-092 | full | `e2-numeric/C-L-w32-disabled-2div` | 0x8e is OP_2DIV: disabled (error 17) under BASE and WITNESS_V0 for both `fExec` values; tapscript OP_SUCCESS142 pre-scan succeeds on an empty stack for every two-byte script, and yields error 36 under DISCOURAGE_OP_SUCCESS; both tools green | — | — (the L leg is a reviewed Lean transliteration because the twin has no tapscript pre-scan) |

Rows closed (full): SCR-087, SCR-088, SCR-089, SCR-090, SCR-091, SCR-092.
Rows partial: SCR-086. Rows blocked: none wholly; SCR-086's residual is
recorded above and in the cell's `spec.md`/`notes.md`.

## Cells and raw results

| Cell | Alive2 | SAW |
|---|---|---|
| `C-L-w32-numeric-unary` | green, 6 checks | green, 12 proofs |
| `C-L-w32-numeric-binary` | green, 12 checks | green, 24 proofs |
| `C-L-w32-within-4byte` | green, 1 check | green, 2 proofs |
| `C-L-w32-numequalverify` | green, 1 check | green, 2 proofs |
| `C-L-w32-equal-bytes` | green, 1 check | green, 2 proofs |
| `C-L-w32-disabled-2div` | green, 3 checks | green, 6 proofs |
| `C-L-w32-getint-pick` | green, 1 check | green, 2 proofs |

Raw result hashes:

```text
e16c8364c3e38ae9cf557ef02b02bda1f1a1dbc3cbba5c6d85c4bd4fbe89bcc3  C-L-w32-numeric-unary/alive2/result.txt
be7bb450dec48e57c8630eae6231211e01e95c60cb0bbc2ee930a2e0099e2131  C-L-w32-numeric-unary/saw/result.txt
2872647ebe47630fb882577c491d3709e23ea8df2cb2335c96e92a2d480242d6  C-L-w32-numeric-binary/alive2/result.txt
1cfc08197955c1e212dcdb416f63e044b5c7206be2fb43f5e5ed14efcaadf769  C-L-w32-numeric-binary/saw/result.txt
829bc0dfb04318071308b0c104a509f8e70bdf9befc4b5471a81169e7008dc45  C-L-w32-within-4byte/alive2/result.txt
4a68f6b6417de72a51a6865fcbb2ad747f5d1b4d786228c4e41bf18f8436b6d7  C-L-w32-within-4byte/saw/result.txt
9efcb49d83e00a0a73b15cded3f2121c3fa5b01c9718aea2ec4b5dced1304063  C-L-w32-numequalverify/alive2/result.txt
8f873c3ea0ddc36b57e471c2624cb2d9e24087cd48665f4a76fbde8bf3453ceb  C-L-w32-numequalverify/saw/result.txt
caa16fbeec9396756fb04eccad1d922f59bb470750eae465654461d1637df87c  C-L-w32-equal-bytes/alive2/result.txt
e1f1a325b84243cd090c4697aa43b070a26d8b3f861d5303936606df679c433b  C-L-w32-equal-bytes/saw/result.txt
650b401f181edc855bf7e25c2cad150e893631b13d2e432526c86220d09baa56  C-L-w32-disabled-2div/alive2/result.txt
d22de1cdf726c624b6919c2072febf18ce0b4d2d7acae988485f0c78859b2d15  C-L-w32-disabled-2div/saw/result.txt
379fb4e34884a298c4103aa2ede28d12aa0c624d27705c2626ad5494eca18a84  C-L-w32-getint-pick/alive2/result.txt
1646a718b2698c1dc3e3c6ef28e8744a2a28d78412db3d74d135eb745cda15bf  C-L-w32-getint-pick/saw/result.txt
```

Every `alive2/result.txt` ends with `STATUS=alive2-green`; every
`saw/result.txt` ends with `STATUS=saw-green` and has exactly the proof count
above with no `^Proof failed`.

## Exact commands

```sh
cd /tmp/opencode/wave32/15-numeric-086-092

for c in numeric-unary numeric-binary numequalverify equal-bytes \
         within-4byte disabled-2div getint-pick; do
  ./spec/equiv/cells/e2-numeric/C-L-w32-$c/alive2/run.sh
  ./spec/equiv/cells/e2-numeric/C-L-w32-$c/saw/run.sh
done

for c in numeric-unary numeric-binary numequalverify equal-bytes \
         within-4byte disabled-2div getint-pick; do
  for k in alive2 saw; do
    sha256sum -c spec/equiv/cells/e2-numeric/C-L-w32-$c/$k/certificate.sha256
  done
done
```

All 14 certificate checks reported `OK` (18–23 files each).

## Tool configuration and modelling notes

- **Alive2**: `alive-tv --bidirectional`, so `L ⊑ C` and `C ⊑ L` are both
  real results. When both directions hold, alive-tv prints "These functions
  seem to be equivalent!" and a one-line `1 correct transformations` summary.
  The runner requires the success line, a 1/2 summary, `0 incorrect
  transformations`, and no mismatch/error.
- **SAW**: pinned SAW 1.6, solver `z3`. ABC did not terminate on the 40-bit
  sign-magnitude serialization predicate (>13 min, killed); z3 takes seconds.
- **Loop freedom / constant indices**: Alive2 has no loop unrolling. All leaf
  and harness code is loop-free and all byte writes use constant indices.
  Symbolic-index array writes took 2–7 min or timed out; constant-index
  encoders take ~1–3 s.
- **4-byte operands**: each numeric cell fixes operands at four bytes, the
  `CScriptNum` `nMaxNumSize` cap. This covers every value the type can hold
  and makes the width guard statically discharged; the `>4` width arm is
  SCR-079/080.
- **Closed entry points**: one function per opcode rather than a symbolic wire
  argument; a 6/13-way symbolic switch made SMT intractable.
- **Packed observable**: `result(2) | error(6) | depth(3) | top.len(9) |
  top.val(40 LE)`, identical on both legs. It masks the top value to exactly
  `len` bytes so the twin's non-zeroed stack tails cannot leak.
- **`-fno-jump-tables`**: `llvm-extract` keeps a `switch.table` reference but
  not its definition; Alive2 models the external constant as poison and
  reports a spurious "target more poisonous". The flag keeps the generated
  `core_ord` switch inline.
- **Error observables**: for SCR-086's error arm, Core pops `n` before the
  depth guard while the verbatim twin handler returns first. Since the script
  has already aborted, the post-error stack is unspecified; both legs pack
  `result=0` plus the error ordinal with an empty stack (`w32_pack_err` /
  `l_fail_err`). Success paths still carry the full stack.
- **SCR-092 L leg**: `src/ops.txt` is empty and the L code is a reviewed
  transliteration of Lean `Defs.lean:455-492`, `:815-845`, `:1211-1216` and
  `Script/Parser/Defs.lean:206-229`, because `twin/runtime.inc:613-614`
  applies `disabled_wire` under every sigversion and has no tapscript
  OP_SUCCESS pre-scan. The predicates are `always_inline`: with an internal
  call in the extracted IR, Alive2 reported spurious UB on a defined helper
  argument.
- **SCR-086 L leg**: not a transliteration; it is the verbatim `OP_PICK`
  body (the twin does have the handler). The missing int32 clamp is the
  recorded blocker, not hidden.

## What was not done

- No edits to `PINS.lock`, `contract/**`, `spec/db/*`, `results/**`,
  `docs/STATE.md`, `README.md`, Lean proofs, census, existing cells/findings,
  the shared ledger, or another wave's worktree.
- `make equiv`, the ledger updater, and any push were not run (the
  orchestrator integrates and regenerates).
- No behavioral run is used as proof evidence; every green above has raw
  Alive2 and SAW output and a verified certificate.
