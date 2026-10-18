import Bitcoin.Activation.Interface

/-!
# BitcoinProofs.Theorems.FlagsCor — flag-monotonicity corollaries (sorry-free)

Corollaries of proved flag laws (`Bitcoin.Activation`,
`research/w2-06-flags-activation.md`). Zero-dependency.

C4 portfolio linkage:

| C4 ID    | theorem here | statement (short) |
|----------|--------------|-------------------|
| (SCR-015 cor) | `flags_base_true` | away from the two exception blocks, {P2SH, WITNESS, TAPROOT} are ALWAYS on (validation.cpp:2256-2260) |
| (SCR-016 cor) | `flags_taproot_iff` | TAPROOT is on ⟺ the height is not one of the two exception blocks |
| (SCR-016 cor) | `flags_p2sh_iff` | P2SH is off ⟺ exactly at the BIP16 exception block 170060 |
| (SCR-011..014 cor) | `flags_dersig_iff` / `flags_cltv_iff` / `flags_csv_iff` / `flags_nulldummy_iff` | each buried flag is on ⟺ height ≥ its burial height (off-exception) |
| (BLK-083 vec) | `flags_genesis_exact` | the exact mainnet genesis flag vector |
| (BLK-072 pin) | `nullDummy_iff_segwit` | NULLDUMMY activates exactly with SegWit (BIP147 rides segwit) |
| (BLK-074 cor) | `bip9_active_stable` | once a BIP9 deployment is ACTIVE it stays ACTIVE across periods |

Dependencies: `flags_norm`, `flags_bip16_exception`, `flags_taproot_exception`,
`flags_exception_blocks`, `bip9State_next_period` (all sorry-free).
-/

namespace BitcoinProofs.Theorems.FlagsCor

open Bitcoin.Activation

/-! ## Base-set corollaries -/

/-- Away from the two exception blocks the always-on base set
{P2SH, WITNESS, TAPROOT} is present at EVERY height (validation.cpp:2256-2260). -/
theorem flags_base_true (height : UInt32)
    (h₁ : height ≠ BIP16_EXCEPTION_HEIGHT) (h₂ : height ≠ TAPROOT_EXCEPTION_HEIGHT) :
    (getBlockScriptFlags height).p2sh = true ∧
    (getBlockScriptFlags height).witness = true ∧
    (getBlockScriptFlags height).taproot = true := by
  rw [flags_norm height h₁ h₂]
  exact ⟨rfl, rfl, rfl⟩

/-- TAPROOT is on exactly at the non-exception heights (the two exception
blocks drop it — interface-change note 4 of the frozen interface). -/
theorem flags_taproot_iff (height : UInt32) :
    (getBlockScriptFlags height).taproot = true ↔ height ∉ EXCEPTION_HEIGHTS := by
  constructor
  · intro h hc
    have hoff := flags_exception_blocks height hc
    rw [hoff] at h
    exact Bool.noConfusion h
  · intro h
    obtain ⟨h₁, h₂⟩ := by
      simp [EXCEPTION_HEIGHTS] at h
      exact h
    exact (flags_base_true height h₁ h₂).2.2

/-- P2SH is off exactly at the BIP16 exception block 170060 (it is on at
the taproot exception block 692261 and everywhere else). -/
theorem flags_p2sh_iff (height : UInt32) :
    (getBlockScriptFlags height).p2sh = true ↔ height ≠ BIP16_EXCEPTION_HEIGHT := by
  constructor
  · intro h hc
    rw [hc, congrArg ScriptFlags.p2sh flags_bip16_exception] at h
    simp at h
  · intro h
    by_cases h2 : height = TAPROOT_EXCEPTION_HEIGHT
    · rw [h2]; exact congrArg ScriptFlags.p2sh flags_taproot_exception
    · exact (flags_base_true height h h2).1

/-! ## Buried-flag characterizations (off-exception) -/

/-- DERSIG (BIP66) is on ⟺ height ≥ 363725, away from exception blocks. -/
theorem flags_dersig_iff (height : UInt32)
    (h₁ : height ≠ BIP16_EXCEPTION_HEIGHT) (h₂ : height ≠ TAPROOT_EXCEPTION_HEIGHT) :
    (getBlockScriptFlags height).dersig = true ↔ BIP66_HEIGHT ≤ height := by
  rw [flags_norm height h₁ h₂]
  exact decide_eq_true_iff

/-- CLTV (BIP65) is on ⟺ height ≥ 388381, away from exception blocks. -/
theorem flags_cltv_iff (height : UInt32)
    (h₁ : height ≠ BIP16_EXCEPTION_HEIGHT) (h₂ : height ≠ TAPROOT_EXCEPTION_HEIGHT) :
    (getBlockScriptFlags height).cltv = true ↔ BIP65_HEIGHT ≤ height := by
  rw [flags_norm height h₁ h₂]
  exact decide_eq_true_iff

/-- CSV (BIP68/112/113) is on ⟺ height ≥ 419328, away from exception blocks. -/
theorem flags_csv_iff (height : UInt32)
    (h₁ : height ≠ BIP16_EXCEPTION_HEIGHT) (h₂ : height ≠ TAPROOT_EXCEPTION_HEIGHT) :
    (getBlockScriptFlags height).csv = true ↔ CSV_HEIGHT ≤ height := by
  rw [flags_norm height h₁ h₂]
  exact decide_eq_true_iff

/-- NULLDUMMY (BIP147) is on ⟺ height ≥ 481824, away from exception blocks. -/
theorem flags_nulldummy_iff (height : UInt32)
    (h₁ : height ≠ BIP16_EXCEPTION_HEIGHT) (h₂ : height ≠ TAPROOT_EXCEPTION_HEIGHT) :
    (getBlockScriptFlags height).nullDummy = true ↔ BIP147_HEIGHT ≤ height := by
  rw [flags_norm height h₁ h₂]
  exact decide_eq_true_iff

/-- BLK-072 (BIP147 rides SegWit): NULLDUMMY and WITNESS switch on at the
SAME height — `BIP147_HEIGHT = SEGWIT_HEIGHT = 481824` exactly. -/
theorem nullDummy_iff_segwit (height : UInt32)
    (h₁ : height ≠ BIP16_EXCEPTION_HEIGHT) (h₂ : height ≠ TAPROOT_EXCEPTION_HEIGHT) :
    ((getBlockScriptFlags height).nullDummy = true ↔ SEGWIT_HEIGHT ≤ height) ∧
    (BIP147_HEIGHT = SEGWIT_HEIGHT) := by
  refine ⟨?_, rfl⟩
  rw [flags_nulldummy_iff height h₁ h₂]
  exact Iff.rfl

/-- BLK-083: the exact mainnet genesis flag vector (height 0 is below every
buried height and is not an exception block). -/
theorem flags_genesis_exact :
    getBlockScriptFlags 0 =
      { p2sh := true, dersig := false, cltv := false, csv := false,
        nullDummy := false, witness := true, taproot := true } := by
  decide

/-! ## BIP9: activation is absorbing -/

/-- Helper (companion of `bip9StateByPeriod_lockIn_atStart`): an
ACTIVE period state can only arise post-start. -/
theorem bip9StateByPeriod_active_atStart (P : Bip9Params) (k : Nat)
    (hl : bip9StateByPeriod P k = .active) :
    ¬ (bip9BoundaryHeight P k < P.start) := by
  cases k with
  | zero =>
    simp only [bip9StateByPeriod] at hl
    by_cases hb : bip9BoundaryHeight P 0 < P.start
    · rw [ite_eq_left hb] at hl; exact absurd hl (by simp)
    · exact hb
  | succ k' =>
    simp only [bip9StateByPeriod] at hl
    by_cases hb : bip9BoundaryHeight P (k' + 1) < P.start
    · rw [ite_eq_left hb] at hl; exact absurd hl (by simp)
    · exact hb

/-- BLK-074 corollary: BIP9 ACTIVATION IS ABSORBING — once the machine is
ACTIVE at height `h`, it is still ACTIVE a full confirmation period later
(versionbits.cpp:100-104: the ACTIVE transition never leaves ACTIVE; the
timeout plays no role, exactly as for `lockin_survives_timeout`). -/
theorem bip9_active_stable (P : Bip9Params) (h : Nat)
    (hP : 0 < P.period)
    (hactive : bip9State P h = .active) :
    bip9State P (h + P.period) = .active := by
  have hP0 : P.period ≠ 0 := by omega
  have hk : P.period ≤ h + 1 := by
    by_cases hc : P.period ≤ h + 1
    · exact hc
    · rw [bip9State_pre P h (by omega)] at hactive
      exact absurd hactive (by simp)
  have hk1 : 0 < (h + 1) / P.period := Nat.div_pos hk hP
  have hstate : bip9StateByPeriod P ((h + 1) / P.period - 1) = .active := by
    rw [← bip9State_eq P hP0 h hk]; exact hactive
  have hbstart : ¬ (bip9BoundaryHeight P ((h + 1) / P.period) < P.start) := by
    have hnb := bip9StateByPeriod_active_atStart P ((h + 1) / P.period - 1) hstate
    have hmono := bip9BoundaryHeight_succ P ((h + 1) / P.period - 1)
    rw [show ((h + 1) / P.period - 1) + 1 = (h + 1) / P.period from by omega] at hmono
    omega
  rw [bip9State_next_period P hP h hk, ite_eq_right hbstart, hactive]
  rfl

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Theorems.FlagsCor.flags_base_true' depends on axioms: [propext] -/
#guard_msgs in #print axioms flags_base_true

/-- info: 'BitcoinProofs.Theorems.FlagsCor.flags_taproot_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms flags_taproot_iff

/-- info: 'BitcoinProofs.Theorems.FlagsCor.flags_p2sh_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms flags_p2sh_iff

/-- info: 'BitcoinProofs.Theorems.FlagsCor.flags_dersig_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms flags_dersig_iff

/-- info: 'BitcoinProofs.Theorems.FlagsCor.flags_cltv_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms flags_cltv_iff

/-- info: 'BitcoinProofs.Theorems.FlagsCor.flags_csv_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms flags_csv_iff

/-- info: 'BitcoinProofs.Theorems.FlagsCor.flags_nulldummy_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms flags_nulldummy_iff

/-- info: 'BitcoinProofs.Theorems.FlagsCor.nullDummy_iff_segwit' depends on axioms: [propext] -/
#guard_msgs in #print axioms nullDummy_iff_segwit

/-- info: 'BitcoinProofs.Theorems.FlagsCor.flags_genesis_exact' does not depend on any axioms -/
#guard_msgs in #print axioms flags_genesis_exact

/-- info: 'BitcoinProofs.Theorems.FlagsCor.bip9StateByPeriod_active_atStart' depends on axioms: [propext] -/
#guard_msgs in #print axioms bip9StateByPeriod_active_atStart

/-- info: 'BitcoinProofs.Theorems.FlagsCor.bip9_active_stable' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms bip9_active_stable

end BitcoinProofs.Theorems.FlagsCor
