# Wave 32 / task 24 — witness-v0 SCR-133…137

**Task:** add real C–L cells for SCR-133…137 (family `witness-v0`) to PR #29.
**Worktree:** `/tmp/opencode/wave32/24-witness-133-137`
**Branch:** `wave32/24-witness-133-137` (base `805c804`)
**Pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Tools:** alive-tv v20.0 (LLVM 20.1.2), SAW 1.6 (68eed5f), clang 20.1.2.
**No push; no shared ledger/results/contract/PINS edits; no `make equiv`.**

## Row table

| SCR | status | cell | what was proved | what remains | exact blocker |
|---|---|---|---|---|---|
| **SCR-134**<br>`empty ⇒ WITNESS_PROGRAM_WITNESS_EMPTY` | **full** (dispatch seam) | `e4-witness/C-L-w32-witness-v0-error-total` | Both directions, total over all inputs: `plen=32 ∧ wn=0 ⇒ (0,39)`, and no other input returns 39. Alive2 green, SAW green. | The non-empty P2WSH success path is not asserted; it is the symbolic `ExecuteWitnessScript` pair (row SCR-136/138 territory). | none for this row at this seam |
| **SCR-135**<br>`else WITNESS_PROGRAM_MISMATCH` (P2WPKH arity) | **full** (dispatch seam) | `e4-witness/C-L-w32-witness-v0-error-total` | Both directions: `plen=20 ∧ wn≠2 ⇒ (0,40)`, and `wn=2` proceeds to `ExecuteWitnessScript`; no other input returns 40 on this arm. | The 2-item execution outcome is not asserted (symbolic pair). | none for this row at this seam |
| **SCR-137**<br>`else WRONG_LENGTH` | **full** (dispatch seam) | `e4-witness/C-L-w32-witness-v0-error-total` | Both directions: `plen ∉ {20,32} ⇒ (0,38)`, and no other input returns 38; total over all 64-bit `plen`. | nothing in the row. | none |
| **SCR-133**<br>`SHA256(witnessScript) == program` | **partial** — comparison proved, hash not | `e4-witness/C-L-w32-witness-hash-compare` (+ branch in `…-error-total`) | Both directions over all 2^256 `(digest, program)` pairs: mismatch in any of the 32 bytes ⇒ `(0,40)`, exact 32-byte match ⇒ pass through `ExecuteWitnessScript`; the C 4-word `memcmp` and the L 32-byte `ByteArray` inequality are the same predicate. Alive2 green, SAW green. | `CSHA256().Write(exec_script).Finalize(...)` at `interpreter.cpp:1940-1941`: the hash itself. No SHA256 model at the leaf seam, and no proved link between Core's `CSHA256` and the Lean `hashSha256`. | **SHA256 floor** — feature: hash primitive model. The twin emits an opaque external `sha256(p,l,out)` (`twin/ops_ir.py:853-887`); Lean `hashSha256` (`Hashes.lean:99-131`) is a list-based model with no equivalence proof against Core's `src/crypto/sha256.cpp`. The same-hash premise is unchanged (`docs/DECISION-lax-ecdsa.md` §2–3) and must stay explicit. Smallest next experiment: standalone single-block SHA256 floor cell (Core `sha256::Transform` specialized to one 64-byte block, whose 64 rounds are already unrolled, vs a reviewed `sha256Compress`/`sha256Schedule` transliteration, plus a FIPS 180-4 Cryptol spec); it would still only cover length ≤ 55 and would not close the row for arbitrary witnessScript. |
| **SCR-136**<br>`DUP HASH160 <20> EQUALVERIFY CHECKSIG` | **partial** — reconstruction proved, execution not | `e4-witness/C-L-w32-p2wpkh-build` | Both directions over all 2^160 programs: the 25 script bytes are exactly `76 a9 14 <program> 88 ac` with the correct PUSHDATA prefix, matching the Lean byte list `[0x76,0xa9,0x14] ++ program ++ [0x88,0xac]`. Alive2 green (4 word pairs), SAW green (8 proofs). | `ExecuteWitnessScript` on the implied script: EvalScript loop, HASH160/RIPEMD160, ECDSA/Schnorr CHECKSIG, cleanstack, EVAL_FALSE. | **script-execution loop + crypto** — no EvalScript/`ExecuteWitnessScript` handler at the seam and no HASH160/CHECKSIG model; the whole-engine probe is `findings/e4/F-TOOL-001.md` and is not a green path. Next experiment: compose this byte-exact script with an EvalScript-loop cell only after the loop seam exists; until then this row cannot be green. |

Rows **closed:** 134, 135, 137 (row-level, at the v0 dispatch seam; the
orchestrator owns the ledger write). Rows **partial:** 133, 136.

Why these three are row-level full and not merely re-labelled: each of
SCR-134/135/137 names exactly one error edge (empty witness, 20-byte arity
mismatch, other v0 lengths).  The new cell is total over all inputs and proves
both the edge and its converse, so every branch/edge named by those rows is
exercised.  The prior `C-L-witness-v0-dispatch` cell fixed the two callees to
success; this cell does not assert any success arm at all — it returns the
symbolic `ExecuteWitnessScript` pair — and it adds the converses.  The success
arms belong to SCR-136/SCR-138 and remain open.  If the orchestrator's ledger
policy requires a fully discharged `ExecuteWitnessScript` for any
witness-v0 row to be green, these three stay gap; the evidence and the exact
residual are stated here either way.

Existing `e4-witness/C-L-witness-v0-dispatch` is untouched. The new cells are
additive and do not relabel its partial status.

## Design of the three cells

All three use `cells/_tools/e4w32/` (new, unique):

- `c_cells.cpp` — line-cited Core excerpts (`interpreter.cpp:1933-1956`,
  `script.h:408-431,470-488`);
- `l_cells.cpp` — reviewed manual transliterations of the Lean v0 arm
  (`Defs.lean:1259-1280`) and the implied-script byte list (`:1272-1274`);
  the twin has no `VerifyWitnessProgram` handler, so there is no
  `mk_leaf.py` instance for this family;
- shared build + Alive2/SAW runners with SHA-256 certificates.

The key difference from the existing dispatch cell: SHA256 and
`ExecuteWitnessScript` are **symbolic inputs**, not fixed to success.  No
success arm is asserted anywhere except the reconstructed script bytes.

### Cell 1 — `C-L-w32-witness-v0-error-total`

`cell_v0_error_total(plen, wn, hash_ok, exec_res, exec_err)`:
total v0 dispatch over `plen`, `wn`, a symbolic hash-match bit and a symbolic
`ExecuteWitnessScript` `(result, error)` pair, with the ABI invariant
`result 1 ⇒ error 0` applied.  Proves the exact `(result, error)` table and
the converses.  Alive2 `--bidirectional` and SAW (both modules against the
same Cryptol function).

### Cell 2 — `C-L-w32-p2wpkh-build`

`cell_p2wpkh_w0..w3`: 20-byte program (3 LE words) → the exact 25-byte
implied script (4 LE words).  Core expansion from `CScript::operator<<`
(opcode bytes + `AppendDataSize(20)=0x14` + 20 data bytes) vs the Lean byte
list.  Cryptol spec rebuilds the script from the same Lean list, independently
of both legs.

### Cell 3 — `C-L-w32-witness-hash-compare`

`cell_hash_compare(h0..h3, p0..p3, exec_res, exec_err)`: the 32-byte
`memcmp` and mismatch branch.  Core uses 4-word equality; L compares all 32
bytes individually (the Lean `ByteArray` inequality); Cryptol compares the
same words.  This is the strongest honest partial for SCR-133 without a hash
model: it proves the comparison covers all 256 bits and that any differing
byte yields error 40.

## Exact commands and raw outcomes

```sh
cd /tmp/opencode/wave32/24-witness-133-137
spec/equiv/cells/e4-witness/C-L-w32-witness-v0-error-total/alive2/run.sh
spec/equiv/cells/e4-witness/C-L-w32-witness-v0-error-total/saw/run.sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-build/alive2/run.sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-build/saw/run.sh
spec/equiv/cells/e4-witness/C-L-w32-witness-hash-compare/alive2/run.sh
spec/equiv/cells/e4-witness/C-L-w32-witness-hash-compare/saw/run.sh
```

Each runner rebuilds the leaf pair with
`/usr/bin/clang++-20 -std=c++17 -O1 -emit-llvm`, extracts each function with
`llvm-extract`, and writes raw output plus `STATUS=` only after parsing the
tool output.  Actual command lines inside the evidence:

```text
alive-tv --bidirectional --smt-to=120000 build/c_<fn>.ll build/l_<fn>.ll
saw spec.saw            # in build/, saw 1.6; both modules vs saw/spec.cry
```

All six runs exit 0:

```text
C-L-w32-witness-v0-error-total/alive2/result.txt: STATUS=alive2-green
C-L-w32-witness-v0-error-total/saw/result.txt:    STATUS=saw-green
C-L-w32-p2wpkh-build/alive2/result.txt:           STATUS=alive2-green
C-L-w32-p2wpkh-build/saw/result.txt:              STATUS=saw-green
C-L-w32-witness-hash-compare/alive2/result.txt:   STATUS=alive2-green
C-L-w32-witness-hash-compare/saw/result.txt:      STATUS=saw-green
```

Alive2 tail (all four p2wpkh word pairs, and the other two cells):

```text
Transformation seems to be correct!
These functions seem to be equivalent!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
```

SAW tails: 2/2 proofs (`cell_v0_error_total`, `cell_hash_compare`) and 8/8
proofs (`cell_p2wpkh_w0..w3` × C,L), e.g.

```text
Verifying cell_hash_compare...
Simulating cell_hash_compare...
Checking proof obligations cell_hash_compare...
Proof succeeded! cell_hash_compare
```

Certificates, verified from the repository root after the runs
(`sha256sum -c`, 0 failures in all six files):

```sh
for c in C-L-w32-witness-v0-error-total C-L-w32-p2wpkh-build \
         C-L-w32-witness-hash-compare; do
  for t in alive2 saw; do
    sha256sum -c spec/equiv/cells/e4-witness/$c/$t/certificate.sha256
  done
done
```

The certificates bind `spec.md`, the runner, the tool sources
(`cells/_tools/e4w32/*`), `build/build.txt`, the extracted `.ll`/`.bc`, the
Cryptol/SAW spec and `result.txt`.  `build/` is git-ignored by repository
policy; as with every existing cell, rerun the runner before checking the
certificate in a fresh checkout.

## Negative controls (not committed)

To show the proofs are not vacuous, three mutated copies of the L leg were
built in `/tmp/opencode/w32-probe` and checked with the same Alive2 command.
All three fail:

| mutant | counterexample | source vs target |
|---|---|---|
| 20-byte guard `wn != 2` → `wn < 2` | `plen=20, wn=8, hash_ok=0, exec_res=0, exec_err=0` | C `160` (0,40) vs L `0` |
| hash compare drops the `h3`/`p3` word | `h=(0,0,0,0), p=(0,0,0,1)` | C `160` (0,40) vs L `0` |
| PUSHDATA prefix `0x14` → `0x13` | `p0=0, p1=3, p2=3` | C `0x14a976` vs L `0x13a976` |

Raw: `Transformation doesn't verify!`, `ERROR: Value mismatch`, `1 incorrect
transformations`.  These mutations are records, not cells.

## Honest limits / same-hash and crypto premises

- No SHA256, HASH160, RIPEMD160, ECDSA, Schnorr or libsecp256k1 internals are
  claimed.  The cells keep the hash-match bit and the `ExecuteWitnessScript`
  pair symbolic.
- The SCR-133 hash claim and the SCR-136 script execution are **not** proved.
  They are same-crypto/same-hash conditional, exactly as in
  `docs/DECISION-lax-ecdsa.md` and `findings/e4/seams.md`; nothing here
  weakens or strengthens that premise.
- The L legs are reviewed transliterations, not generated from the twin: the
  twin has no `VerifyWitnessProgram` handler.  This is recorded in every
  `spec.md`/`notes.md`.
- Alive2 and SAW prove the cell functions, not the whole
  `VerifyWitnessProgram`, not `ExecuteWitnessScript`, and not the engine.
- Counterexample/negative-control runs are tool checks on scratch copies, not
  new cells.

## Files added

```text
spec/equiv/cells/_tools/e4w32/w32_common.h
spec/equiv/cells/_tools/e4w32/c_cells.cpp
spec/equiv/cells/_tools/e4w32/l_cells.cpp
spec/equiv/cells/_tools/e4w32/build_leaf.sh
spec/equiv/cells/_tools/e4w32/run_alive2.sh
spec/equiv/cells/_tools/e4w32/run_saw.sh
spec/equiv/cells/e4-witness/C-L-w32-witness-v0-error-total/{spec.md,notes.md,alive2/*,saw/*}
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-build/{spec.md,notes.md,alive2/*,saw/*}
spec/equiv/cells/e4-witness/C-L-w32-witness-hash-compare/{spec.md,notes.md,alive2/*,saw/*}
spec/equiv/findings/wave32/24-witness-133-137/report.md
```

No existing cell, finding, ledger, result, contract or pin was modified.
