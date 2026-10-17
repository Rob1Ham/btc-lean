import Bitcoin.TxValidation.Interface
import Bitcoin.DataLaws.Laws

/-!
# CT04 — Bitcoin Core txvalidation_tests.cpp + validation_tests.cpp

Bitcoin Core @ cce32b168 (pin D-001), src/test/txvalidation_tests.cpp
(568 lines) + src/test/validation_tests.cpp (363 lines) — the test
material NOT covered by the tx_valid/tx_invalid JSON corpora (those are
driven by the `legacy script runner` in transaction_tests.cpp).

VERIFIED classification (full evidence in vectors/coretests/CT04/):

* CONSENSUS (part of validateTx):
  - CTI-010 `tx_mempool_reject_coinbase` — BUT as a *pipeline-locus*
    finding (see F1 below).
  - CTI-020 max-money guard (validation.cpp:800-801 = MemPoolAccept::
    PreChecks TX_CONSENSUS "coinbase"; tx_verify.cpp:170-220
    CheckTxInputs; 220 lines).
  - CTI-021 coinbase-maturity (tx_verify.cpp:184-188).
* POLICY (not consensus; standardness):
  - CTI-011 IsStandardTx (validation.cpp:804-806).
  - CTI-030 TRUC/version-3 (BIP431) — INV-163, consensus: false.
  - CTI-031 ephemeral anchors (BIP433) — INV-164, consensus: false.
  - CTI-032 TRUC vsize/sigops limits (MAX_BLOCK_STANDARD fact).
* CORE-ONLY (not part of validateTx):
  - CTI-040 block_subsidy_test (GetBlockSubsidy, BIP42).
  - CTI-041 block_malleation (IsBlockMutated = net-relay path).
  - CTI-042 signet (BIP325).
  - CTI-043 assumeutxo (INV-147, non-consensus).
-/
namespace Test.TxValidation.CT04

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Consensus Bitcoin.Numeric
open Bitcoin.TxValidation Bitcoin.Activation Bitcoin.DataLaws

set_option maxRecDepth 10000

/-- Lean 4 core ships no `DecidableEq (Except α β)`; the test vectors
decide on `Except` equalities, so provide it locally (W02/W10 shim,
Tests.lean:32-51). -/
private instance instDecEqExcept {α β : Type} [DecidableEq α] [DecidableEq β] :
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

/-! ## Test infrastructure (Test/TxValidation/Tests.lean pattern) -/

private def kbytes (k : UInt8) : ByteArray :=
  (List.range 4).foldl (fun acc _ => acc.push k) ByteArray.empty

private def op (k : UInt8) : OutPoint := ⟨kbytes k, 0⟩

private def coin (v : Amount) (h : UInt32) (cb : Bool) : Coin :=
  ⟨v, h, cb, Script.empty⟩

private def view : List (OutPoint × Coin) → UtxoSet
  | [], _ => none
  | (o, c) :: rest, o' => if o == o' then some c else view rest o'

private def txIn (o : OutPoint) (seq : UInt32) : TxIn := ⟨o, Script.empty, seq⟩

private def txInS (o : OutPoint) (seq : UInt32) (s : Script) : TxIn :=
  ⟨o, s, seq⟩

/-- Minimal valid coinbase scriptSig (3 bytes). -/
private def cbSig : Script := scriptOf [0x02, 0x51, 0x52]

private def txOut (v : Amount) : TxOut := ⟨v, Script.empty⟩

private def mkTx (ver : Int32) (vin : List TxIn) (vout : List TxOut)
    (lt : UInt32) : Tx := ⟨ver, vin, vout, lt, []⟩

private def sFin : UInt32 := SEQUENCE_FINAL

/-! ## CTI-010 — tx_mempool_reject_coinbase (txvalidation_tests.cpp:27)

The txV layer (stateless CheckTransaction + coinbase early-exit) AGREES
with Core: v1 coinbase, 1 input, 1 output 1*CENT, scriptSig OP_11
OP_EQUAL (2 bytes: in 2..100), 25+ outputs n/a (Core asserts
IsCoinBase() true then expects "coinbase" reject). Here: 1 output. -/

-- Step 1 (txvalidation_tests.cpp:43): IsCoinBase() = true — a null
-- prevout + vin.size() == 1 tx is classified coinbase by our txV layer.
private def c04_cbTx : Tx :=
  mkTx 1 [txInS OutPoint.null sFin (scriptOf [0x5b, 0x87])] [txOut 1000000] 0

example : c04_cbTx.isCoinBase = true := by
  decide

-- Step 2 (txvalidation_tests.cpp:46-57): ProcessTransaction → INVALID,
-- reject "coinbase" (TX_CONSENSUS). Our validateTx (TXV-072) accepts
-- (`.ok 0`) — divergence F1: the "coinbase" check (validation.cpp:800)
-- is a MEMPOOL-ACCEPTANCE gate, one layer above validateTx.
example :
    validateTx c04_cbTx (view []) 101 500000000 {} = .ok 0 := by
  decide

-- True core test tx (25 outputs): C04txCore from vectors CTI-010 —
-- coinbase classification + TXV-072 early-exit + TVA (CB_LENGTH 2) all
-- hold on the Core shape (P2PK spk 25 bytes [0x21 <33-byte key> 0xac]
-- = scriptOf [0x21] ++ 33 zero bytes ++ [0xac]).
private def c04_coreSpk : Script :=
  scriptOf ([0x21] ++ (List.replicate 33 0x00) ++ [0xac])

/-- Core's make_tx(txvalidation_tests.cpp:79-91) full shape: v1 coinbase,
1 input (scriptSig OP_11 OP_EQUAL, 2 bytes = in CB_LENGTH 2..100),
25 × (nValue 10000, P2PK spk 25 bytes [0x21 <33-byte key> 0xAC]). -/
private def c04_coreTx : Tx :=
  mkTx 1 [txInS OutPoint.null sFin (scriptOf [0x5b, 0x87])]
    (List.replicate 25 (⟨10000, c04_coreSpk⟩ : TxOut)) 0

-- (txvalidation_tests.cpp:43) CTransaction(coinbaseTx).IsCoinBase()
example : c04_coreTx.isCoinBase = true := by
  decide

-- (txvalidation_tests.cpp:46-57) ProcessTransaction(coinbaseTx) →
-- INVALID, reject "coinbase", TX_CONSENSUS. Our validateTx = `.ok 0`
-- (TXV-072). Divergence F1 (mempool layer).
example :
    validateTx c04_coreTx (view []) 101 500000000 {} = .ok 0 := by
  decide

/-! ## CTI-020 — max-money overflow (txvalidation_tests.cpp + Core
validation.cpp:797 = PreChecks) — as asserted by the C++ test
`checktxinputs_invalid_transactions_test` (MAX_MONEY rows). -/

-- [MAX_MONEY output] (tx_valid) — txV layer: accepted, fee 0 (W10).
example :
    validateTx (mkTx 1 [txIn (op 1) sFin] [txOut MAX_MONEY] 0)
      (view [(op 1, coin MAX_MONEY 100 false)]) 100 500000000 {}
      = .ok 0 := by
  decide

-- [MAX_MONEY output + 0 output] (tx_valid) — fee 0.
example :
    validateTx (mkTx 1 [txIn (op 1) sFin] [txOut MAX_MONEY, txOut 0] 0)
      (view [(op 1, coin MAX_MONEY 100 false)]) 100 500000000 {}
      = .ok 0 := by
  decide

-- [MAX_MONEY + 1 output] (tx_invalid) — CTI-020A: stateless
-- bad-txns-vout-toolarge (CVE-2010-5139).
example :
    validateTx (mkTx 1 [txIn (op 1) sFin] [txOut (MAX_MONEY + 1)] 0)
      (view [(op 1, coin MAX_MONEY 100 false)]) 100 500000000 {}
      = .error (.stateless .voutTooLarge) := by
  decide

-- [MAX_MONEY output + 1 output] (tx_invalid) — CTI-020B: per-coin OK
-- but running sum 21000000BTC + 1 > MAX_MONEY → toolarge.
example :
    validateTx (mkTx 1 [txIn (op 1) sFin] [txOut MAX_MONEY, txOut 1] 0)
      (view [(op 1, coin MAX_MONEY 100 false)]) 100 500000000 {}
      = .error (.stateless .txoutTotalTooLarge) := by
  decide

-- CTI-020C (input-side MAX_MONEY + 1) — bad-txns-inputvalues-
-- outofrange (tx_verify.cpp:192-193).
example :
    validateTx (mkTx 1 [txIn (op 1) sFin] [txOut COIN] 0)
      (view [(op 1, coin (MAX_MONEY + 1) 100 false)]) 100 500000000 {}
      = .error .badTxnsInputvaluesOutOfRange := by
  decide

-- CTI-020D (CVE-2010-5137 input-sum guard) — coins each MAX_MONEY/1,
-- sum > MAX_MONEY (coin 1 MAX_MONEY + coin 2 1).
example :
    validateTx (mkTx 1 [txIn (op 1) sFin, txIn (op 2) sFin] [txOut COIN] 0)
      (view [(op 1, coin MAX_MONEY 100 false), (op 2, coin 1 100 false)])
      100 500000000 {}
      = .error .badTxnsInputvaluesOutOfRange := by
  decide

/-! ## CTI-021 — coinbase maturity (txvalidation_tests.cpp:26
"TestChain100Setup" = 100-block coinbase chain @ regtest COINBASE_MATURITY
= 100; Core check = tx_verify.cpp:184-188). -/

-- txV: spend coinbase coin @100, spendHeight 199 (depth 99) → reject.
example :
    validateTx (mkTx 1 [txIn (op 1) sFin] [txOut COIN] 0)
      (view [(op 1, coin (10 * COIN) 100 true)]) 199 500000000 {}
      = .error .badTxnsPrematureSpendOfCoinbase := by
  decide

-- txV: spendHeight 200 (depth 100) → accept (fee 9 COIN).
example :
    validateTx (mkTx 1 [txIn (op 1) sFin] [txOut COIN] 0)
      (view [(op 1, coin (10 * COIN) 100 true)]) 200 500000000 {}
      = .ok (9 * COIN) := by
  decide

-- The reject-string taxonomy (code TX_PREMATURE_SPEND) exists:
example : TxError.badTxnsPrematureSpendOfCoinbase ≠
    TxError.badTxnsInBelowout := by
  decide

/-! ## CTI-030/CTI-031/CTI-032 — version-3 TRUC + ephemeral = POLICY.
Classification (INV-163/INV-164/INV-165 consensus: false). Not part of
validateTx (they run in the standardness tier). Registered as CTI-031
scaffold rows = v2/v3 txs are consensus-identical through validateTx:
the same shape with version 3 vs 2 validates identically (no consensus
rule keys on nVersion ≠ BIP68's soft-fork gate TXV-034, TXV-071). -/

private def c04_v2 : Tx :=
  mkTx 2 [txIn (op 1) sFin] (List.replicate 25 (txOut 10000)) 0

private def c04_v3 : Tx :=
  mkTx 3 [txIn (op 1) sFin] (List.replicate 25 (txOut 10000)) 0

example :
    (validateTx c04_v2 (view [(op 1, coin (10 * COIN) 100 false)])
      101 500000000 {}).isOk
      = (validateTx c04_v3 (view [(op 1, coin (10 * COIN) 100 false)])
      101 500000000 {}).isOk := by
  decide

end Test.TxValidation.CT04
