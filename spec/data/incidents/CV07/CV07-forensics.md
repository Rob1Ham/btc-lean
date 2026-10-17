# CV07 forensics addendum — independent anchor re-verification, 2026-10-17

Provenance: this addendum records an independent re-verification of the
CV07 Core anchors (a separate raw.githubusercontent fetch into a scratch
directory outside the repository, the wiki/tag archaeology, and an
independent re-execution of the runner). All items below are VERIFIED
unless marked PROPOSED.

## F-CV07-R1 — independent anchor re-verification (VERIFIED)

Re-fetched cce32b16 = `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
src/validation.cpp (6424 lines), src/coins.h (825), src/chainparams.cpp
(169), src/kernel/chainparams.cpp (745). Every 3e374f0 §1 anchor found
verbatim: **2401** (`fEnforceBIP30 = !IsBIP30Repeat`), **2429**
(LIMIT=1983702), **2458-2459** (`pprev->GetAncestor(BIP34Height)`),
**2461** (BIP34Hash-pin `&&=`), **2466-2475** (bad-txns-BIP30 loop,
`view.HaveCoin(COutPoint(GetHash, o))`), **6207-6211** (IsBIP30Repeat =
h∧hash 91842`..caec`/91880`..d721`), **6213-6217** (IsBIP30Unspendable
= 91722/91812), **2200-2208** (DisconnectBlock's own 91722/91812 pair +
`is_bip30_exception`), **3849-3864** (CheckMerkleRoot `mutated` →
`bad-txns-duplicate`), coins.h:**738** ("We will only get here for BIP30
checks" — the HaveCoin-overlap path corroboration).
`297000` = **0 hits** in all five files + tags v0.8.6/v0.13.1 (G1
re-confirmed); `ShouldCheckUnion`/`CheckUnion`/`fCheckDupCommit` = 0
hits (G1 re-confirmed).

## F-CV07-R2 — BIP30 wiki timeline: why "297000" never existed (G1-strengthening)

bitcoin/bips `bip-0030.mediawiki` @master (fetched 2026-10-16):
Specification = "Blocks are not allowed to contain a transaction whose
identifier matches that of an earlier, not-fully-spent transaction";
**"initially applied to all blocks whose timestamp is after March 15,
2012, 00:00 UTC (testnet: February 20, 2012 00:00 UTC)"** — the
pre-BIP30/BIP30-on boundary was a **timestamp**, not a height;
"It was later extended by commit `ab91bf39` *Apply BIP30 checks to all
blocks except the two historic violations* to apply to all blocks
except the two historic blocks at heights 91842 and 91880".
cce32b16 validation.cpp:**2397** carries that history verbatim
("originally applied to all blocks with a timestamp after March 15,
2012 ... now applied to all blocks except the two in the chain").
⇒ The expected "exact height cutover 297000-1" never existed: the
Era-A boundary was a nTime check (dropped by ab91bf39), then the
91842/91880 height∧hash grandfather (G1's "no 297000" + the wiki
together close the question). Era A "pre-BIP30" in the CV07.md §2
table = {91842-pinned, 91880-pinned} under cce32b16 (BIP90-buried)
semantics only. (Also G1-consistent: CVE-2012-1909 = the BIP30 CVE;
CVE-2013-5709 = Siemens.)

## F-CV07-R3 — tag archaeology: D2b/D2c predate cce32b16; the 1983702 limit does not

- **v0.8.6** (val@tag = main.cpp-era fetch, 4778 lines) **1630-1635**:
  `fEnforceBIP30 = (!phashBlock) || !((h==91842 && hash==..caec) ||
  (h==91880 && hash==..d721))` — the IsRepeat **height∧hash** shape is
  already in v0.8.6 ⇒ D2c (ours heights-only) is an ancient Core
  property, not a cce32b16-era regression. Loop body 1633-1635 =
  `view.HaveCoins(hash) && !view.GetCoins(hash).IsPruned()` — the
  **pre-block-view + unspent(=not-pruned)** overlap check in its
  pre-AddCoin-elision form = the most direct possible corroboration of
  **F-CV07-1** (Core checks against the pristine view, "unspent as of
  connect start"). NO BIP34-skip, NO 1983702.
- **v0.13.1** (6872 lines) **2368-2382**: IsRepeat same (2368-2371);
  **BIP34height/BIP34Hash branch-pin present at 2380** (the exact
  D2b `!pbh || pbh->hash != BIP34Hash` condition) ⇒ the D2b
  non-canonical-branch window dates to **≤ v0.13.1 (Dec 2015)**;
  **2382 = plain `if (fEnforceBIP30)`** — no `|| h >= 1983702` ⇒
  `BIP34_IMPLIES_BIP30_LIMIT` **postdates v0.13.1** (added with the
  209,921 / 490,897(=176,684) / 1,983,702 "indicated height" analysis
  whose comment sits at cce32b16 2420-2456).
  ⇒ a v0.13.1-era 4-era grid would have **no Era D** (BIP34-on =
  permanent BIP30-off); INV-106's optimization window = older
  branch-pin start (D2a/D2b) + newer 1983702 end. Era D (re-ON) is
  the youngest of the four eras; CV07.md §2's B/D-eras-identical
  verdict holds only ≥ 1983702's backport (v0.13.2+).
  PROPOSED reading (labels): D2b severity unchanged (D-MED); D2c
  note gains "ancient (≥ v0.8.6)".

## F-CV07-R4 — the D2b hash anchor, verbatim (VERIFIED)

kernel/chainparams.cpp:**119-120** (mainnet CChainParams):
`consensus.BIP34Height = 227931;`
`consensus.BIP34Hash = uint256{"000000000000024b89b42a942fe0d9fea3bb44ab7bd1b19115dd6a759c0808b8"}`
= the 2461 pin target = RC09.lean:64's BLK-070 constant (RC09 pin
correct). src/chainparams.cpp (169 lines) contains **no** BIP34 (moved
to kernel/). kernel/chainparams.cpp:**84** = the BIP90-signalled
`consensus.BIP34Height = int{height}` branch (CONTEXT-height readout),
i.e. Core itself keeps a non-constant BIP34Height path for the
signalled-activation history — 227931-as-constant (Interface.lean:78,
 BLK-070) is the buried/post-BIP90 reading. (Constant-pair corroboration
only; no row change PROPOSED.)

## F-CV07-R5 — independent runner re-execution (VERIFIED)

Read-only re-run of `CV07Runner.lean` (lean v4.35.0 toolchain binary,
`LEAN_PATH=spec/core/.lake/build/lib/lean`, `lean --run`, zero `.lake`
mutation, no lock): **exit 0**, output **byte-identical** to the
reference `CV07Runner.log` (sha256
`d8f7368e2dda8ebf71245f594c7a38e969bab2acc8caafa1d363c87fb6d250f`
both), 20 check-line PASSes (E1-E8 + D4c×4 + D4a×3 + D4d×3 + K1/K2),
0 FAIL. **Erratum on CV07.md §5:** "21/21 PASS" = **21-stated /
20-actual** (reference miscount; 8+4+3+3+2 = 20). E5 (D2a) and the
D4c/D4a rows reproduce exactly.

## F-CV07-R6 — anchor-numbering corroboration (VERIFIED)

Interface.lean:**311**'s comment anchor "validation.cpp:2496-2511" =
c50817fe numbering = cce32b16 **2466-2475** (directly read:
cce32b16 2476-2515 = BIP68/fork checks) — matches G1's
renumbering note (not a stale anchor). Runner header's "V:2466" uses
cce32b16 numbering (consistent).

## Provenance / scope

Evidence artifacts: `CV07-core-evidence.txt` (verbatim excerpts from
raw.githubusercontent at cce32b16/v0.13.1/v0.8.6 + the bips-master wiki
Specification text). The independent re-run produced a log byte-identical
to the reference `CV07Runner.log` (sha256
`d8f7368e2dda8ebf71245f594c7a38e969bab2acc8caafa1d363c87fb6d250f`
both).

Not touched: rules.yaml, era-mirror.py/.log, CV07Runner.lean/.log, and
other case directories. Links: FIND-X11-004 independently re-found D2a
("S11 BIP30 window off-by-one at 227931, cross-ref CV07 D2a") — D2a is
now confirmed by both the mirror and the runner here, plus an independent
implementation.
