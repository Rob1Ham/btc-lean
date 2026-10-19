import Bitcoin.Script.Parser.Defs
import Bitcoin.Interpreter.Defs
import Bitcoin.Consensus.TxCheck

/-!
# Bitcoin.Interpreter.SigOps — the BIP141 sigop-cost model (the sigop model)

`GetTransactionSigOpCost` / `GetBlockSigOpCost` (tx_verify.cpp:149-168,
consensus.h:17 @`cce32b168`) as a pure model over parsed `WireOp`
stream and witness-program classification:

* **SWT-021** — the block limit: Σ sigop-cost ≤ `MAX_BLOCK_SIGOP_COST`
  = 80,000 per block (`blockSigOpCostOk`).
* **SWT-022** — legacy script sigops cost **×4** each (the pre-segwit
  scale factor; `sigOpCost` multiplies the legacy + P2SH terms by
  `WITNESS_SCALE_FACTOR`).
* **SWT-023** — the P2SH redeemScript's accurate count joins the ×4 term.
* **SWT-024** — witness-derived sigops cost **×1** (NOT ×4): the witness
  term enters `sigOpCost` unscaled.
* **SWT-025** — each P2WPKH (v0, 20-byte program) input counts exactly
  **1** witness sigop (`witnessSigOps`, interpreter.cpp:2136-2137).
* **SWT-026** — a v0 32-byte program counts the ACCURATE sigops of the
  last witness item (the witnessScript), interpreter.cpp:2139-2142.
* **SWT-027** — the P2SH-wrapped case: when the redeemScript (the
  scriptSig's last push) is itself a witness program, its witness sigops
  are counted (`p2shWitnessSigOps`, interpreter.cpp:2162-2173).
* **SWT-028** — witness versions ≥ 1 (Taproot and beyond) contribute
  **0** block sigops (interpreter.cpp:2133-2147 falls through).

The accurate per-script count (`accurateSigOpCount`) is Core
`CScript::GetSigOpCount(true)`: each CHECKSIG/CHECKSIGVERIFY is 1; each
CHECKMULTISIG/CHECKMULTISIGVERIFY is the preceding OP_1..OP_16 push's
value when present, else `MAX_PUBKEYS_PER_MULTISIG` (20). The count is a
MODEL of the interpreter's CHECKSIG/CHECKMULTISIG sites, not a second
interpreter: the executed sites live in `stepBody` (SCR-* rows); this
module exists for the block-cost arithmetic (BLK-level), which Core
computes statically from the scripts.

Everything is `Nat`/`List`/`ByteArray` arithmetic — sorry-free by
construction (no `sorry`, no `native_decide`).
-/

namespace Bitcoin.Interpreter.SigOps

open Bitcoin.Interpreter Bitcoin.Script.Parser

/-- `MAX_BLOCK_SIGOP_COST` (consensus.h:17): 80,000 cost units/block. -/
@[rule "SWT-021"]
def MAX_BLOCK_SIGOP_COST : Nat := 80000

/-- Cost multiplier for non-witness (legacy + P2SH) sigops:
`WITNESS_SCALE_FACTOR` (tx_verify.cpp:151,158 — `*(WITNESS_SCALE_FACTOR)`). -/
def LEGACY_SIGOP_SCALE : Nat := 4

/-- The wire bytes of the four signature-checking opcodes. -/
def isCheckSigWire (w : Nat) : Bool := w = 0xac ∨ w = 0xad
def isCheckMultiSigWire (w : Nat) : Bool := w = 0xae ∨ w = 0xaf

/-- `DecodeOP_N` for the accurate multisig count: only an OP_1..OP_16
pushNum (Core checks the opcode RANGE, so OP_0/OP_1NEGATE do not count —
an inaccurate preceding push falls back to `MAX_PUBKEYS_PER_MULTISIG`). -/
def opNumberOf (o : Opcode) : Option Nat :=
  match o with
  | .pushNum n => if 1 ≤ n ∧ n ≤ 16 then some n else none
  | _ => none

/-- One step of the accurate count: the sigop contribution of `op` given
the preceding opcode (interpreter.cpp's `GetSigOpCount(true)` loop). -/
def sigOpStep (prev : Option Opcode) (op : WireOp) : Nat :=
  if isCheckSigWire op.wire then 1
  else if isCheckMultiSigWire op.wire then
    match prev >>= opNumberOf with
    | some n => n
    | none => MAX_PUBKEYS_PER_MULTISIG
  else 0

/-- `CScript::GetSigOpCount(true)` over a parsed wire-op stream; `prev`
is the previous opcode (the multisig lookback). -/
@[rule "SWT-022"]
def accurateSigOpCountFrom : Option Opcode → List WireOp → Nat
  | _, [] => 0
  | prev, op :: rest =>
    sigOpStep prev op + accurateSigOpCountFrom (some op.ast) rest

/-- The entry point (no lookback before the first opcode). -/
@[rule "SWT-022"]
def accurateSigOpCount (ops : List WireOp) : Nat :=
  accurateSigOpCountFrom none ops

/-- Inaccurate mode always charges twenty for CHECKMULTISIG, regardless
of the preceding opcode. -/
def inaccurateSigOpCount : List WireOp → Nat
  | [] => 0
  | op :: rest =>
    (if isCheckSigWire op.wire then 1
     else if isCheckMultiSigWire op.wire then MAX_PUBKEYS_PER_MULTISIG else 0)
      + inaccurateSigOpCount rest

/-- Both static counting modes, shared by the interpreter rule layer. -/
def sigOpCount (ops : List WireOp) (accurate : Bool) : Nat :=
  if accurate then accurateSigOpCount ops else inaccurateSigOpCount ops

/-- `GetOp` restricted to pushes Core's static sigop counter accepts.
`MAX_SCRIPT_ELEMENT_SIZE` is 520 (`script.h`): a PUSHDATA2/PUSHDATA4
payload beyond it is not a valid opcode for `GetSigOpCount`, so the
counting walk stops there. EvalScript's all-or-nothing `parseWire` keeps
the permissive `getOp` (the interpreter rejects an oversized push with
PUSH_SIZE, SCR-046). -/
def getOpCount (b : ByteArray) (i : Nat) : Option (Opcode × Nat) :=
  match getOp b i with
  | none => none
  | some (o, i') =>
    match o with
    | .pushBytes d =>
      if d.size ≤ Bitcoin.Script.Parser.MAX_SCRIPT_ELEMENT_SIZE
      then some (o, i') else none
    | _ => some (o, i')

/-- A size-bounded `GetOp` is the plain `GetOp` whenever the decoded
opcode is well-formed (in particular every push payload is ≤ 520). -/
theorem getOpCount_eq_getOp_of_opcodeWF {b : ByteArray} {i : Nat}
    {o : Opcode} {i' : Nat} (h : getOp b i = some (o, i'))
    (ho : opcodeWF o) : getOpCount b i = some (o, i') := by
  unfold getOpCount
  rw [h]
  cases o with
  | pushBytes d => simpa [opcodeWF] using ho
  | pushNum n => rfl
  | op c => rfl

/-- Core's `GetOp` loop stops at the first malformed or oversized push
and retains the already parsed prefix. Unlike EvalScript's parser, this
is not all-or-nothing. -/
def parseWirePrefixFrom : Nat → ByteArray → Nat → List WireOp
  | 0, _, _ => []
  | f+1, b, i =>
    if b.size ≤ i then []
    else match getOpCount b i with
      | none => []
      | some (o, i') =>
        { ast := o, wire := b[i]!.toNat, next := i' } :: parseWirePrefixFrom f b i'

def parseWirePrefix (b : ByteArray) : List WireOp :=
  parseWirePrefixFrom (b.size + 1) b 0

/-- A successful size-bounded decode advances at least one byte and
stays inside the script. -/
theorem getOpCount_spec {b : ByteArray} {i : Nat} {o : Opcode} {i' : Nat}
    (h : getOpCount b i = some (o, i')) :
    i < i' ∧ i' ≤ b.size := by
  unfold getOpCount at h
  cases hg : getOp b i with
  | none => simp [hg] at h
  | some p =>
    rcases p with ⟨o₀, j⟩
    have hj := getOp_spec hg
    cases o₀ with
    | pushBytes d =>
      simp only [hg] at h
      split at h
      · simp only [Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        exact ⟨hj.1, hj.2.1⟩
      · simp at h
    | pushNum n =>
      simp only [hg, Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      exact ⟨hj.1, hj.2.1⟩
    | op c =>
      simp only [hg, Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      exact ⟨hj.1, hj.2.1⟩

theorem parseWirePrefixFrom_length_le (f : Nat) (b : ByteArray) (i : Nat) :
    (parseWirePrefixFrom f b i).length ≤ b.size - i := by
  induction f generalizing i with
  | zero => simp [parseWirePrefixFrom]
  | succ f ih =>
    by_cases hi : b.size ≤ i
    · simp [parseWirePrefixFrom, hi]
    · cases hg : getOpCount b i with
      | none => simp [parseWirePrefixFrom, hi, hg]
      | some pair =>
        rcases pair with ⟨o, j⟩
        have hj := getOpCount_spec hg
        have ht := ih j
        simp only [parseWirePrefixFrom, hi, ↓reduceIte, hg, List.length_cons]
        omega

theorem inaccurateSigOpCount_le (ops : List WireOp) :
    inaccurateSigOpCount ops ≤ 20 * ops.length := by
  induction ops with
  | nil => simp [inaccurateSigOpCount]
  | cons o rest ih =>
    simp only [inaccurateSigOpCount, List.length_cons, Nat.mul_add, Nat.mul_one]
    split <;> (try split) <;> (try simp only [MAX_PUBKEYS_PER_MULTISIG]) <;> omega

/-- Every opcode in the list is well-formed, hence every push payload
is at most `MAX_SCRIPT_ELEMENT_SIZE`. -/
def WireOpsWithinLimit (ops : List WireOp) : Prop :=
  ∀ w ∈ ops, opcodeWF w.ast

theorem parseWirePrefixFrom_of_parse (f : Nat) (b : ByteArray) (i : Nat)
    (ops : List WireOp) (h : parseWireFrom f b i = some ops)
    (hall : WireOpsWithinLimit ops) :
    parseWirePrefixFrom f b i = ops := by
  induction f generalizing i ops with
  | zero => simp [parseWireFrom] at h
  | succ f ih =>
    by_cases hi : b.size ≤ i
    · simpa [parseWireFrom, parseWirePrefixFrom, hi] using h.symm
    · cases hg : getOp b i with
      | none => simp [parseWireFrom, hi, hg] at h
      | some pair =>
        rcases pair with ⟨o, j⟩
        cases ht : parseWireFrom f b j with
        | none => simp [parseWireFrom, hi, hg, ht] at h
        | some tail =>
          simp only [parseWireFrom, hi, ↓reduceIte, hg, ht, Option.map_some,
            Option.some.injEq] at h
          have hwmem : ({ ast := o, wire := b[i]!.toNat, next := j } : WireOp) ∈ ops := by
            rw [← h]; simp
          have ho : opcodeWF o := hall _ hwmem
          have htail : WireOpsWithinLimit tail :=
            fun w hw => hall w (by rw [← h]; simp [hw])
          simpa [parseWirePrefixFrom, hi,
            getOpCount_eq_getOp_of_opcodeWF hg ho,
            ih j tail ht htail] using h

@[simp] theorem parseWirePrefix_of_parse (b : ByteArray) (ops : List WireOp)
    (h : parseWire b = some ops) (hall : WireOpsWithinLimit ops) :
    parseWirePrefix b = ops :=
  parseWirePrefixFrom_of_parse (b.size + 1) b 0 ops h hall

/-- Raw-script counter: malformed pushes terminate the loop, preserving
the count of preceding opcodes. Static counting does not execute a script. -/
def scriptSigOpCount (script : ByteArray) (accurate : Bool) : Nat :=
  sigOpCount (parseWirePrefix script) accurate

theorem scriptSigOpCount_inaccurate_le (b : ByteArray) :
    scriptSigOpCount b false ≤ 20 * b.size := by
  have hl := parseWirePrefixFrom_length_le (b.size+1) b 0
  have hc := inaccurateSigOpCount_le (parseWirePrefix b)
  have hm := Nat.mul_le_mul_left 20 hl
  simpa [scriptSigOpCount, sigOpCount, parseWirePrefix] using Nat.le_trans hc hm

/-- **SWT-026/022**: accurate counting of the witnessScript's valid
prefix. The walk uses the 520-byte-bounded `getOpCount`, so an oversized
PUSHDATA2/PUSHDATA4 terminates the count exactly where Core's
`GetScriptOp`/`GetSigOpCount` stops. -/
@[rule "SWT-026"]
def witnessScriptSigOps (script : ByteArray) : Nat :=
  scriptSigOpCount script true

/-- Core's `CScript::GetSigOpCount(true)` rendering: the accurate count
over the size-bounded `GetOp` prefix walk. -/
@[rule "SWT-026"]
def coreSigOpCount (script : ByteArray) : Nat :=
  accurateSigOpCount (parseWirePrefix script)

@[rule "SWT-026"]
theorem witnessScriptSigOps_eq_coreSigOpCount (script : ByteArray) :
    witnessScriptSigOps script = coreSigOpCount script := rfl

/-- The size-bounded counting decode rejects an oversized push outright. -/
@[rule "SWT-026"]
theorem getOpCount_oversize_push {b : ByteArray} {i : Nat} {d : ByteArray}
    {j : Nat} (hg : getOp b i = some (Opcode.pushBytes d, j))
    (hd : Bitcoin.Script.Parser.MAX_SCRIPT_ELEMENT_SIZE < d.size) :
    getOpCount b i = none := by
  unfold getOpCount
  rw [hg]
  simp [hd]

/-- The permissive parser decodes a canonical oversized push
(PUSHDATA2, 521..65535 bytes) to the full payload. This is the decode
that `getOpCount` then rejects, unlike EvalScript's later `PUSH_SIZE`
failure. -/
private theorem getOp_pushBytesWire_oversize (d post : ByteArray)
    (hd : Bitcoin.Script.Parser.MAX_SCRIPT_ELEMENT_SIZE < d.size)
    (hhi : d.size ≤ 0xffff) :
    getOp (Bitcoin.Script.Parser.pushBytesWire d ++ post) 0 =
      some (Opcode.pushBytes d, (Bitcoin.Script.Parser.pushBytesWire d).size) := by
  unfold Bitcoin.Script.Parser.pushBytesWire
  rw [ByteArray.append_assoc]
  have hM : Bitcoin.Script.Parser.MAX_SCRIPT_ELEMENT_SIZE = 520 := rfl
  rw [hM] at hd
  cases heq0 : d.size with
  | zero => omega
  | succ m =>
    simp only [Bitcoin.Script.Parser.lenBytes]
    rw [if_neg (by omega), if_neg (by omega), if_pos (by omega)]
    have hA : (List.toByteArray [(0x4d : UInt8), (((m+1) % 256 : Nat).toUInt8),
        (((m+1) / 256 : Nat).toUInt8)]).size = 3 := by
      simp [List.size_toByteArray]
    rw [Bitcoin.Script.Parser.getOp_toByteArray_cons0]
    have hs : (0+1) + 2 ≤ (List.toByteArray [(0x4d : UInt8),
        (((m+1) % 256 : Nat).toUInt8),
        (((m+1) / 256 : Nat).toUInt8)] ++ (d ++ post)).size := by
      rw [ByteArray.size_append, ByteArray.size_append, hA]; omega
    have hle : Bitcoin.Script.Parser.leOfBytes
        (Bitcoin.Script.Parser.slice (List.toByteArray [(0x4d : UInt8),
          (((m+1) % 256 : Nat).toUInt8),
          (((m+1) / 256 : Nat).toUInt8)] ++ (d ++ post)) 1 2) = m + 1 := by
      rw [Bitcoin.Script.Parser.slice,
          Bitcoin.Script.Parser.extract_head _ (d ++ post) 1 3 (by omega)
            (by rw [hA]; omega),
          Bitcoin.Script.Parser.toByteArray_tail3,
          Bitcoin.Script.Parser.leOfBytes_two,
          show ((((m+1) % 256 : Nat).toUInt8).toNat) = ((m+1) % 256 : Nat) from by
            simp only [Bitcoin.Script.Parser.toUInt8_toNat]; omega,
          show ((((m+1) / 256 : Nat).toUInt8).toNat) = ((m+1) / 256 : Nat) from by
            simp only [Bitcoin.Script.Parser.toUInt8_toNat]; omega]
      omega
    have hr : Bitcoin.Script.Parser.readLE (List.toByteArray [(0x4d : UInt8),
        (((m+1) % 256 : Nat).toUInt8),
        (((m+1) / 256 : Nat).toUInt8)] ++ (d ++ post)) (0+1) 2 = some (m+1) :=
      Bitcoin.Script.Parser.readLE_some _ 1 2 (m+1) hs hle
    have hd' : Bitcoin.Script.Parser.sliceOpt (List.toByteArray [(0x4d : UInt8),
        (((m+1) % 256 : Nat).toUInt8),
        (((m+1) / 256 : Nat).toUInt8)] ++ (d ++ post)) (0+3) (m+1) = some d := by
      rw [Bitcoin.Script.Parser.sliceOpt_payload _ d post 3 (m+1) hA heq0
        (by rw [ByteArray.size_append, ByteArray.size_append, hA]; omega)]
    rw [Bitcoin.Script.Parser.getOpAux_pd2 _ 0 _ (m+1) d rfl hr hd']
    simp [hA, heq0, ByteArray.size_append]

/-- A script whose FIRST opcode is a push larger than 520 bytes is not
counted at all: the bounded walk stops before it and the accurate count
is zero (Core's `GetSigOpCount` valid-prefix behaviour). -/
@[rule "SWT-026"]
theorem coreSigOpCount_oversize_push_head (d post : ByteArray)
    (hd : Bitcoin.Script.Parser.MAX_SCRIPT_ELEMENT_SIZE < d.size)
    (hhi : d.size ≤ 0xffff) :
    coreSigOpCount (Bitcoin.Script.Parser.pushBytesWire d ++ post) = 0 := by
  have hg := getOp_pushBytesWire_oversize d post hd hhi
  have hc : getOpCount (Bitcoin.Script.Parser.pushBytesWire d ++ post) 0 = none :=
    getOpCount_oversize_push hg hd
  have hpos : 0 < (Bitcoin.Script.Parser.pushBytesWire d ++ post).size := by
    have h1 := Bitcoin.Script.Parser.serializeOpcode_size (Opcode.pushBytes d)
    have h1' : 0 < (Bitcoin.Script.Parser.pushBytesWire d).size := by
      have h1'' : 1 ≤ (Bitcoin.Script.Parser.pushBytesWire d).size := by
        simpa [Bitcoin.Script.Parser.serializeOpcode] using h1
      exact Nat.lt_of_lt_of_le Nat.zero_lt_one h1''
    rw [ByteArray.size_append]; omega
  unfold coreSigOpCount parseWirePrefix
  rw [parseWirePrefixFrom]
  rw [if_neg (by omega)]
  rw [hc]
  rfl

@[simp] theorem witnessScriptSigOps_of_parse (b : ByteArray) (ops : List WireOp)
    (h : parseWire b = some ops) (hall : WireOpsWithinLimit ops) :
    witnessScriptSigOps b = accurateSigOpCount ops := by
  simp [witnessScriptSigOps, scriptSigOpCount, sigOpCount,
    parseWirePrefix_of_parse b ops h hall]

/-- The final GetOp data register, only when the entire scriptSig parses
and every opcode is at most OP_16. Small integers/OP_RESERVED clear it. -/
def pushOnlyLastData (scriptSig : ByteArray) : Option ByteArray :=
  match parseWire scriptSig with
  | none => none
  | some ops =>
    if isPushOnlyWire ops then
      match ops.getLast? with
      | none => none
      | some op => some (match op.ast with
          | .pushBytes d => d
          | _ => ByteArray.empty)
    else none

def p2shScriptSigOps (scriptSig : ByteArray) : Nat :=
  match pushOnlyLastData scriptSig with
  | none => 0
  | some d => witnessScriptSigOps d

/-- `WitnessSigOps` (interpreter.cpp:2133-2147): the witness sigops of
one input with witness program `(version, program)` and stack `witness`.
SWT-025: v0-20 → 1. SWT-026: v0-32 → accurate count of the LAST item.
SWT-028: version ≥ 1 → 0 (Taproot/v1+ contribute no block sigops). -/
@[rule "SWT-025", rule "SWT-026", rule "SWT-028", rule "INV-037", rule "TPR-069"]
def witnessSigOps (version : Nat) (program : ByteArray)
    (witness : List ByteArray) : Nat :=
  if version = 0 then
    if program.size = 20 then 1
    else if program.size = 32 then
      match witness.getLast? with
      | some script => witnessScriptSigOps script
      | none => 0
    else 0
  else 0

/-- **SWT-027**: `CountWitnessSigOps` (interpreter.cpp:2162-2173) — when
the P2SH redeemScript (the scriptSig's last push) is itself a witness
program, its witness sigops count (×1, joining the witness term); when
the scriptSig is not push-only or has no pushes, 0. -/
@[rule "SWT-027"]
def p2shWitnessSigOps (scriptSig : ByteArray) (witness : List ByteArray) : Nat :=
  match pushOnlyLastData scriptSig with
  | none => 0
  | some d =>
    match isWitnessProgram d with
    | some (v, prog) => witnessSigOps v prog witness
    | none => 0

/-- The per-input sigop decomposition (`GetTransactionSigOpCost`'s three
terms, tx_verify.cpp:149-166). -/
structure InputSigOps where
  legacy : Nat          -- scriptSig + scriptPubKey static count
  p2sh : Nat            -- accurate redeemScript count (P2SH inputs only)
  witness : Nat         -- witnessSigOps (×1)
deriving Repr, DecidableEq

/-- **SWT-022/023/024**: the input's cost — legacy and P2SH counts
×`LEGACY_SIGOP_SCALE`, the witness count ×1. -/
@[rule "SWT-022", rule "SWT-023", rule "SWT-024", rule "INV-038"]
def sigOpCost (s : InputSigOps) : Nat :=
  LEGACY_SIGOP_SCALE * (s.legacy + s.p2sh) + s.witness

/-- **SWT-021**: the block sigop cost = Σ per-input costs
(`GetBlockSigOpCost`), with the 80,000 gate (`blockSigOpCostOk`). -/
@[rule "SWT-021"]
def blockSigOpCost (inputs : List InputSigOps) : Nat :=
  inputs.foldl (fun acc s => acc + sigOpCost s) 0

@[rule "INV-039"]
def blockSigOpCostOk (inputs : List InputSigOps) : Bool :=
  blockSigOpCost inputs ≤ MAX_BLOCK_SIGOP_COST

/-! ## Structural laws (all rfl/omega-level; the proof-side pins with
axiom fingerprints live in BitcoinProofs.Theorems.WitnessRulesCor) -/

theorem sigOpCost_eq (s : InputSigOps) :
    sigOpCost s = 4 * (s.legacy + s.p2sh) + s.witness := rfl

/-- The witness term is NOT multiplied by 4: raising the witness count by
1 raises the cost by exactly 1 (SWT-024). -/
theorem sigOpCost_witness_scale_one (s : InputSigOps) :
    sigOpCost { s with witness := s.witness + 1 } = sigOpCost s + 1 := by
  simp [sigOpCost]
  omega

theorem blockSigOpCostOk_iff (inputs : List InputSigOps) :
    blockSigOpCostOk inputs = true ↔ blockSigOpCost inputs ≤ MAX_BLOCK_SIGOP_COST := by
  simp [blockSigOpCostOk]

/-- INV-038 (tx_verify.cpp:151,158): the legacy count enters the cost
multiplied by `WITNESS_SCALE_FACTOR = 4` — the same ×4 applies to the
P2SH term, while the witness term is unscaled.  The coefficient is also
pinned operationally: adding one legacy sigop adds exactly 4 cost units. -/
@[rule "INV-038"] theorem sigOpCost_legacy_scaled (s : InputSigOps) :
    sigOpCost s =
      Bitcoin.Consensus.WITNESS_SCALE_FACTOR * s.legacy +
      Bitcoin.Consensus.WITNESS_SCALE_FACTOR * s.p2sh + s.witness ∧
    Bitcoin.Consensus.WITNESS_SCALE_FACTOR = 4 ∧
    sigOpCost { s with legacy := s.legacy + 1 } = sigOpCost s + 4 := by
  refine ⟨?_, rfl, ?_⟩
  · rw [sigOpCost_eq]
    simp only [Bitcoin.Consensus.WITNESS_SCALE_FACTOR, Nat.mul_add]
  · have hlhs : sigOpCost { s with legacy := s.legacy + 1 }
        = 4 * ((s.legacy + 1) + s.p2sh) + s.witness := rfl
    have hrhs : sigOpCost s = 4 * (s.legacy + s.p2sh) + s.witness := rfl
    rw [hlhs, hrhs]
    have h : (s.legacy + 1) + s.p2sh = (s.legacy + s.p2sh) + 1 := by omega
    rw [h, Nat.mul_add, Nat.mul_one, Nat.mul_add]
    omega

/-- `blockSigOpCost` is exactly the running sum of the per-input costs
(the fold seeded at 0; `GetBlockSigOpCost` accumulates `nSigOpsCost` over
the tx's inputs). -/
private theorem foldl_sigop_eq_sum (l : List InputSigOps) (init : Nat) :
    l.foldl (fun acc s => acc + sigOpCost s) init
      = init + (l.map sigOpCost).sum := by
  induction l generalizing init with
  | nil => simp
  | cons s rest ih =>
    simp only [List.foldl_cons, List.map_cons, List.sum_cons]
    rw [ih (init + sigOpCost s)]
    omega

/-- INV-039 (validation.cpp:ConnectBlock:2566-2570): the block sigop cost
is the running sum of the per-input costs. -/
@[rule "INV-039"] theorem blockSigOpCost_eq_sum (inputs : List InputSigOps) :
    blockSigOpCost inputs = (inputs.map sigOpCost).sum := by
  unfold blockSigOpCost
  rw [foldl_sigop_eq_sum]
  simp

/-- INV-039 (validation.cpp:ConnectBlock:2566-2570): the block gate is the
EXACT `nSigOpsCost > MAX_BLOCK_SIGOP_COST` test — accepted iff the running
cost is at most 80,000, rejected iff it is strictly above. -/
@[rule "INV-039"] theorem blockSigOpCost_gate (inputs : List InputSigOps) :
    (blockSigOpCostOk inputs = true ↔ blockSigOpCost inputs ≤ 80000) ∧
    (blockSigOpCostOk inputs = false ↔ 80000 < blockSigOpCost inputs) := by
  constructor
  · rw [blockSigOpCostOk_iff, MAX_BLOCK_SIGOP_COST]
  · unfold blockSigOpCostOk MAX_BLOCK_SIGOP_COST
    by_cases h : blockSigOpCost inputs ≤ 80000
    · simp [h]
    · simp [h]
      omega

private theorem foldl_sigop_add_init (l : List InputSigOps) (init : Nat) :
    l.foldl (fun acc s => acc + sigOpCost s) init
      = init + l.foldl (fun acc s => acc + sigOpCost s) 0 := by
  induction l generalizing init with
  | nil => simp
  | cons s rest ih =>
    simp only [List.foldl_cons]
    rw [ih (init + sigOpCost s), Nat.zero_add, ih (sigOpCost s)]
    omega

/-- Cost is monotone under appending inputs (the block gate composes). -/
theorem blockSigOpCost_append (a b : List InputSigOps) :
    blockSigOpCost (a ++ b) = blockSigOpCost a + blockSigOpCost b := by
  unfold blockSigOpCost
  rw [List.foldl_append, foldl_sigop_add_init]

/-- SWT-025 (definitional): a v0 20-byte program counts exactly 1. -/
theorem witnessSigOps_p2wpkh (program : ByteArray) (witness : List ByteArray)
    (h : program.size = 20) :
    witnessSigOps 0 program witness = 1 := by
  unfold witnessSigOps
  rw [if_pos rfl, if_pos h]

/-- SWT-028 (definitional): witness versions ≥ 1 contribute 0. -/
theorem witnessSigOps_future_zero (v : Nat) (program : ByteArray)
    (witness : List ByteArray) (hv : 1 ≤ v) :
    witnessSigOps v program witness = 0 := by
  unfold witnessSigOps
  rw [if_neg (by omega)]

/-- SWT-026 (definitional): v0-32 counts the last witness item; an empty
witness stack counts 0 (Core's `witness.back()` on an empty stack is
guarded upstream — here the model is total). -/
theorem witnessSigOps_p2wsh (program : ByteArray) (witness : List ByteArray)
    (h : program.size = 32) :
    witnessSigOps 0 program witness =
      (match witness.getLast? with
       | some script => witnessScriptSigOps script
       | none => 0) := by
  unfold witnessSigOps
  rw [if_pos rfl, if_neg (by intro hc; rw [h] at hc; simp at hc), if_pos h]

end Bitcoin.Interpreter.SigOps
