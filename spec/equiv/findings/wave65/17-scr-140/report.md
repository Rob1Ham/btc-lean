# wave65/17 — SCR-140 BIP143 field order + amount: encoding/CompactSize cell

Scope: advance `SCR-140` ("field order per BIP143; amount included",
`interpreter.cpp:1633-1670@cce32b168`) beyond the two existing partial cells
without editing any shared file, existing cell, ledger, results, docs, pins,
proofs, or contract. Everything below is additive.

- Base commit: `76dbfe5e42f8a337e41a7308158b0de078afafd9`
  (remote `equiv/llvm-three-leg`, PR #29).
- Branch: `wave65/17-scr-140`.
- Contract: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`.
- Core pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.
- New cell: `spec/equiv/cells/witness-v0/C-L-bip143-encoding-cs/`.
- Tools: Alive2 v20.0 (LLVM 20.1.2), clang 20.1.2, SAW 1.6 (`68eed5f`), z3.

## 1. What was unproved at BASE

The two SCR-140 cells at BASE prove:

- `C-L-bip143-layout`: the 10-field width/offset table for `0 <= L <= 75`,
  every field payload opaque;
- `C-L-bip143-preimage-order`: byte-level 10-field assembly at
  `L in {0,1,75}`, every payload opaque, one-byte CompactSize.

Named limits in both records that the row still needed:

1. the **little-endian encodings** of version, amount, nSequence, nLockTime and
   nHashType were never derived — integer fields entered as opaque bytes;
2. **CompactSize beyond one byte** was not modelled, so the 3/5/9-byte
   prefixes and the amount offset for `L > 252` were outside the claim;
3. sub-hash **contents**, transaction decode, and SHA256d were abstracted.

## 2. New cell and proved scope

`C-L-bip143-encoding-cs` (9 functions per leg; 18 SAW proofs, 9 Alive2
bidirectional comparisons):

| function | proved claim |
|---|---|
| `cell_ser_u32le` | 4-byte LE image of a u32 (`serU32L`) |
| `cell_ser_u64le` | 8-byte LE image of a u64 (`serU64L`, `serAmountL`) |
| `cell_cs_width` | `GetSizeOfCompactSize`: 1/3/5/9 at 253 / 65536 / 2^32, total over u64 |
| `cell_cs1` | `n<253` → `[n]`, width 1 |
| `cell_cs3` | `253<=n<=65535` → `0xfd || LE16(n)`, width 3 |
| `cell_cs5` | `65536<=n<=2^32-1` → `0xfe || LE32(n)`, width 5 |
| `cell_cs9` | `n>=2^32` → `0xff || LE64(n)`, width 9 |
| `cell_bip143_amount_off` | amount starts at `105 + L + (cs_width(L)-1)`, for `0 <= L <= 2^32-1` (contains MAX_SIZE `0x02000000`) |
| `cell_bip143_preimage_e253` | all 412 preimage bytes at `L=253` (CompactSize `fd fd 00`), amount = 8-byte LE u64 at `[360,368)` |

The 412-byte map (`L=253`):

```text
[0,4)      version        4   u32 LE
[4,36)     hashPrevouts   32  opaque
[36,68)    hashSequence   32  opaque
[68,100)   txid           32  opaque
[100,104)  vout           4   opaque
[104,107)  CompactSize    3   fd fd 00
[107,360)  script         253 opaque
[360,368)  amount         8   u64 LE     <- 105 + 253 + (3-1)
[368,372)  nSequence      4   u32 LE
[372,404)  hashOutputs    32  opaque
[404,408)  nLockTime      4   u32 LE
[408,412)  nHashType      4   u32 LE
```

Direction: Alive2 `--bidirectional` (L ⊑ C and C ⊑ L); SAW verifies both legs
against the same Cryptol encoders. C follows Core's cursor form with unrolled
LE shifts; L follows `serU32L`/`serU64L`/`serAmountL`/`encCSL` and
`bip143MsgL` with absolute offsets and byte-lane loops, so the Alive2
comparison is semantic.

## 3. Real tool results

```text
alive2: 9/9 "Transformation seems to be correct!"
        0 incorrect / 0 failed-to-prove / 0 Alive2 errors
        STATUS=alive2-green
saw:    18/18 "Proof succeeded!" (9 functions x C/L), z3
        CELL_BIP143_ENCODING_CS_SAW_GREEN
        STATUS=saw-green
sha256sum -c alive2/certificate.sha256 -> all OK (25 tracked entries)
sha256sum -c saw/certificate.sha256    -> all OK (27 tracked entries)
```

Raw evidence hashes:

```text
3c5ded2e9e9f5e4f5d1855399dcab61e87b59c6a94c3e7e0db913799e96ed677  alive2/result.txt
2a152fd691811aa76ef73b53da6773cf1570223c4fe834e4de0378778ab150fb  saw/result.txt
d869c5a8e856fed1874c7e2366c22b475bb2e0dd1af39ae878f7984abdc2252c  alive2/certificate.sha256
19e9dffde1fb63f1d9ac7d8777a5ec377fb9baa4542a4b7d92381094614d4675  saw/certificate.sha256
```

The cell-local `src/build.sh` compiles from the cell directory with
`-ffile-prefix-map`, so committed `ir/*.ll` carry `src/...` and
`build/...` instead of an absolute worktree path (wave64 F3). The SAW runner
requires the exact proof count, the final marker, and the absence of
`Proof failed` / `Error` / `Stack trace` / `Could not find` (wave64 F4).

## 4. Non-vacuity mutants (out-of-tree)

Logs in this directory; no mutant is committed to the cell.

1. **Amount order swap** (`mutant-amount-order-saw.log`): L writes
   nSequence at 360 and amount at 364. Expected bytes at `[360,368)` are
   amount, so SAW produces a counterexample and `Proof failed` after 17
   proofs.
2. **Amount endianness** (`mutant-amount-be-saw.log`): L writes the amount
   big-endian at 360. SAW rejects the preimage spec with a counterexample
   (`Proof failed`) after 17 proofs.
3. **CompactSize boundary off by one** (`mutant-cs-boundary-alive2.log`,
   `mutant-cs-boundary-saw.log`): L tests `n <= 0xfd` instead of `n < 0xfd`,
   so length 253 gets width 1. Alive2: `Transformation doesn't verify!`,
   `Value mismatch`, example `n = 253`, source 3 vs target 1. SAW:
   counterexample `n: 253`, `Proof failed`.

## 5. Residual (SCR-140 remains `partial`)

No transaction decode is claimed; the premise is fixed witness bytes / fixed
wire slices. Exactly what is still missing:

- **Sub-hash contents.** `hashPrevouts`, `hashSequence`, `hashOutputs` are
  opaque 32-byte arrays. To close them: a decoded-tx model (vin/vout
  vectors), the three serializers (`serOutpointL` fold, `serU32L` sequence
  fold, `serTxOutL` fold), the ACP/SINGLE/NONE value selection, and SHA256d.
  This is the missing sub-hash/decoded-tx dependency.
- **SHA256d.** Not modelled or called; only its 412-byte input is proved
  (same-hash premise, `spec/equiv/README.md` §7).
- **Arbitrary-length buffer assembly.** Byte-level assembly at `L=253`
  (this cell) and `L in {0,1,75}` (sibling); offsets for every
  `L <= 2^32-1` (this cell); a symbolic-length `memcpy` proof is not
  attempted.
- **Amount value/range semantics.** Negative CAmount (SWT-055) is out of
  scope; only the 8-byte LE wire image is claimed.

`spec/db/equiv-cells.yaml` SCR-140 was not edited (ledger is orchestrator
owned), so the row's `status: gap` and its note remain the ledger record.
This finding + cell are additive evidence for a future ledger update.
