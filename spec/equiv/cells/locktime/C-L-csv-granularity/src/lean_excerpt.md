# Lean excerpt reviewed for `locktime/C-L-csv-granularity`

Repository `btc-lean-public` @ `4d62a97e551082a69b13f495365bff0a903b0c99`
(the `[lean] model_rev` pin). Files
`spec/core/Bitcoin/DataLaws/Laws.lean` and
`spec/core/Bitcoin/Interpreter/Defs.lean`.

## Granularity constant and the mask (Laws.lean:62-64, Defs.lean:80-85)

```lean
/-- `CTxIn::SEQUENCE_LOCKTIME_GRANULARITY` (`primitives/transaction.h:115`): -/
def SEQUENCE_LOCKTIME_GRANULARITY : Nat := 9
```

```lean
def SEQUENCE_LOCKTIME_TYPE_FLAG : Nat := 0x00400000
def SEQUENCE_LOCKTIME_MASK : Nat := 0x0000ffff
```

## seqRelative / seqIsTimeBased (Laws.lean:240, 250-252)

```lean
def seqRelative (s : UInt32) : Nat := (s &&& SEQUENCE_LOCKTIME_MASK).toNat

def seqIsTimeBased (s : UInt32) : Bool :=
  decide ((s &&& SEQUENCE_LOCKTIME_TYPE_FLAG) ≠ 0)
```

## checkSequenceDef tail (Defs.lean:285-297)

The version gate and the transaction disable-flag gate are the prefix of this
definition and are proved in `locktime/C-L-csv-op` (SCR-128/129).  The cell
here starts at the mask:

```lean
      let mask := SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK
      let txMasked := txSeq &&& mask
      let nMasked := n.toNat &&& mask   -- n ≥ 0 (caller checked)
      if !((txMasked < SEQUENCE_LOCKTIME_TYPE_FLAG ∧ nMasked < SEQUENCE_LOCKTIME_TYPE_FLAG) ∨
           (txMasked ≥ SEQUENCE_LOCKTIME_TYPE_FLAG ∧ nMasked ≥ SEQUENCE_LOCKTIME_TYPE_FLAG)) then false
      else !(nMasked > txMasked)
```

## Time lane (Laws.lean:427-444)

```lean
theorem seqTimeGranularity_pow :
    (512 : Nat) = 2 ^ SEQUENCE_LOCKTIME_GRANULARITY := by decide

def seqTimeOk (mtpParent : Nat) (s : UInt32) (mtpBlock : Nat) : Bool :=
  decide (mtpBlock ≥ mtpParent + seqRelative s * 512)

theorem seqTimeLock_last_invalid (mtpParent : Nat) (s : UInt32) (mtpBlock : Nat)
    (h : 1 ≤ mtpParent + seqRelative s * 512) :
    seqTimeOk mtpParent s mtpBlock = true ↔
      mtpParent + seqRelative s * 512 - 1 < mtpBlock := by
  rw [seqTimeOk_iff]; omega
```

## Review mapping

| Lean | `src/l_leaf.cpp` / C leg |
|---|---|
| `mask := TYPE_FLAG ||| MASK` | `0x0040ffff`, identical expression |
| `txMasked := txSeq &&& mask` | `tx_sequence & mask` (`uint32_t`) |
| `nMasked := n.toNat &&& mask` | `static_cast<uint32_t>(n) & mask`; the C slice keeps `CScriptNum::operator&` on the `int64_t` value, which is the same low-32-bit AND |
| type-agreement disjunction (Defs.lean:291-293) | `interpreter.cpp:1823-1828`, identical expression |
| `!(nMasked > txMasked)` | `interpreter.cpp:1832-1833` |
| `seqRelative s = (s &&& MASK).toNat` | `core_slice`: `(tx_sequence & MASK)`; `lean_slice::seq_relative` |
| `seqRelative s * 512` | `(txSeq & MASK) << 9` (both legs); Cryptol `granularity` |
| `seqIsTimeBased s` | the `if (txin.nSequence & TYPE_FLAG)` guard of `tx_verify.cpp:79` |
| `seqTimeOk parent s block` | `EvaluateSequenceLocks` (`tx_verify.cpp:103-111`) on one input |
| `seqTimeLock_last_invalid` (`… - 1 < block`) | `nMinTime = … - 1; if (nMinTime >= nBlockTime) return false` — the `-1` last-invalid convention and the strict `<` are the same integer inequality as `mtpBlock ≥ mtpParent + rel*512` |

## Domain note

`seqTimeOk` takes `Nat` parents and blocks, while the cell quantifies over
`uint32_t` MTPs.  This is not a lossy restriction for reachable chain state:
`CBlockIndex::GetMedianTimePast()` (`chain.h:233`) is the median of
`CBlockHeader::nTime` values, each a `uint32_t`, so the median is always one
of those 32-bit timestamps and therefore lies in `[0, 2^32)`.  It also keeps
`nCoinTime + rel*512 - 1` inside `int64_t`, which is the Core expression's own
type.  The cell's C leg uses `int64_t` for that sum exactly as the pin does.

`nCoinHeight` / the height lane (`tx_verify.cpp:96`), the multi-input
`std::max` fold (identity for one input) and `GetAncestor` are outside this
row.  `CalculateSequenceLocks`' disable-flag `continue` is SCR-129 in
`locktime/C-L-csv-op`.
