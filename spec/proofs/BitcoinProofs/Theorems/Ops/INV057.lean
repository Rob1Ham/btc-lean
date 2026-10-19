import BitcoinProofs.Theorems.Ops.O07
import Bitcoin.Crypto.Taproot.Sighash
import BitcoinProofs.AF.PDW41.TPR043

/-!
# INV-057 — the executed `OP_CODESEPARATOR` position reaches the sighash

The residual target `Bitcoin.SigHash.findAndDeleteL_codeSep_eq` only proves
the deletion algebra for the legacy scriptCode. This module composes the
executed opcode transition with both consumers of the recorded position:

* **tapscript** — `step_codesep_tapscript` records `codeSepPos :=
  st.opcodeIndex` (the 0-based instruction index), `signatureExecutionData`
  copies it into `ScriptExecutionData`, `extSlice` serializes it as the
  BIP342 `codesep_pos` field, and `sigMsgTaproot`/`sighashTaproot` commit
  the extension slice.
* **legacy** — `step_codesep_base` records `codeSep := op.next` (the byte
  offset just past the separator), and `evalChecksigPreTapscript` reads the
  scriptCode from exactly that offset.

The primary theorem `codesep_position_commit` packages both lanes; the
two helper lemmas are the per-lane decompositions.
-/

namespace BitcoinProofs.Theorems.Ops.INV057

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Activation
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)
open Bitcoin.Crypto.Taproot
open Bitcoin.Crypto.Schnorr (taggedHash tagTapSighash)
open BitcoinProofs.Theorems.Ops.O07

set_option maxHeartbeats 1000000 in
/-- Tapscript lane: executing `OP_CODESEPARATOR` records the current
0-based instruction index, and both the SigMsg and the tagged sighash
commit that index in the extension slice. -/
theorem codesep_tapscript_commit (env : TapSighashEnv) (inPos : Nat)
    (ht : UInt8) (ctx : Ctx) (op : WireOp) (st : State)
    (a s : ByteArray)
    (hw : op.wire = 0xab) (hast : op.ast = .op ⟨0xab, by decide⟩)
    (hsv : ctx.sv = .tapscript) (hvf : st.vf.all id = true)
    (htl : ctx.ed.tapleafHashInit = true)
    (hg : sigMsgGate env inPos ht SigVersion.tapscript
      { ctx.ed with codesepPosInit := true, codesepPos := st.opcodeIndex } = true)
    (ha : acpSlice env inPos ht = some a)
    (hs : singleSlice env inPos ht
      { ctx.ed with codesepPosInit := true, codesepPos := st.opcodeIndex } = some s) :
    ∃ pre,
      stepBody ctx op st =
        .ok { st with codeSep := op.next, codeSepPos := st.opcodeIndex } ∧
      sigMsgTaproot env inPos ht SigVersion.tapscript
        (signatureExecutionData ctx
          { st with codeSep := op.next, codeSepPos := st.opcodeIndex }) =
          some (pre ++ ctx.ed.tapleafHash ++ serU8 0 ++ serU32 st.opcodeIndex) ∧
      sighashTaproot env inPos ht SigVersion.tapscript
        (signatureExecutionData ctx
          { st with codeSep := op.next, codeSepPos := st.opcodeIndex }) =
          some (taggedHash tagTapSighash
            (serU8 0 ++ (pre ++ ctx.ed.tapleafHash ++ serU8 0 ++
              serU32 st.opcodeIndex))) := by
  let st' : State := { st with codeSep := op.next, codeSepPos := st.opcodeIndex }
  let d : ScriptExecutionData := signatureExecutionData ctx st'
  have hstep : stepBody ctx op st = .ok st' :=
    step_codesep_tapscript ctx op st hw hast hsv hvf
  have hd : signatureExecutionData ctx st' =
      { ctx.ed with codesepPosInit := true, codesepPos := st.opcodeIndex } := by
    simp [signatureExecutionData, hsv, st']
  have hg' : sigMsgGate env inPos ht SigVersion.tapscript
      (signatureExecutionData ctx st') = true := by
    rw [hd]; exact hg
  have he : extSlice SigVersion.tapscript (signatureExecutionData ctx st') =
      some (ctx.ed.tapleafHash ++ serU8 0 ++ serU32 st.opcodeIndex) := by
    rw [hd]
    exact BitcoinProofs.AF.PDW41.extSlice_tapscript_row
      { ctx.ed with codesepPosInit := true, codesepPos := st.opcodeIndex }
      (by simpa using htl) rfl
  have hs' : singleSlice env inPos ht (signatureExecutionData ctx st') = some s := by
    rw [hd]; exact hs
  have hbody :=
    sigMsgTaproot_body env inPos ht SigVersion.tapscript d a s
      (ctx.ed.tapleafHash ++ serU8 0 ++ serU32 st.opcodeIndex)
      (by simpa [d] using hg') ha (by simpa [d] using hs') he
  obtain ⟨pre, hpre⟩ :
      ∃ pre, sigMsgTaproot env inPos ht SigVersion.tapscript d =
        some (pre ++ (ctx.ed.tapleafHash ++ serU8 0 ++ serU32 st.opcodeIndex)) :=
    ⟨_, hbody⟩
  have hpre' : sigMsgTaproot env inPos ht SigVersion.tapscript
      (signatureExecutionData ctx st') =
        some (pre ++ (ctx.ed.tapleafHash ++ serU8 0 ++ serU32 st.opcodeIndex)) := by
    simpa [d] using hpre
  refine ⟨pre, hstep, ?_, ?_⟩
  · simpa [st', ByteArray.append_assoc] using hpre'
  · unfold sighashTaproot
    simp only [hpre', st', Option.map_some, ByteArray.append_assoc]

/-- Legacy lane: executing `OP_CODESEPARATOR` records the byte offset
`op.next`; `signatureExecutionData` is untouched (no BIP342 `codesep_pos`
commit), and `evalChecksigPreTapscript` extracts the scriptCode from the
recorded offset. -/
theorem codesep_legacy_commit (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xab) (hast : op.ast = .op ⟨0xab, by decide⟩)
    (hsv : ctx.sv = .base) (hnc : ctx.pol.constScriptCode = false)
    (hvf : st.vf.all id = true) (hbud : st.opCount < MAX_OPS_PER_SCRIPT) :
    let st' : State :=
      { st with
        opCount := st.opCount + 1,
        codeSep := op.next,
        codeSepPos := st.opcodeIndex }
    stepBody ctx op st = .ok st' ∧
    signatureExecutionData ctx st' = ctx.ed ∧
    st'.codeSep = op.next ∧
    (∀ (sig pk : ByteArray),
      evalChecksigPreTapscript ctx.flags ctx.pol ctx.chk ctx.ed SigVersion.base
        st'.codeSep ctx.bytes sig pk =
      evalChecksigPreTapscript ctx.flags ctx.pol ctx.chk ctx.ed SigVersion.base
        op.next ctx.bytes sig pk) := by
  let st' : State :=
    { st with
      opCount := st.opCount + 1,
      codeSep := op.next,
      codeSepPos := st.opcodeIndex }
  have hstep : stepBody ctx op st = .ok st' :=
    step_codesep_base ctx op st hw hast hsv hnc hvf hbud
  have hd : signatureExecutionData ctx st' = ctx.ed := by
    simp [signatureExecutionData, hsv]
  refine ⟨hstep, hd, rfl, ?_⟩
  intro sig pk
  rfl

/-- **INV-057** (whole rule): an executed `OP_CODESEPARATOR` commits its
position all the way to the signature digest. The tapscript lane commits
the 0-based instruction index (`st.opcodeIndex`) through
`extSlice`/`sigMsgTaproot`/`sighashTaproot`; the legacy lane commits the
byte offset (`op.next`) through the scriptCode slice handed to
`evalChecksigPreTapscript`. -/
@[rule "INV-057"]
theorem codesep_position_commit (env : TapSighashEnv) (inPos : Nat)
    (ht : UInt8) (ctx : Ctx) (op : WireOp) (st : State) (a s : ByteArray)
    (hw : op.wire = 0xab) (hast : op.ast = .op ⟨0xab, by decide⟩) :
    (ctx.sv = SigVersion.tapscript →
      st.vf.all id = true →
      ctx.ed.tapleafHashInit = true →
      sigMsgGate env inPos ht SigVersion.tapscript
        { ctx.ed with codesepPosInit := true, codesepPos := st.opcodeIndex } = true →
      acpSlice env inPos ht = some a →
      singleSlice env inPos ht
        { ctx.ed with codesepPosInit := true, codesepPos := st.opcodeIndex } = some s →
      ∃ pre,
        stepBody ctx op st =
          .ok { st with codeSep := op.next, codeSepPos := st.opcodeIndex } ∧
        sigMsgTaproot env inPos ht SigVersion.tapscript
          (signatureExecutionData ctx
            { st with codeSep := op.next, codeSepPos := st.opcodeIndex }) =
            some (pre ++ ctx.ed.tapleafHash ++ serU8 0 ++ serU32 st.opcodeIndex) ∧
        sighashTaproot env inPos ht SigVersion.tapscript
          (signatureExecutionData ctx
            { st with codeSep := op.next, codeSepPos := st.opcodeIndex }) =
            some (taggedHash tagTapSighash
              (serU8 0 ++ (pre ++ ctx.ed.tapleafHash ++ serU8 0 ++
                serU32 st.opcodeIndex)))) ∧
    (ctx.sv = SigVersion.base →
      ctx.pol.constScriptCode = false →
      st.vf.all id = true →
      st.opCount < MAX_OPS_PER_SCRIPT →
      let st' : State :=
        { st with
          opCount := st.opCount + 1,
          codeSep := op.next,
          codeSepPos := st.opcodeIndex }
      stepBody ctx op st = .ok st' ∧
      signatureExecutionData ctx st' = ctx.ed ∧
      st'.codeSep = op.next ∧
      (∀ (sig pk : ByteArray),
        evalChecksigPreTapscript ctx.flags ctx.pol ctx.chk ctx.ed
          SigVersion.base st'.codeSep ctx.bytes sig pk =
        evalChecksigPreTapscript ctx.flags ctx.pol ctx.chk ctx.ed
          SigVersion.base op.next ctx.bytes sig pk)) := by
  constructor
  · intro hsv hvf htl hg ha hs
    exact codesep_tapscript_commit env inPos ht ctx op st a s hw hast hsv hvf
      htl hg ha hs
  · intro hsv hnc hvf hbud
    exact codesep_legacy_commit ctx op st hw hast hsv hnc hvf hbud

end BitcoinProofs.Theorems.Ops.INV057
