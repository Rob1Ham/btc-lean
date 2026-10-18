import BitcoinProofs.Theorems.CapstoneWeightCor
import BitcoinProofs.Theorems.BlockCor
import BitcoinProofs.Theorems.CapstonePowCor
import Bitcoin.Block.Connect

/-!
# PDW10Guards — axiom pins for the PDW10 (TOP-46..50) promotions

2026-10-17. Rows BLK-026 / BLK-034 /
BLK-036 / BLK-039 / BLK-068 promoted route A (attr-stack of
`@[rule "BLK-xxx"]` on the read-verified sorry-free S-evidence
theorem over the exact gate — PD02 F-PD02-002 "attr+flip" class,
RC03/RC09/PDW5-BLK-072 attr-only-on-done-files precedent):

- BLK-026 `Bitcoin.Capstone.Block.weightOk` (gate)
  -> `BitcoinProofs.Theorems.CapstoneWeight.weightOk_iff`
     (PD02 V-VERIFIED ≡ rule statement: `weightOk = true ↔
     3·strippedSize + totalSize ≤ 4_000_000`, by `decide_eq_true_iff`;
     870ab22, sorry-free).
- BLK-034 `Bitcoin.Block.Sigops.legacySigOpBudgetOk` (gate)
  -> `BitcoinProofs.Theorems.BlockCor.legacySigOpBudgetOk_le_20000`
     (over-gate: `legacySigOpBudgetOk = true →
     legacySigOpCountBlock ≤ 20000`; X08 b2ec835, sorry-free).
- BLK-036 `Bitcoin.Block.Sigops.blockSigOpCostOk` (gate)
  -> `BitcoinProofs.Theorems.BlockCor.blockSigOpCostOk_of_per_tx_bound`
     (over-gate: per-tx bound × length ≤ MAX_BLOCK_SIGOPS_COST →
     `blockSigOpCostOk = true`, the `foldl_const_le` lift; X08
     b2ec835, sorry-free).
- BLK-039 `Bitcoin.Capstone.Pow.powOk` (gate)
  -> `BitcoinProofs.Theorems.CapstonePow.powOk_iff_conj`
     (PD02 V-VERIFIED ≡ rule statement: `powOk = true ↔ targetOk ∧
     hashNatLE (headerHash h) ≤ compactTarget`; 870ab22,
     sorry-free).
- BLK-068 `Bitcoin.Block.Connect.blockFinalityOk` (gate)
  -> `Bitcoin.Block.Connect.blockFinalityOk_all`
     (over-gate pointwise law: `blockFinalityOk = true → ∀ t ∈ txs,
     isFinalTx t height cutoff`, `List.all_eq_true.mp`; TXV-A
     6b84737, sorry-free. STRONGER than PD02's P-grade pick
     `Bip113MTP.blockFinalityOk_coinbase:266` (decide-witness):
     the pointwise law is the row's promote-property "every tx in
     block must be final" verbatim).

The BlockTaxonomy `row_*` `@[rule]` tags (BT:328/:338/:339/:340/:345)
are `failureRow` error-taxonomy mirrors, NOT row lean_targets
(PD01-† honesty note) — the promotion tags land on the S-evidence
theorems above, per PD02's promotion semantics (`status: proven` ⇔
lean_target is a sorry-free theorem carrying `@[rule "ID"]`).

Axiom pins (house style: bare `#print axioms`, info-level output
only, B07/RC03 discipline). Expected footprints ⊆ the charter trio
`[propext, Classical.choice, Quot.sound]`, zero `sorryAx`; every
`#print axioms` line below was captured in the PDW10 build log
(direct-lean + foreground-flock module build).
-/

#print axioms BitcoinProofs.Theorems.CapstoneWeight.weightOk_iff
#print axioms BitcoinProofs.Theorems.BlockCor.legacySigOpBudgetOk_le_20000
#print axioms BitcoinProofs.Theorems.BlockCor.blockSigOpCostOk_of_per_tx_bound
#print axioms BitcoinProofs.Theorems.CapstonePow.powOk_iff_conj
#print axioms Bitcoin.Block.Connect.blockFinalityOk_all
