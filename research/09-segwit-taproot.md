# 09 — SegWit & Taproot Consensus Layers (BIP141/143/144/145/146/147 + BIP340/341/342)

**Report 09 · project btc-lean · 2026-10-16**

> **Pin note.** The originally requested Core HEAD was `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`; the depth-1 clone
> resolved to **`cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`** (v32.99.0 master, merge of #36535, dated
> 2026-10-16). Every `file:function:lines` citation below is against this commit (`@c50817f`). The
> SegWit/Taproot interpreter code is stable across this range; no relevant semantic drift expected
> between the two commits, but the diff was not checked (no full clone of the older hash).
> BIP repo pin: `927b6de9915c9262615a6399de51b200f81e5aa4` (2026-10-02).

---

## Executive summary (≤15 lines)

1. The entire SegWit+Taproot consensus surface is ~1,000 lines in two Core files:
   `src/script/interpreter.cpp` (witness dispatch, BIP143/341 sighash, tapscript deltas) and
   `src/script/script.cpp` (template matching, sigop counting) — ideal formalization granularity.
2. Everything above the crypto primitive is *pure, total and deterministic*: witness validation is a
   function of `(scriptPubKey, scriptSig, witness stack, spent amount, tx, sighash-relevant context)`.
3. The clean API boundary Core itself draws: **interpreter ⇄ `BaseSignatureChecker`** (2 signature
   entry points: `CheckECDSASignature`, `CheckSchnorrSignature`) + sighash precomputation in
   `PrecomputedTransactionData`. That boundary is exactly the btc-lean "crypto tower" seam.
4. Consensus needs **5** crypto primitives: SHA256 (single+double), RIPEMD160/Hash160,
   secp256k1 ECDSA-verify-with-lax-DER-parse-and-S-normalize, BIP340 Schnorr verify, and
   x-only point tweak check (`xonly_pubkey_tweak_add_check`) for script-path commitment.
5. Signature **construction** (nonce derivation, aux randomness) is NOT consensus — mark: signing
   is out of scope; batch verification is an implementation detail (Core verifies singly) — mark.
6. BIP143's "SINGLE bug absence" is real: out-of-range SINGLE under WITNESS_V0 hashes a *zero*
   hashOutputs instead of early-returning `uint256::ONE` (`interpreter.cpp:1614-1622`).
7. Taproot's deepest formal trap is not the sighash but the **commitment check**: it needs full
   EC point arithmetic (P + tG, parity) *inside* consensus — i.e., script-path validation pulls the
   group tower into the interpreter even for spends with zero signatures.
8. The P2A (pay-to-anchor) special case (`OP_1 <0x4e73>`) is a third witness-v1 behavior that is
   neither key-path nor script-path: unconditionally anyone-can-spend.
9. Current master's `GetBlockScriptFlags` is simpler than history suggests: `{P2SH, WITNESS, TAPROOT}`
   always on + 4 buried deployments + a per-block-hash exception map (two blocks on mainnet).
10. LOW_S / NULLFAIL / STRICTENC / MINIMALIF(v0) / WITNESS_PUBKEYTYPE are **not** consensus in Core
    (absent from `GetBlockScriptFlags`) — BIP146 and BIP143's key-type restriction live only as policy.
11. Recommended build order: BIP143 sighash → witness dispatch/v0 → P2SH interplay → BIP341 sighash →
    taproot commitment → tapscript opcode deltas → sigops/weight accounting.
12. Test-vector coverage is superb and machine-readable: `bips/bip-0340/test-vectors.csv`,
    `bips/bip-0341/wallet-test-vectors.json`, plus Core's `src/test/script_tests.cpp` JSON corpus —
    these are the conformance harness for these rules.

---

## Key findings (with citations)

All citations: Bitcoin Core `@cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` unless marked BIP-only.

| # | Finding | Citation |
|---|---------|----------|
| F1 | Witness-program template match is a 6-clause predicate: script len 4..42, first byte `OP_0`/`OP_1..OP_16`, second byte a direct push, `second_byte + 2 == size`; version = `DecodeOP_N`. Non-minimal encodings (e.g. `PUSH1 0x00`) are *not* witness programs. | `src/script/script.cpp:CScript::IsWitnessProgram:250-264` |
| F2 | Witness dispatch has exactly four outcomes: v0-32 (P2WSH), v0-20 (P2WPKH), v1-32-non-P2SH (Taproot, gated on `SCRIPT_VERIFY_TAPROOT`), P2A anchor; everything else returns **success** unconditionally (future softfork hook) unless `DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM`. | `src/script/interpreter.cpp:VerifyWitnessProgram:1927-2010` |
| F3 | Taproot requires `witversion == 1 && program.size() == 32 && !is_p2sh`; P2SH-wrapped v1 programs fall through to the future-version branch → anyone-can-spend today. | `interpreter.cpp:1957` + `2000-2008`; BIP341 ref footnote |
| F4 | BIP143 digest = double-SHA256 of the 10-field preimage; sub-hashes (`hashPrevouts/Sequence/Outputs`) are themselves double-SHA256 (cached in `PrecomputedTransactionData` as double, computed from single-SHA256 midstates). | `interpreter.cpp:SignatureHash:1609-1687`, `GetPrevoutsSHA256:1358-1365`, `PrecomputedTransactionData::Init:1412-1462` |
| F5 | P2WPKH scriptCode is the *reconstructed* `OP_DUP OP_HASH160 <program> OP_EQUALVERIFY OP_CHECKSIG` (byte-exact `0x1976a914{20B}88ac` incl. CompactSize prefix from CScript serialization). | `interpreter.cpp:1952` + `ss << scriptCode` at 1664; BIP143 §Spec item 5 |
| F6 | Out-of-range SIGHASH_SINGLE: early return of `uint256::ONE` only for `sigversion != WITNESS_V0`; WITNESS_V0 leaves `hashOutputs` zero — the "SINGLE bug" (CVE-2018-17144-adjacent semantics family) is structurally absent in BIP143. | `interpreter.cpp:1614-1622` vs `1647-1653` |
| F7 | `FindAndDelete` of the signature is applied only for `SigVersion::BASE` — witness v0 never mutates scriptCode. | `interpreter.cpp:EvalChecksigPreTapscript:338-343` |
| F8 | Tapscript sigops budget: `validation_weight_left = serialized_witness_size + 50`, each passed non-empty sigop (incl. unknown-pubkey-type) decrements 50, going negative fails. Tapscript sigops never enter the 80,000 block cost. | `interpreter.cpp:368-376`, `1991`; `script.h:VALIDATION_WEIGHT_PER_SIGOP_PASSED=62`, `VALIDATION_WEIGHT_OFFSET=65`; `CountWitnessSigOps:2149-2176` returns 0 for v1 |
| F9 | BIP341 sighash: tagged `TapSighash`, epoch byte `0x00`, hashtype 1 byte, spend_type `= ext_flag*2 + annex_present`, single-SHA256 sub-hashes **including amounts and scriptPubKeys of all spent outputs** (`sha_amounts`, `sha_scriptpubkeys`). | `interpreter.cpp:SignatureHashSchnorr:1492-1580`, `GetSpentAmountsSHA256:1390-1397`, `GetSpentScriptsSHA256:1400-1407` |
| F10 | Schnorr verify (the only consensus-visible part of BIP340): sig 64/65 B; parse checks `r < p` (`fe_set_b32_limit`), `s < n` (overflow flag); challenge = tagged `BIP0340/challenge(r‖P‖m)`; `R = sG − eP`; reject infinity, odd-y, `x(R) ≠ r`. | `src/secp256k1/src/modules/schnorrsig/main_impl.h:secp256k1_schnorrsig_verify:208-253`; `src/pubkey.cpp:XOnlyPubKey::VerifySchnorr:236-242` |
| F11 | Taproot commitment check needs EC point math: `t = tagged TapTweak(p‖root)`; `Q = P + tG`; output x must equal `x(Q)` and control-bit must equal `y(Q) mod 2`. | `interpreter.cpp:VerifyTaprootCommitment:1913-1925`; `pubkey.cpp:CheckTapTweak:257-263`, `ComputeTapTweakHash:246-255` |
| F12 | Flag derivation is centralized: `{P2SH, WITNESS, TAPROOT}` unconditionally + `DERSIG`/`CLTV`/`CSV` (buried heights) + `NULLDUMMY` (segwit height) + per-block-hash exceptions (BIP16 block → `NONE`; one taproot-invalid block → `P2SH|WITNESS`). Taproot is no longer a BIP9 `DeploymentPos` entry at all in master. | `src/validation.cpp:GetBlockScriptFlags:2249-2288`; `src/kernel/chainparams.cpp:117-124`; `src/consensus/params.h:26-36,97,110` |
| F13 | Block witness commitment: coinbase output `OP_RETURN 0x24 0xaa 0x21 0xa9 0xed <32B>`, value = `SHA256d(witness_merkle_root ‖ reserved_value)`; witness merkle root uses wtxids with coinbase leaf = 0; coinbase input witness must be exactly one 32-byte item; blocks without commitment may carry no witness data. | `src/consensus/validation.h:GetWitnessCommitmentIndex:154-172`; `src/validation.cpp:CheckWitnessMalleation:3878-3924`; `src/consensus/merkle.cpp:BlockWitnessMerkleRoot:86-95` |
| F14 | Weight accounting: `weight = ser(tx, NO_WITNESS)*3 + ser(tx, WITH_WITNESS)` for tx *and* block; per-input witness weight includes the witness stack serialization (`GetWitnessInputWeight`). | `src/consensus/validation.h:139-151`; `src/consensus/consensus.h:13-24` |
| F15 | BIP146 (LOW_S, NULLFAIL, STRICTENC) and v0-MINIMALIF are enforced by *policy* flags (`STANDARD_SCRIPT_VERIFY_FLAGS`), never added by `GetBlockScriptFlags` — consensus-vs-policy boundary is verifiable by absence in that one function. | `src/policy/policy.h:101-110`; `validation.cpp:2249-2288` (absence); `interpreter.cpp:631-637` (MINIMALIF v0 comment: "only a policy rule") |

**VERIFIED vs INFERRED labeling** is used throughout the detailed analysis. "VERIFIED" = read directly
in the pinned source or BIP text. "INFERRED" = a deduction or a formalization suggestion not literally
in the sources.

---

## Detailed analysis

### (a) BIP141 — Segregated Witness (consensus layer)

**A.1 Witness program recognition (VERIFIED).**
`CScript::IsWitnessProgram` (`script.cpp:250-264`): a scriptPubKey (or BIP16 redeemScript) of total
length 4–42 bytes, first byte `OP_0` or `OP_1..OP_16` (version 0..16 via `DecodeOP_N`), second byte
a direct data-push length `L` with `L + 2 == size`, `L ∈ [2,40]`. BIP141 §"Witness program"
(`bip-0141.mediawiki:84-92`). Note the *byte-exact* template: `PUSH1 0x00 <20B>` is not a witness
program; a 41-byte push after `OP_0` is not either (BIP141 footnote at `bip-0141.mediawiki:107`).
INFERRED for Lean: model as an inductive `WitnessProgram := ⟨version : ℕ, program : Fin 41⟩` with a
decidable matcher; the "other sizes pass" behavior is the *softfork hook* and must be explicit.

**A.2 The two trigger sites (VERIFIED).**
`VerifyScript` (`interpreter.cpp:2012-2131`):
1. *Native*: `scriptPubKey.IsWitnessProgram` and `scriptSig` must be exactly empty —
   else `SCRIPT_ERR_WITNESS_MALLEATED` (2046-2051).
2. *P2SH-nested*: after P2SH evaluation, `pubKey2` (the redeemScript) `IsWitnessProgram`, and
   `scriptSig` must be exactly one push of the redeemScript — else `SCRIPT_ERR_WITNESS_MALLEATED_P2SH`
   (2088-2096).
Both paths set `hadWitness`; final rule: with `WITNESS` flag, a non-null witness on a non-witness
program → `SCRIPT_ERR_WITNESS_UNEXPECTED` (2120-2128). WITNESS requires P2SH (asserts at 2113-2114,
2124; also asserted in `CountWitnessSigOps:2154`).

**A.3 v0 program rules (VERIFIED).**
- 32-byte program → P2WSH: witness non-empty; last item = witnessScript; single `SHA256(witnessScript)`
  (NOT double) must equal program (`interpreter.cpp:1934-1946`) — note the single-SHA256 here vs
  double-SHA256 everywhere else in txid-land; BIP141 §"P2WSH" line 103.
- 20-byte program → P2WPKH: witness exactly 2 items; executed script is reconstructed
  `OP_DUP OP_HASH160 <program> OP_EQUALVERIFY OP_CHECKSIG` (1947-1953); key-hash check happens
  inside the executed script via `OP_HASH160` (Hash160 = RIPEMD160∘SHA256) and `OP_CHECKSIG`.
- Any other v0 size → `SCRIPT_ERR_WITNESS_PROGRAM_WRONG_LENGTH` (1954-1955).
- The v0 "script must fail if program hash CastToBool == 0" footnote (BIP141:109) is *not* separately
  implemented — INFERRED: it is vacuous because execution of the matched script determines outcome.

**A.4 Future versions (VERIFIED).**
`witversion ∉ {0, 1-with-32B}` (or v1 P2SH-wrapped, or P2A) → `return true` — anyone can spend,
unless `SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM` (a *policy/test* flag) is set (2002-2008).
No witness-stack size restriction for unknown versions (BIP141:109).

**A.5 Stack limits inside witness execution (VERIFIED).**
`ExecuteWitnessScript` (1842-1880): every initial stack item ≤ 520 bytes (`MAX_SCRIPT_ELEMENT_SIZE`,
`script.h:29`); for TAPSCRIPT additionally initial stack ≤ 1000 (`MAX_STACK_SIZE`, `script.h:44`,
checked at 1864-1865); implicit CLEANSTACK (exactly 1 element at end, 1876-1878) and top truthy
(1878). v0 also enforces `MAX_SCRIPT_SIZE = 10,000` on the executed script (`interpreter.cpp:438-440`
— condition includes `WITNESS_V0`). There is **no consensus limit on the number of witness stack
elements for v0** beyond those induced by execution (BIP141 only bounds item size).

**A.6 Weight & sigops (VERIFIED).**
- `weight = base_size*3 + total_size`, block limit 4,000,000 (`consensus.h:13-15,21`;
  `validation.cpp:4187`); per-tx and per-input analogues at `consensus/validation.h:139-151`.
- Sigop cost: legacy and P2SH counts ×4 (`tx_verify.cpp:GetTransactionSigOpCost:149-168`);
  witness sigops counted at cost 1 (P2WPKH=1, P2WSH=accurate count from the *last witness item*,
  `interpreter.cpp:WitnessSigOps:2133-2147`); block limit 80,000 cost (`consensus.h:17`).
  Taproot witness versions contribute **0** (`CountWitnessSigOps` handles only v0).
- P2SH-witness sigops come from the redeemScript inside `scriptSig` when P2SH+push-only
  (`CountWitnessSigOps:2162-2173`).

**A.7 Witness commitment (VERIFIED).**
See F13. The commitment is over `wtxid`s; the coinbase's own witness is *not* covered (leaf = 0) —
hence the malleation check is "ignored" per the code comment (3895-3897). Activation gate: a block
at/after segwit activation **must** have either a valid commitment or zero witness data anywhere
(`ContextualCheckBlock → CheckWitnessMalleation`, `validation.cpp:4177`, `3913-3921`); with a
commitment present, coinbase input witness must be exactly one 32-byte reserved value (3886-3893).
The "someone-can't-spend"/unspendable-genesis nuance: not present in BIP141's
consensus layer (it concerns `IsUnspendable`/OP_RETURN, script-interpreter territory) — out of scope here.

**A.8 Activation interplay (VERIFIED).**
BIP141/143/144/147 deployed together via BIP9, name "segwit", **bit 1** (`bip-0141.mediawiki:304-308`;
the pre-BIP91 attempt used bit 0 — historical only). Mainnet: LOCKED_IN→ACTIVE at height 481,824.
Current Core buries it: `Consensus::BuriedDeployment::DEPLOYMENT_SEGWIT` with `SegwitHeight`
(`params.h:32-34,110`; mainnet 481824 at `chainparams.cpp:124`). Two activation-time semantics:
(i) script flags switch on when `pindexPrev->nHeight >= SegwitHeight`
(`deploymentstatus.h:DeploymentActiveAfter:14-18`); (ii) the *block-structure* rules (commitment
requirement, weight limit) gate on the same predicate (`validation.cpp:3997,4177,4187`).

### (b) BIP143 — SegWit v0 sighash

**B.1 The preimage (VERIFIED).** `SignatureHash(..., SigVersion::WITNESS_V0)` (`interpreter.cpp:1633-1670`):
```
hash = SHA256d( version(4LE) ‖ hashPrevouts(32) ‖ hashSequence(32) ‖
                outpoint(36) ‖ scriptCode(var, CompactSize-prefixed) ‖ amount(8LE) ‖
                nSequence(4LE) ‖ hashOutputs(32) ‖ nLockTime(4LE) ‖ hashtype(4LE) )
```
Framing: `HashWriter::GetHash()` = double-SHA256 (`hash.h:123-128`); the trailing hashtype is
appended *after* any cached midstate (1680-1686).

**B.2 Sub-hash matrix (VERIFIED).**
- `hashPrevouts = SHA256d(all outpoints)` unless ANYONECANPAY (then zero) — 1639-1641.
- `hashSequence = SHA256d(all nSequence)` unless ACP or (SINGLE or NONE) — 1643-1645.
- `hashOutputs = SHA256d(all outputs)` unless SINGLE/NONE; for SINGLE with `nIn < vout.size`,
  `hashOutputs = SHA256d(vout[nIn])` (single, not double — `inner_ss.GetHash()`… note:
  `HashWriter{}` default, `inner_ss << txTo.vout[nIn]; hashOutputs = inner_ss.GetHash()` at
  1650-1652 — this is a *double*-SHA256 of the single output; the BIP text says "Double SHA256 of
  the serialization of 8. …" — VERIFIED consistent). Out-of-range SINGLE → zero hashOutputs.
- Zero sub-hashes are 32 zero bytes (`uint256{}`), never omitted — differs from BIP341.

**B.3 scriptCode (VERIFIED).**
- P2WPKH: `0x1976a914{20-byte-pubkey-hash}88ac` — constructed at `interpreter.cpp:1952` from the
  *program*, i.e. the hash comes from the scriptPubKey, not from the witness pubkey (the witness
  pubkey is verified against it by the executed `OP_EQUALVERIFY`). CScript serialization inside the
  digest adds the CompactSize length prefix (BIP143: "serialized as scripts inside CTxOuts").
- P2WSH: `scriptCode = script from pbegincodehash` (`EvalChecksigPreTapscript:336`), i.e. everything
  from the last executed `OP_CODESEPARATOR` (inclusive of none if none executed); **no**
  `FindAndDelete` of the signature (338-343); unexecuted `OP_CODESEPARATOR`s *after* the last
  executed one are retained (BIP143:43-44; worked example `bip-0143.mediawiki:295-312`).
- The 520-byte question: there is **no** scriptCode size limit *for hashing*; the
  10,000-byte `MAX_SCRIPT_SIZE` applies to the witnessScript as executed (`interpreter.cpp:438-440`).

**B.4 Hashtype handling (VERIFIED).**
One byte appended to the DER sig, popped before ECDSA verify (`CheckECDSASignature:1708-1713`);
empty signature → fail (1710-1711); the hashtype value itself is unrestricted (any int32 via low
bit 5 bits + ACP bit) — no encoding check on hashtype for v0 (unlike Tapscript's whitelist).
The `SIGHASH_SINGLE` bug (legacy: out-of-range SINGLE → hash `1`): structurally absent —
`interpreter.cpp:1614-1622` applies the early-return `uint256::ONE` only for non-WITNESS_V0;
BIP143 commits to zero hashOutputs instead (F6). Also `SINGLE|ANYONECANPAY` does not commit to the
input index (BIP143:49).

**B.5 Missing-data discipline (VERIFIED).**
`WITNESS_V0` sighash requires `amount >= 0` else `HandleMissingData` (1716) — in consensus mode
(`MissingDataBehavior::ASSERT_FAIL`) this is an assertion; the UTXO layer must guarantee amounts
(`tx_verify.cpp:CheckTxInputs` populates `spent_outputs`).

### (c) BIP144 / 145 / 146 / 147 — serialization, tx message, DER repression, dummy

**C.1 BIP144 (extended serialization, VERIFIED).** `UnserializeTransaction`
(`primitives/transaction.h:202-239`): marker = empty vin (size 0), then flag byte; `flag == 0` with
empty vin = legacy-style tx with zero inputs (edge case); `flag != 0` → real vin/vout; witness stacks
serialized per input iff `flag & 1` and `allow_witness`; "Superfluous witness record" error when the
witness flag is set but all stacks empty (229-232); unknown flag bits → error (234-237). txid = hash
of serialization *without* witness; wtxid = with (`TX_WITH_WITNESS`/`TX_NO_WITNESS` params,
181-182).

**C.2 BIP145 (getblocktemplate witness support)** — mining RPC: coinbase witness reserved value,
`SubmitSolution`; **not consensus** (the consensus residue is the commitment check, A.7). Catalogued
as out-of-scope-for-v1 (INFERRED).

**C.3 BIP146 (VERIFIED as policy-only).** LOW_S, NULLFAIL, and STRICTENC-defined-hashtype are
standardness: `CheckSignatureEncoding` gates them behind `SCRIPT_VERIFY_DERSIG|LOW_S|STRICTENC`
flags (`interpreter.cpp:211-226`) and `CheckPubKeyEncoding:228-236`; none appear in
`GetBlockScriptFlags`. The *consensus* member of that family is BIP66 DERSIG (buried at 363,725,
`validation.cpp:2268-2270`) which enforces `IsValidSignatureEncoding` (strict DER, incl. the
hashtype byte's high-bit rule). The "MINIMAL flag semantics" phrase maps to
`SCRIPT_VERIFY_MINIMALDATA` (`CheckMinimalPush`, `script.cpp:373+`) — also policy-only.

**C.4 BIP147 NULLDUMMY (VERIFIED, consensus).** Deployed with segwit (BIP9 bit 1); enforced at
`validation.cpp:2282-2285`; check at `interpreter.cpp:1209-1213`: before the unconditional dummy pop
in OP_CHECKMULTISIG/VERIFY, with `NULLDUMMY`, the dummy must be empty (`SCRIPT_ERR_SIG_NULLDUMMY`).
Applies to pre-segwit *and* P2WSH scripts (same code path; SigVersion-agnostic). The dummy pop
itself is consensus from genesis.

### (d) BIP340 — Schnorr signatures

**D.1 What is consensus (VERIFIED).** Only *verification*:
`XOnlyPubKey::VerifySchnorr` → `secp256k1_xonly_pubkey_parse` + `secp256k1_schnorrsig_verify`
(`pubkey.cpp:236-242`). Core calls it from `CheckSchnorrSignature` (`interpreter.cpp:1726-1752`)
which enforces the wrapper rules: sig size ∈ {64, 65} (`SCHNORR_SIG_SIZE`); for 65-byte sigs the
last byte is popped as hashtype and `0x00` is rejected (`SCHNORR_SIG_HASHTYPE`, 1740-1744); hashtype
range checked inside `SignatureHashSchnorr` (`hash_type ≤ 3 || 0x81 ≤ hash_type ≤ 0x83`, 1526).

**D.2 The verification equation (VERIFIED, BIP340 §Verification + secp256k1 main_impl.h:208-253).**
```
P  = lift_x(int(pk))                 — fail if x ≥ p or x³+7 not a QR mod p
r  = int(sig[0:32]);  fail if r ≥ p
s  = int(sig[32:64]); fail if s ≥ n
e  = int(tag_BIP0340/challenge(bytes(r) ‖ bytes(P) ‖ m)) mod n
R  = s·G − e·P
fail if is_infinite(R); fail if y(R) odd; fail if x(R) ≠ r
```
Core implements `fail if r ≥ p` via `secp256k1_fe_set_b32_limit` and `fail if s ≥ n` via
`secp256k1_scalar_set_b32`'s overflow flag. Field/group constants:
p = 2²⁵⁶ − 2³² − 977, n = 0xFFFF…D0364141 (`bip-0340.mediawiki:98-99`).

**D.3 Failure-condition inventory (complete, VERIFIED).**
1. pk not a valid x-coordinate (lift_x fails);
2. r ≥ p; 3. s ≥ n;
4. R infinite (s·G = e·P);
5. y(R) odd;
6. x(R) ≠ r;
7. (wrapper) sig length ∉ {64,65};
8. (wrapper) 65-byte sig with hashtype 0x00;
9. (wrapper) undefined hashtype (>3 and ∉ 0x81..0x83);
10. (SINGLE) `in_pos ≥ tx_to.vout.size()` → `SignatureHashSchnorr` returns false → same error.
On the "not both R and s invalid" acceptance nuance — INFERRED reading: verification is a
*total deterministic function*; there is no state in which a signature is "partially valid"; in
particular the verifier never accepts on a fallback equation (contrast: some ECDSA verifier
variants). The design property cited by BIP340 is "completely specified at the byte level"
(`bip-0340.mediawiki:60`) — the Lean spec should state and prove totality/determinism of
`verify : sig → pk → msg → Bool`.

**D.4 Key construction (VERIFIED).** x-only keys = 32-byte x-coordinates; implicit even-Y
(`lift_x`: y = +sqrt(x³+7), the even root); `XOnlyPubKey::GetEvenCorrespondingCPubKey`
(`pubkey.cpp:223-228`). Key prefixing rationale: related-key-attack resistance under additive
tweaks + MuSig security (`bip-0340.mediawiki:66`). INFERRED for Lean: x-only key type distinct from
`CPubKey`; `lift_x` requires modular sqrt — the field tower needs a *decidable* QR test on
secp256k1's prime field.

**D.5 Signing — NOT consensus (mark).** Nonce derivation `tag_BIP0340/nonce(tⁱ ‖ pk32 ‖ m ‖ a)`
with aux randomness `tag_BIP0340/aux`, plus signing-side verification-before-release
(`bip-0340.mediawiki:158`) are wallet-side. Tagged-hash midstates for nonce/aux exist in Core only
inside the secp256k1 *signing* module (`main_impl.h:16-38`). Out of btc-lean consensus scope;
keep a stub API for differential testing.

**D.6 Batch verification — implementation detail (mark).** `BatchVerify` (`bip-0340.mediawiki:196-234`)
is probabilistic and verifier-chosen; Core's consensus path verifies singly (`VerifySchnorrSignature`
virtual, `interpreter.cpp:1695-1699`). INFERRED: formalize as an optional theorem ("batch result ≡
individual results w.h.p.") much later, or skip.

### (e) BIP341 — Taproot

**E.1 Output template & dispatch (VERIFIED).** Native segwit output, version 1, 32-byte program;
P2SH-wrapped v1 is *not* taproot (falls to anyone-can-spend); non-32-byte v1 programs likewise.
Dispatch at `interpreter.cpp:1957-1999`; `SCRIPT_VERIFY_TAPROOT` absent → success (1959).

**E.2 Key path (VERIFIED).** Exactly one witness element after annex removal → the element is a
(64|65-byte) Schnorr signature over the output key `q` with the BIP341 sighash (1970-1975).
Construction: `t = tagged_TapTweak(P ‖ merkle_root)` (empty-root case: `tagged_TapTweak(P)`,
`pubkey.cpp:246-255`); `Q = P + int(t)·G`; output key = `x(Q)`. t < n check inside
`secp256k1_xonly_pubkey_tweak_add`. *Signing-side* tweak math is out of consensus scope; the
*validation-side* tweak check is consensus (see E.4).

**E.3 Script path (VERIFIED).**
- Control block `c`: length `33 + 32m`, `0 ≤ m ≤ 128` (`TAPROOT_CONTROL_BASE_SIZE=33`,
  `TAPROOT_CONTROL_MAX_NODE_COUNT=128`, `interpreter.h:244-247`); else
  `SCRIPT_ERR_TAPROOT_WRONG_CONTROL_SIZE` (1978-1982).
- `v = c[0] & 0xfe` leaf version; parity bit `c[0] & 1`.
- Tapleaf hash `k₀ = tag_TapLeaf(v ‖ CompactSize(|s|) ‖ s)` (`ComputeTapleafHash:1882-1885` —
  note the CompactSizeWriter for script length; single SHA256).
- Merkle: `k_{j+1} = tag_TapBranch(min‖max)` lexicographic (`ComputeTapbranchHash:1887-1896`,
  `ComputeTaprootMerkleRoot:1898-1911`).
- Commitment: `q == x(P + t·G)` and `c[0]&1 == y(Q) mod 2` (`VerifyTaprootCommitment:1913-1925`,
  `CheckTapTweak`) — else `WITNESS_PROGRAM_MISMATCH`.
- Leaf version 0xc0 (`TAPROOT_LEAF_TAPSCRIPT`, `interpreter.h:243`) → tapscript execution
  (1988-1993); any other leaf version → success (upgradable), with
  `DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` error flag (1995-1998).

**E.4 Sighash (VERIFIED).** Full spec F9 + `SignatureHashSchnorr:1492-1580`:
epoch 0x00; hashtype; nVersion; nLockTime; [sha_prevouts, sha_amounts, sha_scriptpubkeys,
sha_sequences] iff not ACP; [sha_outputs] iff output_type == ALL (or DEFAULT); spend_type
`= ext_flag*2 + annex_present`; then ACP ? (outpoint, full CTxOut amount+scriptPubKey, nSequence)
: input_index; [sha_annex] iff annex; [sha_single_output] iff SINGLE (with in-pos range failure);
tapscript extension iff TAPSCRIPT: tapleaf_hash, key_version 0x00, codesep_pos (uint32 LE).
All sub-hashes single-SHA256 (`GetSHA256`, `hash.h:134-138`); the whole message is fed to a
`TapSighash`-tagged hasher and finalized with single-SHA256, *then* BIP340 verifies over that
32-byte message — i.e. **no double-SHA256 anywhere in BIP341 hashing** (contrast BIP143).
The "sha-single/double nuance": VERIFIED mapping — single-SHA256: P2WSH program,
tapleaf/tapbranch/taptweak, all BIP341 sub-hashes; double-SHA256: BIP141 block/tx ids, BIP143
digest and its sub-hashes. Epoch byte exists to allow a future invasive redefinition of the
sighash under the same tag (BIP341 ref).

**E.5 Annex (VERIFIED).** Present iff ≥2 witness elements and last element starts 0x50
(`ANNEX_TAG`); popped before dispatch; hashed (with its own CompactSize prefix per BIP341 text —
Core: `(HashWriter{} << annex).GetSHA256()` where `<<` on a std::vector writes a CompactSize —
`interpreter.cpp:1964`); always covered by the signature via `spend_type` low bit; contributes to
weight; never interpreted.

**E.6 Resource limits (VERIFIED).**
- Validation weight (`m_validation_weight_left = GetSerializeSize(witness.stack) + 50`,
  `interpreter.cpp:1991`; constants `script.h:62,65`): each passed non-empty sigop −50; negative →
  `SCRIPT_ERR_TAPSCRIPT_VALIDATION_WEIGHT` (368-376). This *replaces* block-sigop accounting for
  v1 spends (see F8).
- Stack element ≤ 520; initial stack ≤ 1000 (tapscript); stack+altstack ≤ 1000 during execution
  (`interpreter.cpp:1232-1233`); no script-size and no op-count limit for tapscript (438-440,
  460-465 conditions exclude TAPSCRIPT); OP_SUCCESSx short-circuits everything including the
  initial-stack limits (1846-1862).

**E.7 Unspendable key paths / NUMS (VERIFIED, non-consensus).** NUMS point
`lift_x(0x50929b74…)`, `H + rG` trick, always-committing-a-script-path guidance
(`bip-0341.mediawiki:156-158`). Wallet guidance only; INFERRED: include as a comment/example in the
Lean tree-construction library, not in the validator.

### (f) BIP342 — Tapscript

**F.1 Opcodes (VERIFIED).**
- `OP_CHECKSIG`/`OP_CHECKSIGVERIFY`: Schnorr-only via `EvalChecksig` dispatch (402-415); semantics
  per BIP342 "Rules for signature opcodes": empty pubkey → fail; 32-byte pubkey → real verify
  (failure aborts script); other non-zero sizes → "unknown pubkey type", counted-but-always-success
  (with `DISCOURAGE_UPGRADABLE_PUBKEYTYPE` error flag, 383-392); empty signature → success=false,
  script continues (367) — this is why empty sigs don't hit the budget (368-376 only decrements
  when `success`).
- `OP_CHECKSIGADD` (0xba): `(sig num pubkey -- n+{0,1})`, only valid under TAPSCRIPT (1094-1113);
  `num` parsed as `CScriptNum(..., fRequireMinimal)` — under tapscript `fRequireMinimal` is
  whatever `MINIMALDATA` says (policy) but the 4-byte bound is structural in `CScriptNum`
  (BIP342: "If n is larger than 4 bytes, the script MUST fail" — enforced by CScriptNum ctor throw
  → SCRIPT_ERR_SCRIPTNUM). VERIFIED at `interpreter.cpp:1103` + CScriptNum ctor; INFERRED nuance:
  the 4-byte failure is a catch-path, not an explicit opcode check.
- `OP_CHECKMULTISIG`/`OP_CHECKMULTISIGVERIFY`: fail immediately under TAPSCRIPT
  (`SCRIPT_ERR_TAPSCRIPT_CHECKMULTISIG`, 1115-1118); ignored in unexecuted branches.
- OP_SUCCESSx = {80, 98, 126-129, 131-134, 137-138, 141-142, 149-153, 187-254} — unconditional
  script success, checked in a *pre-pass* over the executed script (so it overrides even
  initial-stack limits) (`IsOpSuccess` `script.cpp:365-371`; `ExecuteWitnessScript:1846-1862`).
- Consensus MINIMALIF (624-629): OP_IF/OP_NOTIF operand must be exactly `∅` or `0x01`.
- OP_CHECKLOCKTIMEVERIFY / OP_CHECKSEQUENCEVERIFY: retained from v0 (same code path — VERIFIED via
  absence of any TAPSCRIPT special-case in those cases, `interpreter.cpp:560-603`).
- OP_CODESEPARATOR retained; its *opcode position* (counting every parsed opcode incl. unexecuted
  branches and counting multi-byte pushes once) enters the sighash (`interpreter.cpp:443-445,
  1058-1067`, `opcode_pos` increments per parsed instruction).

**F.2 Limits retained vs dropped (VERIFIED).** Dropped: 10,000-byte script size; 201 op-count.
Retained: 520-byte elements (initial stack + pushes, 457-458); 1000 stack/altstack (extended to the
initial stack for tapscript, 1864-1865); CLEANSTACK + truthy top (1876-1878); sigops budget (E.6).

**F.3 leaf_version 0xc0 (VERIFIED).** `TAPROOT_LEAF_MASK = 0xfe`, `TAPROOT_LEAF_TAPSCRIPT = 0xc0`;
the mask (not equality) selects tapscript; the parity bit rides in the same byte.

**F.4 The "conserved limits" nuance (VERIFIED via BIP342 rationale refs).** The 50 WU/sigop factor
= 4M/80k; one free sigop (the +50 offset) covers non-witness input weight; the design intent is
CPU-cost-per-witness-byte parity between sigop-dense, hash-op-dense and OP_ROLL-dense scripts.

### (g) INTERACTION MATRIX — script type × epoch × flags

Core's single flag-derivation point is `GetBlockScriptFlags` (`validation.cpp:2249-2288`); the
interpreter derives everything else from the scriptPubKey shape. "Epoch" = activated-rule set of the
block *before* the spending block (`DeploymentActiveAt` uses `pindexPrev`).

| spend shape (scriptPubKey) | pre-2012 (no P2SH) | P2SH era (≥173,806) | DERSIG (≥363,725) | CLTV/CSV | segwit (≥481,824) | taproot (≥709,632) | Execution path |
|---|---|---|---|---|---|---|---|
| P2PK / P2PKH / bare multisig / OP_RETURN | legacy EvalScript, `SigVersion::BASE` | + P2SH only if template | + DERSIG on sigs | + CLTV/CSV | + NULLDUMMY on multisig | (no change) | `VerifyScript` main loop only |
| P2SH | — | BIP16 evaluate: scriptSig pushes redeemScript → eval as BASE | ditto | ditto | ditto | ditto | `VerifyScript:2062-2105` |
| P2SH-wrapped v0 witness | — | — | — | — | witness rules; scriptSig must be exactly `push(redeemScript)` | — | `VerifyScript:2088-2104` → `VerifyWitnessProgram(is_p2sh=true)` |
| native v0 witness | — | — | — | — | witness rules; scriptSig empty | — | `VerifyScript:2042-2059` → `VerifyWitnessProgram(is_p2sh=false)` |
| native v1 32B (taproot) | — | — | — | — | (anyone-can-spend before taproot!) | TAPROOT: key/script path, tapscript | `VerifyWitnessProgram:1957-1999` |
| P2SH-wrapped v1 32B | — | — | — | — | anyone-can-spend (even post-taproot) | same | `VerifyWitnessProgram` else-branch |
| P2A `OP_1 <0x4e73>` | — | — | — | — | anyone-can-spend w/ arbitrary (even empty) witness | same | `VerifyWitnessProgram:2000-2001` |
| unknown witness version/size | — | — | — | — | anyone-can-spend | same | `VerifyWitnessProgram:2002-2008` |

Per-epoch flag accumulation (VERIFIED, `GetBlockScriptFlags`):
`{P2SH, WITNESS, TAPROOT}` (always, minus the 2 exception blocks) `+ DERSIG@363725 + CLTV@388381 +
CSV@419328 + NULLDUMMY@481824`. Historically (pre-burial) P2SH was height-gated 173,806 and
WITNESS/TAPROOT were BIP9-gated — INFERRED from chainparams comments + BIP deployment sections; for
btc-lean the *buried* model is the one to formalize, with the exception-map as data.
Policy-only flags to catalogue but exclude from consensus: MINIMALDATA, MINIMALIF(v0), LOW_S,
NULLFAIL, STRICTENC, WITNESS_PUBKEYTYPE, SIGPUSHONLY, CLEANSTACK (consensus-cleanstack is *implicit*
inside witness execution instead), CONST_SCRIPTCODE, DISCOURAGE_* (test/policy aids).
Note the taproot exception block `0000000000000000000f14c35b2d841e986ab5441de8c585d5ffe55ea1e395ad`
was valid under `P2SH|WITNESS` only — a concrete mainnet test vector for flag-derivation faithfulness.

**Sighash-selection matrix (VERIFIED):** which digest an input uses is decided *per input* by
`sigversion`, which is decided by `VerifyWitnessProgram`: BASE for legacy/P2SH (incl. P2SH-wrapped
v1!), WITNESS_V0 for v0 programs, TAPROOT for key-path, TAPSCRIPT for 0xc0 leaves. Mixed-input
transactions (legacy + segwit + taproot in one tx) are fully supported; `PrecomputedTransactionData
::Init` (1412-1462) sniffs per-input which schemes are needed (a heuristic for caching only —
INFERRED: it cannot mis-validate because each `Check*Signature` call re-checks `*_ready` flags and
falls back to `HandleMissingData`).

---

## Implications for btc-lean

### I.1 The crypto tower — exactly what consensus needs (VERIFIED inventory)

| Primitive | Used by | Where in consensus path | Lean sizing |
|---|---|---|---|
| SHA-256 (single) | P2WSH program match; tapleaf/tapbranch/taptweak; all BIP341 sub-hashes; witness merkle root | interpreter + block validation | verified impl (crypto layer) |
| SHA-256 (double) | BIP143 digest + sub-hashes; txid/wtxid; witness commitment | sighash + block | same |
| RIPEMD-160 / Hash160 | P2WPKH reconstruction executes `OP_HASH160` | inside EvalScript (an interpreter opcode, but the crypto layer must supply it) | verified impl |
| secp256k1 field/group ops | taproot tweak check (P + tG, parity), lift_x | `CheckTapTweak` | the hard part; mathlib `ℤ` + custom mod arithmetic |
| ECDSA verify (lax DER parse, S-normalize) | every pre-tapscript CHECKSIG | `CPubKey::Verify` (`pubkey.cpp:283-298`) | hardest; consider axiomatized-at-first, verified later |
| BIP340 Schnorr verify | tapscript CHECKSIG + key path | `XOnlyPubKey::VerifySchnorr` | moderate (needs EC scalar mult) |
| Modular sqrt (lift_x) | BIP340 pk parse, NUMS | inside verify paths | p ≡ 3 mod 4 ⇒ sqrt = `c^((p+1)/4)` — easy |

### I.2 The interpreter ⇄ signature-layer API boundary (the key architectural recommendation)

Core draws the seam at `BaseSignatureChecker` (`interpreter.h:275-299`). Replicate it verbatim:

```lean
-- The interpreter's ONLY crypto dependencies (matches Core exactly):
class SignatureChecker (σ : Type) where
  checkECDSASignature : List UInt8 → List UInt8 → CScript → SigVersion → Bool
      -- sig(‖hashtype) ‖ pubkey ‖ scriptCode; sigversion ∈ {BASE, WITNESS_V0}
  checkSchnorrSignature : List UInt8 → List UInt8 → SigVersion → ScriptExecutionData →
      Except ScriptError Bool   -- sig ‖ xonly-pubkey; sigversion ∈ {TAPROOT, TAPSCRIPT}
  checkLockTime : ScriptNum → Bool
  checkSequence : ScriptNum → Bool

-- The signature layer's ONLY interpreter dependency:
structure SigEnv where
  tx : Tx; inPos : ℕ; amount : CAmount
  spentOutputs : Option (List CTxOut)   -- required for TAPROOT/TAPSCRIPT
  execData : ScriptExecutionData
```

Non-negotiable properties of the seam (each one is a VERIFIED Core behavior the Lean boundary must
preserve):
1. The interpreter computes **no hashes** over the transaction — all sighash logic lives behind
   `Check*Signature` (exceptions: tapleaf hash, annex hash, taproot merkle — these are computed *in*
   the interpreter into `execdata`, `interpreter.cpp:1964,1983`).
2. `ScriptExecutionData` (`interpreter.h:209-235`) is a *mutable output channel* of script
   execution (codesep_pos, tapleaf hash, annex, validation-weight-left, single-output hash) —
   model it as part of the interpreter state monad, threaded into the checker.
3. Amount presence is a *mode*: `MissingDataBehavior` distinguishes consensus (assert) from
   library (fail-closed) (`interpreter.h:304-308`). In Lean: two typed entry points instead.
4. Sig-encoding checks (DER, low-S, etc.) are **flag-driven inside the interpreter** (pre-segwit
   side) but *inside the pubkey layer* for Schnorr sizes — do not smuggle encoding policy into the
   crypto primitive: `CPubKey::Verify` accepts lax-DER + high-S, the flags are what make consensus
   strict.

### I.3 Formalization order (INFERRED, effort-ranked)

1. **SWT easy wins (d≤2):** witness program matcher; P2WPKH/P2WSH dispatch; weight formulas;
   witness commitment; BIP144 serialization.
2. **BIP143 digest (d=3):** pure byte-shuffling + SHA-256; test against BIP143's 8 worked examples
   (in `bip-0143.mediawiki:139-537`) — fully machine-checkable, no crypto beyond SHA-256.
3. **BIP341/342 dispatch + sighash (d=3-4):** same, plus tagged hashes; BIP341 JSON test vectors.
4. **Taproot commitment check (d=4):** needs the secp256k1 group; start with an *axiomatized*
   `xonly_tweak_add_check` and prove the surrounding logic; verify the group later (crypto layer).
5. **Schnorr/ECDSA verify (d=5):** axiomatize first (assume `verify_correct`), conformance-test on
   BIP340 `test-vectors.csv`; the full proof is the crypto layer's endgame.
6. **Sigops/weight accounting (d=3):** `GetTransactionSigOpCost` + tapscript budget; good theorem
   material ("budget ≥ 0 ⇒ at most ⌈(witness_size+50)/50⌉ sigops").

### I.4 Things easy to get wrong (from the code's own comments + history)

- Witness program must be matched on the *exact* bytes; non-minimal pushes are not witness
  programs (malleability return).
- P2SH-wrapped v1-32 is **not** taproot (BIP341 explicitly rejects wrapping).
- The v1-32 && is_p2sh && TAPROOT combination must return **success**, not an error.
- BIP143 zero sub-hashes vs BIP341 *omitted* sub-hashes.
- BIP143 double-SHA256 sub-hashes vs BIP341 single-SHA256 sub-hashes.
- Single `SHA256` for the P2WSH program vs `SHA256d` for the legacy P2SH.
- Tapscript OP_SUCCESSx pre-pass runs *before* the initial-stack limit check.
- Empty signature under tapscript: success=false *without* verify *without* abort; under v0/base:
  fail immediately (different!).
- The dummy pop in CHECKMULTISIG is unconditional; NULLDUMMY only constrains its size.
- `DeploymentActiveAt` uses the *previous* block's height.
- The 4-byte CScriptNum bound in OP_CHECKSIGADD fails via the scriptnum exception path.

---

## Open questions & risks

1. **(INFERRED → to verify against the block-level analysis)** Where exactly does
   `spent_outputs` get populated in the block-connection path (`ConnectBlock` → `CheckInputScripts`?) — the taproot sighash is
   undefined without it; the consensus assert (`m_bip341_taproot_ready`) is the contract. Needs the
   transaction-validation note cross-checked.
2. **Taproot activation modeling.** Master has *removed* taproot from `vDeployments` entirely
   (always-on + exception block). For chains where taproot activates at a height (signet? new
   chains?), btc-lean must decide: buried-height model everywhere, or keep a BIP9 model for
   taproot. (Current code implies: for mainnet, always-on.)
3. **`SigHashCache` / `PrecomputedTransactionData` midstates** are observable in neither outcome
   nor error — safe to omit from the spec (INFERRED; the CacheIndex comment at 1582-1589 confirms
   "no input can simultaneously use both").
4. **OP_SUCCESSx vs unknown-opcode distinction** under future leaf versions: for non-0xc0 leaves
   the *entire* script semantics is deferred (returns success) — the Lean spec should make
   "leaf-version dispatch" a total function returning `∞-many future semantics ⊎ tapscript`.
5. **`GetWitnessInputWeight`** (`consensus/validation.h:150`) — used where? (appears to serve
   mempool/package policy and possibly the taproot validation-weight equivalence). Confirm in the transaction-validation note
   that block validation only uses tx/block weight.
6. **BIP141 footnote 109** (CastToBool of program hash) is unimplemented/unimplementable in Core —
   document as "vacuous in practice" to preempt reviewer questions.
7. **ECDSA in Lean**: the lax-DER parse + normalize + verify chain is consensus-visible *only
   through its accept/reject decision*; a mismatched re-implementation silently forks. The BIP340
   test vectors are exact for Schnorr; for ECDSA the vectors are Core's own `data/` + `src/test/`.
   Risk: medium. Mitigation: differential harness against Core's `bitcoin-chainstate`.
8. **The two mainnet exception blocks** must be first-class citizens of the flag-derivation model,
   else replaying the chain in Lean fails at height ~234,000 (BIP16) and ~709,632 (taproot).

---

## Recommendations

1. **Adopt Core's seam verbatim**: `SignatureChecker` typeclass + `ScriptExecutionData` state;
   forbid any SHA256 call inside `Interpreter.lean` except the tapleaf/annex/merkle computations
   (which Core itself does in the interpreter). Enforce with an import-lint.
2. **Build BIP143 first** (no EC dependency, rich official vectors) as the template for
   BIP341's `SigMsg` — the two share structure (sub-hash matrix) and the contrast (zero vs omit,
   double vs single) is itself theorem material: `bip143_sighash ≠ bip341_sighash` for all inputs.
3. **Model `SigVersion` as a 4-constructor inductive from day one** (`BASE/WITNESS_V0/TAPROOT/
   TAPSCRIPT`) — it is the spine of the interaction matrix (VERIFIED `interpreter.h:201-207`).
4. **Axiomatize the secp256k1 layer behind 3 named assumptions** (`lift_x_correct`,
   `schnorr_verify_sound`, `ecdsa_verify_sound`, + `tweak_add_check_correct`), each with
   `#print axioms` tracking and conformance vectors; keep them in one `CryptoAssumptions.lean`.
5. **Encode the exception-map** (`script_flag_exceptions`) as literal data in the chain-params
   module and property-test `GetBlockScriptFlags` against it.
6. **Do not formalize**: signing, batch verify, mempool policy (BIP146 flags), BIP145 (mining),
   NUMS guidance. Catalogue them in a `nonconsensus.md` instead (the consensus/non-consensus boundary).
7. **Priority test corpus**: BIP143 worked examples; BIP341
   `wallet-test-vectors.json`; BIP340 `test-vectors.csv`; Core `src/test/script_tests.cpp`
   (search "taproot"/"P2WSH" blocks); the two mainnet exception blocks; a real mainnet taproot
   script-path spend block (e.g. pick one via RPC during the second milestone).

---

## Appendix A — Sources

**Primary source code (Bitcoin Core, pinned `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`, v32.99.0 master, cloned to `bitcoin/bitcoin`):**
- `src/script/interpreter.cpp` — `EvalChecksigPreTapscript:331-355`; `EvalChecksigTapscript:357-395`;
  `EvalChecksig:402-415`; `EvalScript:417-1245` (MINIMALIF 613-644, CODESEPARATOR 1058-1067,
  CHECKSIG 1069-1092, CHECKSIGADD 1094-1113, CHECKMULTISIG 1115-1225, NULLDUMMY 1209-1213);
  `GetPrevouts/Sequences/Outputs/SpentAmounts/SpentScriptsSHA256:1358-1407`;
  `PrecomputedTransactionData::Init:1412-1462`; tagged hashers 1476-1478;
  `SignatureHashSchnorr:1492-1580`; `SigHashCache:1582-1607`; `SignatureHash:1609-1687`;
  `CheckECDSASignature:1701-1724`; `CheckSchnorrSignature:1726-1752`; `ExecuteWitnessScript:1842-1880`;
  `ComputeTapleafHash:1882-1885`; `ComputeTapbranchHash:1887-1896`;
  `ComputeTaprootMerkleRoot:1898-1911`; `VerifyTaprootCommitment:1913-1925`;
  `VerifyWitnessProgram:1927-2010`; `VerifyScript:2012-2131`; `WitnessSigOps:2133-2147`;
  `CountWitnessSigOps:2149-2176`; flag-name map 2178-2206.
- `src/script/interpreter.h` — SIGHASH enum 30-39; verify flags 48-151; `SigVersion:201-207`;
  `ScriptExecutionData:209-235`; witness/taproot constants 238-251; checker vtable 275-299.
- `src/script/script.cpp` — `GetSigOpCount:159-205`; `IsPayToAnchor:207-222`;
  `IsPayToScriptHash:224-231`; `IsPayToWitnessScriptHash:233-239`; `IsPayToTaproot:241-246`;
  `IsWitnessProgram:250-264`; `IsOpSuccess:365-371`.
- `src/script/script.h` — limits 29-44; `VALIDATION_WEIGHT_*:62-65`; `CScriptWitness`.
- `src/script/sigencoding` — n/a (encoding checks live in `interpreter.cpp:180-236`:
  `IsValidSignatureEncoding`, `CheckSignatureEncoding:211-226`, `CheckPubKeyEncoding:228-236`).
- `src/pubkey.cpp` — `XOnlyPubKey::VerifySchnorr:236-242`; `ComputeTapTweakHash:246-255`;
  `CheckTapTweak:257-263`; `CreateTapTweak:265-280`; `CPubKey::Verify:283-298`.
- `src/secp256k1/src/modules/schnorrsig/main_impl.h` — `secp256k1_schnorrsig_verify:208-253`;
  tagged midstates 16-32.
- `src/consensus/consensus.h` — weight/sigop constants 13-24. `src/consensus/params.h` —
  buried deployments 26-36; `script_flag_exceptions:97`; `SegwitHeight:110`.
- `src/consensus/validation.h` — `GetWitnessCommitmentIndex:154-172`;
  `GetTransactionWeight/GetBlockWeight/GetWitnessInputWeight:139-151`.
- `src/consensus/tx_verify.cpp` — sigop costs 118-168. `src/consensus/merkle.cpp` —
  `BlockWitnessMerkleRoot:86-95`.
- `src/validation.cpp` — `GetBlockScriptFlags:2249-2288`; `ConnectBlock:2294+`;
  `CheckWitnessMalleation:3878-3924`; `UpdateUncommittedBlockStructures:3995-4003`;
  `GenerateCoinbaseCommitment:4005-4027`; contextual checks 4121-4190.
- `src/primitives/transaction.h` — extended serialization 190-265.
- `src/kernel/chainparams.cpp` — mainnet params incl. exception blocks 117-124.
- `src/deploymentstatus.h`, `src/deploymentinfo.cpp` — deployment queries/burial.
- `src/policy/policy.h:101-110` — `STANDARD_SCRIPT_VERIFY_FLAGS` (the policy/consensus boundary).

**BIP texts (`bitcoin/bips`, pin `927b6de9915c9262615a6399de51b200f81e5aa4`):**
`bip-0141.mediawiki` (§Witness program:84-109, §P2WPKH/P2WSH:94-109, §Block size:112-121,
§Sigops:128-132, §Deployment:304-308); `bip-0143.mediawiki` (§Specification:26-77, worked examples
139-537, §No FindAndDelete:539+); `bip-0144.mediawiki`; `bip-0145.mediawiki`; `bip-0146.mediawiki`
(LOW_S/NULLFAIL, policy); `bip-0147.mediawiki` (NULLDUMMY, bit-1 deployment); `bip-0340.mediawiki`
(§Design:60-77, §Verification:174-194, §Batch:196-234, constants 98-99) + `test-vectors.csv`;
`bip-0341.mediawiki` (§Script validation:56-84, §Common signature message:89-135, key-path
validation 137-146, construction/NUMS 147-158, deployment 338-349) + `wallet-test-vectors.json`;
`bip-0342.mediawiki` (§Script execution:69-81, §Rules for signature opcodes:82-103, §Common
Signature Message Extension:105-111, §Signature validation:112-123, §Resource limits:125-135).

**Not found / N/A:** BIP148/149 (activation of segwit via UASF — historical, no consensus code);
BIP116 (MERKLEBRANCHVERIFY — not deployed); `src/script/sigencoding*` does not exist as a file in
this tree (encoding checks are in interpreter.cpp); "someone-can't-spend/unspendable genesis" —
no such construct in BIP141/341; out of scope here.

---

## Appendix B — THE SEGWIT-TAPROOT RULE TABLE

Legend: **SWT** = SegWit-era (141/143/144/145/146/147 + adjacent), **TPR** = Taproot-era
(340/341/342). Difficulty: 1 = trivial encode, 5 = needs deep crypto/proof work.
All Core citations @`c50817f`. "BIP §" = section anchor in the mediawiki text.

### B.1 SegWit (SWT)

| Rule ID | Rule/check | Core location @c50817f | One-line spec statement | BIP ref | Diff |
|---|---|---|---|---|---|
| SWT-001 | Witness program template | script.cpp:IsWitnessProgram:250-264 | scriptPubKey (or redeemScript) of 4..42 bytes = (OP_0 or OP_1..OP_16) + direct push of 2..40 bytes whose length byte + 2 equals total size | 141 §Witness program | 1 |
| SWT-002 | Version decoding | script.cpp:IsWitnessProgram:259 | witness version = OP_N decoded value (OP_0→0, OP_1..OP_16→1..16) | 141 | 1 |
| SWT-003 | Native-witness scriptSig emptiness | interpreter.cpp:VerifyScript:2048-2051 | if scriptPubKey is a witness program, scriptSig must be exactly empty | 141 | 1 |
| SWT-004 | P2SH-witness scriptSig exactness | interpreter.cpp:2090-2096 | if redeemScript is a witness program, scriptSig must be exactly one push of that redeemScript | 141 | 1 |
| SWT-005 | P2WPKH witness arity | interpreter.cpp:VerifyWitnessProgram:1949-1951 | v0 20-byte program requires witness of exactly 2 items | 141 | 1 |
| SWT-006 | P2WPKH script reconstruction | interpreter.cpp:1952 | executed script = `OP_DUP OP_HASH160 <program> OP_EQUALVERIFY OP_CHECKSIG` | 141 | 1 |
| SWT-007 | P2WSH witness arity | interpreter.cpp:1936-1938 | v0 32-byte program requires non-empty witness | 141 | 1 |
| SWT-008 | P2WSH program match | interpreter.cpp:1941-1945 | SHA256(last witness item) must equal the 32-byte program (single SHA256) | 141 | 2 |
| SWT-009 | v0 wrong-length program | interpreter.cpp:1954-1955 | v0 program of size ∉ {20,32} → WITNESS_PROGRAM_WRONG_LENGTH | 141 | 1 |
| SWT-010 | Witness item size limit | interpreter.cpp:ExecuteWitnessScript:1868-1871 | every initial witness stack item ≤ 520 bytes | 141 (≤520 per item) | 1 |
| SWT-011 | v0 script size limit | interpreter.cpp:EvalScript:438-440 | executed script under WITNESS_V0 ≤ 10,000 bytes | 141 (witnessScript ≤10,000) | 1 |
| SWT-012 | Implicit cleanstack (witness) | interpreter.cpp:1876-1878 | witness execution must end with exactly 1 truthy stack item | 141 (P2WSH semantics) | 1 |
| SWT-013 | Future-version pass-through | interpreter.cpp:2002-2008 | witness version/size combos other than v0-20/32 and v1-32-native validate as anyone-can-spend | 141 | 1 |
| SWT-014 | DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM | interpreter.cpp:2003-2005 | optional flag: unknown witness program → error (policy/test hook) | 141 | 1 |
| SWT-015 | WITNESS_UNEXPECTED | interpreter.cpp:2120-2128 | non-null witness on a non-witness-program output fails (WITNESS flag on) | 141 | 1 |
| SWT-016 | WITNESS⇒P2SH implication | interpreter.cpp:2113-2114,2124 | WITNESS flag requires P2SH flag (structural assertion) | 141 | 1 |
| SWT-017 | Block weight formula | consensus.h:13-15,21; validation.cpp:4187 | weight = base_size×3 + total_size ≤ 4,000,000 | 141 §Block size | 2 |
| SWT-018 | WITNESS_SCALE_FACTOR | consensus.h:21 | legacy units are weight/4 | 141 | 1 |
| SWT-019 | Tx weight | consensus/validation.h:139-141 | tx weight = ser(no-witness)×3 + ser(with-witness) | 141/144 | 2 |
| SWT-020 | Tx virtual size | (derived) | vsize = ⌈weight/4⌉ (policy-facing but defined here) | 141 §Additional definitions | 1 |
| SWT-021 | Block sigop cost limit | consensus.h:17; tx_verify.cpp:149-168 | Σ sigop-cost ≤ 80,000 per block | 141 §Sigops | 2 |
| SWT-022 | Legacy sigop cost ×4 | tx_verify.cpp:GetTransactionSigOpCost:151 | legacy script sigops count 4 cost units each | 141 | 2 |
| SWT-023 | P2SH sigop cost ×4 | tx_verify.cpp:156-158 | P2SH redeemScript sigops count 4 cost units each | 141 | 2 |
| SWT-024 | Witness sigop cost ×1 | tx_verify.cpp:160-166 | witness-derived sigops count 1 cost unit each (not ×4) | 141 | 2 |
| SWT-025 | P2WPKH = 1 sigop | interpreter.cpp:WitnessSigOps:2136-2137 | each P2WPKH input counts exactly 1 sigop | 141 | 1 |
| SWT-026 | P2WSH sigop counting | interpreter.cpp:2139-2142 | accurate sigop count of the last witness item (witnessScript) | 141 | 2 |
| SWT-027 | P2SH-wrapped witness sigops | interpreter.cpp:CountWitnessSigOps:2162-2173 | P2SH scriptSig's last push, if a witness program, yields witness sigops | 141 | 2 |
| SWT-028 | Taproot/v1 zero sigops | interpreter.cpp:2133-2147 | witness versions >0 contribute 0 block sigops | 341/342 | 1 |
| SWT-029 | Witness commitment template | consensus/validation.h:GetWitnessCommitmentIndex:154-172 | coinbase output `OP_RETURN 0x24 0xaa 0x21 0xa9 0xed <32B>` selects the commitment | 141 §Commitment | 1 |
| SWT-030 | Commitment value | validation.cpp:CheckWitnessMalleation:3898-3906 | committed value = SHA256d(witness_merkle_root ‖ reserved_value), compared to scriptPubKey[6..38] | 141 | 2 |
| SWT-031 | Witness reserved value shape | validation.cpp:3886-3893 | coinbase input witness must be exactly one 32-byte item when commitment present | 141 | 1 |
| SWT-032 | Witness merkle root | consensus/merkle.cpp:BlockWitnessMerkleRoot:86-95 | root over wtxids of all non-coinbase txs; coinbase leaf = 0 | 141/144 | 2 |
| SWT-033 | No witness without commitment | validation.cpp:3913-3921 | block with no commitment output may contain no witness data | 141 | 1 |
| SWT-034 | Commitment required post-activation | validation.cpp:ContextualCheckBlock:4177 | blocks after segwit activation must pass CheckWitnessMalleation(expect=true) | 141 | 1 |
| SWT-035 | Segwit activation height (buried) | consensus/params.h:110; chainparams.cpp:124 | mainnet segwit active from block 481,824 (flags via pindexPrev) | 141 §Deployment | 1 |
| SWT-036 | BIP9 bit-1 deployment (historical) | bip-0141.mediawiki:304-308 | segwit deployed by BIP9 name "segwit", bit 1, start 2016-11-15 | 141 | 2 |
| SWT-037 | Extended tx serialization | primitives/transaction.h:UnserializeTransaction:202-239 | vin==0 ⇒ next byte is flag; flag&1 ⇒ per-input witness stacks after vout | 144 | 2 |
| SWT-038 | Marker/flag = 0x00/0x01 | transaction.h:212-218 | witness encoding: dummy byte 0x00 then flag 0x01 | 144 | 1 |
| SWT-039 | Superfluous witness record | transaction.h:229-232 | witness flag with all-empty stacks = serialization error | 144 | 1 |
| SWT-040 | Unknown serialization flags | transaction.h:234-237 | any flag bit ≠ 1 → error (future flags are hardforks) | 144 | 1 |
| SWT-041 | txid/wtxid split | transaction.h:181-182 + GetHash/GetWitnessHash | txid = SHA256d(ser, no witness); wtxid = SHA256d(ser, with witness) | 141/144 | 1 |
| SWT-042 | BIP143 digest structure | interpreter.cpp:SignatureHash:1633-1670 | SHA256d over the 10-field preimage (version, 3 sub-hashes, outpoint, scriptCode, amount, sequence, outputs-hash, locktime, hashtype) | 143 §Specification | 3 |
| SWT-043 | hashPrevouts condition | interpreter.cpp:1639-1641, 1358-1365 | SHA256d(all outpoints) iff ¬ANYONECANPAY else zero-vector | 143 | 2 |
| SWT-044 | hashSequence condition | interpreter.cpp:1643-1645, 1369-1376 | SHA256d(all nSequence) iff ¬ACP ∧ ¬(SINGLE∨NONE) else zero | 143 | 2 |
| SWT-045 | hashOutputs condition | interpreter.cpp:1647-1653, 1379-1387 | SHA256d(all outputs) iff ¬(SINGLE∨NONE); SINGLE∧in-range ⇒ SHA256d(vout[nIn]); else zero | 143 | 3 |
| SWT-046 | v0 out-of-range SINGLE | interpreter.cpp:1614-1622 vs 1647-1653 | for WITNESS_V0, SINGLE with nIn ≥ vout.size uses zero hashOutputs (no uint256::ONE early return) — legacy SINGLE bug absent | 143 | 3 |
| SWT-047 | P2WPKH scriptCode | interpreter.cpp:1952 + 1664; bip-0143:50 | scriptCode = `0x1976a914{20B}88ac` (CompactSize-prefixed in the digest) | 143 item 5 | 2 |
| SWT-048 | P2WSH scriptCode | interpreter.cpp:EvalChecksigPreTapscript:336 | scriptCode = witnessScript from last executed OP_CODESEPARATOR onward | 143 item 5 | 3 |
| SWT-049 | No FindAndDelete (v0) | interpreter.cpp:338-343 | signature is removed from scriptCode only for SigVersion::BASE | 143 §No FindAndDelete | 2 |
| SWT-050 | Amount commitment (v0) | interpreter.cpp:1665 | 8-byte LE spent amount inside the digest | 143 | 1 |
| SWT-051 | Hashtype 4-byte LE framing | interpreter.cpp:1685 | digest ends with 4-byte LE hashtype (appended even on cache hit) | 143 | 1 |
| SWT-052 | Double-SHA256 framing | hash.h:HashWriter::GetHash:123-128 | BIP143 digest and sub-hashes are SHA256d | 143 | 1 |
| SWT-053 | Sig hashtype byte appended | interpreter.cpp:CheckECDSASignature:1708-1713 | last sig byte = hashtype, popped before DER/verify | 141/143 | 1 |
| SWT-054 | Empty sig invalid (v0) | interpreter.cpp:1710-1711 | empty signature fails CHECKSIG (v0/base) | 141 | 1 |
| SWT-055 | Amount-presence mode | interpreter.cpp:1716; interpreter.h:304-308 | WITNESS_V0 sighash requires amount ≥ 0; missing data ⇒ assert (consensus) or fail | 143 | 2 |
| SWT-056 | WITNESS_PUBKEYTYPE compressed-only | interpreter.cpp:CheckPubKeyEncoding:228-236 | compressed-pubkey restriction exists as a flag; **not** set in consensus (policy) | 143 §Restrictions | 2 |
| SWT-057 | BIP145 getblocktemplate | (RPC, non-consensus) | witness-reserved-value plumbing for mining | 145 | 1 |
| SWT-058 | BIP146 LOW_S | interpreter.cpp:CheckSignatureEncoding:219-221 | low-S rule = policy only (flag LOW_S absent from GetBlockScriptFlags) | 146 | 2 |
| SWT-059 | BIP146 NULLFAIL | interpreter.cpp:351-352, 1196-1197 | failing sigs must be empty — policy only | 146 | 2 |
| SWT-060 | BIP146 STRICTENC/hashtype | interpreter.cpp:222-223 | defined-hashtype check = policy only | 146 | 2 |
| SWT-061 | BIP66 DERSIG (consensus) | validation.cpp:2268-2270; interpreter.cpp:217-218 | strict-DER sig encoding enforced from height 363,725 | 66/146 | 2 |
| SWT-062 | MINIMALIF (v0) policy | interpreter.cpp:631-637 | MINIMALIF flag exists for v0 but is not consensus | 342 (contrast) | 2 |
| SWT-063 | BIP147 NULLDUMMY activation | validation.cpp:2282-2285 | NULLDUMMY active exactly with segwit (buried height) | 147 | 1 |
| SWT-064 | NULLDUMMY check | interpreter.cpp:1209-1213 | CHECKMULTISIG dummy element must be empty (consensus, post-segwit) | 147 | 1 |
| SWT-065 | Dummy pop unconditional | interpreter.cpp:1203-1213 | CHECKMULTISIG consumes the extra element regardless of flags (genesis rule) | (BIP62 history) | 1 |
| SWT-066 | SigHashCache equivalence | interpreter.cpp:1582-1607 | midstate caching must be outcome-invisible (6 cache slots by hashtype class) | (impl detail) | 2 |
| SWT-067 | Witness input weight | consensus/validation.h:150 | witness input weight = no-wit ser×3 + wit ser + stack ser | 141/144 | 2 |
| SWT-068 | Mixed-scheme txs | interpreter.cpp:PrecomputedTransactionData::Init:1423-1443 | a single tx may mix BASE/WITNESS_V0/TAPROOT/TAPSCRIPT inputs; per-input dispatch | 141/341 | 3 |

### B.2 Taproot (TPR)

| Rule ID | Rule/check | Core location @c50817f | One-line spec statement | BIP ref | Diff |
|---|---|---|---|---|---|
| TPR-001 | Taproot output template | interpreter.cpp:1957; script.cpp:IsPayToTaproot:241-246 | witness v1 + 32-byte program, native only (never P2SH-wrapped) | 341 §Script validation | 1 |
| TPR-002 | TAPROOT flag gate | interpreter.cpp:1959 | without SCRIPT_VERIFY_TAPROOT, v1-32 spends succeed | 341 | 1 |
| TPR-003 | P2SH-wrapped v1 = anyone-can-spend | interpreter.cpp:1957→2002-2008 | P2SH-embedded v1 programs are unencumbered today | 341 ref | 2 |
| TPR-004 | P2A anchor | interpreter.cpp:2000-2001; script.cpp:IsPayToAnchor:216-222 | `OP_1 <0x4e73>` (v1, 2-byte program) validates unconditionally with any witness | 341 (post-BIP; txpkg context) | 2 |
| TPR-005 | Annex detection | interpreter.cpp:1961-1969 | ≥2 witness items and last item starts 0x50 ⇒ annex, popped | 341 | 2 |
| TPR-006 | Annex hash | interpreter.cpp:1964, 1554-1556 | sha_annex = SHA256(CSize(len)‖annex incl. 0x50); enters sighash iff present | 341 | 2 |
| TPR-007 | Key-path condition | interpreter.cpp:1970-1975 | exactly 1 element (post-annex) ⇒ single BIP340 sig against output key q | 341 | 2 |
| TPR-008 | Script-path trigger | interpreter.cpp:1976-1979 | ≥2 elements ⇒ last = control block, second-to-last = script | 341 | 1 |
| TPR-009 | Control block size | interpreter.cpp:1980-1982; interpreter.h:244-247 | len = 33 + 32m, 0 ≤ m ≤ 128, else TAPROOT_WRONG_CONTROL_SIZE | 341 | 1 |
| TPR-010 | Leaf version extraction | interpreter.cpp:1983; interpreter.h:242 | v = control[0] & 0xfe | 341 | 1 |
| TPR-011 | Parity bit | interpreter.cpp:1924 (control[0]&1) | low bit of control[0] must equal y(Q) mod 2 | 341 | 3 |
| TPR-012 | Tapleaf hash | interpreter.cpp:ComputeTapleafHash:1882-1885 | tag_TapLeaf(v ‖ CSize(|script|) ‖ script), single SHA256 | 341 | 2 |
| TPR-013 | TapBranch lexicographic pairing | interpreter.cpp:ComputeTapbranchHash:1887-1896 | parent = tag_TapBranch(sorted pair), single SHA256 | 341 | 2 |
| TPR-014 | Merkle walk | interpreter.cpp:ComputeTaprootMerkleRoot:1898-1911 | fold path elements left-to-right from leaf hash | 341 | 2 |
| TPR-015 | TapTweak hash | pubkey.cpp:ComputeTapTweakHash:246-255 | t = tag_TapTweak(p ‖ merkle_root) (p alone if root absent) | 341 | 2 |
| TPR-016 | Commitment equation | interpreter.cpp:VerifyTaprootCommitment:1913-1925 | q = x(P + int(t)·G) with parity match, else WITNESS_PROGRAM_MISMATCH | 341 | 4 |
| TPR-017 | tweak range check | secp256k1 (xonly_pubkey_tweak_add_check); bip-0341:78 | t < n required | 341 | 3 |
| TPR-018 | Internal key on-curve check | pubkey.cpp:CheckTapTweak:260 | control-block pubkey must parse as a curve point (lift_x) | 341 | 3 |
| TPR-019 | leaf 0xc0 ⇒ tapscript | interpreter.cpp:1988-1993; interpreter.h:243 | control[0]&0xfe == 0xc0 executes script with SigVersion::TAPSCRIPT | 342 | 1 |
| TPR-020 | Other leaf versions succeed | interpreter.cpp:1995-1998 | non-0xc0 leaves validate as success (softfork hook) | 341 | 1 |
| TPR-021 | DISCOURAGE_UPGRADABLE_TAPROOT_VERSION | interpreter.cpp:1995-1997 | optional error for future leaf versions | 341 | 1 |
| TPR-022 | Validation-weight init | interpreter.cpp:1991; script.h:62,65 | budget = serialized witness size + 50 WU | 342 §Resource limits | 2 |
| TPR-023 | Sigop budget decrement | interpreter.cpp:368-376 | each passed non-empty sigop −50; negative ⇒ TAPSCRIPT_VALIDATION_WEIGHT | 342 | 2 |
| TPR-024 | Empty sig skips budget | interpreter.cpp:367-376 | empty signature: success=false, no decrement, script continues | 342 | 2 |
| TPR-025 | Empty pubkey fails | interpreter.cpp:377-378 | pubkey size 0 ⇒ script failure | 342 | 1 |
| TPR-026 | Unknown pubkey types | interpreter.cpp:383-392 | size ∉ {0,32} ⇒ counted but always-successful sigop | 342 | 2 |
| TPR-027 | DISCOURAGE_UPGRADABLE_PUBKEYTYPE | interpreter.cpp:389-391 | optional error for unknown pubkey sizes | 342 | 1 |
| TPR-028 | Sig size ∈ {64,65} | interpreter.cpp:1736 | otherwise SCHNORR_SIG_SIZE | 340/341 | 1 |
| TPR-029 | 65-byte sig hashtype | interpreter.cpp:1740-1744 | last byte popped as hashtype; 0x00 rejected in 65-byte form | 341 | 1 |
| TPR-030 | Hashtype domain | interpreter.cpp:1526 | hash_type ≤ 3 or 0x81..0x83, else failure | 341 | 2 |
| TPR-031 | SIGHASH_DEFAULT | interpreter.h:37; interpreter.cpp:1524 | missing sighash byte (64B sig) ≡ ALL; only as 64-byte sig | 341 | 2 |
| TPR-032 | Sighash epoch byte | interpreter.cpp:1519-1521 | message = tag_TapSighash(0x00 ‖ SigMsg(...)) | 341 | 1 |
| TPR-033 | SigMsg ordering | interpreter.cpp:1529-1567 | hashtype, nVersion, nLockTime, [prevouts/amounts/scriptpubkeys/sequences], [outputs], spend_type, input data, [annex], [single-output] | 341 §Common signature message | 3 |
| TPR-034 | sha_prevouts (single) | interpreter.cpp:1533, 1447 | SHA256(all outpoints), iff ¬ACP | 341 | 2 |
| TPR-035 | sha_amounts | interpreter.cpp:1534, 1458, 1390-1397 | SHA256(all spent input amounts), iff ¬ACP — commits to the fee | 341 | 2 |
| TPR-036 | sha_scriptpubkeys | interpreter.cpp:1535, 1459, 1400-1407 | SHA256(all spent scriptPubKeys as CTxOut scripts), iff ¬ACP | 341 | 2 |
| TPR-037 | sha_sequences | interpreter.cpp:1536, 1448 | SHA256(all nSequence), iff ¬ACP (incl. NONE/SINGLE!) | 341 | 2 |
| TPR-038 | sha_outputs condition | interpreter.cpp:1538-1540 | only when output_type = ALL/DEFAULT | 341 | 2 |
| TPR-039 | spend_type | interpreter.cpp:1545-1546 | (ext_flag × 2) + annex_present | 341 | 1 |
| TPR-040 | ACP input data | interpreter.cpp:1547-1550 | outpoint ‖ full prevout (amount+scriptPubKey) ‖ nSequence | 341 | 2 |
| TPR-041 | Input index (¬ACP) | interpreter.cpp:1552 | 4-byte LE input index | 341 | 1 |
| TPR-042 | SINGLE output hash | interpreter.cpp:1559-1567 | SHA256(vout[in_pos]); in_pos ≥ vout.size ⇒ failure | 341 | 2 |
| TPR-043 | ext_flag mapping | interpreter.cpp:1496-1508 | TAPROOT⇒0, TAPSCRIPT⇒1; key_version = 0 (tapscript) | 341/342 | 1 |
| TPR-044 | Tapscript sighash extension | interpreter.cpp:1570-1576 | ‖ tapleaf_hash ‖ key_version(0x00) ‖ codesep_pos(4LE) | 342 | 2 |
| TPR-045 | codesep_pos semantics | interpreter.cpp:443-445, 1058-1067; 1575 | opcode index of last executed OP_CODESEPARATOR, 0xFFFFFFFF default; counts parsed-but-unexecuted opcodes; multi-byte push = 1 | 342 | 3 |
| TPR-046 | Single-SHA256 everywhere (341) | interpreter.cpp:GetSHA256 uses; hash.h:134-138 | BIP341 message + sub-hashes use single SHA256 (no double) | 341 | 2 |
| TPR-047 | Tagged hash construction | hash.cpp:TaggedHash:85-91 | SHA256(SHA256(tag)‖SHA256(tag)‖msg) | 340 §Tagged hashes | 1 |
| TPR-048 | BIP340 challenge tag | secp256k1 schnorrsig main_impl.h (+bip-0340) | e = int(tag_BIP0340/challenge(r‖P‖m)) mod n | 340 | 3 |
| TPR-049 | lift_x | secp256k1 xonly parse; bip-0340:114 | y = even root of x³+7 mod p; fail if x ≥ p or non-QR | 340 | 4 |
| TPR-050 | r bound | secp256k1 main_impl.h:212 (fe_set_b32_limit) | fail if int(sig[0:32]) ≥ p | 340 | 3 |
| TPR-051 | s bound | secp256k1 main_impl.h:213-216 (overflow flag) | fail if int(sig[32:64]) ≥ n | 340 | 3 |
| TPR-052 | Verification equation | secp256k1 main_impl.h:226-253 | R = s·G − e·P; fail if ∞, odd-y, or x(R) ≠ r | 340 | 5 |
| TPR-053 | Totality/determinism of verify | (INFERRED design goal) bip-0340:60 | verify is a total deterministic function of (sig, pk, msg) | 340 | 4 |
| TPR-054 | X-only pubkey type | pubkey.cpp:XOnlyPubKey:200-234 | 32-byte x-coordinate; both parities derivable (GetCPubKeys) | 340 | 2 |
| TPR-055 | Tapscript CHECKSIG = Schnorr-only | interpreter.cpp:402-415 dispatch | v0/base sigversions use ECDSA path; TAPSCRIPT uses Schnorr path | 342 | 2 |
| TPR-056 | CHECKSIGADD opcode | interpreter.cpp:1094-1113 | (sig num pubkey -- num+{0,1}); 0xba; tapscript-only | 342 | 2 |
| TPR-057 | CHECKSIGADD outside tapscript | interpreter.cpp:1097 | BAD_OPCODE under BASE/WITNESS_V0 | 342 | 1 |
| TPR-058 | CScriptNum 4-byte bound (CSA) | interpreter.cpp:1103 (CScriptNum ctor) | num operand >4 bytes ⇒ failure (scriptnum exception path) | 342 | 3 |
| TPR-059 | CHECKMULTISIG disabled | interpreter.cpp:1115-1118 | TAPSCRIPT ⇒ TAPSCRIPT_CHECKMULTISIG failure; ignored unexecuted | 342 | 1 |
| TPR-060 | OP_SUCCESSx set | script.cpp:IsOpSuccess:365-371 | opcodes {80,98,126-129,131-134,137-138,141-142,149-153,187-254} | 342 | 1 |
| TPR-061 | OP_SUCCESSx pre-pass | interpreter.cpp:ExecuteWitnessScript:1846-1862 | unconditional success, overrides all limits incl. initial-stack size | 342 | 2 |
| TPR-062 | DISCOURAGE_OP_SUCCESS | interpreter.cpp:1856-1859 | optional error replacing the success short-circuit | 342 | 1 |
| TPR-063 | Consensus MINIMALIF | interpreter.cpp:624-629 | OP_IF/NOTIF operand must be ∅ or 0x01 (consensus in tapscript) | 342 | 2 |
| TPR-064 | No script-size limit (tapscript) | interpreter.cpp:438-440 (condition) | 10,000-byte limit not applied to TAPSCRIPT | 342 | 1 |
| TPR-065 | No op-count limit (tapscript) | interpreter.cpp:460-465 (condition) | 201-op limit not applied to TAPSCRIPT | 342 | 1 |
| TPR-066 | Initial stack ≤ 1000 (tapscript) | interpreter.cpp:1864-1865 | MAX_STACK_SIZE applies to the witness stack before execution | 342 | 1 |
| TPR-067 | Stack+altstack ≤ 1000 | interpreter.cpp:1232-1233 | retained from legacy, checked after every opcode | 342 | 1 |
| TPR-068 | 520-byte push limit retained | interpreter.cpp:457-458, 1868-1871 | pushes during execution ≤ 520 bytes | 342 | 1 |
| TPR-069 | Tapscript sigops excluded from block limit | interpreter.cpp:CountWitnessSigOps:2133-2147 (returns 0 for v1) | v1 spends contribute 0 to the 80,000 cost | 342 | 2 |
| TPR-070 | Key-path spend: no sigop cost | interpreter.cpp:1970-1975 | key-path signature not counted anywhere in sigop accounting | 341 | 2 |
| TPR-071 | Annex counts toward weight | interpreter.cpp:1991 (whole stack serialized); consensus/validation.h:150 | annex included in witness serialization ⇒ weight & budget base | 341 | 2 |
| TPR-072 | ScriptExecutionData plumbing | interpreter.h:209-235 | codesep/tapleaf/annex/weight/single-output hash threaded interpreter→checker | 341/342 | 3 |
| TPR-073 | CLTV/CSV retained | interpreter.cpp:560-603 (no TAPSCRIPT special-case) | OP_CHECKLOCKTIMEVERIFY/OP_CHECKSEQUENCEVERIFY behave as in v0 | 342 | 2 |
| TPR-074 | Disabled opcodes still disabled | interpreter.cpp:467-478 | OP_CAT..OP_RSHIFT fail under tapscript too (until re-enabled by OP_SUCCESSx renaming — none of these are SUCCESSx) | 342 | 2 |
| TPR-075 | Taproot activation params | chainparams.cpp:117-124 (MinBIP9WarningHeight comment); bip-0341:346-349 | mainnet activated at 709,632 via BIP9 bit 2 (historical; buried/always-on in master) | 341 §Deployment | 2 |
| TPR-076 | Taproot exception block | chainparams.cpp:117-121 | block `…1e395ad` validates with flags P2SH|WITNESS only | (mainnet history) | 2 |
| TPR-077 | Always-on base flags | validation.cpp:GetBlockScriptFlags:2261 | {P2SH, WITNESS, TAPROOT} enforced from genesis (mod exceptions) in current master | 341 | 1 |
| TPR-078 | DeploymentActiveAt uses pprev | deploymentstatus.h:14-18,36 | flags apply when previous-block height ≥ activation height | 90/141 | 2 |
| TPR-079 | BIP341/342 deployment coupling | validation.cpp (no TAPROOT deployment entry); bip-0342:138-140 | tapscript rules activate identically with taproot | 342 | 1 |
| TPR-080 | Batch verify = non-consensus | pubkey.cpp:1695-1699 (single verify) | consensus path verifies each Schnorr sig individually | 340 §Batch | 2 |
| TPR-081 | Signing/nonce = non-consensus | secp256k1 schnorrsig module (signing side) | nonce/aux derivation outside validation | 340 §Signing | 1 |
| TPR-082 | NUMS guidance non-consensus | bip-0341:156-158 | H = lift_x(0x50929b74…) construction is wallet guidance | 341 | 1 |
| TPR-083 | Unspendable-script-path tweak | pubkey.cpp:ComputeTapTweakHash:248-251 | t = tag_TapTweak(p) with no merkle root (key-only outputs still tweakable) | 341 | 2 |

**Row count: 68 SWT + 83 TPR = 151 rows.** (The original target was 90+; delivered ~1.7×, split so the
SegWit-era traceability can be maintained independently of the Taproot-era one.)

---

*End of report 09. All VERIFIED citations are reproducible from the pinned sources above.*
