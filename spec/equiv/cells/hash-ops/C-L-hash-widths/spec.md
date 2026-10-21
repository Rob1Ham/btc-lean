---
# Cell hash-ops/C-L-hash-widths
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-hash-widths
family: hash-ops
tool_status: both-green (meta-only Alive2 width/plumbing + SAW concrete-digest witnesses; five hash transforms opaque; SHA1 arm cell-local)
precondition: |
  - base sigversion; flags = 0; one input.
  - closed preimage: the stack holds one element, either the empty element
    (length 0) or the one-byte element 0x61 ("a").
  - the only dispatched opcode is one of the five hash opcodes:
    OP_RIPEMD160 (0xa6), OP_SHA1 (0xa7), OP_SHA256 (0xa8), OP_HASH160 (0xa9),
    OP_HASH256 (0xaa).
  - RIPEMD160, SHA1, SHA256, HASH160 and HASH256 are five opaque external
    symbols, each shared by both legs; their bodies are outside the cell.
  - the SHA1 handler is a reviewed cell-local L body.  The pinned shared twin
    maps wire 0xa7 to OP_UNSUPPORTED_SHA1 (result 3), so this cell does not
    change or claim the shared twin's declared subset; see trust_note.
  - bounded leaf domain: element width <= 32, stack depth 4.
postcondition: |
  - each op consumes the preimage, pushes exactly one element, and the pushed
    element has the width selected by interpreter.cpp:1042: 20 for RIPEMD160,
    SHA1 and HASH160, 32 for SHA256 and HASH256.
  - empty preimage: the zero-length element is accepted (no error) and the
    hash is pushed.  Concrete SAW witnesses:
      RIPEMD160("") = 9c1185a5c5e9fc54612808977ee8f548b2258d31
      SHA1("")      = da39a3ee5e6b4b0d3255bfef95601890afd80709
      SHA256("")    = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
      HASH160("")   = b472a266d0bd89c13706a4132ccfb16f7c3b9fcb
      HASH256("")   = 5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456
  - one-byte 0x61 witnesses:
      RIPEMD160("a") = 0bdc9d2d256b3ee9daae347be6f4dc835a467ffe
      SHA1("a")      = 86f7e437faa5a7fce15d1ddcb9eaeaea377667b8
      SHA256("a")    = ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb
      HASH160("a")   = 994355199e516ff76c4fa4aab39337b9d84cf12b
      HASH256("a")   = bf5d3affb73efd2ec6c36ad3112dd933efed63c4e1cbffcfa88e2759c144f2d8
  - the SAW-observed packed value is result=1, error=0, depth=1, the width
    above, and the first five digest bytes.  Alive2 observes only the defined
    meta fields (result, error, depth, pushed length): an external write is
    unmodelled memory in Alive2, so reading the digest would poison the whole
    packed value and make the refinement check vacuous.  The width is therefore
    Alive2-visible, while the digest bytes are SAW-only witnesses.
direction:
  - L ⊑ C
scr_rows: SCR-093, SCR-095
scr_row_coverage: >
  full for SCR-093 and SCR-095 at this cell's scope.  SCR-093's 20/20/32
  table is exercised on the three named primitives (RIPEMD160 20, SHA1 20,
  SHA256 32), plus the HASH160 (20) and HASH256 (32) dispatch-family
  neighbours.  SCR-095's empty element is exercised on all five wires.  The
  SHA1 arm is a reviewed cell-local L extension because the pinned shared
  twin still maps 0xa7 to result 3; the shared twin's declared subset is
  unchanged.  The hash algorithms remain opaque externals (same-hash premise,
  outside these rows' width/empty claims).
coverage: full
patches: none
source_citations:
  - interpreter.cpp:1032-1056 (hash opcode family)
  - interpreter.cpp:1042 (vchHash width: 20 for RIPEMD160/SHA1/HASH160, 32 otherwise)
  - interpreter.cpp:1043-1052 (CRIPEMD160/CSHA1/CSHA256/CHash160/CHash256 dispatch)
  - interpreter.cpp:1053-1054 (popstack; push_back(vchHash))
  - twin/ops_ir.py OP_RIPEMD160 (wire 0xa6), OP_SHA256 (0xa8), OP_HASH160 (0xa9), OP_HASH256 (0xaa)
  - twin/ops_ir.py OP_UNSUPPORTED_SHA1 (wire 0xa7) -- the shared twin's declared boundary; unchanged by this cell
  - twin/runtime.inc:409-564 (hash floor has sha256/ripemd160/hash160/hash256, no sha1 primitive)
  - twin/generator.md:231,393,407 (shared twin: SHA1 returns result 3)
  - spec/core/Bitcoin/Interpreter/Defs.lean:637-643 (hashForOp; 0xa7 => hashSha1)
  - spec/core/Bitcoin/Interpreter/Hashes.lean:133-157 (hashSha1)
  - spec/proofs/BitcoinProofs/AF/PDW78/PDW78.lean:74-106 (scr093_hashForOp_widths, scr095_emptyElement_hashed)
trust_note: >
  SAME-HASH CONDITION: RIPEMD160, SHA1, SHA256, HASH160 and HASH256 are opaque
  externals with the same symbols and signatures in both legs.  Alive2
  quantifies over their output and proves the surrounding plumbing (output
  width and pop/push) for every digest value; SAW separately pins the call
  arguments.  The Alive2 pairs are the meta-only exports, which do not read the
  externally written bytes, so the compared value stays defined instead of
  becoming poison.  Alive2 does not prove the hash functions and does not
  compare their digest bytes.  SAW pins each external to one concrete digest
  computed with Python hashlib and verifies the full packed observable, so the
  digest is an assumption with a recorded witness, not a derived result.
  This is the proof-level counterpart of README.md (§7 crypto seam); no
  libsecp/SHA/RIPEMD/SHA1 implementation is proved.  C is a line-cited source
  slice of Core interpreter.cpp at the pin, not the whole EvalScript.
  L is a reviewed transliteration of twin/ops_ir.py for the four implemented
  hash handlers (the bodies are verbatim), with the stack rebound to 32-byte
  elements and an unrolled copy because mk_leaf's bounded_memcpy is hard-wired
  to two bytes (the generated build/twin_ops.h is retained for provenance
  only).
  SHA1 is different and is labelled separately: the pinned shared twin maps
  wire 0xa7 to OP_UNSUPPORTED_SHA1 / result 3 and twin/runtime.inc has no sha1
  primitive.  This cell adds a reviewed CELL-LOCAL L handler for 0xa7 in
  src/l_leaf.cpp, with the same pop/push shape and width 20, anchored to Lean
  Defs.lean:637-643 (hashForOp 0xa7 => hashSha1) and Core interpreter.cpp:1043-
  1047 (CSHA1).  It calls an opaque `sha1` external shared with the C leg; no
  SHA1 internals are implemented, linked, or claimed.  The shared twin and its
  declared subset are unchanged, so this is not a claim that the pinned twin
  now supports SHA1.  Integrating the arm into the shared twin (runtime.inc +
  ops_ir.py + regenerated build) remains a separate reviewed change.
  No Core source patch is used.  SCR-093 and SCR-095 are covered at this
  cell's scope: the width table includes SHA1=20 and the empty-element path is
  exercised on all five wires.  Neither row is claimed as a cryptographic
  implementation proof.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - build/ (generated twin_ops.h, extracted C/L IR, build.txt)
mutant: "change the L push width to 32 for HASH160/RIPEMD160/SHA1 (or 20 for SHA256/HASH256), or drop the empty-element path; expect Alive2 and SAW to fail"
mutant_site: "cells/hash-ops/C-L-hash-widths/src/l_leaf.cpp op_hash160/op_ripemd160/op_sha1/op_sha256/op_hash256 width argument"
---

# Cell `hash-ops/C-L-hash-widths`

## What is proved

Ten closed functions per leg: the five hash opcodes (RIPEMD160, SHA1, SHA256,
HASH160, HASH256) over the empty element and the one-byte element `0x61`.
Each function exists in two observables:

- `cell_*_meta` (Alive2): the same handler and the same pop/push, but the
  packed result keeps only result, error, depth and the pushed length.  Alive2
  compares the C and L meta functions with the hash transforms uninterpreted,
  so the width/plumbing claim is checked for every possible digest value.
- `cell_*` (SAW): the full packed observable, including the first five digest
  bytes.  SAW verifies both legs against independent concrete digests.

The split is deliberate.  Alive2 models a call to an external function as
writing memory it does not track; a function that reads those bytes returns a
poisoned packed value, and a poisoned value refines anything.  That is why the
Alive2-visible functions do not read the digest.  An earlier version of this
cell compared the digest-bearing functions and was green for the wrong reason
(any mutation passed); the meta split removes that vacuity.  The digest bytes
are not lost: SAW checks them with concrete overrides, and the recorded
witnesses below are the values those overrides pin.

| Function pair | Width | Empty witness | `0x61` witness |
|---|---:|---|---|
| `cell_ripemd160_*` | 20 | `9c1185a5…` | `0bdc9d2d…` |
| `cell_sha1_*` | 20 | `da39a3ee…` | `86f7e437…` |
| `cell_sha256_*` | 32 | `e3b0c442…` | `ca978112…` |
| `cell_hash160_*` | 20 | `b472a266…` | `99435519…` |
| `cell_hash256_*` | 32 | `5df6e0e2…` | `bf5d3aff…` |

The Alive2 observable's length field is what makes the width claim
observable: a wrong push width changes the length field.  A scratch SHA1 probe
that changed the L width from 20 to 32 made Alive2 report `0xa101` against
`0x10101` (0 correct, 1 incorrect); a scratch probe that rejected length 0 in
`op_sha1` was also rejected.  The SAW observable carries the same length field
plus the digest prefix.

## What is not proved

- **Shared-twin SHA1 support.**  Core implements OP_SHA1
  (`interpreter.cpp:1043-1047`) and the Lean model implements `hashSha1`
  (`Defs.lean:637-643`, `Hashes.lean:133-157`), but the pinned shared twin
  still maps wire 0xa7 to `OP_UNSUPPORTED_SHA1` / result 3 and its
  `runtime.inc` has no `sha1` primitive.  This cell's SHA1 arm is a reviewed
  cell-local L handler that keeps the transform opaque; it is not a claim that
  the shared twin supports SHA1.  Integrating it into `ops_ir.py` /
  `runtime.inc` and regenerating the twin is a separate reviewed change.
- **SHA1 internals.**  No SHA1 compression/padding code is implemented,
  linked, or verified here.  `sha1` is an uninterpreted external whose digest
  is pinned by SAW to the recorded witnesses, exactly like the other four
  transforms.  A claim that the symbol denotes FIPS 180-4 SHA1 would require a
  verified implementation or a link to one, and is outside this cell.
- **The hash functions.**  The five transforms are opaque on both legs; their
  output sizes and digest values are the same-hash premise.  A change hidden
  inside an external body is invisible to Alive2 and is caught by SAW only if
  the recorded witness is changed.
- **Digest bytes under Alive2.**  Alive2 compares only the meta fields; the
  digest bytes are verified by SAW for the recorded closed witnesses, not
  universally.
- **C ⊑ L is not checked.**  The Alive2 run is `alive-tv C L` (L ⊑ C).  The
  reverse run does not verify because Alive2's external-write model makes the
  digest-copying L side undefined when used as the source; it is a model
  asymmetry, not a semantic counterexample.  SAW verifies both legs against
  the same constants, which establishes equality on the recorded witnesses.
- **Preimages longer than one byte.**  The width/empty claims do not depend on
  the preimage length, but only lengths 0 and 1 are exercised.

## Relation to the existing e2-hash cell

`e2-hash/hash160-vector` proved one HASH160 vector with a single opaque
`hash160`.  This cell adds the other four opcodes (including the cell-local
SHA1 arm), both width arms, and the empty element.  It does not edit that
cell.
