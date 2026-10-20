# hash-ops/C-L-hash-compose

SCR-094 (`RIPEMD160∘SHA256; SHA256d`, checked as `HASH160/HASH256`). The cell
is **both-tool green** with SHA256 and RIPEMD160 as opaque externals shared by
both legs. Coverage is `full` for the composition skeleton: both arms, both
directions, an empty and a one-byte preimage, with the 32-byte intermediate
and the 20/32-byte final width in the checked observable. The primitive
algorithms are the same-hash premise, not a claim of this row.

## Source

Pinned Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`:

- `src/script/interpreter.cpp:1032-1056` — hash opcode family.
- `src/script/interpreter.cpp:1049-1050` — `OP_HASH160`:
  `CHash160().Write(vch).Finalize(vchHash);`.
- `src/script/interpreter.cpp:1051-1052` — `OP_HASH256`:
  `CHash256().Write(vch).Finalize(vchHash);`.
- `src/script/interpreter.cpp:1053-1054` — `popstack(stack);
  stack.push_back(vchHash);`.
- `src/hash.h:32-55` — `CHash256::Finalize`: SHA256 into `buf[32]`, then
  reset / write `buf[32]` / SHA256 into the output.
- `src/hash.h:57-78` — `CHash160::Finalize`: SHA256 into `buf[32]`, then
  RIPEMD160 over `buf[32]`.
- `twin/runtime.inc:555-564` — `hash160 = sha256 then ripemd160`;
  `hash256 = sha256 twice`.
- `twin/ops_ir.py` `OP_HASH160` (0xa9), `OP_HASH256` (0xaa).
- `spec/core/Bitcoin/Interpreter/Defs.lean:637-643` — `hashForOp` maps
  HASH160 to `hashHash160` and HASH256 to `hashSha256d`.
- `spec/core/Bitcoin/Interpreter/Hashes.lean` — `hashHash160 =
  hashRipemd160 (hashSha256 data)` and `hashSha256d`.

## Design: memory functions and token chains

Each arm/preimage pair is exported twice:

- `cell_hash160_*` / `cell_hash256_*` — the real memory composition:
  SHA256 writes a 32-byte local intermediate, the second primitive reads
  exactly those 32 bytes, and the result is pushed with width 20 or 32.
  SAW verifies these C/L functions with concrete overrides.
- `cell_hash160_*_chain` / `cell_hash256_*_chain` — the same composition with
  each digest abstracted to a defined 64-bit token returned by an external.
  Alive2 compares these C/L functions.

The abstraction is necessary for the same reason as in
`hash-ops/C-L-hash-widths`: Alive2 treats an external write as unmodelled
memory, so a digest-bearing function returns a poisoned aggregate and a
digest comparison is not a sound way to observe the composition. The token
chain makes the following Alive2-visible and universally quantified over token
values:

1. the first primitive is called with the preimage pointer and length;
2. the second primitive receives exactly the first token;
3. the second call's length argument is the declared `32`;
4. the final pushed width is `20` (HASH160) or `32` (HASH256);
5. the pop/push changes depth from 1 to 1.

SAW then ties the abstraction back to real bytes: the first-stage SHA256
override is keyed to the closed preimage, the second-stage override is keyed
to the concrete 32-byte SHA256 digest, and the expected packed value contains
the concrete composition result. The C token-chain functions are the same
skeleton as the C memory functions with tokens in place of digest arrays; they
are a specification harness, not a replacement for the memory functions, which
are separately SAW-verified.

## Concrete witnesses

Recomputed with Python `hashlib`; the intermediate and final values match
`src/cell.cry`:

```text
preimage "":
  SHA256("")          = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  HASH160("")         = b472a266d0bd89c13706a4132ccfb16f7c3b9fcb
  HASH256("")         = 5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456
preimage "a" (0x61):
  SHA256("a")         = ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb
  HASH160("a")        = 994355199e516ff76c4fa4aab39337b9d84cf12b
  HASH256("a")        = bf5d3affb73efd2ec6c36ad3112dd933efed63c4e1cbffcfa88e2759c144f2d8
```

The SAW overrides assume these primitive outputs; they are witnesses, not
derived results.

## L leg: reviewed transliteration

`twin/runtime.inc:555-564` is copied unchanged into `src/l_leaf.cpp`, and the
`OP_HASH160`/`OP_HASH256` handler bodies are copied from `twin/ops_ir.py`.
`mk_leaf.py` cannot represent the 20/32-byte push (its bounded copy is two
bytes), so the cell carries the bodies with a 32-byte stack and the unrolled
`h_copy` in `src/hash_common.h`. `build/twin_ops.h` is generated and hashed
for provenance but is not the compiled L module.

## Commands

From the repository root:

```sh
bash spec/equiv/cells/hash-ops/C-L-hash-compose/alive2/run.sh
bash spec/equiv/cells/hash-ops/C-L-hash-compose/saw/run.sh
sha256sum -c spec/equiv/cells/hash-ops/C-L-hash-compose/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/hash-ops/C-L-hash-compose/saw/certificate.sha256
```

`build/` is gitignored; the certificates hash the extracted IR, `build.txt`,
`cell.cry`, `cell.saw`, and the results. Each `run.sh` rebuilds before writing
its certificate, so verify after the run.

Tool versions:

```text
alive-tv  Ubuntu LLVM version 20.1.2 (Optimized build)
saw       1.6 (68eed5f release-1.6)
clang++   20.1.2 (Ubuntu 20.1.2-0ubuntu1~24.04.3)
```

## Raw results

`alive2/result.txt` contains four chain comparisons
(`cell_hash160_{empty,a}_chain`, `cell_hash256_{empty,a}_chain`). Each ends
with `1 correct transformations`, `0 incorrect`, `0 failed-to-prove`, and the
file ends with `STATUS=alive2-green`.

`saw/result.txt` contains sixteen proofs: four memory functions per leg and
four chain functions per leg. It ends with
`CELL_HASH_COMPOSE_SAW_GREEN` and `STATUS=saw-green`; the last proof tail is:

```text
Applied override! sha256_mid
Checking proof obligations cell_hash256_a_chain...
Proof succeeded! cell_hash256_a_chain
```

## Mutation sensitivity

Scratch probes under `/tmp/opencode/hashmut`, not part of the committed
evidence:

- **Intermediate length 32 → 20** (`ripemd160_mid(mid, 20)` in the L
  HASH160 chain): Alive2 reports `0 correct, 1 incorrect`.
- **Token dataflow** (`ripemd160_mid(0, 32)` instead of `(mid, 32)`): Alive2
  reports `0 correct, 1 incorrect`.
- **Final width 20 → 32** (`st_push(st, out, 32)` in the L HASH160 chain):
  Alive2 reports `0 correct, 1 incorrect`, source `0xa101` vs target
  `0x10101`.
- **Real memory length 32 → 20** (L `l_hash160`: `ripemd160(s, 20, out)`):
  SAW cannot apply the second-stage override (`No override specification
  applies for ripemd160`, because the recorded override expects the 32-byte
  digest), so the proof does not complete.

These are the exact failure modes the cell is meant to detect: a changed
composition order, a changed intermediate width, or a changed final width.

## Coverage limits (not overclaimed)

- **SCR-094 is `full` for the composition skeleton.** Both named compositions
  (HASH160 and HASH256) are exercised on both legs, for an empty and a one-byte
  preimage. The 32-byte intermediate and both final widths are checked.
- **Refinement is one-directional.** Alive2 is run as `alive-tv C L` (L ⊑ C);
  the reverse run does not verify under Alive2's uninterpreted-external model.
  SAW verifies both legs against the same constants.
- **The primitives are assumed.** SHA256/RIPEMD160 are opaque; the cell does
  not prove the algorithms or that the symbols denote them. This is the
  same-hash premise named in `spec.md` and `README.md` §7.
- **Digest bytes are witnesses.** SAW checks the real memory composition for
  the four recorded closed inputs. Alive2 checks the token dataflow
  universally, not the bytes.
- Only preimages of length 0 and 1 are exercised.
- SHA1 is outside the twin subset; it belongs to SCR-093/SCR-095, not this
  row.
- No Core source patch is used.
