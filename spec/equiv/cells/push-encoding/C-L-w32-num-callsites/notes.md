# push-encoding/C-L-w32-num-callsites

SCR-051, second cell: the four handler call sites, after the shared decode
law (push-encoding/C-L-w32-num-decode-minimal).

## What is proved

For every input in the cell's ABI (five operand bytes and a three-bit length
per decoded operand, the MINIMALDATA bit, stack depth, opcode budget, the
transaction context, and the activation flags):

| entry point | call site | what is compared |
|---|---|---|
| `cell_cltv` | interpreter.cpp:556, cap 5 | flag-off NOP, stack-underflow, decode, `n < 0`, CheckLockTime (type match, `n <= txLockTime`, final-sequence rejection) |
| `cell_csv` | interpreter.cpp:584, cap 5 | flag-off NOP, stack-underflow, decode, `n < 0`, disable-flag NOP, CheckSequence (version, disable flag, type mask, masked compare) |
| `cell_cms` | interpreter.cpp:1126 and :1140, cap 4 | stack-underflow, key-count decode, PUBKEY_COUNT, OP_COUNT, `nKeys + 2` arity, sig-count decode, SIG_COUNT, `nKeys + nSigs + 3` arity |
| `cell_checksigadd` | interpreter.cpp:1103, cap 4 | base/witnessV0 BAD_OPCODE, `stack.size() < 3`, decode |

Operand lengths 0..7 are symbolic, so 3, 4 and 5 — the widths at and below the
two caps — are included, and 6/7 exercise width rejection.  The observable is
`result(2) | error_kind(6) << 2` only (the stack is untouched before every
point where a handler stops).

Both legs are checked twice:

- Alive2: `alive-tv --bidirectional` on each of the four functions
  (`Transformation seems to be correct!`, `1 correct transformations`).
- SAW: each leg against the Cryptol model in `src/cell.cry`
  (8 `Proof succeeded!`, no `Proof failed`).

## Non-vacuity (red-team probe, not a cell input)

The length-5 branch is load-bearing: taking a scratch copy of `c_leaf.cpp`,
changing only the CLTV call site's cap from 5 to 4 and re-running Alive2 against
the cell's L bitcode yields

```
Summary:
  0 correct transformations
  1 incorrect transformations
Source value: #x0000000000000010 (16)
Target value: #x0000000000000001 (1)
```

i.e. the mutant rejects a 5-byte operand with SCRIPTNUM where the L leg
returns OK.  The probe log is in
`spec/equiv/findings/wave64/10-scr-051/mutation-cap5-to-4.log`; the mutant is
not committed.

## Exact blocker filed (still open)

The remaining gap is **not** Alive2/SAW, and **not** the leaf ABI: the cell ABI
is per-cell, and adding transaction context as extra parameters was enough to
build all four sites.  The blocker is the generated twin's opcode table:

1. `twin/ops_ir.py:42-50` (`OP_CLTV`) and `:52-61` (`OP_CSV`) emit
   ```c
   if (!ctx.flags.cltv) return TWIN_OK;
   return TWIN_INVALID_UNSUPPORTED;
   ```
   (and the `csv` analogue).  With the flag on there is no decode step, no
   NEGATIVE_LOCKTIME and no locktime/sequence comparison in the twin, so a
   handler-level C-vs-generated-twin cell would compare a verdict against
   "unsupported" (a different contract result).
2. `twin/gen.py:222-225` lists `CHECKMULTISIG` and `CHECKMULTISIGVERIFY` under
   `unsupported`; no handler is generated at all.
3. `DEFS.lean` does model all four sites (`Defs.lean:857-875`, `:1069-1090`,
   `:803-811`), and PDW98 already proves the non-minimal rejection at each of
   them.  So the Lean side exists; only the twin generator lags.

Because the twin is shared model code, this worktree does not patch
`twin/ops_ir.py` or `twin/gen.py` (no shared edits).  The L leg is therefore a
reviewed transcription of the Defs.lean arms, with the decode call delegated to
the generated `twin::decode_num` (runtime.inc:167-188).  The cell states this
caveat in `spec.md`; it does not claim equivalence of the generated twin's
handler table.

To close the caveat, the twin track needs: (a) CLTV/CSV bodies with the decode
step and the checker calls (`decodeNum … 5`, negative-locktime, then
`checkLockTimeDef`/`checkSequenceDef`); (b) a CHECKMULTISIG handler whose count
decode precedes signature verification.  After that, re-run this cell with the
L leg calling the generated handlers (`mk_leaf.py --ops OP_CLTV,OP_CSV,…`) and
drop the transcription note.  The locktime environment must also enter the twin
`Ctx`/checker surface, which is the same seam work as the E3 checker.
`OP_CHECKSIGADD`'s tapscript arm remains the E4 seam (Schnorr checker).

## Reproduce

From the worktree root:

```sh
spec/equiv/cells/push-encoding/C-L-w32-num-callsites/alive2/run.sh
spec/equiv/cells/push-encoding/C-L-w32-num-callsites/saw/run.sh
cd <worktree-root> && sha256sum -c spec/equiv/cells/push-encoding/C-L-w32-num-callsites/alive2/certificate.sha256
cd <worktree-root> && sha256sum -c spec/equiv/cells/push-encoding/C-L-w32-num-callsites/saw/certificate.sha256
```

Each run overwrites `alive2/result.txt` / `saw/result.txt`, `build/` and the
certificate.  `build/` is gitignored, as for every other cell, so a fresh
checkout must run the script once before the `build/*` certificate lines can be
checked; the tracked-input lines (`src/*`, `spec.md`, `notes.md`, harness,
twin/ops_ir.py, contract) verify immediately.

## What is not claimed

- Whole-`EvalScript`/`VerifyScript` equivalence; the surrounding loop, `fExec`
  gate, op budget and error precedence outside these handlers.
- CHECKMULTISIG signature verification, NULLDUMMY/NULLFAIL, FindAndDelete.
- OP_CHECKSIGADD's Schnorr verification or the pushed value.
- The R leg; consensus status of MINIMALDATA (the row is policy).
