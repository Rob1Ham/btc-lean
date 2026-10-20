# notes — limits/C-L-script-size

## Design

Both legs are straight-line predicates over `(script_len: u64, sv: u8)`.
The C leg is the Core prologue guard `interpreter.cpp:438-440` with the
sigversion enum and `MAX_SCRIPT_SIZE` constant from `script.h:41`.  The L leg
is the Lean `evalScriptBytes` guard `Defs.lean:1163-1164` (strict `<` on the
constant side), which is the same predicate as the generated twin's
`runtime.inc:594-597` prologue.  There is no per-opcode twin handler for this
limit, so the L side is a reviewed transliteration of the structural code
rather than an `ops_ir.py` handler.

The payload is a state projection, not an input echo: on the admitted branch
it is the low 24 bits of the length the opcode loop would parse.  A divergence
in the length reaching the loop would show up in both the result and the
payload.

## Commands

```sh
bash spec/equiv/cells/limits/C-L-script-size/alive2/run.sh
bash spec/equiv/cells/limits/C-L-script-size/saw/run.sh
sha256sum -c spec/equiv/cells/limits/C-L-script-size/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/limits/C-L-script-size/saw/certificate.sha256
```

## Tool versions

- clang/clang++ 20.1.2 (`/usr/bin/clang++-20`)
- LLVM 20.1.2 (`llvm-extract`, `llvm-dis`)
- Alive2 v20.0 (LLVM 20 build, `/usr/local/bin/alive-tv`)
- SAW 1.6 (`/opt/equiv-tools/saw-1.6/bin/saw`, solver `abc`)

## Limits / non-claims

- The cell is the prologue guard only.  It does not parse or execute the
  script; the row is the guard's predicate and placement.
- "Admitted" is result 1 with `EQUIV_ERR_OK`; it is not a `VerifyScript`
  pass claim.  The `spec.md` postcondition says so explicitly.
- Core's `size_t` is 64-bit at the pin, so the u64 domain is the exact
  `script.size()` width on the pinned build.
- No Core patch, no crypto, no hash claim.

## Blockers

None.  Both tools ingested the extracted modules.
