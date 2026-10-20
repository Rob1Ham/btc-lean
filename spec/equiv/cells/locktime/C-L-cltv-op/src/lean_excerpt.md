# Lean excerpt reviewed for `locktime/C-L-cltv-op`

Repository `btc-lean-public` @ `4d62a97e551082a69b13f495365bff0a903b0c99`
(the `[lean] model_rev` pin). File `spec/core/Bitcoin/Interpreter/Defs.lean`.

## Threshold constant (Defs.lean:77-79)

```lean
/-- LOCKTIME_THRESHOLD (script.h): above this, nLockTime/nSequence are
interpreted as a timestamp rather than a block height. -/
def LOCKTIME_THRESHOLD : Nat := 500000000
```

## LocktimeEnv (Defs.lean:235-238)

```lean
structure LocktimeEnv where
  txVersion : Int32 := 1
  txLockTime : UInt32 := 0
  txSequence : UInt32 := 0xFFFFFFFF   -- CTxIn::SEQUENCE_FINAL
```

## checkLockTimeDef (Defs.lean:270-283)

```lean
/-- `GenericTransactionSignatureChecker::CheckLockTime`
(interpreter.cpp:1755-1788), as a pure function of the environment. -/
@[rule "SCR-122", rule "SCR-123", rule "SCR-124", rule "SCR-125", rule "INV-022"]
def checkLockTimeDef (env : LocktimeEnv) (n : ScriptNum) : Bool :=
  let txlt : Int := env.txLockTime.toNat
  if !((txlt < LOCKTIME_THRESHOLD ∧ n < LOCKTIME_THRESHOLD) ∨
       (txlt ≥ LOCKTIME_THRESHOLD ∧ n ≥ LOCKTIME_THRESHOLD)) then false
  else if n > txlt then false
  else if env.txSequence.toNat = 0xFFFFFFFF then false  -- input final
  else true
```

## Opcode branch (Defs.lean:857-865)

```lean
    else if w = 0xb1 then                                   -- OP_CHECKLOCKTIMEVERIFY
      if !flags.cltv then .ok st
      else if st.stack.length < 1 then .error .stackUnderflow
      else match decodeNum pol (topAt st.stack 1) 5 with
        | .error e => .error e
        | .ok n =>
          if n < 0 then .error .negativeLocktime
          else if !checkLockTimeDef ctx.chk.env n then .error .unsatisfiedLocktime
          else .ok st
```

## Review mapping

| Lean | `src/l_leaf.cpp` |
|---|---|
| `LOCKTIME_THRESHOLD = 500000000` | `lean_slice::LOCKTIME_THRESHOLD` |
| `LocktimeEnv.txLockTime/txSequence` | `struct LocktimeEnv { uint32_t txLockTime; uint32_t txSequence; }` |
| `let txlt : Int := env.txLockTime.toNat` | `const int64_t txlt = static_cast<int64_t>(env.txLockTime);` |
| `!((txlt < T ∧ n < T) ∨ (txlt ≥ T ∧ n ≥ T))` | identical expression |
| `n > txlt` | `n > txlt` |
| `env.txSequence.toNat = 0xFFFFFFFF` | `env.txSequence == 0xFFFFFFFFu` |
| `if !flags.cltv then .ok st` | `if (!cltv_flag) return EQUIV_ERR_OK;` |
| `if n < 0 then .error .negativeLocktime` | `if (n < 0) return EQUIV_ERR_NEGATIVE_LOCKTIME;` |
| `if !checkLockTimeDef .. then .error .unsatisfiedLocktime` | mirrored |
| stack-underflow / `decodeNum` branches | outside the cell domain (one decoded operand) |

`.negativeLocktime` and `.unsatisfiedLocktime` reach the ABI ordinals through
`twin/gen.py`'s `ERRORS` table (`TWIN_NEGATIVE_LOCKTIME`,
`TWIN_UNSATISFIED_LOCKTIME`), which is what `core_ord` emits.
