# Consensus residuals

The consensus census has 726 rows: 676 `proven`, 50 `obsolete`, 0
`implemented`, and 0 `planned`. Eighteen of the proven rows are **explicit
model residuals**: the row's one-line claim is true of Bitcoin Core, but the
current Lean model does not yet entail it. They are not counted as fully proved
against Core. A further six former residual rows are **out-of-ledger
obligations** (see the section below): two policy rows that were never
consensus, and four node/API rows retagged `consensus: false` by the issue 22
residual-ledger triage. The database now marks 115 rows `consensus: false`
(65 proven and 50 obsolete).

`status: proven` in `spec/db/rules.yaml` means that the row's cited Lean target
is in the proof surface and carries the row's tag. The default
`BitcoinProofs` target is a 37-module closure; a per-name run covers the
380 outside-closure modules (381 `.lean` entries including the non-module
`lakefile.lean`), of which the recorded per-name census was 373 builds and 7 failures;
`BitcoinProofs.AF.PDW62b.PDW62b` has since been repaired and now builds.
No cited target remains in the failing set. The status does not by itself mean that the target's
conclusion paraphrases the whole row summary. That last step is statement
fidelity, and these 18 rows are where the current targets fall short.

This document records the current per-row statement-fidelity record. The
authoritative row records remain in `spec/db/rules.yaml`; this page exists so
the gaps are visible without depending on unpublished notes.

**Residual rows: 18 / 726.**

The machine-readable ledger is [`spec/db/residuals.yaml`](../spec/db/residuals.yaml).
The generated evidence matrix is [`RESIDUALS-EVIDENCE.md`](RESIDUALS-EVIDENCE.md);
both are rebuilt by `python3 spec/scripts/residuals_index.py`.

## Out-of-ledger obligations

Six rows were removed from the residual ledger by the issue 22 triage. None
was deleted from the census: every row keeps its `spec/db/rules.yaml` record,
its `lean_target`, and its proofs, and no underlying residual statement is
claimed proved. The six IDs are excluded from the residual count (18, down
from 24) because none is a block-acceptance consensus obligation; the census
rows remain as evidence, and the Lean obligations stay open as row-tagged
work, not as proof claims.

- **INV-046** (`BIP62 rule 3/4`, minimal push / `MINIMALDATA`) — already
  catalogued `consensus: false`. `CheckMinimalPush` / minimal push is the
  `SCRIPT_VERIFY_MINIMALDATA` policy flag (standardness), not a block-accept
  rule; Core enforces it only with the flag set. The policy face rows are
  SCR-048/SCR-049/SCR-050/SCR-051, and the consensus operand-width cap is
  INV-058. The open missing-link record (an all-size
  `checkMinimalPush` iff) is an obligation on the policy face.
- **SCR-008** (CLEANSTACK as a flag) — already catalogued
  `consensus: false`. The explicit `stack.size() != 1` gate at
  `VerifyScript:2110-2118` is a script-verify flag; base/P2SH clean-stack is
  policy. The block-accept content (a witness v0 / tapscript spend must leave
  exactly one truthy stack element) is carried by the consensus rows SWT-012
  and SCR-183; the flag-combination constraint is SCR-009.
- **INV-114** (`data model`, Coin = (out, coinbase?, height), spent ⇔ null
  out) — retagged `consensus: false` (issue 22). The `Coin` representation
  and the `IsSpent() = out.IsNull()` spent-encoding are the node's
  in-memory/on-disk coins-DB data model (`coins.h`), a node/API obligation,
  not a block-acceptance check. The UTXO-set consensus content
  (nonexistent-spend rejects, insertion, unspendable outputs never added,
  pre-BIP30 coinbase overwrite) is carried by the block rules
  INV-110/INV-111/INV-112/INV-113. The statement-fidelity gap (no model of
  `Coin::IsSpent`; the cited PDW18 theorem is a definitional restatement)
  remains open; nothing was proved.
- **INV-115** (serialization invariant, 31-bit height + 1-bit coinbase
  metadata word) — retagged `consensus: false` (issue 22). The
  `(nHeight << 1) | fCoinBase` metadata word is the node's on-disk coins
  serialization (`coins.h:77-89`), a node/API obligation, not a
  block-acceptance check. Its consensus-relevant effect (BIP30 coinbase
  spend-by-height, disconnect consistency) is carried by the block rules
  INV-113 and BLK-099/BLK-106. The gap (no enforced 31-bit domain or
  all-stored-coins serialization theorem) remains open; nothing was proved.
- **INV-119** (UTXO snapshot hash, MuHash3072, assumeutxo) — retagged
  `consensus: false` (issue 22). `MuHash3072`/coinstats is the assumeutxo
  snapshot-equality machinery — a node snapshot load/verify feature, a
  node/API obligation, not a block-acceptance check. The UTXO-transition
  consensus content (insert/spend/undo/reverse) is carried by the block rules
  INV-110/INV-111/INV-116/INV-117. The gap (the model's `muhashSet` is an
  additive-Nat abstraction; the 3072-bit class-group digest is unmodelled)
  remains open; nothing was proved.
- **INV-138** (API surface, DeploymentEnabled/ActiveAt helpers) — retagged
  `consensus: false` (issue 22). The `deploymentstatus.h`
  `DeploymentEnabled`/`DeploymentActiveAfter`/`DeploymentActiveAt` helper
  surface is the node's activation API, a node/API obligation, not itself a
  block-acceptance check. Which rules a block is actually validated under is
  carried by the activation block rules INV-122..INV-126, the flag gates
  INV-128/INV-130/INV-131, the actual-hash flag selection SCR-015, and
  BLK-086/BLK-087. The gap (no `DeploymentEnabled` model; the cited PDW88
  theorem is a definitional restatement) remains open; nothing was proved.

## BLK

### BLK-008

- claim: odd-sized level duplicates its last element before pairing
- core: `M:ComputeMerkleRoot:51-73@cce32b168`
- target: `BitcoinProofs.AF.PDW50.merkleLevel_singleton`
- missing link: The summary is true of Core: ComputeMerkleRoot duplicates the odd tail before pairing (`hashes.push_back(hashes.back())`, src/consensus/merkle.cpp:64-65), and the model's `merkleLevel` definition encodes the same rule (`[a] => [pairHash a a]`, `a :: b :: rest => pairHash a b :: merkleLevel rest`, spec/core/Bitcoin/Capstone/Merkle.lean:71-74). The cited target `merkleLevel_singleton` (spec/proofs/BitcoinProofs/AF/PDW50/PDW50.lean:77-78) proves only `merkleLevel [a] = [pairHash a a]`; `merkleLevel_length` (PDW50.lean:82-119) gives only the `(n+1)/2` length law, and the only larger odd cases are the concrete `merkleLevel_odd3` (spec/proofs/BitcoinProofs/Audit/Z27/Audit.lean:92-93) and `merkleRootOf_odd5` (:100-104). No theorem states last-element duplication for an arbitrary odd level of length >= 3. Missing piece: a general odd-tail theorem (e.g. an explicit expression for `merkleLevel` of `l ++ [x]`, or that the duplicated last hash appears as `pairHash x x`). Open proof obligation; the true Core claim is kept, not narrowed.

### BLK-086

- claim: CHECKLOCKTIMEVERIFY when BIP65 active
- core: `V:2271-2274@cce32b168`
- target: `Bitcoin.Activation.cltv_flag_flow`
- missing link: The summary is true of Core: CLTV is OR-ed in whenever BIP65 is active, for every block hash including the exception hashes (validation.cpp:2272-2275). The cited `cltv_flag_flow` (spec/core/Bitcoin/Activation/Flags.lean:280-284) requires `hnone : P.scriptFlagExceptions hash = none` and proves only the non-exception activation direction; the exception-block arm and the below-height/converse arm are not in the target, and no `cltv_flag_flow_any` exists locally. This is a proof gap, not a restriction of the Core claim, so the summary is not narrowed. Missing piece: an `hnone`-free CLTV activation theorem (and optionally the below-height converse). Open proof obligation.

### BLK-087

- claim: CHECKSEQUENCEVERIFY + LOCKTIME_VERIFY_SEQUENCE when CSV active
- core: `V:2276-2278 + 2518-2523@cce32b168`
- target: `Bitcoin.Activation.csv_flag_flow`
- missing link: The summary is true of Core: CSV activation sets both `SCRIPT_VERIFY_CHECKSEQUENCEVERIFY` in `GetBlockScriptFlags` (validation.cpp:2277-2280) and `LOCKTIME_VERIFY_SEQUENCE` for the BIP68 sequence-lock gate (validation.cpp:2477-2481). The cited `csv_flag_flow` (spec/core/Bitcoin/Activation/Flags.lean:289-293) requires `hnone` and proves only `.csv = true`; it says nothing about the separate `LOCKTIME_VERIFY_SEQUENCE` contextual flag, and the exception/below-height arms are absent. The model has the constant `LOCKTIME_VERIFY_SEQUENCE` (spec/core/Bitcoin/DataLaws/Laws.lean:74). The contextual pipeline now applies BIP68 through `checkSequenceContext` (spec/core/Bitcoin/Capstone/Block.lean:654-668) for every non-coinbase BIP68-enabled transaction, reading each spent coin from the UTXO view and the relevant parent median-time-past through `sequenceInputData` (spec/core/Bitcoin/Capstone/Context.lean:126-145). That gate is conditional on caller-supplied prevout data: `validateBlock ... (some ctx)` receives the `ChainContext` and starts from the caller's `CapState.utxo`, rather than deriving the spent outputs from the serialized block, and the context-free `replayBlock` skips BIP68 and reports `sequenceLocksChecked := false` (Capstone/Block.lean:1093,1179-1180). Missing pieces: an `hnone`-free CSV flag theorem, a CSV-active => LOCKTIME_VERIFY_SEQUENCE theorem (or a composed row claim), and a prevout-data derivation or explicit well-formedness premise tying the supplied view to the block history. Open proof obligation; the summary is kept.

## INV

### INV-022

- claim: script-level finality lock (5-byte CScriptNum; both tx-level finality AND lock satisfied)
- core: `interpreter.cpp:OP_CLTV:556–567 + CheckLockTime:1755–1788@cce32b168`
- target: `BitcoinProofs.AF.PDW68x.cltv_accept_iff`
- missing link: The summary is true of Core: OP_CHECKLOCKTIMEVERIFY reads a 5-byte CScriptNum, rejects negatives, and accepts only when CheckLockTime also holds (type agreement, n <= tx nLockTime, non-final input) (interpreter.cpp:556-567,1755-1788). The cited target cltv_accept_iff (PDW68x.lean:40-45) proves only `checkLockTimeDef env n = true <-> cltvSameType env n /\ n <= txLockTime /\ txSequence != 0xFFFFFFFF` on an already-decoded ScriptNum; it has no opcode arm. The local subclaims are real but do not compose the row: 5-byte operand width on a successful flag-on step is PDW93.stepBody_cltv_operand_width_five (PDW93b.lean:152-180); the negative reject is PDW58.cltv_negative_errors (PDW58F.lean:15-24); the flag-off BASE NOP is PDW73.stepBody_cltv_csv_noflag_nop (PDW73.lean:30-39). Still missing: one CLTV stepBody path theorem covering the opcode decode/dispatch, the stack-underflow face (interpreter.cpp:539-540), the negative branch, the flag-off NOP, and the checker verdict. Do not narrow a true Core claim for a missing branch; open proof obligation.

### INV-023

- claim: script-level relative lock
- core: `interpreter.cpp:OP_CSV:584–599 + CheckSequence:1792–1836@cce32b168`
- target: `BitcoinProofs.AF.PDW68x.csv_accept_iff`
- missing link: The summary is true of Core: OP_CHECKSEQUENCEVERIFY reads a 5-byte CScriptNum, rejects negatives, treats a disabled-flag operand as a NOP, then calls CheckSequence (version >= 2, clear disable bit, masked type agreement, masked n <= masked tx sequence) (interpreter.cpp:584-600,1792-1836). The cited target csv_accept_iff (PDW68x.lean:49-57) is transaction-side only, assumes non-negativity, and defers the disable-bit NOP to the opcode. Local subclaims are real but do not form the full path: operand width PDW93.stepBody_csv_operand_width_five (PDW93b.lean:186-216); negative reject PDW58.csv_negative_errors (PDW58F.lean:38-47); disable-flag NOP PDW60.csv_disable_flag_nop (RowsD.lean:85-99) with base/v0 arm `_base_v0` (:103-119) and CSV-off NOP3 arm csv_flag_off_nop3 (:142-158). Still missing: a single CSA opcode-path iff tying decode, negative, disable-flag NOP, checker comparison, and the stack-underflow arm together. Open proof obligation.

### INV-057

- claim: codeseparator-pos commit
- core: `interpreter.cpp:1281–1290,1058–1061@cce32b168`
- target: `Bitcoin.SigHash.findAndDeleteL_codeSep_eq`
- missing link: The summary is true of Core: OP_CODESEPARATOR records `pbegincodehash = pc` (interpreter.cpp:1058-1064), scriptCode is the slice from that position (1281-1290), and the tapscript sighash commits `codeseparator_pos` (1570-1575). The cited target findAndDeleteL_codeSep_eq (spec/core/Bitcoin/SigHash/Ops.lean:696) proves only the deletion algebra `findAndDeleteL b codeSepL = dropCsFrom b 0`. Local pieces are real but not an end-to-end commit: O07.opCodeSep_dispatch (O07.lean:348-353) records `codeSep := op.next`; O07.step_codesep_base (:355-369) proves the executed BASE step with budget increment; Defs.evalChecksigPreTapscript (Defs.lean:683-693) hands `bytes.extract codeSep bytes.size` to the checker; TPR043.extSlice_tapscript_row (PDW41/TPR043.lean:27-35) commits `codesep_pos` in the extension slice. Still missing: one theorem tying the running position through the executed separator, the extracted scriptCode, and the sighash commit. Open proof obligation.

### INV-117

- claim: reverse transition
- core: `validation.cpp:DisconnectBlock:2178–2247@cce32b168`
- target: `BitcoinProofs.AF.PDW58.undoCoins_restore_wins`
- missing link: The summary is true of Core: DisconnectBlock unwinds transactions in reverse order, checks each output against the spent coin (value/script, height, coinbase), restores inputs from undo data, and exempts the two historical BIP30 duplicate-coinbase blocks (validation.cpp:2194-2247). The cited target undoCoins_restore_wins (PDW58C.lean:48-53) proves only restore-priority for a spent coin (`coinLookup spent o = some c => undoCoins ... = some c`). Local pieces are real but not the full row: undoCoins_restore (:14-21), undoCoins_blank_added (:24-32), undoCoins_keep (:35-45), undoCoins_roundtrip (:69-74); the block layer has reverse-order replay replayUndos (Block/Params.lean:159-164), disconnectBlock zipping txs.reverse with undos.reverse (:238-244), and disconnectBlock_three (:271-284). The BIP30 disconnect pair is carried separately by BLK-099/BLK-106. Still missing: one INV-117 theorem covering output/height/coinbase match plus the BIP30 case. Open proof obligation.

### INV-130

- claim: CSV flag gate
- core: `validation.cpp:2277–2280@cce32b168`
- target: `Bitcoin.Activation.csv_flag_flow`
- missing link: The summary is true of Core: the CSV script flag is ORed in exactly when DEPLOYMENT_CSV is active at the block (validation.cpp:2277-2280, with the hash-keyed exception branch in GetBlockScriptFlags). The cited target csv_flag_flow (Flags.lean:289-294) proves only the on direction, and only under `P.scriptFlagExceptions hash = none` plus `P.csvHeight <= height`: it concludes `(getBlockScriptFlagsP P hash height).csv = true`. No `csv_flag_off` or `csv_flag_iff` exists for the hash-keyed `getBlockScriptFlagsP`. The local iff theorems are for the frozen height-only selector: FlagsCor.flags_csv_iff (FlagsCor.lean:86-90) and Interface.csv_flag_iff_deployment (TxValidation/Interface.lean:971-974) both speak about `getBlockScriptFlags height`, not `getBlockScriptFlagsP P hash height`, so they do not cover the exception-hash branch. The off half remains unproved; the Core claim is not narrowed. Open proof obligation.

## SCR

### SCR-030

- claim: combined check
- core: `interpreter.cpp:EvalScript:1232@cce32b168`
- target: `Bitcoin.Interpreter.Defs.evalScriptBytes_ok_stack_bound`
- missing link: The summary (stack + altstack combined check) is true of Core: the guard is `if (stack.size() + altstack.size() > MAX_STACK_SIZE) return SCRIPT_ERR_STACK_SIZE` after every opcode (:1231-1233). The cited `evalScriptBytes_ok_stack_bound` (Defs.lean:1482-1500) concludes only `st'.length <= MAX_STACK_SIZE` on the main stack (:1486). The combined guard is present per step (`stepChecked`, Defs.lean:1098-1103; `stepChecked_ok_bound`, :1396-1408), and `evalFrom_ok_stack_bound` (:1411-1438) also bounds only `st'.length`. No eval-level theorem bounds `st'.length + st'.alt.length`. Missing piece: `evalFrom_ok_stack_alt_bound` / `evalScriptBytes_ok_stack_alt_bound` preserving the combined invariant. Open proof obligation; claim kept, not narrowed.

### SCR-066

- claim: BAD_OPCODE when executed; unexecuted OP_VER passes
- core: `interpreter.cpp:EvalScript:1227-1228@cce32b168`
- target: `BitcoinProofs.AF.PDW67b.stepBody_opVer_unexecuted`
- missing link: The summary (BAD_OPCODE when executed; unexecuted OP_VER passes) is true of Core: OP_VER (0x62) has no switch case and hits the default BAD_OPCODE at :1227-1228; when unexecuted and outside the `[OP_IF..OP_ENDIF]` window it is skipped at :493. The cited `stepBody_opVer_unexecuted` (PDW67bF.lean:9-16) proves only the unexecuted 0x62 tapscript pass (`.ok st`). No local theorem proves the executed half for OP_VER, OP_RESERVED, RESERVED1 or RESERVED2; `Z09.Corners.lean:447-449` is the dead OP_RESERVED pass side. Missing piece: an executed `stepBody` BAD_OPCODE theorem for 0x62/0x50/0x89/0x8a (arbitrary sigversion/state). Open proof obligation; claim kept, not narrowed.

### SCR-067

- claim: each IF counts 1 opcode
- core: `interpreter.cpp:EvalScript:460-464@cce32b168`
- target: `BitcoinProofs.AF.PDW88.stepBody_if_counts_opcode`
- missing link: The summary (each IF counts one opcode) is true of Core: the BASE/WITNESS_V0 count gate increments `nOpCount` for `opcode > OP_16`, which includes both OP_IF (0x63) and OP_NOTIF (0x64) (:460-464). The cited `stepBody_if_counts_opcode` (PDW88.lean:52-64) fixes only 0x63, `ctx.sv = .base`, executed, an empty top operand and available budget, concluding `.ok` with `opCount := st.opCount + 1`. No local SCR-067 theorem covers OP_NOTIF (0x64), WITNESS_V0, non-empty operands, or the unexecuted branch. Missing piece: a general IF/NOTIF op-count theorem (both wires, all counted sigversions). Open proof obligation; claim kept, not narrowed.

### SCR-070

- claim: first-byte OP_RETURN or >10k script ⇒ never spendable
- core: `script.h:IsUnspendable:564-567@cce32b168`
- target: `BitcoinProofs.PDW9.scriptUnspendable_of_oversize`
- missing link: The summary is true of Core: `CScript::IsUnspendable()` is exactly `(size() > 0 && *begin() == OP_RETURN) || (size() > MAX_SCRIPT_SIZE)` (script.h:564-567); OP_RETURN execution returns SCRIPT_ERR_OP_RETURN (:677-680) and an oversize script fails the script-size gate before execution. The cited `scriptUnspendable_of_oversize` (Unspendable.lean:73-76) proves only the oversize classification arm. The OP_RETURN arm (Unspendable.lean:64-68) and the full iff (:83-87) exist, but they are tagged BLK-094, and no local theorem links `scriptUnspendable` to a `verifyScriptFull`/`evalScriptBytes` failure (the local consumers are disconnect/coin selection: PDW23, PDW66, PDW70). Missing piece: a theorem `scriptUnspendable s = true => VerifyScript fails` (or the per-arm OP_RETURN/oversize execution-failure link). Open proof obligation; claim kept, not narrowed.

### SCR-074

- claim: each op checks depth ⇒ INVALID_STACK_OPERATION
- core: `interpreter.cpp:705-880@cce32b168`
- target: `BitcoinProofs.AF.PDW79.stepBody_depth_check`
- missing link: The summary (each op checks depth => INVALID_STACK_OPERATION) is true of Core: the stack-op cases check `stack.size()` before popping (e.g. OP_2DROP :705-709, and the 2DROP..TUCK block :705-880). The cited `stepBody_depth_check` (PDW79.lean:51-61) fixes only `op.wire = 0x6d` (OP_2DROP), BASE, executed, budget available and `stack.length < 2`, concluding `.error .stackUnderflow`. The other PDW79 stack-underflow theorems are opcode-specific PICK/ROLL faces tagged SCR-075; there is no general per-opcode depth theorem. Missing piece: a general arity/depth theorem over the 2DROP..TUCK opcode set. Open proof obligation; claim kept, not narrowed.

### SCR-086

- claim: clamp to int32 for depth/count uses
- core: `script.h:326-333@cce32b168`
- target: `Bitcoin.Numeric.getIntClamped`
- missing link: The summary is true of Core: `CScriptNum::getint()` clamps to `[INT32_MIN, INT32_MAX]` (script.h:326-333), and Core uses it for depth/count reads such as OP_PICK/ROLL and multisig counts. The local `getIntClamped` (ScriptNum.lean:741-744) faithfully clamps, and `getIntClamped_in_range/_id/_max/_min` (:746-772) prove the clamp laws, but no interpreter site consumes it: the depth/count sites use `Nat` stack/alt lengths, and the only other uses are decide examples in `Property/Y04/ScriptNumProps.lean`. Missing piece: a model/consumer theorem linking `getIntClamped` to the OP_PICK/ROLL depth or CMS count read. Open proof obligation; claim kept, not narrowed.

## SWT

### SWT-026

- claim: accurate sigop count of the last witness item (witnessScript)
- core: `interpreter.cpp:2139-2142@cce32b168`
- target: `BitcoinProofs.AF.PDW19.witnessSigOps_p2wsh`
- missing link: The summary is true of Core: `WitnessSigOps` routes a v0-32 program to `witness.stack.back().GetSigOpCount(true)` (src/script/interpreter.cpp:2133-2145), and `CScript::GetSigOpCount(true)` walks opcodes with `GetOp` and returns the count over the valid prefix, stopping at the first decode failure (src/script/script.cpp:159-179). The local `witnessScriptSigOps` (spec/core/Bitcoin/Interpreter/SigOps.lean:176-178) now counts that prefix via `parseWirePrefix` instead of returning 0 on a parse failure, and `witnessSigOps_p2wsh` (spec/proofs/BitcoinProofs/AF/PDW19/PDW19.lean:196-208) states the v0-32 last-item count. A model gap remains: `parseWirePrefix` uses `getOp` (spec/core/Bitcoin/Script/Parser/Defs.lean:206-233), whose PUSHDATA2/PUSHDATA4 arms accept payloads larger than Core's 520-byte `MAX_SCRIPT_ELEMENT_SIZE`; Core's `GetScriptOp` rejects such a push (script.cpp:313-363), so Core stops counting at that opcode while the model continues past it. Missing piece: enforce the push-size limit in the counting parse (or use a size-bounded parser), then restate the prefix-count equality. Open proof obligation; the true Core claim is kept rather than narrowed.

## TPR

### TPR-007

- claim: exactly 1 element (post-annex) ⇒ single BIP340 sig against output key q
- core: `interpreter.cpp:1970-1975@cce32b168`
- target: `BitcoinProofs.AF.PDW25.classifySpend_one_keyPath`
- missing link: the summary is true of Core. Core takes the one-element post-annex stack, calls `checker.CheckSchnorrSignature(stack.front(), program, SigVersion::TAPROOT, execdata, serror)` against the 32-byte output key `program`, and returns success at interpreter.cpp:1970-1975. The cited target `classifySpend_one_keyPath` (PDW25.lean:148-150) proves only the spend-path classification `classifySpend [sig] = SpendPath.keyPath sig`; it does not prove BIP340 verification or the output-key `q` binding. Missing piece: a TPR-007-tagged theorem connecting the key-path classification to the Schnorr check against the output key (the `program`/`q` argument), not merely to `.keyPath sig`. The summary is left unchanged because the Core claim is true.

### TPR-071

- claim: annex included in witness serialization ⇒ weight & budget base
- core: `interpreter.cpp:1991 (whole stack serialized); consensus/validation.h:150@cce32b168`
- target: `Bitcoin.Crypto.Taproot.Program.validationWeightInit_annex_included`
- missing link: the summary is true of Core. Core computes the budget over the whole witness stack before the annex pop (interpreter.cpp:1991 vs :1961-1969), and the transaction weight adds `::GetSerializeSize(txin.scriptWitness.stack)` (consensus/validation.h:147-150), which includes the annex. The cited theorem proves strict growth of the serialized witness size: `witnessSerSize (items ++ [annex]) > witnessSerSize ((items ++ [annex]).dropLast)` under `isAnnex ... = true` (Program.lean:652-664). The size model now includes the stack-count CompactSize, and `WitnessSerialization.witnessSerSize_eq_encoder`, `validationWeightInit_eq_encoder`, and `executeWitnessScript_exact_seed` connect that size to the BIP144 encoder and the interpreter's initial budget. The remaining obligation is transaction-weight composition: no theorem states that adding the annex to the actual transaction witness changes the transaction-weight serialization by the corresponding bytes. The full weight-and-budget row remains residual until that theorem is supplied; the earlier item-only-size defect is fixed and is no longer the missing link. The summary is left unchanged because the Core claim is true; narrowing it would weaken a true Core claim merely because the model is incomplete.

## TXV

### TXV-069

- claim: all value arithmetic in i64, checked incrementally
- core: `amount.h:12–15@cce32b168`
- target: `Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_none_partial_moneyRange, Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_none_partial_i64Range, Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_none_partial_no_overflow, Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_none_i64Fold_agrees, Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_none_zero_i64Fold_agrees`
- missing link: TXV-069's summary says all value arithmetic is i64, but the model's Amount is abbrev Int (spec/core/Bitcoin/Data/Basic.lean:107), and the checked-output theorems cover only the checked output-value fold: they prove every accepted output partial sum is in i64 range and that the wrapping i64 fold agrees with the unbounded Int fold on that path. Input-value sums, the fee computation (CheckTxInputs), and the block-level fee accumulator are still unbounded Int and have no i64 fold model. The additive theorems are retained, but the row remains a residual against Core's int64 CAmount semantics; no narrowing and no theorem deletion.

