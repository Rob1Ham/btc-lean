# CT03 PROVENANCE — the PoW/difficulty test scope at the pin

Case set: CT03, 2026-10-16.
Mined: `src/test/pow_tests.cpp` (213 lines, 13 test cases) + the scope's
implementation surface (`src/pow.cpp`, `src/arith_uint256.cpp`,
`src/test/fuzz/pow.cpp`, `src/kernel/chainparams.cpp` PoW-param block,
`src/consensus/params.h`, `validation.cpp:ContextualCheckBlockHeader`).
Run read-only through the `spec/core/Bitcoin/Block/Pow.lean`
(BLK-042..058) + `Bitcoin.Chain.Basic` (compactTarget) + the
`Bitcoin.Capstone.Pow` module (BLK-037..039). Divergences = `F-CT03-xxx`
(findings: `spec/db/findings-af/CT03.md`; vectors:
`vectors/CT03-cases.json`, runner `run/CT03Run.lean`).

## 1. Pin identity

* Repository/DB pin (ground truth): `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
  (local checkout, HEAD verified =
  `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`, "Merge bitcoin/bitcoin#36379").
* Port pin: `c50817fe` (Bitcoin.Block/Pow.lean:7 cites
  "pow.cpp @c50817fe"). The CT01 provenance (§1) established via the GitHub
  compare API: `cce32b16...c50817fe` = **ahead 2, behind 0**
  (c50817fe is 2 commits newer, linear).

## 2. Pin drift over the entire CT03 scope: ZERO

`git diff c50817fe cce32b16 -- <file>` = **empty (0 lines) for all 9
files** of the PoW scope: `src/pow.cpp`, `src/pow.h`,
`src/test/pow_tests.cpp`, `src/test/fuzz/pow.cpp`,
`src/arith_uint256.cpp`, `src/arith_uint256.h`,
`src/kernel/chainparams.cpp`, `src/consensus/params.h`,
`src/validation.cpp`. (The only tree-level c50817fe→cce32b16 diff is
`src/policy/packages.cpp`, 1 line, outside the scope.)
⇒ **The port base is byte-current with the ground truth on every file
its PoW rules read.** No B-vs-DB anchor drift in the CT03 scope.
(Re-check on next rebase; method = this diff. The local git log between the
pins is not linear (1/1); the GitHub compare API is authoritative.)

`core-src/` = verbatim evidence copies (never imported/built), blob shas
from `git ls-tree cce32b16` (see §7). `CeilDiv` (GetCompact's
arith_uint256.cpp:198) is `util/overflow.h:70`
(`dividend/divisor + (dividend%divisor != 0)`) — cited, not copied.

## 3. The 13 test cases of pow_tests.cpp @cce32b16

| case | lines | through (ours) | vectors |
|---|---|---|---|
| `get_next_work` | 18–34 | `calculateNextWorkRequired` (A1) + `permittedDifficultyTransition` (A1b) | A1 |
| `get_next_work_pow_limit` | 37–48 | same (A2/A2b) — the powLimit-cap lane (F-CT03-001 observationally invisible here) | A2 |
| `get_next_work_lower_limit_actual` | 51–65 | same (A3/A3b) + the `invalid_nbits = expected−1` negative (A3c) | A3 |
| `get_next_work_upper_limit_actual` | 68–82 | same (A4/A4b) + `expected+1` negative (A4c) | A4 |
| `CheckProofOfWork_test_negative_target` | 84–92 | `Capstone.Pow.targetOk` (B1) | **F-CT03-002** |
| `CheckProofOfWork_test_overflow_target` | 94–101 | `targetOk` (B2) | B2 |
| `CheckProofOfWork_test_too_easy_target` | 103–113 | `targetOk` (B3) | B3 |
| `CheckProofOfWork_test_biger_hash_than_target` | 115–125 | `targetOk` + BLK-039 comparison logic (B4) | B4† |
| `CheckProofOfWork_test_zero_target` | 127–136 | `targetOk` (B5) | B5 |
| `GetBlockProofEquivalentTime_test` | 138–158 | — (**unminable**: `m_rng`-random 1000 pairs) | F-CT03-004 |
| `ChainParams_{MAIN,REGTEST,TESTNET,TESTNET4,SIGNET}_sanity` | 160–211,188–211 | `Pow.lean`/`Capstone.Pow` literals + sanity bounds (D1–D7) | D |

† B4 needs `hashNatLE(SHA256d(header)) = 2·powLimit` — a 2^224-preimage
(no hash oracle); covered at the comparison-logic level only
(BLK-039's `≤` vs Core's `>` reject, pow_tests:124). `targetOk`'s
accept-side of B4 IS extractable (nBits = 0x1d00ffff passes the gate in
both).

Runner case totals ≠ 13: 31 cases = A(11: A1–A4 retarget+PDT) + B(6)
+ C(5) + D(7) + F(2). Two extra sources beyond the 13 Core tests:
* `B0` = the `EnableFuzzDeterminism` arm of CheckProofOfWork
  (pow.cpp:142) — not a pow_tests.cpp case; added as a B-group control.
* `D7` = the timewarp guard (consensus.h:35 + validation.cpp:4103–4111)
  — grouped under D (chainparams/sanity adjacency); **F-CT03-006 was
  cleared**: Core's `GetBlockTime()` is int64_t ⇒ uint32-wrap concern is
  out of domain, D7 VERIFIED non-divergent (runner note "wrap note" is
  historical).
* `F` = F1/F2 = BIP94 first-of-period retarget base (pow.cpp:67–76) —
  **PROPOSED** (pow.cpp-derived; zero Core test coverage, see §5/F-CT03-003).
* C-group (C1, C2, C2', C3, C3') = min-difficulty/walk-back lanes —
  likewise **PROPOSED** (§5).

## 4. Test-literal derivations @cce32b16 (all recomputed from the pin,
not from the test comments)

* `powLimit` MAIN/TESTNET/TESTNET4 = uint256
  `00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff`
  = **2^224 − 1** (kernel/chainparams.cpp:126, :257, :364);
  SIGNET = `00000377ae…` (:522); REGTEST = `7fff…` (:603).
  **≠ the `powLimitMainnet` literal** (Block/Pow.lean:63 =
  `0x00000000FFFF0000…` = 0xffff·2^208 = 2^224 − 2^208) and ≠
  `Capstone.Pow.powLimit` (Capstone/Pow.lean:46, same old literal,
  citing "chainparams.cpp:109 @c50817fe" — at cce32b16 kernel/
  chainparams.cpp:126 reads the 2^224−1 form; the old :109 anchor no
  longer matches). → **F-CT03-001** (literal divergence,
  observationally equivalent — see findings §A).
* `nProofOfWorkLimit` = powLimit.GetCompact() = **0x1d00ffff**
  (pow.cpp:17): SetCompact/GetCompact round trip of 2^224−1 = 0x1d00ffff
  = that of 0xffff·2^208 — the two literals are indistinguishable under
  the compact encoding (the gap (2^224−2^208, 2^224−1] contains no
  SetCompact-decodable value: 23-bit mantissa × 2^208).
* B1 nBits = powLimit.GetCompact(**true**) = 0x1d00ffff | 0x00800000 =
  **0x1d80ffff** (arith_uint256.cpp:215, mantissa ≠ 0).
* B2 nBits = `~0x00800000U` = **0xff7fffff** (nSize = 0xff = 255 > 34 ⇒
  fOverflow).
* B3 nBits = (powLimit·2).GetCompact() = (2^225−2).GetCompact():
  bits = 225, nSize = 29, low = (2^225−2)>>208 = 0x1FFFF, bit 23 clear ⇒
  **0x1d01ffff**. (Under the old literal it would be 0x1d01fffe —
  our `targetOk` rejects both; the vector is pin-robust.)
* B5 nBits = 0.GetCompact() = **0** (bits()=0 ⇒ nSize=0 ⇒ low64<<24 = 0).
* All retarget cases are MAINNET params, pindexLast built in-memory
  (heights 2015/32255/46843?? — 46367/68543), `nLastRetargetTime` =
  pindexFirst->GetBlockTime() at height nHeight−2015 (pow.cpp:42–44).

## 5. Coverage of the `fPowAllowMinDifficultyBlocks` lanes: ZERO at the pin

* pow_tests.cpp: **no** `GetNextWorkRequired`, no testnet, no
  `fPowAllowMinDifficulty` reference (grep = 0 hits). The walk-back
  (pow.cpp:31–36) and the 2×spacing min-difficulty trigger (pow.cpp:27)
  are never executed by the unit suite. (The expected
  "fPoSAllowMinDifficultyBlocks" is `fPow…` — consensus/params.h:117.)
* `test/functional/` + `test/util/`: grep `min_difficulty|min-difficulty|
  nProofOfWorkLimit` = **0 hits**.
* `test/fuzz/pow.cpp`: **`SelectParams(ChainType::MAIN)`**
  (test_fuzz_pow.cpp:23) — the fuzzer never covers the min-diff lanes
  either (nor testnet4 BIP94).
⇒ → **F-CT03-003** (coverage gap, both sides). CT03 therefore derived
  logic-level vectors C1–C5/F1 directly from pow.cpp:20–39/67–76
  semantics (marked PROPOSED, not Core-test-grounded), incl. the
  boundary lane of BLK-053 (`newTime == last.time + 2·spacing` ⇒ walk
  -back, strict `>`) and the regtest-combo fact that
  `fPowNoRetargeting` only short-circuits inside
  CalculateNextWorkRequired (pow.cpp:52) — the min-diff trigger stays
  live on regtest (Core order: pow.cpp:20 → :22).

## 6. What was run and how

`run/CT03Run.lean` (core code **read-only**, all inputs constructed
in-file; `main` at root, `open CT03 in def cases`): groups A(11:
retarget arithmetic + `permittedDifficultyTransition` bounds),
B(6: `B0` pow.cpp:142 control + B1–B5 CheckProofOfWork reject gates
through `Capstone.Pow.targetOk`), C(5: min-difficulty lanes through
`nextWorkRequired`/`minDiffWalkBack` over in-file index maps),
D(7: chainparams sanity through the `Pow.lean`/`Capstone.Pow` literals
+ D7 timewarp), F(2: BIP94 first-of-period base). **31 cases total.**

**Execution = direct-lean**, not `lake env lean --run`:
`LEAN_PATH=<checkout>/spec/core/.lake/build/lib/lean
lean --run CT03Run.lean` (toolchain leanprover/lean4:v4.35.0, against
the already-built `core` oleans). Reason: the shared build-queue lock
was heavily contended; the runner performs zero builds and zero writes
(following the established no-build procedure).
**EXIT=0**; runner log is the reference record `run/CT03Run.log`
(summary: `CT03 SUMMARY: 31 cases, 0 FAIL, 1 DIVERGENCE (recorded)`).

Results: `vectors/CT03-cases.json` (31 entries, per-case pass/fail +
detail; validated: `pass=false` = `[B1]`, `divergence=true` =
`[B1, D2]`). Divergences F-CT03-001 (D2) / F-CT03-002 (B1) pinned
in-runner as model-behavior evidence (checks `actual`, expected-Core
recorded in the JSON). Convention: `pass=false ∧ divergence=true` =
recorded intentional finding; exit 0 iff no unexpected failure.
F-CT03-006 (timewarp uint32) **cleared** — non-divergence (D7).

## 7. core-src/ manifest (blob shas @cce32b16)

| file (core-src/) | upstream path | blob sha |
|---|---|---|
| `pow.cpp` (5960 B) | `src/pow.cpp` | `9a9f4e58178b82a6741b4f5a2a8c0ef02f89d0c7` |
| `pow.h` | `src/pow.h` | `26004c46187cb683e5418b723e58036b99e9e506` |
| `pow_tests.cpp` | `src/test/pow_tests.cpp` | `e75d1e345a4a9c9eeb82e44170835d293ae7d8f2` |
| `test_fuzz_pow.cpp` | `src/test/fuzz/pow.cpp` | `b60de392892098296182b87d616ed4ba9215c218` |
| `arith_uint256.cpp` | `src/arith_uint256.cpp` | `545139900a5486e728ea0aa53953088d28747123` |
| `arith_uint256.h` | `src/arith_uint256.h` | `69e0aff8d3fe1c9511445768655e8242b159bc63` |
| `kernel_chainparams.cpp` | `src/kernel/chainparams.cpp` | `147f6d01d9126d80c9b0ec66355c357a9c37c072` |
| `consensus_params.h` | `src/consensus/params.h` | `99096e06d9a813f36675f7996094151501f8350d` |
| `validation_ContextualCheckBlockHeader_excerpt.cpp` | `src/validation.cpp:4070–4135` (excerpt, not a blob copy) | (excerpts carry no blob sha) |
| `SHA256SUMS.core-src` | sha256 of the above (except the excerpt + itself) | `ba3e1a85…305377f` |

Evidence copies only; nothing in `core-src/` is imported or built.

## 8. Divergence inventory

Findings F-CT03-001..006 in `spec/db/findings-af/CT03.md` (002 MEDIUM
= the real one: `targetOk` drops SetCompact's fNegative sign bit →
false-accept of 0x1d80ffff on the live path
Capstone/Block.lean:338-339; 001 LOW literal-only/observationally
equivalent; 003/004 INFO Core-side gaps; 005 LOW representational;
006 **cleared** non-divergence).

| artifact | sha256 (prefix) |
|---|---|
| `run/CT03Run.log` (verbatim) | `a65714d1…` |
| `vectors/CT03-cases.json` (31 cases) | `b8c67c4b…` |
| `SHA256SUMS.core-src` | `ba3e1a85…305377f` |
