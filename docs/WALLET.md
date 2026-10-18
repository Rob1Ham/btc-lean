# The wallet layer


The generated declaration/obligation index is
[`WALLET-THEOREMS.md`](WALLET-THEOREMS.md).

## 1. What this layer is, and what it is not

The wallet layer is an executable specification of how a wallet turns descriptors and keys into
scripts, constructs and signs PSBTs, and builds funded transactions. Its claims are stated
*relative to* the existing consensus model: a wallet output is claimed sound when the script,
transaction, and value it produces satisfy the interpreter, serialization, and conservation
predicates that the consensus artifact already uses.

It is not a second consensus specification. No wallet module is imported by `Bitcoin.lean` or
`BitcoinProofs.lean`, no wallet row is merged into `spec/db/rules.yaml`, and no wallet theorem
changes an existing consensus rule. The consensus census remains 726 rows (676 proven, 50
obsolete), as enforced by `spec/scripts/wallet_isolation.py`.

Soundness is therefore conditional and graded. A wallet row is discharged by a Lean theorem, by
a finite executable check, or by differential observation against Bitcoin Core. Only the first
is a proof; the other two are evidence about a model or a pinned binary, and they are labeled as
such throughout.

## 2. Five property families

The families correspond to the census namespaces; obligation labels follow the proof-surface contract (D/K for descriptors and keys, M for Miniscript, P for PSBT, W for spend).

| Family (namespace) | Obligation | Grade | Status at this commit |
|---|---|---|---|
| Descriptors and key expressions (`DESC`, 30 rows) | D1–D8: checksum, parse-error taxonomy, script-byte expansion, provider completeness; K1–K4: origin/path composition, xprv/xpub agreement, hardened rules, watch-only | theorem; finite checksum/parser vectors | planned; 8 rows tagged; 23 obligation rows (6 PARTIAL, 17 UNMODELLED); 20 DESC obligation `Prop`s declared; BIP32 agreement is a target |
| Miniscript (`MS`, 35 rows) | M1 type soundness; M2 exact opcode emission; M3 sane node + satisfaction accepted by the interpreter; sanity reasons | theorem; runtime vectors | planned; 19 rows tagged; 13 obligation rows (8 PARTIAL, 5 UNMODELLED); 3 corrected statements; operation/stack limits omitted |
| PSBT v0 (`PSBT`, 30 rows) | P1 field exclusivity; P2 unknown-field preservation; P3/P4 decode∘encode and canonical-byte fixed point; P5–P8 lifecycle and extraction | theorem; Core-validated vectors | planned; 12 rows tagged; 20 obligation rows (10 PARTIAL, 10 UNMODELLED); map/lifecycle lemmas present; whole-file round trips are targets |
| Spend construction (`WSP`, 31 rows) | W1 conservation; W2 fee floor; W3 change non-negativity; W4 fee monotonicity; W5 fee-rate bound after signing; W6 selection validity | theorem for arithmetic; differential-only for selection policy | planned; 1 row tagged; 30 obligation rows (6 PARTIAL, 24 UNMODELLED); conservation/funding laws present; selection policy is differential |
| Wallet signing (`SGN2`, 14 rows), with K5–K6 | K5 taproot program equality; K6 control-block validity; SGN2 signing-manager and sighash behaviours | theorem conditional on a `SignerSpec`; differential-only signer | planned; 0 rows tagged; 13 UNMODELLED obligations plus 1 corrected statement; no signer model |

The table's status column is the census status, not a count of local lemmas. All 140 rows
remain `status: planned` because the row-level contract is not closed. Forty rows carry a
`@[walletRule "<ID>"]` tag; 37 are recorded as entailed, and three tagged rows also have
partial obligations. The obligation register covers 99 rows (30 PARTIAL, 69 UNMODELLED),
and four further rows had contradicted text corrected. The tag index is **not** a claim
that all 140 rows are proved against Core.

## 3. Architecture as built

```
spec/core/Bitcoin/Wallet/
  RuleAttr.lean
  Encoding/{Base58,Bech32}.lean        Encoding.lean
  Crypto/{Sha512,Hmac}.lean
  Key/{Origin,Bip32}.lean
  Descriptor/{Ast,Checksum,Parse,Expand}.lean  Descriptor.lean
  Miniscript/{Type,Node,Script,Satisfy,Tests}.lean  Miniscript.lean
  Psbt/{Model,Decode,Encode,Laws,Tests}.lean  Psbt/Psbt.lean
  Spend/{Fee,Funding,Selection,Laws}.lean  Spend.lean
  Taproot/Commit.lean
```

The proofs tree contains per-family modules for the tagged rows (`Desc/Checksum.lean`,
`Desc/Expand.lean`, `Miniscript/TypeSound.lean`, `Miniscript/ScriptExact.lean`,
`Miniscript/SatShape.lean`, `Psbt/RoundTrip.lean`, `Spend/Selection.lean`), `Obligations.lean`
(73 `Prop` declarations in total; 24 cover DESC/WSP rows), and `Taproot/Program.lean` (five re-exported program
facts). There is no umbrella `Wallet.lean` on either side. `Sign/Bridge.lean`
exists as the conditional signing bridge; `EndToEnd.lean` is absent.

Dependency direction is one-way: wallet core imports only `Bitcoin.Data.*`, `Bitcoin.Crypto.*`,
`Bitcoin.Numeric.Amount`, `Bitcoin.Serialization.Interface`, and
`Bitcoin.Conservation.Interface`; wallet proof modules import wallet core and core. Neither
umbrella root imports a wallet module, and `wallet_isolation.py` rejects any `Bitcoin.Wallet`
reference outside the wallet trees.

Wallet code is arranged for two opt-in Lake libraries, `BitcoinWallet` and
`BitcoinProofsWallet`. Those library targets are not yet declared: the tree has the existing
`core` package (library `Bitcoin`) and `proofs` package (library `BitcoinProofs`), so wallet
modules are built by exact module name and `lake build Bitcoin` does not build them.

Traceability uses `@[walletRule "DESC-001"]`, registered as a real parametric `String`
attribute in `spec/core/Bitcoin/Wallet/RuleAttr.lean:43-51`; the payload is a row ID. The
capital `R` is deliberate. The consensus scanner reads raw source case-sensitively with
`\brule\s+"…"` (`spec/scripts/rule_crosscheck.py:22`); a lowercase tag in wallet source would
be collected as an orphan consensus rule. `wallet_crosscheck.py` strips Lean comments before
collecting tags, so the examples in docstrings are not tag sites. At this commit there are 40 tag instances across 37 declarations and 40 distinct row IDs (DESC 8, MS 19, PSBT 12, WSP 1, SGN2 0); `lean_target`
remains null by design because the wallet census is tag-indexed rather than FQN-indexed.

## 4. The second census

`spec/db/rules-wallet.yaml` is a separate database validated by
`spec/scripts/wallet_census.py`. Counts are by ID prefix: `DESC` 30, `MS` 35, `PSBT` 30,
`WSP` 31, `SGN2` 14, total 140. The namespace is the ID prefix; rows do not carry a separate
`namespace` key. Every row's `core_ref` resolves to a non-empty line in the pinned Core source;
all 140 pass the anchor check.

`status` is admitted from `planned`, `stubbed`, `implemented`, `proven`, `obsolete`
(`spec/scripts/wallet_census.py:46`); the census gate currently requires every row to remain
`planned`. Evidence grades — theorem, checked, differential-only — are prose categories, not
stored `status` values. The freeze digest is in `spec/db/rules-wallet.lock`.

No wallet row is a consensus row. Every row carries `consensus: false`, the wallet file is
never merged into `rules.yaml`, and the two ID spaces are required to be disjoint.

## 5. Auditing one claim end to end

Take `DESC-001` (checksum character set), which is one of the 40 tagged rows. From the
repository root:

```sh
grep -n -A14 '^- id: DESC-001' spec/db/rules-wallet.yaml
grep -rn --include='*.lean' --exclude='RuleAttr.lean' '@\[walletRule "DESC-001"\]' \
  spec/core/Bitcoin/Wallet spec/proofs/BitcoinProofs/Wallet
grep -n 'theorem descriptorChecksum_eq_empty_iff' \
  spec/proofs/BitcoinProofs/Wallet/Desc/Checksum.lean
(cd spec/proofs && lake build BitcoinProofs.Wallet.Desc.Checksum)
bash spec/scripts/wallet_axiom_manifest.sh --probe
CORE_SRC=/path/to/bitcoin/src bash spec/scripts/wallet_gates.sh
```

The first command gives the row and statement; the second returns the tag at
`Desc/Checksum.lean:124`; the third returns
`descriptorChecksum_eq_empty_iff`; the build checks that the tagged module compiles; and the
axiom probe plus `spec/scripts/wallet_gates.sh` check for `sorry`, tag/row agreement, census anchors and
digest, the 844-entry wallet axiom manifest, and consensus isolation. The discharge is the tag
plus the compiled theorem plus the axiom check, not the tag alone.

For an **open** obligation take `MS-001` (type bitmap): the same tag search returns
nothing, `has_ofTy` proves only one projection, and the bound, distinctness, and
coverage lemmas are absent. It is one of the 99 rows in
`docs/WALLET-OBLIGATIONS.md`.

An audit that ends with a tag, a compiled theorem, and a clean axiom footprint is a discharged
row. An audit that ends with a statement and no theorem is a modelled obligation, not a proof.

## 6. Boundaries and named residuals

**Policy is not consensus.** Fee rates, dust, relay floors, and selection preferences are wallet
or relay policy. `IsDust` is `src/policy/policy.cpp:66`; the dust relay rate is
`src/policy/policy.h:68`; funding estimates size and fee at `src/wallet/spend.cpp:1332-1337`.
The capstone runs with no policy flags, so a transaction accepted by the consensus model can
still be non-standard. Such rows are differential-only and say so.

**The signer is a boundary.** Signature production (ECDSA and Schnorr), nonce handling, and
secret-key storage are outside the model. A signing theorem would be conditional on a
`SignerSpec`; the signer itself is observed differentially against Core. Nothing here claims
side-channel resistance.

**PSBT v2 is excluded.** The model and corpus cover version 0 only. The pinned Core tree accepts
v0 and v2 (`src/psbt.h:97`, `src/psbt.cpp:23`); the wallet decoder recognises v2 fields only to
reject them. No v2 claim is made, including for the developmental v2 code in that tree.

**The pin is a development snapshot.** Ground truth is Core at `cce32b168`, whose binary reports
`v32.99.0-cce32b16874e` and whose source sets major version 32 at `CMakeLists.txt:30`. This is
not a release tag. Anchors are valid only at this commit, not for any shipped release.

**Taproot program equality is a wallet bridge, not a consensus repair.** In the consensus model,
`verifyTaprootCommitment` now binds its `program` argument
(`Verify.checkTapTweak`: 32-byte length plus `program = x(Q)`), while v1 spends still route to
`unjudgedTaproot` (`spec/core/Bitcoin/Capstone/Block.lean:242-244`). `Taproot/Commit.lean` supplies
the wallet-side `programMatches`, `SpendCommitment`, and `commitmentOf`, and proves
`spendCommitment_iff_verdict` and `commitmentOf_program_binding`; the latter makes the verifier's
program binding explicit. `W1_taprootSpendJudged` (line 384) is a target, not a theorem, because
the capstone still routes the v1 lane to `unjudgedTaproot`, so wallet taproot-spend claims remain
conditional on `SpendCommitment`.

The descriptor fragment has its own boundary: `pk`, `pkh`, `wpkh`, `sh(wpkh)`, `multi`,
`sortedmulti`, and key-path-only `tr`; it omits `wsh`, `combo`, `sh(multi(...))`, taproot script
trees, multipath, private-key descriptors, and range expansion without an explicit provider.

## 7. Data and differential method

The differential harness is `spec/runners/wallet_diff/run.py`. It starts a private regtest
`bitcoind` through `spec/runners/wallet_diff/bitcoind.py` (standard library JSON-RPC, disposable
datadir, cookie authentication, no peer listening), runs the scenarios in
`spec/runners/wallet_diff/scenarios.py`, and compares observed results with
`spec/data/wallet/cases.jsonl`. The scenarios fix one test key, one mock time, explicit
funding inputs, a fixed change address, and PSBT v0, so the corpus is reproducible.

The corpus contains 192 cases: 153 RPC observations, 39 evaluated checks, and 22 recorded
error contracts. Its manifest pins `bitcoind` version `v32.99.0-cce32b16874e`, commit
`cce32b16874e`, and the SHA-256 of the exact JSONL bytes
(`spec/data/wallet/manifest.json`).

```sh
cd spec/runners/wallet_diff
python3 run.py --emit       # regenerate corpus and manifest
python3 run.py --replay     # fresh daemon, compare every case
python3 run.py --smoke      # ten representative cases
python3 run.py --compare-json /path/to/lean-output.json
```

`--compare-json` accepts Lean-side `{"id": ..., "result": ...}` or `{"id": ..., "error": ...}`
records and checks them against the Core observations. Coverage is descriptor checksum/parse and
derivation (54), import/list and watch-only (9), address/scriptPubKey agreement (30), PSBT v0
lifecycle (15), and funding across three output types and three fee rates (81). The corpus is
evidence about this binary and these shapes, not a consensus proof; it covers no PSBT v2,
taproot script-path signing, multisig spending, coin selection, dust change, or wallet database.

## 8. Status at this commit

Present and building: Base58/Base58Check and Bech32/Bech32m encodings; SHA-512 and
HMAC-SHA512; BIP32 origin parsing, private/public derivation, and 78-byte serialization; the
descriptor checksum, parser, and script expansion for the fragment above; the Miniscript type,
node, script, satisfaction, and sanity model for its fragment; the PSBT v0 typed model, decoder,
encoder, lifecycle laws, and Core-derived vectors; fee/dust arithmetic, funding, two
deterministic selection strategies, and their laws.

Checked: the static wallet axiom manifest covers 844 theorem/lemma declarations in 53 wallet modules
and permits only `propext`, `Classical.choice`, and `Quot.sound`; 37 declarations carry 40 row tags across
40 distinct row IDs (DESC 8, MS 19, PSBT 12, WSP 1, SGN2 0). Representative row targets are
`Miniscript.TypeSound.calcType_hash_fragments`, `Miniscript.ScriptExact.toScript_pk_fragments`,
`Psbt.Laws.decMapL_encMapL`, `Psbt.Laws.extract_preserves_unsigned`, and
`Spend.Laws.fundWithChange_conserves`. These are model lemmas; a tag says the declaration
entails the row, not that the whole wallet pipeline is equivalent to Core. The whole-file PSBT
round trips are stated as `decodeEncodeTarget` and `encodeDecodeTarget` at `Psbt/Laws.lean:437,447`,
not proved; the BIP32 public-key agreement laws are `ckdPubAgreementTarget` and
`ckdPubPathAgreementTarget` at `Key/Bip32.lean:358,365`, not proved.

Stated but unproved: the 99-row obligation register in
`docs/WALLET-OBLIGATIONS.md` (30 PARTIAL: 16 MODEL / 14 PROOF; 69 UNMODELLED:
59 MODEL / 10 PROOF; three of these rows also carry tags), plus four corrected
rows whose statements still have no proof. The 24 DESC/WSP obligation `Prop`s
(of 73 in `Obligations.lean`) remain restatements, not evidence. End-to-end
composition and `W1_taprootSpendJudged` are absent; the signer bridge
(`Sign/Bridge.lean`) is stated conditionally, with its cryptographic target
unproved. `bash spec/scripts/wallet_gates.sh` passes with 53
files scanned, zero `sorry`/`admit`, 40 row tags across 40 IDs, 140 anchored `planned` rows, an
844-entry axiom manifest with the three permitted axioms, and the consensus census unchanged at
726 rows (676 proven / 50 obsolete).
