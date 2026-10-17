import Bitcoin.Capstone.Merkle

/-!
# BitcoinProofs.Theorems.CapstoneMerkle — W17 P03: proved merkle-layer spec (sorry-free)

Proves the structural laws of the executable merkle layer
(`Bitcoin.Capstone.Merkle`, the direct port of Core
`consensus/merkle.cpp @cce32b168`). `sha256d` is treated as opaque: every
equality here holds at the `pairHash` / list-structure level, never inside
the hash — exactly the discipline the capstone executable uses when it
turns runtime booleans into PASS lines for the 6 real mainnet anchors.

Key content: **fuel honesty** (`merkleRootOfF_fuel_irrelevant`) — the root
does not depend on the fuel slack of `merkleRootOfF`, so
`merkleRootOf l = merkleRootOfF (l.length + 1) l` computes the SAME root as
any adequately-fueled run of the checker; plus the exact 1-tx and 2-tx
block roots (the genesis/91842 and 74638 shapes).

BLK-rule linkage:

| rule     | theorem here | statement (short) |
|----------|--------------|-------------------|
| BLK-009  | `merkleLevel_pair` | one pairing level of exactly two elements is `pairHash a b` |
| BLK-009  | `merkleRootOf_pair` / `merkleRootOfBlock_pair` | the 2-tx root is `SHA256d(txid₁ ‖ txid₂)` (74638 shape) |
| BLK-008  | `merkleLevel_singleton` | an odd level duplicates its last element: `pairHash a a` |
| BLK-008  | `merkleLevel_length_add1` / `merkleLevel_length` / `merkleLevel_length_halves` | every level exactly halves: `length = (n+1)/2`, and strictly shrinks for `n ≥ 2` |
| (merkle.cpp:51-73) | `merkleRootOfF_fuel` / `merkleRootOfF_fuel_irrelevant` / `merkleRootOf_fuel_ge` | fuel monotonicity: any two fuels ≥ the level length give the same root — the fuel slack is honest |
| BLK-013  | `merkleRootOf_singleton` / `merkleRootOfBlock_single_tx` | the 1-tx root IS the leaf (genesis/91842 shape; the `[] ⇒ null root` case is unreachable for real blocks) |
| BLK-007/BLK-010 | `merkleRootOfBlock_fuel` | the fuel-dropped root over txid leaves at ANY adequate fuel equals `merkleRootOfBlock` |

Axiom footprints (audited below by `#guard_msgs` pins): every theorem is
exactly `[propext, Quot.sound]` — the floor inherited from the core
`ByteArray`/`Sha256` definitional machinery; no theorem uses
`Classical.choice` or `sorryAx`.

Dependencies: `Bitcoin.Capstone.Merkle` (core, sorry-free).
-/

namespace BitcoinProofs.Theorems.CapstoneMerkle

open Bitcoin.Capstone.Merkle Bitcoin.Data

/-! ## Pairing-level laws (BLK-008 / BLK-009) -/

/-- **BLK-009**: a pairing level of exactly two elements produces the
single pair hash `SHA256d(a ‖ b)` — the 2-tx block's whole tree is one
level step (74638 shape). -/
theorem merkleLevel_pair (a b : ByteArray) :
    merkleLevel [a, b] = [pairHash a b] := rfl

/-- **BLK-008**: a singleton level duplicates its last element BEFORE
pairing — `SHA256d(a ‖ a)`. This is the odd-tail rule that lets the fold
terminate. -/
theorem merkleLevel_singleton (a : ByteArray) :
    merkleLevel [a] = [pairHash a a] := rfl

/-- The pairing level of a list of length `n` has length `(n+1)/2` —
every level at least halves. (Strong induction on the length bound: the
pair recursion skips two elements per step, so the hypothesis is about
`rest`, not the induction tail.) -/
theorem merkleLevel_length_add1 : ∀ l : List ByteArray,
    (merkleLevel l).length = (l.length + 1) / 2 := by
  have key : ∀ (n : Nat) (l : List ByteArray), l.length ≤ n →
      (merkleLevel l).length = (l.length + 1) / 2 := by
    intro n
    induction n with
    | zero =>
      intro l hle
      cases l with
      | nil => simp [merkleLevel]
      | cons a tl =>
        have h1 : (a :: tl).length = tl.length + 1 := rfl
        omega
    | succ n ih =>
      intro l hle
      cases l with
      | nil => simp [merkleLevel]
      | cons a tl =>
        cases tl with
        | nil => simp [merkleLevel]
        | cons b rest =>
          have hlen2 : (a :: b :: rest).length = rest.length + 2 := rfl
          have hrest : rest.length ≤ n := by omega
          have h1 : (merkleLevel (a :: b :: rest)).length
              = Nat.succ (merkleLevel rest).length := rfl
          have hrestL := ih rest hrest
          rw [h1, hrestL]
          omega
  intro l
  exact key l.length l (Nat.le_refl _)

/-- **BLK-008** (length form): a level of length `n` folds to a level of
length `(n+1)/2`. -/
theorem merkleLevel_length (l : List ByteArray) (n : Nat) (_h2 : 2 ≤ l.length)
    (hn : l.length = n) : (merkleLevel l).length = (n + 1) / 2 := by
  subst hn
  exact merkleLevel_length_add1 l

/-- Levels strictly shrink once they have at least two elements: the fold
`merkleRootOfF` terminates in at most `l.length` level steps (this is why
fuel `l.length + 1` always suffices). -/
theorem merkleLevel_length_halves : ∀ l : List ByteArray,
    2 ≤ l.length → (merkleLevel l).length < l.length := by
  intro l h2
  have h := merkleLevel_length_add1 l
  omega

/-! ## Fuel honesty (merkle.cpp:51-73) -/

/-- **Fuel monotonicity**: for a list of length `n ≥ 1`, ANY two fuels
`≥ n` produce the same root. Proof: induction on the larger fuel; a
cons-cons level reduces both fuels by one while the list exactly halves
(`merkleLevel_length_halves`), and the singleton level is
definitionally fuel-independent. `sha256d` stays opaque throughout. -/
theorem merkleRootOfF_fuel : ∀ (f₂ f₁ : Nat) (l : List ByteArray),
    1 ≤ l.length → l.length ≤ f₁ → f₁ ≤ f₂ →
    merkleRootOfF f₁ l = merkleRootOfF f₂ l := by
  intro f₂
  induction f₂ with
  | zero =>
    intro f₁ l h1 hle1 _hle2
    omega
  | succ f ih =>
    intro f₁ l h1 hle1 hle2
    rcases Nat.lt_or_ge f₁ (f + 1) with hlt | hge
    · -- f₁ ≤ f: reduce both fuels through one level step
      cases f₁ with
      | zero => omega
      | succ f₁' =>
        cases l with
        | nil =>
          have h0 : (List.nil : List ByteArray).length = 0 := rfl
          omega
        | cons a tl =>
          cases tl with
          | nil =>
            -- singleton level: both sides are the element itself
            rfl
          | cons b rest =>
            cases f with
            | zero => omega
            | succ f' =>
              have hlen' : (a :: b :: rest).length = rest.length + 2 := rfl
              have hmlen : (merkleLevel (a :: b :: rest)).length
                  = (rest.length + 3) / 2 := by
                have h := merkleLevel_length_add1 (a :: b :: rest)
                simpa using h
              have hmlen1 : 1 ≤ (merkleLevel (a :: b :: rest)).length := by omega
              have hmlenf₁ : (merkleLevel (a :: b :: rest)).length ≤ f₁' := by omega
              have hle2' : f₁' ≤ f' + 1 := by omega
              have e1 : ∀ g : Nat, merkleRootOfF (g + 1) (a :: b :: rest)
                  = merkleRootOfF g (merkleLevel (a :: b :: rest)) := fun _ => rfl
              rw [e1 f₁', e1 (f' + 1)]
              exact ih f₁' (merkleLevel (a :: b :: rest)) hmlen1 hmlenf₁ hle2'
    · -- f₁ ≥ f+1 together with f₁ ≤ f+1 gives f₁ = f+1
      have hEq : f₁ = f + 1 := by omega
      rw [hEq]

/-- **Fuel honesty, packaged**: with fuel `f ≥ l.length` the fuel-dropped
root equals the root at the canonical fuel `l.length + 1` that
`merkleRootOf` uses — the fuel slack in the executable never changes the
answer. -/
theorem merkleRootOfF_fuel_irrelevant (f : Nat) (l : List ByteArray)
    (h1 : 1 ≤ l.length) (hle : l.length ≤ f) :
    merkleRootOfF f l = merkleRootOfF (l.length + 1) l := by
  rcases Nat.lt_or_ge f (l.length + 1) with hlt | hge
  · exact merkleRootOfF_fuel (l.length + 1) f l h1 hle (by omega)
  · exact (merkleRootOfF_fuel f (l.length + 1) l h1 (by omega) hge).symm

/-- Corollary: at any fuel ≥ `l.length + 1` the fuel-dropped root IS
`merkleRootOf l` — the executable's fuel-dropped calls (capstone checker)
compute exactly the spec root. -/
theorem merkleRootOf_fuel_ge (f : Nat) (l : List ByteArray)
    (h1 : 1 ≤ l.length) (hf : l.length + 1 ≤ f) :
    merkleRootOfF f l = merkleRootOf l :=
  (merkleRootOfF_fuel f (l.length + 1) l h1 (by omega) hf).symm

/-! ## Exact small roots (BLK-007 / BLK-013) -/

/-- **BLK-013** (non-degenerate case): the root of a single-element list
is the element itself — the singleton level terminates immediately. -/
theorem merkleRootOf_singleton (a : ByteArray) : merkleRootOf [a] = a := rfl

/-- **BLK-009**: the root of exactly two leaves is their pair hash
`SHA256d(a ‖ b)` — one level step then terminate. -/
theorem merkleRootOf_pair (a b : ByteArray) :
    merkleRootOf [a, b] = pairHash a b := rfl

/-- **BLK-007/BLK-010** (1-tx block — the genesis / 91842 shape): the
merkle root of a one-transaction block is the txid of that transaction
itself (leaves are txids in block order; a single leaf IS the root). -/
theorem merkleRootOfBlock_single_tx (tx : Tx) :
    merkleRootOfBlock [tx] = txidOf tx := rfl

/-- **BLK-007/BLK-010** (2-tx block — the 74638 shape): the merkle root is
`SHA256d(txid₁ ‖ txid₂)` in block order. -/
theorem merkleRootOfBlock_pair (t1 t2 : Tx) :
    merkleRootOfBlock [t1, t2] = pairHash (txidOf t1) (txidOf t2) := rfl

/-- Executable-tier linkage: the capstone checker's fuel-dropped root over
the txid leaves, at ANY fuel ≥ block size, equals `merkleRootOfBlock` —
so a runtime `merkleOk` PASS at adequate fuel is a statement about the
canonical root (BLK-007/BLK-010), not an artifact of the fuel. -/
theorem merkleRootOfBlock_fuel (f : Nat) (txs : List Tx)
    (h1 : 1 ≤ txs.length) (hf : txs.length ≤ f) :
    merkleRootOfF f (txs.map txidOf) = merkleRootOfBlock txs := by
  refine merkleRootOfF_fuel_irrelevant f (txs.map txidOf) ?_ ?_
  · simpa using h1
  · simpa using hf

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleLevel_pair' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleLevel_pair

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleLevel_singleton' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleLevel_singleton

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleLevel_length_add1' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleLevel_length_add1

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleLevel_length' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleLevel_length

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleLevel_length_halves' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleLevel_length_halves

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleRootOfF_fuel' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleRootOfF_fuel

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleRootOfF_fuel_irrelevant' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleRootOfF_fuel_irrelevant

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleRootOf_fuel_ge' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleRootOf_fuel_ge

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleRootOf_singleton' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleRootOf_singleton

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleRootOf_pair' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleRootOf_pair

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleRootOfBlock_single_tx' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleRootOfBlock_single_tx

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleRootOfBlock_pair' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleRootOfBlock_pair

/-- info: 'BitcoinProofs.Theorems.CapstoneMerkle.merkleRootOfBlock_fuel' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merkleRootOfBlock_fuel

end BitcoinProofs.Theorems.CapstoneMerkle
