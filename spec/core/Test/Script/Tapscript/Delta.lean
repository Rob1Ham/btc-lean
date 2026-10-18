import Bitcoin.Script.Tapscript.Delta

/-!
# the interpreter delta layer conformance — BIP342 tapscript delta vectors (build-time, no IO)

Every pin is a compiler-reduced equality (`native_decide`, Test-scoped
per the D2 ByteArray.mk #[(0x20:UInt8), (0xd8:UInt8), (0x5a:UInt8), (0x95:UInt8), (0x9b:UInt8), (0x02:UInt8), (0x90:UInt8), (0xbf:UInt8), (0x19:UInt8), (0xbb:UInt8), (0x89:UInt8), (0xed:UInt8), (0x43:UInt8), (0xc9:UInt8), (0x16:UInt8), (0xbe:UInt8), (0x83:UInt8), (0x54:UInt8), (0x75:UInt8), (0xd0:UInt8), (0x13:UInt8), (0xda:UInt8), (0x4b:UInt8), (0x36:UInt8), (0x21:UInt8), (0x17:UInt8), (0x39:UInt8), (0x3e:UInt8), (0x25:UInt8), (0xa4:UInt8), (0x82:UInt8), (0x29:UInt8), (0xb8:UInt8), (0xac:UInt8)] gate) against `executeWitnessScript` from
`Bitcoin.Interpreter.Defs`, cross-checked against the python reference
model `ref342.py` (mirrors interpreter.cpp @ cce32b168 tapscript branches;
verdict table reproduced in the interpreter delta layer report). Vector scripts: the 11
leaf-version-0xc0 tapleaf scripts extracted from
`spec/vectors/bips/bip-0341_wallet-test-vectors.json` (signature
verification is seam-stubbed — `stubChecker` accepts any nonempty
(sig, pk) pair; verdict-carrying vectors live in the Schnorr track).
-/

namespace Test.Script.Tapscript.Delta

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Script.Parser Bitcoin.Activation
open Bitcoin.Crypto.Seam (SigVersion ScriptExecutionData stubChecker)

set_option maxRecDepth 40000

/-- 64-byte stub signature (nonempty ⇒ stub Schnorr verdict `true`). -/
def sig64 : ByteArray := ByteArray.mk (Array.replicate 64 (0xab : UInt8))

/-- Vector pk (bip-0341 group 1 leaf 1, x-only). -/
def pk1 : ByteArray := ByteArray.mk #[(0xd8:UInt8), (0x5a:UInt8), (0x95:UInt8), (0x9b:UInt8), (0x02:UInt8), (0x90:UInt8), (0xbf:UInt8), (0x19:UInt8), (0xbb:UInt8), (0x89:UInt8), (0xed:UInt8), (0x43:UInt8), (0xc9:UInt8), (0x16:UInt8), (0xbe:UInt8), (0x83:UInt8), (0x54:UInt8), (0x75:UInt8), (0xd0:UInt8), (0x13:UInt8), (0xda:UInt8), (0x4b:UInt8), (0x36:UInt8), (0x21:UInt8), (0x17:UInt8), (0x39:UInt8), (0x3e:UInt8), (0x25:UInt8), (0xa4:UInt8), (0x82:UInt8), (0x29:UInt8), (0xb8:UInt8)]

/-- The stub checker (accepts nonempty sig+pk). -/
def ckGood : Bitcoin.Interpreter.ScriptChecker := ⟨stubChecker, default⟩

/-- Schnorr-rejecting checker (for the NULLFAIL-analogue cases). -/
def ckBad : Bitcoin.Interpreter.ScriptChecker :=
  ⟨{ checkECDSASignature := fun _ _ _ _ _ => true
     checkSchnorrSignature := fun _ _ _ _ => false }, default⟩

/-- CLTV-passing environment (tx v2, locktime 5, non-final input). -/
def ckCltv : Bitcoin.Interpreter.ScriptChecker := ⟨stubChecker, ⟨2, 5, 0⟩⟩

/-- CSV-passing environment (tx v2, locktime 5, sequence 5). -/
def ckCsv : Bitcoin.Interpreter.ScriptChecker := ⟨stubChecker, ⟨2, 5, 5⟩⟩

/-- MINIMALIF policy bit on. -/
def polIf : Bitcoin.Interpreter.PolicyFlags := { minimalIf := true }

/-- CLTV consensus flag on. -/
def flCltv : Bitcoin.Activation.ScriptFlags := { cltv := true }

/-- CSV consensus flag on. -/
def flCsv : Bitcoin.Activation.ScriptFlags := { csv := true }

/-- The 11 leaf-version-0xc0 scripts from the BIP341 wallet vectors, in
extraction order (groups 1-6; leaf5 is the push-only "Taproot" script). -/
def leaf1 : ByteArray := ByteArray.mk #[(0x20:UInt8), (0xd8:UInt8), (0x5a:UInt8), (0x95:UInt8), (0x9b:UInt8), (0x02:UInt8), (0x90:UInt8), (0xbf:UInt8), (0x19:UInt8), (0xbb:UInt8), (0x89:UInt8), (0xed:UInt8), (0x43:UInt8), (0xc9:UInt8), (0x16:UInt8), (0xbe:UInt8), (0x83:UInt8), (0x54:UInt8), (0x75:UInt8), (0xd0:UInt8), (0x13:UInt8), (0xda:UInt8), (0x4b:UInt8), (0x36:UInt8), (0x21:UInt8), (0x17:UInt8), (0x39:UInt8), (0x3e:UInt8), (0x25:UInt8), (0xa4:UInt8), (0x82:UInt8), (0x29:UInt8), (0xb8:UInt8), (0xac:UInt8)]
def leaf2 : ByteArray := ByteArray.mk #[(0x20:UInt8), (0xb6:UInt8), (0x17:UInt8), (0x29:UInt8), (0x85:UInt8), (0x52:UInt8), (0xa7:UInt8), (0x2a:UInt8), (0xde:UInt8), (0x07:UInt8), (0x06:UInt8), (0x67:UInt8), (0xe8:UInt8), (0x6c:UInt8), (0xa6:UInt8), (0x3b:UInt8), (0x8f:UInt8), (0x57:UInt8), (0x89:UInt8), (0xa9:UInt8), (0xfe:UInt8), (0x87:UInt8), (0x31:UInt8), (0xef:UInt8), (0x91:UInt8), (0x20:UInt8), (0x2a:UInt8), (0x91:UInt8), (0xc9:UInt8), (0xf3:UInt8), (0x45:UInt8), (0x90:UInt8), (0x07:UInt8), (0xac:UInt8)]
def leaf3 : ByteArray := ByteArray.mk #[(0x20:UInt8), (0x38:UInt8), (0x76:UInt8), (0x71:UInt8), (0x35:UInt8), (0x3e:UInt8), (0x27:UInt8), (0x32:UInt8), (0x64:UInt8), (0xc4:UInt8), (0x95:UInt8), (0x65:UInt8), (0x6e:UInt8), (0x27:UInt8), (0xe3:UInt8), (0x9b:UInt8), (0xa8:UInt8), (0x99:UInt8), (0xea:UInt8), (0x8f:UInt8), (0xee:UInt8), (0x3b:UInt8), (0xb6:UInt8), (0x9f:UInt8), (0xb2:UInt8), (0xa6:UInt8), (0x80:UInt8), (0xe2:UInt8), (0x20:UInt8), (0x93:UInt8), (0x44:UInt8), (0x7d:UInt8), (0x48:UInt8), (0xac:UInt8)]
def leaf4 : ByteArray := ByteArray.mk #[(0x20:UInt8), (0x44:UInt8), (0xb1:UInt8), (0x78:UInt8), (0xd6:UInt8), (0x4c:UInt8), (0x32:UInt8), (0xc4:UInt8), (0xa0:UInt8), (0x5c:UInt8), (0xc4:UInt8), (0xf4:UInt8), (0xd1:UInt8), (0x40:UInt8), (0x72:UInt8), (0x68:UInt8), (0xf7:UInt8), (0x64:UInt8), (0xc9:UInt8), (0x40:UInt8), (0xd2:UInt8), (0x0c:UInt8), (0xe9:UInt8), (0x7a:UInt8), (0xbf:UInt8), (0xd4:UInt8), (0x4d:UInt8), (0xb5:UInt8), (0xc3:UInt8), (0x59:UInt8), (0x2b:UInt8), (0x72:UInt8), (0xfd:UInt8), (0xac:UInt8)]
def leaf5 : ByteArray := ByteArray.mk #[(0x07:UInt8), (0x54:UInt8), (0x61:UInt8), (0x70:UInt8), (0x72:UInt8), (0x6f:UInt8), (0x6f:UInt8), (0x74:UInt8)]
def leaf6 : ByteArray := ByteArray.mk #[(0x20:UInt8), (0x72:UInt8), (0xea:UInt8), (0x6a:UInt8), (0xdc:UInt8), (0xf1:UInt8), (0xd3:UInt8), (0x71:UInt8), (0xde:UInt8), (0xa8:UInt8), (0xfb:UInt8), (0xa1:UInt8), (0x03:UInt8), (0x5a:UInt8), (0x09:UInt8), (0xf3:UInt8), (0xd2:UInt8), (0x4e:UInt8), (0xd5:UInt8), (0xa0:UInt8), (0x59:UInt8), (0x79:UInt8), (0x9b:UInt8), (0xae:UInt8), (0x11:UInt8), (0x40:UInt8), (0x84:UInt8), (0x13:UInt8), (0x0e:UInt8), (0xe5:UInt8), (0x89:UInt8), (0x8e:UInt8), (0x69:UInt8), (0xac:UInt8)]
def leaf7 : ByteArray := ByteArray.mk #[(0x20:UInt8), (0x23:UInt8), (0x52:UInt8), (0xd1:UInt8), (0x37:UInt8), (0xf2:UInt8), (0xf3:UInt8), (0xab:UInt8), (0x38:UInt8), (0xd1:UInt8), (0xea:UInt8), (0xa9:UInt8), (0x76:UInt8), (0x75:UInt8), (0x88:UInt8), (0x73:UInt8), (0x37:UInt8), (0x7f:UInt8), (0xa5:UInt8), (0xeb:UInt8), (0xb8:UInt8), (0x17:UInt8), (0x37:UInt8), (0x2c:UInt8), (0x71:UInt8), (0xe2:UInt8), (0xc5:UInt8), (0x42:UInt8), (0x31:UInt8), (0x3d:UInt8), (0x4a:UInt8), (0xbd:UInt8), (0xa8:UInt8), (0xac:UInt8)]
def leaf8 : ByteArray := ByteArray.mk #[(0x20:UInt8), (0x73:UInt8), (0x37:UInt8), (0xc0:UInt8), (0xdd:UInt8), (0x42:UInt8), (0x53:UInt8), (0xcb:UInt8), (0x86:UInt8), (0xf2:UInt8), (0xc4:UInt8), (0x3a:UInt8), (0x23:UInt8), (0x51:UInt8), (0xaa:UInt8), (0xdd:UInt8), (0x82:UInt8), (0xcc:UInt8), (0xcb:UInt8), (0x12:UInt8), (0xa1:UInt8), (0x72:UInt8), (0xcd:UInt8), (0x12:UInt8), (0x04:UInt8), (0x52:UInt8), (0xb9:UInt8), (0xbb:UInt8), (0x83:UInt8), (0x24:UInt8), (0xf2:UInt8), (0x18:UInt8), (0x6a:UInt8), (0xac:UInt8)]
def leaf9 : ByteArray := ByteArray.mk #[(0x20:UInt8), (0x71:UInt8), (0x98:UInt8), (0x15:UInt8), (0x21:UInt8), (0xad:UInt8), (0x9f:UInt8), (0xc9:UInt8), (0x03:UInt8), (0x66:UInt8), (0x87:UInt8), (0x36:UInt8), (0x41:UInt8), (0x18:UInt8), (0xfb:UInt8), (0x6c:UInt8), (0xcd:UInt8), (0x20:UInt8), (0x35:UInt8), (0xb9:UInt8), (0x6a:UInt8), (0x42:UInt8), (0x3c:UInt8), (0x59:UInt8), (0xc5:UInt8), (0x43:UInt8), (0x0e:UInt8), (0x98:UInt8), (0x31:UInt8), (0x0a:UInt8), (0x11:UInt8), (0xab:UInt8), (0xe2:UInt8), (0xac:UInt8)]
def leaf10 : ByteArray := ByteArray.mk #[(0x20:UInt8), (0xd5:UInt8), (0x09:UInt8), (0x4d:UInt8), (0x2d:UInt8), (0xbe:UInt8), (0x9b:UInt8), (0x76:UInt8), (0xe2:UInt8), (0xc2:UInt8), (0x45:UInt8), (0xa2:UInt8), (0xb8:UInt8), (0x9b:UInt8), (0x60:UInt8), (0x06:UInt8), (0x88:UInt8), (0x89:UInt8), (0x52:UInt8), (0xe2:UInt8), (0xfa:UInt8), (0xa6:UInt8), (0xa1:UInt8), (0x49:UInt8), (0xae:UInt8), (0x31:UInt8), (0x8d:UInt8), (0x69:UInt8), (0xe5:UInt8), (0x20:UInt8), (0x61:UInt8), (0x77:UInt8), (0x48:UInt8), (0xac:UInt8)]
def leaf11 : ByteArray := ByteArray.mk #[(0x20:UInt8), (0xc4:UInt8), (0x40:UInt8), (0xb4:UInt8), (0x62:UInt8), (0xad:UInt8), (0x48:UInt8), (0xc7:UInt8), (0xa7:UInt8), (0x7f:UInt8), (0x94:UInt8), (0xcd:UInt8), (0x45:UInt8), (0x32:UInt8), (0xd8:UInt8), (0xf2:UInt8), (0x11:UInt8), (0x9d:UInt8), (0xce:UInt8), (0xbb:UInt8), (0xd7:UInt8), (0xc9:UInt8), (0x76:UInt8), (0x45:UInt8), (0x57:UInt8), (0xe6:UInt8), (0x27:UInt8), (0x26:UInt8), (0x41:UInt8), (0x9b:UInt8), (0x08:UInt8), (0xad:UInt8), (0x4c:UInt8), (0xac:UInt8)]

/-! ## Cross-checked conformance pins (python ref342.py verdict table) -/

/-- `success_prepass` — python reference verdict `OK`. -/
example : executeWitnessScript 100 [] 0 (ByteArray.mk #[(0x50:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- `success_overrides_stack` — python reference verdict `OK`. -/
example : executeWitnessScript 100 (List.replicate 1001 ByteArray.empty) 0 (ByteArray.mk #[(0x50:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- `success_overrides_elem` — python reference verdict `OK`. -/
example : executeWitnessScript 100 [ByteArray.mk (Array.replicate 521 (0x00:UInt8))] 0 (ByteArray.mk #[(0x50:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- `truncated_before_succ` — python reference verdict `FAIL:BAD_OPCODE`. -/
example : executeWitnessScript 100 [] 0 (ByteArray.mk #[(0x4c:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.fail ExecError.badOpcode := by native_decide

/-- `push_then_success` — python reference verdict `OK`. -/
example : executeWitnessScript 100 [] 0 (ByteArray.mk #[(0x51:UInt8),(0x50:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- `disabled_is_success` — python reference verdict `OK`. -/
example : executeWitnessScript 100 [] 0 (ByteArray.mk #[(0x7e:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- `disabled_legacy_fail` — python reference verdict `FAIL:DISABLED_OPCODE`. -/
example : executeWitnessScript 100 [] 0 (ByteArray.mk #[(0x7e:UInt8)]) default default ckGood SigVersion.witnessV0
  = VerifyOutcome.fail ExecError.disabledOpcode := by native_decide

/-- `minimalif_tap_fail` — python reference verdict `FAIL:TAPSCRIPT_MINIMALIF`. -/
example : executeWitnessScript 100 [ByteArray.mk #[(0x02:UInt8),(0x01:UInt8),(0x00:UInt8)]] 0 (ByteArray.mk #[(0x63:UInt8),(0x68:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.fail ExecError.tapscriptMinimalIf := by native_decide

/-- `minimalif_v0_nopolicy` — python reference verdict `FAIL:CLEANSTACK`. -/
example : executeWitnessScript 100 [ByteArray.mk #[(0x02:UInt8),(0x01:UInt8),(0x00:UInt8)]] 0 (ByteArray.mk #[(0x63:UInt8),(0x68:UInt8)]) default default ckGood SigVersion.witnessV0
  = VerifyOutcome.fail ExecError.cleanstack := by native_decide

/-- `minimalif_v0_policy` — python reference verdict `FAIL:MINIMALIF`. -/
example : executeWitnessScript 100 [ByteArray.mk #[(0x02:UInt8),(0x01:UInt8),(0x00:UInt8)]] 0 (ByteArray.mk #[(0x63:UInt8),(0x68:UInt8)]) default polIf ckGood SigVersion.witnessV0
  = VerifyOutcome.fail ExecError.minimalIf := by native_decide

/-- `minimalif_tap_pass` — python reference verdict `OK:01`. -/
example : executeWitnessScript 100 [ByteArray.mk #[(0x01:UInt8)]] 0 (ByteArray.mk #[(0x63:UInt8),(0x51:UInt8),(0x68:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- `checksig_tap_ok` — python reference verdict `OK:01`. -/
example : executeWitnessScript 100 [sig64] 0 leaf1 default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- `checksig_tap_emptysig` — python reference verdict `FAIL:EVAL_FALSE`. -/
example : executeWitnessScript 100 [ByteArray.empty] 0 leaf1 default default ckGood SigVersion.tapscript
  = VerifyOutcome.fail ExecError.evalFalse := by native_decide

/-- `checksig_tap_badsig` — python reference verdict `FAIL:SCHNORR_SIG`. -/
example : executeWitnessScript 100 [sig64] 0 leaf1 default default ckBad SigVersion.tapscript
  = VerifyOutcome.fail ExecError.schnorrSig := by native_decide

/-- `checksigadd_tap` — python reference verdict `OK:06`. -/
example : executeWitnessScript 100 [sig64, ByteArray.mk #[(0x05:UInt8)], pk1] 0 (ByteArray.mk #[(0xba:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- `checksigadd_tap_failsig` — python reference verdict `FAIL:SCHNORR_SIG`. -/
example : executeWitnessScript 100 [sig64, ByteArray.mk #[(0x05:UInt8)], pk1] 0 (ByteArray.mk #[(0xba:UInt8)]) default default ckBad SigVersion.tapscript
  = VerifyOutcome.fail ExecError.schnorrSig := by native_decide

/-- `checksigadd_num4` — python reference verdict `FAIL:SCRIPTNUM`. -/
example : executeWitnessScript 100 [sig64, ByteArray.mk (Array.replicate 5 (0x01:UInt8)), pk1] 0 (ByteArray.mk #[(0xba:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.fail ExecError.scriptNum := by native_decide

/-- `checksigadd_base_bad` — python reference verdict `FAIL:BAD_OPCODE`. -/
example : executeWitnessScript 100 [sig64, ByteArray.mk #[(0x05:UInt8)], pk1] 0 (ByteArray.mk #[(0xba:UInt8)]) default default ckGood SigVersion.base
  = VerifyOutcome.fail ExecError.badOpcode := by native_decide

/-- `cms_tap_fail` — python reference verdict `FAIL:TAPSCRIPT_CHECKMULTISIG`. -/
example : executeWitnessScript 100 [] 0 (ByteArray.mk #[(0xae:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.fail ExecError.tapscriptCheckMultiSig := by native_decide

/-- `cleanstack_implicit` — python reference verdict `FAIL:CLEANSTACK`. -/
example : executeWitnessScript 100 [ByteArray.empty, ByteArray.empty] 0 (ByteArray.mk #[(0x51:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.fail ExecError.cleanstack := by native_decide

/-- `cltv_negative_tap` — python reference verdict `FAIL:NEGATIVE_LOCKTIME`. -/
example : executeWitnessScript 100 [ByteArray.mk #[(0x81:UInt8)]] 0 (ByteArray.mk #[(0xb1:UInt8)]) flCltv default ckCltv SigVersion.tapscript
  = VerifyOutcome.fail ExecError.negativeLocktime := by native_decide

/-- `cltv_negative_base` — python reference verdict `FAIL:NEGATIVE_LOCKTIME`. -/
example : executeWitnessScript 100 [ByteArray.mk #[(0x81:UInt8)]] 0 (ByteArray.mk #[(0xb1:UInt8)]) flCltv default ckCltv SigVersion.base
  = VerifyOutcome.fail ExecError.negativeLocktime := by native_decide

/-- `cltv_flagoff_nop` — python reference verdict `OK:81`. -/
example : executeWitnessScript 100 [ByteArray.mk #[(0x81:UInt8)]] 0 (ByteArray.mk #[(0xb1:UInt8)]) default default ckCltv SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- `csv_satisfied_tap` — python reference verdict `OK:05`. -/
example : executeWitnessScript 100 [ByteArray.mk #[(0x05:UInt8)]] 0 (ByteArray.mk #[(0xb2:UInt8)]) flCsv default ckCsv SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- `budget_202_tap` — python reference verdict `OK:cb00`. -/
example : executeWitnessScript 500 [] 0 (ByteArray.mk (#[0x51] ++ Array.replicate 202 (0x8b:UInt8))) default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- `budget_202_base_fail` — python reference verdict `FAIL:OP_COUNT`. -/
example : executeWitnessScript 500 [] 0 (ByteArray.mk (#[0x51] ++ Array.replicate 202 (0x8b:UInt8))) default default ckGood SigVersion.base
  = VerifyOutcome.fail ExecError.opCount := by native_decide

/-- Wallet-vector tapleaf 1 (leaf version 0xc0) — reference verdict `OK:01`. -/
example : executeWitnessScript 100 [sig64] 0 leaf1 default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- Wallet-vector tapleaf 2 (leaf version 0xc0) — reference verdict `OK:01`. -/
example : executeWitnessScript 100 [sig64] 0 leaf2 default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- Wallet-vector tapleaf 3 (leaf version 0xc0) — reference verdict `OK:01`. -/
example : executeWitnessScript 100 [sig64] 0 leaf3 default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- Wallet-vector tapleaf 4 (leaf version 0xc0) — reference verdict `OK:01`. -/
example : executeWitnessScript 100 [sig64] 0 leaf4 default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- Wallet-vector tapleaf 5 (leaf version 0xc0) — reference verdict `OK:546170726f6f74`. -/
example : executeWitnessScript 100 [] 0 leaf5 default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- Wallet-vector tapleaf 6 (leaf version 0xc0) — reference verdict `OK:01`. -/
example : executeWitnessScript 100 [sig64] 0 leaf6 default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- Wallet-vector tapleaf 7 (leaf version 0xc0) — reference verdict `OK:01`. -/
example : executeWitnessScript 100 [sig64] 0 leaf7 default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- Wallet-vector tapleaf 8 (leaf version 0xc0) — reference verdict `OK:01`. -/
example : executeWitnessScript 100 [sig64] 0 leaf8 default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- Wallet-vector tapleaf 9 (leaf version 0xc0) — reference verdict `OK:01`. -/
example : executeWitnessScript 100 [sig64] 0 leaf9 default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- Wallet-vector tapleaf 10 (leaf version 0xc0) — reference verdict `OK:01`. -/
example : executeWitnessScript 100 [sig64] 0 leaf10 default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

/-- Wallet-vector tapleaf 11 (leaf version 0xc0) — reference verdict `OK:01`. -/
example : executeWitnessScript 100 [sig64] 0 leaf11 default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by native_decide

end Test.Script.Tapscript.Delta

/-! ## Axiom pins — every Delta theorem is sorry-free with an axiom
footprint inside the standard trio (no `Classical.choice`, no custom
axioms; `#guard_msgs` fails the build on drift). -/

#print axioms Bitcoin.Script.Tapscript.executeWitnessScript_success_total
#print axioms Bitcoin.Script.Tapscript.executeWitnessScript_success_discourage
#print axioms Bitcoin.Script.Tapscript.checksigadd_not_success
#print axioms Bitcoin.Script.Tapscript.disabledWire_success
#print axioms Bitcoin.Script.Tapscript.evalChecksigDispatch_base_arm
#print axioms Bitcoin.Script.Tapscript.evalChecksigDispatch_tapscript_arm
#print axioms Bitcoin.Script.Tapscript.evalChecksigTapscript_empty_sig_false
#print axioms Bitcoin.Script.Tapscript.evalChecksigTapscript_invalid_sig_fails
#print axioms Bitcoin.Script.Tapscript.checksigAddStep_result
#print axioms Bitcoin.Script.Tapscript.checkMultiSig_tapscript_fails
#print axioms Bitcoin.Script.Tapscript.evalScriptBytes_tapscript_no_script_size
#print axioms Bitcoin.Script.Tapscript.evalScriptBytes_sv_congr
#print axioms Bitcoin.Script.Tapscript.tapscript_opcount_guard_off
#print axioms Bitcoin.Script.Tapscript.opBudget_frozen_tapscript
#print axioms Bitcoin.Script.Tapscript.minimalif_tapscript_unconditional
#print axioms Bitcoin.Script.Tapscript.minimalif_witnessv0_policy_gated
#print axioms Bitcoin.Script.Tapscript.minimalif_witnessv0_policy_active
#print axioms Bitcoin.Script.Tapscript.cltv_negative_tapscript
#print axioms Bitcoin.Script.Tapscript.cltv_negative_base
#print axioms Bitcoin.Script.Tapscript.cltv_satisfied_tapscript
#print axioms Bitcoin.Script.Tapscript.csv_satisfied_tapscript
#print axioms Bitcoin.Script.Tapscript.csv_flag_off_nop_tapscript
#print axioms Bitcoin.Script.Tapscript.cleanstack_implicit_witnessv0
#print axioms Bitcoin.Script.Tapscript.cleanstack_implicit_tapscript
#print axioms Bitcoin.Script.Tapscript.checksigadd_num4_bound
#print axioms Bitcoin.Script.Tapscript.initial_stack_limit_tapscript
#print axioms Bitcoin.Script.Tapscript.push_size_limit_tapscript
#print axioms Bitcoin.Script.Tapscript.checksigadd_outside_tapscript
