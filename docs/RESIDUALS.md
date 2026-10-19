# Consensus residuals

**Open residual rows: 0 / 726.**

Issue #22 closed the eighteen statement-fidelity residuals that were counted in
`proven` but whose cited target did not entail the whole row. Each row now
names a theorem whose statement covers the missing link identified by the
audit. The closure is a statement-fidelity and build claim about the Lean
model; it is not an external audit of Bitcoin Core and it does not turn the
model into a bit-for-bit executable.

The authoritative row records remain in `spec/db/rules.yaml`. The closeout
evidence (theorem statements, module builds, anchor replay, and the contextual
entry-point regression) is in [`ISSUE-22-CLOSEOUT.md`](ISSUE-22-CLOSEOUT.md).
The generated evidence matrix is
[`RESIDUALS-EVIDENCE.md`](RESIDUALS-EVIDENCE.md); the machine-readable copy is
[`spec/db/residuals.yaml`](../spec/db/residuals.yaml). Both are rebuilt by
`python3 spec/scripts/residuals_index.py`.

A residual used to mean: the row claim is true of Bitcoin Core, but the cited
Lean target did not yet entail the whole claim. The table below records the
closing target for each former residual. "Closed" means the target now states
the identified missing link and the target builds; it does not mean the row was
independently audited against C++.

## Closed issue-22 residuals

| ID | Row claim | Closing target(s) |
|---|---|---|
| `BLK-008` | odd-sized level duplicates its last element before pairing | `BitcoinProofs.AF.PDW50.merkleLevel_append_singleton` |
| `BLK-086` | CHECKLOCKTIMEVERIFY when BIP65 active | `Bitcoin.Activation.cltv_flag_iff_mainnet_any` |
| `BLK-087` | CHECKSEQUENCEVERIFY + LOCKTIME_VERIFY_SEQUENCE when CSV active | `Bitcoin.Activation.csv_locktime_flag_flow_mainnet_any` |
| `INV-022` | script-level finality lock (5-byte CScriptNum; both tx-level finality AND lock satisfied) | `BitcoinProofs.AF.PDW68xPath.stepBody_cltv_path` |
| `INV-023` | script-level relative lock | `BitcoinProofs.AF.PDW68xPath.stepBody_csv_path` |
| `INV-057` | codeseparator-pos commit | `BitcoinProofs.Theorems.Ops.INV057.codesep_position_commit` |
| `INV-117` | reverse transition | `Bitcoin.Block.Params.disconnectBlock_inv117`; `Bitcoin.Block.Params.disconnectBlock_inv117_fold` |
| `INV-130` | CSV flag gate | `Bitcoin.Activation.csv_flag_iff_mainnet_any` |
| `SCR-030` | combined check | `Bitcoin.Interpreter.evalScriptBytes_ok_stack_alt_bound` |
| `SCR-066` | BAD_OPCODE when executed; unexecuted OP_VER passes | `BitcoinProofs.AF.PDW67bG.stepBody_reserved_executed_badOpcode`; `BitcoinProofs.AF.PDW67bG.stepBody_reserved_unexecuted_skip` |
| `SCR-067` | each IF counts 1 opcode | `BitcoinProofs.AF.PDW88b.stepBody_notif_counts_opcode`; `BitcoinProofs.AF.PDW88b.stepBody_notif_unexecuted_counts`; `BitcoinProofs.AF.PDW88b.stepBody_notif_counts_opcode_base_nonempty`; `BitcoinProofs.AF.PDW88b.stepBody_notif_opCount_reject`; `BitcoinProofs.AF.PDW88.stepBody_if_counts_opcode` |
| `SCR-070` | first-byte OP_RETURN or >10k script ⇒ never spendable | `BitcoinProofs.AF.PDW9.UnspendableSpend.verifyScriptFull_opReturn`; `verifyScriptFull_oversize`; `verifyScriptFull_opReturn_of_parse`; `verifyScriptFull_oversize_of_size` |
| `SCR-074` | each op checks depth ⇒ INVALID_STACK_OPERATION | `BitcoinProofs.AF.PDW79b.stepBody_2drop_depth` … `stepBody_tuck_depth` (all 16 depth arms) |
| `SCR-086` | clamp to int32 for depth/count uses | `BitcoinProofs.AF.PDW86Clamp.stepBody_pick_ok_clamped`; `stepBody_roll_ok_clamped`; `checkMultiSig_key_count_clamped`; `checkMultiSig_sig_count_clamped` |
| `SWT-026` | P2WSH witness-script sigop count is Core `GetSigOpCount(true)` over the last witness item: count the valid opcode prefix up to the first malformed push, with CHECKSIG/CHECKSIGVERIFY = 1 and CHECKMULTISIG = the preceding OP_1..OP_16 value (20 if absent). | `Bitcoin.Interpreter.SigOps.witnessScriptSigOps_eq_coreSigOpCount`; `coreSigOpCount_oversize_push_head` |
| `TPR-007` | exactly 1 element (post-annex) ⇒ single BIP340 sig against output key q | `BitcoinProofs.AF.PDW25.TPR007.keyPath_one_element_bip340` |
| `TPR-071` | the annex is included in the witness stack serialization that seeds the tapscript validation-weight budget; the serialized stack is the CompactSize item count plus each item's CompactSize length and bytes, with the annex present, before it is popped for spend classification. | `BitcoinProofs.Theorems.Ops.TPR071.txWeight_annex_witness_contribution` |
| `TXV-069` | each input value, the running input sum, and the fee satisfy MoneyRange (0 ≤ x ≤ MAX_MONEY); outputs are bounded separately | `Bitcoin.TxValidation.LocktimeSigOps.amountArithmetic_i64`; `BitcoinProofs.Theorems.CapstoneFunding.applyTxsWithFees_i64_final`; `applyTxWithFeeCheck_i64_step` |

## Out-of-ledger obligations

Six former residual rows are outside block-acceptance consensus and remain in
the census with `consensus: false`. They were not deleted, and no statement was
proved by moving them. They are not counted in the open residual total.

- **INV-046** (`BIP62 rule 3/4`, minimal push / `MINIMALDATA`) — the
  `SCRIPT_VERIFY_MINIMALDATA` policy flag, not a block-accept rule. The
  consensus operand-width cap is INV-058; the policy face rows are
  SCR-048/SCR-049/SCR-050/SCR-051. The all-size `checkMinimalPush` obligation
  remains policy work.
- **SCR-008** (CLEANSTACK as a flag) — the explicit flag gate at
  `VerifyScript:2110-2118` is policy for base/P2SH spends. The block-accept
  content is carried by SWT-012 and SCR-183.
- **INV-114** (`data model`, Coin = (out, coinbase?, height), spent ⇔ null
  out) — the in-memory/on-disk coins-DB model, not a block-acceptance check.
  The UTXO-set consensus content is carried by INV-110/INV-111/INV-112/INV-113.
- **INV-115** (serialization invariant, 31-bit height + 1-bit coinbase
  metadata word) — the on-disk coins serialization, not a block-acceptance
  check. Its consensus-relevant effect is carried by INV-113 and
  BLK-099/BLK-106.
- **INV-119** (UTXO snapshot hash, MuHash3072, assumeutxo) — snapshot
  equality machinery, not a block-acceptance check. The UTXO-transition
  consensus content is carried by INV-110/INV-111/INV-116/INV-117.
- **INV-138** (API surface, DeploymentEnabled/ActiveAt helpers) — activation
  API helpers, not a block-acceptance check. The actual flag selection is
  carried by INV-122..INV-126, INV-128/INV-130/INV-131, SCR-015, and
  BLK-086/BLK-087.
