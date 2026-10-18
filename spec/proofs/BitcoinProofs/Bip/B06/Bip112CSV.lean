import Bitcoin.Interpreter.Defs

/-!
# BitcoinProofs.Bip.B06 — BIP112 (CHECKSEQUENCEVERIFY) clause coverage

BIP112 (public domain) makes OP_CSV fail the script when any of the
following holds (consensus-force clauses, from the BIP Summary and its
reference implementation, reproduced verbatim from the BIP text):

- C1: the stack is empty                         → INVALID_STACK_OPERATION
- C2: the top stack item is < 0                  → NEGATIVE_LOCKTIME
- C3: the operand has the disable flag (1 << 31)
      set                                        → NOP (no CheckSequence)
- C4: transaction version < 2                    → UNSATISFIED_LOCKTIME
- C5: tx input sequence disable flag (1 << 31)
      set                                        → UNSATISFIED_LOCKTIME
- C6: relative lock-time type (bit 22) differs
      between operand and tx input sequence      → UNSATISFIED_LOCKTIME
- C7: masked operand > masked tx input sequence  → UNSATISFIED_LOCKTIME
- C8: the operand is a CScriptNum decoded with the special 5-byte limit
      (interpreter.cpp:584 `CScriptNum(stacktop(-1), fRequireMinimal, 5)`)

Implementation under audit: `Bitcoin.Interpreter.Defs.checkSequenceDef`
(CheckSequence, interpreter.cpp:1791-1848) + the `0xb2` arm of
`Bitcoin.Interpreter.Defs.stepBody` (OP_CSV, interpreter.cpp:584-599).

What this module adds (the corpus sc-1161..1166 / sc-0586 rows run with
the DEFAULT corpus env — tx version 1, nSequence 0xFFFFFFFF — so every
non-NOP verdict there is decided by the C4 version gate alone; clauses
C5, C6, C7 and the BIP68 masking have NO kill-vector anywhere in the
tree, and the rules.yaml BIP112 rows (SCR-126/127/128, TXV-046/047/048)
pin `test_vector_ids: []`):

- C5 kill: version-2 tx whose input sequence is 0xFFFFFFFF (disable flag
  set). A mutant deleting the C5 branch would mask-compare
  0x400000 ≤ 0x40FFFF and wrongly succeed.
- C6 kill: version-2 tx, sequence 0x40FFFF (time-based), operand 5
  (height-based). A mutant dropping the type check compares 5 ≤ 0x40FFFF
  and wrongly succeeds.
- C7 kills: masked comparisons in both domains, equality (pass) and
  n > seq (fail).
- Masking kill: non-consensus bits (outside 1 << 22 | 0x0000ffff) must
  be ignored on BOTH sides — operand 0x00010005 vs tx seq 5 succeeds;
  tx seq 0x00200005 vs operand 6 fails (masked tx side is 5 < 6).
- C8 kill: a 5-byte operand (2^32) must decode (a 4-byte-limit mutant
  raises SCRIPTNUM instead of succeeding), and the operand bit-31 form
  0x80000000 (5 bytes, non-minimal in 4) NOPs even against a
  version-1/0xFFFFFFFF env (C3 never reaches CheckSequence).

Every EXPECTED verdict below was computed by the independent Python
mirror of Core's CheckSequence @ cce32b168 in
a reference script (written from the
BIP112 reference-implementation text) and cross-checked case-for-case.
All proofs are kernel `decide` — sorry-free, no `native_decide`.
-/

namespace BitcoinProofs.Bip.B06

open Bitcoin.Interpreter Bitcoin.Numeric
open Bitcoin.Crypto.Seam (stubChecker)

-- Lean core derives `DecidableEq` for `Sum` but not `Except`; the
-- kernel-`decide` verdict tests below need it.
deriving instance DecidableEq for Except

set_option maxRecDepth 10000
set_option maxHeartbeats 2000000

/-! ### Fixtures -/

/-- OP_CSV as a wire op (0xb2). -/
def csvOp : WireOp := { ast := .op ⟨0xb2, by decide⟩, wire := 0xb2, next := 1 }

/-- A minimal interpreter state with the given stack. -/
def st0 (stack : Stack) : State :=
  { stack := stack, alt := [], vf := [], opCount := 0, codeSep := 0, vwLeft := none }

/-- A CSV-enabled context whose checker env is `env` (the `LocktimeEnv`
records exactly what Core's `TransactionSignatureChecker` reads:
`txTo->nVersion`, `txTo->vin[nIn].nSequence`, `txTo->nLockTime`). -/
def csvCtx (env : LocktimeEnv) : Ctx :=
  { flags := { csv := true }, pol := default, chk := ⟨stubChecker, env, none⟩,
    sv := .base, bytes := ByteArray.empty, ed := default }

/-- The corpus-default env: version 1, nSequence 0xFFFFFFFF (final). -/
def envCorpus : LocktimeEnv := default

/-- A version-2 env with the given input sequence (nLockTime 0). -/
def envV2 (seq : UInt32) : LocktimeEnv :=
  { txVersion := 2, txSequence := seq, txLockTime := 0 }

/-- Result state after a successful CSV step: the stack is NOT consumed
(OP_CSV, unlike OP_DROP, leaves its operand) and one opcode was counted. -/
def stOk (stack : Stack) : State :=
  { stack := stack, alt := [], vf := [], opCount := 1, codeSep := 0, vwLeft := none }

/-! ### C1 — empty stack → INVALID_STACK_OPERATION (kill: NOP-mutant) -/

theorem csv_c1_empty_stack :
    stepBody (csvCtx envCorpus) csvOp (st0 []) = .error .stackUnderflow := by
  decide

/-! ### C2 — negative operand → NEGATIVE_LOCKTIME (kill: negative-is-final-mutant) -/

/-- Operand −1 (minimal 1-byte 0x81). -/
theorem csv_c2_negative :
    stepBody (csvCtx envCorpus) csvOp
      (st0 [ByteArray.mk #[(0x81 : UInt8)]]) = .error .negativeLocktime := by
  decide

/-- Negative zero (single byte 0x80) is 0, not negative: it must reach
CheckSequence (and fail on the version gate), NOT raise
NEGATIVE_LOCKTIME — pins the CScriptNum-signed comparison (corpus
sc-1163, re-pinned at def level). -/
theorem csv_c2b_negative_zero :
    stepBody (csvCtx envCorpus) csvOp
      (st0 [ByteArray.mk #[(0x80 : UInt8)]])
      = .error .unsatisfiedLocktime := by
  decide

/-! ### C3 — operand disable flag (1 << 31) set → NOP, CheckSequence skipped -/

/-- 0x80000000 as a (minimal) 5-byte operand, against the hostile
corpus-default env (version 1, sequence 0xFFFFFFFF): still a NOP. A
mutant that drops the C3 branch would fall into CheckSequence and fail
on the version gate. -/
theorem csv_c3_operand_disable_nop :
    stepBody (csvCtx envCorpus) csvOp
      (st0 [ByteArray.mk #[(0x00 : UInt8), (0x00 : UInt8), (0x00 : UInt8),
                           (0x80 : UInt8), (0x00 : UInt8)]])
      = .ok (stOk [ByteArray.mk #[(0x00 : UInt8), (0x00 : UInt8), (0x00 : UInt8),
                                   (0x80 : UInt8), (0x00 : UInt8)]]) := by
  decide

/-! ### C4 — tx version < 2 → UNSATISFIED_LOCKTIME -/

/-- Operand 0 against the version-1 corpus env (mirrors sc-1165; kept so
this module is self-contained: every verdict below is decided against
the very env the checker seam carries). -/
theorem csv_c4_version_gate :
    stepBody (csvCtx envCorpus) csvOp
      (st0 [ByteArray.mk #[(0x00 : UInt8)]]) = .error .unsatisfiedLocktime := by
  decide

/-- Def-level form of C4 (the SCR-128 theorem of X07, re-derivable): a
version-1 env ALWAYS fails CheckSequence regardless of the operand. -/
theorem checkSequenceDef_version1_fails (env : LocktimeEnv) (n : ScriptNum)
    (hv : env.txVersion < 2) : checkSequenceDef env n = false := by
  simp [checkSequenceDef, hv]

/-! ### C5 — tx input sequence disable flag set → UNSATISFIED_LOCKTIME
(no kill-vector existed: the corpus env is version-1, so sc-1161..1166
all die at the C4 gate first) -/

/-- Version-2 tx, input sequence 0xFFFFFFFF (disable flag set), operand
0x400000 (time-based, 1 unit). Correct: FAIL (C5). Mutant deleting the
C5 branch: masks give txMasked = 0x40FFFF, nMasked = 0x400000 — type
match, n ≤ tx — would wrongly succeed. -/
theorem csv_c5_txseq_disable_flag :
    stepBody (csvCtx (envV2 0xFFFFFFFF)) csvOp
      (st0 [ByteArray.mk #[(0x00 : UInt8), (0x00 : UInt8), (0x40 : UInt8)]])
      = .error .unsatisfiedLocktime := by
  decide

/-- Def-level C5: with the tx-version gate passed, a disable-flagged tx
input sequence fails CheckSequence for EVERY operand. -/
theorem checkSequenceDef_txseq_disable_fails (env : LocktimeEnv) (n : ScriptNum)
    (hv : ¬ (env.txVersion < 2))
    (hd : (env.txSequence.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0) :
    checkSequenceDef env n = false := by
  simp [checkSequenceDef, hv, hd]

/-! ### C6 — type mismatch (bit 22) → UNSATISFIED_LOCKTIME (no kill-vector) -/

/-- Version-2 tx, sequence 0x40FFFF (time-based), operand 5
(height-based). Correct: FAIL. Mutant dropping the type check: 5 ≤
0x40FFFF — would wrongly succeed. -/
theorem csv_c6_type_mismatch :
    stepBody (csvCtx (envV2 0x40FFFF)) csvOp
      (st0 [ByteArray.mk #[(0x05 : UInt8)]]) = .error .unsatisfiedLocktime := by
  decide

/-- Def-level C6: a height-based tx sequence vs a time-based operand
fails for every (otherwise-passing) combination. `htype` is the BIP68
type-match disjunction evaluated to False — the exact condition under
which Core's CheckSequence (:1810-1818) rejects. -/
theorem checkSequenceDef_typeMismatch_fails (env : LocktimeEnv) (n : ScriptNum)
    (hv : ¬ (env.txVersion < 2))
    (hd : (env.txSequence.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) = 0)
    (htype : (((env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) < SEQUENCE_LOCKTIME_TYPE_FLAG ∧
               (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) < SEQUENCE_LOCKTIME_TYPE_FLAG) ∨
              ((env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ≥ SEQUENCE_LOCKTIME_TYPE_FLAG ∧
               (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ≥ SEQUENCE_LOCKTIME_TYPE_FLAG)) = False) :
    checkSequenceDef env n = false := by
  simp [checkSequenceDef, hv, hd, htype]

/-! ### C7 — masked operand ≤ masked tx sequence, per type domain -/

/-- Time domain, equality: 10 × 512s vs 10 × 512s → OK (no corpus
vector: the corpus never leaves the version gate). -/
theorem csv_c7_time_equal :
    stepBody (csvCtx (envV2 0x40000A)) csvOp
      (st0 [ByteArray.mk #[(0x0A : UInt8), (0x00 : UInt8), (0x40 : UInt8)]])
      = .ok (stOk [ByteArray.mk #[(0x0A : UInt8), (0x00 : UInt8), (0x40 : UInt8)]]) := by
  decide

/-- Time domain, operand greater: 11 vs 10 × 512s → FAIL. -/
theorem csv_c7_time_greater :
    stepBody (csvCtx (envV2 0x40000A)) csvOp
      (st0 [ByteArray.mk #[(0x0B : UInt8), (0x00 : UInt8), (0x40 : UInt8)]])
      = .error .unsatisfiedLocktime := by
  decide

/-- Height domain, equality: 5 vs 5 blocks → OK. -/
theorem csv_c7_height_equal :
    stepBody (csvCtx (envV2 5)) csvOp
      (st0 [ByteArray.mk #[(0x05 : UInt8)]])
      = .ok (stOk [ByteArray.mk #[(0x05 : UInt8)]]) := by
  decide

/-- Height domain, operand greater: 6 vs 5 blocks → FAIL. -/
theorem csv_c7_height_greater :
    stepBody (csvCtx (envV2 5)) csvOp
      (st0 [ByteArray.mk #[(0x06 : UInt8)]]) = .error .unsatisfiedLocktime := by
  decide

/-! ### Masking — non-consensus bits (outside bit 22 | 0x0000ffff)
ignored on BOTH sides (BIP68 mask; no kill-vector in the tree) -/

/-- Operand 0x00010005 (bit 16 set — outside the mask) vs tx sequence 5:
masked operand is 5 → OK. Mutant comparing unmasked: 0x10005 > 5 —
would wrongly fail. -/
theorem csv_mask_operand_side :
    stepBody (csvCtx (envV2 5)) csvOp
      (st0 [ByteArray.mk #[(0x05 : UInt8), (0x00 : UInt8), (0x01 : UInt8)]])
      = .ok (stOk [ByteArray.mk #[(0x05 : UInt8), (0x00 : UInt8), (0x01 : UInt8)]]) := by
  decide

/-- Tx sequence 0x00200005 (bit 21 set — outside the mask) vs operand 6:
masked tx side is 5 < 6 → FAIL. Mutant comparing unmasked: 6 ≤
0x200005 — would wrongly succeed. -/
theorem csv_mask_tx_side :
    stepBody (csvCtx (envV2 0x00200005)) csvOp
      (st0 [ByteArray.mk #[(0x06 : UInt8)]]) = .error .unsatisfiedLocktime := by
  decide

/-! ### C8 — the 5-byte CScriptNum operand limit -/

/-- Operand 2^32 (5 bytes, as in corpus sc-1166) against a version-2 tx
with sequence 0: masked 0 ≤ 0 → OK. A mutant decoding with the default
4-byte limit raises SCRIPTNUM instead. -/
theorem csv_c8_five_byte_operand :
    stepBody (csvCtx (envV2 0)) csvOp
      (st0 [ByteArray.mk #[(0x00 : UInt8), (0x00 : UInt8), (0x00 : UInt8),
                           (0x00 : UInt8), (0x01 : UInt8)]])
      = .ok (stOk [ByteArray.mk #[(0x00 : UInt8), (0x00 : UInt8), (0x00 : UInt8),
                                   (0x00 : UInt8), (0x01 : UInt8)]]) := by
  decide

/-! ### Axiom footprints (docstring-pinned, Mempool.lean convention;
every theorem here is sorry-free — propext/Quot.sound standard trio,
no Classical.choice, no sorryAx) -/

/-- info: 'BitcoinProofs.Bip.B06.csv_c1_empty_stack' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_c1_empty_stack

/-- info: 'BitcoinProofs.Bip.B06.csv_c2_negative' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_c2_negative

/-- info: 'BitcoinProofs.Bip.B06.csv_c2b_negative_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_c2b_negative_zero

/-- info: 'BitcoinProofs.Bip.B06.csv_c3_operand_disable_nop' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_c3_operand_disable_nop

/-- info: 'BitcoinProofs.Bip.B06.csv_c4_version_gate' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_c4_version_gate

/-- info: 'BitcoinProofs.Bip.B06.checkSequenceDef_version1_fails' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkSequenceDef_version1_fails

/-- info: 'BitcoinProofs.Bip.B06.csv_c5_txseq_disable_flag' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_c5_txseq_disable_flag

/-- info: 'BitcoinProofs.Bip.B06.checkSequenceDef_txseq_disable_fails' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkSequenceDef_txseq_disable_fails

/-- info: 'BitcoinProofs.Bip.B06.csv_c6_type_mismatch' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_c6_type_mismatch

/-- info: 'BitcoinProofs.Bip.B06.checkSequenceDef_typeMismatch_fails' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkSequenceDef_typeMismatch_fails

/-- info: 'BitcoinProofs.Bip.B06.csv_c7_time_equal' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_c7_time_equal

/-- info: 'BitcoinProofs.Bip.B06.csv_c7_time_greater' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_c7_time_greater

/-- info: 'BitcoinProofs.Bip.B06.csv_c7_height_equal' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_c7_height_equal

/-- info: 'BitcoinProofs.Bip.B06.csv_c7_height_greater' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_c7_height_greater

/-- info: 'BitcoinProofs.Bip.B06.csv_mask_operand_side' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_mask_operand_side

/-- info: 'BitcoinProofs.Bip.B06.csv_mask_tx_side' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_mask_tx_side

/-- info: 'BitcoinProofs.Bip.B06.csv_c8_five_byte_operand' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms csv_c8_five_byte_operand

end BitcoinProofs.Bip.B06
