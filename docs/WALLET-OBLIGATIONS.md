# Wallet obligation register

This register covers the **99** wallet census rows whose review verdict is
`PARTIAL` (30) or `UNMODELLED` (69). The remaining 41 rows are outside this
register: 37 are recorded as entailed and 4 had contradicted text corrected.
37 declarations carry 40 `@[walletRule]` row tags; three of those tags sit on
PARTIAL rows (`DESC-005`, `PSBT-002`, `PSBT-003`). No row in this register is
proved.

Snapshot: 2026-10-17; Bitcoin Core pin `cce32b168`. Row summaries and
`core_ref` values are quoted from `spec/db/rules-wallet.yaml`.

## Scope

Source rows are the 140 wallet census rows in `spec/db/rules-wallet.yaml`.
This register covers the **99** rows whose verdict is `PARTIAL` (30) or `UNMODELLED`
(69). The remaining 41 rows are out of scope: 37 `ENTAILED` and 4 `WRONG`
(`SGN2-011`, `MS-014`, `MS-016`, `MS-022`); a `WRONG` row is a contradiction to fix,
not an obligation to prove, and `ENTAILED` rows are already tagged. Three
PARTIAL rows also carry tags: `DESC-005`, `PSBT-002`, and `PSBT-003`; their
obligations remain open.

Every row below quotes the current `summary` from `spec/db/rules-wallet.yaml` and
the YAML `core_ref`, resolved against Core `cce32b168`. `PARTIAL` rows name the
existing declaration and the exact uncovered case. Each obligation is classified:

* **MODEL** — the model lacks the object, field, invariant, or semantics needed to
  state the row; a definition or structure must be added before a theorem can exist.
* **PROOF** — the object exists in the committed model and the row needs a theorem
  statement (guards, directions, or classification) that no declaration provides.

**No obligation below is proved.** The `obligation` column is a specification of the
missing statement, including Lean syntax where the current names permit it; it is not
a proof claim, and `oblig_*` Props in `Obligations.lean` are restatements, not evidence.

## Counts

| Namespace | Rows | PARTIAL | UNMODELLED | MODEL | PROOF |
|---|---:|---:|---:|---:|---:|
| DESC | 23 | 6 | 17 | 9 | 14 |
| SGN2 | 13 | 0 | 13 | 13 | 0 |
| MS | 13 | 8 | 5 | 6 | 7 |
| PSBT | 20 | 10 | 10 | 18 | 2 |
| WSP | 30 | 6 | 24 | 29 | 1 |
| **Total** | **99** | **30** | **69** | **75** | **24** |

| Verdict | MODEL | PROOF | Total |
|---|---:|---:|---:|
| PARTIAL | 16 | 14 | 30 |
| UNMODELLED | 59 | 10 | 69 |
| **Total** | **75** | **24** | **99** |

## Register

## DESC — descriptor parsing and expansion

23 rows: 6 PARTIAL, 17 UNMODELLED; 9 MODEL, 14 PROOF.

### DESC-002 — UNMODELLED / PROOF

- **Row summary:** checksum symbol grouping
- **Core anchor:** `src/script/descriptor.cpp:171` at `cce32b168`
- **Existing declaration:** none
- **Obligation (PROOF, unproved):** The loop exists as `descriptorChecksum.loop`, but only its invalid-character failure (`loop_none`) is stated. Obligation: prove the group algebra, e.g. for characters `a b c` with `charsetIndex inputCharset a = some pa` (and `pb`, `pd`), `descriptorChecksum.loop [a,b,c] c 0 0 = some (polyMod (polyMod (polyMod (polyMod c (pa % 32)) (pb % 32)) (pd % 32)) ((pa/32)*9 + (pb/32)*3 + (pd/32)))`, plus the one- and two-character partial-group cases ending in `polyMod c cls` for `count ≠ 0`. This is the row's `3*cls + (pos >> 5)` symbol and final fold; neither is stated by any existing declaration.

### DESC-005 — PARTIAL / PROOF

- **Row summary:** checksum attachment
- **Core anchor:** `src/script/descriptor.cpp:188` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Desc.addChecksum_eq`
- **Obligation (PROOF, unproved):** `addChecksum_eq` is unconditional: for an invalid payload `descriptorChecksum payload = ""`, so it yields `payload ++ "#"`, not the row's eight-character suffix. Missing guard and direction: state `(h : descriptorChecksum payload ≠ "") → (addChecksum payload).length = payload.length + 9` and `(addChecksum payload).drop (payload.length + 1) = descriptorChecksum payload`, or equivalently `descriptorChecksum payload ≠ "" → ∃ c, descriptorChecksum payload = c ∧ c.length = 8`. `descriptorChecksum_length` gives only 0-or-8, never the nonempty case.

### DESC-008 — UNMODELLED / PROOF

- **Row summary:** checksum length
- **Core anchor:** `src/script/descriptor.cpp:2990` at `cce32b168`
- **Existing declaration:** none
- **Obligation (PROOF, unproved):** `checkChecksum` has the `checksum.length ≠ 8` branch, and `oblig_DESC_008` restates the row, but no theorem. Obligation: `theorem checkChecksum_checksumLength (payload checksum : String) (h1 : ¬ payload.toList.contains '#') (h2 : ¬ checksum.toList.contains '#') (h3 : checksum.length ≠ 8) : checkChecksum (payload ++ "#" ++ checksum) false = .error (.checksumLength checksum.length)`, and the `parse` corollary that no `Descriptor` is returned. The `requireChecksum = false` direction is the one the row needs and is unstated.

### DESC-009 — UNMODELLED / PROOF

- **Row summary:** checksum mismatch
- **Core anchor:** `src/script/descriptor.cpp:3001` at `cce32b168`
- **Existing declaration:** none
- **Obligation (PROOF, unproved):** Only the equal-checksum acceptance branch (`checkChecksum_addChecksum`) is proved; the unequal rejection is not. Obligation: `theorem checkChecksum_mismatch (payload checksum : String) (h1 : ¬ payload.toList.contains '#') (h2 : ¬ checksum.toList.contains '#') (h8 : checksum.length = 8) (hc : descriptorChecksum payload ≠ "") (hne : checksum ≠ descriptorChecksum payload) : checkChecksum (payload ++ "#" ++ checksum) false = .error (.checksumMismatch checksum (descriptorChecksum payload))`, plus `parse (payload ++ "#" ++ checksum) = .error _` (no descriptor returned). `oblig_DESC_009` is an unproved Prop, not evidence.

### DESC-010 — UNMODELLED / PROOF

- **Row summary:** complete parse
- **Core anchor:** `src/script/descriptor.cpp:3017` at `cce32b168`
- **Existing declaration:** none
- **Obligation (PROOF, unproved):** `parsePayload` performs the `rest.isEmpty` test, but `parseTop` is private and no declaration characterises success. Obligation: expose and prove `theorem parsePayload_rest (payload : String) (d : Descriptor) (h : parsePayload payload = .ok d) : ∃ rest, parseTop payload.toList = .ok (d, rest) ∧ rest = []`, its converse `parseTop payload.toList = .ok (d, []) → parsePayload payload = .ok d`, and the lift through `parseWithChecksum`/`parse`. Complete-input consumption is currently only vector-tested by `#eval`, not theorem-stated.

### DESC-011 — UNMODELLED / PROOF

- **Row summary:** hybrid keys
- **Core anchor:** `src/script/descriptor.cpp:2002` at `cce32b168`
- **Existing declaration:** none
- **Obligation (PROOF, unproved):** `constKeyValid` rejects hybrid prefixes by construction, but no declaration states it for all contexts; `oblig_DESC_011` is an unproved Prop. Obligation: `theorem constKeyValid_hybrid (ctx : KeyContext) (k : ByteArray) (h65 : k.size = 65) (hp : k.get! 0 = 0x06 ∨ k.get! 0 = 0x07) : constKeyValid ctx k = false`, for `legacy`, `segwit` and `taproot` (the only constructors). The parser-side corollary `parseKeyExpr ... = .error (.invalidKey _)` is also missing.

### DESC-012 — UNMODELLED / PROOF

- **Row summary:** uncompressed key contexts
- **Core anchor:** `src/script/descriptor.cpp:1986` at `cce32b168`
- **Existing declaration:** none
- **Obligation (PROOF, unproved):** `constKeyValid` is definitionally legacy-accepting and segwit/taproot-rejecting, but no iff is stated; `oblig_DESC_012` is unproved. Obligation: `theorem constKeyValid_uncompressed (k : ByteArray) (h65 : k.size = 65) (hp : k.get! 0 = 0x04) (hv : uncompressedKeyValid k = true) : constKeyValid .legacy k = true ∧ constKeyValid .segwit k = false ∧ constKeyValid .taproot k = false`, plus the converse `constKeyValid .legacy k = true → compressedKeyValid k = true ∨ (k.size = 65 ∧ uncompressedKeyValid k = true)`. The model has one `legacy` context, so Core's TOP/P2SH split cannot be stated as written (record caveat).

### DESC-013 — UNMODELLED / MODEL

- **Row summary:** x-only key parsing
- **Core anchor:** `src/script/descriptor.cpp:2014` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** `KeyExpr` stores 32 bytes plus an `xonly : Bool` flag; there is no lifted 33-byte even-y key, so the row's lifted representation has no model object. Obligation: add `def liftXonly (x : ByteArray) : Option ByteArray` with `theorem liftXonly_spec (h : liftXonly x = some k) : k.size = 33 ∧ k.get! 0 = 0x02 ∧ k.extract 1 33 = x ∧ (Bitcoin.Crypto.Curve.Secp.liftX (bytesToNatBE x)).isSome`, store the lifted key in `KeyExpr`, and prove `constKeyValid .taproot x = true ↔ (liftXonly x).isSome` while `constKeyValid .segwit x = false ∧ constKeyValid .legacy x = false`. `constKeyValid .taproot` currently tests only the x-coordinate and keeps the key at 32 bytes.

### DESC-014 — UNMODELLED / MODEL

- **Row summary:** extended private key neutering
- **Core anchor:** `src/script/descriptor.cpp:2051` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** `Parse` accepts `xpub`/`tpub` only; there is no xprv body, no private-key storage in a signing provider, and no neutered-xpub continuation. Obligation: add a private-key variant to `KeyExpr` and a provider carrying it, with `theorem parse_xprv_neuters (h : parseKeyExpr body ctx = .ok k) (hk : k.body = .xprv sk) : provider k = some (neuterXprv sk) ∧ signable k` and preservation of depth/fingerprint under neutering. `neuter_key` and `neuter_depth` are BIP32 metadata lemmas; they do not state parse-plus-store and cannot entail the row.

### DESC-015 — UNMODELLED / PROOF

- **Row summary:** range specifier
- **Core anchor:** `src/script/descriptor.cpp:1971` at `cce32b168`
- **Existing declaration:** none
- **Obligation (PROOF, unproved):** `parseKeyExpr_const_wildcard` proves only that literal keys have no wildcard. Missing, for each of `/*`, `/*'` and `/*h`: `theorem parseKeyExpr_wildcard_unhardened (body ctx k) (h : parseKeyExpr (body ++ "/*") ctx = .ok k) : k.wildcard = Wildcard.unhardened`; the two hardened variants with `/*'` and `/*h`; the reverse direction `k.wildcard = .unhardened → body ends in /*`; and rejection of `/*x`, `/**`, and a non-final `*`. The suffix-selection rule itself is unstated.

### DESC-016 — UNMODELLED / PROOF

- **Row summary:** origin fingerprint
- **Core anchor:** `src/script/descriptor.cpp:2226` at `cce32b168`
- **Existing declaration:** none
- **Obligation (PROOF, unproved):** `parseOrigin` checks length 8, hexadecimal decoding and a 4-byte result, but no declaration proves acceptance iff those hold; `oblig_DESC_016` covers only the length ≠ 8 rejection. Obligation: `theorem parseOrigin_fingerprint (fp rest : String) : (∃ o, parseOrigin ("[" ++ fp ++ "/" ++ rest ++ "]x") = .ok o) ↔ fp.length = 8 ∧ fp.toList.all isHexDigit`, and on success `(hexDecode? fp).isSome ∧ (hexDecode? fp).get!.size = 4`; add the non-hex-character rejecting direction. `parseKeyExpr_origin` only preserves an already-parsed origin.

### DESC-017 — PARTIAL / PROOF

- **Row summary:** key path element
- **Core anchor:** `src/util/bip32.cpp:26` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Key.parseChildNumber_render`
- **Obligation (PROOF, unproved):** `parseChildNumber_render` proves only that canonical renderings round-trip (`h` suffix for hardened, no suffix for unhardened). Missing: (i) the apostrophe branch `parseChildNumber (toString n ++ "'") = .ok (n + 0x80000000).toUInt32` for `n < 2^31`; (ii) the reverse direction `parseChildNumber s = .ok c → (c.isHardened = true ↔ s.endsWith "'" ∨ s.endsWith "h")`; (iii) rejection `n ≥ 2^31 → ∃ e, parseChildNumber (toString n) = .error e`, tying the bound projected by `parseChildNumber_range` to parse failure.

### DESC-018 — UNMODELLED / MODEL

- **Row summary:** multipath alternatives
- **Core anchor:** `src/script/descriptor.cpp:1933` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** Multipath is absent: `parsePathElement` rejects `<`/`>` wholesale, and there is no alternatives list, no `parseMultipath`, and no duplicate-value rule. Obligation: add `def parseMultipath (s : String) : Except DescriptorError (List UInt32)` with `theorem parseMultipath_length (h : parseMultipath s = .ok xs) : 2 ≤ xs.length`, `theorem parseMultipath_nodup (h : parseMultipath s = .ok xs) : xs.Nodup`, and the row's repeated-numeric-value rejection. The current grammar cannot state the row at all.

### DESC-019 — UNMODELLED / PROOF

- **Row summary:** multipath outside origin
- **Core anchor:** `src/script/descriptor.cpp:2241` at `cce32b168`
- **Existing declaration:** none
- **Obligation (PROOF, unproved):** `parsePathElement` rejects `<`/`>` and `parseOrigin` calls `parsePathElements`, but no declaration proves the origin path; `oblig_DESC_019` is an unproved Prop. Obligation: `theorem parsePathElement_multipath (text : String) (h : text.toList.any (fun c => c = '<' ∨ c = '>') = true) : ∃ e, parsePathElement text = .error e`, plus the origin-level corollary `parseOrigin ("[" ++ fp ++ "/<0;1>]x") = .error (.keyPathRange _)`. `parseKeyExpr_origin` only preserves already-parsed origins.

### DESC-020 — PARTIAL / MODEL

- **Row summary:** pk expansion
- **Core anchor:** `src/script/descriptor.cpp:1242` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Desc.expand?_pk_const`
- **Obligation (MODEL, unproved):** `expand?_pk_const` is already key-length-generic: `payToPubkey` pushes any `ByteArray`, so a 32-byte key would give a 0x20 push. The missing link is parser admission: `pk` is parsed in `.legacy` only, so no P2TR `pk(K)` reaches the AST. Obligation: extend `parseKeyExpr`/`parseTop` to admit `pk` in `.taproot` for 32-byte (and 33-byte) keys, then state `theorem expand?_pk_xonly (o k raw) (h32 : k.size = 32) : expand? (.pk (.const o k true raw)) (fun _ => []) = .ok [payToPubkey k]` and the parser-acceptance lemma. The P2TR context is a model gap, not a missing arithmetic theorem.

### DESC-023 — PARTIAL / MODEL

- **Row summary:** sh expansion
- **Core anchor:** `src/script/descriptor.cpp:1464` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Desc.expand?_shWpkh_const`
- **Obligation (MODEL, unproved):** Only `sh(wpkh(K))` exists (`Descriptor.shWpkh`); there is no general `sh(X)` constructor, no arbitrary redeem script, and `expand?` returns `List Script` rather than recording a redeem script. Obligation: add `| sh (redeem : Descriptor)` with `theorem expand?_sh (d p) (s) (h : expand? d p = .ok [s]) : expand? (.sh d) p = .ok [payToScriptHash s]` and a redeem-script output/provider carrying `s`. The row's general-X and recording clauses have no object; the existing theorem is a proper special case.

### DESC-024 — UNMODELLED / MODEL

- **Row summary:** wsh expansion
- **Core anchor:** `src/script/descriptor.cpp:1514` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** `wsh` is absent from both `Descriptor` and `expand?`; there is no SHA256 script-hash construction and no witness-script recording. Obligation: add `| wsh (witness : Descriptor)` with `theorem expand?_wsh (d p) (s) (h : expand? d p = .ok [s]) : expand? (.wsh d) p = .ok [⟨opcode 0x00 ++ pushData (sha256 s)⟩]` (32-byte SHA256 program) and a witness-script output. The `sha256` fragment in the Miniscript layer hashes a 32-byte preimage; it is not a descriptor witness-script hash.

### DESC-025 — PARTIAL / PROOF

- **Row summary:** sorted multisig
- **Core anchor:** `src/script/descriptor.cpp:1376` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Desc.expand?_multi_consts`
- **Obligation (PROOF, unproved):** `expand?_multi_consts` requires `hne : ks ≠ []` and covers only all-constant keys; `expand?_multi_xpub_consts` covers one ranged key plus constants. Missing: (i) the empty-list case (`alignedCount [] = none`, so `expand? = .error`); (ii) two or more ranged keys, equal and unequal lengths, and interleaved constants; (iii) the general statement `theorem expand?_multi (d p ks scripts) (h : expand? (.multi t ks sorted) p = .ok scripts) : scripts.length = n ∧ ∀ i < n, scripts[i] = multiScript t (if sorted then sortPubkeys (ithKeys ks i) else ithKeys ks i)`. `multi` order and `sortPubkeys` are exact, so only the theorem is missing.

### DESC-026 — UNMODELLED / PROOF

- **Row summary:** bare multisig limit
- **Core anchor:** `src/script/descriptor.cpp:2479` at `cce32b168`
- **Existing declaration:** none
- **Obligation (PROOF, unproved):** `parseMultiFunction` checks `keyTexts.length > 3` for both names, but `oblig_DESC_026` mentions only `multi` and is unproved. Obligation: `theorem parse_multi_keyCap (t : Nat) (ks : List String) (h : 3 < ks.length) (hok : ∀ k ∈ ks, ∃ ke, parseKeyExpr k .legacy = .ok ke) : (∃ e, parse (multiText t ks) = .error e) ∧ (∃ e, parse (sortedMultiText t ks) = .error e)`, where the two constructors are the `multi` and `sortedmulti` spellings. The `sortedmulti` half of the row has no declaration at all.

### DESC-027 — UNMODELLED / MODEL

- **Row summary:** p2sh multisig size
- **Core anchor:** `src/script/descriptor.cpp:2485` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `sh(multi)` model and no `script_size + 3 ≤ 520` accounting; `multiScript` emits a bare script with no size predicate, and the parser has no P2SH context. Obligation: add `def multiScriptSize (t : Nat) (ks : List ByteArray) : Nat` with `theorem multiScript_size (h : ∀ k ∈ ks, k.size = 33) : (multiScript t ks).bytes.size = multiScriptSize t ks` and `theorem parse_sh_multi_size (h : 520 < multiScriptSize t ks + 3) : parse ... = .error (.context _)`. The row's size policy has no object.

### DESC-028 — PARTIAL / PROOF

- **Row summary:** taproot key-path expansion
- **Core anchor:** `src/script/descriptor.cpp:1565` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Desc.specExpand?_tr_const`
- **Obligation (PROOF, unproved):** `specExpand?_tr_const` yields `[script]` only under `h : taprootKeyPath pubkey = some script`, and `taprootKeyPath` unfolds to `p2trOutput xonly none`. Obligation: prove the explicit identification `(h32 : internalKey.size = 32) → taprootKeyPath internalKey = (Bitcoin.Crypto.Taproot.Verify.p2trOutput internalKey none).map (fun b => ⟨b⟩)`, the 33-byte drop-prefix case, the witness-v1 program shape (`script.bytes.size = 34 ∧ script.bytes.get! 0 = 0x51 ∧ script.bytes.get! 1 = 0x20`), and the transfer `expand?_tr_const`. Empty-tree `TaprootBuilder` finalisation and BIP341 output identification remain unstated.

### DESC-029 — UNMODELLED / MODEL

- **Row summary:** taproot tree depth
- **Core anchor:** `src/script/descriptor.cpp:2603` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `TapTree`/`TaprootBuilder` and no depth counter: `tr` carries only the internal key and `tr(key,tree)` is rejected as an unexpected token. Obligation: add a binary `TapTree` with depth/leaf-version fields, `def TAPROOT_CONTROL_MAX_NODE_COUNT : Nat := 128`, and `theorem parseTapTree_depth (t : TapTree) (h : parseTapTree raw = .ok t) : t.depth ≤ 128`, plus the rejection branch for deeper trees. The row's rejection has no object.

### DESC-030 — UNMODELLED / MODEL

- **Row summary:** combo expansion
- **Core anchor:** `src/script/descriptor.cpp:1347` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** `combo` has no `Descriptor` constructor and no `expand?` case, so the four-script conditional output set cannot be stated. Obligation: add `| combo (k : KeyExpr)` with `theorem expand?_combo (o k x raw) : expand? (.combo (.const o k x raw)) (fun _ => []) = .ok ([payToPubkey k, payToPubkeyHash k] ++ (if k.size = 33 then [payToWitnessPubkeyHash k, payToScriptHash (payToWitnessPubkeyHash k)] else []))`, plus a `KeyExpr.isCompressed` predicate (33-byte key). Absent.

## SGN2 — wallet signing paths

13 rows: 0 PARTIAL, 13 UNMODELLED; 13 MODEL, 0 PROOF.

### SGN2-001 — UNMODELLED / MODEL

- **Row summary:** single-argument signing overload
- **Core anchor:** `src/wallet/wallet.cpp:1991` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** `Sign.Spec` starts at the abstract `Signer`/`requestOf` boundary; there is no wallet coin map and no single-argument entry point. Obligation: add `structure WalletCoins where coins : List (OutPoint × TxOut)` and `def signTransaction (w : Wallet) (tx : Tx) : Option Tx := signTransactionWithSighash w tx SIGHASH_DEFAULT`, then `theorem signTransaction_eq_delegate (w tx) : signTransaction w tx = signTransactionWithSighash w tx SIGHASH_DEFAULT`. Nothing in the current layer states the delegation.

### SGN2-002 — UNMODELLED / MODEL

- **Row summary:** signing manager sweep
- **Core anchor:** `src/wallet/wallet.cpp:1997` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `ScriptPubKeyMan` iteration or early return; `SignerSpec` is a per-request oracle, not a manager sweep. Obligation: add `structure ScriptPubKeyMan where signTransaction : Tx → Option Tx` and `def walletSign (mans : List ScriptPubKeyMan) (tx : Tx) : Bool := mans.any (fun m => (m.signTransaction tx).isSome)`, with `theorem walletSign_true_iff (h : walletSign mans tx = true) : ∃ m ∈ mans, (m.signTransaction tx).isSome` and the first-success ordering lemma. Absent.

### SGN2-003 — UNMODELLED / MODEL

- **Row summary:** descriptor signing providers
- **Core anchor:** `src/wallet/scriptpubkeyman.cpp:1379` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `DescriptorScriptPubKeyMan::SignTransaction` bridge and no merged-provider construction from coin scriptPubKeys. Obligation: add `def mergeProviders (coins : List (Script × TxOut)) : SigningProvider` and `theorem signTransaction_descriptor (m tx ht) : m.signTransaction tx = genericSignTransaction (mergeProviders m.coins) tx ht`. `Sign.Bridge` relates PSBT requests to an abstract `Signer`, not a descriptor manager.

### SGN2-004 — UNMODELLED / MODEL

- **Row summary:** cached expansion
- **Core anchor:** `src/wallet/scriptpubkeyman.cpp:1326` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No descriptor signing-provider cache or derivation-index expansion. Obligation: add `structure DescriptorCache where get : Script → Option SigningProvider` and `def getSigningProvider (m : DescriptorManager) (spk : Script) : SigningProvider := (m.cache.get spk).getD (expandDescriptorAt m spk)`, with `theorem getSigningProvider_cached (h : m.cache.get spk = some p) : getSigningProvider m spk = p` and the fresh-expansion branch. Absent.

### SGN2-005 — UNMODELLED / MODEL

- **Row summary:** private-key injection
- **Core anchor:** `src/wallet/scriptpubkeyman.cpp:1348` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** `include_private` is absent from the signing boundary and there is no private-key/`ExpandPrivate` injection. Obligation: add `include_private : Bool` and private material to the provider, then `theorem getSigningProvider_private (h : m.hasPrivate = true) : (getSigningProvider m spk true).keys = (getSigningProvider m spk false).keys ++ expandPrivateKeys m spk`, with the `ExpandPrivate` index link. Absent.

### SGN2-006 — UNMODELLED / MODEL

- **Row summary:** ECDSA default aliasing
- **Core anchor:** `src/script/sign.cpp:75` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `CreateSig`, no SIGHASH_DEFAULT aliasing and no SIGHASH_SINGLE output-index guard. Obligation: add `def createSig (v : EcdsaVersion) (ht : UInt32) (key : Nat) (tx : Tx) (k : Nat) : Option EcdsaSig` with `theorem createSig_default (h : ht = SIGHASH_DEFAULT) : v = .base ∨ v = .witnessV0 → (createSig v ht key tx k).map (·.hashType) = some SIGHASH_ALL` and `theorem createSig_single_none (h : tx.vout[k]? = none) : ht = SIGHASH_SINGLE → createSig .base ht key tx k = none`. `requestOf` has no defaulting.

### SGN2-007 — UNMODELLED / MODEL

- **Row summary:** ECDSA preconditions
- **Core anchor:** `src/script/sign.cpp:63` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No key-compression refusal or MoneyRange check in a `CreateSig` model; `SignerSpec` is ECDSA-shape only. Obligation: add the preconditions `theorem createSig_witness_uncompressed (h : key.size ≠ 33) : createSig .witnessV0 ht key tx k = none` and `theorem createSig_amount_range (h : ¬ (0 ≤ amount ∧ amount ≤ MAX_MONEY)) : createSig .witnessV0 ht key tx k = none`. Neither the amount nor the key encoding is an input to the current boundary.

### SGN2-008 — UNMODELLED / MODEL

- **Row summary:** Schnorr data requirements
- **Core anchor:** `src/script/sign.cpp:91` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No Schnorr signing model: precomputed BIP341 data, spent outputs, annex/OP_CODESEPARATOR exclusion and TAPSCRIPT leaf hashes are all absent. Obligation: add `structure TaprootData where precomputed : Option Bip341Data; spentOutputs : List TxOut; annex : Option ByteArray; codeseparator : Option Nat; leafHash : Option ByteArray` and `def createSchnorrSig (d : TaprootData) : Option ByteArray` with `theorem createSchnorrSig_none_without_precomputed (h : d.precomputed = none) : createSchnorrSig d = none`, the no-annex/no-codeseparator lemmas, and the tapscript leaf-hash requirement. Absent.

### SGN2-009 — UNMODELLED / MODEL

- **Row summary:** taproot key path order
- **Core anchor:** `src/script/sign.cpp:608` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `SignTaproot` and no internal-key-then-output-key fallback order. Obligation: add `def signTaproot (m : Manager) (tx : Tx) (internal output : ByteArray) (root : Option ByteArray) : Option ByteArray` with `theorem signTaproot_order (h : signTaproot m tx internal output root = some sig) : (keyPathSign m internal root = some sig) ∨ (keyPathSign m output none = some sig ∧ keyPathSign m internal root = none)`. Absent.

### SGN2-010 — UNMODELLED / MODEL

- **Row summary:** tapscript leaf version
- **Core anchor:** `src/script/sign.cpp:553` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `SignTaprootScript` or leaf-version / miniscript parsing gate. Obligation: add `def signTaprootScript (m : Manager) (leafVersion : Nat) (leaf : ByteArray) (tx : Tx) : Option ByteArray` with `theorem signTaprootScript_leafVersion (h : leafVersion ≠ TAPROOT_LEAF_TAPSCRIPT) : signTaprootScript m leafVersion leaf tx = none` (TAPROOT_LEAF_TAPSCRIPT = 0xc0) and a `parseMiniscript` gate on `leaf`. Absent.

### SGN2-012 — UNMODELLED / MODEL

- **Row summary:** tweaked keypair
- **Core anchor:** `src/key.cpp:415` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `KeyPair` construction and no x-only tweak-add for a non-null merkle root. Obligation: add `def keyPairTweaked (sk : Nat) (merkleRoot : Option ByteArray) : KeyPair` with `theorem keyPairTweaked_pubkey (h : merkleRoot = some r) : (keyPairTweaked sk (some r)).pubkey = tweakAddXonly (pubkeyOf sk) (tapTweakHash (pubkeyOf sk) r)`. `EcdsaSig` stores only `(r, s, hashType)`; no `KeyPair` or BIP341 tweak exists.

### SGN2-013 — UNMODELLED / MODEL

- **Row summary:** x-only key lookup
- **Core anchor:** `src/script/sign.cpp:111` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No x-only private-key lookup in a `CreateSchnorrSig` model. `SignerSpec.missingKeyRefuses` is about a numeric key label in an abstract oracle, not x-only bytes, so it is not a special case of this row. Obligation: add `def keyByXonly (ks : List KeyMaterial) (x : ByteArray) : Option KeyMaterial` with `theorem createSchnorrSig_none_of_absent_xonly (h : keyByXonly ks x = none) : createSchnorrSig ks x = none`.

### SGN2-014 — UNMODELLED / MODEL

- **Row summary:** sighash byte emission
- **Core anchor:** `src/script/sign.cpp:119` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No signature byte encoding or trailing sighash byte: `EcdsaSig` stores `hashType` mathematically and deliberately omits der/trailing bytes; there is no Schnorr wire form. Obligation: add `def schnorrWire (sig : ByteArray) (ht : Option UInt32) : ByteArray := sig ++ (match ht with | none => [] | some h => [h.toUInt8])` with `theorem schnorrWire_default_length (h : ht = none) : (schnorrWire sig ht).length = 64` and `theorem schnorrWire_explicit_length (h : ht = some h) : (schnorrWire sig ht).length = 65`. Absent.

## MS — Miniscript type, script emission, sanity and satisfaction

13 rows: 8 PARTIAL, 5 UNMODELLED; 6 MODEL, 7 PROOF.

### MS-001 — PARTIAL / PROOF

- **Row summary:** type bitmap
- **Core anchor:** `src/script/miniscript.h:167` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Miniscript.has_ofTy`
- **Obligation (PROOF, unproved):** `has_ofTy` proves only `(MSType.ofTy p).has q = (p == q)`. Missing: `theorem Ty.bit_lt_nineteen (p : Ty) : p.bit < 19`, `theorem Ty.bit_injective {p q : Ty} (h : p.bit = q.bit) : p = q`, and coverage `theorem Ty.bit_surjective (n : Nat) (h : n < 19) : ∃ p, p.bit = n`, enumerating B,V,K,W,z,o,n,d,u,e,f,s,m,x,g,h,i,j,k. `Ty.bit` is a definition and the bound/distinctness/coverage are decidable by cases, but no declaration states them.

### MS-019 — UNMODELLED / MODEL

- **Row summary:** andor type
- **Core anchor:** `src/script/miniscript.cpp:206` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** `andor` is not a constructor of `Bitcoin.Wallet.Miniscript.Node`, and `and_n` is absent for the same reason, so the B/K/V transfer and the d-only-from-third rule have no object. Obligation: add `| andor (x y z : Node)` (with `and_n x y := andor x y (.one)`) and its `calcType` case, then `theorem andor_type_d (ctx x y z) : (calcType ctx (.andor x y z)).has .d ↔ (calcType ctx z).has .d` and the B/K/V projection under `(calcType ctx x).has .B ∧ .has .d ∧ .has .u`. The current `calcType` has no andor branch.

### MS-024 — PARTIAL / PROOF

- **Row summary:** timelock and hash opcodes
- **Core anchor:** `src/script/miniscript.h:819` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Miniscript.toScript_older; BitcoinProofs.Wallet.Miniscript.toScript_after; BitcoinProofs.Wallet.Miniscript.toScript_hash`
- **Obligation (PROOF, unproved):** `toScript_older` and `toScript_after` are exact; `toScript_hash` proves only the `verify = false` arm (`OP_EQUAL`, 0x87). Missing: `theorem toScript_hash_verify (ctx h) : toScriptWith ctx true (.sha256 h) = op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xa8 ++ pushBytes h ++ op 0x88`, and the analogous statements for `hash256` (0xaa), `ripemd160` (0xa6) and `hash160` (0xa9). The definitional `if verify then 0x88 else 0x87` branch has no theorem; the row's verify-context direction is exactly the uncovered case.

### MS-025 — PARTIAL / PROOF

- **Row summary:** wrapper opcodes
- **Core anchor:** `src/script/miniscript.h:825` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Miniscript.toScript_wrapC_pkK; BitcoinProofs.Wallet.Miniscript.toScript_wrapC_pkH`
- **Obligation (PROOF, unproved):** Only `c:pk_k` and `c:pk_h` with `verify = false` are proved. Missing equations for the wrappers (all definitional in `toScriptWith`): `toScriptWith ctx false (.wrapA x) = op 0x6b ++ toScriptWith ctx false x ++ op 0x6c`; `wrapS = op 0x7c ++ toScriptWith ctx verify x`; `wrapD = op 0x76 ++ op 0x63 ++ toScriptWith ctx false x ++ op 0x68`; `wrapV x = toScriptWith ctx true x ++ (if (calcType ctx x).has .x then op 0x69 else [])`; `wrapJ = op 0x82 ++ op 0x92 ++ op 0x63 ++ toScriptWith ctx false x ++ op 0x68`; `wrapN = toScriptWith ctx false x ++ op 0x92`; and the `c:` verify arm `toScriptWith ctx true (.wrapC x) = toScriptWith ctx true x ++ op 0xad` (0xac when false). The row's a/s/d/v/j/n emissions and the 0xad arm are precisely what is unstated.

### MS-026 — PARTIAL / MODEL

- **Row summary:** combinator opcodes
- **Core anchor:** `src/script/miniscript.h:840` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Miniscript.toScriptWith`
- **Obligation (MODEL, unproved):** The six non-andor clauses are definitional in `toScriptWith`, but no theorem states them; `andor` has no `Node` constructor, so its `OP_NOTIF`/`OP_ELSE` clause cannot be stated at all. Obligation: (i) add the `andor` constructor (see MS-019) with `toScriptWith ctx v (.andor x y z) = toScriptWith ctx false x ++ op 0x64 ++ toScriptWith ctx false y ++ op 0x67 ++ toScriptWith ctx false z ++ op 0x68`; (ii) state equations for `and_v` (concatenation, verify on the second operand), `and_b` (+0x9a), `or_b` (+0x9b), `or_d` (0x73 0x64 ... 0x68), `or_c` (0x64 ... 0x68) and `or_i` (0x63 ... 0x67 ... 0x68). The row includes the absent andor, hence MODEL; the six definitional equations are a PROOF sub-obligation.

### MS-027 — PARTIAL / PROOF

- **Row summary:** multisig encodings
- **Core anchor:** `src/script/miniscript.h:847` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Miniscript.toScriptWith`
- **Obligation (PROOF, unproved):** Both encodings are definitional in `toScriptWith`; no theorem states either. Missing: `theorem toScript_multi (ctx v k keys) : toScriptWith ctx v (.multi k keys) = pushInt k ++ concatScripts (keys.map pushBytes) ++ pushInt keys.length ++ (if v then op 0xaf else op 0xae)` and `theorem toScript_multiA (ctx v k keys) : toScriptWith ctx v (.multiA k keys) = multiAKeyScript keys ++ pushInt k ++ (if v then op 0x9d else op 0x9c)`, under the parser guard `k ≤ keys.length` (the model itself does not reject k > n).

### MS-028 — PARTIAL / PROOF

- **Row summary:** threshold opcodes
- **Core anchor:** `src/script/miniscript.h:863` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Miniscript.toScriptWith`
- **Obligation (PROOF, unproved):** The `thresh` equation is definitional in `toScriptWith` and unstated. Obligation: `theorem toScript_thresh (ctx v k xs) : toScriptWith ctx v (.thresh k xs) = intersperseAdd (xs.map (toScriptWith ctx false)) ++ pushInt k ++ (if v then op 0x88 else op 0x87)`, plus the `k ≤ xs.length` parse guard, which the model does not enforce. `intersperseAdd` is exact but has no theorem.

### MS-029 — PARTIAL / PROOF

- **Row summary:** validity
- **Core anchor:** `src/script/miniscript.h:1675` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Miniscript.isValid`
- **Obligation (PROOF, unproved):** `isValid` is a definition; the row's iff holds only by unfolding and no theorem states it. Obligation: `theorem isValid_iff (ctx : MiniscriptContext) (n : Node) : isValid ctx n = true ↔ calcType ctx n ≠ MSType.empty ∧ (toScript ctx n).size ≤ maxScriptSize ctx`, proved in both directions including the `&&` short-circuit (empty type makes the size conjunct irrelevant). `oblig_MS_029` is an unproved Prop.

### MS-030 — PARTIAL / PROOF

- **Row summary:** sanity
- **Core anchor:** `src/script/miniscript.h:1702` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Miniscript.isSane`
- **Obligation (PROOF, unproved):** `isSane` is `(subexpressionReasons ++ topLevelReasons).isEmpty`, and `topLevelReasons` folds `IsValidTopLevel` and `NeedsSignature` into one list; no separate predicates are exposed, so the three-way iff is unstated. Obligation: define `def IsValidTopLevel (ctx n) : Prop := (calcType ctx n).Sub (ty [.B])` and `def NeedsSignature (ctx n) : Prop := (calcType ctx n).has .s`, then `theorem isSane_iff (ctx n) : isSane ctx n = true ↔ IsValidTopLevel ctx n ∧ isSaneSubexpression ctx n ∧ NeedsSignature ctx n`, using the append/emptiness decomposition. The row's three conjuncts are currently merged.

### MS-031 — UNMODELLED / MODEL

- **Row summary:** operation limit
- **Core anchor:** `src/script/miniscript.h:1573` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `Ops`/`GetStaticOps`/`GetOps` or `CheckOpsLimit` in `Miniscript.Satisfy`; neither the P2WSH ≤ 201 bound nor unconditional tapscript acceptance exists. Obligation: add `def maxOps : Node → Nat` and `def checkOpsLimit (ctx : MiniscriptContext) (n : Node) : Bool := ctx = .tapscript ∨ maxOps n ≤ 201`, with `theorem checkOpsLimit_p2wsh (h : maxOps n ≤ 201) : checkOpsLimit .p2wsh n = true` and `theorem checkOpsLimit_p2wsh_reject (h : 201 < maxOps n) : checkOpsLimit .p2wsh n = false`. Core's nullopt-acceptance branch (ops absent) is not represented and should be stated or explicitly excluded.

### MS-032 — UNMODELLED / MODEL

- **Row summary:** stack limit
- **Core anchor:** `src/script/miniscript.h:1595` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `GetStackSize`/`GetExecStackSize`/`CheckStackSize`; neither MAX_STACK_SIZE (1000) nor MAX_STANDARD_P2WSH_STACK_ITEMS (100) is modelled. Obligation: add `def maxStackSize : Node → Nat` and `def checkStackSize (ctx n) : Bool := maxStackSize n ≤ (if ctx = .tapscript then 1000 else 100)`, with `theorem checkStackSize_reject (h : 1000 < maxStackSize n) : checkStackSize .tapscript n = false` and the P2WSH 100-item bound. The P2WSH bound is standardness policy; the row's object is absent.

### MS-033 — UNMODELLED / MODEL

- **Row summary:** non-malleable satisfaction
- **Core anchor:** `src/script/miniscript.h:1709` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** The satisfaction model has no malleable/has_sig flag and no nonmalleable parameter; `satisfy`/`propose` return the first viable branch, and the result is only `Option WitnessStack × Option WitnessStack`. Obligation: add `structure SatResult where stack : WitnessStack; malleable : Bool; hasSig : Bool` and a `nonmalleable : Bool` parameter, then `theorem satisfy_none_of_nonmalleable (h : r.malleable = true ∨ r.hasSig = false) : satisfy sf n true = none`. Core's NO-on-malleable-or-no-signature gate cannot be stated now.

### MS-035 — UNMODELLED / MODEL

- **Row summary:** context-sensitive parsing
- **Core anchor:** `src/script/miniscript.h:1880` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No Miniscript `FromString` parser; no context-sensitive `multi`/`multi_a` acceptance and no MAX_PUBKEYS (20 P2WSH / 999 tapscript) or `k ≤ n` check. Obligation: add `def parseMiniscript (ctx : MiniscriptContext) (s : String) : Except ParseError Node` with `theorem parse_multiA_tapscript_only : parseMiniscript .p2wsh s = .error _` for a `multi_a` text, `theorem parse_multi_p2wsh_only : parseMiniscript .tapscript s = .error _` for `multi`, and `theorem parse_key_count (h : n > maxPubkeys ctx) : parseMiniscript ctx s = .error _` plus the `k ≤ n` check. The parser object is absent, not merely unproved.

## PSBT — v0 decoding, canonicality, lifecycle and (absent) v2

20 rows: 10 PARTIAL, 10 UNMODELLED; 18 MODEL, 2 PROOF.

### PSBT-002 — PARTIAL / PROOF

- **Row summary:** length-prefixed records
- **Core anchor:** `src/psbt.h:1372` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Psbt.decKV_is_length_prefixed`
- **Obligation (PROOF, unproved):** `decKV_is_length_prefixed` gives only the successful shape: `l = encCSL key.size ++ key ++ encCSL value.size ++ value ++ rest`. Missing: (i) rejection when a stated length disagrees with the decoded fields, `theorem decKV_length_mismatch (h : ...) : decKV l = .error .invalidLength`; (ii) the truncation characterisation `decBytesP n l = .error _ ↔ l.length < n`; (iii) the map-level composition that a record boundary consumes exactly the stated bytes. The row's second conjunct (rejection) is entirely uncovered; the current theorem is one-directional.

### PSBT-003 — PARTIAL / PROOF

- **Row summary:** duplicate keys
- **Core anchor:** `src/psbt.h:1382` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Psbt.decMapChecked_rejects_duplicate`
- **Obligation (PROOF, unproved):** `decMapChecked_rejects_duplicate` requires `decMapL = .ok` and `checkKeyEncoding = .ok`, so an identical raw key that is also badly encoded is rejected as `badKeyEncoding`, not `duplicateKey`; Core tests the duplicate set before parsing key types (`psbt.h:1382` vs `:1389`). Obligation: `theorem decMapChecked_duplicate_first (kvs l k) (h : findDuplicate kvs = some k) : decMapChecked l = .error (.duplicateKey k)` independently of key encoding, and show the current conjunction cannot produce that classification. `decMapChecked_no_duplicate` (Invariants.lean:119) gives only unconditional non-acceptance, not the error class.

### PSBT-008 — UNMODELLED / MODEL

- **Row summary:** v2 required globals
- **Core anchor:** `src/psbt.h:1544` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** The v2 branch is absent: `checkGlobalVersion` rejects every non-zero version as unsupported, while the row requires TX_VERSION (0x02), INPUT_COUNT (0x04) and OUTPUT_COUNT (0x05), and rejection of GLOBAL_UNSIGNED_TX (0x00) only in v2. Obligation: add v2 global fields and `theorem checkGlobalVersion_v2 (h : v = 2) : hasGlobal kvs GLOBAL_TX_VERSION ∧ hasGlobal kvs GLOBAL_INPUT_COUNT ∧ hasGlobal kvs GLOBAL_OUTPUT_COUNT → checkGlobalVersion kvs = .ok`, plus `theorem checkGlobalV2_rejects_unsignedTx (h : hasGlobal kvs GLOBAL_UNSIGNED_TX) : checkGlobalVersion kvs = .error _`. Rejecting v2 wholesale is not the row's semantics; v2 is explicitly excluded from `Model.lean`.

### PSBT-009 — PARTIAL / MODEL

- **Row summary:** global xpub record
- **Core anchor:** `src/psbt.h:1458` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Psbt.parseGlobal`
- **Obligation (MODEL, unproved):** `parseGlobal` enforces only the fixed 78-byte xpub key data (`d.size = 78`); `XpubEntry` keeps the xpub opaque, so Core's `CPubKey::IsFullyValid` on the embedded 33-byte key (`psbt.h:1454-1459`) has no model link. Obligation: retain `xpubPubkey : ByteArray` (or decode the payload) and prove `theorem parseGlobal_xpub_valid (h : parseGlobal kvs = .ok g) : ∀ e ∈ g.xpubs, compressedKeyValid e.pubkey = true`. `compressedKeyValid` exists in `Descriptor.Parse` but is not connected to `XpubEntry`; the definitional length check alone cannot entail the row.

### PSBT-012 — PARTIAL / MODEL

- **Row summary:** finalisation suppresses partial data
- **Core anchor:** `src/psbt.h:371` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Psbt.finalizeInput_hasSigningData_false`
- **Obligation (MODEL, unproved):** `finalizeInput` suppresses some signing fields, but the four preimage maps (0x0A-0x0D) are neither cleared nor counted by `hasSigningData`, so they are still serialized after finalisation; `finalizeInput_hasSigningData_false` is also unconditional on the final scripts. Obligation: add the preimage maps to the suppression predicate and prove `theorem finalizeInput_preimages (h : inputSigned (finalizeInput i ss ws) = true) : (finalizeInput i ss ws).ripemd160Preimages = [] ∧ (finalizeInput i ss ws).sha256Preimages = [] ∧ (finalizeInput i ss ws).hash160Preimages = [] ∧ (finalizeInput i ss ws).hash256Preimages = []`, plus the guard `(finalScriptSig ≠ "" ∨ finalScriptWitness ≠ null) → hasSigningData = false`. The theorem currently covers partial sigs, sighash, redeem/witness scripts, key paths and taproot fields only.

### PSBT-014 — PARTIAL / MODEL

- **Row summary:** taproot key signature
- **Core anchor:** `src/psbt.h:787` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Psbt.parseInput`
- **Obligation (MODEL, unproved):** `parseInput` enforces 64 or 65 bytes on read, but `inputKVs` emits `tapKeySig` under 0x13 at any size and `Canonical` does not constrain it; no theorem joins read and write. Obligation: add `def tapKeySigWellFormed (b : ByteArray) : Prop := b.size = 64 ∨ b.size = 65` and prove both directions, `theorem parseInput_tapKeySig_size (h : parseInput kvs = .ok i) (hb : i.tapKeySig = some b) : tapKeySigWellFormed b` and `theorem inputKVs_tapKeySig_size (h : tapKeySigWellFormed b) : ...`; the write-side guard must first be added to `inputKVs`. A constructed 32-byte value is currently serializable.

### PSBT-015 — PARTIAL / MODEL

- **Row summary:** taproot script signature
- **Core anchor:** `src/psbt.h:432` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Psbt.parseInput`
- **Obligation (MODEL, unproved):** `parseInput` splits a 64-byte 0x14 key into 32+32, but `TapScriptSigEntry` carries no component-size invariant and `inputKVs` concatenates `e.xonly ++ e.leafHash` at whatever sizes are stored. Obligation: add the invariant `def tapScriptSigKeyOK (e) : Prop := e.xonly.size = 32 ∧ e.leafHash.size = 32` and prove `theorem parseInput_tapScriptSig_key (h : parseInput kvs = .ok i) : ∀ e ∈ i.tapScriptSigs, tapScriptSigKeyOK e` and the write direction `tapScriptSigKeyOK e → (inputKVs i).keyFor 0x14 e = e.xonly ++ e.leafHash ∧ (e.xonly ++ e.leafHash).size = 64`. The structure currently permits arbitrary sizes.

### PSBT-017 — PARTIAL / MODEL

- **Row summary:** taproot bip32 derivation
- **Core anchor:** `src/psbt.h:450` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Psbt.parseInput`
- **Obligation (MODEL, unproved):** `parseInput` enforces a 32-byte 0x16 key, but `TapBip32Entry` has no 32-byte invariant and `inputKVs` emits `e.xonly` and `encTapBip32Value` without a size check. Obligation: add `theorem parseInput_tapBip32_key (h : parseInput kvs = .ok i) : ∀ e ∈ i.tapBip32Derivation, e.xonly.size = 32` and the write-side `theorem inputKVs_tapBip32_key_size`; the value structure (leaf-hash set followed by key origin) already matches `encTapBip32Value`, so only the key-size guarantee is missing. No theorem ties read and write.

### PSBT-018 — PARTIAL / MODEL

- **Row summary:** taproot output tree
- **Core anchor:** `src/psbt.h:1162` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Psbt.parseTapTree`
- **Obligation (MODEL, unproved):** `parseTapTree` implements only empty-value rejection. Depth ≤ TAPROOT_CONTROL_MAX_NODE_COUNT (128), `(leafVersion &&& ~~~TAPROOT_LEAF_MASK) = 0`, and `TaprootBuilder.IsComplete` are absent. Obligation: add a `TapTree` builder object with `theorem parseTapTree_depth (h : parseTapTree v = .ok t) : ∀ leaf ∈ t, leaf.depth ≤ 128`, `theorem parseTapTree_leafVersion (h : ...) : leaf.version &&& ~~~TAPROOT_LEAF_MASK = 0`, and a completeness predicate with its rejection branch. `oblig_PSBT_018` (Obligations.lean:914) is unproved and states only non-empty value/non-empty tree.

### PSBT-020 — UNMODELLED / MODEL

- **Row summary:** witness-only signing safety
- **Core anchor:** `src/psbt.cpp:733` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `SignPSBTInput` and no `require_witness_sig`. `spentOutput` can select a witness UTXO, but nothing requires the produced signature data to be a witness signature or fails with INCOMPLETE. Obligation: add `def signPsbtInput (p : Psbt) (k : Nat) (keys : List KeyMaterial) (finalize : Bool) : Except SignError Unit` with `theorem signPsbtInput_witness_only (h : p.inputs[k]?.nonWitnessUtxo = none) (hwu : p.inputs[k]?.witnessUtxo = some _) (hns : ¬ IsWitnessSignature sig) : signPsbtInput p k keys finalize = .error .incomplete`. Signing policy is explicitly outside the model.

### PSBT-021 — UNMODELLED / MODEL

- **Row summary:** default sighash
- **Core anchor:** `src/psbt.cpp:690` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No sighash default: `requestOf` is defined only when `p.inputs[k].sighashType` is explicit (`inputSighashType` returns `none` rather than a default). Obligation: add `def effectiveSighash (p : Psbt) (k : Nat) : UInt32 := (inputSighashType p k).getD (if isTaprootPrevout p k then SIGHASH_DEFAULT else SIGHASH_ALL)` and `theorem effectiveSighash_default (h : inputSighashType p k = none) : effectiveSighash p k = (if isTaprootPrevout p k then SIGHASH_DEFAULT else SIGHASH_ALL)`, plus the caller-vs-input mismatch rejection when both are present and differ. The default selection and mismatch branch are absent.

### PSBT-022 — UNMODELLED / MODEL

- **Row summary:** existing signature sighash agreement
- **Core anchor:** `src/psbt.cpp:713` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No agreement check over existing `tapKeySig`, `tapScriptSigs` or ECDSA `partialSigs`; `parseInput` enforces only 64/65 sizes and never compares the 65th byte (or an ECDSA signature's last byte) with the selected sighash type. Obligation: add `def sighashAgrees (sig : ByteArray) (ht : UInt32) : Bool := sig.size = 65 ∧ sig.getLast! = ht.toUInt8` and `theorem signPsbtInput_sighash_mismatch (h : ht ≠ SIGHASH_DEFAULT) (hbad : ¬ sighashAgrees sig ht) : signPsbtInput p k keys finalize = .error .sighashMismatch`, for tap key sigs, tap script sigs and ECDSA partial sigs.

### PSBT-023 — UNMODELLED / MODEL

- **Row summary:** merge identity
- **Core anchor:** `src/psbt.cpp:42` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `PartiallySignedTransaction::Merge`, no `GetUniqueID`, and no same-unique-txid / same-version precondition. Obligation: add `def uniqueId (p : Psbt) : ByteArray` (hash of the unsigned transaction) and `def merge (a b : Psbt) : Option Psbt` with `theorem merge_some_iff : merge a b = some c ↔ uniqueId a = uniqueId b ∧ a.global.version = b.global.version`. Absent.

### PSBT-024 — UNMODELLED / MODEL

- **Row summary:** merge field precedence
- **Core anchor:** `src/psbt.cpp:420` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `PSBTInput::Merge`: no existing-non-empty precedence, empty-field fill, or distinct-key map union. Obligation: add `def mergeInput (a b : PsbtInput) : PsbtInput` with `theorem mergeInput_precedence (h : a.partialSigs ≠ []) : (mergeInput a b).partialSigs = a.partialSigs`, `theorem mergeInput_fill (h : a.redeemScript = none) : (mergeInput a b).redeemScript = b.redeemScript`, and the union lemma for `unknown` under disjoint keys. Absent.

### PSBT-025 — UNMODELLED / MODEL

- **Row summary:** duplicate input rejection
- **Core anchor:** `src/psbt.cpp:169` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `AddInput`: `checkUtxos` validates a non-witness UTXO's hash/index against the unsigned transaction but does not detect duplicate prevouts among inputs. Obligation: add `def addInput (p : Psbt) (i : PsbtInput) : Except PsbtError Psbt` with `theorem addInput_duplicate_prevout (h : ∃ j < p.inputs.length, p.global.unsignedTx.vin[j].prevout = i.prevout) : addInput p i = .error (.duplicateInput i.prevout)` and the success branch appending exactly one input. Absent.

### PSBT-026 — UNMODELLED / MODEL

- **Row summary:** v2 locktime computation
- **Core anchor:** `src/psbt.cpp:92` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** PSBT v2 is excluded: no `time_locktime`/`height_locktime`, no `ComputeTimeLock`, no height/time aggregation and no nullopt-on-mix. Obligation: add input locktime fields and `def computeTimeLock (ins : List PsbtInput) : Option UInt32` with `theorem computeTimeLock_height (h : ∀ i ∈ ins, i.heightLocktime = some h) : computeTimeLock ins = some (maxHeight ins)`, the time analogue, and `theorem computeTimeLock_mix (h : ∃ i j, i.heightLocktime = some _ ∧ j.timeLocktime = some _) : computeTimeLock ins = none`. Absent.

### PSBT-027 — UNMODELLED / MODEL

- **Row summary:** unsigned transaction reconstruction
- **Core anchor:** `src/psbt.cpp:134` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** PSBT v2 is excluded: no `GetUnsignedTx`, no SEQUENCE_FINAL fill (`fillTxIn` preserves `ti.sequence`), and no `ComputeTimeLock` failure branch. Obligation: add `def getUnsignedTx (p : Psbt) : Option Tx` with `theorem getUnsignedTx_sequence_final (h : p.inputs[k].sequence = none) : (getUnsignedTx p).get!.vin[k].sequence = SEQUENCE_FINAL` and `theorem getUnsignedTx_none_of_locktime_mix (h : computeTimeLock p.inputs = none) : getUnsignedTx p = none`. Absent.

### PSBT-028 — UNMODELLED / MODEL

- **Row summary:** finalisation
- **Core anchor:** `src/psbt.cpp:811` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `FinalizePSBT`: `finalizeInput` is a per-input data operation, with no no-key `SignPSBTInput(..., finalize=true)` call over every input, no all-input loop and no boolean success result. Obligation: add `def finalizePsbt (p : Psbt) : Bool` with `theorem finalizePsbt_true_iff (h : finalizePsbt p = true) : ∀ k < p.inputs.length, ∃ i, finalizeInput p.inputs[k] ... = some i ∧ inputSigned i` and the false branch. Absent.

### PSBT-029 — PARTIAL / MODEL

- **Row summary:** extraction
- **Core anchor:** `src/psbt.cpp:832` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Psbt.extract_some`
- **Obligation (MODEL, unproved):** `extract_some` requires `allInputsSigned p = true`, i.e. the already-finalised special case; Core may create final scripts from partial signatures via FinalizePSBT. Also missing: the `GetUnsignedTx` failure branch. Obligation: add `def finalizeAndExtract (p : Psbt) : Option Tx` with `theorem finalizeAndExtract_some (h : finalizePsbt p = true) : ∃ tx, finalizeAndExtract p = some tx ∧ tx.vin[k].scriptSig = (finalizeInput ...).finalScriptSig` and the `extract_none` propagation. The FinalizePSBT step and the v2 unsigned-tx reconstruction are absent.

### PSBT-030 — PARTIAL / MODEL

- **Row summary:** signed-and-verified predicate
- **Core anchor:** `src/psbt.cpp:580` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Psbt.checkUtxos`
- **Obligation (MODEL, unproved):** `checkUtxos` covers only the decode-time non-witness-UTXO hash/index validation. There is no `PSBTInputSignedAndVerified` predicate, no signedness test, no `VerifyScript` call on the reconstructed transaction, and no STANDARD_SCRIPT_VERIFY_FLAGS bridge. Obligation: add `def inputSignedAndVerified (p : Psbt) (k : Nat) : Bool := checkUtxos p.global.unsignedTx k p.inputs = .ok () && verifyScript standardFlags (getUnsignedTx p) k ...` with `theorem inputSignedAndVerified_sound (h : inputSignedAndVerified p k = true) : checkUtxos p.global.unsignedTx k p.inputs = .ok () ∧ verifyScript standardFlags (getUnsignedTx p) k ... = true`. `spentOutput` additionally covers the witness-UTXO branch, but no verification exists.

## WSP — coin selection, funding, fee and transaction assembly

30 rows: 6 PARTIAL, 24 UNMODELLED; 29 MODEL, 1 PROOF.

### WSP-001 — UNMODELLED / MODEL

- **Row summary:** spent outputs excluded
- **Core anchor:** `src/wallet/spend.cpp:437` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `AvailableCoins`, `COutPoint` or `IsSpent` predicate; coins are bare `Amount`s in `Spend/Selection.lean`. Obligation: add `structure Coin where outpoint : OutPoint; value : Amount; txid : ByteArray` and `def availableCoins (w : Wallet) : List Coin := w.coins.filter (fun c => !w.isSpent c.outpoint)`, with `theorem availableCoins_not_spent (h : w.isSpent o = true) : o ∉ (availableCoins w).map (·.outpoint)`. The spent-set filter cannot be stated over the current type.

### WSP-002 — UNMODELLED / MODEL

- **Row summary:** unsafe outputs excluded
- **Core anchor:** `src/wallet/spend.cpp:412` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No trust/safe classification, `only_safe`, or `include_unsafe_inputs` flag; no wallet transaction or trust object exists. Obligation: add `def isTrusted (w : Wallet) (txid : ByteArray) : Bool`, `def isSafe (w : Wallet) (txid : ByteArray) : Bool`, and `def availableCoins (w : Wallet) (includeUnsafe : Bool) : List Coin := w.coins.filter (fun c => includeUnsafe ∨ isTrusted w c.txid)`, with `theorem availableCoins_safe (h : includeUnsafe = false) : c ∈ availableCoins w false → isTrusted w c.txid = true`. Core sets `only_safe = !include_unsafe_inputs` and applies it after `CachedTxIsTrusted` (`spend.cpp:332,412`).

### WSP-004 — UNMODELLED / MODEL

- **Row summary:** positive-value groups
- **Core anchor:** `src/wallet/spend.cpp:643` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No positive-only output group; `effectiveValue` exists but there is no group or filter declaration. Obligation: add `def positiveGroups (r : FeeRate) (coins : List Coin) : List Coin := coins.filter (fun c => 0 < effectiveValue r c.vsize c.value)`, with `theorem positiveGroups_mem_iff (c) : c ∈ positiveGroups r coins ↔ c ∈ coins ∧ 0 < effectiveValue r c.vsize c.value`. Core inserts into `spk_to_positive_groups_map` only when `GetEffectiveValue() > 0` (`spend.cpp:641-645`); no declaration states the group or its membership.

### WSP-005 — UNMODELLED / MODEL

- **Row summary:** BnB target window
- **Core anchor:** `src/wallet/coinselection.cpp:189` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `SelectCoinsBnB`, `selection_target`, `cost_of_change` window, or cut/shift branches. Obligation: add `def bnbWindow (target costOfChange : Amount) (s : Selection) : Prop := target ≤ s.total ∧ s.total ≤ target + costOfChange` and a `selectCoinsBnB` function with `theorem bnb_solution_window (h : selectCoinsBnB ... = some s) : bnbWindow ... s`. Note the row is imprecise against `cce32b168`: lookahead CUT and weight SHIFT are tested before the window (`coinselection.cpp:181-188`), so an 'exactly when' statement would be false of Core.

### WSP-006 — UNMODELLED / MODEL

- **Row summary:** BnB search cap
- **Core anchor:** `src/wallet/coinselection.cpp:213` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No BnB try counter, TOTAL_TRIES, or AlgoCompleted flag. Obligation: add `structure BnbResult where selection : Option Selection; tries : Nat; algoCompleted : Bool` and a `selectCoinsBnB` returning it, with `theorem bnb_tries_bound : bnbResult.tries ≤ 100000` and `theorem bnb_algoCompleted_false_of_cap (h : bnbResult.tries = 100000) : bnbResult.algoCompleted = false`. BnB is explicitly not modelled (`Spend/Selection.lean:10-12`).

### WSP-007 — UNMODELLED / MODEL

- **Row summary:** BnB weight pruning
- **Core anchor:** `src/wallet/coinselection.cpp:185` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No BnB weight guard or `max_selection_weight`. Obligation: add `def bnbWeightOk (maxW : Nat) (s : Selection) : Bool := s.weight ≤ maxW` and `theorem bnb_shift_of_overweight (h : s.weight > maxW) : nextSelection = shift s`. Note the row is imprecise: an insufficient-lookahead CUT precedes the weight SHIFT (`coinselection.cpp:182-188`), so not every over-weight partial selection is shifted.

### WSP-008 — UNMODELLED / MODEL

- **Row summary:** SRD change padding
- **Core anchor:** `src/wallet/coinselection.cpp:620` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `SelectCoinsSRD` and no `target += CHANGE_LOWER + change_fee`. Obligation: add `def srdTarget (target changeLower changeFee : Amount) : Amount := target + changeLower + changeFee` and `def selectCoinsSRD (target : Amount) (coins : List Coin) : Option Selection`, with `theorem selectCoinsSRD_target (h : selectCoinsSRD target coins = some s) : target + CHANGE_LOWER + changeFee ≤ s.total`. SRD is explicitly not modelled.

### WSP-009 — UNMODELLED / MODEL

- **Row summary:** SRD weight trimming
- **Core anchor:** `src/wallet/coinselection.cpp:641` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No SRD heap, least-valuable removal loop, or `max_selection_weight` trim. Obligation: add `def srdTrim (maxW : Nat) (sel : List Coin) : List Coin` with `theorem srdTrim_weight (h : sel ≠ []) : (srdTrim maxW sel).weight ≤ maxW ∨ srdTrim maxW sel = []`, plus the removal step `theorem srdTrim_step (h : ¬ weightFits maxW sel) : srdTrim maxW sel = srdTrim maxW (removeLeastValuable sel)`. No `OutputGroup`, heap, or weight model exists.

### WSP-010 — UNMODELLED / MODEL

- **Row summary:** Knapsack exact match
- **Core anchor:** `src/wallet/coinselection.cpp:746` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `KnapsackSolver` exact-match fast path. Obligation: add `def knapsack (target maxW : Nat) (groups : List Coin) : Option Selection` with `theorem knapsack_exact (h : ∃ g ∈ groups, g.value = target ∧ g.weight ≤ maxW) : knapsack target maxW groups = some [g]` (first such group). `smallestFit`/`firstCover` is a different strategy and has no equality-to-target branch.

### WSP-011 — UNMODELLED / MODEL

- **Row summary:** Knapsack larger-coin fallback
- **Core anchor:** `src/wallet/coinselection.cpp:768` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `KnapsackSolver` lowest_larger fallback. Obligation: add `def lowestLarger (target changeTarget : Amount) (groups : List Coin) : Option Coin` with `theorem lowestLarger_spec (h : lowestLarger target ct gs = some g) : target + ct ≤ g.value ∧ ∀ g' ∈ gs, target + ct ≤ g'.value → g.value ≤ g'.value`. The row's fallback is the smallest weight-fitting group at/above `target + change_target`, not merely above `target`, so the row text is also imprecise.

### WSP-012 — UNMODELLED / MODEL

- **Row summary:** Knapsack approximation
- **Core anchor:** `src/wallet/coinselection.cpp:707` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `ApproximateBestSubset` or randomised passes. Obligation: add `def approximateBestSubset (seed : Nat) (target : Amount) (groups : List Coin) : Selection` with `theorem abs_passes_bound : passes ≤ 1000` and a best-waste invariant `theorem abs_best_waste ...`. The row is false as written: Core keeps the best waste over at most 1000 passes seeded with the all-groups total, not the smallest reachable total (`coinselection.cpp:676-724`); no declaration states either.

### WSP-013 — UNMODELLED / MODEL

- **Row summary:** change target bounds
- **Core anchor:** `src/wallet/coinselection.cpp:885` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `GenerateChangeTarget`, CHANGE_LOWER/CHANGE_UPPER, or uniform range. Obligation: add `def generateChangeTarget (payment changeFee : Amount) (rand : Nat) : Amount` with `theorem generateChangeTarget_low (h : payment ≤ CHANGE_LOWER / 2) : generateChangeTarget payment cf r = cf + CHANGE_LOWER` and `theorem generateChangeTarget_range (h : CHANGE_LOWER / 2 < payment) : cf + CHANGE_LOWER ≤ generateChangeTarget payment cf r ∧ generateChangeTarget payment cf r < cf + min (2*payment) CHANGE_UPPER`. Change-target randomisation is explicitly not modelled.

### WSP-014 — PARTIAL / MODEL

- **Row summary:** change threshold
- **Core anchor:** `src/wallet/coinselection.cpp:1055` at `cce32b168`
- **Existing declaration:** `BitcoinProofs.Wallet.Spend.fundWithChange_change_eq_some_iff_ge`
- **Obligation (MODEL, unproved):** `fundWithChange_change_eq_some_iff_ge` proves the threshold for `fundWithChange`'s residual, but the row is `SelectionResult::GetChange`: the `m_use_effective`/effective-value branch and the `change_fee` subtraction are absent, and the model returns `Option none` where Core returns `CAmount 0`. Obligation: add `def getChange (s : Selection) (fee minViable : Amount) (useEffective : Bool) : Amount := if change s fee useEffective < minViable then 0 else change s fee useEffective` with `theorem getChange_eq_zero_iff : getChange s fee minViable ue = 0 ↔ change s fee ue < minViable` and `theorem getChange_eq_change_of_ge`. The existing theorem is the same threshold law on a different function and result type.

### WSP-015 — UNMODELLED / MODEL

- **Row summary:** waste metric
- **Core anchor:** `src/wallet/coinselection.cpp:910` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No waste metric, bump-fee discount, `change_cost`, or excess term. Obligation: add `def waste (sel : Selection) (longTermFee : FeeRate) (changeCost excess : Amount) (bumpDiscount : Amount) : Amount := (sel.coins.map (fun c => c.fee - longTermFee.getFee c.vsize)).sum - bumpDiscount + (if sel.hasChange then changeCost else excess)` with `theorem waste_eq : waste sel ltf cc ex bd = ...` and the no-change/change case split. No waste field or theorem exists; RecalculateWaste is unmodelled (`coinselection.cpp:901-927`).

### WSP-016 — UNMODELLED / MODEL

- **Row summary:** algorithm portfolio
- **Core anchor:** `src/wallet/spend.cpp:766` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `ChooseSelectionResult` portfolio or algorithm gating; `SelectionAlgorithm` has only `largestFirst` and `smallestFit`, with no BNB/SRD/CG/KNAPSACK constructors. Obligation: add the four constructors and `def chooseSelectionResult (sffo : Bool) (effective longTerm : FeeRate) (results : List Selection) : Option Selection` with `theorem chooseSelectionResult_gating (h : sffo = false ∧ 3 * longTerm < effective) : .coinGrinder ∈ algorithms` and the selection-by-waste rule. `spend.cpp:747-777` is unmodelled.

### WSP-017 — UNMODELLED / MODEL

- **Row summary:** selection weight budget
- **Core anchor:** `src/wallet/spend.cpp:742` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `max_selection_weight` arithmetic (MAX_STANDARD_TX_WEIGHT minus header/recipient weight minus change-output weight). `estimatedWeight`/`VsizeInputs` only sum an explicit estimate; there is no weight budget or limit. Obligation: add `def maxSelectionWeight (headerWeight recipientsWeight changeWeight : Nat) : Nat := 400000 - headerWeight - recipientsWeight - changeWeight` with `theorem estimatedWeight_le_maxSelectionWeight (h : ...) : estimatedWeight v ≤ maxSelectionWeight hw rw cw`; `spend.cpp:739-759` has no counterpart.

### WSP-018 — UNMODELLED / MODEL

- **Row summary:** SFFO skips BnB
- **Core anchor:** `src/wallet/spend.cpp:748` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No SFFO algorithm gating and no skip-BnB branch. Obligation: add `def algorithmsFor (sffo : Bool) : List SelectionAlgorithm := if sffo then [.knapsack, .srd] else [.bnb, .knapsack, .srd]` with `theorem algorithmsFor_sffo (h : sffo = true) : .bnb ∉ algorithmsFor sffo` and the change-creating-start ordering. `spend.cpp:747-752` is absent.

### WSP-019 — UNMODELLED / MODEL

- **Row summary:** recipient dust rejection
- **Core anchor:** `src/wallet/spend.cpp:1094` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `CreateTransaction` recipient dust precheck; `isDust` is defined (`Fee.lean:162`) but there is no rejection declaration. Obligation: add `theorem createTransaction_none_of_recipient_dust (h : isDust relayDust (txoutSize out) out.witnessProgram = true) : createTransaction ... = none`, applied before selection as at `spend.cpp:1093-1096`. The predicate exists; the precheck and abort do not.

### WSP-020 — UNMODELLED / MODEL

- **Row summary:** selection target
- **Core anchor:** `src/wallet/spend.cpp:1197` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `selection_target = recipients_sum + not_input_fees` and no SFFO zero-fee special case; funding takes the fee as an explicit parameter (`Funding.lean:15,35`). Obligation: add `def selectionTarget (recipientsSum notInputFees : Amount) (sffo : Bool) : Amount := recipientsSum + (if sffo then 0 else notInputFees)` with `theorem selectionTarget_eq (h : sffo = false) : selectionTarget rs nif sffo = rs + nif` and the SFFO branch. `spend.cpp:1195-1197` is unmodelled.

### WSP-021 — PARTIAL / PROOF

- **Row summary:** minimum viable change
- **Core anchor:** `src/wallet/spend.cpp:1193` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Spend.minViableChange`
- **Obligation (PROOF, unproved):** `minViableChange` is `max (requiredFee discardRate changeSpendVsize + 1) changeDust`, with `changeDust` a free parameter; nothing ties it to `dustThreshold(change_prototype_txout, discardRate)`. Obligation: `theorem minViableChange_eq (d : FeeRate) (vsize : Nat) (dust : Amount) (h : dust = dustThreshold d 31 true) : minViableChange d vsize dust = max (requiredFee d vsize + 1) dust`, and `theorem minViableChange_ge_dust`. A `minViableChangeAt` wrapper that computes the dust threshold is the model link; `oblig_WSP_021` is unproved and has the same free dust operand.

### WSP-022 — UNMODELLED / MODEL

- **Row summary:** cost of change
- **Core anchor:** `src/wallet/spend.cpp:1184` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `cost_of_change` (discard-rate spend fee plus effective-rate creation fee). Obligation: add `def costOfChange (discard effective : FeeRate) (spendVsize createVsize : Nat) : Amount := requiredFee discard spendVsize + requiredFee effective createVsize` with `theorem costOfChange_eq : costOfChange dr er sv cv = requiredFee dr sv + requiredFee er cv` and `theorem costOfChange_nonneg`. Fee arithmetic exists but no cost-of-change declaration does.

### WSP-023 — PARTIAL / MODEL

- **Row summary:** required fee
- **Core anchor:** `src/wallet/spend.cpp:1337` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Spend.requiredFeeFromEstimate`
- **Obligation (MODEL, unproved):** `requiredFeeFromEstimate` covers only `requiredFee r (estimatedVsize v)`, the effective-feerate fee for an explicit size estimate; Core adds `result.GetTotalBumpFees()` (`spend.cpp:1331-1337`). Obligation: add a bump-fee parameter `def requiredFeeWithBump (r : FeeRate) (v : VsizeInputs) (bump : Amount) : Amount := requiredFee r (estimatedVsize v) + bump` and `theorem requiredFeeWithBump_ge : requiredFeeFromEstimate r v ≤ requiredFeeWithBump r v bump`. `Fee.lean:31-32` explicitly excludes ancestor bump fees and size estimation is caller-supplied.

### WSP-024 — UNMODELLED / MODEL

- **Row summary:** change top-up
- **Core anchor:** `src/wallet/spend.cpp:1348` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No change top-up and no fee-needed/fee-paid recheck. Obligation: add `def topUpChange (f : Funded) (feeNeeded feePaid : Amount) : Funded := if feeNeeded < feePaid then { f with change := f.change + (feePaid - feeNeeded) } else f` with `theorem topUpChange_fee_eq (h : feeNeeded < feePaid) : (topUpChange f feeNeeded feePaid).fee = feeNeeded` and the recheck `theorem topUpChange_needed_eq_paid`. `fundWithChange` pays exactly feeNeeded on the change branch, so the overpay branch is absent.

### WSP-025 — PARTIAL / MODEL

- **Row summary:** SFFO distribution
- **Core anchor:** `src/wallet/spend.cpp:1371` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Spend.total_subtractFeeFromOutputs`
- **Obligation (MODEL, unproved):** `total_subtractFeeFromOutputs` proves the aggregate deduction equals the fee; the equal split and remainder are only definitional in `feeShares`. Missing: the per-output share theorem, the `IsDust`/negative abort (`spend.cpp:1379-1390`), and the negative-`to_reduce` overpay branch. Obligation: `theorem subtractFeeFromOutputs_share (h : flags[i] = true) : (subtractFeeFromOutputs outs flags fee)[i] = outs[i] - share i` where `share 0 = fee / k + fee % k` and `share i = fee / k` for `i > 0`, plus the abort predicate `theorem subtractFeeFromOutputs_dust_abort (h : isDust discardRate ...) : ... = none`. `CreateTransaction` is absent, so the abort half is MODEL; `oblig_WSP_025` disclaims both branches.

### WSP-026 — PARTIAL / MODEL

- **Row summary:** fee sufficiency invariant
- **Core anchor:** `src/wallet/spend.cpp:1398` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Spend.fundWithChange_fee_ge_needed`
- **Obligation (MODEL, unproved):** `fundWithChange_fee_ge_needed` proves fee ≥ feeNeeded for change-to-source under coverage, so the abort condition is unreachable there. Missing: the explicit `CreateTransaction` abort (`spend.cpp:1396-1400`), the SFFO/top-up post-adjustment path, and bump fees. Obligation: add `def createTransaction ... : Option Tx` with `theorem createTransaction_none_of_fee_short (h : feeNeeded > currentFee) : createTransaction ... = none`; `fundSubtractFee_fee_eq` gives fee = feeNeeded for SFFO, but no declaration states the rejection branch.

### WSP-027 — UNMODELLED / MODEL

- **Row summary:** standard transaction weight
- **Core anchor:** `src/wallet/spend.cpp:1415` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No MAX_STANDARD_TX_WEIGHT, signed/unsigned weight check, or rejection. Obligation: add `def checkTxWeight (tx : Tx) : Bool := txWeight tx ≤ 400000` and `theorem createTransaction_none_of_overweight (h : 400000 < txWeight tx) : createTransaction ... = none`, plus the unsigned-estimate branch `theorem createTransaction_none_of_estimated_overweight (h : 400000 < estimatedWeight v) : ...`. `estimatedWeight` exists but there is no standardness limit or abort.

### WSP-028 — UNMODELLED / MODEL

- **Row summary:** fee ceilings
- **Core anchor:** `src/wallet/spend.cpp:1421` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `m_max_tx_fee` or `m_max_tx_fee_rate` ceiling check; no wallet fee-limit parameters exist. Obligation: add `maxTxFee : Amount` and `maxTxFeeRate : FeeRate` to the wallet, with `theorem createTransaction_none_of_fee_ceiling (h : maxTxFee < fee ∨ maxTxFeeRate.getFee vsize < fee) : createTransaction ... = none`. Absent.

### WSP-029 — PARTIAL / MODEL

- **Row summary:** output conservation
- **Core anchor:** `src/wallet/spend.cpp:1339` at `cce32b168`
- **Existing declaration:** `Bitcoin.Wallet.Spend.fundWithChange_conserves`
- **Obligation (MODEL, unproved):** `fundWithChange_conserves` proves value conservation for change-to-source (and `fundSubtractFee_conserves` for SFFO), but not the explicit `Assume(recipients_sum + change_amount = output_value)` nor the `current_fee < 0` abort (`spend.cpp:1338-1345`). Obligation: `theorem createTransaction_conserves (h : createTransaction ... = some tx) : total tx.vout = recipientsSum + changeAmount` and `theorem createTransaction_none_of_negative_fee (h : selectedValue < outputValue) : createTransaction ... = none`. Conservation is currently unconditional and the negative-fee rejection is unstated; `oblig_WSP_029` is exactly the conservation pair.

### WSP-030 — UNMODELLED / MODEL

- **Row summary:** fee rate precedence
- **Core anchor:** `src/wallet/fees.cpp:40` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `GetMinimumFeeRate`, estimator, fallback-fee, or mempool-minimum precedence. Obligation: add `def getMinimumFeeRate (cc : Option FeeRate) (est : Option FeeRate) (fallback mempoolMin : FeeRate) : FeeRate := max ((cc.orElse est).getD fallback) mempoolMin` with `theorem getMinimumFeeRate_explicit (h : cc = some r) : getMinimumFeeRate cc est fb mm = max r mm`, the estimator and fallback branches, and the required-rate raise. The row is imprecise: Core uses the fallback only when the estimator returns 0, and applies the mempool minimum afterwards.

### WSP-031 — UNMODELLED / MODEL

- **Row summary:** discard feerate floor
- **Core anchor:** `src/wallet/fees.cpp:98` at `cce32b168`
- **Existing declaration:** none
- **Obligation (MODEL, unproved):** No `GetDiscardRate` or `max(discard, relayDustFee)` floor; `DUST_RELAY_TX_FEE` is only a constant. Obligation: add `def getDiscardRate (estimator : Option FeeRate) (relayDust : FeeRate) : FeeRate := max (estimator.getD relayDust) relayDust` with `theorem getDiscardRate_ge_relayDust : relayDust.getFee 1000 ≤ (getDiscardRate est relayDust).getFee 1000` and the estimator branch. Core anchors `fees.cpp:90-100`; no discard-rate function or floor theorem exists.

## What this wallet layer does and does not prove

**Entailed by definitions and tagged lemmas (the 37 ENTAILED rows).** Descriptor checksum empty-iff, eight-symbol
finalisation and emission; the multiple- and missing-checksum gates; `pkh` and `wpkh`
expansion. Miniscript `calcType` for every modelled fragment (pk/hashes/wrappers/
and_v/or_b/or_c/or_i/multi/multi_a), `toScript` for pk_k and pk_h, and the pk_k
satisfaction instance. PSBT bad magic, global map parsing, missing unsigned tx, v2
rejection, global version, the covered `inputKVs` emissions and `spentOutput`. The
definitional `effectiveValue`. Fragments used by PARTIAL rows are proved too:
`addChecksum_eq`, canonical child-number rendering, `sh(wpkh)`/`tr` key-path
expansion, `has_ofTy` singletons, `older`/`after`/hash-with-verify=false emission,
the two `c:pk_*` instances, the record length-prefix shape, duplicate non-acceptance,
finalized extraction, and the change/conservation laws over `fundWithChange`.

This is not 37 independent theorem proofs. Nine of the 40 tags are on
definitions rather than theorems, and the entailed set includes two `checked`
rows (`DESC-003`, `DESC-004`) and two `differential` rows (`PSBT-019`,
`WSP-003`). “Entailed” means the row follows from a definition, tagged lemma,
or vector; it does not assert equivalence to Core’s C++ implementation.

**Does not prove.** No descriptor parser theorem turns a successful parse into a
semantic descriptor law: complete-input consumption, checksum rejection categories,
wildcard/origin/child iff laws, general `sh(X)`/`wsh(X)`/`combo`/taproot-tree
expansion and x-only lifting are all open (DESC/SGN2). The signing layer stops at an
abstract `Signer` oracle: no wallet coin map, manager sweep, descriptor provider
cache, private-key injection, `CreateSig`, Schnorr/taproot signing, or wire-format
signature exists (SGN2). The Miniscript layer has script *emission* definitions for
all modelled fragments but theorem statements only for a few; `andor`/`and_n`,
operation and stack limits, malleability flags, and a `FromString` parser are absent
(MS). PSBT v2, merge, `AddInput`, default sighash, existing-signature agreement,
`SignPSBTInput`/`FinalizePSBT` and signed-and-verified checking are absent; v0
canonicality is only partly stated (PSBT). Coin selection is not modelled beyond
`largestFirst`/`smallestFit`: no `AvailableCoins`, BnB/SRD/Knapsack/CoinGrinder, output
groups, waste, weight budget, change-target generation, bump fees, fee ceilings, or
`CreateTransaction` abort branches exist (WSP).

**Boundary.** This register asserts only that the named declarations are absent or
narrower. It makes no claim about consensus validity, cryptography, key secrecy, or
the correctness of Core itself, and it does not re-review the 41 out-of-scope rows.

