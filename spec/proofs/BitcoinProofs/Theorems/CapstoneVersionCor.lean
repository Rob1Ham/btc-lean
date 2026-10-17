import Bitcoin.Capstone.Block

/-!
# BitcoinProofs.Theorems.CapstoneVersionCor — proved buried-version gates (P09, W17 capstone review)

The executable core's buried-version gate (W17 S2b, `Bitcoin.Capstone.Block.versionOk`,
rule rows BLK-060/061/062, Core `ContextualCheck`'s `nVersion ≥ 2/3/4` once
BIP34/BIP66/BIP65 are buried) turned from runtime booleans into proved statements.
Every gate is a decidable `UInt32`/`Int32` comparison, so all concrete anchor
instances are decided, not assumed.

**The real constants** (frozen in the core; the gate reads
`Bitcoin.Ledger.BIP34_HEIGHT` and `Bitcoin.Activation.BIP66_HEIGHT`/`BIP65_HEIGHT`):
`BIP34_HEIGHT = 227931`, `BIP66_HEIGHT = 363725` (DERSIG), `BIP65_HEIGHT = 388381` (CLTV).
They are strictly monotone-ordered (`227931 < 363725 < 388381`), pinned here.

**Honesty note on monotonicity.** Because the gates only *strengthen* as the
connection height grows, the naive upward implication
`versionOk h v = true → h ≤ h' → versionOk h' v = true` is FALSE
(counterexample proved here: `versionOk 0 1 = true` but `versionOk 481824 1 = false`).
The two true monotonicity statements are proved instead:
downward weakening (`versionOk_monotone`: passing at `h'` implies passing at any
`h ≤ h'`) and upward failure persistence (`versionOk_fail_monotone`). For the
upward direction restricted to SegWit-era `v ≥ 4` blocks, `versionOk_of_ge4`
shows the gate passes at EVERY height.

C4 portfolio linkage (rule rows via `Bitcoin.Capstone.Block`):

| C4 ID / rule      | theorem here                               | statement (short) |
|-------------------|--------------------------------------------|-------------------|
| BLK-060           | `BIP34_HEIGHT_eq` / `BIP66_HEIGHT_eq` / `BIP65_HEIGHT_eq` | the real buried heights, pinned: 227931 / 363725 / 388381 |
| BLK-060..062      | `buried_heights_ordered` | the three constants are strictly increasing |
| BLK-060/061/062   | `versionOk_decide_conj` | `versionOk` IS the `&&` of the three decidable gate implications (rfl) |
| BLK-060/061/062   | `versionOk_iff` | `versionOk h v = true` ⟺ the exact three-gate Prop conjunction |
| BLK-060           | `versionOk_true_below_all` | below 227931 every gate is vacuous: `versionOk h v = true` |
| BLK-060..062      | `versionOk_monotone` | gates only strengthen: pass at `h'` ⇒ pass at any `h ≤ h'` |
| BLK-060..062      | `versionOk_fail_monotone` | a gate failure at `h` persists at every `h' ≥ h` |
| BLK-060..062      | `versionOk_monotone_upward_counterexample` | the naive upward pass-implication is false: `(0,1)` passes, `(481824,1)` fails |
| BLK-060..062      | `versionOk_of_ge4` | `v ≥ 4` passes the gates at EVERY height |
| BLK-060           | `versionOk_genesis` | REAL anchor (genesis): `versionOk 0 1 = true` (nVersion = 1) |
| BLK-060           | `versionOk_91842_v1` | REAL anchor 91842 (BIP30 duplicate-coinbase): v1 still legal, BIP34 not yet active |
| BLK-060/061/062   | `versionOk_481824_v4` | REAL anchor 481824 (SegWit): all three gates active, v4 suffices |
| BLK-060           | `versionOk_v1_fails_after_bip34` | the bad-version lane is live: v1 rejected at every height ≥ 227931 |

Dependencies: core `Bitcoin.Capstone.Block` (read-only), `Bitcoin.Activation.Interface`,
`Bitcoin.Ledger.Interface`. Axiom footprints are pinned at the bottom of this file.
-/

namespace BitcoinProofs.Theorems.CapstoneVersion

open Bitcoin.Activation Bitcoin.Capstone.Block

/-! ## The real constants, pinned and ordered -/

/-- `Bitcoin.Ledger.BIP34_HEIGHT` is exactly 227931 (chainparams.cpp `BIP34Height`). -/
theorem BIP34_HEIGHT_eq : Bitcoin.Ledger.BIP34_HEIGHT = 227931 := rfl

/-- `Bitcoin.Activation.BIP66_HEIGHT` (DERSIG) is exactly 363725. -/
theorem BIP66_HEIGHT_eq : BIP66_HEIGHT = 363725 := rfl

/-- `Bitcoin.Activation.BIP65_HEIGHT` (CLTV) is exactly 388381. -/
theorem BIP65_HEIGHT_eq : BIP65_HEIGHT = 388381 := rfl

/-- The three buried heights are strictly increasing: `227931 < 363725 < 388381`. -/
theorem buried_heights_ordered :
    Bitcoin.Ledger.BIP34_HEIGHT < BIP66_HEIGHT ∧ BIP66_HEIGHT < BIP65_HEIGHT := by decide

/-! ## The exact shape of the gate -/

/-- **BLK-060/061/062 as an exact `decide` conjunction** (definitional): the core
gate is precisely the `&&` of the three decidable gate implications (each
`Prop` lands in `Bool` through the `decide` coercion `decPropToBool`). -/
theorem versionOk_decide_conj (height : UInt32) (version : Int32) :
    versionOk height version =
      (decide (Bitcoin.Ledger.BIP34_HEIGHT ≤ height → version ≥ 2) &&
       decide (BIP66_HEIGHT ≤ height → version ≥ 3) &&
       decide (BIP65_HEIGHT ≤ height → version ≥ 4)) := rfl

/-- **The gate as a Prop conjunction** (the Bool characterization): `versionOk`
passes exactly when each buried-height implication holds. This is the master
unfolding lemma every other theorem in this file reduces through. -/
theorem versionOk_iff (height : UInt32) (version : Int32) :
    versionOk height version = true ↔
      (Bitcoin.Ledger.BIP34_HEIGHT ≤ height → version ≥ 2) ∧
      (BIP66_HEIGHT ≤ height → version ≥ 3) ∧
      (BIP65_HEIGHT ≤ height → version ≥ 4) := by
  simp only [versionOk, decide_eq_true_eq, Bool.and_eq_true, and_assoc]

/-! ## Vacuity below all activations -/

/-- **BLK-060**: below the smallest buried height (227931) all three gate
hypotheses are false, so `versionOk` passes for EVERY version — including the
pre-BIP34 `nVersion = 1` blocks. -/
theorem versionOk_true_below_all (height : UInt32) (version : Int32)
    (hl : height < 227931) : versionOk height version = true := by
  have h34 : ¬ (Bitcoin.Ledger.BIP34_HEIGHT ≤ height) := UInt32.not_le.mpr hl
  have h66 : ¬ (BIP66_HEIGHT ≤ height) :=
    UInt32.not_le.mpr (UInt32.lt_trans hl (by decide))
  have h65 : ¬ (BIP65_HEIGHT ≤ height) :=
    UInt32.not_le.mpr (UInt32.lt_trans hl (by decide))
  rw [versionOk_iff]
  exact ⟨fun hc => absurd hc h34, fun hc => absurd hc h66, fun hc => absurd hc h65⟩

/-! ## The real anchor instances -/

/-- **REAL anchor (genesis, height 0, nVersion = 1)**: the version gate passes. -/
theorem versionOk_genesis : versionOk 0 1 = true := by decide

/-- **REAL anchor 91842** (the famous BIP30 duplicate-coinbase block): v1 is
still legal there — 91842 < 227931, so BIP34 (and hence BIP66/BIP65) is not
yet active. -/
theorem versionOk_91842_v1 : versionOk 91842 1 = true := by decide

/-- **REAL anchor 481824** (the SegWit activation height): all three buried
gates are active there (227931 ≤ 481824, 363725 ≤ 481824, 388381 ≤ 481824) and
nVersion = 4 satisfies them all. -/
theorem versionOk_481824_v4 : versionOk 481824 4 = true := by decide

/-- **BLK-060, the bad-version lane is live**: at ANY height at or above the
BIP34 burial height, `nVersion = 1` fails the gate (`bad-version`), because
gate one demands `1 ≥ 2`. -/
theorem versionOk_v1_fails_after_bip34 (height : UInt32)
    (hl : Bitcoin.Ledger.BIP34_HEIGHT ≤ height) : versionOk height 1 = false := by
  have hne : versionOk height 1 ≠ true := by
    intro hc
    have hc' := hc
    simp only [versionOk, decide_eq_true_eq, Bool.and_eq_true, and_assoc] at hc'
    obtain ⟨g34, _, _⟩ := hc'
    exact absurd (g34 hl) (by decide)
  by_cases hb : versionOk height 1 = true
  · exact absurd hb hne
  · simp at hb; exact hb

/-! ## Monotonicity (honest directions) -/

/-- **BLK-060..062, gates strengthen with height (downward weakening)**: if the
version gate passes at connection height `h'`, it passes at every earlier
`h ≤ h'` — each gate's antecedent at `h` implies the antecedent at `h'` by
`UInt32.le_trans`, so the set of active obligations only grows with height. -/
theorem versionOk_monotone (version : Int32) {height height' : UInt32}
    (hle : height ≤ height') (hv : versionOk height' version = true) :
    versionOk height version = true := by
  obtain ⟨g34, g66, g65⟩ := (versionOk_iff height' version).mp hv
  rw [versionOk_iff]
  exact ⟨fun hc => g34 (UInt32.le_trans hc hle),
         fun hc => g66 (UInt32.le_trans hc hle),
         fun hc => g65 (UInt32.le_trans hc hle)⟩

/-- **BLK-060..062, failure persists upward**: a block whose version fails the
gate at height `h` fails it at every connection height `h' ≥ h` (the
contrapositive companion of `versionOk_monotone`; by `Bool` case-splitting, so
no choice axiom is needed). -/
theorem versionOk_fail_monotone (version : Int32) {height height' : UInt32}
    (hle : height ≤ height') (hf : versionOk height version = false) :
    versionOk height' version = false := by
  by_cases hok : versionOk height' version = true
  · exact absurd (versionOk_monotone version hle hok) (by simp [hf])
  · exact (Bool.not_eq_true _).mp hok

/-- **BLK-060..062, SegWit-era blocks pass everywhere**: any `nVersion ≥ 4`
satisfies all three gates at EVERY connection height, since `2 ≤ 3 ≤ 4` in
`Int32`. In particular the naive upward monotonicity implication holds
verbatim for `v ≥ 4` blocks. -/
theorem versionOk_of_ge4 (height : UInt32) (version : Int32)
    (hv : (4 : Int32) ≤ version) : versionOk height version = true := by
  rw [versionOk_iff]
  exact ⟨fun _ => Int32.le_trans (by decide) hv,
         fun _ => Int32.le_trans (by decide) hv,
         fun _ => hv⟩

/-- **The naive upward pass-implication is FALSE** — the witness: the real
genesis pair `(height 0, nVersion 1)` passes, but `(481824, 1)` fails
(481824 ≥ 227931 has all three gates active and v1 < 4). This is why
`versionOk_monotone` is stated in the downward direction. -/
theorem versionOk_monotone_upward_counterexample :
    versionOk 0 1 = true ∧ versionOk 481824 1 = false :=
  ⟨versionOk_genesis, versionOk_v1_fails_after_bip34 481824 (by decide)⟩

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.BIP34_HEIGHT_eq' does not depend on any axioms -/
#guard_msgs in #print axioms BIP34_HEIGHT_eq

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.BIP66_HEIGHT_eq' does not depend on any axioms -/
#guard_msgs in #print axioms BIP66_HEIGHT_eq

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.BIP65_HEIGHT_eq' does not depend on any axioms -/
#guard_msgs in #print axioms BIP65_HEIGHT_eq

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.buried_heights_ordered' does not depend on any axioms -/
#guard_msgs in #print axioms buried_heights_ordered

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.versionOk_decide_conj' does not depend on any axioms -/
#guard_msgs in #print axioms versionOk_decide_conj

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.versionOk_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms versionOk_iff

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.versionOk_true_below_all' depends on axioms: [propext] -/
#guard_msgs in #print axioms versionOk_true_below_all

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.versionOk_genesis' does not depend on any axioms -/
#guard_msgs in #print axioms versionOk_genesis

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.versionOk_91842_v1' does not depend on any axioms -/
#guard_msgs in #print axioms versionOk_91842_v1

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.versionOk_481824_v4' does not depend on any axioms -/
#guard_msgs in #print axioms versionOk_481824_v4

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.versionOk_v1_fails_after_bip34' depends on axioms: [propext] -/
#guard_msgs in #print axioms versionOk_v1_fails_after_bip34

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.versionOk_monotone' depends on axioms: [propext] -/
#guard_msgs in #print axioms versionOk_monotone

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.versionOk_fail_monotone' depends on axioms: [propext] -/
#guard_msgs in #print axioms versionOk_fail_monotone

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.versionOk_of_ge4' depends on axioms: [propext] -/
#guard_msgs in #print axioms versionOk_of_ge4

/-- info: 'BitcoinProofs.Theorems.CapstoneVersion.versionOk_monotone_upward_counterexample' depends on axioms: [propext] -/
#guard_msgs in #print axioms versionOk_monotone_upward_counterexample

end BitcoinProofs.Theorems.CapstoneVersion
