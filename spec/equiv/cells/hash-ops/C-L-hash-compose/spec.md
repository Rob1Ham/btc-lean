---
# Cell hash-ops/C-L-hash-compose
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-hash-compose
family: hash-ops
tool_status: both-green (Alive2 token-chain order/width + SAW two-stage concrete digests; SHA256/RIPEMD160 opaque)
precondition: |
  - base sigversion; flags = 0; one input.
  - closed preimage: one stack element, either empty (length 0) or 0x61 ("a").
  - the only dispatched opcodes are OP_HASH160 (0xa9) and OP_HASH256 (0xaa).
  - SHA256 and RIPEMD160 are two opaque external symbols shared by both
    legs; the primitive bodies are outside the cell.
  - bounded leaf domain: element width <= 32, stack depth 4.
postcondition: |
  - HASH160: the preimage is SHA256'd into a 32-byte intermediate, then
    RIPEMD160 is applied to exactly those 32 bytes, and a 20-byte element is
    pushed.  Concrete witnesses:
      HASH160("")  = b472a266d0bd89c13706a4132ccfb16f7c3b9fcb
      HASH160("a") = 994355199e516ff76c4fa4aab39337b9d84cf12b
  - HASH256: the preimage is SHA256'd into a 32-byte intermediate, then
    SHA256 is applied again to exactly those 32 bytes, and a 32-byte element
    is pushed.  Concrete witnesses:
      HASH256("")  = 5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456
      HASH256("a") = bf5d3affb73efd2ec6c36ad3112dd933efed63c4e1cbffcfa88e2759c144f2d8
  - the SAW-observed packed value is result=1, error=0, depth=1, the final
    width (20 for HASH160, 32 for HASH256), and the first five digest bytes.
    Alive2 observes the token chain instead: external writes are unmodelled
    memory in Alive2, so the digest-bearing functions would return a poisoned
    aggregate.  The token chain records the primitive dataflow and the
    32-byte intermediate length as defined values.
direction:
  - L ⊑ C
scr_rows: SCR-094
scr_row_coverage: full — SCR-094 is exactly the two compositions HASH160
  (RIPEMD160∘SHA256) and HASH256 (SHA256d).  Both arms are exercised on both
  legs, for an empty and a one-byte preimage; the 32-byte intermediate and the
  20/32-byte final width are part of the checked observable.  The primitive
  algorithms remain the same-hash premise, which is not part of this row's
  composition claim.
coverage: full
patches: none
source_citations:
  - interpreter.cpp:1032-1056 (hash opcode family)
  - interpreter.cpp:1049-1052 (OP_HASH160 -> CHash160; OP_HASH256 -> CHash256)
  - interpreter.cpp:1053-1054 (popstack; push_back(vchHash))
  - hash.h:32-55 (CHash256::Finalize: SHA256 into buf[32], then reset/write buf[32]/SHA256)
  - hash.h:57-78 (CHash160::Finalize: SHA256 into buf[32], then RIPEMD160 over buf[32])
  - twin/ops_ir.py OP_HASH160 (wire 0xa9), OP_HASH256 (wire 0xaa)
  - twin/runtime.inc:555-564 (hash160 = sha256 then ripemd160; hash256 = sha256 twice)
  - spec/core/Bitcoin/Interpreter/Defs.lean:637-643 (hashForOp => hashHash160/hashSha256d)
  - spec/core/Bitcoin/Interpreter/Hashes.lean (hashHash160 = hashRipemd160 (hashSha256 data); hashSha256d)
trust_note: >
  SAME-HASH CONDITION: SHA256 and RIPEMD160 are opaque externals with the
  same symbols and signatures in both legs.  Alive2 compares the token-chain
  exports, in which each primitive returns a defined 64-bit token: it
  quantifies over both primitive outputs and proves that both legs chain the
  same two primitives, in the same order, over the same 32-byte intermediate,
  and push the same final width.  It does not prove SHA256 or RIPEMD160 and it
  does not read the digest bytes.  SAW pins the first call to the concrete
  SHA256 digest and the second call to the concrete RIPEMD160/SHA256 digest, so
  the memory-level two-stage chain itself is checked against values computed
  outside both legs; those values remain assumptions with recorded witnesses,
  not derived results.  This is the proof-level counterpart of README.md (§7
  crypto seam), not a cryptographic implementation proof.  The row's
  composition skeleton is exercised in both HASH160 and HASH256 arms for an
  empty and a one-byte preimage; what is not proved is that the opaque symbols
  denote the standard SHA256/RIPEMD160 algorithms, which is exactly the
  same-hash premise.  C is a line-cited source slice of Core interpreter.cpp +
  hash.h at the pin, with the streaming hasher object abstracted to one call.
  L is a reviewed transliteration of twin/runtime.inc + twin/ops_ir.py;
  mk_leaf cannot represent the 20/32-byte push, so the cell carries the body
  unchanged with a 32-byte stack and unrolled copy (generated build/twin_ops.h
  retained for provenance).  No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - build/ (generated twin_ops.h, extracted C/L IR, build.txt)
mutant: "swap the two primitive calls in the L HASH160 body, or make HASH256 hash the preimage twice without the intermediate copy (or use a 20-byte intermediate); expect Alive2 and SAW to fail"
mutant_site: "cells/hash-ops/C-L-hash-compose/src/l_leaf.cpp l_hash160 / l_hash256"
---

# Cell `hash-ops/C-L-hash-compose`

## What is proved

Four closed memory functions per leg (HASH160 and HASH256 over the empty
element and the one-byte element `0x61`), plus four token-chain functions per
leg that Alive2 can compare with a defined observable.

- **Alive2** compares the `cell_*_chain` pairs, with each primitive abstracted
  to a 64-bit token returned by an uninterpreted external.  The first token is
  the SHA256 result over the preimage; the second primitive receives exactly
  that token and the declared 32-byte intermediate length; the second token
  fills the pushed element.  The compared observable therefore records the
  first token flowing into the second primitive with the 32-byte length, and
  the final push width.  Alive2 quantifies over all token values, so the
  order/width claim is not tied to a digest constant.
- **SAW** verifies the real memory functions (`cell_*`, not the token
  abstractions) with a two-stage override chain: the first SHA256 returns the
  concrete digest of the closed preimage; the second-stage override is keyed to
  that 32-byte digest and returns the concrete composition result.  Both legs
  are verified against the packed constant, eight proofs per leg (four memory
  functions and four token chains), sixteen in total.

The split is deliberate.  Alive2 models an external call as writing memory it
does not track and does not supply defined digest bytes, so a direct comparison
of the memory functions is not a sound way to observe the composition: the
digest value is either poison or reaches an external call as an undefined
argument.  The token chain makes the composition skeleton (order, intermediate
width, final width, pop/push) concrete as defined values, and SAW checks the
actual bytes for the recorded witnesses.

## What is not proved

- **The primitives.**  SHA256/RIPEMD160 are opaque.  The cell proves the
  composition skeleton (order, intermediate width, final width) conditional
  on the same-hash premise.  It is not a proof of the hash algorithms and not
  a proof that the symbols denote RIPEMD160/SHA256; that identity is assumed.
- **Digest bytes under Alive2.**  Alive2 checks the token dataflow, not the
  real digest bytes.  The memory composition is SAW-verified for the four
  closed witnesses, not universally.
- **C ⊑ L is not checked.**  The Alive2 run is `alive-tv C L` (L ⊑ C).  The
  reverse run does not verify because Alive2's uninterpreted-external model is
  directional here; it is not a semantic counterexample.  SAW verifies both
  legs against the same constants, which establishes equality on the recorded
  witnesses.
- **Preimages longer than one byte.**  Composition does not depend on the
  preimage length, but only lengths 0 and 1 are exercised.
- **SHA1 / OP_SHA1.**  Outside the twin subset; see
  `hash-ops/C-L-hash-widths`.

## Relation to the existing e2-hash cell

`e2-hash/hash160-vector` used a single opaque `hash160` symbol, so it did not
exercise the composition at all.  This cell splits the transform into the two
primitives and checks the chain in both arms.  It does not edit that cell.
