# Lean excerpt — general-vin SCR-132

Source: `src/GeneralIndex.lean` (new in this cell), importing the pinned model
unchanged.

- Model pin: `4d62a97e551082a69b13f495365bff0a903b0c99` (`PINS.lock` \[lean\]).
- Toolchain: `leanprover/lean4:v4.35.0`.
- Upstream definitions cited, unchanged:
  - `spec/core/Bitcoin/Interpreter/Defs.lean:235-243` `LocktimeEnv`
  - `spec/core/Bitcoin/Interpreter/Defs.lean:272-283` `checkLockTimeDef`
  - `spec/core/Bitcoin/Interpreter/Defs.lean:285-297` `checkSequenceDef`
  - `spec/core/Bitcoin/Interpreter/Rules.lean:87-129` `locktimeEnvOf`,
    `locktimeEnvOf_congr`, `checkLockTime_perInput`, `checkSequence_perInput`

## The inductive access trace

```lean
def vinReads : List TxIn → Nat → List Nat
  | [], _ => []
  | _ :: _, 0 => [0]
  | _ :: tl, k + 1 => (vinReads tl k).map (· + 1)

theorem vinReads_eq (vin : List TxIn) (nIn : Nat) :
    vinReads vin nIn = if nIn < vin.length then [nIn] else []

theorem vinReads_subset (vin : List TxIn) (nIn : Nat) :
    ∀ j ∈ vinReads vin nIn, j = nIn
```

`vinReads_eq` is the induction over the whole list.  In range the lookup
touches exactly `nIn`; out of range it touches nothing (the `getD` default).

## The environment is the selected slot, for any list

```lean
theorem locktimeEnvOf_txSequence_of_lt (tx : Tx) (nIn : Nat)
    (h : nIn < tx.vin.length) :
    (locktimeEnvOf tx nIn).txSequence = (tx.vin[nIn]).sequence

theorem locktimeEnvOf_txSequence_default (tx : Tx) (nIn : Nat)
    (h : tx.vin.length ≤ nIn) :
    (locktimeEnvOf tx nIn).txSequence = 0
```

## Non-interference and the row faces

```lean
def SameSelectedInput (tx tx' : Tx) (nIn : Nat) : Prop :=
  (nIn < tx.vin.length ∧ nIn < tx'.vin.length ∧
      (tx.vin.getD nIn defaultTxIn).sequence
        = (tx'.vin.getD nIn defaultTxIn).sequence) ∨
    (tx.vin.length ≤ nIn ∧ tx'.vin.length ≤ nIn)

theorem locktimeEnvOf_eq_of_selected (tx tx' : Tx) (nIn : Nat)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (hsel : SameSelectedInput tx tx' nIn) :
    locktimeEnvOf tx nIn = locktimeEnvOf tx' nIn

theorem checkLockTime_perInput_row (tx tx' : Tx) (nIn : Nat) (n : ScriptNum)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (hsel : SameSelectedInput tx tx' nIn) :
    checkLockTimeDef (locktimeEnvOf tx nIn) n
      = checkLockTimeDef (locktimeEnvOf tx' nIn) n

theorem checkSequence_perInput_row (tx tx' : Tx) (nIn : Nat) (n : ScriptNum)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (hsel : SameSelectedInput tx tx' nIn) :
    checkSequenceDef (locktimeEnvOf tx nIn) n
      = checkSequenceDef (locktimeEnvOf tx' nIn) n
```

`tx` and `tx'` are arbitrary: other inputs (their sequences, prevouts and
scriptSigs), the outputs, the witness and the vin length on the same side of
`nIn` are unconstrained.  That is the per-input non-interference statement.

## Out-of-range fallback and the two-input special case

```lean
theorem checkLockTime_outOfRange (tx tx' : Tx) (nIn : Nat) (n : ScriptNum)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (h1 : tx.vin.length ≤ nIn) (h2 : tx'.vin.length ≤ nIn) :
    checkLockTimeDef (locktimeEnvOf tx nIn) n
      = checkLockTimeDef (locktimeEnvOf tx' nIn) n

theorem checkSequence_outOfRange ...   -- same

theorem checkLockTime_twoInput_is_special_case (tx tx' : Tx) (n : ScriptNum)
    (hver ...) (hlt ...) (h0 : tx.vin.length = 2) (h0' : tx'.vin.length = 2)
    (nIn : Nat) (hlt2 : nIn < 2) (hs : selected sequences equal) :
    checkLockTimeDef (locktimeEnvOf tx nIn) n
      = checkLockTimeDef (locktimeEnvOf tx' nIn) n
```

## Axiom check (from `lean/result.txt`)

The run ends with `#print axioms` for every exported theorem.  Observed:

```
'...vinReads_eq' depends on axioms: [propext]
'...vinReads_eq_singleton_iff' depends on axioms: [propext]
'...vinReads_eq_nil_iff' depends on axioms: [propext, Quot.sound]
'...vinReads_subset' depends on axioms: [propext, Quot.sound]
'...locktimeEnvOf_txSequence_of_lt' depends on axioms: [propext]
'...locktimeEnvOf_txSequence_default' depends on axioms: [propext]
'...locktimeEnvOf_eq_of_selected' depends on axioms: [propext]
'...checkLockTime_perInput_row' depends on axioms: [propext]
'...checkSequence_perInput_row' depends on axioms: [propext]
'...checkLockTime_outOfRange' depends on axioms: [propext]
'...checkSequence_outOfRange' depends on axioms: [propext]
'...checkLockTime_twoInput_is_special_case' depends on axioms: [propext, Quot.sound]
```

No `sorryAx`.  `propext`/`Quot.sound` are Lean core axioms also present in the
existing model theorems; nothing additional is assumed.
