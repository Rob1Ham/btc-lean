# Wallet differential corpus

This directory holds a deterministic differential corpus for the wallet-facing
RPC paths that sit on top of the proven consensus model: descriptor parsing,
key derivation, address/scriptPubKey agreement, PSBT construction and signing,
and funding arithmetic.  It is evidence about one pinned Bitcoin Core
development tree, not a consensus proof and not a claim about any shipped
release.

## Provenance

| Item | Value |
|---|---|
| Binary | `<core-build>/build/bin/bitcoind` |
| `bitcoind --version` | `v32.99.0-cce32b16874e` |
| Source tree | `<core-build>/src` |
| Commit suffix reported by the binary | `cce32b16874e` |
| Client version in source | 32.99.0 (`src/CMakeLists.txt:30-33`) |
| Wallet support | enabled at build time (`ENABLE_WALLET=ON`) |
| Chain | `regtest`, mock time `1600000000`, 101 blocks |
| Corpus format | `wallet-diff-jsonl-v1` |
| Cases | 192 (153 RPC observations, 39 evaluated checks, 22 recorded error contracts) |
| Size | about 135 KiB |

An earlier plan called the pinned tree a v21.99
snapshot.  The checked-out source and the binary identify themselves as
32.99.0, with commit suffix `cce32b16874e`; this corpus follows the source and
binary actually used.  The wallet RPCs in this corpus require a build with
wallet support.  The stock build in that tree was originally configured with
`ENABLE_WALLET=OFF`; it was reconfigured to `ON` and `bitcoind` was rebuilt
before generation.  Verify with:

```sh
/path/to/bitcoind --version
/path/to/bitcoind -help | grep -i 'wallet component'
```

## Files

* `cases.jsonl` — one case per line, compact canonical JSON.
* `manifest.json` — pinned version, counts, and the SHA-256 of the exact
  `cases.jsonl` bytes.
* `bip32.jsonl` — 33 BIP32 rows: 17 valid chains from official vectors 1-4
  and 16 rejected keys from vector 5. Fields: `id`, `seed_hex`, `path`,
  `expected_xprv`, `expected_xpub`, `expected_pubkey_hex`, `source`, plus
  `core_source`, `valid`, and (for vector 5) `reason`.
* `bip32_core.jsonl` — 73 regtest observations over that corpus: 17 fixed
  xpub rows with three address types, 40 ranged CKDpub rows, and 16 Core
  rejections of the invalid keys.
* `bip32_core.manifest.json` — bitcoind version, counts, and SHA-256 of
  `bip32_core.jsonl`.
* `../bips/bip-0032.mediawiki` — the official BIP32 text the extractor reads.

The BIP32 corpus and its harness are described in `BIP32DIFF.md` at the
repository root. Its generators are
`spec/runners/wallet_diff/bip32_extract.py` and
`spec/runners/wallet_diff/bip32_check.py`.

Every case in `cases.jsonl` has an `id`, `kind` (`rpc` or `check`), and an
`expect` object.
RPC cases also carry `method`, `params`, and, for wallet RPCs, the wallet
endpoint name:

```json
{"id":"desc.derive.wpkh_r0","kind":"rpc","method":"deriveaddresses",
 "params":["wpkh(0279...1798)#ucxz0gak"],"expect":{"result":["bcrt1qw508..."]}}
```

Errors are recorded with Core's exact code and message:

```json
{"id":"desc.derive.missing_checksum","kind":"rpc","method":"deriveaddresses",
 "params":["wpkh(0279...1798)",[0,0]],
 "expect":{"error":{"code":-5,"message":"Missing checksum"}}}
```

Check cases record an assertion that was evaluated during generation and an
`inputs` object containing the compared values:

```json
{"id":"fund.bech32.r10.fee_rate_met","kind":"check",
 "check":"fee_sats >= fee_rate * vsize",
 "inputs":{"fee_sats":1410,"fee_rate":10,"vsize":141,"effective_sat_per_vb":10.0},
 "expect":true}
```

Results of large RPCs are projected to stable fields before being written:
`decodepsbt` keeps PSBT version, fee, unsigned txid/vsize, output scripts, and
partial-signature count; `decoderawtransaction` keeps identity, size, and
output scripts; `analyzepsbt` keeps per-input progress and estimates;
`listdescriptors(true)` is projected to presence/range metadata so private
keys are not written to the corpus; `getwalletinfo`, `getnetworkinfo`, and
`getblockchaininfo` keep only deterministic fields.

## Regeneration and replay

The harness is `spec/runners/wallet_diff/run.py`.  It uses only the Python 3
standard library and starts a private regtest datadir under a temporary
directory outside the corpus.

```sh
cd spec/runners/wallet_diff

# Regenerate this corpus and its manifest.
python3 run.py --emit

# Re-run every scenario against a fresh daemon and compare with the corpus.
python3 run.py --replay

# Ten-case end-to-end check: start, record, shut down.
python3 run.py --smoke

# Compare a Lean-side JSON file with the corpus.
python3 run.py --compare-json /path/to/lean-output.json
python3 run.py --compare-json /path/to/lean-output.json --only fund.
python3 run.py --compare-json /path/to/lean-output.json --allow-partial
```

`--bitcoind PATH` selects another wallet-enabled binary.  `--keep` preserves
the temporary datadir; the default is to remove it after a clean shutdown.
`--compare-json` accepts an array of `{"id": ..., "result": ...}` or
`{"id": ..., "error": {...}}` objects, a single such object, or a mapping from
case id to result.  Checks are represented as `{"id": ..., "result": true}`.
By default every corpus id must be present; `--allow-partial` compares the
intersection and reports coverage.

The corpus is deterministic: two independent `--emit` runs produced
byte-identical files.  The recipe is fixed test key, fixed mock time, fixed
mining address, fixed explicit funding input, fixed change address and change
position, PSBT v0, no broadcast, and no wallet keypool address generation.
The manifest SHA-256 lets a reader detect accidental edits.

## What is covered

| Prefix | Cases | Scope |
|---|---:|---|
| `context.` | 3 | daemon version, chain tip, wallet shape |
| `desc.` | 54 | `getdescriptorinfo` checksum/parse/redaction, `deriveaddresses`, multipath, ranges, errors |
| `import.` | 9 | `importdescriptors`, `listdescriptors`, watch-only wallet, duplicate and malformed imports |
| `addr.` | 30 | `validateaddress`, `getaddressinfo`, `decodescript`, scriptPubKey agreement for P2PKH, P2SH-P2WPKH, P2WPKH, P2WSH, P2SH-multisig, P2TR |
| `psbt.` | 15 | create → sign (without finalizing) → decode → analyze → finalize → decode raw → `testmempoolaccept`; malformed PSBT and funding errors |
| `fund.` | 81 | 3 output types × 3 fee rates (1, 10, 50 sat/vB), each with create/decode/sign/finalize/raw tx/accept plus fee, change, and vsize checks |

The funding matrix observed these exact signed sizes and fees:

| Recipient type | vsize | fee at 1 | fee at 10 | fee at 50 |
|---|---:|---:|---:|---:|
| P2WPKH (`bech32`) | 141 vB | 141 sat | 1,410 sat | 7,050 sat |
| P2SH-P2WPKH (`p2sh-segwit`) | 142 vB | 142 sat | 1,420 sat | 7,100 sat |
| P2PKH (`legacy`) | 144 vB | 144 sat | 1,440 sat | 7,200 sat |

All three rates meet `fee >= rate * vsize` exactly in this sample.  This is an
observation about the pinned tree and these transaction shapes, not a theorem
about all wallets or all signature sizes.

## What is not modeled

* No consensus claim.  The corpus does not prove that a script executes, that
  a signature is valid under consensus, or that a block is valid; those are
  the existing model's obligations.
* No wallet database format, encryption, key storage, backup, migration, or
  crash durability.
* No networking, peer behavior, mempool relay, RBF, CPFP, package relay,
  ancestor/descendant limits, or fee estimation from a live mempool.
* No PSBT v2.  The pinned tree accepts v0 and v2 (`src/psbt.h:97`,
  `src/psbt.cpp:23`); this corpus records only v0.
* No taproot script-path signing and no multisig spending.  Taproot appears
  only as descriptor expansion and address/script agreement; P2WSH and P2SH
  multisig appear only as addresses.
* No dust-change, subtract-fee-from-output, send-all, coin-selection, or
  keypool-exhaustion cases.  The funding input is explicit and amounts are far
  above dust.
* No claim that a descriptor or address is safe to use.  The corpus records
  parse/expand/sign behavior only.
* No hardware-wallet, GUI, or external-signer protocol.

## Consensus, policy, and wallet-policy traps

The following are the places where a result in this corpus must not be read as
a consensus rule.  Each claim was checked against the pinned source.

1. **The requested fee rate is a policy target, not an exact signed-size
   law.**  Core estimates the maximum signed size, computes the fee with that
   size, and may leave the final transaction smaller after signing.  The
   funding path is `FundTransaction` at `src/wallet/spend.cpp:1502`; the
   estimate and fee are at `src/wallet/spend.cpp:1332-1337`;
   `CFeeRate::GetFee` rounds up with `EvaluateFeeUp`
   (`src/policy/feerate.cpp:21-27`).  A signed transaction therefore satisfies
   `fee >= requested_rate * actual_vsize`, not necessarily equality.  The
   three shapes above happen to land exactly.

2. **`testmempoolaccept` has a client-side fee-rate cap.**  The default
   `maxfeerate` is 0.1 BTC/kvB (`src/node/transaction.h:28`), applied in
   `src/rpc/mempool.cpp:329` and `:381`.  A transaction paying 10 sat/vB is
   rejected with `reject-reason: "max-fee-exceeded"`
   (`src/rpc/mempool.cpp:434`) when the caller passes `maxfeerate=0.00001`.
   This is policy and a client guard, not consensus invalidity; the same bytes
   are accepted under the default cap.

3. **Dust is policy.**  `IsDust` is
   `src/policy/policy.cpp:66`; the default dust relay rate is 3000 sat/kvB
   (`src/policy/policy.h:68`).  Change below the dust threshold is dropped
   rather than created.  This corpus does not exercise that branch, so it
   makes no claim about dust-change arithmetic.

4. **The minimum relay fee is policy.**  `DEFAULT_MIN_RELAY_TX_FEE` is
   100 sat/kvB, i.e. 1 sat/vB (`src/policy/policy.h:70`).  The 1 sat/vB
   funding row sits exactly on that floor; lower rates are not covered.

5. **`walletprocesspsbt` finalizes by default.**  Its `finalize` argument
   defaults to true (`src/wallet/rpc/spend.cpp:1615`).  The PSBT lifecycle
   therefore passes `finalize=false` explicitly to expose the partial
   signature, then calls `finalizepsbt` (`src/rpc/rawtransaction.cpp:1669`).
   Without that explicit argument, a caller may mistake "signed and finalized"
   for "signed only".

6. **`getdescriptorinfo` redacts private keys but keeps the input checksum.**
   The result descriptor is documented as "without private keys"
   (`src/rpc/output_script.cpp:188`), while `checksum` is computed from the
   input (`src/rpc/output_script.cpp:224`).  For a master `tprv` with a
   hardened path, the redacted `tpub` is not derivable without the private key;
   `deriveaddresses` then reports "Cannot derive script without private keys"
   (`src/rpc/output_script.cpp:241`).  This is why the corpus records both the
   redacted descriptor and that error.

7. **Both `deriveaddresses` and `importdescriptors` require a checksum.**
   `deriveaddresses` calls `Parse` with `require_checksum=true`
   (`src/rpc/output_script.cpp:325`); `CheckChecksum` reports "Missing
   checksum" (`src/script/descriptor.cpp:2978`).  `importdescriptors` likewise
   rejects bare descriptors per request (`src/wallet/rpc/backup.cpp:175`).
   The checksum is a typo detector, not a security mechanism
   (`src/script/descriptor.cpp:141`).

8. **Descriptor ranges are wallet policy, not descriptor identity.**
   Importing an active ranged descriptor with `range: [0,10]` causes the
   wallet to top up its cache to the keypool target; `listdescriptors` then
   reports a wider range such as `[0,999]` or `[0,1000]`.  The top-up logic
   is `src/wallet/scriptpubkeyman.cpp:1131-1178`.  The corpus records the
   observed expanded range, not the requested one.

9. **`iswatchonly` is deprecated and always false.**  The wallet RPC result
   documentation says so at `src/wallet/rpc/addresses.cpp:428`.  A watch-only
   descriptor wallet can still report `ismine: true` for an imported public
   descriptor; the corpus records that observed shape.  Do not use
   `iswatchonly` as a consensus or ownership predicate.

10. **Address/scriptPubKey agreement is structural.**  `validateaddress`
    derives the script with `GetScriptForDestination`
    (`src/rpc/output_script.cpp:81-82`); `getaddressinfo` reports the same
    script (`src/wallet/rpc/addresses.cpp:426`); `decodescript` reverses the
    mapping (`src/rpc/rawtransaction.cpp:476`).  Agreement shows the three
    encodings describe the same output, not that the output can be spent.

## Source anchors

All paths are relative to the pinned tree's `src/` directory.

* Descriptor checksum: `script/descriptor.cpp:141`,
  `script/descriptor.cpp:2978`.
* Descriptor inspection and redaction: `rpc/output_script.cpp:175`,
  `:188`, `:224`.
* Descriptor derivation and range rules: `rpc/output_script.cpp:267`,
  `:325`, `:331`, `:335`, `:241`, `:252`.
* Descriptor import/list: `wallet/rpc/backup.cpp:175`, `:193-197`,
  `:313`.
* Address/script RPCs: `rpc/output_script.cpp:38`, `:51`, `:81-82`;
  `wallet/rpc/addresses.cpp:413`, `:426`, `:428`;
  `rpc/rawtransaction.cpp:476`.
* PSBT: `rpc/rawtransaction.cpp:1074`, `:1669`, `:1972`;
  `wallet/rpc/spend.cpp:1596`, `:1615`; `psbt.h:97`; `psbt.cpp:23`.
* PSBT signing and finalization: `wallet/rpc/spend.cpp:1596`,
  `rpc/rawtransaction.cpp:1669`.
* Funding: `wallet/rpc/spend.cpp:1680`, `:526`, `:537`;
  `wallet/spend.cpp:1502`, `:1332-1337`.
* Fee arithmetic: `policy/feerate.cpp:21-27`.
* Mempool acceptance: `rpc/mempool.cpp:313`, `:329`, `:381`, `:434`;
  `node/transaction.h:28`.
* Dust and relay floors: `policy/policy.cpp:66`;
  `policy/policy.h:68`, `:70`.

## Safety note

The private key in the corpus is a disposable BIP32 test key used only on
regtest.  It must never be used on a public network.  The corpus contains no
mainnet keys, no wallet passphrases, and no user data.
