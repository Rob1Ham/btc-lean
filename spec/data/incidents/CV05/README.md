# spec/vectors/incidents/CV05 — the CVE-2012-2459 merkle-malleability FAMILY

Case set CV05, 2026-10-16. The original 2012-2459 shape (odd-tail
duplication = root equality) is covered separately; this set covers the
**variant mutation shapes**, the Core fix history, and the
BLK-010/008/011 row-coverage gap check. (The expected
"CVE-2016-10725" is the alert-system DoS, NOT merkle — F-CV05-001.)
Findings: `spec/db/findings-af/CV05.md`.

## Files

- `shapes.py` — 19-shape mutation corpus + **3-way python mirror**:
  `core2012` (end-pair-only detector, the code eece63fa72 2015-11-17
  removed from primitives/block.cpp, preserved in merkle_tests.cpp:28-53)
  / `coreNow` (Core @cce32b16 merkle.cpp:51-73; = the cve_replay
  mirror verbatim) / `leanOurs` (our BLK-011: pair-aligned equal-pair
  `levelHasAdjacentDup` × `merkleMutationFree`, i.e. the same
  even-offset `hashes[2i] == hashes[2i+1]` scan as `coreNow`). Writes
  `shapes.json` (roots + per-row verdicts + the sweep invariants).
- `gen_lean.py` → `../../runners/Test/Incidents/CV05Fam.lean` — 19 rows
  × 3 #evals over the REAL seam (`merkleRootOf`, `merkleFailureKind`).
- `lean_run.log` — the #eval run (green, 0 errors).
- `crosscheck.py` — python-mirror ↔ real-Lean ↔ Core: C1-C5 zero
  failures; C6a = 0 ours-over-strict rows after the BLK-011 pair
  alignment (pre-fix: 7); C6b = the 2012-vs-2015 footprint (exactly
  `EF-nontrailing` [1,1,3,4]).

## The matrix in one look (19 shapes, leaves dsha256("cv05-leaf-i"))

| class | rootEq | c2012 | cNow | ours | Core verdict |
|---|---|---|---|---|---|
| honest control | true | no | no | no | ACCEPT |
| 2^ctz-tail (T1o3/T1o5/T26/T2_10/T4_12) | **true** | yes | yes | yes | bad-txns-duplicate |
| 1-tail-on-even (T1e-2/4/6 = the mut-even shape) | false | no | no | no | bad-txnmrklroot |
| non-2^k tail (T2-12/T4-8/T8-16) | false | no | no | no | bad-txnmrklroot |
| nontrailing/interior (NL-*) | false | no | no | no | bad-txnmrklroot |
| EF-nontrailing [1,1,3,4] | false | **no** | **yes** | yes | bad-txnmrklroot |
| EF-oddspan [1,2,2,4] | false | no | no | no | bad-txnmrklroot |
| whole-tree (TF-4) | false | yes | yes | yes | bad-txnmrklroot |

- root-equal attacks = exactly `tail(2^ctz(n))` (5/5 #eval'd root-eq
  in real Lean); **BLK-010 alone accepts all 5** — BLK-011 catches 5/5
  and is wired into `validateBlock` as `merkleMutationOk`; no honest
  false positive (19/19 bases plainMismatch).
- after the pair-aligned fix `ours` agrees with `cNow` on all 19 shapes:
  the former 7 over-strict rows (odd-k 3-in-a-row [X,Y,Y] family =
  Z03's F-Z03-004 extended cross-level) are now plain
  `bad-txnmrklroot`, exactly Core's even-offset scan.
- 2012→2015 hardening's entire corpus footprint = [1,1,3,4]
  (nontrailing); regression test `merkle_test_mutated_return_value`
  born **2026-04-26 ef501a63d** "document merkle mutation root
  invariant" (post-dates every "2016" reading).

Provenance and fix history: findings-af/CV05.md F-CV05-002.
