import Bitcoin.Crypto.Taproot.Tree
import Bitcoin.Crypto.Taproot.OutputKey

/-!
# Bitcoin.Crypto.Taproot.Verify — the taproot commitment verdict (the Taproot module)

The script-path SPEND composition (Core `interpreter.cpp:1976-1990`, the
`else` arm of `VerifyWitnessProgram`'s taproot branch) and the P2TR
OUTPUT construction (BIP341 §"Constructing and spending Taproot
outputs"), assembling the committed primitives:

* `scriptPathTapleaf` — TPR-012's CALLER side: the tapleaf hash under
  the MASKED leaf version `control[0] & 0xfe` (the witness-structure module's `leafVersionOf`,
  TPR-010; Core masks at the call site interpreter.cpp:1983 — the verifier
  does the masking, per the Tree-module note).
* `pathNodes` / `scriptPathMerkleRoot` — TPR-014's caller side: the
  control block's `m` 32-byte path nodes (`(size − 33) / 32` of them,
  TPR-009 lattice) walked by `taprootMerkleRoot`
  (Core `ComputeTaprootMerkleRoot` interpreter.cpp:1898-1911).
* `verifyTaprootCommitment` — Core `VerifyTaprootCommitment`
  (interpreter.cpp:1913-1924) = `checkTapTweak` under the
  path-recomputed root: internal-key parse (TPR-018) → tweak
  recomputation `Q = P + int(t)·G` (TPR-016/017) → output-key
  binding `program = x(Q)` (Core `q.CheckTapTweak`) and parity
  `control[0]&1 =? y(Q)&1` (TPR-011). The 32-byte program is the
  x-only output key, so the binding is length-checked and byte-equal —
  not a `bytesToNatBE` numeric comparison.
* `scriptPathSpend` — the full arm verdict: the TPR-009 size gate
  (Core :1980-1982 reject), then tapleaf hash + commitment verdict +
  tapscript dispatch (Core :1988: `control[0] & MASK == 0xc0` ⇒
  SigVersion TAPSCRIPT; TPR-019/020's dispatch fact — other leaf
  versions are the non-tapscript success lane).
* `TapTree` / `treeHash` / `treeMerkleRoot` / `p2trOutput` — the
  OUTPUT construction: `Q = P + hash_TapTweak(P ‖ root)·G`, scriptPubKey
  `0x51 0x20 ‖ x(Q)` (BIP341 §Constructing; conformance = the wallet
  vectors' `scriptPubKey` section, ALL 7 cases).

Conformance: `Test/Crypto/TaprootVerifyTest.lean` (7/7 official
scriptPubKey-section output cases — merkleRoot/tweakedPubkey/scriptPubKey
— plus synthetic script-path accept/reject verdicts; NO official
script-path SPEND vectors exist, documented honestly) +
`Test/Crypto/taproot_sighash_crosscheck.py`-style independent mirror
`Test/Crypto/taproot_verify_crosscheck.py` (pure-python secp256k1).

No `sorry`, no `native_decide`; axiom pins at the bottom, footprints ⊆
the standard trio.
-/

namespace Bitcoin.Crypto.Taproot.Verify

open Bitcoin.Data (serU8)
open Bitcoin.Crypto.Curve.Secp (liftX bytesToNatBE RawPoint)
open Bitcoin.Crypto.Schnorr (append_size)
open Bitcoin.Crypto.Taproot (tapLeaf tapBranch taprootMerkleRoot tweakPoint)
open Bitcoin.Crypto.Taproot.OutputKey (outputKeyOk tweakedKey)
open Bitcoin.Crypto.Taproot.Program (controlBlockSizeOk controlBlockSizeOk_sizes
  controlBlockSizeOk_minimal leafVersionOf TAPROOT_LEAF_TAPSCRIPT)

/-- `n` as a `width`-byte big-endian string (test/wire helper; BIP341
x-only keys are 32-byte BE). -/
def natToBytesBE : Nat → Nat → ByteArray
  | 0, _ => ByteArray.empty
  | width + 1, n => natToBytesBE width (n / 256) ++ serU8 ((n % 256).toUInt8)

/-! ## Script path: tapleaf + merkle (interpreter.cpp:1976-1990) -/

/-- The script-path tapleaf hash: `tapLeaf(control[0] & 0xfe, script)` —
the masked version (interpreter.cpp:1983; TPR-012's call site). -/
def scriptPathTapleaf (control script : ByteArray) : ByteArray :=
  tapLeaf (leafVersionOf control).toUInt8 script

/-- The control block's path-node count: `(size − 33) / 32` (Core
:1904, `path_len`; the TPR-009 lattice makes this exact). FIX:
was `(size − 65) / 32` (self-consistent with the old 65-constant). -/
def pathNodeCount (control : ByteArray) : Nat := (control.size - 33) / 32

/-- The `m` path nodes: 32 bytes each, starting at offset 33 (Core
:1907, `subspan(BASE + NODE·i, NODE)`). Out-of-range extractions
fail closed to short slices — the TPR-009 gate is the caller.
FIX: was offset 65 (the witness-structure module's Program.lean 65-convention). -/
def pathNodes (control : ByteArray) : List ByteArray :=
  (List.range (pathNodeCount control)).map
    (fun i => control.extract (33 + 32 * i) (65 + 32 * i))

/-- The merkle root recomputed from the control-block path
(interpreter.cpp:1898-1911; TPR-014's caller). -/
def scriptPathMerkleRoot (control tapleafHash : ByteArray) : ByteArray :=
  taprootMerkleRoot (pathNodes control) tapleafHash

/-! ## The commitment verdict (interpreter.cpp:1913-1924) -/

/-- Core `XOnlyPubKey::CheckTapTweak` as `VerifyTaprootCommitment` calls
it (interpreter.cpp:1913-1924, pubkey.cpp:255-271): the witness program
is the x-only output key `q = x(Q)`, so it must be exactly 32 bytes and
BYTE-EQUAL to the canonical 32-byte big-endian serialization of the
x-coordinate of `Q = P + int(t)·G`, in addition to the TPR-011 parity
test on `control[0]`. The length test is explicit: a longer or shorter
program is never accepted merely because it parses to the same `Nat`
(`bytesToNatBE` alone would ignore leading bytes). -/
def checkTapTweak (control program : ByteArray) (root : Option ByteArray) : Bool :=
  outputKeyOk control root &&
    (decide (program.size = 32) &&
      match tweakedKey control root with
      | none => false
      | some (xQ, _) => decide (natToBytesBE 32 xQ = program))

/-- `VerifyTaprootCommitment` (interpreter.cpp:1913-1924): the output
key `q` (the scriptPubKey's 32-byte witness program) must equal the
tweaked internal key under the path-recomputed merkle root, with
`control[0]&1` the parity of `y(Q)` (Core's `q.CheckTapTweak(p,
merkle_root, control[0] & 1)`). Core's base-size `assert` (:1915) is
the caller's TPR-009 gate; `outputKeyOk` fails closed below 33 bytes
anyway. -/
def verifyTaprootCommitment (control program tapleafHash : ByteArray) : Bool :=
  checkTapTweak control program (some (scriptPathMerkleRoot control tapleafHash))

/-- The script-path spend arm (interpreter.cpp:1976-1990): `none` = the
TPR-009 size reject (Core :1980-1982); `some (tapleafHash, committed,
isTapscript)` = the leaf hash, the commitment verdict, and the 0xc0
dispatch bit (Core :1988; TPR-019/020). -/
def scriptPathSpend (control script program : ByteArray) :
    Option (ByteArray × Bool × Bool) :=
  if controlBlockSizeOk control then
    let tl := scriptPathTapleaf control script
    some (tl, verifyTaprootCommitment control program tl,
      leafVersionOf control = TAPROOT_LEAF_TAPSCRIPT)
  else none

/-! ## Output construction (BIP341 §"Constructing and spending") -/

/-- A script tree: a leaf (version + script) or a binary node. The
wallet vectors' `scriptTree` shape (leaf version 0xc0 = TAPSCRIPT, 0xfa
= the future-version test leaf). -/
inductive TapTree where
  | leaf : UInt8 → ByteArray → TapTree
  | node : TapTree → TapTree → TapTree

/-- The leaf/Branch hash ladder: leaves hash via `tapLeaf`, interior
nodes via the sorted `tapBranch` (TPR-012/013; BIP341:76-79). -/
def treeHash : TapTree → ByteArray
  | .leaf v s => tapLeaf v s
  | .node a b => tapBranch (treeHash a) (treeHash b)

/-- `scriptTree = null` ⇒ `merkleRoot = null` (wallet case 0); a tree
hashes to its root. -/
def treeMerkleRoot (t : Option TapTree) : Option ByteArray := t.map treeHash

/-- The P2TR output: `0x51 0x20 ‖ x(Q)` where
`Q = P + hash_TapTweak(P ‖ root)·G` (BIP341 §Constructing, steps 1-5;
`tree = none` = the key-path-only output, wallet case 0). `none` =
internal key does not lift (TPR-018's construction side) or the tweak
overflows / hits infinity (TPR-016/017). -/
def p2trOutput (internalPubkey : ByteArray) (tree : Option TapTree) :
    Option ByteArray :=
  match liftX (bytesToNatBE internalPubkey) with
  | none => none
  | some P =>
  match tweakPoint internalPubkey P (treeMerkleRoot tree) with
  | none => none
  | some Q => some (serU8 0x51 ++ serU8 0x20 ++ natToBytesBE 32 Q.1)

/-! ## Size / shape contracts -/

theorem serU8_size (x : UInt8) : (serU8 x).size = 1 := rfl

theorem natToBytesBE_size (width n : Nat) : (natToBytesBE width n).size = width := by
  induction width generalizing n with
  | zero => rfl
  | succ w ih =>
      unfold natToBytesBE
      rw [append_size, serU8_size, ih]

theorem treeHash_size (t : TapTree) : (treeHash t).size = 32 := by
  cases t with
  | leaf v s => exact tapLeaf_size v s
  | node a b => exact tapBranch_size _ _

theorem treeMerkleRoot_size (t : TapTree) :
    (treeMerkleRoot (some t)) = some (treeHash t) ∧ (treeHash t).size = 32 :=
  ⟨rfl, treeHash_size t⟩

theorem treeMerkleRoot_none : treeMerkleRoot none = none := rfl

/-- The script-path tapleaf is a 32-byte digest (TPR-012's size
contract through the masked version). -/
theorem scriptPathTapleaf_size (control script : ByteArray) :
    (scriptPathTapleaf control script).size = 32 :=
  tapLeaf_size _ _

/-- The path-node count is the TPR-009 lattice quotient. -/
theorem pathNodeCount_def (control : ByteArray) :
    pathNodeCount control = (control.size - 33) / 32 := rfl

/-- The path list has exactly `m` nodes (`List.range` + `map`). -/
theorem pathNodes_length (control : ByteArray) :
    (pathNodes control).length = pathNodeCount control := by
  unfold pathNodes
  simp

/-- The commitment verdict is the `CheckTapTweak` composite under the
recomputed root (definitional). -/
theorem verifyTaprootCommitment_eq (control program tapleafHash : ByteArray) :
    verifyTaprootCommitment control program tapleafHash
      = checkTapTweak control program
          (some (scriptPathMerkleRoot control tapleafHash)) := rfl

/-- TPR-016 (accept ⇒ 32-byte program): an accepted commitment forces the
witness program to have the canonical x-only key length. -/
theorem checkTapTweak_program_size (control program : ByteArray)
    (root : Option ByteArray) (h : checkTapTweak control program root = true) :
    program.size = 32 := by
  unfold checkTapTweak at h
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h
  exact h.2.1

/-- TPR-016 (accept ⇒ x-coordinate binding): under the recomputed tweaked
key `Q = (xQ, yQ)`, an accepted commitment forces the program to be
exactly the canonical 32-byte big-endian encoding of `x(Q)`. This is
Core's `q.CheckTapTweak` output-key comparison. -/
theorem checkTapTweak_program_eq (control program : ByteArray)
    (root : Option ByteArray) (xQ yQ : Nat)
    (ht : tweakedKey control root = some (xQ, yQ))
    (h : checkTapTweak control program root = true) :
    program = natToBytesBE 32 xQ := by
  unfold checkTapTweak at h
  rw [ht] at h
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h
  exact h.2.2.symm

/-- TPR-016 (accept characterization): an accepted commitment is exactly
the conjunction of the parity/internal-key lane and a 32-byte program
equal to the serialized x-coordinate of the recomputed tweaked key. -/
theorem checkTapTweak_accept_iff (control program : ByteArray)
    (root : Option ByteArray) :
    checkTapTweak control program root = true ↔
      outputKeyOk control root = true ∧ program.size = 32 ∧
        ∃ xQ yQ, tweakedKey control root = some (xQ, yQ) ∧
          program = natToBytesBE 32 xQ := by
  constructor
  · intro h
    have hok : outputKeyOk control root = true := by
      unfold checkTapTweak at h
      exact (Bool.and_eq_true_iff.mp h).1
    have hsize : program.size = 32 :=
      checkTapTweak_program_size control program root h
    cases ht : tweakedKey control root with
    | none =>
        simp [outputKeyOk, ht] at hok
    | some Q =>
        obtain ⟨xQ, yQ⟩ := Q
        exact ⟨hok, hsize, xQ, yQ, rfl,
          checkTapTweak_program_eq control program root xQ yQ ht h⟩
  · rintro ⟨hok, hsize, xQ, yQ, ht, hprog⟩
    unfold checkTapTweak
    rw [ht]
    have hbe : decide (natToBytesBE 32 xQ = program) = true := by
      rw [hprog]
      simp
    simp [hok, hsize, hbe]

/-- TPR-016 (accept ⇒ 32-byte program) at the consensus entry point. -/
theorem verifyTaprootCommitment_program_size (control program tapleafHash : ByteArray)
    (h : verifyTaprootCommitment control program tapleafHash = true) :
    program.size = 32 := by
  rw [verifyTaprootCommitment_eq] at h
  exact checkTapTweak_program_size control program _ h

/-- TPR-016 (accept ⇒ program = x(Q)) at the consensus entry point: the
wrong-program case Core rejects at `q.CheckTapTweak`. -/
theorem verifyTaprootCommitment_program_eq (control program tapleafHash : ByteArray)
    (h : verifyTaprootCommitment control program tapleafHash = true) :
    ∃ xQ yQ,
      tweakedKey control (some (scriptPathMerkleRoot control tapleafHash))
          = some (xQ, yQ) ∧
        program = natToBytesBE 32 xQ := by
  rw [verifyTaprootCommitment_eq] at h
  have hc := (checkTapTweak_accept_iff control program
    (some (scriptPathMerkleRoot control tapleafHash))).mp h
  exact hc.2.2

/-- TPR-016 (negative: wrong program): with the recomputed output key
fixed at `(xQ, yQ)`, a 32-byte program that is not `x(Q)` is rejected.
This is the q-binding that makes the commitment program-sensitive. -/
theorem verifyTaprootCommitment_wrong_program (control program tapleafHash : ByteArray)
    (xQ yQ : Nat)
    (ht : tweakedKey control (some (scriptPathMerkleRoot control tapleafHash))
        = some (xQ, yQ))
    (hne : program ≠ natToBytesBE 32 xQ) :
    verifyTaprootCommitment control program tapleafHash = false := by
  rw [verifyTaprootCommitment_eq]
  unfold checkTapTweak
  rw [ht]
  have hb : decide (natToBytesBE 32 xQ = program) = false := by
    by_cases heq : decide (natToBytesBE 32 xQ = program) = true
    · have hEq : natToBytesBE 32 xQ = program := of_decide_eq_true heq
      exact absurd hEq.symm hne
    · simpa using heq
  simp [hb]

/-- TPR-016 (negative: wrong length): a program that is not 32 bytes is
rejected even if it parses to the same `Nat` as `x(Q)` — the length gate
that a pure `bytesToNatBE` comparison would miss. -/
theorem verifyTaprootCommitment_wrong_length (control program tapleafHash : ByteArray)
    (h : program.size ≠ 32) :
    verifyTaprootCommitment control program tapleafHash = false := by
  rw [verifyTaprootCommitment_eq]
  unfold checkTapTweak
  have hsz : decide (program.size = 32) = false := by
    simp [h]
  simp [hsz]

/-! ## Verdict theorems -/

/-- TPR-009 (reject side, script-path arm): a control block outside the
size lattice is rejected before any hashing (Core :1980-1982; the spec's
`TAPROOT_CONTROL_BASE_SIZE = 33` since the fix — Core's own
constant is 33, the pre-fix 65 was the confirmed spec defect). -/
theorem scriptPathSpend_badSize_none (control script program : ByteArray)
    (h : controlBlockSizeOk control = false) :
    scriptPathSpend control script program = none := by
  unfold scriptPathSpend
  rw [if_neg (by simp [h])]

/-- A 33-byte control block (m = 0) passes the size gate — the minimal
script-path shape (FIX: was `h : control.size = 65`, the old
65-convention's m = 0). -/
theorem scriptPathSpend_minimal_some (control script program : ByteArray)
    (h : control.size = 33) :
    ∃ r, scriptPathSpend control script program = some r := by
  refine ⟨(scriptPathTapleaf control script,
    verifyTaprootCommitment control program (scriptPathTapleaf control script),
    decide (leafVersionOf control = TAPROOT_LEAF_TAPSCRIPT)), ?_⟩
  unfold scriptPathSpend
  rw [if_pos (controlBlockSizeOk_minimal control h)]

/-- The dispatch bit of an accepted spend is exactly the 0xc0 test on
the masked leaf version (Core :1988; TPR-019/020's hook). -/
theorem scriptPathSpend_dispatch (control script program : ByteArray)
    (tl : ByteArray) (ok ts : Bool)
    (h : scriptPathSpend control script program = some (tl, ok, ts)) :
    ts = decide (leafVersionOf control = TAPROOT_LEAF_TAPSCRIPT) := by
  unfold scriptPathSpend at h
  by_cases hg : controlBlockSizeOk control
  · rw [if_pos hg] at h
    injection h with h'
    injection h' with _ h''
    injection h'' with _ hts
    exact hts.symm
  · rw [if_neg hg] at h
    exact absurd h (by simp)

/-- Determinism: equal inputs, equal verdicts. -/
theorem scriptPathSpend_congr (control₁ control₂ script₁ script₂ program₁ program₂ : ByteArray)
    (h₁ : control₁ = control₂) (h₂ : script₁ = script₂) (h₃ : program₁ = program₂) :
    scriptPathSpend control₁ script₁ program₁ = scriptPathSpend control₂ script₂ program₂ := by
  subst h₁; subst h₂; subst h₃; rfl

/-- The P2TR output, when it exists, has the exact template shape
`0x51 0x20 ‖ 32 bytes` (BIP341 §Constructing; TPR-001's construction
side). -/
theorem p2trOutput_shape (pk : ByteArray) (tree : Option TapTree)
    (spk : ByteArray) (h : p2trOutput pk tree = some spk) :
    spk.size = 34 ∧ spk.get! 0 = 0x51 ∧ spk.get! 1 = 0x20 := by
  unfold p2trOutput at h
  split at h
  · exact absurd h (by simp)
  · split at h
    · exact absurd h (by simp)
    · simp at h
      subst h
      refine ⟨by rw [append_size, append_size, serU8_size, serU8_size,
        natToBytesBE_size], rfl, rfl⟩

theorem p2trOutput_none_badKey (pk : ByteArray) (tree : Option TapTree)
    (h : liftX (bytesToNatBE pk) = none) :
    p2trOutput pk tree = none := by
  unfold p2trOutput
  rw [h]

/-- Determinism (the modular-arithmetic layer discipline): `p2trOutput` is a pure function. -/
theorem p2trOutput_congr (pk₁ pk₂ : ByteArray) (t₁ t₂ : Option TapTree)
    (h₁ : pk₁ = pk₂) (h₂ : t₁ = t₂) :
    p2trOutput pk₁ t₁ = p2trOutput pk₂ t₂ := by
  subst h₁; subst h₂; rfl

/-! ## Axiom footprints (the existing modules' style: `#guard_msgs in #print axioms`)

All sorry-free; footprints ⊆ the standard trio `[propext, Classical.choice,
Quot.sound]`. Pinned by the guard block below.
-/

/-- info: 'Bitcoin.Crypto.Taproot.Verify.serU8_size' does not depend on any axioms -/
#guard_msgs in #print axioms serU8_size

/-- info: 'Bitcoin.Crypto.Taproot.Verify.natToBytesBE_size' depends on axioms: [propext] -/
#guard_msgs in #print axioms natToBytesBE_size

/-- info: 'Bitcoin.Crypto.Taproot.Verify.treeHash_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms treeHash_size

/-- info: 'Bitcoin.Crypto.Taproot.Verify.treeMerkleRoot_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms treeMerkleRoot_size

/-- info: 'Bitcoin.Crypto.Taproot.Verify.treeMerkleRoot_none' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms treeMerkleRoot_none

/-- info: 'Bitcoin.Crypto.Taproot.Verify.scriptPathTapleaf_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms scriptPathTapleaf_size

/-- info: 'Bitcoin.Crypto.Taproot.Verify.pathNodeCount_def' does not depend on any axioms -/
#guard_msgs in #print axioms pathNodeCount_def

/-- info: 'Bitcoin.Crypto.Taproot.Verify.pathNodes_length' depends on axioms: [propext] -/
#guard_msgs in #print axioms pathNodes_length

/-- info: 'Bitcoin.Crypto.Taproot.Verify.verifyTaprootCommitment_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verifyTaprootCommitment_eq

/-- info: 'Bitcoin.Crypto.Taproot.Verify.checkTapTweak_program_size' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms checkTapTweak_program_size

/-- info: 'Bitcoin.Crypto.Taproot.Verify.checkTapTweak_program_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms checkTapTweak_program_eq

/-- info: 'Bitcoin.Crypto.Taproot.Verify.checkTapTweak_accept_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms checkTapTweak_accept_iff

/-- info: 'Bitcoin.Crypto.Taproot.Verify.verifyTaprootCommitment_program_size' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms verifyTaprootCommitment_program_size

/-- info: 'Bitcoin.Crypto.Taproot.Verify.verifyTaprootCommitment_program_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms verifyTaprootCommitment_program_eq

/-- info: 'Bitcoin.Crypto.Taproot.Verify.verifyTaprootCommitment_wrong_program' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms verifyTaprootCommitment_wrong_program

/-- info: 'Bitcoin.Crypto.Taproot.Verify.verifyTaprootCommitment_wrong_length' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms verifyTaprootCommitment_wrong_length

/-- info: 'Bitcoin.Crypto.Taproot.Verify.scriptPathSpend_badSize_none' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms scriptPathSpend_badSize_none

/-- info: 'Bitcoin.Crypto.Taproot.Verify.scriptPathSpend_minimal_some' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms scriptPathSpend_minimal_some

/-- info: 'Bitcoin.Crypto.Taproot.Verify.scriptPathSpend_dispatch' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms scriptPathSpend_dispatch

/-- info: 'Bitcoin.Crypto.Taproot.Verify.scriptPathSpend_congr' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms scriptPathSpend_congr

/-- info: 'Bitcoin.Crypto.Taproot.Verify.p2trOutput_shape' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms p2trOutput_shape

/-- info: 'Bitcoin.Crypto.Taproot.Verify.p2trOutput_none_badKey' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms p2trOutput_none_badKey

/-- info: 'Bitcoin.Crypto.Taproot.Verify.p2trOutput_congr' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms p2trOutput_congr

end Bitcoin.Crypto.Taproot.Verify
