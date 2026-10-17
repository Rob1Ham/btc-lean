import Bitcoin.TxValidation.Interface
import Bitcoin.DataLaws.Laws

/-!
# W10 unit tests — TxValidation conformance vectors

Every check is a build-time `example … := by decide` (kernel-reduced, no
IO), mirroring the W02/W04 pattern. Ports of Bitcoin Core's consensus
unit tests @ `f54186c`:

* `checktxinputs_invalid_transactions_test` + the valid variants
  (`validation_flush_tests`-style value matrices): HaveInputs
  (TXV-020), the per-coin value loop (TXV-023), in-below-out (TXV-024),
  fee MoneyRange (TXV-025), the CVE-2010-5137 running-sum guard and the
  new `bad-txns-inputvalues-outofrange` ctor (TXV-023).
* Coinbase maturity: depth exactly 100 passes / 99 fails (TXV-021),
  boundary theorem instances at 900099/900100 (TXV-070).
* `isfinaltx_sequences_test` (TXV-032) and BIP68 nSequence algebra
  instances (TXV-034..038), incl. the height/time domain split.
* `validateTx` end-to-end: fee path, missing input, duplicate inputs
  (CVE-2018-17144), nonfinal reject, coinbase early-exit (TXV-072).
* Rule-DB instances: zero-value outputs spendable (TXV-067), any 32-bit
  `nVersion` valid (TXV-071), `GetValueOut` in-range on success
  (TXV-074). The `mempoolHeight` ↔ `Bitcoin.Ledger.MEMPOOL_HEIGHT`
  cross-check (TXV-042) lives in `LedgerCross.lean` (it needs the
  Ledger interface module, W12-owned).
-/

namespace Test.TxValidation.Tests

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Consensus Bitcoin.Numeric
open Bitcoin.TxValidation Bitcoin.Activation Bitcoin.DataLaws

set_option maxRecDepth 10000

/-- Lean 4 core ships no `DecidableEq (Except α β)`; the test vectors
decide on `Except` equalities, so provide it locally (W02 shim). -/
instance instDecEqExcept {α β : Type} [DecidableEq α] [DecidableEq β] :
    DecidableEq (Except α β)
  | .error e, .error e' =>
      match decEq e e' with
      | isTrue h => isTrue (by rw [h])
      | isFalse h => isFalse (by intro h2; exact h (Except.error.inj h2))
  | .ok a, .ok b =>
      match decEq a b with
      | isTrue h => isTrue (by rw [h])
      | isFalse h => isFalse (by intro h2; exact h (Except.ok.inj h2))
  | .error _, .ok _ => isFalse (by intro h; simp at h)
  | .ok _, .error _ => isFalse (by intro h; simp at h)

/-! ## Test infrastructure -/

/-- A 4-byte ByteArray filled with byte `k` (distinguishes test txids). -/
def kbytes (k : UInt8) : ByteArray :=
  (List.range 4).foldl (fun acc _ => acc.push k) ByteArray.empty

/-- Test outpoint #k. -/
def op (k : UInt8) : OutPoint := ⟨kbytes k, 0⟩

/-- Test coin. -/
def coin (v : Amount) (h : UInt32) (cb : Bool) : Coin := ⟨v, h, cb, Script.empty⟩

/-- Test UTXO view from an association list. -/
def view : List (OutPoint × Coin) → UtxoSet
  | [], _ => none
  | (o, c) :: rest, o' => if o == o' then some c else view rest o'

def txIn (o : OutPoint) (seq : UInt32) : TxIn := ⟨o, Script.empty, seq⟩

/-- TxIn with a given scriptSig (coinbases need a 2..100-byte one). -/
def txInS (o : OutPoint) (seq : UInt32) (s : Script) : TxIn := ⟨o, s, seq⟩

/-- A minimal valid coinbase scriptSig (3 bytes, Core PoC pattern). -/
def cbSig : Script := scriptOf [0x02, 0x51, 0x52]

def txOut (v : Amount) : TxOut := ⟨v, Script.empty⟩

def mkTx (ver : Int32) (vin : List TxIn) (vout : List TxOut) (lt : UInt32) : Tx :=
  ⟨ver, vin, vout, lt, []⟩

/-- The all-final sequence value. -/
def sFin : UInt32 := SEQUENCE_FINAL

/-! ## HaveInputs (TXV-020) -/

example : haveInputs (mkTx 2 [txIn (op 1) sFin] [] 0) (view [(op 1, coin 1 0 false)]) = true := by
  decide

example :
    haveInputs (mkTx 2 [txIn (op 1) sFin, txIn (op 2) sFin] [] 0)
      (view [(op 1, coin 1 0 false)]) = false := by
  decide

/-! ## CheckTxInputs value matrix (Core `checktxinputs` tests) -/

/-- Valid spend: fee = valueIn − valueOut = 6 COIN. -/
example :
    checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (4 * COIN)] 0)
      (view [(op 1, coin (10 * COIN) 100 false)]) 100 = .ok (6 * COIN) := by
  decide

/-- `bad-txns-in-belowout` (TXV-024): value in < value out. -/
example :
    checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (11 * COIN)] 0)
      (view [(op 1, coin (10 * COIN) 100 false)]) 100
      = .error .badTxnsInBelowout := by
  decide

/-- `bad-txns-inputs-missingorspent` (TXV-020): prevout absent from view. -/
example :
    checkTxInputs (mkTx 2 [txIn (op 7) sFin] [txOut COIN] 0)
      (view [(op 1, coin (10 * COIN) 100 false)]) 100
      = .error .badTxnsInputsMissingOrSpent := by
  decide

/-- `bad-txns-inputvalues-outofrange` (TXV-023): single coin value
outside MoneyRange. -/
example :
    checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut COIN] 0)
      (view [(op 1, coin (MAX_MONEY + 1) 100 false)]) 100
      = .error .badTxnsInputvaluesOutOfRange := by
  decide

/-- CVE-2010-5137 guard (TXV-023): each coin in range but the running
sum overflows the MoneyRange envelope. -/
example :
    checkTxInputs (mkTx 2 [txIn (op 1) sFin, txIn (op 2) sFin] [txOut COIN] 0)
      (view [(op 1, coin MAX_MONEY 100 false), (op 2, coin 1 100 false)]) 100
      = .error .badTxnsInputvaluesOutOfRange := by
  decide

/-- Exact-MAX_MONEY inputs are fine: fee 0 (sum stays in range). -/
example :
    checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut MAX_MONEY] 0)
      (view [(op 1, coin MAX_MONEY 100 false)]) 100 = .ok 0 := by
  decide

/-! ## Coinbase maturity (TXV-021 / TXV-070) -/

/-- Depth 99: `bad-txns-premature-spend-of-coinbase`. -/
example :
    checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (50 * COIN)] 0)
      (view [(op 1, coin (50 * COIN) 900000 true)]) 900099
      = .error .badTxnsPrematureSpendOfCoinbase := by
  decide

/-- Depth exactly 100: spendable, fee 0. -/
example :
    checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (50 * COIN)] 0)
      (view [(op 1, coin (50 * COIN) 900000 true)]) 900100
      = .ok 0 := by
  decide

/-- Non-coinbase coins have no maturity gate (spend at the coin's own
height is fine). -/
example :
    checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (50 * COIN)] 0)
      (view [(op 1, coin (50 * COIN) 900100 false)]) 900100
      = .ok 0 := by
  decide

/-- TXV-070 boundary instance at concrete heights. -/
example :
    coinMatured 900099 (coin 0 900000 true) = false ∧
    coinMatured 900100 (coin 0 900000 true) = true := by
  decide

/-- TXV-022 packing instances. -/
example : packCoinCode 900000 true = 1800001 := by decide
example : coinHeightOfCode 1800001 = 900000 := by decide
example : coinIsCoinbaseOfCode 1800001 = true := by decide
example : coinIsCoinbaseOfCode 1800000 = false := by decide

/-! ## Zero-value outputs (TXV-067) -/

/-- A `value = 0` output creates a perfectly spendable flow: the tx
itself validates. -/
example :
    checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut 0] 0)
      (view [(op 1, coin 0 100 false)]) 100 = .ok 0 := by
  decide

/-! ## nVersion unconstrained (TXV-071) -/

/-- Any 32-bit version validates: `INT32_MAX`. -/
example :
    checkTxInputs (mkTx 2147483647 [txIn (op 1) sFin] [txOut (4 * COIN)] 0)
      (view [(op 1, coin (10 * COIN) 100 false)]) 100 = .ok (6 * COIN) := by
  decide

/-- Any 32-bit version validates: `-1`. -/
example :
    checkTxInputs (mkTx (-1) [txIn (op 1) sFin] [txOut (4 * COIN)] 0)
      (view [(op 1, coin (10 * COIN) 100 false)]) 100 = .ok (6 * COIN) := by
  decide

/-! ## Reject strings (Core-verbatim, tx_check.cpp / tx_verify.cpp) -/

example : rejectReason .badTxnsInputsMissingOrSpent = "bad-txns-inputs-missingorspent" := by
  decide
example : rejectReason .badTxnsInBelowout = "bad-txns-in-belowout" := by decide
example : rejectReason .badTxnsFeeOutOfRange = "bad-txns-fee-outofrange" := by decide
example : rejectReason .badTxnsInputvaluesOutOfRange = "bad-txns-inputvalues-outofrange" := by
  decide
example : rejectReason .badTxnsPrematureSpendOfCoinbase = "bad-txns-premature-spend-of-coinbase" := by
  decide
example : rejectReason (.stateless .inputsDuplicate) = "bad-txns-inputs-duplicate" := by decide

/-! ## IsFinalTx (TXV-032) — Core `isfinaltx_sequences_test` -/

/-- nLockTime = 0 ⇒ final. -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 10] [] 0) 100 500000000 = true := by
  decide

/-- Height domain: nLockTime below the block height ⇒ final. -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [] 500) 1000 0 = true := by
  decide

/-- Height domain: nLockTime at the block height ⇒ NOT final (strict). -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [] 1000) 1000 0 = false := by
  decide

/-- Time domain (BIP113, TXV-031): nLockTime below the median-time-past
cutoff ⇒ final. -/
example :
    Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [] 500000000) 100 500000001
      = true := by
  decide

/-- Time domain: nLockTime at-or-above the cutoff ⇒ NOT final. -/
example :
    Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [] 500000000) 100 500000000
      = false := by
  decide

/-- Every input SEQUENCE_FINAL ⇒ final regardless of nLockTime. -/
example :
    Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) sFin, txIn (op 2) sFin] [] 999999999)
      100 500000000 = true := by
  decide

/-! ## BIP68 (TXV-034..040) — sequence algebra -/

/-- seq = 10: height-based, relative 10. -/
private def sH10 : UInt32 := 10

/-- seq = type-flag | 10: time-based (512s granularity), relative 10. -/
private def sT10 : UInt32 := SEQUENCE_LOCKTIME_TYPE_FLAG ||| 10

/-- BIP68 enabled, height lock not reached ⇒ `validateTx` rejects with
Core's block-context string `bad-txns-nonfinal` (validation.cpp:2556). -/
example :
    validateTx (mkTx 2 [txIn (op 1) sH10] [txOut (4 * COIN)] 0)
      (view [(op 1, coin (10 * COIN) 50 false)]) 55 0 { csv := true }
      = .error .badTxnsNonfinal := by
  decide

/-- Same tx at depth exactly 10: validates, fee 6 COIN. -/
example :
    validateTx (mkTx 2 [txIn (op 1) sH10] [txOut (4 * COIN)] 0)
      (view [(op 1, coin (10 * COIN) 50 false)]) 60 0 { csv := true }
      = .ok (6 * COIN) := by
  decide

/-- A time-based sequence does NOT constrain the height domain: the tx
validates at height 55 (the 512-second check belongs to W12's time
domain, tx_verify.cpp:79-99). -/
example :
    validateTx (mkTx 2 [txIn (op 1) sT10] [txOut (4 * COIN)] 0)
      (view [(op 1, coin (10 * COIN) 50 false)]) 55 0 { csv := true }
      = .ok (6 * COIN) := by
  decide

/-- BIP68 flag off (csv := false): the same sequence-locked tx validates
at height 0. -/
example :
    validateTx (mkTx 2 [txIn (op 1) sH10] [txOut (4 * COIN)] 0)
      (view [(op 1, coin (10 * COIN) 50 false)]) 0 0 {}
      = .ok (6 * COIN) := by
  decide

/-- Disabled flag (bit 31): the input contributes no sequence lock. -/
example :
    Bitcoin.DataLaws.seqIsDisabled (SEQUENCE_LOCKTIME_DISABLE_FLAG ||| 5) = true ∧
    validateTx (mkTx 2 [txIn (op 1) (SEQUENCE_LOCKTIME_DISABLE_FLAG ||| 5)] [txOut (4 * COIN)] 0)
      (view [(op 1, coin (10 * COIN) 50 false)]) 50 0 { csv := true }
      = .ok (6 * COIN) := by
  decide

/-! ## validateTx end-to-end -/

/-- Fee path through the full pipeline. -/
example :
    validateTx (mkTx 2 [txIn (op 1) sFin] [txOut (4 * COIN)] 0)
      (view [(op 1, coin (10 * COIN) 100 false)]) 100 500000000 {}
      = .ok (6 * COIN) := by
  decide

/-- Missing input through the full pipeline. -/
example :
    validateTx (mkTx 2 [txIn (op 7) sFin] [txOut (4 * COIN)] 0)
      (view [(op 1, coin (10 * COIN) 100 false)]) 100 500000000 {}
      = .error .badTxnsInputsMissingOrSpent := by
  decide

/-- CVE-2018-17144: duplicate inputs are caught by the stateless prefix
(before any contextual check), with Core's exact reject string. -/
example :
    validateTx (mkTx 2 [txIn (op 1) sFin, txIn (op 1) sFin] [txOut (4 * COIN)] 0)
      (view [(op 1, coin (10 * COIN) 100 false)]) 100 500000000 {}
      = .error (.stateless .inputsDuplicate) := by
  decide

/-- Nonfinal tx (nLockTime ≥ height, non-final sequence) →
`bad-txns-nonfinal`. -/
example :
    validateTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [txOut (4 * COIN)] 2000)
      (view [(op 1, coin (10 * COIN) 100 false)]) 100 500000000 {}
      = .error .badTxnsNonfinal := by
  decide

/-- Coinbase early-exit (TXV-072): no inputs are consulted — the empty
view suffices and the "fee" is 0. -/
example :
    validateTx (mkTx 2 [txInS OutPoint.null sFin cbSig] [txOut (50 * COIN)] 0)
      (view []) 100 500000000 {}
      = .ok 0 := by
  decide

/-- TXV-067 + TXV-074 end-to-end: zero-value output, version INT32_MIN,
and the resulting fee is in MoneyRange. -/
example :
    validateTx (mkTx (-2147483648) [txIn (op 1) sFin] [txOut 0, txOut 0] 0)
      (view [(op 1, coin 1 100 false)]) 100 500000000 {}
      = .ok 1 := by
  decide

/-! ## Rule-DB cross-checks -/

/-- TXV-042 value itself. -/
example : mempoolHeight = 0x7FFFFFFF := by decide

/-- TXV-031: the BIP113 cutoff is the caller-supplied median-time-past
(identity convention). -/
example : bip113Cutoff 500000001 = 500000001 := by decide

end Test.TxValidation.Tests
