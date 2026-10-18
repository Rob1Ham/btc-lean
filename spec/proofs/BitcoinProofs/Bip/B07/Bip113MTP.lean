import Bitcoin.Block.Pow
import Bitcoin.Block.Connect
import Bitcoin.DataLaws.Interface
import Bitcoin.DataLaws.Laws
import Bitcoin.TxValidation.Interface
import Bitcoin.TxValidation.Mempool
import Bitcoin.Ledger.Interface
import Bitcoin.Data.Script

/-!
# BitcoinProofs.Bip.B07.Bip113MTP — BIP113 clause kill-tests

BIP113 "Median time-past as endpoint for lock-time calculations"
(bip-0113.mediawiki, License: PD — public domain). Consensus clauses:

* C1  `GetMedianTimePast`: median of the last ≤11 block times INCLUDING the
  queried index, ascending sort, middle element `(n-1)/2` (chain.h:233-244).
* C2  Consensus `IsFinalTx` calls use `GetMedianTimePast(pindexPrev)` — the
  PREVIOUS block's MTP, not the block's own (lie-able) timestamp.
* C3  The rule applies to ALL transactions, including the coinbase; a
  non-final tx is rejected (`bad-txns-nonfinal`).
* C4  Strict inequality: `nLockTime < cutoff` is final; `nLockTime == cutoff`
  is NOT final. Height domain (< 500,000,000) is unchanged by BIP113.

Every numeral below was computed by `ref_bip113.py`, a python3 mirror of the pinned
Core @ cce32b168 algorithms; `decide` makes Lean recompute from the Lean
defs, so drift from Core semantics fails the build.

Mutation kills (mutation-thinking, each verified in ref_bip113.py):
* span 12 → MTP(1000011) changes if block h-11 changes (tested: it doesn't)
* span 10 → MTP(1000011) = 1470001800 ≠ golden 1470002100
* self-excluded → MTP(1000010) = 1470001500 ≠ golden 1470001800
* ceil-median n/2 → MTP(1) of 2 blocks = 600000000 ≠ golden 500000000
* cutoff `≤` instead of `<` → lt == MTP flips final
* block-time cutoff (pre-BIP113) → lt = 1.55e9 flips final
* domain-swap at LOCKTIME_THRESHOLD → boundary tests flip
* tipH instead of tipH+1 (TXV-033) → height-domain boundary flips
* coinbase finality exemption → validateTx coinbase case flips
-/

set_option maxRecDepth 100000

namespace BitcoinProofs.Bip.B07

open Bitcoin.Data Bitcoin.DataLaws Bitcoin.Block.Pow Bitcoin.Block.Connect
open Bitcoin.TxValidation Bitcoin.TxValidation.Mempool Bitcoin.Ledger

/-! ## Chain fixture (heights 1,000,000..1,000,011; non-monotone times) -/

/-- Non-monotone times, all distinct. The outlier 1470099999 sits at
h=1,000,001, which keeps the chain BIP113-valid (`T[h] > MTP(h-1)`,
asserted below). -/
def ts : List UInt32 :=
  [1470000250, 1470099999, 1470000300, 1470001200, 1470000900, 1470001500,
   1470002100, 1470001800, 1470002400, 1470002700, 1470003000, 1470003300]

/-- Map-model accessor: `chain h = nTime(h)`, holes → none. The `1000000 ≤ h`
guard keeps `Nat`-subtraction from aliasing pre-chain heights onto index 0. -/
def chain (h : Nat) : Option UInt32 :=
  if 1000000 ≤ h then ts[h - 1000000]? else none

/-- Same chain except height 1,000,000 (the h-11 block for h=1,000,011). -/
def ts2 : List UInt32 :=
  [1479999999, 1470099999, 1470000300, 1470001200, 1470000900, 1470001500,
   1470002100, 1470001800, 1470002400, 1470002700, 1470003000, 1470003300]

def chain2 (h : Nat) : Option UInt32 :=
  if 1000000 ≤ h then ts2[h - 1000000]? else none

/-- `chain` with a hole at height 1,000,002 (map-model skip semantics). -/
def chainHoled (h : Nat) : Option UInt32 :=
  if h = 1000002 then none else chain h

/-- Golden MTP series (ref_bip113.py), used for the monotonicity instance. -/
def mtpD (h : Nat) : UInt32 := (medianTimePast chain h).getD 0

/-! ## C1: the median-of-11 definition (BLK-056) -/

theorem mtp_golden_11elem :
    medianTimePast chain 1000010 = some (1470001800 : UInt32) := by decide

theorem mtp_golden_next :
    medianTimePast chain 1000011 = some (1470002100 : UInt32) := by decide

theorem mtp_golden_ten_elem_window :
    medianTimePast chain 1000009 = some (1470001500 : UInt32) := by decide

/-- **Span killer (span ≥ 12)**: changing block h-11 does NOT move MTP(h). -/
theorem mtp_ignores_h_minus_11 :
    medianTimePast chain 1000011 = medianTimePast chain2 1000011 := by
  decide

/-- Span killer (span ≤ 10): a span-10 implementation at h=1,000,011 takes
the window T[1,000,002..1,000,011] (dropping the max outlier at h-10) whose
median — per ref_bip113.py — is 1470001800, NOT the golden 1470002100.
So `mtp_golden_next` above already fails any span-10 build; stated here as
documentation rather than a duplicate implementation of the mutation. -/
theorem mtp_ten_window_mutation_value :
    mtpD 1000011 ≠ 1470001800 := by decide

/-! ## C1': monotonicity of MTP along the (time-too-old-valid) chain -/

/-- The fixture chain is BIP113-valid: every block time strictly exceeds
the parent's MTP (this is BLK-057's `time-too-old` gate). -/
theorem fixture_time_too_old :
    (ts.getD 1 0).toNat > (mtpD 1000000).toNat ∧
    (ts.getD 2 0).toNat > (mtpD 1000001).toNat ∧
    (ts.getD 3 0).toNat > (mtpD 1000002).toNat ∧
    (ts.getD 4 0).toNat > (mtpD 1000003).toNat ∧
    (ts.getD 5 0).toNat > (mtpD 1000004).toNat ∧
    (ts.getD 6 0).toNat > (mtpD 1000005).toNat ∧
    (ts.getD 7 0).toNat > (mtpD 1000006).toNat ∧
    (ts.getD 8 0).toNat > (mtpD 1000007).toNat ∧
    (ts.getD 9 0).toNat > (mtpD 1000008).toNat ∧
    (ts.getD 10 0).toNat > (mtpD 1000009).toNat ∧
    (ts.getD 11 0).toNat > (mtpD 1000010).toNat := by decide

/-- BIP's motivation clause: on a valid chain MTP advances monotonically
(concrete instance over heights 1,000,004..1,000,011). -/
theorem mtp_mono_concrete :
    (mtpD 1000004).toNat ≤ (mtpD 1000005).toNat ∧
    (mtpD 1000005).toNat ≤ (mtpD 1000006).toNat ∧
    (mtpD 1000006).toNat ≤ (mtpD 1000007).toNat ∧
    (mtpD 1000007).toNat ≤ (mtpD 1000008).toNat ∧
    (mtpD 1000008).toNat ≤ (mtpD 1000009).toNat ∧
    (mtpD 1000009).toNat ≤ (mtpD 1000010).toNat ∧
    (mtpD 1000010).toNat ≤ (mtpD 1000011).toNat := by decide

/-! ## C1 edge cases: even counts, n=1, holes -/

/-- Two-block chain: even count ⇒ LOWER median, index `(n-1)/2 = 0`. -/
theorem mtp_even_count_lower_median :
    let small : Nat → Option UInt32 := fun h => if h = 0 then some 500000000
      else if h = 1 then some 600000000 else none
    medianTimePast small 1 = some (500000000 : UInt32) := by decide

/-- Genesis: single block, median = its own time. -/
theorem mtp_single_block :
    let small : Nat → Option UInt32 := fun h => if h = 0 then some 500000000 else none
    medianTimePast small 0 = some (500000000 : UInt32) := by decide

/-- Holes are skipped; median over the 5 surviving times. -/
theorem mtp_hole_skipped :
    medianTimePast chainHoled 1000005 = some (1470001200 : UInt32) := by decide

/-! ## C2 + C4: IsFinalTx cutoff semantics (INV-011..014, TXV-029) -/

/-- **Strict inequality**: `nLockTime == MTP` is NOT final. Kills the
`≤`-cutoff mutation. -/
theorem final_strict_lt_eq_cutoff :
    isFinalTx { sampleSegwitTx with locktime := 1470001800 } 800000 1470001800
      = false := by decide

theorem final_strict_lt_below_cutoff :
    isFinalTx { sampleSegwitTx with locktime := 1470001799 } 800000 1470001800
      = true := by decide

/-- INV-011: zero locktime is final even at height 0 / MTP 0. -/
theorem final_zero_boundary :
    isFinalTx sampleSegwitTx 0 0 = true := by decide

/-- INV-014/TXV-030: all-`SEQUENCE_FINAL` inputs override a future
time-domain locktime. -/
theorem final_sequence_final_override :
    isFinalTx { sampleSegwitTx with
                  locktime := 2000000000
                  vin := sampleSegwitTx.vin.map
                    (fun i => { i with sequence := SEQUENCE_FINAL }) }
      800000 1470001800 = true := by decide

/-- Domain boundary BELOW the threshold: height comparison (BIP113 leaves
this untouched). Note MTP = 0 here: the height decides. -/
theorem final_height_domain_boundary :
    isFinalTx { sampleSegwitTx with locktime := 499999999 } 500000000 0
      = true := by decide

/-- Domain boundary AT `LOCKTIME_THRESHOLD = 500000000`: time domain —
the (earlier) height 499,999,999 does NOT decide; the (later) MTP does.
Kills the threshold off-by-one mutation. -/
theorem final_time_domain_boundary :
    isFinalTx { sampleSegwitTx with locktime := 500000000 } 499999999 600000000
      = true := by decide

/-! ## C2: the BIP113 switch itself (TXV-031, BLK-067) -/

/-- TXV-031: the cutoff IS the previous block's MTP (identity pin). -/
theorem bip113Cutoff_pin : bip113Cutoff 1470002100 = 1470002100 := rfl

/-- **The heart of BIP113**: a tx whose time-domain locktime lies between
MTP(prev) and the block's own time is NON-final under BIP113 but would
have been final under the pre-BIP113 block-time rule. This is exactly the
miner-fee gaming vector the BIP removes. -/
theorem bip113_mtp_not_block_time :
    isFinalTx { sampleSegwitTx with locktime := 1550000000 } 800000
        (finalityCutoff true 1470001800 1600000000) = false ∧
    isFinalTx { sampleSegwitTx with locktime := 1550000000 } 800000
        (finalityCutoff false 1470001800 1600000000) = true := by decide

/-- BLK-057 boundary: a block time EQUAL to the parent MTP is rejected
(`time-too-old` is strict). -/
theorem time_not_too_old_strict :
    timeNotTooOld 1470003000 1470001500 = true ∧
    timeNotTooOld 1470001500 1470001500 = false := by decide

/-! ## C2 at the mempool tip (TXV-033) -/

/-- Height-domain tx is non-final AT the tip height but final for the NEXT
block: `CheckFinalTxAtTip` evaluates at `tipHeight + 1`. Kills the
evaluate-at-tip mutation. -/
theorem checkFinalTxAtTip_next_height :
    isFinalTx { sampleSegwitTx with locktime := 100 } 100 0 = false ∧
    checkFinalTxAtTip { sampleSegwitTx with locktime := 100 } 100 0 = true := by
  decide

/-- Time-domain tx: the tip height is irrelevant, the tip's MTP decides
(strictly). -/
theorem checkFinalTxAtTip_time_domain_mtp :
    checkFinalTxAtTip { sampleSegwitTx with locktime := 1470001800 } 999999 1470001800
      = false := by decide

/-! ## C3: every tx, including the coinbase (TXV-032, BLK-068) -/

/-- Lean 4.34 core ships no `DecidableEq (Except α β)` (same local patch as
`BitcoinProofs.ErrMap.E01.Test`); the coinbase vectors below decide on
`Except` equalities, so provide it locally. -/
instance instDecEqExceptB07 {α β : Type} [DecidableEq α] [DecidableEq β] :
    DecidableEq (Except α β)
  | .error e, .error e' =>
      match decEq e e' with
      | isTrue h => isTrue (by rw [h])
      | isFalse h => isFalse (by intro h2; exact h (Except.error.inj h2))
  | .ok a, .ok b =>
      match decEq a b with
      | isTrue h => isTrue (by rw [h])
      | isFalse h => isFalse (by intro h2; exact h (Except.ok.inj h2))
  | .error _, .ok _  => isFalse (by intro h; cases h)
  | .ok _, .error _  => isFalse (by intro h; cases h)

/-- A coinbase paying out with a future time-domain locktime and a
non-final input sequence. -/
def cbB07 : Tx where
  version := 2
  vin := [{ prevout := OutPoint.null
            scriptSig := scriptOf [0x51, 0x51]   -- 2 bytes: MIN_CB_LENGTH
            sequence := 1 }]
  vout := [{ value := 1000, scriptPubKey := scriptOf [0x51] }]
  locktime := 1500000000
  witness := []

/-- BIP113 "applies to the coinbase transaction": the coinbase is rejected
`bad-txns-nonfinal` when its locktime is ≥ MTP and its sequence is not
`SEQUENCE_FINAL` — finality is checked BEFORE the coinbase early-exit. -/
theorem validateTx_coinbase_nonfinal :
    validateTx cbB07 emptyUtxo 800000 1470001800 {} = .error .badTxnsNonfinal := by
  decide

/-- Same coinbase one second earlier: final, and the coinbase early-exit
returns `.ok 0` without touching the (empty) UTXO view. -/
theorem validateTx_coinbase_final_ok :
    validateTx { cbB07 with locktime := 1470001799 } emptyUtxo 800000 1470001800 {}
      = .ok 0 := by decide

/-- BLK-068: the block-level fold inherits the coinbase rule — a singleton
block (just the coinbase) fails `blockFinalityOk` under the same conditions. -/
theorem blockFinalityOk_coinbase :
    blockFinalityOk [cbB07] 800000 1470001800 = false ∧
    blockFinalityOk [{ cbB07 with locktime := 1470001799 }] 800000 1470001800
      = true := by decide

/-! ## Axiom pins (house style: bare #print axioms; info-level output only) -/

#print axioms mtp_golden_11elem
#print axioms mtp_mono_concrete
#print axioms bip113_mtp_not_block_time
#print axioms validateTx_coinbase_nonfinal
#print axioms final_strict_lt_eq_cutoff

end BitcoinProofs.Bip.B07
