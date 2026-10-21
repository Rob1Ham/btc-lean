# Wave 65 — task `19-scr-146`

**Branch:** `wave65/19-scr-146`
**Base:** `76dbfe5e42f8a337e41a7308158b0de078afafd9` (worktree clean at start)
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Cell:** `spec/equiv/cells/tapscript/C-L-tapleaf-taggedhash`
**Result:** partial — both-green on the complete **tagged-hash input
construction** against a named opaque oracle; SHA256 internals are not proved.
Alive2 9/9 bidirectional comparisons green; SAW 18/18 obligations green.

## Scope

SCR-146 is the TapLeaf tagged hash:

```text
T        := H("TapLeaf")                              one 32-byte tag hash
pre(v,s)  = T || T || serU8(v & 0xfe) || CS(|s|) || s
digest    = H(pre(v,s))                               H = SHA256 (not proved)
```

This cell proves how `pre(v,s)` is built, **parametric in `H`**, and states
the missing hash identity as an explicit premise. `H` is a named opaque
whole-input hash; `T` is passed symbolically as four little-endian `u64`
words to both legs. The proofs therefore hold for *every* 32-byte `T`, hence
for the real `SHA256("TapLeaf")`.

The separation the cell makes explicit:

- **Tag derivation and input encoding — proved.** The tag string is exactly
  the seven ASCII bytes `TapLeaf`; one hash value is written twice to form a
  64-byte prefix (`byte i == byte i+32`); the masked version byte, the exact
  CompactSize bytes and the script bytes follow in that order. These are
  properties of `hash.cpp:85-91`, `interpreter.cpp:1882-1884` and
  `serialize.h:301-323`; they do not depend on SHA256's internals.
- **SHA256 internals — not proved.** Compression, padding, the message-length
  loop, streamed `CSHA256` versus one-shot equivalence, and any concrete
  32-byte digest. These are the residual, not hidden behind an opaque
  `sha256_tagged` that would silently absorb the tag layout.

No ledger, rules, pin, contract, existing cell or `spec/proofs/**` file was
edited. SCR-146 remains `unjudged-seam`; this report narrows its gap.

## Proved functions

Nine functions per leg, all checked against one independent Cryptol statement
written from the Core/Lean equations (not from either leg). Alive2 runs
bidirectional; SAW verifies the C leg and the L leg separately.

| Function | Statement (all inputs in the cell domain) | Alive2 | SAW |
|---|---|---|---|
| `cell_tag_byte` | byte `i` of the tag plus in-range bit; exactly `54 61 70 4c 65 61 66`, nothing else | green | green ×2 |
| `cell_prefix_byte` | byte `i` of the 64-byte prefix; `i` and `i+32` read the same T byte | green | green ×2 |
| `cell_leaf_mask` | hashed version `c&0xfe`, parity `c&1`, disjoint and exhaustive over `b` | green | green ×2 |
| `cell_cs_size` | `1/3/5/9` for `n < 0xfd / <= 0xffff / <= 0xffffffff / else`, total over u64 | green | green ×2 |
| `cell_cs_byte` | exact CompactSize byte `j` (marker then LE payload) at every boundary, total | green | green ×2 |
| `cell_field_kind` | field at any preimage offset: T-copy-0, T-copy-1, version, CompactSize, script, past-end; total over u64 lengths | green | green ×2 |
| `cell_field_index` | exact index inside that field, total over u64 lengths | green | green ×2 |
| `cell_preimage_byte` | exact composed byte at every u64 offset + range bit, scripts 0..4 B | green | green ×2 |
| `cell_preimage_len` | `64 + 1 + cs(len) + len` for scripts 0..4 B, sentinel above | green | green ×2 |

Field order is `T, T, version, CompactSize, script`. `control0` enters only
through `& 0xfe` at offset 64, so `control0` and `control0^1` (parity bit)
produce byte-identical preimages at every offset; congruence for any
deterministic `H` then gives equal digests. This is the parity separation
`interpreter.cpp:1924` relies on, not the EC commitment (SCR-147).

## Evidence and certificate verification

Tracked-input certificates (generated `build/` files are **not** listed):

```sh
C=spec/equiv/cells/tapscript/C-L-tapleaf-taggedhash
sha256sum -c "$C/alive2/certificate.sha256"
sha256sum -c "$C/saw/certificate.sha256"
```

Certificate digests:

```
alive2/certificate.sha256  0daea770e5a1cafc418c747553bc844f7d41e91e342c827a1c644750e11848c3
saw/certificate.sha256     7e28af8a3eca67357702ef13f1207bb7c72592529c86cbc4cb6390ecbc30ce42
spec.md                    6bcdf3cd1df17b60d351d3321257ca93a29921d3656d88704b921941bf1f8419
```

Raw result digests:

```
alive2/result.txt          aed4d089e4bb1ad85a2335e3115e799b998f8f4b3e058b2b4ad00ed010f30195
saw/result.txt             e6421f6ae214aaba1f99c88ed80e2c01eb4711042f16b2c738d515cbb17eca59
src/vector_result.txt      9f447cef397dd3d3176041e0a828c2a1718a0663b787b7b3d3c4b83c3cde4512
```

Status lines:

```
STATUS=alive2-green
CELL_TAPLEAF_TAGGEDHASH_SAW_GREEN
STATUS=saw-green
```

## Exact commands

```sh
bash spec/equiv/cells/tapscript/C-L-tapleaf-taggedhash/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-tapleaf-taggedhash/saw/run.sh
sha256sum -c spec/equiv/cells/tapscript/C-L-tapleaf-taggedhash/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-tapleaf-taggedhash/saw/certificate.sha256
python3 spec/equiv/cells/tapscript/C-L-tapleaf-taggedhash/src/vector_check.py
```

`alive/run.sh` invokes
`alive-tv --bidirectional --always-verify --smt-to=120000`; `saw/run.sh`
prepends `/opt/equiv-tools/saw-1.6/bin` to `PATH` so `abc` resolves. Both
runners build from tracked sources with Ubuntu clang 20.1.2 and record the
raw logs. The C leg is a line-cited Core slice of the stream fed to
`CSHA256`; the L leg is a reviewed transliteration of `Rules.lean`'s
`tapLeafHash` and `TaggedHash.lean`'s `taggedHash`, assembled arithmetically
rather than by memory stores, so the Alive2 comparison is semantic.

## Published-vector corroboration (not proof)

`src/vector_check.py` recomputes four leaf hashes from Core's
`src/test/data/bip341_wallet_vectors.json` at `cce32b168` using the preimage
construction above and Python's SHA-256. It covers a `0xfa` leaf version and
both control parities, plus four negative controls (single prefix,
NUL-terminated tag, version-before-prefix, unmasked control). All pass
(`VECTOR_CHECK=PASS`). The reference tag hash used only there is
`sha256("TapLeaf") = aeea8fdc4208983105734b58081d1e2638d35f1cb54008d4d357ca03be78e9ee`.

This is corroboration, not proof: it uses a real SHA-256 as an external
oracle, is not tracked by either tool certificate, and does not constrain the
cell's symbolic `T`.

## Exact residual

The missing premise, stated for both legs:

1. `H = SHA256_FIPS180_4` on both the C leg (Core's `CSHA256`) and the L leg
   (Lean's executable SHA-256). This covers compression, padding, the
   64-byte-block loop and the final 32-byte value.
2. `CSHA256::Write || CSHA256::Write || CSHA256::Write || CSHA256::Finalize`
   over one context equals one-shot SHA256 over the concatenated byte stream
   (streamed/one-shot equivalence, one `Finalize`).
3. Consequently a concrete digest for a concrete script/version pair. The
   cell never computes one and never claims one.

Concretely, what remains for SCR-146 to become fully green is a proved
same-hash link from Core's `HashWriter`/`CSHA256` to the Lean
`Crypto/Seam/Hash.lean` `sha256` (and `taggedHash_unfold` in
`Crypto/Taproot/Program.lean`), plus the streamed-vs-one-shot lemma. None of
those are tag-derivation facts; they are SHA256 internals.

Also outside this cell: script-content exactness is bounded to 0..4 bytes in
`cell_preimage_byte`/`cell_preimage_len`. Placement, addressing and length are
total over all 64-bit lengths via the field-map functions, so no boundary
case is dropped, but a concrete long-script byte equality is not enumerated.

## Tool notes / limits

Recorded because they affect evidence quality:

1. Alive2 does not model an undefined external oracle call as an
   uninterpreted function: a probe produced `0 correct / 0 incorrect /
   0 errors`, i.e. vacuous output. The cell therefore passes `T` as symbolic
   input instead of calling `H`.
2. Constant globals/jump tables confused the comparison (optimizer-generated
   `switch.table` size mismatch). Tag bytes are inline literals and both legs
   build with `-fno-jump-tables`.
3. Ungated speculative `nuw` subtraction / `nneg` extension is poison for SAW.
   `sub_u64`/`add_u64` via `__builtin_*_overflow` keep arithmetic defined for
   every input; no semantic branch condition changed.
4. The default 10 s SMT budget timed out once on `cell_field_index`; the
   runner uses 120 s with `--always-verify`.
5. `abc` is not on `PATH` by default; the SAW runner adds the SAW 1.6 `bin`
   directory.

## Disposition

- **Row:** SCR-146 remains `unjudged-seam` (ledger unchanged).
- **Cell:** `partial` by construction; it must not be cited as a full TapLeaf
  proof.
- **Finding:** none filed. Both tools are green on the stated scope; the gap
  is a named cryptographic premise, not a tool failure or divergence.
- **Mutants:** proposed but not executed here (single-T duplication broken,
  CompactSize payload/marker order, three-bit mask). Wave 64's layout cell
  records the mask/order mutants; the prefix-duplication and tag-string
  mutants are specific to this cell.
