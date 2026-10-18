# 07 — Transaction-Validation Pipeline

**Commit verified against:** Bitcoin Core `master`, commit `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (2026-10-16), version 32.99 (pre-33 master).
All `file:line` citations below are against the canonical pin `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.

---

## Executive summary

1. The transaction-validation consensus core is remarkably small and clean: `CheckTransaction` (~50 lines, stateless), `Consensus::CheckTxInputs` (~50 lines, contextual), `IsFinalTx`/`CalculateSequenceLocks`/`EvaluateSequenceLocks` (~90 lines), and the per-input `VerifyScript` dispatch. Everything else in `validation.cpp` around them is caching, policy, or plumbing.
2. **Good news for Lean:** nearly every consensus tx rule is a pure function of `(tx, coins-for-inputs, spend-height, MTP/prev-block-time)`. No mutation leaks into the *checks*; mutation (`SpendCoin`/`AddCoin`/`UpdateCoins`) is only the *effect application* after checks pass, and it is sequential in block tx order.
3. Serialization **is** consensus (txid = double-SHA256 of the stripped serialization; the SegWit marker/flag/witness framing; "Superfluous witness record" is a consensus-relevant decode failure). The spec must define the byte format and both hash functions as first-class objects.
4. The error taxonomy (`TxValidationResult` + reject-reason strings) cleanly separates consensus (`TX_CONSENSUS`, `TX_MISSING_INPUTS`, `TX_PREMATURE_SPEND`) from policy (`TX_NOT_STANDARD`, `TX_MEMPOOL_POLICY`, …) — the consensus/policy boundary is visible in code, not a vibe.
5. The "negative-height marker" **does not exist in current master**: coinbase-ness is a `fCoinBase : 1` bitfield packed into the height's LSB on disk, and mempool coins carry the sentinel `MEMPOOL_HEIGHT = 0x7FFFFFFF` (txmempool.h:51). Historic `int`-height negative tricks are gone.
6. Money arithmetic is deliberately trivial to formalize: `CAmount = int64`, `MAX_MONEY = 21e6·COIN` inclusive bound, `MoneyRange` = `0 ≤ x ≤ MAX_MONEY`, checked **incrementally** at every addition (this incremental pattern is the direct descendant of the CVE-2010-5137/5139 184-billion-BTC overflow family).
7. Coinbase maturity is a strict inequality: spendable when `spend_height − coin_height ≥ COINBASE_MATURITY(100)`; i.e. a coinbase from block N is spendable in block N+100.
8. Consensus applies **no fee floor**: fee ≥ 0 is implied by `in ≥ out`; positive-fee rules are pure policy.
9. Per-epoch script flags come from one function, `GetBlockScriptFlags` (validation.cpp:2249), which is exactly the interface Lean needs: `flags : block_index → flag_set`, with a 2-block historical exception map for P2SH/Taproot.

---

## Key findings (VERIFIED unless noted)

| # | Finding | Citation |
|---|---------|----------|
| K1 | `CheckTransaction` is the complete stateless check set: non-empty vin/vout, stripped-size ≤ 4M weight, per-output and cumulative MoneyRange, duplicate prevouts, coinbase scriptSig 2–100, non-coinbase null-prevout ban | consensus/tx_check.cpp:19–68 |
| K2 | Duplicate-input check is in `CheckTransaction` (not in `CheckTxInputs`/`UpdateCoins`) — added after **CVE-2018-17144** (inflation/crash) | tx_check.cpp:44–53 |
| K3 | Output overflow checks cite **CVE-2010-5139** in-code; the same family includes CVE-2010-5137 (184-billion-BTC ConnectInputs overflow). Modern defense: incremental `MoneyRange` on both the in-side and out-side sums | tx_check.cpp:31–42; tx_verify.cpp:190–216 |
| K4 | `Consensus::CheckTxInputs` = existence (`HaveInputs`), maturity, input MoneyRange, `nValueIn ≥ GetValueOut()`, fee MoneyRange (last is unreachable-by-construction, documented) | tx_verify.cpp:170–220 |
| K5 | `IsFinalTx`: nLockTime==0 final; threshold 500,000,000 splits height- vs time-encoding; all-inputs `SEQUENCE_FINAL` overrides | tx_verify.cpp:23–43; script/script.h:48 |
| K6 | **BIP113**: in blocks, the time cutoff is the **MTP of the previous block** (post-CSV activation), else block time — implemented in `ContextualCheckBlock`, *not* in `IsFinalTx` itself | validation.cpp:4143–4157 |
| K7 | **BIP68**: enforced only if `tx.version ≥ 2 && LOCKTIME_VERIFY_SEQUENCE`; disable-flag (bit 31), type-flag (bit 22, 512s granularity), 16-bit mask; "minus 1" semantics flip between first-valid (BIP68) and last-invalid (nLockTime) conventions | tx_verify.cpp:45–101 |
| K8 | BIP68 in mempool context assumes mempool-input coins confirm at `tip+1` (`MEMPOOL_HEIGHT` sentinel) | validation.cpp:193–199, txmempool.h:51 |
| K9 | Mempool path runs the *consensus* checks at **height+1** (next block), block path at `pindex->nHeight` | validation.cpp:888–890 vs 2545 |
| K10 | Block script flags: P2SH+WITNESS+TAPROOT always on except two hash-listed historical blocks; DERSIG/CLTV/CSV/NULLDUMMY by BIP9 deployment | validation.cpp:2249–2286 |
| K11 | Sigop cost: legacy×4 + P2SH×4 + witness cost; block cap 80,000; per-tx in mempool checked against `MAX_STANDARD_TX_SIGOPS_COST` (policy) | tx_verify.cpp:118–168; consensus/consensus.h:17 |
| K12 | `Coin` = `{CTxOut out, fCoinBase:1, nHeight:31}`; serialized as `code = (nHeight << 1) \| fCoinBase` | coins.h:52–87 |
| K13 | `CAmount`/`MAX_MONEY`/`MoneyRange` are 12 lines total; MAX_MONEY is an inclusive sanity bound, not the supply cap | consensus/amount.h:12–27 |
| K14 | txid vs wtxid: both computed at construction; `wtxid == txid` iff no witness; script-execution cache keyed by `(wtxid, flags)` | transaction.cpp:81–96; validation.cpp:2086–2093 |
| K15 | Weight formula implemented as `stripped·3 + total` (= BIP141 `base·3 + total`) | consensus/validation.h:135–142 |

INFERRED (not from this clone, flagged): CVE-2010-5137 historical attribution details; BIP14x numbering trivia; anything in Appendix B marked (inf).

---

## Detailed analysis

### (a) Data structures — `src/primitives/transaction.{h,cpp}` + `src/serialize`

**The transaction object** (transaction.h:286–368): `vin : vector<CTxIn>`, `vout : vector<CTxOut>`, `version : uint32`, `nLockTime : uint32` — all `const` after construction; `hash (Txid)` and `m_witness_hash (Wtxid)` are memory-only caches (transaction.h:302–309, transaction.cpp:81–96).

- `COutPoint` (transaction.h:29–56): `{Txid hash, uint32 n}`; `NULL_INDEX = 0xffffffff`; `IsNull()` = null hash **and** NULL_INDEX — this is the coinbase prevout.
- `CTxIn` (transaction.h:62–135): `{prevout, CScript scriptSig, uint32 nSequence, CScriptWitness scriptWitness}`. Note the witness is **not** part of CTxIn's wire serialization (transaction.h:125); it travels in the SegWit extended format.
- `CTxOut` (transaction.h:140–173): `{CAmount nValue, CScript scriptPubKey}`; `IsNull()` is `nValue == -1` — a sentinel, *not* a consensus value.
- `SEQUENCE_FINAL = 0xffffffff` (transaction.h:77): disables nLockTime (`IsFinalTx`), fails CLTV (BIP65), disables BIP68. `MAX_SEQUENCE_NONFINAL = SEQUENCE_FINAL − 1` (transaction.h:83).
- `IsCoinBase()` = `vin.size() == 1 && vin[0].prevout.IsNull()` (transaction.h:347–350). A *definition*, not a check — but consensus-critical because every later rule branches on it.

**Serialization = consensus** (transaction.h:201–239 `UnserializeTransaction`):
1. `version` (uint32 LE), then attempt to read `vin` as a CompactSize-counted vector.
2. If vin came back **empty** and witness allowed: the first byte was the SegWit marker (0x00); read the flag byte; if flags ≠ 0, re-read vin and vout (transaction.h:212–218).
3. If `flags & 1`: read one witness stack (CompactSize-counted vector of CompactSize-counted byte vectors) **per input** (transaction.h:223–228).
4. If all witness stacks empty despite flag → `"Superfluous witness record"` decode failure (transaction.h:229–232).
5. Any other flag bits → `"Unknown transaction optional data"` (transaction.h:234–237).
6. `nLockTime` last. Note the witness section sits **between vout and nLockTime**.

**CompactSize** (serialize.h:333–361): `<0xfd` = 1 byte; `0xfd`→uint16; `0xfe`→uint32; `0xff`→uint64; non-minimal encodings are **rejected** ("non-canonical ReadCompactSize()") — canonicality is consensus because txid is computed over these exact bytes.

**Hashes:** `txid = dsha256(TX_NO_WITNESS serialization)`, `wtxid = dsha256(TX_WITH_WITNESS serialization)`, `wtxid = txid` when `!HasWitness()` (transaction.cpp:81–93; typed as `Txid`/`Wtxid` newtype wrappers in primitives/transaction_identifier.h:23+).

**Weight:** `GetTransactionWeight(tx) = stripped_size·(WITNESS_SCALE_FACTOR−1) + total_size = stripped·3 + total` (validation.h:139–142), `WITNESS_SCALE_FACTOR = 4` (consensus/consensus.h:21). This is BIP141's `base·3 + total` exactly; the block-weight side is covered in the block-level notes.

**Lean mapping:** a `Tx` structure with `version : Fin`-ish Nat, `vin : List TxIn`, `vout : List TxOut`, `locktime : Nat`; serialization as total functions `encode : Tx → Bytes`, `decode : Bytes → Option Tx` (decode must reproduce every failure mode above); `txid = sha256∘sha256 ∘ encodeNoWitness`.

### (b) Stateless checks — `consensus/tx_check.cpp:CheckTransaction`

Complete list (all verified, tx_check.cpp:19–68), all returning `TX_CONSENSUS`:

| Check | Reject string | Line |
|---|---|---|
| `vin.empty()` | `bad-txns-vin-empty` | 22–23 |
| `vout.empty()` | `bad-txns-vout-empty` | 24–25 |
| `GetSerializeSize(TX_NO_WITNESS(tx))·4 > MAX_BLOCK_WEIGHT` | `bad-txns-oversize` | 27–29 |
| per-output `nValue < 0` | `bad-txns-vout-negative` | 35–36 |
| per-output `nValue > MAX_MONEY` | `bad-txns-vout-toolarge` | 37–38 |
| cumulative `!MoneyRange(nValueOut)` | `bad-txns-txouttotal-toolarge` | 39–41 |
| duplicate prevouts (std::set insert) | `bad-txns-inputs-duplicate` | 49–53 |
| coinbase `scriptSig.size() ∉ [2,100]` | `bad-cb-length` | 55–58 |
| non-coinbase null prevout | `bad-txns-prevout-null` | 60–64 |

What "remains" relative to the old Satoshi-era `CheckTransaction`: the version check, the size-in-bytes check, and `MoneyRange` on inputs moved out (inputs are contextual now); there is **no consensus check on `tx.version`** (any version accepted; v3-TRUC is policy-only). The oversize check deliberately uses the **stripped** serialization "as that hasn't been checked for malleability" (tx_check.cpp:26) — full-weight tx-size consensus limits only exist at block level.

### (c) Contextual checks — given a CCoinsView

**Pipeline, real function names:**

- *Block path* (`Chainstate::ConnectBlock`, validation.cpp:2290+): per non-coinbase tx, in order:
  1. `Consensus::CheckTxInputs(tx, tx_state, view, pindex->nHeight, txfee)` (validation.cpp:2545) — existence, maturity, value math.
  2. accumulate `nFees`, `MoneyRange(nFees)` → `bad-txns-accumulated-fee-outofrange` (validation.cpp:2548–2552).
  3. `SequenceLocks(tx, nLockTimeFlags, prevheights, *pindex)` → `bad-txns-nonfinal` (validation.cpp:2555–2558); BIP68 flag `LOCKTIME_VERIFY_SEQUENCE` set iff CSV deployed (validation.cpp:2478–2481).
  4. `GetTransactionSigOpCost(tx, view, flags)`; block accumulator > `MAX_BLOCK_SIGOPS_COST` → `bad-blk-sigops` (validation.cpp:2563–2568).
  5. `CheckInputScripts(tx, …)` → per-input `CScriptCheck` (possibly queued to threads) (validation.cpp:2571–2597, def at 2060–2134).
  6. `UpdateCoins(tx, view, undo, nHeight)` (validation.cpp:2600–2606; coins.cpp:133–142 `AddCoins`, coins.cpp:144 `SpendCoin`).
  7. Final `bad-cb-amount`: coinbase payout ≤ fees + subsidy (validation.cpp:2611–2616).
  Also: BIP30 duplicate-coinbase-overwrite check before the loop (validation.cpp:2466–2474, `BIP34_IMPLIES_BIP30_LIMIT = 1983702` at 2429).
- *Mempool path* (`MemPoolAccept::PreChecks`, validation.cpp:790–910): `CheckTransaction` (795), `CheckFinalTxAtTip` (816), `CheckSequenceLocksAtTip` (884), **`Consensus::CheckTxInputs(…, m_active_chainstate.m_chain.Height() + 1, …)`** (889 — mempool validates for the *next* block), `GetTransactionSigOpCost(…, STANDARD_SCRIPT_VERIFY_FLAGS)` (905). Then `PolicyScriptChecks` (script flags = STANDARD, line 1140) and `ConsensusScriptChecks` (script flags = `currentBlockScriptVerifyFlags = GetBlockScriptFlags(tip)`, lines 1175–1178) — the code literally separates consensus flags from policy flags at these two call sites.

**`Consensus::CheckTxInputs` anatomy** (tx_verify.cpp:170–220):
1. `inputs.HaveInputs(tx)` → `TX_MISSING_INPUTS / bad-txns-inputs-missingorspent` (173–176). `HaveInputs` (coins.cpp:322–331) = every prevout has an unspent Coin (coinbase txs skip it).
2. Per input: `coin.IsCoinBase() && nSpendHeight − coin.nHeight < COINBASE_MATURITY` → `TX_PREMATURE_SPEND / bad-txns-premature-spend-of-coinbase` (185–188). `COINBASE_MATURITY = 100` (consensus.h:19).
3. Per input: `MoneyRange(coin.out.nValue)` and running `MoneyRange(nValueIn)` → `bad-txns-inputvalues-outofrange` (191–194).
4. `nValueIn < tx.GetValueOut()` → `bad-txns-in-belowout` (202–205). Note `GetValueOut()` **throws** on range violation — the code comment (tx_verify.cpp:197–200) documents why that cannot fire in validation paths (CheckTransaction ran first). For Lean this is a lemma, not an assumption.
5. `fee = nValueIn − value_out`, `MoneyRange(fee)` → `bad-txns-fee-outofrange`; comment proves `0 ≤ fee ≤ MAX_MONEY` unreachable (208–216). **Consensus fee floor is exactly 0.**

**Maturity mechanism:** `Coin = {CTxOut out; bool fCoinBase:1; uint32 nHeight:31}` (coins.h:52–55); disk serialization packs `code = (nHeight << 1) | fCoinBase` (coins.h:77–87). Mempool-coins view injects `nHeight = MEMPOOL_HEIGHT = 0x7FFFFFFF` (txmempool.h:51, txmempool.cpp:804,816), which `CalculatePrevHeights` maps to `tip+1` (validation.cpp:193–199). **There is no negative-height marker in current master** — the earlier claim likely refers either to this sentinel or to pre-0.15 encodings; VERIFIED-corrected.

**Error taxonomy** (consensus/validation.h:30–57): `TX_CONSENSUS` / `TX_INPUTS_NOT_STANDARD` / `TX_NOT_STANDARD` / `TX_MISSING_INPUTS` / `TX_PREMATURE_SPEND` / `TX_WITNESS_MUTATED` / `TX_WITNESS_STRIPPED` / `TX_CONFLICT` / `TX_MEMPOOL_POLICY` / `TX_NO_MEMPOOL` / `TX_RECONSIDERABLE` / `TX_UNKNOWN`. Only the first four (+ PREMATURE_SPEND, WITNESS_*) can arise from consensus failure; in `ConnectBlock` any tx failure becomes `BlockValidationResult::BLOCK_CONSENSUS` with the tx reason preserved (validation.cpp:2545–2549, 2591–2596). `ValidationState` itself (validation.h:81–130) is a mode+result+strings triple — trivially an `Except`/`Sum` type in Lean.

**Per-input script invocation:** `CheckInputScripts` (validation.cpp:2060–2134) skips coinbases (2069), checks the `(wtxid, flags)` execution cache (2086–2093), builds `PrecomputedTransactionData` with spent outputs (2095–2108), and creates one `CScriptCheck` per input (2116–2126); `CScriptCheck::operator()` (validation.cpp:2013–2026) calls `VerifyScript(scriptSig, prevout.scriptPubKey, witness, flags, CachingTransactionSignatureChecker(...))`. Flags come from `GetBlockScriptFlags` (block path) or STANDARD (mempool policy path) — see K10. The interpreter itself is covered in the script-interpreter note.

### (d) Sequence & locktime semantics

**`IsFinalTx(tx, height, time)`** (tx_verify.cpp:23–43):
- `nLockTime == 0` → final.
- `nLockTime < LOCKTIME_THRESHOLD(=500_000_000)` (script/script.h:48) → compare against **height**; else against **time**. The threshold is the 500k boundary (values < 500M are block numbers; ≥ 500M are Unix timestamps).
- Even if unsatisfied: all inputs `nSequence == SEQUENCE_FINAL` → final.

**BIP113:** not in `IsFinalTx`; the *caller* chooses the time. Block context: `ContextualCheckBlock` uses MTP of `pindexPrev` once CSV is active, else `block.GetBlockTime()` (validation.cpp:4143–4151), then enforces finality for every tx → `bad-txns-nonfinal` (validation.cpp:4153–4156). Mempool context: `CheckFinalTxAtTip` uses `tip.nHeight + 1` and `tip.GetMedianTimePast()` (validation.cpp:156–176). So the same `IsFinalTx` is evaluated at three (height, time) pairs depending on context — in Lean, keep `IsFinalTx : Tx → Height → Time → Bool` pure and make the context the *caller's* problem (exactly like Core does).

**BIP68** (`CalculateSequenceLocks`, tx_verify.cpp:45–101 + `EvaluateSequenceLocks` 103–111):
- Enabled iff `tx.version ≥ 2 && flags & LOCKTIME_VERIFY_SEQUENCE` (57).
- Disable flag (bit 31) → input contributes nothing; its prevheight is zeroed (71–75).
- Type flag (bit 22) → time-based: `nMinTime = max(nMinTime, MTP(ancestor(max(coinHeight−1,0))) + (seq & 0xffff)·512 − 1)` (79–94). Measured from the MTP of the block *before* the coin's block; the `−1` converts "first valid" (BIP68) to "last invalid" (nLockTime) semantics — the comment at 82–93 is the authoritative statement.
- Otherwise height-based: `nMinHeight = max(nMinHeight, coinHeight + (seq & 0xffff) − 1)` (96).
- `EvaluateSequenceLocks`: invalid iff `min_height ≥ block.nHeight ∨ min_time ≥ MTP(block.pprev)` (103–111). Granularity constant `SEQUENCE_LOCKTIME_GRANULARITY = 9` (=512=2⁹) (transaction.h:115); mask `0x0000ffff` (transaction.h:105).

**BIP65 CLTV** (`GenericTransactionSignatureChecker::CheckLockTime`, script/interpreter.cpp:1755–1786): (1) tx nLockTime and the stack operand must be the *same kind* (both < or both ≥ 500M); (2) `nLockTime_operand > tx.nLockTime` fails; (3) this input's `nSequence == SEQUENCE_FINAL` fails (prevents the finality override from silently bypassing CLTV). That's the whole rule — a clean cast to three boolean conditions. (Opcode plumbing: interpreter.cpp:565.)

**BIP112 CSV** (`CheckSequence`, interpreter.cpp:1792–1826): version ≥ 2 required; disable-flag on the *tx's* sequence fails; mask both sides with `TYPE_FLAG|0xffff`; type match; `operand_masked > tx_sequence_masked` fails. (Opcode site: interpreter.cpp:599.)

### (e) Replacement & mempool: policy vs consensus catalog (one line each — all NOT consensus)

| Policy rule | Location | Why not consensus |
|---|---|---|
| BIP125 RBF signaling/replaceability (`IsRBFOptIn`) | policy/rbf.h:56–57 | Nodes may accept/relay non-RBF txs; blocks containing "replaced" txs are still valid |
| Replacement constraints (fee increment ≥ incremental relay feerate, ≤100 affected clusters, descendants paid for) | policy/rbf.h:26, 87–91; validation.cpp:1194–1207 | Pure relay economics; no block invalidity |
| Min-relay feerate / feerate sorting | kernel/mempool_options.h:42 (`min_relay_feerate` = 1 sat/vB default) | Zero-fee txs can legally appear in blocks |
| Ancestor/descendant & cluster limits (25/25; cluster 64 / 101 KvB) | kernel/mempool_limits.h:20–27; policy/packages.h:19–30 | Block topology validity only needs acyclicity + per-tx rules |
| Package acceptance (25 txs, 404k weight) | policy/packages.h:19–24 | Same |
| Dust (`GetDustThreshold`, DUST_RELAY_TX_FEE=3000) | policy/policy.h:66, policy/policy.cpp:27–68 | Dust outputs are consensus-valid; spendable at any fee |
| Standardness of scripts (`IsStandardTx`, bare multisig, OP_RETURN ≤ 80 bytes datacarrier, scriptSig ≤1650, MAX_STANDARD_TX_WEIGHT=400k, MIN_STANDARD_TX_NONWITNESS_SIZE=65) | policy/policy.h:100; policy/policy.cpp:100+ | Explicitly "does not affect consensus validity" (policy/policy.h:104–107) |
| Per-tx sigop cap `MAX_STANDARD_TX_SIGOPS_COST` = 16k | policy/policy.h:46 | Block-level 80k cap is the consensus part |
| Ephemeral dust (`CheckEphemeralSpends`, MAX_DUST_OUTPUTS_PER_TX=1) | policy/policy.h:93; validation.cpp:1371,1525 | New (2025-era) relay/package policy |
| TRUC/v3 topology (version=3 policy) | policy (truc.h) | Version numbers have no consensus meaning |
| `incremental_relay_feerate`, mempool expiry, `max_size_bytes` | kernel/mempool_options.h:36–44 | Node-local memory management |

### (f) Fee/amount arithmetic & the CVE lineage

- `CAmount = int64_t` satoshis, `COIN = 100_000_000`, `MAX_MONEY = 21_000_000·COIN = 2.1e15` (fits in int64 with huge headroom; comment explicitly warns the constant is consensus-critical and a fork vector if changed) — consensus/amount.h:12–27.
- `MoneyRange(x) = 0 ≤ x ≤ MAX_MONEY` (amount.h:27). MAX_MONEY is an **inclusive** upper bound.
- The 184-billion-BTC incident (Aug 2010): int64 overflow when summing input/output values allowed `in − out` to wrap negative-negative into huge "fee". Modern code defends with **incremental** range checks at every accumulation point (tx_check.cpp:39–41; tx_verify.cpp:191–194) plus a provably-unreachable final check (tx_verify.cpp:208–216, whose comment is a ready-made Lean lemma: `0 ≤ in ≤ MAX_MONEY ∧ 0 ≤ out ≤ MAX_MONEY ∧ out ≤ in → MoneyRange(in − out)`). The in-code citation is CVE-2010-5139 (outputs); CVE-2010-5137 is the same-family input/fee overflow from the 0.3.x era (historical attribution INFERRED from CVE lists, not from this tree).
- `GetValueOut()` throws `std::runtime_error` on any non-MoneyRange intermediate (transaction.cpp:98–108) — a second, redundant layer.
- Fee floor: consensus requires only `fee ≥ 0` (via `in ≥ out`); everything above 0 is policy (see (e)). The block-level fee accumulator also gets a `MoneyRange` check (validation.cpp:2548–2552) — a block-level CVE-family guard.
- `WITNESS_SCALE_FACTOR = 4` (consensus.h:21) is the only magic in weight math; weight = `stripped·3 + total` (validation.h:139–142).

### (g) Weird cases

1. **OP_RETURN outputs**: zero consensus rules. Any scriptPubKey is serializable into a vout; `nValue ≥ 0` suffices. An OP_RETURN output is only "unspendable" because `OP_RETURN` always fails at spend time (script-interpreter territory); the coins sit in the UTXO set forever. The 80-byte datacarrier cap and "dust" classification are policy (policy/policy.h:84, kernel/mempool_options.h:47–53).
2. **0-value outputs**: fully valid (only bounds are `≥ 0`, `≤ MAX_MONEY`); they create real UTXO entries (AddCoins iterates all vouts, coins.cpp:133–142). A 0-value output is *not* `IsNull()` (`IsNull` is the `-1` sentinel that never appears on the wire).
3. **MAX_MONEY boundary**: a single output of exactly `21e6·COIN` passes (`> MAX_MONEY` fails, tx_check.cpp:37); a *sum* exactly at MAX_MONEY passes (`MoneyRange` inclusive); `MAX_MONEY + 1` total fails.
4. **Coinbase at the maturity boundary**: coinbase of block N; `CheckTxInputs` at height H fails iff `H − N < 100`. So the earliest valid spend is in block **N+100** (e.g. coinbase at height 900_000, first spendable at 900_100). Mempool path: uses `H+1`, so a coinbase needs 100 confs *including* the hypothetical next block — subtle off-by-one difference between mempool acceptance and block insertion (validation.cpp:888–890 vs 2545).
5. **Double-spend ordering within a block**: `ConnectBlock` processes txs **sequentially**, calling `UpdateCoins` (spend inputs, add outputs) after each tx's checks (validation.cpp:2571–2606). The *first* spender in block order wins; the second tx's `CheckTxInputs→HaveInputs` sees the spent coin → `bad-txns-inputs-missingorspent`. There is no explicit "same-block double-spend" rule — it falls out of the sequential cache mutation. In-block spending of a same-block output also works purely through this order (tx i+1 can spend tx i's output). **This is the one place order/mutation is load-bearing for consensus.**
6. **BIP30 duplicate txids**: pre-BIP34-compliant heights (and heights < 1,983,702) reject any block containing a txid that already exists in the UTXO set (`bad-txns-BIP30`, validation.cpp:2466–2474) — needed because two historical coinbases duplicated txids.
7. **wtxid/txid malleability**: pre-SegWit, txid covered scriptSig → third-party malleability; post-SegWit, txid excludes witness, and the mempool tracks both (`same-txid-different-wtxid` replacement paths, validation.cpp:1655–1660). Script execution cache is keyed by **wtxid** + flags (validation.cpp:2086–2093). Consensus-relevant residue: the "Superfluous witness record" rule and `TX_WITNESS_MUTATED`/`TX_WITNESS_STRIPPED` results (validation.h:37–47).
8. **Tx version**: no consensus check at all; `CURRENT_VERSION = 2` is a creation default (transaction.h:290). BIP68's "version ≥ 2" gate (tx_verify.cpp:57) is the only place version enters consensus.
9. **Coinbase identification edge**: a tx with exactly one input whose prevout is `(0×32, 0xffffffff)` **is** a coinbase by definition (transaction.h:347–350) and therefore *must* have scriptSig ∈ [2,100] and is exempt from script verification and HaveInputs; a two-input tx with a null prevout is `bad-txns-prevout-null`. There is no way to be "half coinbase".

---

## Implications for btc-lean

**Pure-function inventory (the good news).** All of the following are total/partial pure functions of small explicit inputs — directly translatable to Lean with no IO or state:

| Lean function (proposed) | Signature sketch | Core origin |
|---|---|---|
| `decodeTx` | `Bytes → Option Tx` (all failure modes) | transaction.h:201–239 |
| `encodeTx / encodeNoWitness` | `Tx → Bytes` | transaction.h:242–269 |
| `txid / wtxid` | `Tx → Hash` | transaction.cpp:81–93 |
| `txWeight` | `Tx → ℕ` | validation.h:139–142 |
| `isCoinBase` | `Tx → Bool` | transaction.h:347–350 |
| `checkTransaction` | `Tx → Except RejectReason Unit` | tx_check.cpp:19–68 |
| `isFinalTx` | `Tx → Height → Time → Bool` | tx_verify.cpp:23–43 |
| `calculateSequenceLocks` | `Tx → List Height → BlockIndex → Height × Time` | tx_verify.cpp:45–101 |
| `evaluateSequenceLocks` | `BlockIndex → Height × Time → Bool` | tx_verify.cpp:103–111 |
| `checkLockTime / checkSequence` | `… → Bool` (3/4 pure conditions) | interpreter.cpp:1755–1826 |
| `checkTxInputs` | `Tx → CoinView → Height → Except RejectReason Fee` | tx_verify.cpp:170–220 |
| `sigOpCost` | `Tx → CoinView → Flags → ℤ` | tx_verify.cpp:149–168 |
| `getMaxMoney`, `moneyRange` | constants + `ℤ → Bool` | amount.h |

Everything composes into: **`validateTx : Tx → CoinView → Height → Time → Flags → Except TxError Fee`** — a single pure function; the mempool/block contexts differ only in the height/time/flags arguments (tip+1 vs nHeight; MTP vs block time; STANDARD vs GetBlockScriptFlags — though for *consensus* only GetBlockScriptFlags matters).

**Where order/mutation leaks in (the honest list):**
1. `UpdateCoins` sequential application inside `ConnectBlock` — same-block spends and same-block chaining are defined by processing order (validation.cpp:2571–2606). Lean model: a fold over `block.vtx` threading a CoinView; the "first spender wins" property is then a *theorem*, which is a nice early proof target.
2. Coin insertion marks spendability; `AddCoin`'s `possible_overwrite` + BIP30 check guard duplicate txids (coins.cpp:80+, validation.cpp:2466–2474).
3. `Coin.nHeight` is fixed at insert time; maturity checks are pure reads afterwards. No other hidden state.
4. The script-execution/signature caches are pure optimizations — provable as "results equal results without cache" (a conformance test, and a lemma if we model them).
5. `GetValueOut()` throwing vs `CheckTransaction` pre-running it: encode as a lemma `checkTransaction tx = ok → (tx.GetValueOut() terminates with MoneyRange result)`.

**Rule-ID seeds:** every row of Appendix B maps 1:1 to a Lean definition or a case of one; the reject-reason string should ride along as a `@[reducible] def` so the differential harness can compare against Core's `GetRejectReason()` output.

**Testing vectors to steal:** `src/test/transaction_tests.cpp` (serialization), `test/functional/mempool_accept.py`, `mempool_packages.py`, the JSON `tx_valid`/`tx_invalid` fixtures (`src/test/data/txinvalid.json` etc.), BIP68/112/113 unit tests.

---

## Open questions & risks

1. **Version skew**: this report is pinned to `cce32b168…`; the originally requested pin (`cce32b168…`) was unavailable at clone time. Before the build phase, re-diff `consensus/{tx_check,tx_verify,validation,amount}.h/.cpp` and `primitives/transaction.*` against whatever commit the project freezes. Risk: low (tx-validation code is historically stable; the biggest recent churn is mempool cluster-based limits).
2. **BIP94 timewarp** (`MAX_TIMEWARP`, consensus.h:35) now lives in consensus/consensus.h — block-time territory, but it interacts with MTP-based locks; the boundary should be settled with the block-level analysis.
3. **`CheckTransaction` oversize check uses stripped size only** — confirm in the SegWit/Taproot analysis that the *full*-weight per-tx limit is genuinely absent from consensus (it is in this tree) so we don't over-constrain.
4. **The unreachable-fee-check invariant** (tx_verify.cpp:208–216) relies on call-order (`CheckTransaction` before `CheckTxInputs`). In Lean we should *prove* the invariant rather than preserve the dead check, but keep the reject string for conformance.
5. **CVE-2010-5137 vs -5139 attribution** needs a primary-source check (bitcointalk/Satoshi-era commit 0.3.11/0.3.13) before it enters the rule-ID database — flagged INFERRED here.
6. **Negative-height marker**: VERIFIED absent in master (replaced by `fCoinBase:1` bit + `MEMPOOL_HEIGHT` sentinel). If the historical claim meant pre-0.15 `CCoins`, the CVE/history analysis should confirm; don't spec it.
7. **Sigop-counting details** (`GetSigOpCount(fAccurate)`, `CountWitnessSigOps`, tapscript sigop counting) are shared with the script-interpreter analysis — this note claims only the *accounting aggregation* (tx_verify.cpp:118–168) and the 80k block cap; the per-opcode semantics rows belong there, to avoid double-bookkeeping.

---

## Recommendations

1. Model **serialization as consensus** from day one: `decodeTx : Bytes → Option Tx` with the exact SegWit framing rules and canonical-CompactSize rejection; txid/wtxid as pure functions over the encoding. This is where "the spec must run" gets proven cheaply (round-trip + hash against Core vectors).
2. Define `validateTx` as the single pure entry point (section above) and derive both block-context and mempool-context validation as parameterizations; keep `MEMPOOL_HEIGHT`-related tip+1 logic out of the consensus module (it's a mempool *approximation* of the next block, not a consensus rule).
3. Make **first-spender-wins-in-a-block** an explicit early theorem (fold over vtx), since it's the only place block tx order is consensus-visible from the tx layer.
4. Adopt Core's reject strings as literals in the Lean error type; the differential harness then matches on `(valid?, rejectCode)` pairs from `test/functional/mempool_accept.py` and the JSON tx fixtures.
5. Prove the money-safety lemma family early (incremental MoneyRange ⇒ no overflow; fee ∈ [0, MAX_MONEY]) — small, satisfying, and directly tied to the CVE lineage for the traceability matrix.
6. Coordinate with the block-level analysis on `ConnectBlock`'s fold structure and with the script-interpreter analysis on `VerifyScript`'s interface; freeze the *interface* `VerifyScript : ScriptSig → ScriptPubKey → Witness → Flags → Ctx → Bool` so the layers compose.

---

## Appendix A — Sources

Primary (all read at commit `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`, 2026-10-16):

- src/primitives/transaction.h, transaction.cpp, transaction_identifier.h
- src/consensus/tx_check.{h,cpp}, tx_verify.{h,cpp}, consensus.h, amount.h, validation.h, params.h
- src/validation.cpp (CheckFinalTxAtTip 156–175; CalculatePrevHeights 183–202; CheckSequenceLocksAtTip 255–270; MemPoolAccept::PreChecks 790–910; PolicyScriptChecks/ConsensusScriptChecks 1130–1180; CScriptCheck::operator() 2013–2026; CheckInputScripts 2060–2134; GetBlockScriptFlags 2249–2286; ConnectBlock 2290–2620; ContextualCheckBlock 4137–4160)
- src/coins.h, coins.cpp, src/undo.h, src/serialize.h, src/txmempool.{h,cpp}
- src/kernel/mempool_options.h, mempool_limits.h
- src/policy/policy.{h,cpp}, policy/rbf.h, policy/packages.h
- src/script/interpreter.cpp (CheckLockTime/CheckSequence 1755–1826), script/script.h (LOCKTIME_THRESHOLD, multisig limits)

Secondary (context, unverified against this tree): BIPs 14/30/34/65/68/112/113/125/141/144; CVE-2010-5137/5139, CVE-2018-17144, CVE-2012-2459 writeups.

## Appendix B — TX rule table

All locations @ commit `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`. Difficulty: 1 = trivially translatable, 5 = needs care/coordination.

| Rule ID | Rule/check | Core location (file:function:lines) | One-line spec | BIP/CVE ref | Diff |
|---|---|---|---|---|---|
| TXV-001 | vin non-empty | tx_check.cpp:CheckTransaction:22–23 | `vin ≠ ∅` else `bad-txns-vin-empty` | — | 1 |
| TXV-002 | vout non-empty | tx_check.cpp:CheckTransaction:24–25 | `vout ≠ ∅` else `bad-txns-vout-empty` | — | 1 |
| TXV-003 | stripped-size weight limit | tx_check.cpp:27–29 | `weight(stripped_serialization) ≤ 4_000_000` | BIP141 (block rule) | 2 |
| TXV-004 | output value ≥ 0 | tx_check.cpp:35–36 | `∀ o ∈ vout: o.value ≥ 0` | CVE-2010-5139 | 1 |
| TXV-005 | output value ≤ MAX_MONEY | tx_check.cpp:37–38 | `∀ o ∈ vout: o.value ≤ 21e6·COIN` | CVE-2010-5139 | 1 |
| TXV-006 | cumulative output range | tx_check.cpp:39–41 | running sum stays in `[0, MAX_MONEY]` | CVE-2010-5139/5137 | 2 |
| TXV-007 | no duplicate prevouts | tx_check.cpp:49–53 | prevouts pairwise distinct | CVE-2018-17144 | 1 |
| TXV-008 | coinbase scriptSig size | tx_check.cpp:55–58 | coinbase ⇒ `2 ≤ |scriptSig| ≤ 100` | — | 1 |
| TXV-009 | non-coinbase null prevout ban | tx_check.cpp:60–64 | non-coinbase ⇒ no prevout is `(0,0xffffffff)` | — | 1 |
| TXV-010 | coinbase definition | transaction.h:CTransaction::IsCoinBase:347–350 | coinbase ⇔ `|vin|=1 ∧ prevout₀ null` | — | 1 |
| TXV-011 | basic tx serialization | transaction.h:UnserializeTransaction:201–239 | version·vin·vout·nLockTime layout, LE, CompactSize-counted | — | 3 |
| TXV-012 | CompactSize canonicality | serialize.h:ReadCompactSize:333–361 | minimal-length encoding only | — | 2 |
| TXV-013 | SegWit marker/flag framing | transaction.h:212–222 | empty-vin ⇒ marker byte + flag byte, then re-read vin/vout | BIP144 | 3 |
| TXV-014 | witness serialization position | transaction.h:223–228 | flag&1 ⇒ one stack per input after vout, before nLockTime | BIP144 | 3 |
| TXV-015 | superfluous witness ban | transaction.h:229–232 | flag set but all stacks empty ⇒ decode failure | BIP144 | 2 |
| TXV-016 | unknown flag ban | transaction.h:234–237 | flag ∉ {1} ⇒ decode failure | BIP144 | 1 |
| TXV-017 | txid computation | transaction.cpp:ComputeHash:81–84 | `txid = dsha256(encodeNoWitness(tx))` | BIP141 | 2 |
| TXV-018 | wtxid computation | transaction.cpp:ComputeWitnessHash:86–93 | `wtxid = dsha256(encode(tx))`; = txid if no witness | BIP141 | 2 |
| TXV-019 | weight formula | consensus/validation.h:139–142 | `weight = stripped·3 + total` | BIP141 | 2 |
| TXV-020 | inputs exist/unspent | tx_verify.cpp:CheckTxInputs:173–176; coins.cpp:HaveInputs:322–331 | every prevout resolves to unspent coin | — | 2 |
| TXV-021 | coinbase maturity | tx_verify.cpp:185–188; consensus.h:19 | `spendH − coinH ≥ 100` for coinbase coins | — | 2 |
| TXV-022 | coin encoding (height+coinbase bit) | coins.h:52–87 | `Coin = {out, fCoinBase:1, nHeight:31}`; disk pack `(h<<1)\|cb` | — | 2 |
| TXV-023 | input value range | tx_verify.cpp:191–194 | per-coin and running input sum in `[0,MAX_MONEY]` | CVE-2010-5137 (inf) | 2 |
| TXV-024 | value conservation (in ≥ out) | tx_verify.cpp:202–205 | `Σin ≥ Σout` else `bad-txns-in-belowout` | — | 2 |
| TXV-025 | fee range | tx_verify.cpp:208–216 | `fee = Σin − Σout ∈ [0, MAX_MONEY]` (implied) | CVE-2010-5137 (inf) | 3 |
| TXV-026 | block fee accumulator range | validation.cpp:ConnectBlock:2548–2552 | block Σfees ∈ MoneyRange | CVE-2010-5137 (inf) | 2 |
| TXV-027 | locktime zero ⇒ final | tx_verify.cpp:IsFinalTx:25–26 | `nLockTime = 0` ⇒ final | — | 1 |
| TXV-028 | locktime encoding threshold | tx_verify.cpp:27–28; script.h:48 | `< 500_000_000` compares to height, else to time | — | 2 |
| TXV-029 | locktime comparison | tx_verify.cpp:27–28 | final iff `nLockTime < cutoff_height_or_time` | — | 2 |
| TXV-030 | SEQUENCE_FINAL override | tx_verify.cpp:38–42; transaction.h:77 | all inputs 0xffffffff ⇒ final regardless | — | 1 |
| TXV-031 | BIP113 MTP cutoff (block ctx) | validation.cpp:ContextualCheckBlock:4143–4151 | time cutoff = MTP(prev block) post-CSV, else block time | BIP113 | 3 |
| TXV-032 | block finality enforcement | validation.cpp:4153–4156 | every tx in block must be final else `bad-txns-nonfinal` | — | 2 |
| TXV-033 | mempool finality ctx (tip+1, tip MTP) | validation.cpp:CheckFinalTxAtTip:156–175 | evaluate at `tipH+1`, `MTP(tip)` | BIP113 | 3 |
| TXV-034 | BIP68 enable gate | tx_verify.cpp:57–63 | enforce iff `version ≥ 2 ∧ LOCKTIME_VERIFY_SEQUENCE` | BIP68 | 2 |
| TXV-035 | BIP68 disable flag | tx_verify.cpp:71–75; transaction.h:94 | sequence bit31 set ⇒ no relative lock | BIP68 | 1 |
| TXV-036 | BIP68 time-based lock | tx_verify.cpp:79–94; transaction.h:100,105,115 | bit22 set ⇒ `MTP(coin's parent) + (seq&0xffff)·512 − 1` | BIP68 | 4 |
| TXV-037 | BIP68 height-based lock | tx_verify.cpp:96 | else `coinHeight + (seq&0xffff) − 1` | BIP68 | 3 |
| TXV-038 | BIP68 −1 semantics | tx_verify.cpp:82–93 (comment), 94, 96 | lockpoints express *last invalid* height/time | BIP68 | 3 |
| TXV-039 | sequence-lock evaluation | tx_verify.cpp:EvaluateSequenceLocks:103–111 | fail iff `minH ≥ blkH ∨ minT ≥ MTP(blk.prev)` | BIP68 | 3 |
| TXV-040 | CSV in ConnectBlock gate | validation.cpp:2478–2481 | BIP68 flag set iff CSV deployment active at block | BIP112/68 | 3 |
| TXV-041 | mempool seqlock ctx (tip+1) | validation.cpp:CheckSequenceLocksAtTip:255–270; CalculatePrevHeights:183–202 | evaluate at `tipH+1`; mempool-input heights = tip+1 | BIP68 | 3 |
| TXV-042 | MEMPOOL_HEIGHT sentinel | txmempool.h:51; txmempool.cpp:804,816 | unconfirmed coins carry height 0x7FFFFFFF | — | 2 |
| TXV-043 | CLTV type-match | interpreter.cpp:CheckLockTime:1762–1768 | operand and tx.nLockTime same kind (< / ≥ 500M) | BIP65 | 2 |
| TXV-044 | CLTV comparison | interpreter.cpp:1771–1772 | fail iff `operand > tx.nLockTime` | BIP65 | 1 |
| TXV-045 | CLTV finality interlock | interpreter.cpp:1775–1786 | fail iff this input's sequence = 0xffffffff | BIP65 | 2 |
| TXV-046 | CSV version gate | interpreter.cpp:CheckSequence:1795–1797 | fail iff `tx.version < 2` | BIP112 | 1 |
| TXV-047 | CSV disable-flag fail | interpreter.cpp:1800–1802 | fail iff tx sequence bit31 set | BIP112 | 1 |
| TXV-048 | CSV mask+type+compare | interpreter.cpp:1805–1823 | mask both sides (bit22\|0xffff), type match, `operand ≤ seq` | BIP112 | 3 |
| TXV-049 | legacy sigop count | tx_verify.cpp:GetLegacySigOpCount:118–130 | Σ accurate=false counts over scriptSigs+scriptPubKeys | — | 3 |
| TXV-050 | P2SH sigop count | tx_verify.cpp:GetP2SHSigOpCount:132–147 | for P2SH prevouts, count with scriptSig as subscript; coinbase = 0 | BIP16 | 3 |
| TXV-051 | witness sigop count | tx_verify.cpp:160–167; interpreter.h:CountWitnessSigOps:381 | per-input witness program sigop cost | BIP141 | 4 |
| TXV-052 | sigop cost scaling | tx_verify.cpp:151,157 | legacy+P2SH counts ×WITNESS_SCALE_FACTOR | BIP141 | 2 |
| TXV-053 | block sigop cap | validation.cpp:2563–2568; consensus.h:17 | block ΣsigopCost ≤ 80_000 else `bad-blk-sigops` | BIP141 | 2 |
| TXV-054 | multisig sigop counting constant | script.h:35 | non-accurate CHECKMULTISIG = 20 | — | 2 |
| TXV-055 | per-epoch script flags | validation.cpp:GetBlockScriptFlags:2249–2286 | `flags(blk) = base ∪ active-deployment flags` | BIP66/65/112/141/341 | 4 |
| TXV-056 | flag exception blocks | validation.cpp:2260–2265; consensus/params (script_flag_exceptions) | 2 historical blocks use reduced flag sets (P2SH/Taproot) | BIP16 | 3 |
| TXV-057 | NULLDUMMY w/ SegWit | validation.cpp:2282–2285 | BIP147 enforced from SegWit activation | BIP147 | 2 |
| TXV-058 | per-input script invocation | validation.cpp:CheckInputScripts:2116–2126; CScriptCheck::operator():2013–2026 | each input: VerifyScript(sig, prevout.spk, witness, flags) | — | 3 |
| TXV-059 | coinbase skips script checks | validation.cpp:2068–2069 | coinbase inputs never script-verified | — | 1 |
| TXV-060 | script result → tx result mapping | validation.cpp:2127–2137 | consensus flags ⇒ TX_CONSENSUS; extra ⇒ TX_NOT_STANDARD | — | 2 |
| TXV-061 | mempool consensus-flag re-check | validation.cpp:1175–1178 | mempool re-runs scripts under current-block (consensus) flags | — | 3 |
| TXV-062 | script exec cache by (wtxid,flags) | validation.cpp:2086–2093 | cache keyed by witness hash + flags (optimization, provably transparent) | — | 3 |
| TXV-063 | BIP30 duplicate-txid ban | validation.cpp:2466–2474; 2429 | pre-BIP34(-limit) blocks: no txid may already exist in UTXO set | BIP30 | 3 |
| TXV-064 | same-block spend ordering | validation.cpp:2571–2606 (loop) + coins.cpp:SpendCoin:144 | sequential UpdateCoins; first spender in block order wins | — | 4 |
| TXV-065 | in-block output reuse | validation.cpp:2571–2606 | tx i+1 may spend tx i's outputs (cache-first semantics) | — | 3 |
| TXV-066 | OP_RETURN outputs consensus-valid | (absence: no consensus check; spend fails at interpreter) | any spk allowed; value rules only | — | 1 |
| TXV-067 | zero-value outputs valid | tx_check.cpp:35–41 (only bounds) | `value = 0` outputs create spendable-looking UTXOs | — | 1 |
| TXV-068 | MAX_MONEY inclusive bound | amount.h:26–27 | `MAX_MONEY = 2.1e15` sat, inclusive | — | 1 |
| TXV-069 | CAmount = int64 satoshis | amount.h:12–15 | all value arithmetic in i64, checked incrementally | CVE-2010-5137 | 2 |
| TXV-070 | maturity boundary exactness | tx_verify.cpp:185 | coinbase of N first spendable in N+100 (block ctx); N+101 needed for mempool-at-tip+1 acceptance | — | 3 |
| TXV-071 | tx version unconstrained (consensus) | transaction.h:290; (absence of check) | any 32-bit version valid; BIP68 gate at ≥2 | — | 1 |
| TXV-072 | coinbase exempt from HaveInputs | coins.cpp:HaveInputs:322–331 | coinbase txs never input-checked | — | 1 |
| TXV-073 | wtxid mempool identity | transaction.cpp:86–93; validation.cpp:1655–1657 | mempool dedup/conflict by wtxid; txid-equivalence handled separately | BIP141 | 3 |
| TXV-074 | GetValueOut totality precondition | transaction.cpp:98–108; tx_verify.cpp:197–200 comment | `checkTransaction = ok ⇒ GetValueOut` terminates in range (lemma) | CVE-2010-5139 | 3 |
| TXV-075 | coin "spent" representation | coins.h (Fresh/Dirty flags, IsSpent) | spent ⇔ absent-from-cache-or-spent-bit; Undo restores on disconnect | — | 3 |

**Row count: 75.** (The original target was 60+; surplus comes from serialization-as-consensus and sigops accounting rows. Rows TXV-049/051/054 overlap the interpreter analysis — flagged in Open questions.)

---

*Report 07. All file:line citations verified against the cloned tree; INFERRED items explicitly marked.*
