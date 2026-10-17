import Bitcoin.TxValidation.LocktimeSigOps
import Bitcoin.Interpreter.Defs

/-!
# X09 unit tests — CLTV/CSV tx-side, sigops, exact-weight vectors

Build-time `example … := by decide` instances (kernel-reduced, no IO),
mirroring the W02/W04/W10 test pattern, over X09's
`Bitcoin.TxValidation.LocktimeSigOps` layer:

* CLTV tx-side (`CheckLockTime`, interpreter.cpp:1755-1788): the
  cross-domain type-match gate (TXV-043), the `operand > nLockTime`
  comparison (TXV-044), the SEQUENCE_FINAL interlock (TXV-045) —
  including the boundary case `n = nLockTime` passing.
* CSV tx-side (`CheckSequence`, interpreter.cpp:1791-1848): the BIP68
  version gate (TXV-046), the per-input disable flag (TXV-047), the
  masked `nMasked ≤ txMasked` verdict in both domains (TXV-048).
* Sigop accounting (tx_verify.cpp:118-168): the cost scaling law
  (TXV-052) and the multisig constant — CHECKSIG = 1, OP_N-led
  CHECKMULTISIG = N, and the no-push fallback = 20 (TXV-054).
* OP_RETURN outputs consensus-valid: rewriting spk leaves the output
  loop's verdict unchanged (TXV-066) and every partial value sum is
  MoneyRange'd on acceptance (TXV-069, CVE-2010-5137).
* The exact BIP141 weight gate (TXV-003/INV-003): a small tx both
  accepted and weight-bounded, and an over-weight tx rejected — through
  the theorem, since a literal 4M-weight tx is too large to decide.
-/

namespace Test.TxValidation.LocktimeVec

open Bitcoin.Data Bitcoin.Consensus Bitcoin.Interpreter Bitcoin.Numeric
open Bitcoin.TxValidation.LocktimeSigOps
open Bitcoin.Interpreter.SigOps (sigOpStep opNumberOf)
open Bitcoin.DataLaws (baseSize totalSize)

/-! ## Fixtures -/

/-- A 4-byte ByteArray filled with byte `k` (distinguishes test txids). -/
def kbytes (k : UInt8) : ByteArray :=
  (List.range 4).foldl (fun acc _ => acc.push k) ByteArray.empty

def opk (k : UInt8) : OutPoint := ⟨kbytes k, 0⟩

def txin (k : UInt8) (seq : UInt32) : TxIn := ⟨opk k, ⟨ByteArray.empty⟩, seq⟩

def txout (v : Amount) : TxOut := ⟨v, ⟨ByteArray.empty⟩⟩

/-! ## TXV-043: the CLTV type-match gate (cross-domain fails) -/

-- tx.nLockTime = 500_000_000 (time domain), operand 100 (height domain): fail
example : checkLockTimeDef ⟨1, 500000000, 0⟩ (100 : ScriptNum) = false := by decide
-- mirror: nLockTime in height domain, operand at the 500M threshold: fail
example : checkLockTimeDef ⟨1, 100, 0⟩ (500000000 : ScriptNum) = false := by decide

/-! ## TXV-044: same-domain comparison — fail iff operand > nLockTime -/

example : checkLockTimeDef ⟨1, 1000, 5⟩ (1001 : ScriptNum) = false := by decide
example : checkLockTimeDef ⟨1, 1000, 5⟩ (1000 : ScriptNum) = true := by decide
example : checkLockTimeDef ⟨1, 1000, 5⟩ (999 : ScriptNum) = true := by decide
-- time domain, same law
example : checkLockTimeDef ⟨1, 500000100, 5⟩ (500000101 : ScriptNum) = false := by decide
example : checkLockTimeDef ⟨1, 500000100, 5⟩ (500000100 : ScriptNum) = true := by decide

/-! ## TXV-045: SEQUENCE_FINAL input fails CLTV even when in range -/

example : checkLockTimeDef ⟨1, 999, 0xFFFFFFFF⟩ (999 : ScriptNum) = false := by decide
example : checkLockTimeDef ⟨1, 999, 0xFFFFFFFE⟩ (999 : ScriptNum) = true := by decide

/-! ## TXV-046: the BIP68 version gate -/

example : checkSequenceDef ⟨1, 0, 10⟩ (5 : ScriptNum) = false := by decide
example : checkSequenceDef ⟨2, 0, 10⟩ (5 : ScriptNum) = true := by decide
example : checkSequenceDef ⟨(-2147483648 : Int32), 0, 10⟩ (5 : ScriptNum) = false := by decide

/-! ## TXV-047: the per-input disable flag (bit 31) -/

example : checkSequenceDef ⟨2, 0, 0x80000005⟩ (5 : ScriptNum) = false := by decide

/-! ## TXV-048: the masked comparison, both domains -/

-- height domain (bit22 clear): nMasked 6 > txMasked 5 → fail; = → pass
example : checkSequenceDef ⟨2, 0, 5⟩ (6 : ScriptNum) = false := by decide
example : checkSequenceDef ⟨2, 0, 5⟩ (5 : ScriptNum) = true := by decide
-- time domain (bit22 set): same masked law under type flag 0x00400000
example : checkSequenceDef ⟨2, 0, 0x00400005⟩ (6 : ScriptNum) = false := by decide
example : checkSequenceDef ⟨2, 0, 0x00400005⟩ (0x00400005 : ScriptNum) = true := by decide
-- the theorem instantiated at the time-domain vector (hypotheses + type check)
example : True := by
  have _h := checkSequence_masked (env := ⟨2, 0, 0x00400005⟩) (n := 0x00400005)
    (by decide) (by decide)
    (by decide : checkSequenceDef ⟨2, 0, 0x00400005⟩ (0x00400005 : ScriptNum) = true)
  trivial

/-! ## TXV-052: sigop cost scaling (× WITNESS_SCALE_FACTOR) -/

example : sigOpCost 0 0 0 = 0 := by decide
example : sigOpCost 2 3 7 = 27 := by decide
example : sigOpCost 79999 0 0 = 319996 := by decide

/-! ## TXV-054: the multisig sigop constants -/

/-- Wire ops for OP_CHECKSIG (0xac), OP_CHECKMULTISIG (0xae). -/
def csOp : WireOp := ⟨.op ⟨0xac, by decide⟩, 0xac, 1⟩
def msOp : WireOp := ⟨.op ⟨0xae, by decide⟩, 0xae, 1⟩

example : sigOpStep none csOp = 1 := by decide
example : sigOpStep (some (.pushNum 16)) csOp = 1 := by decide
-- OP_N-led CHECKMULTISIG counts the N
example : sigOpStep (some (.pushNum 3)) msOp = 3 := by decide
example : sigOpStep (some (.pushNum 16)) msOp = 16 := by decide
-- no preceding OP_N (or a non-OP_N push) → the MAX_PUBKEYS_PER_MULTISIG fallback
example : sigOpStep none msOp = MAX_PUBKEYS_PER_MULTISIG := by decide
example : sigOpStep (some (.pushNum 0)) msOp = MAX_PUBKEYS_PER_MULTISIG := by decide
example : sigOpStep (some (.op ⟨0x00, by decide⟩)) msOp = MAX_PUBKEYS_PER_MULTISIG := by decide
example : MAX_PUBKEYS_PER_MULTISIG = 20 := by decide
-- non-sigop ops count 0
example : sigOpStep none ⟨.op ⟨0x51, by decide⟩, 0x00, 1⟩ = 0 := by decide

/-! ## TXV-066: OP_RETURN outputs are consensus-valid (value rules only) -/

/-- OP_RETURN (0x6a) scriptPubKey. -/
def opRetSpk : Script := ⟨ByteArray.empty.push 0x6a⟩

example : checkTransaction.checkOutputs [txout 100, txout 200] 0 = none := by decide
example :
    checkTransaction.checkOutputs
        (([txout 100, txout 200]).map fun o => { o with scriptPubKey := opRetSpk }) 0 = none := by
  rw [checkOutputs_spk_irrelevant]
  decide

/-! ## TXV-069: every partial sum of the value fold is MoneyRange'd -/

example : checkTransaction.checkOutputs [txout 50, txout 60, txout 70] 0 = none := by decide
example : MoneyRange (([txout 50, txout 60, txout 70].take 2).foldl
    (fun a o => a + o.value) 0) := by decide
example : MoneyRange (([txout 50, txout 60, txout 70].take 3).foldl
    (fun a o => a + o.value) 0) := by decide

/-! ## TXV-003 / INV-003: the stripped-size oversize gate -/

/-- A small segwit-marked tx (one input, one output, one empty witness
stack): accepted, and its stripped-size weight `4·baseSize` is bounded. -/
def txSmall : Tx := ⟨2, [txin 1 0xFFFFFFFF], [txout 100], 0, [[]]⟩

example : checkTransaction txSmall = none := by decide
example : Bitcoin.DataLaws.baseSize txSmall * WITNESS_SCALE_FACTOR ≤ MAX_BLOCK_WEIGHT :=
  checkTransaction_weight_bound txSmall (by decide)
-- the BIP141 weight model is still available for block consumers
example : Bitcoin.DataLaws.txWeight txSmall = 3 * baseSize txSmall + totalSize txSmall := rfl
example : baseSize txSmall ≤ totalSize txSmall := by decide

/-- INV-003 instance: the reject theorem — ANY tx whose stripped-size
weight `4·baseSize` exceeds `MAX_BLOCK_WEIGHT` is rejected by
`checkTransaction` (witness bytes do not enter this gate). -/
example (tx : Tx) (hW : Bitcoin.DataLaws.baseSize tx * WITNESS_SCALE_FACTOR >
    MAX_BLOCK_WEIGHT) :
    checkTransaction tx ≠ none := checkTransaction_weight_reject tx hW

-- the gate sits between the emptiness checks and the output loop:
-- a vin-empty tx still reports `vinEmpty`, not `oversize`
example : checkTransaction ⟨2, [], [txout 100], 0, []⟩ = some .vinEmpty := by decide

end Test.TxValidation.LocktimeVec
