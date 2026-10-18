import Bitcoin.DataLaws.Interface
import Bitcoin.TxValidation.Interface
import Bitcoin.TxValidation.Mempool
import Bitcoin.Block.Connect

/-!
# BitcoinProofs.Bip.B05.Bip68Coverage — BIP68 kill-vectors (sorry-free)

License of the audited BIP text:
`bip-0068.mediawiki` (bitcoin/bips, documentation under the repo's
CC-BY-like terms; this file quotes only rule formulas, no prose).

Every clause of BIP68 with consensus force is COVERED-WEAK in
`spec/db/rules.yaml` (rows TXV-034..041, BLK-104: implemented and proved
over the abstract defs, but `test_vector_ids: []` and the hash-pinned
corpus `spec/vectors/core/tx_{valid,invalid}.json` contains **zero**
version≥2 transactions with an active — bit31 clear, mask nonzero —
sequence).  This module lands the missing kill-vectors as concrete
sorry-free decide-theorems: each instance was computed with
an independent python3 reference (a faithful transcription of Core's
`CalculateSequenceLocks`/`EvaluateSequenceLocks`, tx_verify.cpp
@cce32b168 ≡ cce32b168, the same code embedded in the BIP text) and is
chosen so that a mutant violating the clause flips at least one pinned
verdict (mutation-thinking).

Instance naming: `b68_i<n>_<clause>`.  `prevData` entries are
`(coinHeight, coinParentMTP)` pairs — the caller seam for Core's
`block.GetAncestor(max(coinHeight-1,0)).GetMedianTimePast()`; the
`blockTime` argument is `MTP(block.pprev)` (BIP113 MTP).
-/

namespace BitcoinProofs.Bip.B05

open Bitcoin Bitcoin.Data Bitcoin.DataLaws Bitcoin.Ledger Bitcoin.TxValidation
open Bitcoin.TxValidation.Mempool Bitcoin.Block.Connect

/-! ## Reusable literals -/

/-- A minimal non-coinbase input (null prevout is fine: BIP68 algebra
never dereferences the prevout here, only the caller-supplied pair). -/
def inOf (seq : UInt32) : TxIn := ⟨OutPoint.null, Script.empty, seq⟩

def inAt (seq : UInt32) (coinH coinMTP : Int) : TxIn × (Int × Int) :=
  (inOf seq, (coinH, coinMTP))

def txOf (version : Int32) (seqs : List UInt32) : Tx :=
  ⟨version, seqs.map inOf, [], 0, []⟩

/--prevData for a single input list, paired heights/mtps.-/
def pd (pairs : List (Int × Int)) : List (Int × Int) := pairs

/-! ## I1 — TXV-034: version gate, *unsigned* cast -/

/-- Core: `static_cast<uint32_t>(tx.nVersion) >= 2` — version `-1` on the
wire is 0xFFFFFFFF, so a v`-1` tx (Int32) HAS BIP68 enabled.  Mutant:
signed `version >= 2` comparison disables BIP68 here and flips I1b. -/
def txNeg1 : Tx := txOf (-1) [0x0000000A]

/-- lockPair = (100 + 10 − 1, −1) = (109, −1). -/
theorem b68_i1a_lockpair :
    calculateSequenceLocks txNeg1 true (pd [(100, 0)]) = (109, -1) := by
  decide

/-- Last invalid height 109: block 109 still rejects. -/
theorem b68_i1b_invalid :
    sequenceLocksOk txNeg1 true (pd [(100, 0)]) 109 0 = false := by
  decide

/-- Block 110 (exactly age 10) accepts. -/
theorem b68_i1c_valid :
    sequenceLocksOk txNeg1 true (pd [(100, 0)]) 110 0 = true := by
  decide

/-- Version 1: no BIP68 enforcement even at the same premature block. -/
theorem b68_i1d_v1_gate :
    sequenceLocksOk (txOf 1 [0x0000000A]) true (pd [(100, 0)]) 100 0 = true := by
  decide

/-! ## I2 — TXV-035: disable flag (bit 31), incl. SEQUENCE_FINAL -/

def txDis : Tx := txOf 2 [0x80000001, 0xFFFFFFFF]

/-- Both sequences carry bit 31 ⇒ no lock at all: valid at H = 100 even
though the masked low bits (1) would demand age ≥ 1 from coin h=100.
Mutant ignoring the disable bit: lockPair = (100, −1) ⇒ verdict flips. -/
theorem b68_i2_disable_flag :
    sequenceLocksOk txDis true (pd [(100, 0), (100, 0)]) 100 0 = true := by
  decide

theorem b68_i2_lockpair :
    calculateSequenceLocks txDis true (pd [(100, 0), (100, 0)]) = (-1, -1) := by
  decide

/-! ## I3 — TXV-037: the 0x0000ffff mask (bit 16 is OUTSIDE) -/

/-- Block-based with stray bit 16: masked RLT is 5, not 65541. -/
theorem b68_i3a_mask_height_valid :
    sequenceLocksOk (txOf 2 [0x00010005]) true (pd [(100, 0)]) 105 0 = true := by
  decide

theorem b68_i3b_mask_height_last_invalid :
    sequenceLocksOk (txOf 2 [0x00010005]) true (pd [(100, 0)]) 104 0 = false := by
  decide

/-- Time-based with stray bit 16 (seq 0x00410005): masked RLT 5 ⇒
minTime = 1000 + 5·512 − 1 = 3559.  A mutant with a wider mask reads
65541 ⇒ minTime = 33557991 ⇒ the valid-side verdict flips. -/
theorem b68_i3c_mask_time_valid :
    sequenceLocksOk (txOf 2 [0x00410005]) true (pd [(100, 1000)]) 100000 3560 = true := by
  decide

theorem b68_i3d_mask_time_last_invalid :
    sequenceLocksOk (txOf 2 [0x00410005]) true (pd [(100, 1000)]) 100000 3559 = false := by
  decide

/-! ## I4 — TXV-036: time-based ⇒ 512-second granularity (2^9) -/

/-- One masked unit demands exactly 512 s, not 600 s or 1 s:
minTime = 1000 + 512 − 1 = 1511. -/
theorem b68_i4a_granularity_valid :
    sequenceLocksOk (txOf 2 [0x00400001]) true (pd [(100, 1000)]) 100000 1512 = true := by
  decide

theorem b68_i4b_granularity_last_invalid :
    sequenceLocksOk (txOf 2 [0x00400001]) true (pd [(100, 1000)]) 100000 1511 = false := by
  decide

/-! ## I5 — TXV-037/038: height-domain last-invalid boundary -/

/-- Delay 16 from coin height 100: last invalid height = 115. -/
theorem b68_i5a_height_boundary_invalid :
    sequenceLocksOk (txOf 2 [0x00000010]) true (pd [(100, 0)]) 115 0 = false := by
  decide

theorem b68_i5b_height_boundary_valid :
    sequenceLocksOk (txOf 2 [0x00000010]) true (pd [(100, 0)]) 116 0 = true := by
  decide

/-! ## I6 — TXV-039: multi-input aggregation (max per domain,
height AND time jointly enforced) -/

/-- Two height inputs: lockPair = (max(104, 209), −1) = (209, −1). -/
theorem b68_i6a_agg_lockpair :
    calculateSequenceLocks (txOf 2 [0x00000005, 0x0000000A]) true
        (pd [(100, 0), (200, 0)]) = (209, -1) := by
  decide

theorem b68_i6b_agg_max_invalid :
    sequenceLocksOk (txOf 2 [0x00000005, 0x0000000A]) true
        (pd [(100, 0), (200, 0)]) 209 0 = false := by
  decide

theorem b68_i6c_agg_max_valid :
    sequenceLocksOk (txOf 2 [0x00000005, 0x0000000A]) true
        (pd [(100, 0), (200, 0)]) 210 0 = true := by
  decide

/-- Mixed domains: height satisfied at H=101 but time last-invalid 3559 ⇒
reject; one tick later accept.  A mutant dropping the time domain (or
the height domain) flips one side. -/
theorem b68_i6d_mixed_time_fails :
    sequenceLocksOk (txOf 2 [0x00000001, 0x00400005]) true
        (pd [(100, 0), (100, 1000)]) 101 3559 = false := by
  decide

theorem b68_i6e_mixed_both_pass :
    sequenceLocksOk (txOf 2 [0x00000001, 0x00400005]) true
        (pd [(100, 0), (100, 1000)]) 101 3560 = true := by
  decide

/-! ## I7 — zero relative locktime ⇒ any block -/

theorem b68_i7_zero_delay :
    sequenceLocksOk (txOf 2 [0x00000000]) true (pd [(7, 0)]) 7 0 = true := by
  decide

/-! ## I8 — coinbase input excluded (BLK-104 `isCoinBase ||`) -/

/-- A v2 coinbase whose (active) sequence would demand age 100 from a
h=1000 coin (last-invalid 1099) must NOT block the block at H=1001 —
contrast `b68_i8b`: the same lock pair on a non-coinbase tx fails. -/
def cbTx : Tx := txOf 2 [0x00000064]

theorem b68_i8a_coinbase_skipped :
    blockSequenceLocksOk [cbTx] true (fun _ => pd [(1000, 0)]) 1001 0 = true := by
  decide

theorem b68_i8b_noncoinbase_contrast :
    sequenceLocksOk cbTx true (pd [(1000, 0)]) 1001 0 = false := by
  decide

/-! ## I9 — TXV-040: the CSV/LOCKTIME_VERIFY_SEQUENCE flag gate -/

theorem b68_i9a_flag_off_no_enforcement :
    sequenceLocksOk cbTx false (pd [(1000, 0)]) 1001 0 = true := by
  decide

/-! ## I10 — TXV-041: mempool evaluates at tipHeight + 1 -/

/-- Coin h=1000, delay 10 ⇒ last invalid 1009.  At tip 1009 the NEXT
block 1010 accepts; at tip 1008 the next block 1009 rejects. -/
def uCoin : UtxoSet := fun _ => some ⟨1000, 1000, false, Script.empty⟩

theorem b68_i10a_tip_next_valid :
    checkSequenceLocksAtTip (txOf 2 [0x0000000A]) uCoin true 1009 = true := by
  decide

theorem b68_i10b_tip_next_invalid :
    checkSequenceLocksAtTip (txOf 2 [0x0000000A]) uCoin true 1008 = false := by
  decide

end BitcoinProofs.Bip.B05

/-! Axiom audit (rule 4): the build log must show only
`[propext, Classical.choice, Quot.sound]` (the standard trio) for every
theorem above — no sorryAx, no native_decide. -/
section AxiomAudit
open BitcoinProofs.Bip.B05
#print axioms BitcoinProofs.Bip.B05.b68_i1a_lockpair
#print axioms BitcoinProofs.Bip.B05.b68_i1b_invalid
#print axioms BitcoinProofs.Bip.B05.b68_i1c_valid
#print axioms BitcoinProofs.Bip.B05.b68_i1d_v1_gate
#print axioms BitcoinProofs.Bip.B05.b68_i2_disable_flag
#print axioms BitcoinProofs.Bip.B05.b68_i2_lockpair
#print axioms BitcoinProofs.Bip.B05.b68_i3a_mask_height_valid
#print axioms BitcoinProofs.Bip.B05.b68_i3b_mask_height_last_invalid
#print axioms BitcoinProofs.Bip.B05.b68_i3c_mask_time_valid
#print axioms BitcoinProofs.Bip.B05.b68_i3d_mask_time_last_invalid
#print axioms BitcoinProofs.Bip.B05.b68_i4a_granularity_valid
#print axioms BitcoinProofs.Bip.B05.b68_i4b_granularity_last_invalid
#print axioms BitcoinProofs.Bip.B05.b68_i5a_height_boundary_invalid
#print axioms BitcoinProofs.Bip.B05.b68_i5b_height_boundary_valid
#print axioms BitcoinProofs.Bip.B05.b68_i6a_agg_lockpair
#print axioms BitcoinProofs.Bip.B05.b68_i6b_agg_max_invalid
#print axioms BitcoinProofs.Bip.B05.b68_i6c_agg_max_valid
#print axioms BitcoinProofs.Bip.B05.b68_i6d_mixed_time_fails
#print axioms BitcoinProofs.Bip.B05.b68_i6e_mixed_both_pass
#print axioms BitcoinProofs.Bip.B05.b68_i7_zero_delay
#print axioms BitcoinProofs.Bip.B05.b68_i8a_coinbase_skipped
#print axioms BitcoinProofs.Bip.B05.b68_i8b_noncoinbase_contrast
#print axioms BitcoinProofs.Bip.B05.b68_i9a_flag_off_no_enforcement
#print axioms BitcoinProofs.Bip.B05.b68_i10a_tip_next_valid
#print axioms BitcoinProofs.Bip.B05.b68_i10b_tip_next_invalid
end AxiomAudit
