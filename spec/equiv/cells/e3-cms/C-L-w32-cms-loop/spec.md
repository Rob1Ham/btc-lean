---
# Cell e3-cms/C-L-w32-cms-loop
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: the pinned rbitcoin render/error path is documented non-proof (F-HARNESS-002, F-TOOL-001)"
cell: C-L-w32-cms-loop
family: checkmultisig
tool_status: both-green (symbolic counts 0..20 and flags; 60 oracle scenarios)
precondition: |
  - The cell is the OP_CHECKMULTISIG / OP_CHECKMULTISIGVERIFY matching loop
    and tail, interpreter.cpp:1152-1225 at the pin, entered after the
    argument prelude (SCR-114's cell). Four symbolic 64-bit inputs:
      nKeys, nSigs   0 <= nSigs <= nKeys <= 20 (values outside this domain
                     return the shared marker result=3 in both legs and are
                     still compared by Alive2);
      salt           selects the position-derived element vocabulary;
      flags          bit 0 DERSIG, bit 1 STRICTENC, bit 2 LOW_S,
                     bit 3 WITNESS_PUBKEYTYPE, bit 4 sigversion WITNESS_V0,
                     bit 5 OP_CHECKMULTISIGVERIFY wire.
  - Stack shape (base/witness stack, bottom to top):
      [ dummy(empty), sig_0..sig_{nSigs-1}, nSigs, key_0..key_{nKeys-1},
        nKeys ]
    with depth nKeys+nSigs+3, exactly the successful prelude shape.
    Elements are position-derived from a fixed vocabulary, not symbolically
    arbitrary bytes:
      sig kind = (index + salt) mod 5:
        0 empty, 1 minimal DER hashtype 0x01, 2 short/invalid DER,
        3 minimal DER with a 32-byte high-S value, 4 minimal DER hashtype 0x00;
      key kind = (index + salt) mod 3:
        0 33-byte compressed 0x02, 1 65-byte uncompressed 0x04,
        2 one-byte 0x05 (invalid prefix).
  - FindAndDelete (SCR-115) happens before this slice and is not modelled
    here; the signature elements are the ones the loop reads.
  - ECDSA is NOT modelled: both legs call the same concrete deterministic
    predicate e32_check_pair(sig, pk, salt) (a bit-mix of lengths, first
    bytes and salt). This is deliberate: Alive2 does not correlate an
    external declaration across calls by argument (verified on this
    workstream: ext(x)+ext(x) vs 2*ext(x) is reported non-equivalent), so
    an uninterpreted checker would make the loop order unobservable. The
    cell therefore proves control flow and error precedence, not crypto.
postcondition: |
  - Observable (one packed uint64):
      result (bits 0..1: 1 success, 0 error, 3 out-of-domain) |
      error ordinal (2..7) | fSuccess (8) | early (9) |
      nSigsLeft (10..15) | nKeysLeft (16..21) | isig (22..27) |
      ikey (28..33).
  - Per iteration, in Core's order: read sig at stacktop(-isig), read key at
    stacktop(-ikey), CheckSignatureEncoding, CheckPubKeyEncoding, then the
    checker. An encoding error exits immediately with its ordinal:
      SIG_DER = 24, SIG_HIGH_S = 27, SIG_HASHTYPE = 23,
      PUBKEYTYPE = 29, WITNESS_PUBKEYTYPE = 44.
  - On fOk: isig += 1 and nSigsLeft -= 1; on !fOk only ikey += 1 and
    nKeysLeft -= 1. If nSigsLeft > nKeysLeft the loop stops with
    fSuccess = false (early flag when signatures remain).
  - Tail: CHECKMULTISIGVERIFY false -> EQUIV_ERR_CHECKMULTISIGVERIFY = 13;
    CHECKMULTISIG false -> EQUIV_ERR_EVAL_FALSE = 2; true -> result 1 with
    fSuccess 1.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-116, SCR-117
scr_row_coverage: full
coverage: full
patches: none
source_citations:
  - "interpreter.cpp:1152-1160 (per-sig FindAndDelete, BASE only; outside this slice)"
  - "interpreter.cpp:1163-1191 (matching loop: stacktop(-isig), stacktop(-ikey), encoding gates, checker, counters, early exit)"
  - "interpreter.cpp:1171-1174 (CheckSignatureEncoding then CheckPubKeyEncoding -> immediate error)"
  - "interpreter.cpp:1194-1205 (cmsCleanup pops i-1 items; dummy is empty and NULLDUMMY off here)"
  - "interpreter.cpp:1209-1223 (dummy pop, bool push, CMSVERIFY ordinal)"
  - "script.cpp:169-211 (IsValidSignatureEncoding), interpreter.cpp:120-167 (DERSIG/LOW_S/STRICTENC, defined hashtype)"
  - "interpreter.cpp:74-99,225-234 (compressed/uncompressed pubkey, WITNESS_PUBKEYTYPE)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:672-700 (cmsLoop), 702-718 (cmsCleanup), 1107-1127 (tail), 320-411 (encoding checks)"
  - "contract/error_kind.h:27,42,58,62,64,83 (ordinals 2,13,23,24,27,29,44)"
trust_note: >
  C is a line-cited slice of pinned interpreter.cpp specialized to the
  post-prelude loop with a fixed, in-domain stack shape. L is a reviewed
  transliteration of the Lean cmsLoop/cmsCleanup/checkMultiSig-tail
  equations and of checkSigEncoding/checkPubKeyEncoding, written from the
  equations rather than from the C slice. Alive2 compares the two
  functions as total functions of (nKeys, nSigs, salt, flags) in both
  directions; SAW re-checks both linked modules against 60 oracle-derived
  packed constants (120 proofs), including every encoding error ordinal at
  iterations 1, 2 and 3.

  SAME-CHECKER PREMISE: the ECDSA verdict is the shared concrete predicate
  e32_check_pair, identical in both legs, so the claim is "the two legs
  agree on loop order, counters, early exit and encoding precedence given
  the same verdict function". It is not an ECDSA/secp256k1 claim and it is
  not conditional on an uninterpreted external call the way the earlier
  C-L-cms-1of1 cell is. Element contents come from the fixed 5x3 kind
  vocabulary driven by (position + salt), so the encoders are compared on
  that vocabulary (all five signature gates and all three pubkey shapes are
  represented); completeness of the DER/hashtype/pubkey parsers over
  arbitrary byte strings belongs to SCR-102/104/105/106/107 and is not
  claimed here. NULLFAIL, NULLDUMMY, witness-script execution and tapscript
  are outside the cell. "full" refers to SCR-116 and SCR-117 only: 0..20
  counts are symbolic, every loop exit is reachable, and each in-loop
  encoding branch has a witness.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - build/ (twin_ops.h, c_leaf.ll, l_leaf.ll, extracted per-function IR)
mutant: "swap the signature/key encoding-check order in the loop (key first) so a pair with two invalid elements must report the other ordinal; expect Alive2/SAW to fail. Recorded in findings/wave32/20-cms-114-117/report.md"
mutant_site: "cells/_tools/w32cms/c_loop.cpp (C leg) / l_loop.cpp (L leg)"
---

# Cell `e3-cms/C-L-w32-cms-loop`

## What is proved

`cell_cms_loop(nKeys, nSigs, salt, flags)` is the CHECKMULTISIG matching
loop and its tail. Alive2 compares both legs bidirectionally for all
`0 <= nSigs <= nKeys <= 20`, all salts and all flag combinations; SAW
verifies 60 oracle scenarios (120 proofs) against both linked modules.

| Branch | Observable |
|---|---|
| encoding pass, checker true every pair | result 1, `fSuccess=1` |
| checker false, enough keys left | loop continues, `ikey`/`nKeysLeft` advance only |
| checker false, `nSigsLeft > nKeysLeft` | early stop, final false |
| sig DER invalid | ordinal 24 (with LOW_S/STRICTENC gates, DER checked first) |
| sig high-S under LOW_S | ordinal 27 |
| sig hashtype undefined under STRICTENC | ordinal 23 |
| key not compressed/uncompressed under STRICTENC | ordinal 29 |
| uncompressed key in witness-v0 with WITNESS_PUBKEYTYPE | ordinal 44 |
| false on the VERIFY wire | ordinal 13 |
| false on CHECKMULTISIG | ordinal 2 (EVAL_FALSE) |

Because the same pair can be invalid in more than one way, the result also
pins the precedence: signature encoding before key encoding, and within the
signature DER before HIGH_S before HASHTYPE. The counters
`nSigsLeft/nKeysLeft/isig/ikey` are part of the observable, so a wrong
increment (advancing `isig` on a failed check, or comparing against a stale
count) is a visible mismatch.

## SCR-116

`SCR-116 (sigs to keys in order; early fail when sigs>keys remain)` is fully
covered for symbolic counts 0..20: the loop consumes signatures in stack
order against keys in stack order, a failed check advances only the key
pointer, and the `nSigsLeft > nKeysLeft` early exit is reachable for many
(nSigs, nKeys) shapes. The verdict is the shared concrete predicate; the row
is control flow, so this is the intended abstraction.

## SCR-117

`SCR-117 (CheckSignatureEncoding+CheckPubKeyEncoding inside loop)` is fully
covered for the five gates and their in-loop placement/precedence: every
gate has a witness, they are evaluated per pair inside the loop (not once
before it), and an error aborts before the checker and before any counter
increment. The encoders' internal completeness over arbitrary byte strings
is the subject of SCR-102/104/105/106/107, not this row.

## Directions

`alive2/result.txt` uses `alive-tv --bidirectional` (L ⊑ C and C ⊑ L);
`--smt-to=600000` is required for this cell. Both legs are compiled at -O2
for the Alive2 lane. At -O1 clang tags the `while` loop with
`llvm.loop.unroll.disable`; Alive2 v20.0 then does not unroll it and treats
executions that leave the loop as unconstrained, which produces a vacuous
green (measured: the encoding-order mutant in §4 of the wave report came
back "correct" at -O1 and is caught at -O2). SAW proves each leg against the
same oracle constants in one build (-O0). No R leg or whole-engine claim is
made.
