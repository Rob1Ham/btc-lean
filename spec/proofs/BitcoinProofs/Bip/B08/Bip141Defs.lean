/-
BitcoinProofs.Bip.B08.Bip141Defs — BIP141 (SegWit, consensus layer) clause models.

B08 Review-5 support suite, 2026-10-16. Ground truth: BIP141.mediawiki
(public domain) fetched from bitcoin/bips master; Core @ cce32b168 for the
witness-merkle shape (merkle.cpp:BlockWitnessMerkleRoot) and the BIP9
segwit deployment constants (deploymentinfo.cpp: threshold 1916).

Every definition here is pure, computable, axiom-free. The Double-SHA256
combine of the witness merkle is injected as `combine` (a documented seam);
its byte-level behaviour is cross-checked in python3
(scratch/B08/bip141_xcheck.py) against hashlib, mirroring Core's
MerkleComputation (odd count duplicates the last leaf).
-/

namespace BitcoinProofs.Bip.B08

/-! ## C3 — Witness program grammar ("Witness program" section)

A scriptPubKey (or BIP16 redeemScript) of exactly: one version byte
(`0x00` or `0x51..0x60`), one length byte `L` with `2 ≤ L ≤ 40`, and `L`
program bytes. -/

def isVersionByte (b : Nat) : Bool :=
  b == 0 || (decide (0x51 ≤ b) && decide (b ≤ 0x60))

/-- OP_0 → version 0; OP_1 (0x51) → 1; ... OP_16 (0x60) → 16. -/
def versionOf (b : Nat) : Nat := if b = 0 then 0 else b - 0x50

def parseWitnessProgram (s : List Nat) : Option (Nat × List Nat) :=
  match s with
  | vb :: l :: prog =>
      if isVersionByte vb && decide (2 ≤ l) && decide (l ≤ 40)
         && decide (prog.length = l) then
        some (versionOf vb, prog)
      else none
  | _ => none

/-! ## C8 — v0 program size dispatch (20 → P2WPKH, 32 → P2WSH, else fail) -/

inductive WitKind where
  | p2wpkh | p2wsh | invalidV0Size | future (v : Nat)
deriving Repr, DecidableEq

def dispatchProgram (v : Nat) (prog : List Nat) : WitKind :=
  if v = 0 then
    if prog.length = 20 then .p2wpkh
    else if prog.length = 32 then .p2wsh
    else .invalidV0Size
  else .future v

/-- BIP141 footnote (consensus): for any version byte 0..16 the script must
fail if the witness program's `CastToBool` value is zero. -/
def castToBool (bytes : List Nat) : Bool := bytes.any (· != 0)

def programMustFailCastToBool (v : Nat) (prog : List Nat) : Bool :=
  decide (v ≤ 16) && !castToBool prog

/-! ## C6/C7 — v0 witness stack shape clauses -/

def MAX_SCRIPT_ELEMENT_SIZE : Nat := 520
def MAX_WITNESS_SCRIPT_SIZE : Nat := 10000

def witnessItemSizeOk (item : List Nat) : Bool :=
  decide (item.length ≤ MAX_SCRIPT_ELEMENT_SIZE)

/-- P2WPKH: witness must be exactly 2 items, each ≤ 520 bytes. -/
def p2wpkhWitnessOk (w : List (List Nat)) : Bool :=
  decide (w.length = 2) && w.all witnessItemSizeOk

/-- P2WSH: the witnessScript (last stack item) is ≤ 10,000 bytes. -/
def p2wshScriptSizeOk (witnessScript : List Nat) : Bool :=
  decide (witnessScript.length ≤ MAX_WITNESS_SCRIPT_SIZE)

/-! ## C4/C5 — scriptSig forms (native / P2SH-wrapped witness programs) -/

/-- Native witness program: the scriptSig must be exactly empty. -/
def nativeScriptSigOk (scriptSig : List Nat) : Bool := scriptSig.isEmpty

/-- `s` is exactly one direct push of `data` (canonical form; redeemScripts
of nested witness programs are 22 or 34 bytes, well under 75). -/
def isSinglePush (data : List Nat) (s : List Nat) : Bool :=
  decide (data.length ≤ 75) && decide (s.length = data.length + 1)
    && decide (s.head? = some data.length) && decide (s.tail? = some data)

/-- P2SH witness program: scriptSig must be exactly a push of the redeemScript. -/
def p2shWitnessScriptSigOk (redeem scriptSig : List Nat) : Bool :=
  isSinglePush redeem scriptSig

/-- Full native path: parse spk, require empty scriptSig, dispatch. -/
def nativeWitnessOk (spk scriptSig : List Nat) : Option WitKind :=
  match parseWitnessProgram spk with
  | some (v, prog) => if nativeScriptSigOk scriptSig then some (dispatchProgram v prog) else none
  | none => none

/-- Full P2SH path: redeemScript must itself be a witness program and the
scriptSig exactly its push. -/
def p2shWitnessOk (redeem scriptSig : List Nat) : Option WitKind :=
  match parseWitnessProgram redeem with
  | some (v, prog) =>
      if p2shWitnessScriptSigOk redeem scriptSig then some (dispatchProgram v prog) else none
  | none => none

/-! ## C1 — BIP144 marker/flag framing + per-input witness discipline -/

inductive Framing where
  | ok | badMarker | badFlag | superfluousWitness
deriving Repr, DecidableEq

/-- marker MUST be 0x00; flag MUST be non-zero (0x01 in current use, Core
TXV-016 rejects every other value); flag=1 with an all-empty witness is
Core's "superfluous witness record". -/
def framingCheck (marker flag : Nat) (stacks : List (List Nat)) : Framing :=
  if marker != 0 then .badMarker
  else if flag == 0 then .badFlag
  else if flag != 1 then .badFlag
  else if stacks.all (fun s => s.isEmpty) then .superfluousWitness
  else .ok

/-- "A non-witness program txin MUST be associated with an empty witness
field": input i without a witness program must carry an empty stack. -/
def witnessDiscipline (hasProgram : List Bool) (stacks : List (List Nat)) : Bool :=
  decide (hasProgram.length = stacks.length) &&
  (hasProgram.zip stacks).all (fun p => p.1 || p.2.isEmpty)

/-! ## C10 — block weight = base·3 + total ≤ 4,000,000 -/

def MAX_BLOCK_WEIGHT : Nat := 4000000

def blockWeight (base total : Nat) : Nat := 3 * base + total

def blockWeightOk (base total : Nat) : Bool :=
  decide (blockWeight base total ≤ MAX_BLOCK_WEIGHT)

/-- BIP141 weight model: witness bytes are counted once, base bytes four
times (3·base + total where total = base + witness). -/
theorem witness_discounted_once (base w : Nat) :
    blockWeight base (base + w) = 4 * base + w := by
  unfold blockWeight
  omega

/-! ## C11 — sigops: legacy ×4, block cost ≤ 80,000, witness costs -/

def MAX_BLOCK_SIGOP_COST : Nat := 80000

def legacySigopCost (n : Nat) : Nat := 4 * n

def blockSigopOk (legacySigops witnessCost : Nat) : Bool :=
  decide (legacySigopCost legacySigops + witnessCost ≤ MAX_BLOCK_SIGOP_COST)

/-- P2WSH witnessScript CHECKMULTISIG: OP_1..OP_16 → n, otherwise 20. -/
def cmsSigops (op : Nat) : Nat := if 1 ≤ op && op ≤ 16 then op else 20

/-- Each P2WPKH input counts as 1 sigop. -/
def p2wpkhSigops : Nat := 1

/-! ## C2 — witness commitment output + witness merkle shape -/

def commitmentPrefix : List Nat := [0x6a, 0x24, 0xaa, 0x21, 0xa9, 0xed]

/-- ≥ 38 bytes with the 6-byte `6a24aa21a9ed` header. -/
def isCommitmentSpk (spk : List Nat) : Bool :=
  decide (38 ≤ spk.length) && decide (spk.take 6 = commitmentPrefix)

/-- If several scriptPubKeys match, the highest output index wins. -/
def lastMatching : List (List Nat) → Nat → Option Nat
  | [], _ => none
  | spk :: rest, i =>
      match lastMatching rest (i + 1) with
      | some j => some j
      | none => if isCommitmentSpk spk then some i else none

def pickCommitmentIdx (spks : List (List Nat)) : Option Nat := lastMatching spks 0

/-- Coinbase input witness = a single 32-byte witness reserved value. -/
def reservedValueOk (cbWitness : List (List Nat)) : Bool :=
  match cbWitness with
  | [item] => decide (item.length = 32)
  | _ => false

/-- Witness data present ⇒ a commitment must exist; without witness data the
commitment is optional. -/
def commitmentGate (hasCommitment hasWitnessData : Bool) : Bool :=
  !hasWitnessData || hasCommitment

/-- Witness merkle leaf: the coinbase's leaf is forced to 32 zero bytes
(Core merkle.cpp:BlockWitnessMerkleRoot). -/
def zero32 : List Nat := List.replicate 32 0

def wLeaf (isCoinbase : Bool) (wtxid : List Nat) : List Nat :=
  if isCoinbase then zero32 else wtxid

/-- Injected Double-SHA256 seam (see module docstring). -/
def combine (h1 h2 : List Nat) : List Nat := h1 ++ h2

/-- One merkle reduction: pair up, duplicating the last leaf when the count
is odd (Core merkle.cpp:MerkleComputation). -/
def merkleStep : List (List Nat) → List (List Nat)
  | [] => []
  | [h] => [combine h h]
  | h1 :: h2 :: rest => combine h1 h2 :: merkleStep rest

/-- Structurally-terminating wrapper; `n` steps suffice for an `n`-leaf list
(each `merkleStep` at least halves a list of length ≥ 2). -/
def merkleRootF : Nat → List (List Nat) → List Nat
  | 0, hs => match hs with | [h] => h | _ => zero32
  | _ + 1, [] => zero32
  | _ + 1, [h] => h
  | n + 1, hs => merkleRootF n (merkleStep hs)

def merkleRoot (hs : List (List Nat)) : List Nat := merkleRootF hs.length hs

/-- Witness root over (isCoinbase?, wtxid) leaves. -/
def witnessRoot (txs : List (Bool × List Nat)) : List Nat :=
  merkleRoot (txs.map (fun p => wLeaf p.1 p.2))

/-! ## C12 — BIP9 deployment of segwit (bit 1) -/

inductive Bip9State where
  | defined | started | lockedIn | active | failed
deriving Repr, DecidableEq

structure Bip9Params where
  bit : Nat
  start : Nat
  timeout : Nat
  period : Nat
  threshold : Nat

/-- BIP141 "Deployment": BIP9 name "segwit", bit 1; mainnet start
1479168000 (2016-11-15 00:00 UTC), timeout 1510704000 (2017-11-15).
Threshold 1916 = Core deploymentinfo.cpp segwit (95% of the 2016-block
retarget period; 2016·95/100 floors to 1915, Core pins 1916). -/
def segwitParams : Bip9Params := ⟨1, 1479168000, 1510704000, 2016, 1916⟩

/-- One retarget-boundary transition (versionbits.cpp:AbstractThreshold-
ConditionCache, counting abstracted to the boundary sigcount). -/
def bip9Step (p : Bip9Params) (s : Bip9State) (t sigs : Nat) : Bip9State :=
  match s with
  | .defined => if p.start ≤ t then .started else .defined
  | .started => if p.timeout ≤ t then .failed
                else if p.threshold ≤ sigs then .lockedIn else .started
  | .lockedIn => .active
  | .active => .active
  | .failed => .failed

end BitcoinProofs.Bip.B08
