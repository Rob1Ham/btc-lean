---
# Cell C-L-cms-nullfail-loop (wave64 / 58-cms-nullfail-loop)
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted (out of this task's scope: findings/cross/F-HARNESS-002, findings/tools/F-TOOL-001)"
cell: C-L-cms-nullfail-loop
family: checkmultisig
tool_status: "both-green (loop+cleanup unroll nKeys <= 2; 2 SAW cases)"
precondition: |
  - The cell is the OP_CHECKMULTISIG arm from the counts into the cleanup scan
    and the dummy/push tail, interpreter.cpp:1132-1215 at the pin, entered
    after the argument prelude.  The prelude itself (script-num decode, size
    checks, FindAndDelete) is SCR-114/115's cells; the counts are inputs.
  - Counts: 0 <= nSigs <= nKeys <= 2.  The verification loop is unrolled
    twice and the cleanup scan six times (i-1 = nKeys+nSigs+2 <= 6).  The
    row's domain allows nKeys <= MAX_PUBKEYS_PER_MULTISIG = 20, so the cell is
    PARTIAL: the residual is exactly nKeys in [3,20] (see notes.md and the
    wave64 report).
  - flags = SCRIPT_VERIFY_NULLFAIL | SCRIPT_VERIFY_NULLDUMMY only
    (`nullfail` and `nulldummy` are symbolic 0/1 inputs), sigversion BASE.
    DERSIG, LOW_S, STRICTENC and WITNESS_PUBKEYTYPE are clear, so
    CheckSignatureEncoding and CheckPubKeyEncoding return true without
    inspecting the element (interpreter.cpp:120-167) and are not part of this
    slice; the enc-loop cell owns their call sites.
  - Stack, top-down: nKeys count (len 1), nKeys pubkeys (len 1), nSigs count
    (len 1), nSigs signatures (emptiness slots sig0/sig1, so position 0 and
    position 1 can differ), dummy (len dummylen).  All non-signature items are
    deliberately non-empty, so a gate that fires on the wrong item changes the
    observable.  There is no item below the dummy: the surviving-prefix shape
    is the tail cell's (with NULLFAIL off).
  - ikey2 = nKeys+2 (1135) and i = nKeys+nSigs+3, so the scan performs
    i-1 pops; at pop p the tested (pre-decrement) ikey2 is nKeys+2-(p-1),
    clamped at 0 because Core only decrements while ikey2 > 0 (1198-1199).
  - The checker is the family's one abstract seam symbol
    (btc_equiv_check_sig), the same symbol in both legs: Alive2 quantifies
    over its verdict; SAW links two concrete instances (always false, always
    true).
postcondition: |
  - NULLFAIL site (1196-1197): the gate fires iff, at some pop p,
    !fSuccess && NULLFAIL && ikey2(p) = 0 && the current top item is
    non-empty.  In this stack that is exactly the signature region
    p >= nKeys+3, the tested ikey2 is 0, and the ordinal is
    SIG_NULLFAIL = 32.  It precedes the NULLDUMMY arm (28) and the boolean
    push, and no pop is performed on the failing step.
  - Otherwise the scan performs i-1 = nKeys+nSigs+2 pops; then the dummy is
    on top.  NULLDUMMY && dummylen != 0 -> SIG_NULLDUMMY = 28 (contents never
    read); else the dummy is popped and vchTrue/vchFalse is pushed (the
    continuation; VERIFY's true-pop and the script-end EVAL_FALSE are the
    tail cell's rows).
  - Packed observable (src/cms_nullfail_obs.h): result (0/1/3), error
    ordinal, pops actually performed, fire position, ikey2 at the test,
    item-length bucket at the fire position, depth after the pops, dummy
    length bucket, pushed boolean, final depth, fSuccess entering the scan.
    Both legs return the same packed value for every 7-tuple of inputs, in
    both directions.  Witnesses (checker false): 1-of-1, NULLFAIL on,
    non-empty signature -> {err 32, popped 3, firePos 4, ikey2 0, fireLen 1,
    depthAfter 2, fsv 0} = 0x10484380; same but empty signature, or with
    NULLFAIL off -> 0x20370401 (popped 4, pushed false); 2 keys / 1 empty
    signature / NULLFAIL on / NULLDUMMY on / non-empty dummy -> err 28 =
    0x12370570 (the NULLFAIL arm is before the dummy arm and does not fire on
    an empty signature); checker true -> 0x68370401 (pushes true).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-110
scr_row_coverage: partial
coverage: partial
patches: none
source_citations:
  - "interpreter.cpp:1132-1135 (ikey; ikey2 = nKeysCount + 2)"
  - "interpreter.cpp:1140-1148 (nSigsCount parse and range check)"
  - "interpreter.cpp:1163-1191 (loop: pair selection, checker, counters, nSigsCount > nKeysCount early exit)"
  - "interpreter.cpp:1194-1201 (cleanup scan: NULLFAIL arm 1196-1197, ikey2-- 1198-1199, popstack 1200)"
  - "interpreter.cpp:1209-1210 (empty stack -> INVALID_STACK_OPERATION; unreachable in domain)"
  - "interpreter.cpp:1211-1212 (NULLDUMMY arm reads only stacktop(-1).size())"
  - "interpreter.cpp:1213-1215 (dummy pop; push vchTrue/vchFalse)"
  - "interpreter.cpp:120-167 (encoding validators are no-ops when their policy flags are clear)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:672-700 (cmsLoop)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:702-718 (cmsCleanup: nullFail/ikey2/size arm)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1091-1127 (checkMultiSig call sites, nullDummy, pushBoolV)"
  - "spec/proofs/BitcoinProofs/AF/PDW18/INV051.lean (cmsCleanup guard lemmas at this site)"
  - "contract/error_kind.h:33,29 (SIG_NULLFAIL=32, SIG_NULLDUMMY=28)"
  - "spec/db/rules.yaml SCR-110"
trust_note: >
  SAME-CRYPTO PREMISE (docs/DECISION-lax-ecdsa.md) for the checker: fSuccess
  is the abstract btc_equiv_check_sig verdict, so the cell proves the
  cleanup's treatment of the loop verdict for every verdict, not ECDSA/
  secp256k1 agreement.  The encoding validators are NOT abstracted here: the
  cell fixes flags to NULLFAIL|NULLDUMMY, where Core's validators return true
  immediately (interpreter.cpp:120-167), which is a flag-configuration
  restriction rather than a second seam.  C is a line-cited slice of pinned
  Core; L is a reviewed transliteration of cmsLoop/cmsCleanup/checkMultiSig,
  not generated by twin/gen.py.  The packed trace beyond bits 0..7 is harness
  instrumentation (like the family's other *_pack helpers); the engine
  observable is (result, error ordinal).  The row is PARTIAL because the
  counts are bounded at two keys (the domain allows 20); the exact residual is
  nKeys in [3,20], where both the loop body count and the scan length exceed
  the unroll.  Signature *contents* are not modelled beyond emptiness, which
  is exactly what the guard reads; checker/element encoding is the family's
  shared 32-bit word.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - build/ (both legs' IR, linked SAW modules per case, build.txt, spec_c*.saw)
mutant: "drop !ikey2 (fire on the nKeys count), test ikey2 after the decrement (fire on the nSigs count), or drop the non-empty-signature guard (fire on an empty signature); expect Alive2 and SAW to fail"
mutant_site: "cells/checkmultisig/C-L-cms-nullfail-loop/src/c_cms_nullfail.cpp"
---

# Cell `C-L-cms-nullfail-loop`

## What is proved

The second half of SCR-110: the CHECKMULTISIG cleanup scan's NULLFAIL arm
(`interpreter.cpp:1196-1197`).  The cell starts at the parsed counts, runs the
verification loop far enough to produce `fSuccess` (two bodies), then replays
the scan with Core's `ikey2` bookkeeping and ends at the boolean push.  It
proves where the arm sits: only the signature region sees `ikey2 == 0`
because `ikey2` starts at `nKeys+2` and is decremented *after* the test, so a
failing non-empty signature returns `SIG_NULLFAIL = 32` before any pop and
before the NULLDUMMY arm, while an empty signature, NULLFAIL off, or a
successful loop continue to the dummy gate and the `vchFalse`/`vchTrue` push.

Alive2 compares the two leg IRs with the checker uninterpreted, so both loop
verdicts are covered; SAW links the family stub (case 0 false, case 1 true)
and checks each leg against `saw/model.cry`, an independent Cryptol oracle
written from the Core lines and the Lean equations.

## Why `partial`

The row's domain allows up to `MAX_PUBKEYS_PER_MULTISIG = 20` keys.  This cell
unrolls the loop twice and the scan six times, so it covers
`0 <= nSigs <= nKeys <= 2` exactly, and the scan's `ikey2` arithmetic is
symbolic in the counts only over that lattice.  The residual is exactly
`nKeys in [3,20]` (and the corresponding `nSigs`): both the loop trip count and
the scan length exceed the unroll.  Closing it needs a 20-body loop unroll (or
a symbolic-trip-count scan with a SAW loop invariant, which the family's
harness does not currently support).  Everything else the row states at this
site -- the `!ikey2` position gate, the pre-decrement order, the non-empty
guard, the error ordinal and its precedence over NULLDUMMY -- is proved for
the unrolled domain.

## Limits

- `nKeys <= 2`, `nSigs <= nKeys`; no item below the dummy.
- flags fixed to NULLFAIL|NULLDUMMY (the validators are no-ops there).
- Signature contents reduce to emptiness at the seam (the guard reads only
  `size()`); the checker verdict is the same-crypto premise.
- CHECKMULTISIGVERIFY's true-pop and the script-end EVAL_FALSE tail are the
  tail cell's SCR-120.
