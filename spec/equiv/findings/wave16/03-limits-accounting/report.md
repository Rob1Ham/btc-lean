# Wave 16 / 03 — limits & accounting

Status: **11 of the 16 assigned SCR rows are closed as full both-tool cells;
1 row is a partial cell; 2 rows are partial with no cell; 1 row is a no-go
(constant with no engine check); 1 row is a no-go for the enforcement claim
(constant relation only).**

Everything below is on branch `wave16/03-limits-accounting` at repository
`HEAD` `805c804` (no commit had been made when the cells were built; the
cell commit is the one that contains this report).

- Contract: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- Pinned Core: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
  (checkout used for every `core_ref` line below)
- Cell root: `spec/equiv/cells/limits/`
- Shared harness: `spec/equiv/cells/limits/_shared/` (only `limits_common.h`,
  `build_leaf.sh`, `run_alive2.sh`, `run_saw.sh`; no shared file outside the
  `limits` cell tree was edited)

## 1. Assigned rows

`SCR-026, 027, 028, 032, 033, 034, 035, 036, 037, 038, 039, 040, 041, 042,
043, 044` (16 rows).

## 2. Delivered cells

All cells use scalar-only `extern "C"` leaves: the `limits` ABI packs the
observed value into a `uint64_t`, so no pointer argument reaches Alive2
(Alive2 rejects `nocapture` on an external declaration). Each cell has
`spec.md`, `notes.md`, `src/`, `build/`, `alive2/result.txt`,
`alive2/certificate.sha256`, `saw/result.txt`, `saw/certificate.sha256`.

| Cell | Functions | Alive2 | SAW proofs | Rows |
|---|---|---|---|---|
| `C-L-cms-count-bounds` | `cell_cms_count_bounds` | green | 2 | 026, 027, 028 (full) |
| `C-L-sigop-site-weights` | `cell_sigop_site_weight` | green | 2 | 032, 033 (full) |
| `C-L-witness-sigop-dispatch` | `cell_witness_sigops` | green | 2 | 035 (full) |
| `C-L-sigop-cost-arith` | `cell_tx_sigop_cost`, `cell_block_sigop_gate`, `cell_tx_sigop_policy` | green | 6 | 037, 038, 039 (full) |
| `C-L-tapscript-weight` | `cell_tapscript_budget`, `cell_tapscript_checksig` | green | 4 | 040 (partial), 041, 042 (full) |

Each Alive2 certificate covers `spec.md`, both leaves, the shared driver,
`build/build.txt` and the result file; each SAW certificate additionally
covers `src/cell.cry`, `src/cell.saw`, the copied `build/` inputs, the
result file, and the Lean definitions listed in `src/cert-inputs.txt`
(`Interpreter/SigOps.lean`, `Block/Sigops.lean`, `Interpreter/Rules.lean`,
`Interpreter/Defs.lean`, `TxValidation/SigOpsCost.lean`,
`Crypto/Taproot/Program.lean`, `Data/Basic.lean` as applicable).

## 3. Row dispositions

### 3.1 Full rows (11)

| Row | Claim exercised | Cell |
|---|---|---|
| SCR-026 | `nKeysCount < 0 \|\| nKeysCount > 20 ⇒ PUBKEY_COUNT`, decoded `int` domain | `C-L-cms-count-bounds` |
| SCR-027 | `ikey < 0 \|\| ikey + nKeysCount > nKeysCountMax ⇒ PUBKEY_COUNT` | `C-L-cms-count-bounds` |
| SCR-028 | `nSigsCount < 0 \|\| nSigsCount > nKeysCount ⇒ SIG_COUNT` | `C-L-cms-count-bounds` |
| SCR-032 | per-site CHECKSIG/CHECKSIGVERIFY = 1, CHECKMULTISIG(VERIFY) = 20 | `C-L-sigop-site-weights` |
| SCR-033 | accurate CHECKMULTISIG = preceding `OP_1..OP_16`, else 20, all 256×256 opcode pairs | `C-L-sigop-site-weights` |
| SCR-035 | v0-20 ⇒ 1; v0-32 ⇒ last witness item count (or 0 on an empty witness); v1+ ⇒ 0 | `C-L-witness-sigop-dispatch` |
| SCR-037 | `cost = 4*(legacy + p2sh) + witness` | `C-L-sigop-cost-arith` |
| SCR-038 | cumulative block cost gate at 80,000 | `C-L-sigop-cost-arith` |
| SCR-039 | per-tx policy gate at 16,000 | `C-L-sigop-cost-arith` |
| SCR-041 | non-empty sig decrements 50 WU regardless of validity; `< 0 ⇒ TAPSCRIPT_VALIDATION_WEIGHT`, with precedence over the pubkey rules | `C-L-tapscript-weight` |
| SCR-042 | non-empty sig + upgradable key still decrements | `C-L-tapscript-weight` |

`SCR-034`/`SCR-036` are **not** in this table; see §4.

### 3.2 Partial (1 row, with cell)

- **SCR-040** — `C-L-tapscript-weight:cell_tapscript_budget`. The formula
  (`CompactSize(n) + Σ(CompactSize(len_i) + len_i) + 50`), the 1/3/5-byte
  CompactSize branches and the 32-bit item lengths are proved for 0–4
  witness items. Missing: an unbounded item count and the 9-byte
  CompactSize branch (unreachable for a serialized witness item). Must not
  be cited as a full SCR-040 green.

## 4. Rows with no green: 034, 036, 043, 044

### SCR-034 — P2SH sigop count (partial, no cell)

Row: `script.cpp:GetSigOpCount(scriptSig):183-205` and
`tx_verify.cpp:132-146`: a malformed or non-push-only scriptSig returns 0;
otherwise count the final push data's valid prefix accurately.

What a cell would need: a byte-array scriptSig argument (Core takes
`const CScript&`). Alive2 rejects external functions with pointer
arguments carrying `nocapture` (`ERROR: Unsupported attribute: nocapture`,
reproduced on this toolchain), so the script must be packed into scalars —
which is possible for a bounded length only, because the 8-step unroll has
to be fixed. A **bounded** scalar cell is therefore the only honest shape;
the question is whether it adds coverage beyond `C-L-witness-sigop-dispatch`
(which already proves the `witnessSigOps` dispatch that SCR-034's tail
calls) and `C-L-sigop-site-weights` (which proves the accurate count itself).

Attempted and **not delivered**: `C-L-p2sh-scriptsig-parser` (8-byte
scriptSig packed into a `uint64_t`, both entry points, Alive2 + 4 SAW
proofs). The C↔L pair was written and Alive2 was reduced to a single
harness-level shift-UB difference (fixed by making the packed-byte helper
total), but the SAW proof of the C leg against the independent Cryptol
`p2sh_sigops` did not finish (abc: >25 min, killed; z3/bitwuzla as tried —
see `notes` in the commit message / this report's log). The residual
difficulty is the symbolic 8-step parser plus the second accurate-count
walk over 64-bit packed data. No result file is claimed for it, and the
directory is not part of the commit.

Honest disposition: **partial**. Nothing about malformed/non-push-only
scriptSig handling is added by this batch beyond the Lean-side definitions
already present; the accurate-count tail and the witness dispatch are
covered by the cells in §3.1. A full SCR-034 green needs a scalable
script-parser encoding (byte-array shim with a bounded, but larger, script
model), which is out of this task's no-patch / scalar-leaf constraints.

### SCR-036 — P2SH-wrapped witness sigops (partial, no cell)

Row: `interpreter.cpp:CountWitnessSigOps:2162-2173`: push-only scriptSig
whose last push is a witness program ⇒ `WitnessSigOps(v, program, witness)`.

Same encoding obstacle as SCR-034 (the scriptSig is a byte array). The
reachable-by-construction part — `IsWitnessProgram` classification and the
v0-20/v0-32/v1+ dispatch — is proved in
`C-L-witness-sigop-dispatch:cell_witness_sigops` for decoded
`(version, program length, witness)` inputs, and the push-only/last-push
extraction is exactly the missing piece that needs the parser cell.
Honest disposition: **partial**, with the dispatch half green elsewhere.

### SCR-043 — `MAX_PUBKEYS_PER_MULTI_A = 999` (no-go)

`script.h:37-38` is a header constant. At the pin it is referenced only by
the miniscript/descriptor/solver layer, never by script execution:

- `script/miniscript.h:1879` (multi_a key bound while building a node)
- `script/miniscript.h:2404`, `:2418` (`multi_a` parse key count)
- `script/miniscript.cpp:79` (`CHECK_NONFATAL` on `n_keys`)
- `script/solver.cpp:124` (reject > 999 keys when recognising the template)
- `script/descriptor.cpp:2469-2470` (descriptor `multi_a` key count)

A `limits` both-tool cell would be a constant restatement, not an
equivalence of a check the interpreter performs; the row's own text calls
it a "miniscript-side resource limit". Honest disposition: **no-go for a
script-interpreter cell**. A future cell in the miniscript subsystem
(parse/reject at `miniscript.h:2404`) is the meaningful target and is out
of this task's scope.

### SCR-044 — `MIN_TRANSACTION_WEIGHT = 240` (no-go for the enforcement claim)

`consensus/consensus.h:23` is `WITNESS_SCALE_FACTOR * 60` (= 240); the
comment states 60 is "the lower bound for the size of a valid serialized
CTransaction". Core does not enforce a 240 minimum on a transaction: the
only use is as a divisor in a merkleblock transaction-count bound
(`merkleblock.cpp:159`). Proving "every valid serialized tx weighs at
least 240" needs a CTransaction serializer model and a validity argument;
neither exists in this cell family, and a cell that proves `4 * 60 = 240`
would be a constant identity, not the row's claim. Honest disposition:
**no-go**; the constant relation is `240 = 4 * 60` by definition.

## 5. Validation

Run from the repository root:

```sh
for c in C-L-cms-count-bounds C-L-sigop-site-weights \
         C-L-witness-sigop-dispatch C-L-sigop-cost-arith \
         C-L-tapscript-weight; do
  d=spec/equiv/cells/limits/$c
  bash "$d/alive2/run.sh" && bash "$d/saw/run.sh"
  sha256sum -c "$d/alive2/certificate.sha256"
  sha256sum -c "$d/saw/certificate.sha256"
done
```

Observed:

- Alive2: `Transformation seems to be correct` and
  `1 correct transformations` for every function, no `ERROR:`;
  `STATUS=alive2-green` in each `alive2/result.txt`.
- SAW: 2/2/2/6/4 `Proof succeeded!` for the five cells, no `Proof failed`;
  `STATUS=saw-green` in each `saw/result.txt`.
- `sha256sum -c`: 12/12 and 17/17 (cms), 12/12 and 18/18 (site weights),
  12/12 and 17/17 (dispatch), 12/12 and 18/18 (cost arith), 12/12 and
  19/19 (tapscript weight) — all `OK`.

Tools: `alive-tv` (LLVM 20.1.2), `saw` 1.6 (68eed5f), `clang++-20`.

## 6. Trust notes and limits

- **C legs** are line-cited source-excerpt slices of the pinned Core files;
  they are not compiled Core and do not include Core headers.
- **L legs** are reviewed transliterations of the Lean model, not extracted
  definitions; the exact Lean ranges are cited in each `spec.md` and hashed
  into the SAW certificate via `src/cert-inputs.txt`.
- `precondition:` in each `spec.md` names the bounds (decoded `int` inputs,
  32-bit lengths, 0–4 witness items, the same-crypto checker seam). The
  bounded domain is part of the claim: no unbounded/whole-entry result is
  claimed.
- No hash, signature or full-script-execution claim is made. The Schnorr
  checker result is an input (`decision = 2` marks a checker rejection
  whose ordinal is outside the cell).
- `patches: none` for every cell; no Core patch, no pin change, no contract
  or consensus-semantics change.
- Proposed (not executed) mutants are recorded in each `spec.md`; none is
  reported as killed.

## 7. Not done / next step

- A scalable script-parser encoding (byte-array leaf or a larger fixed
  bound with a split prover budget) is the single blocker for a real
  SCR-034/SCR-036 green; the current cells stop at the dispatch and
  accurate-count primitives.
- A miniscript-subsystem cell for SCR-043 (`miniscript.h:2404` reject path)
  and a serializer lower-bound model for SCR-044 are the honest targets for
  those two rows, both outside this task's scope.
