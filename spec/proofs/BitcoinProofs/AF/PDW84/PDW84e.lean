import Bitcoin.Activation.Flags

/-! # PDW84e — TOP-444 row face: `getBlockScriptFlagsP` per-epoch flags

Route B, zero core writes. `GetBlockScriptFlags`
(validation.cpp:2249-2288): the epoch flag set is the base
P2SH|WITNESS|TAPROOT (or the exception-map replacement), with
DERSIG/CLTV/CSV/NULLDUMMY OR-ed in by their buried activation heights
(NULLDUMMY rides segwit). -/

namespace BitcoinProofs.AF.PDW84

open Bitcoin.Activation

/-- **TXV-055 (no exception)**: away from exception blocks every epoch
flag is exactly the base trio plus its buried activation predicate. -/
@[rule "TXV-055"]
theorem getBlockScriptFlagsP_row (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (hnone : P.scriptFlagExceptions hash = none) :
    (getBlockScriptFlagsP P hash height).p2sh = true ∧
    (getBlockScriptFlagsP P hash height).witness = true ∧
    (getBlockScriptFlagsP P hash height).taproot = true ∧
    (getBlockScriptFlagsP P hash height).dersig =
      buriedActive P P.bip66Height height ∧
    (getBlockScriptFlagsP P hash height).cltv =
      buriedActive P P.bip65Height height ∧
    (getBlockScriptFlagsP P hash height).csv =
      buriedActive P P.csvHeight height ∧
    (getBlockScriptFlagsP P hash height).nullDummy =
      buriedActive P P.segwitHeight height := by
  simp [getBlockScriptFlagsP, hnone]

/-- **TXV-055 (exception cell)**: an exception-map hit REPLACES the base
trio; the four buried flags are OR-ed onto the replacement. -/
@[rule "TXV-055"]
theorem getBlockScriptFlagsP_exception_row (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (exf : ScriptFlags)
    (hexc : P.scriptFlagExceptions hash = some exf) :
    (getBlockScriptFlagsP P hash height).p2sh = exf.p2sh ∧
    (getBlockScriptFlagsP P hash height).witness = exf.witness ∧
    (getBlockScriptFlagsP P hash height).taproot = exf.taproot ∧
    (getBlockScriptFlagsP P hash height).dersig =
      (exf.dersig || buriedActive P P.bip66Height height) ∧
    (getBlockScriptFlagsP P hash height).cltv =
      (exf.cltv || buriedActive P P.bip65Height height) ∧
    (getBlockScriptFlagsP P hash height).csv =
      (exf.csv || buriedActive P P.csvHeight height) ∧
    (getBlockScriptFlagsP P hash height).nullDummy =
      (exf.nullDummy || buriedActive P P.segwitHeight height) := by
  simp [getBlockScriptFlagsP, hexc]

/-- info: 'BitcoinProofs.AF.PDW84.getBlockScriptFlagsP_row' depends on axioms: [propext] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.getBlockScriptFlagsP_row

/-- info: 'BitcoinProofs.AF.PDW84.getBlockScriptFlagsP_exception_row' depends on axioms: [propext] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.getBlockScriptFlagsP_exception_row

end BitcoinProofs.AF.PDW84
