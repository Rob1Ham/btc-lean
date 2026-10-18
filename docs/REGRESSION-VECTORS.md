# Audit regression vectors

This page records the exact regression vectors for the consensus-semantics
fixes tracked by the source audit. The model changes themselves belong to the
modules that own each definition; this page keeps the vectors and the intended
test locations in one place so a fix is not accepted without a witness.

The proof-surface repairs are already exercised in-file:

* `SmallCurve/TweakCorSmall.lean`: `mulP' (2^16) G = none` and
  `mulP' (2^16 + 1) G = mulP' 1 G` (kernel checks for the 16-bit bound).
* `Theorems/Ops/O07.lean`: the five hash-op examples assert that the digest
  replaces the top item (`[digest]`, not `[digest, input]`).
* `EcdsaDeep/PubKeyCor.lean`: the `GetLen` ladder and `ValidSize` matrix.
* `Theorems/FuelStability.lean`: `evalFrom_eventually_constant`.

Each section below records the input vector, the owning module, the test
location, and a status. `pass` means the named command was run against the
integrated tree and exited 0; `planned` means the vector is recorded but was
not run here. The old-behaviour column states the pre-fix result, not a result
measured on this tree.

## Issue 16 behavioural fixes

### CODESEPARATOR — instruction index, not byte offset

`State.codeSep` remains the byte offset used to slice the legacy scriptCode,
while `State.codeSepPos` is the 0-based instruction index committed by the
BIP342 tapscript sighash; the sentinel is `0xFFFFFFFF` until a separator
executes. Owning module: `spec/core/Bitcoin/Interpreter/Defs.lean:601-604`
(`codeSep`, `opcodeIndex`, `codeSepPos`) and `:1032` (the executed
`0xab` transition records both).

The signed BIP341 fixture executes its separator at opcode index 6 and byte
offset 9 (`spec/data/review/taproot-validation/provenance.json`). The four
sighash inputs give:

| Signing input | Core verdict |
|---|---|
| no separator executed, sentinel `0xffffffff` | accept |
| zero substitute for the sentinel, no separator executed | reject `schnorrSig` |
| byte offset 9 substituted for the index | reject `schnorrSig` |
| instruction index 6 (the fixture signature) | accept |

Test location: `spec/core/Test/Capstone/TaprootInputs.lean:49-55` over the
`extraCases` rows. Status: **pass** —
`make test-capstone-taproot` (exit 0; `wrong byte-offset separator` and
`wrong zero separator sentinel` both produced `schnorrSig`, the sentinel row
passed). The kernel-level form is in
`spec/proofs/BitcoinProofs/Theorems/Ops/O07.lean:465-470`: wire `0xab` with
`next = 3` and `opcodeIndex = 0` yields `codeSep = 3` and `codeSepPos = 0`.

### 2-of-2 P2SH sigop cost

A 2-of-2 P2SH redeem script `52ae` (`OP_2 OP_CHECKMULTISIG`) counts from its
decoded public-key count, not as one flat CHECKMULTISIG. Owning module:
`spec/core/Bitcoin/Interpreter/Rules.lean:200-215` and
`spec/core/Bitcoin/Interpreter/SigOps.lean:80-100`
(`accurateSigOpCount`).

| Redeem script | Flags | Sigops | Cost |
|---|---|---:|---:|
| `52ae` | P2SH on | 2 | 8 |
| `52ae` | P2SH off | — | 0 |
| `52ae53af` | P2SH on, accurate counter | 5 | — |
| `52ae53af` | P2SH on, flat counter | 40 | — |

The old flat counter charged 1 sigop (cost 4) for the 2-of-2 script. Test
location: `spec/core/Test/Capstone/Sigops.lean:41,48,58`. Status: **pass** —
`make test-capstone-sigops` (exit 0; `P2SH enabled` expected 8, actual 8).

### Malformed P2WSH — count the valid prefix

`witnessScriptSigOps` parses as far as the byte stream is well formed and
counts every complete sigop opcode in that valid prefix; a truncated push at
the end does not zero the count. Owning module:
`spec/core/Bitcoin/Interpreter/SigOps.lean:178-224`.

| Witness script bytes | Sigops |
|---|---:|
| `ac4c` (`CHECKSIG`, truncated PUSHDATA1) | 1 |
| `ac02ae` (`CHECKSIG`, truncated direct push) | 1 |
| `52ae4c02ac` (`2 CMS`, truncated PUSHDATA1 payload) | 2 |
| `ac4d01` (`CHECKSIG`, truncated PUSHDATA2) | 1 |
| `af4e000000` (`CMS`, truncated PUSHDATA4) | 20 |

The old model returned 0 for a malformed witness script. Test location:
`spec/core/Test/Capstone/Sigops.lean:53-57,67`. Status: **pass** —
`make test-capstone-sigops` (exit 0; `witness P2WSH retains valid prefix`
expected 1, actual 1).

### Witness-stack CompactSize

The BIP342 budget base is the full BIP144 witness serialization: a CompactSize
stack count followed by each item's CompactSize length and payload. Owning
module: `spec/core/Bitcoin/Crypto/Taproot/Program.lean:599-606`
(`witnessSerSize`) and `:641-642` (`validationWeightInit = size + 50`).

| Witness stack | Serialized bytes |
|---|---:|
| 252 empty items | 253 (1-byte count + 252 length bytes) |
| 253 empty items | 256 (3-byte `fdfd00` count + 253 length bytes) |
| fixture's four-signature witness | 150 |

The fixture's initial budget is therefore 200 WU. The old size omitted the
stack-count prefix (252 and 253 respectively). Test location:
`spec/core/Test/Capstone/TaprootInputs.lean:66-69`. Status: **pass** —
`make test-capstone-taproot` (exit 0; 253 and 256 both matched). The encoder
identity is proved in
`spec/proofs/BitcoinProofs/Theorems/WitnessSerialization.lean:25-40`.

### 80,001 block sigops

The block limit is 80,000 sigop cost, with legacy sigops scaled by four and
witness sigops added directly. Owning module:
`spec/core/Bitcoin/Capstone/Block.lean:828-834` (`checkSigopTotal`) and
`spec/proofs/BitcoinProofs/Bip/B08/Bip141Defs.lean:156-161`.

| Legacy sigops | Witness cost | Total | Verdict |
|---:|---:|---:|---|
| 20,000 | 0 | 80,000 | accept |
| 20,001 | 0 | 80,004 | reject |
| 0 | 80,000 | 80,000 | accept |
| 0 | 80,001 | 80,001 | reject |
| 10,000 | 40,001 | 80,001 | reject |
| 10,000 | 40,000 | 80,000 | accept |

Test locations: `spec/proofs/BitcoinProofs/Bip/B08/Bip141Tests.lean:171-176`
(predicate) and `spec/core/Test/Capstone/SigopBudget.lean:92-125,140-145`
(live stage and public serialized blocks). Status: **pass** —
`cd spec/proofs && lake env lean BitcoinProofs/Bip/B08/Bip141Tests.lean`
(exit 0) and `make test-capstone-sigop-budget` (exit 0; 80,000 accepted,
the next representable 80,004 and the one-unit witness overage rejected).

### Full powLimit and above-powLimit work

Mainnet `powLimit` is Core's full `2^224 - 1`, not the rounded difficulty-one
target `2^224 - 2^208`. `GetBlockProof` returns work for every nonzero decode
and does not clamp targets above `powLimit`; only a zero decode gives 0.
Owning modules: `spec/core/Bitcoin/Block/Pow.lean:63-66` and
`spec/core/Bitcoin/Block/Index.lean:54-76`.

| nBits | Decoded target | Relation | Work |
|---|---|---|---|
| `1d00ffff` | `2^224 - 2^208` | strictly below `powLimit` | positive |
| `1d7fffff` | `2^231 - 2^208` | above `powLimit` | positive |
| zero decode | 0 | — | 0 |

The old model used `2^224 - 2^208` as `powLimit` and returned 0 for
`1d7fffff`. Test locations: `spec/core/Test/Capstone/PowLimit.lean:14-27`
(parameter and compact-target checks) and
`spec/proofs/BitcoinProofs/AF/PDW28/PDW28.lean:59-87` (full-limit and
genesis-target constants). Status: **pass** — `make test-capstone-pow-limit` (exit 0)
and `cd spec/core && lake build Bitcoin.Block.Index` (exit 0, including
`workOf_above_powLimit_pos`).

### BIP68 relative-height/time rejection

The contextual stage resolves each non-coinbase input's prevout height/time
and applies `sequenceLocksOk` before the sigop budget. Owning modules:
`spec/core/Bitcoin/TxValidation/Interface.lean:374`,
`spec/core/Bitcoin/Block/Connect.lean:131-144`, and
`spec/core/Bitcoin/Capstone/Block.lean:663`.

| Vector at height 419,328 | Sequence | Verdict |
|---|---|---|
| prevout at 419,327, height lock 1 | `0x00000001` | accept |
| prevout at 419,327, height lock 2 | `0x00000002` | reject `bad-txns-nonfinal` |
| prevout at 419,327, 512 s spacing, time lock 1 | `0x00400001` | accept |
| same vector, 511 s spacing | `0x00400001` | reject `bad-txns-nonfinal` |
| same-block child, height lock 1 | `0x00000001` | reject `bad-txns-nonfinal` |
| same-block child, time lock 1 | `0x00400001` | reject `bad-txns-nonfinal` |
| version 1, or disable bit set | any | exempt |

Test location: `spec/core/Test/Capstone/Finality.lean:70-115`. Status:
**pass** — `make test-capstone-finality` (exit 0; exact height/time
boundaries accepted, one unit over rejected).

### Policy-flag acceptance

Block validation supplies only consensus `ScriptFlags`; policy bits such as
LOW_S, CLEANSTACK, MINIMALDATA, MINIMALIF, CONST_SCRIPTCODE, STRICTENC,
WITNESS_PUBKEYTYPE, NULLFAIL, and the discourage flags are off in the
consensus view and are not enabled by the block flag selector. Tapscript
re-imports MINIMALIF and clean-stack as consensus. Owning module:
`spec/core/Bitcoin/Activation/Flags.lean:573-599`
(`consensusFullFlags`, `minimalIfRequired`, `cleanStackRequired`).

| Check at height 709,632 | Result |
|---|---|
| consensus policy `lowS` | false |
| consensus policy `cleanStack` | false |
| consensus policy `minimalIfV0` | false |
| tapscript `minimalIfRequired` with empty flags | true |
| tapscript `cleanStackRequired` with empty flags | true |
| base `minimalIfRequired` with empty flags | false |

Test location: `spec/Test/Activation/FlagsTest.lean:87-99,151-154`. Status:
**pass** — `cd spec/core && lake env lean --run
../Test/Activation/FlagsTest.lean` (exit 0; `policy flags absent from
consensus view` and `tapscript re-imports MINIMALIF/CLEANSTACK` both passed).

### Tapscript empty-signature weight

A non-empty tapscript signature is charged 50 WU after the budget check and
before the pubkey rules; an empty signature is a false check that continues
with the budget unchanged (no Schnorr verification and no charge). Owning
module: `spec/core/Bitcoin/Interpreter/Defs.lean:757-780`
(`evalChecksigTapscript`).

| Signature | Pubkey | Budget before | Result |
|---|---|---|---:|
| empty | 32-byte | any | `.ok (false, same budget)` |
| non-empty | any | `< 50` | `.error tapscriptValidationWeight` |
| non-empty | 32-byte, valid Schnorr | `>= 50` | `.ok (true, budget - 50)` |
| non-empty | empty | `>= 50` | `.error tapscriptEmptyPubkey` |

Test locations: `spec/core/Test/Script/Tapscript/Delta.lean:117-120`,
`spec/proofs/BitcoinProofs/AF/PDW82/PDW82.lean:137-163`, and
`spec/proofs/BitcoinProofs/AF/PDW90/PDW90b.lean:15-33`. Status: **pass** —
`cd spec/proofs && lake build BitcoinProofs.AF.PDW82.PDW82` (exit 0;
`evalChecksigTapscript_empty_sig_no_weight` and
`evalChecksigTapscript_weight_before_pubkey` checked).

### Deleted BIP141 predicate

The obsolete `programMustFailCastToBool` helper and its tests are removed from
`spec/proofs/BitcoinProofs/Bip/B08/Bip141Defs.lean`; witness-program verdicts
now use the real `Bitcoin.Numeric.castToBool`. A zero-valued program is not a
consensus rejection: size dispatch decides the verdict.

| Program | Dispatch | Rejected by zero value? |
|---|---|---|
| v0, 20 zero bytes | `.p2wpkh` | no |
| v0, 32 zero bytes | `.p2wsh` | no |
| v1, 2 zero bytes | `.future 1` | no |

Test location:
`spec/proofs/BitcoinProofs/Bip/B08/Bip141Tests.lean:79-99`. Negative zero is
still false through the model at `spec/core/Bitcoin/Numeric/Interface.lean:64`
(`castToBool`). Status: **pass** — `cd spec/proofs && lake env lean
BitcoinProofs/Bip/B08/Bip141Tests.lean` (exit 0; no `programMustFailCastToBool`
declaration remains).

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
