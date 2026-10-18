import Bitcoin.Activation.Flags

/-! # PDW27 SCR-103 — DERSIG from BIP66 height 363725
(items TOP-131..135).

Route = B-verify + drift-fix (PDW15-SCR-101 class): the row's yaml
lean_target was module-path-drifted (`.Flags.dersig_flag_flow` vs the real
`Bitcoin.Activation.dersig_flag_flow`, ns `Bitcoin.Activation`);
the truth is the core theorem `dersig_flag_flow` (Flags.lean:196,
tag-stacked BLK-085/SWT-061/SCR-103/INV-128, sorry-free). Zero core
writes; the mainnet activation-height pins below carry the SCR-103 tag. -/

namespace BitcoinProofs.AF.PDW27

open Bitcoin.Activation

/-- SCR-103: mainnet BIP66 activation height is 363725 (BIP66). -/
@[rule "SCR-103"]
theorem mainnet_bip66_height : mainnetParams.bip66Height = 363725 := rfl

/-- SCR-103: at the BIP66 height (and away from exception blocks)
DERSIG is applied. -/
@[rule "SCR-103"]
theorem dersig_applied_from_bip66 (hash : BlockHash)
    (hnone : mainnetParams.scriptFlagExceptions hash = none) :
    (getBlockScriptFlagsP mainnetParams hash 363725).dersig = true :=
  dersig_flag_flow mainnetParams hash 363725 hnone (by decide)

/-- SCR-103 converse: one block below, DERSIG is off. -/
@[rule "SCR-103"]
theorem dersig_off_below_bip66 (hash : BlockHash)
    (hnone : mainnetParams.scriptFlagExceptions hash = none) :
    (getBlockScriptFlagsP mainnetParams hash 363724).dersig = false :=
  dersig_flag_off mainnetParams hash 363724 hnone (by decide)

end BitcoinProofs.AF.PDW27
