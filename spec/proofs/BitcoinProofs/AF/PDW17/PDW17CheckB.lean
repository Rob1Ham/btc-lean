import Bitcoin.SigHash.Theorems

/-!
# PDW17CheckB — sorry-free / axiom-footprint check (items TOP-81..85, part B)

PDW17 (proof-promotion review, recovery RC21/RC22), 2026-10-17.
Claim `4d864b8`. PDW15CheckB / PDW11Check(B) pattern. Item:
SCR-141. Split from PDW17Check.lean (bloat rule:
per-theorem/per-import files; this one pulls the
SigHash/Theorems import chain). PD02-F-PD02-002 "22
THM-on-target" c-true remainder row (the 18-queue head,
PDW15-003 register); promotion = B-verify (this file) + yaml
flip (+ lean_target drift-fix). NOT in the BIP30R-5
ripple/frozen paths (grep-verified at claim @ef81ecf).

**NAME-DRIFT (TPR-032 / SCR-092 / SCR-101 class, 4th promoted
instance, PDW15-003 predicted)**: rules.yaml SCR-141 lean_target
= `Bitcoin.SigHash.Theorems.bip143_single_oor` but
SigHash/Theorems.lean:38 declares `namespace Bitcoin.SigHash` —
the REAL full name = **`Bitcoin.SigHash.bip143_single_oor`**
(`.Theorems.` = the MODULE name, not the namespace). Drift-fix
in flip (the PDW15CheckB/SCR-101 protocol verbatim).

Expected line = the probe1 pass-1 output verbatim
(probe1.lean, direct-lean RC=0 16:4x UTC; the
bare `#print axioms` capture = the in-file gallery pin
Theorems.lean:305 = the same line). The full charter trio
`[propext, Classical.choice, Quot.sound]` (Classical.choice via
the `hashOutputsL` `htBase`-match decidability). ZERO
`sorryAx` (Theorems.lean = the W11 S3 all-sorry-free module,
"every theorem carries an axiom pin" :7-8; sorry-scan =
doc-words only).

Elaborated + built with (foreground; proofs package env =
BitcoinProofs.AF.PDW17.PDW17CheckB; own-target flock lake
build RC=0):
  cd ./spec/proofs && lake env lean \
    BitcoinProofs/AF/PDW17/PDW17CheckB.lean
-/

namespace PDW17CheckB

/-! ## D. SCR-141 — `Bitcoin.SigHash.bip143_single_oor`
(SigHash/Theorems.lean:219, `@[rule "SCR-141", rule "SWT-046"]`
@:218; the BIP143 out-of-range SIGHASH_SINGLE law
(interpreter.cpp:1647-1653): `htBase ht = singleHt ∧
tx.vout.length ≤ nIn → hashOutputsL tx nIn ht = zeroHashL` =
NO `uint256::ONE` early return (the legacy lane
`legacyImpl_single_oor` :208 = the `singleOverflowOneB`
contrast; the tri-modal dispatch BIP341 3rd mode =
fail-closed hashtype error = SCR-166/X06, not this face).
The row face "hashOutputs = 0 (not uint256::ONE)" = the
BIP143≠legacy divergence verbatim. -/

/-- info: 'Bitcoin.SigHash.bip143_single_oor' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.SigHash.bip143_single_oor

end PDW17CheckB
