import Bitcoin.Activation.Bip9
import Bitcoin.Activation.Flags
import Bitcoin.Activation.Interface
import Bitcoin.Activation.Taproot
import Bitcoin.Block.Connect
import Bitcoin.Block.Params
import Bitcoin.Block.Sigops
import Bitcoin.Capstone.Block
import Bitcoin.Consensus.TxCheck
import Bitcoin.Conservation.Interface
import Bitcoin.Crypto.Curve.Mod
import Bitcoin.Crypto.Curve.Secp
import Bitcoin.Crypto.Schnorr.Verify
import Bitcoin.Crypto.Seam.Der
import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Crypto.Taproot.LeafDispatch
import Bitcoin.Crypto.Taproot.Program
import Bitcoin.Crypto.Taproot.Sighash
import Bitcoin.Data.Tx
import Bitcoin.DataLaws.Interface
import Bitcoin.DataLaws.Laws
import Bitcoin.Interpreter.Defs
import Bitcoin.Interpreter.Rules
import Bitcoin.Interpreter.SigOps
import Bitcoin.Invariants.RC03
import Bitcoin.Invariants.RC10
import Bitcoin.Ledger.Interface
import Bitcoin.Numeric.Interface
import Bitcoin.Numeric.ScriptNum
import Bitcoin.Script.Parser.Defs
import Bitcoin.Script.Tapscript.Delta
import Bitcoin.Serialization.Interface
import Bitcoin.SigHash.Digest
import Bitcoin.SigHash.Interface
import Bitcoin.SigHash.Ops
import Bitcoin.SigHash.Theorems
import Bitcoin.TxValidation.Full
import Bitcoin.TxValidation.Interface
import Bitcoin.TxValidation.LocktimeSigOps
import Bitcoin.TxValidation.Mempool
import Bitcoin.TxValidation.ScriptExecCache
import Bitcoin.TxValidation.SigOpsCost
import BitcoinProofs.AF.PDW100.PDW100
import BitcoinProofs.AF.PDW12.PDW12
import BitcoinProofs.AF.PDW13.PDW13
import BitcoinProofs.AF.PDW14.B020
import BitcoinProofs.AF.PDW14.B069
import BitcoinProofs.AF.PDW14.B089B104
import BitcoinProofs.AF.PDW16.PDW16
import BitcoinProofs.AF.PDW18.PDW18
import BitcoinProofs.AF.PDW18.SCR042
import BitcoinProofs.AF.PDW19.PDW19
import BitcoinProofs.AF.PDW20.PDW20
import BitcoinProofs.AF.PDW21.PDW21
import BitcoinProofs.AF.PDW22.PDW22
import BitcoinProofs.AF.PDW23.PDW23
import BitcoinProofs.AF.PDW24.PDW24
import BitcoinProofs.AF.PDW25.PDW25
import BitcoinProofs.AF.PDW27.BLK004INV122
import BitcoinProofs.AF.PDW27.SCR015INV133
import BitcoinProofs.AF.PDW28.PDW28
import BitcoinProofs.AF.PDW29.PDW29
import BitcoinProofs.AF.PDW29.PDW29Sigops
import BitcoinProofs.AF.PDW3.INV100TimewarpCor
import BitcoinProofs.AF.PDW3.INV101TimeNotTooNewCor
import BitcoinProofs.AF.PDW30.PDW30
import BitcoinProofs.AF.PDW30.PDW30b
import BitcoinProofs.AF.PDW31.PDW31
import BitcoinProofs.AF.PDW32.PDW32
import BitcoinProofs.AF.PDW33.PDW33
import BitcoinProofs.AF.PDW33.PDW33b
import BitcoinProofs.AF.PDW33b.PDW33b
import BitcoinProofs.AF.PDW35.PDW35
import BitcoinProofs.AF.PDW36.PDW36
import BitcoinProofs.AF.PDW37.PDW37
import BitcoinProofs.AF.PDW39b.PDW39b
import BitcoinProofs.AF.PDW40.PDW40
import BitcoinProofs.AF.PDW41.TPR004
import BitcoinProofs.AF.PDW41.TPR006
import BitcoinProofs.AF.PDW41.TPR010
import BitcoinProofs.AF.PDW41.TPR022
import BitcoinProofs.AF.PDW41.TPR043
import BitcoinProofs.AF.PDW41b.PDW41b
import BitcoinProofs.AF.PDW42.PDW42
import BitcoinProofs.AF.PDW42.PDW42B
import BitcoinProofs.AF.PDW43.PDW43
import BitcoinProofs.AF.PDW43b.PDW43b
import BitcoinProofs.AF.PDW44.PDW44
import BitcoinProofs.AF.PDW45.PDW45
import BitcoinProofs.AF.PDW46.PDW46
import BitcoinProofs.AF.PDW46b.PDW46b
import BitcoinProofs.AF.PDW46b.PDW46bB
import BitcoinProofs.AF.PDW47.PDW47
import BitcoinProofs.AF.PDW48.PDW48Finality
import BitcoinProofs.AF.PDW48.PDW48Locktime
import BitcoinProofs.AF.PDW49.PDW49
import BitcoinProofs.AF.PDW50.PDW50
import BitcoinProofs.AF.PDW51.PDW51
import BitcoinProofs.AF.PDW52.PDW52
import BitcoinProofs.AF.PDW53.PDW53
import BitcoinProofs.AF.PDW55.PDW55
import BitcoinProofs.AF.PDW55.PDW55b
import BitcoinProofs.AF.PDW56.PDW56
import BitcoinProofs.AF.PDW57b.PDW57b
import BitcoinProofs.AF.PDW58.PDW58
import BitcoinProofs.AF.PDW58.PDW58A
import BitcoinProofs.AF.PDW58.PDW58B
import BitcoinProofs.AF.PDW58.PDW58C
import BitcoinProofs.AF.PDW58.PDW58F
import BitcoinProofs.AF.PDW59.PDW59b
import BitcoinProofs.AF.PDW59.PDW59c
import BitcoinProofs.AF.PDW59.PDW59d
import BitcoinProofs.AF.PDW62.PDW62
import BitcoinProofs.AF.PDW62b.PDW62b
import BitcoinProofs.AF.PDW63.PDW63
import BitcoinProofs.AF.PDW63b.PDW63b
import BitcoinProofs.AF.PDW65.PDW65
import BitcoinProofs.AF.PDW66.PDW66
import BitcoinProofs.AF.PDW67.PDW67
import BitcoinProofs.AF.PDW67b.PDW67bC2
import BitcoinProofs.AF.PDW67b.PDW67bC3
import BitcoinProofs.AF.PDW67b.PDW67bD
import BitcoinProofs.AF.PDW67b.PDW67bE
import BitcoinProofs.AF.PDW67b.PDW67bF
import BitcoinProofs.AF.PDW68.PDW68
import BitcoinProofs.AF.PDW68x.PDW68x
import BitcoinProofs.AF.PDW68x.PDW68xB
import BitcoinProofs.AF.PDW69.PDW69
import BitcoinProofs.AF.PDW70.PDW70
import BitcoinProofs.AF.PDW70.PDW70B
import BitcoinProofs.AF.PDW71.PDW71
import BitcoinProofs.AF.PDW72.PDW72
import BitcoinProofs.AF.PDW73.PDW73
import BitcoinProofs.AF.PDW74.PDW74
import BitcoinProofs.AF.PDW75.PDW75
import BitcoinProofs.AF.PDW76.PDW76
import BitcoinProofs.AF.PDW76.PDW76b
import BitcoinProofs.AF.PDW78.PDW78
import BitcoinProofs.AF.PDW79.PDW79
import BitcoinProofs.AF.PDW8.Blk063Cor
import BitcoinProofs.AF.PDW8.Blk064Cor
import BitcoinProofs.AF.PDW8.Blk120Cor
import BitcoinProofs.AF.PDW8.Blk122Cor
import BitcoinProofs.AF.PDW8.Blk126Cor
import BitcoinProofs.AF.PDW80.PDW80A
import BitcoinProofs.AF.PDW80.PDW80B
import BitcoinProofs.AF.PDW81.PDW81
import BitcoinProofs.AF.PDW82.PDW82
import BitcoinProofs.AF.PDW82.PDW82b
import BitcoinProofs.AF.PDW82.PDW82c
import BitcoinProofs.AF.PDW83.PDW83
import BitcoinProofs.AF.PDW84.PDW84c
import BitcoinProofs.AF.PDW84.PDW84e
import BitcoinProofs.AF.PDW85.PDW85
import BitcoinProofs.AF.PDW85.PDW85b
import BitcoinProofs.AF.PDW86.PDW86
import BitcoinProofs.AF.PDW87.PDW87
import BitcoinProofs.AF.PDW88.PDW88
import BitcoinProofs.AF.PDW88.PDW88Act
import BitcoinProofs.AF.PDW89.PDW89
import BitcoinProofs.AF.PDW89.PDW89b
import BitcoinProofs.AF.PDW89.PDW89c
import BitcoinProofs.AF.PDW90.PDW90
import BitcoinProofs.AF.PDW90.PDW90b
import BitcoinProofs.AF.PDW91.PDW91
import BitcoinProofs.AF.PDW93.PDW93
import BitcoinProofs.AF.PDW93.PDW93b
import BitcoinProofs.AF.PDW95.PDW95d
import BitcoinProofs.AF.PDW95.PDW95e
import BitcoinProofs.AF.PDW95.PDW95f
import BitcoinProofs.AF.PDW97.PDW97
import BitcoinProofs.AF.PDW98.PDW98
import BitcoinProofs.Activation.PDW5
import BitcoinProofs.Crypto.CurveZMod
import BitcoinProofs.PDW9.MoneyRange
import BitcoinProofs.PDW9.Unspendable
import BitcoinProofs.Theorems.BlockCor
import BitcoinProofs.Theorems.CapstoneBip30Loop
import BitcoinProofs.Theorems.CapstonePowCor
import BitcoinProofs.Theorems.CapstoneWeightCor

/-!
# axiom_probe_rows — ROWAXIOM: `#print axioms` over every distinct
`lean_target` of a `proven` row in `spec/db/rules.yaml`.

Generated by the ROWAXIOM audit lane from the row database and the
source-derived declaration map. Run from `spec/proofs`:

    lake env lean ../scripts/axiom_probe_rows.lean

Targets are printed with their name as written in rules.yaml. Where
the written name carries a stale module-path segment (e.g.
`Bitcoin.Interpreter.Defs.foo` for the real
`Bitcoin.Interpreter.foo`), the actual declaration is printed too,
marked `-- drift`. The audit file records both.

Two declaring modules do not build at the audited HEAD:
`BitcoinProofs.AF.PDW34.PDW34` and
`BitcoinProofs.AF.PDW69TxCheck.PDW69TxCheck`. Importing either aborts
the whole probe (missing .olean), so they are intentionally not
imported; their 10 target names are still printed below and the
resulting unknown-constant errors are recorded as `build-failed` in
`spec/db/axiom-audit-rows.txt`. Four further `BitcoinProofs.AF.PDW38`
targets have no declaration at HEAD (the module was deleted) and are
likewise `missing`.
-/

-- target BitcoinProofs.AF.PDW22.checkTransaction_vin_empty_reject
#print axioms BitcoinProofs.AF.PDW22.checkTransaction_vin_empty_reject

-- target BitcoinProofs.AF.PDW22.checkTransaction_vout_empty_reject
#print axioms BitcoinProofs.AF.PDW22.checkTransaction_vout_empty_reject

-- target Bitcoin.Consensus.TxCheck.checkTransaction
#print axioms Bitcoin.Consensus.TxCheck.checkTransaction
-- drift Bitcoin.Consensus.TxCheck.checkTransaction -> Bitcoin.Consensus.checkTransaction
#print axioms Bitcoin.Consensus.checkTransaction

-- target BitcoinProofs.AF.PDW22.checkTransaction_ok_outputs_nonneg
#print axioms BitcoinProofs.AF.PDW22.checkTransaction_ok_outputs_nonneg

-- target BitcoinProofs.AF.PDW22.checkTransaction_ok_outputs_le_MAX_MONEY
#print axioms BitcoinProofs.AF.PDW22.checkTransaction_ok_outputs_le_MAX_MONEY

-- target Bitcoin.TxValidation.checkTransaction_ok_no_dup_prevouts
#print axioms Bitcoin.TxValidation.checkTransaction_ok_no_dup_prevouts

-- target BitcoinProofs.AF.PDW69TxCheck.checkTransaction_ok_cbLength
#print axioms BitcoinProofs.AF.PDW69TxCheck.checkTransaction_ok_cbLength

-- target BitcoinProofs.AF.PDW22.checkTransaction_ok_no_null_prevout
#print axioms BitcoinProofs.AF.PDW22.checkTransaction_ok_no_null_prevout

-- target Bitcoin.Data.Tx.isCoinBase
#print axioms Bitcoin.Data.Tx.isCoinBase

-- target Bitcoin.DataLaws.final_locktime_zero
#print axioms Bitcoin.DataLaws.final_locktime_zero

-- target Bitcoin.DataLaws.final_height_domain
#print axioms Bitcoin.DataLaws.final_height_domain

-- target Bitcoin.DataLaws.final_time_domain
#print axioms Bitcoin.DataLaws.final_time_domain

-- target Bitcoin.DataLaws.final_sequence_final
#print axioms Bitcoin.DataLaws.final_sequence_final

-- target BitcoinProofs.AF.PDW48.bip113_cutoff_finality_sandwich
#print axioms BitcoinProofs.AF.PDW48.bip113_cutoff_finality_sandwich

-- target BitcoinProofs.AF.PDW48.blockAllFinal_mono_cutoff
#print axioms BitcoinProofs.AF.PDW48.blockAllFinal_mono_cutoff

-- target BitcoinProofs.AF.PDW48.bip68Enabled_row_iff
#print axioms BitcoinProofs.AF.PDW48.bip68Enabled_row_iff

-- target BitcoinProofs.AF.PDW20.seqIsDisabled_bit31_iff
#print axioms BitcoinProofs.AF.PDW20.seqIsDisabled_bit31_iff

-- target BitcoinProofs.AF.PDW63.seqIsTimeBased_row
#print axioms BitcoinProofs.AF.PDW63.seqIsTimeBased_row

-- target BitcoinProofs.AF.PDW48.seqRelative_height_lock
#print axioms BitcoinProofs.AF.PDW48.seqRelative_height_lock

-- target BitcoinProofs.AF.PDW48.sequenceLocksOk_enabled_iff
#print axioms BitcoinProofs.AF.PDW48.sequenceLocksOk_enabled_iff

-- target BitcoinProofs.AF.PDW68x.cltv_accept_iff
#print axioms BitcoinProofs.AF.PDW68x.cltv_accept_iff

-- target BitcoinProofs.AF.PDW68x.csv_accept_iff
#print axioms BitcoinProofs.AF.PDW68x.csv_accept_iff

-- target BitcoinProofs.PDW9.moneyRange_spec
#print axioms BitcoinProofs.PDW9.moneyRange_spec

-- target Bitcoin.Invariants.RC03.inputValuesLoop_ok_perCoinMoneyRange
#print axioms Bitcoin.Invariants.RC03.inputValuesLoop_ok_perCoinMoneyRange

-- target Bitcoin.Invariants.RC03.inputValuesLoop_ok_runningSumInRange
#print axioms Bitcoin.Invariants.RC03.inputValuesLoop_ok_runningSumInRange

-- target Bitcoin.Ledger.applyTxStepU_missing_or_spent
#print axioms Bitcoin.Ledger.applyTxStepU_missing_or_spent

-- target Bitcoin.Ledger.maturity_boundary
#print axioms Bitcoin.Ledger.maturity_boundary

-- target Bitcoin.Invariants.RC03.checkTxInputs_ok_valueIn_ge_valueOut
#print axioms Bitcoin.Invariants.RC03.checkTxInputs_ok_valueIn_ge_valueOut

-- target Bitcoin.Conservation.single_tx_fee_in_range
#print axioms Bitcoin.Conservation.single_tx_fee_in_range

-- target Bitcoin.Invariants.RC03.connectChecks_ok_feeAccumInRange
#print axioms Bitcoin.Invariants.RC03.connectChecks_ok_feeAccumInRange

-- target Bitcoin.Invariants.RC03.connectChecks_ok_noInflation
#print axioms Bitcoin.Invariants.RC03.connectChecks_ok_noInflation

-- target Bitcoin.Conservation.blockSubsidy
#print axioms Bitcoin.Conservation.blockSubsidy

-- target Bitcoin.Invariants.RC03.coin_constants
#print axioms Bitcoin.Invariants.RC03.coin_constants

-- target Bitcoin.Block.Sigops.legacySigOpCountTx
#print axioms Bitcoin.Block.Sigops.legacySigOpCountTx

-- target Bitcoin.Invariants.RC03.p2shSigOpCount_zero_of_noP2SH
#print axioms Bitcoin.Invariants.RC03.p2shSigOpCount_zero_of_noP2SH

-- target BitcoinProofs.AF.PDW44.witnessSigOps_v0_20
#print axioms BitcoinProofs.AF.PDW44.witnessSigOps_v0_20

-- target Bitcoin.Interpreter.SigOps.sigOpCost
#print axioms Bitcoin.Interpreter.SigOps.sigOpCost

-- target Bitcoin.Interpreter.SigOps.blockSigOpCostOk
#print axioms Bitcoin.Interpreter.SigOps.blockSigOpCostOk

-- target BitcoinProofs.AF.PDW74.legacySigOpBudgetOk_iff
#print axioms BitcoinProofs.AF.PDW74.legacySigOpBudgetOk_iff

-- target Bitcoin.Interpreter.Defs.evalScriptBytes
#print axioms Bitcoin.Interpreter.Defs.evalScriptBytes
-- drift Bitcoin.Interpreter.Defs.evalScriptBytes -> Bitcoin.Interpreter.evalScriptBytes
#print axioms Bitcoin.Interpreter.evalScriptBytes

-- target BitcoinProofs.AF.PDW67.pushSize_row
#print axioms BitcoinProofs.AF.PDW67.pushSize_row

-- target BitcoinProofs.AF.PDW88.stepBody_opCount_gate
#print axioms BitcoinProofs.AF.PDW88.stepBody_opCount_gate

-- target BitcoinProofs.AF.PDW39b.stepChecked_stack_alt_bound
#print axioms BitcoinProofs.AF.PDW39b.stepChecked_stack_alt_bound

-- target Bitcoin.Interpreter.Defs.stepBody
#print axioms Bitcoin.Interpreter.Defs.stepBody
-- drift Bitcoin.Interpreter.Defs.stepBody -> Bitcoin.Interpreter.stepBody
#print axioms Bitcoin.Interpreter.stepBody

-- target BitcoinProofs.AF.PDW81.checkMinimalPush_iff
#print axioms BitcoinProofs.AF.PDW81.checkMinimalPush_iff

-- target BitcoinProofs.AF.PDW39b.evalFrom_ok_vf_nil
#print axioms BitcoinProofs.AF.PDW39b.evalFrom_ok_vf_nil

-- target BitcoinProofs.AF.PDW67.verifyScriptFull_evalFalse_row
#print axioms BitcoinProofs.AF.PDW67.verifyScriptFull_evalFalse_row

-- target BitcoinProofs.AF.PDW80.inv049_pubkey_limit
#print axioms BitcoinProofs.AF.PDW80.inv049_pubkey_limit

-- target BitcoinProofs.AF.PDW69.checkMultiSig_nulldummy_row
#print axioms BitcoinProofs.AF.PDW69.checkMultiSig_nulldummy_row

-- target BitcoinProofs.AF.PDW18.cmsCleanup_nullFail_fires
#print axioms BitcoinProofs.AF.PDW18.cmsCleanup_nullFail_fires

-- target Bitcoin.Crypto.Seam.Der.checkSignatureEncoding_dersig_iff
#print axioms Bitcoin.Crypto.Seam.Der.checkSignatureEncoding_dersig_iff

-- target BitcoinProofs.AF.PDW81.checkLowS_iff
#print axioms BitcoinProofs.AF.PDW81.checkLowS_iff

-- target BitcoinProofs.AF.PDW81.checkPubKeyEncoding_none_iff
#print axioms BitcoinProofs.AF.PDW81.checkPubKeyEncoding_none_iff

-- target Bitcoin.SigHash.htBase_cover
#print axioms Bitcoin.SigHash.htBase_cover

-- target BitcoinProofs.AF.PDW59.findAndDelete_none_unchanged
#print axioms BitcoinProofs.AF.PDW59.findAndDelete_none_unchanged

-- target Bitcoin.SigHash.findAndDeleteL_codeSep_eq
#print axioms Bitcoin.SigHash.findAndDeleteL_codeSep_eq

-- target BitcoinProofs.AF.PDW93.decodeNum_size_le
#print axioms BitcoinProofs.AF.PDW93.decodeNum_size_le

-- target BitcoinProofs.AF.PDW88.stepBody_tapscript_minimalif_reject
#print axioms BitcoinProofs.AF.PDW88.stepBody_tapscript_minimalif_reject

-- target BitcoinProofs.AF.PDW73.checksigAddStep_ok
#print axioms BitcoinProofs.AF.PDW73.checksigAddStep_ok

-- target Bitcoin.Script.Tapscript.executeWitnessScript_success_total
#print axioms Bitcoin.Script.Tapscript.executeWitnessScript_success_total

-- target Bitcoin.Script.Tapscript.checkMultiSig_tapscript_fails
#print axioms Bitcoin.Script.Tapscript.checkMultiSig_tapscript_fails

-- target BitcoinProofs.AF.PDW59.disabledWire_iff
#print axioms BitcoinProofs.AF.PDW59.disabledWire_iff

-- target BitcoinProofs.AF.PDW59.verifyScriptFull_scriptSig_error
#print axioms BitcoinProofs.AF.PDW59.verifyScriptFull_scriptSig_error

-- target BitcoinProofs.AF.PDW62b.verifyScriptFull_sigPushOnly_nonpush_fail
#print axioms BitcoinProofs.AF.PDW62b.verifyScriptFull_sigPushOnly_nonpush_fail

-- target Bitcoin.Interpreter.p2shInner
#print axioms Bitcoin.Interpreter.p2shInner

-- target BitcoinProofs.AF.PDW52.verifyWitnessProgram_v0_wrongLength
#print axioms BitcoinProofs.AF.PDW52.verifyWitnessProgram_v0_wrongLength

-- target BitcoinProofs.AF.PDW52.witnessMalleated_bare
#print axioms BitcoinProofs.AF.PDW52.witnessMalleated_bare

-- target BitcoinProofs.AF.PDW52.p2shInner_witnessMalleatedP2SH
#print axioms BitcoinProofs.AF.PDW52.p2shInner_witnessMalleatedP2SH

-- target BitcoinProofs.AF.PDW52.verifyWitnessProgram_v1_upgradable
#print axioms BitcoinProofs.AF.PDW52.verifyWitnessProgram_v1_upgradable

-- target Bitcoin.SigHash.bip143MsgL_determined
#print axioms Bitcoin.SigHash.bip143MsgL_determined

-- target Bitcoin.Interpreter.verifyWitnessProgram_keypath
#print axioms Bitcoin.Interpreter.verifyWitnessProgram_keypath

-- target BitcoinProofs.AF.PDW58.tapleafCommitment_singleLeaf_row
#print axioms BitcoinProofs.AF.PDW58.tapleafCommitment_singleLeaf_row

-- target BitcoinProofs.AF.PDW58.tapleafCommitment_short_none
#print axioms BitcoinProofs.AF.PDW58.tapleafCommitment_short_none

-- target BitcoinProofs.AF.PDW42B.isTapscriptLeaf_face
#print axioms BitcoinProofs.AF.PDW42B.isTapscriptLeaf_face

-- target Bitcoin.Interpreter.Defs.verifyWitnessProgram
#print axioms Bitcoin.Interpreter.Defs.verifyWitnessProgram
-- drift Bitcoin.Interpreter.Defs.verifyWitnessProgram -> Bitcoin.Interpreter.verifyWitnessProgram
#print axioms Bitcoin.Interpreter.verifyWitnessProgram

-- target BitcoinProofs.AF.PDW52.witnessUnexpected_nonWitness
#print axioms BitcoinProofs.AF.PDW52.witnessUnexpected_nonWitness

-- target Bitcoin.SigHash.signatureHashLegacyImpl
#print axioms Bitcoin.SigHash.signatureHashLegacyImpl

-- target BitcoinProofs.AF.PDW55.checkBlockTxs_none_iff_row
#print axioms BitcoinProofs.AF.PDW55.checkBlockTxs_none_iff_row

-- target BitcoinProofs.AF.PDW70.signetBlockOk_skip_row
#print axioms BitcoinProofs.AF.PDW70.signetBlockOk_skip_row

-- target BitcoinProofs.AF.PDW66.witnessCommitmentOutput_some_iff
#print axioms BitcoinProofs.AF.PDW66.witnessCommitmentOutput_some_iff

-- target BitcoinProofs.AF.PDW66.witnessCommitmentOutput_shape
#print axioms BitcoinProofs.AF.PDW66.witnessCommitmentOutput_shape

-- target BitcoinProofs.AF.PDW41b.commitmentNonceOk_head_32
#print axioms BitcoinProofs.AF.PDW41b.commitmentNonceOk_head_32

-- target BitcoinProofs.AF.PDW55.witnessCommitmentMatch_zeroNonce_row
#print axioms BitcoinProofs.AF.PDW55.witnessCommitmentMatch_zeroNonce_row

-- target BitcoinProofs.AF.PDW43b.commitmentGate_true_iff
#print axioms BitcoinProofs.AF.PDW43b.commitmentGate_true_iff

-- target BitcoinProofs.AF.PDW76.witnessLeaves_cons
#print axioms BitcoinProofs.AF.PDW76.witnessLeaves_cons

-- target BitcoinProofs.AF.PDW51.weightOk_iff
#print axioms BitcoinProofs.AF.PDW51.weightOk_iff

-- target BitcoinProofs.AF.PDW55B.blockBitsOk_badDiffbits_row
#print axioms BitcoinProofs.AF.PDW55B.blockBitsOk_badDiffbits_row

-- target BitcoinProofs.AF.PDW55B.retarget_boundary_row
#print axioms BitcoinProofs.AF.PDW55B.retarget_boundary_row

-- target BitcoinProofs.AF.PDW55B.clampedTimespan_bounds_window_row
#print axioms BitcoinProofs.AF.PDW55B.clampedTimespan_bounds_window_row

-- target BitcoinProofs.AF.PDW38.calculateNextWorkRequired_target_mid
#print axioms BitcoinProofs.AF.PDW38.calculateNextWorkRequired_target_mid

-- target BitcoinProofs.AF.PDW46.permittedDifficultyTransition_nonboundary
#print axioms BitcoinProofs.AF.PDW46.permittedDifficultyTransition_nonboundary

-- target BitcoinProofs.AF.PDW71.timeNotTooOld_row
#print axioms BitcoinProofs.AF.PDW71.timeNotTooOld_row

-- target BitcoinProofs.AF.PDW3.timewarpOk_reject
#print axioms BitcoinProofs.AF.PDW3.timewarpOk_reject

-- target BitcoinProofs.AF.PDW3.timeNotTooNew_le
#print axioms BitcoinProofs.AF.PDW3.timeNotTooNew_le

-- target BitcoinProofs.AF.PDW32.versionOk_row_iff
#print axioms BitcoinProofs.AF.PDW32.versionOk_row_iff

-- target BitcoinProofs.AF.PDW66.bip34Ok_active_eq
#print axioms BitcoinProofs.AF.PDW66.bip34Ok_active_eq

-- target BitcoinProofs.AF.PDW66.bip34Ok_below_height
#print axioms BitcoinProofs.AF.PDW66.bip34Ok_below_height

-- target BitcoinProofs.AF.PDW71.bip30Collision_row
#print axioms BitcoinProofs.AF.PDW71.bip30Collision_row

-- target BitcoinProofs.AF.PDW71.bip30DisconnectRelaxed_row
#print axioms BitcoinProofs.AF.PDW71.bip30DisconnectRelaxed_row

-- target BitcoinProofs.AF.PDW71.bip30OptimizationWindow_row
#print axioms BitcoinProofs.AF.PDW71.bip30OptimizationWindow_row

-- target BitcoinProofs.AF.PDW49.connectGenesis_hash_face
#print axioms BitcoinProofs.AF.PDW49.connectGenesis_hash_face

-- target BitcoinProofs.AF.PDW53.blockSequenceLocksOk_gate_off
#print axioms BitcoinProofs.AF.PDW53.blockSequenceLocksOk_gate_off

-- target BitcoinProofs.AF.PDW20.chainLinkOk_iff
#print axioms BitcoinProofs.AF.PDW20.chainLinkOk_iff

-- target Bitcoin.Ledger.updateCoins_spend_gone
#print axioms Bitcoin.Ledger.updateCoins_spend_gone

-- target Bitcoin.Ledger.updateCoins_insert_isSome
#print axioms Bitcoin.Ledger.updateCoins_insert_isSome

-- target Bitcoin.Ledger.addedCoins_lookup_none_of_unspendable
#print axioms Bitcoin.Ledger.addedCoins_lookup_none_of_unspendable

-- target Bitcoin.Ledger.updateCoins_spend_recreate
#print axioms Bitcoin.Ledger.updateCoins_spend_recreate

-- target BitcoinProofs.AF.PDW18.isSpent_true_iff_none
#print axioms BitcoinProofs.AF.PDW18.isSpent_true_iff_none

-- target BitcoinProofs.AF.PDW20.coinMeta_roundtrip
#print axioms BitcoinProofs.AF.PDW20.coinMeta_roundtrip

-- target Bitcoin.Ledger.updateCoins_undo
#print axioms Bitcoin.Ledger.updateCoins_undo

-- target BitcoinProofs.AF.PDW58.undoCoins_restore_wins
#print axioms BitcoinProofs.AF.PDW58.undoCoins_restore_wins

-- target BitcoinProofs.AF.PDW21.sentinel_ne_real_height
#print axioms BitcoinProofs.AF.PDW21.sentinel_ne_real_height

-- target BitcoinProofs.AF.PDW21.muhashSet_split
#print axioms BitcoinProofs.AF.PDW21.muhashSet_split

-- target BitcoinProofs.AF.PDW21.setBestBlock_coins'
#print axioms BitcoinProofs.AF.PDW21.setBestBlock_coins'

-- target BitcoinProofs.AF.PDW21.defined_started
#print axioms BitcoinProofs.AF.PDW21.defined_started

-- target BitcoinProofs.AF.PDW27.versionBitsSignals_iff
#print axioms BitcoinProofs.AF.PDW27.versionBitsSignals_iff

-- target Bitcoin.Activation.bip9_threshold_locks_in
#print axioms Bitcoin.Activation.bip9_threshold_locks_in

-- target Bitcoin.Activation.bip9_timeout_fails
#print axioms Bitcoin.Activation.bip9_timeout_fails

-- target Bitcoin.Activation.bip9_min_activation
#print axioms Bitcoin.Activation.bip9_min_activation

-- target BitcoinProofs.AF.PDW21.bip9State_eq'
#print axioms BitcoinProofs.AF.PDW21.bip9State_eq'

-- target Bitcoin.Activation.buried_heights_mainnet
#print axioms Bitcoin.Activation.buried_heights_mainnet

-- target Bitcoin.Activation.dersig_flag_flow
#print axioms Bitcoin.Activation.dersig_flag_flow

-- target Bitcoin.Activation.cltv_flag_flow
#print axioms Bitcoin.Activation.cltv_flag_flow

-- target BitcoinProofs.Activation.PDW5.cltv_flag_off
#print axioms BitcoinProofs.Activation.PDW5.cltv_flag_off

-- target Bitcoin.Activation.csv_flag_flow
#print axioms Bitcoin.Activation.csv_flag_flow

-- target Bitcoin.Activation.nulldummy_flag_flow
#print axioms Bitcoin.Activation.nulldummy_flag_flow

-- target Bitcoin.Activation.base_flags_p2sh_witness_taproot
#print axioms Bitcoin.Activation.base_flags_p2sh_witness_taproot

-- target BitcoinProofs.AF.PDW27.mainnetExceptionMap_fail_closed
#print axioms BitcoinProofs.AF.PDW27.mainnetExceptionMap_fail_closed

-- target BitcoinProofs.AF.PDW58.bip113Cutoff_mtp_of_active
#print axioms BitcoinProofs.AF.PDW58.bip113Cutoff_mtp_of_active

-- target BitcoinProofs.AF.PDW57b.bip34Ok_pre
#print axioms BitcoinProofs.AF.PDW57b.bip34Ok_pre

-- target BitcoinProofs.AF.PDW43b.commitmentGate_eq_if
#print axioms BitcoinProofs.AF.PDW43b.commitmentGate_eq_if

-- target BitcoinProofs.AF.PDW88.deploymentActiveAt_iff
#print axioms BitcoinProofs.AF.PDW88.deploymentActiveAt_iff

-- target BitcoinProofs.AF.PDW66.calculateNextWorkRequired_noRetarget
#print axioms BitcoinProofs.AF.PDW66.calculateNextWorkRequired_noRetarget

-- target BitcoinProofs.AF.PDW66.calculateNextWorkRequired_bip94_lastBits_irrel
#print axioms BitcoinProofs.AF.PDW66.calculateNextWorkRequired_bip94_lastBits_irrel

-- target BitcoinProofs.AF.PDW24.mostWork?_pair_maximality
#print axioms BitcoinProofs.AF.PDW24.mostWork?_pair_maximality

-- target BitcoinProofs.AF.PDW24.workOf_pos_of_inRange
#print axioms BitcoinProofs.AF.PDW24.workOf_pos_of_inRange

-- target BitcoinProofs.AF.PDW29.proofEquivalentWork_row_vector
#print axioms BitcoinProofs.AF.PDW29.proofEquivalentWork_row_vector

-- target BitcoinProofs.AF.PDW29.prunedCandidates_descendant
#print axioms BitcoinProofs.AF.PDW29.prunedCandidates_descendant

-- target BitcoinProofs.AF.PDW29.submitVerdict_cached_iff
#print axioms BitcoinProofs.AF.PDW29.submitVerdict_cached_iff

-- target BitcoinProofs.AF.PDW49.prevNotFailed_iff
#print axioms BitcoinProofs.AF.PDW49.prevNotFailed_iff

-- target BitcoinProofs.AF.PDW49.minChainWorkOk_iff
#print axioms BitcoinProofs.AF.PDW49.minChainWorkOk_iff

-- target BitcoinProofs.AF.PDW63.assumevalidSkipped_none_row
#print axioms BitcoinProofs.AF.PDW63.assumevalidSkipped_none_row

-- target BitcoinProofs.AF.PDW57b.nMinimumChainWorkMainnet_row
#print axioms BitcoinProofs.AF.PDW57b.nMinimumChainWorkMainnet_row

-- target BitcoinProofs.AF.PDW90.verifyScriptFull_sequential
#print axioms BitcoinProofs.AF.PDW90.verifyScriptFull_sequential

-- target BitcoinProofs.AF.PDW73.verifyScriptFull_ok_base_stack
#print axioms BitcoinProofs.AF.PDW73.verifyScriptFull_ok_base_stack

-- target BitcoinProofs.AF.PDW39b.evalFrom_nil_ok
#print axioms BitcoinProofs.AF.PDW39b.evalFrom_nil_ok

-- target BitcoinProofs.AF.PDW90.verifyScriptFull_empty_spk
#print axioms BitcoinProofs.AF.PDW90.verifyScriptFull_empty_spk

-- target BitcoinProofs.AF.PDW62.p2shInner_reeval_stackCopy
#print axioms BitcoinProofs.AF.PDW62.p2shInner_reeval_stackCopy

-- target BitcoinProofs.AF.PDW62.p2shInner_nonpush_fail
#print axioms BitcoinProofs.AF.PDW62.p2shInner_nonpush_fail

-- target BitcoinProofs.AF.PDW62.p2shInner_stack_snapshot
#print axioms BitcoinProofs.AF.PDW62.p2shInner_stack_snapshot

-- target BitcoinProofs.AF.PDW90.verifyScriptFull_cleanstack_fails
#print axioms BitcoinProofs.AF.PDW90.verifyScriptFull_cleanstack_fails

-- target BitcoinProofs.AF.PDW33.flagsComboOk_consensus_row
#print axioms BitcoinProofs.AF.PDW33.flagsComboOk_consensus_row

-- target Bitcoin.Interpreter.Defs.verifyScriptFull
#print axioms Bitcoin.Interpreter.Defs.verifyScriptFull
-- drift Bitcoin.Interpreter.Defs.verifyScriptFull -> Bitcoin.Interpreter.verifyScriptFull
#print axioms Bitcoin.Interpreter.verifyScriptFull

-- target BitcoinProofs.AF.PDW62.verifyScriptFull_native_witness_malleated
#print axioms BitcoinProofs.AF.PDW62.verifyScriptFull_native_witness_malleated

-- target BitcoinProofs.AF.PDW62.p2shInner_witness_malleated
#print axioms BitcoinProofs.AF.PDW62.p2shInner_witness_malleated

-- target BitcoinProofs.AF.PDW90.verifyScriptFull_witness_unexpected
#print axioms BitcoinProofs.AF.PDW90.verifyScriptFull_witness_unexpected

-- target BitcoinProofs.AF.PDW36.flagsComboOk_iff
#print axioms BitcoinProofs.AF.PDW36.flagsComboOk_iff

-- target BitcoinProofs.AF.PDW27.getBlockScriptFlagsP_eq
#print axioms BitcoinProofs.AF.PDW27.getBlockScriptFlagsP_eq

-- target Bitcoin.Activation.flags_bip16_exception
#print axioms Bitcoin.Activation.flags_bip16_exception

-- target BitcoinProofs.AF.PDW62b.verifyScriptFull_first_eval_fail
#print axioms BitcoinProofs.AF.PDW62b.verifyScriptFull_first_eval_fail

-- target BitcoinProofs.AF.PDW57b.evalScriptBytes_oversize
#print axioms BitcoinProofs.AF.PDW57b.evalScriptBytes_oversize

-- target BitcoinProofs.AF.PDW39b.evalScriptBytes_tapscript_no_size_guard
#print axioms BitcoinProofs.AF.PDW39b.evalScriptBytes_tapscript_no_size_guard

-- target BitcoinProofs.AF.PDW73.stepBody_opCount_reject
#print axioms BitcoinProofs.AF.PDW73.stepBody_opCount_reject

-- target BitcoinProofs.AF.PDW67b.executeWitnessScript_item_size
#print axioms BitcoinProofs.AF.PDW67b.executeWitnessScript_item_size

-- target BitcoinProofs.AF.PDW80.scr022_budget_exceeded
#print axioms BitcoinProofs.AF.PDW80.scr022_budget_exceeded

-- target BitcoinProofs.AF.PDW85.stepBody_unexecuted_if_counts
#print axioms BitcoinProofs.AF.PDW85.stepBody_unexecuted_if_counts

-- target Bitcoin.Script.Parser.countsTowardOpLimit
#print axioms Bitcoin.Script.Parser.countsTowardOpLimit

-- target BitcoinProofs.AF.PDW79.stepBody_opCount_precedes_disabled
#print axioms BitcoinProofs.AF.PDW79.stepBody_opCount_precedes_disabled

-- target Bitcoin.Interpreter.Defs.cmsLoop
#print axioms Bitcoin.Interpreter.Defs.cmsLoop
-- drift Bitcoin.Interpreter.Defs.cmsLoop -> Bitcoin.Interpreter.cmsLoop
#print axioms Bitcoin.Interpreter.cmsLoop

-- target Bitcoin.Interpreter.Defs.stepChecked_ok_bound
#print axioms Bitcoin.Interpreter.Defs.stepChecked_ok_bound
-- drift Bitcoin.Interpreter.Defs.stepChecked_ok_bound -> Bitcoin.Interpreter.stepChecked_ok_bound
#print axioms Bitcoin.Interpreter.stepChecked_ok_bound

-- target Bitcoin.Interpreter.Defs.evalScriptBytes_ok_stack_bound
#print axioms Bitcoin.Interpreter.Defs.evalScriptBytes_ok_stack_bound
-- drift Bitcoin.Interpreter.Defs.evalScriptBytes_ok_stack_bound -> Bitcoin.Interpreter.evalScriptBytes_ok_stack_bound
#print axioms Bitcoin.Interpreter.evalScriptBytes_ok_stack_bound

-- target Bitcoin.Interpreter.Defs.executeWitnessScript
#print axioms Bitcoin.Interpreter.Defs.executeWitnessScript
-- drift Bitcoin.Interpreter.Defs.executeWitnessScript -> Bitcoin.Interpreter.executeWitnessScript
#print axioms Bitcoin.Interpreter.executeWitnessScript

-- target BitcoinProofs.AF.PDW69.cmsLoop_charges_nKeys_row
#print axioms BitcoinProofs.AF.PDW69.cmsLoop_charges_nKeys_row

-- target BitcoinProofs.AF.PDW36.sigOpCount_eq
#print axioms BitcoinProofs.AF.PDW36.sigOpCount_eq

-- target BitcoinProofs.AF.PDW36.p2shSigOpCount_malformed
#print axioms BitcoinProofs.AF.PDW36.p2shSigOpCount_malformed

-- target BitcoinProofs.AF.PDW33.witnessSigOps_v0_32
#print axioms BitcoinProofs.AF.PDW33.witnessSigOps_v0_32

-- target BitcoinProofs.AF.PDW33.countWitnessSigOps_p2sh_wrapped
#print axioms BitcoinProofs.AF.PDW33.countWitnessSigOps_p2sh_wrapped

-- target BitcoinProofs.AF.PDW36.sigOpCost_eq
#print axioms BitcoinProofs.AF.PDW36.sigOpCost_eq

-- target BitcoinProofs.AF.PDW33.blockSigOpsCostOk_iff
#print axioms BitcoinProofs.AF.PDW33.blockSigOpsCostOk_iff

-- target BitcoinProofs.AF.PDW74.MAX_STANDARD_TX_SIGOPS_COST_eq
#print axioms BitcoinProofs.AF.PDW74.MAX_STANDARD_TX_SIGOPS_COST_eq

-- target Bitcoin.Interpreter.Defs.evalChecksigTapscript
#print axioms Bitcoin.Interpreter.Defs.evalChecksigTapscript
-- drift Bitcoin.Interpreter.Defs.evalChecksigTapscript -> Bitcoin.Interpreter.evalChecksigTapscript
#print axioms Bitcoin.Interpreter.evalChecksigTapscript

-- target BitcoinProofs.AF.PDW18.evalChecksigTapscript_upgradable_key_decrements
#print axioms BitcoinProofs.AF.PDW18.evalChecksigTapscript_upgradable_key_decrements

-- target BitcoinProofs.AF.PDW36.MAX_PUBKEYS_PER_MULTI_A_eq
#print axioms BitcoinProofs.AF.PDW36.MAX_PUBKEYS_PER_MULTI_A_eq

-- target BitcoinProofs.AF.PDW57b.MIN_TRANSACTION_WEIGHT_row
#print axioms BitcoinProofs.AF.PDW57b.MIN_TRANSACTION_WEIGHT_row

-- target Bitcoin.Script.Parser.getOp
#print axioms Bitcoin.Script.Parser.getOp

-- target Bitcoin.Interpreter.encodeScriptNum_1negate_0x81
#print axioms Bitcoin.Interpreter.encodeScriptNum_1negate_0x81

-- target BitcoinProofs.AF.PDW98.stepBody_pushBytes_nonminimal
#print axioms BitcoinProofs.AF.PDW98.stepBody_pushBytes_nonminimal

-- target BitcoinProofs.AF.PDW98.stepBody_pushBytes_unexec_ok
#print axioms BitcoinProofs.AF.PDW98.stepBody_pushBytes_unexec_ok

-- target BitcoinProofs.AF.PDW80.scr050_minimal_reject
#print axioms BitcoinProofs.AF.PDW80.scr050_minimal_reject

-- target BitcoinProofs.AF.PDW98.stepBody_cltv_nonminimal
#print axioms BitcoinProofs.AF.PDW98.stepBody_cltv_nonminimal

-- target Bitcoin.Interpreter.Defs.isPushOnlyWire
#print axioms Bitcoin.Interpreter.Defs.isPushOnlyWire
-- drift Bitcoin.Interpreter.Defs.isPushOnlyWire -> Bitcoin.Interpreter.isPushOnlyWire
#print axioms Bitcoin.Interpreter.isPushOnlyWire

-- target Bitcoin.Interpreter.Defs.isWitnessProgram
#print axioms Bitcoin.Interpreter.Defs.isWitnessProgram
-- drift Bitcoin.Interpreter.Defs.isWitnessProgram -> Bitcoin.Interpreter.isWitnessProgram
#print axioms Bitcoin.Interpreter.isWitnessProgram

-- target BitcoinProofs.AF.PDW72.scr056_if_effect
#print axioms BitcoinProofs.AF.PDW72.scr056_if_effect

-- target Bitcoin.Numeric.castToBool
#print axioms Bitcoin.Numeric.castToBool

-- target BitcoinProofs.AF.PDW72.scr058_minimalIf_tapscript
#print axioms BitcoinProofs.AF.PDW72.scr058_minimalIf_tapscript

-- target BitcoinProofs.AF.PDW89.stepBody_minimalif_witnessv0
#print axioms BitcoinProofs.AF.PDW89.stepBody_minimalif_witnessv0

-- target BitcoinProofs.AF.PDW85b.stepBody_unexecuted_if_stack
#print axioms BitcoinProofs.AF.PDW85b.stepBody_unexecuted_if_stack

-- target BitcoinProofs.AF.PDW72.scr061_else_toggle
#print axioms BitcoinProofs.AF.PDW72.scr061_else_toggle

-- target BitcoinProofs.AF.PDW39b.evalFrom_nil_unbalanced
#print axioms BitcoinProofs.AF.PDW39b.evalFrom_nil_unbalanced

-- target BitcoinProofs.AF.PDW67b.stepBody_opVerif_badOpcode
#print axioms BitcoinProofs.AF.PDW67b.stepBody_opVerif_badOpcode

-- target BitcoinProofs.AF.PDW67b.stepBody_opVer_unexecuted
#print axioms BitcoinProofs.AF.PDW67b.stepBody_opVer_unexecuted

-- target BitcoinProofs.AF.PDW88.stepBody_if_counts_opcode
#print axioms BitcoinProofs.AF.PDW88.stepBody_if_counts_opcode

-- target BitcoinProofs.AF.PDW72.scr068_verify_success
#print axioms BitcoinProofs.AF.PDW72.scr068_verify_success

-- target BitcoinProofs.AF.PDW72.scr069_return_always
#print axioms BitcoinProofs.AF.PDW72.scr069_return_always

-- target BitcoinProofs.PDW9.scriptUnspendable_of_oversize
#print axioms BitcoinProofs.PDW9.scriptUnspendable_of_oversize

-- target BitcoinProofs.AF.PDW69.nopClass_discourage_row
#print axioms BitcoinProofs.AF.PDW69.nopClass_discourage_row

-- target BitcoinProofs.AF.PDW73.stepBody_cltv_csv_noflag_nop
#print axioms BitcoinProofs.AF.PDW73.stepBody_cltv_csv_noflag_nop

-- target BitcoinProofs.AF.PDW67b.stepBody_fromAltstack_empty
#print axioms BitcoinProofs.AF.PDW67b.stepBody_fromAltstack_empty

-- target BitcoinProofs.AF.PDW79.stepBody_depth_check
#print axioms BitcoinProofs.AF.PDW79.stepBody_depth_check

-- target BitcoinProofs.AF.PDW79.stepBody_pickroll_oob
#print axioms BitcoinProofs.AF.PDW79.stepBody_pickroll_oob

-- target BitcoinProofs.AF.PDW85.stepBody_size_minimal_scriptnum
#print axioms BitcoinProofs.AF.PDW85.stepBody_size_minimal_scriptnum

-- target BitcoinProofs.AF.PDW79.stepBody_ifdup_true
#print axioms BitcoinProofs.AF.PDW79.stepBody_ifdup_true

-- target Bitcoin.Numeric.scriptNum_four_byte_rule
#print axioms Bitcoin.Numeric.scriptNum_four_byte_rule

-- target Bitcoin.Numeric.SCRIPT_NUM_DEFAULT_MAX_SIZE
#print axioms Bitcoin.Numeric.SCRIPT_NUM_DEFAULT_MAX_SIZE

-- target BitcoinProofs.AF.PDW62b.decodeScriptNum_width_none
#print axioms BitcoinProofs.AF.PDW62b.decodeScriptNum_width_none

-- target Bitcoin.Numeric.encodeScriptNum
#print axioms Bitcoin.Numeric.encodeScriptNum

-- target Bitcoin.Numeric.setVchBE_neg_zero
#print axioms Bitcoin.Numeric.setVchBE_neg_zero

-- target Bitcoin.Numeric.scriptNum_minimal_reject
#print axioms Bitcoin.Numeric.scriptNum_minimal_reject

-- target Bitcoin.Numeric.getIntClamped
#print axioms Bitcoin.Numeric.getIntClamped

-- target BitcoinProofs.AF.PDW86.stepBody_unop
#print axioms BitcoinProofs.AF.PDW86.stepBody_unop

-- target BitcoinProofs.AF.PDW86.stepBody_binop
#print axioms BitcoinProofs.AF.PDW86.stepBody_binop

-- target BitcoinProofs.AF.PDW86.stepBody_within
#print axioms BitcoinProofs.AF.PDW86.stepBody_within

-- target BitcoinProofs.AF.PDW79.stepBody_numequalverify_false
#print axioms BitcoinProofs.AF.PDW79.stepBody_numequalverify_false

-- target BitcoinProofs.AF.PDW86.stepBody_size_raw
#print axioms BitcoinProofs.AF.PDW86.stepBody_size_raw

-- target Bitcoin.Interpreter.opNotequal_0x8e_disabled_and_success
#print axioms Bitcoin.Interpreter.opNotequal_0x8e_disabled_and_success

-- target BitcoinProofs.AF.PDW78.scr093_hashForOp_widths
#print axioms BitcoinProofs.AF.PDW78.scr093_hashForOp_widths

-- target BitcoinProofs.AF.PDW78.scr094_hash_composition
#print axioms BitcoinProofs.AF.PDW78.scr094_hash_composition

-- target BitcoinProofs.AF.PDW78.scr095_emptyElement_hashed
#print axioms BitcoinProofs.AF.PDW78.scr095_emptyElement_hashed

-- target BitcoinProofs.AF.PDW85b.stepBody_codeseparator
#print axioms BitcoinProofs.AF.PDW85b.stepBody_codeseparator

-- target BitcoinProofs.AF.PDW85b.stepBody_codeseparator_unexecuted
#print axioms BitcoinProofs.AF.PDW85b.stepBody_codeseparator_unexecuted

-- target BitcoinProofs.AF.PDW83.findAndDelete_empty_needle
#print axioms BitcoinProofs.AF.PDW83.findAndDelete_empty_needle

-- target BitcoinProofs.AF.PDW83.evalChecksigPreTapscript_constScriptCode_row
#print axioms BitcoinProofs.AF.PDW83.evalChecksigPreTapscript_constScriptCode_row

-- target BitcoinProofs.AF.PDW87.evalChecksigPreTapscript_findAndDelete
#print axioms BitcoinProofs.AF.PDW87.evalChecksigPreTapscript_findAndDelete

-- target Bitcoin.SigHash.scriptCodeOf_idempotent
#print axioms Bitcoin.SigHash.scriptCodeOf_idempotent

-- target BitcoinProofs.AF.PDW82.isValidSigEncoding_size
#print axioms BitcoinProofs.AF.PDW82.isValidSigEncoding_size

-- target BitcoinProofs.AF.PDW89c.checkLowS_row
#print axioms BitcoinProofs.AF.PDW89c.checkLowS_row

-- target BitcoinProofs.AF.PDW81.isDefinedHashtype_iff
#print axioms BitcoinProofs.AF.PDW81.isDefinedHashtype_iff

-- target BitcoinProofs.AF.PDW68x.pubkey_strictenc_reject
#print axioms BitcoinProofs.AF.PDW68x.pubkey_strictenc_reject

-- target BitcoinProofs.AF.PDW68x.witness_pubkeytype_reject
#print axioms BitcoinProofs.AF.PDW68x.witness_pubkeytype_reject

-- target Bitcoin.Interpreter.Defs.checkSigEncoding
#print axioms Bitcoin.Interpreter.Defs.checkSigEncoding
-- drift Bitcoin.Interpreter.Defs.checkSigEncoding -> Bitcoin.Interpreter.checkSigEncoding
#print axioms Bitcoin.Interpreter.checkSigEncoding

-- target BitcoinProofs.AF.PDW87.evalChecksigPreTapscript_empty_sig
#print axioms BitcoinProofs.AF.PDW87.evalChecksigPreTapscript_empty_sig

-- target BitcoinProofs.AF.PDW87.evalChecksigPreTapscript_nullfail
#print axioms BitcoinProofs.AF.PDW87.evalChecksigPreTapscript_nullfail

-- target Bitcoin.SigHash.htAcp
#print axioms Bitcoin.SigHash.htAcp

-- target BitcoinProofs.AF.PDW62b.evalChecksigPreTapscript_pk_invalid
#print axioms BitcoinProofs.AF.PDW62b.evalChecksigPreTapscript_pk_invalid

-- target BitcoinProofs.AF.PDW86.stepBody_nop_opCount
#print axioms BitcoinProofs.AF.PDW86.stepBody_nop_opCount

-- target BitcoinProofs.AF.PDW80.scr114_pubkey_range
#print axioms BitcoinProofs.AF.PDW80.scr114_pubkey_range

-- target BitcoinProofs.AF.PDW84.cms_fad_before_check_row
#print axioms BitcoinProofs.AF.PDW84.cms_fad_before_check_row

-- target BitcoinProofs.AF.PDW83.cmsLoop_sig_exceeds_keys
#print axioms BitcoinProofs.AF.PDW83.cmsLoop_sig_exceeds_keys

-- target BitcoinProofs.AF.PDW80.scr117_sig_encoding_in_loop
#print axioms BitcoinProofs.AF.PDW80.scr117_sig_encoding_in_loop

-- target BitcoinProofs.AF.PDW87.checkMultiSig_extra_item_consumed
#print axioms BitcoinProofs.AF.PDW87.checkMultiSig_extra_item_consumed

-- target BitcoinProofs.AF.PDW87.checkMultiSig_nulldummy
#print axioms BitcoinProofs.AF.PDW87.checkMultiSig_nulldummy

-- target BitcoinProofs.AF.PDW69.checkMultiSigVerify_fail_row
#print axioms BitcoinProofs.AF.PDW69.checkMultiSigVerify_fail_row

-- target BitcoinProofs.AF.PDW73.stepBody_tapscript_checkmultisig_ban
#print axioms BitcoinProofs.AF.PDW73.stepBody_tapscript_checkmultisig_ban

-- target BitcoinProofs.AF.PDW58.cltv_negative_errors
#print axioms BitcoinProofs.AF.PDW58.cltv_negative_errors

-- target BitcoinProofs.AF.PDW46b.cltv_mixed_type_false
#print axioms BitcoinProofs.AF.PDW46b.cltv_mixed_type_false

-- target BitcoinProofs.AF.PDW46b.cltv_above_locktime_false
#print axioms BitcoinProofs.AF.PDW46b.cltv_above_locktime_false

-- target BitcoinProofs.AF.PDW46b.cltv_final_input_false
#print axioms BitcoinProofs.AF.PDW46b.cltv_final_input_false

-- target BitcoinProofs.AF.PDW58.csv_negative_errors
#print axioms BitcoinProofs.AF.PDW58.csv_negative_errors

-- target Bitcoin.Interpreter.Defs.checkSequenceDef
#print axioms Bitcoin.Interpreter.Defs.checkSequenceDef
-- drift Bitcoin.Interpreter.Defs.checkSequenceDef -> Bitcoin.Interpreter.checkSequenceDef
#print axioms Bitcoin.Interpreter.checkSequenceDef

-- target Bitcoin.Interpreter.Rules.checkSequenceDef_version_gate
#print axioms Bitcoin.Interpreter.Rules.checkSequenceDef_version_gate
-- drift Bitcoin.Interpreter.Rules.checkSequenceDef_version_gate -> Bitcoin.Interpreter.checkSequenceDef_version_gate
#print axioms Bitcoin.Interpreter.checkSequenceDef_version_gate

-- target BitcoinProofs.AF.PDW46b.csv_tx_disable_flag_false
#print axioms BitcoinProofs.AF.PDW46b.csv_tx_disable_flag_false

-- target BitcoinProofs.AF.PDW46b.csv_masked_above_false
#print axioms BitcoinProofs.AF.PDW46b.csv_masked_above_false

-- target BitcoinProofs.AF.PDW68x.csv_accept_masked_le
#print axioms BitcoinProofs.AF.PDW68x.csv_accept_masked_le

-- target BitcoinProofs.AF.PDW33.locktimeEnvOf_congr_row
#print axioms BitcoinProofs.AF.PDW33.locktimeEnvOf_congr_row

-- target BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wsh_script
#print axioms BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wsh_script

-- target BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wsh_empty
#print axioms BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wsh_empty

-- target BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wsh_mismatch
#print axioms BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wsh_mismatch

-- target BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wpkh_wrong_len
#print axioms BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wpkh_wrong_len

-- target BitcoinProofs.AF.PDW65.verifyWitnessProgram_v0_20_ok_cleanstack
#print axioms BitcoinProofs.AF.PDW65.verifyWitnessProgram_v0_20_ok_cleanstack

-- target Bitcoin.Interpreter.Defs.evalChecksigPreTapscript
#print axioms Bitcoin.Interpreter.Defs.evalChecksigPreTapscript
-- drift Bitcoin.Interpreter.Defs.evalChecksigPreTapscript -> Bitcoin.Interpreter.evalChecksigPreTapscript
#print axioms Bitcoin.Interpreter.evalChecksigPreTapscript

-- target Bitcoin.SigHash.bip143MsgL
#print axioms Bitcoin.SigHash.bip143MsgL

-- target Bitcoin.SigHash.bip143_single_oor
#print axioms Bitcoin.SigHash.bip143_single_oor

-- target BitcoinProofs.AF.PDW19.verifyWitnessProgram_taproot_gate_silent_ok
#print axioms BitcoinProofs.AF.PDW19.verifyWitnessProgram_taproot_gate_silent_ok

-- target BitcoinProofs.AF.PDW82c.verifyWitnessProgram_annex_detected
#print axioms BitcoinProofs.AF.PDW82c.verifyWitnessProgram_annex_detected

-- target BitcoinProofs.AF.PDW19.verifyWitnessProgram_keypath
#print axioms BitcoinProofs.AF.PDW19.verifyWitnessProgram_keypath

-- target BitcoinProofs.AF.PDW83.verifyWitnessProgram_taproot_control_bad
#print axioms BitcoinProofs.AF.PDW83.verifyWitnessProgram_taproot_control_bad

-- target BitcoinProofs.AF.PDW58.tapLeafHash_size_row
#print axioms BitcoinProofs.AF.PDW58.tapLeafHash_size_row

-- target Bitcoin.Interpreter.Rules.tweakPoint_determined
#print axioms Bitcoin.Interpreter.Rules.tweakPoint_determined
-- drift Bitcoin.Interpreter.Rules.tweakPoint_determined -> Bitcoin.Interpreter.tweakPoint_determined
#print axioms Bitcoin.Interpreter.tweakPoint_determined

-- target BitcoinProofs.AF.PDW67.verifyTaprootLeafDispatch_c0_row
#print axioms BitcoinProofs.AF.PDW67.verifyTaprootLeafDispatch_c0_row

-- target BitcoinProofs.AF.PDW19.verifyWitnessProgram_upgradable_leaf_ok
#print axioms BitcoinProofs.AF.PDW19.verifyWitnessProgram_upgradable_leaf_ok

-- target BitcoinProofs.AF.PDW59.verifyWitnessProgram_v1_anchor_ok
#print axioms BitcoinProofs.AF.PDW59.verifyWitnessProgram_v1_anchor_ok

-- target BitcoinProofs.AF.PDW59.verifyWitnessProgram_v1_wrong_size_ok
#print axioms BitcoinProofs.AF.PDW59.verifyWitnessProgram_v1_wrong_size_ok

-- target Bitcoin.Interpreter.Defs.disabledWire
#print axioms Bitcoin.Interpreter.Defs.disabledWire
-- drift Bitcoin.Interpreter.Defs.disabledWire -> Bitcoin.Interpreter.disabledWire
#print axioms Bitcoin.Interpreter.disabledWire

-- target BitcoinProofs.AF.PDW82b.executeWitnessScript_opSuccess_ok
#print axioms BitcoinProofs.AF.PDW82b.executeWitnessScript_opSuccess_ok

-- target BitcoinProofs.AF.PDW97.executeWitnessScript_opSuccess_discouraged
#print axioms BitcoinProofs.AF.PDW97.executeWitnessScript_opSuccess_discouraged

-- target BitcoinProofs.AF.PDW91.stepBody_nop_tapscript_overbudget
#print axioms BitcoinProofs.AF.PDW91.stepBody_nop_tapscript_overbudget

-- target BitcoinProofs.AF.PDW89.checksigAddStep_nonminimal
#print axioms BitcoinProofs.AF.PDW89.checksigAddStep_nonminimal

-- target BitcoinProofs.AF.PDW90b.evalChecksigTapscript_empty_pubkey_fails
#print axioms BitcoinProofs.AF.PDW90b.evalChecksigTapscript_empty_pubkey_fails

-- target BitcoinProofs.AF.PDW82.evalChecksigTapscript_weight_before_pubkey
#print axioms BitcoinProofs.AF.PDW82.evalChecksigTapscript_weight_before_pubkey

-- target BitcoinProofs.AF.PDW82.evalChecksigTapscript_empty_sig_no_weight
#print axioms BitcoinProofs.AF.PDW82.evalChecksigTapscript_empty_sig_no_weight

-- target BitcoinProofs.AF.PDW47.schnorrVerdict_size_gate
#print axioms BitcoinProofs.AF.PDW47.schnorrVerdict_size_gate

-- target BitcoinProofs.AF.PDW47.schnorrVerdict_65_default_rejected
#print axioms BitcoinProofs.AF.PDW47.schnorrVerdict_65_default_rejected

-- target BitcoinProofs.AF.PDW58.isValidBip341Hashtype_valid_iff
#print axioms BitcoinProofs.AF.PDW58.isValidBip341Hashtype_valid_iff

-- target BitcoinProofs.AF.PDW89b.extSlice_tapscript_ext
#print axioms BitcoinProofs.AF.PDW89b.extSlice_tapscript_ext

-- target BitcoinProofs.AF.PDW47.schnorrVerdict_default_64
#print axioms BitcoinProofs.AF.PDW47.schnorrVerdict_default_64

-- target BitcoinProofs.AF.PDW47.schnorrVerdict_sighash_fail_closed
#print axioms BitcoinProofs.AF.PDW47.schnorrVerdict_sighash_fail_closed

-- target BitcoinProofs.AF.PDW47.stepBody_codesep_records_next
#print axioms BitcoinProofs.AF.PDW47.stepBody_codesep_records_next

-- target Bitcoin.Interpreter.Rules.evalChecksigTapscript_budget_exactly_zero
#print axioms Bitcoin.Interpreter.Rules.evalChecksigTapscript_budget_exactly_zero
-- drift Bitcoin.Interpreter.Rules.evalChecksigTapscript_budget_exactly_zero -> Bitcoin.Interpreter.evalChecksigTapscript_budget_exactly_zero
#print axioms Bitcoin.Interpreter.evalChecksigTapscript_budget_exactly_zero

-- target BitcoinProofs.AF.PDW83.sighashTaproot_epoch_row
#print axioms BitcoinProofs.AF.PDW83.sighashTaproot_epoch_row

-- target BitcoinProofs.AF.PDW91.stepBody_disabled_unexec
#print axioms BitcoinProofs.AF.PDW91.stepBody_disabled_unexec

-- target BitcoinProofs.AF.PDW58.disabledWire_successx_matrix_row
#print axioms BitcoinProofs.AF.PDW58.disabledWire_successx_matrix_row

-- target BitcoinProofs.AF.PDW68.opNameKnown_covered
#print axioms BitcoinProofs.AF.PDW68.opNameKnown_covered

-- target BitcoinProofs.AF.PDW91.stepBody_invalidopcode
#print axioms BitcoinProofs.AF.PDW91.stepBody_invalidopcode

-- target BitcoinProofs.AF.PDW63.checkTransaction_vinEmpty_row
#print axioms BitcoinProofs.AF.PDW63.checkTransaction_vinEmpty_row

-- target BitcoinProofs.AF.PDW63.checkTransaction_voutEmpty_row
#print axioms BitcoinProofs.AF.PDW63.checkTransaction_voutEmpty_row

-- target BitcoinProofs.AF.PDW59.checkOutputs_none_nonneg
#print axioms BitcoinProofs.AF.PDW59.checkOutputs_none_nonneg

-- target BitcoinProofs.AF.PDW59.checkOutputs_none_le_MAX
#print axioms BitcoinProofs.AF.PDW59.checkOutputs_none_le_MAX

-- target BitcoinProofs.AF.PDW59.checkOutputs_none_total_moneyRange
#print axioms BitcoinProofs.AF.PDW59.checkOutputs_none_total_moneyRange

-- target BitcoinProofs.AF.PDW69TxCheck.checkTransaction_none_noDup
#print axioms BitcoinProofs.AF.PDW69TxCheck.checkTransaction_none_noDup

-- target BitcoinProofs.AF.PDW74.checkTransaction_ok_cbLength
#print axioms BitcoinProofs.AF.PDW74.checkTransaction_ok_cbLength

-- target BitcoinProofs.AF.PDW69TxCheck.checkTransaction_ok_prevoutNotNull
#print axioms BitcoinProofs.AF.PDW69TxCheck.checkTransaction_ok_prevoutNotNull

-- target BitcoinProofs.AF.PDW40.decTxCore_base_layout
#print axioms BitcoinProofs.AF.PDW40.decTxCore_base_layout

-- target Bitcoin.Serialization.Interface.decCS
#print axioms Bitcoin.Serialization.Interface.decCS
-- drift Bitcoin.Serialization.Interface.decCS -> Bitcoin.Serialization.decCS
#print axioms Bitcoin.Serialization.decCS

-- target BitcoinProofs.AF.PDW40.decTxCore_flag0_shortRecord
#print axioms BitcoinProofs.AF.PDW40.decTxCore_flag0_shortRecord

-- target BitcoinProofs.AF.PDW40.decTxCore_witness_layout
#print axioms BitcoinProofs.AF.PDW40.decTxCore_witness_layout

-- target BitcoinProofs.AF.PDW40.decTxCore_superfluous
#print axioms BitcoinProofs.AF.PDW40.decTxCore_superfluous

-- target BitcoinProofs.AF.PDW40.decTxCore_unknownFlag
#print axioms BitcoinProofs.AF.PDW40.decTxCore_unknownFlag

-- target BitcoinProofs.AF.PDW42.txid_identity_face
#print axioms BitcoinProofs.AF.PDW42.txid_identity_face

-- target BitcoinProofs.AF.PDW42.wtxid_witness_face
#print axioms BitcoinProofs.AF.PDW42.wtxid_witness_face

-- target Bitcoin.DataLaws.txWeight_formula
#print axioms Bitcoin.DataLaws.txWeight_formula

-- target Bitcoin.TxValidation.haveInputs
#print axioms Bitcoin.TxValidation.haveInputs

-- target BitcoinProofs.AF.PDW66.coinMatured_iff
#print axioms BitcoinProofs.AF.PDW66.coinMatured_iff

-- target Bitcoin.TxValidation.coinHeightOfCode_pack
#print axioms Bitcoin.TxValidation.coinHeightOfCode_pack

-- target BitcoinProofs.AF.PDW70.inputValuesLoop_ok_sum_row
#print axioms BitcoinProofs.AF.PDW70.inputValuesLoop_ok_sum_row

-- target Bitcoin.Numeric.feeOf_nonneg_iff
#print axioms Bitcoin.Numeric.feeOf_nonneg_iff

-- target BitcoinProofs.AF.PDW38.feeAccumInRange_iff
#print axioms BitcoinProofs.AF.PDW38.feeAccumInRange_iff

-- target Bitcoin.DataLaws.locktimeIsTimeDomain_iff
#print axioms Bitcoin.DataLaws.locktimeIsTimeDomain_iff

-- target Bitcoin.DataLaws.isFinalTx_iff
#print axioms Bitcoin.DataLaws.isFinalTx_iff

-- target BitcoinProofs.AF.PDW63.bip113Cutoff_row
#print axioms BitcoinProofs.AF.PDW63.bip113Cutoff_row

-- target BitcoinProofs.AF.PDW100.validateTx_nonfinal
#print axioms BitcoinProofs.AF.PDW100.validateTx_nonfinal

-- target Bitcoin.TxValidation.Mempool.checkFinalTxAtTip
#print axioms Bitcoin.TxValidation.Mempool.checkFinalTxAtTip

-- target Bitcoin.DataLaws.bip68Enabled
#print axioms Bitcoin.DataLaws.bip68Enabled

-- target Bitcoin.DataLaws.seqIsDisabled_iff
#print axioms Bitcoin.DataLaws.seqIsDisabled_iff

-- target Bitcoin.DataLaws.seqIsTimeBased_iff
#print axioms Bitcoin.DataLaws.seqIsTimeBased_iff

-- target Bitcoin.DataLaws.seqRelative_eq_mod
#print axioms Bitcoin.DataLaws.seqRelative_eq_mod

-- target Bitcoin.DataLaws.seqHeightLock_last_invalid
#print axioms Bitcoin.DataLaws.seqHeightLock_last_invalid

-- target Bitcoin.TxValidation.sequenceLocksOk_iff
#print axioms Bitcoin.TxValidation.sequenceLocksOk_iff

-- target Bitcoin.TxValidation.bip68HeightOk
#print axioms Bitcoin.TxValidation.bip68HeightOk

-- target Bitcoin.TxValidation.Mempool.checkSequenceLocksAtTip
#print axioms Bitcoin.TxValidation.Mempool.checkSequenceLocksAtTip

-- target Bitcoin.TxValidation.mempoolHeight
#print axioms Bitcoin.TxValidation.mempoolHeight

-- target Bitcoin.TxValidation.LocktimeSigOps.checkLockTime_domain_mismatch_fails
#print axioms Bitcoin.TxValidation.LocktimeSigOps.checkLockTime_domain_mismatch_fails

-- target Bitcoin.TxValidation.LocktimeSigOps.checkLockTime_gt_fails
#print axioms Bitcoin.TxValidation.LocktimeSigOps.checkLockTime_gt_fails

-- target Bitcoin.TxValidation.LocktimeSigOps.checkLockTime_finalSeq_fails
#print axioms Bitcoin.TxValidation.LocktimeSigOps.checkLockTime_finalSeq_fails

-- target Bitcoin.TxValidation.LocktimeSigOps.checkSequence_version_fails
#print axioms Bitcoin.TxValidation.LocktimeSigOps.checkSequence_version_fails

-- target Bitcoin.TxValidation.LocktimeSigOps.checkSequence_disable_fails
#print axioms Bitcoin.TxValidation.LocktimeSigOps.checkSequence_disable_fails

-- target Bitcoin.TxValidation.LocktimeSigOps.checkSequence_masked
#print axioms Bitcoin.TxValidation.LocktimeSigOps.checkSequence_masked

-- target Bitcoin.TxValidation.LocktimeSigOps.txLegacySigOps_one_in_out
#print axioms Bitcoin.TxValidation.LocktimeSigOps.txLegacySigOps_one_in_out

-- target Bitcoin.TxValidation.SigOpsCost.p2shSigOpsTx_coinbase_zero
#print axioms Bitcoin.TxValidation.SigOpsCost.p2shSigOpsTx_coinbase_zero

-- target Bitcoin.TxValidation.SigOpsCost.p2shSigOpsTx_one_p2sh
#print axioms Bitcoin.TxValidation.SigOpsCost.p2shSigOpsTx_one_p2sh

-- target Bitcoin.TxValidation.SigOpsCost.witnessSigOpsTx
#print axioms Bitcoin.TxValidation.SigOpsCost.witnessSigOpsTx

-- target Bitcoin.TxValidation.LocktimeSigOps.sigOpCost_scale
#print axioms Bitcoin.TxValidation.LocktimeSigOps.sigOpCost_scale

-- target BitcoinProofs.Theorems.BlockCor.blockSigOpCostOk_of_per_tx_bound
#print axioms BitcoinProofs.Theorems.BlockCor.blockSigOpCostOk_of_per_tx_bound

-- target Bitcoin.TxValidation.LocktimeSigOps.sigOpStep_le_maxMultisig
#print axioms Bitcoin.TxValidation.LocktimeSigOps.sigOpStep_le_maxMultisig

-- target BitcoinProofs.AF.PDW84.getBlockScriptFlagsP_row
#print axioms BitcoinProofs.AF.PDW84.getBlockScriptFlagsP_row

-- target Bitcoin.Activation.exception_replaces_base
#print axioms Bitcoin.Activation.exception_replaces_base

-- target Bitcoin.TxValidation.Full.scriptLane
#print axioms Bitcoin.TxValidation.Full.scriptLane

-- target Bitcoin.TxValidation.Full.txVerdictFull_coinbase_skip
#print axioms Bitcoin.TxValidation.Full.txVerdictFull_coinbase_skip

-- target Bitcoin.TxValidation.Full.txVerdictFull_script_fail
#print axioms Bitcoin.TxValidation.Full.txVerdictFull_script_fail

-- target Bitcoin.TxValidation.Full.txCheckerFor
#print axioms Bitcoin.TxValidation.Full.txCheckerFor

-- target Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached
#print axioms Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached

-- target BitcoinProofs.Theorems.CapstoneBip30Loop.applyBlockL_loop_iff
#print axioms BitcoinProofs.Theorems.CapstoneBip30Loop.applyBlockL_loop_iff

-- target Bitcoin.TxValidation.Mempool.first_spender_wins
#print axioms Bitcoin.TxValidation.Mempool.first_spender_wins

-- target Bitcoin.TxValidation.Mempool.applyBlockU_cons_ok_step
#print axioms Bitcoin.TxValidation.Mempool.applyBlockU_cons_ok_step

-- target Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_spk_irrelevant
#print axioms Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_spk_irrelevant

-- target Bitcoin.TxValidation.checkTxInputs
#print axioms Bitcoin.TxValidation.checkTxInputs

-- target Bitcoin.Numeric.moneyRange_iff
#print axioms Bitcoin.Numeric.moneyRange_iff

-- target Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_none_partial_moneyRange
#print axioms Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_none_partial_moneyRange

-- target Bitcoin.TxValidation.coinbase_maturity_boundary
#print axioms Bitcoin.TxValidation.coinbase_maturity_boundary

-- target Bitcoin.TxValidation.validateTx
#print axioms Bitcoin.TxValidation.validateTx

-- target BitcoinProofs.AF.PDW81.validateTx_coinbase_ok
#print axioms BitcoinProofs.AF.PDW81.validateTx_coinbase_ok

-- target Bitcoin.TxValidation.Mempool.mempoolKey
#print axioms Bitcoin.TxValidation.Mempool.mempoolKey

-- target Bitcoin.TxValidation.checkTransaction_ok_getValueOut_moneyRange
#print axioms Bitcoin.TxValidation.checkTransaction_ok_getValueOut_moneyRange

-- target Bitcoin.Invariants.RC10.isSpent_iff
#print axioms Bitcoin.Invariants.RC10.isSpent_iff

-- target Bitcoin.Serialization.decodeBlockHeader_encodeBlockHeader
#print axioms Bitcoin.Serialization.decodeBlockHeader_encodeBlockHeader

-- target Bitcoin.Serialization.decodeBlock_encodeBlock
#print axioms Bitcoin.Serialization.decodeBlock_encodeBlock

-- target BitcoinProofs.AF.PDW68.headerHash_row
#print axioms BitcoinProofs.AF.PDW68.headerHash_row

-- target BitcoinProofs.AF.PDW27.headerIsNull_iff
#print axioms BitcoinProofs.AF.PDW27.headerIsNull_iff

-- target BitcoinProofs.AF.PDW50.txidOf_eq_sha256d_serTx
#print axioms BitcoinProofs.AF.PDW50.txidOf_eq_sha256d_serTx

-- target BitcoinProofs.AF.PDW50.wtxidOf_eq_txidOf_of_noWitness
#print axioms BitcoinProofs.AF.PDW50.wtxidOf_eq_txidOf_of_noWitness

-- target BitcoinProofs.AF.PDW50.merkleRootOfBlock_eq
#print axioms BitcoinProofs.AF.PDW50.merkleRootOfBlock_eq

-- target BitcoinProofs.AF.PDW50.merkleLevel_singleton
#print axioms BitcoinProofs.AF.PDW50.merkleLevel_singleton

-- target BitcoinProofs.AF.PDW50.pairHash_eq_sha256d_append
#print axioms BitcoinProofs.AF.PDW50.pairHash_eq_sha256d_append

-- target BitcoinProofs.AF.PDW12.merkleOk_of_eq
#print axioms BitcoinProofs.AF.PDW12.merkleOk_of_eq

-- target BitcoinProofs.AF.PDW12.levelHasAdjacentDup_cons2_of_beq
#print axioms BitcoinProofs.AF.PDW12.levelHasAdjacentDup_cons2_of_beq

-- target BitcoinProofs.AF.PDW53.merkleFailureKind_mutated
#print axioms BitcoinProofs.AF.PDW53.merkleFailureKind_mutated

-- target BitcoinProofs.AF.PDW76.merkleRootOf_nil
#print axioms BitcoinProofs.AF.PDW76.merkleRootOf_nil

-- target BitcoinProofs.AF.PDW41b.witnessLeaves_length
#print axioms BitcoinProofs.AF.PDW41b.witnessLeaves_length

-- target BitcoinProofs.AF.PDW41b.witnessCommitmentOutput_some_spec
#print axioms BitcoinProofs.AF.PDW41b.witnessCommitmentOutput_some_spec

-- target BitcoinProofs.AF.PDW41b.commitmentValueZero_eq_true_iff
#print axioms BitcoinProofs.AF.PDW41b.commitmentValueZero_eq_true_iff

-- target BitcoinProofs.AF.PDW13.witnessCommitmentOk_eq_true
#print axioms BitcoinProofs.AF.PDW13.witnessCommitmentOk_eq_true

-- target BitcoinProofs.AF.PDW13.commitmentNonceOk_eq_true
#print axioms BitcoinProofs.AF.PDW13.commitmentNonceOk_eq_true

-- target BitcoinProofs.AF.PDW13.commitmentGate_unexpected_witness
#print axioms BitcoinProofs.AF.PDW13.commitmentGate_unexpected_witness

-- target BitcoinProofs.AF.PDW14.commitmentGate_forces_binding
#print axioms BitcoinProofs.AF.PDW14.commitmentGate_forces_binding

-- target BitcoinProofs.AF.PDW53.contextualChecksOrdered_row
#print axioms BitcoinProofs.AF.PDW53.contextualChecksOrdered_row

-- target BitcoinProofs.AF.PDW41b.vtxNonempty_eq_true_iff
#print axioms BitcoinProofs.AF.PDW41b.vtxNonempty_eq_true_iff

-- target BitcoinProofs.AF.PDW28.vtxCountWeightOk_eq
#print axioms BitcoinProofs.AF.PDW28.vtxCountWeightOk_eq

-- target BitcoinProofs.AF.PDW51.strippedSize_row
#print axioms BitcoinProofs.AF.PDW51.strippedSize_row

-- target BitcoinProofs.AF.PDW51.blockWeight_row
#print axioms BitcoinProofs.AF.PDW51.blockWeight_row

-- target BitcoinProofs.Theorems.CapstoneWeight.weightOk_iff
#print axioms BitcoinProofs.Theorems.CapstoneWeight.weightOk_iff

-- target BitcoinProofs.AF.PDW51.cbPositionOk_cons_iff
#print axioms BitcoinProofs.AF.PDW51.cbPositionOk_cons_iff

-- target BitcoinProofs.AF.PDW68.cbPositionOk_tail_reject
#print axioms BitcoinProofs.AF.PDW68.cbPositionOk_tail_reject

-- target BitcoinProofs.AF.PDW32.cbLengthOk_iff
#print axioms BitcoinProofs.AF.PDW32.cbLengthOk_iff

-- target Bitcoin.Capstone.Block.validateBlock
#print axioms Bitcoin.Capstone.Block.validateBlock

-- target BitcoinProofs.AF.PDW68.hasDupPrevouts_pair_dup
#print axioms BitcoinProofs.AF.PDW68.hasDupPrevouts_pair_dup

-- target BitcoinProofs.AF.PDW34.checkTransaction_none_weight
#print axioms BitcoinProofs.AF.PDW34.checkTransaction_none_weight

-- target BitcoinProofs.AF.PDW29.legacySigOpCountTx_row_vector
#print axioms BitcoinProofs.AF.PDW29.legacySigOpCountTx_row_vector

-- target BitcoinProofs.Theorems.BlockCor.legacySigOpBudgetOk_le_20000
#print axioms BitcoinProofs.Theorems.BlockCor.legacySigOpBudgetOk_le_20000

-- target BitcoinProofs.AF.PDW29.txSigOpCost_decompose_row
#print axioms BitcoinProofs.AF.PDW29.txSigOpCost_decompose_row

-- target BitcoinProofs.AF.PDW16.compactTarget_eq
#print axioms BitcoinProofs.AF.PDW16.compactTarget_eq

-- target BitcoinProofs.AF.PDW16.targetOk_eq
#print axioms BitcoinProofs.AF.PDW16.targetOk_eq

-- target BitcoinProofs.Theorems.CapstonePow.powOk_iff_conj
#print axioms BitcoinProofs.Theorems.CapstonePow.powOk_iff_conj

-- target BitcoinProofs.AF.PDW28.powLimitMainnet_pin
#print axioms BitcoinProofs.AF.PDW28.powLimitMainnet_pin

-- target BitcoinProofs.AF.PDW28.powLimitSignet_pin
#print axioms BitcoinProofs.AF.PDW28.powLimitSignet_pin

-- target BitcoinProofs.AF.PDW12.nextWorkRequired_nonboundary_const
#print axioms BitcoinProofs.AF.PDW12.nextWorkRequired_nonboundary_const

-- target BitcoinProofs.AF.PDW31.nextWorkRequired_retarget_boundary
#print axioms BitcoinProofs.AF.PDW31.nextWorkRequired_retarget_boundary

-- target BitcoinProofs.AF.PDW38.nextWorkRequired_timespan_anchor
#print axioms BitcoinProofs.AF.PDW38.nextWorkRequired_timespan_anchor

-- target BitcoinProofs.AF.PDW31.calculateNextWorkRequired_clamp_low
#print axioms BitcoinProofs.AF.PDW31.calculateNextWorkRequired_clamp_low

-- target BitcoinProofs.AF.PDW43.calculateNextWorkRequired_scaled
#print axioms BitcoinProofs.AF.PDW43.calculateNextWorkRequired_scaled

-- target BitcoinProofs.AF.PDW43.calculateNextWorkRequired_bip94_base
#print axioms BitcoinProofs.AF.PDW43.calculateNextWorkRequired_bip94_base

-- target BitcoinProofs.AF.PDW31.calculateNextWorkRequired_capped_target
#print axioms BitcoinProofs.AF.PDW31.calculateNextWorkRequired_capped_target

-- target BitcoinProofs.AF.PDW38.calculateNextWorkRequired_noRetarget
#print axioms BitcoinProofs.AF.PDW38.calculateNextWorkRequired_noRetarget
-- drift BitcoinProofs.AF.PDW38.calculateNextWorkRequired_noRetarget -> BitcoinProofs.AF.PDW66.calculateNextWorkRequired_noRetarget
#print axioms BitcoinProofs.AF.PDW66.calculateNextWorkRequired_noRetarget

-- target BitcoinProofs.AF.PDW46.permittedDifficultyTransition_bounds
#print axioms BitcoinProofs.AF.PDW46.permittedDifficultyTransition_bounds

-- target BitcoinProofs.AF.PDW31.permittedDifficultyTransition_nonboundary
#print axioms BitcoinProofs.AF.PDW31.permittedDifficultyTransition_nonboundary

-- target BitcoinProofs.AF.PDW28.permitted_mindiff_true
#print axioms BitcoinProofs.AF.PDW28.permitted_mindiff_true

-- target BitcoinProofs.AF.PDW28.nextWorkRequired_minDiff_slow
#print axioms BitcoinProofs.AF.PDW28.nextWorkRequired_minDiff_slow

-- target BitcoinProofs.AF.PDW46.minDiffWalkBack_nearest
#print axioms BitcoinProofs.AF.PDW46.minDiffWalkBack_nearest

-- target BitcoinProofs.AF.PDW13.timewarpOk_true_iff
#print axioms BitcoinProofs.AF.PDW13.timewarpOk_true_iff

-- target BitcoinProofs.AF.PDW31.medianTimePast_congr
#print axioms BitcoinProofs.AF.PDW31.medianTimePast_congr

-- target BitcoinProofs.AF.PDW13.timeNotTooOld_eq
#print axioms BitcoinProofs.AF.PDW13.timeNotTooOld_eq

-- target BitcoinProofs.AF.PDW12.timeNotTooNew_eq
#print axioms BitcoinProofs.AF.PDW12.timeNotTooNew_eq

-- target BitcoinProofs.AF.PDW30.connectHeight_row
#print axioms BitcoinProofs.AF.PDW30.connectHeight_row

-- target BitcoinProofs.AF.PDW32.versionOk_bip34_face
#print axioms BitcoinProofs.AF.PDW32.versionOk_bip34_face

-- target BitcoinProofs.AF.PDW32.versionOk_bip66_face
#print axioms BitcoinProofs.AF.PDW32.versionOk_bip66_face

-- target BitcoinProofs.AF.PDW32.versionOk_bip65_face
#print axioms BitcoinProofs.AF.PDW32.versionOk_bip65_face

-- target BitcoinProofs.AF.PDW8.prevHeaderKnown_true_iff
#print axioms BitcoinProofs.AF.PDW8.prevHeaderKnown_true_iff

-- target BitcoinProofs.AF.PDW8.prevHeaderKnown_false_iff
#print axioms BitcoinProofs.AF.PDW8.prevHeaderKnown_false_iff

-- target BitcoinProofs.AF.PDW8.prevNotFailed_true_iff
#print axioms BitcoinProofs.AF.PDW8.prevNotFailed_true_iff

-- target Bitcoin.Block.Params.cachedVerdict
#print axioms Bitcoin.Block.Params.cachedVerdict

-- target BitcoinProofs.AF.PDW43.isFinalTx_iff_row
#print axioms BitcoinProofs.AF.PDW43.isFinalTx_iff_row

-- target BitcoinProofs.AF.PDW38.finalityCutoff_iff
#print axioms BitcoinProofs.AF.PDW38.finalityCutoff_iff

-- target Bitcoin.Block.Connect.blockFinalityOk_all
#print axioms Bitcoin.Block.Connect.blockFinalityOk_all

-- target BitcoinProofs.AF.PDW14.bip34Ok_push_prefix
#print axioms BitcoinProofs.AF.PDW14.bip34Ok_push_prefix

-- target Bitcoin.Activation.buriedActive_true
#print axioms Bitcoin.Activation.buriedActive_true

-- target Bitcoin.Activation.buriedActive_false
#print axioms Bitcoin.Activation.buriedActive_false

-- target Bitcoin.Activation.versionBitsSignals
#print axioms Bitcoin.Activation.versionBitsSignals

-- target Bitcoin.Activation.bip9State_next_period
#print axioms Bitcoin.Activation.bip9State_next_period

-- target Bitcoin.Activation.count_beats_timeout
#print axioms Bitcoin.Activation.count_beats_timeout

-- target Bitcoin.Activation.bip9_never_active
#print axioms Bitcoin.Activation.bip9_never_active

-- target Bitcoin.Activation.bip9_genesis_defined
#print axioms Bitcoin.Activation.bip9_genesis_defined

-- target BitcoinProofs.AF.PDW20.mainnet_testdummy_table
#print axioms BitcoinProofs.AF.PDW20.mainnet_testdummy_table

-- target BitcoinProofs.AF.PDW16.testnet4_testdummy_table
#print axioms BitcoinProofs.AF.PDW16.testnet4_testdummy_table

-- target BitcoinProofs.AF.PDW14.cbAmountOk_iff
#print axioms BitcoinProofs.AF.PDW14.cbAmountOk_iff

-- target BitcoinProofs.AF.PDW12.feeAccumInRange_eq
#print axioms BitcoinProofs.AF.PDW12.feeAccumInRange_eq

-- target BitcoinProofs.AF.PDW70.updateCoinsL_row
#print axioms BitcoinProofs.AF.PDW70.updateCoinsL_row

-- target BitcoinProofs.AF.PDW70.addedCoins_spendable_row
#print axioms BitcoinProofs.AF.PDW70.addedCoins_spendable_row

-- target BitcoinProofs.PDW9.scriptUnspendable_of_opReturn
#print axioms BitcoinProofs.PDW9.scriptUnspendable_of_opReturn

-- target BitcoinProofs.AF.PDW70.updateCoinsL_coinbase_row
#print axioms BitcoinProofs.AF.PDW70.updateCoinsL_coinbase_row

-- target Bitcoin.Ledger.bip30Enforced
#print axioms Bitcoin.Ledger.bip30Enforced

-- target BitcoinProofs.AF.PDW71.bip30DisconnectRelaxed_pair_row
#print axioms BitcoinProofs.AF.PDW71.bip30DisconnectRelaxed_pair_row

-- target BitcoinProofs.AF.PDW18.Coin_mk_eta
#print axioms BitcoinProofs.AF.PDW18.Coin_mk_eta

-- target Bitcoin.TxValidation.checkTxInputs_ok_conservation
#print axioms Bitcoin.TxValidation.checkTxInputs_ok_conservation

-- target BitcoinProofs.AF.PDW14.blockSequenceLocksOk_all
#print axioms BitcoinProofs.AF.PDW14.blockSequenceLocksOk_all

-- target Bitcoin.Ledger.spentUndo_hit
#print axioms Bitcoin.Ledger.spentUndo_hit

-- target Bitcoin.Block.Params.replayUndos
#print axioms Bitcoin.Block.Params.replayUndos

-- target BitcoinProofs.AF.PDW23.disconnectRelevant_row_iff
#print axioms BitcoinProofs.AF.PDW23.disconnectRelevant_row_iff

-- target BitcoinProofs.AF.PDW23.undoCountOk_row_iff
#print axioms BitcoinProofs.AF.PDW23.undoCountOk_row_iff

-- target BitcoinProofs.AF.PDW49.connectGenesis_utxo_face
#print axioms BitcoinProofs.AF.PDW49.connectGenesis_utxo_face

-- target BitcoinProofs.AF.PDW68.emptyUtxo_row
#print axioms BitcoinProofs.AF.PDW68.emptyUtxo_row

-- target BitcoinProofs.AF.PDW23.genesisHeader_row
#print axioms BitcoinProofs.AF.PDW23.genesisHeader_row

-- target BitcoinProofs.AF.PDW16.genesisCoinbaseTx_coinbase
#print axioms BitcoinProofs.AF.PDW16.genesisCoinbaseTx_coinbase

-- target BitcoinProofs.AF.PDW24.workOf_zero_invalid
#print axioms BitcoinProofs.AF.PDW24.workOf_zero_invalid

-- target BitcoinProofs.AF.PDW24.chainWork_cons_eq
#print axioms BitcoinProofs.AF.PDW24.chainWork_cons_eq

-- target BitcoinProofs.AF.PDW24.mostWork?_maximality
#print axioms BitcoinProofs.AF.PDW24.mostWork?_maximality

-- target BitcoinProofs.AF.PDW30.betterThan_tie_earlier
#print axioms BitcoinProofs.AF.PDW30.betterThan_tie_earlier

-- target BitcoinProofs.AF.PDW30.switchTip_strict
#print axioms BitcoinProofs.AF.PDW30.switchTip_strict

-- target BitcoinProofs.AF.PDW30.reorgPlan_disconnect
#print axioms BitcoinProofs.AF.PDW30.reorgPlan_disconnect

-- target BitcoinProofs.AF.PDW30.prunedCandidates_subset
#print axioms BitcoinProofs.AF.PDW30.prunedCandidates_subset

-- target BitcoinProofs.AF.PDW8.submitVerdict_duplicate_invalid_iff
#print axioms BitcoinProofs.AF.PDW8.submitVerdict_duplicate_invalid_iff

-- target BitcoinProofs.AF.PDW46.bestInvalidWork_ge_mem
#print axioms BitcoinProofs.AF.PDW46.bestInvalidWork_ge_mem

-- target BitcoinProofs.AF.PDW8.minChainWorkOk_true_iff
#print axioms BitcoinProofs.AF.PDW8.minChainWorkOk_true_iff

-- target BitcoinProofs.AF.PDW46.assumevalidSkipped_below_guard
#print axioms BitcoinProofs.AF.PDW46.assumevalidSkipped_below_guard

-- target BitcoinProofs.AF.PDW49.scriptVerdicts_serial
#print axioms BitcoinProofs.AF.PDW49.scriptVerdicts_serial

-- target Bitcoin.Block.Params.mutated64ByteTx
#print axioms Bitcoin.Block.Params.mutated64ByteTx

-- target BitcoinProofs.AF.PDW8.signetDefaultChallenge_script_shape
#print axioms BitcoinProofs.AF.PDW8.signetDefaultChallenge_script_shape

-- target Bitcoin.Block.Params.memoVerdict
#print axioms Bitcoin.Block.Params.memoVerdict

-- target Bitcoin.Block.Params.reservedValueFill
#print axioms Bitcoin.Block.Params.reservedValueFill

-- target Bitcoin.Block.Params.merklePathRoot
#print axioms Bitcoin.Block.Params.merklePathRoot

-- target BitcoinProofs.AF.PDW16.timestamp_window_eq_max_future
#print axioms BitcoinProofs.AF.PDW16.timestamp_window_eq_max_future

-- target BitcoinProofs.AF.PDW45.isWitnessProgram_template
#print axioms BitcoinProofs.AF.PDW45.isWitnessProgram_template

-- target BitcoinProofs.AF.PDW65.witnessMalleated_bare
#print axioms BitcoinProofs.AF.PDW65.witnessMalleated_bare

-- target BitcoinProofs.AF.PDW65.p2shInner_witnessMalleatedP2SH
#print axioms BitcoinProofs.AF.PDW65.p2shInner_witnessMalleatedP2SH

-- target BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_p2wpkh_arity
#print axioms BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_p2wpkh_arity

-- target BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wpkh_script
#print axioms BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wpkh_script

-- target BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_p2wsh_empty_witness
#print axioms BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_p2wsh_empty_witness

-- target BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_p2wsh_mismatch
#print axioms BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_p2wsh_mismatch

-- target BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_wrongLength
#print axioms BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_wrongLength

-- target Bitcoin.SigHash.witnessScriptSizeOk_spec
#print axioms Bitcoin.SigHash.witnessScriptSizeOk_spec

-- target BitcoinProofs.AF.PDW65.executeWitnessScript_witnessV0_cleanstack
#print axioms BitcoinProofs.AF.PDW65.executeWitnessScript_witnessV0_cleanstack

-- target BitcoinProofs.AF.PDW65.witnessUnexpected_nonWitness
#print axioms BitcoinProofs.AF.PDW65.witnessUnexpected_nonWitness

-- target Bitcoin.Activation.Flags.witness_implies_p2sh
#print axioms Bitcoin.Activation.Flags.witness_implies_p2sh
-- drift Bitcoin.Activation.Flags.witness_implies_p2sh -> Bitcoin.Activation.witness_implies_p2sh
#print axioms Bitcoin.Activation.witness_implies_p2sh

-- target BitcoinProofs.AF.PDW51.blockWeight_witness_discount
#print axioms BitcoinProofs.AF.PDW51.blockWeight_witness_discount

-- target BitcoinProofs.AF.PDW20.witness_scale_factor_eq_four
#print axioms BitcoinProofs.AF.PDW20.witness_scale_factor_eq_four

-- target Bitcoin.DataLaws.Interface.vsize
#print axioms Bitcoin.DataLaws.Interface.vsize
-- drift Bitcoin.DataLaws.Interface.vsize -> Bitcoin.DataLaws.vsize
#print axioms Bitcoin.DataLaws.vsize

-- target BitcoinProofs.AF.PDW44.sigOpCost_legacy_scale
#print axioms BitcoinProofs.AF.PDW44.sigOpCost_legacy_scale

-- target BitcoinProofs.AF.PDW44.sigOpCost_p2sh_step
#print axioms BitcoinProofs.AF.PDW44.sigOpCost_p2sh_step

-- target Bitcoin.Interpreter.SigOps.sigOpCost_witness_scale_one
#print axioms Bitcoin.Interpreter.SigOps.sigOpCost_witness_scale_one

-- target Bitcoin.Interpreter.SigOps.witnessSigOps_p2wpkh
#print axioms Bitcoin.Interpreter.SigOps.witnessSigOps_p2wpkh

-- target BitcoinProofs.AF.PDW19.witnessSigOps_p2wsh
#print axioms BitcoinProofs.AF.PDW19.witnessSigOps_p2wsh

-- target BitcoinProofs.AF.PDW44.p2shWitnessSigOps_p2wpkh
#print axioms BitcoinProofs.AF.PDW44.p2shWitnessSigOps_p2wpkh

-- target Bitcoin.Interpreter.SigOps.witnessSigOps_future_zero
#print axioms Bitcoin.Interpreter.SigOps.witnessSigOps_future_zero

-- target BitcoinProofs.AF.PDW76.witnessCommitmentOutput_some_spec
#print axioms BitcoinProofs.AF.PDW76.witnessCommitmentOutput_some_spec

-- target BitcoinProofs.AF.PDW58.witnessCommitmentOk_iff
#print axioms BitcoinProofs.AF.PDW58.witnessCommitmentOk_iff

-- target BitcoinProofs.AF.PDW76.commitmentNonceOk_eq_true
#print axioms BitcoinProofs.AF.PDW76.commitmentNonceOk_eq_true

-- target BitcoinProofs.AF.PDW43b.witnessMerkleRoot_cons
#print axioms BitcoinProofs.AF.PDW43b.witnessMerkleRoot_cons

-- target BitcoinProofs.AF.PDW43b.commitmentGate_no_witness
#print axioms BitcoinProofs.AF.PDW43b.commitmentGate_no_witness

-- target BitcoinProofs.AF.PDW43b.commitmentGate_witness_true_iff
#print axioms BitcoinProofs.AF.PDW43b.commitmentGate_witness_true_iff

-- target Bitcoin.Activation.Flags.buried_heights_mainnet
#print axioms Bitcoin.Activation.Flags.buried_heights_mainnet
-- drift Bitcoin.Activation.Flags.buried_heights_mainnet -> Bitcoin.Activation.buried_heights_mainnet
#print axioms Bitcoin.Activation.buried_heights_mainnet

-- target Bitcoin.Activation.segwitBip9Deployment
#print axioms Bitcoin.Activation.segwitBip9Deployment

-- target BitcoinProofs.AF.PDW69.decTxCore_extended_roundtrip_row
#print axioms BitcoinProofs.AF.PDW69.decTxCore_extended_roundtrip_row

-- target BitcoinProofs.AF.PDW34.encTxL_witness_marker_flag
#print axioms BitcoinProofs.AF.PDW34.encTxL_witness_marker_flag

-- target BitcoinProofs.AF.PDW34.decTxCore_flag_one_superfluous
#print axioms BitcoinProofs.AF.PDW34.decTxCore_flag_one_superfluous

-- target BitcoinProofs.AF.PDW34.decTxCore_flag_even_unknown
#print axioms BitcoinProofs.AF.PDW34.decTxCore_flag_even_unknown

-- target BitcoinProofs.AF.PDW76.wtxidOf_noWitness
#print axioms BitcoinProofs.AF.PDW76.wtxidOf_noWitness

-- target Bitcoin.SigHash.signatureHashBip143Impl
#print axioms Bitcoin.SigHash.signatureHashBip143Impl

-- target Bitcoin.SigHash.Theorems.hashPrevoutsL_cases
#print axioms Bitcoin.SigHash.Theorems.hashPrevoutsL_cases
-- drift Bitcoin.SigHash.Theorems.hashPrevoutsL_cases -> Bitcoin.SigHash.hashPrevoutsL_cases
#print axioms Bitcoin.SigHash.hashPrevoutsL_cases

-- target Bitcoin.SigHash.Theorems.hashSequenceL_cases
#print axioms Bitcoin.SigHash.Theorems.hashSequenceL_cases
-- drift Bitcoin.SigHash.Theorems.hashSequenceL_cases -> Bitcoin.SigHash.hashSequenceL_cases
#print axioms Bitcoin.SigHash.hashSequenceL_cases

-- target Bitcoin.SigHash.Theorems.hashOutputsL_cases
#print axioms Bitcoin.SigHash.Theorems.hashOutputsL_cases
-- drift Bitcoin.SigHash.Theorems.hashOutputsL_cases -> Bitcoin.SigHash.hashOutputsL_cases
#print axioms Bitcoin.SigHash.hashOutputsL_cases

-- target Bitcoin.SigHash.Theorems.bip143_single_oor
#print axioms Bitcoin.SigHash.Theorems.bip143_single_oor
-- drift Bitcoin.SigHash.Theorems.bip143_single_oor -> Bitcoin.SigHash.bip143_single_oor
#print axioms Bitcoin.SigHash.bip143_single_oor

-- target Bitcoin.SigHash.Theorems.p2wpkhScriptCodeL_spec
#print axioms Bitcoin.SigHash.Theorems.p2wpkhScriptCodeL_spec
-- drift Bitcoin.SigHash.Theorems.p2wpkhScriptCodeL_spec -> Bitcoin.SigHash.p2wpkhScriptCodeL_spec
#print axioms Bitcoin.SigHash.p2wpkhScriptCodeL_spec

-- target BitcoinProofs.AF.PDW98.evalChecksigPreTapscript_scriptCode_extract
#print axioms BitcoinProofs.AF.PDW98.evalChecksigPreTapscript_scriptCode_extract

-- target BitcoinProofs.AF.PDW62b.evalChecksigPreTapscript_nonbase
#print axioms BitcoinProofs.AF.PDW62b.evalChecksigPreTapscript_nonbase

-- target BitcoinProofs.AF.PDW23.bip143MsgL_amount_field
#print axioms BitcoinProofs.AF.PDW23.bip143MsgL_amount_field

-- target BitcoinProofs.AF.PDW23.bip143MsgL_hashtype_tail
#print axioms BitcoinProofs.AF.PDW23.bip143MsgL_hashtype_tail

-- target BitcoinProofs.AF.PDW34.dshaL_is_sha256d
#print axioms BitcoinProofs.AF.PDW34.dshaL_is_sha256d

-- target Bitcoin.Crypto.Seam.Entry.ecdsaEntry_pops_hashtype
#print axioms Bitcoin.Crypto.Seam.Entry.ecdsaEntry_pops_hashtype

-- target Bitcoin.Crypto.Seam.Entry.ecdsaEntry_empty_sig_false
#print axioms Bitcoin.Crypto.Seam.Entry.ecdsaEntry_empty_sig_false

-- target Bitcoin.Crypto.Seam.Entry.ecdsaEntry_witnessV0_missing_amount_false
#print axioms Bitcoin.Crypto.Seam.Entry.ecdsaEntry_witnessV0_missing_amount_false

-- target BitcoinProofs.AF.PDW93.witnessPubkeyType_off
#print axioms BitcoinProofs.AF.PDW93.witnessPubkeyType_off

-- target BitcoinProofs.AF.PDW66.cmsCleanup_no_nullfail
#print axioms BitcoinProofs.AF.PDW66.cmsCleanup_no_nullfail

-- target BitcoinProofs.AF.PDW66.cmsCleanup_nullfail_error
#print axioms BitcoinProofs.AF.PDW66.cmsCleanup_nullfail_error

-- target Bitcoin.Activation.Flags.dersig_flag_flow
#print axioms Bitcoin.Activation.Flags.dersig_flag_flow
-- drift Bitcoin.Activation.Flags.dersig_flag_flow -> Bitcoin.Activation.dersig_flag_flow
#print axioms Bitcoin.Activation.dersig_flag_flow

-- target BitcoinProofs.AF.PDW98.stepBody_if_tapscript_minimalIf
#print axioms BitcoinProofs.AF.PDW98.stepBody_if_tapscript_minimalIf

-- target Bitcoin.Activation.Flags.nulldummy_flag_flow
#print axioms Bitcoin.Activation.Flags.nulldummy_flag_flow
-- drift Bitcoin.Activation.Flags.nulldummy_flag_flow -> Bitcoin.Activation.nulldummy_flag_flow
#print axioms Bitcoin.Activation.nulldummy_flag_flow

-- target Bitcoin.Interpreter.Defs.stepBody.checkMultiSig
#print axioms Bitcoin.Interpreter.Defs.stepBody.checkMultiSig
-- drift Bitcoin.Interpreter.Defs.stepBody.checkMultiSig -> Bitcoin.Interpreter.stepBody.checkMultiSig
#print axioms Bitcoin.Interpreter.stepBody.checkMultiSig

-- target Bitcoin.SigHash.Theorems.signatureHashBip143Impl_determined
#print axioms Bitcoin.SigHash.Theorems.signatureHashBip143Impl_determined
-- drift Bitcoin.SigHash.Theorems.signatureHashBip143Impl_determined -> Bitcoin.SigHash.signatureHashBip143Impl_determined
#print axioms Bitcoin.SigHash.signatureHashBip143Impl_determined

-- target Bitcoin.DataLaws.Interface.serWitness
#print axioms Bitcoin.DataLaws.Interface.serWitness
-- drift Bitcoin.DataLaws.Interface.serWitness -> Bitcoin.DataLaws.serWitness
#print axioms Bitcoin.DataLaws.serWitness

-- target BitcoinProofs.AF.PDW67b.verifyInput_taproot_unjudged
#print axioms BitcoinProofs.AF.PDW67b.verifyInput_taproot_unjudged

-- target BitcoinProofs.AF.PDW25.isPayToTaproot_p2trScript_iff
#print axioms BitcoinProofs.AF.PDW25.isPayToTaproot_p2trScript_iff

-- target BitcoinProofs.AF.PDW25.taprootLane_gate_off
#print axioms BitcoinProofs.AF.PDW25.taprootLane_gate_off

-- target Bitcoin.Crypto.Taproot.Program.taprootLane_p2sh_wrapped
#print axioms Bitcoin.Crypto.Taproot.Program.taprootLane_p2sh_wrapped

-- target BitcoinProofs.AF.PDW41.isPayToAnchor_iff
#print axioms BitcoinProofs.AF.PDW41.isPayToAnchor_iff

-- target BitcoinProofs.AF.PDW25.isAnnex_def
#print axioms BitcoinProofs.AF.PDW25.isAnnex_def

-- target BitcoinProofs.AF.PDW41.annexHash_row
#print axioms BitcoinProofs.AF.PDW41.annexHash_row

-- target BitcoinProofs.AF.PDW25.classifySpend_one_keyPath
#print axioms BitcoinProofs.AF.PDW25.classifySpend_one_keyPath

-- target BitcoinProofs.AF.PDW25.classifySpend_many_scriptPath
#print axioms BitcoinProofs.AF.PDW25.classifySpend_many_scriptPath

-- target BitcoinProofs.AF.PDW18.controlBlockSizeOk_sizes
#print axioms BitcoinProofs.AF.PDW18.controlBlockSizeOk_sizes

-- target BitcoinProofs.AF.PDW41.leafVersionOf_row
#print axioms BitcoinProofs.AF.PDW41.leafVersionOf_row

-- target BitcoinProofs.AF.PDW35.parityOk_row
#print axioms BitcoinProofs.AF.PDW35.parityOk_row

-- target BitcoinProofs.AF.PDW56.tapLeaf_wire_eq
#print axioms BitcoinProofs.AF.PDW56.tapLeaf_wire_eq

-- target BitcoinProofs.AF.PDW35.tapBranch_row
#print axioms BitcoinProofs.AF.PDW35.tapBranch_row

-- target BitcoinProofs.AF.PDW35.taprootMerkleRoot_row
#print axioms BitcoinProofs.AF.PDW35.taprootMerkleRoot_row

-- target BitcoinProofs.AF.PDW56.taptweak_some_face
#print axioms BitcoinProofs.AF.PDW56.taptweak_some_face

-- target BitcoinProofs.AF.PDW56.tweakPoint_commitment_face
#print axioms BitcoinProofs.AF.PDW56.tweakPoint_commitment_face

-- target BitcoinProofs.AF.PDW56.tweakPoint_overflow_face
#print axioms BitcoinProofs.AF.PDW56.tweakPoint_overflow_face

-- target BitcoinProofs.AF.PDW35.internalKeyOk_row
#print axioms BitcoinProofs.AF.PDW35.internalKeyOk_row

-- target Bitcoin.Crypto.Taproot.LeafDispatch.leafVersionSpend
#print axioms Bitcoin.Crypto.Taproot.LeafDispatch.leafVersionSpend

-- target BitcoinProofs.AF.PDW41.validationWeightInit_row
#print axioms BitcoinProofs.AF.PDW41.validationWeightInit_row

-- target BitcoinProofs.AF.PDW74.evalChecksigTapscript_unknown_pubkey_discouraged
#print axioms BitcoinProofs.AF.PDW74.evalChecksigTapscript_unknown_pubkey_discouraged

-- target BitcoinProofs.AF.PDW35.hashtypeValid_row
#print axioms BitcoinProofs.AF.PDW35.hashtypeValid_row

-- target Bitcoin.Crypto.Taproot.sighashTaproot_epoch
#print axioms Bitcoin.Crypto.Taproot.sighashTaproot_epoch

-- target BitcoinProofs.AF.PDW33b.sigMsgTaproot_exists_row
#print axioms BitcoinProofs.AF.PDW33b.sigMsgTaproot_exists_row

-- target BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_prevouts
#print axioms BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_prevouts

-- target BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_amounts
#print axioms BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_amounts

-- target BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_scripts
#print axioms BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_scripts

-- target BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_sequences
#print axioms BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_sequences

-- target BitcoinProofs.AF.PDW37.sigMsgTaproot_noAcp_outputs_gate
#print axioms BitcoinProofs.AF.PDW37.sigMsgTaproot_noAcp_outputs_gate

-- target BitcoinProofs.AF.PDW33b.spendType_row
#print axioms BitcoinProofs.AF.PDW33b.spendType_row

-- target Bitcoin.Crypto.Taproot.acpSlice_acp
#print axioms Bitcoin.Crypto.Taproot.acpSlice_acp

-- target Bitcoin.Crypto.Taproot.acpSlice_notACP
#print axioms Bitcoin.Crypto.Taproot.acpSlice_notACP

-- target BitcoinProofs.AF.PDW33b.singleSlice_some_row
#print axioms BitcoinProofs.AF.PDW33b.singleSlice_some_row

-- target BitcoinProofs.AF.PDW41.extSlice_tapscript_row
#print axioms BitcoinProofs.AF.PDW41.extSlice_tapscript_row

-- target BitcoinProofs.AF.PDW33b.extSlice_tapscript_some_row
#print axioms BitcoinProofs.AF.PDW33b.extSlice_tapscript_some_row

-- target BitcoinProofs.AF.PDW95.extSlice_requires_codesepPosInit
#print axioms BitcoinProofs.AF.PDW95.extSlice_requires_codesepPosInit

-- target Bitcoin.Crypto.Taproot.sighashTaproot_size
#print axioms Bitcoin.Crypto.Taproot.sighashTaproot_size

-- target Bitcoin.Crypto.Taproot.Program.taggedHash_unfold
#print axioms Bitcoin.Crypto.Taproot.Program.taggedHash_unfold

-- target Bitcoin.Crypto.Schnorr.Verify.eOf
#print axioms Bitcoin.Crypto.Schnorr.Verify.eOf

-- target Bitcoin.Crypto.Curve.Secp.liftX_onCurve
#print axioms Bitcoin.Crypto.Curve.Secp.liftX_onCurve

-- target Bitcoin.Crypto.Schnorr.Verify.verifyImpl
#print axioms Bitcoin.Crypto.Schnorr.Verify.verifyImpl

-- target BitcoinProofs.AF.PDW95.tpr052_verifyImpl_iff
#print axioms BitcoinProofs.AF.PDW95.tpr052_verifyImpl_iff

-- target BitcoinProofs.AF.PDW42.liftX_x_preserved
#print axioms BitcoinProofs.AF.PDW42.liftX_x_preserved

-- target Bitcoin.Script.Tapscript.evalChecksigDispatch_tapscript_arm
#print axioms Bitcoin.Script.Tapscript.evalChecksigDispatch_tapscript_arm

-- target Bitcoin.Script.Tapscript.checksigAddStep_result
#print axioms Bitcoin.Script.Tapscript.checksigAddStep_result

-- target Bitcoin.Script.Tapscript.checksigadd_outside_tapscript
#print axioms Bitcoin.Script.Tapscript.checksigadd_outside_tapscript

-- target Bitcoin.Script.Tapscript.checksigadd_num4_bound
#print axioms Bitcoin.Script.Tapscript.checksigadd_num4_bound

-- target BitcoinProofs.AF.PDW93.isOpSuccessWire_iff
#print axioms BitcoinProofs.AF.PDW93.isOpSuccessWire_iff

-- target Bitcoin.Script.Tapscript.executeWitnessScript_success_discourage
#print axioms Bitcoin.Script.Tapscript.executeWitnessScript_success_discourage

-- target Bitcoin.Script.Tapscript.minimalif_tapscript_unconditional
#print axioms Bitcoin.Script.Tapscript.minimalif_tapscript_unconditional

-- target Bitcoin.Script.Tapscript.evalScriptBytes_tapscript_no_script_size
#print axioms Bitcoin.Script.Tapscript.evalScriptBytes_tapscript_no_script_size

-- target Bitcoin.Script.Tapscript.tapscript_opcount_guard_off
#print axioms Bitcoin.Script.Tapscript.tapscript_opcount_guard_off

-- target BitcoinProofs.AF.PDW93.executeWitnessScript_stack_limit
#print axioms BitcoinProofs.AF.PDW93.executeWitnessScript_stack_limit

-- target BitcoinProofs.AF.PDW78.tpr067_stepChecked_cap
#print axioms BitcoinProofs.AF.PDW78.tpr067_stepChecked_cap

-- target BitcoinProofs.AF.PDW78.tpr068_ok_push_bound
#print axioms BitcoinProofs.AF.PDW78.tpr068_ok_push_bound

-- target BitcoinProofs.AF.PDW44.witnessSigOps_v1_zero
#print axioms BitcoinProofs.AF.PDW44.witnessSigOps_v1_zero

-- target Bitcoin.Crypto.Taproot.Program.validationWeightInit_annex_included
#print axioms Bitcoin.Crypto.Taproot.Program.validationWeightInit_annex_included

-- target Bitcoin.Crypto.Seam.Entry.schnorrEntry_execData_plumbed
#print axioms Bitcoin.Crypto.Seam.Entry.schnorrEntry_execData_plumbed

-- target Bitcoin.Script.Tapscript.cltv_negative_tapscript
#print axioms Bitcoin.Script.Tapscript.cltv_negative_tapscript

-- target Bitcoin.Script.Tapscript.disabledWire_success
#print axioms Bitcoin.Script.Tapscript.disabledWire_success

-- target BitcoinProofs.AF.PDW33b.taprootBip9Deployment_row
#print axioms BitcoinProofs.AF.PDW33b.taprootBip9Deployment_row

-- target Bitcoin.Activation.taproot_exception_block_flags
#print axioms Bitcoin.Activation.taproot_exception_block_flags

-- target Bitcoin.Activation.taproot_always_on_base
#print axioms Bitcoin.Activation.taproot_always_on_base

-- target BitcoinProofs.AF.PDW88.deploymentActiveAt_pprev_row
#print axioms BitcoinProofs.AF.PDW88.deploymentActiveAt_pprev_row

-- target BitcoinProofs.AF.PDW56.taptweak_none_face
#print axioms BitcoinProofs.AF.PDW56.taptweak_none_face

-- target Bitcoin.Activation.tapscript_reimports_policy
#print axioms Bitcoin.Activation.tapscript_reimports_policy

-- target BitcoinProofs.AF.PDW93.checkSigEncoding_lowS_off
#print axioms BitcoinProofs.AF.PDW93.checkSigEncoding_lowS_off

-- target BitcoinProofs.AF.PDW63b.strictenc_policy_only
#print axioms BitcoinProofs.AF.PDW63b.strictenc_policy_only

-- target BitcoinProofs.AF.PDW63b.minimaldata_policy_only
#print axioms BitcoinProofs.AF.PDW63b.minimaldata_policy_only

-- target BitcoinProofs.AF.PDW63b.minimalif_policy_and_tapscript
#print axioms BitcoinProofs.AF.PDW63b.minimalif_policy_and_tapscript

-- target BitcoinProofs.AF.PDW63b.nullfail_policy_only
#print axioms BitcoinProofs.AF.PDW63b.nullfail_policy_only

-- target BitcoinProofs.AF.PDW63b.cleanstack_policy_and_tapscript
#print axioms BitcoinProofs.AF.PDW63b.cleanstack_policy_and_tapscript

-- target BitcoinProofs.AF.PDW57b.constScriptCode_not_consensus
#print axioms BitcoinProofs.AF.PDW57b.constScriptCode_not_consensus

-- target BitcoinProofs.AF.PDW89.witnessPubKeyType_rejects_uncompressed
#print axioms BitcoinProofs.AF.PDW89.witnessPubKeyType_rejects_uncompressed

-- target Bitcoin.Crypto.Curve.Secp.G_onCurve
#print axioms Bitcoin.Crypto.Curve.Secp.G_onCurve

-- target Bitcoin.Crypto.Curve.Mod.invM_correct
#print axioms Bitcoin.Crypto.Curve.Mod.invM_correct

-- target Bitcoin.Crypto.Curve.Mod.expBits_eq_pow_mod
#print axioms Bitcoin.Crypto.Curve.Mod.expBits_eq_pow_mod

-- target BitcoinProofs.Crypto.CurveZMod.P_prime
#print axioms BitcoinProofs.Crypto.CurveZMod.P_prime

-- target BitcoinProofs.AF.PDW69TxCheck.parsePubKey_wrong_length
#print axioms BitcoinProofs.AF.PDW69TxCheck.parsePubKey_wrong_length

-- target BitcoinProofs.AF.PDW69TxCheck.parseDerLax_badHead
#print axioms BitcoinProofs.AF.PDW69TxCheck.parseDerLax_badHead

-- target BitcoinProofs.AF.PDW95.sgn107_verifyImpl_mod_n_invariant
#print axioms BitcoinProofs.AF.PDW95.sgn107_verifyImpl_mod_n_invariant

-- target BitcoinProofs.AF.PDW74.isLowDERSignature_true_iff
#print axioms BitcoinProofs.AF.PDW74.isLowDERSignature_true_iff

-- target BitcoinProofs.AF.PDW58.parseDerLax_tag_none
#print axioms BitcoinProofs.AF.PDW58.parseDerLax_tag_none

-- target BitcoinProofs.AF.PDW58.parseDerLax_empty_row
#print axioms BitcoinProofs.AF.PDW58.parseDerLax_empty_row

-- target BitcoinProofs.AF.PDW95.sgn110_verifyImpl_iff
#print axioms BitcoinProofs.AF.PDW95.sgn110_verifyImpl_iff

-- target BitcoinProofs.AF.PDW42B.isDERSignature_len
#print axioms BitcoinProofs.AF.PDW42B.isDERSignature_len

