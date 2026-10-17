# 08 — Block-level consensus: structure, PoW/retarget, chain/UTXO state transition, soft-fork activation, genesis

**Workstream:** B4 / report 08 · **Project:** btc-lean · **Date:** 2026-10-16
**Ground truth:** bitcoin/bitcoin cloned at **commit `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`** (master, merged 2026-10-16, "Merge bitcoin/bitcoin#36535: policy: sum package weight in int64_t").
NOTE: the brief pinned `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`; the actual `--depth 1` clone HEAD at task time was `cce32b168…`. Version: **v32.99** (master, pre-33; `CMakeLists.txt:30-31` `CLIENT_VERSION_MAJOR 32`, `CLIENT_VERSION_MINOR 99`). All `validation.cpp` line numbers below are at this commit.

---

## Executive summary

1. The block validation pipeline decomposes cleanly into **four layers** Core itself already names: `CheckBlockHeader` (validation.cpp:3836) → `CheckBlock` (stateless, :3926) → `ContextualCheckBlockHeader`/`ContextualCheckBlock` (:4088/:4137) → `ConnectBlock` (UTXO state, :2294). This layering is *exactly* the pure-check / stateful-split btc-lean needs; the stateful part is confined to `ConnectBlock`, `DisconnectBlock`, `UpdateCoins`, and the coins cache.
2. **PoW** is two small pure functions: nBits compact decode (`arith_uint256::SetCompact`, arith_uint256.cpp:176 — sign/exponent/mantissa with the fNegative/fOverflow cases) and `CheckProofOfWorkImpl` (pow.cpp:161, `hash ≤ target`, plus `DeriveTarget` bounds :146). Retarget is `GetNextWorkRequired`/`CalculateNextWorkRequired` (pow.cpp:14/50): 2016-block window, ×/4 and ×4 clamp, powLimit ceiling, plus `PermittedDifficultyTransition` (:89) as a *header-side* re-derivation check.
3. The **merkle root rule includes CVE-2012-2459** as a first-class rule: `ComputeMerkleRoot(..., &mutated)` (consensus/merkle.cpp:51) flags *any* level containing an identical adjacent pair; `CheckMerkleRoot` (validation.cpp:3845) rejects with `bad-txns-duplicate`. This is the "depth%2 fix" formalized as `mutated` detection, not as a differently-shaped tree.
4. The **UTXO transition** is an apply/rollback machine: `UpdateCoins` (validation.cpp:1998) = `SpendCoin` per input (recording `CTxUndo`) + `AddCoins` per output; `AddCoin` (coins.cpp:80) **silently drops unspendable (OP_RETURN) outputs — they are NOT stored**; `DisconnectBlock` (:2178) replays undo data in reverse and is the *only* place rollback semantics live.
5. **BIP30 is a live special-case**, not history: `IsBIP30Repeat` (validation.cpp:6207) hardcodes the two duplicate-coinbase blocks (91842, 91880) and BIP30 enforcement is skipped exactly there (and at heights 91722/91812 in `DisconnectBlock`/`IsBIP30Unspendable` :6213); it is re-enabled wholesale from `BIP34_IMPLIES_BIP30_LIMIT = 1983702` (:2477).
6. **Activation is now almost entirely "buried"**: `Consensus::Params` carries exactly ONE live BIP9 deployment (`DEPLOYMENT_TESTDUMMY`, consensus/params.h:57-59) — segwit/taproot are no longer in the BIP9 table; P2SH/WITNESS/TAPROOT script flags are *always on* with per-block-hash exceptions (`script_flag_exceptions`, chainparams.cpp:113-116). A formal spec of mainnet-2026 activation is mostly a **height-threshold lookup + one BIP9 state machine**.
7. **Chain selection** is precisely: maximize `nChainWork` (sum of `GetBitsProof(nBits)`, chain.cpp:120 = `~target/(target+1)+1`), tie-break by `nSequenceId` then pointer (node/blockstorage.cpp:174-188). Everything else (candidate set, `m_best_invalid`, failed-block caching) is implementation, spec-able as "invalid blocks may be remembered".
8. **Genesis** (kernel/chainparams.cpp:47-72, 169-172): mainnet genesis = time 1231006505, nonce 2083236893, bits 0x1d00ffff, coinbase `"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"`, 50 BTC to P2PK of pubkey `04678afd…d5f`. "Genesis state" in code = **empty UTXO set + tip pointer at genesis hash; the 50 BTC output is unspendable-by-omission** (never written to the coin DB; ConnectBlock short-circuits genesis, :2330-2335).

This track carries **the most state** of any workstream; §Implications splits what must be a functional state machine (UTXO map, chainwork, versionbits caches, BIP9 state) vs pure checks.

---

## Key findings (all VERIFIED against source at `cce32b1682d…` unless marked INFERRED)

| # | Finding | Citation |
|---|---------|----------|
| K1 | Header = 6 fixed fields, serialized `nVersion‖hashPrevBlock‖hashMerkleRoot‖nTime‖nBits‖nNonce` (80 bytes); block = header + `vector<CTransactionRef>` | primitives/block.h:26-42, 95-98 |
| K2 | Block weight = `ser_size(no-witness)×3 + ser_size(with-witness)`; max 4,000,000; checked in `ContextualCheckBlock` (not `CheckBlock`) | consensus/validation.h:143-146, consensus/consensus.h:15, validation.cpp:4187 |
| K3 | Stateless size check is *dual*: tx-count `vtx.size()*4 > MAX_BLOCK_WEIGHT` and no-witness serialization `×4 > MAX_BLOCK_WEIGHT` (`bad-blk-length`) | validation.cpp:3955 |
| K4 | Witness commitment: coinbase output ≥38 bytes, prefix `OP_RETURN 0x24 0xaa 0x21 0xa9 0xed` (= `6a24aa21a9ed`), value 0; commitment = `SHA256D(witness_merkle_root ‖ 32-byte reserved value)`; last matching output wins | consensus/validation.h:154-172, validation.cpp:3878-3917, :4005-4027 |
| K5 | Witness merkle root: leaf 0 is the coinbase and is `uint256()` (all-zeros), leaves 1..n-1 are `GetWitnessHash()` = hash *with* witness; coinbase `scriptWitness` must be exactly one 32-byte stack element (`bad-witness-nonce-size`) | consensus/merkle.cpp:86-96, validation.cpp:3884-3901, primitives/transaction.cpp:86-93 |
| K6 | Blocks with no commitment must contain **no witness data at all** (`unexpected-witness`) | validation.cpp:3908-3916 |
| K7 | CVE-2012-2459: `mutated` = any *adjacent equal pair at any level* before hashing; rejected as `bad-txns-duplicate`; `BLOCK_MUTATED` results are **never** written to the invalid-block cache (mutation ⇒ possibly hardware corruption, not consensus-invalid) | consensus/merkle.cpp:20-73, validation.cpp:3853-3864, :2318-2321, :4488-4495 comment |
| K8 | 64-byte-transaction rule: a coinbase-less (already invalid) block is additionally flagged mutated if any tx serializes to exactly 64 bytes (merkle-leaf ambiguity paper, 2019) — only in `IsBlockMutated`, i.e. mining/relay path, not `CheckBlock` | validation.cpp:4035-4060 |
| K9 | `CheckBlock` order: PoW/signet → merkle → size limits → coinbase-position (`bad-cb-missing`/`bad-cb-multiple`) → per-tx `CheckTransaction` (incl. CVE-2018-17144 duplicate-inputs) → legacy sigops ≤ 80,000 cost (`bad-blk-sigops`) | validation.cpp:3926-3989 |
| K10 | Legacy sigops check under-counts by design (no p2sh/witness sigops) — the exact-cost check with P2SH+witness is in `ConnectBlock` via `GetTransactionSigOpCost` | validation.cpp:3981-3985 comment, consensus/tx_verify.cpp:149-168, :2567 |
| K11 | Contextual header checks: `nBits == GetNextWorkRequired` (`bad-diffbits`); `time > MTP(prev)` (`time-too-old`); `time ≤ now + 7200s` (`time-too-new`, **wall-clock dependent**); version ≥2/3/4 when HEIGHTINCB/DERSIG/CLTV active (`bad-version`) | validation.cpp:4088-4130, chain.h:29 |
| K12 | MTP = median of the **11** most recent blocks' times (this block excluded); BIP113 changes the *finality* cutoff from block time to MTP for all txs when CSV active | chain.h:231-244, validation.cpp:4143-4155 |
| K13 | BIP94 timewarp guard (`MAX_TIMEWARP = 600`): first block of a period must be ≥ prev block time − 600s; **testnet4/regtest only** (`enforce_BIP94`) | consensus/consensus.h:35, validation.cpp:4103-4113 |
| K14 | Retarget: window = `nPowTargetTimespan/nPowTargetSpacing` = 2016 (mainnet); `nActualTimespan` clamped to [timespan/4, timespan×4]; new = last_bits × clamped/timespan, capped at powLimit; **no floor other than powLimit**; `fPowNoRetargeting` (regtest) returns last bits | pow.cpp:14-48, 50-85 |
| K15 | The 4-fold clamp is re-verified *as a rule* by `PermittedDifficultyTransition` (pow.cpp:89-136): at boundary heights the observed new nBits must equal the **re-encoded (round-tripped through GetCompact)** clamp bounds; at non-boundary heights nBits must be unchanged; always true when `fPowAllowMinDifficultyBlocks`. This is called from header validation (TestHeader...) — a genuinely tricky round-trip detail for formalization | pow.cpp:89-136 |
| K16 | Testnet min-difficulty: if new block time > prev time + 2×600s ⇒ **must** be powLimit; else walk back to the last block not at powLimit boundary and copy its nBits (testnet-only; `fPowAllowMinDifficultyBlocks`) | pow.cpp:22-38 |
| K17 | BIP94 retarget base: with `enforce_BIP94`, retarget multiplies the **first block of the period's** nBits, not the last block's (blocks-the-storm rule) | pow.cpp:66-76 |
| K18 | nBits decode: exponent = top byte, mantissa = low 23 bits (0x007fffff), sign bit = 0x00800000 only counts when mantissa ≠ 0; size ≤ 3 shifts right; overflow iff mantissa ≠ 0 ∧ (size > 34 ∨ (mantissa > 0xff ∧ size > 33) ∨ (mantissa > 0xffff ∧ size > 32)); negative/overflow/zero targets are all invalid for PoW | arith_uint256.cpp:176-194, pow.cpp:146-159 |
| K19 | Chainwork per block = `~target/(target+1)+1` over the *decoded* target (0/negative/overflow target ⇒ work 0); no compact re-encoding involved | chain.cpp:120-133 |
| K20 | BIP9 condition bit counts only when `(nVersion & 0xE0000000) == 0x20000000` and bit set; period/threshold/timeout/min_activation_height per-deployment; states DEFINED→STARTED→LOCKED_IN→ACTIVE, timeout→FAILED; **lock-in-on-timeout**: `count ≥ threshold` is checked before the timeout test, so the last period before timeout can still lock in | versionbits_impl.h:79-82, versionbits.cpp:37-131 |
| K21 | State is evaluated only at period boundaries (`pindexPrev height ≡ period−1 (mod period)`); genesis is DEFINED by definition; `min_activation_height` delays LOCKED_IN→ACTIVE | versionbits.cpp:46-52, 111-117 |
| K22 | Buried deployments (BIP90): HEIGHTINCB/BIP34=227931, DERSIG/BIP66=363725, CLTV/BIP65=388381, CSV=419328, SEGWIT=481824 (mainnet); `DeploymentActiveAt` = plain height compare | consensus/params.h:33-43, 149-167, kernel/chainparams.cpp:117-122, deploymentstatus.h:14-37 |
| K23 | Script flags per block: base = P2SH|WITNESS|TAPROOT always, overridden by `script_flag_exceptions` (BIP16 exception block `0000…02dc…`, taproot exception block `0000…0f14…` on mainnet — both get flags-minus-rule), then DERSIG/CLTV/CSV/NULLDUMMY added when their deployment is active *at this block* | validation.cpp:2249-2278, kernel/chainparams.cpp:113-116 |
| K24 | BIP34 enforcement chain: version ≥2 rule (ContextualCheckBlockHeader) + coinbase scriptSig **starts with** `CScriptNum(height)` minimal encoding (`bad-cb-height`, ContextualCheckBlock) + it gates BIP30 skipping (ConnectBlock) | validation.cpp:4123-4130, 4163-4171, 2401-2500 |
| K25 | BIP30: for every tx output, `view.HaveCoin(outpoint)` ⇒ `bad-txns-BIP30`; skipped exactly for blocks 91842/91880 (the two known duplicates) once the chain's block at `BIP34Height` has hash `BIP34Hash`; re-enabled from height 1,983,702 | validation.cpp:2477-2511, 6207-6211 |
| K26 | Coinbase maturity: spend depth `nSpendHeight − coin.nHeight ≥ 100` (`bad-txns-premature-spend-of-coinbase`). **There is no "negative height" in current code** (brief's phrase appears stale): `Coin::nHeight` is a 31-bit unsigned; the genesis coinbase is unspendable because it is *never added to the coin DB* | consensus/consensus.h:19, consensus/tx_verify.cpp:184-188, coins.h:45-72 |
| K27 | Subsidy: `50 COIN >> (height/210000)`, forced 0 when halvings ≥ 64; coinbase total ≤ subsidy + fees (`bad-cb-amount`); fee accumulation must stay in MoneyRange | validation.cpp:1833-1844, 2608-2612, 2543-2548 |
| K28 | OP_RETURN (unspendable) outputs are **never inserted** into the UTXO set (`AddCoin` early-return) but ARE counted in `DisconnectBlock`'s consistency check only if present — i.e., disconnect skips them symmetrically (`IsUnspendable` guard) | coins.cpp:82, validation.cpp:2214-2227 |
| K29 | Undo model: `CTxUndo` per non-coinbase tx stores the full previous `Coin` (out + height + coinbase bit) for each spent input; `ApplyTxInUndo` restores; `fClean` tracks "unclean" disconnects (BIP30/edge cases) that force a coins-db rebuild | validation.cpp:2001-2011, 2198-2247, 2204-2212 |
| K30 | Duplicate-txid nuance, second half: `AddCoins(..., check_for_overwrite=true)` allows coinbase coins to be **overwritten** always (`overwrite = fCoinbase`), precisely to model pre-BIP30 duplicates | coins.cpp:133-142 |
| K31 | Block ordering/context: `AcceptBlockHeader` requires prev in index (`prev-blk-not-found`), prev not failed (`bad-prevblk`), then contextual checks; duplicate known header short-circuits (unless BLOCK_FAILED_VALID → `duplicate-invalid`) | validation.cpp:4198-4270 |
| K32 | Most-work rule: candidate set ordered by `nChainWork` desc, then `nSequenceId` asc (active-chain blocks have lower id), then pointer; tip switches only to strictly-greater work via this comparator | node/blockstorage.cpp:174-189, validation.cpp:3126-3176 |
| K33 | Invalid-block caching: non-mutated consensus failure ⇒ `BLOCK_FAILED_VALID` on the index, descendants excluded from candidate set, `m_best_invalid` tracks highest-work invalid chain; **cache is an optimization** — validation would reach the same verdict without it | validation.cpp:1987-1996, 3149-3161, 3650-3676 |
| K34 | Genesis: mainnet `CreateGenesisBlock(1231006505, 2083236893, 0x1d00ffff, 1, 50*COIN)`; coinbase scriptSig = `0x04ffff001d 0x04 <"The Times …">`; output = 50 BTC P2PK to pubkey `04678afd…b6bf11d5f`; asserts fix hash `000000000019d668…ce26f` and merkle root `4a5e1e4b…a33b` | kernel/chainparams.cpp:47-72, 169-172 |
| K35 | The **only** current BIP9 deployment on mainnet is `testdummy` (bit 28, NEVER_ACTIVE, threshold 1815/2016); testnet4 1512/2016 75%, regtest 108/144 75% | kernel/chainparams.cpp:128-134, 371-377, 649-655 |
| K36 | Finality-in-block: every tx must be final w.r.t. `(height, cutoff)` where cutoff = MTP(prev) if CSV active else block time (`bad-txns-nonfinal`) | validation.cpp:4143-4155, consensus/tx_verify.cpp:23-43 |
| K37 | `assumevalid` and parallel `CCheckQueue` script verification are pure implementation/DoS-control — they cannot change accept/reject except via the documented trust assumption; out of formal scope | validation.cpp:2344-2400 |

---

## Detailed analysis

### (a) Block structure & serialization — VERIFIED

**Header** (`CBlockHeader`, primitives/block.h:26-70): six fields in serialization order
`int32_t nVersion, uint256 hashPrevBlock, uint256 hashMerkleRoot, uint32_t nTime, uint32_t nBits, uint32_t nNonce` (SERIALIZE_METHODS at block.h:42). 80 bytes fixed. `GetHash()` = double-SHA256 of the 80-byte header (block.cpp); `IsNull()` ⇔ `nBits==0`. Block adds `std::vector<CTransactionRef> vtx` after the header (block.h:95-98). Locator (`CBlockLocator`) is p2p/disk-only, never consensus.

**Weight model** (consensus/validation.h:143-146):
```
GetBlockWeight(b) = GetSerializeSize(TX_NO_WITNESS(b)) * (WITNESS_SCALE_FACTOR-1)
                  + GetSerializeSize(TX_WITH_WITNESS(b))
```
i.e. `3×stripped_size + total_size`, `WITNESS_SCALE_FACTOR = 4` (consensus/consensus.h:21), cap `MAX_BLOCK_WEIGHT = 4'000'000` (:15). Note the *legacy* "size" checks in `CheckBlock` (:3955) use `count×4` and `stripped_size×4` — the weight cap itself is only enforced in `ContextualCheckBlock` (:4187) *after* the witness commitment is verified (comment at :4179-4186: otherwise a too-big-by-witness block could be wrongly cached as invalid, since filling the coinbase witness doesn't change the block hash).

**wtxid / BIP141 witness commitment** (validation.cpp:3878-3917, :4005-4027; consensus/merkle.cpp:86-96):
- `GetWitnessHash()` = double-SHA256 of tx *with* witness; equals `GetHash()` when no witness (primitives/transaction.cpp:86-93).
- `BlockWitnessMerkleRoot`: leaves = `[0x00…00 (coinbase), wtxid_1, …, wtxid_{n−1}]`, same odd-duplicate merkle tree as txids.
- Commitment output: `scriptPubKey` = `OP_RETURN 0x24 aa 21 a9 ed ‖ 32 bytes` (≥38 bytes total = `MINIMUM_WITNESS_COMMITMENT`), `nValue = 0`. Prefix bytes on the wire: **`6a 24 aa 21 a9 ed`**.
- Matching: `GetWitnessCommitmentIndex` (consensus/validation.h:154-172) scans coinbase outputs, takes the **last** one matching the prefix.
- Check: `SHA256D(witness_root ‖ scriptWitness.stack[0]) == scriptPubKey[6..38]`; the coinbase witness must be exactly one 32-byte element even though its content ("witness reserved value") is unconstrained.
- If segwit is active for the block and there is no commitment output, **no tx may have witness data** (`unexpected-witness`).
- Commitment is optional per block even when segwit is active (commitment required only when some tx has witness — enforced by the contrapositive of the no-witness rule: if any witness present, a commitment must exist and match).

### (b) Stateless block checks — `CheckBlock` — VERIFIED

validation.cpp:3926-3989, in exact order:
1. `fChecked` cache short-circuit (impl).
2. `CheckBlockHeader` (:3836-3842): `CheckProofOfWork(block.GetHash(), block.nBits, params)` ⇒ `high-hash`/`proof of work failed`. (Signet: `CheckSignetBlockSolution`, signet-only.)
3. `CheckMerkleRoot` (:3845-3869): recompute `BlockMerkleRoot(block, &mutated)`; mismatch ⇒ `bad-txnmrklroot` (BLOCK_MUTATED); `mutated` ⇒ `bad-txns-duplicate` (BLOCK_MUTATED) — **the CVE-2012-2459 rule**. The `mutated` flag is computed in `ComputeMerkleRoot` (consensus/merkle.cpp:51-73): at **every** level, before hashing, if any adjacent pair `hashes[2i]==hashes[2i+1]` ⇒ mutation; odd tail duplicated as usual. Formal note: the fix is "reject if the standard construction would at any level hash two equal values", not "use a different tree".
4. Size limits (:3955): `vtx.empty()` ⇒ invalid; `vtx.size()*WITNESS_SCALE_FACTOR > MAX_BLOCK_WEIGHT`; `GetSerializeSize(TX_NO_WITNESS(block))*WITNESS_SCALE_FACTOR > MAX_BLOCK_WEIGHT` ⇒ `bad-blk-length`. (So a block is limited to ≤1,000,000 non-coinbase-inclusive tx count and ≤4 MB stripped bytes.)
5. Coinbase position (:3959-3966): `vtx[0]->IsCoinBase()` (`bad-cb-missing`); `vtx[i]->IsCoinBase()` for i≥1 ⇒ `bad-cb-multiple`. (`IsCoinBase()` = `vin.size()==1 && vin[0].prevout.IsNull()`, primitives/transaction.h.)
6. Per-tx `CheckTransaction` (consensus/tx_check.cpp:19-68): vin/vout non-empty; stripped size ×4 ≤ 4M (`bad-txns-oversize`); value range/MoneyRange (CVE-2010-5139); **duplicate inputs** (CVE-2018-17144); coinbase scriptSig 2..100 bytes (`bad-cb-length`); non-coinbase null prevout (`bad-txns-prevout-null`).
7. Legacy sigops (:3979-3986): Σ `GetLegacySigOpCount` (consensus/tx_verify.cpp:118-130 — count `OP_CHECKSIG/OP_CHECKSIGVERIFY/OP_CHECKMULTISIG(VERIFY)` with `fAccurate=false`, i.e. multisig counts as 20) ×4 ≤ `MAX_BLOCK_SIGOPS_COST = 80'000` ⇒ `bad-blk-sigops`. Explicitly an under-estimate; the complete sigop budget (legacy+p2sh+witness, per-input, coinbase-exempt for p2sh/witness) is enforced in `ConnectBlock` (:2560-2568) using `GetTransactionSigOpCost` (tx_verify.cpp:149-168).

**Duplicate-txid merkle nuance (CVE-2012-2459), the depth%2 story:** the attack duplicates the *tail* of the tx list so that the odd-duplication rule produces the same root (e.g. `[1..6]` vs `[1..6,5,6]`). The "depth%2 fix" as described publicly = Core's implementation: detect equal-adjacent-pairs at any level in `ComputeMerkleRoot` and treat the block as mutated (`bad-txns-duplicate`). Two consequences formalization must keep: (i) a mutated block is rejected but **not** recorded in the invalid-block cache (`InvalidBlockFound` skips `BLOCK_MUTATED`, validation.cpp:1987-1996; ProcessNewBlock comment :4488-4495 cites CVE-2012-2459), (ii) detection runs per level, not just at the leaves.

### (c) Contextual block checks — VERIFIED

**`ContextualCheckBlockHeader`** (validation.cpp:4088-4130), inputs = header + `pindexPrev` (the block index, not UTXO):
- height = `pindexPrev->nHeight + 1`.
- `block.nBits != GetNextWorkRequired(pindexPrev, &block, params)` ⇒ `bad-diffbits`.
- `block.GetBlockTime() <= pindexPrev->GetMedianTimePast()` ⇒ `time-too-old` (BIP113 MTP; median of 11 incl. prev, chain.h:231-244).
- BIP94 (testnet4/regtest only): on period-boundary heights, `time < prev.time − 600` ⇒ `time-timewarp-attack` (MAX_TIMEWARP, consensus/consensus.h:35).
- `block.Time() > NodeClock::now() + 7200s` ⇒ `time-too-new` (MAX_FUTURE_BLOCK_TIME = 2h, chain.h:29). **Wall-clock dependent** — see implications (the rule is "not more than 2h in the node's future"; per-validation, not consensus-deterministic on reorg depth).
- Version floors: `nVersion < 2 ∧ HEIGHTINCB-active`, `< 3 ∧ DERSIG-active`, `< 4 ∧ CLTV-active` ⇒ `bad-version(0x…)` — these are the BIP34/66/65 *block-version* halves.

**`ContextualCheckBlock`** (validation.cpp:4137-4192):
- Finality cutoff: CSV active ⇒ MTP(prev), else block time (BIP113); all txs `IsFinalTx` ⇒ `bad-txns-nonfinal`.
- BIP34: coinbase scriptSig must *begin with* `CScript() << nHeight` (CScriptNum minimal serialization of the height) ⇒ `bad-cb-height`.
- `CheckWitnessMalleation(block, segwit_active_after_prev, state)` — commitment checks + no-witness-without-commitment (a).
- `GetBlockWeight(block) > MAX_BLOCK_WEIGHT` ⇒ `bad-blk-weight`.

**Ordering / "prev block exists"**: `AcceptBlockHeader` (:4198-4270): duplicate-hash check (genesis exempt) → `CheckBlockHeader` (PoW) → prev in index (`prev-blk-not-found`) → prev not BLOCK_FAILED_VALID (`bad-prevblk`) → `ContextualCheckBlockHeader` → anti-DoS `min_pow_checked` gate (`too-little-chainwork` — a DoS gate, not consensus) → `AddToBlockIndex`.

**CheckProofOfWork / nBits decode** — see K18; the full predicate (pow.cpp:140-171):
```
valid ⇔ decode(nBits) = (target, ok) ∧ ok ∧ target ≠ 0 ∧ target ≤ powLimit ∧ hash ≤ target
```
`powLimit` mainnet/testnet = `0x00000000ffff…ff` (difficulty 1), regtest = `0x7fff…ff`, signet = `0x00000377ae00…00` (kernel/chainparams.cpp:118, 263, 654, 527). Note the sign bit does not make the *value* negative in the comparison (arith_uint256 is unsigned); `fNegative` is a decode *error* only.

### (d) Difficulty retarget — VERIFIED (pow.cpp)

**`GetNextWorkRequired`** (:14-48):
- Only retarget when `(pindexLast->nHeight + 1) % 2016 == 0` (`DifficultyAdjustmentInterval() = nPowTargetTimespan/nPowTargetSpacing` = 14 days / 10 min).
- Non-boundary: copy `pindexLast->nBits` (mainnet), or the testnet min-difficulty dance (K16).
- Boundary: `pindexFirst = GetAncestor(height − 2015)`; `CalculateNextWorkRequired(pindexLast, pindexFirst->GetBlockTime(), params)`. So the window is the **timespan of the last 2016 blocks' first→last** (2015 intervals).

**`CalculateNextWorkRequired`** (:50-85):
- `fPowNoRetargeting` ⇒ copy last nBits (regtest).
- Clamp `nActualTimespan ∈ [timespan/4, timespan×4]` (mainnet: 3.5–56 days).
- BIP94: base target = *first block of the period's* nBits; else last block's.
- `bnNew ×= clampedTimespan; bnNew /= timespan;` then cap at powLimit; return `GetCompact()`. Integer division truncates; multiplication on 256-bit values, no overflow possible given clamps (target ≤ powLimit < 2^224 ⇒ ×56 < 2^231).

**`PermittedDifficultyTransition`** (:89-136) — header-context re-verification used by header acceptance paths (TestHeader / `ContextualCheckBlockHeader` callers via `PermittedDifficultyTransition` in validation; called from `ChainstateManager::AcceptBlockHeader`-adjacent logic and `test/functional` semantics): at boundary, decode new nBits; require `min_rounded ≤ observed ≤ max_rounded` where bounds are old_target×{1/4,4}/timespan **then capped at powLimit then re-encoded via GetCompact** (so the comparison happens against the *compact-round-tripped* bound — rounding matters!). Non-boundary: `old_nbits == new_nbits`. Trivially true on min-difficulty chains.

**Testnet special rule** (K16, pow.cpp:22-38) — TESTNET-ONLY, documented for completeness: block time > prev + 20 min ⇒ nBits must be powLimit; else nBits = last non-min-difficulty block's nBits (walk back while at boundary-or-min).

**Early-days / difficulty-1 exception:** VERIFIED — **current code has no pre-BIP34/early-chain difficulty exception.** The only "difficulty 1" specialness is: genesis nBits = 0x1d00ffff = powLimit, and the powLimit cap. (Historic v0.1 quirks — e.g. the initial 0.25× clamp mishap around block 30k-31k era — are outside current source; INFERRED from history, not in code.) The `assert(nHeightFirst >= 0)` guards the first window. There is also no special case for the genesis block in `GetNextWorkRequired` — the genesis's *own* nBits is never retargeted because header acceptance for genesis skips contextual checks entirely (`hash != hashGenesisBlock` gate, validation.cpp:4205-4245).

**fNegative/fOverflow at the boundary:** decode errors inside `GetNextWorkRequired` are impossible for well-formed nBits seen on-chain (they'd already fail PoW checks), but `PermittedDifficultyTransition` decodes `new_nbits` without checking fNegative/fOverflow explicitly — a malformed nBits with sign bit yields whatever SetCompact produces and is then compared; the PoW check (`hash ≤ target`) plus powLimit bound provides the real guard. Flag: formal spec should route *all* nBits through one total decode function with explicit error cases (VERIFIED decode semantics, arith_uint256.cpp:176-194).

### (e) The chain state transition — VERIFIED

**Apply model.** `ConnectBlock` (validation.cpp:2294-2653) per tx i:
1. (i>0) non-coinbase: `Consensus::CheckTxInputs` (consensus/tx_verify.cpp:170-220) — inputs exist (`bad-txns-inputs-missingorspent`), coinbase maturity depth ≥ 100, value ranges, `in ≥ out`, fee in range.
2. BIP68 `SequenceLocks` with `prevheights` from the coins being spent (needs UTXO set — this is why it lives in ConnectBlock, :2525-2538).
3. Sigop cost via `GetTransactionSigOpCost` against the *view* (p2sh/witness need prevout scripts), cumulative ≤ 80,000 (`bad-blk-sigops`).
4. Script verification (`CheckInputScripts`, :149) with block flags (K23) — parallelizable, assumevalid-gated.
5. `UpdateCoins(tx, view, undo, height)` (:1998-2011): for each input `SpendCoin` (storing the prior `Coin` into `CTxUndo.vprevout`), then `AddCoins` for all outputs.
6. After all txs: coinbase payout ≤ `nFees + GetBlockSubsidy(height)` (`bad-cb-amount`).

**UTXO insertion details (coins.cpp):**
- `AddCoin` (:80-110): **unspendable outputs (`scriptPubKey.IsUnspendable()`, i.e. OP_RETURN-style) return early — they are NOT in the UTXO set.** VERIFIED at coins.cpp:82.
- `AddCoins` (:133-142): `possible_overwrite = check_for_overwrite ? HaveCoin(outpoint) : fCoinbase` — coinbase outputs may always overwrite (pre-BIP30 duplicates); non-coinbase overwrite without flag throws (logic error).
- `Coin` = `{CTxOut out, bool fCoinBase:1, uint32_t nHeight:31}` (coins.h:45-72); disk form packs `(nHeight<<1)|fCoinBase` as VARINT.

**BIP30 (validation.cpp:2477-2511 + 6207-6211):** if any output of any tx in the new block already exists in the UTXO view ⇒ `bad-txns-BIP30`. Enforcement suppressed **only** for the two historical duplicate-coinbase blocks:
- height 91842, `00000000000a4d0a398161ffc163c503763b1f4360639393e0e4c8e300e0caec`
- height 91880, `00000000000743f190a18c5577a3c2d2a1f610ae9601ac046a38084ccb7cd721`
…conditional on the chain's block at `BIP34Height` (227931) having hash `BIP34Hash` (i.e. "we're on the known chain"); and unconditionally re-enabled from `BIP34_IMPLIES_BIP30_LIMIT = 1983702`. The long comment block (:2403-2476) documents the heights 209921/490897/1983702 coinbase-indicated-height analysis — formalization can hardcode the same predicate.

**BIP30 in disconnect** (:2198-2212): the *other* pair — heights 91722 (`0000…0271a2…`) and 91812 (`0000…0af0ae…`) — where disconnect-time consistency checks are relaxed (`IsBIP30Unspendable`, :6213-6218, also used by coinstatsindex to exclude the *first* instance's coins).

**Rollback model.** `DisconnectBlock` (:2178-2247): undo txs in reverse; for each output **not unspendable**, `SpendCoin` must succeed and the coin must match `{vout, nHeight, fCoinBase}` exactly (mismatch ⇒ `fClean=false` unless BIP30-exception block); then restore inputs from `CTxUndo` via `ApplyTxInUndo`. `DISCONNECT_UNCLEAN` forces a coins-cache flush/rebuild. `DisconnectTip` (:2936) + `ConnectTip` (:3012) implement reorg as disconnect-to-fork then connect-forward; undo data written by `WriteBlockUndo` (required for any future disconnect — pruning drops blocks+undo only above the prune depth).

**Coinbase maturity "negative height":** VERIFIED as *not present in current code* — see K26. The brief's phrase likely refers to the pre-0.15 `CCoins` era; the modern semantics are the plain depth check in `CheckTxInputs` plus `fCoinBase` bit. (The one genuinely negative height in the neighborhood is `nHeight = -1` used for `CBlockIndex` iteration in `ActivateBestChainStep`, unrelated to maturity.)

**BIP34 enforcement chain** (three independent legs, all VERIFIED):
1. block version ≥ 2 (header rule, only when HEIGHTINCB "active", i.e. height ≥ 227931 on mainnet),
2. coinbase scriptSig prefix = CScriptNum(height) (`bad-cb-height`),
3. BIP30-skip gating + `BIP34Hash` pin (the *exact* hash at 227931 is also pinned: `000000000000024b89b42a942fe0d9fea3bb44ab7bd1b19115dd6a759c0808b8`).

**Coins cache vs disk** (CCoinsViewCache/CCoinsViewDB, FRESH/DIRTY entry states, flush heuristics, leveldb, `coinstatsindex`, assumeutxo snapshots): **implementation — out of formal scope** per charter; only the *logical* coins map + undo semantics are consensus.

### (f) Soft-fork activation — VERIFIED

**BIP9 machine** (versionbits.cpp:37-131; versionbits_impl.h:57-83):
- State computed for a `pindexPrev` aligned to period boundaries; cached (`ThresholdConditionCache`); genesis (nullptr) = DEFINED.
- DEFINED --(MTP ≥ nStartTime)--> STARTED --(≥ threshold of last `period` blocks signal)--> LOCKED_IN --(height+1 ≥ min_activation_height)--> ACTIVE; STARTED --(MTP ≥ nTimeout ∧ count < threshold)--> FAILED.
- **Lock-in-on-timeout fix**: the `count >= nThreshold` test precedes the timeout test, so a period ending exactly at the timeout still locks in (versionbits.cpp:104-110).
- ALWAYS_ACTIVE (−1) ⇒ ACTIVE; NEVER_ACTIVE (−2) ⇒ FAILED; NO_TIMEOUT = INT64_MAX.
- Signal predicate: `(nVersion & 0xE0000000) == 0x20000000 && (nVersion & (1<<bit)) != 0`.
- Statistics/GBT and the "active since" bookkeeping (`GetStateSinceHeightFor`, versionbits.cpp:152-186) are reporting, not rules; the warning-bit system (VERSIONBITS_NUM_BITS=5, `m_warning_caches`) is p2p-warning policy — implementation.

**Deployments on mainnet today** (kernel/chainparams.cpp:113-134):
- Buried (BIP90, height-locked, `DeploymentActiveAt` = height compare): BIP34 @227931 (+BIP34Hash pin), BIP66/DERSIG @363725, BIP65/CLTV @388381, CSV (BIP68/112/113) @419328, SegWit (BIP141/143/147) @481824.
- BIP9 table: only `testdummy` (bit 28, NEVER_ACTIVE, timeout ∞, 1815/2016 = 90%).
- SegWit is special: `SCRIPT_VERIFY_WITNESS` is enforced from genesis in the flag base but its *data availability / commitment* gating uses `SegwitHeight`; NULLDUMMY (BIP147) rides `DeploymentActiveAt(SEGWIT)`.
- P2SH: base flag always-on; exception block `00000000000002dc756eebf4f49723ed8d30cc28a5f108eb94b1ba88ac4f9c22` gets `SCRIPT_VERIFY_NONE`. Taproot: always-on; exception block `0000000000000000000f14c35b2d841e986ab5441de8c585d5ffe55ea1e395ad` gets P2SH|WITNESS only (kernel/chainparams.cpp:113-116).
- BIP34/65/66 additionally have the *block version floor* legs in ContextualCheckBlockHeader (c).
- testnet: BIP34@21111 (+hash), BIP66@330776, BIP65@581885, CSV@770112, segwit@834624; testnet4/regtest/signet bury at height 0/1 (regtest segwit at **0**).

**Flag flow into script verification per block:** `GetBlockScriptFlags(block_index, chainman)` (validation.cpp:2249-2278) is called once in `ConnectBlock` (:2541) and applied to every non-coinbase tx's `CheckInputScripts`. Flags = base(P2SH|WITNESS|TAPROOT) ⊕ exceptions-by-hash ∪ {DERSIG, CLTV, CSV, NULLDUMMY as deployed}. (WITNESS_SH/NATIVE etc. are inside the interpreter's per-input logic, B5's territory.)

### (g) Genesis — VERIFIED (kernel/chainparams.cpp:38-72, 169-172)

Mainnet:
- time = 1231006505, nonce = 2083236893, bits = 0x1d00ffff, version = 1, prev = null.
- Coinbase (only tx): version 1, vin = null-prevout coinbase with scriptSig = `0x04ffff001d` (push of 0x01d00ffff... i.e. bits as data) ‖ `0x04` ‖ `"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"`; vout = 50 BTC to `P2PK(pubkey 04678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5f, OP_CHECKSIG)`.
- merkle root computed from that single tx = `4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b`; block hash asserted = `000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f`.

**"Genesis state" for a formal spec:** in Core, connecting genesis = special case in `ConnectBlock` (:2330-2334): *skip connecting its transactions entirely; just set best block*. The 50 BTC output is therefore **not** in the UTXO set (its output is spendable by nobody; the comment at chainparams.cpp:52-54 says exactly this). Genesis passes no checks at all (its header path is exempted in AcceptBlockHeader; its PoW is trivially valid). ⇒ Formal state at height 0: `UTXO = ∅`, `tip = genesis_hash`, `chainwork = GetBitsProof(0x1d00ffff)`, and every "active" deployment with height ≤ 0 active per params (mainnet: none at 0; regtest: segwit at 0).

### (h) Chain selection — the precise rule + implementation notes

**The rule (spec-ready, VERIFIED):** among all chains whose headers+data are known and which contain no invalid ancestor, the active chain is the one with maximal total work `nChainWork = Σ_i work(nBits_i)`, `work(t) = ⌊(~t / (t+1))⌋ + 1` on the decoded target t (chain.cpp:120-133, computed as `2^256/(t+1)` rounded down, i.e. expected number of hashes per block). A tip change happens only when a candidate has **strictly greater** work than the current tip (`CBlockIndexWorkComparator` is a strict weak ordering with the tie-breakers below; `ActivateBestChain` re-checks `m_chain.Tip()->nChainWork > pindexOldTip->nChainWork` etc., validation.cpp:3263, 3508).

**Tie-breaking (implementation, but deterministic):** equal-work candidates order by `nSequenceId` (blocks on the active chain get the lowest; new blocks higher) then pointer address (node/blockstorage.cpp:174-189). Consensus-wise, equal-work ties are resolved by *whichever was received/connected first* staying tip — a spec may model the tie-break as "stay" without loss.

**Invalid-block caching (`CANDIDATE`/BLOCK_FAILED_VALID):** on a non-mutated consensus failure, the block index entry gets `BLOCK_FAILED_VALID`; descendants are erased from `setBlockIndexCandidates`; `m_best_invalid` remembers the best invalid chain for warning/UI; `duplicate-invalid`/`bad-prevblk` reuse the cache (validation.cpp:4210-4219, 4253-4257, 3650-3676; InvalidateBlock clears flags on unmark). **Spec treatment:** an optional memoization of the verdict function; must not change the extension of "valid chain". Note the CVE-2012-2459 asymmetry (K7/B7): mutated blocks are *not* cached.

**Most-work vs "first-seen":** Core implements Nakamoto's rule exactly (most accumulated work), not "longest chain". `nMinimumChainWork` and the headers-sync `min_pow_checked` gate are DoS policy — out of consensus scope.

---

## Implications for btc-lean (state-machine vs pure checks)

This track contributes the **largest stateful core** of the 16 workstreams. Recommended decomposition:

**A. Pure total functions (easy, prove-first):**
- nBits decode/encode (`SetCompact`/`GetCompact`) — small, decidable, ideal for `BitVec`-based Lean defs and property tests vs Core's unit vectors (`test/arith_uint256_tests.cpp`).
- `CheckProofOfWork`, `DeriveTarget`, `GetBitsProof` (chainwork).
- `ComputeMerkleRoot` (+ `mutated` flag) — recursion over levels; CVE-2012-2459 is a *theorem-shaped* statement: "two tx lists with equal roots ⇒ one is an equal-adjacent-pair mutation or they are equal".
- `GetNextWorkRequired`/`CalculateNextWorkRequired`/`PermittedDifficultyTransition` — arithmetic over ℕ; the compact round-trip in PermittedDifficultyTransition is the only subtle part.
- `GetBlockSubsidy`, `GetBlockWeight`, sigop counting, `IsFinalTx` (given cutoff), `GetMedianTimePast`.

**B. Pure predicates over (header, context) — still stateless in the Lean sense once context is a parameter:**
- `CheckBlockHeader`, `CheckBlock` (parameterized by `pow_ok`, `merkle_ok`), `ContextualCheckBlockHeader(h, prev_index_summary)`, `ContextualCheckBlock(b, prev, activations)` — context can be modeled as a *record* `{height, mtp, nBits_next, activations_at, now_bounded_time}` so no pointer-forest (`CBlockIndex`) is needed in the spec.

**C. Functional state machines (the real state — flag for C1/C4):**
1. **UTXO set**: `State = OutPoint ⇀ Coin`; step = `connect_block : State × Block → Option (State × Undo)`; `disconnect_block : State × Block × Undo → Option State` (+ `clean` flag). Theorems: `disconnect ∘ connect = id` (the undo lemma, mirroring `DISCONNECT_OK`), value conservation per block (fees+subsidy), no-creation-without-coinbase, BIP30 injectivity (outputs unique in `State`).
2. **Chainwork/selection**: `nChainWork` fold + argmax with the "stay on tie" tie-break; theorem: active chain is the max-work chain among candidate extensions.
3. **BIP9 activation**: an explicit five-state machine indexed by period; the lock-in-on-timeout ordering (K20) is a spec-level subtlety; define `DeploymentActiveAt` for buried forks as `height ≥ h` and prove the BIP9 machine with `nStartTime = ALWAYS_ACTIVE` *equals* the buried semantics (nice bridge theorem).
4. **The activation-flag → script-flags map**: `GetBlockScriptFlags` as a function `Height × BlockHash → FlagSet`; the two exception blocks are literal table entries.

**D. Wall-clock taint:** `time-too-new` (MAX_FUTURE_BLOCK_TIME) is the *only* accept/reject rule that depends on the validating node's clock. Options: (i) model as `time ≤ T_now + 7200` with `T_now` universally quantified and prove monotone-in-history properties; (ii) treat as liveness/relay rule, not consensus (a block rejected at T may be accepted at T+1h — Core itself relies on this, hence blocks never become *invalidated* by it, only `BLOCK_TIME_FUTURE` deferred). Recommend (i)+document.

**E. Genesis as an axiom-free constant:** build the genesis block *by computation* in Lean (SHA-256 tower from C2) and state `genesis_hash = 0x…ce26f` as a theorem, not an axiom — this doubles as the first end-to-end conformance test.

**F. Rule-ID prerequisites:** the CVE-2012-2459 `mutated` flag, the BIP30 height/hash pair set, the script-flag exception table, and `BIP34_IMPLIES_BIP30_LIMIT` must be *parameters* of the spec (network profile record), mirroring `Consensus::Params` — do not hardcode mainnet in the rules.

---

## Open questions & risks

1. **`PermittedDifficultyTransition`'s GetCompact round-trip** — the bound comparison happens against re-encoded targets; a naive spec that compares unrounded values will disagree with Core on adversarial nBits. Needs a dedicated test vector. (VERIFIED behavior; edge-case risk HIGH.)
2. **`time-too-new` clock dependence** — formalization must decide the quantifier over `now`; conformance tests against Core need time injection (Core has `setmocktime` in tests). MEDIUM.
3. **BIP30/BIP34 constant soup** — 4 hardcoded hashes (91722/91812 disconnect pair, 91842/91880 repeat pair) + BIP34Hash + BIP34_IMPLIES_BIP30_LIMIT=1983702. Low risk, but every one is a mandatory constant in the network profile; missing one breaks historical replay from block ~91k. LOW.
4. **The `m_checked_*` / `fChecked` caching flags in `CBlock`** — validation *ordering* effects (e.g., witness-malleability checks deliberately deferred to ContextualCheckBlock so a corrupted block isn't cached invalid) are observable in failure *classification* (BLOCK_MUTATED vs BLOCK_CONSENSUS) but not in the validity predicate itself. Spec should classify failures the same way if we want rule-level conformance with Core's `reject reason` strings. MEDIUM.
5. **`IsBlockMutated`'s 64-byte tx rule** is relay/mining-path only (not `CheckBlock`); if btc-lean models the p2p boundary at all this must be parked outside consensus. LOW.
6. **SegWit "optional commitment"**: a pre-activation-height block *with* a valid commitment is fine; a block *without* commitment must have no witnesses. The interaction is only fully specified by reading `CheckWitnessMalleation`'s both branches — B5 should own the definitive write-up. LOW-MED (hand-off).
7. **Genesis-coinbase unspendability is *positional*, not a rule**: "the coinbase of the genesis block cannot be spent" is emergent (never added to the coin DB). A spec that instead adds it at height 0 and then needs an ad-hoc unspendable flag would diverge from Core's model — recommend modeling ∅-UTXO at genesis and *proving* the 50 BTC output never enters the set. LOW.
8. **`assert`s as consensus checks**: `ConnectBlock` asserts (`hashPrevBlock == view.GetBestBlock()`, undo counts) are invariant guards, not rules; a total-functional spec converts them to hypotheses. Note in theorem statements. LOW.

---

## Recommendations

1. **Adopt Core's 4-layer decomposition verbatim** as the Lean module structure: `BlockHeader.lean` (structure+PoW), `Block.lean` (stateless), `BlockContext.lean` (header/contextual), `Connect.lean` (UTXO state machine). One Lean definition per Core function, same name.
2. **Milestone order**: (1) nBits+PoW+merkle (pure), (2) retarget trio, (3) CheckBlock/Contextual predicates, (4) UTXO connect/disconnect + undo-isomorphism theorem, (5) BIP9 machine + buried lookup, (6) genesis-by-computation, (7) chain selection. Items (1)–(3) are M1-achievable and give immediate conformance tests vs Core's `test/functional/mining_*.py` and `p2p_segwit.py` vectors.
3. **Model context as a record, not the `CBlockIndex` forest** — collapses ~30% of validation.cpp complexity with zero rule loss (the forest is a performance structure; see K31/K32 for what leaks into consensus: only `nHeight`, `MTP`, `nBits_next`, `nChainWork`, ancestor hashes).
4. **Make `mutated` a first-class result** of merkle computation (as Core does) so CVE-2012-2459's "don't cache invalid" asymmetry is representable.
5. **Keep the network-profile record** (`Consensus::Params` mirror) as a Lean parameter from day one; mainnet values are one instance; testnet4/BIP94 and regtest come nearly free and serve as differential tests.
6. **Escalate to B5**: witness-commitment details and NULLDUMMY/WITNESS flag interactions; **to B3**: `CheckTransaction`/`CheckTxInputs`/BIP68 details (referenced here only as block-context call sites).
7. **File the wall-clock question** with D2 (formality ladder): decide whether `now` is axiomatized, quantified, or modeled as an environment cell (KEVM-style) before M2.

---

## Appendix A — Sources (all at commit `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`)

Primary source files (cloned at bitcoin/bitcoin):
- `src/primitives/block.h`, `src/primitives/block.cpp` — header/block/locator structures, hashing.
- `src/primitives/transaction.{h,cpp}` — txid vs wtxid (`ComputeHash`/`ComputeWitnessHash`), `IsCoinBase`.
- `src/consensus/consensus.h` — MAX_BLOCK_WEIGHT, MAX_BLOCK_SIGOPS_COST, WITNESS_SCALE_FACTOR, COINBASE_MATURITY, MAX_TIMEWARP.
- `src/consensus/validation.h` — `GetBlockWeight`, `GetWitnessCommitmentIndex`, MINIMUM_WITNESS_COMMITMENT.
- `src/consensus/merkle.cpp` — `ComputeMerkleRoot` (+CVE-2012-2459 comment), `BlockMerkleRoot`, `BlockWitnessMerkleRoot`, `MerkleComputation`.
- `src/consensus/tx_verify.{h,cpp}` — `IsFinalTx`, `CalculateSequenceLocks`, sigop counts/cost, `CheckTxInputs`.
- `src/consensus/tx_check.cpp` — `CheckTransaction` (stateless).
- `src/consensus/params.h` — `BIP9Deployment`, buried deployments, `Consensus::Params`.
- `src/pow.{h,cpp}` — `GetNextWorkRequired`, `CalculateNextWorkRequired`, `PermittedDifficultyTransition`, `CheckProofOfWork(Impl)`, `DeriveTarget`.
- `src/arith_uint256.cpp` — `SetCompact`/`GetCompact` (nBits codec).
- `src/chain.{h,cpp}` — `GetBitsProof`, `GetMedianTimePast` (11), `MAX_FUTURE_BLOCK_TIME`, `TIMESTAMP_WINDOW`, `LastCommonAncestor`.
- `src/validation.{h,cpp}` — `CheckBlockHeader` :3836, `CheckMerkleRoot` :3845, `CheckWitnessMalleation` :3878, `CheckBlock` :3926, `UpdateUncommittedBlockStructures` :3993, `GenerateCoinbaseCommitment` :4005, `HasValidProofOfWork` :4029, `IsBlockMutated` :4035, `ContextualCheckBlockHeader` :4088, `ContextualCheckBlock` :4137, `AcceptBlockHeader` :4198, `AcceptBlock` :4300ish, `ConnectBlock` :2294, `DisconnectBlock` :2178, `GetBlockScriptFlags` :2249, `UpdateCoins` :1998, `InvalidBlockFound` :1987, `InvalidChainFound` :1963, `FindMostWorkChain` :3126, `ActivateBestChainStep` :3199, `ConnectTip` :3012, `DisconnectTip` :2936, `InvalidateBlock` :3529, `IsBIP30Repeat` :6207, `IsBIP30Unspendable` :6213, `GetBlockSubsidy` :1833, `CheckInputScripts` :149.
- `src/coins.{h,cpp}` — `Coin`, `AddCoin` :80, `AddCoins` :133, `SpendCoin` :144.
- `src/versionbits.{h,cpp}`, `src/versionbits_impl.h` — threshold state machine, `Condition`, stats, `IsActiveAfter`, `ComputeBlockVersion`.
- `src/deploymentstatus.h`, `src/deploymentinfo.{h,cpp}` — buried/active lookups, deployment names.
- `src/kernel/chainparams.cpp` — genesis construction (mainnet :47-72/169-172), all network `Consensus::Params`, script_flag_exceptions, assumeutxo, `nMinimumChainWork`.
- `src/kernel/signet.h` — default signet challenge.
- `src/node/blockstorage.h/.cpp` — `CBlockIndexWorkComparator` (:174), `CBlockIndexHeightOnlyComparator`.
- `src/chain.h` — `CBlockIndex` (`nChainWork`, `nStatus`, `GetAncestor`).
- `src/index/coinstatsindex.cpp` :129/357 — BIP30-unspendable usage.

BIP/CVE references used: BIP22/23 (context), BIP30, BIP34, BIP65, BIP66, BIP68/112/113, BIP90, BIP94, BIP9, BIP141/144/147 (commitment parts; deep-dive in B5), BIP16 (exception), CVE-2012-2459, CVE-2018-17144, CVE-2010-5139, CVE-2012-1909 (BIP30), timewarp (PR 15482 / BIP94), merkle-weaknesses paper (lists.linuxfoundation.org 2019 attachment, cited in `IsBlockMutated`).

## Appendix B — THE BLOCK RULE TABLE

Difficulty: 1 = trivial arithmetic, 5 = state-machine + historic special cases.
Locations `file:function:lines` @`cce32b1682d…` (validation.cpp = V, consensus/merkle.cpp = M, pow.cpp = P, consensus/tx_verify.cpp = TV, consensus/tx_check.cpp = TC, coins.cpp = C, kernel/chainparams.cpp = CP, chain.h = CH, chain.cpp = CN, versionbits.cpp = VB, versionbits_impl.h = VI, consensus/validation.h = CV, arith_uint256.cpp = AU, node/blockstorage.cpp = NS, consensus/consensus.h = CC, deploymentstatus.h = DS, primitives/block.h = PB, primitives/transaction.cpp = PT).

| Rule ID | Rule/check | Core location | One-line spec statement | BIP/CVE | Diff |
|---|---|---|---|---|---|
| BLK-001 | Header field set & order | PB:CBlockHeader:26-42 | A block header is exactly (nVersion, prevHash, merkleRoot, nTime, nBits, nNonce), serialized in that order, 80 bytes | — | 1 |
| BLK-002 | Block body serialization | PB:CBlock:95-98 | A block is header ‖ varint(txcount) ‖ txs | — | 1 |
| BLK-003 | Header hash function | PB:GetHash + primitives/block.cpp | block hash = SHA256d(80-byte header), interpreted little-endian | — | 1 |
| BLK-004 | Header IsNull | PB:54-57 | nBits == 0 defines a null header | — | 1 |
| BLK-005 | Txid definition | PT:ComputeHash:81-84 | txid = SHA256d(tx serialized without witness) | BIP141 | 1 |
| BLK-006 | wtxid definition | PT:ComputeWitnessHash:86-93 | wtxid = SHA256d(tx with witness) = txid when no witness | BIP141 | 1 |
| BLK-007 | Merkle leaf set (txids) | M:BlockMerkleRoot:76-84 | leaves = txid_i of all vtx in order | — | 1 |
| BLK-008 | Merkle odd-duplication | M:ComputeMerkleRoot:51-73 | odd-sized level duplicates its last element before pairing | — | 2 |
| BLK-009 | Merkle hash step | M:67 | pair hash = SHA256d(concat of two 32-byte values, in order) | — | 1 |
| BLK-010 | Merkle root equality | V:CheckMerkleRoot:3848-3852 | header.hashMerkleRoot must equal computed root (`bad-txnmrklroot`) | — | 1 |
| BLK-011 | Merkle mutation detection | M:ComputeMerkleRoot:55-63 + V:3853-3864 | reject if any level contains two adjacent equal hashes (`bad-txns-duplicate`) | CVE-2012-2459 | 3 |
| BLK-012 | Mutated ⇒ not cached invalid | V:InvalidBlockFound:1987-1996 | BLOCK_MUTATED failures must not mark the block permanently invalid | CVE-2012-2459 | 3 |
| BLK-013 | Empty-txlist merkle edge | M:71-72 | empty leaf list ⇒ null root (unreachable for valid blocks due BLK-022) | — | 2 |
| BLK-014 | Witness merkle leaf 0 | M:BlockWitnessMerkleRoot:86-96 | leaf for coinbase is 0x00…00; leaves are wtxid_1..n−1 | BIP141 | 2 |
| BLK-015 | Witness commitment output syntax | V:GetWitnessCommitmentIndex(CV:154-172) | a commitment output is any coinbase output ≥38 bytes with prefix 6a24aa21a9ed; last one counts | BIP141 | 2 |
| BLK-016 | Witness commitment value | V:4018 | commitment output nValue = 0 | BIP141 | 1 |
| BLK-017 | Witness commitment equation | V:3898-3904 | SHA256d(witness_root ‖ reserved_value) == scriptPubKey[6..38] | BIP141 | 2 |
| BLK-018 | Witness reserved value shape | V:3884-3892 | coinbase scriptWitness must be exactly one 32-byte element (`bad-witness-nonce-size`), content unconstrained | BIP141 | 2 |
| BLK-019 | No commitment ⇒ no witness | V:3908-3916 | if no commitment output exists, no tx in the block may have witness data (`unexpected-witness`) | BIP141 | 2 |
| BLK-020 | Commitment required iff witness used | (contrapositive of BLK-019) | any tx with witness ⇒ a valid commitment must exist (when segwit active) | BIP141 | 2 |
| BLK-021 | Commitment check timing | V:4179-4187 comment | weight check must occur after commitment check (hash-invariance argument) | BIP141 | 3 |
| BLK-022 | Block non-empty | V:CheckBlock:3955 | vtx non-empty (`bad-cb-missing` via empty check) | — | 1 |
| BLK-023 | Tx-count weight bound | V:3955 | vtx.size() × 4 ≤ 4,000,000 | — | 1 |
| BLK-024 | Stripped-size bound | V:3955 | stripped block size × 4 ≤ 4,000,000 (`bad-blk-length`) | — | 1 |
| BLK-025 | Weight definition | CV:143-146 | weight = 3×stripped_size + total_size | BIP141 | 1 |
| BLK-026 | Weight bound (contextual) | V:ContextualCheckBlock:4185-4188 | weight ≤ 4,000,000 (`bad-blk-weight`), checked after commitment validation | BIP141 | 2 |
| BLK-027 | First tx is coinbase | V:3959-3962 | vtx[0].IsCoinBase() (`bad-cb-missing`); IsCoinBase = single input, null prevout | — | 1 |
| BLK-028 | Only first tx is coinbase | V:3963-3966 | ∀i≥1: ¬vtx[i].IsCoinBase() (`bad-cb-multiple`) | — | 1 |
| BLK-029 | Coinbase scriptSig length | TC:55-58 | coinbase vin scriptSig size ∈ [2,100] bytes (`bad-cb-length`) | BIP34-era | 1 |
| BLK-030 | Per-tx stateless validity | V:3968-3977 → TC:19-68 | every tx passes CheckTransaction (vin/vout nonempty, size, money range, dup inputs, prevout null) | CVE-2018-17144, CVE-2010-5139 | 2 |
| BLK-031 | Duplicate-input ban | TC:49-53 | no two inputs of one tx share an outpoint (`bad-txns-inputs-duplicate`) | CVE-2018-17144 | 2 |
| BLK-032 | Tx stripped size bound | TC:26-29 | stripped tx size × 4 ≤ 4,000,000 (`bad-txns-oversize`) | BIP141 | 1 |
| BLK-033 | Legacy sigop count | TV:GetLegacySigOpCount:118-130 | count CHECKSIG(VERIFY)+CHECKMULTISIG(VERIFY) in scriptSig&scriptPubKey, multisig = 20 | — | 2 |
| BLK-034 | Legacy sigop block budget | V:3979-3986 | Σ legacy sigops ×4 ≤ 80,000 (`bad-blk-sigops`), under-counting by design | BIP141 | 2 |
| BLK-035 | Full sigop cost | TV:GetTransactionSigOpCost:149-168 | cost = 4×(legacy + P2SH) + witness sigops; P2SH/witness exclude coinbase | BIP16/141 | 3 |
| BLK-036 | Full sigop budget in connect | V:2560-2568 | cumulative sigop cost ≤ 80,000 during ConnectBlock (`bad-blk-sigops`) | — | 2 |
| BLK-037 | PoW target decode | AU:SetCompact:176-194 | nBits → (mantissa&0x007fffff) << (8×(exp−3)) for exp>3, >>8×(3−exp) else; sign bit = 0x00800000 valid only with nonzero mantissa; overflow iff mantissa≠0 ∧ (exp>34 ∨ (m>0xff ∧ exp>33) ∨ (m>0xffff ∧ exp>32)) | — | 3 |
| BLK-038 | PoW target bounds | P:DeriveTarget:146-159 | decode must be non-negative, non-overflow, nonzero, ≤ powLimit | — | 2 |
| BLK-039 | PoW check | P:CheckProofOfWorkImpl:161-171 | SHA256d(header) interpreted as LE integer ≤ target (`high-hash`) | — | 1 |
| BLK-040 | powLimit mainnet/testnet | CP:118/263 | 0x00000000ffffffff…ff | — | 1 |
| BLK-041 | powLimit signet/regtest | CP:654/530ish | signet 0x00000377ae00…; regtest 0x7fffffff… | — | 1 |
| BLK-042 | nBits equality with retarget | V:ContextualCheckBlockHeader:4096-4098 | header nBits must equal GetNextWorkRequired(prev, header) (`bad-diffbits`) | — | 2 |
| BLK-043 | Retarget interval | P:20-21 | retarget iff (height+1) mod 2016 == 0; else copy prev nBits | — | 1 |
| BLK-044 | Retarget window anchors | P:41-47 | timespan = time(block at height H) − time(block at H−2015) | — | 2 |
| BLK-045 | Timespan clamp | P:55-60 | actualTimespan clamped to [T/4, 4T], T = 1209600 s | — | 1 |
| BLK-046 | Retarget formula | P:62-84 | new = base_nBits_decoded × clampedTimespan / T, truncated division, then cap at powLimit, re-encode | — | 3 |
| BLK-047 | Retarget base (BIP94) | P:66-76 | base = first block of period's nBits iff enforce_BIP94 else last block's | BIP94 | 2 |
| BLK-048 | powLimit ceiling in retarget | P:81-82 | new target never exceeds powLimit | — | 1 |
| BLK-049 | No-retarget mode | P:52-53 | fPowNoRetargeting ⇒ nBits copied (regtest) | — | 1 |
| BLK-050 | Permitted transition (boundary) | P:PermittedDifficultyTransition:93-131 | at boundary, observed new target ∈ [min_rounded, max_rounded] where bounds = clamp±4 recomputed from old nBits, capped, then GetCompact-round-tripped | — | 4 |
| BLK-051 | Permitted transition (non-boundary) | P:132-134 | nBits constant within a period | — | 1 |
| BLK-052 | Transition check bypass on min-diff chains | P:91 | fPowAllowMinDifficultyBlocks ⇒ always permitted | — | 1 |
| BLK-053 | Testnet min-difficulty trigger | P:22-29 | if blockTime > prevTime + 2×600 ⇒ nBits must be powLimit (testnet3/testnet4/regtest) | — | 2 |
| BLK-054 | Testnet min-difficulty walk-back | P:30-36 | else nBits = nearest ancestor's nBits that is not (boundary ∧ powLimit) | — | 3 |
| BLK-055 | BIP94 timewarp bound | V:4103-4113, CC:35 | on period boundaries: blockTime ≥ prevBlockTime − 600 (`time-timewarp-attack`); testnet4/regtest only | BIP94 | 2 |
| BLK-056 | MTP definition | CH:GetMedianTimePast:233-244 | MTP = median of last 11 block times (self excluded) | BIP113 | 2 |
| BLK-057 | time-too-old | V:4100-4102 | blockTime > MTP(prev) (`time-too-old`) | BIP113 | 1 |
| BLK-058 | time-too-new (2h) | V:4115-4118, CH:29 | blockTime ≤ node now + 7200 s (`time-too-new`) | — | 2 |
| BLK-059 | Height derivation | V:4092-4093 | height = pindexPrev.height + 1 (no separate rule) | — | 1 |
| BLK-060 | Version floor v≥2 | V:4123-4129 | nVersion ≥ 2 when BIP34 active (`bad-version`) | BIP34 | 1 |
| BLK-061 | Version floor v≥3 | V:4123-4129 | nVersion ≥ 3 when BIP66 active | BIP66 | 1 |
| BLK-062 | Version floor v≥4 | V:4123-4129 | nVersion ≥ 4 when BIP65 active | BIP65 | 1 |
| BLK-063 | Prev-header existence | V:AcceptBlockHeader:4237-4245 | prev hash must be a known header (`prev-blk-not-found`) | — | 1 |
| BLK-064 | Prev-not-invalid | V:4246-4250 | prev not BLOCK_FAILED_VALID (`bad-prevblk`) | — | 2 |
| BLK-065 | Duplicate header short-circuit | V:4205-4235 | known hash ⇒ return cached verdict; genesis exempt from all header checks | — | 2 |
| BLK-066 | Tx finality (height/locktime) | TV:IsFinalTx:23-43 | nLockTime==0 or < cutoff(height if <500M else time) or all SEQUENCE_FINAL | BIP113 | 2 |
| BLK-067 | BIP113 cutoff switch | V:4143-4155 | finality cutoff = MTP(prev) when CSV active, else block time | BIP113 | 2 |
| BLK-068 | Block-level finality check | V:4157-4161 | every tx in block must be final (`bad-txns-nonfinal`) | — | 1 |
| BLK-069 | BIP34 coinbase height prefix | V:4163-4171 | coinbase scriptSig starts with CScriptNum(height) minimal encoding (`bad-cb-height`) | BIP34 | 3 |
| BLK-070 | BIP34 activation pin | CP:117-118 | mainnet: height 227931, hash 000000000000024b89…08b8 | BIP34 | 1 |
| BLK-071 | Buried deployment heights | CP:117-122, CP:149-167 | BIP65@388381, BIP66@363725, CSV@419328, segwit@481824 (mainnet) | BIP90 | 1 |
| BLK-072 | Buried = height compare | DS:DeploymentActiveAt:27-37 | deployment active at block ⇔ block height ≥ activation height | BIP90 | 1 |
| BLK-073 | BIP9 signal predicate | VI:Condition:79-82 | bit set iff (version & 0xE0000000)==0x20000000 and deployment bit set | BIP9 | 1 |
| BLK-074 | BIP9 period alignment | VB:GetStateFor:46-52 | state defined per period: evaluate at pindexPrev with (h+1) mod period == 0 | BIP9 | 3 |
| BLK-075 | BIP9 threshold counting | VB:100-110 | count signals among the `period` blocks ending at period boundary; ≥ threshold ⇒ LOCKED_IN | BIP9 | 3 |
| BLK-076 | BIP9 timeout | VB:108-109 | MTP ≥ nTimeout without threshold ⇒ FAILED | BIP9 | 2 |
| BLK-077 | BIP9 lock-in-on-timeout | VB:105-109 (order of tests) | threshold reached in the final period before timeout still locks in | BIP9 (2017 erratum) | 3 |
| BLK-078 | BIP9 min_activation_height | VB:111-117 | LOCKED_IN → ACTIVE only when next height ≥ min_activation_height | BIP9 | 2 |
| BLK-079 | ALWAYS_ACTIVE / NEVER_ACTIVE | VB:42-47 | nStartTime −1 ⇒ ACTIVE; −2 ⇒ FAILED, no state machine | — | 1 |
| BLK-080 | Genesis is DEFINED | VB:57-60 | null parent ⇒ DEFINED for every deployment | BIP9 | 1 |
| BLK-081 | Deployment table (mainnet) | CP:128-134 | only testdummy: bit 28, NEVER_ACTIVE, threshold 1815/period 2016 | BIP9 | 1 |
| BLK-082 | Deployment tables (other nets) | CP:371-377/649-655 | testnet4 1512/2016; regtest 108/144 start 0 | — | 1 |
| BLK-083 | Base script flags | V:GetBlockScriptFlags:2256-2260 | P2SH|WITNESS|TAPROOT always on | BIP16/141/341 | 1 |
| BLK-084 | Script-flag exceptions | CP:113-116 + V:2261-2264 | exception blocks: BIP16-exempt 0000…02dc…(NONE), taproot-exempt 0000…0f14…(P2SH|WITNESS) | BIP16, BIP341 | 2 |
| BLK-085 | DERSIG flag flow | V:2266-2269 | SCRIPT_VERIFY_DERSIG when BIP66 active at block | BIP66 | 1 |
| BLK-086 | CLTV flag flow | V:2271-2274 | CHECKLOCKTIMEVERIFY when BIP65 active | BIP65 | 1 |
| BLK-087 | CSV flag flow | V:2276-2278 + 2518-2523 | CHECKSEQUENCEVERIFY + LOCKTIME_VERIFY_SEQUENCE when CSV active | BIP68/112 | 1 |
| BLK-088 | NULLDUMMY with segwit | V:2280-2283 | NULLDUMMY when segwit active (BIP147) | BIP147 | 1 |
| BLK-089 | Coinbase output total | V:2608-2612 | Σ coinbase outputs ≤ fees + subsidy (`bad-cb-amount`) | — | 2 |
| BLK-090 | Subsidy schedule | V:GetBlockSubsidy:1833-1844 | subsidy = 50 COIN >> (height/210000); 0 when halvings ≥ 64 | — | 1 |
| BLK-091 | Fee accumulation range | V:2543-2548 | Σ fees must be in MoneyRange (`bad-txns-accumulated-fee-outofrange`) | — | 1 |
| BLK-092 | UTXO update step | V:UpdateCoins:1998-2011 | per input: SpendCoin (record undo); then add all outputs as coins | — | 2 |
| BLK-093 | OP_RETURN outputs not stored | C:AddCoin:82 | outputs with unspendable scriptPubKey are never inserted into the coin set | — | 2 |
| BLK-094 | Unspendable definition | script/script.h IsUnspendable | script empty or first byte OP_RETURN ⇒ unspendable | — | 1 |
| BLK-095 | Coinbase overwrite allowance | C:AddCoins:133-142 | coinbase coins may overwrite (models pre-BIP30 duplicates); others require explicit check | BIP30 | 3 |
| BLK-096 | BIP30 no-overwrite | V:2496-2511 | any output of the new block already in UTXO ⇒ invalid (`bad-txns-BIP30`) | BIP30, CVE-2012-1909 | 3 |
| BLK-097 | BIP30 repeat exception | V:IsBIP30Repeat:6207-6211 | blocks 91842 (…0a4d0a…) and 91880 (…0743f1…) are exempt on the canonical chain | BIP30 | 3 |
| BLK-098 | BIP30 post-BIP34 skip | V:2477-2494 | skip BIP30 once chain's block@BIP34Height has BIP34Hash, except ≥ height 1983702 re-enables | BIP30/34 | 4 |
| BLK-099 | BIP30 unspendable pair (disconnect) | V:IsBIP30Unspendable:6213-6218 + 2204-2212 | blocks 91722 (…0271a2…), 91812 (…0af0ae…) relax disconnect consistency; coinstats excludes first instances | BIP30 | 4 |
| BLK-100 | Coinbase maturity | TV:184-188, CC:19 | coinbase input spendable iff spendHeight − coinHeight ≥ 100 (`bad-txns-premature-spend-of-coinbase`) | — | 1 |
| BLK-101 | Coin = (out, height, coinbase) | C(Coins):Coin:45-72 | coin records value+script+creation height+coinbase bit (31+1 bits) | — | 1 |
| BLK-102 | Inputs exist | TV:173-176 | every prevout present in UTXO view (`bad-txns-inputs-missingorspent`) | — | 1 |
| BLK-103 | Value conservation per tx | TV:191-205 | Σin ≥ Σout, both in MoneyRange; fee = Σin − Σout (`bad-txns-in-belowout`) | — | 1 |
| BLK-104 | BIP68 sequence locks | V:2525-2538 + TV:CalculateSequenceLocks:45+ | tx BIP68-final vs entry heights/times of spent coins; enforced only in ConnectBlock | BIP68 | 4 |
| BLK-105 | Undo record content | V:UpdateCoins:2001-2008 | CTxUndo stores prior Coin per spent input, in input order | — | 2 |
| BLK-106 | Disconnect reversibility | V:DisconnectBlock:2198-2247 | replay undos in reverse; outputs re-checked against coins (mismatch ⇒ unclean) | — | 4 |
| BLK-107 | Disconnect skips unspendable | V:2214-2227 | unspendable outputs excluded from disconnect verification (symmetry with BLK-093) | — | 2 |
| BLK-108 | Undo/tx count consistency | V:2187-2192 | vtxundo.size()+1 == vtx.size() else treat as data corruption | — | 1 |
| BLK-109 | Genesis connect special case | V:2330-2334 | genesis block: skip tx connection, just set best block | — | 2 |
| BLK-110 | Genesis coinbase unspendable | CP:52-54 comment | genesis 50 BTC output never enters UTXO set (empty-set genesis state) | — | 2 |
| BLK-111 | Genesis values (mainnet) | CP:47-72,169-172 | time 1231006505, nonce 2083236893, bits 1d00ffff, coinbase text "The Times 03/Jan/2009…", hash 000000000019d668…ce26f, merkle 4a5e1e4b…a33b | — | 2 |
| BLK-112 | Genesis output script | CP:66-67 | P2PK to pubkey 04678afd…b6bf11d5f, 50 COIN | — | 1 |
| BLK-113 | Work function | CN:GetBitsProof:120-133 | work(nBits) = (~target/(target+1)) + 1; 0 for invalid decode | — | 2 |
| BLK-114 | Chainwork accumulation | chain.h nChainWork (CBlockIndex) | nChainWork(B) = nChainWork(prev) + work(B.nBits); genesis = own work | — | 1 |
| BLK-115 | Most-work rule | NS:CBlockIndexWorkComparator:174-189 + V:FindMostWorkChain:3126 | active tip = max nChainWork among valid, data-complete candidates | — | 3 |
| BLK-116 | Work tie-break | NS:174-189 | equal work ⇒ lower nSequenceId (earlier-received/active-chain) wins, then pointer order (non-consensus detail) | — | 3 |
| BLK-117 | Strict-improvement switching | V:3263, 3508 | tip changes only to strictly better work (ties keep current tip) | — | 2 |
| BLK-118 | Reorg = disconnect+connect | V:ActivateBestChainStep:3199-3270 | switch via DisconnectTip to fork point then ConnectTip forward, undo data per block | — | 3 |
| BLK-119 | Invalid-block caching | V:InvalidBlockFound:1987-1996, InvalidateBlock:3529+ | non-mutated failures mark BLOCK_FAILED_VALID; descendants pruned from candidates; pure memoization | — | 3 |
| BLK-120 | duplicate-invalid reuse | V:4205-4219 | cached-failed block re-submission rejected as `duplicate-invalid` without re-validation | — | 2 |
| BLK-121 | best_invalid bookkeeping | V:InvalidChainFound:1963-1984 | track highest-work invalid chain (warning/UI only) | — | 1 |
| BLK-122 | min-chainwork DoS gate | V:4270-4276 (`too-little-chainwork`) | headers below nMinimumChainWork not indexed pre-sync; anti-DoS, not consensus | — | 2 |
| BLK-123 | assumevalid skip | V:2344-2400 | script checks skippable below assumevalid ancestor with 2-week equivalent-time guard; trust-parameterized | — | 4 |
| BLK-124 | Parallel script checks | V:2570-2596 (CCheckQueue) | script verification parallelizable; results identical to serial | — | 2 |
| BLK-125 | 64-byte tx mutation guard | V:IsBlockMutated:4038-4048 | coinbase-less block with a 64-byte tx ⇒ mutated (relay-path only) | merkle paper 2019 | 3 |
| BLK-126 | Signet solution check | V:CheckBlock:3938-3940 | signet only: block solution satisfies challenge (BIP325); non-mainnet | BIP325 | 3 |
| BLK-127 | Witness cache flags | PB:79-82, V:3881/3926 | fChecked/m_checked_* are memoization only, no rule content | — | 1 |
| BLK-128 | Coinbase witness auto-fill | V:UpdateUncommittedBlockStructures:3993-4002 | mining fills 32-byte zero reserved value when segwit active; construction rule, mining-side | BIP141 | 2 |
| BLK-129 | Merkle path (aux/mining) | M:MerkleComputation:100-160 | constant-space path algorithm; equivalence with level-duplication tree is provable | — | 3 |
| BLK-130 | Timestamp window constant | CH:29-37 | MAX_FUTURE_BLOCK_TIME=7200 s also defines TIMESTAMP_WINDOW for headers sync | — | 1 |

*(130 rows; ~85 encode distinct normative checks, the rest structural definitions/memoization marked as such.)*

---

## Separation summary

**VERIFIED (read directly from source at `cce32b1682d…`):** every file:line citation above; all constants (4M weight, 80k sigops, 100 maturity, 7200 future time, 600 timewarp, 2016 window, ×/4–×4 clamp, 11-block MTP, 210000 halving); all four historic BIP30 block hashes and heights; mainnet genesis tuple; the single-deployment BIP9 table; the exception-block hashes; `AddCoin` OP_RETURN exclusion; the lock-in-before-timeout ordering.

**INFERRED (marked where used):**
- The brief's "coinbase-maturity negative height" does not exist in current code (K26) — inferred as a stale reference to pre-0.15 `CCoins`.
- "Early-days difficulty-1 exception" — none in current `pow.cpp`; the genesis/powLimit identity is the only difficulty-1 specialness; historical v0.1 anomalies inferred from chain history, not source.
- Tie-break-by-pointer being non-consensus-observable (it is deterministic given receive order, which consensus doesn't specify).
- Exact upstream PR/BIP-erratum attribution for lock-in-on-timeout (behavior VERIFIED in code; the erratum label is from BIP9 history).
- BIP94's "block storm mitigation" phrasing comes from the code comment (chainparams/testnet4) — mechanism (min-difficulty + timewarp bounds) VERIFIED, storm framing INFERRED.
