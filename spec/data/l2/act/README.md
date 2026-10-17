# L2-ACT — differential vectors, CLASS=act (softfork activation boundaries)

This directory contains the class=act cases. Findings:
`spec/db/findings-edge/L2-ACT.md`; campaign status notes are kept outside
this data subset.

## Scope
- In scope: `spec/vectors/l2/act/**` (this tree).
- Out of scope: `spec/vectors/l2/{scr,txv,swt,tpr,blk,bound,fuzz,replay}/`,
  the non-L2 `spec/vectors/**` tree, other `findings-edge/*` notes, the
  Ledger/HashMap, TxValidation/Mempool, Capstone*, Bip30*, and ErrMap
  definitions, the E14 and PDW17-20 workstreams, and any shared Lean tree
  file (the runner is a separate file importing frozen interfaces only;
  zero core writes).

## Oracle
- (A) refs/ = pinned Bitcoin Core @ cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66,
  curl-fetched (following the L2-SCR precedent): validation.cpp, versionbits.cpp/h,
  deploymentstatus.h, kernel/chainparams.cpp/h, consensus/params.h,
  kernel/chain.h, consensus/consensus.h?? (see ls), validation.h,
  test/versionbits_tests.cpp. Semantics pin; line cites in mirrors/findings.
- (B) L2ActMirror.py = independent want-generator, verbatim-cited
  transliteration (NO Lean reuse). (C) versionbits_tests.cpp sequences.
- NO bitcoind binary; the findings-edge directory was empty at start
  (the campaign decision record was not present) — decision documented,
  reproducible, seeded.

## Result
- 399 cases / 394 AGREE / 5 DIVERGE (all 5 = documented D2b/D2c
  non-canonical-branch gaps of the heights-only Ledger face).
- `cases.jsonl` + `results.tsv` are included; see
  `spec/db/findings-edge/L2-ACT.md` for the analysis.
- reproduce: `python3 L2ActMirror.py` then
  `cd ../../.. && lake env lean --run vectors/l2/act/L2ActRunner.lean
  vectors/l2/act/cases.jsonl vectors/l2/act/results.tsv` (from spec/).

## DUT (read-only imports)
Bitcoin.Activation.Interface (getBlockScriptFlags, bip9State/thresholdState,
buried heights), Bitcoin.Activation.Flags (getBlockScriptFlagsP,
mainnetExceptionMap, flagBits), Bitcoin.Activation.Bip9 (versionBitsSignals,
mainnetTestdummy), Bitcoin.Ledger.Interface (bip30Enforced), Bitcoin.
Block.Bip30Nuance (isBip30Repeat, isBip30UnspendableInline, bip34PinHolds,
coreBip30Enforced, coreBip30LoopRuns), Bitcoin.Capstone.Block (versionOk,
bip34Ok), Bitcoin.Block.Connect (finalityCutoff, blockSequenceLocksOk).

## Case classes
F  getBlockScriptFlags/getBlockScriptFlagsP — BIP34@227931(±1), BIP66@363725,
   BIP65@388381, CSV@419328, SegWit@481824, all H±1 (+H±2), exceptions
   170060/692261 ±1, hash-vs-height faces, UInt32 extremes.
B  BIP30 windows — ConnectBlock fEnforceBIP30 face @ 91722/91812 (Disconnect
   pair), 91842/91880 (Repeat pair), 227929..227933 (D2a), 1983700..1983704
   (BIP34_IMPLIES_BIP30_LIMIT), fork faces (anc227931 hash ≠ BIP34Hash =
   D2b), own-hash faces (D2c).
V  versionOk @ 227930..227932/363724..363726/388380..388382 × v∈{1,2,3,4,5};
   bip34Ok @ 227930..227932 (+481824) × cbHeightPush faces (h-1/h/h+1,
   nonminimal, short).
S  BIP113 finalityCutoff mux + blockSequenceLocksOk(csvFlag) @ 419327..419329
   (CSV ActiveAt = 419328 face).
B9 BIP9 TESTDUMMY window edges — thresholdState/bip9State machine: period
   alignment (h+1)%p edges, start edges, count = thr-1/thr/thr+1,
   deadline = bnd-1/bnd/bnd+1 (BLK-077 count-beats-timeout), min_activation
   (BLK-078), sentinels, period 0, mainnetTestdummy pins, versionBitsSignals
   faces, versionbits_tests.cpp sequences (normal/delayed/always/never).
E  SCR-016 — the two named mainnet script-flag-exception blocks (170060
   02dc…→NONE, 692261 0f14…→P2SH|WITNESS): hash/height/right/wrong faces.

## Reproducibility
Every cases_*.txt: header = seed + gen cmd (L2ActMirror.py). Runner:
`cd <checkout>/spec/runners && timeout 240 lake env lean --run
<abs>/L2ActRunner.lean <lane> <cases.txt>...` (direct-lean, no build).
Output rows: `id|got|want|verdict(AGREE/DIVERGE)` -> results_*.txt.
