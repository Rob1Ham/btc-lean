import BitcoinProofs.Wallet.Taproot.Program
import Bitcoin.Capstone.Block

/-!
# Wallet Taproot program and commitment bridge

Proves exact v1 program decoding, wallet program equality and real verifier
output-key binding. The conditional wallet spend theorem requires the
supplied wallet program to match the spent script. The standalone target
`V1SpendJudgedTarget` quantifies over an unrelated wallet program and script;
its equivalent missing premise is isolated below. That logical target is
not a consensus-validator claim.

The public capstone now runs `verifyScriptFull` with a typed real Schnorr
adapter and all spent outputs from the current UTXO view. The old two
unconditional claims that every v1 input is unjudged have been removed:
they are false after that repair. Public integration and cache/status proofs
live in the capstone regression/proof modules. This wallet module does not
claim full spend validity, signature correctness or script execution from
program matching alone.
-/

namespace BitcoinProofs.Wallet.Taproot

open Bitcoin.Data (Script bytesBEq)
open Bitcoin.Wallet.Taproot
  (programOf programMatches ProgramMatches commitmentOf
   programOf_v1_34 programOf_v1_34_size
   programMatches_eq_true_iff
   bytesBEq_eq_true bytesBEq_self_eq_true
   taprootSpendJudged_iff_commitment programOf_p2trScript
   committedProgram commitmentOf_program_binding leafHash)
open Bitcoin.Crypto.Taproot.Program (controlBlockSizeOk p2trScript)
open Bitcoin.Crypto.Taproot.Verify
  (scriptPathSpend scriptPathTapleaf scriptPathMerkleRoot verifyTaprootCommitment
   verifyTaprootCommitment_program_eq natToBytesBE)

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
The verdict itself now binds `program` to `x(Q)`; this equivalence is
only the arm's success condition. -/
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
the `programMatches` premise relates `spk` to the definition's `program`
argument, which the verifier does not see. -/
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

This is false in the executable tree whenever `spk` names a v1 program
different from the definition's `program` argument: the arm's verdict
binds `program` (`verifyTaprootCommitment_program_binding`), but nothing
ties `spk` to that argument here, so the forward direction fails.  It is
stated as a `def` so downstream work can name the obligation without
asserting it. -/
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
program.  This is the entire forward direction the target lacks: the
verifier binds `program`, but the definition does not relate `spk`'s
payload to that argument. -/
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
`CommitmentForcesProgramMatch` outright.  The logical target supplies no relation between the independently
quantified spent script and wallet program. -/
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
then `V1SpendJudgedTarget` is false.  The hypotheses expose the absent script/program relation in this
standalone logical target; the actual verifier binds its program argument. -/
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
implies that its `program` argument is the output key recomputed from
the control block and leaf script.  This is Core's
`src/script/interpreter.cpp:1919-1924` (`q.CheckTapTweak`) via
`src/pubkey.cpp:257-263`, implemented in the model by
`Verify.checkTapTweak` (length-checked `program = x(Q)` byte equality). -/
def VerifyComparesProgram : Prop :=
  ∀ (control program leafScript : ByteArray),
    verifyTaprootCommitment control program
        (scriptPathTapleaf control leafScript) = true →
      committedProgram control leafScript = some program

/-- `VerifyComparesProgram` is proved: the verifier's output-key binding
is exactly the wallet's `committedProgram` equality. -/
theorem verifyComparesProgram_holds : VerifyComparesProgram := by
  intro control program leafScript hcommit
  exact commitmentOf_program_binding control program leafScript (by
    simpa [commitmentOf, leafHash] using hcommit)

/-- The verifier binds its `program` argument (the re-exported
program-comparison fact). -/
theorem verifyTaprootCommitment_program_binding
    (control program tapleafHash : ByteArray)
    (h : verifyTaprootCommitment control program tapleafHash = true) :
    ∃ xQ yQ,
      Bitcoin.Crypto.Taproot.OutputKey.tweakedKey control
          (some (scriptPathMerkleRoot control tapleafHash)) = some (xQ, yQ) ∧
        program = natToBytesBE 32 xQ :=
  verifyTaprootCommitment_program_eq control program tapleafHash h

/-! ## The v1 lane in the capstone -/

/-- A v1 decoded program satisfies the historical recognition helper.
The public validator no longer uses this helper as a bypass gate. -/
theorem isTaprootProgram_of_programOf {spk : Script} {program : ByteArray}
    (h : programOf spk = some (1, program)) :
    Bitcoin.Capstone.Block.isTaprootProgram spk.bytes = true := by
  unfold Bitcoin.Capstone.Block.isTaprootProgram
  have h' : Bitcoin.Interpreter.isWitnessProgram spk.bytes = some (1, program) := by
    simpa [Bitcoin.Wallet.Taproot.programOf] using h
  rw [h']
  simp

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
#print axioms verifyComparesProgram_holds
#print axioms verifyTaprootCommitment_program_binding

end BitcoinProofs.Wallet.Taproot
