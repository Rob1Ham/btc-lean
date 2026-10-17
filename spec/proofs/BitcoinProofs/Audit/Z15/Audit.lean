import Bitcoin.TxValidation.Interface
import Bitcoin.Ledger.Interface
import Bitcoin.Capstone.Block

/-!
# Z15 dark-corner audit — coinbase maturity 99/100 + BIP34 height push (W4 suite)

NEW file, owned by Z15 (recovered by kicked continuation Z15-2,
2026-10-16/17). Recovery note: the Z15 predecessor landed ZERO commits;
this file was recovered UNCOMMITTED and NEVER-COMPILED (scratch
build1.log empty; first compile = 2 errors, missing `DecidableEq
(Except TxError Amount)` — fixed with the suite `instDecEqExcept` shim,
idiom E01/B07/Y01/Y02/Y13). Python3 probes: scratch
`build/scratch/build/scratch/scratch/Z15/` (`crosscheck.py`; the
predecessor's final probe looped `range(0, 2**32)` — NEVER completed —
bounded rerun `run2.log` EXIT=0: push cross-check PASS over 85545
heights [0..65535 exhaustive + 20k random + edge cases], maturity
cross-check PASS, 20k-case bip34Ok gate fuzz PASS vs a Core-faithful
`CScriptNum::getvch` + `CScript::operator<<` mirror).
Build trail: build2.log = 2 errors (pre-shim); build3.log =
`lake env lean` LEAN_EXIT=0, 0 output (Y10/RC02 B04-route, flock -w
timed out 2x, 257-waiter warzone); Audit.olean written green 23:40:38
by an in-flight holder's lake run, 47s after the last source edit.
Findings: `spec/db/findings-w4/Z15.md`.

F-Z15-002 (see findings): Core's `CScript() << nHeight`
(validation.cpp:4162) is `push_int64` (script/script.h:434-448 @
c50817f): heights {1..16} push a single OP_N OPCODE (0x51..0x60), not
a length-prefixed CScriptNum push. Lean `cbHeightPush` implements only
the getvch branch — divergence set = {1..16} exactly (python probe 2:
count 16, max 16, 0 agrees via OP_0). DEAD on mainnet (gate ≥ 227931,
`bip34Ok 227930 garbage = true` below), but LIVE the day a non-mainnet
profile parameterizes BIP34_HEIGHT (signet/testnet4/regtest bury at
0/1 — W-1 report :198). The pins below exercise 227931+, where
`cbHeightPush` is Core-exact (cross-check PASS).

Ground truth: Bitcoin Core — `consensus/consensus.h:19`
(`COINBASE_MATURITY = 100`), `consensus/tx_verify.cpp:184-188`
(`bad-txns-premature-spend-of-coinbase`), `validation.cpp:4160-4166`
(`bad-cb-height`: `CScript() << nHeight` prefix compare),
`deploymentstatus.h:13-17` (`DeploymentActiveAfter`, buried:
`(pindexPrev->nHeight + 1) >= 227931`).

## C1 — Coinbase maturity, 99/100 boundary exactness

In-tree CAPTURED: `Bitcoin.TxValidation.coinMatured` (TXV-021, per-coin
gate inside `CheckTxInputs`), `Bitcoin.Ledger.maturityOk` (BLK-100 /
INV-028, block-fold gate), the boundary theorem
`Bitcoin.TxValidation.coinbase_maturity_boundary` (TXV-070), and the
Y13 decide grid (`Property/Y13/TxValidationProps.lean` cC036-cC043).
Here: independent re-pins incl. the exact 99/100 pair at four coin
heights, both gates, and the end-to-end `checkTxInputs` error identity.

## C2 — BIP34 coinbase height push (LE CScriptNum, minimal)

In-tree CAPTURED: `Bitcoin.Capstone.Block.cbHeightPush`/`cbHeightBytes`
(BLK-069) + `bip34Ok`, with the P04 theorem module
`Theorems.CapstoneBip34Cor` (sign-byte rule, MSB-strip only, real
anchors 481824/709632/227931, vacuity below 227931).
Here: independent decide pins of the FULL GATE on the activation block
227931 — exact push passes, prev-block push fails (off-by-one trap),
non-minimal padded encoding fails (Core's minimal `CScript() << nHeight`),
short scriptSig fails (`size() < expect.size()` arm), push++rest passes
(the `std::equal` prefix arm).
-/

namespace BitcoinProofs.Audit.Z15

open Bitcoin.Data Bitcoin.TxValidation Bitcoin.Ledger Bitcoin.Capstone.Block

/-- Lean core ships no `DecidableEq (Except α β)`; the checkTxInputs
error-identity pins below decide on `Except` equalities, so provide it
locally (suite idiom: E01/Test.lean:36, B07/Bip113MTP.lean:227,
Y01/CompactSizeProps.lean:50, Y02/Corpus.lean:69,
Y13/TxValidationProps.lean:60). -/
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

/-! ### Fixtures -/

/-- A Coin created at height `h` (50 BTC, coinbase flag `cb`). -/
def mkCoin (h : UInt32) (cb : Bool) : Coin :=
  ⟨5000000000, h, cb, Script.empty⟩

/-- A spend tx: one input over `prev`, one output returning the full
50 BTC (fee 0, `MoneyRange`-clean), so `checkTxInputs` adjudicates the
maturity gate alone. -/
def spendTx : Tx :=
  ⟨2, [⟨⟨zeroBytes 32, 4294967295⟩, Script.empty, 0xFFFFFFFF⟩],
     [⟨5000000000, Script.empty⟩], 0, []⟩

/-- Single-coin view holding a coinbase coin from height `h`. -/
def cbView (h : UInt32) : UtxoSet := fun _ => some (mkCoin h true)

/-- A coinbase tx whose scriptSig is the byte list `l` (vin is a proper
null-prevout singleton, so the tx is a real coinbase shape). -/
def cbWithSS (l : List UInt8) : Tx :=
  ⟨2, [⟨⟨zeroBytes 32, 4294967295⟩, ⟨l.toByteArray⟩, 0xFFFFFFFF⟩], [], 0, []⟩

/-! ## C1 — Coinbase maturity (99/100) -/

/-- Core tx_verify.cpp:184 at depth 99 (`900099 − 900000 = 99 < 100`):
PREMATURE. -/
theorem coinMatured_99_premature :
    coinMatured 900099 (mkCoin 900000 true) = false := by decide

/-- Core tx_verify.cpp:184 at depth exactly 100: spendable. -/
theorem coinMatured_100_matured :
    coinMatured 900100 (mkCoin 900000 true) = true := by decide

/-- The same 99/100 pair at coin height 0 (the earliest coinbase). -/
example : coinMatured 99 (mkCoin 0 true) = false ∧
          coinMatured 100 (mkCoin 0 true) = true := by decide

/-- The same 99/100 pair at the BIP34 activation height 227931. -/
example : coinMatured (227931 + 99) (mkCoin 227931 true) = false ∧
          coinMatured (227931 + 100) (mkCoin 227931 true) = true := by decide

/-- Non-coinbase coins have no maturity gate (depth 0 spends fine). -/
example : coinMatured 900000 (mkCoin 900000 false) = true := by decide

/-- Block-level gate `Bitcoin.Ledger.maturityOk` (BLK-100): the spend tx
is rejected from the view at depth 99, accepted at depth 100. -/
theorem maturityOk_99_100_pair :
    maturityOk (cbView 900000) spendTx 900099 = false ∧
    maturityOk (cbView 900000) spendTx 900100 = true := by decide

/-- End-to-end through `Consensus::CheckTxInputs` (TXV-020/021/023/024):
depth 99 yields EXACTLY `bad-txns-premature-spend-of-coinbase`. -/
theorem checkTxInputs_premature_99 :
    checkTxInputs spendTx (cbView 900000) 900099
      = .error .badTxnsPrematureSpendOfCoinbase := by decide

/-- …and depth 100 returns `.ok` with fee 0. -/
theorem checkTxInputs_matured_100 :
    checkTxInputs spendTx (cbView 900000) 900100 = .ok 0 := by decide

/-- The reject string is Core's verbatim. -/
theorem rejectReason_premature_verbatim :
    rejectReason .badTxnsPrematureSpendOfCoinbase
      = "bad-txns-premature-spend-of-coinbase" := by rfl

/-! ## C2 — BIP34 coinbase height push -/

/-- `CScript() << CScriptNum(227931)` = `03 5B 7A 03` (227931 = 0x37A5B;
python3 cross-checked). The ACTIVATION BLOCK ITSELF is checked: Core
`DeploymentActiveAfter(pprev)` = `(pprev.nHeight + 1) ≥ 227931` ⇔ block
height ≥ 227931, and Lean gates on the same `BIP34_HEIGHT ≤ height`. -/
example : cbHeightPush 227931 = ([0x03, 0x5B, 0x7A, 0x03] : List UInt8).toByteArray := by
  rfl

/-- Real anchor 481824 (SegWit activation, W17 capstone run). -/
example : cbHeightPush 481824 = ([0x03, 0x20, 0x5A, 0x07] : List UInt8).toByteArray := by
  rfl

/-- Real anchor 709632: the INTERIOR zero digit is not stripped
(0x0AD400 → `00 D4 0A`; only MSB-side zeros are). -/
example : cbHeightPush 709632 = ([0x03, 0x00, 0xD4, 0x0A] : List UInt8).toByteArray := by
  rfl

/-- Sign-byte rule at the realistic domain edge: height 2^31 (top digit
0x80) pushes 5 CScriptNum bytes `00 00 00 80 00`. -/
theorem cbHeightPush_2p31 :
    cbHeightPush 2147483648
      = ([0x05, 0x00, 0x00, 0x00, 0x80, 0x00] : List UInt8).toByteArray := by
  rfl

/-- THE GATE at the activation block: exact push PASSES. -/
theorem bip34Ok_gate_activation :
    bip34Ok 227931 (cbWithSS [0x03, 0x5B, 0x7A, 0x03]) = true := by
  decide

/-- Off-by-one trap: the PREVIOUS block's push is rejected at 227931. -/
theorem bip34Ok_off_by_one :
    bip34Ok 227931 (cbWithSS [0x03, 0xFB, 0x7A, 0x02]) = false := by
  decide

/-- Vacuity just below: at 227930 the scriptSig is never inspected
(arbitrary garbage passes). -/
example : bip34Ok 227930 (cbWithSS [0x99, 0x99]) = true := by
  decide

/-- Non-minimal padded encoding (0x04-pushed with a leading zero byte):
Core's `CScript() << nHeight` is minimal, so this FAILS. -/
example : bip34Ok 227931 (cbWithSS [0x04, 0x00, 0x5B, 0x7A, 0x03]) = false := by
  decide

/-- Missing sign byte: 2^31 must be pushed WITH the 0x00 sign byte;
the 4-byte form without it FAILS. -/
example : bip34Ok 2147483648
    (cbWithSS [0x04, 0x00, 0x00, 0x00, 0x80]) = false ∧
    bip34Ok 2147483648
    (cbWithSS [0x05, 0x00, 0x00, 0x00, 0x80, 0x00]) = true := by
  decide

/-- ScriptSig SHORTER than the expected push: Core's
`scriptSig.size() < expect.size()` arm → FAIL (Lean's `extract` returns
a short array, `bytesBEq` sees unequal lengths). -/
example : bip34Ok 227931 (cbWithSS [0x03, 0x5B, 0x7A]) = false := by
  decide

/-- Empty scriptSig at an active height: FAIL. -/
example : bip34Ok 227931 (cbWithSS []) = false := by
  decide

/-- The `std::equal` prefix arm: push followed by arbitrary extra bytes
PASSES (scriptSig must START WITH the push). -/
example : bip34Ok 227931
    (cbWithSS ([0x03, 0x5B, 0x7A, 0x03] ++ [0x01, 0x02, 0x03])) = true := by
  decide

end BitcoinProofs.Audit.Z15
