# Issue 22 closeout: mainnet consensus residual closure

This page records the evidence for closing issue #22. It is a
statement-fidelity and build claim about the Lean model, plus a diagnostic
replay of the release anchor corpus. It is not an external audit of Bitcoin
Core, and it does not claim that the Lean model is bit-for-bit executable.

## Result

- The statement-fidelity ledger is **0 / 726** open residuals. The eighteen
  issue-22 residuals are closed; the six out-of-ledger obligations remain
  marked `consensus: false` in [`RESIDUALS.md`](RESIDUALS.md).
- Every one of the eighteen closing targets builds. The new targets are
  generic over the case the audit identified, not additional examples.
- The default proof closure builds, the core package builds, and CI builds the
  seven issue-22 audit modules plus the ten closing-target modules outside the
  default closure.
- The contextual pipeline has one public next-block entry point,
  `validateNextBlock`, which derives its `ChainContext` from a checked
  `ChainState`. The context-free `replayBlockPartial` reports
  `fullValidation = false` and is never an acceptance predicate.
- The release anchor corpus replays diagnostically with `replayOk=true` and
  `accepted=false`; the runner labels the result `partial-context`, and every
  script-unjudged count is reported rather than treated as success.

## Closed rows

The row summaries and Core anchors are in [`RESIDUALS.md`](RESIDUALS.md) and
[`spec/db/rules.yaml`](../spec/db/rules.yaml). This table records the closing
target and the specific missing link it now states.

| ID | Closing target(s) | What the target now covers |
|---|---|---|
| `BLK-008` | `BitcoinProofs.AF.PDW50.merkleLevel_append_singleton` | The odd-tail duplication law for any odd-length level, not only the singleton level. |
| `BLK-086` | `Bitcoin.Activation.cltv_flag_iff_mainnet_any` | CLTV is on at every mainnet hash exactly from the buried height, including the exception-hash arm and the below-height converse. |
| `BLK-087` | `Bitcoin.Activation.csv_locktime_flag_flow_mainnet_any` | CSV activation sets the OP_CSV flag and the contextual `LOCKTIME_VERIFY_SEQUENCE` bit together for every mainnet hash. |
| `INV-022` | `BitcoinProofs.AF.PDW68xPath.stepBody_cltv_path` | The whole executed CLTV transition: flag gate, stack-depth check, five-byte numeric decode, negative check, `CheckLockTime` verdict, and opcode-count update. |
| `INV-023` | `BitcoinProofs.AF.PDW68xPath.stepBody_csv_path` | The whole executed CSV transition, including the disable-bit NOP and `CheckSequence` verdict. |
| `INV-057` | `BitcoinProofs.Theorems.Ops.INV057.codesep_position_commit` | Both consumers of an executed `OP_CODESEPARATOR`: tapscript `codesep_pos` in the sighash and legacy `codeSep` scriptCode slicing. |
| `INV-117` | `Bitcoin.Block.Params.disconnectBlock_inv117_fold`; `disconnectBlock_inv117` | The arbitrary-length reverse disconnect fold, with the UTXO state and the per-output cleanliness verdict; the three-transaction face remains as a corollary. |
| `INV-130` | `Bitcoin.Activation.csv_flag_iff_mainnet_any`; `csv_flag_gate_iff_mainnet_any` | The CSV script flag (and the contextual locktime gate) exactly from the buried height for every mainnet hash. |
| `SCR-030` | `Bitcoin.Interpreter.evalScriptBytes_ok_stack_alt_bound` | An exported `evalScriptBytes` stack is the main stack of a machine state satisfying the combined main+alt bound. |
| `SCR-066` | `BitcoinProofs.AF.PDW67bG.stepBody_reserved_executed_badOpcode`; `stepBody_reserved_unexecuted_skip` | Executed reserved opcodes fail with `BAD_OPCODE`; unexecuted `OP_VER` is skipped as Core does. |
| `SCR-067` | `BitcoinProofs.AF.PDW88b.stepBody_notif_counts_opcode`; `stepBody_notif_unexecuted_counts`; `stepBody_notif_counts_opcode_base_nonempty`; `stepBody_notif_opCount_reject`; `BitcoinProofs.AF.PDW88.stepBody_if_counts_opcode` | Each executed or unexecuted IF/NOTIF increments the opcode count and the 201-op gate rejects before dispatch. |
| `SCR-070` | `BitcoinProofs.AF.PDW9.UnspendableSpend.verifyScriptFull_opReturn_of_parse`; `verifyScriptFull_oversize_of_size`; `verifyScriptFull_opReturn`; `verifyScriptFull_oversize` | Any parsed OP_RETURN-prefixed output script and any output script over 10,000 bytes fail the consensus verifier; the boundary 10,000-byte non-OP_RETURN positive control also evaluates true. |
| `SCR-074` | The sixteen `BitcoinProofs.AF.PDW79b.stepBody_*_depth` targets | Each opcode that needs stack depth checks the depth and returns `INVALID_STACK_OPERATION` before mutating the stack. |
| `SCR-086` | `BitcoinProofs.AF.PDW86Clamp.stepBody_pick_ok_clamped`; `stepBody_roll_ok_clamped`; the CHECKMULTISIG key/sig clamps | Depth/count operands are clamped to the int32 range before use, so the model cannot accept a huge negative/overflowed index. |
| `SWT-026` | `Bitcoin.Interpreter.SigOps.witnessScriptSigOps_eq_coreSigOpCount`; `coreSigOpCount_oversize_push_head` | The P2WSH witness-script sigop count uses Core's size-bounded `GetOp` walk, including the stop at an oversized push. |
| `TPR-007` | `BitcoinProofs.AF.PDW25.TPR007.keyPath_one_element_bip340` | The post-annex one-element key-path case verifies exactly one BIP340 signature against the output key. |
| `TPR-071` | `BitcoinProofs.Theorems.Ops.TPR071.txWeight_annex_witness_contribution`; `txWeight_annex_witness_contribution_pos` | The annex changes the actual BIP144 `txWeight` by its length prefix and bytes (and any stack-count prefix growth), not merely a helper size. |
| `TXV-069` | `Bitcoin.TxValidation.LocktimeSigOps.amountArithmetic_i64`; `BitcoinProofs.Theorems.CapstoneFunding.applyTxsWithFees_i64_final`; `applyTxWithFeeCheck_i64_step` | Input values, partial input sums, each transaction fee, and the block fee accumulator stay in `MoneyRange`; the wrapping i64 accumulator is the identity on those values. |

## Build and gate evidence

Recorded on 2026-10-19 with the pinned Lean toolchain and mathlib revision.

| Check | Result |
|---|---|
| `cd spec/core && lake build` | `Build completed successfully (149 jobs).` |
| `cd spec/proofs && lake build BitcoinProofs` | `Build completed successfully (1733 jobs).` |
| `lake exe issue22` (core) | 3/3 checks: single entry point equals contextual pipeline and explicit context; context-free adapter reports `fullValidation=false`. |
| `make gates` | All gates pass, including rule crosscheck, theorem index, residual index, proof scope, sorry/axiom/wallet gates, data subset, and reproducibility checks. |
| `rule_crosscheck.py` | 726 rows; 676 `@[rule]` ids / 2686 attributes; 676 implemented/tagged; coverage OK. |
| `core_correspondence_check.py` | 611 proven consensus rows carry a pinned Core anchor and a Lean target. |
| `residuals_index.py --check` | 0 residuals. |
| `proof_scope.py --check` | 426 modules, 38-module default closure, 388 outside-closure modules; counts current. |
| `python3 spec/scripts/backfill_overrides.py` | Wrote the synchronized 721-entry overrides table. |

The seven issue-22 audit modules were built by exact name:

| Module | Jobs |
|---|---:|
| `BitcoinProofs.Audit.Z03.Probe` | 33 |
| `BitcoinProofs.Audit.Z09.Corners` | 26 |
| `BitcoinProofs.Bip.B03.B03Subsidy` | 75 |
| `BitcoinProofs.Bip.B10.Bip144Vectors` | 8 |
| `BitcoinProofs.EcdsaDeep.DerBattery` | 9 |
| `BitcoinProofs.EcdsaDeep.S02Flip` | 49 |
| `BitcoinProofs.Theorems.Audit.CV02` | 26 |

The closing targets were also built by exact name. `PDW50` and
`CapstoneFunding` are in the default closure; the other ten are additionally
built by the CI closeout job:

| Module | Jobs |
|---|---:|
| `BitcoinProofs.AF.PDW50.PDW50` | 13 |
| `BitcoinProofs.AF.PDW68x.PDW68xPath` | 40 |
| `BitcoinProofs.Theorems.Ops.INV057` | 29 |
| `BitcoinProofs.AF.PDW67b.PDW67bG` | 26 |
| `BitcoinProofs.AF.PDW88.PDW88` | 26 |
| `BitcoinProofs.AF.PDW88.PDW88b` | 27 |
| `BitcoinProofs.AF.PDW9.UnspendableSpend` | 42 |
| `BitcoinProofs.AF.PDW79.PDW79b` | 27 |
| `BitcoinProofs.AF.PDW86.PDW86Clamp` | 28 |
| `BitcoinProofs.AF.PDW25.TPR007` | 37 |
| `BitcoinProofs.Theorems.Ops.TPR071` | 32 |
| `BitcoinProofs.Theorems.CapstoneFunding` | 57 |

The activation and capstone rows are in the core build: `Bitcoin.Activation`,
`Bitcoin.Block.Params`, `Bitcoin.Interpreter.Defs`, and
`Bitcoin.TxValidation.LocktimeSigOps` are part of the 149-job core build.

## Contextual replay and the anchor corpus

`replayBlockPartial` is a diagnostic adapter. It keeps the structural,
Merkle, PoW, header-link, ledger, and fee checks that can be evaluated without
the prior-chain view, and it reports the inputs whose script signatures could
not be adjudicated. It reports `fullValidation = false` unconditionally.
`validateBlockInContext` is the contextual pipeline: it rejects an
unadjudicated input as `script-unjudged` and cannot return `ok` while
`scriptUnjudged` is nonzero. `validateNextBlock` is the public single entry
point; its `ChainState` carries the candidate height, checked parent hash, UTXO
view, header index, and node clock, and the contexts for BIP68 and header
checks are derived from that state.

| set | height | replayOk | accepted | isPartial | reason | txs | scriptOk | scriptUnjudged | adjudication | fold agrees | ms | model hash |
|---:|---:|---|---|---|---|---:|---:|---:|---|---|---:|---|
| 1 | 0 | true | false | true | partial-context | 1 | 0 | 0 | complete | true | 0 | `000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f` |
| 1 | 74638 | true | false | true | partial-context | 3 | 2 | 0 | complete | true | 130 | `000000000069e1affe7161ab4bcbeacebb4ddf155b50e807f42de971b688a09b` |
| 1 | 91842 | true | false | true | partial-context | 1 | 0 | 0 | complete | true | 1 | `00000000000a4d0a398161ffc163c503763b1f4360639393e0e4c8e300e0caec` |
| 1 | 91880 | true | false | true | partial-context | 2 | 1 | 0 | complete | true | 68 | `00000000000743f190a18c5577a3c2d2a1f610ae9601ac046a38084ccb7cd721` |
| 1 | 481824 | true | false | true | partial-context | 1866 | 5192 | 0 | complete | true | 2795563 | `0000000000000000001c8018d9cb3b742ef25114f27563e3fc4a1902167f9893` |
| 1 | 709632 | true | false | true | partial-context | 2043 | 6630 | 0 | complete | true | 3502804 | `0000000000000000000687bca986194dc2c1f949318629b44bb54ec0a94d8244` |
| 2 | 170 | true | false | true | partial-context | 2 | 1 | 0 | complete | true | 68 | `00000000d1145790a8694403d4063f323d499e655c83426834d4ce2f8dd4a2ee` |
| 2 | 170060 | true | false | true | partial-context | 23 | 63 | 0 | complete | true | 4191 | `00000000000002dc756eebf4f49723ed8d30cc28a5f108eb94b1ba88ac4f9c22` |
| 2 | 170061 | true | false | true | partial-context | 6 | 14 | 0 | complete | true | 910 | `0000000000000abd377cb70a3131adefe82fbefb9f3adfc0ea1a4252be3896de` |
| 2 | 481827 | true | false | true | partial-context | 1377 | 4855 | 0 | complete | true | 1652360 | `000000000000000000509863d58a52dbe2ec811d91619f164dab3fe9177874b4` |
| 2 | 481828 | true | false | true | partial-context | 1 | 0 | 0 | complete | true | 2 | `000000000000000000bc331eb461d522cb3673b3881217dc30c6a5cf91710f23` |
| 2 | 499195 | true | false | true | partial-context | 3778 | 4592 | 0 | complete | true | 900220 | `0000000000000000000c239e79582620a8f586387a3e6990eba9d7f2328315bc` |
| 2 | 709635 | true | false | true | partial-context | 945 | 2274 | 0 | complete | true | 923076 | `00000000000000000001f9ee4f69cbc75ce61db5178175c2ad021fe1df5bad8f` |

All thirteen blocks report `replayOk=true`, `accepted=false`, `isPartial=true`,
`reason=partial-context`, `scriptAdjudication=complete`, `scriptUnjudged=0`,
and `foldAgrees=true`. The 709635 row is the first real Taproot-spend block:
the earlier diagnostic run had 21 unjudged taproot inputs, while this run
adjudicates all 2,274 inputs and reports zero unjudged. The sum of per-block
`ms` is 9,779.4 s; the blocks were run concurrently, so wall clock was about
59 minutes. Twelve blocks have a pinned `.hash` file and the model hash
matches it; the bundle has no `481827.hash`, so that row's hash is the value
recorded by the prior corpus run. The model does not contact the network and
does not compare against `bitcoind`; this is a finite offline replay record.


## What is still not claimed

- The default proof closure is not the whole proof tree. The combined recorded
  per-name status over today's 388 outside-closure modules is 386 passes and
  2 failures (the prior post-audit run over 380 modules plus the eight new
  modules, all built individually). One
  failure is the deliberate `BitcoinProofs.Theorems.FuelStabilityProbe`
  counterexample. The other is
  `BitcoinProofs.Theorems.T3T4PipelineRealCor`, a pre-existing post-audit API
  drift module with no `@[rule]` tag and no CI entry; it is not in the
  issue-22 target set, and the closeout does not claim a package-wide green
  build.
- The context-free anchor replays are diagnostic. They show that the decoder,
  Merkle root, PoW, header link, ledger transition, and fee checks agree on
  real blocks, but they do not supply historical block context, BIP68
  sequence data, or historical script signature adjudication for every input.
- The row closure is statement fidelity plus a build. It is not a
  bit-for-bit refinement proof against Bitcoin Core C++, and it is not an
  external security audit.
- The model's `Amount` is an unbounded `Int` with an explicit `i64Wrap`
  accumulator. The TXV-069 targets prove the wrap is the identity on the
  checked values; they do not claim the model uses machine `int64_t`
  everywhere.
- Historical reachability remains a separate obligation: `ChainState` is
  caller-supplied checked state, not a proof that the state was derived from
  serialized chain history.

## Reproduction

```sh
cd spec/core
lake build
lake exe issue22

cd ../proofs
lake build BitcoinProofs
lake build BitcoinProofs.Audit.Z03.Probe
lake build BitcoinProofs.Audit.Z09.Corners
lake build BitcoinProofs.Bip.B03.B03Subsidy
lake build BitcoinProofs.Bip.B10.Bip144Vectors
lake build BitcoinProofs.EcdsaDeep.DerBattery
lake build BitcoinProofs.EcdsaDeep.S02Flip
lake build BitcoinProofs.Theorems.Audit.CV02
lake build BitcoinProofs.AF.PDW68x.PDW68xPath
lake build BitcoinProofs.Theorems.Ops.INV057
lake build BitcoinProofs.AF.PDW67b.PDW67bG
lake build BitcoinProofs.AF.PDW88.PDW88
lake build BitcoinProofs.AF.PDW88.PDW88b
lake build BitcoinProofs.AF.PDW9.UnspendableSpend
lake build BitcoinProofs.AF.PDW79.PDW79b
lake build BitcoinProofs.AF.PDW86.PDW86Clamp
lake build BitcoinProofs.AF.PDW25.TPR007
lake build BitcoinProofs.Theorems.Ops.TPR071

cd ../..
make gates
python3 spec/scripts/rule_crosscheck.py
python3 spec/scripts/core_correspondence_check.py
python3 spec/scripts/theorem_index.py --check
python3 spec/scripts/residuals_index.py --check
python3 spec/scripts/proof_scope.py --check
```
