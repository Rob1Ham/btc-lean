import Bitcoin.Capstone.Block
import Bitcoin.Capstone.Merkle
import Bitcoin.Block.Pow
import Bitcoin.TxValidation.Interface
import Bitcoin.Consensus.TxCheck
import Bitcoin.Interpreter.Defs

/-! # PDW66 — row faces for TOP-351..355 (RC29)

{Route B} Canonical-decl row faces for {INV-103, INV-088, INV-139, BLK-031,
TXV-021}. Tags live on these theorems; core decls untouched. -/

namespace BitcoinProofs.AF.PDW66

open Bitcoin.Data (bytesBEq Tx TxIn)
open Bitcoin.Capstone.Merkle (wcm witnessCommitmentOutput)

/-- INV-103 / BLK-069: with BIP34 active the gate is exactly the
minimal-height-push prefix compare on the coinbase scriptSig. -/
@[rule "INV-103"]
theorem bip34Ok_active_eq (height : UInt32) (cb : Tx) (i : TxIn) (rest : List TxIn)
    (hvin : cb.vin = i :: rest) (h : Bitcoin.Ledger.BIP34_HEIGHT ≤ height) :
    Bitcoin.Capstone.Block.bip34Ok height cb =
      bytesBEq ((i.scriptSig.bytes).extract 0
        (Bitcoin.Capstone.Block.cbHeightPush height).size)
        (Bitcoin.Capstone.Block.cbHeightPush height) := by
  unfold Bitcoin.Capstone.Block.bip34Ok
  rw [ite_eq_left h]
  simp [hvin]

/-- INV-103 below the BIP34 height: the gate is vacuous. -/
@[rule "INV-103"]
theorem bip34Ok_below_height (height : UInt32) (cb : Tx)
    (h : ¬ Bitcoin.Ledger.BIP34_HEIGHT ≤ height) :
    Bitcoin.Capstone.Block.bip34Ok height cb = true := by
  unfold Bitcoin.Capstone.Block.bip34Ok
  rw [ite_eq_right h]

/-- INV-088: `some s` iff the LAST output matching the BIP141 template
(≥38 bytes, prefix `6a24aa21a9ed`) exists, and `s` is its script. -/
@[rule "INV-088"]
theorem witnessCommitmentOutput_some_iff (tx : Tx) (s : ByteArray) :
    witnessCommitmentOutput tx = some s ↔
      ∃ o, (tx.vout.filter (fun o =>
        38 ≤ o.scriptPubKey.bytes.size && bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm)).getLast? = some o ∧
        s = o.scriptPubKey.bytes := by
  by_cases h : (tx.vout.filter (fun o =>
      38 ≤ o.scriptPubKey.bytes.size && bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm)).getLast? = none
  · simp [Bitcoin.Capstone.Merkle.witnessCommitmentOutput, h]
  · obtain ⟨o, ho⟩ := Option.ne_none_iff_exists'.mp h
    simp [Bitcoin.Capstone.Merkle.witnessCommitmentOutput, ho, eq_comm]

/-- INV-088 shape: a selected commitment output is ≥38 bytes and carries
the 6-byte BIP141 prefix. -/
@[rule "INV-088"]
theorem witnessCommitmentOutput_shape (tx : Tx) (s : ByteArray)
    (h : witnessCommitmentOutput tx = some s) :
    ∃ o ∈ tx.vout, s = o.scriptPubKey.bytes ∧ 38 ≤ s.size ∧
      bytesBEq (s.extract 0 6) wcm = true := by
  rw [witnessCommitmentOutput_some_iff] at h
  obtain ⟨o, ho, rfl⟩ := h
  obtain ⟨hov, hp⟩ := List.mem_filter.mp (List.mem_of_getLast? ho)
  obtain ⟨hsz, hpre⟩ := Bool.and_eq_true_iff.mp hp
  exact ⟨o, hov, rfl, of_decide_eq_true hsz, hpre⟩

/-- INV-139: on a no-retargeting chain (regtest) the nBits are frozen. -/
@[rule "INV-139"]
theorem calculateNextWorkRequired_noRetarget (P : Bitcoin.Block.Pow.PowParams)
    (h : P.fPowNoRetargeting = true) (lb lt ft fb : UInt32) :
    Bitcoin.Block.Pow.calculateNextWorkRequired P lb lt ft fb = lb := by
  unfold Bitcoin.Block.Pow.calculateNextWorkRequired
  rw [ite_eq_left h]

/-- INV-139 testnet4 (BIP94): with `enforceBIP94` the retarget base is the
FIRST-of-period bits, so the last block's nBits is irrelevant. -/
@[rule "INV-139"]
theorem calculateNextWorkRequired_bip94_lastBits_irrel
    (P : Bitcoin.Block.Pow.PowParams) (h1 : P.fPowNoRetargeting = false)
    (h2 : P.enforceBIP94 = true) (lb lb' lt ft fb : UInt32) :
    Bitcoin.Block.Pow.calculateNextWorkRequired P lb lt ft fb =
      Bitcoin.Block.Pow.calculateNextWorkRequired P lb' lt ft fb := by
  simp [Bitcoin.Block.Pow.calculateNextWorkRequired, h1, h2]

/-- TXV-021: coinbase coins mature exactly at depth ≥ 100; non-coinbase
coins are always mature. -/
@[rule "TXV-021"]
theorem coinMatured_iff (spendHeight : UInt32) (c : Bitcoin.Ledger.Coin) :
    Bitcoin.TxValidation.coinMatured spendHeight c = true ↔
      (¬ c.isCoinbase ∨
        c.height.toNat + Bitcoin.TxValidation.COINBASE_MATURITY.toNat ≤
          spendHeight.toNat) := by
  unfold Bitcoin.TxValidation.coinMatured
  simp [Bool.or_eq_true]

/-- BLK-031 (CVE-2018-17144): the pairwise scanner is false exactly when
no later input repeats an earlier one's outpoint. -/
@[rule "BLK-031"]
theorem hasDupPrevouts_eq_false_iff (l : List TxIn) :
    Bitcoin.Consensus.hasDupPrevouts l = false ↔
      l.Pairwise (fun a b => (b.prevout == a.prevout) = false) := by
  induction l with
  | nil => simp [Bitcoin.Consensus.hasDupPrevouts]
  | cons i rest ih =>
      simp only [Bitcoin.Consensus.hasDupPrevouts, Bool.or_eq_false_iff, ih,
        List.pairwise_cons, List.any_eq_false, Bool.not_eq_true]

/-! ## Axiom footprints -/

/-- info: 'BitcoinProofs.AF.PDW66.bip34Ok_active_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip34Ok_active_eq
/-- info: 'BitcoinProofs.AF.PDW66.bip34Ok_below_height' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip34Ok_below_height
/-- info: 'BitcoinProofs.AF.PDW66.witnessCommitmentOutput_some_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms witnessCommitmentOutput_some_iff
/-- info: 'BitcoinProofs.AF.PDW66.witnessCommitmentOutput_shape' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms witnessCommitmentOutput_shape
/-- info: 'BitcoinProofs.AF.PDW66.calculateNextWorkRequired_noRetarget' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms calculateNextWorkRequired_noRetarget
/-- info: 'BitcoinProofs.AF.PDW66.calculateNextWorkRequired_bip94_lastBits_irrel' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms calculateNextWorkRequired_bip94_lastBits_irrel
/-- info: 'BitcoinProofs.AF.PDW66.hasDupPrevouts_eq_false_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms hasDupPrevouts_eq_false_iff
/-- info: 'BitcoinProofs.AF.PDW66.coinMatured_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms coinMatured_iff

/-- BLK-093: outputs with an unspendable scriptPubKey never enter the
UTXO set (`addedCoins` filters them out; `updateCoinsL` adds only these). -/
@[rule "BLK-093"]
theorem addedCoins_unspendable_absent (tx : Tx) (key : Bitcoin.Ledger.Key)
    (height : UInt32) (o : Bitcoin.Data.OutPoint) (c : Bitcoin.Ledger.Coin)
    (h : (o, c) ∈ Bitcoin.Ledger.addedCoins tx key height) :
    Bitcoin.Ledger.scriptUnspendable c.scriptPubKey = false := by
  unfold Bitcoin.Ledger.addedCoins at h
  obtain ⟨k, hk, hsome⟩ := List.mem_filterMap.mp h
  dsimp only at hsome
  split at hsome
  · exact absurd hsome (by simp)
  · rename_i hsp
    cases hsome
    simpa using hsp

/-- info: 'BitcoinProofs.AF.PDW66.addedCoins_unspendable_absent' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms addedCoins_unspendable_absent

/-- BLK-092 (coinbase arm): a coinbase spends nothing, so the update is
exactly the output insertions on top of the view. -/
@[rule "BLK-092"]
theorem updateCoinsL_coinbase (l : List (Bitcoin.Data.OutPoint × Bitcoin.Ledger.Coin))
    (tx : Tx) (key : Bitcoin.Ledger.Key) (height : UInt32) (h : tx.isCoinBase = true) :
    Bitcoin.Ledger.updateCoinsL l tx key height =
      Bitcoin.Ledger.addedCoins tx key height ++ l := by
  simp [Bitcoin.Ledger.updateCoinsL, h]

/-- BLK-092 (spend arm): every view coin whose outpoint is an input is
removed (SpendCoin), and the outputs are added. -/
@[rule "BLK-092"]
theorem updateCoinsL_spend (l : List (Bitcoin.Data.OutPoint × Bitcoin.Ledger.Coin))
    (tx : Tx) (key : Bitcoin.Ledger.Key) (height : UInt32) (h : tx.isCoinBase = false) :
    Bitcoin.Ledger.updateCoinsL l tx key height =
      Bitcoin.Ledger.addedCoins tx key height ++
        l.filter (fun p => !(tx.vin.any (fun i => i.prevout == p.1))) := by
  simp [Bitcoin.Ledger.updateCoinsL, h]

/-- info: 'BitcoinProofs.AF.PDW66.updateCoinsL_coinbase' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms updateCoinsL_coinbase

/-- info: 'BitcoinProofs.AF.PDW66.updateCoinsL_spend' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms updateCoinsL_spend

/-- SWT-059 policy arm: with NULLFAIL off, the multisig cleanup can never
error — it only pops `i` stack entries. -/
@[rule "SWT-059"]
theorem cmsCleanup_no_nullfail (pol : Bitcoin.Interpreter.PolicyFlags)
    (h : pol.nullFail = false) (st : Bitcoin.Interpreter.Stack) (fs : Bool)
    (i ikey2 fuel : Nat) :
    ∃ s, Bitcoin.Interpreter.cmsCleanup pol st fs i ikey2 fuel = .ok s := by
  induction fuel generalizing i ikey2 st with
  | zero => exact ⟨st, by simp [Bitcoin.Interpreter.cmsCleanup]⟩
  | succ f ih =>
    by_cases hi : i ≤ 1
    · exact ⟨st, by simp [Bitcoin.Interpreter.cmsCleanup, hi]⟩
    · obtain ⟨s, hs⟩ := ih st.tail (i - 1) (if 0 < ikey2 then ikey2 - 1 else ikey2)
      exact ⟨s, by simp [Bitcoin.Interpreter.cmsCleanup, hi, h, hs]⟩

/-- SWT-059 error arm: with NULLFAIL on, a failed signature whose stack
item is non-empty raises `SIG_NULLFAIL`. -/
@[rule "SWT-059"]
theorem cmsCleanup_nullfail_error (pol : Bitcoin.Interpreter.PolicyFlags)
    (h : pol.nullFail = true) (st : Bitcoin.Interpreter.Stack)
    (hst : st[0]!.size ≠ 0) (i fuel : Nat) (hi : ¬ i ≤ 1) :
    Bitcoin.Interpreter.cmsCleanup pol st false i 0 fuel.succ = .error .sigNullFail := by
  simp only [List.getElem!_eq_getElem?_getD] at hst
  simp only [Bitcoin.Interpreter.cmsCleanup, hi, h, List.getElem!_eq_getElem?_getD]
  rw [ite_eq_right (by simp : ¬ False)]
  rw [ite_eq_left (by simp [hst])]

/-- info: 'BitcoinProofs.AF.PDW66.cmsCleanup_no_nullfail' depends on axioms: [propext] -/
#guard_msgs in #print axioms cmsCleanup_no_nullfail

/-- info: 'BitcoinProofs.AF.PDW66.cmsCleanup_nullfail_error' depends on axioms: [propext] -/
#guard_msgs in #print axioms cmsCleanup_nullfail_error

end BitcoinProofs.AF.PDW66
