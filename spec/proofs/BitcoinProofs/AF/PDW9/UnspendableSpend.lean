import Bitcoin.Interpreter.Defs
import Bitcoin.Script.Parser.Defs
import Bitcoin.Ledger.Interface
import BitcoinProofs.AF.PDW98.PDW98
import BitcoinProofs.Wallet.Miniscript.Interp

/-!
# AF/PDW9/UnspendableSpend — SCR-070 executed-path faces

SCR-070 (residual): an OP_RETURN-prefixed scriptPubKey and a scriptPubKey
larger than `MAX_SCRIPT_SIZE` (10,000) are unspendable, while a
10,000-byte non-OP_RETURN script is spendable.  The classification
faces (`scriptUnspendable`) live in `BitcoinProofs.PDW9.Unspendable`;
this module closes the execution-side residual on the consensus entry
`Bitcoin.Interpreter.verifyScriptFull`.

Main results:

* `verifyScriptFull_opReturn` — the OP_RETURN face: with an empty
  scriptSig the scriptPubKey evaluation fails with `SCRIPT_ERR_OP_RETURN`
  (interpreter.cpp:677-681), hence the whole verification fails.
* `verifyScriptFull_oversize` — the size face: a scriptPubKey of 10,001
  bytes fails with `SCRIPT_ERR_SCRIPT_SIZE` at the pre-parse cap
  (interpreter.cpp:419-421).
* `verifyScriptFull_scriptList_spendable` — the positive control: the
  10,000-byte script

  `OP_0 OP_IF (9996 × OP_0) OP_ENDIF OP_1`

  has size exactly `MAX_SCRIPT_SIZE` (so it is not size-rejected), starts
  with `0x00` (not OP_RETURN), and evaluates to a true stack under an
  empty scriptSig and empty witness.  The 9,996 OP_0 pushes sit in the
  untaken branch and are skipped by the interpreter.

The positive script begins with OP_0, so
`scriptUnspendable_scriptList_10000` also records that the size/OP_RETURN
classifier returns `false` for it: spendability of the boundary case is
not vacuous.

Fuel is pinned at 10,001 = (number of wire ops) + 1, the exact bound the
`evalFrom` loop needs for this witness.
-/

namespace BitcoinProofs.AF.PDW9

open Bitcoin.Interpreter Bitcoin.Script.Parser Bitcoin.Numeric
open Bitcoin.Activation Bitcoin.Crypto.Seam
open Bitcoin.Data (WitnessStack)

set_option autoImplicit false

def push0Code : Opcode := .pushBytes ByteArray.empty
def ifCode : Opcode := .op ⟨0x63, by decide⟩
def endifCode : Opcode := .op ⟨0x68, by decide⟩
def oneCode : Opcode := .pushNum 1

def init0 : State := { stack := [], alt := [], vf := [], opCount := 0, codeSep := 0, vwLeft := none }
def st1s : State := { init0 with stack := [ByteArray.empty] }
def st2s : State := { st1s with stack := [], vf := [false], opCount := 1 }
def st1 : State := { st1s with opcodeIndex := 1 }
def st2 : State := { st2s with opcodeIndex := 2 }

theorem stepChecked_push0_init (ctx : Ctx) (nx : Nat) :
    stepChecked ctx { ast := push0Code, wire := 0, next := nx } init0 = .ok st1s := by
  unfold stepChecked
  simp [stepBody, push0Code, init0, st1s, checkMinimalPush, disabledWire,
    MAX_STACK_SIZE, MAX_OPS_PER_SCRIPT]


theorem evalFrom_push0_init_cons (ctx : Ctx) (nx : Nat) (rest : List WireOp) (f : Nat) :
    evalFrom ctx (f + 1) ({ ast := push0Code, wire := 0, next := nx } :: rest) init0 =
      evalFrom ctx f rest st1 := by
  simp only [evalFrom]
  rw [stepChecked_push0_init ctx nx]
  rfl

theorem stepChecked_if_anyidx (ctx : Ctx) (nx : Nat) (i : UInt32) (hsv : ctx.sv = .base) :
    stepChecked ctx { ast := ifCode, wire := 0x63, next := nx } { st1s with opcodeIndex := i } =
      .ok { st2s with opcodeIndex := i } := by
  unfold stepChecked
  simp [stepBody, stepBody.dispatchOp, ifCode, st1s, st2s, init0, hsv, castToBool,
    castToBoolList, bytesOf, topAt, MAX_STACK_SIZE, MAX_OPS_PER_SCRIPT, disabledWire]

theorem evalFrom_endif_cons (ctx : Ctx) (op : WireOp) (rest : List WireOp) (f : Nat)
    (st : State) (c : Fin 256)
    (ha : op.ast = .op c) (hc : c.toNat = 0x68) (hw : op.wire = 0x68)
    (hsv : ctx.sv = .base)
    (hvf : st.vf = [false])
    (hbud : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hsz : st.stack.length + st.alt.length ≤ MAX_STACK_SIZE) :
    evalFrom ctx (f + 1) (op :: rest) st =
      evalFrom ctx f rest { st with vf := [], opCount := st.opCount + 1, opcodeIndex := st.opcodeIndex + 1 } := by
  obtain ⟨ast, wire, next⟩ := op
  simp only at ha hw
  subst ha
  subst hw
  have hc' : (c.toNat) = 0x68 := hc
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  have hng : ¬ (MAX_STACK_SIZE < st.stack.length + st.alt.length) := by omega
  simp only [evalFrom]
  unfold stepChecked stepBody
  have hb' : ¬ (201 < st.opCount + 1) := by simpa [MAX_OPS_PER_SCRIPT] using hb
  have hng' : ¬ (1000 < st.stack.length + st.alt.length) := by simpa [MAX_STACK_SIZE] using hng
  simp [stepBody.dispatchOp, hsv, hvf, hc', disabledWire, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
    hb', hng']

theorem evalFrom_one_cons (ctx : Ctx) (op : WireOp) (rest : List WireOp) (f : Nat)
    (st : State) (c : Fin 256)
    (ha : op.ast = .pushNum 1) (hw : op.wire = 0x51)
    (hvf : st.vf = [])
    (hsz : st.stack.length + 1 + st.alt.length ≤ MAX_STACK_SIZE) :
    evalFrom ctx (f + 1) (op :: rest) st =
      evalFrom ctx f rest { st with stack := encodeScriptNum 1 false :: st.stack, opcodeIndex := st.opcodeIndex + 1 } := by
  obtain ⟨ast, wire, next⟩ := op
  simp only at ha hw
  subst ha
  subst hw
  have hng : ¬ (MAX_STACK_SIZE < st.stack.length + 1 + st.alt.length) := by omega
  have hng' : ¬ (1000 < st.stack.length + 1 + st.alt.length) := by
    simpa [MAX_STACK_SIZE] using hng
  simp only [evalFrom]
  unfold stepChecked stepBody
  simp [disabledWire, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE, hng', hvf]

theorem wireOpsFrom_length (off : Nat) (ops : List Opcode) :
    (wireOpsFrom off ops).length = ops.length := by
  induction ops generalizing off with
  | nil => rfl
  | cons o ops ih => simp [wireOpsFrom, ih]

theorem wireOpsFrom_push0_cons (off : Nat) (rest : List Opcode) :
    wireOpsFrom off (push0Code :: rest) =
      { ast := push0Code, wire := 0, next := off + 1 } :: wireOpsFrom (off + 1) rest := by
  simp [wireOpsFrom, push0Code, wireOfAst, serializeOpcode, pushBytesWire, lenBytes]

theorem wireOpsFrom_if_cons (off : Nat) (rest : List Opcode) :
    wireOpsFrom off (ifCode :: rest) =
      { ast := ifCode, wire := 0x63, next := off + 1 } :: wireOpsFrom (off + 1) rest := by
  simp only [wireOpsFrom, ifCode, wireOfAst, serializeOpcode_op, List.size_toByteArray]
  rfl

theorem wireOpsFrom_endif_cons (off : Nat) (rest : List Opcode) :
    wireOpsFrom off (endifCode :: rest) =
      { ast := endifCode, wire := 0x68, next := off + 1 } :: wireOpsFrom (off + 1) rest := by
  simp only [wireOpsFrom, endifCode, wireOfAst, serializeOpcode_op, List.size_toByteArray]
  rfl

theorem wireOpsFrom_one_cons (off : Nat) (rest : List Opcode) :
    wireOpsFrom off (oneCode :: rest) =
      { ast := oneCode, wire := 0x51, next := off + 1 } :: wireOpsFrom (off + 1) rest := by
  simp only [wireOpsFrom, oneCode, wireOfAst, serializeOpcode_pushNum, List.size_toByteArray]
  rfl

theorem wireOpsFrom_replicate_push0_pred (off n : Nat) :
    ∀ op ∈ wireOpsFrom off (List.replicate n push0Code),
      op.ast = .pushBytes ByteArray.empty ∧ op.wire = 0 := by
  induction n generalizing off with
  | zero => simp [wireOpsFrom]
  | succ n ih =>
      intro op hop
      rw [List.replicate_succ, wireOpsFrom_push0_cons] at hop
      simp only [List.mem_cons] at hop
      rcases hop with rfl | hmem
      · simp [push0Code]
      · exact ih (off + 1) op hmem

theorem stepChecked_push0_unexec (ctx : Ctx) (nx : Nat) (st : State)
    (hvf : st.vf.all id = false)
    (hsz : st.stack.length + st.alt.length ≤ MAX_STACK_SIZE) :
    stepChecked ctx { ast := .pushBytes ByteArray.empty, wire := 0, next := nx } st = .ok st := by
  unfold stepChecked
  rw [BitcoinProofs.AF.PDW98.stepBody_pushBytes_unexec_ok ctx _ st ByteArray.empty
    rfl (by simp) (by simp) (by simp [disabledWire]) (by simp) hvf]
  simp [hsz]

theorem evalFrom_push0_cons' (ctx : Ctx) (op : WireOp) (rest : List WireOp) (f : Nat)
    (st : State)
    (ha : op.ast = .pushBytes ByteArray.empty) (hw : op.wire = 0)
    (hvf : st.vf.all id = false)
    (hsz : st.stack.length + st.alt.length ≤ MAX_STACK_SIZE) :
    evalFrom ctx (f + 1) (op :: rest) st =
      evalFrom ctx f rest { st with opcodeIndex := st.opcodeIndex + 1 } := by
  obtain ⟨ast, wire, next⟩ := op
  simp only at ha hw
  subst ha
  subst hw
  simp only [evalFrom]
  rw [stepChecked_push0_unexec ctx next st hvf hsz]

theorem evalFrom_dead_push0s (ctx : Ctx) :
    ∀ (ops : List WireOp) (f : Nat) (rest : List WireOp) (st : State),
      ops.length + rest.length + 1 ≤ f →
      (∀ op ∈ ops, op.ast = .pushBytes ByteArray.empty ∧ op.wire = 0) →
      st.vf.all id = false →
      st.stack.length + st.alt.length ≤ MAX_STACK_SIZE →
      evalFrom ctx f (ops ++ rest) st =
        evalFrom ctx (f - ops.length) rest
          { st with opcodeIndex := st.opcodeIndex + UInt32.ofNat ops.length } := by
  intro ops
  induction ops with
  | nil =>
      intro f rest st hfuel _ hvf hsz
      simp
  | cons op ops ih =>
      intro f rest st hfuel hcond hvf hsz
      have hhead := hcond op (by simp)
      have hrest : ∀ o ∈ ops, o.ast = .pushBytes ByteArray.empty ∧ o.wire = 0 :=
        fun o ho => hcond o (by simp [ho])
      cases f with
      | zero => simp at hfuel
      | succ f =>
          rw [List.cons_append]
          rw [evalFrom_push0_cons' ctx op (ops ++ rest) f st hhead.1 hhead.2 hvf hsz]
          rw [ih f rest { st with opcodeIndex := st.opcodeIndex + 1 }
            (by simp at hfuel ⊢; omega) hrest (by simpa using hvf) (by simpa using hsz)]
          simp [Nat.add_sub_add_right, UInt32.ofNat_add, UInt32.add_assoc, UInt32.add_comm]

theorem evalFrom_if_cons (ctx : Ctx) (nx : Nat) (rest : List WireOp) (f : Nat)
    (hsv : ctx.sv = .base) :
    evalFrom ctx (f + 1) ({ ast := ifCode, wire := 0x63, next := nx } :: rest) st1 =
      evalFrom ctx f rest st2 := by
  simp only [evalFrom, st1]
  rw [stepChecked_if_anyidx ctx nx 1 hsv]
  rfl

def scriptList (n : Nat) : List Opcode :=
  push0Code :: ifCode :: (List.replicate n push0Code ++ [endifCode, oneCode])

theorem wireOpsFrom_append (off : Nat) (a b : List Opcode) :
    wireOpsFrom off (a ++ b) =
      wireOpsFrom off a ++ wireOpsFrom (off + (serializeOpcodes a).size) b := by
  induction a generalizing off with
  | nil =>
      simp only [List.nil_append, wireOpsFrom]
      rw [show (serializeOpcodes ([] : List Opcode)).size = 0 from rfl]
      simp
  | cons o a ih =>
      simp only [List.cons_append, wireOpsFrom, serializeOpcodes_cons, ByteArray.size_append]
      rw [ih]
      congr 2
      rw [Nat.add_assoc]

theorem serializeOpcode_push0 : (serializeOpcode push0Code).size = 1 := by
  simp [push0Code, serializeOpcode, pushBytesWire, lenBytes, List.size_toByteArray]

theorem serializeOpcodes_replicate_push0 (n : Nat) :
    (serializeOpcodes (List.replicate n push0Code)).size = n := by
  induction n with
  | zero => rfl
  | succ n ih =>
      rw [List.replicate_succ, serializeOpcodes_cons, ByteArray.size_append, ih,
        serializeOpcode_push0]
      omega

theorem wireOpsFrom_scriptList (n : Nat) :
    wireOpsFrom 0 (scriptList n) =
      { ast := push0Code, wire := 0, next := 1 } ::
      { ast := ifCode, wire := 0x63, next := 2 } ::
      (wireOpsFrom 2 (List.replicate n push0Code) ++
       wireOpsFrom (2 + n) [endifCode, oneCode]) := by
  simp only [scriptList]
  rw [wireOpsFrom_push0_cons 0 (ifCode :: (List.replicate n push0Code ++ [endifCode, oneCode])),
      wireOpsFrom_if_cons 1 (List.replicate n push0Code ++ [endifCode, oneCode])]
  simp only [Nat.zero_add]
  rw [wireOpsFrom_append 2 (List.replicate n push0Code) [endifCode, oneCode],
      serializeOpcodes_replicate_push0]

theorem wireOpsFrom_nil (off : Nat) : wireOpsFrom off ([] : List Opcode) = [] := rfl

theorem eval_script_ok (ctx : Ctx) (hsv : ctx.sv = .base) :
    ∃ s, evalFrom ctx 10001 (wireOpsFrom 0 (scriptList 9996)) init0 = .ok s ∧
      s.stack = [encodeScriptNum 1 false] ∧ s.vf = [] := by
  rw [wireOpsFrom_scriptList]
  rw [evalFrom_push0_init_cons ctx 1 _ 10000]
  rw [evalFrom_if_cons ctx 2 _ 9999 hsv]
  rw [evalFrom_dead_push0s ctx (wireOpsFrom 2 (List.replicate 9996 push0Code)) 9999
        (wireOpsFrom 9998 [endifCode, oneCode]) st2
        (by
          rw [wireOpsFrom_length, wireOpsFrom_length, List.length_replicate,
            List.length_cons, List.length_cons, List.length_nil]
          omega)
        (wireOpsFrom_replicate_push0_pred 2 9996) (by rfl)
        (by simp [st2, st2s, st1s, init0, MAX_STACK_SIZE])]
  simp only [wireOpsFrom_length, List.length_replicate]
  rw [show 9999 - 9996 = 3 from rfl]
  rw [wireOpsFrom_endif_cons]
  rw [evalFrom_endif_cons ctx _ _ 2 _ ⟨0x68, by decide⟩ rfl rfl rfl hsv
        (by simp [st2, st2s, st1s, init0])
        (by simp [st2, st2s, st1s, init0, MAX_OPS_PER_SCRIPT])
        (by simp [st2, st2s, st1s, init0, MAX_STACK_SIZE])]
  rw [wireOpsFrom_one_cons]
  rw [evalFrom_one_cons ctx _ _ 1 _ ⟨0, by decide⟩ rfl rfl
        (by simp [st2, st2s, st1s, init0])
        (by simp [st2, st2s, st1s, init0, MAX_STACK_SIZE])]
  refine ⟨?_, ?_⟩
  case refine_2 =>
    constructor
    · rw [wireOpsFrom_nil]
      simp only [evalFrom, if_true]
      rfl
    · constructor
      · simp [st2, st2s, st1s, init0]
      · simp [st2, st2s, st1s, init0]

/-! ## SCR-070: serialization, parsing, and spendability of the witness -/

theorem serializeOpcodes_append (a b : List Opcode) :
    serializeOpcodes (a ++ b) = serializeOpcodes a ++ serializeOpcodes b := by
  induction a with
  | nil => simp [serializeOpcodes]
  | cons o a ih =>
      simp only [List.cons_append, serializeOpcodes_cons, ih, ByteArray.append_assoc]

theorem serializeOpcode_op_size (c : Fin 256) : (serializeOpcode (.op c)).size = 1 := by
  simp [serializeOpcode]

theorem serializeOpcode_pushNum_size (n : Nat) : (serializeOpcode (.pushNum n)).size = 1 := by
  simp [serializeOpcode]

theorem serializeOpcodes_nil_size : (serializeOpcodes ([] : List Opcode)).size = 0 := rfl

theorem serializeOpcodes_scriptList_size (n : Nat) :
    (serializeOpcodes (scriptList n)).size = n + 4 := by
  rw [scriptList, serializeOpcodes_cons, serializeOpcodes_cons,
    serializeOpcodes_append]
  simp only [ByteArray.size_append, serializeOpcodes_replicate_push0,
    serializeOpcodes_cons, serializeOpcodes_nil_size, serializeOpcode_push0,
    serializeOpcode_op_size, serializeOpcode_pushNum_size, ifCode, endifCode, oneCode]
  omega

theorem head_zero_append (b : ByteArray) :
    ((ByteArray.mk #[0]) ++ b)[0]? = some 0 := by
  rw [show ((ByteArray.mk #[0]) ++ b)[0]? =
      (((ByteArray.mk #[0]) ++ b).data)[0]? from rfl]
  rw [ByteArray.data_append, Array.getElem?_append_left (by simp)]
  rfl

theorem serializeOpcodes_scriptList_head (n : Nat) :
    (serializeOpcodes (scriptList n))[0]? = some 0 := by
  rw [scriptList, serializeOpcodes_cons]
  rw [show serializeOpcode push0Code = ByteArray.mk #[0] from rfl]
  exact head_zero_append _

/-- SCR-070 (classifier side): the 10,000-byte witness script is not
classified unspendable — it is exactly at the size cap and starts with
OP_0, not OP_RETURN. -/
@[rule "SCR-070"]
theorem scriptUnspendable_scriptList_10000 :
    Bitcoin.Ledger.scriptUnspendable ⟨serializeOpcodes (scriptList 9996)⟩ = false := by
  unfold Bitcoin.Ledger.scriptUnspendable
  have hsize : (serializeOpcodes (scriptList 9996)).size = 10000 := by
    rw [serializeOpcodes_scriptList_size]
  have hhead : (serializeOpcodes (scriptList 9996))[0]? = some 0 :=
    serializeOpcodes_scriptList_head 9996
  have hbang : (serializeOpcodes (scriptList 9996)).get! 0 = 0 := by
    show (serializeOpcodes (scriptList 9996)).data[0]! = 0
    rw [Array.getElem!_eq_getD, Array.getD_eq_getD_getElem?]
    rw [show (serializeOpcodes (scriptList 9996)).data[0]? = some 0 from hhead]
    rfl
  simp [hsize, hbang, Bitcoin.Ledger.MAX_SCRIPT_SIZE]

theorem opcodeWF_push0 : opcodeWF push0Code := by
  unfold opcodeWF
  simp [push0Code, Bitcoin.Script.Parser.MAX_SCRIPT_ELEMENT_SIZE]

theorem opcodeWF_if : opcodeWF ifCode := by
  unfold opcodeWF
  simp [ifCode]
  omega

theorem opcodeWF_endif : opcodeWF endifCode := by
  unfold opcodeWF
  simp [endifCode]
  omega

theorem opcodeWF_one : opcodeWF oneCode := by
  unfold opcodeWF
  simp [oneCode]

theorem opcodeWF_scriptList (n : Nat) :
    ∀ o ∈ scriptList n, opcodeWF o := by
  intro o ho
  simp only [scriptList, List.mem_cons, List.mem_append, List.mem_replicate,
    List.mem_singleton, List.not_mem_nil, or_false] at ho
  rcases ho with rfl | rfl | ⟨_, rfl⟩ | rfl | rfl
  · exact opcodeWF_push0
  · exact opcodeWF_if
  · exact opcodeWF_push0
  · exact opcodeWF_endif
  · exact opcodeWF_one

theorem parseWire_scriptList (n : Nat) :
    parseWire (serializeOpcodes (scriptList n)) =
      some (wireOpsFrom 0 (scriptList n)) :=
  BitcoinProofs.Wallet.MiniscriptInterp.parseWire_serializeOpcodes _
    (opcodeWF_scriptList n)

theorem evalScriptBytes_scriptList (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) :
    evalScriptBytes 10001 flags pol (serializeOpcodes (scriptList 9996)) []
      chk .base ed = .ok [encodeScriptNum 1 false] := by
  have hsize : ¬((SigVersion.base = .base ∨ SigVersion.base = .witnessV0) ∧
      MAX_SCRIPT_SIZE < (serializeOpcodes (scriptList 9996)).size) := by
    rw [serializeOpcodes_scriptList_size]
    simp [MAX_SCRIPT_SIZE]
  unfold evalScriptBytes
  rw [if_neg hsize, parseWire_scriptList]
  change finalStack (evalFrom
      ⟨flags, pol, chk, .base, serializeOpcodes (scriptList 9996), ed⟩ 10001
      (wireOpsFrom 0 (scriptList 9996)) init0) = .ok [encodeScriptNum 1 false]
  obtain ⟨s, hs, hstack, _⟩ :=
    eval_script_ok ⟨flags, pol, chk, .base, serializeOpcodes (scriptList 9996), ed⟩ rfl
  rw [hs]
  simp [finalStack, hstack]

/-! ### OP_RETURN is unspendable -/

theorem getOp_zero_of_getElem (b : ByteArray) (c : UInt8) (h : b[0]? = some c) :
    getOp b 0 = getOpAux b 0 c := by
  unfold getOp
  have hc : getOpt b 0 = some c := h
  rw [hc]

theorem getOp_zero_opReturn (b : ByteArray) (h : b[0]? = some 0x6a) :
    getOp b 0 = some (Opcode.op ⟨0x6a, by decide⟩, 1) := by
  rw [getOp_zero_of_getElem b 0x6a h]
  rw [getOpAux_ophi b 0 0x6a (by decide)]
  simp

theorem parseWire_opReturn :
    parseWire (ByteArray.mk #[0x6a]) = some
      ({ ast := Opcode.op ⟨0x6a, by decide⟩, wire := 0x6a, next := 1 } :: []) := by
  unfold parseWire
  simp only [parseWireFrom]
  have h0 : (ByteArray.mk #[0x6a])[0]? = some 0x6a := rfl
  have hget := getOp_zero_opReturn _ h0
  have hsz : (ByteArray.mk #[0x6a]).size = 1 := rfl
  have htail1 : parseWireFrom 1 (ByteArray.mk #[0x6a]) 1 = some [] := by
    simp only [parseWireFrom]
    rw [if_pos (by simp [hsz])]
  have htail : parseWireFrom (ByteArray.mk #[0x6a]).size (ByteArray.mk #[0x6a]) 1 = some [] := by
    simpa [hsz] using htail1
  have hbne : (ByteArray.mk #[0x6a]) ≠ ByteArray.empty := by decide
  have hbang : (ByteArray.mk #[0x6a])[0]! = 0x6a := rfl
  simp [hget, htail, hbne, hbang]

theorem stepBody_opReturn (ctx : Ctx) (op : WireOp) (st : State)
    (hast : op.ast = Opcode.op ⟨0x6a, by decide⟩) (hwire : op.wire = 0x6a)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st = .error .opReturn := by
  obtain ⟨ast, wire, next⟩ := op
  simp only at hast hwire
  subst hast
  subst hwire
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    simp only [MAX_OPS_PER_SCRIPT] at hbud ⊢
    omega
  simp [stepBody, stepBody.dispatchOp, hsv, hfe, hb, disabledWire]

theorem evalFrom_opReturn_head (ctx : Ctx) (fuel : Nat) (op : WireOp)
    (rest : List WireOp) (st : State)
    (hast : op.ast = Opcode.op ⟨0x6a, by decide⟩) (hwire : op.wire = 0x6a)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) :
    evalFrom ctx (fuel + 1) (op :: rest) st = .error .opReturn := by
  have hstep : stepChecked ctx op st = .error .opReturn := by
    unfold stepChecked
    rw [stepBody_opReturn ctx op st hast hwire hsv hfe hbud]
  simp [evalFrom, hstep]

theorem evalScriptBytes_opReturn (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData) :
    evalScriptBytes (fuel + 1) flags pol (ByteArray.mk #[0x6a]) [] chk .base ed =
      .error .opReturn := by
  have hsz : (ByteArray.mk #[0x6a]).size = 1 := rfl
  have hsize : ¬((SigVersion.base = .base ∨ SigVersion.base = .witnessV0) ∧
      MAX_SCRIPT_SIZE < (ByteArray.mk #[0x6a]).size) := by
    rw [hsz]
    simp [MAX_SCRIPT_SIZE]
  unfold evalScriptBytes
  rw [if_neg hsize, parseWire_opReturn]
  change finalStack (evalFrom
    ⟨flags, pol, chk, .base, ByteArray.mk #[0x6a], ed⟩ (fuel + 1)
    ({ ast := Opcode.op ⟨0x6a, by decide⟩, wire := 0x6a, next := 1 } :: [])
    init0) = .error .opReturn
  rw [evalFrom_opReturn_head ⟨flags, pol, chk, .base, ByteArray.mk #[0x6a], ed⟩ fuel
    { ast := Opcode.op ⟨0x6a, by decide⟩, wire := 0x6a, next := 1 } [] init0
    rfl rfl rfl (by decide) (by decide)]
  rfl

/-- SCR-070 (general OP_RETURN head): any parsed script whose first opcode is
OP_RETURN fails at the second evaluation with `OP_RETURN`, independent of the
rest of the script.  The parse-success premise is the model's all-or-nothing
parser boundary; the first opcode is executed before any later opcode. -/
@[rule "SCR-070"]
theorem evalScriptBytes_opReturn_of_parse {fuel : Nat} {flags : ScriptFlags}
    {pol : PolicyFlags} {b : ByteArray} {ops : List WireOp}
    {chk : ScriptChecker} {ed : ScriptExecutionData}
    (hb : b.size ≤ MAX_SCRIPT_SIZE)
    (hp : parseWire b = some
      ({ ast := Opcode.op ⟨0x6a, by decide⟩, wire := 0x6a, next := 1 } :: ops)) :
    evalScriptBytes (fuel + 1) flags pol b [] chk .base ed = .error .opReturn := by
  unfold evalScriptBytes
  have hsz : ¬((SigVersion.base = .base ∨ SigVersion.base = .witnessV0) ∧
      MAX_SCRIPT_SIZE < b.size) := by
    intro h; omega
  rw [if_neg hsz, hp]
  change finalStack (evalFrom
    ⟨flags, pol, chk, .base, b, ed⟩ (fuel + 1)
    ({ ast := Opcode.op ⟨0x6a, by decide⟩, wire := 0x6a, next := 1 } :: ops)
    init0) = .error .opReturn
  rw [evalFrom_opReturn_head ⟨flags, pol, chk, .base, b, ed⟩ fuel
    { ast := Opcode.op ⟨0x6a, by decide⟩, wire := 0x6a, next := 1 } ops init0
    rfl rfl rfl (by decide) (by decide)]
  rfl

/-- SCR-070 (general oversize): any script longer than the 10,000-byte cap
fails the second evaluation with `SCRIPT_SIZE`, independent of its bytes. -/
@[rule "SCR-070"]
theorem evalScriptBytes_oversize_of_size {fuel : Nat} {flags : ScriptFlags}
    {pol : PolicyFlags} {b : ByteArray} {st0 : Stack} {chk : ScriptChecker}
    {sv : SigVersion} {ed : ScriptExecutionData}
    (hb : MAX_SCRIPT_SIZE < b.size) (hsv : sv = .base ∨ sv = .witnessV0) :
    evalScriptBytes fuel flags pol b st0 chk sv ed = .error .scriptSize := by
  unfold evalScriptBytes
  rw [if_pos ⟨hsv, hb⟩]

/-! ### Oversize scripts are unspendable -/

theorem evalScriptBytes_oversize_10001 (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData) :
    evalScriptBytes fuel flags pol (ByteArray.mk (Array.replicate 10001 0)) []
      chk .base ed = .error .scriptSize := by
  have hsz : (ByteArray.mk (Array.replicate 10001 0)).size = 10001 := by
    show (Array.replicate 10001 0).size = 10001
    rw [Array.size_replicate]
  simp [evalScriptBytes, MAX_SCRIPT_SIZE, hsz]

theorem evalScriptBytes_empty (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData) :
    evalScriptBytes (fuel + 1) flags pol ByteArray.empty [] chk .base ed = .ok [] := by
  have hsize : ¬((SigVersion.base = .base ∨ SigVersion.base = .witnessV0) ∧
      MAX_SCRIPT_SIZE < ByteArray.empty.size) := by
    simp [MAX_SCRIPT_SIZE]
  have hparse : parseWire ByteArray.empty = some [] := by
    simp [parseWire, parseWireFrom]
  unfold evalScriptBytes
  rw [if_neg hsize, hparse]
  change finalStack (evalFrom
    ⟨flags, pol, chk, .base, ByteArray.empty, ed⟩ (fuel + 1) [] init0) = .ok []
  simp [finalStack, evalFrom, init0]

/-! ### verifyScriptFull plumbing -/

theorem verifyScriptFull_second_eval_fail (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (ss spk : ByteArray) (witness : Bitcoin.Data.WitnessStack)
    (chk : ScriptChecker) (stack1 : Stack) (e : ExecError)
    (hpre : pol.sigPushOnly = false ∨
      ∃ ops, parseWire ss = some ops ∧ isPushOnlyWire ops = true)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .error e) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail e := by
  unfold verifyScriptFull
  rcases hpre with hp | ⟨ops, ⟨hp, hpo⟩⟩
  · simp [hp, hss, hspk]
  · simp [hp, hpo, hss, hspk]

theorem verifyScriptFull_empty_pre (ss : ByteArray) (pol : PolicyFlags)
    (hss : ss = ByteArray.empty) :
    pol.sigPushOnly = false ∨
      ∃ ops, parseWire ss = some ops ∧ isPushOnlyWire ops = true := by
  subst hss
  cases hp : pol.sigPushOnly with
  | false => exact Or.inl rfl
  | true =>
      exact Or.inr ⟨[], by simp [parseWire, parseWireFrom], by simp [isPushOnlyWire]⟩

@[rule "SCR-070"]
theorem verifyScriptFull_opReturn (flags : ScriptFlags) (pol : PolicyFlags)
    (witness : Bitcoin.Data.WitnessStack) (chk : ScriptChecker) :
    verifyScriptFull 10001 flags pol ByteArray.empty (ByteArray.mk #[0x6a])
      witness chk = .fail .opReturn := by
  apply verifyScriptFull_second_eval_fail (stack1 := [])
  · exact verifyScriptFull_empty_pre _ pol rfl
  · exact evalScriptBytes_empty 10001 flags pol chk default
  · exact evalScriptBytes_opReturn 10000 flags pol chk default

@[rule "SCR-070"]
theorem verifyScriptFull_oversize (flags : ScriptFlags) (pol : PolicyFlags)
    (witness : Bitcoin.Data.WitnessStack) (chk : ScriptChecker) :
    verifyScriptFull 10001 flags pol ByteArray.empty
      (ByteArray.mk (Array.replicate 10001 0)) witness chk = .fail .scriptSize := by
  apply verifyScriptFull_second_eval_fail (stack1 := [])
  · exact verifyScriptFull_empty_pre _ pol rfl
  · exact evalScriptBytes_empty 10001 flags pol chk default
  · exact evalScriptBytes_oversize_10001 10001 flags pol chk default

/-- SCR-070 (general OP_RETURN verifier): a parsed script beginning with
OP_RETURN fails spending even when the script is not the one-byte singleton. -/
@[rule "SCR-070"]
theorem verifyScriptFull_opReturn_of_parse (flags : ScriptFlags) (pol : PolicyFlags)
    (witness : Bitcoin.Data.WitnessStack) (chk : ScriptChecker)
    (spk : ByteArray) (ops : List WireOp)
    (hsize : spk.size ≤ MAX_SCRIPT_SIZE)
    (hparse : parseWire spk = some
      ({ ast := Opcode.op ⟨0x6a, by decide⟩, wire := 0x6a, next := 1 } :: ops)) :
    verifyScriptFull 10001 flags pol ByteArray.empty spk witness chk =
      .fail .opReturn := by
  apply verifyScriptFull_second_eval_fail (stack1 := [])
  · exact verifyScriptFull_empty_pre _ pol rfl
  · exact evalScriptBytes_empty 10000 flags pol chk default
  · exact evalScriptBytes_opReturn_of_parse (fuel := 10000) hsize hparse

/-- SCR-070 (general oversize verifier): any output script beyond the
10,000-byte cap fails spending, independent of its contents. -/
@[rule "SCR-070"]
theorem verifyScriptFull_oversize_of_size (flags : ScriptFlags) (pol : PolicyFlags)
    (witness : Bitcoin.Data.WitnessStack) (chk : ScriptChecker)
    (spk : ByteArray) (hsize : MAX_SCRIPT_SIZE < spk.size) :
    verifyScriptFull 10001 flags pol ByteArray.empty spk witness chk =
      .fail .scriptSize := by
  apply verifyScriptFull_second_eval_fail (stack1 := [])
  · exact verifyScriptFull_empty_pre _ pol rfl
  · exact evalScriptBytes_empty 10000 flags pol chk default
  · exact evalScriptBytes_oversize_of_size (fuel := 10001)
      (b := spk) (st0 := []) (sv := .base) hsize (Or.inl rfl)

/-! ### The 10,000-byte non-OP_RETURN witness is spendable -/

theorem castToBool_one : castToBool (encodeScriptNum 1 false) = true := by
  decide

theorem isWitnessProgram_scriptList_9996 :
    isWitnessProgram (serializeOpcodes (scriptList 9996)) = none := by
  unfold isWitnessProgram
  have hsize : (serializeOpcodes (scriptList 9996)).size = 10000 := by
    rw [serializeOpcodes_scriptList_size]
  have hn : ¬ (4 ≤ (serializeOpcodes (scriptList 9996)).size ∧
      (serializeOpcodes (scriptList 9996)).size ≤ 42) := by
    rw [hsize]
    omega
  simp [hn]

theorem isPayToScriptHash_scriptList_9996 :
    isPayToScriptHash (serializeOpcodes (scriptList 9996)) = false := by
  unfold isPayToScriptHash
  have hsize : (serializeOpcodes (scriptList 9996)).size = 10000 := by
    rw [serializeOpcodes_scriptList_size]
  have hn : (serializeOpcodes (scriptList 9996)).size ≠ 23 := by
    rw [hsize]
    omega
  simp [hn]

theorem verifyScriptFull_second_eval_ok (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (ss spk : ByteArray) (witness : Bitcoin.Data.WitnessStack)
    (chk : ScriptChecker) (stack1 stack : Stack)
    (hpre : pol.sigPushOnly = false ∨
      ∃ ops, parseWire ss = some ops ∧ isPushOnlyWire ops = true)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (hstack : stack = [encodeScriptNum 1 false])
    (hwp : isWitnessProgram spk = none)
    (hp2sh : isPayToScriptHash spk = false)
    (hwit : witness = []) :
    verifyScriptFull fuel flags pol ss spk witness chk = .ok := by
  unfold verifyScriptFull
  rcases hpre with hp | ⟨ops, ⟨hp, hpo⟩⟩
  · simp [hp, hss, hspk, hstack, castToBool_one, hwp, hp2sh, hwit]
  · simp [hp, hpo, hss, hspk, hstack, castToBool_one, hwp, hp2sh, hwit]

@[rule "SCR-070"]
theorem verifyScriptFull_scriptList_spendable (flags : ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) :
    verifyScriptFull 10001 flags pol ByteArray.empty
      (serializeOpcodes (scriptList 9996)) [] chk = .ok := by
  have hwp := isWitnessProgram_scriptList_9996
  have hp2sh := isPayToScriptHash_scriptList_9996
  have hss := evalScriptBytes_empty 10000 flags pol chk default
  have hspk := evalScriptBytes_scriptList flags pol chk default
  exact verifyScriptFull_second_eval_ok 10001 flags pol ByteArray.empty
    (serializeOpcodes (scriptList 9996)) [] chk [] [encodeScriptNum 1 false]
    (verifyScriptFull_empty_pre _ pol rfl) hss hspk rfl hwp hp2sh rfl

end BitcoinProofs.AF.PDW9
