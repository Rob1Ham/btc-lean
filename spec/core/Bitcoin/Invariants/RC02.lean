import Bitcoin.RuleAttr
import Bitcoin.DataLaws.Interface

/-!
# Bitcoin.Invariants.RC02 — INV-015/016/021 (RC02, Rule-Closure suite)

B1 acceptance-spine invariant rows whose faithful homes sit in files owned
by *running* contributors (X08's `Block/Connect.lean`, X09's
`TxValidation/Interface.lean`): the attribute-only aliasing lane is closed
there, so these three rows get the smallest honest standalone check here,
in RC02's own namespace, cross-referenced to the running contributors' decls.

Rows closed here (B-type):

- **INV-015** — BIP113 finality-cutoff domain switch
  (`validation.cpp:ContextualCheckBlock:4141-4150`): once CSV is active the
  cutoff for `IsFinalTx`'s time comparison is the parent block's
  median-time-past, else the block's own time. Mirrors X08's
  `Bitcoin.Block.Connect.finalityCutoff` (`@[rule "BLK-067"]`).
- **INV-016** — block-level quantifier over the per-tx finality gate
  (`validation.cpp:4152-4157`, `bad-txns-nonfinal`): EVERY tx of the block
  must be final at `(height, cutoff)`. Composes W03's frozen
  `Bitcoin.DataLaws.isFinalTx` (INV-012/013) over `txs.all`; mirrors X08's
  `Bitcoin.Block.Connect.blockFinalityOk` (`@[rule "BLK-068"]`).
- **INV-021** — `EvaluateSequenceLocks` (`tx_verify.cpp:103-111`): the
  BIP68 lock-pair verdict `minH < blockHeight ∧ minT < blockTime`, where
  `blockTime` is Core's `MTP(block.prev)` caller convention. Mirrors X09's
  `Bitcoin.TxValidation.evaluateSequenceLocks` (`@[rule "TXV-039"]`).

Vectors: decide-pinned `example`s below (threshold-adjacent values,
both switch arms, block-level pass/fail, lock-pair boundaries), each
independently cross-checked in python3 (see
`spec/db/findings-rc/RC02.md`, VERIFIED section).
-/

namespace Bitcoin.Invariants.RC02

open Bitcoin.Data Bitcoin.DataLaws

/-! ## INV-015 — BIP113 cutoff switch -/

/-- The (block, BIP113-corrected) time cutoff handed to `IsFinalTx`:
the parent's median-time-past once CSV is active, else the block's own
time (`validation.cpp:4141-4150`; identical switch to X08's
`finalityCutoff`, BLK-067). -/
@[rule "INV-015"]
def bip113Cutoff (csvActive : Bool) (mtp blockTime : UInt32) : UInt32 :=
  if csvActive then mtp else blockTime

/-- The switch in both arms. -/
theorem bip113Cutoff_csv (mtp blockTime : UInt32) :
    bip113Cutoff true mtp blockTime = mtp := rfl

theorem bip113Cutoff_no_csv (mtp blockTime : UInt32) :
    bip113Cutoff false mtp blockTime = blockTime := rfl

/-- Whatever the arm, the cutoff is one of the two supplied times. -/
theorem bip113Cutoff_mem (csvActive : Bool) (mtp blockTime : UInt32) :
    bip113Cutoff csvActive mtp blockTime = mtp ∨
      bip113Cutoff csvActive mtp blockTime = blockTime := by
  cases csvActive <;> simp [bip113Cutoff]

/-! ## INV-016 — block-level finality quantifier -/

/-- **`bad-txns-nonfinal`** (`validation.cpp:4152-4157`): every tx of the
block must be final at `(height, cutoff)` — the block-level quantifier
over W03's `isFinalTx` (INV-011..014), identical fold to X08's
`blockFinalityOk` (BLK-068). -/
@[rule "INV-016"]
def blockAllFinal (txs : List Tx) (height cutoff : UInt32) : Bool :=
  txs.all (fun t => isFinalTx t height cutoff)

/-- Pointwise reading: the gate passes iff each member tx is final. -/
theorem blockAllFinal_iff (txs : List Tx) (height cutoff : UInt32) :
    blockAllFinal txs height cutoff = true ↔
      ∀ t ∈ txs, isFinalTx t height cutoff = true := by
  unfold blockAllFinal
  constructor
  · intro h t ht
    exact List.all_eq_true.mp h t ht
  · intro h
    exact List.all_eq_true.mpr h

/-- One nonfinal tx poisons the whole block. -/
theorem blockAllFinal_fail_of_nonfinal (txs : List Tx) (height cutoff : UInt32)
    (t : Tx) (ht : t ∈ txs) (hnf : isFinalTx t height cutoff = false) :
    blockAllFinal txs height cutoff = false := by
  unfold blockAllFinal
  cases h : txs.all (fun t => isFinalTx t height cutoff) with
  | true =>
    have hfin := List.all_eq_true.mp h t ht
    rw [hfin] at hnf
    simp at hnf
  | false => rfl

/-! ## INV-021 — EvaluateSequenceLocks -/

/-- `EvaluateSequenceLocks` (`tx_verify.cpp:103-111`): the BIP68 lock
pair (running maxima over the inputs' height/time lockpoints, X09's
`calculateSequenceLocks`) passes iff `minH < blockHeight ∧
minT < blockTime`, where Core's caller passes `nBlockTime =
MTP(block.prev)`. Identical verdict to X09's `evaluateSequenceLocks`
(TXV-039). -/
@[rule "INV-021"]
def evalSequenceLocks (blockHeight blockTime minH minT : Int) : Bool :=
  decide (minH < blockHeight ∧ minT < blockTime)

theorem evalSequenceLocks_iff (blockHeight blockTime minH minT : Int) :
    evalSequenceLocks blockHeight blockTime minH minT = true ↔
      minH < blockHeight ∧ minT < blockTime := by
  unfold evalSequenceLocks
  exact decide_eq_true_iff

/-- Boundary: equality on either axis fails (strict `<`). -/
theorem evalSequenceLocks_boundary_height (blockHeight blockTime minH minT : Int)
    (h : minH ≥ blockHeight) : evalSequenceLocks blockHeight blockTime minH minT = false := by
  unfold evalSequenceLocks
  simp [decide_eq_false_iff_not]
  omega

theorem evalSequenceLocks_boundary_time (blockHeight blockTime minH minT : Int)
    (h : minT ≥ blockTime) : evalSequenceLocks blockHeight blockTime minH minT = false := by
  unfold evalSequenceLocks
  simp [decide_eq_false_iff_not]
  omega

/-! ## Vectors (decide-pinned; python3-cross-checked)

Cross-check (independent python3, VERIFIED):
`bip113Cutoff(true, 1600000000, 1600000100) == 1600000000`,
`bip113Cutoff(false, 1600000000, 1600000100) == 1600000100`;
`evalSequenceLocks(100, 1600000000, 99, 1599999488)`,
`(100, 1600000000, 100, 1599999488)`, `(100, 1600000000, 99, 1600000000)`,
`(100, 1600000000, 99, 1599999489)` — see RC02.md for the transcript.
-/

/-- A one-in/one-out tx with chosen locktime/sequence (coinbase-style
null prevout). -/
def txEx (lt seq : UInt32) : Tx :=
  { version := 2
    vin := [{ prevout := OutPoint.null, scriptSig := Bitcoin.Data.Script.empty
              sequence := seq }]
    vout := [{ value := 1000, scriptPubKey := Bitcoin.Data.Script.empty }]
    locktime := lt, witness := [] }

-- INV-015: both switch arms on threshold-adjacent values.
example : bip113Cutoff true 1600000000 1600000100 = 1600000000 := rfl
example : bip113Cutoff false 1600000000 1600000100 = 1600000100 := rfl
example : bip113Cutoff true 499999999 499999998 = 499999999 := rfl

-- INV-016: time-domain tx final under BIP113 cutoff; locktime == mtp fails.
example : blockAllFinal [txEx 500000000 42] 500000001 1600000000 = true := by
  rfl
example : blockAllFinal [txEx 100 0xFFFFFFFF, txEx 500000000 42] 500000001 1600000000 = true := by
  rfl
example : blockAllFinal [txEx 100 0xFFFFFFFF, txEx 1600000000 42] 500000001 1600000000 = false := by
  rfl

-- INV-021: pass inside both axes; boundary and one-axis failures.
example : evalSequenceLocks 100 1600000000 99 1599999488 = true := by rfl
example : evalSequenceLocks 100 1600000000 100 1599999488 = false := by rfl
example : evalSequenceLocks 100 1600000000 99 1600000000 = false := by rfl
example : evalSequenceLocks 100 1600000000 99 1599999489 = true := by rfl

/-! ## Axiom pins (L3) -/

/-- info: 'Bitcoin.Invariants.RC02.bip113Cutoff_mem' depends on axioms: [propext] -/
#guard_msgs in #print axioms bip113Cutoff_mem
/-- info: 'Bitcoin.Invariants.RC02.blockAllFinal_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockAllFinal_iff
/-- info: 'Bitcoin.Invariants.RC02.blockAllFinal_fail_of_nonfinal' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockAllFinal_fail_of_nonfinal
/-- info: 'Bitcoin.Invariants.RC02.evalSequenceLocks_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms evalSequenceLocks_iff
/-- info: 'Bitcoin.Invariants.RC02.evalSequenceLocks_boundary_height' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms evalSequenceLocks_boundary_height
/-- info: 'Bitcoin.Invariants.RC02.evalSequenceLocks_boundary_time' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms evalSequenceLocks_boundary_time

end Bitcoin.Invariants.RC02
