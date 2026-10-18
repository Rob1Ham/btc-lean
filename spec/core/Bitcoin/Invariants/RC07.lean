import Bitcoin.Crypto.Schnorr.TaggedHash
import Bitcoin.Interpreter.Rules

/-!
# Bitcoin.Invariants.RC07 — INV-073/074 (RC07, Rule-Closure suite)

Two B1 acceptance-spine invariant rows whose BIP341/342 script-path hash
lane had no faithful Lean home yet (the EC tweak step lives behind the Taproot module's
`CheckTapTweak` seam; the control-block dispatch in the interpreter rule layer's
`verifyWitnessProgram` returns `.unjudged` exactly there). The pure-hash
half is fully closable standalone, so it is closed here, in RC07's own
namespace, on the interpreter rule layer's tagged-hash floor (SCR-146's `tapLeafHash`) and the Schnorr module's
`taggedHash`.

Rows closed here (B-type):

- **INV-073** — leaf commitment, hash lane
  (`interpreter.cpp:ComputeTaprootMerkleRoot:1898–1911` +
  `VerifyTaprootCommitment:1913–1926` @cce32b168): starting from the
  tapleaf hash (the interpreter rule layer `tapLeafHash`, SCR-146), climb the control block's
  32-byte internal nodes with the lexicographically-ordered tagged
  `TapBranch` hash (`ComputeTapbranchHash:1903–1910`); malformed control
  shapes (short / oversized / non-multiple-of-32 path) are rejected.
  The final `q.CheckTapTweak(p, root, control[0]&1)` EC comparison is the
  the Taproot module seam lane (TPR rows) and is NOT re-modeled here.
- **INV-074** — tapscript leaf version 0xc0
  (`interpreter.cpp:1962–1972`, BIP342 §2): the leaf version is
  `control[0] &&& 0xfe` (parity bit stripped); the script path executes
  as tapscript iff that mask equals 0xc0. Leaf versions that mask
  elsewhere are NOT consensus-invalid — they take the upgradable path
  (DISCOURAGE_UPGRADABLE_TAPROOT_VERSION is the policy hook, the interpreter rule layer's
  SCR-149 lane) — so the honest consensus check is the 0xc0 mask gate
  alone.

Vectors: python3-cross-checked — tapbranch ordering/masking and
the control-shape
gates mirrored in python3 over the 33 + 32k control-block shape
convention (0xc0/0xc1/unknown first bytes).

Zero-dependency discipline: core tactics only (no Mathlib).
-/

namespace Bitcoin.Invariants.RC07

open Bitcoin.Crypto.Schnorr (taggedHash)

/-! ### Control-block shape constants

**Core-faithful, RC07-local** (`interpreter.h:244-247` @cce32b168:
`TAPROOT_CONTROL_BASE_SIZE = 33`, `_MAX_SIZE = 33 + 32·128 = 4129`).
NOTE the control-size note (fixed in the 2026-10-17 repair): the interpreter rule layer's
`Bitcoin.Interpreter.TAPROOT_CONTROL_BASE_SIZE` (Defs.lean) had pinned
**65** (and MAX 4161) — over-strict against Core's 33: a single-leaf
taptree has a 33-byte control block (0 internal nodes). The defect was
fixed in that repair (Interpreter/Defs.lean 65→33, MAX 4161→4129, the
same Core-33 fix as 201e050/8a3343b); these RC07-local constants
mirrored Core exactly all along and are unchanged. History: the control-size note. -/

@[rule "INV-073"]
def controlBaseSize : Nat := 33

@[rule "INV-073"]
def controlNodeSize : Nat := 32

@[rule "INV-073"]
def controlMaxSize : Nat := 33 + 32 * 128

/-! ## INV-073 — the tapbranch hash + taptree climb -/

/-- `"TapBranch"` domain-separation tag (BIP341; Core `HASHER_TAPBRANCH`). -/
@[rule "INV-073"]
def tagTapBranch : ByteArray := "TapBranch".toUTF8

/-- Byte-lexicographic strict order (Core
`std::lexicographical_compare(a, b)` in `ComputeTapbranchHash`). -/
def bytesLexLt : List UInt8 → List UInt8 → Bool
  | [], [] => false
  | [], _ :: _ => true
  | _ :: _, [] => false
  | x :: xs, y :: ys => if x = y then bytesLexLt xs ys else x < y

@[rule "INV-073"]
def lexLt (a b : ByteArray) : Bool := bytesLexLt a.data.toList b.data.toList

/-- `ComputeTapbranchHash` (`interpreter.cpp:1903–1910`): the tagged
`TapBranch` hash of the lexicographically-ordered pair. Equal inputs
fall to the `b ‖ a` arm (the compare is strict). -/
@[rule "INV-073"]
def tapbranchHash (a b : ByteArray) : ByteArray :=
  if lexLt a b then taggedHash tagTapBranch (a ++ b)
  else taggedHash tagTapBranch (b ++ a)

/-- Equal inputs take the `b ‖ a` arm (`lexLt` is irreflexive). -/
theorem tapbranchHash_self (a : ByteArray) :
    tapbranchHash a a = taggedHash tagTapBranch (a ++ a) := by
  unfold tapbranchHash lexLt bytesLexLt
  induction a.data.toList with
  | nil => simp
  | cons x xs ih => simp [ih]

/-- The climb (Core's fold over `ComputeTapbranchHash`): stays a 32-byte
digest given a 32-byte accumulator and 32-byte nodes — the tagged-hash
size contract composed along the fold. -/
theorem climb_size32 (nodes : List ByteArray) (k : ByteArray)
    (hk : k.size = 32) (hn : ∀ n ∈ nodes, n.size = 32) :
    (nodes.foldl (fun acc n => tapbranchHash acc n) k).size = 32 := by
  have key : ∀ (ms : List ByteArray) (a : ByteArray), a.size = 32 →
      (∀ n ∈ ms, n.size = 32) →
      (ms.foldl (fun x y => tapbranchHash x y) a).size = 32 := by
    intro ms
    induction ms with
    | nil => intro a ha _; simp [ha]
    | cons m ms' ih =>
        intro a _ hn''
        simp only [List.foldl_cons]
        refine ih _ ?_ (fun x hx => hn'' x (List.mem_cons_of_mem _ hx))
        unfold tapbranchHash
        split <;> simp [Bitcoin.Crypto.Schnorr.taggedHash_size]
  exact key nodes k hk hn

/-- `ComputeTaprootMerkleRoot` (`interpreter.cpp:1898–1911`), hash lane:
from the tapleaf hash, fold the control block's 32-byte internal nodes
(after the 33-byte parity+internal-key prefix) through `tapbranchHash`.
`none` = control block rejected on shape (Core asserts these;
`verifyWitnessProgram` already gates them to
`.fail .taprootWrongControlSize`). -/
@[rule "INV-073"]
def taprootMerkleRoot (control : ByteArray) (tapleaf : ByteArray) :
    Option ByteArray :=
  if control.size < controlBaseSize ∨
      controlMaxSize < control.size ∨
      (control.size - controlBaseSize) % controlNodeSize ≠ 0 then
    none
  else
    some ((List.range ((control.size - controlBaseSize) /
        controlNodeSize)).map
      (fun i => control.extract
        (controlBaseSize + controlNodeSize * i)
        (controlBaseSize + controlNodeSize * i + controlNodeSize))
      |>.foldl (fun acc n => tapbranchHash acc n) tapleaf)

/-- Shape gate, short arm: a control block below 33 bytes is rejected
(Core `assert(control.size() >= TAPROOT_CONTROL_BASE_SIZE)`, 33). -/
theorem taprootMerkleRoot_short (c : ByteArray) (tl : ByteArray)
    (h : c.size < 33) : taprootMerkleRoot c tl = none := by
  unfold taprootMerkleRoot
  have hb : controlBaseSize = 33 := rfl
  have hn : controlNodeSize = 32 := rfl
  have hx : controlMaxSize = 4129 := rfl
  simp only [hb, hn, hx]
  rw [if_pos (by omega)]

/-- Shape gate, residue arm: a non-32-multiple path length is rejected. -/
theorem taprootMerkleRoot_badResidue (c : ByteArray) (tl : ByteArray)
    (h1 : 33 ≤ c.size) (h2 : c.size ≤ 4129) (h3 : (c.size - 33) % 32 ≠ 0) :
    taprootMerkleRoot c tl = none := by
  unfold taprootMerkleRoot
  have hb : controlBaseSize = 33 := rfl
  have hn : controlNodeSize = 32 := rfl
  have hx : controlMaxSize = 4129 := rfl
  simp only [hb, hn, hx]
  rw [if_pos (by omega)]

/-- Zero-node control (33 bytes = single-leaf taptree): the climb is the
identity, so the merkle root IS the tapleaf hash — the python3 `root33`
vector. -/
theorem taprootMerkleRoot_empty (c : ByteArray) (tl : ByteArray)
    (h33 : c.size = 33) : taprootMerkleRoot c tl = some tl := by
  unfold taprootMerkleRoot
  have hb : controlBaseSize = 33 := rfl
  have hn : controlNodeSize = 32 := rfl
  have hx : controlMaxSize = 4129 := rfl
  simp only [hb, hn, hx, h33]
  rw [if_neg (by omega)]
  first | rfl | simp

/-- Single-node control (65 bytes = 33 + 1·32, the minimum script-path
size): the climb is exactly one ordered tapbranch hash of the tapleaf
against the single 32-byte node — the python3 `root65` vector. -/
theorem taprootMerkleRoot_single (c : ByteArray) (tl : ByteArray)
    (h65 : c.size = 65) :
    taprootMerkleRoot c tl = some (tapbranchHash tl (c.extract 33 65)) := by
  unfold taprootMerkleRoot
  have hb : controlBaseSize = 33 := rfl
  have hn : controlNodeSize = 32 := rfl
  have hx : controlMaxSize = 4129 := rfl
  simp only [hb, hn, hx, h65]
  rw [if_neg (by omega)]
  first | rfl | simp

/-- For the 65-byte single-node shape the climber's node is exactly
`c.extract 33 65` — connecting the index-based fold to the concrete
single-step reading (vector pin for the python3 mirror). -/
theorem taprootMerkleRoot_single_node (c : ByteArray) (tl : ByteArray)
    (h65 : c.size = 65) :
    ((List.range 1).map (fun i => c.extract (33 + 32 * i) (33 + 32 * i + 32))
      |>.foldl (fun acc n => tapbranchHash acc n) tl)
      = tapbranchHash tl (c.extract 33 65) := by
  first | rfl | simp

/-- Full leaf commitment, hash lane (Core `VerifyTaprootCommitment:1913–1926`
minus the final EC step): tapleaf hash from the script being spent
(the interpreter rule layer's `tapLeafHash`, SCR-146 — `leaf_ver = control[0] &&& 0xfe`) fed
through the climb. `none` = control shape rejected. The remaining
`q.CheckTapTweak(p, root, control[0]&1)` comparison is the Taproot module seam lane. -/
@[rule "INV-073"]
def tapleafCommitment (control : ByteArray) (script : ByteArray) :
    Option ByteArray :=
  taprootMerkleRoot control
    (Bitcoin.Interpreter.tapLeafHash (control[0]! &&& 0xfe) script)

/-- A 33-byte (single-leaf) control commits exactly to the tapleaf hash
of the script being spent (leaf version = masked control byte 0). -/
theorem tapleafCommitment_singleLeaf (control : ByteArray) (script : ByteArray)
    (h33 : control.size = 33) :
    tapleafCommitment control script
      = some (Bitcoin.Interpreter.tapLeafHash (control[0]! &&& 0xfe) script) := by
  unfold tapleafCommitment
  rw [taprootMerkleRoot_empty _ _ h33]

/-! ## INV-074 — tapscript leaf version 0xc0 -/

/-- The leaf version masked out of control byte 0 (`interpreter.cpp:1962`,
BIP342 §2: `leaf_ver = control[0] & 0xfe`; the stripped low bit is the
output-key parity, consumed by the EC lane). -/
@[rule "INV-074"]
def tapscriptLeafVersion (control : ByteArray) : Option UInt8 :=
  if 33 ≤ control.size then some (control[0]! &&& 0xfe) else none

/-- The BIP342 tapscript gate: the script path executes as tapscript iff
the masked leaf version is 0xc0. -/
@[rule "INV-074"]
def isTapscriptLeaf (control : ByteArray) : Bool :=
  match tapscriptLeafVersion control with
  | some 0xc0 => true
  | _ => false

/-- Definitional characterization of the gate. -/
theorem isTapscriptLeaf_def (control : ByteArray) :
    isTapscriptLeaf control =
      (match tapscriptLeafVersion control with
       | some 0xc0 => true
       | _ => false) := rfl

/-- Parity bit is stripped: a 0xc1 control byte is the SAME 0xc0 leaf
version (low bit = output-key parity, BIP341 §5). Probe-verified: the
whole statement reduces by `rfl` (kernel evaluates the ByteArray
append/index and the UInt8 mask), footprint [propext, Quot.sound]. -/
theorem leafVersion_parity_stripped :
    tapscriptLeafVersion (ByteArray.mk #[0xc1] ++ ByteArray.mk (Array.replicate 32 0))
      = some 0xc0 := by
  rfl

/-- A non-0xc0 masked version (here 0xbe, an unknown future version) is
NOT tapscript — it takes the upgradable path, consensus-valid. -/
theorem unknownLeafVersion_not_tapscript :
    isTapscriptLeaf (ByteArray.mk #[0xbe] ++ ByteArray.mk (Array.replicate 32 0))
      = false := by
  rfl

/-- Short control blocks carry no leaf version at all. -/
theorem leafVersion_short (c : ByteArray) (h : c.size < 33) :
    tapscriptLeafVersion c = none := by
  unfold tapscriptLeafVersion
  rw [if_neg (by omega)]

/-! ## Axiom pins (all theorems sorry-free) -/

/-- info: 'Bitcoin.Invariants.RC07.tapbranchHash_self' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tapbranchHash_self

/-- info: 'Bitcoin.Invariants.RC07.climb_size32' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms climb_size32

/-- info: 'Bitcoin.Invariants.RC07.taprootMerkleRoot_short' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms taprootMerkleRoot_short

/-- info: 'Bitcoin.Invariants.RC07.taprootMerkleRoot_badResidue' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms taprootMerkleRoot_badResidue

/-- info: 'Bitcoin.Invariants.RC07.taprootMerkleRoot_empty' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms taprootMerkleRoot_empty

/-- info: 'Bitcoin.Invariants.RC07.taprootMerkleRoot_single' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms taprootMerkleRoot_single

/-- info: 'Bitcoin.Invariants.RC07.taprootMerkleRoot_single_node' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms taprootMerkleRoot_single_node

/-- info: 'Bitcoin.Invariants.RC07.tapleafCommitment_singleLeaf' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tapleafCommitment_singleLeaf

/-- info: 'Bitcoin.Invariants.RC07.isTapscriptLeaf_def' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms isTapscriptLeaf_def

/-- info: 'Bitcoin.Invariants.RC07.leafVersion_parity_stripped' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms leafVersion_parity_stripped

/-- info: 'Bitcoin.Invariants.RC07.unknownLeafVersion_not_tapscript' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms unknownLeafVersion_not_tapscript

/-- info: 'Bitcoin.Invariants.RC07.leafVersion_short' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms leafVersion_short

end Bitcoin.Invariants.RC07
