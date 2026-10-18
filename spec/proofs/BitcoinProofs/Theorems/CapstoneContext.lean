import BitcoinProofs.Theorems.CapstoneFunding

/-! R04: header-context enforcement on the actual serialized-block path.
The ancestor lookup is the caller's validated parent-chain state, just as
the UTXO view is input state. These theorems do not validate prior blocks. -/

namespace BitcoinProofs.Theorems.CapstoneContext

open Bitcoin.Data Bitcoin.Chain Bitcoin.Serialization Bitcoin.Block.Pow
open Bitcoin.Capstone.Context Bitcoin.Capstone.Block
open BitcoinProofs.Theorems.CapstonePipeline

/-- A complete MTP window resolves every height that Core would visit. -/
theorem requireMtpWindow_complete {ctx : ChainContext} {fuel height : Nat}
    (h : requireMtpWindow ctx fuel height = .ok ()) :
    ∀ i, i < fuel → i ≤ height → ∃ header, ancestor ctx (height-i) = .ok header := by
  induction fuel generalizing height with
  | zero => omega
  | succ fuel ih =>
    simp only [requireMtpWindow] at h
    cases ha : ancestor ctx height with
    | error e => simp [ha] at h
    | ok header =>
      simp only [ha, ebind_ok] at h
      intro i hi hheight
      cases i with
      | zero => simpa using (Exists.intro header ha)
      | succ i =>
        have hn : height ≠ 0 := by omega
        simp only [hn, ↓reduceIte] at h
        have step := ih h i (by omega) (by omega)
        simpa [Nat.sub_sub, Nat.add_comm] using step

/-- A successful strict median never skips a missing internal ancestor. -/
theorem medianTimePastStrict_complete {ctx : ChainContext} {height : Nat} {mtp : UInt32}
    (h : medianTimePastStrict ctx height = .ok mtp) :
    ∀ i, i < 11 → i ≤ height → ∃ header, ancestor ctx (height-i) = .ok header := by
  unfold medianTimePastStrict at h
  cases hw : requireMtpWindow ctx 11 height with
  | error e => simp [hw] at h
  | ok unit =>
    cases unit
    exact requireMtpWindow_complete hw

/-- Successful header checks expose the exact expected nBits, full-window
MTP and signed node-clock bound; none is assumed by the theorem. -/
theorem checkHeaderContext_ok {ctx : ChainContext} {height : UInt32}
    {parent : ByteArray} {header : BlockHeader} {facts : HeaderFacts}
    (h : checkHeaderContext ctx height parent header = .ok facts) :
    ∃ expected mtp,
      resolveExpectedBits ctx height parent header = .ok expected ∧
      medianTimePastStrict ctx ctx.parentHeight = .ok mtp ∧
      facts = ⟨expected, mtp⟩ ∧ header.bits = expected ∧
      header.time > mtp ∧ (header.time.toNat : Int) ≤ ctx.nodeTime + 7200 := by
  unfold checkHeaderContext at h
  cases he : resolveExpectedBits ctx height parent header with
  | error e => simp [he] at h
  | ok expected =>
    simp only [he, ebind_ok] at h
    split at h
    · simp at h
    · rename_i bits
      cases hm : medianTimePastStrict ctx ctx.parentHeight with
      | error e => simp [hm] at h
      | ok mtp =>
        simp only [hm, ebind_ok] at h
        split at h
        · simp at h
        · rename_i old
          split at h
          · simp at h
          · rename_i future
            simp only [epure_ok, Except.ok.injEq] at h
            subst facts
            exact ⟨expected, mtp, rfl, rfl, rfl, by simpa using bits,
              by simpa [timeNotTooOld] using old, by simpa using future⟩

/-- A successful contextual public call ran the actual header-context
checker against the decoded header and the state's expected parent hash. -/
theorem validateBlockInContext_header {raw : ByteArray} {st : CapState}
    {ctx : ChainContext} {report : CapReport}
    (h : validateBlockInContext raw st ctx = .ok report) :
    ∃ header txs facts,
      decodeBlock raw = .ok (header, txs) ∧
      checkHeaderContext ctx st.height st.prevHash header = .ok facts := by
  unfold validateBlockInContext at h
  rw [validateBlock.eq_1] at h
  cases hd : decodeBlock raw with
  | error e => simp [hd] at h
  | ok p =>
    obtain ⟨header, txs⟩ := p
    simp only [hd, epure_ok, ebind_ok] at h
    obtain ⟨_, h⟩ := gate_step _ _ h -- nonempty
    obtain ⟨_, h⟩ := gate_step _ _ h -- coinbase position
    obtain ⟨_, h⟩ := gate_step _ _ h -- coinbase length
    obtain ⟨_, h⟩ := gate_step _ _ h -- target
    obtain ⟨_, h⟩ := gate_step _ _ h -- proof of work
    obtain ⟨_, h⟩ := gate_step _ _ h -- parent link
    cases hc : checkHeaderContext ctx st.height st.prevHash header with
    | error e => simp [hc] at h
    | ok facts => exact ⟨header, txs, facts, rfl, hc⟩

/-- Thus the public contextual entry point enforces all three missing
header rules on the same decoded header, rather than isolated helpers. -/
theorem validateBlockInContext_header_rules {raw : ByteArray} {st : CapState}
    {ctx : ChainContext} {report : CapReport}
    (h : validateBlockInContext raw st ctx = .ok report) :
    ∃ header txs mtp,
      decodeBlock raw = .ok (header, txs) ∧
      resolveExpectedBits ctx st.height st.prevHash header = .ok header.bits ∧
      medianTimePastStrict ctx ctx.parentHeight = .ok mtp ∧
      header.time > mtp ∧ (header.time.toNat : Int) ≤ ctx.nodeTime + 7200 := by
  obtain ⟨header, txs, facts, hd, hc⟩ := validateBlockInContext_header h
  obtain ⟨expected, mtp, he, hm, _, bits, old, future⟩ := checkHeaderContext_ok hc
  exact ⟨header, txs, mtp, hd, bits ▸ he, hm, old, future⟩

/-- info: 'BitcoinProofs.Theorems.CapstoneContext.requireMtpWindow_complete' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms requireMtpWindow_complete
/-- info: 'BitcoinProofs.Theorems.CapstoneContext.medianTimePastStrict_complete' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms medianTimePastStrict_complete
/-- info: 'BitcoinProofs.Theorems.CapstoneContext.checkHeaderContext_ok' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms checkHeaderContext_ok
/-- info: 'BitcoinProofs.Theorems.CapstoneContext.validateBlockInContext_header' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms validateBlockInContext_header
/-- info: 'BitcoinProofs.Theorems.CapstoneContext.validateBlockInContext_header_rules' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms validateBlockInContext_header_rules

end BitcoinProofs.Theorems.CapstoneContext
