import BitcoinProofs.Theorems.Ops.O09
import BitcoinProofs.Theorems.Ops.O02
import BitcoinProofs.AF.PDW87.PDW87
import Bitcoin.Serialization.Interface

/-! # PDW69 (lane B) — TOP-366..370 row faces (route B, zero core writes)

* **INV-050** NULLDUMMY gate (BIP147) — O09 concrete vector.
* **SCR-032** CMS op budget charges `nKeys` wholesale.
* **SCR-120** `CHECKMULTISIGVERIFY` failure ⇒ `checkMultiSigVerify`.
* **SWT-037** BIP144 extended-tx round trip (marker/flag + witness stacks).
* **SCR-071** NOP1/4-10 pass iff DISCOURAGE_UPGRADABLE_NOPS is clear.
-/

namespace BitcoinProofs.AF.PDW69

open Bitcoin.Data Bitcoin.Serialization
open BitcoinProofs.Theorems.Ops.O09

/-- **INV-050** (BIP147 NULLDUMMY): nonzero dummy ⇒ `sigNullDummy`;
empty dummy passes. -/
@[rule "INV-050"]
theorem checkMultiSig_nulldummy_row :
    Bitcoin.Interpreter.stepBody { BitcoinProofs.Theorems.Ops.O09.ctx0 with flags := { nullDummy := true } } opCMS
        { BitcoinProofs.Theorems.Ops.O09.st0 with stack := [enc 0, BitcoinProofs.Theorems.Ops.O09.enc 0, serU8 7] } = .error .sigNullDummy ∧
    Bitcoin.Interpreter.stepBody { BitcoinProofs.Theorems.Ops.O09.ctx0 with flags := { nullDummy := true } } opCMS
        { BitcoinProofs.Theorems.Ops.O09.st0 with stack := [enc 0, BitcoinProofs.Theorems.Ops.O09.enc 0, ByteArray.empty] } =
      .ok { BitcoinProofs.Theorems.Ops.O09.st0 with opCount := 1, stack := [Bitcoin.Interpreter.vchTrue] } :=
  cms_nulldummy_concrete

/-- **INV-050, general lane** (BIP147): for an arbitrary `CHECKMULTISIG`
state whose key count decodes to `nkv` and whose signature count is `0`
(the matching loop's trivial success path), if the `nullDummy` flag is set
and the dummy element at depth `nKeys + 2` is non-empty, the opcode
returns `SIG_NULLDUMMY` — this is the "dummy must be empty" rule at all
`nKeys`, not just the concrete vector. -/
@[rule "INV-050"]
theorem checkMultiSig_nulldummy_general_row (ctx : Bitcoin.Interpreter.Ctx)
    (st : Bitcoin.Interpreter.State) (nkv : Bitcoin.Numeric.ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hd1 : Bitcoin.Interpreter.decodeNum ctx.pol
      (Bitcoin.Interpreter.topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ Bitcoin.Interpreter.MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (Bitcoin.Interpreter.MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : Bitcoin.Interpreter.decodeNum ctx.pol
      (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok 0)
    (hlen3 : (st.stack.length < nkv.toNat + 3) = false)
    (hflag : ctx.flags.nullDummy = true)
    (hne : (st.stack[nkv.toNat + 2]?.getD default).size ≠ 0) :
    Bitcoin.Interpreter.stepBody.checkMultiSig ctx 0xae st = .error .sigNullDummy := by
  have hl3 : ¬(st.stack.length < nkv.toNat + 3) := by rw [hlen3]; simp
  have hne0 : st.stack ≠ [] := by
    intro h
    rw [h] at hl3
    have h0 : List.length ([] : List ByteArray) = 0 := rfl
    omega
  have hcond0 : ¬(max (nkv : Int) 0 < (0 : Int)) :=
    Int.not_lt_of_ge (Int.le_max_right (nkv : Int) 0)
  have hne4 : ¬(List.length st.stack - (nkv.toNat + 2) = 0) := by omega
  have hcl : Bitcoin.Interpreter.cmsCleanup ctx.pol st.stack true (nkv.toNat + 3)
      (nkv.toNat + 2) (nkv.toNat + 3) = .ok (st.stack.drop (nkv.toNat + 2)) := by
    have h := cmsCleanup_true_eq ctx.pol (nkv.toNat + 3) (nkv.toNat + 3)
      (nkv.toNat + 2) st.stack (Nat.le_refl _) (by omega)
    rw [show nkv.toNat + 3 - 1 = nkv.toNat + 2 from by omega] at h
    exact h
  simp [Bitcoin.Interpreter.stepBody.checkMultiSig, hsv, hd1, hrange, hop, hlen2,
    hd2, hlen3, Bitcoin.Interpreter.cmsLoop, hcl, hne0, hcond0, hne4, hflag]
  intro h
  exact hne (by rw [h]; rfl)

/-- **SCR-032**: CMS charges `nKeys` units wholesale, so
`opCount + nKeys > 201` ⇒ `opCount` (Core's sigop inaccuracy kept). -/
@[rule "SCR-032"]
theorem cmsLoop_charges_nKeys_row (ctx : Bitcoin.Interpreter.Ctx)
    (st : Bitcoin.Interpreter.State) (nkv : Bitcoin.Numeric.ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd : Bitcoin.Interpreter.decodeNum ctx.pol
      (Bitcoin.Interpreter.topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ Bitcoin.Interpreter.MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hcond : (Bitcoin.Interpreter.MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = true) :
    Bitcoin.Interpreter.stepBody.checkMultiSig ctx 0xae st = .error .opCount :=
  cms_opCount ctx st nkv hsv hne0 hd hrange hcond

/-- **SCR-120**: failing `CHECKMULTISIGVERIFY` ⇒ `checkMultiSigVerify`. -/
@[rule "SCR-120"]
theorem checkMultiSigVerify_fail_row :
    Bitcoin.Interpreter.stepBody BitcoinProofs.Theorems.Ops.O09.ctx0 opCMSV
        { BitcoinProofs.Theorems.Ops.O09.st0 with stack := [enc 1, serU8 6, BitcoinProofs.Theorems.Ops.O09.enc 1, ByteArray.empty, serU8 7] } =
      .error .checkMultiSigVerify :=
  cmsv_falsesig_concrete

/-- **SCR-120, general lane**: a false `CHECKMULTISIG` verdict on
`OP_CHECKMULTISIGVERIFY` is `SCRIPT_ERR_CHECKMULTISIGVERIFY`, for arbitrary
state, key/signature counts, FindAndDelete result, matching-loop verdict and
cleanup output. This is the after-loop/post-cleanup shape of
`interpreter.cpp:1223-1225`; the non-verify opcode would instead push the
false verdict. -/
@[rule "SCR-120"]
theorem checkMultiSigVerify_fail_general
    (ctx : Bitcoin.Interpreter.Ctx) (st : Bitcoin.Interpreter.State)
    (nkv nsv : Bitcoin.Numeric.ScriptNum) (scriptCode : ByteArray)
    (stc : Bitcoin.Interpreter.Stack)
    (hsv : ctx.sv ≠ Bitcoin.Crypto.Seam.SigVersion.tapscript)
    (hd1 : Bitcoin.Interpreter.decodeNum ctx.pol
      (Bitcoin.Interpreter.topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ Bitcoin.Interpreter.MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (Bitcoin.Interpreter.MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : Bitcoin.Interpreter.decodeNum ctx.pol
      (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hrange2 : (nsv < 0 ∨ max (nkv : Int) 0 < nsv) = false)
    (hlen3 : (st.stack.length < nkv.toNat + nsv.toNat + 3) = false)
    (hfd : BitcoinProofs.AF.PDW84.cmsFadFold ctx st nkv.toNat
      (ctx.bytes.extract st.codeSep ctx.bytes.size) nsv.toNat = .ok scriptCode)
    (hloop : Bitcoin.Interpreter.cmsLoop ctx.flags ctx.pol ctx.sv ctx.chk ctx.ed
      scriptCode st.stack (nkv.toNat + nsv.toNat + 1) nkv.toNat nsv.toNat
      (nkv.toNat + 3) 2 = .ok false)
    (hclean : Bitcoin.Interpreter.cmsCleanup ctx.pol st.stack false
      (nkv.toNat + nsv.toNat + 3) (nkv.toNat + 2)
      (nkv.toNat + nsv.toNat + 3) = .ok stc)
    (hlen : ¬ stc.length < 1)
    (hflag : ¬ (ctx.flags.nullDummy ∧
      stc[0]?.getD default ≠ ByteArray.empty)) :
    Bitcoin.Interpreter.stepBody.checkMultiSig ctx 0xaf st =
      .error .checkMultiSigVerify := by
  have hpost := BitcoinProofs.AF.PDW87.checkMultiSig_post_cleanup ctx st nkv nsv
    scriptCode stc false hsv hd1 hrange hop hlen2 hd2 hrange2 hlen3
    hfd hloop hclean hlen hflag
  simpa using hpost.2

/-- **SWT-037** (BIP144): extended serialization decodes back exactly. -/
@[rule "SWT-037"]
theorem decTxCore_extended_roundtrip_row (tx : Bitcoin.Data.Tx) (rest : Bytes)
    (h : wireDomain tx) :
    decTxCore (encTxL tx ++ rest) = .ok (tx, rest) :=
  decTxCore_encTxL tx rest h

/-- **SWT-037, layout lane** (BIP144, `UnserializeTransaction:202-239`):
for a transaction with a witness the wire encoding is
`version ‖ 0x00 (marker) ‖ 0x01 (flag) ‖ vin ‖ vout ‖ per-input witness
stacks ‖ locktime`. Thus `vin == 0` is signalled by the marker byte and
the next byte is the flag; `flag & 1` is the `0x01` here, after which one
witness stack per input is appended after `vout`. -/
@[rule "SWT-037"]
theorem encTxL_extended_layout_row (tx : Bitcoin.Data.Tx)
    (hh : hasWitness tx = true) :
    encTxL tx =
      encU32L tx.version.toUInt32 ++ [0x00, 0x01]
        ++ encCSL tx.vin.length
        ++ tx.vin.flatMap (fun i => bL (Bitcoin.Data.serTxIn i))
        ++ encCSL tx.vout.length
        ++ tx.vout.flatMap (fun o => bL (Bitcoin.Data.serTxOut o))
        ++ encStacksL tx
        ++ encU32L tx.locktime := by
  unfold encTxL
  rw [ite_eq_left hh]

/-- **SCR-071**: NOP1/NOP4..NOP10 pass iff the policy discouragement flag
is clear (interpreter.cpp:611-612). -/
@[rule "SCR-071"]
theorem nopClass_discourage_row (ctx : Bitcoin.Interpreter.Ctx)
    (op : Bitcoin.Interpreter.WireOp) (fExec : Bool) (st : Bitcoin.Interpreter.State)
    (w : Nat)
    (hw : w = 0xb0 ∨ w = 0xb3 ∨ w = 0xb4 ∨ w = 0xb5 ∨ w = 0xb6 ∨
          w = 0xb7 ∨ w = 0xb8 ∨ w = 0xb9) :
    Bitcoin.Interpreter.stepBody.dispatchOp ctx op w fExec st =
      (if ctx.pol.discourageUpgradableNops then
         .error .discourageUpgradableNops else .ok st) :=
  BitcoinProofs.Theorems.Ops.O02.opNopClass_effect ctx op fExec st w hw

end BitcoinProofs.AF.PDW69

/-- info: 'BitcoinProofs.AF.PDW69.checkMultiSig_nulldummy_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW69.checkMultiSig_nulldummy_row
/-- info: 'BitcoinProofs.AF.PDW69.cmsLoop_charges_nKeys_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW69.cmsLoop_charges_nKeys_row
/-- info: 'BitcoinProofs.AF.PDW69.checkMultiSigVerify_fail_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW69.checkMultiSigVerify_fail_row
/-- info: 'BitcoinProofs.AF.PDW69.checkMultiSigVerify_fail_general' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW69.checkMultiSigVerify_fail_general
/-- info: 'BitcoinProofs.AF.PDW69.decTxCore_extended_roundtrip_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW69.decTxCore_extended_roundtrip_row
/-- info: 'BitcoinProofs.AF.PDW69.nopClass_discourage_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW69.nopClass_discourage_row
