import Bitcoin.Data.Basic
import Bitcoin.Chain.Basic
import Bitcoin.Crypto.Seam.Interface
import Bitcoin.Crypto.Seam.Der
import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Crypto.Seam.Mock
import Bitcoin.Crypto.Curve.Mod
import Bitcoin.Crypto.Curve.Secp
import Bitcoin.Crypto.Curve.Interface
import Bitcoin.Crypto.Ecdsa.Der
import Bitcoin.Crypto.Ecdsa.Verify
import Bitcoin.Conservation.Interface
import Bitcoin.TxValidation.Interface
import Bitcoin.DataLaws.Interface
import Bitcoin.Numeric.Amount
import Bitcoin.Script.Parser.Interface
import Bitcoin.Interpreter.Interface
import Bitcoin.Serialization.Interface
-- W15: proof-side theorem modules (the `proofs` package requires `core`,
-- so probing from the proofs env sees BOTH packages).
import BitcoinProofs.Theorems.ParserCor
import BitcoinProofs.Theorems.FlagsCor
import BitcoinProofs.Theorems.NumericCor
import BitcoinProofs.Theorems.LedgerCor
import BitcoinProofs.Theorems.InterpCor
-- W14b: curve group law + ECDSA-lax (ZMod Pratt certificate lives proofs-side).
import BitcoinProofs.Crypto.CurveZMod

/-!
# Axiom probe — the input of the axiom-manifest gate

Every public theorem whose axiom fingerprint must be CI-pinned gets a
`#print axioms` line here. W15 grows this file with the theorem
portfolio; the manifest (`spec/db/axiom-manifest.txt`) is diffed in CI
(`scripts/axiom_manifest.sh`), and headline theorems additionally get
`#guard_msgs in #print axioms` pins inside their own modules (D2 L3).

(W08 note: this file previously did a root `import Bitcoin`, which made
the G2 gate hostage to every in-flight interface edit anywhere in the
tree. It now imports exactly the modules owning the pinned theorems.)
-/

-- C1 bootstrap theorems (regression-pinned since the PoC):
#print axioms Bitcoin.Data.moneyRange_zero
#print axioms Bitcoin.Chain.compactTarget_difficulty_one
#print axioms Bitcoin.Crypto.Seam.stubChecker_deterministic

-- Review-2 interface theorems that are already proof-backed (skeleton):
-- (added here as W02+ land sorry-free proofs; sorry-stubbed statements
-- are deliberately NOT listed — sorryAx drift there is expected.)

-- W03 (data-type laws): the sorryAx entries are the transitive footprints
-- of W02's `totalSize` and W13's `sha256d` opaque stubs. The W04-routed
-- CScriptNum contract statement was discharged by W04 (now axiom-light).
#print axioms Bitcoin.DataLaws.isNull_spec
#print axioms Bitcoin.DataLaws.isNull_bytesBEq
#print axioms Bitcoin.DataLaws.seqRelative_eq_mod
#print axioms Bitcoin.DataLaws.seqIsDisabled_iff
#print axioms Bitcoin.DataLaws.seqIsTimeBased_iff
#print axioms Bitcoin.DataLaws.bip68Enabled_iff
#print axioms Bitcoin.DataLaws.testBit31_iff
#print axioms Bitcoin.DataLaws.seqHeightLock_last_invalid
#print axioms Bitcoin.DataLaws.scriptNum_four_byte_boundary
#print axioms Bitcoin.DataLaws.txWeight_formula
#print axioms Bitcoin.DataLaws.txid_witness_independence
#print axioms Bitcoin.DataLaws.wtxid_eq_txid_iff_no_witness
#print axioms Bitcoin.DataLaws.final_locktime_zero
#print axioms Bitcoin.DataLaws.final_sequence_final

-- W08 (conservation / T1): all sorry-free, pinned in-module as well.
#print axioms Bitcoin.Conservation.moneyRange_eq_true_iff
#print axioms Bitcoin.Conservation.single_tx_conservation
#print axioms Bitcoin.Conservation.single_tx_fee_in_range
#print axioms Bitcoin.Conservation.subsidy_epoch33_zero
#print axioms Bitcoin.Conservation.subsidy_epoch32_one

-- W10 (stateless tx validation): the theorem portfolio of
-- Bitcoin.TxValidation.Interface — every public theorem axiom-pinned.
#print axioms Bitcoin.TxValidation.coinHeightOfCode_pack
#print axioms Bitcoin.TxValidation.coinIsCoinbaseOfCode_pack
#print axioms Bitcoin.TxValidation.coinbase_maturity_boundary
#print axioms Bitcoin.TxValidation.checkTxInputs_ok
#print axioms Bitcoin.TxValidation.foldl_value_sum
#print axioms Bitcoin.TxValidation.getValueOut_eq_plainSum
#print axioms Bitcoin.TxValidation.checkOutputs_ok_plain
#print axioms Bitcoin.TxValidation.checkTransaction_ok_getValueOut_moneyRange
#print axioms Bitcoin.TxValidation.checkTransaction_ok_no_dup_prevouts
#print axioms Bitcoin.TxValidation.haveInputs_congr
#print axioms Bitcoin.TxValidation.inputValuesLoop_congr
#print axioms Bitcoin.TxValidation.checkTxInputs_congr
#print axioms Bitcoin.TxValidation.prevHeightData_congr
#print axioms Bitcoin.TxValidation.bip68HeightOk_congr
#print axioms Bitcoin.TxValidation.validateTx_total
#print axioms Bitcoin.TxValidation.validateTx_stateless_prefix
#print axioms Bitcoin.TxValidation.validateTx_fee_consistent
#print axioms Bitcoin.TxValidation.validateTx_utxo_extensional
#print axioms Bitcoin.TxValidation.duplicate_inputs_rejected
#print axioms Bitcoin.TxValidation.heightLockOf_some
#print axioms Bitcoin.TxValidation.heightLockOf_none_of_disabled
#print axioms Bitcoin.TxValidation.heightLockOf_none_of_time
#print axioms Bitcoin.TxValidation.heightLockOf_spec
#print axioms Bitcoin.TxValidation.timeLockOf_some
#print axioms Bitcoin.TxValidation.timeLockOf_none_of_disabled
#print axioms Bitcoin.TxValidation.timeLockOf_none_of_height
#print axioms Bitcoin.TxValidation.timeLockOf_spec
#print axioms Bitcoin.TxValidation.seqLockStep_fst_lt
#print axioms Bitcoin.TxValidation.seqLockStep_snd_lt
#print axioms Bitcoin.TxValidation.seqLockFold_height
#print axioms Bitcoin.TxValidation.seqLockFold_time
#print axioms Bitcoin.TxValidation.calculateSequenceLocks_enabled
#print axioms Bitcoin.TxValidation.calculateSequenceLocks_disabled
#print axioms Bitcoin.TxValidation.evaluateSequenceLocks_eq
#print axioms Bitcoin.TxValidation.sequenceLocksOk_iff
#print axioms Bitcoin.TxValidation.bip68HeightOk_iff
#print axioms Bitcoin.TxValidation.foldl_coin_add
#print axioms Bitcoin.TxValidation.inputValuesLoop_ok_sum
#print axioms Bitcoin.TxValidation.totalIn_eq_foldl
#print axioms Bitcoin.TxValidation.checkTxInputs_ok_conservation

-- W04 (ScriptNum + amount arithmetic): sorry-free; freeze/decide + propext.
#print axioms Bitcoin.Numeric.scriptNum_roundtrip
#print axioms Bitcoin.Numeric.scriptNum_four_byte_rule
#print axioms Bitcoin.Numeric.scriptNum_minimal_reject
#print axioms Bitcoin.Numeric.moneyRange_iff
#print axioms Bitcoin.Numeric.fee_in_money_range
#print axioms Bitcoin.Numeric.feeOf_nonneg_iff
#print axioms Bitcoin.Numeric.castToBool_iff_setVchBE
#print axioms Bitcoin.Numeric.checkedSum_catches
#print axioms Bitcoin.Numeric.checkedSum_sound
#print axioms Bitcoin.Numeric.cve2010_5137_checkedSum_none
#print axioms Bitcoin.Numeric.cve2010_5137_wrapped

-- W05 (script parser): sorry-free; the probe imports the two parser
-- modules owning the pinned theorems (see the import header above).
#print axioms Bitcoin.Script.Parser.parseScript_terminates
#print axioms Bitcoin.Script.Parser.parse_serialize_roundtrip
#print axioms Bitcoin.Script.Parser.pushBytes_exact
#print axioms Bitcoin.Script.Parser.disabled_roundtrip
#print axioms Bitcoin.Script.Parser.parseFrom_roundtrip
#print axioms Bitcoin.Script.Parser.parseFrom_none_trunc
#print axioms Bitcoin.Script.Parser.parseFrom_shape
#print axioms Bitcoin.Script.Parser.getOp_serialize

-- W02 (serialization core): all sorry-free.
#print axioms Bitcoin.Serialization.decodeTx_encodeTx
#print axioms Bitcoin.Serialization.encodeTx_decodeTx
#print axioms Bitcoin.Serialization.decodeTx_no_superfluous_witness
#print axioms Bitcoin.Serialization.decodeBlockHeader_encodeBlockHeader
#print axioms Bitcoin.Serialization.decodeBlock_encodeBlock
#print axioms Bitcoin.Serialization.decTxCore_encTxL
#print axioms Bitcoin.Serialization.decTxCore_shape
#print axioms Bitcoin.Serialization.decCS_encCSL
#print axioms Bitcoin.Serialization.decCS_shape
#print axioms Bitcoin.Serialization.decHeaderL_enc
#print axioms Bitcoin.Serialization.bL_compactSizeEnc

-- W13 (crypto seam): hash floor, BIP66 DER gate, checker adapters, mock
-- table. All sorry-free; the seam contract theorems are the W13 deliverable.
#print axioms Bitcoin.Crypto.Seam.Hash.Sha256.pad_size_multiple
#print axioms Bitcoin.Crypto.Seam.Hash.sha256_size
#print axioms Bitcoin.Crypto.Seam.Hash.ripemd160_size
#print axioms Bitcoin.Crypto.Seam.Hash.sha256d_size
#print axioms Bitcoin.Crypto.Seam.Hash.hash160_size
#print axioms Bitcoin.Crypto.Seam.sha256d_size
#print axioms Bitcoin.Crypto.Seam.hash160_size
#print axioms Bitcoin.Crypto.Seam.checker_ext
#print axioms Bitcoin.Crypto.Seam.checker_eq_of_entry_eq
#print axioms Bitcoin.Crypto.Seam.scriptExecData_ext
#print axioms Bitcoin.Crypto.Seam.scriptExecData_default_fields
#print axioms Bitcoin.Crypto.Seam.Der.checkSignatureEncoding_empty
#print axioms Bitcoin.Crypto.Seam.Der.checkSignatureEncoding_dersig_iff
#print axioms Bitcoin.Crypto.Seam.Der.checkSignatureEncoding_lax
#print axioms Bitcoin.Crypto.Seam.Der.bip66_valid_accepted_everywhere
#print axioms Bitcoin.Crypto.Seam.Der.pubKeyLen_values
#print axioms Bitcoin.Crypto.Seam.Der.isValidPubKey_empty
#print axioms Bitcoin.Crypto.Seam.Entry.ecdsaEntry_execData_independent
#print axioms Bitcoin.Crypto.Seam.Entry.ecdsaEntry_empty_sig_false
#print axioms Bitcoin.Crypto.Seam.Entry.ecdsaEntry_badPubKey_false
#print axioms Bitcoin.Crypto.Seam.Entry.ecdsaEntry_pops_hashtype
#print axioms Bitcoin.Crypto.Seam.Entry.ecdsaEntry_witnessV0_missing_amount_false
#print axioms Bitcoin.Crypto.Seam.Entry.schnorrHashtype_none
#print axioms Bitcoin.Crypto.Seam.Entry.schnorrHashtype_64
#print axioms Bitcoin.Crypto.Seam.Entry.schnorrHashtype_65_default_rejected
#print axioms Bitcoin.Crypto.Seam.Entry.schnorrHashtype_65
#print axioms Bitcoin.Crypto.Seam.Entry.schnorrEntry_size_gate
#print axioms Bitcoin.Crypto.Seam.Entry.schnorrEntry_execData_plumbed
#print axioms Bitcoin.Crypto.Seam.Entry.schnorrEntry_pops_hashtype
#print axioms Bitcoin.Crypto.Seam.Entry.txCheckerOf_ecdsa
#print axioms Bitcoin.Crypto.Seam.Entry.txCheckerOf_schnorr
#print axioms Bitcoin.Crypto.Seam.Mock.bytesBEq_refl
#print axioms Bitcoin.Crypto.Seam.Mock.mockChecker_hit
#print axioms Bitcoin.Crypto.Seam.Mock.mockFind_skip
#print axioms Bitcoin.Crypto.Seam.Mock.mockFind_nil
#print axioms Bitcoin.Crypto.Seam.Mock.mockChecker_deterministic

-- W14b (secp256k1 curve group law + ECDSA-lax verify): modular
-- foundation, raw-layer group law, pubkey/liftX contract, DER parsers,
-- and the lax verifier's structural fail-closed theorems. All sorry-free.
#print axioms Bitcoin.Crypto.Curve.Mod.expBits_eq_pow_mod
#print axioms Bitcoin.Crypto.Curve.Mod.egcd_bezout
#print axioms Bitcoin.Crypto.Curve.Mod.invM_correct
#print axioms Bitcoin.Crypto.Curve.Mod.invM_lt
#print axioms Bitcoin.Crypto.Curve.Mod.expM_lt
#print axioms Bitcoin.Crypto.Curve.Secp.G_onCurve
#print axioms Bitcoin.Crypto.Curve.Secp.OnCurve_negN
#print axioms Bitcoin.Crypto.Curve.Secp.invP_zero
#print axioms Bitcoin.Crypto.Curve.Secp.invP_correct
#print axioms Bitcoin.Crypto.Curve.Secp.mulP_ok
#print axioms Bitcoin.Crypto.Curve.Secp.addP_ok
#print axioms Bitcoin.Crypto.Curve.Secp.liftX_ok
#print axioms Bitcoin.Crypto.Curve.Secp.liftX_snd
#print axioms Bitcoin.Crypto.Curve.Secp.liftX_even
#print axioms Bitcoin.Crypto.Curve.Secp.liftX_onCurve
#print axioms Bitcoin.Crypto.Ecdsa.Der.parseDerLax_nil
#print axioms Bitcoin.Crypto.Ecdsa.Der.isDERSignature_short
#print axioms Bitcoin.Crypto.Ecdsa.Verify.verifyImpl_sig_nil
#print axioms Bitcoin.Crypto.Ecdsa.Verify.verifyImpl_pk_nil

-- W15 (theorem portfolio, proof side): 45 sorry-free corollary theorems
-- over the C1 models (parser / activation flags / CScriptNum numerics /
-- stateless tx checks / structural-fuel interpreter), in
-- spec/proofs/BitcoinProofs/Theorems/. All pinned in-module (L3) too.
-- NOTE: the probe now spans both packages; axiom_manifest.sh runs it from
-- the `proofs` env, which sees `core` as a lake dependency.
#print axioms BitcoinProofs.Theorems.ParserCor.parseFrom_fuel_sufficient
#print axioms BitcoinProofs.Theorems.ParserCor.parseFrom_none_mono
#print axioms BitcoinProofs.Theorems.ParserCor.parseScript_fuel_indep
#print axioms BitcoinProofs.Theorems.ParserCor.parseScript_none_truncation
#print axioms BitcoinProofs.Theorems.ParserCor.parseScript_roundtrip_fuel
#print axioms BitcoinProofs.Theorems.ParserCor.parseScript_shape
#print axioms BitcoinProofs.Theorems.FlagsCor.flags_base_true
#print axioms BitcoinProofs.Theorems.FlagsCor.flags_taproot_iff
#print axioms BitcoinProofs.Theorems.FlagsCor.flags_p2sh_iff
#print axioms BitcoinProofs.Theorems.FlagsCor.flags_dersig_iff
#print axioms BitcoinProofs.Theorems.FlagsCor.flags_cltv_iff
#print axioms BitcoinProofs.Theorems.FlagsCor.flags_csv_iff
#print axioms BitcoinProofs.Theorems.FlagsCor.flags_nulldummy_iff
#print axioms BitcoinProofs.Theorems.FlagsCor.nullDummy_iff_segwit
#print axioms BitcoinProofs.Theorems.FlagsCor.flags_genesis_exact
#print axioms BitcoinProofs.Theorems.FlagsCor.bip9StateByPeriod_active_atStart
#print axioms BitcoinProofs.Theorems.FlagsCor.bip9_active_stable
#print axioms BitcoinProofs.Theorems.NumericCor.MAX_MONEY_exact
#print axioms BitcoinProofs.Theorems.NumericCor.moneyRange_boundary_vectors
#print axioms BitcoinProofs.Theorems.NumericCor.setVchBE_int32_bound
#print axioms BitcoinProofs.Theorems.NumericCor.decodeScriptNum_int32_range
#print axioms BitcoinProofs.Theorems.NumericCor.locktime_partition
#print axioms BitcoinProofs.Theorems.NumericCor.locktime_domain_exclusive
#print axioms BitcoinProofs.Theorems.NumericCor.castToBool_corner_vectors
#print axioms BitcoinProofs.Theorems.LedgerCor.checkOutputs_none_total_moneyRange
#print axioms BitcoinProofs.Theorems.LedgerCor.checkOutputs_none_moneyRange
#print axioms BitcoinProofs.Theorems.LedgerCor.totalOut_moneyRange_of_checkTransaction
#print axioms BitcoinProofs.Theorems.LedgerCor.totalOut_le_MAX_of_checkTransaction
#print axioms BitcoinProofs.Theorems.LedgerCor.checkTransaction_none_basic
#print axioms BitcoinProofs.Theorems.LedgerCor.checkTransaction_none_noDup
#print axioms BitcoinProofs.Theorems.LedgerCor.checkTransaction_none_noNullPrevout
#print axioms BitcoinProofs.Theorems.LedgerCor.block_conservation_arith
#print axioms BitcoinProofs.Theorems.LedgerCor.blockOut_cons
#print axioms BitcoinProofs.Theorems.LedgerCor.blockIn_cons
#print axioms BitcoinProofs.Theorems.LedgerCor.supplyAt_checkpoints
#print axioms BitcoinProofs.Theorems.InterpCor.run_zero_scriptSize
#print axioms BitcoinProofs.Theorems.InterpCor.run_nil_ok
#print axioms BitcoinProofs.Theorems.InterpCor.run_cons_bind
#print axioms BitcoinProofs.Theorems.InterpCor.step_ne_scriptSize
#print axioms BitcoinProofs.Theorems.InterpCor.run_fuel_canonical
#print axioms BitcoinProofs.Theorems.InterpCor.run_ok_fuel_bound
#print axioms BitcoinProofs.Theorems.InterpCor.run_fuel_mono
#print axioms BitcoinProofs.Theorems.InterpCor.runsClean_fuel_irrelevant
#print axioms BitcoinProofs.Theorems.InterpCor.runsTrue_fuel_irrelevant
#print axioms BitcoinProofs.Theorems.InterpCor.run_len1_not_scriptSize
-- W14b part 2 (curve portfolio completion + P-primality): the 19-pin
-- W14b block above (committed via the W15 sweep) covered Mod, the
-- closure/decompression core, and the Ecdsa structural theorems; this
-- block completes the Secp portfolio and pins the proofs-side Pratt
-- certificate. All sorry-free.
#print axioms Bitcoin.Crypto.Curve.Secp.P_pos
#print axioms Bitcoin.Crypto.Curve.Secp.P_gt_one
#print axioms Bitcoin.Crypto.Curve.Secp.P_odd
#print axioms Bitcoin.Crypto.Curve.Secp.n_pos
#print axioms Bitcoin.Crypto.Curve.Secp.n_gt_one
#print axioms Bitcoin.Crypto.Curve.Secp.Gx_lt
#print axioms Bitcoin.Crypto.Curve.Secp.Gy_lt
#print axioms Bitcoin.Crypto.Curve.Secp.onCurveN_true
#print axioms Bitcoin.Crypto.Curve.Secp.onCurveN_of_OnCurve
#print axioms Bitcoin.Crypto.Curve.Secp.onCurveN_G
#print axioms Bitcoin.Crypto.Curve.Secp.negN_lt
#print axioms Bitcoin.Crypto.Curve.Secp.add_negN_zero
#print axioms Bitcoin.Crypto.Curve.Secp.mulP_zero
#print axioms Bitcoin.Crypto.Curve.Secp.addP_none
#print axioms Bitcoin.Crypto.Curve.Secp.mulP_one
#print axioms Bitcoin.Crypto.Curve.Secp.negP_ok
#print axioms Bitcoin.Crypto.Curve.Secp.doubleP_ok
#print axioms Bitcoin.Crypto.Curve.Secp.liftCand_lt
#print axioms BitcoinProofs.Crypto.CurveZMod.P_prime
#print axioms BitcoinProofs.Crypto.CurveZMod.secp_P_prime

-- W09: script interpreter core — the frozen-interface theorem trio plus
-- the Defs-side proof tail (fuel/STACK_SIZE algebra). All sorry-free.
#print axioms Bitcoin.Interpreter.evalScript_deterministic
#print axioms Bitcoin.Interpreter.evalScript_stack_bounds
#print axioms Bitcoin.Interpreter.evalScript_fuel_monotone
#print axioms Bitcoin.Interpreter.stepChecked_ok_bound
#print axioms Bitcoin.Interpreter.evalFrom_ok_stack_bound
#print axioms Bitcoin.Interpreter.evalFrom_succ_ok
#print axioms Bitcoin.Interpreter.evalFrom_fuel_mono
#print axioms Bitcoin.Interpreter.finalStack_isOk_iff
#print axioms Bitcoin.Interpreter.finalStack_ok
#print axioms Bitcoin.Interpreter.evalScriptBytes_ok_stack_bound
#print axioms Bitcoin.Interpreter.evalScriptBytes_fuel_mono
