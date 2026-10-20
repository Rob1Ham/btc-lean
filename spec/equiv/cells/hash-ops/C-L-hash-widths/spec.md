---
# Cell hash-ops/C-L-hash-widths
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-hash-widths
family: hash-ops
tool_status: both-green (meta-only Alive2 width/plumbing + SAW concrete-digest witnesses; hash transforms opaque)
precondition: |
  - base sigversion; flags = 0; one input.
  - closed preimage: the stack holds one element, either the empty element
    (length 0) or the one-byte element 0x61 ("a").
  - the only dispatched opcode is one of the four hash opcodes the twin
    implements: OP_RIPEMD160 (0xa6), OP_SHA256 (0xa8), OP_HASH160 (0xa9),
    OP_HASH256 (0xaa).
  - RIPEMD160, SHA256, HASH160 and HASH256 are four opaque external symbols,
    each shared by both legs; their bodies are outside the cell.
  - bounded leaf domain: element width <= 32, stack depth 4.
postcondition: |
  - each op consumes the preimage, pushes exactly one element, and the pushed
    element has the width selected by interpreter.cpp:1042: 20 for RIPEMD160
    and HASH160, 32 for SHA256 and HASH256.
  - empty preimage: the zero-length element is accepted (no error) and the
    hash is pushed.  Concrete SAW witnesses:
      RIPEMD160("") = 9c1185a5c5e9fc54612808977ee8f548b2258d31
      SHA256("")    = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
      HASH160("")   = b472a266d0bd89c13706a4132ccfb16f7c3b9fcb
      HASH256("")   = 5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456
  - one-byte 0x61 witnesses:
      RIPEMD160("a") = 0bdc9d2d256b3ee9daae347be6f4dc835a467ffe
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
scr_row_coverage: partial
coverage: partial
patches: none
source_citations:
  - interpreter.cpp:1032-1056 (hash opcode family)
  - interpreter.cpp:1042 (vchHash width: 20 for RIPEMD160/SHA1/HASH160, 32 otherwise)
  - interpreter.cpp:1043-1052 (CRIPEMD160/CSHA1/CSHA256/CHash160/CHash256 dispatch)
  - interpreter.cpp:1053-1054 (popstack; push_back(vchHash))
  - twin/ops_ir.py OP_RIPEMD160 (wire 0xa6), OP_SHA256 (0xa8), OP_HASH160 (0xa9), OP_HASH256 (0xaa)
  - twin/ops_ir.py OP_UNSUPPORTED_SHA1 (wire 0xa7) -- SHA1 is outside the L subset
  - twin/generator.md:231,393,407 (SHA1 returns result 3)
  - spec/core/Bitcoin/Interpreter/Defs.lean:637-643 (hashForOp width dispatch)
  - spec/core/Bitcoin/Interpreter/Hashes.lean (hashSha256/hashRipemd160/hashHash160/hashSha256d)
trust_note: >
  SAME-HASH CONDITION: RIPEMD160, SHA256, HASH160 and HASH256 are opaque
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
  libsecp/SHA/RIPEMD implementation is proved.  C is a line-cited source
  slice of Core interpreter.cpp at the pin, not the whole EvalScript.  L is a
  reviewed transliteration of twin/ops_ir.py: the handler bodies are verbatim,
  but the cell rebinds the stack to 32-byte elements and an unrolled copy
  because mk_leaf's bounded_memcpy is hard-wired to two bytes (the generated
  build/twin_ops.h is retained for provenance only).  No Core source patch is
  used.  SCR-093 stays partial because its SHA1 arm is deliberately not in the
  L subset (wire 0xa7 returns TWIN_INVALID_UNSUPPORTED), and because the hash
  output sizes themselves are assumed at the seam.  SCR-095 is partial for
  the same SHA1/scoping reason.  Neither row is claimed as a cryptographic
  implementation proof.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - build/ (generated twin_ops.h, extracted C/L IR, build.txt)
mutant: "change the L push width to 32 for HASH160/RIPEMD160 (or 20 for SHA256/HASH256), or drop the empty-element path; expect Alive2 and SAW to fail"
mutant_site: "cells/hash-ops/C-L-hash-widths/src/l_leaf.cpp op_hash160/op_ripemd160/op_sha256/op_hash256 width argument"
---

# Cell `hash-ops/C-L-hash-widths`

## What is proved

Eight closed functions per leg: the four hash opcodes the twin implements
(RIPEMD160, SHA256, HASH160, HASH256) over the empty element and the one-byte
element `0x61`.  Each function exists in two observables:

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
| `cell_sha256_*` | 32 | `e3b0c442…` | `ca978112…` |
| `cell_hash160_*` | 20 | `b472a266…` | `99435519…` |
| `cell_hash256_*` | 32 | `5df6e0e2…` | `bf5d3aff…` |

The Alive2 observable's length field is what makes the width claim
observable: a wrong push width changes the length field (the recorded mutation
probe changes 20 to 32 and Alive2 reports `0xa101` against `0x10101`).  The
SAW observable carries the same length field plus the digest prefix.

## What is not proved

- **SHA1 (wire 0xa7).** Core implements it (`interpreter.cpp:1043-1047`);
  `twin/ops_ir.py` maps it to `OP_UNSUPPORTED_SHA1` and returns
  `TWIN_INVALID_UNSUPPORTED` / result 3.  SCR-093's SHA1 arm therefore has no
  L-side implementation to compare.  This is a declared twin-subset boundary,
  not an IR/tool failure.
- **The hash functions.**  The four transforms are opaque on both legs; their
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
`hash160`.  This cell adds the other three implemented opcodes, both width
arms, and the empty element.  It does not edit that cell.
