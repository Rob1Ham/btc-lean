# Wave 16 / 14-witness-v0 — SegWit v0 witness-program cell advance

Date: 2026-10-20. Task: `wave16/14-witness-v0`.

Contract `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`.
Repo head `805c8042f92d3bed909ca40219a4d21fc9150cc1`.
Core pin `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.

Scope: rows SCR-133..141 (the SegWit v0 arm of `VerifyWitnessProgram`, the
P2WPKH implied script, the witness cleanstack post-state, the BIP143 sigversion
branch, and the BIP143 `hashOutputs`/layout rules).  Seven new cells under
`spec/equiv/cells/witness-v0/`.  Both tools were really run for every cell.
No Core patch, no ledger edit, no `make equiv`, nothing pushed.

## 1. Row dispositions

| row | what the row is | cell | disposition |
|---|---|---|---|
| SCR-133 | `SHA256(witnessScript) == program` | `C-L-p2wsh-hashmatch` | **partial** — 32-byte compare proved; SHA256 abstract |
| SCR-134 | empty witness ⇒ ordinal 39 | `C-L-witness-v0-dispatch` | **full** |
| SCR-135 | P2WPKH arity ≠ 2 ⇒ ordinal 40 | `C-L-witness-v0-dispatch` | **full** |
| SCR-136 | `DUP HASH160 <20> EQUALVERIFY CHECKSIG` | `C-L-p2wpkh-script` | **partial** — script bytes proved; execution not modelled |
| SCR-137 | other v0 lengths ⇒ ordinal 38 | `C-L-witness-v0-dispatch` | **full** |
| SCR-138 | exactly 1 true element after EvalScript | `C-L-witness-v0-cleanstack` | **full** for the post-state rule |
| SCR-139 | sigversion ≠ BASE skips FindAndDelete | `C-L-sigversion-findanddelete` | **full** |
| SCR-140 | BIP143 field order; amount included | `C-L-bip143-layout` | **partial** — layout proved; contents/hash not modelled |
| SCR-141 | SINGLE overflow ⇒ zero `hashOutputs`, never `uint256::ONE` | `C-L-bip143-hashoutputs-single-oor` | **full** |

Totals: **6 full, 3 partial, 0 gap/seam** in this slice.  All nine rows now have
a real both-tool cell; no row is left with only a narrative seam.

### Why 134/135/137 are full now

The E4 cell proved the error predicates but abstracted both success arms to
`(1,0)`, so its P2WSH arm could not distinguish a SHA256 match from a mismatch.
The new dispatch cell adds `hash_match` as an explicit input and returns a
continuation sentinel `2` for both `ExecuteWitnessScript` call sites.  The rows
themselves are the error predicates; the cell proves them as total implications
over every `(program_len, witness_n, hash_match)` triple, with Core/Lean
precedence (empty before hash, arity before execution, length last).

### What the three partial rows still need

- **SCR-133**: SHA256 over the witnessScript.  The cell proves
  `memcmp(digest, program, 32)` and both outcomes for all inputs; the digest is
  a symbolic input under the same-hash premise (`spec/equiv/README.md` §7).
  Promoting the row needs a SHA256 model (or a verified same-hash shim) bound to
  the executed bytes.
- **SCR-136**: `ExecuteWitnessScript` on the implied script.  The cell proves
  the 25 bytes `76 a9 14 <program> 88 ac` exactly; HASH160 and CHECKSIG are not
  modelled, so neither the `EQUALVERIFY` nor the signature check is claimed.
- **SCR-140**: the preimage contents.  Field order, widths, offsets and the
  8-byte `amount` slot are proved for `script_len <= 75`; the three sub-hashes,
  the tx serializer and SHA256d are not modelled.  Multi-byte CompactSize is
  outside the claim.

## 2. Cells and tool status

All cells live under `spec/equiv/cells/witness-v0/`.

| cell | functions | Alive2 | SAW | rows |
|---|---|---|---:|---:|---|
| `C-L-witness-v0-dispatch` | `cell_v0_dispatch` | green | green | 134, 135, 137 (full) |
| `C-L-p2wpkh-script` | `cell_p2wpkh_script_w0..w3` | green (4) | green (8 proofs) | 136 (partial) |
| `C-L-witness-v0-cleanstack` | `cell_v0_cleanstack` | green | green (2) | 138 (full) |
| `C-L-sigversion-findanddelete` | `cell_checksig_verdict`, `cell_checksig_scriptcode` | green (2) | green (4) | 139 (full) |
| `C-L-bip143-hashoutputs-single-oor` | `cell_bip143_hashoutputs_mode` | green | green (2) | 141 (full) |
| `C-L-p2wsh-hashmatch` | `cell_p2wsh_hashmatch` | green | green (2) | 133 (partial) |
| `C-L-bip143-layout` | `cell_bip143_field`, `cell_bip143_total_len` | green (2) | green (4) | 140 (partial) |

Each cell has `spec.md` (full YAML front matter), `notes.md`, `src/` (C leg, L
leg, Cryptol spec, SAW script, function list), committed `ir/*.ll`, and
`alive2/` + `saw/` with `run.sh`, raw `result.txt`, and `certificate.sha256`.

## 3. Evidence

Tool versions:

- Alive2 v20.0, `/opt/equiv-tools/alive-tv-v20.0` (linked LLVM 20.1.2;
  `alive-tv --version` reports `Ubuntu LLVM version 20.1.2`).
- SAW 1.6, `/opt/equiv-tools/saw-1.6/bin/saw` (68eed5f);
  solver `abc` for six cells, `z3` for `C-L-bip143-layout`.
- clang/LLVM 20.1.2 (`/usr/bin/clang++-20`, `/usr/lib/llvm-20/bin/llvm-extract`).

Commands (per cell, from the repository root):

```sh
bash spec/equiv/cells/witness-v0/<cell>/alive2/run.sh
bash spec/equiv/cells/witness-v0/<cell>/saw/run.sh
sha256sum -c spec/equiv/cells/witness-v0/<cell>/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/witness-v0/<cell>/saw/certificate.sha256
```

All fourteen certificates verify from the repo root.  Raw tails:

- every `alive2/result.txt` ends `STATUS=alive2-green` with
  `1 correct transformations`, `0 incorrect`, `0 failed-to-prove`,
  `0 Alive2 errors` per compared function;
- every `saw/result.txt` ends `STATUS=saw-green` with at least one
  `Proof succeeded!` per module and no `Proof failed` / `saw: error`.

The evidence hash binds `spec.md`, both runners, the shared `wv_common.h` and
`build.sh`, both C/L sources, `fns.txt`, the Cryptol/SAW inputs, the committed
`ir/*.ll`, and `result.txt`.  `build/` is gitignored and not certificate input.

## 4. Design decisions

- **Scalar word encodings instead of pointers.**  Alive2 v20 rejects clang's
  `nocapture`/`noalias` attributes on the pointer parameters
  (`Unsupported attribute: nocapture`, `Unsupported attribute: noalias`) and
  reports `Out of memory; skipping function.` for a 20- or 32-byte symbolic
  memory input.  The cells therefore expose byte buffers as little-endian u64
  words.  Each encoding is a bijection between the byte string and the word
  tuple (with explicitly documented unused high bits), so no byte is dropped.
- **Continuation sentinel.**  Both `ExecuteWitnessScript` call sites return `2`,
  never `1`.  No cell claims that a witness spend succeeds; the cleanstack cell
  separately proves the post-state rule.
- **Different spellings per leg.**  C and L differ at source level (cursor vs
  explicit sums; XOR/OR vs conjunction; nested conditionals vs switch/select;
  prefix-first vs suffix-first stores).  Where clang normalized both legs to the
  same IR, Alive2 reports `(syntactically equal)`; elsewhere it reports a
  semantic proof.  Either is a full Alive2 pass; no cell relies on a textual
  self-comparison.
- **Hash/crypto abstractions are labelled.**  SHA256, HASH160, ECDSA and the
  sub-hashes are inputs or modes, under the same-hash/same-crypto premise.
  `spec/equiv/docs/DECISION-lax-ecdsa.md` is referenced by the brief but is
  absent from this tree; the cells cite `spec/equiv/README.md` §7, which is the
  in-tree statement of that premise.

## 5. Tool/infrastructure blockers

- Alive2 cannot ingest the whole `VerifyWitnessProgram`/`ExecuteWitnessScript`
  (indirect calls, `std::span`, `CScript`/vector memory, loops).  Every cell is
  therefore a loop-free predicate/constructor slice, cited line by line.
- The attribute and symbolic-memory limits above are the reason for the word
  encodings; they are recorded in each cell's `notes.md`.
- SAW with `abc` did not converge on the layout descriptor arithmetic; `z3`
  proves it.  The runner reads the optional `src/solver.txt` and records the
  solver in `result.txt`.
- No blocker prevented a both-tool result for any of the seven cells.

## 6. Files

New tree: `spec/equiv/cells/witness-v0/` (seven cells plus `_tools/`:
`wv_common.h`, `build.sh`, `run_alive2.sh`, `run_saw.sh`).  This report:
`spec/equiv/findings/wave16/14-witness-v0/report.md`.

No changes to `spec/db/**`, `spec/equiv/results/**`, `docs/**`, `contract/**`,
`twin/**`, `shims/**`, the Lean sources, the pins, or the Core checkout.
`patches: none` for every cell.
