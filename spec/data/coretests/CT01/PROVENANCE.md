# CT01 PROVENANCE — the pinned tree, the two pins, and what is where

Case set: CT01, 2026-10-16. Evidence file; every claim
below is reproducible against the captured material in `core-src/`.

## 1. Pin identity

* Repository/DB pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
  (GitHub API `GET /repos/bitcoin/bitcoin/commits/cce32b16` = 200,
  `"sha": "cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66"`;
  `spec/core/lakefile.lean`: "Ground truth: Bitcoin Core v32.99 @
  `cce32b16` (traceability DB pin; **B-track line anchors for B2–B5 were
  taken @ `c50817fe`**, re-verify on rebase)").
* B-track anchor pin: `c50817fe` (short; full sha unrecorded here —
  resolves via the API; `bitcoin/bitcoin/c50817fe/src/consensus/merkle.cpp`
  = 200).
* Relationship (GitHub compare API `cce32b16...c50817fe`):
  `"status": "ahead", "ahead_by": 2, "behind_by": 0`
  → `c50817fe` is **2 commits newer** than the repository pin.

## 2. Pin drift over the entire CT01 scope: ZERO

Byte-identical between `cce32b16` and `c50817fe` (local `diff`):
`src/consensus/merkle.cpp`, `src/merkleblock.cpp`, `src/merkleblock.h`,
`src/test/pmt_tests.cpp`, `src/test/merkleblock_tests.cpp`,
`src/test/merkle_tests.cpp` (copies `c50817fe_*` in `core-src/`).
No B-vs-DB anchor drift in the merkle/merkleblock/PMT scope at these two
pins. (Re-check on the next rebase; method = this diff.)

All `core-src/` copies were verified byte-exact against the pinned git
**tree blob shas** (sizes match tree entries; shas in README.md; local
file hashes in `SHA256SUMS.core-src`).

## 3. `pmt_tests.h` does not exist at the pin

* `raw.githubusercontent.com/bitcoin/bitcoin/cce32b16/src/test/pmt_tests.h`
  → **404** (also `test/util/pmt_tests.h`, `src/test/pmt.cpp`,
  `src/test/fuzz/pmt.cpp` → 404).
* The PMT tests live in **`src/test/pmt_tests.cpp`**
  (tree blob `da955b3f63373acc4d5d2a5d7f501641f58490f6`, 4612 bytes,
  128 lines; `grep tree.json` evidence line 19260).
* Contents: `pmt_test1` (pmt_tests.cpp:34-109) and
  `pmt_malleability` (pmt_tests.cpp:111-126) — two test cases, not a
  header. There is **no `pmt_tests.h`** and no `pmt.cpp` fuzz target at
  the pin; the fuzz coverage is `test/fuzz/merkleblock.cpp` (2020,
  crash-only) and `test/fuzz/merkle.cpp` (2025, semantic: merkle-path
  replay == root). Recorded as a scope-divergence note
  (F-CT01-001).

## 4. The two merkleblock test vectors (merkleblock_tests.cpp, 81 lines)

* `merkleblock_construct_from_txids_found` (:19-52): block from
  `getBlock13b8a()` (`src/test/util/setup_common.cpp:678-690`, excerpt
  in `core-src/setup_common_getBlock13b8a_excerpt.cpp`), a real mainnet
  block — `0000000000013b8ab2cd513b0261a14096412195a72a0c4827d229dcc7e0f7af`
  (comment :679) with **9 txs** (:680). txhash1 = last txn (idx 8) =
  `74d681e0e03bafa802c8aa084379aa98d9fcd632ddc2ed9782b586ec87451f20`
  (:24), txhash2 = second txn (idx 1) =
  `f9fc751cb7dc372406a9f8d738d5e6f8f63bab71986a39cf36ee70ee17036d07`
  (:28). `CMerkleBlock(block, {txhash1,txhash2})` (std::set, sorted →
  insertion order {txhash2, txhash1}); `vMatchedTxn.size()==0` (no
  bloom filter); `ExtractMatches` root == `block.hashMerkleRoot` (:46),
  `vMatched.size()==2`, **DFS-ordered**: `vMatched[0]==txhash2`,
  `vIndex[0]==1`, `vMatched[1]==txhash1`, `vIndex[1]==8` (:49-52).
* `merkleblock_construct_from_txids_not_found` (:57-79): same block,
  txid `c0ffee00003bafa802c8aa084379aa98d9fcd632ddc2ed9782b586ec87451f20`
  (:63); `ExtractMatches` root **still equals** `block.hashMerkleRoot`
  (:71), `vMatched.size()==0`, `vIndex.size()==0` (:72-73) — the
  not-found proof authenticates (empty match, root-only PMT).

## 5. The pmt_malleability vector (pmt_tests.cpp:111-126)

12 txids: `uint256{1}..uint256{10}` followed by **duplicates** of
`uint256{9}` and `uint256{10}` (:113-120) — i.e. leaf values
`[1,2,3,4,5,6,7,8,9,10,9,10]`, so leaves `[8..12) = [9,10,9,10]` are the
merkle.cpp:16-50 CVE-2012-2459 mutation shape on the very same data.
`vMatch` = only positions 9,10 true (:121). Expected:
`tree.ExtractMatches(vTxid, vIndex).IsNull()` (:125) — the non-canonical
PMT is rejected by `TraverseAndExtract`'s identical-branches check
(`merkleblock.cpp:124-128`, `fBad = true`), NOT by any hash mismatch.

`pmt_test1` (:34-109) is a **randomized** test (BasicTestingSetup
`m_rng`, unspecific seed): 12 tx-counts {1,4,7,17,56,100,127,256,312,
513,1000,4095} (:36) x 14 inclusion rates att=1..14 (:61,
`randbits(att/2)==0`); block txs are dummy `CMutableTransaction`s with
`nLockTime = j` (:44-46). It carries no literal vectors; CT01 mines it
as DETERMINISTIC re-derivations (see the mirror's `pmt_test1_deterministic`
family + exhaustive subsets for the small counts). Note the test's
`nHeight` (:54-58) counts levels (merkleblock.cpp:143-145 height + 1).
The size bound (:80-81) `ss.size() <= 10 + (258*n+7)/8` with
`n = min(nTx, 1 + vMatchTxid1.size()*nHeight)` = merkleblock.h:40-54
`SIZE <= 10 + ceil(32.25*N)` with `N <= 1 + matched*tree_height` (:46).
The Damage() auth check (:23-27, :100-106) flips ONE random bit
(`randbits(8)` → bit 0..255 → byte `bit>>3` 0..31, mask `1<<(bit&7)`)
in one random **vHash** entry of a deserialized copy; 4 rounds per
(att, nTx); expected root != merkleRoot1. NB: `vBits` bit-flips are
never tested in Core (Damage touches vHash only) — CT01 mines them
(F-CT01-006).

## 6. In-repo anchor state at capture time (21:30, 2026-10-16)

`spec/core/Bitcoin/Capstone/Merkle.lean` (the CT01 mirror target) and
21 other spec files were **uncommitted-modified in the working tree**
by concurrent work (`git status` @ `583b463`); CT01 never edits them.
The CT01 mirror anchors the `cce32b16` pin and the working-tree defs as
built at the timestamps in `run/`'s build; any later in-flight change to
`pairHash`/`merkleRootOf` semantics must re-run `CT01-pmt-mirror.py` + the
`ct01pmt` exe (README "re-verify on rebase").
