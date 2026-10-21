# e4-witness/C-L-w32-p2wpkh-build

Bounded, symbolic proof of the **P2WPKH implied-script reconstruction** at
`interpreter.cpp:1952`.  For every 20-byte witness program, the C byte
expansion and the Lean byte list produce the same 25 script bytes.

## Seam and citations

Core (`interpreter.cpp:1952`):

```cpp
exec_script << OP_DUP << OP_HASH160 << program << OP_EQUALVERIFY << OP_CHECKSIG;
```

Byte emissions:

- `script.h:470-476` — `operator<<(opcodetype)`: one byte per opcode, so
  `OP_DUP=0x76`, `OP_HASH160=0xa9`, `OP_EQUALVERIFY=0x88`,
  `OP_CHECKSIG=0xac`;
- `script.h:484-488` — `operator<<(span)`: `AppendDataSize(size)` then
  `AppendData`;
- `script.h:408-411` — `size < OP_PUSHDATA1` emits the single byte `0x14` for
  a 20-byte program;
- `script.h:428-431` — the 20 program bytes are copied verbatim.

Lean (`Defs.lean:1272-1274`):

```lean
let exec : ByteArray :=
  List.toByteArray [0x76, 0xa9, 0x14] ++ program ++
    List.toByteArray [0x88, 0xac]
```

Both are the 25 bytes `76 a9 14 <program> 88 ac`.

## Proof shape

The 25 bytes are carried as four little-endian u64 words (`p0`,`p1`,`p2` in;
`w0`..`w3` out), four scalar witnesses.  Each is proved in both directions by
Alive2 and by SAW against an independent Cryptol reconstruction from the Lean
byte list.  The programme space is the full 2^160: `p2` bits 32..63 do not
reach any output byte on either leg, and the Cryptol spec ignores them
identically.

## What is not proved

- The second half of SCR-136: running the constructed script through
  `ExecuteWitnessScript` (EvalScript loop, HASH160/RIPEMD160, ECDSA CHECKSIG,
  cleanstack).  No script execution is modelled.
- The arity guard (proved in `C-L-w32-witness-v0-error-total`) and everything
  after the call.
- No crypto internals; no hash claim.

## Exact commands

```sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-build/alive2/run.sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-build/saw/run.sh
```

## Raw results (2026-10-20)

Alive2: four function pairs, each

```
Transformation seems to be correct!
These functions seem to be equivalent!
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
```

(`cell_p2wpkh_w3` is reported as syntactically equal — the last word is the
constant `0xac` — which is expected and still checked.)

SAW: eight `Proof succeeded!` lines (four functions × C and L),
`STATUS=saw-green`.

## Negative control (not committed)

A copy of the L leg with the PUSHDATA prefix changed from `0x14` to `0x13`
was built in `/tmp/opencode/w32-probe`.  `alive-tv --bidirectional` reported
`Transformation doesn't verify!`, `ERROR: Value mismatch`, source
`0x14a976` vs target `0x13a976`, i.e. exactly byte 2.  The signed cell is not
vacuous.

## Note on word packing

`w0..w3` are a marshalling bijection, not engine semantics; the same packing
is used in `cells/_tools/e4w32/l_cells.cpp` and in `saw/spec.cry`.  No claim
is made about `CScript`'s container representation beyond the emitted bytes.
