# witness-v0/C-L-p2wpkh-script

The pure half of SCR-136: Core's synthesis of the 25-byte implied P2WPKH
script (interpreter.cpp:1952), proved against the verified Lean byte
construction.

## Design

Core builds:

```
exec_script << OP_DUP << OP_HASH160 << program << OP_EQUALVERIFY << OP_CHECKSIG;
```

For a 20-byte vector, `CScript::operator<<` emits `0x14` (minimal push), so the
executed script is exactly:

```
76 a9 14 <program[0..19]> 88 ac        (25 bytes)
```

The cell exposes the 20 program bytes as three little-endian u64 words and the
32-byte padded buffer as four little-endian u64 words (see `spec.md` for the
bijection argument).  Four functions `cell_p2wpkh_script_w0..w3` each build the
buffer and return one word.  The L leg writes the same bytes suffix-first
(`s[24]`, `s[23]`, ..., `s[0]`) to make the Alive2 comparison semantic; the
Cryptol leg builds the byte list prefix-first with `#`.

## Exact commands

```sh
bash spec/equiv/cells/witness-v0/C-L-p2wpkh-script/alive2/run.sh
bash spec/equiv/cells/witness-v0/C-L-p2wpkh-script/saw/run.sh
sha256sum -c spec/equiv/cells/witness-v0/C-L-p2wpkh-script/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/witness-v0/C-L-p2wpkh-script/saw/certificate.sha256
```

`src/gen_sources.py` is the generator used for the repetitive 20-byte
copy/word-pack code.  It is checked in for auditability but is not run by the
runners.

## Versions

Alive2 v20.0 (`/opt/equiv-tools/alive-tv-v20.0`, LLVM 20.1.2), SAW 1.6
(68eed5f, solver abc), clang 20.1.2.

## Result

- Alive2: four functions, each `Transformation seems to be correct!`; all four
  were reported `(syntactically equal)` after clang normalized the two store
  orders.  `STATUS=alive2-green`.
- SAW: eight `Proof succeeded!` (4 functions x C and L), `STATUS=saw-green`.

## Why scalar words, not memory

Two independent Alive2 v20 limitations forced the encoding:

1. clang emits `nocapture`/`noalias` on the pointer parameters, and Alive2
   rejects them (`Unsupported attribute: nocapture`, `noalias`).
2. A 20-byte symbolic memory input made Alive2 report
   `Out of memory; skipping function.`

The scalar encoding is information-preserving (every byte is observed), so this
is an engineering adaptation, not a weakened claim.  It is documented in the
source comments and in `spec.md`.

## Limits / blockers

- SCR-136 stays **partial**: `ExecuteWitnessScript` (interpreter.cpp:1953) is
  not run, so `HASH160(pubkey) == program` and `CHECKSIG` are not proved.
- No stack/witness state, no EvalScript, no crypto (same-crypto premise,
  `spec/equiv/README.md` §7).
- The C source is a slice, not the whole `VerifyWitnessProgram`.
