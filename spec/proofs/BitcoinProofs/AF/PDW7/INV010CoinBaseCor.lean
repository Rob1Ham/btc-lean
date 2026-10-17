import Bitcoin.Data.Tx

/-!
# INV010CoinBaseCor — TOP-35/INV-010 promotion proof

PDW7 (proof-promotion review 4, recovery review 4), 2026-10-17.
Row INV-010 (the coinbase classification rule underlying INV-008/009;
core anchor primitives/transaction.h:IsCoinBase:347 @cce32b168;
Satoshi), the D-DATA lane pick.

Core anchor (cce32b168, transaction.h:347):

    bool IsCoinBase() const {
      return (vin.size() == 1 && vin[0].prevout.IsNull());
    }

`CheckTransaction`'s very first gate (consensus/tx_check.cpp:19-68):
not-coinbase ⇒ the input-missing/duplicate checks run; coinbase ⇒
the BIP30/BIP34 duplicate-coinbase machinery instead. Our frozen def
(Data/Tx.lean:73, `@[rule "INV-010", rule "TXV-010"]`):
`match tx.vin with | [i] => i.prevout.isNull | _ => false` — the
`vin.size() == 1` = the `[i]` singleton pattern (a 0- or 2+-input
tx falls to the `_ => false` arm), `vin[0].prevout.IsNull()` =
`i.prevout.isNull` (Basic/Tx's `OutPoint.isNull` = the 32-zero-bytes
+ NULL_INDEX conjunction, transaction.h:43).

This file = the proof-promotion tier (route-B, PDW2 4df229b pattern):
the classification law — positive (single null-prevout input ⇒
coinbase) + the two negatives (0-input / 2-input ⇒ NOT coinbase; the
`vin.size() == 1` half of the Core conjunction) — proofs-side
`@[rule "INV-010"]` tags (the def-side tag stays on the frozen core
def), axiom-pinned. Proof route = the PDW2 F-PDW2-002 lesson: a def
whose body is a `match` on a field projection has no usable `rw`
equation, so each proof `show`s the match form verbatim (defeq =
delta+beta), `rw`s the `vin` hypothesis into the discriminant, and
closes by `rfl` (iota) / `exact` (iota+defeq). No mathlib, no
decide, no induction.
-/

namespace BitcoinProofs.AF.PDW7

open Bitcoin.Data

/-- INV-010 (positive): a tx with exactly one input whose prevout is
null (32 zero bytes + NULL_INDEX) IS a coinbase. -/
@[rule "INV-010"]
theorem isCoinBase_single_null (i : TxIn) (tx : Tx)
    (h : tx.vin = [i]) (hnull : i.prevout.isNull = true) :
    tx.isCoinBase = true := by
  show (match tx.vin with
        | [x] => x.prevout.isNull
        | _ => false) = true
  rw [h]
  exact hnull

/-- INV-010 (negative, 2 inputs): the `vin.size() == 1` half of the
Core conjunction — a two-input tx (e.g. a spend) is NOT a coinbase,
whatever its prevouts. -/
@[rule "INV-010"]
theorem isCoinBase_twoInputs (i j : TxIn) (tx : Tx)
    (h : tx.vin = [i, j]) :
    tx.isCoinBase = false := by
  show (match tx.vin with
        | [x] => x.prevout.isNull
        | _ => false) = false
  rw [h]

/-- INV-010 (negative, 0 inputs): a zero-input tx is NOT a coinbase
(the `[x]` singleton pattern does not match `nil`). -/
@[rule "INV-010"]
theorem isCoinBase_noInputs (tx : Tx)
    (h : tx.vin = []) :
    tx.isCoinBase = false := by
  show (match tx.vin with
        | [x] => x.prevout.isNull
        | _ => false) = false
  rw [h]


/-! ## L3 axiom pins (D2): drift on any of these fails the build.
All 3 theorems sorry-free; the full legal pin-set
[propext, Classical.choice, Quot.sound] on each = the elaborated
`match`-motive route of the `show`/`rw`-herding (PDW2 F-PDW2-002
class: a def matching on a field projection elaborates its motive
through the axiom-backed `match`-equation machinery). Zero sorryAx
everywhere (sorry_lint G1 class). -/

/-- info: 'BitcoinProofs.AF.PDW7.isCoinBase_single_null' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.isCoinBase_single_null

/-- info: 'BitcoinProofs.AF.PDW7.isCoinBase_twoInputs' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.isCoinBase_twoInputs

/-- info: 'BitcoinProofs.AF.PDW7.isCoinBase_noInputs' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW7.isCoinBase_noInputs

end BitcoinProofs.AF.PDW7
