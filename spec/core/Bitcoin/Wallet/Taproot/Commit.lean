import Bitcoin.Data.Script
import Bitcoin.Interpreter.Defs
import Bitcoin.Crypto.Taproot.Verify

/-!
# Wallet spent-program and Taproot commitment relations

`programOf` reuses the interpreter's witness-program decoder. The wallet
predicates relate the claimed program to the spent script and to the real
control/leaf commitment. The verifier's accepting commitment binds the exact
32-byte program to the recomputed output key; conditional wallet theorems
make that relation explicit.

`W1_taprootSpendJudged` is a standalone target with independently quantified
script and program arguments. Control size alone cannot establish their
relation. It remains a target, and wallet predicates alone do not establish
signature correctness or valid script execution. The live capstone now
performs real key/script-path adjudication with complete spent-output data.
-/

namespace Bitcoin.Wallet.Taproot

open Bitcoin.Data (Script serU8 bytesBEq)
open Bitcoin.Interpreter (isWitnessProgram)
open Bitcoin.Crypto.Taproot.Program
  (controlBlockSizeOk leafVersionOf p2trScript TAPROOT_LEAF_TAPSCRIPT)
open Bitcoin.Crypto.Taproot.OutputKey (tweakedKey)
open Bitcoin.Crypto.Taproot.Verify
  (scriptPathTapleaf scriptPathMerkleRoot scriptPathSpend
   verifyTaprootCommitment natToBytesBE natToBytesBE_size)

/-! ## Byte equality used by the wallet predicate

The executable tree uses the plain `bytesBEq` function rather than a
`LawfulBEq` instance for `ByteArray` (`Bitcoin.Data.Basic:37-39`).  The
two facts below are the Boolean/equality bridge needed by
`programMatches`. -/

/-- `bytesBEq` is sound for real byte-array equality. -/
theorem bytesBEq_eq_true (a b : ByteArray) (h : bytesBEq a b = true) :
    a = b := by
  simp only [bytesBEq, decide_eq_true_eq] at h
  obtain ⟨hsz, hall⟩ := h
  refine ByteArray.ext (Array.ext hsz (fun i h1 h2 => ?_))
  have hget : a.get! i = b.get! i := by
    have hm : i ∈ List.range a.size := List.mem_range.mpr h1
    exact eq_of_beq (List.all_eq_true.mp hall i hm)
  rw [show a.data[i] = a.get! i from by
        rw [← getElem!_pos a.data i h1]; rfl,
      show b.data[i] = b.get! i from by
        rw [← getElem!_pos b.data i h2]; rfl]
  exact hget

/-- `bytesBEq` is reflexive. -/
theorem bytesBEq_self_eq_true (b : ByteArray) : bytesBEq b b = true := by
  unfold bytesBEq
  simp

/-! ## Program decomposition and equality -/

/-- The witness-program decomposition of a spent `scriptPubKey`:
`some (version, program)` exactly when the consensus decoder
`IsWitnessProgram` recognises it (`Bitcoin.Interpreter.Defs:489-501`,
Core `script/script.h:250-264`). -/
def programOf (spk : Script) : Option (Nat × ByteArray) :=
  isWitnessProgram spk.bytes

/-- The Taproot (v1) program carried by `spk`, if the script is a v1
witness program.  Version zero and future versions are deliberately
excluded: this predicate is specific to the BIP341 lane. -/
def taprootProgramOf (spk : Script) : Option ByteArray :=
  match programOf spk with
  | some (1, program) => some program
  | _ => none

/-- Wallet-side program equality: `spk` is a v1 witness program and its
32-byte payload equals `program`.  The byte comparison is the consensus
`bytesBEq`, not a decision procedure for an unavailable `DecidableEq`
instance on `ByteArray`. -/
def programMatches (spk : Script) (program : ByteArray) : Bool :=
  match programOf spk with
  | some (v, p) => if v = 1 then bytesBEq p program else false
  | none => false

/-- The propositional reading of `programMatches`. -/
def ProgramMatches (spk : Script) (program : ByteArray) : Prop :=
  programOf spk = some (1, program)

/-- The Boolean predicate is sound and complete for the propositional
reading: it is true exactly when the spent script's v1 program is
`program`. -/
theorem programMatches_eq_true_iff (spk : Script) (program : ByteArray) :
    programMatches spk program = true ↔ ProgramMatches spk program := by
  unfold programMatches ProgramMatches
  cases h : programOf spk with
  | none => simp
  | some vp =>
      obtain ⟨v, p⟩ := vp
      dsimp only
      by_cases hv : v = 1
      · rw [ite_eq_left hv]
        constructor
        · intro hb
          have hp : p = program := bytesBEq_eq_true p program hb
          rw [hv, hp]
        · intro hsome
          have hconj : v = 1 ∧ p = program := by simpa using hsome
          have hp : p = program := hconj.2
          rw [hp, bytesBEq_self_eq_true]
      · rw [ite_eq_right hv]
        constructor
        · intro hfalse
          exact (Bool.false_eq_true.mp hfalse).elim
        · intro hsome
          have hconj : v = 1 ∧ p = program := by simpa using hsome
          exact absurd hconj.1 hv

/-- `ProgramMatches` is decidable, by evaluation of the Boolean
predicate. -/
instance (spk : Script) (program : ByteArray) : Decidable (ProgramMatches spk program) :=
  decidable_of_iff (programMatches spk program = true)
    (programMatches_eq_true_iff spk program)

/-- A scriptPubKey with the 34-byte v1 template (`0x51 0x20` followed by
32 program bytes) decomposes to version `1` and the trailing program.
The hypotheses are the byte-level shape Core's `IsWitnessProgram`
recognises. -/
theorem programOf_v1_34 (spk : Script)
    (h0 : (spk.bytes.get! 0).toNat = 0x51)
    (h1 : (spk.bytes.get! 1).toNat = 32)
    (hsz : spk.bytes.size = 34) :
    programOf spk = some (1, spk.bytes.extract 2 spk.bytes.size) := by
  unfold programOf Bitcoin.Interpreter.isWitnessProgram
  rw [hsz, h0, h1]
  simp

/-- The program returned by `programOf_v1_34` has exactly 32 bytes. -/
theorem programOf_v1_34_size (spk : Script)
    (hsz : spk.bytes.size = 34) :
    (spk.bytes.extract 2 spk.bytes.size).size = 32 := by
  rw [ByteArray.size_extract, hsz]
  omega

/-- On a v1 34-byte scriptPubKey, `programMatches` is true exactly when
the trailing program equals the supplied bytes. -/
theorem programMatches_v1_34_iff (spk : Script) (program : ByteArray)
    (h0 : (spk.bytes.get! 0).toNat = 0x51)
    (h1 : (spk.bytes.get! 1).toNat = 32)
    (hsz : spk.bytes.size = 34) :
    programMatches spk program = true ↔
      spk.bytes.extract 2 spk.bytes.size = program := by
  rw [programMatches_eq_true_iff]
  unfold ProgramMatches
  rw [programOf_v1_34 spk h0 h1 hsz]
  simp

/-- The canonical P2TR constructor `OP_1 <32B>` (`Bitcoin.Crypto.Taproot.Program.p2trScript`,
`spec/core/Bitcoin/Crypto/Taproot/Program.lean:80-83`; BIP341
§"Constructing and spending Taproot outputs").  Re-exported here so the
wallet layer can state its program facts without naming the consensus
namespace. -/
def p2trScriptPubKey (program : ByteArray) : ByteArray :=
  p2trScript program

/-- `programOf` of the canonical P2TR script recovers exactly the
32-byte program that was placed in it. -/
theorem programOf_p2trScript (program : ByteArray) (h : program.size = 32) :
    programOf ⟨p2trScript program⟩ = some (1, program) := by
  have h2 : (serU8 0x51 ++ serU8 32).size = 2 := rfl
  have hsz : (p2trScript program).size = 2 + program.size := by
    unfold p2trScript
    rw [ByteArray.size_append, h2]
  have h0 : ((p2trScript program).get! 0).toNat = 0x51 := by
    unfold p2trScript serU8; rfl
  have h1 : ((p2trScript program).get! 1).toNat = 32 := by
    unfold p2trScript serU8; rfl
  have hext : (p2trScript program).extract 2 (p2trScript program).size = program := by
    unfold p2trScript
    rw [show (serU8 0x51 ++ serU8 32 ++ program).size = 2 + program.size from
      by rw [ByteArray.size_append, h2]]
    exact ByteArray.extract_append_eq_right h2.symm (by omega)
  rw [programOf_v1_34 ⟨p2trScript program⟩ h0 h1 (by rw [hsz, h])]
  change some (1, (p2trScript program).extract 2
    (p2trScript program).size) = some (1, program)
  rw [hext]

/-- Program equality on the canonical P2TR script is literal equality of
the 32-byte program. -/
theorem programMatches_p2trScript (p q : ByteArray) (hp : p.size = 32) :
    programMatches ⟨p2trScript p⟩ q = true ↔ p = q := by
  rw [programMatches_eq_true_iff]
  unfold ProgramMatches
  rw [programOf_p2trScript p hp]
  simp

/-! ## The control-block / internal-key commitment -/

/-- The tapleaf hash of a script-path spend: the consensus
`scriptPathTapleaf` under the masked leaf version
(`Bitcoin.Crypto.Taproot.Verify:58-60`, Core
`src/script/interpreter.cpp:1983`). -/
def leafHash (control leafScript : ByteArray) : ByteArray :=
  scriptPathTapleaf control leafScript

/-- The merkle root committed to by a control block for a leaf script,
reconstructed from the control block's path. -/
def committedMerkleRoot (control leafScript : ByteArray) : Option ByteArray :=
  some (scriptPathMerkleRoot control (leafHash control leafScript))

/-- The x-only output key that a control block commits to for a leaf
script: parse the internal key, apply the BIP341 tweak, and serialise the
x-coordinate.  This is the wallet-layer counterpart of the output key
Core compares with the scriptPubKey program. -/
def committedProgram (control leafScript : ByteArray) : Option ByteArray :=
  (tweakedKey control (committedMerkleRoot control leafScript)).map
    (fun Q => natToBytesBE 32 Q.1)

/-- The consensus commitment verdict in wallet vocabulary.  The
`program` argument is the x-only output key and is bound by the verdict
(see `commitmentOf_program_binding`). -/
def commitmentOf (control program leafScript : ByteArray) : Bool :=
  verifyTaprootCommitment control program (leafHash control leafScript)

/-- A wallet script-path spend is committed when the spent scriptPubKey
is the v1 program the control block commits to, the recomputed output
key equals that program, and the consensus commitment verdict accepts
the tapleaf. -/
def SpendCommitment (spk : Script) (program control leafScript : ByteArray) : Prop :=
  programMatches spk program = true ∧
    committedProgram control leafScript = some program ∧
    commitmentOf control program leafScript = true

theorem spendCommitment_programMatches (spk : Script) (program control leafScript : ByteArray)
    (h : SpendCommitment spk program control leafScript) :
    programMatches spk program = true :=
  h.1

theorem spendCommitment_programOf (spk : Script) (program control leafScript : ByteArray)
    (h : SpendCommitment spk program control leafScript) :
    programOf spk = some (1, program) :=
  (programMatches_eq_true_iff spk program).mp h.1

theorem spendCommitment_committedProgram (spk : Script) (program control leafScript : ByteArray)
    (h : SpendCommitment spk program control leafScript) :
    committedProgram control leafScript = some program :=
  h.2.1

theorem spendCommitment_verdict (spk : Script) (program control leafScript : ByteArray)
    (h : SpendCommitment spk program control leafScript) :
    commitmentOf control program leafScript = true :=
  h.2.2

/-- A committed program is 32 bytes: it is the x-coordinate serialisation
produced by the BIP341 tweak lane. -/
theorem spendCommitment_program_size (spk : Script) (program control leafScript : ByteArray)
    (h : SpendCommitment spk program control leafScript) :
    program.size = 32 := by
  have hc : committedProgram control leafScript = some program := h.2.1
  unfold committedProgram committedMerkleRoot leafHash at hc
  cases ht : tweakedKey control
      (some (scriptPathMerkleRoot control (scriptPathTapleaf control leafScript))) with
  | none => simp [ht] at hc
  | some Q =>
      simp [ht] at hc
      rw [← hc]
      exact natToBytesBE_size 32 Q.1

/-- Given the two program facts, `SpendCommitment` is exactly the
consensus commitment verdict.  The consensus function now performs the
program comparison, so `spendCommitment_committedProgram` is a
consequence of the verdict rather than an extra wallet premise. -/
theorem spendCommitment_iff_verdict (spk : Script) (program control leafScript : ByteArray)
    (hm : programMatches spk program = true)
    (hc : committedProgram control leafScript = some program) :
    SpendCommitment spk program control leafScript ↔
      commitmentOf control program leafScript = true := by
  unfold SpendCommitment
  rw [hm, hc]
  simp

/-! ## The program-binding facts -/

/-- An accepted consensus commitment binds its `program` argument to the
output key recomputed from the control block and leaf script: the
program is exactly the canonical 32-byte `x(Q)` serialization.  This is
Core's `q.CheckTapTweak` comparison (`src/script/interpreter.cpp:1919-1924`,
`src/pubkey.cpp:257-263`). -/
theorem commitmentOf_program_binding (control program leafScript : ByteArray)
    (h : commitmentOf control program leafScript = true) :
    committedProgram control leafScript = some program := by
  unfold commitmentOf at h
  unfold committedProgram committedMerkleRoot leafHash
  obtain ⟨xQ, yQ, ht, hprog⟩ :=
    Bitcoin.Crypto.Taproot.Verify.verifyTaprootCommitment_program_eq
      control program (scriptPathTapleaf control leafScript) h
  rw [ht]
  simp [hprog]

/-- An accepted script-path arm likewise binds its `program` argument.
The control-block size gate is the only precondition for the arm to
reach the commitment verdict. -/
theorem scriptPathSpend_program_binding
    (control leafScript program : ByteArray) (tl : ByteArray) (ts : Bool)
    (h : scriptPathSpend control leafScript program = some (tl, true, ts)) :
    committedProgram control leafScript = some program := by
  unfold scriptPathSpend at h
  by_cases hg : controlBlockSizeOk control
  · rw [ite_eq_left hg] at h
    injection h with h1
    injection h1 with _ h2
    injection h2 with hcommit _
    exact commitmentOf_program_binding control program leafScript (by
      simpa [commitmentOf, leafHash] using hcommit)
  · rw [ite_eq_right hg] at h
    simp at h

/-- Under the control-block size gate, the script-path arm is judged
(its commitment bit is `true`) exactly when the consensus commitment
verdict is `true`. -/
theorem taprootSpendJudged_iff_commitment
    (program control leafScript : ByteArray)
    (hsize : controlBlockSizeOk control = true) :
    (∃ tl ts, scriptPathSpend control leafScript program = some (tl, true, ts)) ↔
      commitmentOf control program leafScript = true := by
  unfold scriptPathSpend commitmentOf leafHash
  rw [ite_eq_left hsize]
  simp

/-- A standalone target with independently supplied spent script and wallet
program. A valid control size alone cannot imply that those arguments match.
`spendCommitment_iff_verdict` proves the conditional relation. The live
capstone's actual-program dataflow does not prove this unrelated-arguments
proposition, and this target does not assert a complete signed spend. -/
def W1_taprootSpendJudged : Prop :=
  ∀ (spk : Script) (program control leafScript : ByteArray),
    controlBlockSizeOk control = true →
    ((∃ tl ts, scriptPathSpend control leafScript program = some (tl, true, ts)) ↔
      (programMatches spk program = true ∧
        commitmentOf control program leafScript = true))

end Bitcoin.Wallet.Taproot
