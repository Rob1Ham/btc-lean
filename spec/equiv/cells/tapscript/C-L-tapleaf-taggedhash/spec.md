---
# Cell tapscript/C-L-tapleaf-taggedhash
cell: C-L-tapleaf-taggedhash
family: tapscript
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 76dbfe5
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (tagged-hash input only; SHA256 oracle opaque)
precondition: |
  - `control0` is `control[0]`, the first byte of the control block
    (Core `control[0]`, interpreter.cpp:1983).
  - `script` is the popped leaf script as raw bytes (`std::span<const
    unsigned char>` at the pin).
  - The named opaque oracle `H` is SHA256:
      H        : {n} (fin n) => [n][8] -> [32][8]     (never defined in-cell)
      T        := H("TapLeaf")                        (one tag hash, 32 bytes)
      pre(v,s) = T || T || serU8(v & 0xfe) || CompactSize(|s|) || s
      digest   = H(pre(v,s))
    The cell never computes a digest and never assumes H is SHA256.  T is a
    symbolic 32-byte value (four little-endian u64 inputs t0..t3); the proofs
    hold for every T, hence for the real SHA256("TapLeaf").
  - `cell_preimage_byte` / `cell_preimage_len` bound the script to 0..4 bytes
    so the script content fits the scalar observable.  Header/field layout is
    total over all 64-bit lengths.
postcondition: |
  All observables are packed little-endian bytes (cell harness; Core's LE
  writers are the pinned fact, serialize.h:57-80).

  - `cell_tag_byte(i)`  = bit8 set iff i < 7, low byte = the i-th byte of
    `"TapLeaf".toUTF8`; i.e. exactly 0x54 0x61 0x70 0x4c 0x65 0x61 0x66 and
    nothing else.  This is the *only* tag string hashed (hash.cpp:89).
  - `cell_prefix_byte(i,t)` = bit8 set iff i < 64, low byte = T[i mod 32].
    The prefix is exactly 64 bytes and byte i equals byte i+32: one tag hash
    value, written twice (`writer << taghash << taghash`, hash.cpp:90), not
    two independent hashes and not the tag string itself.
  - `cell_leaf_mask(c)` = (c & 0xfe, c & 1): the hashed version byte is
    `control[0] & TAPROOT_LEAF_MASK` (interpreter.cpp:1983,
    interpreter.h:242) and the low bit is the output-key parity consumed by
    VerifyTaprootCommitment (interpreter.cpp:1924).  The two never mix.
  - `cell_cs_size(n)` = 1/3/5/9 for n < 0xfd / <= 0xffff / <= 0xffffffff /
    otherwise, total over all 64-bit n (serialize.h:301-323).
  - `cell_cs_byte(n,j)` = bit8 set iff j < size, low byte = WriteCompactSize
    byte j (marker then little-endian payload), total over all n and j.
  - `cell_field_kind(i,len)` / `cell_field_index(i,len)`: for every 64-bit
    script length, offset i maps to T-copy-0 (0..31), T-copy-1 (32..63),
    version (64), CompactSize (65..65+cs-1), script (65+cs..65+cs+len-1), or
    past the end; the index inside the field is exact.  Field order is
    prefix, prefix, version, length, script.
  - `cell_preimage_byte(i,T,c,len,s)`, len <= 4: at every 64-bit offset i the
    exact composed preimage byte and an in-range bit.  `cell_preimage_len`
    is 64+1+cs+len for the same domain.  byte 64 is the masked version; the
    CompactSize byte follows; script bytes follow verbatim.
  - Same-preimage congruence: `control0` and `control0^1` produce the same
    preimage byte at every offset (the version is the only place control0
    enters, through `& 0xfe`), so for any deterministic H the two digests
    agree.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-146
scr_row_coverage: |
  partial, explicitly, and deliberately so.  SCR-146's row text names the
  *digest*: `TaggedHash("TapLeaf", leaf_ver, CompactSize, script)` with
  `leaf_ver = control[0] & 0xfe`.  This cell proves the complete tagged-hash
  *input construction* against the named opaque oracle H:
    (a) the tag string is exactly the seven ASCII bytes "TapLeaf";
    (b) the prefix is exactly 64 bytes = T || T for ONE symbolic 32-byte T,
        so the two copies are the same value (tag derivation, not two calls);
    (c) the leaf-version mask and its separation from the parity bit, for all
        256 control bytes;
    (d) the exact CompactSize encoding (1/3/5/9-byte forms, all boundaries)
        at offset 65, total over all 64-bit lengths;
    (e) the exact field map for every 64-bit length and the exact composed
        preimage byte string for scripts of 0..4 bytes;
    (f) preimage invariance under the parity bit, hence digest equality by
        function congruence for any deterministic H.
  It does NOT prove SHA256: no compression, padding, length loop, streamed
  vs one-shot equivalence, or concrete 32-byte value.  The residual is the
  named premise
    `H = SHA256_FIPS180_4` on BOTH legs, and
    `CSHA256::Write/Write/Finalize` (one context, one Finalize) =
    SHA256 over the concatenated byte stream,
  which are SHA256 internals, not tag derivation.  The published-vector
  script `src/vector_check.py` corroborates (does not prove) that the
  specified byte stream reproduces four BIP341 wallet leaf hashes.
  The ledger row therefore stays `unjudged-seam`; this cell narrows it to a
  single named hash premise and must not be cited as a full TapLeaf proof.
patches: none
source_citations:
  - "interpreter.cpp:1882-1884 (ComputeTapleafHash: HashWriter{HASHER_TAPLEAF} << leaf_version << CompactSizeWriter(script.size()) << script, GetSHA256)"
  - "interpreter.cpp:1983 (call site: ComputeTapleafHash(control[0] & TAPROOT_LEAF_MASK, script))"
  - "interpreter.cpp:1477 (const HashWriter HASHER_TAPLEAF{TaggedHash(\"TapLeaf\")})"
  - "interpreter.cpp:1924 (VerifyTaprootCommitment passes control[0] & 1 as parity)"
  - "interpreter.h:242 (TAPROOT_LEAF_MASK = 0xfe)"
  - "hash.cpp:85-91 (TaggedHash: one CSHA256 over the tag bytes, writer << taghash << taghash)"
  - "hash.h:108-142 (HashWriter: single CSHA256 ctx; GetSHA256 Finalizes once)"
  - "hash.h:221-227 (TaggedHash doc: SHA256(tag) written twice, 64 bytes)"
  - "uint256.h:110-114 (base_blob::Serialize writes the 32 bytes raw)"
  - "serialize.h:248-250 (Serialize(uint8_t) = one byte)"
  - "serialize.h:57-80 (ser_writedata16/32/64 are little-endian)"
  - "serialize.h:301-323 (WriteCompactSize: 1 / 0xfd+2LE / 0xfe+4LE / 0xff+8LE)"
  - "serialize.h:248-261 (Serialize(span<B>) writes raw bytes, no prefix)"
  - "serialize.h:618-629 (CompactSizeWriter calls WriteCompactSize)"
  - "spec/core/Bitcoin/Crypto/Schnorr/TaggedHash.lean:29-31 (taggedHash = sha256 (sha256 tag ++ sha256 tag ++ msg))"
  - "spec/core/Bitcoin/Crypto/Schnorr/TaggedHash.lean:46 (tagTapLeaf = \"TapLeaf\".toUTF8)"
  - "spec/core/Bitcoin/Interpreter/Rules.lean:681-686 (tapLeafHash: masked version ++ compactSizeEnc ++ script)"
  - "spec/core/Bitcoin/Crypto/Taproot/Program.lean:554-555 (leafVersionOf = control[0] &&& 0xfe)"
  - "spec/core/Bitcoin/Data/Basic.lean:42 (serU8), :73-77 (compactSizeEnc)"
  - "spec/proofs/BitcoinProofs/AF/PDW58/PDW58.lean:160-164 (tapLeafHash_preimage_row)"
  - "spec/equiv/README.md §7 (same-hash premise)"
trust_note: >
  C is a line-cited byte-level slice of the stream Core feeds to its SHA256
  context: HashWriter is primed with TaggedHash("TapLeaf") (64 bytes) and the
  three writes are expressed as the byte stores/offsets they perform, with
  the CompactSize branch structure of serialize.h.  GetSHA256/CSHA256 are NOT
  in the cell.  L is a REVIEWED TRANSLITERATION of Rules.lean's tapLeafHash
  and TaggedHash.lean's taggedHash, assembled arithmetically (offsets and
  shifts) rather than by memory stores, so the Alive2 comparison is semantic.
  The opaque T is passed identically to both legs; both prefix copies read the
  same four words, which models the Lean term `sha256 tag` occurring twice as
  one value.  Both tools check the same byte-level observable; neither
  computes or constrains a SHA256 digest.  `src/vector_check.py` is
  corroboration against Core's published BIP341 wallet vectors, not proof and
  not part of the tool certificates' claim.  No Core patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - src/vector_check.py, src/vector_result.txt
mutant: >
  Proposed (not executed here): in l_leaf.cpp make `lean_cs_byte` put the
  payload before the marker, or make `lean_t_byte` for the second prefix copy
  read a different word (breaking the single-T duplication), or use
  `lean_mask(c) = c - (c & 3)`.  Expected Alive2 counterexample at any len,
  at control0 with bit 1 set, or at prefix offset 32; SAW must fail the
  corresponding leg.  These are single-byte/single-field differences, so the
  byte observables cannot hide them.  The wave64/33 layout cell records the
  mask/order mutants; this cell adds the prefix-duplication and tag-string
  mutants.
mutant_site: "cells/tapscript/C-L-tapleaf-taggedhash/src/l_leaf.cpp lean_t_byte / lean_cs_byte / lean_mask"
---

# `tapscript/C-L-tapleaf-taggedhash`

SCR-146 is the TapLeaf tagged hash.  This cell proves **how its input is
built against a named opaque oracle**, not the hash itself:

```text
T        := H("TapLeaf")                              (one 32-byte hash)
pre(v,s)  = T || T || serU8(v & 0xfe) || CS(|s|) || s
digest    = H(pre(v,s))                               (H = SHA256; NOT proved)
```

The distinction the cell makes explicit:

- **Tag derivation** (proved): the tag bytes are exactly `TapLeaf`, one hash
  value is written twice, the prefix is 64 bytes, and the version/length/
  script fields follow in order.  These are properties of hash.cpp:85-91 and
  interpreter.cpp:1882-1884 and do not depend on SHA256's internals.
- **SHA256 internals** (not proved): compression, padding, the message-length
  loop, streamed-vs-one-shot equivalence and any concrete digest.  These are
  the residual named premise; the cell does not assume an opaque
  `sha256_tagged` that would hide the tag layout, because the oracle is the
  whole-input hash function and its input bytes are fully visible.

## What is proved

Nine total functions per leg, all checked against one independent Cryptol
statement (Alive2 bidirectional with `--always-verify`, SAW both legs):

| function | claim |
|---|---|
| `cell_tag_byte` | tag string is exactly `"TapLeaf"` (7 bytes), no more |
| `cell_prefix_byte` | 64-byte prefix = one 32-byte T repeated (byte i = byte i+32) |
| `cell_leaf_mask` | version = `control[0]&0xfe`, parity = `control[0]&1`, separated |
| `cell_cs_size` | CompactSize size 1/3/5/9, total over all u64 lengths |
| `cell_cs_byte` | exact CompactSize bytes at every boundary and index |
| `cell_field_kind` | field at any preimage offset, total over all u64 lengths |
| `cell_field_index` | exact index inside that field |
| `cell_preimage_byte` | exact composed preimage byte + range, scripts 0..4 B |
| `cell_preimage_len` | exact preimage length, scripts 0..4 B |

Field order is `T, T, version, CompactSize, script`.  Since `control0` enters
only through `& 0xfe` at offset 64, `control0` and `control0^1` (parity bit)
give byte-identical preimages at every offset; deterministic-H congruence
then gives equal digests.

## What is not proved

- Any SHA256 computation or digest value; streamed `CSHA256` vs one-shot
  SHA256; the `HASHER_TAPLEAF` midstate.
- Script bytes beyond 4 bytes in the *content* exactness function.  Their
  placement, length and indexing are proved for all 64-bit lengths.
- SCR-147 (EC tweak/commitment) and the control-block size gate (SCR-145).

## Published-vector corroboration (not proof)

`src/vector_check.py` recomputes four leaf hashes from Core's
`bip341_wallet_vectors.json` (commit cce32b168) with the byte construction
above and Python's SHA-256, including a `0xfa` leaf version and both control
parities, plus four negative controls (single prefix, NUL-terminated tag,
version-before-prefix, unmasked control).  All pass.  This shows the cell's
construction is the vector-expected one; it is not a proof and is not part of
the Alive2/SAW claim.

## Exact commands

```sh
bash spec/equiv/cells/tapscript/C-L-tapleaf-taggedhash/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-tapleaf-taggedhash/saw/run.sh
sha256sum -c spec/equiv/cells/tapscript/C-L-tapleaf-taggedhash/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-tapleaf-taggedhash/saw/certificate.sha256
python3 spec/equiv/cells/tapscript/C-L-tapleaf-taggedhash/src/vector_check.py
```
