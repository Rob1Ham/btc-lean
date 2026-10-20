# Mutation catalogue (planned, E1–E4)

**Status:** design + raw runs; **mutation evidence not admitted**. **Version:** 0.2-adjudicated. **Owner:** REDTEAM.
**Machine-readable twin of this file:** `cells/_redteam/mutate.py` (`--list`).
**Execution status:** eight runs were recorded on 2026-10-19. **Six reports
are withdrawn as evidence** because their pasted tail is green while their
header says `KILLED`; two runs (`M-E3-008`, `M-E4-004`) show genuine non-green
mutant output but their JSON records remain pending. No required mutation set
is complete and no mutation PASS is claimed. Raw records are in
`cells/_redteam/runs/`; adjudication is in
`cells/_redteam/AUDIT-ADJUDICATION.md`. The E1/E2/E4 anchors are calibrated
against the current sources; every other anchor remains uncalibrated pending a
patched Core copy and the later cells. No source was left mutated.

This file is the human-readable catalogue. `mutate.py` is the only permitted
way to apply a mutation: it records target hashes, a diff, and a mutant record
under `cells/_redteam/mutants/`.

---

## 0. Conventions

| Tag | Meaning |
|---|---|
| **T** | twin site: twin generator input (`twin/ops_ir.py`, preferred) or generated `twin/build/twin.cpp` |
| **C** | Core-copy site: patched, test-only copy of Core at `cce32b168`, never a `patches/` entry |
| **R** | optional rust-copy canary (not required) |
| **A2** | Alive2 (`alive-tv`) |
| **SAW** | SAW/Crucible `llvm_verify` |
| **DIFF** | three-leg differential / fuzz oracle |
| **ENUM** | error-enum equality harness |
| **CORPUS** | corpus/canary harness |

`Catcher` is a **prediction** of which mechanism should fail first. Both tools
are still attempted on every cell; a mutation is `KILLED` if at least one named
expected cell fails. "DIFF only" is acceptable evidence for a kill **only** if
the cell family records that the proof tool cannot express the cell and the gap
is filed with a named feature. A differential kill never promotes a cell to
green.

**Target sites are per mutation, not per row.** A row marked `T+C` means the
same semantic mutation is run at both sites, as a pair, unless the mutation is
inexpressible at one site; inexpressibility is recorded, not skipped silently.

**No line numbers.** Anchors are exact text with an expected occurrence count,
calibrated against the actual source. A missing/ambiguous anchor is a hard
failure (`MUTATION_NOT_CALIBRATED` / `ANCHOR_COUNT_MISMATCH`), never a silent
partial edit.

**Revert before the next mutant.** The tree must return to the baseline hash and
the baseline cell must be green again. A mutant left applied blocks the
milestone.

---

## 1. E1 — stack ops and push surface

E1 covers the stack family plus the push-size boundary because pushes are the
stack's input surface. The first semantic gate is here.

| ID | Mutation | Site | Expected failing cell | Catcher | Kill witness / observable |
|---|---|---|---|---|---|
| **M-E1-001** | `OP_SWAP` becomes a no-op (top two not exchanged) | T+C | `cells/e1-stack/swap-order` | A2, SAW | `51 52 7c 51 87` (`OP_1 OP_2 OP_SWAP OP_1 OP_EQUAL`): baseline pass, mutant fail |
| **M-E1-002** | `OP_DUP` duplicates the second-from-top item, not top | T+C | `cells/e1-stack/dup-order` | A2, SAW | `51 52 76 52 87` (`OP_1 OP_2 OP_DUP OP_2 OP_EQUAL`): baseline pass, mutant fail |
| **M-E1-003** | `OP_ROT` rotates in the opposite direction | T+C | `cells/e1-stack/rot-direction` | A2, SAW | `51 52 53 7b 51 87` (`OP_1 OP_2 OP_3 OP_ROT OP_1 OP_EQUAL`): baseline pass, mutant fail |
| **M-E1-004** | `OP_TOALTSTACK`/`OP_FROMALTSTACK` implementations swapped (or TOALT acts on main stack) | T+C | `cells/e1-altstack/roundtrip` | A2, SAW | `51 52 6b 6c 52 87`: baseline pass; mutant hits `EQUIV_ERR_INVALID_ALTSTACK_OPERATION` or wrong item |
| **M-E1-005** | push element limit `MAX_SCRIPT_ELEMENT_SIZE` 520 → 521 (or 520 rejected) | T+C | `cells/e1-push/size-boundary` | A2, SAW, DIFF | 520-byte direct push + `OP_DROP OP_1`: baseline pass; 521-byte push: baseline `EQUIV_ERR_PUSH_SIZE`; mutant flips one side |
| **M-E1-006** | `OP_DEPTH` returns `depth - 1` | T+C | `cells/e1-stack/depth-count` | A2, SAW | `51 51 74 52 87` (`OP_1 OP_1 OP_DEPTH OP_2 OP_EQUAL`): baseline pass, mutant fail |
| **M-E1-007** | `OP_PICK`/`OP_ROLL` index is off by one (selects neighbor) | T+C | `cells/e1-stack/pick-depth` | A2, SAW | `51 52 53 52 79 52 87` (`OP_1 OP_2 OP_3 OP_2 OP_PICK OP_2 OP_EQUAL`): baseline pass, mutant fail |

Notes:

- **First batch is swap + dup only.** `cells/README.md` records that
  `cells/e1-stack/swap-order` and `cells/e1-stack/dup-order` are the currently
  buildable gate cells; the twin skeleton supports push/NOP/VERIFY/DROP/DUP/
  SWAP. The other E1 rows above are planned and MUST NOT be counted until
  their gate cell is green. If only two E1 gate cells exist, the required third
  mutant blocks E1 sign-off rather than being replaced by a weaker test.
- `M-E1-001` is the recommended first mutation (see
  `findings/redteam/redteam-report.md`). It is flag-free, crypto-free,
  verdict-observable, expressible by both tools, and trivially revertible.
- `M-E1-004`: "swapped" is intentionally one mutation, not two. If the twin's
  altstack representation makes a pure swap impossible, mutate the
  `TOALTSTACK` transfer direction and record the exact semantic change.
- `M-E1-005` uses the direct-push limit; do not mutate the script-size limit
  (`MAX_SCRIPT_SIZE`, 10,000) in the same mutant.

---

## 2. E2 — flow, numeric, hash

| ID | Mutation | Site | Expected failing cell | Catcher | Kill witness / observable |
|---|---|---|---|---|---|
| **M-E2-001** | `CastToBool` treats negative zero (`0x80`) as true | T+C | `cells/e2-flow/negzero-if` | A2, SAW, DIFF | `01 80 63 51 67 00 68` (`PUSH 0x80; IF; 1; ELSE; 0; ENDIF`): baseline `EQUIV_ERR_EVAL_FALSE`, mutant pass |
| **M-E2-002** | `CScriptNum` operand bound 4 → 5 bytes (or 5-byte accepted in base arithmetic) | T+C | `cells/e2-numeric/num-4byte-boundary` | A2, SAW | `05 00 00 00 00 01 8b 75 51` (5-byte `2^32`, `1ADD`, `DROP`, `1`): baseline `EQUIV_ERR_SCRIPTNUM`, mutant pass |
| **M-E2-003** | `CScriptNum` result is truncated/wrapped to 4 bytes instead of emitting the 5-byte sum | T+C | `cells/e2-numeric/result-5byte` | A2, SAW, DIFF | `04 ff ff ff 7f 04 ff ff ff 7f 93 05 fe ff ff ff 00 87` (`2^31-1 + 2^31-1`, compare to 5-byte `0xfffffffe`): baseline pass, mutant fail |
| **M-E2-004** | `OP_WITHIN` max boundary is inclusive (`<=`) instead of exclusive (`<`) | T+C | `cells/e2-numeric/within-boundary` | A2, SAW | `55 51 55 a5` (`5 1 5 WITHIN`): baseline fail (5 `<` 5 is false), mutant pass |
| **M-E2-005** | `OP_COUNT` threshold 201 → 200 (off-by-one at the budget) | T+C | `cells/e2-flow/opcount-201` | A2, SAW | 201 counted ops + `OP_1`: baseline pass; 202: baseline `EQUIV_ERR_OP_COUNT`; mutant rejects 201 |
| **M-E2-006** | `OP_ENDIF` without a matching `OP_IF` is accepted (unbalanced conditional not raised) | T+C | `cells/e2-flow/unbalanced-endif` | SAW, ENUM, DIFF | `68` (`OP_ENDIF` alone): baseline `EQUIV_ERR_UNBALANCED_CONDITIONAL`; mutant proceeds to `EQUIV_ERR_EVAL_FALSE`/pass — kill requires **error-kind** postcondition |
| **M-E2-007** | `HASH160` composition swapped (`SHA256(RIPEMD160(x))` vs `RIPEMD160(SHA256(x))`) or hash opcode dispatch swapped | T+C | `cells/e2-hash/hash160-vector` | SAW, DIFF | push 32-byte preimage, `HASH160`, push expected 20-byte digest, `EQUAL`: baseline pass; mutant digest mismatch/length error |
| **M-E2-008** | `CheckLockTime` comparison is off by one at equality (rejects `nLockTime == tx.nLockTime`) or skips the height-vs-time type check | T+C | `cells/e2-flow/cltv-equal` | A2, SAW | `<locktime> CLTV DROP 1` with `tx.nLockTime == locktime`: baseline pass; mutant `EQUIV_ERR_UNSATISFIED_LOCKTIME` |
| **M-E2-009** | stack-size limit 1000 → 1001 (or check after the push instead of before/after per Core) | T+C | `cells/e2-flow/stacksize-1000` | A2, SAW | 1000 pushes + `OP_1`: baseline pass; 1001: baseline `EQUIV_ERR_STACK_SIZE`; mutant flips the boundary |

Notes:

- `M-E2-001` is the canonical negative-zero case; do not also mutate `OP_NOT`
  in the same mutant. The cell must exercise `CastToBool`, not merely push
  `0x80`.
- `M-E2-006` is deliberately an error-kind mutant: final verdict may remain
  "fail" under both builds. A verdict-only cell cannot kill it and is a cell
  finding.
- `M-E2-007`: Alive2 with uninterpreted hash externals may not distinguish the
  two compositions. If so, record the named external-function limitation and
  rely on SAW overrides or DIFF; do not silently mark the cell green.
- `M-E2-008`: locktime type matching (height vs time) is part of the cell;
  mutation is only the equality/edge comparison, not the whole type rule.
- **Do not use `OP_DIV`/`OP_MOD`/`OP_MUL` as mutants at this pin.** They are
  disabled opcodes and cannot reach the arithmetic (`contract/error_enum.md`;
  `findings/cross/F-UB-001-int64-bounds.md`). Arithmetic operands are capped at
  4 bytes, so an int64 overflow mutant is also unreachable. `M-E2-003`/`004`
  therefore target the **result encoding** and `OP_WITHIN` boundary instead.

---

## 3. E3 — CHECKSIG, CHECKMULTISIG, encoding, error kind

The crypto checker is abstracted as a shared premise. These mutants target
engine logic around the checker, not libsecp internals.

| ID | Mutation | Site | Expected failing cell | Catcher | Kill witness / observable |
|---|---|---|---|---|---|
| **M-E3-001** | CMS loop advances/selects the wrong index on failure (signature/key iteration order swapped) | T+C | `cells/e3-cms/sig-key-order` | SAW, DIFF | 2-of-3 CMS with signatures that match only `(sig1,key2)`, `(sig2,key3)`; symbolic checker true only for matching pairs: baseline pass, mutant fail |
| **M-E3-002** | `NULLDUMMY` check dropped (empty-dummy rule not enforced) | T+C | `cells/e3-cms/nulldummy` | SAW, ENUM | 1-of-1 CMS with dummy `OP_1` and a valid signature + `NULLDUMMY` flag: baseline `EQUIV_ERR_SIG_NULLDUMMY`, mutant pass |
| **M-E3-003** | `NULLFAIL` cleanup check dropped (non-empty failing signature not rejected) | T+C | `cells/e3-cms/nullfail` | SAW, ENUM | CMS with an invalid but non-empty signature + `NULLFAIL`: baseline `EQUIV_ERR_SIG_NULLFAIL`, mutant `EQUIV_ERR_EVAL_FALSE` |
| **M-E3-004** | `HIGH_S`/low-S gate skipped | T+C | `cells/e3-checksig/high-s` | SAW, DIFF | CHECKSIG with a high-S DER signature + `LOW_S`: baseline `EQUIV_ERR_SIG_HIGH_S`, mutant pass (checker override accepts) |
| **M-E3-005** | CMS count bounds relaxed (`nSigs > nKeys` or `nKeys > 20` accepted) | T+C | `cells/e3-cms/count-bounds` | A2, SAW | CMS with `nKeys=21`, `nSigs=1`: baseline `EQUIV_ERR_PUBKEY_COUNT`; or `nSigs>nKeys`: baseline `EQUIV_ERR_SIG_COUNT`; mutant proceeds |
| **M-E3-006** | `FindAndDelete` applied in witness v0 (must be base-only) | T+C | `cells/e3-checksig/findanddelete-v0` | SAW, DIFF | v0 CHECKSIG whose signature bytes also appear in `scriptCode`; checker is scriptCode-sensitive: baseline sees the signature, mutant deletes it |
| **M-E3-007** | `OP_CODESEPARATOR` offset off by one (scriptCode starts before/after the separator byte) | T+C | `cells/e3-checksig/codesep` | SAW, DIFF | CHECKSIG after `OP_CODESEPARATOR`; checker is scriptCode-sensitive: baseline pass, mutant fail |
| **M-E3-008** | `OP_CHECKMULTISIGVERIFY` failure maps to `EQUIV_ERR_EVAL_FALSE` instead of `EQUIV_ERR_CHECKMULTISIGVERIFY` | T+C | `cells/e3-cms/verify-error-kind` / `cells/e3-cms/C-L-cms-1of1` | ENUM, SAW | CMSVERIFY with a false result: baseline `EQUIV_ERR_CHECKMULTISIGVERIFY`, mutant `EQUIV_ERR_EVAL_FALSE`; verdict is fail in both, so **error kind** is the kill. Executed on the bounded 1-of-1 cell; run report in `runs/M-E3-008-e3-cell-20261019T230115Z.md` |

Notes:

- `M-E3-001` is the highest-value E3 mutant. It tests that the *pairing* of
  signatures to keys is modeled, not just "some checker returned true."
- `M-E3-002`/`M-E3-003` require the flag sets named in the cell; without the
  policy flags these branches are unreachable and the mutant is a coverage
  finding, not an equivalent mutant.
- `M-E3-006`/`M-E3-007` require a checker that observes `scriptCode`. If the
  SAW override ignores `scriptCode`, the cell is blind; record that as a
  checker-contract finding.
- `M-E3-008` is only killable by a cell that asserts the error enum. A
  verdict-only cell survives and is not acceptable for the error-equality
  family.

---

## 4. E4 — witness v0 and taproot dispatch

| ID | Mutation | Site | Expected failing cell | Catcher | Kill witness / observable |
|---|---|---|---|---|---|
| **M-E4-001** | P2SH redeem script taken from the wrong source (scriptPubKey / first push instead of the last stack item) | T+C | `cells/e4-p2sh/redeem-source` | SAW, DIFF | P2SH spk `HASH160 <hash> EQUAL` with redeem script pushed by scriptSig: baseline executes redeem, mutant fails/hash mismatch |
| **M-E4-002** | witness stack order reversed when building the v0 execution stack | T+C | `cells/e4-witness/stack-order` | SAW, DIFF | P2WSH witness `[script, arg1, arg2]`; baseline pass, mutant executes with args reversed/fails |
| **M-E4-003** | taproot leaf version accepted/compared with the wrong value (0xc0 vs 0xc2, or wrong mask) | T+C | `cells/e4-taproot/leaf-version` | SAW, DIFF | script-path spend with leaf version `0xc0`; mutant requires `0xc2` or masks to accept the wrong byte: baseline pass, mutant fail |
| **M-E4-004** | v0 witness program length check accepts a bad length (e.g. 30 bytes; v0 allows 20 or 32) | T+C | `cells/e4-witness/program-length` | SAW, ENUM | 30-byte v0 program with matching witness: baseline `EQUIV_ERR_WITNESS_PROGRAM_WRONG_LENGTH`, mutant proceeds |
| **M-E4-005** | P2WSH script hash uses `HASH160` instead of `SHA256` | T+C | `cells/e4-witness/p2wsh-hash` | SAW, DIFF | P2WSH spk with 32-byte SHA256 program and valid witness script: baseline pass, mutant `EQUIV_ERR_WITNESS_PROGRAM_MISMATCH` |
| **M-E4-006** | taproot annex treated as a stack element instead of stripped/detected | T+C | `cells/e4-taproot/annex` | SAW, DIFF | key-path spend with final witness element `0x50...`: baseline pass, mutant fails or executes a different stack |
| **M-E4-007** | `OP_SUCCESSx` in tapscript treated as `BAD_OPCODE` (or not treated as immediate success) | T+C | `cells/e4-taproot/opsuccess` | SAW, DIFF | tapscript with an `OP_SUCCESSx` byte followed by a would-be-invalid opcode: baseline success, mutant `EQUIV_ERR_BAD_OPCODE` |
| **M-E4-008** | control-block size bounds off by one (accept 32 or 4130; reject 33/4129) | T+C | `cells/e4-taproot/control-size` | SAW, ENUM | script-path spend with 32-byte control block: baseline `EQUIV_ERR_TAPROOT_WRONG_CONTROL_SIZE`, mutant accepts; mirror at 4129/4130 |

Notes:

- `M-E4-001` and `M-E4-002` target the two most common "looks equivalent"
  mistakes: reading the right bytes from the wrong place, and building a stack
  in the wrong order.
- `M-E4-003` must not be combined with a control-block mutation; leaf version
  and control-block parsing are separate cells.
- `M-E4-006`: annex detection is a dispatch rule; if the cell only proves
  key-path success and never includes an annex, the mutant is a coverage gap.
- `M-E4-007`: `OP_SUCCESSx` is a consensus rule in tapscript; a "disabled
  opcode" cell is not a substitute.

---

## 5. Required subsets and scoring

| Milestone | Required minimum | Must include |
|---|---|---|
| E0 | 0 semantic + 2 harness canaries | shim-smuggle, pin-drift |
| E1 | 3 distinct mutants | `M-E1-001`; plus at least one model-site and one core-copy application (may be the same mutant pair) |
| E2 | 4 distinct mutants | `M-E2-001`, `M-E2-002`, `M-E2-005`, and one of `M-E2-003`/`M-E2-004`/`M-E2-008`/`M-E2-009` |
| E3 | 5 distinct mutants | `M-E3-001`, `M-E3-002`, `M-E3-003`, `M-E3-008`, and one of `M-E3-004`–`M-E3-007` |
| E4 | 5 distinct mutants | `M-E4-001`, `M-E4-002`, `M-E4-003`, `M-E4-004`, `M-E4-007` |

Score = killed required / (required − adjudicated equivalent). Sign-off
requires 100%. Optional mutants are reported separately and never dilute the
required score.

---

## 6. Calibration procedure (before E1 execution)

1. Inventory the actual twin symbols after `twin/` lands. Do not guess anchors.
2. For each variant, fill `find`/`replace` in `mutate.py` with exact text and
   `expect_count` (usually 1).
3. Run `python3 cells/_redteam/mutate.py --list` and confirm the variant is
   reported as calibrated.
4. Run `--dry-run` on a read-only copy; inspect the diff and before/after
   hashes. No write occurs in dry-run.
5. Apply on the real target only after the cell baseline is green (B-gate).
6. If an anchor occurs more than once, expand context; never use
   `replace_all` for a semantic mutation.
7. Record the anchor calibration in the mutant record (`catalogue_version`,
   `anchor_sha256`).
8. If a mutation cannot be expressed textually in the generated twin (e.g. the
   generator emits different names), apply it at the model site and record the
   generated diff; do not fall back to hand-editing IR.

A mutation that cannot be calibrated is not a waiver. It is an open redteam
item blocking the family until a textual or model-site equivalent is found.
