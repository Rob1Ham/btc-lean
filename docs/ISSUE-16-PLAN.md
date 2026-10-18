# Issue 16 remediation plan

## Pins

- `btc-lean` `main` baseline: `80bf09b5dd7de4f6f879671cc0b93c30a4e89dc2`
- Merged integration: `f9e9bde535ed16142421309171f06762ecfdf4d4` (the squash
  of `915233cdf7f4e7aa7bd10f133a1ed199f8191edc` plus the validated gap
  fixes; on `main` as of 2026-10-18)
- Bitcoin Core census anchor: `cce32b168`
- Release tag `data-2026.10.17`: `4f5c4f858fb9ca0743042644453cfa92d30dd271`

This plan covers the mainnet-consensus findings in issue 16. It records the
baseline, the merged remediation, and the closeout validation. It does not
change the release payload, tag, or default proof closure.
Issue checkboxes are updated only after the corresponding change is present
on `main` and its validation has passed.

## Status vocabulary

- **on main** — present at the `80bf09b` baseline and unchanged by the
  integration.
- **merged** — present on `main` at `f9e9bde` and validated by the closeout
  run.
- **open** — not implemented, or implemented incompletely. No row remains
  in this state.

## Current assessment

The `Remaining work` column records the closeout checks. All were run and
passed unless this page names an accepted residual.

| Finding | State on `main` (`80bf09b`) | Merged remediation | Remaining work |
|---|---|---|---|
| BLK-056/BLK-057 median time | Fixed on main: even windows select index `n/2` and the strict `>` gate is retained. | No semantic change; the merged tree retains the fix and the even-window vectors. | Re-run the BIP113 regression in closeout. |
| BLK-011 Merkle mutation | Fixed on main: adjacent-pair detection is pair-aligned and `validateBlock` runs it after the root check. | No semantic change; the merged tree retains the CVE-2012-2459 shape tests. | None. |
| BLK-017/SWT-030 witness commitment | Fixed on main: the actual coinbase witness reserved value is hashed. | `merged`: the block witness stage also checks nonce shape, amount independence, and the commitment/reward ordering. | Verify the nonzero reserved-value and commitment-value vectors. |
| BLK-096 BIP30 in the capstone path | Fixed on main: `validateBlock` calls the BIP30 collision gate before the tx fold. | `merged`: exception-aware enforcement at 91842/91880, the height re-enable, and the real candidate txid. | Verify both historical fixtures and the collision path. |
| SCR-147 taproot output key | Fixed on main in the verifier: `scriptPathSpend` compares the program with the tweaked x-coordinate. | `merged`: the live dispatcher binds the control/program commitment before executing the leaf. | Census retag and dispatch regressions. |
| TPR-006 annex hash | Fixed on main: the interpreter uses the length-prefixed `annexHash`. | No semantic change; the merged tree retains the fix. | None. |
| SCR-167 CODESEPARATOR position | Open on main: the state carries a byte offset starting at `0`. | `merged`: `codeSepPos` starts at `0xFFFFFFFF` and records the 0-based opcode index in tapscript; the legacy byte offset is unchanged. | Census summary/tag and an index-versus-offset regression. |
| SCR-098/INV-056 FindAndDelete | Fixed on main: the suffix resumes after the match, including the whole-tail case. | No semantic change; the merged tree retains the head, middle, whole-tail, and no-match vectors. | Keep the regressions in closeout. |
| Numeric minimal padding | Partially fixed on main: `SCR-051` and `SCR-157` are non-consensus and `decodeNum` defaults `pol.minimalData` to false, but `SCR-050` is still tagged consensus. | `merged`: the model is unchanged; the census pass clears `SCR-050` and corrects the mixed encoding summaries. | Complete the census wording and tag correction. |
| Sigop accounting | Partially fixed on main: P2SH/P2WSH use the accurate counter, but the flat per-multisig charge, tail `DecodeOP_N`, zero-on-parse-failure witness count, missing witness-stack `CompactSize`, and missing block gate remain. | `merged`: one shared accurate/inaccurate counter with per-multisig lookback, valid-prefix counting, a count-prefixed witness size, and the cumulative `> 80,000` block gate. | Verify the 2-of-2 P2SH, malformed P2WSH, witness-size, at-limit, and over-limit vectors; update BLK-035/BLK-036 wording. |
| INV-141/BLK-113/BLK-040 work and powLimit | Open on main: `powLimitMainnet` is the genesis target `2^224-2^208`, and `workOf` returns 0 above the model powLimit. | `merged`: `powLimit = 2^224-1`; `workOf` returns 0 only for a negative-flagged, overflowing, or zero decode and does not clamp above `powLimit`. | None: `workOf_above_powLimit_pos`, PDW24, BIP94, and the full build pass. |
| TXV-069 amount range | Fixed on main in the executable model: each input coin, the running input sum, and the fee are checked against `MoneyRange`. | `merged`: the block pipeline also checks the accumulated fee and the coinbase reward. `Amount` remains an unbounded `Int`. | Census wording must say `MoneyRange`, not a global int64 type; keep the out-of-range input and fee vectors. |
| Taproot/tapscript consensus rows | Open on main: `SCR-142`–`SCR-153`, `SCR-155`–`SCR-172`, and `SCR-174` are mostly `consensus: false`. | `merged`: the live key/script path is implemented and the census pass retags the 30 consensus rows; `SCR-154`, `SCR-157`, and `SCR-173` stay non-consensus. | Verify the final census counts and retain policy-only rows off. |
| Tapscript signature weight/empty pubkey | Correct on main: empty signatures do not consume weight, the empty-pubkey error follows the budget decrement, and `SCR-168` uses `< 0`. | `merged`: the same ordering is retained with the shared witness size. | Retag `SCR-159`/`SCR-160` and keep the ordering regressions. |
| Policy flags | Open on main: 29 rows still carry `consensus: true` for policy-only rules. | `merged`: the census pass sets those 29 rows to `consensus: false`; the policy text remains. | Verify the 29-row count in the final census. |
| Obsolete/implementation rows | Open on main: 41 rows outside mainnet block consensus are still tagged consensus. | `merged`: the census pass clears those 41 rows without deleting live successors. | Verify the 41-row count and that no successor was removed. |
| Mixed accept/reject rows | Open on main: summaries for `INV-054`, `INV-055`, `INV-058`, `INV-059`, `INV-074`, `SCR-071`, `SCR-112`, and `TXV-069` mix policy with consensus or overstate the model. | `merged`: the census wording keeps only the consensus half and points policy halves at their policy rows. | Verify each corrected summary against the audit disposition. |
| BLK-104 BIP68 wiring | Open on main: `blockSequenceLocksOk` exists and is proved, but `validateBlock` never calls it. | `merged`: caller-supplied prevout height/time data, a non-coinbase gate before sigops and scripts, and height/time rejection vectors. | Verify disabled-sequence, relative-height, and relative-time cases. |
| BIP141 proof helper | Open on main: `programMustFailCastToBool` still exists and its tests assert the wrong any-nonzero predicate. | `merged`: the helper and its six tests are removed; the tests use `Bitcoin.Numeric.castToBool` and the witness-program verdict. | None: `Bip141Defs`, `Bip141Tests`, and W09 pass. |
| Candidate taproot live path | On main, v1 witness spends take the `unjudged` lane. | `merged`: real BIP341 hashing and BIP340 verification, full spent-output binding, and an explicit `unjudged` outcome only when required signature context is unavailable. | Keep the unavailable-context accounting explicit and do not describe a partial replay as complete validation. |

## Workstreams

1. **Script semantics** — CODESEPARATOR index and sentinel, accurate sigop parsing, valid-prefix witness counting, and removal of the BIP141 false helper. `merged`.
2. **Block pipeline** — 80,000 sigop gate, block fee accumulator, and BIP68 sequence locks in the real `validateBlock` path. `merged`.
3. **Taproot weight** — include the witness-stack `CompactSize` count in `witnessSerSize`; keep the annex in the budget base. `merged`.
4. **Proof of work** — Core's full `2^224-1` mainnet `powLimit` and the `GetBitsProof` negative/overflow/zero rule. `merged`.
5. **Census retagging** — 29 policy rows, 41 non-consensus rows, and 30 taproot/tapscript rows. `merged` through the census curation layer; `spec/db/rules.yaml` is regenerated, not hand-edited.
6. **Census wording** — the mixed summaries and the TXV-069 int64 overclaim. `merged`.
7. **Regressions** — index-versus-offset CODESEPARATOR, 2-of-2 P2SH cost, malformed P2WSH prefix counting, witness-stack serialization, 80,001 block sigops, full powLimit and above-powLimit work, non-final BIP68 spend, policy-flag acceptance, and tapscript empty-signature weight. `merged`; the final results are recorded in the validation section above.
8. **Documentation and residuals** — reconcile `docs/CLAIMS.md`, `docs/RESIDUALS.md`, `docs/REGRESSION-VECTORS.md`, `docs/PROOF-BUILD.md`, `docs/TCB.md`, and `README.md`; record accepted residuals explicitly. `merged`.

## Validation status

The merged integration now has a final `make gates` pass and a
`lake build BitcoinProofs` pass with **1,731 jobs**. The nine static gates,
the extraction/backfill fixed points, the theorem/scope/residual indexes, the
dynamic axiom manifest (333 entries; 434 lines), the focused Capstone suites,
W09, the CVE replay, and the BIP30 driver all pass. The changes are merged to
`main` at `f9e9bde`; this page records their validation and is not a
substitute for an external audit or for the public issue closeout.

## Final acceptance commands

```sh
make gates
python3 spec/scripts/extract_rules.py --check
python3 spec/scripts/backfill_overrides.py --check
python3 spec/scripts/theorem_index.py --check
python3 spec/scripts/proof_scope.py --check
python3 spec/scripts/residuals_index.py --check
(cd spec/proofs && lake build BitcoinProofs)
(cd spec/core && lake build Test.Capstone.Run)
make test-capstone-values test-capstone-funding test-capstone-context \
     test-capstone-finality test-capstone-csv test-capstone-script-flags \
     test-capstone-pow-limit test-capstone-sigops test-capstone-sigop-budget \
     test-capstone-witness test-capstone-taproot
make gate-axiom-probe
bash spec/scripts/wallet_axiom_manifest.sh --probe
```

The closeout records the exact exit status, job count, focused-test result,
and any accepted residual. A command that was not run is not reported as
passed.

## Residual policy

- A `proven` row means its cited Lean target exists, is in the proof surface,
  and carries the row tag. It does not by itself mean the target paraphrases
  the whole row summary. Statement fidelity is reviewed separately.
- The 27 accepted residuals remain explicit until the replacement target
  covers the Core claim. A repaired code path is not by itself grounds to
  delete a residual. The ledger and its generated evidence page are updated
  together.
- Candidate status is provisional. No issue checkbox is checked until the
  change is on `main` and the closeout validation passes.
- `validateBlock` without a supplied `ChainContext` is partial replay, not a
  full historical mainnet validation. Ancestor history and supplied UTXOs are
  conditional inputs, and a report with incomplete script adjudication is not
  a successful complete validation.
- BIP68 prevout heights and times are caller-supplied. The model does not
  reconstruct historical chainstate.
- Taproot signature context that is unavailable is reported as `unjudged`,
  never as an assumed pass or an invalid signature. It must remain visible in
  replay reports.
- The `workOf` above-powLimit clamp and the BIP141 `programMustFailCastToBool`
  helper are fixed on `main`. Do not describe either as an unmerged change.
- Census counts are updated only for changes actually present on `main`.
  The row count remains 726 (676 `proven`, 50 `obsolete`) unless a separate,
  validated census change says otherwise.
