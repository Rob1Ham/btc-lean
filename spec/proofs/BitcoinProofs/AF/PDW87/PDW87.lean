import Bitcoin.Interpreter.Defs
import Bitcoin.Script.Parser.Defs
import BitcoinProofs.AF.PDW80.PDW80A
import BitcoinProofs.AF.PDW84.PDW84c
import BitcoinProofs.AF.PDW84.PDW84d

/-! # PDW87 — TOP-456..460, codesep / CHECKSIG / CMS-dummy hard tail

Row faces on `Bitcoin.Interpreter` defs (route B, zero core writes):
SCR-096/097 (OP_CODESEPARATOR), SCR-109 (empty sig ⇒ FALSE),
SCR-110 (NULLFAIL on non-empty failed sig), SCR-118/119 (CMS dummy). -/

namespace BitcoinProofs.AF.PDW87
open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Crypto.Seam Bitcoin.Script.Parser

/-- SCR-097: an unexecuted OP_CODESEPARATOR does not update `codeSep`
(only executed separators do; interpreter.cpp:497). -/
@[rule "SCR-097"]
theorem stepBody_codesep_unexec {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0xab)
    (hconst : ¬ (ctx.sv = .base ∧ ctx.pol.constScriptCode = true))
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hfe : st.vf.all id = false) :
    stepBody ctx op st =
      .ok { st with
        opCount := if (ctx.sv = .base ∨ ctx.sv = .witnessV0) then st.opCount + 1 else st.opCount } := by
  rw [stepBody]
  by_cases h : ctx.sv = .base ∨ ctx.sv = .witnessV0
  · have hb : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
      intro hc; exact hbudget ⟨h, hc⟩
    simp [ha, hw, hconst, hfe, h, hb, disabledWire]
  · simp [ha, hw, hconst, hfe, h, disabledWire]


/-- SCR-100: under BASE and CONST_SCRIPTCODE, a positive FindAndDelete hit
is `sigFindAndDelete` — even when the CHECKSIG is unexecuted (the gate is
in `evalChecksigPreTapscript` itself; interpreter.cpp:328-368). -/
@[rule "SCR-100"]
theorem evalChecksigPreTapscript_findAndDelete
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (sv : SigVersion)
    (codeSep : Nat) (bytes sig pk : ByteArray)
    (hsv : sv = .base)
    (hfd : 0 < (findAndDelete (bytes.extract codeSep bytes.size) (pushBytesWire sig)).1)
    (hc : pol.constScriptCode = true) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk
      = .error .sigFindAndDelete := by
  simp [evalChecksigPreTapscript, hsv, hfd, hc]

/-- SCR-109: an empty signature makes the legacy CHECKSIG verdict FALSE
(and, `sig.size = 0`, bypasses NULLFAIL); interpreter.cpp:328-368. -/
@[rule "SCR-109"]
theorem evalChecksigPreTapscript_empty_sig
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (sv : SigVersion)
    (codeSep : Nat) (bytes sig pk : ByteArray) (scriptCode : ByteArray)
    (hsig : sig.size = 0)
    (hpk : checkPubKeyEncoding flags pol sv pk = none)
    (hdel : (if sv = .base then
        (let p := findAndDelete (bytes.extract codeSep bytes.size) (pushBytesWire sig)
         if 0 < p.1 ∧ pol.constScriptCode then Except.error ExecError.sigFindAndDelete
         else Except.ok p.2)
      else Except.ok (bytes.extract codeSep bytes.size)) = Except.ok scriptCode)
    (hchk : chk.base.checkECDSASignature sig pk scriptCode sv ed = false) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk = .ok false := by
  simp [evalChecksigPreTapscript, hsig, checkSigEncoding, hpk, hdel, hchk]

/-- SCR-110: a failed non-empty signature under NULLFAIL is
`sigNullFail` (policy gate; interpreter.cpp:361-365). -/
@[rule "SCR-110"]
theorem evalChecksigPreTapscript_nullfail
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (sv : SigVersion)
    (codeSep : Nat) (bytes sig pk : ByteArray) (scriptCode : ByteArray)
    (hsig : sig.size ≠ 0) (hnull : pol.nullFail = true)
    (hsed : checkSigEncoding flags pol sig = none)
    (hpk : checkPubKeyEncoding flags pol sv pk = none)
    (hdel : (if sv = .base then
        (let p := findAndDelete (bytes.extract codeSep bytes.size) (pushBytesWire sig)
         if 0 < p.1 ∧ pol.constScriptCode then Except.error ExecError.sigFindAndDelete
         else Except.ok p.2)
      else Except.ok (bytes.extract codeSep bytes.size)) = Except.ok scriptCode)
    (hchk : chk.base.checkECDSASignature sig pk scriptCode sv ed = false) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk
      = .error .sigNullFail := by
  simp [evalChecksigPreTapscript, hsig, hnull, hsed, hpk, hdel, hchk]

/-- SCR-118: with `nKeys = nSigs = 0` the CHECKMULTISIG epilogue consumes
the extra dummy item unconditionally (`nKeys + 2` arity + cleanup pops
run regardless of flags; interpreter.cpp:1212-1225, SWT-065). -/
@[rule "SCR-118"]
theorem checkMultiSig_extra_item_consumed
    (ctx : Ctx) (st : State)
    (hsv : ctx.sv ≠ .tapscript)
    (hbudget : ¬ (MAX_OPS_PER_SCRIPT < st.opCount))
    (hk : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok 0)
    (hs : decodeNum ctx.pol (st.stack[1]?.getD default) 4 = .ok 0)
    (hlen : 2 < st.stack.length)
    (hnd : ctx.flags.nullDummy = false) :
    Bitcoin.Interpreter.stepBody.checkMultiSig ctx 0xae st =
      .ok { st with opCount := st.opCount, stack := pushBoolV true :: st.stack.drop 3 } := by
  have h3 : st.stack ≠ [] := by intro h; rw [h] at hlen; simp at hlen
  have h2 : ¬ st.stack.length < 2 := by omega
  have h4 : ¬ st.stack.length < 3 := by omega
  have h5 : ¬ st.stack.length - 1 - 1 = 0 := by omega
  have ht : (List.tail st.stack).tail.tail = st.stack.drop 3 := by
    rcases st.stack with _ | ⟨a, _ | ⟨b, _ | ⟨c, rest⟩⟩⟩ <;> simp_all
  have hp : ¬ ((MAX_PUBKEYS_PER_MULTISIG : Int) < 0) := by omega
  simp [Bitcoin.Interpreter.stepBody.checkMultiSig, hsv, hbudget, hk, hs,
    h3, h2, h4, h5, ht, hp, hlen, hnd, cmsLoop, cmsCleanup]

/-- SCR-119: post-SegWit NULLDUMMY — a non-empty extra CMS item is
`sigNullDummy` (consensus flag; interpreter.cpp:1219-1221). -/
@[rule "SCR-119"]
theorem checkMultiSig_nulldummy
    (ctx : Ctx) (st : State)
    (hsv : ctx.sv ≠ .tapscript)
    (hbudget : ¬ (MAX_OPS_PER_SCRIPT < st.opCount))
    (hk : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok 0)
    (hs : decodeNum ctx.pol (st.stack[1]?.getD default) 4 = .ok 0)
    (hlen : 2 < st.stack.length)
    (hnd : ctx.flags.nullDummy = true)
    (hdummy : st.stack[2] ≠ ByteArray.empty) :
    Bitcoin.Interpreter.stepBody.checkMultiSig ctx 0xae st
      = .error .sigNullDummy := by
  have h3 : st.stack ≠ [] := by intro h; rw [h] at hlen; simp at hlen
  have h2 : ¬ st.stack.length < 2 := by omega
  have h4 : ¬ st.stack.length < 3 := by omega
  have h5 : ¬ (st.stack.length - 1 - 1 = 0) := by omega
  have hp : ¬ ((MAX_PUBKEYS_PER_MULTISIG : Int) < 0) := by omega
  simp [Bitcoin.Interpreter.stepBody.checkMultiSig, hsv, hbudget, hk, hs,
    h3, h2, h4, h5, hp, hlen, hnd, hdummy, cmsLoop, cmsCleanup]

/-- `cmsFadFold` (PDW84c) is definitionally the inline per-signature
FindAndDelete fold of `checkMultiSig`. -/
theorem cmsFadFold_core (ctx : Ctx) (st : State) (nKeys nSigs : Nat)
    (sc0 : ByteArray) :
    BitcoinProofs.AF.PDW84.cmsFadFold ctx st nKeys sc0 nSigs =
      (List.range nSigs).foldl
        (fun (acc : Except ExecError ByteArray) (k : Nat) =>
          match acc with
          | .error e => .error e
          | .ok sc =>
            if ctx.sv = .base then
              let (found, sc') := findAndDelete sc
                (pushBytesWire (st.stack[nKeys + k + 2]!))
              if 0 < found ∧ ctx.pol.constScriptCode then
                .error .sigFindAndDelete
              else .ok sc'
            else .ok sc)
        (.ok sc0) := by
  unfold BitcoinProofs.AF.PDW84.cmsFadFold
    BitcoinProofs.AF.PDW84.cmsFadStep
  rfl

/-- `checkMultiSig` with its inline cumulative FindAndDelete fold exposed as
`cmsFadFold` (definitional equality; the fold is the only difference). -/
theorem checkMultiSig_cmsFadFold (ctx : Ctx) (w : Nat) (st : State) :
    stepBody.checkMultiSig ctx w st =
      (if ctx.sv = .tapscript then .error .tapscriptCheckMultiSig
       else if st.stack.length < 1 then .error .stackUnderflow
       else match decodeNum ctx.pol (topAt st.stack 1) 4 with
         | .error e => .error e
         | .ok nkv =>
           if nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv then .error .pubKeyCount
           else
             let nKeys := nkv.toNat
             let opCount₂ := st.opCount + nKeys
             if MAX_OPS_PER_SCRIPT < opCount₂ then .error .opCount
             else if st.stack.length < nKeys + 2 then .error .stackUnderflow
             else match decodeNum ctx.pol (st.stack[nKeys + 1]!) 4 with
               | .error e => .error e
               | .ok nsv =>
                 if nsv < 0 ∨ (nKeys : Int) < nsv then .error .sigCount
                 else
                   let nSigs := nsv.toNat
                   if st.stack.length < nKeys + nSigs + 3 then .error .stackUnderflow
                   else
                     match BitcoinProofs.AF.PDW84.cmsFadFold ctx st nKeys
                         (ctx.bytes.extract st.codeSep ctx.bytes.size) nSigs with
                     | .error e => .error e
                     | .ok scriptCode =>
                       match cmsLoop ctx.flags ctx.pol ctx.sv ctx.chk ctx.ed scriptCode
                           st.stack (nKeys + nSigs + 1) nKeys nSigs (nKeys + 3) 2 with
                       | .error e => .error e
                       | .ok fSuccess =>
                         match cmsCleanup ctx.pol st.stack fSuccess
                             (nKeys + nSigs + 3) (nKeys + 2) (nKeys + nSigs + 3) with
                         | .error e => .error e
                         | .ok st₃ =>
                           if st₃.length < 1 then .error .stackUnderflow
                           else if ctx.flags.nullDummy ∧ st₃[0]!.size ≠ 0 then .error .sigNullDummy
                           else
                             let st₄ :=
                               { st with opCount := opCount₂,
                                         stack := pushBoolV fSuccess :: st₃.tail }
                             if w = 0xaf then
                               if fSuccess then .ok { st₄ with stack := st₄.stack.tail }
                               else .error .checkMultiSigVerify
                             else .ok st₄) := by
  rw [stepBody.checkMultiSig]
  rfl

/-- **Post-loop / post-cleanup shape of CHECKMULTISIG** (interpreter.cpp:
1203-1223). Once every pre-loop gate and the cumulative FindAndDelete fold
have passed, an arbitrary matching-loop verdict `fSuccess` and an arbitrary
successful `cmsCleanup` result `stc` determine the rest of the opcode. In
particular the cleanup has already popped all `nKeys + nSigs + 2` stack
arguments (so the historical dummy at depth `nKeys + nSigs + 2` is gone);
only the NULLDUMMY test on its successor `stc[0]` remains. This is the
general after-loop lemma used by SCR-118/119/120. -/
@[rule "SCR-118", rule "SCR-119", rule "SCR-120"]
theorem checkMultiSig_post_cleanup
    (ctx : Ctx) (st : State) (nkv nsv : ScriptNum)
    (scriptCode : ByteArray) (stc : Stack) (fSuccess : Bool)
    (hsv : ctx.sv ≠ .tapscript)
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol
      (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hrange2 : (nsv < 0 ∨ max (nkv : Int) 0 < nsv) = false)
    (hlen3 : (st.stack.length < nkv.toNat + nsv.toNat + 3) = false)
    (hfd : BitcoinProofs.AF.PDW84.cmsFadFold ctx st nkv.toNat
      (ctx.bytes.extract st.codeSep ctx.bytes.size) nsv.toNat = .ok scriptCode)
    (hloop : cmsLoop ctx.flags ctx.pol ctx.sv ctx.chk ctx.ed scriptCode
      st.stack (nkv.toNat + nsv.toNat + 1) nkv.toNat nsv.toNat
      (nkv.toNat + 3) 2 = .ok fSuccess)
    (hclean : cmsCleanup ctx.pol st.stack fSuccess
      (nkv.toNat + nsv.toNat + 3) (nkv.toNat + 2)
      (nkv.toNat + nsv.toNat + 3) = .ok stc)
    (hlen : ¬ stc.length < 1)
    (hflag : ¬ (ctx.flags.nullDummy ∧
      stc[0]?.getD default ≠ ByteArray.empty)) :
    stepBody.checkMultiSig ctx 0xae st =
      .ok { st with opCount := st.opCount + nkv.toNat,
                    stack := pushBoolV fSuccess :: stc.tail } ∧
    stepBody.checkMultiSig ctx 0xaf st =
      (if fSuccess then
        .ok { st with opCount := st.opCount + nkv.toNat,
                      stack := (pushBoolV fSuccess :: stc.tail).tail }
       else .error .checkMultiSigVerify) := by
  have hnotrange2 : ¬ (nsv < 0 ∨ max (nkv : Int) 0 < nsv) := by
    simpa [hrange2]
  have hnsv0 : ¬ nsv < 0 := fun h => hnotrange2 (Or.inl h)
  have hnkmax : ¬ (max (nkv : Int) 0 < nsv) := fun h => hnotrange2 (Or.inr h)
  have hnotrange : ¬ (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) := by
    simpa [hrange]
  have hnkv_nonneg : 0 ≤ nkv := by
    have h : ¬ nkv < 0 := fun h => hnotrange (Or.inl h)
    exact Int.not_lt.mp h
  have hnk : ¬ ((nkv.toNat : Int) < nsv) := by
    intro hlt
    have hlt' : nkv < nsv := by
      rwa [Int.toNat_of_nonneg hnkv_nonneg] at hlt
    exact hnkmax (by simpa [Int.max_eq_left hnkv_nonneg] using hlt')
  have hl3 : ¬ (st.stack.length < nkv.toNat + nsv.toNat + 3) := by
    rw [hlen3]; simp
  have hne0 : st.stack ≠ [] := by
    intro h
    rw [h] at hl3
    simp at hl3
  have hne : stc ≠ [] := by
    intro h; rw [h] at hlen; simp at hlen
  have hpre : ¬ (st.stack.length < 1) := by omega
  constructor
  · rw [checkMultiSig_cmsFadFold]
    simp only [List.getElem!_eq_getElem?_getD, hsv, hpre, hd1, hrange, hop,
      hlen2, hd2, hrange2, hnsv0, hnk, hlen3]
    rw [hfd]
    dsimp only
    rw [hloop]
    dsimp only
    rw [hclean]
    dsimp only
    simp [hne, hflag]
  · rw [checkMultiSig_cmsFadFold]
    simp only [List.getElem!_eq_getElem?_getD, hsv, hpre, hd1, hrange, hop,
      hlen2, hd2, hrange2, hnsv0, hnk, hlen3]
    rw [hfd]
    dsimp only
    rw [hloop]
    dsimp only
    rw [hclean]
    dsimp only
    by_cases hfs : fSuccess <;> simp [hne, hflag, hfs]

/-- **SCR-118 (general dummy consumption, arbitrary `nSigs`)**: on the
successful matching path (so also for `nSigs = 0`, where the loop is
trivially true), with NULLDUMMY off, `CHECKMULTISIG` consumes exactly
`nKeys + nSigs + 3` stack items: both counts, all signatures and keys, and
the historical extra dummy at depth `nKeys + nSigs + 2` (the
`inv049_dummy_popped_general` / `cms_ok_zero_sigs_row` case is `nSigs = 0`).
The dummy's contents are never inspected: the conclusion does not mention
them, and the cleanup pop is unconditional (`interpreter.cpp:1209-1213`). -/
@[rule "SCR-118"]
theorem checkMultiSig_extra_item_consumed_general
    (ctx : Ctx) (st : State) (nkv nsv : ScriptNum) (scriptCode : ByteArray)
    (hsv : ctx.sv ≠ .tapscript)
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol
      (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hrange2 : (nsv < 0 ∨ max (nkv : Int) 0 < nsv) = false)
    (hlen3 : (st.stack.length < nkv.toNat + nsv.toNat + 3) = false)
    (hfd : BitcoinProofs.AF.PDW84.cmsFadFold ctx st nkv.toNat
      (ctx.bytes.extract st.codeSep ctx.bytes.size) nsv.toNat = .ok scriptCode)
    (hloop : cmsLoop ctx.flags ctx.pol ctx.sv ctx.chk ctx.ed scriptCode
      st.stack (nkv.toNat + nsv.toNat + 1) nkv.toNat nsv.toNat
      (nkv.toNat + 3) 2 = .ok true)
    (hnd : ctx.flags.nullDummy = false) :
    stepBody.checkMultiSig ctx 0xae st =
      .ok { st with opCount := st.opCount + nkv.toNat,
                    stack := pushBoolV true ::
                      st.stack.drop (nkv.toNat + nsv.toNat + 3) } := by
  have hl3 : ¬ (st.stack.length < nkv.toNat + nsv.toNat + 3) := by
    rw [hlen3]; simp
  have hcl : cmsCleanup ctx.pol st.stack true
      (nkv.toNat + nsv.toNat + 3) (nkv.toNat + 2)
      (nkv.toNat + nsv.toNat + 3) =
      .ok (st.stack.drop (nkv.toNat + nsv.toNat + 2)) := by
    have h := BitcoinProofs.AF.PDW84.cmsCleanup_true_eq ctx.pol
      (nkv.toNat + nsv.toNat + 3) (nkv.toNat + nsv.toNat + 3)
      (nkv.toNat + 2) st.stack (Nat.le_refl _) (by omega)
    rw [show nkv.toNat + nsv.toNat + 3 - 1 =
      nkv.toNat + nsv.toNat + 2 from by omega] at h
    exact h
  have hlenStc : ¬ (st.stack.drop (nkv.toNat + nsv.toNat + 2)).length < 1 := by
    rw [List.length_drop]
    omega
  have hflag : ¬ (ctx.flags.nullDummy ∧
      (st.stack.drop (nkv.toNat + nsv.toNat + 2))[0]?.getD
        default ≠ ByteArray.empty) := by
    simp [hnd]
  have hpost := checkMultiSig_post_cleanup ctx st nkv nsv scriptCode
    (st.stack.drop (nkv.toNat + nsv.toNat + 2)) true
    hsv hd1 hrange hop hlen2 hd2 hrange2 hlen3 hfd hloop hcl hlenStc hflag
  have hdrop : (st.stack.drop (nkv.toNat + nsv.toNat + 2)).tail =
      st.stack.drop (nkv.toNat + nsv.toNat + 3) := by
    rw [List.tail_drop]
  simpa [hdrop] using hpost.1

/-- **SCR-119 (general NULLDUMMY gate, arbitrary `nSigs`)**: once the
FindAndDelete fold, the matching loop and the argument cleanup have run,
a non-empty item at the post-cleanup top (`stc[0]`, i.e. the historical
dummy at depth `nKeys + nSigs + 2` in the original stack) is
`SCRIPT_ERR_SIG_NULLDUMMY` whenever NULLDUMMY is set — whatever the loop
verdict was (`interpreter.cpp:1211-1212`, BIP147). -/
@[rule "SCR-119"]
theorem checkMultiSig_nulldummy_general
    (ctx : Ctx) (st : State) (nkv nsv : ScriptNum)
    (scriptCode : ByteArray) (stc : Stack) (fSuccess : Bool) (w : Nat)
    (hsv : ctx.sv ≠ .tapscript)
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol
      (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hrange2 : (nsv < 0 ∨ max (nkv : Int) 0 < nsv) = false)
    (hlen3 : (st.stack.length < nkv.toNat + nsv.toNat + 3) = false)
    (hfd : BitcoinProofs.AF.PDW84.cmsFadFold ctx st nkv.toNat
      (ctx.bytes.extract st.codeSep ctx.bytes.size) nsv.toNat = .ok scriptCode)
    (hloop : cmsLoop ctx.flags ctx.pol ctx.sv ctx.chk ctx.ed scriptCode
      st.stack (nkv.toNat + nsv.toNat + 1) nkv.toNat nsv.toNat
      (nkv.toNat + 3) 2 = .ok fSuccess)
    (hclean : cmsCleanup ctx.pol st.stack fSuccess
      (nkv.toNat + nsv.toNat + 3) (nkv.toNat + 2)
      (nkv.toNat + nsv.toNat + 3) = .ok stc)
    (hlen : ¬ stc.length < 1)
    (hflag : ctx.flags.nullDummy = true)
    (hne : (stc[0]?.getD default).size ≠ 0) :
    stepBody.checkMultiSig ctx w st = .error .sigNullDummy := by
  have hnotrange2 : ¬ (nsv < 0 ∨ max (nkv : Int) 0 < nsv) := by
    simpa [hrange2]
  have hnsv0 : ¬ nsv < 0 := fun h => hnotrange2 (Or.inl h)
  have hnkmax : ¬ (max (nkv : Int) 0 < nsv) := fun h => hnotrange2 (Or.inr h)
  have hnotrange : ¬ (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) := by
    simpa [hrange]
  have hnkv_nonneg : 0 ≤ nkv := by
    have h : ¬ nkv < 0 := fun h => hnotrange (Or.inl h)
    exact Int.not_lt.mp h
  have hnk : ¬ ((nkv.toNat : Int) < nsv) := by
    intro hlt
    have hlt' : nkv < nsv := by
      rwa [Int.toNat_of_nonneg hnkv_nonneg] at hlt
    exact hnkmax (by simpa [Int.max_eq_left hnkv_nonneg] using hlt')
  have hl3 : ¬ (st.stack.length < nkv.toNat + nsv.toNat + 3) := by
    rw [hlen3]; simp
  have hne0 : st.stack ≠ [] := by
    intro h
    rw [h] at hl3
    simp at hl3
  have hneEmpty : stc[0]?.getD default ≠ ByteArray.empty := by
    intro h
    exact hne (by simp [h])
  have hpre : ¬ (st.stack.length < 1) := by omega
  rw [checkMultiSig_cmsFadFold]
  simp only [List.getElem!_eq_getElem?_getD, hsv, hpre, hd1, hrange, hop,
    hlen2, hd2, hrange2, hnsv0, hnk, hlen3]
  rw [hfd]
  dsimp only
  rw [hloop]
  dsimp only
  rw [hclean]
  dsimp only
  simp [hne, hlen, hflag, hneEmpty]

/-- **SCR-119 (explicit-dummy form)**: with NULLDUMMY set, on the
successful matching path, a non-empty historical dummy at index
`nKeys + nSigs + 2` (depth `nKeys + nSigs + 2` from the top; `nKeys + 2`
when `nSigs = 0`) is `SCRIPT_ERR_SIG_NULLDUMMY` for every in-range
`nSigs`/`nKeys` (`interpreter.cpp:1211-1212`). -/
@[rule "SCR-119"]
theorem checkMultiSig_nulldummy_general_dummy
    (ctx : Ctx) (st : State) (nkv nsv : ScriptNum) (scriptCode : ByteArray)
    (hsv : ctx.sv ≠ .tapscript)
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol
      (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hrange2 : (nsv < 0 ∨ max (nkv : Int) 0 < nsv) = false)
    (hlen3 : (st.stack.length < nkv.toNat + nsv.toNat + 3) = false)
    (hfd : BitcoinProofs.AF.PDW84.cmsFadFold ctx st nkv.toNat
      (ctx.bytes.extract st.codeSep ctx.bytes.size) nsv.toNat = .ok scriptCode)
    (hloop : cmsLoop ctx.flags ctx.pol ctx.sv ctx.chk ctx.ed scriptCode
      st.stack (nkv.toNat + nsv.toNat + 1) nkv.toNat nsv.toNat
      (nkv.toNat + 3) 2 = .ok true)
    (hflag : ctx.flags.nullDummy = true)
    (hne : (st.stack[nkv.toNat + nsv.toNat + 2]?.getD default).size ≠ 0) :
    stepBody.checkMultiSig ctx 0xae st = .error .sigNullDummy := by
  have hl3 : ¬ (st.stack.length < nkv.toNat + nsv.toNat + 3) := by
    rw [hlen3]; simp
  have hcl : cmsCleanup ctx.pol st.stack true
      (nkv.toNat + nsv.toNat + 3) (nkv.toNat + 2)
      (nkv.toNat + nsv.toNat + 3) =
      .ok (st.stack.drop (nkv.toNat + nsv.toNat + 2)) := by
    have h := BitcoinProofs.AF.PDW84.cmsCleanup_true_eq ctx.pol
      (nkv.toNat + nsv.toNat + 3) (nkv.toNat + nsv.toNat + 3)
      (nkv.toNat + 2) st.stack (Nat.le_refl _) (by omega)
    rw [show nkv.toNat + nsv.toNat + 3 - 1 =
      nkv.toNat + nsv.toNat + 2 from by omega] at h
    exact h
  have hlenStc : ¬ (st.stack.drop (nkv.toNat + nsv.toNat + 2)).length < 1 := by
    rw [List.length_drop]
    omega
  have hne! : (st.stack.drop (nkv.toNat + nsv.toNat + 2))[0]!.size ≠ 0 := by
    rw [BitcoinProofs.Theorems.Ops.O09.getElem!_drop_zero]
    simpa only [List.getElem!_eq_getElem?_getD] using hne
  have hne' : ((st.stack.drop (nkv.toNat + nsv.toNat + 2))[0]?.getD
      default).size ≠ 0 := by
    simpa only [List.getElem!_eq_getElem?_getD] using hne!
  exact checkMultiSig_nulldummy_general ctx st nkv nsv scriptCode
    (st.stack.drop (nkv.toNat + nsv.toNat + 2)) true 0xae
    hsv hd1 hrange hop hlen2 hd2 hrange2 hlen3 hfd hloop hcl hlenStc hflag hne'

end BitcoinProofs.AF.PDW87

/-- info: 'BitcoinProofs.AF.PDW87.stepBody_codesep_unexec' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW87.stepBody_codesep_unexec

/-- info: 'BitcoinProofs.AF.PDW87.evalChecksigPreTapscript_empty_sig' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW87.evalChecksigPreTapscript_empty_sig

/-- info: 'BitcoinProofs.AF.PDW87.evalChecksigPreTapscript_nullfail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW87.evalChecksigPreTapscript_nullfail

/-- info: 'BitcoinProofs.AF.PDW87.checkMultiSig_extra_item_consumed' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW87.checkMultiSig_extra_item_consumed

/-- info: 'BitcoinProofs.AF.PDW87.checkMultiSig_nulldummy' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW87.checkMultiSig_nulldummy

/-- info: 'BitcoinProofs.AF.PDW87.evalChecksigPreTapscript_findAndDelete' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW87.evalChecksigPreTapscript_findAndDelete

/-- info: 'BitcoinProofs.AF.PDW87.checkMultiSig_post_cleanup' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW87.checkMultiSig_post_cleanup
/-- info: 'BitcoinProofs.AF.PDW87.checkMultiSig_extra_item_consumed_general' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW87.checkMultiSig_extra_item_consumed_general
/-- info: 'BitcoinProofs.AF.PDW87.checkMultiSig_nulldummy_general' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW87.checkMultiSig_nulldummy_general
/-- info: 'BitcoinProofs.AF.PDW87.checkMultiSig_nulldummy_general_dummy' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW87.checkMultiSig_nulldummy_general_dummy
