import Bitcoin.Interpreter.Defs

/-!
# PDW78 — proof promotion TOP-411..415 (hash / numeric dispatch band)

Row faces for `Bitcoin.Interpreter.Defs` (`hashForOp`, `stepBody.dispatchOp`):
SCR-093 (digest widths 20/20/32), SCR-094 (HASH160/HASH256 composition),
SCR-095 (empty preimage hashes), SCR-089 (OP_WITHIN clamp), SCR-087
(unary arithmetic). Zero core writes; proofs are self-contained over the
interpreter floor (no dependency on the stale O07 guard).
-/

namespace BitcoinProofs.AF.PDW78

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Numeric

/-! ## Digest widths (SCR-093/094) -/

theorem foldl_append4_size (g : Nat → ByteArray) (hg : ∀ i, (g i).size = 4) :
    ∀ (l : List Nat) (acc : ByteArray),
      (l.foldl (fun a i => a ++ g i) acc).size = acc.size + 4 * l.length := by
  intro l
  induction l with
  | nil => intro acc; simp
  | cons i l ih =>
      intro acc
      simp only [List.foldl_cons]
      rw [ih, ByteArray.size_append, hg i]
      simp only [List.length_cons]
      omega

theorem wordBEEmit_size (x : UInt32) : (wordBEEmit x).size = 4 := by
  simp [wordBEEmit]

theorem wordLEEmitted_size (x : UInt32) : (wordLEEmitted x).size = 4 := by
  simp [wordLEEmitted]

theorem emitLE_size20 (h : Array UInt32) :
    ((List.range 5).foldl (fun acc i => acc ++ wordLEEmitted h[i]!)
      ByteArray.empty).size = 20 := by
  have hx := foldl_append4_size (fun i => wordLEEmitted h[i]!)
    (fun _ => wordLEEmitted_size _) (List.range 5) ByteArray.empty
  rw [hx]; rfl

theorem emitBE_size20 (h : Array UInt32) :
    ((List.range 5).foldl (fun acc i => acc ++ wordBEEmit h[i]!)
      ByteArray.empty).size = 20 := by
  have hx := foldl_append4_size (fun i => wordBEEmit h[i]!)
    (fun _ => wordBEEmit_size _) (List.range 5) ByteArray.empty
  rw [hx]; rfl

theorem emitBE_size32 (h : Array UInt32) :
    ((List.range 8).foldl (fun acc i => acc ++ wordBEEmit h[i]!)
      ByteArray.empty).size = 32 := by
  have hx := foldl_append4_size (fun i => wordBEEmit h[i]!)
    (fun _ => wordBEEmit_size _) (List.range 8) ByteArray.empty
  rw [hx]; rfl

theorem hashRipemd160_size (d : ByteArray) : (hashRipemd160 d).size = 20 := by
  unfold hashRipemd160; exact emitLE_size20 _

theorem hashSha1_size (d : ByteArray) : (hashSha1 d).size = 20 := by
  unfold hashSha1; exact emitBE_size20 _

theorem hashSha256_size (d : ByteArray) : (hashSha256 d).size = 32 := by
  unfold hashSha256; exact emitBE_size32 _

theorem hashHash160_size (d : ByteArray) : (hashHash160 d).size = 20 := by
  unfold hashHash160; exact hashRipemd160_size _

theorem hashSha256d_size (d : ByteArray) : (hashSha256d d).size = 32 := by
  unfold hashSha256d; exact hashSha256_size _

/-- SCR-093: the exact output-width table of the five digest opcodes. -/
theorem scr093_hashForOp_widths (d : ByteArray) :
    (hashForOp 0xa6 d).size = 20 ∧ (hashForOp 0xa7 d).size = 20 ∧
    (hashForOp 0xa8 d).size = 32 ∧ (hashForOp 0xa9 d).size = 20 ∧
    (hashForOp 0xaa d).size = 32 := by
  refine ⟨?_, ?_, ?_, ?_, ?_⟩ <;> simp [hashForOp]
  · exact hashRipemd160_size d
  · exact hashSha1_size d
  · exact hashSha256_size d
  · exact hashHash160_size d
  · exact hashSha256d_size d

/-- SCR-094: HASH160 = RIPEMD160 ∘ SHA256 and HASH256 = SHA256d. -/
theorem scr094_hash_composition (d : ByteArray) :
    hashForOp 0xa9 d = hashRipemd160 (hashSha256 d) ∧
    hashForOp 0xaa d = hashSha256 (hashSha256 d) := by
  constructor <;> rfl

/-- SCR-094, digest matrix over all five wires. -/
theorem scr094_hashForOp_matrix (d : ByteArray) :
    hashForOp 0xa6 d = hashRipemd160 d ∧ hashForOp 0xa7 d = hashSha1 d ∧
    hashForOp 0xa8 d = hashSha256 d ∧ hashForOp 0xa9 d = hashHash160 d ∧
    hashForOp 0xaa d = hashSha256d d := by
  refine ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- SCR-095: a singleton EMPTY stack element is hashed (no empty-preimage
reject), and nothing but the top element changes. -/
theorem scr095_emptyElement_hashed (ctx : Ctx) (op : WireOp) (w : Nat)
    (st : State) (hr : 0xa6 ≤ w ∧ w ≤ 0xaa) :
    stepBody.dispatchOp ctx op w true { st with stack := [ByteArray.empty] } =
      .ok { st with stack := [hashForOp w ByteArray.empty] } := by
  have h5 : w = 0xa6 ∨ w = 0xa7 ∨ w = 0xa8 ∨ w = 0xa9 ∨ w = 0xaa := by omega
  rcases h5 with rfl | rfl | rfl | rfl | rfl <;> simp [stepBody.dispatchOp, topAt]

/-! ## Numeric dispatch (SCR-089 / SCR-087) -/

/-- SCR-089: OP_WITHIN pops max/min/x (in that stack order) and pushes
`min ≤ x < max`; it is `pushBoolV` of exactly that predicate. -/
theorem scr089_within_semantics (ctx : Ctx) (op : WireOp) (st : State)
    (h3 : ¬ st.stack.length < 3) (bn1 bn2 bn3 : ScriptNum)
    (hd1 : decodeNum ctx.pol (topAt st.stack 3) 4 = .ok bn1)
    (hd2 : decodeNum ctx.pol (topAt st.stack 2) 4 = .ok bn2)
    (hd3 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok bn3) :
    stepBody.dispatchOp ctx op 0xa5 (st.vf.all id) st =
      .ok { st with stack := pushBoolV (bn2 ≤ bn1 ∧ bn1 < bn3) :: st.stack.drop 3 } := by
  simp [stepBody.dispatchOp, h3, hd1, hd2, hd3]

/-- SCR-087: the six unary arithmetic opcodes replace the decoded top by
`encodeScriptNum (unOp w bn)` and consume exactly one element. -/
theorem scr087_unary_dispatch (ctx : Ctx) (op : WireOp) (st : State) (w : Nat)
    (hw : w = 0x8b ∨ w = 0x8c ∨ w = 0x8f ∨ w = 0x90 ∨ w = 0x91 ∨ w = 0x92)
    (hne : st.stack ≠ []) (bn : ScriptNum)
    (hd : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok bn) :
    stepBody.dispatchOp ctx op w (st.vf.all id) st =
      .ok { st with stack := encodeScriptNum (unOp w bn) false :: st.stack.tail } := by
  have h1 : ¬ st.stack.length < 1 := by
    cases hs : st.stack with
    | nil => rw [hs] at hne; exact (hne rfl).elim
    | cons _ _ => simp
  rcases hw with rfl | rfl | rfl | rfl | rfl | rfl <;>
    simp [stepBody.dispatchOp, h1, hd]

/-! ## Terminal stack guard and push-size gate (TPR-067 / TPR-068) -/

/-- TPR-067: the legacy STACK_SIZE guard is retained and re-checked after
EVERY opcode — any successful `stepChecked` output is within the combined
stack + altstack cap. -/
theorem tpr067_stepChecked_cap (ctx : Ctx) (op : WireOp) (st st' : State)
    (h : stepChecked ctx op st = .ok st') :
    st'.stack.length + st'.alt.length ≤ MAX_STACK_SIZE :=
  stepChecked_ok_bound h

/-- TPR-067, rejecting face: when the opcode succeeds but the fused
stack+altstack exceeds MAX_STACK_SIZE, `stepChecked` maps it to
`SCRIPT_ERR_STACK_SIZE` (the guard sits outside `stepBody`). -/
theorem tpr067_stepChecked_reject (ctx : Ctx) (op : WireOp) (st st' : State)
    (hb : stepBody ctx op st = .ok st')
    (hover : MAX_STACK_SIZE < st'.stack.length + st'.alt.length) :
    stepChecked ctx op st = .error .stackSize := by
  unfold stepChecked
  rw [hb]
  simp [hover]

/-- TPR-068: an oversized push (`> MAX_SCRIPT_ELEMENT_SIZE = 520`) is
rejected with `SCRIPT_ERR_PUSH_SIZE` before any execution gate. -/
theorem tpr068_pushSize_gate (ctx : Ctx) (op : WireOp) (st : State)
    (d : ByteArray) (hast : op.ast = .pushBytes d)
    (hover : MAX_SCRIPT_ELEMENT_SIZE < d.size) :
    stepBody ctx op st = .error .pushSize := by
  have h520 : MAX_SCRIPT_ELEMENT_SIZE = 520 := rfl
  have hs : decide (d.size ≤ MAX_SCRIPT_ELEMENT_SIZE) = false := by
    simp [h520]; omega
  simp [stepBody, hast, hs]

/-- TPR-068, positive face: every push that survives a step is ≤ 520 bytes. -/
theorem tpr068_ok_push_bound (ctx : Ctx) (op : WireOp) (st st' : State)
    (d : ByteArray) (hast : op.ast = .pushBytes d)
    (h : stepBody ctx op st = .ok st') :
    d.size ≤ MAX_SCRIPT_ELEMENT_SIZE := by
  by_cases hle : d.size ≤ MAX_SCRIPT_ELEMENT_SIZE
  · exact hle
  · exfalso
    have hgt : MAX_SCRIPT_ELEMENT_SIZE < d.size := by omega
    rw [tpr068_pushSize_gate ctx op st d hast hgt] at h
    simp at h

end BitcoinProofs.AF.PDW78
