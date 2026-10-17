# CV06 — BIP62-era malleability: boundary and checker verdicts

Purpose: (1) classify BIP62/CVE-2015-3641-adjacent malleability vectors
consensus vs policy (Core cce32b16 ground truth); (2) run consensus-class
mutants through the Lean checker; (3) map to rules.yaml rows (READ-ONLY),
flag rows claiming consensus where Core is policy. Data:
spec/data/incidents/CV06/; findings: spec/db/findings-af/CV06.md.

## Boundary (Core, pinned)

- GetBlockScriptFlags (validation.cpp:2267-2275 r06) sets per height:
  P2SH, WITNESS, (post-BIP66) DERSIG, (post-BIP65) CLTV, (post-BIP147)
  NULLDUMMY, (post-CSV) CSV, (post-BIP341) TAPROOT.
- policy.h:104-111 (r06): MANDATORY = P2SH|DERSIG|NULLDUMMY|CLTV|CSV|WITNESS|TAPROOT.
- LOW_S, STRICTENC (hashtype + pubkey), MINIMALDATA (push + CScriptNum),
  SIGPUSHONLY, CLEANSTACK (legacy), NULLFAIL, MINIMALIF (v0),
  CONST_SCRIPTCODE FindAndDelete, DISCOURAGE_UPGRADABLE_NOPS = POLICY.
- Consensus since activation: BIP66 strict DER (IsValidSignatureEncoding),
  BIP65 CLTV (not malleability), BIP147 NULLDUMMY, tapscript MINIMALIF
  (SCR-183), BIP341 witness non-malleability (wtxid commit), 64B-tx guard.

## Vector classes (BIP62 rules 1..6 + CVE-2015-3641)

| id | vector | Core class | check |
|----|--------|-----------|-------|
| MAL-01 | non-minimal push (PUSHDATAx for small data) | policy (MINIMALDATA) | SCR-048/049 |
| MAL-02 | non-minimal scriptnum (0x9500 vs 0x85, extra zero) | policy (BIP62 r4) | SCR-050/084 |
| MAL-03 | HIGH-S ECDSA (s > n/2) | policy (BIP62 r5) | SCR-104 |
| MAL-04 | non-canonical DER (pad zero, neg R, len>33) | CONSENSUS post-BIP66 (363725) | SCR-102/103 |
| MAL-05 | undefined hashtype byte | policy (BIP62 r5) | SCR-105 |
| MAL-06 | non-canonical pubkey (hybrid, uncompressed mod) | policy (STRICTENC) | SCR-106 |
| MAL-07 | non-empty CHECKMULTISIG dummy | CONSENSUS post-BIP147 (461824) | SCR-0??/INV-050 |
| MAL-08 | scriptSig trailing junk / non-push opcodes | policy (SIGPUSHONLY r2); scriptSig≠spk concat = consensus (CVE-2010-5141) | SCR-010 |
| MAL-09 | scriptSig trailing bytes on P2SH (non-push tail) | policy (P2SH std) | SCR-005/006 |
| MAL-10 | empty scriptSig on P2SH/witness | structural verdict | — |
| MAL-11 | witness-dup (extra witness on legacy tx) | CONSENSUS (WITNESS) | SCR-011 |
| MAL-12 | unexecuted-branch junk (OP_IF f | policy (MINIMALDATA r3) | SCR-049 |
| MAL-13 | non-empty-failed-sig (NULLFAIL) | policy (BIP146) | SCR-110 |
| MAL-14 | sighash-scriptcode FindAndDelete variant | policy (CONST_SCRIPTCODE) | SCR-099/100 |
| MAL-15 | CHECKMULTISIG dummy non-empty (pre-BIP147) + SIGHASH | — | — |

CVE-2015-3641 (bip62-lite): the pre-BIP62/66 stack vars = uncontrolled
mempool mutability; node eventually hard-forked SPV (bip62-lite patch).
Only BIP66/65 + BIP147 landed CONSENSUS; rules 2/3/4/5/parts = policy.

## Method (runner: vectorrunner / BitcoinVectors)

A) CASE PACK: spec/data/incidents/CV06/mal-pack.json (a self-contained
   corpus in Core script_tests style) + Python driver
   incidents/CV06/run_mal.py building ScrVec records verbatim in runner
   syntax + `lake build vectorrunner` + verdicts into
   incidents/CV06/results.json (no other corpora touched).
B) POL-PROBE: FLIP trick (O6) = for each consensus-class mutant build
   the pack rows twice (policy ON, OFF) + diff. LOW_S acceptance probe:
   canonical DER-tail high-S construct + (Core-faithful) checkLowS = false
   (RC05 impl) + (inductive Core stub) = ACCEPT (SGN-108 says consensus
   never normalizes). Assert Lean misses NONE.
C) ScriptPushOnly/hex fake rows: skip (full corpus rerun = >20min).
D) POLICY-ONLY rows: F2 = pass x2 (DERSIG-only, DERSIG|policy) diff =
   reject-diff asserts POLICY-honesty [not Core dishonesty].
E) Findings: spec/db/findings-af/CV06.md (VERIFIED/PROPOSED split).

## Constraints

- rules.yaml = READ-ONLY (report F-findings w/ row IDs).
- The case set is self-contained; no other case directory is edited.
- Run builds in the foreground only.
- No scrub vectors (KeyNode verify() drops ps vs ps.compose).
- No Core rollbacks mid-transaction.
