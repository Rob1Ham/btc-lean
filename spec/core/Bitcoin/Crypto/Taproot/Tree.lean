import Bitcoin.Crypto.Taproot.TapTweak
import Bitcoin.Data.Basic

/-!
# Bitcoin.Crypto.Taproot.Tree — TapLeaf / TapBranch / the Merkle walk
# (X03, Unit 2)

BIP341's script-path hashing lane: the tapleaf hash, the sorted
TapBranch pairing, and the control-block Merkle walk (bip-0341.mediawiki
§"Script validation rules" items ''k_0 = hash_TapLeaf(v || compact_size(
size of s) || s)'' .. ''k_{j+1} = hash_TapBranch(e_j || k_j)'';
Core `ComputeTapleafHash` / `ComputeTapbranchHash` /
`ComputeTaprootMerkleRoot` interpreter.cpp:1882-1911 @cce32b168).

## What is ported where

* `tapLeaf` (TPR-012) — `ComputeTapleafHash` (interpreter.cpp:1882-1885)
  EXACTLY: `(HashWriter{HASHER_TAPLEAF} << leaf_version <<
  CompactSizeWriter(script.size()) << script).GetSHA256()` =
  `taggedHash("TapLeaf", serU8 v ‖ compactSizeEnc s.size ‖ s)`.
  **Core passes `control[0] & TAPROOT_LEAF_MASK` at the call site**
  (interpreter.cpp:1983) = BIP341:79's `v = c[0] & 0xfe` (the parity bit
  is masked OFF before the leaf hash) — that masking is the caller's
  (Unit 3 `Verify.lean`) job; this def takes the masked leaf version.
* `lexLtB` (private) + `tapBranch` (TPR-013) —
  `ComputeTapbranchHash` (interpreter.cpp:1887-1896) EXACTLY:
  `if std::lexicographical_compare(a, b) { a ‖ b } else { b ‖ a }` —
  strict lexicographic compare (`a < b` byte-wise) selects `a‖b`,
  else (incl. `a = b`, strict-lex irreflexivity) `b‖a` =
  BIP341:75-76 (''k_j < e_j'' → `k_j‖e_j`; ''k_j ≥ e_j'' → `e_j‖k_j`).
  `lexLtB` = `std::lexicographical_compare` on the byte lists
  (`lexLN` over `a.data.toList`): `[] < _`; `_ ≥ []`; `x::xs < y::ys :=
  if x = y then xs < ys else x.toNat < y.toNat`. Pinned:
  irrefl (strict), asym, and both-false ↔ byte-equal (the trichotomy
  Core's `lexicographical_compare` gives).
* `taprootMerkleRoot` (TPR-014) — `ComputeTaprootMerkleRoot`
  (interpreter.cpp:1898-1911) EXACTLY: `k = tapleaf_hash`;
  `for i in [0..m): k = ComputeTapbranchHash(k, e_j)` (Core 1906-1908;
  BIP341:74-76) — the sort lives INSIDE `tapBranch` (1890), so the walk
  is the structural left-to-right recursion on the node list
  `e_j = c[33+32j..65+32j)` (BIP341:74): `e :: rest` walked from `tl`
  recurses on `rest` from `tapBranch tl e` (Core 1906-1908's in-place
  `k = ComputeTapbranchHash(k, e_j)`; NOT a `List.foldl` def — the
  foldl-cons equation under a def whnf-times-out in this List-backed
  -Array toolchain, and the structural form makes all walk equations
  definitional). The `(size-33)/32`-chunking of
  the control block is the control-block PARSE (TPR-009, Unit 3
  `Verify.lean`); this module walks the parsed nodes, so
  `m = 0 ⇔ root = tapleaf hash` (Core 1905) is definitional.
* Tag distinctness (BIP341 §design: `hash_tag` domain separation) —
  `TapTweak ≠ TapLeaf ≠ TapBranch` + `TapLeaf ≠ TapSighash` by
  `decide` (the 4 tags involved in the Tree/TapTweak lanes; TapSighash
  is Unit 4's). [propext, Quot.sound] only — no `sorry`, no
  `native_decide`.

## Rule rows (spec/db/rules.yaml TPR block)

TPR-012 (tapleaf hash), TPR-013 (TapBranch lexicographic pairing),
TPR-014 (merkle walk fold) live on this module's defs. TPR-016
(commitment equation) stays on Unit 1's `tweakPoint` + Unit 3's
`Verify.lean`. TPR-009 (control-block size `33+32m`) = the Unit 3 parse.

## Status: X03 Unit 2 — all theorems sorry-free, axioms pinned at the
bottom (footprints ⊆ the standard trio `[propext, Classical.choice,
Quot.sound]`, X02 style). No `sorry`, no `native_decide`, zero-warning
build (no deprecated `if_pos`/`if_neg`; `split` + `nomatch` forms).
-/

namespace Bitcoin.Crypto.Taproot

open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Schnorr (taggedHash tagTapLeaf tagTapTweak tagTapSighash
  taggedHash_size append_size)
open Bitcoin.Data (serU8 compactSizeEnc)

/-! ## The tapleaf hash (TPR-012) -/

/-- `tapLeaf v s` = `taggedHash("TapLeaf", serU8 v ‖ compactSizeEnc
s.size ‖ s)` — Core `ComputeTapleafHash(leaf_version, script)`
(interpreter.cpp:1882-1885) = BIP341:71. `v` is the MASKED leaf version
(`c[0] & 0xfe`, interpreter.cpp:1983; BIP341:79) — Unit 3's caller does
the masking. TPR-012. -/
@[rule "TPR-012"]
def tapLeaf (v : UInt8) (script : ByteArray) : ByteArray :=
  taggedHash tagTapLeaf (serU8 v ++ compactSizeEnc script.size ++ script)

/-! ## The lexicographic byte compare (private; Core
`std::lexicographical_compare`, interpreter.cpp:1890) -/

/-- Strict lexicographic compare on byte lists (Core
`std::lexicographical_compare(a, b)`, interpreter.cpp:1890):
`[] < _`; `_ ≥ []` (shorter equal-prefix is greater, NOT less —
`[] < y::ys` is the ONLY nil-true case); `x::xs < y::ys := if x = y
then xs < ys else x.toNat < y.toNat`. Compares `UInt8`s via `.toNat`
(Nat `<` is the Core `<` on `unsigned char` promoted values).
Private: the ByteArray-level face is `lexLtB`. -/
private def lexLN : List UInt8 → List UInt8 → Bool
  | [], [] => false
  | [], _ :: _ => true
  | _ :: _, [] => false
  | x :: xs, y :: ys => if x = y then lexLN xs ys else decide (x.toNat < y.toNat)

theorem lexLN_cons (x y : UInt8) (xs ys : List UInt8) :
    lexLN (x :: xs) (y :: ys) =
      if x = y then lexLN xs ys else decide (x.toNat < y.toNat) := rfl

/-- `lexLtB a b` = `std::lexicographical_compare(a, b)` on the byte
arrays (strict lexicographic `a < b`). Private: it exists to be
PINNED (irrefl / asym / both-false ↔ equal); `tapBranch` is its only
consumer. -/
private def lexLtB (a b : ByteArray) : Bool :=
  lexLN a.data.toList b.data.toList

/-- Strict-lex irreflexivity (Core `lexicographical_compare(a, a)` =
false — the `k_j ≥ e_j` else-branch at `k_j = e_j`,
interpreter.cpp:1890). -/
private theorem lexLN_irrefl : ∀ xs : List UInt8, lexLN xs xs = false
  | [] => rfl
  | x :: xs => by
      have ih := lexLN_irrefl xs
      rw [lexLN_cons]
      split
      · exact ih
      · exact decide_eq_false (Nat.lt_irrefl x.toNat)

/-- Strict-lex asymmetry: `xs < ys` → `¬(ys < xs)`. -/
private theorem lexLN_asym : ∀ (xs ys : List UInt8),
    lexLN xs ys = true → lexLN ys xs = false
  | [], [], _ => by rfl
  | [], y :: ys, _ => by rfl
  | x :: xs, [], h => by
      rw [show lexLN (x :: xs) [] = false from by rfl] at h
      nomatch h
  | x :: xs, y :: ys, h => by
      have ih := lexLN_asym xs ys
      rw [lexLN_cons] at h
      split at h
      · rename_i hxy
        rw [lexLN_cons]
        split
        · rename_i hyx
          exact ih h
        · rename_i hyx
          exact absurd hxy.symm hyx
      · rename_i hxy
        rw [lexLN_cons]
        split
        · rename_i hyx
          exact absurd hyx.symm hxy
        · rename_i hyx
          have hx : x.toNat < y.toNat := of_decide_eq_true h
          have hnx : ¬(y.toNat < x.toNat) := by omega
          exact decide_eq_false hnx

/-- Strict-lex trichotomy (the both-false half): neither `xs < ys` nor
`ys < xs` iff the byte lists are equal. -/
theorem lexLN_false_false : ∀ (xs ys : List UInt8),
    lexLN xs ys = false → lexLN ys xs = false → xs = ys
  | [], [], _, _ => by rfl
  | [], y :: ys, h1, h2 => by
      rw [show lexLN [] (y :: ys) = true from by rfl] at h1
      nomatch h1
  | x :: xs, [], h1, h2 => by
      rw [show lexLN [] (x :: xs) = true from by rfl] at h2
      nomatch h2
  | x :: xs, y :: ys, h1, h2 => by
      have ih := lexLN_false_false xs ys
      rw [lexLN_cons] at h1
      rw [lexLN_cons] at h2
      split at h1
      · rename_i hxy
        split at h2
        · rename_i hyx
          rw [hxy, ih h1 h2]
        · rename_i hyx
          exact absurd hxy.symm hyx
      · rename_i hxy
        split at h2
        · rename_i hyx
          exact absurd hyx.symm hxy
        · rename_i hyx
          have n1 : ¬(x.toNat < y.toNat) := of_decide_eq_false h1
          have n2 : ¬(y.toNat < x.toNat) := of_decide_eq_false h2
          have hxe : x.toNat = y.toNat := by omega
          exact absurd (UInt8.toNat_inj.mp hxe) hxy

/-- ByteArray face of `lexLN_irrefl`. -/
private theorem lexLtB_irrefl (a : ByteArray) : lexLtB a a = false :=
  lexLN_irrefl a.data.toList

/-- ByteArray face of `lexLN_asym`. -/
private theorem lexLtB_asym (a b : ByteArray) (h : lexLtB a b = true) :
    lexLtB b a = false :=
  lexLN_asym a.data.toList b.data.toList h

/-- ByteArray face of `lexLN_false_false` (both-false ↔ byte-equal). -/
private theorem lexLtB_false_false (a b : ByteArray)
    (h1 : lexLtB a b = false) (h2 : lexLtB b a = false) : a = b := by
  apply ByteArray.ext
  rw [show a.data = Array.mk a.data.toList from rfl,
      show b.data = Array.mk b.data.toList from rfl,
      lexLN_false_false a.data.toList b.data.toList h1 h2]

/-! ## The TapBranch pairing (TPR-013) -/

/-- `tapBranch a b` = `taggedHash("TapBranch", a ‖ b)` if `a < b`
(lexicographic) else `taggedHash("TapBranch", b ‖ a)` — Core
`ComputeTapbranchHash` (interpreter.cpp:1887-1896) EXACTLY:
`lexicographical_compare(a, b)` → `a ‖ b`, else `b ‖ a` =
BIP341:75-76 (''k_j < e_j'' → `k_j‖e_j`; ''k_j ≥ e_j'' → `e_j‖k_j`;
`k_j = e_j` lands in the else-branch by strict irreflexivity).
The comparison is BYTES (32-byte digests/leaves in consensus, but the
def is total on all ByteArrays). TPR-013. -/
@[rule "TPR-013"]
def tapBranch (a b : ByteArray) : ByteArray :=
  taggedHash tagTapBranch (if lexLtB a b then a ++ b else b ++ a)

/-- TPR-013 (hash-domain size): the branch hash is a 32-byte digest. -/
theorem tapBranch_size (a b : ByteArray) :
    (tapBranch a b).size = 32 := taggedHash_size _ _

/-- TPR-012 (definitional statement): `tapLeaf` is the tagged hash of
`v ‖ compactSize(size of s) ‖ s` (Core 1884's `<<` chain). -/
theorem tapLeaf_eq (v : UInt8) (script : ByteArray) :
    tapLeaf v script =
      taggedHash tagTapLeaf (serU8 v ++ compactSizeEnc script.size ++ script) :=
  rfl

/-- TPR-012 (hash-domain size): the tapleaf hash is a 32-byte digest. -/
theorem tapLeaf_size (v : UInt8) (script : ByteArray) :
    (tapLeaf v script).size = 32 := taggedHash_size _ _

/-- TPR-013 (the `k_j = e_j` case): equal branch inputs hash as
`hash_TapBranch(a ‖ a)` — strict irreflexivity sends `k_j = e_j` to
Core's else-branch `b ‖ a` = `a ‖ a` (interpreter.cpp:1892-1893;
BIP341:76). Both ite-branches give `a ++ a`, so the statement is
condition-free. -/
theorem tapBranch_diag (a : ByteArray) :
    tapBranch a a = taggedHash tagTapBranch (a ++ a) := by
  unfold tapBranch
  split <;> rfl

/-- TPR-013 (the sort makes the pairing commutative): `tapBranch a b =
tapBranch b a` — Core compares `(a, b)` and hashes the sorted pair
(1890), so the argument order is irrelevant: `a < b` gives `a‖b` on
both sides (asym flips the call); `b < a` likewise; `a = b` by
`lexLtB_false_false` (both-false) and `tapBranch_diag`. This is the
BIP341 "no left/right directions revealed" property
(bip-0341.mediawiki: ''Why are child elements sorted before hashing in
the Merkle tree?''). -/
theorem tapBranch_comm (a b : ByteArray) :
    tapBranch a b = tapBranch b a := by
  unfold tapBranch
  cases h : lexLtB a b with
  | true =>
      have hb : lexLtB b a = false := lexLtB_asym a b h
      rw [hb]
      rfl
  | false =>
      cases h' : lexLtB b a with
      | true => rfl
      | false =>
          have hab : a = b := lexLtB_false_false a b h h'
          rw [hab]

/-! ## The Merkle walk (TPR-014) -/

/-- `taprootMerkleRoot nodes tapleaf_hash` — Core
`ComputeTaprootMerkleRoot` (interpreter.cpp:1898-1911) EXACTLY:
`k = tapleaf_hash`; for each path node `e_j` (the 32-byte control-block
chunks `c[33+32j..65+32j)`, BIP341:74), `k = ComputeTapbranchHash(k,
e_j)` (Core 1906-1908; BIP341:75-76). Core's walk is over `path_len =
(control.size() - 33) / 32` nodes; `taprootMerkleRoot` walks the PARSED
node list (the `33+32m` control-block parse = TPR-009, Unit 3), so
Core's `for (int i = 0; i < path_len; ++i)` = the structural recursion
`| e :: rest, tl => taprootMerkleRoot rest (tapBranch tl e)` (the sort
lives inside `tapBranch`, Core 1908 passes `(k, node)`; the equivalent
`List.foldl tapBranch tl nodes` encoding was tried and its cons-
equation `rfl` hits a whnf timeout in this List-backed-Array toolchain,
so the def is the structural recursion Core 1906-1908 spells).
TPR-014. -/
@[rule "TPR-014"]
def taprootMerkleRoot : List ByteArray → ByteArray → ByteArray
  | [], tapleaf_hash => tapleaf_hash
  | e :: rest, tapleaf_hash => taprootMerkleRoot rest (tapBranch tapleaf_hash e)

/-- TPR-014 (Core 1905: `path_len = 0`): an empty path has the tapleaf
hash as the merkle root — the `m = 0` case of
`taprootMerkleRoot (c[33..33+0)) tapleaf = tapleaf`
(`ComputeTaprootMerkleRoot` returns `k = tapleaf_hash` unchanged).
Definitional. -/
theorem taprootMerkleRoot_nil (tapleaf_hash : ByteArray) :
    taprootMerkleRoot [] tapleaf_hash = tapleaf_hash := rfl

/-- TPR-014 (Core 1906-1908, the fold step): walking `e :: rest` from
`tl` first pairs the tapleaf hash with `e_0` —
`k_1 = ComputeTapbranchHash(k_0, e_0)` = `tapBranch tl e` — then walks
`rest` from `k_1` (left-to-right, BIP341:74's `j ∈ [0..m)`).
Definitional. -/
theorem taprootMerkleRoot_cons (e : ByteArray) (rest : List ByteArray)
    (tapleaf_hash : ByteArray) :
    taprootMerkleRoot (e :: rest) tapleaf_hash =
      taprootMerkleRoot rest (tapBranch tapleaf_hash e) := rfl

/-- TPR-014 (Core 1906-1908, `path_len = 1`): a single-node path has
root = `hash_TapBranch(k_0 ‖ e_0)`-with-sort = `tapBranch tl e`.
Definitional (foldl nil-equation). -/
theorem taprootMerkleRoot_single (e : ByteArray) (tapleaf_hash : ByteArray) :
    taprootMerkleRoot [e] tapleaf_hash = tapBranch tapleaf_hash e := by rfl

/-- TPR-014 (determinism): the merkle walk is a pure function of the
node list and the tapleaf hash (BIP341 §design: the commitment is
completely specified at the byte level). -/
theorem taprootMerkleRoot_congr (nodes₁ nodes₂ : List ByteArray)
    (tl₁ tl₂ : ByteArray) (hn : nodes₁ = nodes₂) (ht : tl₁ = tl₂) :
    taprootMerkleRoot nodes₁ tl₁ = taprootMerkleRoot nodes₂ tl₂ := by
  subst hn; subst ht; rfl

/-! ## Tag distinctness (BIP341 `hash_tag` domain separation) -/

/-- The TapTweak and TapLeaf tags are distinct (BIP341 §design: SHA256
tags domain-separate the hash lanes; `TapTweak` ≠ `TapLeaf` pins the
taptweak/tapleaf lanes). `decide`-proved — the tags are literal UTF8.
[propext, Quot.sound]. -/
theorem tagTapTweak_ne_leaf : tagTapTweak ≠ tagTapLeaf := by decide

/-- The TapTweak and TapBranch tags are distinct (the tweak/branch
lanes). -/
theorem tagTapTweak_ne_branch : tagTapTweak ≠ tagTapBranch := by decide

/-- The TapLeaf and TapBranch tags are distinct (the leaf/branch
lanes). -/
theorem tagTapLeaf_ne_branch : tagTapLeaf ≠ tagTapBranch := by decide

/-- The TapLeaf and TapSighash tags are distinct (the leaf/sighash
lanes; TapSighash is Unit 4's tag, pinned here for the TapLeaf
domain). -/
theorem tagTapLeaf_ne_sighash : tagTapLeaf ≠ tagTapSighash := by decide

/-! ## Axiom footprints (X02 style: `#guard_msgs in #print axioms`)

All sorry-free; footprints ⊆ the standard trio
`[propext, Classical.choice, Quot.sound]`, pinned by the guard blocks
below (predictions corrected against the actual `#print axioms` output
at build time).
-/

/-- info: 'Bitcoin.Crypto.Taproot.lexLN_cons' does not depend on any axioms -/
#guard_msgs in #print axioms lexLN_cons

/-- info: '_private.Bitcoin.Crypto.Taproot.Tree.0.Bitcoin.Crypto.Taproot.lexLN_irrefl' does not depend on any axioms -/
#guard_msgs in #print axioms lexLN_irrefl

/-- info: '_private.Bitcoin.Crypto.Taproot.Tree.0.Bitcoin.Crypto.Taproot.lexLN_asym' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms lexLN_asym

/-- info: 'Bitcoin.Crypto.Taproot.lexLN_false_false' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms lexLN_false_false

/-- info: 'Bitcoin.Crypto.Taproot.tapLeaf_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tapLeaf_eq

/-- info: 'Bitcoin.Crypto.Taproot.tapLeaf_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tapLeaf_size

/-- info: 'Bitcoin.Crypto.Taproot.tapBranch_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tapBranch_size

/-- info: 'Bitcoin.Crypto.Taproot.tapBranch_diag' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tapBranch_diag

/-- info: 'Bitcoin.Crypto.Taproot.tapBranch_comm' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tapBranch_comm

/-- info: 'Bitcoin.Crypto.Taproot.taprootMerkleRoot_nil' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms taprootMerkleRoot_nil

/-- info: 'Bitcoin.Crypto.Taproot.taprootMerkleRoot_cons' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms taprootMerkleRoot_cons

/-- info: 'Bitcoin.Crypto.Taproot.taprootMerkleRoot_single' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms taprootMerkleRoot_single

/-- info: 'Bitcoin.Crypto.Taproot.taprootMerkleRoot_congr' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms taprootMerkleRoot_congr

/-- info: 'Bitcoin.Crypto.Taproot.tagTapTweak_ne_leaf' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tagTapTweak_ne_leaf

/-- info: 'Bitcoin.Crypto.Taproot.tagTapTweak_ne_branch' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tagTapTweak_ne_branch

/-- info: 'Bitcoin.Crypto.Taproot.tagTapLeaf_ne_branch' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tagTapLeaf_ne_branch

/-- info: 'Bitcoin.Crypto.Taproot.tagTapLeaf_ne_sighash' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tagTapLeaf_ne_sighash

end Bitcoin.Crypto.Taproot
