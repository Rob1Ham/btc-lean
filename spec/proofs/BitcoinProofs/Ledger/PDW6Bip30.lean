import Bitcoin.Ledger.Interface
import Bitcoin.Invariants.RC09

/-!
# PDW6Bip30 — BLK-096 / BLK-097 / BLK-098 promotion proofs (BIP30 unit)

PDW6 (proof-promotion review 6, TOP-26..30), recovery review 3,
2026-10-17. Rows BLK-096 / BLK-097 / BLK-098 = the BIP30 unit:
3 rules.yaml rows over ONE vehicle, `Bitcoin.Ledger.bip30Enforced`
(Ledger/Interface.lean:354, W12; tags already attr-stacked on the
def). Promotion here = PD02 F-PD02-002 "attr+flip" class over the
read-verified sorry-free vehicle (PDW10Guards / PDW5-BLK-072 /
RC09-INV-035 attr-on-done-file precedents): constant pins, the
enforcement-iff, the three boundary batteries, and the RC09
INV-106 window link, each carrying its row's tag.

## Row semantics (split by rules.yaml notes)

- **BLK-096** (BIP30, CVE-2012-1909; CT02/CV07-cited): the
  enforcement gate row — frozen constants + the def's iff structure
  (`bip30Enforced = true ↔` not-a-duplicate-coinbase height AND
  outside the BIP34 optimization window).
- **BLK-097** (CVE-2012-1909, duplicate-coinbase heights): the two
  historical exceptions 91,842 / 91,880 (BIP30 NOT enforced — the
  CVE's own condition) + their adjacents (enforced).
- **BLK-098** (BIP34 window skip + re-enable): window-proper
  (227931, 1983702) elision boundaries and the 1,983,702 wholesale
  re-enable, linked to RC09's `bip30OptimizationWindow`
  (INV-106: inside the window `bip30Enforced = false`).

## D2a (critical)

All window theorems are stated over the D2a-FIXED def (RC SWEEP
13c827a; was the elide-window [227931, 1983702)): Core
@cce32b168 validation.cpp:2458-2461 computes
`pindexBIP34height = pindex->pprev->GetAncestor(BIP34Height)` —
null on the height-227930 parent, so 2461's second conjunct is
VACUOUS at h = 227931 and Core ENFORCES BIP30 there. Skip window
proper = (227931, 1983702): `227931 = true` pin below is the D2a
row (pre-fix it was false); matches RC09's post-fix 8-height
`#guard` table (F-S04-001 / F-Z05-001 / CV07 D2a / X11
FIND-X11-004). D2b (chain hash pin) / D2c (own-hash pins) remain
documented divergences (heights-only abstraction) — see
Block/Bip30Nuance.lean F-S04-001..006; nothing here claims them.

Axiom-pinned in-file (D2 L3), zero sorryAx; every footprint ⊆
[propext, Classical.choice, Quot.sound] (all theorems over the
vehicle inherit the def's full set; the frozen-constant pins are
axiom-free `rfl`s). Unregistered in BitcoinProofs.lean (warzone
convention: direct-lean verified, invisible to the default build).
-/

namespace BitcoinProofs.Ledger.PDW6

/-! ### BLK-096: the enforcement gate row -/

/-- BLK-096: the frozen constants — the two duplicate-coinbase
heights (CVE-2012-1909's blocks), BIP34Height = 227,931 and
BIP34_IMPLIES_BIP30_LIMIT = 1,983,702 (validation.cpp:2429,
kernel/chainparams.cpp; BLK-070's constant). Axiom-free. -/
@[rule "BLK-096"]
theorem bip30Enforced_constants :
    Bitcoin.Ledger.BIP30_DUPLICATE_COINBASE_HEIGHTS = [91842, 91880] ∧
    Bitcoin.Ledger.BIP34_HEIGHT = 227931 ∧
    Bitcoin.Ledger.BIP34_IMPLIES_BIP30_LIMIT = 1983702 := ⟨rfl, rfl, rfl⟩

/-- BLK-096 (CVE-2012-1909): the enforcement iff — `bip30Enforced`
holds exactly at non-duplicate-coinbase heights outside the BIP34
optimization window proper (D2a: `227931 < h`, so 227931 itself is
enforced). Height-only abstraction: the D2b chain-hash pin and the
2466 loop gate's own-hash pins are NOT claimed (F-S04-001..006). -/
@[rule "BLK-096"]
theorem bip30Enforced_iff (height : UInt32) :
    Bitcoin.Ledger.bip30Enforced height = true ↔
      height ∉ Bitcoin.Ledger.BIP30_DUPLICATE_COINBASE_HEIGHTS ∧
      (height ≤ Bitcoin.Ledger.BIP34_HEIGHT ∨
       Bitcoin.Ledger.BIP34_IMPLIES_BIP30_LIMIT ≤ height) := by
  unfold Bitcoin.Ledger.bip30Enforced
  simp [Bool.and_eq_true]

/-- BLK-096: the enforcement battery — the pre-duplicate era and
the historical disconnect pair (91722/91812) are enforced. -/
@[rule "BLK-096"]
theorem bip30Enforced_enforced_pins :
    Bitcoin.Ledger.bip30Enforced 0 = true ∧
    Bitcoin.Ledger.bip30Enforced 91722 = true ∧
    Bitcoin.Ledger.bip30Enforced 91812 = true :=
  ⟨rfl, rfl, rfl⟩

/-! ### BLK-097: the duplicate-coinbase exceptions (the CVE rows) -/

/-- BLK-097 (CVE-2012-1909): BIP30 is NOT enforced at exactly the
two duplicate-coinbase heights 91,842 and 91,880 — the CVE's own
enabling condition — while every adjacent height is enforced
(`by decide` over the D2c heights-only abstraction; the 91842/91880
own-hash-pins of validation.cpp:2496-2511 remain documented
divergences). -/
@[rule "BLK-097"]
theorem bip30Enforced_duplicate_pins :
    Bitcoin.Ledger.bip30Enforced 91842 = false ∧
    Bitcoin.Ledger.bip30Enforced 91880 = false ∧
    Bitcoin.Ledger.bip30Enforced 91841 = true ∧
    Bitcoin.Ledger.bip30Enforced 91843 = true ∧
    Bitcoin.Ledger.bip30Enforced 91879 = true ∧
    Bitcoin.Ledger.bip30Enforced 91881 = true :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

/-! ### BLK-098: the BIP34 optimization window (D2a) -/

/-- BLK-098: the window battery (D2a post-fix, = RC09's 8-height
`#guard` table): enforced through 227,931 inclusive (Core's
null-ancestor reading — 227931 = the LAST BIP30-ON height), elided
on the window proper (227931, 1983702), re-enabled wholesale from
1,983,702 (`BIP34_IMPLIES_BIP30_LIMIT`), i.e. 1983702 = the first
re-enabled height. -/
@[rule "BLK-098"]
theorem bip30Enforced_window_pins :
    Bitcoin.Ledger.bip30Enforced 227930 = true ∧
    Bitcoin.Ledger.bip30Enforced 227931 = true ∧
    Bitcoin.Ledger.bip30Enforced 227932 = false ∧
    Bitcoin.Ledger.bip30Enforced 1983701 = false ∧
    Bitcoin.Ledger.bip30Enforced 1983702 = true :=
  ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- BLK-098: inside the optimization window BIP30 enforcement is
OFF — RC09's INV-106 `bip30OptimizationWindow` (the soundness
precondition carrier) disables `bip30Enforced` exactly (the window
predicate IS the def's negated window conjunct, post-D2a). This is
the BLK-098 ↔ INV-106 seam: the window link is INV-106's row, the
enforcement-side face is this battery's. -/
@[rule "BLK-098"]
theorem bip30OptimizationWindow_disables (height : UInt32)
    (hw : Bitcoin.Invariants.RC09.bip30OptimizationWindow height = true) :
    Bitcoin.Ledger.bip30Enforced height = false :=
  Bitcoin.Invariants.RC09.inv106_window_disables_bip30 height hw

/-! ### Axiom pins (D2 L3)

Expected messages as docstrings on the guards; every footprint ⊆
[propext, Classical.choice, Quot.sound], zero sorryAx. -/

/-- info: 'Bitcoin.Ledger.bip30Enforced' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Ledger.bip30Enforced

/-- info: 'BitcoinProofs.Ledger.PDW6.bip30Enforced_constants' does not depend on any axioms -/
#guard_msgs in
#print axioms bip30Enforced_constants

/-- info: 'BitcoinProofs.Ledger.PDW6.bip30Enforced_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms bip30Enforced_iff

/-- info: 'BitcoinProofs.Ledger.PDW6.bip30Enforced_enforced_pins' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms bip30Enforced_enforced_pins

/-- info: 'BitcoinProofs.Ledger.PDW6.bip30Enforced_duplicate_pins' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms bip30Enforced_duplicate_pins

/-- info: 'BitcoinProofs.Ledger.PDW6.bip30Enforced_window_pins' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms bip30Enforced_window_pins

/-- info: 'BitcoinProofs.Ledger.PDW6.bip30OptimizationWindow_disables' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms bip30OptimizationWindow_disables

end BitcoinProofs.Ledger.PDW6
