# Lean excerpt reviewed for `locktime/C-L-locktime-input-index`

Repository `btc-lean-public` @ `4d62a97e551082a69b13f495365bff0a903b0c99`
(the `[lean] model_rev` pin).  Files
`spec/core/Bitcoin/Interpreter/Defs.lean`,
`spec/core/Bitcoin/Interpreter/Rules.lean` and the row face
`spec/proofs/BitcoinProofs/AF/PDW33/PDW33.lean`.

## LocktimeEnv (Defs.lean:235-243)

```lean
structure LocktimeEnv where
  txVersion : Int32 := 1
  txLockTime : UInt32 := 0
  txSequence : UInt32 := 0xFFFFFFFF   -- CTxIn::SEQUENCE_FINAL
```

## checkLockTimeDef (Defs.lean:272-283)

```lean
def checkLockTimeDef (env : LocktimeEnv) (n : ScriptNum) : Bool :=
  let txlt : Int := env.txLockTime.toNat
  if !((txlt < LOCKTIME_THRESHOLD ∧ n < LOCKTIME_THRESHOLD) ∨
       (txlt ≥ LOCKTIME_THRESHOLD ∧ n ≥ LOCKTIME_THRESHOLD)) then false
  else if n > txlt then false
  else if env.txSequence.toNat = 0xFFFFFFFF then false  -- input final
  else true
```

## checkSequenceDef (Defs.lean:285-297)

```lean
def checkSequenceDef (env : LocktimeEnv) (n : ScriptNum) : Bool :=
  if env.txVersion.toUInt32 < 2 then false
  else
    let txSeq := env.txSequence.toNat
    if (txSeq &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0 then false
    else
      let mask := SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK
      let txMasked := txSeq &&& mask
      let nMasked := n.toNat &&& mask   -- n ≥ 0 (caller checked)
      if !((txMasked < SEQUENCE_LOCKTIME_TYPE_FLAG ∧ nMasked < SEQUENCE_LOCKTIME_TYPE_FLAG) ∨
           (txMasked ≥ SEQUENCE_LOCKTIME_TYPE_FLAG ∧ nMasked ≥ SEQUENCE_LOCKTIME_TYPE_FLAG)) then false
      else !(nMasked > txMasked)
```

## locktimeEnvOf and the per-input theorems (Rules.lean:89-129)

```lean
def locktimeEnvOf (tx : Bitcoin.Data.Tx) (nIn : Nat) : LocktimeEnv :=
  { txVersion := tx.version
    txLockTime := tx.locktime
    txSequence :=
      (tx.vin.getD nIn { prevout := .null, scriptSig := .empty,
                         sequence := 0 }).sequence }

theorem locktimeEnvOf_congr (tx tx' : Bitcoin.Data.Tx) (nIn : Nat)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (hvin : (tx.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence
          = (tx'.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence) :
    locktimeEnvOf tx nIn = locktimeEnvOf tx' nIn

theorem checkLockTime_perInput (tx tx' : Bitcoin.Data.Tx) (nIn : Nat) (n : ScriptNum)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (hvin : …) :
    checkLockTimeDef (locktimeEnvOf tx nIn) n
      = checkLockTimeDef (locktimeEnvOf tx' nIn) n

theorem checkSequence_perInput (tx tx' : Bitcoin.Data.Tx) (nIn : Nat) (n : ScriptNum)
    (hver : …) (hlt : …) (hvin : …) :
    checkSequenceDef (locktimeEnvOf tx nIn) n
      = checkSequenceDef (locktimeEnvOf tx' nIn) n
```

The row-facing copies are `PDW33.lean:53,63,75`
(`locktimeEnvOf_congr_row`, `checkLockTime_perInput_row`,
`checkSequence_perInput_row`), tagged `@[rule "SCR-132"]` and axiom-clean
(`#print axioms` shows `[propext]`).

## Review mapping

| Lean | `src/l_leaf.cpp` / C leg |
|---|---|
| `locktimeEnvOf tx nIn` | `LocktimeEnv env{version, locktime, vin_at(vin, nIn)}` |
| `(tx.vin.getD nIn default).sequence` | `vin_at(vin, nIn)` = `nIn ? vin[1] : vin[0]` (2-input instance; `getD` default never taken) |
| `tx.version` (`Int32`, compared as `toUInt32`) | C `txTo.version` (`uint32_t`, `primitives/transaction.h:299`); both legs use the unsigned wire bits |
| `tx.locktime` (`UInt32`) | C `txTo.nLockTime` (`uint32_t`) |
| `checkLockTimeDef` | `check_lock_time`, verbatim branch order |
| `checkSequenceDef` | `check_sequence`, verbatim branch order |
| `Bool` verdict | harness `1`/`0`; the excluded `n < 0` operand is `-1` on both legs |

## What the equality proves

Both L entry points compute `check*Def (locktimeEnvOf tx nIn) n`, and
`locktimeEnvOf` mentions only the selected slot.  The *other* slot is still a
free parameter of both functions (it sits in the `vin` array / is passed to
`vin_at`), so a proof that the C body equals `check*Def (locktimeEnvOf …)` for
all `(version/locktime, n, s0, s1, nIn)` is exactly the row: changing the
non-`nIn` input's `nSequence` cannot change the verdict.  That is the bounded
2-input instance of `checkLockTime_perInput_row` /
`checkSequence_perInput_row`, with the index symbolic over both values.
