# witness-v0/C-L-bip143-encoding-cs

SCR-140 extension: the BIP143 segwit-v0 preimage field order **including the
8-byte amount**, now with the integer fields actually encoded and with
CompactSize ordering across its width boundaries.

Companion cells (not modified):

- `witness-v0/C-L-bip143-layout` — width/offset table for every
  `0 <= script_len <= 75`, payloads abstract.
- `witness-v0/C-L-bip143-preimage-order` — byte-level assembly for
  `script_len` in {0, 1, 75}, payloads abstract, one-byte CompactSize.
- `witness-v0/C-L-bip143-hashoutputs-single-oor` — which value fills the
  hashOutputs slot (SCR-141), orthogonal here.

## Why this cell

Both sibling cells stop at opaque field payloads and at one-byte CompactSize.
That leaves three SCR-140 sub-claims unproved: the little-endian encodings of
version/amount/nSequence/nLockTime/nHashType, the CompactSize width rule
(1/3/5/9 bytes) and the resulting shift of the amount slot for scripts longer
than 252 bytes. This cell closes those without touching the shared tx decode
or SHA256d.

## Functions (9 per leg)

| function | claim |
|---|---|
| `cell_ser_u32le` | 4-byte LE of a u32 (`serU32L`) |
| `cell_ser_u64le` | 8-byte LE of a u64 (`serU64L`/`serAmountL`) |
| `cell_cs_width` | GetSizeOfCompactSize: 1/3/5/9 at 253 / 65536 / 2^32, total over u64 |
| `cell_cs1` | `n<253` → `[n]`, width 1 |
| `cell_cs3` | `253<=n<=65535` → `0xfd || LE16`, width 3 |
| `cell_cs5` | `65536<=n<=2^32-1` → `0xfe || LE32`, width 5 |
| `cell_cs9` | `n>=2^32` → `0xff || LE64`, width 9 |
| `cell_bip143_amount_off` | `105 + L + (cs_width(L)-1)`, amount start, for `L <= 2^32-1` |
| `cell_bip143_preimage_e253` | the 412-byte preimage at script_len 253, integer fields encoded LE |

The preimage function's field map (scriptCode length 253, CompactSize
`fd fd 00`, so offsets after the script move +2 relative to the sibling
cells):

```text
[0,4)      version        4   u32 LE
[4,36)     hashPrevouts   32  opaque
[36,68)    hashSequence   32  opaque
[68,100)   txid           32  opaque
[100,104)  vout           4   opaque
[104,107)  CompactSize    3   fd fd 00
[107,360)  script         253 opaque
[360,368)  amount         8   u64 LE
[368,372)  nSequence      4   u32 LE
[372,404)  hashOutputs    32  opaque
[404,408)  nLockTime      4   u32 LE
[408,412)  nHashType      4   u32 LE
```

## Design

C leg: `interpreter.cpp:1655-1670` order as a running cursor with
`memcpy` of the fixed wire widths; integer fields serialized with unrolled
byte shifts matching `ser_writedata16/32/64` on a little-endian host;
CompactSize branches matching `WriteCompactSize`.

L leg: reviewed transliteration of `serU32L`, `serU64L`, `serAmountL`,
`encCSL` and `bip143MsgL` (`Digest.lean:53-64, 288-302`;
`Interface.lean:487-500`), with **absolute offsets** and byte-lane loops.
Different formulations, so the Alive2 comparison is semantic rather than
syntactic.

## Exact commands

```sh
cd spec/equiv/cells/witness-v0/C-L-bip143-encoding-cs
bash alive2/run.sh
bash saw/run.sh
sha256sum -c alive2/certificate.sha256
sha256sum -c saw/certificate.sha256
```

Alive2 v20.0 (LLVM 20.1.2), clang 20.1.2, SAW 1.6 (`68eed5f`), z3.
Alive2 is run `--bidirectional --src-unroll=8 --tgt-unroll=8` (the L
encoders are byte-lane loops; the unroll factor makes both loops reach a
return). `src/build.sh` is cell-local so the committed IR uses relative
`src/...`/`build/...` paths (`-ffile-prefix-map`), fixing the wave64 F3
checkout-path dependence for this cell. The SAW runner rejects
`Proof failed`, `Error`, `Stack trace` and `Could not find`, and requires the
final marker — the wave64 F4 false-green path is not used.

## Result (real runs)

```text
alive2: 9/9 functions "Transformation seems to be correct!",
        0 incorrect, 0 failed-to-prove, 0 Alive2 errors
        STATUS=alive2-green
saw:    18/18 "Proof succeeded!" (9 functions x C/L), z3
        CELL_BIP143_ENCODING_CS_SAW_GREEN
        STATUS=saw-green
```

Certificates hash `spec.md`, `notes.md`, both runners, both sources,
`fns.txt`, `solver.txt`, `cell.cry`, `cell.saw`, all 18 committed `ir/*.ll`,
the raw `result.txt` of the leg, and the two shared witness-v0 tool files.
`build/` (bc/ll) is not hashed.

## Non-vacuity (out-of-tree mutants)

Full logs in `findings/wave65/17-scr-140/`:

1. **amount misplaced** — L writes amount at 364 (nSequence stays at 368),
   total unchanged. SAW rejects the preimage spec with a byte
   counterexample (`Proof failed`).
2. **CompactSize boundary off by one** — L tests `script_len > 253` instead
   of `>= 253`, so length 253 is classified as width 1. Alive2 rejects
   `cell_cs_width` at n=253 (source 3, target 1); SAW rejects the L cs3
   width spec.

## What remains (SCR-140 stays partial)

- **Sub-hash contents.** `hashPrevouts`/`hashSequence`/`hashOutputs` are
  opaque 32-byte payloads. Proving their contents needs a decoded
  transaction (vin/vout vectors), the three serializers
  (`serOutpointL` fold, `serU32L` sequence fold, `serTxOutL` fold), the
  ACP/SINGLE/NONE selection, and SHA256d. This cell states the fixed
  witness-bytes premise and does not claim the decode.
- **SHA256d.** Not modelled; only the 412-byte input is proved.
- **Arbitrary-length assembly.** Byte-level assembly is proved at L=253
  (this cell) and L in {0,1,75} (sibling). Offsets for every L are proved
  (this cell for L<=2^32-1; sibling for L<=75); a symbolic-length memcpy
  proof is not attempted.
- **Amount range semantics** (negative CAmount, SWT-055) is out of scope;
  only the 8-byte LE wire image is claimed.
