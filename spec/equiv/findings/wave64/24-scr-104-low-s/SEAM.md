# SCR-104 — exact numeric LOW_S / libsecp seam

Pinned Core: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.
Pinned libsecp source: `src/secp256k1` in that tree.
Cell that this note bounds: `spec/equiv/cells/checksig/C-L-checksig-lows-numeric`.
Row: **SCR-104** (`S <= order/2 under LOW_S (pol.)`,
`interpreter.cpp:183-198; pubkey.cpp:393-399@cce32b168`).

This note is deliberately narrow: it names the exact boundary between the
numeric half-order predicate (which is proved by the cell) and the
libsecp256k1 parse/normalize seam (which is not).

---

## 1. The three predicates

Let `n` be the secp256k1 group order and `halfN = floor(n/2)`:

```
n     = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
halfN = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
2^256 - n = 0x14551231950B75FC4402DA1732FC9BEBF   (129 bits)
```

For a BIP66-valid signature, let `r` and `s` be the raw big-endian magnitudes
of the DER integers **after** the leading-zero stripping performed by
`ecdsa_signature_parse_der_lax` (so `0 <= r,s < 2^256`).  Let `len_ov` be
that parser's one shared length-overflow flag
`rlen' > 32 || slen' > 32` (`pubkey.cpp:157-181`).

### Core (`CPubKey::CheckLowS`, pubkey.cpp:393-399)

```
parse = ecdsa_signature_parse_der_lax(sig)
if !parse: reject
return !secp256k1_ecdsa_signature_normalize(ctx, NULL, sig)
```

The lax parser copies the stripped magnitudes into a 64-byte compact buffer
and calls `secp256k1_ecdsa_signature_parse_compact`
(secp256k1.c:407-425).  `scalar_set_b32` sets overflow for any value `>= n`;
`parse_compact` then `memset`s **both** scalars to zero.  `normalize`
(secp256k1.c:453-470) loads the zeroed pair and returns
`secp256k1_scalar_is_high(&s)`, which is 0 for `s = 0`.  Therefore, for
BIP66-valid DER and `parse_ok = 1`:

```
CoreLowS(r,s) = len_ov  OR  r >= n  OR  s >= n  OR  s <= halfN
```

The `s >= n` disjunct is not the canonical `s <= halfN` comparison; it is the
parse_compact overflow path.  It is exactly the window the existing
`checksig/C-L-checksig-lows` cell excluded with its `s < n` domain.

### Lean `Der.isLowDERSignature` (Der.lean:203-219)

```
isDERSignature b && match parseDerLax (dropLastByte b) with
| none => false
| some (_, s) => s % n <= halfN
```

`parseDerLax` zeroes both values only on `len_ov` (it does not check
`r >= n` or `s >= n` as values), so

```
DerLowS(r,s) = len_ov  OR  (s % n <= halfN)
```

Because `s < 2^256 < 2n`, `s % n` is `s` for `s < n` and `s - n` for
`s >= n`; and `0 <= s - n <= 2^256 - 1 - n < halfN` (the gap is only 129
bits).  Hence `DerLowS = len_ov OR s >= n OR s <= halfN`.

### Lean `Defs.checkLowS` (Defs.lean:349-362), the SCR-104 target

```
if !isValidSigEncoding (sigNoHT.push 0x01) then false
else sval <= SIG_S_HALF_ORDER
```

`sval` is the raw big-endian value read from the S field; there is no
`% n` and no parse-compact overflow model:

```
DefsLowS(r,s) = s <= halfN
```

---

## 2. Where they differ (exact sets)

All statements assume BIP66 passed and `parse_ok = 1`.

| Pair | Difference set | Direction |
|---|---|---|
| Core vs `Der` | `not len_ov AND r >= n AND s < n AND s > halfN` | Core accepts (R overflow zeroes S); Der rejects (it ignores R) |
| Core vs `Defs` | `s > halfN AND (len_ov OR r >= n OR s >= n)` | Core accepts; Defs rejects |
| `Der` vs `Defs` | `s >= n OR (len_ov AND s > halfN)` | Der accepts (mod n or zeroing); Defs rejects (raw compare) |

The cell proves the remaining region:

```
(not len_ov) AND r < n  =>  CoreLowS(r,s) = DerLowS(r,s)  for all s in [0, 2^256)
```

which is the *numeric* half-order predicate including the `s >= n` window.
The two residual mismatches are a Lean-model boundary, not an IR/tool limit:

1. **R coupling.** Core's compact parser has one shared overflow flag; a
   non-canonical R zeroes S as well. `Der.parseDerLax` and `Defs.checkLowS`
   do not read R.  A canonical-R premise is therefore unavoidable for any
   Core-vs-Lean equivalence, unless the Lean model grows a parse-compact
   overflow seam.
2. **Raw vs reduced S.** `Defs.checkLowS` (the row's Lean target) compares
   raw S to halfN.  Core and `Der` accept `s >= n` via zeroing/mod-n.  The
   two models disagree on that entire window, even when R is canonical and
   no length overflows.

`docs/DECISION-lax-ecdsa.md` §2-3 already records SGN-107 for the compact
parser's overflow rejection; this note pins the corresponding LOW_S
consequence and its witness set.

---

## 3. Runtime probe against the pinned libsecp source

`probe_lows.c` is a standalone C program:

- `ecdsa_signature_parse_der_lax` is copied **verbatim** from
  `src/pubkey.cpp:45-193` at the pin.
- `IsValidSignatureEncoding` is copied **verbatim** from
  `src/script/interpreter.cpp:118-180` to prove each witness reaches
  `CheckLowS` through the BIP66 gate.
- It links the pinned `src/secp256k1` source and calls
  `secp256k1_ecdsa_signature_normalize`, printing `check_lows = !return`,
  which is exactly `CPubKey::CheckLowS`.
- `Defs` and `Der` columns are computed in Python from the same raw S
  (`Defs = s <= halfN`, `Der = s % n <= halfN`).

Build (from a scratch copy of the pinned secp tree):

```sh
cmake -S src/secp256k1 -B build \
  -DCMAKE_BUILD_TYPE=Release -DSECP256K1_BUILD_TEST=OFF \
  -DSECP256K1_BUILD_BENCHMARK=OFF -DSECP256K1_BUILD_EXHAUSTIVE_TESTS=OFF
cmake --build build -j4
gcc -O2 -I src/secp256k1/include probe_lows.c \
  -L build/lib -lsecp256k1 -Wl,-rpath,$PWD/build/lib -o probe_lows
./probe_lows <SIGHEX>
```

Raw output of the ten witnesses is in `probe_witnesses.txt`.  Summary:

| witness | r | s | BIP66 | Core | Der | Defs | mismatch |
|---|---|---|---|---|---|---|---|
| control_low | 1 | halfN | 1 | 1 | 1 | 1 | — |
| control_high | 1 | halfN+1 | 1 | 0 | 0 | 0 | — |
| s_eq_n | 1 | n | 1 | 1 | 1 | 0 | Core/Der vs Defs |
| s_eq_n_plus_1 | 1 | n+1 | 1 | 1 | 1 | 0 | Core/Der vs Defs |
| s_max | 1 | 2^256-1 | 1 | 1 | 1 | 0 | Core/Der vs Defs |
| s_n_minus_1 | 1 | n-1 | 1 | 0 | 0 | 0 | — |
| r_eq_n_s_high | n | halfN+1 | 1 | 1 | 0 | 0 | Core vs both Lean arms |
| r_max_s_high | 2^256-1 | halfN+1 | 1 | 1 | 0 | 0 | Core vs both Lean arms |
| s_len33_2p256 | 1 | 2^256 (33 bytes) | 1 | 1 | 1 | 0 | Core/Der vs Defs |
| r_len33_s_high | 2^256 (33 bytes) | halfN+1 | 1 | 1 | 0 | 0 | Core vs both Lean arms |

The `check_lows` column is the pinned libsecp result, not a model claim.
`control_low`/`control_high` also show the cell's boundary behavior:
`halfN` is accepted and `halfN+1` is rejected.

---

## 4. Consequence for SCR-104

- The **numeric S predicate** is proved over all raw S by
  `checksig/C-L-checksig-lows-numeric`: under canonical R and no length
  overflow, Core and `Der` agree, including `s >= n`.
- SCR-104 **stays partial**: the row's Lean target `Defs.checkLowS` is a raw
  compare, so it disagrees with Core on `s >= n`; and Core's R-overflow
  coupling is not modelled by either Lean arm.
- Closing the row is a **Lean model change** (add parse-compact overflow /
  zeroing semantics, or explicitly scope LOW_S to canonical S), not a new
  Alive2/SAW cell.  This is the "same-crypto seam" named by
  `docs/DECISION-lax-ecdsa.md`; no IR feature blocks it.
