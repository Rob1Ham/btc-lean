# tapscript/C-L-taproot-scriptpath-dispatch — notes

## Source excerpts (pin `cce32b168`)

`src/script/interpreter.cpp:1980-1982`:

```cpp
            if (control.size() < TAPROOT_CONTROL_BASE_SIZE || control.size() > TAPROOT_CONTROL_MAX_SIZE || ((control.size() - TAPROOT_CONTROL_BASE_SIZE) % TAPROOT_CONTROL_NODE_SIZE) != 0) {
                return set_error(serror, SCRIPT_ERR_TAPROOT_WRONG_CONTROL_SIZE);
            }
```

`src/script/interpreter.cpp:1988-1998`:

```cpp
            if ((control[0] & TAPROOT_LEAF_MASK) == TAPROOT_LEAF_TAPSCRIPT) {
                // Tapscript (leaf version 0xc0)
                exec_script = CScript(script.begin(), script.end());
                execdata.m_validation_weight_left = ::GetSerializeSize(witness.stack) + VALIDATION_WEIGHT_OFFSET;
                execdata.m_validation_weight_left_init = true;
                return ExecuteWitnessScript(stack, exec_script, flags, SigVersion::TAPSCRIPT, checker, execdata, serror);
            }
            if (flags & SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION) {
                return set_error(serror, SCRIPT_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION);
            }
            return set_success(serror);
```

`src/script/interpreter.cpp:2000-2008`:

```cpp
    } else if (!is_p2sh && CScript::IsPayToAnchor(witversion, program)) {
        return true;
    } else {
        if (flags & SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM) {
            return set_error(serror, SCRIPT_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM);
        }
        // Other version/size/p2sh combinations return true for future softfork compatibility
        return true;
    }
```

`src/script/script.cpp:216-222`:

```cpp
bool CScript::IsPayToAnchor(int version, const std::vector<unsigned char>& program)
{
    return version == 1 &&
        program.size() == 2 &&
        program[0] == 0x4e &&
        program[1] == 0x73;
}
```

`src/script/interpreter.h:242-247`:

```cpp
inline constexpr uint8_t TAPROOT_LEAF_MASK = 0xfe;
inline constexpr uint8_t TAPROOT_LEAF_TAPSCRIPT = 0xc0;
inline constexpr size_t TAPROOT_CONTROL_BASE_SIZE = 33;
inline constexpr size_t TAPROOT_CONTROL_NODE_SIZE = 32;
inline constexpr size_t TAPROOT_CONTROL_MAX_NODE_COUNT = 128;
inline constexpr size_t TAPROOT_CONTROL_MAX_SIZE = TAPROOT_CONTROL_BASE_SIZE + TAPROOT_CONTROL_NODE_SIZE * TAPROOT_CONTROL_MAX_NODE_COUNT;
```

## Lean anchors

- `Program.lean:490-499` `controlBlockSizeOk`: `33 <= size`, `size <= 4129`,
  `(size-33) % 32 == 0`.
- `LeafVersion.lean:36-40` `isTapscriptLeaf` via `leafVersionOf`
  (`Program.lean:554-555`, `control[0] & 0xfe`).
- `LeafVersion.lean:62-70` `verifyTaprootLeafDispatch`: 0xc0 -> tapscript,
  else policy 35, else `.ok`.
- `Defs.lean:523-525` `isPayToAnchor`.
- `Defs.lean:1319-1321` upgradable tail.
- `Defs.lean:1796-1811` `verifyWitnessProgram_other_pass`.

## Design

- `cell_control_size` is a pure total predicate over `size`. The C
  short-circuit and the Lean `∨` are both encoded; the underflow case
  `size < 33` is rejected by the first disjunct before the modulo matters.
- `cell_leaf_version` masks `control0` to a byte and then with `0xfe`, so
  0xc0 and 0xc1 both dispatch and every other masked value does not.
- `cell_tail` covers the post-taproot tail. v0 and native v1-32 are delegated
  markers because they are decided earlier; the function is therefore a
  faithful model of the branch it claims, not of the whole dispatch.
- The P2A predicate is exact: non-P2SH, version 1, two program bytes 0x4e and
  0x73. Because the P2A arm precedes the policy gate, the cell proves P2A
  success even with `DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM` set.

## Commands and versions

- clang: Ubuntu clang 20.1.2 (0ubuntu1~24.04.3)
- Alive2: Ubuntu LLVM version 20.1.2 (`/usr/local/bin/alive-tv`, v20.0)
- SAW: 1.6 (68eed5f release-1.6), solver `abc`
- IR: `clang++-20 -O1 -S -emit-llvm`; `llvm-extract --recursive`.

```sh
bash spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/saw/run.sh
```

## Raw result tails

Alive2 (`alive2/result.txt`):

```
Transformation seems to be correct!            (cell_control_size)
Transformation seems to be correct! (syntactically equal)  (cell_leaf_version)
Transformation seems to be correct!            (cell_tail)
Summary (per function):
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

SAW (`saw/result.txt`):

```
Proof succeeded! cell_control_size
Proof succeeded! cell_control_size
Proof succeeded! cell_leaf_version
Proof succeeded! cell_leaf_version
Proof succeeded! cell_tail
Proof succeeded! cell_tail
CELL_tapscript_scriptpath_dispatch_SAW_GREEN
STATUS=saw-green (6/6 proofs)
```

## Honesty notes

- The tapleaf hash and commitment/parity check are **preconditions**: the cell
  starts after a successful `VerifyTaprootCommitment`. SCR-146/147 are not
  claimed here.
- SCR-148's execution half is SCR-153/155 and is not claimed; the proved claim
  is the selection of the tapscript lane for exactly `0xc0`/`0xc1`.
- SCR-149's row summary names `DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM`; the
  pinned branch uses `DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` (error 35). The
  cell proves the pin and states the discrepancy.
- `cell_tail` uses a harness domain guard for `version > 16`; the engine's
  `IsWitnessProgram` cannot produce such a version.
