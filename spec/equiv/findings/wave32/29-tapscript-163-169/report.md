# Wave 32 — task 29, tapscript SCR-163..169

**Worktree:** `/tmp/opencode/wave32/29-tapscript-163-169`
**Branch:** `wave32/29-tapscript-163-169` (base `805c804`, additive to PR #29)
**Family:** tapscript
**Assigned rows:** SCR-163, SCR-164, SCR-165, SCR-166, SCR-167, SCR-168, SCR-169
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Lean model rev:** `4d62a97e551082a69b13f495365bff0a903b0c99`

## Result

Six new cells under `spec/equiv/cells/tapscript/`, all **both-tools green**:

| Cell | Rows | Functions | `alive2/result.txt` | `saw/result.txt` |
|---|---|---|---|---|
| `C-L-w32-tap-hashtype` | SCR-163, SCR-165 | `cell_ht_valid`, `cell_sig_to_ht`, `cell_output_type` | `STATUS=alive2-green`, 3 correct / 0 incorrect | `STATUS=saw-green`, 6 proofs |
| `C-L-w32-tap-vw-zero` | SCR-168 | `cell_eval_checksig` | `STATUS=alive2-green`, 1 correct / 0 incorrect | `STATUS=saw-green`, 2 proofs |
| `C-L-w32-tap-extslice` | SCR-164 | `cell_ext_w0..w4` | `STATUS=alive2-green`, 5 correct / 0 incorrect | `STATUS=saw-green`, 10 proofs |
| `C-L-w32-tap-single-output` | SCR-166 | `cell_single_output` | `STATUS=alive2-green`, 1 correct / 0 incorrect | `STATUS=saw-green`, 2 proofs |
| `C-L-w32-tap-epoch-annex` | SCR-169 | `cell_epoch_ht`, `cell_spend_type`, `cell_annex_slice` | `STATUS=alive2-green`, 3 correct / 0 incorrect | `STATUS=saw-green`, 6 proofs |
| `C-L-w32-tap-codesep-pos` | SCR-167 | `cell_codesep_walk` | `STATUS=alive2-green`, 1 correct / 0 incorrect | `STATUS=saw-green`, 2 proofs |

**Rows: 5 full (SCR-163, 164, 165, 166, 168), 2 partial (SCR-167, 169),
0 blocked at the cell level.** "Full" is full for the row text over the
declared input domain of the cell, not full `EvalScript`/`VerifyScript`
equivalence. The precise limits and the two next experiments are below.

## Row table

| SCR | status | cell | proved | remains | blocker |
|---|---|---|---|---|---|
| SCR-163 | **full** | `tapscript/C-L-w32-tap-hashtype` | `cell_ht_valid` over all 2^8 hashtypes: valid iff `ht <= 3 || 0x81 <= ht <= 0x83`; invalid maps to ordinal 46 (`SCHNORR_SIG_HASHTYPE`) at the cited lines. C↔L by Alive2; both legs vs the independent Cryptol predicate by SAW. | Nothing in the row text. The error mapping is modelled at `interpreter.cpp:1747-1748`; the signature body/BIP340 verdict is not part of this row. | None. L is a reviewed transliteration; the twin has no Schnorr handler at the model rev. |
| SCR-164 | **full** | `tapscript/C-L-w32-tap-extslice` | For both SigVersions and all 32-byte tapleaf hashes / 32-bit codesep positions: TAPSCRIPT appends `tapleaf_hash` (32 B) ‖ `key_version = 0x00` ‖ `codeseparator_pos` (4 LE B), total 37 B; TAPROOT appends nothing. Byte-for-byte, all five observed words, C↔L and each leg vs the Cryptol `slice`. | The tapleaf hash *value* (SCR-146) and the full SigMsg offset/layout (SCR-169/last-field construction). | None for the three named appends. The serializer convention (uint256 = 32 raw bytes, uint32 = 4 LE bytes) is a cited `HashWriter` premise. |
| SCR-165 | **full** | `tapscript/C-L-w32-tap-hashtype` | `cell_sig_to_ht` over all 2^32 sizes × 2^8 trailing bytes: size 64 ⇒ implicit `SIGHASH_DEFAULT` 0x00; size 65 ⇒ explicit trailing byte, explicit 0x00 rejected with 46; other sizes ⇒ 45 (`SCHNORR_SIG_SIZE`). `cell_output_type` over all 2^8 hashtypes: 0x00 ⇒ `SIGHASH_ALL` (=1), else `ht & 3`. | The 65-byte explicit-0x00 rejection is SCR-162's rule; it is exercised but not claimed as SCR-162. | None. |
| SCR-166 | **full** | `tapscript/C-L-w32-tap-single-output` | `cell_single_output` over all 8-bit hashtypes and all 32-bit `in_pos`/`vout_size`: SINGLE (`ht & 3 == 3`) and `in_pos >= vout_size` ⇒ construction fails with 46; equality edge included; `in_pos < vout_size` succeeds and commits a single-output hash; non-SINGLE succeeds regardless of count. | The single-output hash *value* (SCR-169 lane); `vout.size() < 2^32` is a physical premise. | None for the existence gate. |
| SCR-167 | **partial** | `tapscript/C-L-w32-tap-codesep-pos` | Over every pre-decoded 4-opcode stream with symbolic `pend`, kind (push/op), wire byte, push payload length and `fExec`: start at `0xFFFFFFFF`; increment exactly one per parsed opcode regardless of push length; unexecuted opcodes still consume a slot; an executed `OP_CODESEPARATOR` records the 0-based index; last executed wins. | The byte-level `GetScriptOp` parse, the `vfExec` derivation, loop lengths > 4 opcodes, and the rest of the switch. The Core loop is not executed. | Parse seam F-DIV-001 / SCR-045; the opcode stream is an input premise. Next: bounded `GetScriptOp` advance leaf over ≤ 8 concrete script bytes. |
| SCR-168 | **full** | `tapscript/C-L-w32-tap-vw-zero` | `cell_eval_checksig` over all reachable budgets `[0, 4000050]` (initialised at `interpreter.cpp:1991`): non-empty sig decrements by 50, fail only when the result is `< 0`; exactly 0 continues (including `vw = 50`); empty sig does not decrement; pubkey-size and Schnorr-false branches exercise the surrounding ordering. | The witness-stack initialisation itself and the BIP340 verdict (free boolean). The `0xdeadbeef` out-of-domain guard is harness. | None for the `< 0` vs `<= 0` edge. Same-crypto premise for the Schnorr verdict. |
| SCR-169 | **partial** | `tapscript/C-L-w32-tap-epoch-annex` | Epoch byte: message bytes 0..1 are `0x00` then the hashtype, for all 2^8 hashtypes. `spend_type = 2*ext_flag + annex_present` for ext_flag 0 (TAPROOT) / 1 (TAPSCRIPT), both annex states. Annex slice: empty without an annex, exactly 32 bytes with one, supplied uint256 word unchanged. | `m_annex_hash = SHA256(CompactSize(len) ‖ annex)`, the tagged `TapSighash`, the four tx-level sub-hashes, the full SigMsg byte order and the digest value. | No SHA256 is linked into either leaf, and the cell does not prove Core's `HashWriter` equals the executable Lean `Sha256.sha256`. Next: same-hash link on concrete vectors, then extend the slice with the digest. |

## Cell evidence

| Cell | Alive2 pairs | Alive2 notes | SAW |
|---|---|---|---|
| hashtype | `ht_valid`, `sig_to_ht`, `output_type`, `--bidirectional` | `ht_valid` is reported `syntactically equal`; the other two are real transformations. | 2 proofs per function (C leg + L leg vs `cell.cry`). |
| vw-zero | `eval_checksig`, `--bidirectional` | Real transformation; all seven return arms differ. | 2 proofs. |
| extslice | `ext_w0..w4`, `--bidirectional` | Real transformations; C is word-granular, L is byte-granular, so the green is not syntactic equality. | 10 proofs. |
| single-output | `single_output`, `--bidirectional` | Real transformation (gate + error packing). | 2 proofs. |
| epoch-annex | `epoch_ht`, `spend_type`, `annex_slice`, `--bidirectional` | `epoch_ht` and `spend_type` are `syntactically equal`; `annex_slice` is a real transformation. This is stated, not hidden. | 6 proofs. |
| codesep-pos | `codesep_walk`, `--bidirectional` | Real transformation (counter + assignment + packing). | 2 proofs. |

Every `alive2/result.txt` ends with `1 correct transformations`,
`0 incorrect transformations`, `0 failed-to-prove transformations`,
`0 Alive2 errors`, `STATUS=alive2-green`. Every `saw/result.txt` ends with
`STATUS=saw-green` and contains no `Proof failed`.

## Exact commands and raw outcomes

Run from the repository root
(`/tmp/opencode/wave32/29-tapscript-163-169`):

```sh
spec/equiv/cells/tapscript/C-L-w32-tap-hashtype/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w32-tap-hashtype/saw/run.sh
spec/equiv/cells/tapscript/C-L-w32-tap-vw-zero/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w32-tap-vw-zero/saw/run.sh
spec/equiv/cells/tapscript/C-L-w32-tap-extslice/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w32-tap-extslice/saw/run.sh
spec/equiv/cells/tapscript/C-L-w32-tap-single-output/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w32-tap-single-output/saw/run.sh
spec/equiv/cells/tapscript/C-L-w32-tap-epoch-annex/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w32-tap-epoch-annex/saw/run.sh
spec/equiv/cells/tapscript/C-L-w32-tap-codesep-pos/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w32-tap-codesep-pos/saw/run.sh
```

All twelve exited `0` on the final run. Each `alive2/run.sh` builds both
legs with:

```sh
/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-exceptions \
  -fno-rtti -I src -S -emit-llvm -fno-discard-value-names src/c_leaf.cpp -o build/c_leaf.ll
# and src/l_leaf.cpp -> build/l_leaf.ll
/usr/lib/llvm-20/bin/llvm-extract --func=<fn> --recursive build/<leg>_leaf.ll -o build/<leg>_<fn>.bc
/usr/lib/llvm-20/bin/llvm-dis build/<leg>_<fn>.bc -o build/<leg>_<fn>.ll
/usr/local/bin/alive-tv --bidirectional build/c_<fn>.ll build/l_<fn>.ll
```

Tool versions, recorded in every `alive2/result.txt` header:

```text
# alive-tv: Ubuntu LLVM version 20.1.2
# clang: Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)
```

Each `saw/run.sh` copies `src/cell.cry` and `src/cell.saw` into `build/`
and runs SAW 1.6 from there (`# saw: 1.6 (68eed5f release-1.6)`), checking
each leg separately against the same Cryptol oracle. Representative tails:

```text
Transformation seems to be correct!

These functions seem to be equivalent!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

```text
Proof succeeded! cell_single_output
...
CELL_W32_SINGLE_OUTPUT_SAW_GREEN
STATUS=saw-green
```

(The per-cell green markers are `CELL_W32_HASHTYPE_SAW_GREEN`,
`CELL_W32_VW_ZERO_SAW_GREEN`, `CELL_W32_EXTSLICE_SAW_GREEN`,
`CELL_W32_SINGLE_OUTPUT_SAW_GREEN`, `CELL_W32_EPOCH_ANNEX_SAW_GREEN`,
`CELL_W32_CODESEP_POS_SAW_GREEN`.)

### No-go runs

There were **no failed Alive2 or SAW runs** and therefore no tool error to
quote for the two partial rows. Their limitation is model scope, stated
exactly in the row table and in each `spec.md`/`notes.md`:

- **SCR-167:** no command can prove `GetScriptOp` from the current cell
  because the opcode stream is a function input. The small next experiment
  is a new bounded leaf over a concrete/symbolic byte string of length ≤ 8
  that implements `script.cpp`'s advance rule, then run
  `alive2/run.sh` and `saw/run.sh` on that leaf. That still would not claim
  the whole `EvalScript` loop.
- **SCR-169:** no command can prove the digest because neither leaf links a
  SHA256 implementation. The small next experiment is a crypto-lane cell
  that (a) links Core `HashWriter` as an opaque symbol, (b) evaluates the
  executable Lean `Sha256.sha256` (`Crypto/Seam/Hash.lean:133`, re-exported
  at `Crypto/Seam/Interface.lean:62`) on the same vectors, and (c) proves
  `sha_annex = HashWriter{}(CSize(len) || annex)` there. This cell already
  proves the surrounding epoch/spend_type/append structure.

## Certificate verification

From the repository root, after the final runs:

```sh
sha256sum -c spec/equiv/cells/tapscript/C-L-w32-tap-<cell>/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-w32-tap-<cell>/saw/certificate.sha256
```

Results (`rc`, OK lines, FAILED lines):

```text
hashtype/alive2      rc=0 ok=11 failed=0
hashtype/saw         rc=0 ok=15 failed=0
vw-zero/alive2       rc=0 ok=11 failed=0
vw-zero/saw          rc=0 ok=15 failed=0
extslice/alive2      rc=0 ok=11 failed=0
extslice/saw         rc=0 ok=15 failed=0
single-output/alive2 rc=0 ok=11 failed=0
single-output/saw    rc=0 ok=15 failed=0
epoch-annex/alive2   rc=0 ok=11 failed=0
epoch-annex/saw      rc=0 ok=15 failed=0
codesep-pos/alive2   rc=0 ok=11 failed=0
codesep-pos/saw      rc=0 ok=15 failed=0
OVERALL_FAIL=0
```

The certificates hash `spec.md`, `notes.md`, the runners, both leaves, the
shared `error_kind.h`, `build/build.txt`, the relevant build copies and
`result.txt`. `build/` is gitignored, so a fresh checkout must run
`alive2/run.sh` once to recreate those artifacts before re-checking.

## What is actually claimed

- **C↔L:** mutual refinement (`--bidirectional`) for every function's full
  symbolic input space, with both modules total in the observed ABI.
- **C and L vs an independent oracle:** SAW checks each leg separately
  against `src/cell.cry`, which is written from the cited Core lines and
  Lean equations. A shared C/L mistake would still be caught.
- **Not claimed:** whole `EvalScript`/`VerifyScript` equivalence, the
  witness/stack/tx machinery, the R leg, or any SHA256/libsecp/BIP340
  internals. SCR-169's digest and SCR-167's parse are explicitly open.
- **L-link strength:** the twin's generated op table has no BIP341 sighash
  or Schnorr handler at this model rev, so the L legs of hashtype, vw-zero,
  extslice, single-output and epoch-annex are reviewed transliterations,
  not drift-gated generated code. `mk_leaf.py` *is* used for the
  SCR-167 `OP_CODESEPARATOR` handler. This is a link-strength caveat, not
  an Alive2/SAW failure.

## Blockers and smallest next experiments

1. **SCR-167 parse seam (row partial).** `GetScriptOp`'s byte advance and
   the `vfExec` stack are premises; the stream is pre-decoded and bounded
   at four opcodes. Next: a bounded `GetScriptOp` advance leaf over ≤ 8
   concrete script bytes, then the same counter run. Owner: the
   F-DIV-001 / SCR-045 seam.
2. **SCR-169 hash lane (row partial).** The structural epoch/spend_type/
   annex-slice facts are proved, but the digest, tagged hash, tx sub-hashes
   and full preimage are not. Next: the concrete-vector same-hash link
   described above. Owner: the crypto/IR lane, not this leaf cell.
3. **L generator gap (link strength).** Add sighash/Schnorr handlers to
   `twin/ops_ir.py` and regenerate; that edits shared twin files and should
   be owned by the twin track.
4. **R leg absent.** The pinned rbitcoin lane is non-proof
   (F-HARNESS-002 / F-TOOL-001); all six cells are C-L only.

## Harness corrections made during close-out

- `src/run_cell.sh` now actually runs Alive2 with `--bidirectional` and
  requires the `These functions seem to be equivalent!` line, matching the
  `direction: L ⊑ C / C ⊑ L` declared in every `spec.md`. The earlier
  one-way invocation was logically sufficient for these total functions,
  but did not match the written claim; all cells were rebuilt and re-run.
- The SCR-169 documentation previously said the Lean seam exposes `sha256`
  opaquely. That is false at this rev: `Crypto/Seam/Hash.lean:133` has an
  executable `sha256`. The spec and notes now state the real blocker — the
  missing Core-`HashWriter` ↔ Lean-`sha256` link — without claiming any
  SHA256 internals.

## Files added

```text
spec/equiv/cells/tapscript/C-L-w32-tap-hashtype/{spec.md,notes.md,src/...,alive2/...,saw/...}
spec/equiv/cells/tapscript/C-L-w32-tap-vw-zero/{spec.md,notes.md,src/...,alive2/...,saw/...}
spec/equiv/cells/tapscript/C-L-w32-tap-extslice/{spec.md,notes.md,src/...,alive2/...,saw/...}
spec/equiv/cells/tapscript/C-L-w32-tap-single-output/{spec.md,notes.md,src/...,alive2/...,saw/...}
spec/equiv/cells/tapscript/C-L-w32-tap-epoch-annex/{spec.md,notes.md,src/...,alive2/...,saw/...}
spec/equiv/cells/tapscript/C-L-w32-tap-codesep-pos/{spec.md,notes.md,src/...,alive2/...,saw/...}
spec/equiv/findings/wave32/29-tapscript-163-169/report.md
```

No pin, contract, ledger, result, `docs/STATE.md`, Lean proof, existing cell
or other worktree was edited. `make equiv` and the shared ledger updater
were not run. Nothing was pushed.
