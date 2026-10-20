# Lean excerpt reviewed for `locktime/C-L-csv-op`

Repository `btc-lean-public` @ `4d62a97e551082a69b13f495365bff0a903b0c99`
(the `[lean] model_rev` pin). File `spec/core/Bitcoin/Interpreter/Defs.lean`.

## BIP68 constants (Defs.lean:80-85)

```lean
/-- CTxIn::SEQUENCE_LOCKTIME_DISABLE_FLAG (1 << 31). -/
def SEQUENCE_LOCKTIME_DISABLE_FLAG : Nat := 0x80000000
/-- CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG (1 << 22). -/
def SEQUENCE_LOCKTIME_TYPE_FLAG : Nat := 0x00400000
/-- CTxIn::SEQUENCE_LOCKTIME_MASK (0x0000ffff). -/
def SEQUENCE_LOCKTIME_MASK : Nat := 0x0000ffff
```

## LocktimeEnv (Defs.lean:235-238)

```lean
structure LocktimeEnv where
  txVersion : Int32 := 1
  txLockTime : UInt32 := 0
  txSequence : UInt32 := 0xFFFFFFFF   -- CTxIn::SEQUENCE_FINAL
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

## Opcode branch (Defs.lean:866-875)

```lean
    else if w = 0xb2 then                                   -- OP_CHECKSEQUENCEVERIFY
      if !flags.csv then .ok st
      else if st.stack.length < 1 then .error .stackUnderflow
      else match decodeNum pol (topAt st.stack 1) 5 with
        | .error e => .error e
        | .ok n =>
          if n < 0 then .error .negativeLocktime
          else if (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0 then .ok st
          else if !checkSequenceDef ctx.chk.env n then .error .unsatisfiedLocktime
          else .ok st
```

## Review mapping

| Lean | `src/l_leaf.cpp` |
|---|---|
| `SEQUENCE_LOCKTIME_DISABLE_FLAG = 0x80000000` | `lean_slice::SEQUENCE_LOCKTIME_DISABLE_FLAG` |
| `SEQUENCE_LOCKTIME_TYPE_FLAG = 0x00400000` | `lean_slice::SEQUENCE_LOCKTIME_TYPE_FLAG` |
| `SEQUENCE_LOCKTIME_MASK = 0x0000ffff` | `lean_slice::SEQUENCE_LOCKTIME_MASK` |
| `env.txVersion.toUInt32 < 2` | `env.txVersion < 2u` (both are the unsigned wire value) |
| `env.txSequence` (`UInt32`) | `env.txSequence` (`uint32_t`) |
| `(txSeq &&& DISABLE_FLAG) ≠ 0` | `(txSeq & SEQUENCE_LOCKTIME_DISABLE_FLAG) != 0u` |
| `mask := TYPE_FLAG ||| MASK` | `const uint32_t mask = TYPE_FLAG \| MASK;` |
| `txMasked := txSeq &&& mask` | `const uint32_t txMasked = txSeq & mask;` |
| `nMasked := n.toNat &&& mask` (n ≥ 0) | `static_cast<uint32_t>(n) & mask` |
| type-agreement disjunction | identical expression |
| `!(nMasked > txMasked)` | `return !(nMasked > txMasked);` |
| `if !flags.csv then .ok st` | `if (!csv_flag) return EQUIV_ERR_OK;` |
| `if n < 0 then .error .negativeLocktime` | mirrored |
| `(n.toNat &&& DISABLE_FLAG) ≠ 0 then .ok st` | `if ((uint64_t)n & DISABLE_FLAG) != 0) return EQUIV_ERR_OK;` |
| stack-underflow / `decodeNum` branches | outside the cell domain (one decoded operand) |

Note on `txVersion`: `LocktimeEnv.txVersion` is `Int32` but the model compares
`toUInt32`, i.e. the unsigned wire bits.  Core's `CTransaction::version` is
`uint32_t` at the pin (`primitives/transaction.h:299`), so the C leg's
`txTo->version < 2` and the transliteration's `txVersion < 2u` are the same
unsigned comparison.  This is why the C leg must model the field as
`uint32_t`, not `int32_t`.
