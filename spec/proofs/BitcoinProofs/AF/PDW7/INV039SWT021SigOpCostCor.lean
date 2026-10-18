import Bitcoin.Interpreter.SigOps

/-!
# INV039SWT021SigOpCostCor — TOP-33/INV-039 + TOP-34/SWT-021 promotion proofs

Rows INV-039 + BLK-side alias SWT-021 (the block sigop-cost pair, one
def: `Bitcoin.Interpreter.SigOps.blockSigOpCostOk`,
validation.cpp:ConnectBlock:2566-2570 + consensus.h:17 +
tx_verify.cpp:149-168; BIP141 §Sigops).

Core anchor (cce32b168): ConnectBlock's gate

    nSigOps += GetTransactionSigOpCost(tx, ...);
    if (nSigOps > MAX_BLOCK_SIGOP_COST)   // consensus.h:17 = 80,000
      return state.Invalid("bad-blk-sigops");

`GetBlockSigOpCost` (tx_verify.cpp:149-168) = Σ per-input
`GetTransactionSigOpCost` = Σ (legacy + p2sh)·WITNESS_SCALE_FACTOR(=4)
+ Σ witness·1 — the segwit discount, exactly our `sigOpCost`
(SigOps.lean:143, `sigOpCost_eq : 4·(legacy+p2sh) + witness`).

This file = the row-face theorem tier (route-B):
the row's gate + arithmetic-structure laws. The def-side
`blockSigOpCostOk_iff` (SigOps.lean:169), `blockSigOpCost_append`
(:184) and `sigOpCost_eq` (:159) are RC04/X05 core theorems left
UNTAGGED for these rows — the promotion here restates the gate around
them (gates 1-2 of rule_crosscheck: proofs-side `@[rule]` tags satisfy
the implemented/proven row-tag law), axiom-pins everything, and flips
status. Everything is `rfl`/`rw`-herding over the frozen core defs —
no mathlib, no decide, no induction (the upstream
`blockSigOpCostOk_iff`'s `simp` carries the only propext).
-/

namespace BitcoinProofs.AF.PDW7

open Bitcoin.Interpreter.SigOps

/-! ## The 80,000-cost gate (consensus.h:17) -/

/-- INV-039/SWT-021 (the gate, `bad-blk-sigops`): a block passes the
ConnectBlock sigop-cost check iff its total per-input cost is at most
`MAX_BLOCK_SIGOP_COST` = 80,000. -/
@[rule "INV-039", rule "SWT-021"]
theorem INV039_blockSigOpCost_le_of_ok (inputs : List InputSigOps)
    (h : blockSigOpCostOk inputs = true) :
    blockSigOpCost inputs ≤ MAX_BLOCK_SIGOP_COST :=
  (blockSigOpCostOk_iff inputs).mp h

/-- INV-039/SWT-021 (gate converse): a block whose total cost is at
most 80,000 passes the check (Core's `>` = the negation of `≤`). -/
@[rule "INV-039", rule "SWT-021"]
theorem INV039_blockSigOpCostOk_of_le (inputs : List InputSigOps)
    (h : blockSigOpCost inputs ≤ MAX_BLOCK_SIGOP_COST) :
    blockSigOpCostOk inputs = true :=
  (blockSigOpCostOk_iff inputs).mpr h

/-! ## The Σ-structure (GetBlockSigOpCost = the input list fold) -/

/-- SWT-021 (empty block): the cost of the empty block is 0. -/
@[rule "SWT-021"]
theorem SWT021_blockSigOpCost_nil :
    blockSigOpCost [] = 0 := rfl

/-- SWT-021 (per-input decomposition): the cost of a one-input block
is exactly that input's cost (the fold over `[] ++ [s]`). -/
@[rule "SWT-021"]
theorem SWT021_blockSigOpCost_single (s : InputSigOps) :
    blockSigOpCost [s] = sigOpCost s := by
  simp [blockSigOpCost]

/-- INV-039 (ConnectBlock's running cost): prepending an input to an
already-legal block keeps the gate iff `sigOpCost s + old ≤ 80,000` —
the running form of the ConnectBlock check (validation.cpp:2566-2570)
over `blockSigOpCost_append` (SigOps.lean:184). -/
@[rule "INV-039"]
theorem INV039_blockSigOpCostOk_cons (s : InputSigOps)
    (inputs : List InputSigOps) :
    blockSigOpCostOk (s :: inputs) = true ↔
      sigOpCost s + blockSigOpCost inputs ≤ MAX_BLOCK_SIGOP_COST := by
  have h : s :: inputs = [s] ++ inputs := rfl
  rw [h, blockSigOpCostOk_iff, blockSigOpCost_append,
      SWT021_blockSigOpCost_single]

/-- INV-039 (block composition): the gate on the concatenation of two
blocks is the 80,000-cap on the SUM of their costs (the ConnectBlock
fold across block segments; the `bad-blk-sigops` arithmetic). -/
@[rule "INV-039"]
theorem INV039_blockSigOpCostOk_append (a b : List InputSigOps) :
    blockSigOpCostOk (a ++ b) = true ↔
      blockSigOpCost a + blockSigOpCost b ≤ MAX_BLOCK_SIGOP_COST := by
  rw [blockSigOpCostOk_iff, blockSigOpCost_append]


/-! ## L3 axiom pins (D2): drift on any of these fails the build.
All 6 theorems sorry-free; the only axiom debt is the frozen core
`blockSigOpCostOk_iff`'s `simp` bridge ([propext]; the cons/append
`rw`-herding picks up [Quot.sound] via the iff-`rw` route). `nil` =
AXIOM-FREE rfl; `single` = the one `simp [blockSigOpCost]` fold step.
Zero sorryAx everywhere (sorry_lint G1 class). -/

/-- info: 'BitcoinProofs.AF.PDW7.INV039_blockSigOpCost_le_of_ok' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.INV039_blockSigOpCost_le_of_ok

/-- info: 'BitcoinProofs.AF.PDW7.INV039_blockSigOpCostOk_of_le' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.INV039_blockSigOpCostOk_of_le

/-- info: 'BitcoinProofs.AF.PDW7.SWT021_blockSigOpCost_nil' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.SWT021_blockSigOpCost_nil

/-- info: 'BitcoinProofs.AF.PDW7.SWT021_blockSigOpCost_single' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.SWT021_blockSigOpCost_single

/-- info: 'BitcoinProofs.AF.PDW7.INV039_blockSigOpCostOk_cons' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.INV039_blockSigOpCostOk_cons

/-- info: 'BitcoinProofs.AF.PDW7.INV039_blockSigOpCostOk_append' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.INV039_blockSigOpCostOk_append

end BitcoinProofs.AF.PDW7
