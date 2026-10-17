import BitcoinProofs.Conservation.Thms

/-!
# INV033BLK090SubsidyCor — TOP-31/INV-033 + TOP-32/BLK-090 promotion proofs

PDW7 (proof-promotion review 4, recovery review 4), 2026-10-17.
Rows INV-033 + BLK-090 (the halving-schedule pair, one def:
`Bitcoin.Conservation.blockSubsidy`, validation.cpp:GetBlockSubsidy:
1833-1844 @cce32b168; BIP42). BLK-090 = the 08-block-pow-utxo
restatement ("W08: same def as INV-033"), lean_target identical.

Core anchor (cce32b168, validation.cpp:1833-1844):

    CAmount GetBlockSubsidy(int nHeight, ...) {
      int halvings = nHeight / 210000;
      if (halvings >= 64) return 0;   // the BIP42 guard
      CAmount nSubsidy = 50 * COIN;   // 5,000,000,000
      nSubsidy >>= halvings;
      return nSubsidy;
    }

Our `blockSubsidy` (Conservation/Interface.lean:149, W08 frozen):
`((5000000000 / 2 ^ (min (halvingsAt height) 64) : Nat) : Amount)` —
Core's `halvings >= 64 → 0` guard = the `min _ 64` saturation; the
BIP42 fix (`subsidyNat_zero_ge33`: 2^33 > 5·10^9) kills the tail even
earlier, from halving 33 on — the no-hyperinflation law.

This file = the proof-promotion tier (route-B): the W08 sorry-free
`BitcoinProofs.Conservation.Thms` schedule theorems (THM-015/016/
039/040, built over the frozen core interface) restated 1:1 in the
PDW7 AF-file (PDW2 4df229b pattern) under the INV-033/BLK-090 rule
tags, axiom-pinned in-file. No new math; port + tag + pin = the honest
promote (D-CONSV dep = "Conservation.Thms port (subsidy_le_max) +
MoneyRange", PD01 D-notes). B03Subsidy.lean (BIP42 coverage-audit
module, B03) separately carries the Nat-mirror tier (C1..C8) — its
:37 claims traceability to both rows; THIS file = the tree-def tier
+ the `@[rule]` tags + the status flips.
-/

namespace BitcoinProofs.AF.PDW7

open Bitcoin.Data Bitcoin.Conservation

/-! ## THM-015 (the 50·COIN cap) -/

/-- INV-033 (THM-015): the block subsidy never exceeds the initial
50·COIN = 5,000,000,000 sats (Core's `50 * COIN` mantissa; the
`>> halvings` only ever divides). -/
@[rule "INV-033"]
theorem INV033_subsidy_le_max (height : UInt32) :
    blockSubsidy height ≤ 5000000000 :=
  BitcoinProofs.Conservation.subsidy_le_max height

/-- BLK-090 (THM-015): same law, 08-block-pow-utxo row. -/
@[rule "BLK-090"]
theorem BLK090_subsidy_le_max (height : UInt32) :
    blockSubsidy height ≤ 5000000000 :=
  BitcoinProofs.Conservation.subsidy_le_max height

/-- INV-033 (THM-015 companion): epochs 0..31 each pay at least 1
satoshi (`5000000000 / 2^31 > 0`). -/
@[rule "INV-033"]
theorem INV033_subsidy_pos (height : UInt32)
    (h : halvingsAt height ≤ 31) :
    0 < blockSubsidy height :=
  BitcoinProofs.Conservation.subsidy_pos height h

/-- INV-033 (MoneyRange form): the subsidy alone is in MoneyRange
(`0 ≤ subsidy ≤ MAX_MONEY`, the D-CONSV "MoneyRange" dep). -/
@[rule "INV-033"]
theorem INV033_subsidy_moneyRange (height : UInt32) :
    MoneyRange (blockSubsidy height) = true :=
  BitcoinProofs.Conservation.subsidy_moneyRange height

/-! ## THM-016 (BIP42: the tail schedule is zero) -/

/-- INV-033 (BIP42): from halving 33 on the subsidy is exactly 0 —
Core's `>> 64` guard = `subsidyNat_zero_ge33`'s 2^33 > 50·COIN; no
hyperinflation tail. (Core anchor :154, sorry-free.) -/
@[rule "INV-033"]
theorem INV033_subsidy_zero_ge33 (height : UInt32)
    (h : 33 ≤ halvingsAt height) :
    blockSubsidy height = 0 :=
  Bitcoin.Conservation.subsidy_epoch33_zero height h

/-- BLK-090 (BIP42, check-text form): "0 when halvings ≥ 64" — the
Core :1838 guard, via the same `subsidyNat_zero_ge33` saturation. -/
@[rule "BLK-090"]
theorem BLK090_subsidy_zero_ge64 (height : UInt32)
    (h : 64 ≤ halvingsAt height) :
    blockSubsidy height = 0 :=
  Bitcoin.Conservation.subsidy_epoch33_zero height (by omega)

/-! ## THM-039/040 (schedule tier: the 21M cap) -/

/-- INV-033 (THM-039): the total schedule issuance is exactly
2,099,999,997,690,000 sats = 20,999,999.9769 BTC. -/
@[rule "INV-033"]
theorem INV033_totalIssuance_exact :
    BitcoinProofs.Conservation.totalIssuance = 2099999997690000 :=
  BitcoinProofs.Conservation.totalIssuance_exact

/-- INV-033 (THM-039): the total supply is under the 21M cap with
231,000 sats to spare — the "Σ < MAX_MONEY" lean-note. -/
@[rule "INV-033"]
theorem INV033_totalIssuance_le_cap :
    BitcoinProofs.Conservation.totalIssuance ≤ 21000000 * 100000000 :=
  BitcoinProofs.Conservation.totalIssuance_le_cap

/-- BLK-090 (THM-040): the supply at ANY height is at most the total
schedule issuance (the 21M cap at consensus granularity). -/
@[rule "BLK-090"]
theorem BLK090_supplyAt_le_cap (height : UInt32) :
    BitcoinProofs.Conservation.supplyAt height
      ≤ BitcoinProofs.Conservation.totalIssuance :=
  BitcoinProofs.Conservation.supplyAt_le_cap height


/-! ## L3 axiom pins (D2): drift on any of these fails the build.
All 9 theorems sorry-free; fingerprints = the upstream W08
`Conservation.Thms` tier (port side adds nothing: `exact`-restatements).
`subsidy_le_max`/`subsidy_moneyRange` pick up `propext` via
`Int.ofNat_le`/`moneyRange_eq_true_iff` decide-bridge; the
`subsidy_pos`/`zero_ge33`/`zero_ge64`/`supplyAt_le_cap` group carries
`Quot.sound` from the upstream omega-bridge `List.foldl` tiers; the two
`totalIssuance` pins are the pure-Nat `decide` tier (AXIOM-FREE).
Zero sorryAx everywhere (sorry_lint G1 class). -/

/-- info: 'BitcoinProofs.AF.PDW7.INV033_subsidy_le_max' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.INV033_subsidy_le_max

/-- info: 'BitcoinProofs.AF.PDW7.BLK090_subsidy_le_max' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.BLK090_subsidy_le_max

/-- info: 'BitcoinProofs.AF.PDW7.INV033_subsidy_pos' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.INV033_subsidy_pos

/-- info: 'BitcoinProofs.AF.PDW7.INV033_subsidy_moneyRange' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.INV033_subsidy_moneyRange

/-- info: 'BitcoinProofs.AF.PDW7.INV033_subsidy_zero_ge33' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.INV033_subsidy_zero_ge33

/-- info: 'BitcoinProofs.AF.PDW7.BLK090_subsidy_zero_ge64' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.BLK090_subsidy_zero_ge64

/-- info: 'BitcoinProofs.AF.PDW7.INV033_totalIssuance_exact' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.INV033_totalIssuance_exact

/-- info: 'BitcoinProofs.AF.PDW7.INV033_totalIssuance_le_cap' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.INV033_totalIssuance_le_cap

/-- info: 'BitcoinProofs.AF.PDW7.BLK090_supplyAt_le_cap' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.BLK090_supplyAt_le_cap

end BitcoinProofs.AF.PDW7
