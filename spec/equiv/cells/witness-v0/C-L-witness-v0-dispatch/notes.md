# witness-v0/C-L-witness-v0-dispatch

Total v0 dispatch predicate for `VerifyWitnessProgram` (pin `cce32b168`).
This cell supersedes the E4 cell of the same name: it adds the P2WSH
SHA256-mismatch arm and removes E4's abstract "success" in favour of an explicit
continuation sentinel.

## Design

`cell_v0_dispatch(program_len, witness_n, hash_match)` is symbolic in all three
u64 arguments and returns `(result, error_ordinal)` packed as
`result | ordinal << 2`:

| program_len | witness_n | hash_match | result |
|---:|---:|---:|---|
| 32 | 0 | any | (0, 39) WITNESS_PROGRAM_WITNESS_EMPTY |
| 32 | > 0 | 0 | (0, 40) WITNESS_PROGRAM_MISMATCH |
| 32 | > 0 | 1 | (2, 0) continuation sentinel |
| 20 | != 2 | any | (0, 40) WITNESS_PROGRAM_MISMATCH |
| 20 | 2 | any | (2, 0) continuation sentinel |
| other | any | any | (0, 38) WITNESS_PROGRAM_WRONG_LENGTH |

Two declared abstractions:

- `hash_match` stands for the 32-byte compare at interpreter.cpp:1943-1945.
  SHA256 is not modelled; SCR-133 is covered separately (partially) by
  `C-L-p2wsh-hashmatch`.
- `2` is a continuation sentinel for both `ExecuteWitnessScript` call sites
  (interpreter.cpp:1946 and :1953).  It is never `1`, so no execution success is
  asserted.  The actual post-state is covered by `C-L-witness-v0-cleanstack`.

The L leg is a reviewed transliteration of the verified Lean v0 arm
(`spec/core/Bitcoin/Interpreter/Defs.lean:1259-1279`).  The C leg is a
line-cited excerpt of interpreter.cpp:1933-1956.  The ordering (empty before
hash, arity before execution, length last) is identical in both.

## Exact commands

From the repository root:

```sh
bash spec/equiv/cells/witness-v0/C-L-witness-v0-dispatch/alive2/run.sh
bash spec/equiv/cells/witness-v0/C-L-witness-v0-dispatch/saw/run.sh
sha256sum -c spec/equiv/cells/witness-v0/C-L-witness-v0-dispatch/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/witness-v0/C-L-witness-v0-dispatch/saw/certificate.sha256
```

The runners call `../_tools/build.sh`, which compiles both sources with
`/usr/bin/clang++-20 -std=c++17 -O1`, extracts each function in `src/fns.txt`
with `llvm-extract`, and writes the compared IR to `ir/`.  `ir/` is committed
and hashed by the certificates; `build/` is gitignored.

## Versions

- Alive2: `/opt/equiv-tools/alive-tv-v20.0` (`alive-tv --version` reports the
  LLVM build it links: Ubuntu LLVM 20.1.2).
- SAW: `/opt/equiv-tools/saw-1.6/bin/saw`, version 1.6 (68eed5f), solver abc.
- clang/LLVM: Ubuntu clang 20.1.2 (0ubuntu1~24.04.3), LLVM 20.

## Result

- `alive2/result.txt`: `1 correct transformations`, `0 incorrect`,
  `STATUS=alive2-green`.
- `saw/result.txt`: one `Proof succeeded!` for each of the C and L modules,
  `STATUS=saw-green`.

## Limits / blockers

- SHA256(witnessScript) is an input.  No hash implementation or collision
  resistance is claimed (same-hash premise, `spec/equiv/README.md` §7).
- `ExecuteWitnessScript` is not run; the sentinel is not a success verdict.
  EvalScript, the opcode loop, HASH160/CHECKSIG and item-size limits are out of
  scope.
- Alive2 cannot ingest the whole `VerifyWitnessProgram` (indirect calls,
  `std::span`, `CScript` memory).  The slice is therefore at predicate level.
- `spec/equiv/docs/DECISION-lax-ecdsa.md` is referenced by the brief but is not
  present in this tree; `spec/equiv/README.md` §7 is the in-tree same-crypto
  statement and is what this cell cites.
