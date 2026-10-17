import Bitcoin.Script.Parser.Defs
import Bitcoin.Interpreter.Defs
import Bitcoin.Consensus.TxCheck

/-!
# Bitcoin.Interpreter.SigOps — the BIP141 sigop-cost model (X05)

`GetTransactionSigOpCost` / `GetBlockSigOpCost` (tx_verify.cpp:149-168,
consensus.h:17 @`cce32b168`) as a pure model over W05's parsed `WireOp`
stream and W09's witness-program classification:

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

/-- **SWT-026/022 core counter**: sigops of a witness script, parsed from
wire bytes (0 when the parse fails — Core's `GetSigOpCount(true, …)` on
an unparseable witnessScript; the 10,000-byte gate is upstream). -/
@[rule "SWT-026"]
def witnessScriptSigOps (script : ByteArray) : Nat :=
  match parseWire script with
  | none => 0
  | some ops => accurateSigOpCount ops

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
  match parseWire scriptSig with
  | none => 0
  | some ops =>
    match ops.getLast? with
    | some op =>
      match isWitnessProgram (match op.ast with
        | .pushBytes d => d
        | _ => ByteArray.empty) with
      | some (v, prog) => witnessSigOps v prog witness
      | none => 0
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
