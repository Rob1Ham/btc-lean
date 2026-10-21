# tapscript/C-L-taproot-activation-gate — notes

## Source excerpts (pin `cce32b168`)

`src/validation.cpp:2249-2288` (taproot-relevant head):

```cpp
script_verify_flags GetBlockScriptFlags(const CBlockIndex& block_index,
                                        const ChainstateManager& chainman)
{
    ...
    // For simplicity, always leave P2SH+WITNESS+TAPROOT on except for the two
    // violating blocks.
    script_verify_flags flags{SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_WITNESS
                              | SCRIPT_VERIFY_TAPROOT};                    // :2261
    const auto it{consensusparams.script_flag_exceptions.find(
                      *Assert(block_index.phashBlock))};                   // :2262
    if (it != consensusparams.script_flag_exceptions.end()) {
        flags = it->second;                                                // :2264
    }
    if (DeploymentActiveAt(block_index, chainman,
                           Consensus::DEPLOYMENT_DERSIG))
        flags |= SCRIPT_VERIFY_DERSIG;                                     // :2268-2270
    ... CLTV, CSV, NULLDUMMY (segwit) ...                                  // :2273-2285
    return flags;
}
```

`src/kernel/chainparams.cpp:115-118`:

```cpp
consensus.script_flag_exceptions.emplace( // BIP16 exception
    uint256{"00000000000002dc756eebf4f49723ed8d30cc28a5f108eb94b1ba88ac4f9c22"},
    SCRIPT_VERIFY_NONE);
consensus.script_flag_exceptions.emplace( // Taproot exception
    uint256{"0000000000000000000f14c35b2d841e986ab5441de8c585d5ffe55ea1e395ad"},
    SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_WITNESS);
```

`src/script/interpreter.cpp:1957-1969`:

```cpp
    } else if (witversion == 1 && program.size() == WITNESS_V1_TAPROOT_SIZE &&
               !is_p2sh) {
        if (!(flags & SCRIPT_VERIFY_TAPROOT)) return set_success(serror);   // :1959
        if (stack.size() == 0) return set_error(serror,
            SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY);                      // :1960
        // annex / key path / script path ...                              // :1961+
```

Lean (`spec/core/Bitcoin/Activation/Flags.lean:145-157`):

```lean
def getBlockScriptFlagsP (P : ChainParams) (hash : BlockHash)
    (height : UInt32) : ScriptFlags :=
  let base :=
    match P.scriptFlagExceptions hash with
    | some exf => exf
    | none => { p2sh := true, witness := true, taproot := true }
  { base with
      dersig    := base.dersig    || buriedActive P P.bip66Height  height
      ... }
```

Lean (`spec/core/Bitcoin/Interpreter/Defs.lean:1280-1285`):

```lean
  else if version = 1 ∧ program.size = 32 ∧ !isP2SH then
    -- BIP341 taproot
    if !flags.taproot then .ok
    else match witness with
      | [] => .fail .witnessProgramWitnessEmpty
      | _ => ...
```

## Design

The cell is the composition `gate(shape, taproot_bit(GetBlockScriptFlags))`.
The C leg keeps the pinned expression order: base, exception replacement,
four buried ORs, then the interpreter arm.  The L leg restates the Lean
record/Option definitions and the Lean branch order.  The two differ in
representation (bitmask + limb equality vs Bool record + Option), which is
what the Alive2 compare closes.

`taproot_on` is an explicit observable (bit 8) so SAW checks the flag
selector, not only the gate branch.  `height` is an explicit uint32 input
driven through the buried ORs; the proof shows it never reaches the TAPROOT
bit.  The Cryptol spec still binds the `height` argument (SAW prints an
"Unused name: height" warning): that warning is the machine-checked statement
that the pinned flag assembly is height-inert for TAPROOT.

## Concrete corners (behavior/result.txt; witness only)

```
taproot exception hash, its height        h=692261 -> 0x001 (result=1 err=0 taproot=0)
taproot exception hash, activation height h=709632 -> 0x001 (result=1 err=0 taproot=0)
last pre-activation height 709631, empty  h=709631 -> 0x19c (result=0 err=39 taproot=1)
activation height 709632, empty           h=709632 -> 0x19c (result=0 err=39 taproot=1)
activation height 709632, non-empty       h=709632 -> 0x102 (result=2 err=0 taproot=1)
near-miss hash, last limb flipped         h=709632 -> 0x19c (fail-closed lookup)
v1 31-byte program                        h=709632 -> 0x103 (outside the arm)
v1 32-byte P2SH-wrapped                   h=709632 -> 0x103 (outside the arm)
v0 32-byte program                        h=709632 -> 0x103 (outside the arm)
```

The 709631/709632 pair is byte-identical: at the pin the activation height
is not a gate.

## Commands and versions

- clang: Ubuntu clang 20.1.2 (0ubuntu1~24.04.3)
- Alive2: Ubuntu LLVM version 20.1.2 (`/usr/local/bin/alive-tv`)
- SAW: 1.6 (68eed5f release-1.6), solver `abc`
- IR: `clang++-20 -O1 -S -emit-llvm`; `llvm-extract --func=cell_taproot_activation
  --recursive`.

```sh
bash spec/equiv/cells/tapscript/C-L-taproot-activation-gate/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-activation-gate/saw/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-activation-gate/behavior/run.sh
```

## Raw result tails

Alive2 (`alive2/result.txt`):

```
Transformation seems to be correct!
These functions seem to be equivalent!
Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

SAW (`saw/result.txt`):

```
Warning: ... Unused name: height
Proof succeeded! cell_taproot_activation
Proof succeeded! cell_taproot_activation
CELL_taproot_activation_SAW_GREEN
STATUS=saw-green (2/2 proofs)
```

## Honesty notes

- The cell does **not** prove a 709632 activation gate.  It proves the
  pinned tree has none: TAPROOT is base-on at every height except the two
  hash-keyed exception blocks.  The historical BIP9 gate is a Lean record
  (`Activation/Taproot.lean`, TPR-075/078) with no C counterpart at the pin.
- The row's "not anyone-can-spend" half is evidenced by error 39 for empty
  witnesses and by the continuation marker for non-empty witnesses; the
  final verdict is the sibling key-path/script-path cells' subject.
- The exception lookup is fail-closed: a hash matching three of four limbs is
  not an exception (behavior row 8).  The mainnet map has exactly two entries.
- The BIP16 exception also clears TAPROOT, so it is in the silent-success set
  too; the row names only the taproot exception because that is the one that
  violated the rules taproot introduced.
- `GAP-CONTEXT.md` records the exact missing contract context for the
  remaining height clause.  No shared cell, contract, database or ledger file
  is edited by this cell.
