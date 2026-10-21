/-
  SCR-132, general-vin closure: `CheckLockTime` / `CheckSequence` read exactly
  the `nIn`-th vin slot, for an arbitrary `List TxIn`.

  Model source (btc-lean-public @ 4d62a97e, the pin in PINS.lock):
    spec/core/Bitcoin/Interpreter/Defs.lean:235-243  LocktimeEnv
    spec/core/Bitcoin/Interpreter/Defs.lean:272-283  checkLockTimeDef
    spec/core/Bitcoin/Interpreter/Defs.lean:285-297  checkSequenceDef
    spec/core/Bitcoin/Interpreter/Rules.lean:87-129  locktimeEnvOf + congruence

  This file is new; it imports the existing model and proves the parametric
  list statement that the two-input LLVM instance did not cover:

    * `vinReads` is an inductive model of the slots the `getD` lookup touches.
      It returns `[nIn]` in range and `[]` out of range (where the `getD`
      default is taken).  `vinReads_eq` proves this for an arbitrary list by
      induction, and `vinReads_subset` states that no index other than `nIn`
      can ever appear.
    * `locktimeEnvOf` selects `vin[nIn].sequence` in range and `0` (the
      `getD` default input's sequence) out of range, for an arbitrary list.
    * `locktimeEnvOf_eq_of_selected`: two transactions with the same version,
      locktime and selected sequence (or both with `nIn` out of range) have
      the same environment, whatever the other inputs, outputs or witnesses
      are.  This is the per-input non-interference statement.
    * `checkLockTime_perInput_row` / `checkSequence_perInput_row`: the verdicts
      are unchanged under any such perturbation, for an arbitrary `vin`.

  Everything is total, `sorry`-free, and axiom-clean (`#print axioms` at the
  end prints no `sorryAx`).
-/
import Bitcoin.Interpreter.Rules

namespace Bitcoin.Interpreter
namespace LocktimeInputIndexGeneral

open Bitcoin.Data

/-! ## The `getD` fallback input

`locktimeEnvOf` (Rules.lean:92-95) uses the inline default

    { prevout := .null, scriptSig := .empty, sequence := 0 }

whose `sequence` is `0`.  Naming it here keeps the statements readable; it is
definitionally the literal in the model. -/
def defaultTxIn : TxIn :=
  { prevout := .null, scriptSig := .empty, sequence := 0 }

/-! ## Inductive access trace of the per-input lookup

`vinReads vin nIn` records which input slots the `List.getD nIn default`
lookup touches.  The empty list and an out-of-range successor both take the
default without reading an element, hence return `[]`. -/
def vinReads : List TxIn → Nat → List Nat
  | [], _ => []
  | _ :: _, 0 => [0]
  | _ :: tl, k + 1 => (vinReads tl k).map (· + 1)

/-- For an arbitrary `vin` and `nIn`, the lookup touches exactly slot `nIn`
when it is in range, and no slot at all when it is out of range (the `getD`
fallback). -/
theorem vinReads_eq (vin : List TxIn) (nIn : Nat) :
    vinReads vin nIn = if nIn < vin.length then [nIn] else [] := by
  induction vin generalizing nIn with
  | nil => simp [vinReads]
  | cons a tl ih =>
    cases nIn with
    | zero => simp [vinReads]
    | succ k =>
      rw [vinReads]
      rw [ih k]
      by_cases h : k < tl.length
      · have h' : k + 1 < (a :: tl).length := by simp [h]
        simp [h]
      · have h' : ¬ k + 1 < (a :: tl).length := by simp [h]
        simp [h]

/-- In range the trace is the singleton `[nIn]`. -/
theorem vinReads_eq_singleton_iff (vin : List TxIn) (nIn : Nat) :
    vinReads vin nIn = [nIn] ↔ nIn < vin.length := by
  rw [vinReads_eq]
  by_cases h : nIn < vin.length <;> simp [h]

/-- Out of range the trace is empty: the `getD` fallback reads no input. -/
theorem vinReads_eq_nil_iff (vin : List TxIn) (nIn : Nat) :
    vinReads vin nIn = [] ↔ vin.length ≤ nIn := by
  rw [vinReads_eq]
  by_cases h : nIn < vin.length
  · simp [h]
  · simp [h]; omega

/-- No slot other than `nIn` is ever touched. -/
theorem vinReads_subset (vin : List TxIn) (nIn : Nat) :
    ∀ j ∈ vinReads vin nIn, j = nIn := by
  rw [vinReads_eq]
  by_cases h : nIn < vin.length <;> simp [h]

/-! ## `List.getD` lemmas (local copies, arbitrary list) -/

theorem getD_eq_getElem_of_lt {α : Type} (l : List α) (i : Nat) (d : α)
    (h : i < l.length) : l.getD i d = l[i] := by
  induction l generalizing i with
  | nil => simp at h
  | cons a tl ih =>
    cases i with
    | zero => rfl
    | succ k =>
      simp only [List.getD_cons_succ, List.getElem_cons_succ]
      exact ih k (by simpa using h)

theorem getD_eq_default_of_ge {α : Type} (l : List α) (i : Nat) (d : α)
    (h : l.length ≤ i) : l.getD i d = d := by
  induction l generalizing i with
  | nil => rfl
  | cons a tl ih =>
    cases i with
    | zero => simp at h
    | succ k =>
      simp only [List.getD_cons_succ]
      exact ih k (by simpa using h)

/-! ## What the environment reads, for an arbitrary list -/

/-- In range, the environment carries `vin[nIn].sequence` and nothing else
from the selected input (not its prevout, not its scriptSig). -/
theorem locktimeEnvOf_txSequence_of_lt (tx : Tx) (nIn : Nat)
    (h : nIn < tx.vin.length) :
    (locktimeEnvOf tx nIn).txSequence = (tx.vin[nIn]).sequence := by
  unfold locktimeEnvOf
  change (tx.vin.getD nIn defaultTxIn).sequence = (tx.vin[nIn]).sequence
  rw [getD_eq_getElem_of_lt tx.vin nIn defaultTxIn h]

/-- Out of range, the environment carries the `getD` default sequence (`0`),
so no input is read at all. -/
theorem locktimeEnvOf_txSequence_default (tx : Tx) (nIn : Nat)
    (h : tx.vin.length ≤ nIn) :
    (locktimeEnvOf tx nIn).txSequence = 0 := by
  unfold locktimeEnvOf
  change (tx.vin.getD nIn defaultTxIn).sequence = 0
  rw [getD_eq_default_of_ge tx.vin nIn defaultTxIn h]
  rfl

/-- The selected sequence relation used by the non-interference theorems:
either both transactions have `nIn` in range and agree on that slot's
sequence, or both have `nIn` out of range (so both take the default). -/
def SameSelectedInput (tx tx' : Tx) (nIn : Nat) : Prop :=
  (nIn < tx.vin.length ∧ nIn < tx'.vin.length ∧
      (tx.vin.getD nIn defaultTxIn).sequence
        = (tx'.vin.getD nIn defaultTxIn).sequence) ∨
    (tx.vin.length ≤ nIn ∧ tx'.vin.length ≤ nIn)

/-- The checker environment is input-local for an arbitrary `vin`: same
version, same locktime, same selected sequence (or both out of range) is
enough.  Every other input, every output and the witness are unconstrained. -/
theorem locktimeEnvOf_eq_of_selected (tx tx' : Tx) (nIn : Nat)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (hsel : SameSelectedInput tx tx' nIn) :
    locktimeEnvOf tx nIn = locktimeEnvOf tx' nIn := by
  unfold locktimeEnvOf
  simp only [hver, hlt]
  congr 1
  rcases hsel with ⟨h1, h2, hs⟩ | ⟨h1, h2⟩
  · exact hs
  · change (tx.vin.getD nIn defaultTxIn).sequence
      = (tx'.vin.getD nIn defaultTxIn).sequence
    rw [getD_eq_default_of_ge tx.vin nIn defaultTxIn h1,
        getD_eq_default_of_ge tx'.vin nIn defaultTxIn h2]

/-! ## The row faces -/

/-- SCR-132 for `CheckLockTime`: arbitrary `vin`, arbitrary `nIn`; changing
any input other than `nIn` (or any output/witness) cannot change the verdict,
and an out-of-range `nIn` is the default input on both sides. -/
theorem checkLockTime_perInput_row (tx tx' : Tx) (nIn : Nat) (n : Bitcoin.Numeric.ScriptNum)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (hsel : SameSelectedInput tx tx' nIn) :
    checkLockTimeDef (locktimeEnvOf tx nIn) n
      = checkLockTimeDef (locktimeEnvOf tx' nIn) n := by
  rw [locktimeEnvOf_eq_of_selected tx tx' nIn hver hlt hsel]

/-- SCR-132 for `CheckSequence` (BIP112): same statement. -/
theorem checkSequence_perInput_row (tx tx' : Tx) (nIn : Nat) (n : Bitcoin.Numeric.ScriptNum)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (hsel : SameSelectedInput tx tx' nIn) :
    checkSequenceDef (locktimeEnvOf tx nIn) n
      = checkSequenceDef (locktimeEnvOf tx' nIn) n := by
  rw [locktimeEnvOf_eq_of_selected tx tx' nIn hver hlt hsel]

/-- Out-of-range corollary: when `nIn` is past the end of both vin lists, the
`getD` fallback is taken on both sides, so the verdict depends only on the
transaction-level version/locktime and the operand. -/
theorem checkLockTime_outOfRange (tx tx' : Tx) (nIn : Nat) (n : Bitcoin.Numeric.ScriptNum)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (h1 : tx.vin.length ≤ nIn) (h2 : tx'.vin.length ≤ nIn) :
    checkLockTimeDef (locktimeEnvOf tx nIn) n
      = checkLockTimeDef (locktimeEnvOf tx' nIn) n :=
  checkLockTime_perInput_row tx tx' nIn n hver hlt (Or.inr ⟨h1, h2⟩)

/-- Out-of-range corollary for `CheckSequence`. -/
theorem checkSequence_outOfRange (tx tx' : Tx) (nIn : Nat) (n : Bitcoin.Numeric.ScriptNum)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (h1 : tx.vin.length ≤ nIn) (h2 : tx'.vin.length ≤ nIn) :
    checkSequenceDef (locktimeEnvOf tx nIn) n
      = checkSequenceDef (locktimeEnvOf tx' nIn) n :=
  checkSequence_perInput_row tx tx' nIn n hver hlt (Or.inr ⟨h1, h2⟩)

/-- The two-input instance of the old cell is the special case `vin.length = 2`
of the statements above; recorded so the general theorem is visibly a strict
strengthening, not a relabelling. -/
theorem checkLockTime_twoInput_is_special_case (tx tx' : Tx) (n : Bitcoin.Numeric.ScriptNum)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (h0 : tx.vin.length = 2) (h0' : tx'.vin.length = 2) (nIn : Nat)
    (hlt2 : nIn < 2)
    (hs : (tx.vin.getD nIn defaultTxIn).sequence
            = (tx'.vin.getD nIn defaultTxIn).sequence) :
    checkLockTimeDef (locktimeEnvOf tx nIn) n
      = checkLockTimeDef (locktimeEnvOf tx' nIn) n :=
  checkLockTime_perInput_row tx tx' nIn n hver hlt
    (Or.inl ⟨by omega, by omega, hs⟩)

#print axioms vinReads_eq
#print axioms vinReads_eq_singleton_iff
#print axioms vinReads_eq_nil_iff
#print axioms vinReads_subset
#print axioms locktimeEnvOf_txSequence_of_lt
#print axioms locktimeEnvOf_txSequence_default
#print axioms locktimeEnvOf_eq_of_selected
#print axioms checkLockTime_perInput_row
#print axioms checkSequence_perInput_row
#print axioms checkLockTime_outOfRange
#print axioms checkSequence_outOfRange
#print axioms checkLockTime_twoInput_is_special_case

end LocktimeInputIndexGeneral
end Bitcoin.Interpreter
