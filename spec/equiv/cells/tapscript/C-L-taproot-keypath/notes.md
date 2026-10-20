# tapscript/C-L-taproot-keypath — notes

## Source excerpts (pin `cce32b168`)

`src/script/interpreter.cpp:1970-1975`:

```cpp
        if (stack.size() == 1) {
            // Key path spending (stack size is 1 after removing optional annex)
            if (!checker.CheckSchnorrSignature(stack.front(), program, SigVersion::TAPROOT, execdata, serror)) {
                return false; // serror is set
            }
            return set_success(serror);
        } else {
```

`src/script/interpreter.h:201-207`:

```cpp
enum class SigVersion
{
    BASE = 0,
    WITNESS_V0 = 1,
    TAPROOT = 2,
    TAPSCRIPT = 3,
};
```

Lean (`spec/core/Bitcoin/Interpreter/Defs.lean:1190-1193, 1298`):

```lean
def schnorrOutcome : Except ExecError Unit → VerifyOutcome
  | .ok () => .ok
  | .error .taprootDataUnavailable => .unjudged
  | .error e => .fail e
...
          schnorrOutcome (checkSchnorrWithContext chk stack[0]! program .taproot ed)
```

## Design

`checker_abi.h` defines the single external seam:

```cpp
extern "C" uint32_t btc_equiv_check_schnorr(uint32_t sig_id, uint32_t key_id,
                                            uint32_t sigversion,
                                            uint32_t key_len);
```

The return packs `ok` in bit 0 and the Core `ScriptError` ordinal in bits 1..6,
so the cell proves an exact pass-through of the checker's error instead of
choosing one. `sig_id`/`program_key_id` are symbolic, which lets Alive2 prove
both legs pass the same item and key.

The L transliteration follows Lean: one item -> `schnorrOutcome
(checkSchnorrWithContext ...)`; more than one -> script path. Lean's
`taprootDataUnavailable` is a model-state outcome from the Crypto seam, not an
engine verdict; it is not reachable in this bounded call-site model, whose
checker result is a concrete (ok, error) pair.

## Commands and versions

- clang: Ubuntu clang 20.1.2 (0ubuntu1~24.04.3)
- Alive2: Ubuntu LLVM version 20.1.2 (`/usr/local/bin/alive-tv`, v20.0)
- SAW: 1.6 (68eed5f release-1.6), solver `abc`
- Alive2 lane: external declaration, `-O1`, IR return-attribute `noundef`
  added to both extracted modules (C uint32_t return cannot be poison).
- SAW lane: shared stub `checker_stub.cpp` linked into both legs, result 1
  (success) and 94 (ok=0, SCHNORR_SIG=47).

```sh
bash spec/equiv/cells/tapscript/C-L-taproot-keypath/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-keypath/saw/run.sh
```

## Raw result tails

Alive2 (`alive2/result.txt`):

```
declare i32 @btc_equiv_check_schnorr(...) noundef
...
tail call i32 @btc_equiv_check_schnorr(... %sig_id, ... %program_key_id, ... 2, ... 32) noundef
...
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
Proof succeeded! cell_keypath
Proof succeeded! cell_keypath
CELL_tapscript_keypath_1_SAW_GREEN
Proof succeeded! cell_keypath
Proof succeeded! cell_keypath
CELL_tapscript_keypath_94_SAW_GREEN
STATUS=saw-green (4/4 proofs)
```

## Honesty notes

- The crypto check is not proved. SCR-144 is promoted only under the
  same-crypto premise P12. No BIP340/libsecp256k1 claim is made.
- `stack_n != 1` is a marker (code 2); the script-path dispatch is proved in
  `C-L-taproot-scriptpath-dispatch`.
- The checker call arguments are symbolic in Alive2, so the cell also shows
  both legs bind the same single item and the same output key. SAW uses
  concrete ids because the shared stub ignores them.
