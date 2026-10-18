import Bitcoin.Activation.Flags

/-! # PDW27 SCR-015 + INV-133 — flag-selection row faces
(items TOP-131..135).

SCR-015 (`getBlockScriptFlagsP`, validation.cpp:2249-2288): the whole-def
law — away from exception blocks the result is exactly the 7-field record
P2SH|WITNESS|TAPROOT plus the four buried ORs; at an exception block the
base is REPLACED before the same ORs. INV-133 (`mainnetExceptionMap`,
kernel/chainparams.cpp:105-108): the map has exactly two entries and is
fail-closed elsewhere. Route B: zero core writes, tags ride these decls. -/

namespace BitcoinProofs.AF.PDW27

open Bitcoin.Activation

/-- SCR-015 whole-def law: no exception hit ⇒ the exact 7-field shape
(base = P2SH|WITNESS|TAPROOT, buried ORs from false). -/
@[rule "SCR-015"]
theorem getBlockScriptFlagsP_eq (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (hnone : P.scriptFlagExceptions hash = none) :
    getBlockScriptFlagsP P hash height =
      { p2sh := true, witness := true, taproot := true
        dersig := buriedActive P P.bip66Height height
        cltv := buriedActive P P.bip65Height height
        csv := buriedActive P P.csvHeight height
        nullDummy := buriedActive P P.segwitHeight height } := by
  simp [getBlockScriptFlagsP, hnone]

/-- SCR-015 exception law: an exception hit REPLACES the base; the buried
ORs are then layered on the exception record. -/
@[rule "SCR-015"]
theorem getBlockScriptFlagsP_exc (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (exf : ScriptFlags)
    (hexc : P.scriptFlagExceptions hash = some exf) :
    getBlockScriptFlagsP P hash height =
      { exf with
        dersig := exf.dersig || buriedActive P P.bip66Height height
        cltv := exf.cltv || buriedActive P P.bip65Height height
        csv := exf.csv || buriedActive P P.csvHeight height
        nullDummy := exf.nullDummy || buriedActive P P.segwitHeight height } := by
  simp [getBlockScriptFlagsP, hexc]

/-- INV-133: the BIP16 exception entry (SCRIPT_VERIFY_NONE). -/
@[rule "INV-133"]
theorem mainnetExceptionMap_bip16 :
    mainnetExceptionMap bip16ExceptionHash =
      some { p2sh := false, witness := false, taproot := false } := by
  rw [mainnetExceptionMap, ite_eq_left rfl]

/-- INV-133: the taproot exception entry (P2SH|WITNESS). -/
@[rule "INV-133"]
theorem mainnetExceptionMap_taproot :
    mainnetExceptionMap taprootExceptionHash =
      some { p2sh := true, witness := true, taproot := false } := by
  rw [mainnetExceptionMap,
      ite_eq_right (by decide : ¬ (taprootExceptionHash = bip16ExceptionHash))]
  rfl

/-- INV-133: exactly two entries — anything else is fail-closed. -/
@[rule "INV-133"]
theorem mainnetExceptionMap_fail_closed (hash : BlockHash)
    (h1 : hash ≠ bip16ExceptionHash) (h2 : hash ≠ taprootExceptionHash) :
    mainnetExceptionMap hash = none := by
  simp [mainnetExceptionMap, h1, h2]

/-- INV-133: the two exception hashes are distinct. -/
@[rule "INV-133"]
theorem mainnetExceptionMap_ne : bip16ExceptionHash ≠ taprootExceptionHash := by
  decide

end BitcoinProofs.AF.PDW27
