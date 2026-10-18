import Bitcoin.Script.Tapscript.LeafVersion

/-!
# SCR-148 conformance — the 0xc0 leaf-version dispatch (Test-scoped)

`Bitcoin.Script.Tapscript.LeafVersion`'s Test-side pins, per the axiom-pin gate
(`native_decide` allowed under `Test/` only):

* the `hops` hypothesis of `dispatch_v1_0xc0_opsuccess_ok` — the one-byte
  script `#[0xbb]` (OP_SUCCESS187) scans as OP_SUCCESSx
  (`opSuccessScan`, `IsOpSuccess` script.cpp:365-371) — pinned here,
  Test-scoped, so the core-file theorem stays kernel-terrified;
* the dispatch outcome matrix: the 0xc0 arm executing into the interpreter delta layer's
  `executeWitnessScript` tapscript lanes (OP_SUCCESS `.ok` / OP_1 +
  2-item `.fail .cleanstack`) and the :1995-1998 non-0xc0 fall-through
  (DISCOURAGE_UPGRADABLE_TAPROOT_VERSION `.fail` / 0xc2 and 0xfa
  upgradable `.ok`).

No official Core dispatch vectors exist for script-path spends
(documented in the Taproot module's `Crypto/Taproot/Verify.lean` for the same
`VerifyWitnessProgram` arm); the matrix is Core-:1988-by-inspection.
Vector discipline as the interpreter delta layer's `Test/Script/Tapscript/Delta.lean`.
-/

namespace Test.Script.Tapscript.LeafVersionTest

open Bitcoin.Interpreter Bitcoin.Data
open Bitcoin.Crypto.Taproot.Program (leafVersionOf TAPROOT_LEAF_TAPSCRIPT)
open Bitcoin.Crypto.Seam (SigVersion)
open Bitcoin.Script.Tapscript (ctl isTapscriptLeaf verifyTaprootLeafDispatch)

set_option maxRecDepth 40000

/-! ## The `hops` pin (V1's hypothesis, Test-scoped) -/

/-- OP_SUCCESS187 (0xbb) scans as OP_SUCCESSx — the one-byte probe
script of `dispatch_v1_0xc0_opsuccess_ok` (BIP342 §Spec step 2). -/
theorem opsuccess187_scan : opSuccessScan (ByteArray.mk #[(0xbb : UInt8)]) = true := by
  native_decide

/-- OP_1 (0x51) does NOT scan as OP_SUCCESSx (the V2 failure lane's
implicit scan — BIP342 assigns 0x51 = OP_1, not OP_SUCCESSx). -/
theorem op1_not_success : opSuccessScan (ByteArray.mk #[(0x51 : UInt8)]) = false := by
  native_decide

/-- The DISCOURAGE_UPGRADABLE_TAPROOT_VERSION-only policy (the V3
outcome pin's `pol` argument). -/
def polUpg : Bitcoin.Interpreter.PolicyFlags :=
  { discourageUpgradableTaprootVersion := true }

/-! ## The dispatch outcome matrix -/

/-- 0xc0 + OP_SUCCESS187 script: the dispatch reaches the tapscript
OP_SUCCESSx pre-scan, which overrides everything (empty initial stack
here; `executeWitnessScript_success_total` covers all stacks). -/
theorem dispatch_0xc0_opsuccess_ok :
    verifyTaprootLeafDispatch 10 [] (ctl 0xc0)
      (ByteArray.mk #[(0xbb : UInt8)]) [] default default default
      = VerifyOutcome.ok := by native_decide

/-- 0xc0 + one-op OP_1 script + 2-item initial stack: the implicit
tapscript cleanstack fails (BIP342 §Spec step 5). -/
theorem dispatch_0xc0_cleanstack_fail :
    verifyTaprootLeafDispatch 10 [ByteArray.empty, ByteArray.empty] (ctl 0xc0)
      (ByteArray.mk #[(0x51 : UInt8)]) [] default default default
      = VerifyOutcome.fail ExecError.cleanstack := by native_decide

/-- 0xc2 (the next even leaf version) + the DISCOURAGE bit: the
:1995-1997 policy failure. -/
theorem dispatch_0xc2_discourage_fail :
    verifyTaprootLeafDispatch 10 [] (ctl 0xc2)
      (ByteArray.mk #[(0x51 : UInt8)]) [] default polUpg default
      = VerifyOutcome.fail ExecError.discourageUpgradableTaprootVersion := by
  native_decide

/-- 0xc2 without the DISCOURAGE bit (`default` = every policy bit
false): the :1998 upgradable success (SCR-149's ground). -/
theorem dispatch_0xc2_upgradable_ok :
    verifyTaprootLeafDispatch 10 [] (ctl 0xc2)
      (ByteArray.mk #[(0x51 : UInt8)]) [] default default default
      = VerifyOutcome.ok := by native_decide

/-- 0xfa (the wallet-vectors' future leaf version): the same :1998
softfork upgradability success. -/
theorem dispatch_0xfa_upgradable_ok :
    verifyTaprootLeafDispatch 10 [] (ctl 0xfa)
      (ByteArray.mk #[(0x51 : UInt8)]) [] default default default
      = VerifyOutcome.ok := by native_decide

/-! ## Axiom footprints of the core-file pins (the interpreter delta layer style) -/

#print axioms Bitcoin.Script.Tapscript.isTapscriptLeaf_c0
#print axioms Bitcoin.Script.Tapscript.isTapscriptLeaf_c1_parity
#print axioms Bitcoin.Script.Tapscript.isTapscriptLeaf_matrix
#print axioms Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_tapscript
#print axioms Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_upgradable_discourage
#print axioms Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_upgradable_ok
#print axioms Bitcoin.Script.Tapscript.dispatch_v1_0xc0_opsuccess_ok
#print axioms Bitcoin.Script.Tapscript.dispatch_v2_0xc0_cleanstack_fail
#print axioms Bitcoin.Script.Tapscript.dispatch_v3_0xc2_discourage_fail
#print axioms Bitcoin.Script.Tapscript.dispatch_v4_0xc2_upgradable_ok
#print axioms Bitcoin.Script.Tapscript.dispatch_v5_0xfa_upgradable_ok
#print axioms Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_congr

end Test.Script.Tapscript.LeafVersionTest
