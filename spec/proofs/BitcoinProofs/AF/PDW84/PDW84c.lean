import Bitcoin.Interpreter.Defs

/-! # PDW84c — TOP-442/445: CMS FindAndDelete ordering + boundary scan

Route B, zero core writes.

* **SCR-115** (nSigs = 1 instance): in BASE the signature push is
  FindAndDelete'd from the scriptCode *before* any signature check; with
  CONST_SCRIPTCODE a found match aborts with `sigFindAndDelete` and the
  checker loop is never entered.
* **SCR-098**: the greedy scan consumes whole needle copies only
  (`span` law). The full row face is **false of the current core model**:
  the final `fdLastPc2` tail copy re-appends the last deleted segment, so
  a match that reaches the script end is counted but not removed. The
  abstract divergence theorem records the exact failure shape; see
  findings PDW84 §3. -/

namespace BitcoinProofs.AF.PDW84

open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Script.Parser

/-- The per-signature FindAndDelete step of `checkMultiSig`, factored out
of the inline `List.range nSigs` fold in `Bitcoin.Interpreter.Defs`.
`acc` is the accumulated scriptCode (or the first error). -/
def cmsFadStep (ctx : Ctx) (st : State) (nKeys : Nat)
    (acc : Except ExecError ByteArray) (k : Nat) : Except ExecError ByteArray :=
  match acc with
  | .error e => .error e
  | .ok sc =>
    if ctx.sv = .base then
      let (found, sc') := findAndDelete sc
        (pushBytesWire (st.stack[nKeys + k + 2]!))
      if 0 < found ∧ ctx.pol.constScriptCode then .error .sigFindAndDelete
      else .ok sc'
    else .ok sc

/-- The cumulative FindAndDelete fold over the first `n` signature
indices, starting from `sc0`. -/
def cmsFadFold (ctx : Ctx) (st : State) (nKeys : Nat)
    (sc0 : ByteArray) (n : Nat) : Except ExecError ByteArray :=
  (List.range n).foldl (cmsFadStep ctx st nKeys) (.ok sc0)

/-- **SCR-115 (fold coverage)**: the fold really visits every signature
index in `[0, nSigs)`; its result at `nSigs` is the fold at `nSigs - 1`
followed by the last deletion, so "all `nSigsCount` sigs" is not an
instance but the whole range. -/
theorem cmsFadFold_succ (ctx : Ctx) (st : State) (nKeys : Nat)
    (sc0 : ByteArray) (n : Nat) :
    cmsFadFold ctx st nKeys sc0 (n + 1) =
      cmsFadStep ctx st nKeys (cmsFadFold ctx st nKeys sc0 n) n := by
  unfold cmsFadFold
  rw [List.range_succ, List.foldl_append]
  simp

/-- The fold is sticky in its error: once the step at index `k` fails,
every longer fold ends in the same error. -/
theorem cmsFadFold_error_of_step (ctx : Ctx) (st : State) (nKeys : Nat)
    (sc0 : ByteArray) (n k : Nat) (e : ExecError)
    (hk : k < n)
    (h : cmsFadStep ctx st nKeys (cmsFadFold ctx st nKeys sc0 k) k = .error e) :
    cmsFadFold ctx st nKeys sc0 n = .error e := by
  induction n with
  | zero => omega
  | succ n ih =>
    rw [cmsFadFold_succ]
    by_cases hk' : k < n
    · have hfoldn : cmsFadFold ctx st nKeys sc0 n = .error e := ih hk'
      rw [hfoldn]
      unfold cmsFadStep
      rfl
    · have hk_eq : k = n := by omega
      subst hk_eq
      exact h

/-- **SCR-115 (BASE, all `nSigs` sigs)**: the per-signature FindAndDelete
is a fold over `List.range nSigs` that runs to completion *before*
`cmsLoop` is entered. If the signature at any index `k < nSigs` is found
in the scriptCode accumulated by the first `k` deletions, the whole
CHECKMULTISIG step aborts with `sigFindAndDelete` — no signature check
has run. This generalizes `cms_fad_before_check_row` from the `nSigs = 1`
instance to every signature position and every `nSigs`. -/
@[rule "SCR-115"]
theorem cms_fad_all_sigs_before_check (ctx : Ctx) (st : State) (nkv nsv : ScriptNum)
    (w : Nat) (sc : ByteArray)
    (hsv : ctx.sv = .base)
    (hne0 : st.stack ≠ [])
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : ¬ (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv))
    (hop : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat))
    (hlen2 : ¬ (st.stack.length < nkv.toNat + 2))
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hrange2 : ¬ (nsv < 0 ∨ max (nkv : Int) 0 < nsv))
    (hlen3 : ¬ (st.stack.length < nkv.toNat + nsv.toNat + 3))
    (k : Nat) (hk : k < nsv.toNat)
    (hscript : cmsFadFold ctx st nkv.toNat
        (ctx.bytes.extract st.codeSep ctx.bytes.size) k = .ok sc)
    (hfd : 0 < (findAndDelete sc (pushBytesWire (st.stack[nkv.toNat + k + 2]!))).1)
    (hconst : ctx.pol.constScriptCode = true) :
    stepBody.checkMultiSig ctx w st = .error .sigFindAndDelete := by
  have hfd' : 0 < (findAndDelete sc (pushBytesWire
      (st.stack[nkv.toNat + k + 2]?.getD default))).1 := by
    simpa only [List.getElem!_eq_getElem?_getD] using hfd
  have hstep : cmsFadStep ctx st nkv.toNat
      (cmsFadFold ctx st nkv.toNat
        (ctx.bytes.extract st.codeSep ctx.bytes.size) k) k
      = .error .sigFindAndDelete := by
    unfold cmsFadStep
    rw [hscript]
    simp [hsv, hfd', hconst]
  have hfold := cmsFadFold_error_of_step (ctx := ctx) (st := st) (nKeys := nkv.toNat)
      (sc0 := ctx.bytes.extract st.codeSep ctx.bytes.size) (n := nsv.toNat)
      (k := k) (e := .sigFindAndDelete) hk hstep
  have hnsv0 : ¬ nsv < 0 := fun h => hrange2 (Or.inl h)
  have hnk : ¬ (max (nkv : Int) 0 < nsv) := fun h => hrange2 (Or.inr h)
  simp [stepBody.checkMultiSig, hsv, hne0, hd1, hrange, hop, hlen2, hd2,
    hlen3, hnsv0, hnk]
  have hraw : (List.range nsv.toNat).foldl
      (fun (acc : Except ExecError ByteArray) (k : Nat) =>
        match acc with
        | .error e => .error e
        | .ok sc =>
          if 0 < (findAndDelete sc (pushBytesWire
                (st.stack[nkv.toNat + k + 2]?.getD default))).1 ∧
              ctx.pol.constScriptCode = true then
            .error .sigFindAndDelete
          else .ok (findAndDelete sc (pushBytesWire
                (st.stack[nkv.toNat + k + 2]?.getD default))).2)
      (.ok (ctx.bytes.extract st.codeSep ctx.bytes.size))
      = .error .sigFindAndDelete := by
    unfold cmsFadFold cmsFadStep at hfold
    simpa only [hsv, if_true, List.getElem!_eq_getElem?_getD] using hfold
  split
  · rename_i sc' e heq
    have hcontra : Except.error e = Except.error ExecError.sigFindAndDelete :=
      heq.symm.trans hraw
    cases hcontra
    rfl
  · rename_i sc' scriptCode heq
    have hcontra : Except.error ExecError.sigFindAndDelete = Except.ok scriptCode :=
      hraw.symm.trans heq
    cases hcontra

/-- **SCR-115 (BASE, nSigs = 1)**: a found sig-push match under
CONST_SCRIPTCODE fails with `sigFindAndDelete` before `cmsLoop`. This is
the `nSigs = 1` instance of `cms_fad_all_sigs_before_check`. -/
@[rule "SCR-115"]
theorem cms_fad_before_check_row (ctx : Ctx) (st : State) (nkv : ScriptNum)
    (w : Nat)
    (hsv : ctx.sv = .base)
    (hne0 : st.stack ≠ [])
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : ¬ (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv))
    (hop : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat))
    (hlen2 : ¬ (st.stack.length < nkv.toNat + 2))
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4
      = .ok (1 : ScriptNum))
    (hrange2 : ¬ ((1 : ScriptNum) < 0 ∨ max (nkv : Int) 0 < (1 : ScriptNum)))
    (hlen3 : ¬ (st.stack.length < nkv.toNat + 1 + 3))
    (hfd : 0 < (findAndDelete (ctx.bytes.extract st.codeSep ctx.bytes.size)
      (pushBytesWire (st.stack[nkv.toNat + 2]?.getD default))).1)
    (hconst : ctx.pol.constScriptCode = true) :
    stepBody.checkMultiSig ctx w st = .error .sigFindAndDelete := by
  simp [stepBody.checkMultiSig, hsv, hne0, hd1, hrange, hop, hlen2, hd2,
    hlen3, hfd, hconst, List.range_one]
  have h : ¬ (max (nkv : Int) 0 < 1) := by
    intro hlt
    exact hrange2 (Or.inr hlt)
  exact Int.le_of_not_gt h

/-- **SCR-098 (scan quantum)**: the greedy matcher advances by exactly
one whole needle per increment of the found-count, so the deleted byte
span is `count * b.size` and the count is monotone. -/
theorem findAndDeleteMatches_span (script b : ByteArray) (pc n fuel : Nat) :
    (findAndDeleteMatches script b pc n fuel).1
        = pc + ((findAndDeleteMatches script b pc n fuel).2 - n) * b.size ∧
      n ≤ (findAndDeleteMatches script b pc n fuel).2 := by
  induction fuel generalizing pc n with
  | zero => simp [findAndDeleteMatches]
  | succ f ih =>
    rw [findAndDeleteMatches]
    by_cases h1 : script.size < pc + b.size
    · simp [h1]
    · simp only [h1, ite_false, Nat.succ_ne_zero, ite_false]
      by_cases h2 : (script.extract pc (pc + b.size) == b) = true
      · simp only [h2, ite_true, Nat.succ_sub_one]
        have h := ih (pc + b.size) (n + 1)
        obtain ⟨e1, e2⟩ := h
        constructor
        · rw [e1]
          have hs : (findAndDeleteMatches script b (pc + b.size) (n + 1) f).2 - n
              = ((findAndDeleteMatches script b (pc + b.size) (n + 1) f).2 - (n + 1)) + 1 := by omega
          rw [hs, Nat.succ_mul]
          omega
        · omega
      · simp [h2]

/-- **SCR-098 (core-model divergence)**: when the first greedy scan
consumes the whole script and the recomputed final `pc2` is 0, the
result is `(1, script)` — the match is counted but the tail re-append
puts it back. Core's `FindAndDelete` returns the empty script here. -/
theorem findAndDelete_whole_match_not_removed (script b : ByteArray)
    (hb : b.size ≠ 0)
    (hm : findAndDeleteMatches script b 0 0 (script.size + 1) = (script.size, 1))
    (hfd : fdLastPc2 script b (script.size + 1) 0 0 = 0) :
    findAndDelete script b = (1, script) := by
  rw [findAndDelete]
  simp only [hb, ite_false]
  rw [findAndDeleteAux]
  rw [hm]
  simp [hfd]

end BitcoinProofs.AF.PDW84


/-- info: 'BitcoinProofs.AF.PDW84.cms_fad_all_sigs_before_check' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cms_fad_all_sigs_before_check

/-- info: 'BitcoinProofs.AF.PDW84.cmsFadFold_succ' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cmsFadFold_succ

/-- info: 'BitcoinProofs.AF.PDW84.cmsFadFold_error_of_step' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cmsFadFold_error_of_step

/-- info: 'BitcoinProofs.AF.PDW84.cms_fad_before_check_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cms_fad_before_check_row

/-- info: 'BitcoinProofs.AF.PDW84.findAndDeleteMatches_span' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.findAndDeleteMatches_span

/-- info: 'BitcoinProofs.AF.PDW84.findAndDelete_whole_match_not_removed' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.findAndDelete_whole_match_not_removed
