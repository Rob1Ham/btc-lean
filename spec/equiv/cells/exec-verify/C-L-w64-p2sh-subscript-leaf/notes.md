# Notes — C-L-w64-p2sh-subscript-leaf

**Verdict:** both tools green for one bounded function. `scr_row_coverage` is
**partial** for SCR-005: this cell removes the *redeem-script outcome premise*
of `C-L-w32-p2sh-23byte` for an explicit one-instruction leaf, but it does
**not** prove the real `EvalScript` body (E5 residual), so the row is not
promoted to full.

## What advanced

`exec-verify/C-L-w32-p2sh-23byte` proved the P2SH arm with the subscript
outcome `(redeem_err, redeem_depth, redeem_top, redeem_top_len)` as four
symbolic inputs. That left the call itself unconstrained: any triple was
admissible. This cell replaces those four inputs with a computed outcome for
a declared leaf:

1. The call target bytes **are** the last scriptSig stack element: the same
   `ss_top`/`ss_top_len` is popped from `stackCopy` and is `pubKey2`.
2. The call's argument stack is `stackCopy` minus that element; the cell
   tracks its depth and top element (`prev_*`). No deeper element is read by
   any in-domain instruction.
3. The bounded evaluation is a line-cited transcription of `GetScriptOp` +
   one `EvalScript` instruction (push / OP_RETURN / parse failure), including
   `CScriptNum` push encoding and the post-op stack-size check.
4. Core's two EVAL_FALSE checks at interpreter.cpp:2083-2086 are applied to
   the stack the evaluation returned, in Core's order: `stack.empty()` first,
   then `CastToBool(stack.back())`.

## Leaf domain (declared, both legs return the out-of-model marker outside)

Subscript length 0..2 (at most one instruction):

| script | instruction | return |
|---|---|---|
| empty | none | `(1,0)` if depth ≥ 2 and `CastToBool(prev)`, else `(0,2)` |
| `00` | OP_0 pushes empty | `(0,2)` |
| `4f` | OP_1NEGATE pushes `81` | `(1,0)` |
| `51..60` | OP_1..OP_16 pushes `01..10` | `(1,0)` |
| `6a` | OP_RETURN | `(0,3)` |
| `01..4e` | truncated push/PUSHDATA | `(0,16)` |
| `01 b` | direct 1-byte push of `b` | `(0,2)` iff `b` is 0 or `80` (len 1), else `(1,0)` |
| `4c 00` | PUSHDATA1 of zero bytes | `(0,2)` |
| `4c b>0`, `02..4b`, `4d`, `4e` | truncated | `(0,16)` |

Anything else (e.g. `00 51` two instructions, `50` OP_RESERVED, `61` OP_NOP,
`76` OP_DUP, `4c b1>0` payloads that fit) is out of model. The raw encoding
is `pack(result, error) = result | error << 2`, error ordinals from
`contract/error_kind.h`.

## Exact commands and raw outcomes

From the repository root:

```sh
bash spec/equiv/cells/exec-verify/C-L-w64-p2sh-subscript-leaf/alive2/run.sh
bash spec/equiv/cells/exec-verify/C-L-w64-p2sh-subscript-leaf/saw/run.sh
bash spec/equiv/cells/exec-verify/C-L-w64-p2sh-subscript-leaf/concrete/run.sh
bash spec/equiv/cells/exec-verify/C-L-w64-p2sh-subscript-leaf/mutant/run.sh
```

Observed:

```
alive2/result.txt:
  Transformation seems to be correct!
  Summary: 1 correct transformations, 0 incorrect, 0 failed-to-prove, 0 Alive2 errors
  STATUS=alive2-green

saw/result.txt:
  Proof succeeded! cell_p2sh_subscript_leaf      (C module, vs cell.cry)
  Proof succeeded! cell_p2sh_subscript_leaf      (L module, vs cell.cry)
  CELL_W64_P2SH_SUBSCRIPT_LEAF_SAW_GREEN
  STATUS=saw-green

concrete/result.txt:
  checked=561848 skipped_out_of_model=1280356 mismatches=0
  STATUS=core-differential-green
```

Alive2 is invoked with `--always-verify`, so the C and L functions are
compared by SMT, not by the syntactically-equal shortcut. SAW uses solver
`abc`, no `llvm_unsafe_assume_spec`, and both legs call nothing outside their
module. Both legs are built with `/usr/bin/clang++-20 -std=c++17 -O1` and each
exported function is extracted recursively (`llvm-extract`, LLVM 20.1.2).

## Concrete Core differential (evidence, not proof)

`concrete/diff_core.cpp` includes no model: it calls the real
`EvalScript(stack, CScript(pubKey2), SCRIPT_VERIFY_P2SH, checker,
SigVersion::BASE, execdata, &serror)` from the local Core build at the pin and
applies :2083-2086 to the returned stack. The C model is the same
`src/c_cell.cpp` compiled into the harness. The input space is every byte
string of length 0..2 (1 + 256 + 65536) times depth {1,2,3,12} times seven
`prev` elements that cover CastToBool: empty, `01`, `80` (negative zero),
`0101`, `0001`, `0080` (negative zero at the wire-last byte), `8100`. Result:
561,848 in-leaf inputs, 0 mismatches; 1,280,356 inputs returned the
out-of-model marker and were skipped (all multi-instruction scripts and
opcodes outside the leaf, e.g. `OP_RESERVED`, `OP_NOP`, `OP_DUP`).

What the harness records in `concrete/result.txt`: the source hashes of
`interpreter.cpp` (`57a6f328…`) and `script.cpp` (`210b1720…`), the
`libbitcoin_consensus.a` and `libsecp256k1.a` hashes, and the hashes of the
model and harness sources. The build tree is not a git checkout, so the pin
is inferred from the source hashes (both match the pinned `core-pin` tree)
and from the libraries built from it; this is why the differential is filed
as evidence, not as a pinned-refinement result.


## Negative controls (mutants)

`mutant/run.sh` applies one semantic change at a time to the C leg and runs
Alive2 against the real L leg. Raw output: `mutant/result.txt`.

| mutant | change | outcome |
|---|---|---|
| `m1_no_popstack` | `stack{ss_depth, ss_top, ss_top_len}` — evaluate with the redeem element still on the stack (skip :2078) | counterexample: `depth=2, top_len=0, prev_top=1, prev_len=2` |
| `m2_wrong_top` | read the EVAL_FALSE element from `ss_top/ss_top_len` (the redeem bytes) instead of the returned stack top | counterexample: `depth=12, top_len=0, prev_top=1, prev_len=1` |

Both `MUTANT_CAUGHT=…`; `STATUS=mutants-caught`. The green cell is therefore
discriminating on both the restore/pop boundary and the element the truth
check reads.

## Certificate

The certificate files are exactly what the shared
`spec/equiv/cells/_tools/w32-exec` runners emit: `spec.md`, the runner, the
shared harness (`w32_common.h`, `build_cell.sh`, `run_*.sh`), the twin
sources, `contract/error_kind.h`, `build.txt`, the extracted `.ll` files and
the raw result. `build/` is gitignored (regenerated by the runners), so on a
fresh checkout run the two runners first, then:

```sh
sha256sum -c spec/equiv/cells/exec-verify/C-L-w64-p2sh-subscript-leaf/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w64-p2sh-subscript-leaf/saw/certificate.sha256
```

## Residual (exact, not claimed)

- The real `EvalScript` body for arbitrary scripts is still unproved
  (`findings/e5/E5-RESIDUAL.md`): B1 undefined `GetScriptOp` over general
  buffers, B2 heap/allocator, B3 the symbolic dispatch loop, B4 exception
  edges, B5 `__cxa_guard` statics, B6 `ptrtoint`/STL, B7 crypto/assert
  externals. This cell is a handwritten bounded transcription on both legs,
  not a refinement proof of the pinned IR.
- Only 0..2-byte scripts with at most one instruction; the 201-op count
  limit, MAX_SCRIPT_SIZE, MINIMALDATA, altstack/condition-stack interaction
  and OP_COUNT are outside the leaf.
- Elements below `prev` are unobservable only because no in-domain instruction
  reads or pops them; a longer subscript would need them.
- The HASH160 match gating the P2SH arm is not touched (crypto seam), and the
  P2SH-wrapped witness tail / `WITNESS_MALLEATED_P2SH` byte comparison is
  SCR-012's cell, not this one.

Next smallest experiment (if the row is to advance further): extend the same
two-leg shape to a two-byte, two-instruction subscript (e.g. `51 9c` /
`OP_1 OP_EQUALVERIFY`) with the same computed-outcome discipline. That adds
the multi-op dispatch boundary without needing the real EvalScript body, and
it is where the op-count and stack-read rules first matter.
