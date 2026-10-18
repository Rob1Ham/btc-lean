import Bitcoin.Interpreter.Defs

/-!
# BitcoinProofs.Theorems.Ops.O07 — per-opcode semantics: the crypto group

O07. Sorry-free per-opcode semantics theorems over
interpreter tier (`Bitcoin.Interpreter.Defs`, `stepBody.dispatchOp`)
for the crypto group:

* OP_RIPEMD160 0xa6, OP_SHA1 0xa7, OP_SHA256 0xa8,
  OP_HASH160 0xa9, OP_HASH256 0xaa  — the five digest opcodes
* OP_CODESEPARATOR 0xab            — the cs-recording opcode

Ground truth: interpreter.cpp @ cce32b168, `EvalScript` switch cases
:1032-1056 (hash block: `stack.size() < 1` → SCRIPT_ERR_INVALID_STACK_OPERATION
at :1037-1038; pop-then-push at :1054-1055), :1058-1067 (OP_CODESEPARATOR:
`pbegincodehash = pc`, `execdata.m_codeseparator_pos = opcode_pos`, no
stack effect, never fails), :484-486 (CONST_SCRIPTCODE + BASE rejects
0xab even in unexecuted branches), :459-464 (opcode budget burns for
0xa6-0xab under BASE/WITNESS_V0 — all exceed OP_16), :493 (the
dead-branch window `[OP_IF..OP_ENDIF]` excludes 0xa6-0xab, so dead hash
ops and dead CODESEPARATORs are skipped, not recorded/executed). Digests:
CRIPEMD160/CSHA1/CSHA256/CHash160/CHash256 (hash.h), transcribed in
`Bitcoin.Interpreter.Hashes`.
SCR rows: research/06-script-interpreter.md :210-215 (opcode table),
SCR-093 :584 (output sizes 20/20/32), SCR-094 :585 (HASH160 =
RIPEMD160∘SHA256, HASH256 = SHA256d), SCR-095 :586 (empty element hashes
fine), SCR-167 (CODESEPARATOR records `op.next`).

Concrete verdicts are cross-checked by a python script
(python3 `hashlib` transcription of the C++ cases) against `#eval` of
the Lean hash floor (probe `probe1.out`): RIPEMD160("abc") =
8eb208f7e05d987a9b044a8e98c6b087f15a0bfc, SHA1("abc") =
a9993e364706816aba3e25717850c26c9cd0d89d, SHA256("abc") =
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad,
HASH160("abc") = bb1be98c142444d7a56aa3981c3942a978e4dc33,
HASH256("abc") =
4f8b42c22dd3729b519ba6f68d2da7cc5b2d606d05daed5ad5128cc03e6c6358 —
byte-identical on both sides (VERIFIED).

VERIFIED vs PROPOSED: everything here is VERIFIED against the pinned
C++ (anchors above) and the python3 mirror; no PROPOSED rows. No
divergence from Core found in this group (no F-O07-* rows).
-/

namespace BitcoinProofs.Theorems.Ops.O07

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Activation

/-! ## Fixtures -/

/-- A context with caller-chosen sig version and policy flags; the
checker is the stub (this opcode group never reaches the checker). -/
def octx (sv : Bitcoin.Crypto.Seam.SigVersion) (pol : PolicyFlags) : Ctx :=
  ⟨{ p2sh := false, dersig := false, cltv := false, csv := false,
     nullDummy := false, witness := false, taproot := false }, pol,
   default, sv, ByteArray.empty, default⟩

/-- Wire-op witness (AST `.op`, `next := 1`): at the dispatch level the
AST/next fields are inert for the hash block; the OP_CODESEPARATOR
theorems carry their own `op`. -/
def opw (n : Nat) : WireOp := ⟨.op ⟨n % 256, by omega⟩, n, 1⟩

/-- The empty machine state. -/
def st0 : State := ⟨[], [], [], 0, 0, none⟩

/-- `"abc"` as a stack element (the cross-check input). -/
def abc : ByteArray := "abc".toUTF8

/-- Nonempty stacks have positive length (feeds the underflow guards). -/
theorem len_pos {l : List ByteArray} (h : l ≠ []) : 0 < l.length := by
  cases l with
  | nil => exact absurd rfl h
  | cons _ _ => simp

/-- A singleton stack's top is its only element. -/
@[simp] theorem topAt_singleton (a : ByteArray) : topAt [a] 1 = a := by
  simp [topAt]

/-- The six crypto wires are exactly 0xa6..0xab (drives case splits). -/
theorem cryptoRange_cases (w : Nat) (hr : 0xa6 ≤ w ∧ w ≤ 0xab) :
    w = 0xa6 ∨ w = 0xa7 ∨ w = 0xa8 ∨ w = 0xa9 ∨ w = 0xaa ∨ w = 0xab := by omega

/-- The hash block and CODESEPARATOR are never disabled (CVE-2010-5137's
15 disabled bytes are all ≤ 0x99; `disabledWire` decides). -/
theorem disabledWire_hashblock (w : Nat) (hr : 0xa6 ≤ w ∧ w ≤ 0xab) :
    disabledWire w = false := by
  rcases cryptoRange_cases w hr with h | h | h | h | h | h <;>
    rw [h] <;> decide

/-! ## 1. The hash block at dispatch level (0xa6-0xaa) — :1032-1056 -/

/-- Exact failure precondition (interpreter.cpp:1037-1038): the dispatch
of a hash opcode raises INVALID_STACK_OPERATION **iff** the stack is
empty — no other error is reachable inside the hash block. -/
theorem opHash_underflow_iff (ctx : Ctx) (op : WireOp) (w : Nat) (fExec : Bool)
    (st : State) (hr : 0xa6 ≤ w ∧ w ≤ 0xaa) :
    stepBody.dispatchOp ctx op w fExec st = .error .stackUnderflow
      ↔ st.stack = [] := by
  have h5 : w = 0xa6 ∨ w = 0xa7 ∨ w = 0xa8 ∨ w = 0xa9 ∨ w = 0xaa := by omega
  rcases h5 with rfl|rfl|rfl|rfl|rfl <;>
    simp [stepBody.dispatchOp]

/-- Stack effect (interpreter.cpp:1041-1055, `(in -- hash)`): with a
nonempty stack the transition replaces the top element by its digest —
altstack, condition stack, budget and codeSep are untouched. -/
theorem opHash_effect (ctx : Ctx) (op : WireOp) (w : Nat) (fExec : Bool)
    (st : State) (hr : 0xa6 ≤ w ∧ w ≤ 0xaa) (hne : st.stack ≠ []) :
    stepBody.dispatchOp ctx op w fExec st =
      .ok { st with stack := hashForOp w (topAt st.stack 1) :: st.stack.tail } := by
  have h5 : w = 0xa6 ∨ w = 0xa7 ∨ w = 0xa8 ∨ w = 0xa9 ∨ w = 0xaa := by omega
  rcases h5 with rfl|rfl|rfl|rfl|rfl <;>
    simp [stepBody.dispatchOp, hne]

/-- SCR-093/094 digest matrix: each wire computes exactly its hash.h
counterpart (`CHash160` = RIPEMD160∘SHA256, `CHash256` = SHA256d). -/
theorem opHash_digest_matrix (d : ByteArray) :
    hashForOp 0xa6 d = hashRipemd160 d ∧
    hashForOp 0xa7 d = hashSha1 d ∧
    hashForOp 0xa8 d = hashSha256 d ∧
    hashForOp 0xa9 d = hashHash160 d ∧
    hashForOp 0xaa d = hashSha256d d := by
  refine ⟨rfl, rfl, rfl, rfl, rfl⟩

/-! ## 2. Digest widths — SCR-093/SCR-094 -/

/-- A fold of 4-byte word emissions has size `acc.size + 4·l.length`. -/
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

/-- Five 4-byte little-endian word emissions ⇒ 20 bytes. -/
theorem emitLE_size20 (h : Array UInt32) :
    ((List.range 5).foldl (fun acc i => acc ++ wordLEEmitted h[i]!)
      ByteArray.empty).size = 20 := by
  have hx := foldl_append4_size (fun i => wordLEEmitted h[i]!)
    (fun _ => wordLEEmitted_size _) (List.range 5) ByteArray.empty
  rw [hx]
  rfl

/-- Five 4-byte big-endian word emissions ⇒ 20 bytes. -/
theorem emitBE_size20 (h : Array UInt32) :
    ((List.range 5).foldl (fun acc i => acc ++ wordBEEmit h[i]!)
      ByteArray.empty).size = 20 := by
  have hx := foldl_append4_size (fun i => wordBEEmit h[i]!)
    (fun _ => wordBEEmit_size _) (List.range 5) ByteArray.empty
  rw [hx]
  rfl

/-- Eight 4-byte big-endian word emissions ⇒ 32 bytes. -/
theorem emitBE_size32 (h : Array UInt32) :
    ((List.range 8).foldl (fun acc i => acc ++ wordBEEmit h[i]!)
      ByteArray.empty).size = 32 := by
  have hx := foldl_append4_size (fun i => wordBEEmit h[i]!)
    (fun _ => wordBEEmit_size _) (List.range 8) ByteArray.empty
  rw [hx]
  rfl

/-- SCR-093 (interpreter.cpp:1042,1049-1051): RIPEMD-160 emits 20 bytes
for EVERY input. -/
theorem hashRipemd160_size (d : ByteArray) : (hashRipemd160 d).size = 20 := by
  unfold hashRipemd160
  exact emitLE_size20 _

/-- SCR-093: SHA-1 emits 20 bytes for every input. -/
theorem hashSha1_size (d : ByteArray) : (hashSha1 d).size = 20 := by
  unfold hashSha1
  exact emitBE_size20 _

/-- SCR-093: SHA-256 emits 32 bytes for every input. -/
theorem hashSha256_size (d : ByteArray) : (hashSha256 d).size = 32 := by
  unfold hashSha256
  exact emitBE_size32 _

/-- SCR-094 (interpreter.cpp:1050, `CHash160`): HASH160 emits 20 bytes. -/
theorem hashHash160_size (d : ByteArray) : (hashHash160 d).size = 20 := by
  unfold hashHash160
  exact hashRipemd160_size _

/-- SCR-094 (interpreter.cpp:1052, `CHash256`): HASH256 emits 32 bytes. -/
theorem hashSha256d_size (d : ByteArray) : (hashSha256d d).size = 32 := by
  unfold hashSha256d
  exact hashSha256_size _

/-- SCR-095 (interpreter.cpp:1038-1054): the hash block consumes ONE
stack element of ANY size — 0 included: the empty element hashes fine
(no failure edge at size 0; minimal-data policy is orthogonal). -/
theorem opHash_emptyElement (ctx : Ctx) (op : WireOp) (w : Nat)
    (st : State) (hr : 0xa6 ≤ w ∧ w ≤ 0xaa) :
    stepBody.dispatchOp ctx op w true
        { st with stack := [ByteArray.empty] } =
      .ok { st with stack := [hashForOp w ByteArray.empty] } := by
  have h5 : w = 0xa6 ∨ w = 0xa7 ∨ w = 0xa8 ∨ w = 0xa9 ∨ w = 0xaa := by omega
  rcases h5 with rfl|rfl|rfl|rfl|rfl <;>
    simp [stepBody.dispatchOp, topAt]

/-! ## 3. Full stepBody transitions under BASE — :459-464 + :1032-1056 -/

/-- Executed OP_RIPEMD160 under BASE: the step burns one 201-opcode
budget unit (0xa6 > OP_16, interpreter.cpp:459-464) and replaces the top
stack element by its RIPEMD-160 digest. -/
theorem step_ripemd160_base (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xa6) (hast : op.ast = .op ⟨0xa6, by decide⟩)
    (hsv : ctx.sv = .base) (hvf : st.vf.all id = true)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) (hne : st.stack ≠ []) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1,
                    stack := hashRipemd160 (topAt st.stack 1) :: st.stack.tail } := by
  have hd := disabledWire_hashblock 0xa6 (by omega)
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
    simp only [h201] at hbud ⊢; omega
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp [stepBody, stepBody.dispatchOp, hw, hast, hsv, hvf, hd, hb, hlen, hashForOp]

/-- Executed OP_SHA1 under BASE (interpreter.cpp:1045). -/
theorem step_sha1_base (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xa7) (hast : op.ast = .op ⟨0xa7, by decide⟩)
    (hsv : ctx.sv = .base) (hvf : st.vf.all id = true)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) (hne : st.stack ≠ []) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1,
                    stack := hashSha1 (topAt st.stack 1) :: st.stack.tail } := by
  have hd := disabledWire_hashblock 0xa7 (by omega)
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
    simp only [h201] at hbud ⊢; omega
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp [stepBody, stepBody.dispatchOp, hw, hast, hsv, hvf, hd, hb, hlen, hashForOp]

/-- Executed OP_SHA256 under BASE (interpreter.cpp:1046). -/
theorem step_sha256_base (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xa8) (hast : op.ast = .op ⟨0xa8, by decide⟩)
    (hsv : ctx.sv = .base) (hvf : st.vf.all id = true)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) (hne : st.stack ≠ []) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1,
                    stack := hashSha256 (topAt st.stack 1) :: st.stack.tail } := by
  have hd := disabledWire_hashblock 0xa8 (by omega)
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
    simp only [h201] at hbud ⊢; omega
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp [stepBody, stepBody.dispatchOp, hw, hast, hsv, hvf, hd, hb, hlen, hashForOp]

/-- Executed OP_HASH160 under BASE (interpreter.cpp:1049-1050):
RIPEMD160 ∘ SHA256, one budget unit. -/
theorem step_hash160_base (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xa9) (hast : op.ast = .op ⟨0xa9, by decide⟩)
    (hsv : ctx.sv = .base) (hvf : st.vf.all id = true)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) (hne : st.stack ≠ []) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1,
                    stack := hashRipemd160 (hashSha256 (topAt st.stack 1))
                               :: st.stack.tail } := by
  have hd := disabledWire_hashblock 0xa9 (by omega)
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
    simp only [h201] at hbud ⊢; omega
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp [stepBody, stepBody.dispatchOp, hw, hast, hsv, hvf, hd, hb, hlen,
    hashForOp, hashHash160]

/-- Executed OP_HASH256 under BASE (interpreter.cpp:1051-1052):
SHA256d, one budget unit. -/
theorem step_hash256_base (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xaa) (hast : op.ast = .op ⟨0xaa, by decide⟩)
    (hsv : ctx.sv = .base) (hvf : st.vf.all id = true)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) (hne : st.stack ≠ []) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1,
                    stack := hashSha256 (hashSha256 (topAt st.stack 1))
                               :: st.stack.tail } := by
  have hd := disabledWire_hashblock 0xaa (by omega)
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
    simp only [h201] at hbud ⊢; omega
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp [stepBody, stepBody.dispatchOp, hw, hast, hsv, hvf, hd, hb, hlen,
    hashForOp, hashSha256d]

/-- Executed hash op under TAPSCRIPT (BIP342): 0xa6-0xaa are ordinary
opcodes there and do NOT burn the 201-opcode budget (`counts` requires
BASE/WITNESS_V0, interpreter.cpp:460-461 `sigversion` guard) — the
result state's `opCount` is the input's. -/
theorem step_sha256_tapscript_noBudget (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xa8) (hast : op.ast = .op ⟨0xa8, by decide⟩)
    (hsv : ctx.sv = .tapscript) (hvf : st.vf.all id = true)
    (hne : st.stack ≠ []) :
    stepBody ctx op st =
      .ok { st with stack := hashSha256 (topAt st.stack 1) :: st.stack.tail } := by
  have hd := disabledWire_hashblock 0xa8 (by omega)
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp [stepBody, stepBody.dispatchOp, hw, hast, hsv, hvf, hd, hlen, hashForOp]

/-- Executed hash op with an empty stack under BASE →
INVALID_STACK_OPERATION (interpreter.cpp:1037-1038); the budget unit is
already burned by :459-464 but the error preempts the state. -/
theorem step_hash_underflow_base (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xa6) (hast : op.ast = .op ⟨0xa6, by decide⟩)
    (hsv : ctx.sv = .base) (hvf : st.vf.all id = true)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) (hnil : st.stack = []) :
    stepBody ctx op st = .error .stackUnderflow := by
  have hd := disabledWire_hashblock 0xa6 (by omega)
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
    simp only [h201] at hbud ⊢; omega
  simp [stepBody, stepBody.dispatchOp, hw, hast, hsv, hvf, hd, hb, hnil]

/-- Dark corner (SCR-022): a hash op in an UNEXECUTED branch is skipped
(:493 — 0xa8 is outside `[OP_IF..OP_ENDIF]`) yet still burns one budget
unit under BASE (:459-464 counts unexecuted opcodes too); the stack is
untouched. -/
theorem step_hash_unexecuted_budgetBurns (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xa8) (hast : op.ast = .op ⟨0xa8, by decide⟩)
    (hsv : ctx.sv = .base) (hvf : ∃ rest, st.vf = false :: rest)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st = .ok { st with opCount := st.opCount + 1 } := by
  obtain ⟨rest, hvf⟩ := hvf
  have hf : st.vf.all id = false := by simp [hvf]
  have hd := disabledWire_hashblock 0xa8 (by omega)
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
    simp only [h201] at hbud ⊢; omega
  simp [stepBody, hw, hast, hsv, hf, hd, hb]

/-! ## 4. OP_CODESEPARATOR 0xab — :1058-1067 -/

/-- Dispatch level (interpreter.cpp:1058-1067): OP_CODESEPARATOR is a
TOTAL transition — any stack, any fExec — that only records
`pbegincodehash = pc`, i.e. `codeSep := op.next` (the byte offset
just past the opcode). -/
theorem opCodeSep_dispatch (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State) :
    stepBody.dispatchOp ctx op 0xab fExec st = .ok { st with codeSep := op.next } := by
  simp [stepBody.dispatchOp]

/-- SCR-167, executed under BASE: budget +1 (0xab > OP_16) and
`codeSep := op.next`; stack, altstack and condition stack untouched.
(CONST_SCRIPTCODE must be off — see `step_codesep_const_dead`.) -/
theorem step_codesep_base (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xab) (hast : op.ast = .op ⟨0xab, by decide⟩)
    (hsv : ctx.sv = .base) (hnc : ctx.pol.constScriptCode = false)
    (hvf : st.vf.all id = true)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1, codeSep := op.next } := by
  have hd := disabledWire_hashblock 0xab (by omega)
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
    simp only [h201] at hbud ⊢; omega
  simp [stepBody, stepBody.dispatchOp, hw, hast, hsv, hvf, hd, hb, hnc]

/-- Dark corner (interpreter.cpp:484-486): under CONST_SCRIPTCODE in
BASE script, OP_CODESEPARATOR is rejected EVEN IN AN UNEXECUTED BRANCH
— the gate sits above the fExec check. Budget headroom assumed (the
opCount check at :459-464 fires first otherwise). -/
theorem step_codesep_const_dead (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xab) (hast : op.ast = .op ⟨0xab, by decide⟩)
    (hsv : ctx.sv = .base) (hc : ctx.pol.constScriptCode = true)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st = .error .opCodeSeparator := by
  have hd := disabledWire_hashblock 0xab (by omega)
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
    simp only [h201] at hbud ⊢; omega
  simp [stepBody, hw, hast, hsv, hd, hb, hc]

/-- Dead OP_CODESEPARATOR without CONST_SCRIPTCODE: skipped (:493 —
0xab is outside the conditional window), yet the budget still burns
under BASE, and — crucially — `codeSep` is NOT updated (the recording
at :1064 only happens for executed separators). -/
theorem step_codesep_unexecuted (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xab) (hast : op.ast = .op ⟨0xab, by decide⟩)
    (hsv : ctx.sv = .base) (hnc : ctx.pol.constScriptCode = false)
    (hvf : ∃ rest, st.vf = false :: rest)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st = .ok { st with opCount := st.opCount + 1 } := by
  obtain ⟨rest, hvf⟩ := hvf
  have hf : st.vf.all id = false := by simp [hvf]
  have hd := disabledWire_hashblock 0xab (by omega)
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
    simp only [h201] at hbud ⊢; omega
  simp [stepBody, hw, hast, hsv, hf, hd, hb, hnc]

/-- OP_CODESEPARATOR under TAPSCRIPT (BIP342): recorded on execution,
no budget burn, and the CONST_SCRIPTCODE gate cannot fire (BASE-only). -/
theorem step_codesep_tapscript (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xab) (hast : op.ast = .op ⟨0xab, by decide⟩)
    (hsv : ctx.sv = .tapscript) (hvf : st.vf.all id = true) :
    stepBody ctx op st = .ok { st with codeSep := op.next } := by
  have hd := disabledWire_hashblock 0xab (by omega)
  simp [stepBody, stepBody.dispatchOp, hw, hast, hsv, hvf, hd]

/-! ## 5. Concrete verdicts (python3-cross-checked, xcheck.py) -/

-- RIPEMD160("abc") executed under BASE:
--   stack := [8eb208f7e05d987a9b044a8e98c6b087f15a0bfc], opCount := 1
example : stepBody (octx .base {}) (opw 0xa6) { st0 with stack := [abc] } =
    .ok { st0 with opCount := 1,
                   stack := [hashRipemd160 abc] } := by
  have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
  have hd : disabledWire 0xa6 = false := disabledWire_hashblock 0xa6 (by omega)
  simp [stepBody, stepBody.dispatchOp, opw, st0, octx, topAt, hashForOp, abc, h201, hd]

-- SHA1("abc"): stack := [a9993e36…] (xcheck.py: hashlib.sha1)
example : stepBody (octx .base {}) (opw 0xa7) { st0 with stack := [abc] } =
    .ok { st0 with opCount := 1,
                   stack := [hashSha1 abc] } := by
  have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
  have hd : disabledWire 0xa7 = false := disabledWire_hashblock 0xa7 (by omega)
  simp [stepBody, stepBody.dispatchOp, opw, st0, octx, topAt, hashForOp, abc, h201, hd]

-- SHA256("abc"): stack := [ba7816bf…] (hashlib.sha256)
example : stepBody (octx .base {}) (opw 0xa8) { st0 with stack := [abc] } =
    .ok { st0 with opCount := 1,
                   stack := [hashSha256 abc] } := by
  have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
  have hd : disabledWire 0xa8 = false := disabledWire_hashblock 0xa8 (by omega)
  simp [stepBody, stepBody.dispatchOp, opw, st0, octx, topAt, hashForOp, abc, h201, hd]

-- HASH160("abc"): stack := [bb1be98c…] (ripemd160(sha256))
example : stepBody (octx .base {}) (opw 0xa9) { st0 with stack := [abc] } =
    .ok { st0 with opCount := 1,
                   stack := [hashHash160 abc] } := by
  have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
  have hd : disabledWire 0xa9 = false := disabledWire_hashblock 0xa9 (by omega)
  simp [stepBody, stepBody.dispatchOp, opw, st0, octx, topAt, hashForOp, abc, h201, hd]

-- HASH256("abc"): stack := [4f8b42c2…] (sha256d)
example : stepBody (octx .base {}) (opw 0xaa) { st0 with stack := [abc] } =
    .ok { st0 with opCount := 1,
                   stack := [hashSha256d abc] } := by
  have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
  have hd : disabledWire 0xaa = false := disabledWire_hashblock 0xaa (by omega)
  simp [stepBody, stepBody.dispatchOp, opw, st0, octx, topAt, hashForOp, abc, h201, hd]

-- SCR-095 edge: the EMPTY element hashes fine (SHA-256 of ∅ =
-- e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855).
example : stepBody.dispatchOp (octx .base {}) (opw 0xa8) 0xa8 true
    { st0 with stack := [ByteArray.empty] } =
    .ok { st0 with stack := [hashSha256 ByteArray.empty] } := by
  simp [stepBody.dispatchOp, opw, st0, octx, topAt, hashForOp]

-- Empty stack → INVALID_STACK_OPERATION (interpreter.cpp:1037-1038).
example : stepBody.dispatchOp (octx .base {}) (opw 0xa9) 0xa9 true st0 =
    .error .stackUnderflow := by
  simp [stepBody.dispatchOp, opw, st0, octx]

-- OP_CODESEPARATOR verdict: third opcode in `<1> OP_CODESEPARATOR <1>`
-- has `pc = 3` (1-byte push + 1-byte codesep), so codeSep := 3.
example : stepBody (octx .base {})
    ⟨.op ⟨0xab, by decide⟩, 0xab, 3⟩ { st0 with stack := [vchFalse, vchTrue] } =
    .ok { st0 with opCount := 1, codeSep := 3,
                   stack := [vchFalse, vchTrue] } := by
  have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
  simp [stepBody, stepBody.dispatchOp, st0, octx, disabledWire, topAt, h201]

-- CONST_SCRIPTCODE kills even a DEAD separator (interpreter.cpp:484-486).
example : stepBody (octx .base { constScriptCode := true })
    ⟨.op ⟨0xab, by decide⟩, 0xab, 3⟩ { st0 with vf := [false] } =
    .error .opCodeSeparator := by
  have h201 : MAX_OPS_PER_SCRIPT = 201 := rfl
  simp [stepBody, stepBody.dispatchOp, st0, octx, disabledWire, h201]


/-! ## 6. Axiom pins (exact footprints; no sorryAx, no native_decide) -/

/-- info: 'BitcoinProofs.Theorems.Ops.O07.opHash_underflow_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms opHash_underflow_iff

/-- info: 'BitcoinProofs.Theorems.Ops.O07.opHash_effect' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms opHash_effect

/-- info: 'BitcoinProofs.Theorems.Ops.O07.opHash_digest_matrix' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms opHash_digest_matrix

/-- info: 'BitcoinProofs.Theorems.Ops.O07.opHash_emptyElement' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms opHash_emptyElement

/-- info: 'BitcoinProofs.Theorems.Ops.O07.hashRipemd160_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms hashRipemd160_size

/-- info: 'BitcoinProofs.Theorems.Ops.O07.hashSha1_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms hashSha1_size

/-- info: 'BitcoinProofs.Theorems.Ops.O07.hashSha256_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms hashSha256_size

/-- info: 'BitcoinProofs.Theorems.Ops.O07.hashHash160_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms hashHash160_size

/-- info: 'BitcoinProofs.Theorems.Ops.O07.hashSha256d_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms hashSha256d_size

/-- info: 'BitcoinProofs.Theorems.Ops.O07.step_ripemd160_base' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms step_ripemd160_base

/-- info: 'BitcoinProofs.Theorems.Ops.O07.step_sha1_base' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms step_sha1_base

/-- info: 'BitcoinProofs.Theorems.Ops.O07.step_sha256_base' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms step_sha256_base

/-- info: 'BitcoinProofs.Theorems.Ops.O07.step_hash160_base' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms step_hash160_base

/-- info: 'BitcoinProofs.Theorems.Ops.O07.step_hash256_base' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms step_hash256_base

/-- info: 'BitcoinProofs.Theorems.Ops.O07.step_sha256_tapscript_noBudget' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms step_sha256_tapscript_noBudget

/-- info: 'BitcoinProofs.Theorems.Ops.O07.step_hash_underflow_base' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms step_hash_underflow_base

/-- info: 'BitcoinProofs.Theorems.Ops.O07.step_hash_unexecuted_budgetBurns' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms step_hash_unexecuted_budgetBurns

/-- info: 'BitcoinProofs.Theorems.Ops.O07.opCodeSep_dispatch' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms opCodeSep_dispatch

/-- info: 'BitcoinProofs.Theorems.Ops.O07.step_codesep_base' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms step_codesep_base

/-- info: 'BitcoinProofs.Theorems.Ops.O07.step_codesep_const_dead' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms step_codesep_const_dead

/-- info: 'BitcoinProofs.Theorems.Ops.O07.step_codesep_unexecuted' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms step_codesep_unexecuted

/-- info: 'BitcoinProofs.Theorems.Ops.O07.step_codesep_tapscript' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms step_codesep_tapscript

end BitcoinProofs.Theorems.Ops.O07
