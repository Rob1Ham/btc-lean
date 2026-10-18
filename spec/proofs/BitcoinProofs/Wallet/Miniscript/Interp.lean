import Bitcoin.Wallet.Miniscript.Satisfy
import Bitcoin.Interpreter.Interface
import Bitcoin.Script.Parser.Interface

/-!
# Miniscript satisfaction soundness against the consensus interpreter

**English claim.**  For the supported sane Miniscript fragments, if the
abstract satisfier can produce the witness requested by Core's `Satisfy`
(`src/script/miniscript.h:1709`, `Satisfy`), then that witness stack is
accepted by the consensus-model segwit-v0 interpreter
(`Bitcoin.Interpreter.executeWitnessScript`), under the encoding, policy and
signature-checker premises stated in each theorem.  Proved fragments:
`c:pk_k` (P2PK), `c:pk_h` (P2PKH), `sha256`/`hash256`/`ripemd160`/`hash160`,
and `after`/`older`; the script bytes are matched against the model's
`toScript` and Core's `BuildScript` cases (`src/script/miniscript.h:817`,
`:818`, `:819`, `:820`, `:821`-`:824`, `:827`).

**Core anchors** (pinned commit `cce32b168`):
- satisfaction/production: `src/script/miniscript.h:1247` (`ProduceInput`),
  `:1254` (PK_K), `:1259` (PK_H), `:1353` (OLDER), `:1356` (AFTER),
  `:1359` (SHA256 and siblings), and `:1709` (`Satisfy`);
- script construction: `src/script/miniscript.h:817`-`:830`;
- consensus execution: `src/script/interpreter.cpp:417` (`EvalScript`) and
  `:2012` (`VerifyScript`); signature checking:
  `src/script/interpreter.h:275` (`BaseSignatureChecker`).

**What is not modeled.**  `Satisfier` is abstract: `sign`, `satSHA256`, etc.
return the witness data, so each theorem takes an explicit premise that the
satisfier really returned a signature/preimage for the pinned transaction
(`hsign`, `hproduce`, `hcheck`), plus the checker's signature and locktime
premises.  Only P2WSH/`SigVersion.witnessV0` with a default
`ScriptExecutionData` is covered; tapscript, policy/standardness limits, and
the full descriptor/scriptPubKey round trip are out of scope.  Multisig
(`multi`, `multiA`) is *not* proved; the named obligation
`MultisigEvalSound` at the end of this file records exactly what remains.
-/

namespace BitcoinProofs.Wallet.MiniscriptInterp

open Bitcoin.Wallet.Miniscript
open Bitcoin.Interpreter
open Bitcoin.Data Bitcoin.Script.Parser Bitcoin.Activation
open Bitcoin.Crypto.Seam
open Bitcoin.Numeric

/-! ## ByteArray `get!` helpers -/

theorem get!_append_right {a b : ByteArray} {i : Nat} (h : a.size ≤ i)
    (hi : i < (a ++ b).size) :
    (a ++ b)[i]! = b[i - a.size]! := by
  have hb : i - a.size < b.size := by
    rw [ByteArray.size_append] at hi; omega
  rw [getElem!_pos (a ++ b) i hi, getElem!_pos b (i - a.size) hb]
  exact ByteArray.getElem_append_right h

theorem get!_append_left {a b : ByteArray} {i : Nat} (h : i < a.size) :
    (a ++ b)[i]! = a[i]! := by
  have hi : i < (a ++ b).size := by rw [ByteArray.size_append]; omega
  rw [getElem!_pos (a ++ b) i hi, getElem!_pos a i h]
  exact ByteArray.getElem_append_left h

/-- The wire byte of a canonically serialized opcode. -/
theorem get!_serializeOpcode_zero (o : Opcode) :
    (serializeOpcode o)[0]! = (wireOfAst o).toUInt8 := by
  cases o with
  | op c =>
      rw [serializeOpcode_op, wireOfAst]
      have h0 : 0 < [c.toNat.toUInt8].length := by simp
      rw [← get!_eq_getElem!, toByteArray_get! [c.toNat.toUInt8] 0 h0]
      simp only [List.getElem_cons_zero]
  | pushNum n =>
      rw [serializeOpcode_pushNum, wireOfAst]
      have h0 : 0 < [if n = 0 then (0x4f : UInt8) else (0x50 + n).toUInt8].length := by simp
      rw [← get!_eq_getElem!, toByteArray_get! _ 0 h0]
      simp only [List.getElem_cons_zero]
      by_cases h : n = 0
      · simp [h]
      · simp [h]
  | pushBytes d =>
      rw [serializeOpcode_pushBytes, wireOfAst]
      have hl : 0 < (lenBytes d.size).length := lenBytes_pos d.size
      rw [get!_append_left (a := (lenBytes d.size).toByteArray) (b := d)
        (by simpa [List.size_toByteArray] using hl)]
      rw [← get!_eq_getElem!, toByteArray_get! (lenBytes d.size) 0 hl]
      revert hl
      cases hd : d.size with
      | zero =>
          simp [hd, lenBytes]
      | succ m =>
          by_cases h75 : m + 1 ≤ 75
          · simp [hd, lenBytes, h75]
          · by_cases h255 : m + 1 ≤ 0xff
            · simp [hd, lenBytes, h75, h255]
            · by_cases hffff : m + 1 ≤ 0xffff
              · simp [hd, lenBytes, h75, h255, hffff]
              · simp [hd, lenBytes, h75, h255, hffff]

/-- The wire byte of a well-formed AST opcode is a byte. -/
theorem wireOfAst_lt_256_of_wf (o : Opcode) (ho : opcodeWF o) : wireOfAst o < 256 := by
  cases o with
  | op c =>
      rw [wireOfAst]
      exact Fin.isLt c
  | pushNum n =>
      simp only [opcodeWF] at ho
      rw [wireOfAst]
      by_cases h : n = 0
      · simp [h]
      · simp [h]; omega
  | pushBytes d =>
      rw [wireOfAst]
      by_cases h0 : d.size = 0
      · simp [h0]
      · by_cases h75 : d.size ≤ 75
        · simp [h0, h75]; omega
        · by_cases h255 : d.size ≤ 0xff
          · simp [h0, h75, h255]
          · by_cases hffff : d.size ≤ 0xffff
            · simp [h0, h75, h255, hffff]
            · simp [h0, h75, h255, hffff]

/-- The wire byte recorded by `parseWireFrom` for the head opcode at a
prefix boundary. -/
theorem get!_pre_serializeOpcode (pre : ByteArray) (o : Opcode) (rest : ByteArray) :
    (pre ++ (serializeOpcode o ++ rest))[pre.size]! =
      (wireOfAst o).toUInt8 := by
  have hi : pre.size < (pre ++ (serializeOpcode o ++ rest)).size := by
    rw [ByteArray.size_append, ByteArray.size_append]
    have := serializeOpcode_size o
    omega
  rw [get!_append_right (a := pre) (b := serializeOpcode o ++ rest) (i := pre.size)
    (by omega) hi]
  have h0 : pre.size - pre.size = 0 := by omega
  rw [h0]
  rw [get!_append_left (a := serializeOpcode o) (b := rest) (i := 0)
    (show 0 < (serializeOpcode o).size by exact serializeOpcode_size o)]
  exact get!_serializeOpcode_zero o

/-- Fuel monotonicity for the wire parser. -/
theorem parseWireFrom_mono : ∀ (f : Nat) (b : ByteArray) (ops : List WireOp) (i f' : Nat),
    f ≤ f' → parseWireFrom f b i = some ops → parseWireFrom f' b i = some ops := by
  intro f
  induction f with
  | zero =>
      intro b ops i f' _ h
      simp only [parseWireFrom] at h
      contradiction
  | succ f ih =>
      intro b ops i f' hle h
      cases f' with
      | zero => omega
      | succ f'' =>
        have hle' : f ≤ f'' := by omega
        rw [parseWireFrom] at h ⊢
        by_cases hbi : b.size ≤ i
        · rw [if_pos hbi] at h ⊢
          exact h
        · rw [if_neg hbi] at h ⊢
          cases hgo : getOp b i with
          | none => simp [hgo] at h
          | some p =>
            obtain ⟨o, i'⟩ := p
            simp only [hgo] at h ⊢
            rw [Option.map_eq_some_iff] at h
            obtain ⟨tl, htl, rfl⟩ := h
            exact Option.map_eq_some_iff.mpr
              ⟨tl, ih b tl i' f'' hle' htl, rfl⟩

/-- **Parser bridge.** Parsing the canonical wire image of a well-formed
opcode list yields exactly the `WireOp`s that `wireOpsFrom` records at
canonical offsets. -/
theorem parseWireFrom_serializeOpcodes : ∀ (ops : List Opcode),
    (∀ o ∈ ops, opcodeWF o) →
    ∀ (f : Nat) (pre : ByteArray),
      (serializeOpcodes ops).size + 1 ≤ f →
      parseWireFrom f (pre ++ serializeOpcodes ops) pre.size =
        some (wireOpsFrom pre.size ops) := by
  intro ops
  induction ops with
  | nil =>
      intro _ f pre hf
      cases f with
      | zero => omega
      | succ f' =>
          simp [serializeOpcodes, wireOpsFrom, parseWireFrom]
  | cons o rest ih =>
      intro hall f pre hf
      have ho : opcodeWF o := hall o (by simp)
      have hrest : ∀ o' ∈ rest, opcodeWF o' := fun o' hm => hall o' (by simp [hm])
      have hsize : (serializeOpcodes (o :: rest)).size =
          (serializeOpcode o).size + (serializeOpcodes rest).size := by
        rw [serializeOpcodes_cons, ByteArray.size_append]
      cases f with
      | zero => omega
      | succ f' =>
        rw [serializeOpcodes_cons]
        rw [parseWireFrom]
        have hb : ¬(pre ++ (serializeOpcode o ++ serializeOpcodes rest)).size ≤ pre.size := by
          rw [ByteArray.size_append, ByteArray.size_append]
          have := serializeOpcode_size o
          omega
        rw [if_neg hb]
        have hgo : getOp (pre ++ (serializeOpcode o ++ serializeOpcodes rest)) pre.size =
            some (o, pre.size + (serializeOpcode o).size) := by
          have h := getOp_shift pre (serializeOpcode o ++ serializeOpcodes rest) 0
          rw [Nat.add_zero] at h
          rw [h, getOp_serialize o (serializeOpcodes rest) ho]
          rfl
        rw [hgo]
        simp only [Option.map_some]
        have hfuel : (serializeOpcodes rest).size + 1 ≤ f' := by
          rw [hsize] at hf
          have := serializeOpcode_size o
          omega
        have hpreSize : (pre ++ serializeOpcode o).size =
            pre.size + (serializeOpcode o).size := ByteArray.size_append
        have hrec := ih hrest f' (pre ++ serializeOpcode o) hfuel
        rw [hpreSize] at hrec
        rw [show pre ++ (serializeOpcode o ++ serializeOpcodes rest) =
              (pre ++ serializeOpcode o) ++ serializeOpcodes rest from by
            rw [ByteArray.append_assoc]]
        rw [hrec]
        rw [wireOpsFrom]
        have hw : ((pre ++ serializeOpcode o) ++ serializeOpcodes rest)[pre.size]!.toNat =
            wireOfAst o := by
          rw [ByteArray.append_assoc]
          rw [get!_pre_serializeOpcode]
          simp only [toUInt8_toNat]
          exact Nat.mod_eq_of_lt (wireOfAst_lt_256_of_wf o ho)
        rw [hw]
        rfl

/-- Canonical parser bridge at the `parseWire` entry point. -/
theorem parseWire_serializeOpcodes (ops : List Opcode)
    (h : ∀ o ∈ ops, opcodeWF o) :
    parseWire (serializeOpcodes ops) = some (wireOpsFrom 0 ops) := by
  unfold parseWire
  have := parseWireFrom_serializeOpcodes ops h ((serializeOpcodes ops).size + 1)
    ByteArray.empty (by omega)
  rwa [ByteArray.empty_append] at this

/-! ## Emitted-script serialization lemmas -/

/-- Length of the little-endian magnitude of `n`, bounded by the size of
the base-256 representation. -/
theorem leBytes_length_le : ∀ (k n : Nat), n < 256 ^ k → (leBytes n).length ≤ k := by
  intro k
  induction k with
  | zero =>
      intro n hn
      have hn0 : n = 0 := by
        rw [Nat.pow_zero] at hn
        omega
      subst hn0
      simp [leBytes]
  | succ k ih =>
      intro n hn
      cases n with
      | zero => simp [leBytes]
      | succ m =>
          rw [leBytes, List.length_cons]
          have hpow : 256 ^ (k + 1) = 256 ^ k * 256 := Nat.pow_succ 256 k
          have hdiv : (m + 1) / 256 < 256 ^ k := by
            rw [hpow] at hn
            exact Nat.div_lt_of_lt_mul (by rwa [Nat.mul_comm] at hn)
          have := ih ((m + 1) / 256) hdiv
          omega

theorem bytes_size (l : List Nat) : (bytes l).size = l.length := by
  simp [bytes, ByteArray.size, List.size_toArray]

/-- `scriptNumBytes n` is at most one byte longer than the magnitude of
`n`, so values below `2^31` encode in at most five bytes. -/
theorem scriptNumBytes_size_le (n k : Nat) (h : n < 256 ^ k) :
    (scriptNumBytes n).size ≤ k + 1 := by
  have hlen := leBytes_length_le k n h
  cases hb : leBytes n with
  | nil => simp [scriptNumBytes, hb]
  | cons b bs =>
      rw [hb] at hlen
      simp only [scriptNumBytes, hb]
      by_cases htop : (b :: bs).getLast! ≥ 0x80
      · rw [if_pos htop, bytes_size]
        simp only [List.length_append, List.length_singleton]
        omega
      · rw [if_neg htop, bytes_size]
        omega

/-- One `op n` byte is the canonical serialization of `Opcode.op n`. -/
theorem op_eq_serializeOpcode (n : Nat) (hn : n < 256) :
    op n = serializeOpcode (.op ⟨n, hn⟩) := rfl

theorem op_toByteArray (n : Nat) : op n = List.toByteArray [n.toUInt8] := rfl

theorem bytes_toByteArray2 (a b : Nat) :
    bytes [a, b] = List.toByteArray [a.toUInt8, b.toUInt8] := rfl

/-- `pushBytes` is the canonical serialization of `Opcode.pushBytes` for
payloads below the PUSHDATA2 limit. -/
theorem pushBytes_eq_serializeOpcode (d : ByteArray) (h : d.size ≤ 0xffff) :
    pushBytes d = serializeOpcode (.pushBytes d) := by
  unfold pushBytes
  rw [serializeOpcode_pushBytes]
  cases hd : d.size with
  | zero =>
      have hd0 : d = ByteArray.empty := ByteArray.size_eq_zero_iff.mp hd
      rw [hd0]
      simp [lenBytes, op_toByteArray]
  | succ m =>
      by_cases h75 : m + 1 ≤ 75
      · simp only [if_neg (by omega : ¬m + 1 = 0), if_pos h75, lenBytes]
        rw [op_toByteArray]
      · by_cases h255 : m + 1 ≤ 0xff
        · simp only [if_neg (by omega : ¬m + 1 = 0), if_neg h75, if_pos h255, lenBytes]
          rw [op_toByteArray, op_toByteArray]
          rw [show ([76, (m + 1).toUInt8] : List UInt8) =
              [76] ++ [(m + 1).toUInt8] from rfl, List.toByteArray_append]
          simp
        · have hffff : m + 1 ≤ 0xffff := by omega
          simp only [if_neg (by omega : ¬m + 1 = 0), if_neg h75, if_neg h255,
            if_pos hffff, lenBytes]
          rw [op_toByteArray, bytes_toByteArray2]
          rw [show ([77, ((m + 1) % 256).toUInt8, ((m + 1) / 256).toUInt8] : List UInt8) =
              [77] ++ [((m + 1) % 256).toUInt8, ((m + 1) / 256).toUInt8] from rfl,
            List.toByteArray_append]
          simp


/-- The AST opcode used to emit `pushInt n`: `OP_0`, `OP_1..OP_16`, or
the canonical ScriptNum push. -/
def pushIntOp (n : Nat) : Opcode :=
  if n = 0 then .pushBytes .empty
  else if n ≤ 16 then .pushNum n
  else .pushBytes (scriptNumBytes n)

theorem pushInt_eq_serializeOpcode (n : Nat) (hn : n < 2 ^ 31) :
    pushInt n = serializeOpcode (pushIntOp n) := by
  by_cases h0 : n = 0
  · subst h0
    simp [pushInt, pushIntOp, serializeOpcode, pushBytesWire, lenBytes, op_toByteArray]
  · rw [pushInt, pushIntOp]
    simp only [if_neg h0]
    by_cases h16 : n ≤ 16
    · simp only [if_pos h16]
      rw [op_toByteArray, serializeOpcode_pushNum, if_neg h0]
    · simp only [if_neg h16]
      rw [pushBytes_eq_serializeOpcode]
      · have h4 : n < 256 ^ 4 := by
          have h256 : (256 : Nat) ^ 4 = 2 ^ 32 := by decide
          rw [h256]
          omega
        have := scriptNumBytes_size_le n 4 h4
        omega

/-! ## Numeric bridge: `scriptNumBytes` is the canonical ScriptNum encoding -/

theorem foldl_push_eq (l : List Nat) (acc : ByteArray) :
    (l.map (fun n => n.toUInt8)).foldl (fun a b => a.push b) acc
      = ByteArray.mk (acc.data ++ (l.map (fun n => n.toUInt8)).toArray) := by
  induction l generalizing acc with
  | nil => simp
  | cons x xs ih =>
      simp only [List.map_cons, List.foldl_cons]
      rw [ih]
      congr 1
      simp [ByteArray.push]

theorem bytes_eq_bytesFromLE (l : List Nat) : bytes l = bytesFromLE l := by
  unfold bytes bytesFromLE
  rw [foldl_push_eq]
  simp

theorem leBytes_eq_reverse_magBEAux : ∀ (f n : Nat), n < 256 ^ f →
    leBytes n = (magBEAux f n).reverse := by
  intro f
  induction f with
  | zero =>
      intro n h
      have h0 : n = 0 := by rw [Nat.pow_zero] at h; omega
      subst h0
      simp [leBytes, magBEAux]
  | succ f ih =>
      intro n h
      cases n with
      | zero => simp [leBytes, magBEAux]
      | succ m =>
          have hpow : 256 ^ (f + 1) = 256 ^ f * 256 := Nat.pow_succ 256 f
          have hdiv : (m + 1) / 256 < 256 ^ f := by
            rw [hpow] at h
            exact Nat.div_lt_of_lt_mul (by rwa [Nat.mul_comm] at h)
          rw [leBytes, magBEAux, if_neg (by omega : ¬ m + 1 = 0), ih ((m + 1) / 256) hdiv,
            List.reverse_append, List.reverse_singleton]
          rfl

theorem leBytes_eq_reverse_magBE (n : Nat) (h : n < 256 ^ 10) :
    leBytes n = (magBE n).reverse :=
  leBytes_eq_reverse_magBEAux 10 n h

theorem match_append_singleton (t : List Nat) (d : Nat) :
    (match t.reverse ++ [d] with
      | [] => ByteArray.empty
      | bs => if bs.getLast! ≥ 128 then bytes (bs ++ [0]) else bytes bs)
      = (if (t.reverse ++ [d]).getLast! ≥ 128 then
          bytes ((t.reverse ++ [d]) ++ [0]) else bytes (t.reverse ++ [d])) := by
  cases h : t.reverse ++ [d] with
  | nil => simp at h
  | cons b bs => simp

theorem scriptNumBytes_eq_encodeScriptNum (n : Nat) (h : n < 2 ^ 31) :
    scriptNumBytes n = encodeScriptNum (n : ScriptNum) false := by
  have h10 : n < 256 ^ 10 := by
    have h256 : (256 : Nat) ^ 10 = 2 ^ 80 := by decide
    rw [h256]
    omega
  have hle := leBytes_eq_reverse_magBE n h10
  unfold scriptNumBytes
  rw [hle]
  cases hm : magBE n with
  | nil =>
      have hv : n = 0 := by
        have := magOfBE_magBE n h10
        rw [hm] at this
        simpa [magOfBE] using this.symm
      subst hv
      simp only [List.reverse_nil]
      rfl
  | cons d t =>
      rw [List.reverse_cons]
      have hd : (t.reverse ++ [d]).getLast! = d := by
        rw [List.getLast!_eq_getElem!]
        simp
      refine (match_append_singleton t d).trans ?_
      rw [hd]
      unfold encodeScriptNum scriptNumBE
      simp only [Int.natAbs_natCast]
      rw [hm]
      have hneg : ¬ (n : Int) < 0 := by omega
      simp [decide_eq_false hneg, encodeSignBE]
      by_cases hlt : d < 128
      · simp only [if_pos hlt, if_neg (by omega : ¬ d ≥ 128)]
        rw [← bytes_eq_bytesFromLE, List.reverse_cons]
      · simp only [if_neg hlt, if_pos (by omega : d ≥ 128)]
        rw [← bytes_eq_bytesFromLE, List.reverse_cons, List.reverse_cons]
        simp

theorem decode_encodeScriptNum_nat (n : Nat) (h : n < 2 ^ 31) (minimal : Bool) :
    decodeScriptNum (encodeScriptNum (n : ScriptNum) false) minimal 5 = some (n : ScriptNum) := by
  have h10 : n < 256 ^ 10 := by
    have h256 : (256 : Nat) ^ 10 = 2 ^ 80 := by decide
    rw [h256]; omega
  have hdigits : ∀ d ∈ (scriptNumBE (n : ScriptNum)).reverse, d < 256 :=
    fun d hd => scriptNumBE_digits_lt _ d (List.mem_reverse.mp hd)
  have hb : (bytesOf (encodeScriptNum (n : ScriptNum) false)).reverse = scriptNumBE (n : ScriptNum) := by
    unfold encodeScriptNum
    rw [bytesOf_bytesFromLE _ hdigits, List.reverse_reverse]
  have hlen : (scriptNumBE (n : ScriptNum)).length ≤ 5 := by
    have := scriptNumBE_length_le4 (n : ScriptNum) (by simpa using h)
    omega
  have hmin : minimalOkBE (scriptNumBE (n : ScriptNum)) = true :=
    minimalOkBE_scriptNumBE _ h10
  unfold decodeScriptNum
  rw [hb, decodeBE_some (by omega) (Or.inr hmin), scriptNumBE_value n h10]

theorem decode_scriptNumBytes (n : Nat) (h : n < 2 ^ 31) (minimal : Bool) :
    decodeScriptNum (scriptNumBytes n) minimal 5 = some (n : ScriptNum) := by
  rw [scriptNumBytes_eq_encodeScriptNum n h]
  exact decode_encodeScriptNum_nat n h minimal

/-! ## P2PK (`c:pk_k`) against the interpreter -/

theorem finAC_toNat : (⟨0xac, by omega⟩ : Fin 256).toNat = 0xac := rfl
theorem fin172_toNat : (172 : Fin 256).toNat = 172 := rfl

/-- `toScript` of `c:pk_k key` is exactly the canonical serialization of
`<key> OP_CHECKSIG`. -/
theorem toScript_wrapC_pkK (ctx : MiniscriptContext) (key : ByteArray)
    (hkey : key.size ≤ 0xffff) :
    toScript ctx (.wrapC (.pkK key)) =
      serializeOpcodes [.pushBytes key, .op ⟨0xac, by omega⟩] := by
  unfold toScript
  simp only [toScriptWith, Bool.false_eq_true, if_false]
  rw [pushBytes_eq_serializeOpcode key hkey]
  rw [op_eq_serializeOpcode 0xac (by omega)]
  simp [serializeOpcodes]

/-- The interpreter accepts `<key> OP_CHECKSIG` on witness `[sig]` when the
signature and key encodings pass and the checker accepts the signature. -/
theorem eval_wrapC_pkK (key sig : ByteArray) (hkey : key.size = 33)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData)
    (hmin : pol.minimalData = false)
    (henc : checkSigEncoding flags pol sig = none)
    (hpk : checkPubKeyEncoding flags pol .witnessV0 key = none)
    (hchk : (chk.base.checkECDSASignature sig key
      ((serializeOpcodes [.pushBytes key, .op ⟨0xac, by omega⟩]).extract 0
        (serializeOpcodes [.pushBytes key, .op ⟨0xac, by omega⟩]).size)
      .witnessV0 ed) = true) :
    evalScriptBytes 4 flags pol (serializeOpcodes [.pushBytes key, .op ⟨0xac, by omega⟩])
      [sig] chk .witnessV0 ed = .ok [vchTrue] := by
  have hne : key ≠ ByteArray.empty := by
    intro h
    rw [h] at hkey
    simp at hkey
  have h75 : key.size ≤ 75 := by omega
  have hlen : (serializeOpcodes [.pushBytes key, .op ⟨0xac, by omega⟩]).size ≤ 10000 := by
    simp [serializeOpcodes, serializeOpcode, pushBytesWire, hkey, lenBytes]
  have hcode : (serializeOpcodes [.pushBytes key, .op ⟨0xac, by omega⟩]).extract 0
        (serializeOpcodes [.pushBytes key, .op ⟨0xac, by omega⟩]).size
      = (([33].toByteArray ++ key).push (UInt8.ofFin (172 : Fin 256))).extract 0 35 := by
    simp [serializeOpcodes, serializeOpcode, pushBytesWire, lenBytes, hkey]
  have hchk' : chk.base.checkECDSASignature sig key
      ((([33].toByteArray ++ key).push (UInt8.ofFin (172 : Fin 256))).extract 0 35)
      SigVersion.witnessV0 ed = true := by
    rw [← hcode]
    exact hchk
  unfold evalScriptBytes
  rw [if_neg]
  · rw [parseWire_serializeOpcodes]
    · simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
        Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_STACK_SIZE, MAX_OPS_PER_SCRIPT,
        finAC_toNat, fin172_toNat,
        wireOfAst, serializeOpcode, pushBytesWire, lenBytes, checkMinimalPush,
        topAt, evalChecksigDispatch, evalChecksigPreTapscript,
        hkey, hne, h75, henc, hpk, hchk', pushBoolV, vchTrue, disabledWire, hmin,
        ByteArray.append_assoc, serializeOpcodes]
      rw [show (↑(172 : Fin 256) : Nat) = 172 from rfl]
      simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
        Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_STACK_SIZE, MAX_OPS_PER_SCRIPT,
        wireOfAst, serializeOpcode, pushBytesWire, lenBytes, checkMinimalPush,
        topAt, evalChecksigDispatch, evalChecksigPreTapscript,
        hkey, hne, h75, henc, hpk, hchk', pushBoolV, vchTrue, disabledWire, hmin,
        ByteArray.append_assoc, serializeOpcodes]
    · intro o ho
      simp only [List.mem_cons, List.mem_singleton, List.not_mem_nil, or_false] at ho
      rcases ho with rfl | rfl
      · simp [opcodeWF, hkey, Bitcoin.Script.Parser.MAX_SCRIPT_ELEMENT_SIZE]
      · simp [opcodeWF]
        omega
  · simp only [Bool.and_eq_true, not_and]
    intro _
    exact Nat.not_lt.mpr hlen


/-! ## P2PKH (`c:pk_h`) against the interpreter -/

theorem toScript_wrapC_pkH (ctx : MiniscriptContext) (key keyHash : ByteArray)
    (h : keyHash.size ≤ 0xffff) :
    toScript ctx (.wrapC (.pkH key keyHash)) =
      serializeOpcodes [.op ⟨0x76, by omega⟩, .op ⟨0xa9, by omega⟩,
        .pushBytes keyHash, .op ⟨0x88, by omega⟩, .op ⟨0xac, by omega⟩] := by
  unfold toScript
  simp only [toScriptWith, Bool.false_eq_true, if_false]
  rw [pushBytes_eq_serializeOpcode keyHash h]
  simp [serializeOpcodes, op_eq_serializeOpcode, ByteArray.append_assoc]

theorem eval_wrapC_pkH (key keyHash sig : ByteArray) (hkey : key.size = 33) (hkh : keyHash.size = 20)
    (hhash : hashHash160 key = keyHash)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData)
    (hmin : pol.minimalData = false)
    (henc : checkSigEncoding flags pol sig = none)
    (hpk : checkPubKeyEncoding flags pol .witnessV0 key = none)
    (hchk : (chk.base.checkECDSASignature sig key
      ((serializeOpcodes [.op ⟨0x76, by omega⟩, .op ⟨0xa9, by omega⟩,
        .pushBytes keyHash, .op ⟨0x88, by omega⟩, .op ⟨0xac, by omega⟩]).extract 0
        (serializeOpcodes [.op ⟨0x76, by omega⟩, .op ⟨0xa9, by omega⟩,
          .pushBytes keyHash, .op ⟨0x88, by omega⟩, .op ⟨0xac, by omega⟩]).size)
      .witnessV0 ed) = true) :
    evalScriptBytes 8 flags pol (serializeOpcodes [.op ⟨0x76, by omega⟩, .op ⟨0xa9, by omega⟩,
        .pushBytes keyHash, .op ⟨0x88, by omega⟩, .op ⟨0xac, by omega⟩])
      [key, sig] chk .witnessV0 ed = .ok [vchTrue] := by
  have hbeq : (keyHash == keyHash) = true := by
    change (keyHash.data == keyHash.data) = true
    exact beq_iff_eq.mpr rfl
  have hchk3 : chk.base.checkECDSASignature sig key
      (serializeOpcodes [Opcode.op 118, Opcode.op 169, Opcode.pushBytes keyHash,
        Opcode.op 136, Opcode.op 172]) SigVersion.witnessV0 ed = true := by
    simpa using hchk
  have hchk'' : chk.base.checkECDSASignature sig key
      (serializeOpcodes [.op ⟨0x76, by omega⟩, .op ⟨0xa9, by omega⟩,
        .pushBytes keyHash, .op ⟨0x88, by omega⟩, .op ⟨0xac, by omega⟩])
      .witnessV0 ed = true := by
    simpa using hchk
  have hne : key ≠ ByteArray.empty := by
    intro h; rw [h] at hkey; simp at hkey
  have hneKH : keyHash ≠ ByteArray.empty := by
    intro h; rw [h] at hkh; simp at hkh
  have hlen : (serializeOpcodes [.op ⟨0x76, by omega⟩, .op ⟨0xa9, by omega⟩,
        .pushBytes keyHash, .op ⟨0x88, by omega⟩, .op ⟨0xac, by omega⟩]).size ≤ 10000 := by
    simp [serializeOpcodes, serializeOpcode, pushBytesWire, hkey, hkh, lenBytes]
  unfold evalScriptBytes
  rw [if_neg]
  · rw [parseWire_serializeOpcodes]
    · simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
        Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
        wireOfAst, hashForOp, checkMinimalPush, topAt, evalChecksigDispatch, evalChecksigPreTapscript,
        hkey, hne, hkh, hneKH, hhash, henc, hpk, hchk'', pushBoolV, vchTrue, disabledWire, hmin,
        ByteArray.append_assoc, hbeq]
      rw [show (↑(118 : Fin 256) : Nat) = 118 from rfl,
          show (↑(169 : Fin 256) : Nat) = 169 from rfl,
          show (↑(136 : Fin 256) : Nat) = 136 from rfl,
          show (↑(172 : Fin 256) : Nat) = 172 from rfl]
      simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
        Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
        wireOfAst, hashForOp, checkMinimalPush, topAt, evalChecksigDispatch, evalChecksigPreTapscript,
        hkey, hne, hkh, hneKH, hhash, henc, hpk, hchk'', pushBoolV, vchTrue, disabledWire, hmin,
        ByteArray.append_assoc, hbeq]
      simp [hchk3, hchk'', Bool.true_eq_false, Bool.false_eq_true, pushBoolV, vchTrue, serU8, vchFalse]
    · intro o ho
      simp only [List.mem_cons, List.mem_singleton, List.not_mem_nil, or_false] at ho
      rcases ho with rfl | rfl | rfl | rfl | rfl
      · simp [opcodeWF]; omega
      · simp [opcodeWF]; omega
      · simp [opcodeWF, hkh, Bitcoin.Script.Parser.MAX_SCRIPT_ELEMENT_SIZE]
      · simp [opcodeWF]; omega
      · simp [opcodeWF]; omega
  · simp only [Bool.and_eq_true, not_and]
    intro _
    exact Nat.not_lt.mpr hlen


/-! ## Hash locks (`sha256`, `hash256`, `ripemd160`, `hash160`) -/

theorem toScript_sha256 (ctx : MiniscriptContext) (h : ByteArray) (hh : h.size ≤ 0xffff) :
    toScript ctx (.sha256 h) = serializeOpcodes
      [.op ⟨0x82, by omega⟩, .pushBytes (bytes [0x20]),
       .op ⟨0x88, by omega⟩, .op ⟨0xa8, by omega⟩, .pushBytes h, .op ⟨0x87, by omega⟩] := by
  have hsz : (bytes [0x20]).size = 1 := rfl
  have hpair : op 1 ++ op 32 = serializeOpcode (.pushBytes (bytes [0x20])) := by decide
  have hshift : ∀ rest, op 1 ++ (op 32 ++ rest) =
      serializeOpcode (.pushBytes (bytes [0x20])) ++ rest := by
    intro rest
    rw [← ByteArray.append_assoc, hpair]
  unfold toScript
  simp only [toScriptWith, Bool.false_eq_true, if_false]
  simp only [ByteArray.append_assoc]
  rw [hshift]
  simp [serializeOpcodes, op_eq_serializeOpcode, pushBytes_eq_serializeOpcode, hh,
    hsz, ByteArray.append_assoc]

theorem toScript_hash256 (ctx : MiniscriptContext) (h : ByteArray) (hh : h.size ≤ 0xffff) :
    toScript ctx (.hash256 h) = serializeOpcodes
      [.op ⟨0x82, by omega⟩, .pushBytes (bytes [0x20]),
       .op ⟨0x88, by omega⟩, .op ⟨0xaa, by omega⟩, .pushBytes h, .op ⟨0x87, by omega⟩] := by
  have hsz : (bytes [0x20]).size = 1 := rfl
  have hpair : op 1 ++ op 32 = serializeOpcode (.pushBytes (bytes [0x20])) := by decide
  have hshift : ∀ rest, op 1 ++ (op 32 ++ rest) =
      serializeOpcode (.pushBytes (bytes [0x20])) ++ rest := by
    intro rest
    rw [← ByteArray.append_assoc, hpair]
  unfold toScript
  simp only [toScriptWith, Bool.false_eq_true, if_false]
  simp only [ByteArray.append_assoc]
  rw [hshift]
  simp [serializeOpcodes, op_eq_serializeOpcode, pushBytes_eq_serializeOpcode, hh,
    hsz, ByteArray.append_assoc]

theorem toScript_ripemd160 (ctx : MiniscriptContext) (h : ByteArray) (hh : h.size ≤ 0xffff) :
    toScript ctx (.ripemd160 h) = serializeOpcodes
      [.op ⟨0x82, by omega⟩, .pushBytes (bytes [0x20]),
       .op ⟨0x88, by omega⟩, .op ⟨0xa6, by omega⟩, .pushBytes h, .op ⟨0x87, by omega⟩] := by
  have hsz : (bytes [0x20]).size = 1 := rfl
  have hpair : op 1 ++ op 32 = serializeOpcode (.pushBytes (bytes [0x20])) := by decide
  have hshift : ∀ rest, op 1 ++ (op 32 ++ rest) =
      serializeOpcode (.pushBytes (bytes [0x20])) ++ rest := by
    intro rest
    rw [← ByteArray.append_assoc, hpair]
  unfold toScript
  simp only [toScriptWith, Bool.false_eq_true, if_false]
  simp only [ByteArray.append_assoc]
  rw [hshift]
  simp [serializeOpcodes, op_eq_serializeOpcode, pushBytes_eq_serializeOpcode, hh,
    hsz, ByteArray.append_assoc]

theorem toScript_hash160 (ctx : MiniscriptContext) (h : ByteArray) (hh : h.size ≤ 0xffff) :
    toScript ctx (.hash160 h) = serializeOpcodes
      [.op ⟨0x82, by omega⟩, .pushBytes (bytes [0x20]),
       .op ⟨0x88, by omega⟩, .op ⟨0xa9, by omega⟩, .pushBytes h, .op ⟨0x87, by omega⟩] := by
  have hsz : (bytes [0x20]).size = 1 := rfl
  have hpair : op 1 ++ op 32 = serializeOpcode (.pushBytes (bytes [0x20])) := by decide
  have hshift : ∀ rest, op 1 ++ (op 32 ++ rest) =
      serializeOpcode (.pushBytes (bytes [0x20])) ++ rest := by
    intro rest
    rw [← ByteArray.append_assoc, hpair]
  unfold toScript
  simp only [toScriptWith, Bool.false_eq_true, if_false]
  simp only [ByteArray.append_assoc]
  rw [hshift]
  simp [serializeOpcodes, op_eq_serializeOpcode, pushBytes_eq_serializeOpcode, hh,
    hsz, ByteArray.append_assoc]

theorem eval_hash (w : Nat) (hw : w = 0xa8 ∨ w = 0xaa ∨ w = 0xa6 ∨ w = 0xa9)
    (p digest : ByteArray) (hp : p.size = 32) (hhash : hashForOp w p = digest)
    (hd : digest.size = 32 ∨ digest.size = 20)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (hmin : pol.minimalData = false) :
    evalScriptBytes 10000 flags pol (serializeOpcodes
      [.op ⟨0x82, by omega⟩, .pushBytes (bytes [0x20]), .op ⟨0x88, by omega⟩,
       .op ⟨w, by omega⟩, .pushBytes digest, .op ⟨0x87, by omega⟩])
      [p] chk .witnessV0 ed = .ok [vchTrue] := by
  rcases hd with hd | hd
  all_goals
    have hsz : (bytes [0x20]).size = 1 := rfl
    have hdpos : 0 < digest.size := by omega
    have hdne : digest ≠ ByteArray.empty := by
      intro h; rw [h] at hdpos; simp at hdpos
    have hbeq32 : (encodeScriptNum 32 false == bytes [0x20]) = true := by
      change ((encodeScriptNum 32 false).data == (bytes [0x20]).data) = true
      rw [show encodeScriptNum 32 false = bytes [0x20] from by decide]
      exact beq_iff_eq.mpr rfl
    have hbeqDD : (digest == digest) = true := by
      change (digest.data == digest.data) = true
      exact beq_iff_eq.mpr rfl
    have hlenbytes : (lenBytes digest.size).length = 1 := by
      rw [hd]; decide
    have hpushWire : (pushBytesWire digest).size = 1 + digest.size := by
      unfold pushBytesWire
      simp [List.size_toByteArray, hlenbytes]
    have hpushWire32 : (pushBytesWire (bytes [0x20])).size = 2 := by decide
    have hbeqD : (hashForOp w p == digest) = true := by
      rw [hhash]; exact hbeqDD
    have hlen : (serializeOpcodes
        [.op ⟨0x82, by omega⟩, .pushBytes (bytes [0x20]), .op ⟨0x88, by omega⟩,
         .op ⟨w, by omega⟩, .pushBytes digest, .op ⟨0x87, by omega⟩]).size ≤ 10000 := by
      simp [serializeOpcodes, serializeOpcode, hpushWire, hpushWire32, hd]
    rcases hw with rfl | rfl | rfl | rfl
    all_goals
      unfold evalScriptBytes
      rw [if_neg]
      · rw [parseWire_serializeOpcodes]
        · simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
            Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
            wireOfAst, checkMinimalPush, topAt, hp, hsz, hd, hdne, hhash, hbeq32, hbeqD, hbeqDD,
            pushBoolV, vchTrue, disabledWire, hmin, ByteArray.append_assoc]
          rw [show (↑(130 : Fin 256) : Nat) = 130 from rfl,
              show (↑(136 : Fin 256) : Nat) = 136 from rfl,
              show (↑(135 : Fin 256) : Nat) = 135 from rfl]
          first
          | rw [show (↑(166 : Fin 256) : Nat) = 166 from rfl]
          | rw [show (↑(168 : Fin 256) : Nat) = 168 from rfl]
          | rw [show (↑(169 : Fin 256) : Nat) = 169 from rfl]
          | rw [show (↑(170 : Fin 256) : Nat) = 170 from rfl]
          simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
            Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
            wireOfAst, checkMinimalPush, topAt, hp, hsz, hd, hdne, hhash, hbeq32, hbeqD, hbeqDD,
            pushBoolV, vchTrue, disabledWire, hmin, ByteArray.append_assoc]
        · intro o ho
          simp only [List.mem_cons, List.mem_singleton, List.not_mem_nil, or_false] at ho
          rcases ho with rfl | rfl | rfl | rfl | rfl | rfl
          · simp [opcodeWF]; omega
          · simp [opcodeWF]; decide
          · simp [opcodeWF]; omega
          · simp [opcodeWF]; omega
          · simp [opcodeWF, Bitcoin.Script.Parser.MAX_SCRIPT_ELEMENT_SIZE]; omega
          · simp [opcodeWF]; omega
      · simp only [Bool.and_eq_true, not_and]
        intro _
        exact Nat.not_lt.mpr hlen


/-! ## Timelocks (`older`, `after`) -/

theorem and_disable_flag_eq_zero (n : Nat) (h : n < 2^31) :
    (n &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) = 0 := by
  rw [show SEQUENCE_LOCKTIME_DISABLE_FLAG = 2^31 from rfl]
  apply Nat.eq_of_testBit_eq
  intro i
  rw [Nat.testBit_and, Nat.testBit_two_pow, Nat.zero_testBit]
  by_cases hi : i = 31
  · subst hi; rw [Nat.testBit_lt_two_pow h]; simp
  · have h31 : ¬ (31 = i) := by omega
    simp [h31]

theorem scriptNumBytes_ne_empty (n : Nat) (hn : 0 < n) : scriptNumBytes n ≠ ByteArray.empty := by
  cases n with
  | zero => omega
  | succ m =>
      cases hb : leBytes (m + 1) with
      | nil => simp [leBytes] at hb
      | cons b bs =>
          have hEq : scriptNumBytes (m + 1) =
              (if (b :: bs).getLast! ≥ 0x80 then bytes ((b :: bs) ++ [0]) else bytes (b :: bs)) := by
            simp [scriptNumBytes, hb]
          rw [hEq]
          by_cases htop : (b :: bs).getLast! ≥ 0x80
          · rw [if_pos htop]
            have hpos : 0 < (bytes ((b :: bs) ++ [0])).size := by simp [bytes, ByteArray.size]
            intro h
            rw [h] at hpos
            simp at hpos
          · rw [if_neg htop]
            intro h
            have hpos : 0 < (bytes (b :: bs)).size := by simp [bytes, ByteArray.size]
            rw [h] at hpos
            simp at hpos

theorem eval_after_pushNum (n : Nat) (hn : n < 2^31) (hn16 : n ≤ 16) (hn1 : 1 ≤ n)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (hmin : pol.minimalData = false)
    (hcltv : flags.cltv = true)
    (hdef : checkLockTimeDef chk.env (n : ScriptNum) = true) :
    evalScriptBytes 8 flags pol (serializeOpcodes [.pushNum n, .op ⟨0xb1, by omega⟩])
      [] chk .witnessV0 ed = .ok [scriptNumBytes n] := by
  have hdec : decodeNum pol (scriptNumBytes n) 5 = .ok (n : ScriptNum) := by
    unfold decodeNum
    rw [hmin, decode_scriptNumBytes n hn false]
  have henc : encodeScriptNum (n : ScriptNum) false = scriptNumBytes n := by
    rw [scriptNumBytes_eq_encodeScriptNum n hn]
  have hn0 : n ≠ 0 := by omega
  have hnneg : ¬ ((n : ScriptNum) < 0) := by simp
  have hnot : ¬ (96 < 80 + n) := by omega
  have hdisj : ¬ (80 + n = 126 ∨ 80 + n = 127 ∨ 80 + n = 128 ∨ 80 + n = 129 ∨
      80 + n = 131 ∨ 80 + n = 132 ∨ 80 + n = 133 ∨ 80 + n = 134 ∨
      80 + n = 141 ∨ 80 + n = 142 ∨ 80 + n = 149 ∨ 80 + n = 150 ∨
      80 + n = 151 ∨ 80 + n = 152 ∨ 80 + n = 153) := by omega
  have hlen : (serializeOpcodes [.pushNum n, .op ⟨0xb1, by omega⟩]).size ≤ 10000 := by
    simp [serializeOpcodes, serializeOpcode]
  unfold evalScriptBytes
  rw [if_neg]
  · rw [parseWire_serializeOpcodes]
    · simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
        Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
        wireOfAst, checkMinimalPush, topAt, hmin, hcltv, hdef, henc, hn0, hn16, hnneg, hnot, hdisj,
        pushBoolV, vchTrue, disabledWire]
      rw [show (↑(177 : Fin 256) : Nat) = 177 from rfl]
      simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
        Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
        wireOfAst, checkMinimalPush, topAt, hmin, hcltv, hdef, henc, hn0, hn16, hnneg, hnot, hdisj, hdec,
        pushBoolV, vchTrue, disabledWire]
    · intro o ho
      simp only [List.mem_cons, List.mem_singleton, List.not_mem_nil, or_false] at ho
      rcases ho with rfl | rfl
      · simp [opcodeWF]; omega
      · simp [opcodeWF]; omega
  · simp only [Bool.and_eq_true, not_and]
    intro _
    exact Nat.not_lt.mpr hlen


theorem eval_after_pushBytes (n : Nat) (hn : n < 2^31) (hn16 : ¬ n ≤ 16) (hn1 : 1 ≤ n)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (hmin : pol.minimalData = false)
    (hcltv : flags.cltv = true)
    (hdef : checkLockTimeDef chk.env (n : ScriptNum) = true) :
    evalScriptBytes 8 flags pol (serializeOpcodes [.pushBytes (scriptNumBytes n), .op ⟨0xb1, by omega⟩])
      [] chk .witnessV0 ed = .ok [scriptNumBytes n] := by
  have hdec : decodeNum pol (scriptNumBytes n) 5 = .ok (n : ScriptNum) := by
    unfold decodeNum
    rw [hmin, decode_scriptNumBytes n hn false]
  have hnneg : ¬ ((n : ScriptNum) < 0) := by simp
  have hne : scriptNumBytes n ≠ ByteArray.empty := scriptNumBytes_ne_empty n (by omega)
  have h75 : (scriptNumBytes n).size ≤ 75 := by
    have h4 : n < 256 ^ 4 := by
      have h256 : (256 : Nat) ^ 4 = 2 ^ 32 := by decide
      rw [h256]; omega
    have := scriptNumBytes_size_le n 4 h4
    omega
  have hszd : (scriptNumBytes n).size ≤ 96 := by
    have h4 : n < 256 ^ 4 := by
      have h256 : (256 : Nat) ^ 4 = 2 ^ 32 := by decide
      rw [h256]; omega
    have := scriptNumBytes_size_le n 4 h4
    omega
  have hnot : ¬ (96 < (scriptNumBytes n).size) := by omega
  have hdisj : ¬ ((scriptNumBytes n).size = 126 ∨ (scriptNumBytes n).size = 127 ∨ (scriptNumBytes n).size = 128 ∨ (scriptNumBytes n).size = 129 ∨
      (scriptNumBytes n).size = 131 ∨ (scriptNumBytes n).size = 132 ∨ (scriptNumBytes n).size = 133 ∨ (scriptNumBytes n).size = 134 ∨
      (scriptNumBytes n).size = 141 ∨ (scriptNumBytes n).size = 142 ∨ (scriptNumBytes n).size = 149 ∨ (scriptNumBytes n).size = 150 ∨
      (scriptNumBytes n).size = 151 ∨ (scriptNumBytes n).size = 152 ∨ (scriptNumBytes n).size = 153) := by omega
  have h520 : (scriptNumBytes n).size ≤ 520 := by omega
  have hsz5 : (scriptNumBytes n).size ≤ 5 := by
    have h4 : n < 256 ^ 4 := by
      have h256 : (256 : Nat) ^ 4 = 2 ^ 32 := by decide
      rw [h256]; omega
    have := scriptNumBytes_size_le n 4 h4
    omega
  have hlenbytes : (lenBytes (scriptNumBytes n).size).length = 1 := by
    cases h : (scriptNumBytes n).size with
    | zero => simp [lenBytes]
    | succ m =>
        have hm : m + 1 ≤ 75 := by omega
        simp [lenBytes, h, hm]
  have hpush : (pushBytesWire (scriptNumBytes n)).size ≤ 9999 := by
    unfold pushBytesWire
    simp [List.size_toByteArray, hlenbytes]
    omega
  have hlen : (serializeOpcodes [.pushBytes (scriptNumBytes n), .op ⟨0xb1, by omega⟩]).size ≤ 10000 := by
    simp [serializeOpcodes, serializeOpcode]
    exact hpush
  unfold evalScriptBytes
  rw [if_neg]
  · rw [parseWire_serializeOpcodes]
    · simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
        Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
        wireOfAst, checkMinimalPush, topAt, hmin, hcltv, hdef, hdec, hnneg, hne, h75, h520, hnot, hdisj,
        pushBoolV, vchTrue, disabledWire]
      rw [show (↑(177 : Fin 256) : Nat) = 177 from rfl]
      simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
        Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
        wireOfAst, checkMinimalPush, topAt, hmin, hcltv, hdef, hdec, hnneg, hne, h75, h520, hnot, hdisj, hdec,
        pushBoolV, vchTrue, disabledWire]
    · intro o ho
      simp only [List.mem_cons, List.mem_singleton, List.not_mem_nil, or_false] at ho
      rcases ho with rfl | rfl
      · simp [opcodeWF]
        exact h520
      · simp [opcodeWF]; omega
  · simp only [Bool.and_eq_true, not_and]
    intro _
    exact Nat.not_lt.mpr hlen


theorem eval_older_pushNum (n : Nat) (hn : n < 2^31) (hn16 : n ≤ 16) (hn1 : 1 ≤ n)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (hmin : pol.minimalData = false)
    (hcsv : flags.csv = true)
    (hdef : checkSequenceDef chk.env (n : ScriptNum) = true) :
    evalScriptBytes 8 flags pol (serializeOpcodes [.pushNum n, .op ⟨0xb2, by omega⟩])
      [] chk .witnessV0 ed = .ok [scriptNumBytes n] := by
  have hdec : decodeNum pol (scriptNumBytes n) 5 = .ok (n : ScriptNum) := by
    unfold decodeNum
    rw [hmin, decode_scriptNumBytes n hn false]
  have henc : encodeScriptNum (n : ScriptNum) false = scriptNumBytes n := by
    rw [scriptNumBytes_eq_encodeScriptNum n hn]
  have hn0 : n ≠ 0 := by omega
  have hnneg : ¬ ((n : ScriptNum) < 0) := by simp
  have hflag : ((n : ScriptNum).toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) = 0 := by
    simp [and_disable_flag_eq_zero n hn]
  have hnot : ¬ (96 < 80 + n) := by omega
  have hdisj : ¬ (80 + n = 126 ∨ 80 + n = 127 ∨ 80 + n = 128 ∨ 80 + n = 129 ∨
      80 + n = 131 ∨ 80 + n = 132 ∨ 80 + n = 133 ∨ 80 + n = 134 ∨
      80 + n = 141 ∨ 80 + n = 142 ∨ 80 + n = 149 ∨ 80 + n = 150 ∨
      80 + n = 151 ∨ 80 + n = 152 ∨ 80 + n = 153) := by omega
  have hlen : (serializeOpcodes [.pushNum n, .op ⟨0xb2, by omega⟩]).size ≤ 10000 := by
    simp [serializeOpcodes, serializeOpcode]
  unfold evalScriptBytes
  rw [if_neg]
  · rw [parseWire_serializeOpcodes]
    · simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
        Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
        wireOfAst, checkMinimalPush, topAt, hmin, hcsv, hdef, henc, hn0, hn16, hnneg, hnot, hdisj,
        pushBoolV, vchTrue, disabledWire]
      rw [show (↑(178 : Fin 256) : Nat) = 178 from rfl]
      simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
        Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
        wireOfAst, checkMinimalPush, topAt, hmin, hcsv, hdef, henc, hn0, hn16, hnneg, hnot, hdisj, hdec,
        pushBoolV, vchTrue, disabledWire]
    · intro o ho
      simp only [List.mem_cons, List.mem_singleton, List.not_mem_nil, or_false] at ho
      rcases ho with rfl | rfl
      · simp [opcodeWF]; omega
      · simp [opcodeWF]; omega
  · simp only [Bool.and_eq_true, not_and]
    intro _
    exact Nat.not_lt.mpr hlen


theorem eval_older_pushBytes (n : Nat) (hn : n < 2^31) (hn16 : ¬ n ≤ 16) (hn1 : 1 ≤ n)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (hmin : pol.minimalData = false)
    (hcsv : flags.csv = true)
    (hdef : checkSequenceDef chk.env (n : ScriptNum) = true) :
    evalScriptBytes 8 flags pol (serializeOpcodes [.pushBytes (scriptNumBytes n), .op ⟨0xb2, by omega⟩])
      [] chk .witnessV0 ed = .ok [scriptNumBytes n] := by
  have hdec : decodeNum pol (scriptNumBytes n) 5 = .ok (n : ScriptNum) := by
    unfold decodeNum
    rw [hmin, decode_scriptNumBytes n hn false]
  have hnneg : ¬ ((n : ScriptNum) < 0) := by simp
  have hflag : ((n : ScriptNum).toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) = 0 := by
    simp [and_disable_flag_eq_zero n hn]
  have hne : scriptNumBytes n ≠ ByteArray.empty := scriptNumBytes_ne_empty n (by omega)
  have h75 : (scriptNumBytes n).size ≤ 75 := by
    have h4 : n < 256 ^ 4 := by
      have h256 : (256 : Nat) ^ 4 = 2 ^ 32 := by decide
      rw [h256]; omega
    have := scriptNumBytes_size_le n 4 h4
    omega
  have hszd : (scriptNumBytes n).size ≤ 96 := by
    have h4 : n < 256 ^ 4 := by
      have h256 : (256 : Nat) ^ 4 = 2 ^ 32 := by decide
      rw [h256]; omega
    have := scriptNumBytes_size_le n 4 h4
    omega
  have hnot : ¬ (96 < (scriptNumBytes n).size) := by omega
  have hdisj : ¬ ((scriptNumBytes n).size = 126 ∨ (scriptNumBytes n).size = 127 ∨ (scriptNumBytes n).size = 128 ∨ (scriptNumBytes n).size = 129 ∨
      (scriptNumBytes n).size = 131 ∨ (scriptNumBytes n).size = 132 ∨ (scriptNumBytes n).size = 133 ∨ (scriptNumBytes n).size = 134 ∨
      (scriptNumBytes n).size = 141 ∨ (scriptNumBytes n).size = 142 ∨ (scriptNumBytes n).size = 149 ∨ (scriptNumBytes n).size = 150 ∨
      (scriptNumBytes n).size = 151 ∨ (scriptNumBytes n).size = 152 ∨ (scriptNumBytes n).size = 153) := by omega
  have h520 : (scriptNumBytes n).size ≤ 520 := by omega
  have hsz5 : (scriptNumBytes n).size ≤ 5 := by
    have h4 : n < 256 ^ 4 := by
      have h256 : (256 : Nat) ^ 4 = 2 ^ 32 := by decide
      rw [h256]; omega
    have := scriptNumBytes_size_le n 4 h4
    omega
  have hlenbytes : (lenBytes (scriptNumBytes n).size).length = 1 := by
    cases h : (scriptNumBytes n).size with
    | zero => simp [lenBytes]
    | succ m =>
        have hm : m + 1 ≤ 75 := by omega
        simp [lenBytes, h, hm]
  have hpush : (pushBytesWire (scriptNumBytes n)).size ≤ 9999 := by
    unfold pushBytesWire
    simp [List.size_toByteArray, hlenbytes]
    omega
  have hlen : (serializeOpcodes [.pushBytes (scriptNumBytes n), .op ⟨0xb2, by omega⟩]).size ≤ 10000 := by
    simp [serializeOpcodes, serializeOpcode]
    exact hpush
  unfold evalScriptBytes
  rw [if_neg]
  · rw [parseWire_serializeOpcodes]
    · simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
        Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
        wireOfAst, checkMinimalPush, topAt, hmin, hcsv, hdef, hdec, hnneg, hflag, hne, h75, h520, hnot, hdisj,
        pushBoolV, vchTrue, disabledWire]
      rw [show (↑(178 : Fin 256) : Nat) = 178 from rfl]
      simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, finalStack, wireOpsFrom,
        Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT, MAX_STACK_SIZE,
        wireOfAst, checkMinimalPush, topAt, hmin, hcsv, hdef, hdec, hnneg, hflag, hne, h75, h520, hnot, hdisj, hdec,
        pushBoolV, vchTrue, disabledWire]
    · intro o ho
      simp only [List.mem_cons, List.mem_singleton, List.not_mem_nil, or_false] at ho
      rcases ho with rfl | rfl
      · simp [opcodeWF]
        exact h520
      · simp [opcodeWF]; omega
  · simp only [Bool.and_eq_true, not_and]
    intro _
    exact Nat.not_lt.mpr hlen

/-- `toScript` of `after n` is the canonical serialization of
`<n> OP_CHECKLOCKTIMEVERIFY`. -/
theorem toScript_after (ctx : MiniscriptContext) (n : Nat) (hn : n < 2 ^ 31) :
    toScript ctx (.after n) =
      serializeOpcodes [pushIntOp n, .op ⟨0xb1, by omega⟩] := by
  unfold toScript
  simp only [toScriptWith]
  rw [pushInt_eq_serializeOpcode n hn, op_eq_serializeOpcode 0xb1 (by omega)]
  simp [serializeOpcodes]

/-- `toScript` of `older n` is the canonical serialization of
`<n> OP_CHECKSEQUENCEVERIFY`. -/
theorem toScript_older (ctx : MiniscriptContext) (n : Nat) (hn : n < 2 ^ 31) :
    toScript ctx (.older n) =
      serializeOpcodes [pushIntOp n, .op ⟨0xb2, by omega⟩] := by
  unfold toScript
  simp only [toScriptWith]
  rw [pushInt_eq_serializeOpcode n hn, op_eq_serializeOpcode 0xb2 (by omega)]
  simp [serializeOpcodes]

/-- The interpreter accepts `after n` on the empty witness whenever the
CLTV flag is on and the transaction satisfies the locktime. -/
theorem eval_after (n : Nat) (hn1 : 1 ≤ n) (hn : n < 2 ^ 31)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (hmin : pol.minimalData = false)
    (hcltv : flags.cltv = true)
    (hdef : checkLockTimeDef chk.env (n : ScriptNum) = true) :
    evalScriptBytes 8 flags pol (serializeOpcodes [pushIntOp n, .op ⟨0xb1, by omega⟩])
      [] chk .witnessV0 ed = .ok [scriptNumBytes n] := by
  have hn0 : n ≠ 0 := by omega
  by_cases h16 : n ≤ 16
  · simp only [pushIntOp, if_neg hn0, if_pos h16]
    exact eval_after_pushNum n hn h16 hn1 flags pol chk ed hmin hcltv hdef
  · simp only [pushIntOp, if_neg hn0, if_neg h16]
    exact eval_after_pushBytes n hn h16 hn1 flags pol chk ed hmin hcltv hdef

/-- The interpreter accepts `older n` on the empty witness whenever the
CSV flag is on and the transaction satisfies the relative locktime. -/
theorem eval_older (n : Nat) (hn1 : 1 ≤ n) (hn : n < 2 ^ 31)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (hmin : pol.minimalData = false)
    (hcsv : flags.csv = true)
    (hdef : checkSequenceDef chk.env (n : ScriptNum) = true) :
    evalScriptBytes 8 flags pol (serializeOpcodes [pushIntOp n, .op ⟨0xb2, by omega⟩])
      [] chk .witnessV0 ed = .ok [scriptNumBytes n] := by
  have hn0 : n ≠ 0 := by omega
  by_cases h16 : n ≤ 16
  · simp only [pushIntOp, if_neg hn0, if_pos h16]
    exact eval_older_pushNum n hn h16 hn1 flags pol chk ed hmin hcsv hdef
  · simp only [pushIntOp, if_neg hn0, if_neg h16]
    exact eval_older_pushBytes n hn h16 hn1 flags pol chk ed hmin hcsv hdef

/-! ## Witness acceptance bridge -/

theorem castToBool_scriptNumBytes (n : Nat) (hn1 : 1 ≤ n) (hn : n < 2 ^ 31) :
    castToBool (scriptNumBytes n) = true := by
  have h10 : n < 256 ^ 10 := by
    have h256 : (256 : Nat) ^ 10 = 2 ^ 80 := by decide
    rw [h256]; omega
  have hdigits : ∀ d ∈ (scriptNumBE (n : ScriptNum)).reverse, d < 256 :=
    fun d hd => scriptNumBE_digits_lt _ d (List.mem_reverse.mp hd)
  have hb : (bytesOf (encodeScriptNum (n : ScriptNum) false)).reverse = scriptNumBE (n : ScriptNum) := by
    unfold encodeScriptNum
    rw [bytesOf_bytesFromLE _ hdigits, List.reverse_reverse]
  rw [scriptNumBytes_eq_encodeScriptNum n hn]
  unfold castToBool
  rw [hb]
  have hdigits2 : ∀ d ∈ scriptNumBE (n : ScriptNum), d < 256 :=
    fun d hd => scriptNumBE_digits_lt _ d hd
  exact (castToBoolList_iff _ hdigits2).mpr (by
    rw [scriptNumBE_value n h10]
    omega)
theorem castToBool_vchTrue : castToBool vchTrue = true := by decide

theorem executeWitnessScript_ok_of_eval (fuel : Nat) (items : List ByteArray)
    (vwSer : Int) (exec : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (st : Stack)
    (hsize : ∀ d ∈ items, d.size ≤ 520)
    (heval : evalScriptBytes fuel flags pol exec items.reverse chk .witnessV0 default = .ok st)
    (hlen : st.length = 1) (htop : castToBool st[0]! = true) :
    executeWitnessScript fuel items vwSer exec flags pol chk .witnessV0 = .ok := by
  have hany : items.any (fun d => Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE < d.size) = false := by
    apply List.any_eq_false.mpr
    intro d hd
    have := hsize d hd
    have hlt : ¬ (Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE < d.size) := by
      simp only [Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE]
      omega
    simpa using hlt
  have h0 : st[0]! = st[0] := getElem!_pos st 0 (by omega)
  rw [h0] at htop
  simp [executeWitnessScript, executeWitnessScript.runExec, hany, heval, hlen, htop]

/-! ## Satisfaction lifting: `satisfy` witnesses are accepted -/

/-- `satisfy` for `c:pk_k key` produces exactly the singleton witness
`[sig]` when the satisfier signs `key`. -/
theorem satisfy_wrapC_pkK_eq (sf : Satisfier) (key sig : ByteArray)
    (hsign : sf.sign key = some sig) :
    satisfy sf (.wrapC (.pkK key)) = some [sig] := by
  simp [satisfy, produce, hsign]

/-- **P2PK soundness.**  If the satisfier signs the key, the witness stack
returned by `satisfy` for `c:pk_k key` is accepted by the consensus-model
interpreter at segwit v0, given the standard encoding/checker premises.

Not modeled: `Satisfier.sign` is abstract, so `hsign` is an explicit premise
that the signature really is a valid signature for the spending transaction
(the checker premise `hchk` is stated against the consensus checker). -/
theorem satisfy_wrapC_pkK_accepts (sf : Satisfier) (key sig : ByteArray)
    (ctx : MiniscriptContext) (hkey : key.size = 33)
    (hsign : sf.sign key = some sig) (hsigsz : sig.size ≤ 520)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (hmin : pol.minimalData = false)
    (henc : checkSigEncoding flags pol sig = none)
    (hpk : checkPubKeyEncoding flags pol .witnessV0 key = none)
    (hchk : (chk.base.checkECDSASignature sig key
      ((serializeOpcodes [.pushBytes key, .op ⟨0xac, by omega⟩]).extract 0
        (serializeOpcodes [.pushBytes key, .op ⟨0xac, by omega⟩]).size)
      .witnessV0 default) = true) :
    ∀ ws : List ByteArray, satisfy sf (.wrapC (.pkK key)) = some ws →
      executeWitnessScript 4 ws 0 (toScript ctx (.wrapC (.pkK key)))
        flags pol chk .witnessV0 = .ok := by
  intro ws hwit
  have hws : ws = [sig] := by
    rw [satisfy_wrapC_pkK_eq sf key sig hsign] at hwit
    exact (Option.some.inj hwit).symm
  subst hws
  have hkeyff : key.size ≤ 0xffff := by omega
  rw [toScript_wrapC_pkK ctx key hkeyff]
  exact executeWitnessScript_ok_of_eval 4 [sig] 0 _ flags pol chk [vchTrue]
    (by intro d hd; simp only [List.mem_singleton] at hd; subst hd; exact hsigsz)
    (by simpa using eval_wrapC_pkK key sig hkey flags pol chk default hmin henc hpk hchk)
    (by simp) castToBool_vchTrue

/-- `satisfy` for `c:pk_h key keyHash` produces `[sig, key]`. -/
theorem satisfy_wrapC_pkH_eq (sf : Satisfier) (key keyHash sig : ByteArray)
    (hsign : sf.sign key = some sig) :
    satisfy sf (.wrapC (.pkH key keyHash)) = some [sig, key] := by
  simp [satisfy, produce, hsign]

/-- **P2PKH soundness.**  The `satisfy` witness for `c:pk_h key keyHash` is
accepted by the interpreter when `keyHash` is the hash of `key` and the
signature checks against `key`.

Not modeled: as for P2PK, the satisfier's signature is an explicit premise,
and `hchk` must be discharged against the real transaction checker. -/
theorem satisfy_wrapC_pkH_accepts (sf : Satisfier) (key keyHash sig : ByteArray)
    (ctx : MiniscriptContext) (hkey : key.size = 33) (hkh : keyHash.size = 20)
    (hhash : hashHash160 key = keyHash)
    (hsign : sf.sign key = some sig) (hsigsz : sig.size ≤ 520)
    (hkeysz : key.size ≤ 520)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (hmin : pol.minimalData = false)
    (henc : checkSigEncoding flags pol sig = none)
    (hpk : checkPubKeyEncoding flags pol .witnessV0 key = none)
    (hchk : (chk.base.checkECDSASignature sig key
      ((serializeOpcodes [.op ⟨0x76, by omega⟩, .op ⟨0xa9, by omega⟩,
        .pushBytes keyHash, .op ⟨0x88, by omega⟩, .op ⟨0xac, by omega⟩]).extract 0
        (serializeOpcodes [.op ⟨0x76, by omega⟩, .op ⟨0xa9, by omega⟩,
          .pushBytes keyHash, .op ⟨0x88, by omega⟩, .op ⟨0xac, by omega⟩]).size)
      .witnessV0 default) = true) :
    ∀ ws : List ByteArray, satisfy sf (.wrapC (.pkH key keyHash)) = some ws →
      executeWitnessScript 8 ws 0 (toScript ctx (.wrapC (.pkH key keyHash)))
        flags pol chk .witnessV0 = .ok := by
  intro ws hwit
  have hws : ws = [sig, key] := by
    rw [satisfy_wrapC_pkH_eq sf key keyHash sig hsign] at hwit
    exact (Option.some.inj hwit).symm
  subst hws
  have hkhff : keyHash.size ≤ 0xffff := by omega
  rw [toScript_wrapC_pkH ctx key keyHash hkhff]
  exact executeWitnessScript_ok_of_eval 8 [sig, key] 0 _ flags pol chk [vchTrue]
    (by
      intro d hd
      simp only [List.mem_cons, List.mem_singleton, List.not_mem_nil, or_false] at hd
      rcases hd with rfl | rfl
      · exact hsigsz
      · exact hkeysz)
    (by simpa using eval_wrapC_pkH key keyHash sig hkey hkh hhash flags pol chk default hmin henc hpk hchk)
    (by simp) castToBool_vchTrue

/-- `satisfy` for a hash lock produces the singleton witness `[p]`. -/
theorem satisfy_hash_eq (sf : Satisfier) (node : Node) (p : ByteArray)
    (hproduce : produce sf node =
      (some [bytes (List.replicate 32 0)], some [p])) :
    satisfy sf node = some [p] := by
  unfold satisfy
  rw [hproduce]

/-- **Hash-lock soundness** (generic in `sha256`, `hash256`, `ripemd160`,
`hash160`).  If the satisfier supplies a preimage `p` whose hash matches the
lock, the `satisfy` witness is accepted.

Not modeled: only the preimage witness is proved; the satisfier is trusted to
return a preimage of the pinned 32-byte hash (`hproduce` supplies both the
32-byte canonical dissatisfaction and the preimage), and the digest size
premise is exactly what the interpreter's `OP_EQUAL` requires. -/
theorem satisfy_hash_accepts (sf : Satisfier) (h p digest : ByteArray) (w : Nat)
    (hw : w = 0xa8 ∨ w = 0xaa ∨ w = 0xa6 ∨ w = 0xa9)
    (node : Node) (ctx : MiniscriptContext)
    (hscript : toScript ctx node = serializeOpcodes
      [.op ⟨0x82, by omega⟩, .pushBytes (bytes [0x20]), .op ⟨0x88, by omega⟩,
       .op ⟨w, by omega⟩, .pushBytes digest, .op ⟨0x87, by omega⟩])
    (hproduce : produce sf node =
      (some [bytes (List.replicate 32 0)], some [p]))
    (hp : p.size = 32) (hhash : hashForOp w p = digest)
    (hd : digest.size = 32 ∨ digest.size = 20)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (hmin : pol.minimalData = false) :
    ∀ ws : List ByteArray, satisfy sf node = some ws →
      executeWitnessScript 10000 ws 0 (toScript ctx node) flags pol chk .witnessV0 = .ok := by
  intro ws hwit
  have hws : ws = [p] := by
    unfold satisfy at hwit
    rw [hproduce] at hwit
    exact (Option.some.inj hwit).symm
  subst hws
  rw [hscript]
  exact executeWitnessScript_ok_of_eval 10000 [p] 0 _ flags pol chk [vchTrue]
    (by intro d hd'; simp only [List.mem_singleton] at hd'; subst hd'; rw [hp]; omega)
    (by simpa using eval_hash w hw p digest hp hhash hd flags pol chk default hmin)
    (by simp) castToBool_vchTrue

/-! ### Hash-lock dissatisfaction checks

The canonical dissatisfaction of a hash fragment is Core's `ZERO32`, the
32-zero-byte vector (`src/script/miniscript.h:1359`).  The first example
checks that the corrected 32-byte value is the one `produce` actually
returns and that `satisfy_hash_eq` applies to it; the second checks that
the former four-byte value does not occur. -/

private theorem produce_sha256_fst_eq (sf : Satisfier) (h : ByteArray) :
    (produce sf (.sha256 h)).1 =
      some [bytes (List.replicate 32 0)] := by
  simp [produce]
  decide

example (sf : Satisfier) (h p : ByteArray)
    (hh : sf.satSHA256 h = some p) :
    satisfy sf (.sha256 h) = some [p] := by
  apply satisfy_hash_eq
  exact Prod.ext (produce_sha256_fst_eq sf h) (by simp [produce, hh])

example (sf : Satisfier) (h p : ByteArray) :
    produce sf (.sha256 h) ≠
      (some [bytes [0,0,0,0]], some [p]) := by
  intro hz
  have hfst := congrArg Prod.fst hz
  rw [produce_sha256_fst_eq] at hfst
  have hlist : [bytes (List.replicate 32 0)] =
      [bytes [0,0,0,0]] := Option.some.inj hfst
  have hb : bytes (List.replicate 32 0) = bytes [0,0,0,0] :=
    List.cons.inj hlist |>.1
  have hsz := congrArg ByteArray.size hb
  simp [bytes_size] at hsz

/-- `satisfy` for `after n` produces the empty witness when the checker
accepts the absolute locktime. -/
theorem satisfy_after_eq (sf : Satisfier) (n : Nat) (hcheck : sf.checkAfter n = true) :
    satisfy sf (.after n) = some [] := by
  simp [satisfy, produce, hcheck]

/-- **Absolute-timelock soundness.**  When `checkAfter` holds, the empty
`satisfy` witness for `after n` is accepted under `OP_CHECKLOCKTIMEVERIFY`.

Not modeled: `checkAfter` is the abstract satisfier predicate; `hdef` is the
consensus checker's locktime predicate, which must be supplied separately. -/
theorem satisfy_after_accepts (sf : Satisfier) (n : Nat) (ctx : MiniscriptContext)
    (hn1 : 1 ≤ n) (hn : n < 2 ^ 31) (hcheck : sf.checkAfter n = true)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (hmin : pol.minimalData = false) (hcltv : flags.cltv = true)
    (hdef : checkLockTimeDef chk.env (n : ScriptNum) = true) :
    ∀ ws : List ByteArray, satisfy sf (.after n) = some ws →
      executeWitnessScript 8 ws 0 (toScript ctx (.after n)) flags pol chk .witnessV0 = .ok := by
  intro ws hwit
  have hws : ws = [] := by
    rw [satisfy_after_eq sf n hcheck] at hwit
    exact (Option.some.inj hwit).symm
  subst hws
  rw [toScript_after ctx n hn]
  exact executeWitnessScript_ok_of_eval 8 [] 0 _ flags pol chk [scriptNumBytes n]
    (by intro d hd; simp at hd)
    (by simpa using eval_after n hn1 hn flags pol chk default hmin hcltv hdef)
    (by simp) (castToBool_scriptNumBytes n hn1 hn)

/-- `satisfy` for `older n` produces the empty witness when the checker
accepts the relative locktime. -/
theorem satisfy_older_eq (sf : Satisfier) (n : Nat) (hcheck : sf.checkOlder n = true) :
    satisfy sf (.older n) = some [] := by
  simp [satisfy, produce, hcheck]

/-- **Relative-timelock soundness.**  When `checkOlder` holds, the empty
`satisfy` witness for `older n` is accepted under `OP_CHECKSEQUENCEVERIFY`.

Not modeled: `checkOlder` is the abstract satisfier predicate; `hdef` is the
consensus relative-locktime predicate. -/
theorem satisfy_older_accepts (sf : Satisfier) (n : Nat) (ctx : MiniscriptContext)
    (hn1 : 1 ≤ n) (hn : n < 2 ^ 31) (hcheck : sf.checkOlder n = true)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (hmin : pol.minimalData = false) (hcsv : flags.csv = true)
    (hdef : checkSequenceDef chk.env (n : ScriptNum) = true) :
    ∀ ws : List ByteArray, satisfy sf (.older n) = some ws →
      executeWitnessScript 8 ws 0 (toScript ctx (.older n)) flags pol chk .witnessV0 = .ok := by
  intro ws hwit
  have hws : ws = [] := by
    rw [satisfy_older_eq sf n hcheck] at hwit
    exact (Option.some.inj hwit).symm
  subst hws
  rw [toScript_older ctx n hn]
  exact executeWitnessScript_ok_of_eval 8 [] 0 _ flags pol chk [scriptNumBytes n]
    (by intro d hd; simp at hd)
    (by simpa using eval_older n hn1 hn flags pol chk default hmin hcsv hdef)
    (by simp) (castToBool_scriptNumBytes n hn1 hn)

/-- **Named unproven obligation: the multisig interpreter bridge.**  For a
`multi` or `multi_a` fragment, if the satisfier returns a witness stack `ws`
(whose elements fit the 520-byte witness limit), then evaluating the
fragment's script on the reversed stack (bottom-first witness to machine
stack) at segwit v0 yields the singleton true stack.

This is *not* proved here.  The remaining gap is the `OP_CHECKMULTISIG`
dispatch bridge: the dummy-element quirk, the per-key ordered
signature/encoding checks in `cmsLoop`, and the `multi_a` vs `multi`
signature ordering.  Given this `Prop`, acceptance by
`executeWitnessScript` follows from the already-proved
`executeWitnessScript_ok_of_eval`.  All non-multisig fragments listed above
are proved without this bridge. -/
def MultisigEvalSound : Prop :=
  ∀ (sf : Satisfier) (k : Nat) (keys : List ByteArray) (node : Node)
    (ctx : MiniscriptContext) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ws : List ByteArray),
    (node = .multi k keys ∨ node = .multiA k keys) →
    satisfy sf node = some ws →
    (∀ d ∈ ws, d.size ≤ 520) →
    evalScriptBytes 10000 flags pol (toScript ctx node) ws.reverse chk .witnessV0
      default = .ok [vchTrue]

end BitcoinProofs.Wallet.MiniscriptInterp

