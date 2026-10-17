import Bitcoin.Capstone.Block
import Bitcoin.Interpreter.Rules
import Bitcoin.Block.Params

/-! # PDW57b — items TOP-306..310: BIP34 coinbase gate, coinbase position,
10k script-size cap, tx-weight floor, min-chain-work parameter.
Route B: row faces only, zero core writes. Claim `59e85a9`. -/

namespace BitcoinProofs.AF.PDW57b

open Bitcoin.Capstone.Block Bitcoin.Interpreter Bitcoin.Block.Params
open Bitcoin.Activation Bitcoin.Crypto.Seam Bitcoin.Data

/-- INV-135 (pre-BIP34 half): before height 227931 the BIP34 coinbase
prefix check is not applied, so `bip34Ok` is vacuously true. -/
@[rule "INV-135"]
theorem bip34Ok_pre (height : UInt32) (cb : Tx) (h : height < Bitcoin.Ledger.BIP34_HEIGHT) :
    bip34Ok height cb = true := by
  have hb : ¬ Bitcoin.Ledger.BIP34_HEIGHT ≤ height :=
    fun hle => UInt32.lt_irrefl _ (UInt32.lt_of_le_of_lt hle h)
  simp [bip34Ok, hb]

/-- INV-135 (active half): at/after BIP34 activation acceptance is exactly
the minimal height-push prefix check (`bad-cb-height`); stated on the first
input (`vin ≠ []`), the default argument is immaterial. -/
@[rule "INV-135"]
theorem bip34Ok_post_iff (height : UInt32) (cb : Tx)
    (h : Bitcoin.Ledger.BIP34_HEIGHT ≤ height) (hvin : cb.vin ≠ []) :
    bip34Ok height cb = true ↔
      bytesBEq (((cb.vin.head hvin).scriptSig.bytes).extract 0 (cbHeightPush height).size)
        (cbHeightPush height) = true := by
  obtain ⟨version, vin, vout, locktime, witness⟩ := cb
  cases vin with
  | nil => exact absurd rfl hvin
  | cons x xs => simp [bip34Ok, h]

/-- BLK-028: the empty list has no coinbase at position 0. -/
@[rule "BLK-028"]
theorem cbPositionOk_nil : cbPositionOk ([] : List Tx) = false := rfl

/-- BLK-028: `vtx[0]` is the unique coinbase. -/
@[rule "BLK-028"]
theorem cbPositionOk_cons_iff (cb : Tx) (rest : List Tx) :
    cbPositionOk (cb :: rest) = true ↔
      cb.isCoinBase = true ∧ rest.any (fun t => t.isCoinBase) = false := by
  simp [cbPositionOk, Bool.and_eq_true]

/-- SCR-018: the 10,000-byte pre-parse cap applies to base and witness-v0
scripts and fires before parsing. -/
@[rule "SCR-018"]
theorem evalScriptBytes_oversize (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (b : ByteArray) (st : Stack) (chk : ScriptChecker) (sv : SigVersion)
    (ed : ScriptExecutionData) (hsv : sv = .base ∨ sv = .witnessV0)
    (h : MAX_SCRIPT_SIZE < b.size) :
    evalScriptBytes fuel flags pol b st chk sv ed = .error .scriptSize := by
  simp [evalScriptBytes, hsv, h]

/-- SWT-010: a witness stack item above 520 bytes is rejected before
execution (BIP141 item-size limit; tapscript's OP_SUCCESS override is
excluded by `hsv`). -/
@[rule "SWT-010"]
theorem executeWitnessScript_oversize (fuel : Nat) (items : List ByteArray) (vwSer : Int)
    (exec : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (sv : SigVersion) (hsv : sv ≠ .tapscript)
    (h : items.any (fun d => MAX_SCRIPT_ELEMENT_SIZE < d.size) = true) :
    executeWitnessScript fuel items vwSer exec flags pol chk sv = .fail .pushSize := by
  simp [executeWitnessScript, executeWitnessScript.runExec, hsv, h]

/-- SCR-181: CONST_SCRIPTCODE is a policy-only flag — the consensus
projection never enables it, while the mempool flag string does. -/
@[rule "SCR-181"]
theorem constScriptCode_not_consensus (f : ScriptFlags) :
    (consensusFullFlags f).policy .constScriptCode = false := rfl

/-- SCR-044: the 240-weight floor is exactly 4 x 60 (vs. size). -/
@[rule "SCR-044"]
theorem MIN_TRANSACTION_WEIGHT_row : MIN_TRANSACTION_WEIGHT = 240 := rfl

/-- INV-149: mainnet `nMinimumChainWork` pinned to the Core constant. -/
@[rule "INV-149"]
theorem nMinimumChainWorkMainnet_row :
    nMinimumChainWorkMainnet =
      0x000000000000000000000000000000000000000145ec036acc5ba740052af1a0 := rfl

end BitcoinProofs.AF.PDW57b
