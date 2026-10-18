# Issue 16 remediation plan

## Pin

- `btc-lean` baseline: `80bf09b5dd7de4f6f879671cc0b93c30a4e89dc2`
- Bitcoin Core census anchor: `cce32b168`
- Release tag `data-2026.10.17`: `4f5c4f858fb9ca0743042644453cfa92d30dd271`

This plan covers the mainnet-consensus findings in issue 16. It does not
change the release payload, tag, or default proof closure. Checkboxes on
the issue are updated only after the corresponding change is present on
`main` and its validation has passed.

## Current assessment

| Finding | Current state on `80bf09b` | Remaining work |
|---|---|---|
| BLK-056/BLK-057 median time | Fixed: even windows select index `n/2` and the strict `>` gate is retained. | Re-verify the regression vector in the final proof build. |
| BLK-011 Merkle mutation | Fixed: adjacent-pair detection is pair-aligned and `validateBlock` runs it after the root check. | None. |
| BLK-017/SWT-030 witness commitment | Fixed: the actual coinbase witness reserved value is hashed. | None. |
| BLK-096 BIP30 in the capstone path | Fixed: `validateBlock` calls the BIP30 collision gate before the tx fold. | None. |
| SCR-147 taproot output key | Fixed: `scriptPathSpend` compares the 32-byte program with the tweaked x-coordinate. | Census tag is still `false`; retag with the taproot batch. |
| TPR-006 annex hash | Fixed: the interpreter uses the length-prefixed `annexHash`. | None. |
| SCR-167 CODESEPARATOR position | Open: `State.codeSep` still carries a byte offset and starts at `0`; the tapscript sighash needs the 0-based instruction index with the `0xFFFFFFFF` sentinel. | Correct the state/step model, tag the row consensus, add index-vs-offset vectors, update dependent proofs. |
| SCR-098/INV-056 FindAndDelete | Fixed: the suffix resumes after the match, including the whole-tail case. | Add/retain whole-tail and middle-match regressions. |
| Numeric minimal padding | Partially fixed: `SCR-051` and `SCR-157` are already non-consensus; `SCR-050` is still tagged consensus. `decodeNum` already defaults `pol.minimalData` to false. | Remove the `SCR-050` consensus tag and correct the mixed encoding summaries. |
| Sigop accounting | Partially fixed: P2SH/P2WSH now use the accurate counter. `Rules.sigOpCount` still charges a flat 1 per CHECKMULTISIG and adds one DecodeOP_N for the script tail; `witnessScriptSigOps` returns 0 on a malformed script instead of counting the valid prefix; `witnessSerSize` omits the witness-stack CompactSize count; `validateBlock` does not run the 80,000 block gate. | Fix all four model issues and wire the block gate, then update BLK-035/BLK-036 and the proof corpus. |
| INV-141/BLK-113/BLK-040 work and powLimit | Open: `powLimitMainnet` is the genesis target `2^224-2^208`, not Core's `2^224-1`; `workOf` returns 0 above the model powLimit instead of only for negative, overflow, or zero decodes. | Replace the constant, correct `workOf`, and update the affected proof values. |
| TXV-069 amount range | Fixed in the executable model: each input coin, the running input sum, and the fee are checked against `MoneyRange`. `Amount` is an unbounded `Int`, so the census wording must not claim a global int64 type. | Tighten the summary and proof note; add the out-of-range input/fee regressions. |
| Taproot/tapscript consensus rows | Open: `SCR-142`–`SCR-153`, `SCR-155`–`SCR-172`, and `SCR-174` are still mostly `consensus: false`; `SCR-157`, `SCR-154`, and `SCR-173` stay non-consensus. | Retag the 30 consensus rows after the tapscript weight fix; keep policy-only rows off. |
| Tapscript signature weight/empty pubkey | Correct in the interpreter: empty signatures do not consume weight; the empty-pubkey error follows the budget decrement; `SCR-168` uses `< 0`. | Retag `SCR-159`/`SCR-160` and retain the ordering regressions. |
| Policy flags | Open: 29 rows still carry `consensus: true` for SIGPUSHONLY, CLEANSTACK, MINIMALDATA, MINIMALIF, CONST_SCRIPTCODE, LOW_S, STRICTENC, WITNESS_PUBKEYTYPE, NULLFAIL, discourage flags, the 16,000 standard-tx sigop cap, and the 64-byte mutation arm. | Remove the consensus tag from all 29 rows; retain the policy text as non-consensus. |
| Obsolete/implementation rows | Open: 41 rows marked outside mainnet consensus are still tagged consensus, including retired duplicates, BIP94, signet, policy/DoS, node, and wallet rows. | Remove the consensus tag from all 41 rows; do not delete live successors. |
| Mixed accept/reject rows | Open: summaries for `INV-054`, `INV-055`, `INV-058`, `INV-059`, `INV-074`, `SCR-071`, `SCR-112`, and `TXV-069` still mix policy behavior with consensus behavior or overstate the model. | Rewrite the summaries/notes to keep only the consensus half; point policy halves at their policy rows. |
| BLK-104 BIP68 wiring | Open: `blockSequenceLocksOk` exists and is proved, but `validateBlock` never calls it. | Add the prevout height/time data to the block context, run the gate for non-coinbase txs, and add rejected/accepted sequence vectors. |
| BIP141 proof helper | Open: `programMustFailCastToBool` still exists and its tests assert the wrong any-nonzero predicate. | Delete the helper and its tests; do not change `Bitcoin.Numeric.castToBool`. |

## Workstreams

1. **Script semantics** — CODESEPARATOR index, accurate sigop parsing, valid-prefix witness counting, and deletion of the BIP141 false helper. Files: `spec/core/Bitcoin/Interpreter/Defs.lean`, `Interpreter/Rules.lean`, `Interpreter/SigOps.lean`, `spec/proofs/BitcoinProofs/Bip/B08/`.
2. **Block pipeline** — 80,000 sigop gate and BIP68 sequence locks in the real `validateBlock` path. Files: `spec/core/Bitcoin/Capstone/Block.lean` and its tests/proofs.
3. **Taproot weight** — include the witness-stack CompactSize count in `witnessSerSize`; keep the annex in the budget base. File: `spec/core/Bitcoin/Crypto/Taproot/Program.lean` and `AF/PDW41`.
4. **Proof of work** — Core's full `2^224-1` mainnet powLimit and the `GetBitsProof` negative/overflow/zero rule. Files: `spec/core/Bitcoin/Block/Pow.lean`, `Block/Index.lean`, `AF/PDW28`, `AF/PDW31`.
5. **Census retagging** — 29 policy rows, 41 non-consensus rows, and 30 taproot/tapscript rows. Apply through the census curation layer, then regenerate `spec/db/rules.yaml`; never hand-edit the generated file without the override pass.
6. **Census wording** — correct the mixed summaries and the TXV-069 int64 overclaim, while preserving the consensus halves.
7. **Regressions** — add or update vectors for each behavioral change: index-vs-offset CODESEPARATOR, 2-of-2 P2SH cost, malformed P2WSH prefix counting, witness-stack serialization, 80,001 block sigops, full powLimit/negative work, non-final BIP68 spend, policy-flag acceptance, and tapscript empty-signature weight.
8. **Documentation and residuals** — reconcile `docs/CLAIMS.md`, `docs/RESIDUALS.md`, `docs/REGRESSION-VECTORS.md`, `docs/PROOF-BUILD.md`, `docs/TCB.md`, and `README.md`; record accepted residuals explicitly.

## Acceptance criteria

- No new `sorry`, `admit`, `unsafe`, `partial`, or FFI use.
- Every behavioral correction has a named theorem or executable regression that fails on the old behavior and passes on the new one.
- `make gates`, `spec/scripts/extract_rules.py --check`, `spec/scripts/backfill_overrides.py --check`, `spec/scripts/theorem_index.py --check`, `spec/scripts/proof_scope.py --check`, and `spec/scripts/residuals_index.py --check` pass.
- `lake build BitcoinProofs` succeeds; the final job count and outside-closure result are recorded honestly.
- The consensus and wallet axiom probes pass with only the permitted axiom footprints.
- Census counts and the 27-entry residual ledger are updated only for changes actually present on `main`.
- Issue checkboxes are updated after merge, one workstream at a time, with the validating commit cited.
