---
# Cell witness-v0/C-L-bip143-encoding-cs
cell: C-L-bip143-encoding-cs
family: witness-v0
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 76dbfe5e42f8a337e41a7308158b0de078afafd9
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (integer field encodings LE; CompactSize width/bytes; amount offset across the 1/3/5-byte prefix; 412-byte preimage at script_len 253; sub-hashes and SHA256d abstracted)
precondition: |
  - WITNESS_V0 BIP143 preimage path, interpreter.cpp:1655-1670, with
    nHashType appended after the arm (interpreter.cpp:1672-1676).
  - The three sub-hashes, txid, vout and hashOutputs are opaque symbolic
    byte arrays of exactly their wire widths (32, 32, 32, 4, 32).  The
    transaction is NOT decoded: this cell starts from fixed witness bytes /
    fixed wire slices, and does not claim that any concrete tx serializes to
    them.  Same-hash / same-serializer premise, spec/equiv/README.md §7.
  - Integer fields are wire values, not decoded semantics:
    version/nSequence/nLockTime/nHashType are uint32_t images of Core's
    int32_t/uint32_t fields, amount is the uint64_t image of CAmount
    (int64_t); negative CAmount (SWT-055) is out of scope.
  - CompactSize claims: width selection is total over u64; the byte writers
    are claimed on their own branch (n < 253; 253 <= n <= 65535; 65536 <= n
    <= 4294967295; n >= 4294967296).  The amount-offset formula is claimed
    for 0 <= script_len <= 4294967295, which contains every consensus-valid
    scriptCode length (MAX_SIZE = 0x02000000, Interface.lean:487-491).
  - The 412-byte assembly is claimed for script_len = 253 only, the first
    length whose CompactSize prefix is three bytes.  It completes the
    sibling byte-level cell's L in {0,1,75} at the one-byte/three-byte
    boundary; arbitrary-length symbolic assembly is not claimed.
  - SHA256d is NOT modelled or called.  The return value is the number of
    bytes SHA256d consumes.
postcondition: |
  - cell_ser_u32le / cell_ser_u64le write the 4/8 little-endian significance
    bytes of their argument (serU32L / serU64L / serAmountL).
  - cell_cs_width(n) = 1 if n<253, 3 if n<=65535, 5 if n<=4294967295,
    else 9 (GetSizeOfCompactSize, serialize.h:291-297).
  - cell_cs1/3/5/9(n) write the canonical prefix and return its width:
      n < 253          -> [n]                          width 1
      253 <= n <= 65535 -> 0xfd || LE16(n)             width 3
      65536 <= n <= 2^32-1 -> 0xfe || LE32(n)          width 5
      n >= 2^32        -> 0xff || LE64(n)              width 9
  - cell_bip143_amount_off(L) = 105 + L + (cs_width(L) - 1), the byte offset
    of the 8-byte amount in the BIP143 preimage (fields before scriptCode end
    at 104; API: encCSL(L) ++ scriptCode then amount).  Total preimage length
    is amount_off(L) + 52.
  - cell_bip143_preimage_e253 writes exactly 412 bytes:
      [0,4)      version       4   u32 LE
      [4,36)     hashPrevouts  32  opaque
      [36,68)    hashSequence  32  opaque
      [68,100)   txid          32  opaque
      [100,104)  vout          4   opaque
      [104,107)  CompactSize   3   0xfd 0xfd 0x00
      [107,360)  script        253 opaque
      [360,368)  amount        8   u64 LE   <- 105 + 253 + 2
      [368,372)  nSequence     4   u32 LE
      [372,404)  hashOutputs   32  opaque
      [404,408)  nLockTime     4   u32 LE
      [408,412)  nHashType     4   u32 LE
    and returns 412.  Every preimage byte is attributed to exactly one field;
    amount sits between scriptCode and nSequence, as BIP143 requires.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-140
scr_row_coverage: |
  partial, but this closes two limits the sibling SCR-140 cells name:
  integer field ENCODING and CompactSize ordering beyond one byte.
  Covered:
    (a) version, amount, nSequence, nLockTime and nHashType are written as
        little-endian wire integers at their BIP143 positions (preimage at
        L=253); the amount is exactly 8 bytes of LE u64 at [360,368), i.e.
        105 + L + 2 with L=253;
    (b) CompactSize selects a 1/3/5/9-byte prefix at the 253 / 65536 /
        2^32 boundaries for every u64 length, and each branch's bytes are
        the canonical LE encoding;
    (c) the amount offset is 105 + L + (cs_width(L) - 1) for every
        0 <= L <= 4294967295, so field order after scriptCode is correct for
        one-, three- and five-byte prefixes.
  NOT covered (SCR-140 therefore stays partial):
    - the CONTENTS of hashPrevouts / hashSequence / hashOutputs.  Exact
      dependency: a decoded-transaction model (vin/vout vectors) plus the
      sub-hash serializers (serOutpointL, sequence and serTxOutL folds) and
      the ACP/SINGLE/NONE value selection, then SHA256d.  The txid/vout
      fields here are opaque wire slices; no transaction decode is claimed.
    - SHA256d over the preimage: opaque; only its 412-byte input is proved.
    - full-buffer assembly for arbitrary script_len: proved at L=253 here
      and at L in {0,1,75} by C-L-bip143-preimage-order; offsets for all L
      are proved by amount_off and C-L-bip143-layout, but a symbolic-length
      stores proof is not attempted.
    - amount value/range semantics (negative CAmount, SWT-055); only the
      64-bit LE wire image is claimed.
patches: none
source_citations:
  - interpreter.cpp:1655-1670 (10-field BIP143 preimage order, amount after scriptCode)
  - interpreter.cpp:1672-1676 (nHashType appended after the serializer arm)
  - serialize.h:61-80 (ser_writedata16/32/64 = LE object bytes)
  - serialize.h:250-256 (Serialize(int32_t/uint32_t/int64_t/uint64_t))
  - serialize.h:291-297 (GetSizeOfCompactSize)
  - serialize.h:302-324 (WriteCompactSize branches)
  - spec/core/Bitcoin/SigHash/Digest.lean:53-64 (serU32L, serU64L, serAmountL)
  - spec/core/Bitcoin/SigHash/Digest.lean:288-302 (bip143MsgL order)
  - spec/core/Bitcoin/Serialization/Interface.lean:487-500 (MAX_SIZE, encCSL)
  - spec/equiv/README.md §7 (same-hash premise)
trust_note: >
  C is a line-cited serializer slice (serialize.h WriteLE/WriteCompactSize
  plus the interpreter.cpp field order), not Core's HashWriter pipeline: the
  hash object is replaced by the returned input length and the three
  sub-hashes and tx payloads are opaque byte arrays.  L is a REVIEWED
  TRANSLITERATION of serU32L/serU64L/serAmountL/encCSL and bip143MsgL with
  explicit absolute offsets; the C leg uses a running cursor and unrolled
  shifts, the L leg byte-lane loops and absolute offsets, so the Alive2
  comparison is semantic.  SAW checks both legs against the same Cryptol
  concatenation and LE encoders with z3.  The cell proves field order +
  integer encodings + CompactSize ordering; it does not prove sub-hash
  contents, transaction decode, or SHA256d.  No Core patch is used.  The
  cell-local build uses -ffile-prefix-map and relative output paths so the
  committed IR is checkout-independent (wave64 F3); the SAW classifier
  rejects stack traces/errors in addition to 'Proof failed' (wave64 F4).
evidence:
  - alive2/result.txt (alive-tv v20.0, clang 20.1.2; 9 functions x
    --bidirectional, unroll 8; 9/9 "Transformation seems to be correct",
    0 incorrect, 0 failed-to-prove, 0 Alive2 errors)
  - saw/result.txt (SAW 1.6 68eed5f, z3; 18/18 "Proof succeeded!",
    final marker CELL_BIP143_ENCODING_CS_SAW_GREEN)
  - alive2/certificate.sha256, saw/certificate.sha256
mutant: >
  Two mutants were run out-of-tree (records in
  findings/wave65/17-scr-140/).  (1) L writes the amount at 364 instead of
  360 while nSequence stays at 368: SAW rejects the preimage spec with a
  byte counterexample ("Proof failed").  (2) L changes the CompactSize
  branch test from >= 253 to > 253: Alive2 rejects cell_cs_width at n=253
  (source 3, target 1) and SAW rejects the L cs3 width; sensitivity is not
  left to the spec alone.
---
