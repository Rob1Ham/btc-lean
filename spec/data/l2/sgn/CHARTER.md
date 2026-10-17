# L2-SGN — differential corpus: signatures (ECDSA / sighash / Schnorr)

CLASS=sgn. Core pin cce32b16 (B-track corpus pin c50817fe; see ORACLE below).

## Scope

This directory contains the `sgn` case files, oracle references, and results.
The corresponding findings note is `spec/db/findings-edge/L2-SGN.md`;
campaign status notes are kept outside this data subset.

Out of scope: other `spec/vectors/l2/<class>/` directories, other
`findings-edge/*` notes, the non-L2 `spec/vectors/**` tree (read-only oracle
input), the Ledger/HashMap, TxValidation/Mempool, Capstone*, Bip30*, and
ErrMap definitions, the Crypto/EcdsaDeep tree (read-only; it is the object
under test), the proofs tree, and the core tree (read-only; the runner is a
separate file in this directory, launched with the no-lakefile
`lake env lean --run` route).

## Differential subject (the SGN row family, rules.yaml SGN-101..111)

The whole signature stack, front-door through the FROZEN seams:
  * ECDSA lane:   Bitcoin.Crypto.Ecdsa.Der (parseDerLax SGN-109/106,
                  isDERSignature SGN-111 BIP66-strict, isLowDERSignature
                  SGN-108) + Bitcoin.Crypto.Ecdsa.Verify (parsePubKey
                  SGN-105, verifyImpl SGN-107/110) + the interpreter
                  gate Bitcoin.Crypto.Seam.Der.checkSignatureEncoding
                  (INV-052) + Bitcoin.Interpreter.verifyScriptFull
                  (ExecError sig-family) + RealChecker's
                  realCheckerFullOf/realEcdsaEntry/sighashDispatch.
  * Sighash lane: Bitcoin.SigHash.signatureHashLegacy +
                  signatureHashBip143.
  * Schnorr lane: Bitcoin.Crypto.Schnorr.Verify.verifyImpl.
  * Taproot:      Bitcoin.Crypto.Taproot.Sighash.sigMsgGate/sighashTaproot
                  — hash-type validity matrix. NOTE SCS-B01: the
                  BIP342 sighash is a `none` stand-in at the RealChecker
                  wiring (RealChecker.lean:96-98), so taproot cases are
                  differentially tested at the E13 layer only (and the
                  full-pipeline taproot lane = lane-blocked, documented).

## ORACLE decision (checked 2026-10-17)

spec/db/findings-edge/EDGE-DIFF2.md was not present (the directory held
only EDGE-UNDO.md and GATES2.md). No bitcoind binary was available
(checked; the L2-SCR and TPR runs concurred), and no local Core-source
cache remained. => strongest available oracle = the IN-PIN Core sources +
the IN-REPO pinned corpora:

  O1  E05-anchors @ cce32b16 (spec/db/findings-dl/E05-anchors/:
      pubkey.cpp, secp256k1.c, ecdsa_impl.h) — the ECDSA-DER + parse_compact
      semantics pin. (READ-ONLY.)
  O2  L2-SCR's refs @ c50817fe (spec/vectors/l2/scr/refs/: interpreter.cpp
      2225L, script.h, script_error.h, script_tests.cpp) — the
      IsValidSignatureEncoding / CheckSignatureEncoding / CheckECDSA/
      CheckLowS / sighash / SigMsg / script-error vocabulary pin.
      (READ-ONLY; copy nothing, cite.)
  O3  the pinned, hash-pinned corpora (spec/vectors/, read-only oracle):
      core/script_tests.json 1258 rows / 45 err-kinds — the SGN-family
      rows = SIG_DER 30, SIG_PUSHONLY 5, SIG_NULLDUMMY 3, NULLFAIL 3,
      SIG_FINDANDDELETE 2, SIG_HASHTYPE 2, SIG_HIGH_S 1, PUBKEYTYPE 8
      (STRICTENC), TAPSCRIPT_EMPTY_PUBKEY 1 = 55 rows (CV06's 121-row
      malleability census = the superset incl. MINIMALDATA etc.);
      core/sighash.json 500 rows (SghVec);
      bips/bip-0340_test-vectors.csv (Bip340Vec 19);
      bips/bip-0143.mediawiki (7 worked examples);
      bips/bip-0341_wallet-test-vectors.json (keyPathSpending);
      core/tx_valid.json (DERSIG rows) / tx_invalid.json.
  O4  INDEPENDENT C-mirrors (python, independent, anti-echo: written against
      the C, never against the Lean): a `parse_der_lax_c`-style lax-DER
      oracle (E05's anchor bytes + F-E12-004's out-of-pin
      scalar_4x64 check_overflow >=n semantics read from secp256k1.c
      anchor), a BIP66 IsValidSignatureEncoding oracle (O2 bytes), a
      CheckLowS/CheckPubKeyEncoding oracle, a legacy+BIP143+SIGMSG
      sighash oracle (hashlib), and a secp256k1-shape ECDSA
      sign/verify oracle (python ecdsa-shape arithmetic, exact
      Curve/ZMod params) for witness-vector construction.
  O5  PRIOR in-repo evidence as the ORACLE-ARTIFACT/divergence catalog:
      docs/SHORTCUTS.md (S10) SCS-A01 (r/s>=n CoreZero-vs-modn, S1,
      doubly-confirmed), SCS-A12 (SINGLE_OVERFLOW_ONE 32x01 vs
      uint256::ONE, S2 OPEN-CONFIRMED), SCS-B01/B02 (taproot lane
      blocked), SCS-C03 (SGN-107 phantom vectors der-000..009),
      SCS-E07/CV06 (119/121, 2 = WITNESS_PUBKEYTYPE sc-1149/1150,
      24 script_legacy stubChecker EC artifacts = 22 "bad sig/wrong
      key/wrong value" rows = the A-tier re-judgment),
      E12.md (T1 b66GeN window witness, F-E12-003 phantom vectors),
      E05.md (F-E05-001 window), S08.md (SCS-A12 closure),
      F-Z23 (Z23/Z25 audit), F-CV06 F-2/F-3 (21 misflagged rows).

If a bitcoind harness becomes available later, these cases need not be
re-oracled: they stay reproducible (seeds + exact mirrors recorded).

## Case classes (targets; total 500+, seeded)

  A  Corpus replays (oracle = Core's own pinned rows):
     A1  script_tests SIG-family rows (55): full verifyScriptFull w/
         ERROR-KIND map (L2ScrRunner clone; scrVerdict discards the
         kind) — kind-map = SIG_HASHTATE?? no: the ExecError collapse
         (SCHNORR_SIG_SIZE/SCHNORR_SIG_HASHTYPE) = recorded facts.
     A2  the 22 stubChecker-EC-artifact rows (CV06 F-5.1: sc-1012/1016/
         1047/1102-1113) = REAL-EC re-judgment (mockChecker hid EC).
     A3  sighash.json 500 = signatureHashLegacy byte-exact.
     A4  bip-0340 19 = verifyImpl.
     A5  bip-0143 7 = signatureHashBip143 byte-exact.
     A6  tx_valid/invalid DERSIG rows.
     A7  bip-0341 wallet key-path sigMsg/sigHash (TaprootSighashTest
         7/7 re-run + an extension from the same JSON).
  B  Boundary windows (oracle = the independent C-mirrors O4 over O1/O2 bytes; the
     KNOWN divergences get their first end-to-end verdict-level cases):
     B1  r/s >= n window (SCS-A01/F-E05-001): 33-byte r=n+1 BIP66-strict-
         lax/consensus matrix (E12 T1 b66GeN's shape), 32-byte post-strip
         r>=n CoreZero window, S-polarity; Core-mirror = reject (zeroed),
         Lean = parseDerLax raw + verifyImpl %n => verdict comparison;
         plus E2E DoTest script rows (the F-E12-003 phantom der-000..009
         class, now real).
     B2  SIGHASH_SINGLE overflow (SCS-A12): SINGLE nIn>=vout rows:
         Core uint256::ONE (0x01||0^31) vs Lean 32x0x01 = digest diff +
         E2E ECDSA accept/reject (Core-valid ONE-signed sig vs Lean) =
         S2 verdict-level.
     B3  BIP66 17-guard boundary matrix (E12's G1-G3): 9..73B, sig[1],
         lenR/lenS 0/1/neg 0x80/pad 0x00, seq-len long-form, hashtype
         byte presence; Core-mirror IsValidSignatureEncoding vs
         isDERSignature + parseDerLax + E2E DERSIG-gate (Seam/Der).
     B4  LOW_S/HIGH_S (SGN-108): isLowDERSignature vs CheckLowS
         (n/2 boundary exact), high-S verify-consensus-accepts (u1,u2 ->
         -u1,-u2 invariant), 0x00||(n-s) padded forms, S=n/2 boundary,
         LOW_S flag rows E2E.
     B5  pubkey parse forms (SGN-105): 33B 02/03 (y-parity), 65B 04,
         hybrid 06/07 (parity match/mismatch), len 0/1/32/33/64/65/66,
         x>=P, off-curve, y=P-1...; parsePubKey vs pubkey.cpp parse
         (O1) mirror.
     B6  lax-DER grammar matrix (SGN-109/106): 13 reject sites
         (E05-anchors table) x the accept quirks (long-form seq-len
         skipped?? Core lax: >0x7f len byte form, zero-skip <4, neg
         payload, leading-zero pad, trailing garbage, over-32 payload =
         shared zero), parseDerLax vs mirror.
     B7  legacy sighash modes (spec "LEGACY all 6"): {ALL,NONE,SINGLE}
         x {0,ACP} x (SINGLE overflow/no) x (scriptCode 0xab-trim/no) x
         (nIn bounds) — mirror vs signatureHashLegacy; incl. hashType
         raw-bit matrix 0x00..0xff x nIn 0/max (the SIGHASH_SINGLE
         nIn<vout branch = midstate-ONE?? = B2's complement) +
         "SIGHASH hashType ?? json 0x1f-variants" (501-row ht&0x1f
         census: 0..31 x 0x80!!).
     B8  BIP143 modes: 6 modes + amount edge 0/MAX_MONEY + scriptCode
         P2WPKH (0x1976a914..88ac form) vs witness-script; mirror
         (hashlib) vs signatureHashBip143.
  C  Hash-type validity (BIP341) matrix (oracle = O2 SigMsg C-mirror):
     C1  hash_type 0x00..0xff full byte matrix (invalid high bits,
         DEFAULT=0x00, 0x02/0x03?? = SINGLE variants 0x02=?? 0x82/83
         SINGLE+ACP) x (SINGLE w/ vout bound) x (annex present/no) —
         sigMsgGate vs Core reject conditions (:1532/:1560).
  D  Fuzz/seeded (oracle = mirror): DER/sig/pk/hashes byte-stream
     mutations (seeded, recorded), E2E script rows (DoTest pair)
     through verifyScriptFull w/ kind-map.
  E  (NOT differential-testable today; documented): full-pipeline
     taproot (B01 stand-in) = cases E-lane only, lane-blocked recorded.

## Verdict vocabulary (per case)

  AGREEMENT | OUR-BUG (Lean tree wrong vs pinned Core semantics; filed
  precisely, never silently fixed) | ORACLE-ARTIFACT (the mirror/harness
  wrong; fixed + recorded) | KNOWN-DIVERGENCE (already in
  SHORTCUTS findings: SCS-A01/A12/B01...; re-confirmed verdict-
  level = new evidence, no new severity) | UNJUDGED (lane-blocked).

## Rules of engagement

  * Seeded + reproducible: every gen file carries its seed + cmd; runner
    takes case files as args (L2-SCR .l2c pattern). No lakefile edits.
  * Builds: direct-lean `cd spec/runners && timeout 240 lake env lean
    --run <abs>.lean` (no build, no lock); run in the foreground to
    completion.
  * ANTI-TRUNCATION: <=5-line message summaries, never echo file
    contents; <=60 lines new Lean per turn; small files (BLOAT guard).
  * Divergences in other components (Ecdsa/, SigHash/, Schnorr/, Taproot/,
    Interpreter/, Seam/): file precisely (case id, want, got, Core
    file:line citation), NEVER silently fix.

## Findings (candidates, pre-run)

  * SCS-A01 (B1) = the r/s>=n window: EXPECTED verdict-level OUR-BUG
    class (known); these cases give it the first END-TO-END verdict
    evidence (E12 T1 = values-level).
  * SCS-A12 (B2) = SINGLE-overflow-ONE: EXPECTED digest + E2E verdict
    divergence (S16 OPEN-CONFIRMED).
  * SCS-B01 (E) = taproot full-pipeline = UNJUDGED (lane-blocked).
  * CV06 F-5.1 (A2) = the 22 stubChecker rows = expect FULL-EC judgment
    to differ from the recorded script_legacy layer ( = the layer's
    honest stale-ness, ORACLE-ARTIFACT-CLASS?? no = the layer's
    stub-blindness (F-W16-005); the A2 re-judgment = the real-EC check).
  * SCS-C03 (B1) = the phantom der-000..009 = now real cases.
