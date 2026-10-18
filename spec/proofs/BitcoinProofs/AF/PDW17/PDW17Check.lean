import Bitcoin.Crypto.Taproot.Program
import Bitcoin.Crypto.Taproot.Sighash
import Bitcoin.SigHash.Theorems

/-!
# PDW17Check — sorry-free / axiom-footprint check (TOP-81..85)

PDW15Check / PDW11Check pattern (imports FIRST, module doc AFTER).
Items (CLAIM v1, `[PDW17] claim`): SCR-141, TPR-032, TPR-040, TPR-041,
TPR-046 = the PD02-F-PD02-002 "22 THM-on-target" promotion-overdue
head: each yaml `lean_target` already IS an `@[rule]`-tagged,
sorry-free core theorem. Promotion route = B-verify (this file:
verbatim qualified name resolution + guarded axiom footprint) +
rules.yaml status flip. NOT a lake build target concern: lives under
`proofs/` but is only ever elaborated directly (no core writes).

Elaborated foreground: `cd spec && lake env lean
proofs/BitcoinProofs/AF/PDW17/PDW17Check.lean` (no lock, no tree
writes).
-/

namespace PDW17Check

/-! ## SCR-141 — `Bitcoin.SigHash.bip143_single_oor`
(Theorems.lean:218-226, `@[rule "SCR-141", rule "SWT-046"]`;
BIP143 out-of-range SINGLE has NO `uint256::ONE` early return:
`hashOutputsL tx nIn ht = zeroHashL` when `vout.length ≤ nIn`.
yaml name-join drift repaired at flip: `Theorems.` -> real ns.) -/

/-- info: 'Bitcoin.SigHash.bip143_single_oor' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.SigHash.bip143_single_oor

/-! ## TPR-032 — `Bitcoin.Crypto.Taproot.sighashTaproot_epoch`
(Sighash.lean:347-351, `@[rule "TPR-032"]`; epoch byte `0x00`
first, then one TapSighash tagged hash — `rfl`.) -/

/-- info: 'Bitcoin.Crypto.Taproot.sighashTaproot_epoch' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Crypto.Taproot.sighashTaproot_epoch

/-! ## TPR-040 — `Bitcoin.Crypto.Taproot.acpSlice_acp`
(Sighash.lean:409-417, `@[rule "TPR-040"]`; ACP input slice =
outpoint ‖ full prevout ‖ nSequence.) -/

/-- info: 'Bitcoin.Crypto.Taproot.acpSlice_acp' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Crypto.Taproot.acpSlice_acp

/-! ## TPR-041 — `Bitcoin.Crypto.Taproot.acpSlice_notACP`
(Sighash.lean:400-406, `@[rule "TPR-041"]`; ¬ACP lane = 4-byte LE
input index.) -/

/-- info: 'Bitcoin.Crypto.Taproot.acpSlice_notACP' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Crypto.Taproot.acpSlice_notACP

/-! ## TPR-046 — `Bitcoin.Crypto.Taproot.sighashTaproot_size`
(Sighash.lean:331-345, `@[rule "TPR-046"]`; single-SHA256 digest is
32 bytes when `sighashTaproot = some m`.) -/

/-- info: 'Bitcoin.Crypto.Taproot.sighashTaproot_size' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Crypto.Taproot.sighashTaproot_size

/-! ## TPR-003 — `Bitcoin.Crypto.Taproot.Program.taprootLane_p2sh_wrapped`
(Program.lean:155-160, `@[rule "TPR-003"]`; a v1-32 program reached
THROUGH P2SH (`isP2SH = true`) is NOT a taproot spend: `taprootLane
_ _ _ true = false` = BIP341 "native only". yaml `lean_target`
drift-fixed from the def `taprootLane` to this theorem.) -/

/-- info: 'Bitcoin.Crypto.Taproot.Program.taprootLane_p2sh_wrapped' depends on axioms: [propext] -/
#guard_msgs in #print axioms Bitcoin.Crypto.Taproot.Program.taprootLane_p2sh_wrapped

end PDW17Check
