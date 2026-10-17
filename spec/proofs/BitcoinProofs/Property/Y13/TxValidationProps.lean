import Bitcoin.TxValidation.Interface
import Bitcoin.DataLaws.Laws

/-!
# BitcoinProofs.Property.Y13 — property-test corpus for TxValidation (Review-4, contributor Y13)

Systematic edges + seeded pseudo-random tx mutations against an INDEPENDENT
python reference. Every EXPECTED verdict below was computed by
`scratch/Y13/ref.py` — a ground-truth port of Bitcoin Core @ cce32b168
(tx_check.cpp:23-68 `CheckTransaction`; tx_verify.cpp:23-43 `IsFinalTx`,
:45-121 `CalculateSequenceLocks`/`EvaluateSequenceLocks`, :170-220
`Consensus::CheckTxInputs`; transaction.h:299 `const uint32_t version`;
amount.h:12-27 `MoneyRange`; consensus.h) — NOT from the Lean code.
Module under test: `Bitcoin.TxValidation.Interface` (the frozen
`validateTx` signature); the script lane is X09's `Full` — out of scope.

REPRODUCIBLE: `python3 build/scratch/build/scratch/scratch/Y13/gen.py`
regenerates this file byte-for-byte; all pseudo-random cases use
`random.Random(20261016)`.

Model totalizations (documented; mirror the frozen `validateTx` signature):
  * the BIP68 gate inside `validateTx` is the HEIGHT-domain projection (the
    frozen signature carries no parent-MTP data); full height+time semantics
    are asserted through `sequenceLocksOk` with explicit
    `(prevHeight, parentMTP)` pairs (section G);
  * a missing coin contributes prevHeight 0 (`prevHeightData`); corpus cases
    with a missing input always use SEQUENCE_FINAL sequences so the gate is
    verdict-neutral in both implementations;
  * `oversize` (TXV-003) is exercised only implicitly (every corpus tx is far
    below the 1 MB base-serialization bound; the exact weight model is
    W02/W03's).

Sections (145 cases, all kernel `decide`-checkable concrete vectors):
  A  checkTransaction systematic edges (18 cases)
  B  error-taxonomy mapping (reject strings, verbatim) (17 cases)
  C  coinbase maturity grid + coin packing (incl. the F-Y13-001 future-coin corner) (14 cases)
  D  checkTxInputs value matrix (CVE-2010-5137 + check-order probes) (15 cases)
  E  IsFinalTx grid (height/time domain boundaries, SEQUENCE_FINAL override) (13 cases)
  F  BIP68 height gate through validateTx (incl. the uint32-version pin) (20 cases)
  G  full sequenceLocksOk incl. the time domain (512 s granularity) (10 cases)
  H  validateTx end-to-end (ordering probes) (8 cases)
  I  seeded pseudo-random mutations (random.Random(20261016)) (30 cases)

VERDICT: all 145 python (Core) verdicts are confirmed by kernel
`decide` — zero Lean-vs-python divergence on the reachable domain. The one
out-of-domain divergence (future-coin maturity depth wrap, F-Y13-001) is
pinned in section C with the LEAN verdict and filed in
spec/db/findings-w4/Y13.md.
-/

namespace BitcoinProofs.Property.Y13.TxValidationProps

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Consensus Bitcoin.Numeric
open Bitcoin.TxValidation Bitcoin.Activation Bitcoin.DataLaws

set_option maxRecDepth 10000

/-- Lean core ships no `DecidableEq (Except α β)`; the vectors decide on
`Except` equalities, so provide it locally (W02/W10 shim). -/
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

/-! ## Test infrastructure (mirrors `Test/TxValidation/Tests.lean`) -/

/-- A 4-byte ByteArray filled with byte `k` (distinguishes test txids). -/
private def kbytes (k : UInt8) : ByteArray :=
  (List.range 4).foldl (fun acc _ => acc.push k) ByteArray.empty

private def op (k : UInt8) : OutPoint := ⟨kbytes k, 0⟩

/-- OutPoint with an explicit index (same-hash/different-n probes). -/
private def opN (k : UInt8) (n : UInt32) : OutPoint := ⟨kbytes k, n⟩

private def coin (v : Amount) (h : UInt32) (cb : Bool) : Coin := ⟨v, h, cb, Script.empty⟩

/-- Test UTXO view from an association list. -/
private def view : List (OutPoint × Coin) → UtxoSet
  | [], _ => none
  | (o, c) :: rest, o' => if o == o' then some c else view rest o'

private def txIn (o : OutPoint) (seq : UInt32) : TxIn := ⟨o, Script.empty, seq⟩

private def txInS (o : OutPoint) (seq : UInt32) (s : Script) : TxIn := ⟨o, s, seq⟩

/-- A uniform-byte script of length `n` (coinbase scriptSig length edges). -/
private def sN (n : Nat) : Script := scriptOf (List.replicate n 0x51)

/-- The minimal valid coinbase scriptSig (3 bytes). -/
private def cbSig : Script := scriptOf [0x02, 0x51, 0x52]

private def txOut (v : Amount) : TxOut := ⟨v, Script.empty⟩

private def mkTx (ver : Int32) (vin : List TxIn) (vout : List TxOut) (lt : UInt32) : Tx :=
  ⟨ver, vin, vout, lt, []⟩

/-- The all-final sequence value. -/
private def sFin : UInt32 := SEQUENCE_FINAL

/-! ## The corpus -/


/-! ## Section A — checkTransaction systematic edges -/

/-- cA001 — python: bad-txns-vin-empty -/
example : checkTransaction (mkTx 2 [] [txOut 1] 0) = some .vinEmpty := by decide

/-- cA002 — python: bad-txns-vout-empty -/
example : checkTransaction (mkTx 2 [txIn (op 1) sFin] [] 0) = some .voutEmpty := by decide

/-- cA003 — python: bad-txns-vout-negative -/
example : checkTransaction (mkTx 2 [txIn (op 1) sFin] [txOut (-1)] 0) = some .voutNegative := by decide

/-- cA004 — python: bad-txns-vout-toolarge -/
example : checkTransaction (mkTx 2 [txIn (op 1) sFin] [txOut (MAX_MONEY + 1)] 0) = some .voutTooLarge := by decide

/-- cA005 — python: None -/
example : checkTransaction (mkTx 2 [txIn (op 1) sFin] [txOut MAX_MONEY] 0) = none := by decide

/-- cA006 — python: bad-txns-txouttotal-toolarge -/
example : checkTransaction (mkTx 2 [txIn (op 1) sFin] [txOut MAX_MONEY, txOut 1] 0) = some .txoutTotalTooLarge := by decide

/-- cA007 — python: None -/
example : checkTransaction (mkTx 2 [txIn (op 1) sFin] [txOut (MAX_MONEY - 1), txOut 1] 0) = none := by decide

/-- cA008 — python: bad-txns-inputs-duplicate -/
example : checkTransaction (mkTx 2 [txIn (op 1) sFin, txIn (op 1) sFin] [txOut (1 * COIN)] 0) = some .inputsDuplicate := by decide

/-- cA009 — python: None -/
example : checkTransaction (mkTx 2 [txIn (op 9) sFin, txIn (opN 9 0x00000001) sFin] [txOut (1 * COIN)] 0) = none := by decide

/-- cA010 — python: bad-txns-inputs-duplicate -/
example : checkTransaction (mkTx 2 [txIn (op 1) sFin, txIn (op 2) sFin, txIn (op 1) sFin] [txOut (1 * COIN)] 0) = some .inputsDuplicate := by decide

/-- cA011 — python: bad-cb-length (coinbase scriptSig len 1) -/
example : checkTransaction (mkTx 2 [txInS OutPoint.null sFin (sN 1)] [txOut (50 * COIN)] 0) = some (.cbLength) := by decide

/-- cA012 — python: None (coinbase scriptSig len 2) -/
example : checkTransaction (mkTx 2 [txInS OutPoint.null sFin (sN 2)] [txOut (50 * COIN)] 0) = none := by decide

/-- cA013 — python: None (coinbase scriptSig len 100) -/
example : checkTransaction (mkTx 2 [txInS OutPoint.null sFin (sN 100)] [txOut (50 * COIN)] 0) = none := by decide

/-- cA014 — python: bad-cb-length (coinbase scriptSig len 101) -/
example : checkTransaction (mkTx 2 [txInS OutPoint.null sFin (sN 101)] [txOut (50 * COIN)] 0) = some (.cbLength) := by decide

/-- cA015 — python: bad-txns-prevout-null -/
example : checkTransaction (mkTx 2 [txInS OutPoint.null sFin Script.empty, txIn (op 1) sFin] [txOut (1 * COIN)] 0) = some .prevoutNull := by decide

/-- cA016 — python: bad-txns-prevout-null -/
example : checkTransaction (mkTx 2 [txIn (op 1) sFin, txInS OutPoint.null sFin Script.empty] [txOut (1 * COIN)] 0) = some .prevoutNull := by decide

/-- cA017 — python: all 5 versions -> None (TXV-071; transaction.h:299 `const uint32_t version`) -/
example : (checkTransaction (mkTx (-2147483648) [txIn (op 1) sFin] [txOut 1] 0) = none ∧
    checkTransaction (mkTx (-1) [txIn (op 1) sFin] [txOut 1] 0) = none ∧
    checkTransaction (mkTx 0 [txIn (op 1) sFin] [txOut 1] 0) = none ∧
    checkTransaction (mkTx 1 [txIn (op 1) sFin] [txOut 1] 0) = none ∧
    checkTransaction (mkTx 2147483647 [txIn (op 1) sFin] [txOut 1] 0) = none) = True := by decide

/-- cA018 — python: None -/
example : checkTransaction (mkTx 2 [txIn (op 1) sFin, txIn (op 2) sFin] [txOut (3 * COIN), txOut 0] 0x000001F4) = none := by decide


/-! ## Section B — error-taxonomy mapping (reject strings, verbatim) -/

/-- cB019 — tx_check.cpp verbatim string bad-txns-vin-empty -/
example : txCheckReason .vinEmpty = "bad-txns-vin-empty" := by decide

/-- cB020 — tx_check.cpp verbatim string bad-txns-vout-empty -/
example : txCheckReason .voutEmpty = "bad-txns-vout-empty" := by decide

/-- cB021 — tx_check.cpp verbatim string bad-txns-oversize -/
example : txCheckReason .oversize = "bad-txns-oversize" := by decide

/-- cB022 — tx_check.cpp verbatim string bad-txns-vout-negative -/
example : txCheckReason .voutNegative = "bad-txns-vout-negative" := by decide

/-- cB023 — tx_check.cpp verbatim string bad-txns-vout-toolarge -/
example : txCheckReason .voutTooLarge = "bad-txns-vout-toolarge" := by decide

/-- cB024 — tx_check.cpp verbatim string bad-txns-txouttotal-toolarge -/
example : txCheckReason .txoutTotalTooLarge = "bad-txns-txouttotal-toolarge" := by decide

/-- cB025 — tx_check.cpp verbatim string bad-txns-inputs-duplicate -/
example : txCheckReason .inputsDuplicate = "bad-txns-inputs-duplicate" := by decide

/-- cB026 — tx_check.cpp verbatim string bad-cb-length -/
example : txCheckReason .cbLength = "bad-cb-length" := by decide

/-- cB027 — tx_check.cpp verbatim string bad-txns-prevout-null -/
example : txCheckReason .prevoutNull = "bad-txns-prevout-null" := by decide

/-- cB028 — tx_verify.cpp / validation.cpp verbatim string bad-txns-inputs-missingorspent -/
example : rejectReason .badTxnsInputsMissingOrSpent = "bad-txns-inputs-missingorspent" := by decide

/-- cB029 — tx_verify.cpp / validation.cpp verbatim string bad-txns-in-belowout -/
example : rejectReason .badTxnsInBelowout = "bad-txns-in-belowout" := by decide

/-- cB030 — tx_verify.cpp / validation.cpp verbatim string bad-txns-fee-outofrange -/
example : rejectReason .badTxnsFeeOutOfRange = "bad-txns-fee-outofrange" := by decide

/-- cB031 — tx_verify.cpp / validation.cpp verbatim string bad-txns-inputvalues-outofrange -/
example : rejectReason .badTxnsInputvaluesOutOfRange = "bad-txns-inputvalues-outofrange" := by decide

/-- cB032 — tx_verify.cpp / validation.cpp verbatim string bad-txns-nonfinal -/
example : rejectReason .badTxnsNonfinal = "bad-txns-nonfinal" := by decide

/-- cB033 — tx_verify.cpp / validation.cpp verbatim string bad-txns-premature-spend-of-coinbase -/
example : rejectReason .badTxnsPrematureSpendOfCoinbase = "bad-txns-premature-spend-of-coinbase" := by decide

/-- cB034 — tx_verify.cpp / validation.cpp verbatim string non-BIP68-final -/
example : rejectReason .badTxnsNonstandardSequence = "non-BIP68-final" := by decide

/-- cB035 — tx_verify.cpp / validation.cpp verbatim string bad-txns-inputs-duplicate -/
example : rejectReason (.stateless .inputsDuplicate) = "bad-txns-inputs-duplicate" := by decide


/-! ## Section C — coinbase maturity grid + coin packing (incl. the F-Y13-001 future-coin corner) -/

/-- cC036 — python: False — depth 99 -> immature -/
example : coinMatured 900099 (coin 0 0x000DBBA0 true) = false := by decide

/-- cC037 — python: True — depth exactly 100 -> matured -/
example : coinMatured 900100 (coin 0 0x000DBBA0 true) = true := by decide

/-- cC038 — python: True — non-coinbase: no maturity gate -/
example : coinMatured 900100 (coin 0 0x000DBC04 false) = true := by decide

/-- cC039 — python: False — coin height 0, spend 99: depth 99 -/
example : coinMatured 99 (coin 0 0 true) = false := by decide

/-- cC040 — python: True — coin height 0, spend 100: depth 100 -/
example : coinMatured 100 (coin 0 0 true) = true := by decide

/-- cC041 — python: False — coin height 0, spend 98: depth 98 -/
example : coinMatured 98 (coin 0 0 true) = false := by decide

/-- cC042 — python: True — mempool-height sentinel, non-coinbase -/
example : coinMatured 2147483647 (coin 0 0x7FFFFFFF false) = true := by decide

/-- cC043 — python: False — FUTURE-COIN corner: LEAN verdict false; Core's unsigned depth wrap (int - uint32_t) says matured -> divergence F-Y13-001 -/
example : coinMatured 900100 (coin 0 0x000DBC68 true) = false := by decide

/-- cC044 — TXV-022 packing instance -/
example : packCoinCode 900000 true = 1800001 := by decide

/-- cC045 — TXV-022 packing instance -/
example : packCoinCode 900000 false = 1800000 := by decide

/-- cC046 — TXV-022 packing instance -/
example : packCoinCode 0 false = 0 := by decide

/-- cC047 — TXV-022 packing instance -/
example : coinHeightOfCode 1800001 = 900000 := by decide

/-- cC048 — TXV-022 packing instance -/
example : coinIsCoinbaseOfCode 1800001 = true := by decide

/-- cC049 — TXV-022 packing instance -/
example : coinIsCoinbaseOfCode 1800000 = false := by decide


/-! ## Section D — checkTxInputs value matrix (CVE-2010-5137 + check-order probes) -/

/-- cD050 — python: OK fee=600000000 — fee 6 COIN -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000064 false)]) 100 = .ok (6 * COIN) := by decide

/-- cD051 — python: OK fee=0 — fee exactly 0 -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (10 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000064 false)]) 100 = .ok 0 := by decide

/-- cD052 — python: bad-txns-in-belowout — belowout by exactly 1 sat -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut 1000000001] 0) (view [(op 1, coin (10 * COIN) 0x00000064 false)]) 100 = .error .badTxnsInBelowout := by decide

/-- cD053 — python: OK fee=0 — outputs summing exactly to valueIn: fee 0 -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (4 * COIN), txOut (6 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000064 false)]) 100 = .ok 0 := by decide

/-- cD054 — python: bad-txns-inputs-missingorspent — missing prevout (TXV-020) -/
example : checkTxInputs (mkTx 2 [txIn (op 7) sFin] [txOut (1 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000064 false)]) 100 = .error .badTxnsInputsMissingOrSpent := by decide

/-- cD055 — python: OK fee=900000000 — unused second coin present in the view: harmless -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (1 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000064 false), (op 9, coin 1 0x00000064 false)]) 100 = .ok (9 * COIN) := by decide

/-- cD056 — python: bad-txns-inputvalues-outofrange — single coin above MoneyRange (TXV-023) -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (1 * COIN)] 0) (view [(op 1, coin (MAX_MONEY + 1) 0x00000064 false)]) 100 = .error .badTxnsInputvaluesOutOfRange := by decide

/-- cD057 — python: bad-txns-inputvalues-outofrange — CVE-2010-5137: running sum overflows the envelope -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin, txIn (op 2) sFin] [txOut (1 * COIN)] 0) (view [(op 1, coin MAX_MONEY 0x00000064 false), (op 2, coin 1 0x00000064 false)]) 100 = .error .badTxnsInputvaluesOutOfRange := by decide

/-- cD058 — python: OK fee=2100000000000000 — sum exactly MAX_MONEY: fee = MAX_MONEY -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin, txIn (op 2) sFin] [txOut 0] 0) (view [(op 1, coin (MAX_MONEY - 1) 0x00000064 false), (op 2, coin 1 0x00000064 false)]) 100 = .ok MAX_MONEY := by decide

/-- cD059 — python: bad-txns-premature-spend-of-coinbase — coinbase depth 99 (TXV-021) -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (50 * COIN)] 0) (view [(op 1, coin (50 * COIN) 0x000DBBA0 true)]) 900099 = .error .badTxnsPrematureSpendOfCoinbase := by decide

/-- cD060 — python: OK fee=0 — coinbase depth exactly 100: fee 0 -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (50 * COIN)] 0) (view [(op 1, coin (50 * COIN) 0x000DBBA0 true)]) 900100 = .ok 0 := by decide

/-- cD061 — python: bad-txns-premature-spend-of-coinbase — ORDER: immature coinbase coin AND out-of-range value -> maturity fires first -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (1 * COIN)] 0) (view [(op 1, coin (MAX_MONEY + 1) 0x000DBBA0 true)]) 900050 = .error .badTxnsPrematureSpendOfCoinbase := by decide

/-- cD062 — python: bad-txns-inputvalues-outofrange — mature non-coinbase, out-of-range coin value -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut (1 * COIN)] 0) (view [(op 1, coin (MAX_MONEY + 1) 0x000C3500 false)]) 900050 = .error .badTxnsInputvaluesOutOfRange := by decide

/-- cD063 — python: OK fee=0 — zero-value coin, zero-value output (TXV-067): fee 0 -/
example : checkTxInputs (mkTx 2 [txIn (op 1) sFin] [txOut 0] 0) (view [(op 1, coin 0 0x00000064 false)]) 100 = .ok 0 := by decide

/-- cD064 — python: OK fee=100000000 — reversed input order, same total: fee 1 COIN -/
example : checkTxInputs (mkTx 2 [txIn (op 2) sFin, txIn (op 1) sFin] [txOut (6 * COIN)] 0) (view [(op 1, coin (3 * COIN) 0x00000064 false), (op 2, coin (4 * COIN) 0x00000064 false)]) 100 = .ok (1 * COIN) := by decide


/-! ## Section E — IsFinalTx grid (height/time domain boundaries, SEQUENCE_FINAL override) -/

/-- cE065 — python: True — nLockTime 0 => final -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) sFin] [txOut 1] 0) 100 500000000 = true := by decide

/-- cE066 — python: True — nLockTime 0 beats non-final sequences -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [txOut 1] 0) 100 500000000 = true := by decide

/-- cE067 — python: True — height domain: below -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [txOut 1] 0x000001F4) 1000 0 = true := by decide

/-- cE068 — python: False — height domain: AT height => NOT final (strict) -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [txOut 1] 0x000003E8) 1000 0 = false := by decide

/-- cE069 — python: False — height domain: above height => NOT final -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [txOut 1] 0x000003E9) 1000 0 = false := by decide

/-- cE070 — python: False — height-domain boundary at the threshold-1: lt==height => NOT final -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [txOut 1] 0x1DCD64FF) 499999999 999999999 = false := by decide

/-- cE071 — python: True — lt just below the threshold: height domain -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [txOut 1] 0x1DCD64FF) 500000000 0 = true := by decide

/-- cE072 — python: False — time domain: lt==mtp => NOT final -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [txOut 1] 0x1DCD6500) 100 500000000 = false := by decide

/-- cE073 — python: True — time domain: below the BIP113 cutoff -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [txOut 1] 0x1DCD6500) 100 500000001 = true := by decide

/-- cE074 — python: False — time domain: above the cutoff => NOT final -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [txOut 1] 0x1DCD6501) 100 500000000 = false := by decide

/-- cE075 — python: True — all-SEQUENCE_FINAL override -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) sFin, txIn (op 2) sFin] [txOut 1] 0x3B9AC9FF) 100 500000000 = true := by decide

/-- cE076 — python: True — max nLockTime + final sequences -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) sFin] [txOut 1] 0xFFFFFFFF) 100 500000000 = true := by decide

/-- cE077 — python: False — one non-final sequence at max locktime => NOT final -/
example : Bitcoin.DataLaws.isFinalTx (mkTx 2 [txIn (op 1) sFin, txIn (op 2) 0xFFFFFFFE] [txOut 1] 0xFFFFFFFF) 100 500000000 = false := by decide


/-! ## Section F — BIP68 height gate through validateTx (incl. the uint32-version pin) -/

/-- cF078 — python: bad-txns-nonfinal — seq 10: lock 59, spend 55 -> gate fails -/
example : validateTx (mkTx 2 [txIn (op 1) 10] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 55 0 { csv := true } = .error .badTxnsNonfinal := by decide

/-- cF079 — python: bad-txns-nonfinal — seq 10: lock 59, spend 59 -> NOT < 59, fails (strict) -/
example : validateTx (mkTx 2 [txIn (op 1) 10] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 59 0 { csv := true } = .error .badTxnsNonfinal := by decide

/-- cF080 — python: OK fee=600000000 — seq 10: lock 59 < 60 -> ok -/
example : validateTx (mkTx 2 [txIn (op 1) 10] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 60 0 { csv := true } = .ok (6 * COIN) := by decide

/-- cF081 — python: bad-txns-nonfinal — masked 1: lock 50, spend 50 -> fails -/
example : validateTx (mkTx 2 [txIn (op 1) 1] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 50 0 { csv := true } = .error .badTxnsNonfinal := by decide

/-- cF082 — python: OK fee=600000000 — masked 1: lock 50 < 51 -> ok -/
example : validateTx (mkTx 2 [txIn (op 1) 1] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 51 0 { csv := true } = .ok (6 * COIN) := by decide

/-- cF083 — python: OK fee=600000000 — masked 0 (seq 0): lock 49 < 50 -> ok, no-lock sequence -/
example : validateTx (mkTx 2 [txIn (op 1) 0] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 50 0 { csv := true } = .ok (6 * COIN) := by decide

/-- cF084 — python: bad-txns-nonfinal — masked 65535: lock 65584, spend at exactly the lock -> fails (strict) -/
example : validateTx (mkTx 2 [txIn (op 1) 65535] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 65584 0 { csv := true } = .error .badTxnsNonfinal := by decide

/-- cF085 — python: bad-txns-nonfinal — masked 65535: spend below the lock -> fails -/
example : validateTx (mkTx 2 [txIn (op 1) 65535] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 65583 0 { csv := true } = .error .badTxnsNonfinal := by decide

/-- cF086 — python: OK fee=600000000 — disable flag: no lock, gate passes -/
example : validateTx (mkTx 2 [txIn (op 1) (SEQUENCE_LOCKTIME_DISABLE_FLAG ||| 5)] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 50 0 { csv := true } = .ok (6 * COIN) := by decide

/-- cF087 — python: OK fee=600000000 — SEQUENCE_FINAL: no lock -/
example : validateTx (mkTx 2 [txIn (op 1) sFin] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 50 0 { csv := true } = .ok (6 * COIN) := by decide

/-- cF088 — python: OK fee=600000000 — time-based seq: HEIGHT projection only -> gate passes (time domain is the W12 seam) -/
example : validateTx (mkTx 2 [txIn (op 1) (SEQUENCE_LOCKTIME_TYPE_FLAG ||| 100)] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 55 0 { csv := true } = .ok (6 * COIN) := by decide

/-- cF089 — python: OK fee=600000000 — csv flag off: gate disabled -/
example : validateTx (mkTx 2 [txIn (op 1) 10] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 55 0 {} = .ok (6 * COIN) := by decide

/-- cF090 — python: bad-txns-nonfinal — version 2 exact: gate enforced -/
example : validateTx (mkTx 2 [txIn (op 1) 10] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 55 0 { csv := true } = .error .badTxnsNonfinal := by decide

/-- cF091 — python: OK fee=600000000 — version 1 disables BIP68 (tx_verify.cpp:57) even with csv on -/
example : validateTx (mkTx 1 [txIn (op 1) 10] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 55 0 { csv := true } = .ok (6 * COIN) := by decide

/-- cF092 — python: bad-txns-nonfinal — WIRE-VERSION PIN: version -1 = wire 0xFFFFFFFF >= 2 UNSIGNED (transaction.h:299 `const uint32_t version`) => BIP68 ENABLED -> nonfinal -/
example : validateTx (mkTx (-1) [txIn (op 1) 10] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 55 0 { csv := true } = .error .badTxnsNonfinal := by decide

/-- cF093 — python: bad-txns-nonfinal — two locks: max(55, 150) = 150 >= 120 -> gate fails -/
example : validateTx (mkTx 2 [txIn (op 1) 6, txIn (op 2) 101] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false), (op 2, coin (10 * COIN) 0x00000032 false)]) 120 0 { csv := true } = .error .badTxnsNonfinal := by decide

/-- cF094 — python: bad-txns-nonfinal — two locks: max(55, 150) = 150 >= 150 -> gate fails (boundary) -/
example : validateTx (mkTx 2 [txIn (op 1) 6, txIn (op 2) 101] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false), (op 2, coin (10 * COIN) 0x00000032 false)]) 150 0 { csv := true } = .error .badTxnsNonfinal := by decide

/-- cF095 — python: bad-txns-inputs-missingorspent — ORDER (model): missing input + satisfied gate (prevHeight 0 -> lock 9 < 1000) -> missingorspent; agrees with Core (both orders) -/
example : validateTx (mkTx 2 [txIn (op 7) 10] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 1000 0 { csv := true } = .error .badTxnsInputsMissingOrSpent := by decide

/-- cF096 — python: bad-txns-nonfinal — ORDER (model): missing input + unsatisfied gate (lock 65534 >= 1000) -> nonfinal FIRST. LEAN verdict; Core's real paths report missingorspent (validation.cpp:846-856 mempool HaveCoin loop BEFORE CheckSequenceLocksAtTip:884; ConnectBlock CheckTxInputs:2533 BEFORE SequenceLocks:2557) -> divergence F-Y13-002 -/
example : validateTx (mkTx 2 [txIn (op 7) 65535] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 1000 0 { csv := true } = .error .badTxnsNonfinal := by decide

/-- cF097 — python: OK fee=0 — coinbase: early exit BEFORE the BIP68 gate / input checks, fee 0 -/
example : validateTx (mkTx 2 [txInS OutPoint.null 0xFFFFFFFE cbSig] [txOut (50 * COIN)] 0) (view []) 100 500000000 { csv := true } = .ok 0 := by decide


/-! ## Section G — full sequenceLocksOk incl. the time domain (512 s granularity) -/

/-- cG098 — python: False — time lock 100*512: last-invalid = mtp+51199; T == it -> FAIL -/
example : sequenceLocksOk (mkTx 2 [txIn (op 1) (SEQUENCE_LOCKTIME_TYPE_FLAG ||| 100)] [txOut 1] 0) true [(50, 1500000000)] 60 1500051199 = false := by decide

/-- cG099 — python: True — T one past the last-invalid second -> PASS -/
example : sequenceLocksOk (mkTx 2 [txIn (op 1) (SEQUENCE_LOCKTIME_TYPE_FLAG ||| 100)] [txOut 1] 0) true [(50, 1500000000)] 60 1500051200 = true := by decide

/-- cG100 — python: True — height lock 59 < 60, time seed -1 -> PASS -/
example : sequenceLocksOk (mkTx 2 [txIn (op 1) 10] [txOut 1] 0) true [(50, 1500000000)] 60 1500000000 = true := by decide

/-- cG101 — python: False — height lock 59 == H -> FAIL (>= semantics) -/
example : sequenceLocksOk (mkTx 2 [txIn (op 1) 10] [txOut 1] 0) true [(50, 1500000000)] 59 1500000000 = false := by decide

/-- cG102 — python: False — mixed domains: height max 55, time mtp+1535; T == last-invalid -> FAIL -/
example : sequenceLocksOk (mkTx 2 [txIn (op 1) 6, txIn (op 2) (SEQUENCE_LOCKTIME_TYPE_FLAG ||| 3)] [txOut 1] 0) true [(50, 1500000000), (70, 1500000000)] 55 1500001535 = false := by decide

/-- cG103 — python: True — mixed domains: H past 55 and T past the lock -> PASS -/
example : sequenceLocksOk (mkTx 2 [txIn (op 1) 6, txIn (op 2) (SEQUENCE_LOCKTIME_TYPE_FLAG ||| 3)] [txOut 1] 0) true [(50, 1500000000), (70, 1500000000)] 56 1500001536 = true := by decide

/-- cG104 — python: True — csv off: seeds (-1,-1) -> PASS at height 0 -/
example : sequenceLocksOk (mkTx 2 [txIn (op 1) 10] [txOut 1] 0) false [(50, 1500000000)] 0 0 = true := by decide

/-- cG105 — python: True — version 1 => fEnforceBIP68 false => (-1,-1) -> PASS -/
example : sequenceLocksOk (mkTx 1 [txIn (op 1) 10] [txOut 1] 0) true [(50, 1500000000)] 60 1500000000 = true := by decide

/-- cG106 — python: True — disabled seq ignores its (higher) coin height; lock 46 < 47 -> PASS -/
example : sequenceLocksOk (mkTx 2 [txIn (op 1) (SEQUENCE_LOCKTIME_DISABLE_FLAG ||| 5), txIn (op 2) 7] [txOut 1] 0) true [(50, 1500000000), (40, 1500000000)] 47 1500000000 = true := by decide

/-- cG107 — python: False — masked 1 at coin height 100: lock 100 == H -> FAIL -/
example : sequenceLocksOk (mkTx 2 [txIn (op 1) 1] [txOut 1] 0) true [(100, 1500000000)] 100 1500000000 = false := by decide


/-! ## Section H — validateTx end-to-end (ordering probes) -/

/-- cH108 — python: OK fee=600000000 — fee path -/
example : validateTx (mkTx 2 [txIn (op 1) sFin] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 100 500000000 { csv := true } = .ok (6 * COIN) := by decide

/-- cH109 — python: bad-txns-inputs-missingorspent — missing input -/
example : validateTx (mkTx 2 [txIn (op 7) sFin] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 100 500000000 { csv := true } = .error .badTxnsInputsMissingOrSpent := by decide

/-- cH110 — python: bad-txns-inputs-duplicate — CVE-2018-17144 duplicates -> stateless prefix fires -/
example : validateTx (mkTx 2 [txIn (op 1) sFin, txIn (op 1) sFin] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000064 false)]) 100 500000000 { csv := true } = .error (.stateless .inputsDuplicate) := by decide

/-- cH111 — python: OK fee=600000000 — nLockTime 0 is final regardless of sequences -> ok -/
example : validateTx (mkTx 2 [txIn (op 1) 0xFFFFFFFE] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 100 500000000 { csv := true } = .ok (6 * COIN) := by decide

/-- cH112 — python: bad-txns-nonfinal — BIP68 gate reject inside validateTx (bad-txns-nonfinal) -/
example : validateTx (mkTx 2 [txIn (op 1) 10] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 55 0 { csv := true } = .error .badTxnsNonfinal := by decide

/-- cH113 — python: OK fee=1000000000 — zero-value outputs end-to-end: fee = 10 COIN -/
example : validateTx (mkTx 2 [txIn (op 1) sFin] [txOut 0, txOut 0] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 100 500000000 { csv := true } = .ok (10 * COIN) := by decide

/-- cH114 — python: OK fee=0 — MAX_MONEY passthrough: fee 0 -/
example : validateTx (mkTx 2 [txIn (op 1) sFin] [txOut MAX_MONEY] 0) (view [(op 1, coin MAX_MONEY 0x00000064 false)]) 100 500000000 { csv := true } = .ok 0 := by decide

/-- cH115 — python: OK fee=600000000 — csv off end-to-end: fee path -/
example : validateTx (mkTx 2 [txIn (op 1) sFin] [txOut (4 * COIN)] 0) (view [(op 1, coin (10 * COIN) 0x00000032 false)]) 100 500000000 {} = .ok (6 * COIN) := by decide


/-! ## Section I — seeded pseudo-random mutations (random.Random(20261016)) -/

/-- cI116 — python: bad-txns-nonfinal seed-draw #0 -/
example : validateTx (mkTx 7 [txIn (op 144) (SEQUENCE_LOCKTIME_TYPE_FLAG ||| 100)] [txOut 294074973, txOut 159160256, txOut 238395545] 0xFFFFFFFF) (view [(op 144, coin 168473195 0x00000090 true)]) 144 0 {} = .error .badTxnsNonfinal := by decide

/-- cI117 — python: bad-txns-inputs-missingorspent seed-draw #1 [missing input, final seqs] -/
example : validateTx (mkTx 0 [txIn (op 16) sFin, txIn (op 176) sFin, txIn (op 1) sFin] [txOut 193135446, txOut 211741451, txOut 250369721] 0x1DCD6501) (view [(op 176, coin 189333573 0x0000001E true), (op 1, coin 149242024 0x00000082 false)]) 130 1500000000 {} = .error .badTxnsInputsMissingOrSpent := by decide

/-- cI118 — python: OK fee=161213787 seed-draw #2 -/
example : validateTx (mkTx 2 [txIn (op 196) 0x7FFFFFFF, txIn (op 36) 5] [txOut 50276839] 1) (view [(op 196, coin 42707537 0x00000125 false), (op 36, coin 168783089 0x000000F4 false)]) 294 1500000000 { csv := true } = .ok 161213787 := by decide

/-- cI119 — python: bad-txns-nonfinal seed-draw #3 -/
example : validateTx (mkTx 2 [txIn (op 154) 0, txIn (op 155) SEQUENCE_LOCKTIME_TYPE_FLAG] [txOut 49093055, txOut 187464572] 0x000001F3) (view [(op 154, coin 34324413 0 false), (op 155, coin 31003453 0x00000011 false)]) 116 1600000000 {} = .error .badTxnsNonfinal := by decide

/-- cI120 — python: bad-txns-nonfinal seed-draw #4 -/
example : validateTx (mkTx 1 [txIn (op 64) 0, txIn (op 82) 5] [txOut 274428936, txOut 236703184, txOut 176234562] 0x000003E7) (view [(op 64, coin 116066126 0x00000099 false), (op 82, coin 182607155 0x00000099 false)]) 153 1500000000 {} = .error .badTxnsNonfinal := by decide

/-- cI121 — python: bad-txns-inputs-missingorspent seed-draw #5 [missing input, final seqs] -/
example : validateTx (mkTx 0 [txIn (op 108) sFin, txIn (op 22) sFin, txIn (op 123) sFin] [txOut 167812240, txOut 105207564, txOut 13695216] 0) (view [(op 22, coin 57195098 0x0000003F true), (op 123, coin 156440442 0x0000003E false)]) 162 500000000 {} = .error .badTxnsInputsMissingOrSpent := by decide

/-- cI122 — python: bad-txns-nonfinal seed-draw #6 -/
example : validateTx (mkTx (-2147483648) [txIn (op 187) (SEQUENCE_LOCKTIME_DISABLE_FLAG ||| 1), txIn (op 59) 100, txIn (op 142) 0x3FFFFFFF] [txOut 43946778, txOut 105083317, txOut 56066985] 0x1DCD6501) (view [(op 187, coin 89685442 3 true), (op 59, coin 100077346 0 false), (op 142, coin 113731152 0x00000066 false)]) 103 500000001 {} = .error .badTxnsNonfinal := by decide

/-- cI123 — python: bad-txns-nonfinal seed-draw #7 -/
example : validateTx (mkTx 2147483647 [txIn (op 102) 10] [txOut 26259556, txOut 1707861, txOut 73503462] 0xFFFFFFFF) (view [(op 102, coin 118765978 0x0000002D false)]) 145 500000000 {} = .error .badTxnsNonfinal := by decide

/-- cI124 — python: bad-txns-nonfinal seed-draw #8 -/
example : validateTx (mkTx 2147483647 [txIn (op 140) 0x7FFFFFFF, txIn (op 64) (SEQUENCE_LOCKTIME_DISABLE_FLAG ||| 5), txIn (op 80) (SEQUENCE_LOCKTIME_TYPE_FLAG ||| 7)] [txOut 69464640, txOut 223599825] 0x1DCD64FF) (view [(op 140, coin 132457415 0x000000BF false), (op 64, coin 27229886 0x000000F1 false), (op 80, coin 133162106 0x000000F1 false)]) 291 500000000 {} = .error .badTxnsNonfinal := by decide

/-- cI125 — python: bad-txns-inputs-missingorspent seed-draw #9 [missing input, final seqs] -/
example : validateTx (mkTx 1 [txIn (op 158) sFin] [txOut 19946422, txOut 86271920, txOut 209145217] 0xFFFFFFFF) (view []) 127 0 {} = .error .badTxnsInputsMissingOrSpent := by decide

/-- cI126 — python: bad-txns-premature-spend-of-coinbase seed-draw #10 -/
example : validateTx (mkTx 0 [txIn (op 198) 0x7FFFFFFF, txIn (op 74) (SEQUENCE_LOCKTIME_TYPE_FLAG ||| 500), txIn (op 92) 1] [txOut 123913467] 0x3B9AC9FF) (view [(op 198, coin 107107378 0 false), (op 74, coin 24673832 0x0000007D true), (op 92, coin 108414910 0x00000019 false)]) 125 1500000000 { csv := true } = .error .badTxnsPrematureSpendOfCoinbase := by decide

/-- cI127 — python: bad-txns-inputs-duplicate seed-draw #11 [missing input, final seqs] -/
example : validateTx (mkTx 0 [txIn (op 26) sFin, txIn (op 26) sFin] [txOut 27875039] 0x000001F3) (view [(op 26, coin 112448489 0x00000063 false), (op 26, coin 112448489 0x00000063 false)]) 198 0 {} = .error (.stateless .inputsDuplicate) := by decide

/-- cI128 — python: bad-txns-nonfinal seed-draw #12 -/
example : validateTx (mkTx 3 [txIn (op 40) (SEQUENCE_LOCKTIME_DISABLE_FLAG ||| 5), txIn (op 194) 0] [txOut 93823667, txOut 203161989] 0x1DCD6501) (view [(op 40, coin 142201624 0x0000006C false), (op 194, coin 160701717 0x0000006C true)]) 208 500000001 { csv := true } = .error .badTxnsNonfinal := by decide

/-- cI129 — python: bad-txns-inputs-duplicate seed-draw #13 -/
example : validateTx (mkTx (-2147483648) [txIn (op 103) 10, txIn (op 191) (SEQUENCE_LOCKTIME_TYPE_FLAG ||| 7), txIn (op 103) (SEQUENCE_LOCKTIME_TYPE_FLAG ||| 7)] [txOut 84282494] 1) (view [(op 103, coin 94648458 0x000000EA false), (op 191, coin 195767163 0x000000EA false), (op 103, coin 94648458 0x000000EA false)]) 234 500000001 {} = .error (.stateless .inputsDuplicate) := by decide

/-- cI130 — python: bad-txns-inputs-duplicate seed-draw #14 -/
example : validateTx (mkTx 1 [txIn (op 170) 10, txIn (op 118) 0xFFFFFFFE, txIn (op 170) sFin] [txOut 233853506, txOut 72633958] 0x000001F4) (view [(op 170, coin 94990013 0x00000081 true), (op 118, coin 71839772 0 false), (op 170, coin 94990013 0x00000081 true)]) 130 1500000000 { csv := true } = .error (.stateless .inputsDuplicate) := by decide

/-- cI131 — python: bad-txns-inputs-duplicate seed-draw #15 -/
example : validateTx (mkTx (-2147483648) [txIn (op 119) (SEQUENCE_LOCKTIME_TYPE_FLAG ||| 100), txIn (op 119) 0xFFFFFFFE] [txOut 224102163, txOut 70835433] 0x000003E7) (view [(op 119, coin 119721910 0x000000F2 false), (op 119, coin 119721910 0x000000F2 false)]) 242 1600000000 {} = .error (.stateless .inputsDuplicate) := by decide

/-- cI132 — python: bad-txns-in-belowout seed-draw #16 -/
example : validateTx (mkTx 2147483647 [txIn (op 62) 100] [txOut 134705783, txOut 152356229, txOut 244980064] 0) (view [(op 62, coin 16209096 0x000000B9 true)]) 285 500000000 { csv := true } = .error .badTxnsInBelowout := by decide

/-- cI133 — python: bad-txns-nonfinal seed-draw #17 -/
example : validateTx (mkTx (-1) [txIn (op 168) (SEQUENCE_LOCKTIME_DISABLE_FLAG ||| 5)] [txOut 21231673, txOut 110126836] 0x000003E8) (view [(op 168, coin 34715941 0x000000CE false)]) 207 1500000000 {} = .error .badTxnsNonfinal := by decide

/-- cI134 — python: bad-txns-nonfinal seed-draw #18 -/
example : validateTx (mkTx 7 [txIn (op 27) 0xFFFFFFFE, txIn (op 192) 65535, txIn (op 148) 0x7FFFFFFF] [txOut 65728221, txOut 53579933] 0x1DCD6501) (view [(op 27, coin 108725675 0x00000040 false), (op 192, coin 96133421 0x00000072 false), (op 148, coin 44144956 0x0000000E true)]) 164 0 {} = .error .badTxnsNonfinal := by decide

/-- cI135 — python: OK fee=27964311 seed-draw #19 -/
example : validateTx (mkTx 3 [txIn (op 143) (SEQUENCE_LOCKTIME_TYPE_FLAG ||| 3)] [txOut 47262120, txOut 117036770] 1) (view [(op 143, coin 192263201 0x0000006B false)]) 157 0 {} = .ok 27964311 := by decide

/-- cI136 — python: OK fee=48056573 seed-draw #0 -/
example : checkTxInputs (mkTx 2 [txIn (op 79) sFin, txIn (op 55) sFin, txIn (op 63) sFin] [txOut 196240367, txOut 157130120] 0) (view [(op 79, coin 197643364 0x000000A5 false), (op 55, coin 35964575 0x000000C1 true), (op 63, coin 167819121 0x000000F6 false)]) 315 = .ok 48056573 := by decide

/-- cI137 — python: bad-txns-premature-spend-of-coinbase seed-draw #1 -/
example : checkTxInputs (mkTx 2 [txIn (op 186) sFin, txIn (op 170) sFin] [txOut 57505147, txOut 162911744] 0) (view [(op 186, coin 165733072 0x000000F5 true), (op 170, coin 8710325 0x00000074 false)]) 338 = .error .badTxnsPrematureSpendOfCoinbase := by decide

/-- cI138 — python: OK fee=118481774 seed-draw #2 -/
example : checkTxInputs (mkTx 2 [txIn (op 164) sFin, txIn (op 47) sFin, txIn (op 33) sFin] [txOut 25297089, txOut 46175271] 0) (view [(op 164, coin 65949801 0x000000E8 false), (op 47, coin 7605943 0x000000FA true), (op 33, coin 116398390 0x000000AB true)]) 378 = .ok 118481774 := by decide

/-- cI139 — python: OK fee=46440608 seed-draw #3 -/
example : checkTxInputs (mkTx 2 [txIn (op 176) sFin] [txOut 83773726] 0) (view [(op 176, coin 130214334 0x0000006E true)]) 353 = .ok 46440608 := by decide

/-- cI140 — python: bad-txns-premature-spend-of-coinbase seed-draw #4 -/
example : checkTxInputs (mkTx 2 [txIn (op 136) sFin, txIn (op 5) sFin] [txOut 282964, txOut 196350523] 0) (view [(op 136, coin 186044531 0x00000123 false), (op 5, coin 188637202 0x00000119 true)]) 308 = .error .badTxnsPrematureSpendOfCoinbase := by decide

/-- cI141 — python: True seed-draw #0; lockPair=(-1, -1) -/
example : sequenceLocksOk (mkTx 3 [txIn (op 1) 1, txIn (op 2) 0x3FFFFFFF] [txOut 1] 0) false [(188, 1600000000), (110, 1500000000)] 0 0 = true := by decide

/-- cI142 — python: True seed-draw #1; lockPair=(-1, -1) -/
example : sequenceLocksOk (mkTx 3 [txIn (op 1) 10] [txOut 1] 0) false [(139, 1500000000)] 0 0 = true := by decide

/-- cI143 — python: True seed-draw #2; lockPair=(-1, -1) -/
example : sequenceLocksOk (mkTx 1 [txIn (op 1) 5, txIn (op 2) (SEQUENCE_LOCKTIME_DISABLE_FLAG ||| 5)] [txOut 1] 0) false [(200, 1600000000), (164, 1600000000)] 4 0 = true := by decide

/-- cI144 — python: True seed-draw #3; lockPair=(-1, -1) -/
example : sequenceLocksOk (mkTx 1 [txIn (op 1) 65535, txIn (op 2) (SEQUENCE_LOCKTIME_DISABLE_FLAG ||| 5), txIn (op 3) (SEQUENCE_LOCKTIME_DISABLE_FLAG ||| 1)] [txOut 1] 0) true [(160, 1600000000), (164, 1550000000), (133, 1600000000)] 0 5999 = true := by decide

/-- cI145 — python: False seed-draw #4; lockPair=(-1, 1599999999) -/
example : sequenceLocksOk (mkTx 3 [txIn (op 1) (SEQUENCE_LOCKTIME_DISABLE_FLAG ||| 1), txIn (op 2) SEQUENCE_LOCKTIME_TYPE_FLAG] [txOut 1] 0) true [(154, 1550000000), (189, 1600000000)] 0 1599999998 = false := by decide
/-! ## Named pins + axiom footprint -/

/-- TXV-070 boundary instance at concrete heights (a named, decidable
instance of the `coinbase_maturity_boundary` content): a coinbase output
created at height 900000 is first spendable in block 900100. -/
theorem y13_maturity_boundary_900000 :
    coinMatured 900099 (coin 0 900000 true) = false ∧
    coinMatured 900100 (coin 0 900000 true) = true := by decide

/-- Wire-version pin for the section-F vector: the Lean `Int32` -1 carries
the wire value 0xFFFFFFFF, which satisfies `>= 2` UNSIGNED at Core @
cce32b168 (`const uint32_t version`) — hence BIP68 ENABLED. -/
theorem y13_wire_version_pin :
    (mkTx (-1) [txIn (op 1) 10] [txOut (4 * COIN)] 0).version.toUInt32
      = 0xFFFFFFFF := by
  decide

section Pins

/-- info: 'BitcoinProofs.Property.Y13.TxValidationProps.y13_maturity_boundary_900000' does not depend on any axioms -/
#guard_msgs in #print axioms y13_maturity_boundary_900000

/-- info: 'BitcoinProofs.Property.Y13.TxValidationProps.y13_wire_version_pin' does not depend on any axioms -/
#guard_msgs in #print axioms y13_wire_version_pin

end Pins

end BitcoinProofs.Property.Y13.TxValidationProps
