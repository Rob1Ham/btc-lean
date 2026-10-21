# tapscript/C-L-tapleaf-taggedhash — notes

## Claim shape

The row SCR-146 names `TaggedHash("TapLeaf", leaf_ver, CompactSize, script)`.
The cell separates the two halves of that phrase:

1. **Tag derivation and input encoding — proved.**  One named opaque oracle
   `H`; `T := H("TapLeaf")`; the bytes handed to the final hash are
   `T || T || serU8(v & 0xfe) || CS(|s|) || s`.  The tag string, the 64-byte
   duplicated prefix, the mask, the CompactSize bytes and the field offsets
   are all explicit and universally quantified (T is symbolic), so the result
   is parametric in `H` and holds for the real SHA256 tag hash.
2. **SHA256 internals — not proved.**  No compression/padding/length-loop
   model, no streamed-vs-one-shot lemma, no digest value.  These are recorded
   as the single named residual premise, not hidden in an opaque
   `sha256_tagged`.

This is exactly the distinction the seam review asked for.  The cell never
assumes a tagged-hash primitive whose internals contain the tag structure:
`H` is the raw whole-input hash and every byte of its argument is proved.

## Design

Nine functions per leg, each small enough for Alive2 and SAW to discharge
exactly:

| function | observable |
|---|---|
| `cell_tag_byte(i)` | byte i of the tag string plus an in-range bit |
| `cell_prefix_byte(i,t0..t3)` | byte i of the 64-byte prefix; `i` and `i+32` read the same T byte |
| `cell_leaf_mask(c)` | `c & 0xfe` (hashed version) and `c & 1` (parity) |
| `cell_cs_size(n)` | 1/3/5/9, total over all u64 |
| `cell_cs_byte(n,j)` | exact encoding byte j with in-range bit, total |
| `cell_field_kind(i,len)` | field code at any offset, total over all u64 lengths |
| `cell_field_index(i,len)` | exact index within the field, total |
| `cell_preimage_byte(i,...)` | exact composed byte + range, scripts 0..4 B |
| `cell_preimage_len(len)` | exact preimage length, scripts 0..4 B |

Why a byte-at function rather than packed words?  A preimage is 64 + 10 + len
bytes, far more than one 64-bit word.  Quantifying over the *offset* i with a
symbolic 64-bit index lets one small function pin **every** byte position and
the exact end of the string, instead of a fixed-size packing that could hide
a field.  The field-map pair then extends placement to every 64-bit script
length without needing the (unbounded) script content.

Why is T an input and not a call?  The oracle must be *opaque* and *shared*.
Passing the same four words to both legs is the faithful model of Lean's
`sha256 tag` term occurring twice as one value, and of Core writing one
`taghash` twice.  An actual external call is not usable evidence here (see
tool notes below).  Quantifying over T is stronger than any particular hash:
it proves the structure for every possible 32-byte tag hash.

## Tool notes (found while building this cell)

These are recorded because they affect evidence quality, and they are why the
sources look the way they do.

1. **Alive2 does not treat an undefined external oracle call as an
   uninterpreted function.**  A probe with `extern "C" void H(...)` produced
   `0 correct transformations / 0 incorrect / 0 errors` — neither a proof nor
   a counterexample.  A cell that relied on it would be silently vacuous, so
   the oracle value is a symbolic input instead.  (This is the same
   vacuity class flagged in `findings/wave64/52-tool-nondeterminism/`.)
2. **Constant globals / jump tables confuse the comparison.**  A
   `static const uint8_t tag[7]` produced an Alive2 value mismatch because the
   target's optimizer-generated `switch.table` global had a different size
   (14 vs 10 bytes), and the source constant load was not the initializer.
   The tag bytes are now inline literals and the legs are built with
   `-fno-jump-tables`, so the comparison contains no global tables.
3. **Speculative `nuw` subtraction / `nneg` extension is poison to SAW.**
   Clang hoists e.g. `j - cs` and `len + 66` out of the guarding branch and
   marks them `nuw`, so a symbolic value that takes the other branch still
   "creates poison" and SAW reports undefined behavior (e.g. `i = 65,
   len = 0`, or `len = 18446744073709551557`).  Offsets and lengths are formed
   with `sub_u64`/`add_u64` (via `__builtin_*_overflow`) so the arithmetic is
   defined for every input; no semantic branch condition changed.
4. **Alive2 budget.**  The runner uses
   `alive-tv --bidirectional --always-verify --smt-to=120000`.  The default
   10 s budget timed out on `cell_field_index` once (a replay of the same
   query then finished in ~2.4 s, so this is budget, not content); 120 s and
   `--always-verify` remove both the timeout and the "syntactically equal,
   skipped" vacuity class.
5. **SAW solver path.**  The runner prepends `/opt/equiv-tools/saw-1.6/bin`
   to `PATH`; otherwise `abc` is not found (`posix_spawnp: does not exist`).

Helper calls are `always_inline`, so the extracted modules contain no calls
(Alive2's interprocedural handling is the weak spot exercised in note 1).

## Versions

- clang: Ubuntu clang 20.1.2 (0ubuntu1~24.04.3)
- Alive2: v20.0, Ubuntu LLVM 20.1.2, `--bidirectional --always-verify
  --smt-to=120000`
- SAW: 1.6 (68eed5f release-1.6), solver `abc`
- Cryptol spec: `build/cell.cry`; proof script: `build/cell.saw`

## Raw result tails

Alive2 (`alive2/result.txt`), one comparison per function:

```
Transformation seems to be correct!
These functions seem to be equivalent!
  Summary:
    1 correct transformations
    0 incorrect transformations
    0 failed-to-prove transformations
    0 Alive2 errors
...                                             (8 more functions)
STATUS=alive2-green
```

SAW (`saw/result.txt`), both legs against `build/cell.cry`:

```
Proof succeeded! cell_tag_byte
Proof succeeded! cell_tag_byte
Proof succeeded! cell_prefix_byte
Proof succeeded! cell_prefix_byte
...                                             (16 more proofs)
Proof succeeded! cell_preimage_len
Proof succeeded! cell_preimage_len
CELL_TAPLEAF_TAGGEDHASH_SAW_GREEN
STATUS=saw-green
```

## Published-vector corroboration

`src/vector_result.txt` records the run of `src/vector_check.py`: four leaf
hashes from Core's `src/test/data/bip341_wallet_vectors.json` at cce32b168
reproduce exactly from the specified preimage with Python's SHA-256, including
leaf version `0xfa`, both control parities, and four negative controls that
must (and do) differ.  `VECTOR_CHECK=PASS`.

This is corroboration, not proof: it uses a real SHA-256 as an external
oracle and is not covered by the Alive2/SAW claims.

## Honesty notes

- The tag hash value used in the vector check is
  `sha256("TapLeaf") = aeea8fdc4208983105734b58081d1e2638d35f1cb54008d4d357ca03be78e9ee`.
  The cell itself never needs this value; it quantifies over all T.
- `control[0] & 1` is the output-key parity (interpreter.cpp:1924).  The cell
  proves it is *separated* from the hashed version byte, not that the
  commitment equation holds (SCR-147).
- `cell_preimage_byte`/`cell_preimage_len` guard `len > 4`.  That bound is a
  harness limit for script *content*; the field map and CompactSize functions
  are total over all 64-bit lengths, so no boundary case is dropped.
- The ledger row stays `unjudged-seam`.  The exact missing premise is the
  hash identity and its streaming semantics, stated in `spec.md`; a concrete
  digest is not proved and is not claimed.
- No Core patch is used.  T is not read from a patched source.
