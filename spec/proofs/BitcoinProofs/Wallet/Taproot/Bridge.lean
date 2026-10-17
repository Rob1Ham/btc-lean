import BitcoinProofs.Wallet.Taproot.Program
import Bitcoin.Capstone.Block

/-!
# Wallet Taproot program bridge (`PEER-TAPROOT2`)

This module proves the wallet-local bridge between a spent P2TR
`scriptPubKey` and the Taproot script-path commitment.  The predicates
`programOf` and `programMatches` already live in the executable model at
`spec/core/Bitcoin/Wallet/Taproot/Commit.lean:119-137`; they are reused
here unchanged (no model file is edited and no predicate is duplicated
under a different meaning).  The only new definitions are a decision
procedure for `programOf` (`programOfEq`), a named "judged" proposition
(`ScriptPathJudged`), the unproven target `V1SpendJudgedTarget`, and the
explicit missing-link proposition `VerifyComparesProgram`.

## What is proved

* **34-byte v1 exactness.**  If a 34-byte scriptPubKey has the wire shape
  `0x51 0x20` followed by 32 bytes, then `programOf` returns a unique
  32-byte program, namely `spk.bytes.extract 2 spk.bytes.size`
  (`programOf_v1_34_exact`, `programOf_v1_34_unique`).  This is the
  model's `isWitnessProgram` decoder
  (`spec/core/Bitcoin/Interpreter/Defs.lean:489-501`), which mirrors
  Core `CScript::IsWitnessProgram`, `src/script/script.cpp:250-264` at
  pinned `cce32b168` (the model docstring cites `script/script.h`;
  the implementation is in `script.cpp`).
* **Program equality.**  For any `spk` whose decoder returns
  `some (1, payload)`, `programMatches spk program = true` is equivalent
  to `payload = program` (`programMatches_iff_payload`); the 34-byte
  corollary identifies the payload with the trailing 32 bytes
  (`programMatches_v1_34_payload_iff`).
* **Decidability.**  `programOf spk = some (version, program)` is decided
  by `programOfEq` (`programOfEq_eq_true_iff`,
  `decidable_programOf_eq`); `ProgramMatches spk program` is decided by
  the model's Boolean predicate (`decidable_programMatches`).
* **Conditional spend theorem.**  Under the wallet premise
  `programMatches spk program = true`, a script-path spend is judged
  exactly when the commitment verdict accepts
  (`v1Spend_judged_iff_programMatches_and_commitment`).
* **The gap, as theorems.**  `verifyTaprootCommitment` ignores its
  `program` argument (`verifyTaprootCommitment_program_irrelevant`) and
  `Capstone.Block.verifyInput` routes every v1 witness program to
  `unjudgedTaproot` before script execution
  (`verifyInput_unjudged_of_v1_program`,
  `verifyInput_unjudged_of_v1_34`).

## The unproven target and the exact missing link

`V1SpendJudgedTarget` is the unconditional claim: for every 34-byte v1
scriptPubKey and every wallet-supplied program, the spend is judged iff
`programMatches` holds *and* the commitment verdict accepts.  It is a
`def : Prop`, not a theorem.  The module proves

* it is exactly `CommitmentForcesProgramMatch`: every accepting
  commitment must force `programMatches`
  (`v1SpendJudgedTarget_iff_commitmentForcesProgramMatch`), and
* it is false as soon as an accepting commitment coexists with a
  mismatched wallet program
  (`v1SpendJudgedTarget_fails_of_program_mismatch`,
  `commitmentForcesProgramMatch_fails_of_program_mismatch`).

The exact missing obligation is therefore `CommitmentForcesProgramMatch`.
The verifier-level mechanism that supplies it in Core is
`VerifyComparesProgram`: an accepting
`verifyTaprootCommitment control program tapleafHash` must imply that
`program` is the output key recomputed from the control block and leaf,
and Core calls it with the spent script's program.  Core performs
exactly this comparison —
`const XOnlyPubKey q{program};` then `q.CheckTapTweak(p, merkle_root,
control[0] & 1)` at `src/script/interpreter.cpp:1919-1924` and
`src/pubkey.cpp:257-263` — whereas the model's verifier is
`outputKeyOk control (some (scriptPathMerkleRoot control tapleafHash))`
at `spec/core/Bitcoin/Crypto/Taproot/Verify.lean:89-90`, which never
receives or compares `program`.  Supplying that comparison, and having
the capstone adjudicate the v1 lane instead of returning
`InputVerdict.unjudgedTaproot`
(`spec/core/Bitcoin/Capstone/Block.lean:218-221`, `:242-245`), is the
consensus change this wallet bridge is waiting for.

## What is not modeled or claimed

* No consensus definition, interpreter arm, capstone dispatch, or model
  file is modified; this module only proves facts over the executable
  tree.
* No secp256k1 arithmetic is added.  The tweak chain is the model's
  `tweakedKey`/`outputKeyOk`/`tweakPoint`; the wallet comparison is only
  the equality `committedProgram control leafScript = some program`.
* No wallet spend is proved valid, and no signature, sighash, or
  tapscript execution is modeled.
* The target is not proved, and cannot be proved while the verifier is
  program-blind.  The conditional theorem is the strongest proven form
  in this tree.
-/

namespace BitcoinProofs.Wallet.Taproot

open Bitcoin.Data (Script bytesBEq)
open Bitcoin.Wallet.Taproot
  (programOf programMatches ProgramMatches commitmentOf
   programOf_v1_34 programOf_v1_34_size
   programMatches_eq_true_iff
   bytesBEq_eq_true bytesBEq_self_eq_true
   taprootSpendJudged_iff_commitment programOf_p2trScript
   committedProgram)
open Bitcoin.Crypto.Taproot.Program (controlBlockSizeOk p2trScript)
open Bitcoin.Crypto.Taproot.Verify
  (scriptPathSpend scriptPathTapleaf verifyTaprootCommitment)

/-! ## A decision procedure for `programOf` -/

/-- Boolean decision procedure for `programOf spk = some (version, program)`.
`bytesBEq` is the executable tree's byte equality; no `DecidableEq`
instance on `ByteArray` is assumed. -/
def programOfEq (spk : Script) (version : Nat) (program : ByteArray) : Bool :=
  match programOf spk with
  | some (v, p) => decide (v = version) && bytesBEq p program
  | none => false

/-- `programOfEq` is sound and complete for the `Option` equality. -/
theorem programOfEq_eq_true_iff (spk : Script) (version : Nat) (program : ByteArray) :
    programOfEq spk version program = true ↔
      programOf spk = some (version, program) := by
  unfold programOfEq
  cases h : programOf spk with
  | none => simp
  | some vp =>
      obtain ⟨v, p⟩ := vp
      constructor
      · intro hb
        have hb' := hb
        simp only [Bool.and_eq_true, decide_eq_true_eq] at hb'
        obtain ⟨hv, hbe⟩ := hb'
        have hp : p = program := bytesBEq_eq_true p program hbe
        rw [hv, hp]
      · intro hs
        have hconj : v = version ∧ p = program := by simpa using hs
        rw [hconj.1, hconj.2]
        simp [bytesBEq_self_eq_true]

/-! ## Exact program extraction from a 34-byte v1 scriptPubKey

The payload-shape lemma itself is the committed
`programOf_v1_34_payload` from `BitcoinProofs.Wallet.Taproot.Program`
(which re-exports the model's `programOf_v1_34`/`programOf_v1_34_size`);
this module adds the uniqueness and canonical-constructor forms. -/

/-- The program extracted from any 34-byte v1 scriptPubKey is unique and
is exactly the 32 trailing bytes.  This is the "returns exactly the 32
program bytes" statement in its strongest form. -/
theorem programOf_v1_34_unique (spk : Script) (version : Nat) (program : ByteArray)
    (h0 : (spk.bytes.get! 0).toNat = 0x51)
    (h1 : (spk.bytes.get! 1).toNat = 32)
    (hsz : spk.bytes.size = 34)
    (h : programOf spk = some (version, program)) :
    version = 1 ∧ program = spk.bytes.extract 2 spk.bytes.size ∧
      program.size = 32 := by
  have hp : programOf spk = some (1, spk.bytes.extract 2 spk.bytes.size) :=
    programOf_v1_34 spk h0 h1 hsz
  have h' : some (version, program) =
      some (1, spk.bytes.extract 2 spk.bytes.size) := by
    rw [← h]
    exact hp
  injection h' with hpair
  injection hpair with hver hprog
  exact ⟨hver, hprog, by rw [hprog]; exact programOf_v1_34_size spk hsz⟩

/-- Existence and uniqueness form: a 34-byte v1 scriptPubKey determines
exactly one 32-byte program. -/
theorem programOf_v1_34_exact (spk : Script)
    (h0 : (spk.bytes.get! 0).toNat = 0x51)
    (h1 : (spk.bytes.get! 1).toNat = 32)
    (hsz : spk.bytes.size = 34) :
    ∃ program : ByteArray,
      (programOf spk = some (1, program) ∧ program.size = 32) ∧
        ∀ other : ByteArray,
          (programOf spk = some (1, other) ∧ other.size = 32) → other = program := by
  refine ⟨spk.bytes.extract 2 spk.bytes.size, ?_⟩
  constructor
  · exact programOf_v1_34_payload spk h0 h1 hsz
  · intro program hprogram
    exact (programOf_v1_34_unique spk 1 program h0 h1 hsz hprogram.1).2.1

/-- Canonical P2TR constructor: `programOf` of `OP_1 <32B>` recovers the
same 32-byte program.  Anchors: `Bitcoin.Crypto.Taproot.Program.p2trScript`
(`spec/core/Bitcoin/Crypto/Taproot/Program.lean:80-83`); Core
`CScript::IsWitnessProgram` `src/script/script.cpp:250-264`. -/
theorem programOf_p2trScript_exact (program : ByteArray) (h : program.size = 32) :
    programOf ⟨p2trScript program⟩ = some (1, program) ∧ program.size = 32 :=
  ⟨programOf_p2trScript program h, h⟩

/-! ## Program equality -/

/-- On a scriptPubKey whose decoder returns `some (1, payload)`,
`programMatches` is equivalent to literal equality of that payload with
the supplied program.  The comparison is `bytesBEq`, whose soundness is
`bytesBEq_eq_true` and whose reflexivity is
`bytesBEq_self_eq_true` (`spec/core/Bitcoin/Data/Basic.lean:37-39`). -/
theorem programMatches_iff_payload (spk : Script) (payload program : ByteArray)
    (hv : programOf spk = some (1, payload)) :
    programMatches spk program = true ↔ payload = program := by
  unfold programMatches
  rw [hv]
  simp only [↓reduceIte]
  constructor
  · intro hb
    exact bytesBEq_eq_true payload program hb
  · intro h
    rw [h]
    exact bytesBEq_self_eq_true program

/-- 34-byte v1 corollary: `programMatches` is exactly equality with the
trailing 32-byte payload. -/
theorem programMatches_v1_34_payload_iff (spk : Script) (program : ByteArray)
    (h0 : (spk.bytes.get! 0).toNat = 0x51)
    (h1 : (spk.bytes.get! 1).toNat = 32)
    (hsz : spk.bytes.size = 34) :
    programMatches spk program = true ↔
      spk.bytes.extract 2 spk.bytes.size = program :=
  programMatches_iff_payload spk (spk.bytes.extract 2 spk.bytes.size) program
    (programOf_v1_34 spk h0 h1 hsz)

/-! ## Decidability -/

/-- `programOf spk = some (version, program)` is decidable, by
`programOfEq`. -/
def decidable_programOf_eq (spk : Script) (version : Nat) (program : ByteArray) :
    Decidable (programOf spk = some (version, program)) :=
  decidable_of_iff (programOfEq spk version program = true)
    (programOfEq_eq_true_iff spk version program)

/-- The propositional reading `ProgramMatches spk program` is decidable,
by the model's `programMatches` Boolean and
`programMatches_eq_true_iff`
(`spec/core/Bitcoin/Wallet/Taproot/Commit.lean:146-176`). -/
def decidable_programMatches (spk : Script) (program : ByteArray) :
    Decidable (ProgramMatches spk program) :=
  inferInstance

/-! ## The conditional spend theorem -/

/-- A script-path spend is judged when the consensus arm returns an
accepted commitment bit.  The existential `tl`, `ts` retains the tapleaf
hash and the tapscript dispatch bit, so this is the arm's success
condition rather than a new consensus predicate. -/
def ScriptPathJudged (control leafScript program : ByteArray) : Prop :=
  ∃ tl ts, scriptPathSpend control leafScript program = some (tl, true, ts)

/-- Model-side judgment: under the control-block size gate, the
script-path arm is judged exactly when the commitment verdict accepts.
No program equality appears, because `verifyTaprootCommitment` does not
inspect its `program` argument
(`spec/core/Bitcoin/Crypto/Taproot/Verify.lean:89-90`). -/
theorem v1Spend_judged_iff_commitment
    (program control leafScript : ByteArray)
    (hsize : controlBlockSizeOk control = true) :
    ScriptPathJudged control leafScript program ↔
      commitmentOf control program leafScript = true :=
  taprootSpendJudged_iff_commitment program control leafScript hsize

/-- **Conditional spend theorem (proved).**  If the wallet's program is
the spent script's v1 program (`programMatches`), then the script-path
spend is judged exactly when the commitment verdict accepts.  This is
the strongest unconditional-in-consensus form available in this tree;
the `programMatches` premise is what the program-blind verifier cannot
check for us. -/
theorem v1Spend_judged_iff_programMatches_and_commitment
    (spk : Script) (program control leafScript : ByteArray)
    (hsize : controlBlockSizeOk control = true)
    (hm : programMatches spk program = true) :
    ScriptPathJudged control leafScript program ↔
      (programMatches spk program = true ∧
        commitmentOf control program leafScript = true) := by
  rw [v1Spend_judged_iff_commitment program control leafScript hsize]
  constructor
  · intro hc
    exact ⟨hm, hc⟩
  · intro h
    exact h.2

/-! ## The unconditional target and the exact missing link -/

/-- **Target, not proved.**  For every 34-byte v1 scriptPubKey and every
wallet-supplied program, a script-path spend is judged iff the wallet's
program matches the spent script's program *and* the commitment verdict
accepts.

This is false in the executable tree whenever an accepting commitment
coexists with a mismatched wallet program: the arm's verdict is
program-blind (`v1Spend_judged_iff_commitment`), so the forward
direction fails.  It is stated as a `def` so downstream work can name
the obligation without asserting it. -/
def V1SpendJudgedTarget : Prop :=
  ∀ (spk : Script) (program control leafScript : ByteArray),
    spk.bytes.size = 34 →
    (spk.bytes.get! 0).toNat = 0x51 →
    (spk.bytes.get! 1).toNat = 32 →
    controlBlockSizeOk control = true →
    (ScriptPathJudged control leafScript program ↔
      (programMatches spk program = true ∧
        commitmentOf control program leafScript = true))

/-- **The exact missing obligation, isolated.**  Every accepting
commitment must force the wallet's program to be the spent script's v1
program.  This is the entire forward direction the target lacks; the
model cannot prove it because `commitmentOf` is program-blind. -/
def CommitmentForcesProgramMatch : Prop :=
  ∀ (spk : Script) (program control leafScript : ByteArray),
    spk.bytes.size = 34 →
    (spk.bytes.get! 0).toNat = 0x51 →
    (spk.bytes.get! 1).toNat = 32 →
    controlBlockSizeOk control = true →
    commitmentOf control program leafScript = true →
      programMatches spk program = true

/-- The target is exactly `CommitmentForcesProgramMatch`.  The backward
direction of the target is already supplied by
`v1Spend_judged_iff_programMatches_and_commitment`; all of the missing
content is the implication isolated here. -/
theorem v1SpendJudgedTarget_iff_commitmentForcesProgramMatch :
    V1SpendJudgedTarget ↔ CommitmentForcesProgramMatch := by
  unfold CommitmentForcesProgramMatch
  constructor
  · intro htarget spk program control leafScript hsz h0 h1 hsize hc
    have hjudged : ScriptPathJudged control leafScript program :=
      (v1Spend_judged_iff_commitment program control leafScript hsize).mpr hc
    have hrhs :=
      (htarget spk program control leafScript hsz h0 h1 hsize).mp hjudged
    exact hrhs.1
  · intro hno spk program control leafScript hsz h0 h1 hsize
    constructor
    · intro hjudged
      have hc : commitmentOf control program leafScript = true :=
        (v1Spend_judged_iff_commitment program control leafScript hsize).mp hjudged
      exact ⟨hno spk program control leafScript hsz h0 h1 hsize hc, hc⟩
    · intro hrhs
      exact (v1Spend_judged_iff_commitment program control leafScript hsize).mpr hrhs.2

/-- **Conditional refutation of the exact missing obligation.**  An
accepting commitment with a mismatched wallet program refutes
`CommitmentForcesProgramMatch` outright.  The model admits exactly this
witness; Core's program comparison would reject it. -/
theorem commitmentForcesProgramMatch_fails_of_program_mismatch
    (spk : Script) (program control leafScript : ByteArray)
    (hsz : spk.bytes.size = 34)
    (h0 : (spk.bytes.get! 0).toNat = 0x51)
    (h1 : (spk.bytes.get! 1).toNat = 32)
    (hsize : controlBlockSizeOk control = true)
    (hcommit : commitmentOf control program leafScript = true)
    (hmis : programMatches spk program = false) :
    ¬ CommitmentForcesProgramMatch := by
  intro hforces
  have hm : programMatches spk program = true :=
    hforces spk program control leafScript hsz h0 h1 hsize hcommit
  rw [hmis] at hm
  simp at hm

/-- **Conditional refutation of the target.**  If some accepting
commitment has a wallet program that does not match the spent script,
then `V1SpendJudgedTarget` is false.  The hypotheses are exactly the
witness Core's program comparison would exclude; the model admits it
because `verifyTaprootCommitment` ignores `program`. -/
theorem v1SpendJudgedTarget_fails_of_program_mismatch
    (spk : Script) (program control leafScript : ByteArray)
    (hsz : spk.bytes.size = 34)
    (h0 : (spk.bytes.get! 0).toNat = 0x51)
    (h1 : (spk.bytes.get! 1).toNat = 32)
    (hsize : controlBlockSizeOk control = true)
    (hcommit : commitmentOf control program leafScript = true)
    (hmis : programMatches spk program = false) :
    ¬ V1SpendJudgedTarget := by
  intro htarget
  exact commitmentForcesProgramMatch_fails_of_program_mismatch
    spk program control leafScript hsz h0 h1 hsize hcommit hmis
    ((v1SpendJudgedTarget_iff_commitmentForcesProgramMatch).mp htarget)

/-- The verifier-level half of the missing link: an accepting commitment
must imply that its `program` argument is the output key recomputed from
the control block and leaf script.  Core performs this comparison at
`src/script/interpreter.cpp:1919-1924` (`q.CheckTapTweak`) via
`src/pubkey.cpp:257-263`; the executable model does not.  Core also
calls the verifier with the *spent script's* program, which is why this
comparison yields `CommitmentForcesProgramMatch` for a real P2TR
output. -/
def VerifyComparesProgram : Prop :=
  ∀ (control program leafScript : ByteArray),
    verifyTaprootCommitment control program
        (scriptPathTapleaf control leafScript) = true →
      committedProgram control leafScript = some program

/-- Any accepting verdict with a mismatched recomputed output key refutes
`VerifyComparesProgram`.  This is a conditional refutation: the module
does not construct such a verdict (that needs curve arithmetic outside
this bridge). -/
theorem verifyComparesProgram_false_of_witness
    (control program leafScript : ByteArray)
    (hcommit : verifyTaprootCommitment control program
      (scriptPathTapleaf control leafScript) = true)
    (hmismatch : committedProgram control leafScript ≠ some program) :
    ¬ VerifyComparesProgram := by
  intro hlink
  exact hmismatch (hlink control program leafScript hcommit)

/-- The model's commitment verdict is invariant under its `program`
argument: the exact statement of the consensus gap, by `rfl`
(`spec/core/Bitcoin/Crypto/Taproot/Verify.lean:89-90`). -/
theorem verifyTaprootCommitment_program_irrelevant
    (control p₁ p₂ tapleafHash : ByteArray) :
    verifyTaprootCommitment control p₁ tapleafHash =
      verifyTaprootCommitment control p₂ tapleafHash := rfl

/-! ## The v1 lane in the capstone -/

/-- A scriptPubKey whose decoder returns a v1 program is a Taproot
program for the capstone gate (`isTaprootProgram`,
`spec/core/Bitcoin/Capstone/Block.lean:217-221`). -/
theorem isTaprootProgram_of_programOf {spk : Script} {program : ByteArray}
    (h : programOf spk = some (1, program)) :
    Bitcoin.Capstone.Block.isTaprootProgram spk.bytes = true := by
  unfold Bitcoin.Capstone.Block.isTaprootProgram
  have h' : Bitcoin.Interpreter.isWitnessProgram spk.bytes = some (1, program) := by
    simpa [Bitcoin.Wallet.Taproot.programOf] using h
  rw [h']
  simp

/-- Every v1 spend is routed to the unjudged lane before script
execution (`verifyInput`, `spec/core/Bitcoin/Capstone/Block.lean:242-245`).
This is the second half of the consensus gap: even the program-blind
commitment verdict is not consulted for a v1 input in this tree. -/
theorem verifyInput_unjudged_of_v1_program
    (height : UInt32) (tx : Bitcoin.Data.Tx) (i : Nat) (coin : Bitcoin.Ledger.Coin)
    (txIdx inputIdx : Nat) (program : ByteArray)
    (h : programOf coin.scriptPubKey = some (1, program)) :
    Bitcoin.Capstone.Block.verifyInput height tx i coin txIdx inputIdx =
      Bitcoin.Capstone.Block.InputVerdict.unjudgedTaproot := by
  unfold Bitcoin.Capstone.Block.verifyInput
  rw [ite_eq_left (isTaprootProgram_of_programOf h)]

/-- The same routing from the 34-byte wire shape, without naming the
extracted program. -/
theorem verifyInput_unjudged_of_v1_34
    (height : UInt32) (tx : Bitcoin.Data.Tx) (i : Nat) (coin : Bitcoin.Ledger.Coin)
    (txIdx inputIdx : Nat)
    (h0 : (coin.scriptPubKey.bytes.get! 0).toNat = 0x51)
    (h1 : (coin.scriptPubKey.bytes.get! 1).toNat = 32)
    (hsz : coin.scriptPubKey.bytes.size = 34) :
    Bitcoin.Capstone.Block.verifyInput height tx i coin txIdx inputIdx =
      Bitcoin.Capstone.Block.InputVerdict.unjudgedTaproot :=
  verifyInput_unjudged_of_v1_program height tx i coin txIdx inputIdx
    (coin.scriptPubKey.bytes.extract 2 coin.scriptPubKey.bytes.size)
    (programOf_v1_34 coin.scriptPubKey h0 h1 hsz)

/-! ## Axiom footprints

Every theorem above is sorry-free and uses only the standard Lean
axioms.  The `#print axioms` lines below pin the footprint of the
bridge surface. -/

#print axioms programOfEq_eq_true_iff
#print axioms programOf_v1_34_unique
#print axioms programOf_v1_34_exact
#print axioms programMatches_iff_payload
#print axioms programMatches_v1_34_payload_iff
#print axioms decidable_programOf_eq
#print axioms decidable_programMatches
#print axioms v1Spend_judged_iff_programMatches_and_commitment
#print axioms v1SpendJudgedTarget_iff_commitmentForcesProgramMatch
#print axioms commitmentForcesProgramMatch_fails_of_program_mismatch
#print axioms v1SpendJudgedTarget_fails_of_program_mismatch
#print axioms verifyComparesProgram_false_of_witness
#print axioms verifyTaprootCommitment_program_irrelevant
#print axioms verifyInput_unjudged_of_v1_program
#print axioms verifyInput_unjudged_of_v1_34

end BitcoinProofs.Wallet.Taproot
