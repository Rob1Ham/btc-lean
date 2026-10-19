import Bitcoin.Capstone.Merkle

/-!
# PDW50 — TOP-246..250 row faces: Capstone/Merkle leaf & tree core

Route B (F-PDW32-001): `Theorems/CapstoneMerkleCor.lean` and
`Theorems/CapstoneTxidCor.lean` already carry the development; this file
restates the five row faces on PDW50's own `@[rule]` theorems (the DB
rows had never been flipped — Capstone/Merkle had zero proven rows).
Core defs are read-only; zero core writes.

Rows: BLK-005 txid, BLK-006 wtxid split, BLK-007 txid-leaf root,
BLK-008 odd-level duplication + halving, BLK-009 pair hash.
-/

namespace BitcoinProofs.AF.PDW50

open Bitcoin.Capstone.Merkle
open Bitcoin.Crypto.Seam.Hash (sha256d)
open Bitcoin.Data
open Bitcoin.Serialization (hasWitness encodeTx)

/-! ## BLK-005 — txid = SHA256d(base serialization) -/

@[rule "BLK-005"]
theorem txidOf_eq_sha256d_serTx (tx : Tx) : txidOf tx = sha256d (serTx tx) := rfl

/-- txid is a function of the base serialization alone (no witness slot). -/
@[rule "BLK-005"]
theorem txidOf_congr {a b : Tx} (h : serTx a = serTx b) : txidOf a = txidOf b := by
  rw [txidOf_eq_sha256d_serTx, txidOf_eq_sha256d_serTx, h]

/-! ## BLK-006 — wtxid: txid verbatim without witness, SHA256d(encodeTx) with -/

@[rule "BLK-006"]
theorem wtxidOf_eq_txidOf_of_noWitness {tx : Tx} (h : hasWitness tx = false) :
    wtxidOf tx = txidOf tx := by
  simp [wtxidOf, txidOf, h]

@[rule "BLK-006"]
theorem wtxidOf_eq_sha256d_encodeTx_of_hasWitness {tx : Tx}
    (h : hasWitness tx = true) : wtxidOf tx = sha256d (encodeTx tx) := by
  simp [wtxidOf, h]

/-! ## BLK-007 — block merkle leaves are the txids in block order -/

@[rule "BLK-007"]
theorem merkleRootOfBlock_eq (txs : List Tx) :
    merkleRootOfBlock txs = merkleRootOf (txs.map txidOf) := rfl

/-- A one-tx block's root is that tx's txid (genesis / 91842 shape). -/
@[rule "BLK-007"]
theorem merkleRootOfBlock_single (tx : Tx) : merkleRootOfBlock [tx] = txidOf tx := rfl

/-- A two-tx block's root is the pair hash of the two txids, in order. -/
@[rule "BLK-007"]
theorem merkleRootOfBlock_pair (a b : Tx) :
    merkleRootOfBlock [a, b] = pairHash (txidOf a) (txidOf b) := rfl

/-! ## BLK-009 — pair hash = SHA256d(left ‖ right), in order -/

@[rule "BLK-009"]
theorem pairHash_eq_sha256d_append (a b : ByteArray) :
    pairHash a b = sha256d (a ++ b) := rfl

@[rule "BLK-009"]
theorem merkleLevel_pair (a b : ByteArray) :
    merkleLevel [a, b] = [pairHash a b] := rfl

@[rule "BLK-009"]
theorem merkleRootOf_pair (a b : ByteArray) :
    merkleRootOf [a, b] = pairHash a b := rfl

/-! ## BLK-008 — odd-sized level duplicates its last element; levels halve -/

@[rule "BLK-008"]
theorem merkleLevel_singleton (a : ByteArray) :
    merkleLevel [a] = [pairHash a a] := rfl

/-- **BLK-008**, arbitrary odd level: if `l` has even length then
`l ++ [x]` has odd length, and Core duplicates its last element `x`
before pairing. The whole level step is therefore the level step of the
even prefix followed by the single paired tail `pairHash x x`.

This is the general form of `merkleLevel_singleton`: every odd-sized
level is `l ++ [x]` for an even prefix `l`, so no length or element is
special-cased. -/
@[rule "BLK-008"]
theorem merkleLevel_append_singleton (l : List ByteArray) (x : ByteArray)
    (h : l.length % 2 = 0) :
    merkleLevel (l ++ [x]) = merkleLevel l ++ [pairHash x x] := by
  -- Strong induction on a length bound: each step consumes the pair
  -- `a, b` and leaves the even-length tail `rest` for the IH.
  have key : ∀ (n : Nat) (l : List ByteArray), l.length ≤ n →
      l.length % 2 = 0 →
      merkleLevel (l ++ [x]) = merkleLevel l ++ [pairHash x x] := by
    intro n
    induction n with
    | zero =>
      intro l hle _hpar
      have hl : l = [] := by
        cases l with
        | nil => rfl
        | cons a tl => simp at hle
      subst hl
      rfl
    | succ n ih =>
      intro l hle hpar
      cases l with
      | nil => rfl
      | cons a tl =>
        cases tl with
        | nil => simp at hpar
        | cons b rest =>
          have hrest_le : rest.length ≤ n := by
            simp only [List.length_cons] at hle
            omega
          have hrest_par : rest.length % 2 = 0 := by
            simp only [List.length_cons] at hpar
            omega
          have hIH := ih rest hrest_le hrest_par
          change merkleLevel (a :: b :: (rest ++ [x])) =
            merkleLevel (a :: b :: rest) ++ [pairHash x x]
          simp only [merkleLevel, List.cons_append]
          rw [hIH]
  exact key l.length l (Nat.le_refl _) h

/-- The Core odd-tail rule plus pairing: every level has length `(n+1)/2`. -/
@[rule "BLK-008"]
theorem merkleLevel_length (l : List ByteArray) :
    (merkleLevel l).length = (l.length + 1) / 2 := by
  -- Strong induction on a length bound: the pair step consumes two
  -- elements at once, so the hypothesis must be about `rest`, not the
  -- induction tail.
  have key : ∀ (n : Nat) (l : List ByteArray), l.length ≤ n →
      (merkleLevel l).length = (l.length + 1) / 2 := by
    intro n
    induction n with
    | zero =>
      intro l hle
      cases l with
      | nil => rfl
      | cons a tl =>
        have h1 : (a :: tl).length = tl.length + 1 := rfl
        omega
    | succ n ih =>
      intro l hle
      cases l with
      | nil => rfl
      | cons a tl =>
        cases tl with
        | nil => simp [merkleLevel]
        | cons b rest =>
          have hrest : rest.length ≤ n := by simp only [List.length_cons] at hle; omega
          have h1 : (merkleLevel (a :: b :: rest)).length
              = Nat.succ (merkleLevel rest).length := rfl
          have hrestL := ih rest hrest
          rw [h1, hrestL]
          simp only [List.length_cons]
          omega
  exact key l.length l (Nat.le_refl _)

/-- Non-degenerate levels strictly shrink, so the fold terminates. -/
@[rule "BLK-008"]
theorem merkleLevel_length_lt {l : List ByteArray} (h : 2 ≤ l.length) :
    (merkleLevel l).length < l.length := by
  rw [merkleLevel_length]
  omega

end BitcoinProofs.AF.PDW50
