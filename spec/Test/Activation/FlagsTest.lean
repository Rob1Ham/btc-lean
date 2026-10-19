import Bitcoin.Activation.Flags
import Bitcoin.Activation.Bip9

/-!
# W06 test harness — consensus script flags (Flags + Interface)

Run: `bash spec/Test/Activation/run.sh` (from anywhere).
Every check is ALSO a build-time `example ... := by decide`, so the
compiler verifies the vectors even without running the harness.
No `native_decide` anywhere (D2 L1 gate).
-/

open Bitcoin.Activation

set_option maxRecDepth 100000

/-! ## Build-time-verified flag vectors (decide; SCR-015 / SCR-016) -/

-- Genesis: base set only (no buried deployment active, no exception).
example : getBlockScriptFlags 0 =
    { p2sh := true, witness := true, taproot := true } := by decide

-- Last pre-BIP66 height: DERSIG still off.
example : (getBlockScriptFlags 363724).dersig = false := by decide

-- BIP66 boundary: DERSIG on from exactly the buried height (BLK-072).
example : (getBlockScriptFlags 363725).dersig = true := by decide

-- CLTV boundary 388381, CSV boundary 419328 (BLK-086 / BLK-087).
example : (getBlockScriptFlags 388381).cltv = true := by decide
example : (getBlockScriptFlags 419328).csv = true := by decide

-- NULLDUMMY rides SEGWIT at 481824 (BLK-088): on at the boundary, off the block before.
example : (getBlockScriptFlags 481823).nullDummy = false := by decide
example : (getBlockScriptFlags 481824).nullDummy = true := by decide

-- Taproot activation height 709632: all seven consensus flags.
example : getBlockScriptFlags 709632 =
    { p2sh := true, dersig := true, cltv := true, csv := true,
      nullDummy := true, witness := true, taproot := true } := by decide

-- The BIP16 exception block 170060: SCRIPT_VERIFY_NONE, despite BIP16's
-- own activation — the historical exemption (SCR-016).
example : getBlockScriptFlags 170060 =
    { p2sh := false, dersig := false, cltv := false, csv := false,
      nullDummy := false, witness := false, taproot := false } := by decide

-- The taproot exception block 692261: P2SH|WITNESS + buried, TAPROOT off.
example : getBlockScriptFlags 692261 =
    { p2sh := true, dersig := true, cltv := true, csv := true,
      nullDummy := true, witness := true, taproot := false } := by decide

-- Height 173805 (W01's erroneous "exception" height) is a NORMAL block:
-- full base set, nothing buried yet.
example : getBlockScriptFlags 173805 =
    { p2sh := true, witness := true, taproot := true } := by decide

/-! ## Hash-keyed model agrees with the height-keyed frozen interface -/

-- Same vectors through the Core-faithful hash-keyed port.
example : getBlockScriptFlagsP mainnetParams bip16ExceptionHash 170060 =
    getBlockScriptFlags 170060 := rfl
example : getBlockScriptFlagsP mainnetParams taprootExceptionHash 692261 =
    getBlockScriptFlags 692261 := rfl
example : getBlockScriptFlagsP mainnetParams 0xdeadbeef 709632 =
    getBlockScriptFlags 709632 := rfl

-- Exact exception-map entries (BLK-084).
example : mainnetExceptionMap bip16ExceptionHash =
    some { p2sh := false, witness := false, taproot := false } := rfl
example : mainnetExceptionMap taprootExceptionHash =
    some { p2sh := true, witness := true, taproot := false } := rfl

-- Buried heights + BIP34 hash (BLK-070/071), restated as a build-time check.
example : mainnetParams.bip34Height = 227931 ∧
    mainnetParams.bip66Height = 363725 ∧ mainnetParams.bip65Height = 388381 ∧
    mainnetParams.csvHeight = 419328 ∧ mainnetParams.segwitHeight = 481824 := by
  decide

/-! ## BLK-086 / BLK-087 / INV-130: exception-hash and converse arms -/

-- CLTV is on at the BIP65 boundary for the exception hashes too (no `hnone`).
example : (getBlockScriptFlagsP mainnetParams bip16ExceptionHash 388381).cltv = true :=
  (cltv_flag_iff_mainnet_any bip16ExceptionHash 388381).mpr (by decide)

-- ... and off one block before, for the taproot exception hash.
example : (getBlockScriptFlagsP mainnetParams taprootExceptionHash 388380).cltv = false :=
  cltv_flag_off_any mainnetParams taprootExceptionHash 388380
    (fun exf hmap => mainnet_exception_cltv_false taprootExceptionHash exf hmap) (by decide)

-- CSV is on at its boundary for the taproot exception hash (INV-130), and
-- off one block before at the BIP16 exception hash.
example : (getBlockScriptFlagsP mainnetParams taprootExceptionHash 419328).csv = true :=
  (csv_flag_iff_mainnet_any taprootExceptionHash 419328).mpr (by decide)
example : (getBlockScriptFlagsP mainnetParams bip16ExceptionHash 419327).csv = false :=
  csv_flag_off_any mainnetParams bip16ExceptionHash 419327
    (fun exf hmap => mainnet_exception_csv_false bip16ExceptionHash exf hmap) (by decide)

-- BLK-087: both CSV gates (script flag + contextual LOCKTIME_VERIFY_SEQUENCE)
-- and the resulting BIP68 enablement are on for a version-2 transaction.
example : (getBlockScriptFlagsP mainnetParams bip16ExceptionHash 419328).csv = true ∧
    blockLocktimeFlags mainnetParams 419328 =
      Bitcoin.DataLaws.LOCKTIME_VERIFY_SEQUENCE ∧
    Bitcoin.DataLaws.bip68Enabled 2
      (locktimeVerifySequenceFlag mainnetParams 419328) = true :=
  csv_locktime_flag_flow_mainnet_any bip16ExceptionHash 419328 (by decide) 2 (by decide)

/-! ## flagBits: verify_flags.h bit values -/

example : flagBits mainnetBaseFlags = 0x20801 := by decide
example : flagBits { p2sh := true, dersig := true, cltv := true, csv := true,
                     nullDummy := true, witness := true, taproot := true } = 0x20E15 := by
  decide

/-! ## Policy flags are absent from consensus (brief item b) -/

example : (consensusFullFlags (getBlockScriptFlags 709632)).policy .lowS = false ∧
    (consensusFullFlags (getBlockScriptFlags 709632)).policy .cleanStack = false ∧
    (consensusFullFlags (getBlockScriptFlags 709632)).policy .minimalIfV0 = false := by
  decide

-- Tapscript re-imports MINIMALIF/CLEANSTACK as consensus even with policy off.
example : minimalIfRequired (consensusFullFlags {}) Bitcoin.Crypto.Seam.SigVersion.tapscript = true ∧
    cleanStackRequired (consensusFullFlags {}) Bitcoin.Crypto.Seam.SigVersion.tapscript = true := by
  decide
example : minimalIfRequired (consensusFullFlags {}) Bitcoin.Crypto.Seam.SigVersion.base = false := by
  decide

/-! ## Axiom pins (D2 L3): the headline theorems carry exactly these
axiom fingerprints (propext/Quot.sound from `simp`; no Classical.choice,
no sorryAx anywhere). -/

/-- info: 'Bitcoin.Activation.flags_after_burial' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Activation.flags_after_burial
/-- info: 'Bitcoin.Activation.flags_bip16_exception' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.flags_bip16_exception
/-- info: 'Bitcoin.Activation.flags_taproot_exception' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.flags_taproot_exception
/-- info: 'Bitcoin.Activation.flags_monotone' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Activation.flags_monotone
/-- info: 'Bitcoin.Activation.lockin_then_active' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Activation.lockin_then_active
/-- info: 'Bitcoin.Activation.bip9_always_active' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.bip9_always_active
/-- info: 'Bitcoin.Activation.bip9_never_active' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.bip9_never_active
/-- info: 'Bitcoin.Activation.buried_heights_mainnet' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.buried_heights_mainnet
/-- info: 'Bitcoin.Activation.mainnet_height_hash_agree' depends on axioms: [propext] -/
#guard_msgs in #print axioms Bitcoin.Activation.mainnet_height_hash_agree
/-- info: 'Bitcoin.Activation.cltv_flag_iff_mainnet_any' depends on axioms: [propext] -/
#guard_msgs in #print axioms Bitcoin.Activation.cltv_flag_iff_mainnet_any
/-- info: 'Bitcoin.Activation.csv_flag_iff_mainnet_any' depends on axioms: [propext] -/
#guard_msgs in #print axioms Bitcoin.Activation.csv_flag_iff_mainnet_any
/-- info: 'Bitcoin.Activation.csv_locktime_flag_flow_mainnet_any' depends on axioms: [propext] -/
#guard_msgs in #print axioms Bitcoin.Activation.csv_locktime_flag_flow_mainnet_any
/-- info: 'Bitcoin.Activation.csv_flag_gate_iff_mainnet_any' depends on axioms: [propext] -/
#guard_msgs in #print axioms Bitcoin.Activation.csv_flag_gate_iff_mainnet_any

/-! ## Runtime harness (mirror of core/Main.lean's checkR pattern) -/

def check (name : String) (b : Bool) : IO Unit :=
  IO.println s!"[{if b then "PASS" else "FAIL"}] {name}"

def checkR (name : String) (b : Bool) : IO Bool := do
  check name b
  return b

def main : IO UInt32 := do
  let r1 ← checkR "genesis flags = P2SH|WITNESS|TAPROOT"
    (getBlockScriptFlags 0 = { p2sh := true, witness := true, taproot := true })
  let r2 ← checkR "BIP16 exception block 170060 = SCRIPT_VERIFY_NONE"
    ((getBlockScriptFlags 170060) == { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false })
  let r3 ← checkR "taproot exception block 692261 = P2SH|WITNESS+buried, no TAPROOT"
    ((getBlockScriptFlags 692261).taproot = false ∧ (getBlockScriptFlags 692261).witness = true)
  let r4 ← checkR "buried boundaries 363725/388381/419328/481824 all inclusive"
    ((getBlockScriptFlags 363725).dersig ∧ (getBlockScriptFlags 388381).cltv ∧
     (getBlockScriptFlags 419328).csv ∧ (getBlockScriptFlags 481824).nullDummy)
  let r5 ← checkR "taproot era 709632 = all 7 flags (bits 0x20E15)"
    (flagBits (getBlockScriptFlags 709632) == 0x20E15)
  let r6 ← checkR "hash-keyed port agrees with height-keyed interface"
    (getBlockScriptFlagsP mainnetParams bip16ExceptionHash 170060 = getBlockScriptFlags 170060)
  let r7 ← checkR "mainnet buried heights"
    (mainnetParams.bip34Height == 227931 && mainnetParams.bip66Height == 363725 &&
     mainnetParams.bip65Height == 388381 && mainnetParams.csvHeight == 419328 &&
     mainnetParams.segwitHeight == 481824)
  let r8 ← checkR "policy flags absent from consensus view"
    (¬ (consensusFullFlags (getBlockScriptFlags 709632)).policy .lowS &&
     ¬ (consensusFullFlags (getBlockScriptFlags 709632)).policy .cleanStack)
  let r9 ← checkR "tapscript re-imports MINIMALIF/CLEANSTACK"
    (minimalIfRequired (consensusFullFlags {}) Bitcoin.Crypto.Seam.SigVersion.tapscript &&
     cleanStackRequired (consensusFullFlags {}) Bitcoin.Crypto.Seam.SigVersion.tapscript)
  IO.println "FlagsTest done."
  let all := [r1, r2, r3, r4, r5, r6, r7, r8, r9]
  return if all.foldl (· && ·) true then 0 else 1
