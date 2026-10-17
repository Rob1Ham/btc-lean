import Bitcoin.Interpreter.Defs
import Bitcoin.Activation.Flags

/-! # PDW93b — hard-tail row faces: pubkey-type policy, CScriptNum bound,
LOW_S policy gate. Route B, zero core writes. -/

namespace BitcoinProofs.AF.PDW93
open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Activation Bitcoin.Crypto.Seam

/-! ## SWT-056 — WITNESS_PUBKEYTYPE is a policy bit, never consensus -/

/-- SWT-056 (off): with the policy bit clear the compressed-key error is
never produced, whatever the script version or key shape. -/
@[rule "SWT-056"]
theorem witnessPubkeyType_off (flags : ScriptFlags) (pol : PolicyFlags)
    (sv : SigVersion) (pk : ByteArray) (hp : pol.witnessPubkeyType = false) :
    checkPubKeyEncoding flags pol sv pk ≠ some .witnessPubkeyType := by
  unfold checkPubKeyEncoding
  simp [hp]

/-- SWT-056 (on): policy on + witness-v0 + uncompressed key (STRICTENC not
tripped) yields exactly `WITNESS_PUBKEYTYPE`. -/
@[rule "SWT-056"]
theorem witnessPubkeyType_on (flags : ScriptFlags) (pol : PolicyFlags)
    (sv : SigVersion) (pk : ByteArray) (hp : pol.witnessPubkeyType = true)
    (hsv : sv = .witnessV0) (hc : isCompressedPubKey pk = false)
    (hse : pol.strictEnc = false ∨ isCompressedOrUncompressedPubKey pk = true) :
    checkPubKeyEncoding flags pol sv pk = some .witnessPubkeyType := by
  unfold checkPubKeyEncoding
  rcases hse with h | h <;> simp [hp, hsv, hc, h]

/-- SWT-056 (consensus projection): block flag selection assigns the bit
`false` for every consensus `ScriptFlags`. -/
@[rule "SWT-056"]
theorem witnessPubkeyType_absent_from_consensus (f : ScriptFlags) :
    (consensusFullFlags f).policy .witnessPubKeyType = false := rfl

/-! ## INV-058 — CScriptNum constructor: width bound + minimal encoding -/

/-- INV-058 (width): a successfully decoded operand fits the call site's
`maxSize` (4 general, 5 for CLTV/CSV). -/
@[rule "INV-058"]
theorem decodeNum_size_le {pol : PolicyFlags} {b : ByteArray} {maxSize : Nat}
    {n : ScriptNum} (h : decodeNum pol b maxSize = .ok n) : b.size ≤ maxSize := by
  unfold decodeNum at h
  cases hd : decodeScriptNum b pol.minimalData maxSize with
  | none => simp [hd] at h
  | some n0 =>
    unfold decodeScriptNum decodeBE at hd
    by_cases hle : b.size ≤ maxSize
    · exact hle
    · have hw : (bytesOf b).reverse.length > maxSize := by
        simp [List.length_reverse, bytesOf_length]; omega
      rw [if_pos hw] at hd
      simp at hd

/-- INV-058 (the full numeric encoding rule, not just the width bound):
a successful `decodeNum` operand (a) fits the call site's `maxSize`
(4 general; 5 at the CLTV/CSV opcodes, interpreter.cpp:833-849), (b) has
the exact little-endian sign-magnitude value `set_vch` (`CScriptNum`
constructor), and (c) under MINIMALDATA is minimally encoded. -/
@[rule "INV-058"]
theorem decodeNum_encoding_rule {pol : PolicyFlags} {b : ByteArray} {maxSize : Nat}
    {n : ScriptNum} (h : decodeNum pol b maxSize = .ok n) :
    b.size ≤ maxSize ∧
      n = Bitcoin.Numeric.setVchBE (bytesOf b).reverse ∧
      (pol.minimalData = true → minimalOkBE (bytesOf b).reverse = true) := by
  unfold decodeNum at h
  cases hd : decodeScriptNum b pol.minimalData maxSize with
  | none => simp [hd] at h
  | some n0 =>
    have hv := Bitcoin.Numeric.decodeScriptNum_value b pol.minimalData maxSize n0 hd
    obtain ⟨hval, hlen, hmin⟩ := hv
    have hn : n0 = n := by simpa [hd] using h
    refine ⟨?_, ?_, ?_⟩
    · rw [List.length_reverse, bytesOf_length] at hlen
      exact hlen
    · rw [← hn]
      exact hval
    · intro hm
      rcases hmin with hf | hok
      · rw [hf] at hm
        exact absurd hm (by decide)
      · exact hok

/-- INV-058 (minimal): under MINIMALDATA only minimal encodings decode. -/
@[rule "INV-058"]
theorem decodeNum_minimal {pol : PolicyFlags} {b : ByteArray} {maxSize : Nat}
    {n : ScriptNum} (h : decodeNum pol b maxSize = .ok n)
    (hm : pol.minimalData = true) :
    minimalOkBE (bytesOf b).reverse = true := by
  have hw := decodeNum_size_le h
  unfold decodeNum at h
  cases hd : decodeScriptNum b pol.minimalData maxSize with
  | none => simp [hd] at h
  | some n0 =>
    unfold decodeScriptNum decodeBE at hd
    by_cases hc : minimalOkBE (bytesOf b).reverse = true
    · exact hc
    · exfalso
      have hmin : pol.minimalData = true ∧ ¬ minimalOkBE (bytesOf b).reverse = true :=
        ⟨hm, hc⟩
      rw [if_neg (by simp [List.length_reverse, bytesOf_length]; omega), if_pos hmin] at hd
      simp at hd

/-! ### INV-058 — the two consensus widths at the real call sites

`decodeNum` takes the caller-supplied `maxSize`; Core has exactly two
constants in the interpreter: `CScriptNum(vch, fRequireMinimal)` uses the
default 4 (`interpreter.cpp:972-1019`, `interpreter.cpp:1103` for
CHECKSIGADD) and CLTV/CSV pass 5 explicitly (`interpreter.cpp:556`,
`interpreter.cpp:584`). The following results pin those instantiations
and drive them through the actual `stepBody`/`checksigAddStep` branches, so
the row is no longer relative to an arbitrary parameter. -/

/-- INV-058 (general numeric width): the 4-byte instantiation used by the
arithmetic opcodes and CHECKSIGADD's `num` operand. -/
@[rule "INV-058"]
theorem decodeNum_width_four {pol : PolicyFlags} {b : ByteArray} {n : ScriptNum}
    (h : decodeNum pol b 4 = .ok n) : b.size ≤ 4 :=
  decodeNum_size_le h

/-- INV-058 (CLTV/CSV width): the 5-byte instantiation used only by
OP_CHECKLOCKTIMEVERIFY / OP_CHECKSEQUENCEVERIFY. -/
@[rule "INV-058"]
theorem decodeNum_width_five {pol : PolicyFlags} {b : ByteArray} {n : ScriptNum}
    (h : decodeNum pol b 5 = .ok n) : b.size ≤ 5 :=
  decodeNum_size_le h

/-- INV-058 (general call site): CHECKSIGADD's `num` operand is read
through exactly `decodeNum pol num 4`, so a successful step forces
`num.size ≤ 4` unconditionally (interpreter.cpp:1103). -/
@[rule "INV-058"]
theorem checksigAddStep_num_width_four {pol : PolicyFlags} {chk : ScriptChecker}
    {ed : ScriptExecutionData} {sig num pk : ByteArray} {vw : Option Int}
    {n : ScriptNum} {vw' : Option Int}
    (h : checksigAddStep pol chk ed sig num pk vw = .ok (n, vw')) :
    num.size ≤ 4 := by
  unfold checksigAddStep at h
  split at h
  · simp at h
  · rename_i n0 hdec
    split at h
    · simp at h
    · exact decodeNum_width_four hdec

/-- INV-058 (CLTV call site): a successful OP_CHECKLOCKTIMEVERIFY step
with the flag on and a nonempty stack read its operand through
`decodeNum … 5`, hence the operand is at most 5 bytes
(interpreter.cpp:553-556). -/
@[rule "INV-058"]
theorem stepBody_cltv_operand_width_five (ctx : Ctx) (op : WireOp) (st : State)
    (o : Fin 256) {st' : State}
    (ha : op.ast = .op o) (hw : op.wire = 0xb1)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hfe : st.vf.all id = true) (hcltv : ctx.flags.cltv = true)
    (hstack : 1 ≤ st.stack.length)
    (hstep : stepBody ctx op st = .ok st') :
    (topAt st.stack 1).size ≤ 5 := by
  have hne : st.stack ≠ [] := by intro h; rw [h] at hstack; simp at hstack
  have hwire : 0x60 < op.wire := by rw [hw]; decide
  have hb : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1) :=
    fun h => hbudget ⟨h.1, hwire, h.2⟩
  have hb' : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT <
        (if (ctx.sv = .base ∨ ctx.sv = .witnessV0) then st.opCount + 1 else st.opCount)) := by
    intro h
    exact hb ⟨h.1, by
      have h2 := h.2
      rw [if_pos h.1] at h2
      exact h2⟩
  rw [stepBody] at hstep
  simp [ha, hw, hb', hfe, hcltv, hne, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp] at hstep
  cases hd : decodeNum ctx.pol (topAt st.stack 1) 5 with
  | error e => rw [hd] at hstep; cases hstep
  | ok n => exact decodeNum_width_five hd

/-- INV-058 (CSV call site): a successful OP_CHECKSEQUENCEVERIFY step with
the flag on and a nonempty stack reads its operand through
`decodeNum … 5`, hence the operand is at most 5 bytes
(interpreter.cpp:581-584). -/
@[rule "INV-058"]
theorem stepBody_csv_operand_width_five (ctx : Ctx) (op : WireOp) (st : State)
    (o : Fin 256) {st' : State}
    (ha : op.ast = .op o) (hw : op.wire = 0xb2)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hfe : st.vf.all id = true) (hcsv : ctx.flags.csv = true)
    (hstack : 1 ≤ st.stack.length)
    (hstep : stepBody ctx op st = .ok st') :
    (topAt st.stack 1).size ≤ 5 := by
  have hne : st.stack ≠ [] := by intro h; rw [h] at hstack; simp at hstack
  have hwire : 0x60 < op.wire := by rw [hw]; decide
  have hb : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1) :=
    fun h => hbudget ⟨h.1, hwire, h.2⟩
  have hb' : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT <
        (if (ctx.sv = .base ∨ ctx.sv = .witnessV0) then st.opCount + 1 else st.opCount)) := by
    intro h
    exact hb ⟨h.1, by
      have h2 := h.2
      rw [if_pos h.1] at h2
      exact h2⟩
  rw [stepBody] at hstep
  simp [ha, hw, hb', hfe, hcsv, hne, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp] at hstep
  cases hd : decodeNum ctx.pol (topAt st.stack 1) 5 with
  | error e => rw [hd] at hstep; cases hstep
  | ok n => exact decodeNum_width_five hd

/-- INV-058 (general arithmetic call site): a successful OP_ADD step reads
both operands through `decodeNum … 4` (interpreter.cpp:972-974). -/
@[rule "INV-058"]
theorem stepBody_opAdd_operand_width_four (ctx : Ctx) (op : WireOp) (st : State)
    (o : Fin 256) {st' : State}
    (ha : op.ast = .op o) (hw : op.wire = 0x93)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hfe : st.vf.all id = true) (hstack : 2 ≤ st.stack.length)
    (hstep : stepBody ctx op st = .ok st') :
    (topAt st.stack 2).size ≤ 4 ∧ (topAt st.stack 1).size ≤ 4 := by
  have hwire : 0x60 < op.wire := by rw [hw]; decide
  have hb : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1) :=
    fun h => hbudget ⟨h.1, hwire, h.2⟩
  have hb' : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT <
        (if (ctx.sv = .base ∨ ctx.sv = .witnessV0) then st.opCount + 1 else st.opCount)) := by
    intro h
    exact hb ⟨h.1, by
      have h2 := h.2
      rw [if_pos h.1] at h2
      exact h2⟩
  have hlt : ¬ List.length st.stack < 2 := Nat.not_lt.mpr hstack
  rw [stepBody] at hstep
  simp [ha, hw, hb', hfe, hlt, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp] at hstep
  cases hd2 : decodeNum ctx.pol (topAt st.stack 2) 4 with
  | error e => rw [hd2] at hstep; cases hstep
  | ok n2 =>
    cases hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 with
    | error e => rw [hd2, hd1] at hstep; cases hstep
    | ok n1 => exact ⟨decodeNum_width_four hd2, decodeNum_width_four hd1⟩

/-! ## SCR-175 — LOW_S is mempool policy, never block consensus -/

/-- SCR-175 (off): with LOW_S clear the high-S error is unreachable. -/
@[rule "SCR-175"]
theorem checkSigEncoding_lowS_off (flags : ScriptFlags) (pol : PolicyFlags)
    (sig : ByteArray) (hp : pol.lowS = false) :
    checkSigEncoding flags pol sig ≠ some .sigHighS := by
  unfold checkSigEncoding
  by_cases hsz : sig = ByteArray.empty
  · simp [hsz]
  · simp only [hsz, if_false, hp]
    split
    · simp
    · split <;> simp

/-- SCR-175 (on): LOW_S + valid DER + high S yields `SIG_HIGH_S`. -/
@[rule "SCR-175"]
theorem checkSigEncoding_lowS_high (flags : ScriptFlags) (pol : PolicyFlags)
    (sig : ByteArray) (hsz : sig.size ≠ 0) (hp : pol.lowS = true)
    (hder : isValidSigEncoding sig = true)
    (hlow : checkLowS (sig.extract 0 (sig.size - 1)) = false) :
    checkSigEncoding flags pol sig = some .sigHighS := by
  unfold checkSigEncoding
  simp [hsz, hp, hder, hlow]

/-- SCR-175 (consensus projection): LOW_S is absent from block flags. -/
@[rule "SCR-175"]
theorem lowS_absent_from_consensus (f : ScriptFlags) :
    (consensusFullFlags f).policy .lowS = false := rfl

/-- SCR-175 (the row, against the real selector): at EVERY height the
consensus view of `GetBlockScriptFlags` assigns LOW_S `false`, and the
LOW_S gate of `checkSigEncoding` is consequently off for block
validation (the policy word block validation passes is `default`). The
mempool's standard word is the only place the bit can be set
(`checkSigEncoding_lowS_high` is the enforcement direction). -/
@[rule "SCR-175"]
theorem lowS_never_block_consensus (height : UInt32) (sig : ByteArray) :
    (consensusFullFlags (getBlockScriptFlags height)).policy .lowS = false ∧
      checkSigEncoding (getBlockScriptFlags height) default sig ≠ some .sigHighS := by
  refine ⟨rfl, ?_⟩
  exact checkSigEncoding_lowS_off _ _ _ rfl

/-- SCR-175 (mempool direction): the model of Core's
`STANDARD_SCRIPT_VERIFY_FLAGS` (`policy/policy.h:114-130`, which contains
`SCRIPT_VERIFY_LOW_S`, `SCRIPT_VERIFY_STRICTENC`, `SCRIPT_VERIFY_MINIMALDATA`,
etc.). This is the positive half the row needs; the block selector above
proves the negative half. (`SIGPUSHONLY` is not in the standard script
word, so it stays false.) -/
@[rule "SCR-175"]
def standardPolicy : PolicyFlags :=
  { minimalData := true, minimalIf := true, nullFail := true,
    strictEnc := true, constScriptCode := true, cleanstack := true,
    sigPushOnly := false, lowS := true, witnessPubkeyType := true,
    discourageUpgradableNops := true,
    discourageUpgradableWitnessProgram := true,
    discourageUpgradablePubkeyType := true,
    discourageOpSuccess := true,
    discourageUpgradableTaprootVersion := true }

/-- SCR-175 (mempool direction): the standard policy word has the LOW_S
bit on. -/
@[rule "SCR-175"]
theorem standardPolicy_lowS : standardPolicy.lowS = true := rfl

/-- SCR-175 (mempool enforcement): with the standard policy word, a
nonempty valid-DER high-S signature is rejected as `SIG_HIGH_S`. -/
@[rule "SCR-175"]
theorem standardPolicy_lowS_high (flags : ScriptFlags) (sig : ByteArray)
    (hsz : sig.size ≠ 0) (hder : isValidSigEncoding sig = true)
    (hlow : checkLowS (sig.extract 0 (sig.size - 1)) = false) :
    checkSigEncoding flags standardPolicy sig = some .sigHighS :=
  checkSigEncoding_lowS_high flags _ sig hsz standardPolicy_lowS hder hlow

/-- SCR-175 (the complete row): LOW_S is off in the block consensus word at
every height, while the mempool standard word sets it on. -/
@[rule "SCR-175"]
theorem lowS_block_vs_standard (height : UInt32) :
    (consensusFullFlags (getBlockScriptFlags height)).policy .lowS = false ∧
      standardPolicy.lowS = true :=
  ⟨(lowS_never_block_consensus height ByteArray.empty).1, standardPolicy_lowS⟩

end BitcoinProofs.AF.PDW93

/-! ## Axiom pins (charter subset `[propext, Classical.choice, Quot.sound]`) -/

/-- info: 'BitcoinProofs.AF.PDW93.witnessPubkeyType_off' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.witnessPubkeyType_off
/-- info: 'BitcoinProofs.AF.PDW93.witnessPubkeyType_on' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.witnessPubkeyType_on
/-- info: 'BitcoinProofs.AF.PDW93.witnessPubkeyType_absent_from_consensus' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.witnessPubkeyType_absent_from_consensus
/-- info: 'BitcoinProofs.AF.PDW93.decodeNum_size_le' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.decodeNum_size_le
/-- info: 'BitcoinProofs.AF.PDW93.decodeNum_minimal' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.decodeNum_minimal
/-- info: 'BitcoinProofs.AF.PDW93.checkSigEncoding_lowS_off' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.checkSigEncoding_lowS_off
/-- info: 'BitcoinProofs.AF.PDW93.checkSigEncoding_lowS_high' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.checkSigEncoding_lowS_high
/-- info: 'BitcoinProofs.AF.PDW93.lowS_absent_from_consensus' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.lowS_absent_from_consensus
/-- info: 'BitcoinProofs.AF.PDW93.decodeNum_encoding_rule' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.decodeNum_encoding_rule
/-- info: 'BitcoinProofs.AF.PDW93.lowS_never_block_consensus' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.lowS_never_block_consensus
/-- info: 'BitcoinProofs.AF.PDW93.decodeNum_width_four' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.decodeNum_width_four
/-- info: 'BitcoinProofs.AF.PDW93.decodeNum_width_five' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.decodeNum_width_five
/-- info: 'BitcoinProofs.AF.PDW93.checksigAddStep_num_width_four' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.checksigAddStep_num_width_four
/-- info: 'BitcoinProofs.AF.PDW93.stepBody_cltv_operand_width_five' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.stepBody_cltv_operand_width_five
/-- info: 'BitcoinProofs.AF.PDW93.stepBody_csv_operand_width_five' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.stepBody_csv_operand_width_five
/-- info: 'BitcoinProofs.AF.PDW93.stepBody_opAdd_operand_width_four' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.stepBody_opAdd_operand_width_four
/-- info: 'BitcoinProofs.AF.PDW93.standardPolicy_lowS' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.standardPolicy_lowS
/-- info: 'BitcoinProofs.AF.PDW93.standardPolicy_lowS_high' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.standardPolicy_lowS_high
/-- info: 'BitcoinProofs.AF.PDW93.lowS_block_vs_standard' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.lowS_block_vs_standard
