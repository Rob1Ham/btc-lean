import Bitcoin.Activation.Flags
import Bitcoin.Interpreter.Rules
import Bitcoin.SigHash.Theorems

/-!
# PDW5 — promotion review proofs, items TOP-21..25 (INV-129 iff-gap-fill)

PDW5 (proof-promotion review), recovery review 3, 2026-10-17.
NEW file, owned by PDW5 (claim-first: `spec/db/findings-af/PDW5.md`,
commit 5ad2d00). Sister probes: `PDW2Check.lean` (PDW2's statement
registry), `PDW5Check.lean` (this lane's pins file, db/findings-af).

## What this file is (and is NOT)

PDW5 rows TOP-21..25 = INV-129, INV-132, BLK-072, SWT-011, SCR-047 —
five **Day-1-bank promotions** (PD03 F-PD03-002/D2/D10: sorry-free
proofs already exist in `core`, rows never flipped). This file
carries the ONE piece of new math the bank was missing:

* **`cltv_flag_off`** — row INV-129 ("CLTV flag gate",
  validation.cpp:2272-2275@cce32b168) has only the ≥-BIP65-height half
  in-tree (`cltv_flag_flow`, Flags.lean:214, RC11 6800247); the
  below-height converse — the `dersig_flag_off` 1:1 twin
  (Flags.lean:207, INV-128's row-note records its existence) — was
  ABSENT. Together with `cltv_flag_flow` it closes the iff ("CLTV on
  **iff** height ≥ bip65Height" = the row contract). Tagged
  `@[rule "INV-129"]` (same-id-two-decls = the SGN-107/110
  Ecdsa-Verify + RealChecker precedent; crosscheck gate-1 scans
  `spec/proofs/**` too).

It is NOT: a Flags.lean content edit (that file = W06's, RC11-tagged,
live-suite-shared; attr-only touches there are the sanctioned
exception — see the BLK-072 stacks, recorded in the PDW5 commit); and
it is NOT the SCR-047 exec-push half (row check "OP_1NEGATE pushes
0x81" vs the in-tree `rfl` pin `encodeScriptNum (-1) = serU8 0x81` =
the *encoding* half = this promotion's honest scope; the
`stepBody`-push half = the D-STEP master-correspondence lane =
PDW1/PDW2's T10/T11/T12 interpreter-gate territory). `buriedActive`
(BLK-072) similarly: the `⇔` = in-tree `buriedActive_true`/`_false`
(AXIOM-FREE), tags attr-stacked on both by PDW5.

## Axiom pins (CI-visible guards, RC03-pattern)

Every **flip-target** of this review is pinned here (§ charter axiom-subset
[propext, Classical.choice, Quot.sound]; all five + the gap-fill are
⊆):
* `cltv_flag_off` **[propext]** (below)
* `cltv_flag_flow` [propext], `base_flags_p2sh_witness_taproot`
  [propext] (Flags.lean)
* `buriedActive_true` / `buriedActive_false` — AXIOM-FREE (Flags.lean;
  `buried_heights_mainnet` = same-family AXIOM-FREE probe (INV-127 =
  PDW2's row, not a PDW5 flip-target))
* `encodeScriptNum_1negate_0x81` — AXIOM-FREE (Rules.lean:151)
* `witnessScriptSizeOk_spec` [propext] (Theorems.lean:251; also
  `#guard_msgs`-pinned in its own file at :314)

This module is deliberately **NOT** imported by the `BitcoinProofs`
root (`proofs/BitcoinProofs.lean` = W15's closure list; the root
`lake build` is RED on pre-existing `Theorems/LedgerCor` errors —
S15/F-S15-004(b), e16-crown-debt): new-file, own-target-built,
A18-isolated = the `proofs/BitcoinProofs/Shortcuts/S05/`-pattern
(F-S15-004 note in 3b104f7 lineage). `sorry_lint` scans `core/**`
only (this file = invisible BY DESIGN, zero sorry anyway); the
`axiom_manifest` probe imports a fixed list (this file not in it =
no manifest drift). All honestly recorded in `PDW5.md`.
-/

namespace BitcoinProofs.Activation.PDW5

open Bitcoin.Activation

/-- Row **INV-129** (BLK-086, BIP65): CLTV is OFF below the buried
BIP65 height — the `←`-half of the row's iff contract, the
`dersig_flag_off` (Flags.lean:207) 1:1 twin. Away from exception
blocks (`hnone`) the base-`cltv` is `false` (the `getBlockScriptFlagsP`
`none`-branch literal) and `buriedActive P P.bip65Height height`
decides false under `hlt`. -/
@[rule "INV-129"]
theorem cltv_flag_off (P : ChainParams) (hash : BlockHash) (height : UInt32)
    (hnone : P.scriptFlagExceptions hash = none) (hlt : height < P.bip65Height) :
    (getBlockScriptFlagsP P hash height).cltv = false := by
  have hcmp : ¬ (P.bip65Height ≤ height) :=
    Nat.not_le.mpr (UInt32.lt_iff_toNat_lt.mp hlt)
  simp [getBlockScriptFlagsP, hnone, buriedActive, decide_eq_false hcmp]

end BitcoinProofs.Activation.PDW5

/-! ## Axiom guards (all flip-targets of PDW5 TOP-21..25) -/

/-- info: 'BitcoinProofs.Activation.PDW5.cltv_flag_off' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.Activation.PDW5.cltv_flag_off

/-- info: 'Bitcoin.Activation.cltv_flag_flow' depends on axioms: [propext] -/
#guard_msgs in #print axioms Bitcoin.Activation.cltv_flag_flow

/-- info: 'Bitcoin.Activation.base_flags_p2sh_witness_taproot' depends on axioms: [propext] -/
#guard_msgs in #print axioms Bitcoin.Activation.base_flags_p2sh_witness_taproot

/-- info: 'Bitcoin.Activation.buriedActive_true' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.buriedActive_true

/-- info: 'Bitcoin.Activation.buriedActive_false' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.buriedActive_false

/-- info: 'Bitcoin.Interpreter.encodeScriptNum_1negate_0x81' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Interpreter.encodeScriptNum_1negate_0x81

/-- info: 'Bitcoin.SigHash.witnessScriptSizeOk_spec' depends on axioms: [propext] -/
#guard_msgs in #print axioms Bitcoin.SigHash.witnessScriptSizeOk_spec
