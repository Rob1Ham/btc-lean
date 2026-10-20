# Wave 64 / task 29 — SCR-133 witness-v0, abstract-hash cell

**Task:** close the SCR-133 gap ("comparison half is full; reconstruction/hashing
half is not") with a cell that proves the exact comparison and the byte-domain
relation under an explicit same-hash/SHA256 abstraction, or file a precise
crypto-seam report.
**Worktree:** `/tmp/opencode/wave64/29-scr-133`
**Branch:** `wave64/29-scr-133` (base `5946c02`)
**Pin (Core):** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Tools:** alive-tv v20.0 (LLVM 20.1.2), SAW 1.6 (68eed5f, z3 + abc),
clang 20.1.2, llvm-20.
**Edits:** additive only — one new cell directory and this report. No shared
ledger/results/contract/PINS edits, no edits to existing cells or tooling, no
`make equiv`, no push.

## Row disposition

| SCR | status | cell | proved | remaining |
|---|---|---|---|---|
| **SCR-133**<br>`SHA256(witnessScript) == program` | **covered modulo same-hash** (both-tool green) | `e4-witness/C-L-w32-witness-133-abstract-sha256` | (1) Exact 32-byte comparison on the **real lowered Core call** in both pinned lanes: `bcmp` at `-O1`, `memcmp` at `-O0`, against the row postcondition for all 2^256 digest/program pairs, with only the C11 7.24.4.1 comparison contract as an override (SAW). (2) The C ISO-C-memcmp predicate over four uint256 words equals the Lean `ByteArray` inequality over 32 bytes, both directions, all 2^256 pairs (Alive2). (3) Byte-domain bijection `le64`/`unle64` proved both ways, and both legs verified against the same `le64`-based postcondition (SAW). (4) The full row with SHA256 replaced by one **uninterpreted oracle shared by both legs** is equal in both directions for all witnessScript bytes, all lengths, all programs and exec pairs; same-symbol call arguments are compared, so both legs hash the same `(script, length)` (Alive2). (5) The `exec_script = CScript(begin, end)` copy identity (Alive2 + SAW). | Exactly **same-hash**: Core `CSHA256` and Lean `hashSha256` must return the same 32 bytes, in the same order, for every witnessScript. No SHA256 internals are modelled or claimed; the cell quantifies over all digest functions. This is the project's declared same-crypto premise (`README.md` §7, `docs/DECISION-lax-ecdsa.md` §2–3), the same premise under which SCR-094 is green. |

**What changed relative to `e4-witness/C-L-w32-witness-hash-compare`:** that
cell proved the comparison over four symbolic u64 words and described the C
side as "the memcmp predicate"; it did not touch the lowered libc call, the
byte-domain map, the reconstruction copy, or the hashing plumbing. All four
are now proved, so the residual shrinks from "half the row" to one named
premise.

## Cell design

`cells/e4-witness/C-L-w32-witness-133-abstract-sha256/`

| file | role |
|---|---|
| `src/c_compare.cpp` | Core excerpt shape `memcmp(h, p, 32)` (`cell_core_o1`, O1→`bcmp`) plus the ISO-C-memcmp predicate over uint256 words (`cell_words`) |
| `src/c_compare_o0.cpp` | the same shape at the pinned `-O0` lane (`memcmp` call, `cell_core_o0`) |
| `src/l_compare.cpp` | reviewed transliteration of `Defs.lean:1265-1270` / ByteArray BEq: `cell_lean_bytes` and `cell_words` |
| `src/c_row.cpp`, `src/l_row.cpp` | the row with `sha256_word(script, len, idx)`, one external oracle identical in both legs |
| `src/c_recon.cpp`, `src/l_recon.cpp` | `exec_script` copy identity (`cell_recon_w0/w3`) |
| `src/build.sh` | builds bitcode/text IR; records every artifact hash in `build/build.txt` |
| `alive2/run.sh`, `alive2/run_mutation.sh` | 4 bidirectional Alive2 proofs; 3 refuted mutants |
| `saw/spec.cry`, `saw/spec.saw`, `saw/run.sh` | 9 `llvm_verify` proofs + 2 `prove_print` round-trips |

### Why the digest is an oracle, and why that is not a SHA256 claim

`sha256_word` is declared in both legs and defined in neither.  Alive2 treats
a call to an undefined symbol relationally: same symbol + same arguments ⇒
same value, different arguments ⇒ independent value.  Therefore:

- the proof quantifies over **every** possible 32-byte digest function, so no
  property of SHA256 is used (there is no compression function, schedule,
  padding, or FIPS-180-4 model anywhere in the cell);
- the four calls in each leg must pass the same `(script pointer, length)`,
  otherwise the oracle returns are independent and the proof fails.  Mutant
  M1 (hash one extra byte) is refuted, so the plumbing check is load-bearing.

The SAW comparison proofs are independent of the oracle: digest and program
are fully symbolic byte arrays, and the only override is `bcmp`/`memcmp`'s
standard contract (`0 iff the n bytes are equal`; the sign of a nonzero result
is never observed).

## Evidence

| artifact | content |
|---|---|
| `cells/.../alive2/result.txt` | tool versions, command, IR hashes, 4 × "These functions seem to be equivalent", `STATUS=alive2-green` |
| `cells/.../alive2/certificate.sha256` | sha256 of every tracked input + the result |
| `cells/.../alive2/mutation_result.txt` | M1/M2/M3 each `1 incorrect transformations` → `MUTANT KILLED`; `STATUS=mutation-check-passed` |
| `cells/.../saw/result.txt` | 9 × `Proof succeeded!`, both `LE64_ROUNDTRIP_*_PROVED`, `CELL_W133_SAW_GREEN`, `STATUS=saw-green (llvm_verify proofs: 9)` |
| `cells/.../saw/certificate.sha256` | sha256 of every tracked input + the result |

Reproduce:

```sh
cd spec/equiv/cells/e4-witness/C-L-w32-witness-133-abstract-sha256
bash src/build.sh && bash alive2/run.sh && bash alive2/run_mutation.sh && bash saw/run.sh
```

## Findings worth carrying forward

1. **The pinned Core comparison is a libc call, not a word compare.** With
   `uint256` (`std::array<uint8_t,32>`, align 1) and
   `program` (`vector<unsigned char>`, align 1), clang 20.1.2 lowers
   `memcmp(h, p, 32)` to `bcmp` at `-O1` and keeps `memcmp` at `-O0`.
   Earlier cell text calling the C side "the 4-word memcmp" is a semantic
   model, not the lowered IR.  This cell proves the actual calls (SAW
   override) *and* the predicate model (Alive2), and says which is which.
2. **`nocapture` is rejected by alive-tv v20.0.** Any pointer-parameter cell
   in this family needs the attribute stripped from the `.ll` comparison
   input.  Stripping only drops an assumption (more general programs), and
   both the bitcode hash and the stripped `.ll` hash are recorded.
3. **Same-hash is the entire remaining obligation.** A single-block SHA256
   compression cell (Core `sha256::Transform` vs Lean
   `sha256Compress`/`sha256Schedule`) would cover only inputs ≤ 55 bytes and
   still not close SCR-133 for arbitrary witnessScript.  Filing this as the
   seam is more honest than a partial hash model.

## Handoff / blockers (ledger owner action)

- **Ledger not edited** (shared file, out of scope). Suggested
  `spec/db/equiv-cells.yaml` update for SCR-133: add this cell; `alive2:
  green`, `saw: green`; replace the "comparison half only" gap note with
  "covered modulo same-hash; see
  e4-witness/C-L-w32-witness-133-abstract-sha256 and README §7".  The
  auto-classifier (`_partial_coverage`) will treat the cell as non-partial
  because `scr_row_coverage` does not start with "partial"; if the ledger
  policy wants SCR-133 to stay a seam row because its *subject* is the hash,
  mark it accordingly — the evidence supports either reading, and the
  premise is named in both `spec.md` and `notes.md`.
- **L provenance unchanged:** the L leg is a reviewed transliteration (the
  twin has no `VerifyWitnessProgram` handler and emits an opaque
  `sha256(p,l,out)` external).  Dual review of the transliteration is still
  the L trust step; this cell does not change it.
- **No Core patch, no PINS change, no contract change.**
