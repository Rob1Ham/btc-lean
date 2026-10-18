# Audit regression vectors

This page records the exact regression vectors for the consensus-semantics
fixes tracked by the source audit. The model changes themselves belong to the
modules that own each definition; this page keeps the vectors and the intended
test locations in one place so a fix is not accepted without a witness.

The shared static sigop counters have 36 executable checks in
`spec/core/Test/Capstone/Sigops.lean` (`make test-capstone-sigops`). They
cover per-CHECKMULTISIG lookback, inaccurate cost twenty, skipped push
data, retained valid prefixes on malformed pushes, push-only P2SH
scriptSigs, native/wrapped witness programs, absent witness stacks,
independent input indexing and activation flags. These are resource
accounting checks; malformed scripts need not execute successfully.

`spec/scripts/check_sigops_core.py` extracts and compiles nine actual Core
functions from the immutable `src/script/script.cpp` and
`src/script/interpreter.cpp` files. Pass them with `--script` and
`--interpreter`, and pass the Lean runner's saved stdout with `--lean-log`.
The script verifies the full input-file hashes against either supported
Core pin before compiling. All 28 raw/per-input reference cases agree at
both pins; eight further Lean checks cover transaction wrappers. This is
a source-function harness, with container/type shims, rather than a whole
bitcoind integration test or an equivalence proof. The before-repair
reproduction command is
`python3 docs/reviews/2026-10-18/reproduce_sigops.py`; it requires exactly
18 named failures and 10 passing controls at the recorded pre-fix commit.
Commands, hashes and proof scope are recorded in
`docs/reviews/2026-10-18/validation-sigops.json`.

The live block budget has 32 further checks in
`spec/core/Test/Capstone/SigopBudget.lean`
(`make test-capstone-sigop-budget`). They cover CheckBlock's early legacy
budget, the evolving UTXO view, coinbase costs, cumulative P2SH/witness
costs, input/fee/BIP68 error ordering and budget-before-script ordering.
The two serialized files in `spec/data/review/sigop-budget` are synthetic
height-one forks of the real mainnet genesis header, mined at its actual
`0x1d00ffff` target. Both public entry paths accept 80,000 and reject
80,004. They are not canonical blocks or whole-bitcoind validation results.
Regenerate their exact bytes with
`python3 spec/scripts/generate_sigop_blocks.py --check`.

`spec/scripts/check_sigop_budget_core.py` takes `--script`, `--interpreter`,
`--tx-verify` and `--validation` paths from either exact Core pin and
`--fixtures spec/data/review/sigop-budget`. It verifies all four source
hashes, then compiles thirteen unchanged extracted functions/sites with
container/state shims. Nine reference cases agree at both pins; the
ConnectBlock fee/sequence/cost/script order and CheckBlock's earlier
transaction/legacy order are checked against the pinned source. This does
not execute Core's parser, script checks or full block-validation pipeline.
`python3 docs/reviews/2026-10-18/reproduce_sigop_budget.py` reproduces exactly
two public-path over-budget acceptances at `732efdf`, with two at-limit
controls. The new public success theorem proves the reported budget and
an exact cost trace over each intermediate ledger. See
`docs/reviews/2026-10-18/validation-sigop-budget.json` for scoped receipts
and the remaining whole-repository verification work.

Witness commitment validation has 31 further checks in
`Test/Capstone/WitnessCommitment.lean` and `WitnessStage.lean`
(`make test-capstone-witness`). The 267-byte mined fixture accepts two
nonzero output amounts totalling exactly the subsidy. Its highest matching
output binds a nonzero 32-byte reserved value and has a legal trailing
byte. Witness-only variants preserve its txid/merkle root/PoW and exercise
missing, 31/33-byte and multiple reserved items, plus an actual hash mismatch.
The supplied height/history is conditional input; this is not a reachable
historical mainnet block. Stage checks include preactivation, no commitment,
reversed output selection, and separate amount/reward rejection.

`python3 docs/reviews/2026-10-18/reproduce_witness_commitment.py` requires
exactly twelve old public failures and seven passing fixture controls at
`8856247`. Regenerate with
`python3 spec/scripts/generate_witness_commitment_block.py --check`.
`spec/scripts/check_witness_commitment_core.py` takes `--validation`,
`--consensus-validation` and `--fixture` paths and verifies the source hashes
at either pin. Two unchanged extracted functions agree on twelve reference
cases using container/state/single-coinbase-merkle shims and CommonCrypto
SHA256d. These are runtime checks, not whole-bitcoind validation or a
C++/Lean equivalence proof. See `validation-r05.json` in the review directory.

The proof-surface repairs are already exercised in-file:

* `SmallCurve/TweakCorSmall.lean`: `mulP' (2^16) G = none` and
  `mulP' (2^16 + 1) G = mulP' 1 G` (kernel checks for the 16-bit bound).
* `Theorems/Ops/O07.lean`: the five hash-op examples assert that the digest
  replaces the top item (`[digest]`, not `[digest, input]`).
* `EcdsaDeep/PubKeyCor.lean`: the `GetLen` ladder and `ValidSize` matrix.
* `Theorems/FuelStability.lean`: `evalFrom_eventually_constant`.

The remaining vectors are consensus-model fixes owned by the corresponding
semantics modules. They should be added as `example`/`theorem` rows in those
modules (or in their existing `*Tests.lean` / `*Vec.lean` companions) when the
model change lands.

## BIP113 median time past — upper median

Core `GetMedianTimePast` sorts the last 11 block times and returns index
`n/2` (upper median for even `n`).

| Input (prior block times) | Core `medianTimePast` | Lower-median (buggy) |
|---|---:|---:|
| `[11, 12]` | 12 | 11 |
| `[11, 12, 13, 14]` | 13 | 12 |
| `[14, 13, 12, 11]` | 13 | 12 |

Test location: `spec/core/Bitcoin/Block/Pow.lean` (`medianTimePast`), with
fixtures in `spec/proofs/BitcoinProofs/Bip/B07/Bip113MTP.lean`; replace any
`mtp_even_count_lower_median` expectation with the upper-median value.

## `castToBool` — negative zero

Core's loop treats a final byte whose low 7 bits are zero as negative zero.

| Script number bytes | Core `CastToBool` |
|---|---|
| `[]` | false |
| `00` | false |
| `0080` | false (negative zero) |
| `8000` | true |
| `008000` | true (last byte zero, previous nonzero is not final) |
| `01` | true |

Test location: `spec/core/Bitcoin/Interpreter/Defs.lean`
(`castToBool`/`Bitcoin.Numeric.castToBool`) and
`spec/proofs/BitcoinProofs/Bip/B08/Bip141Tests.lean`.

## Witness commitment — reserved value

Commitment is `SHA256d(wtxidRoot ++ reservedValue)`; the scriptPubKey
prefixes it with `OP_RETURN 0xaa21a9ed`.
With `wtxidRoot = 11...11` (32 bytes) the two reserved values give:

| Reserved value | Expected commitment (hex) |
|---|---|
| `00` × 32 | `5178ffc59837e89271d12d22a7b277a58fcbea919a2af76c65755abba0e339e7` |
| `01` × 32 | `3957c63e04409a2c7e09d30c75e66bfb69e74a6ef93760889e9e5b6877a7ba73` |

A coinbase witness whose reserved item is `00` × 32 must not satisfy a
commitment computed from `01` × 32, and vice versa. Test location:
`spec/core/Bitcoin/Capstone/Merkle.lean` (`witnessCommitmentOk` /
`commitmentGate`) and `AF/PDW13/WitnessCommitmentReserved.lean`; re-prove the
BLK-017/SWT-030/PDW58B rows after wiring the reserved value.

## BIP30 — duplicate unspent coinbase

| Case | Core verdict |
|---|---|
| height 91842, coinbase txid duplicates the unspent coinbase of 91812 | accept (historical exception) |
| height 91880, likewise | accept (historical exception) |
| height 100000, coinbase txid duplicates any unspent coinbase | reject `bad-txns-BIP30` |
| height 100000, duplicate txid whose earlier output is already spent | accept |

Test location: `spec/core/Bitcoin/Capstone/Block.lean` (`validateBlock` /
`bip30BlockCollision`) and `AF/PDW58` / `Theorems/CapstoneComposePipeline.lean`.

## `findAndDelete` — suffix preservation

Core removes every exact occurrence of the needle and concatenates the
remaining pieces; it never re-appends the tail after a match.

| Script | Needle | Result |
|---|---|---|
| `01aa01bb` | `01aa` | `01bb` |
| `01aa01bb` | `01bb` | `01aa` |
| `01aa01aa` | `01aa` | empty |
| `01aa02bbcc` | `02bbcc` | `01aa` |

A result of `01bb01aa` (tail re-appended) is the bug. Test location:
`spec/core/Bitcoin/Interpreter/Defs.lean` (`findAndDelete`/`fdLastPc2`) and
`AF/PDW59/PDW59d.lean`.

## Merkle mutation detector — pair-aligned duplicates only

Core checks only pair-aligned positions (`hashes[2i] == hashes[2i+1]`) at each
level, before the odd tail is duplicated.

| Leaves | Core mutation verdict |
|---|---|
| `[A, B, B]` | accept (unaligned duplicate) |
| `[B, A, A]` | accept (unaligned duplicate) |
| `[A, A]` | reject |
| `[A, A, B, B]` | reject |
| `[A, B, B, B]` | reject (aligned `B, B` at pair 1) |

with `A = 00...00` and `B = 11...11` (32 bytes each). Test location:
`spec/core/Bitcoin/Block/Connect.lean` (`merkleMutationFree`) and
`AF/PDW12` / `AF/PDW53`.

## Taproot output key — program binding

BIP341 test vector 0 (also in `spec/Test/Crypto/TaprootVerifyTest.lean:93-96`):

* internal key: `d6889cb081036e0faefa3a35157ad71086b123b2b144b649798b494c300a961d`
* merkle root: empty
* output key: `53a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda343`
* scriptPubKey: `512053a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda343`

Negative case: the same internal key with output program
`53a1f6e4...dda344` (last byte changed) must fail the tweak check, as must a
33-byte program carrying the same numeric value. Test location:
`spec/core/Bitcoin/Crypto/Taproot/Verify.lean`
(`OutputKey.outputKeyOk`/`CheckTapTweak`) and `Audit/Z29`.
