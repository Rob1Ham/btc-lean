import Bitcoin.Wallet.Descriptor.Checksum
import Bitcoin.Wallet.Descriptor.Ast
import Bitcoin.Wallet.Descriptor.Parse
import Bitcoin.Wallet.Descriptor.Expand
import Bitcoin.Wallet.Miniscript.Type
import Bitcoin.Wallet.Miniscript.Node
import Bitcoin.Wallet.Miniscript.Script
import Bitcoin.Wallet.Miniscript.Satisfy
import Bitcoin.Wallet.Psbt.Model
import Bitcoin.Wallet.Psbt.Decode
import Bitcoin.Wallet.Psbt.Encode
import Bitcoin.Wallet.Psbt.Laws
import Bitcoin.Wallet.Spend.Fee
import Bitcoin.Wallet.Spend.Funding
import Bitcoin.Wallet.Spend.Selection

/-!
# Wallet obligation surface

One `Prop`-valued definition per wallet-census row graded `theorem` and
expressible over the committed wallet models.  Each definition is a
statement only: it carries no proof, so this module compiles without
`sorry`, `admit`, or `native_decide`, and a later proof module can attach
to the name without restating the proposition.

The definitions below cover the committed fragments of
`Bitcoin.Wallet.Descriptor.*`, `Bitcoin.Wallet.Miniscript.*`,
`Bitcoin.Wallet.Psbt.*` and `Bitcoin.Wallet.Spend.*`.  Census rows whose
Core behaviour has no committed model are left without a definition and
are recorded as `no obligation: unmodelled` in
`spec/db/rules-wallet.obligations.tsv`; they are not replaced by
vacuous or invented predicates.

Core anchors are line numbers in the pinned tree
`src` at commit `cce32b168`.  When that tree is
absent, the same anchors are the `core_ref` values in
`spec/db/rules-wallet.yaml`.
-/

namespace BitcoinProofs.Wallet

open Bitcoin.Wallet.Descriptor
open Bitcoin.Wallet.Miniscript
open Bitcoin.Wallet.Psbt
open Bitcoin.Wallet.Spend
open Bitcoin.Data
open Bitcoin.Serialization

/-! ## DESCRIPTORS -/

/-- **DESC-001.** The checksum routine returns the empty string exactly
when the payload contains a character outside Core's descriptor input
alphabet.  Core anchor: `src/script/descriptor.cpp:155-158` (the
`INPUT_CHARSET.find` test returning `""`).  Does not claim any typo
correction probability or the algebraic distance of the checksum code. -/
def oblig_DESC_001 : Prop :=
  ∀ payload : String,
    descriptorChecksum payload = "" ↔ (firstInvalidChar payload).isSome

/-- **DESC-005.** Appending a checksum is exactly the payload, then `#`,
then the eight computed characters.  Core anchor:
`src/script/descriptor.cpp:188` (`AddChecksum`).  Does not claim that the
input payload is well-formed descriptor text. -/
def oblig_DESC_005 : Prop :=
  ∀ payload : String,
    addChecksum payload = payload ++ "#" ++ descriptorChecksum payload

/-- **DESC-006.** More than one `#` is rejected as a duplicate separator
before any checksum comparison.  Core anchor:
`src/script/descriptor.cpp:2978-2982` (`check_split.size() > 2`).  Does
not claim recovery of malformed text. -/
def oblig_DESC_006 : Prop :=
  ∀ (input : String) (requireChecksum : Bool),
    (input.splitOn "#").length > 2 →
      checkChecksum input requireChecksum =
        .error DescriptorError.multipleChecksums

/-- **DESC-007.** When a checksum is required and the input has no `#`,
the gate fails with `Missing checksum`.  Core anchor:
`src/script/descriptor.cpp:2983-2986`.  Does not claim anything about
callers that do not require a checksum. -/
def oblig_DESC_007 : Prop :=
  ∀ input : String,
    (input.splitOn "#").length = 1 →
      checkChecksum input true = .error DescriptorError.missingChecksum

/-- **DESC-008.** A present checksum whose length is not eight is rejected
with the observed length.  Core anchor:
`src/script/descriptor.cpp:2987-2991`.  Does not claim checksum
correctness for eight-character strings. -/
def oblig_DESC_008 : Prop :=
  ∀ (payload checksum : String),
    ¬ payload.toList.contains '#' →
      ¬ checksum.toList.contains '#' →
        checksum.length ≠ 8 →
          checkChecksum (payload ++ "#" ++ checksum) false =
            .error (DescriptorError.checksumLength checksum.length)

/-- **DESC-009.** An eight-character checksum that differs from the
computed checksum is rejected, and no payload is returned.  Core anchor:
`src/script/descriptor.cpp:2995-3000`.  Does not claim that equal
checksums imply semantic validity of the descriptor. -/
def oblig_DESC_009 : Prop :=
  ∀ (payload checksum : String),
    ¬ payload.toList.contains '#' →
      ¬ checksum.toList.contains '#' →
        checksum.length = 8 →
          descriptorChecksum payload ≠ "" →
            checksum ≠ descriptorChecksum payload →
              checkChecksum (payload ++ "#" ++ checksum) false =
                .error (DescriptorError.checksumMismatch checksum
                  (descriptorChecksum payload))

/-- **DESC-011.** A 65-byte key with hybrid prefix `0x06` or `0x07` is
rejected in every parse context.  Core anchor:
`src/script/descriptor.cpp:1999-2005` (`IsValidNonHybrid`).  Does not
claim the curve validity of non-hybrid keys. -/
def oblig_DESC_011 : Prop :=
  ∀ (ctx : KeyContext) (pubkey : ByteArray),
    pubkey.size = 65 →
      (pubkey.get! 0 = 0x06 ∨ pubkey.get! 0 = 0x07) →
        constKeyValid ctx pubkey = false

/-- **DESC-012.** An otherwise valid uncompressed key is accepted in the
legacy context (Core's TOP and P2SH contexts) and rejected by the segwit
and taproot contexts.  Core anchor:
`src/script/descriptor.cpp:1986` and `:2006-2011`.  Does not
distinguish TOP from P2SH, because the committed AST has one `legacy`
context for both. -/
def oblig_DESC_012 : Prop :=
  ∀ pubkey : ByteArray,
    pubkey.size = 65 →
      pubkey.get! 0 = 0x04 →
        uncompressedKeyValid pubkey = true →
          constKeyValid .legacy pubkey = true ∧
            constKeyValid .segwit pubkey = false ∧
              constKeyValid .taproot pubkey = false

/-- **DESC-013.** A 32-byte key is legal only in taproot context, where
acceptance is exactly the existence of an even-y lift.  Core anchor:
`src/script/descriptor.cpp:2014-2023`.  Does not claim that the parser
rewrites the stored bytes to a 33-byte compressed key; the model keeps the
x-only bytes and the `xonly` flag. -/
def oblig_DESC_013 : Prop :=
  ∀ pubkey : ByteArray,
    pubkey.size = 32 →
      (constKeyValid .taproot pubkey = true ↔
        (Bitcoin.Crypto.Curve.Secp.liftX
          (Bitcoin.Crypto.Curve.Secp.bytesToNatBE pubkey)).isSome) ∧
        constKeyValid .segwit pubkey = false ∧
          constKeyValid .legacy pubkey = false

/-- **DESC-015.** A trailing `*` records an unhardened wildcard, while
`*'` and `*h` record a hardened wildcard.  Core anchor:
`src/script/descriptor.cpp:1968-1981` (`ParseDeriveType`).  Does not
claim any child-key derivation, which the model leaves to its key
provider. -/
def oblig_DESC_015 : Prop :=
  ∀ (body : String) (ctx : KeyContext) (key : KeyExpr),
    (parseKeyExpr (body ++ "/*") ctx = .ok key →
      key.wildcard = Wildcard.unhardened) ∧
    (parseKeyExpr (body ++ "/*'") ctx = .ok key →
      key.wildcard = Wildcard.hardened) ∧
    (parseKeyExpr (body ++ "/*h") ctx = .ok key →
      key.wildcard = Wildcard.hardened)

/-- **DESC-016.** A bracketed key origin whose fingerprint field is not
exactly eight hexadecimal characters is rejected.  Core anchor:
`src/script/descriptor.cpp:2223-2235`.  Does not claim that an
eight-character fingerprint is the correct master fingerprint. -/
def oblig_DESC_016 : Prop :=
  ∀ (fingerprint rest : String),
    fingerprint.length ≠ 8 →
      ∃ e : DescriptorError,
        parseOrigin ("[" ++ fingerprint ++ "/" ++ rest ++ "]x") = .error e

/-- **DESC-017.** A path element with a trailing apostrophe or `h` sets
the hardened bit and requires the numeric part below `2^31`; without a
suffix it remains unhardened.  Core anchor:
`src/util/bip32.cpp:17-39` (`ParseKeyPathElement`), called from
`src/script/descriptor.cpp:1883-1895`.  Does not claim BIP32 child-key
derivation. -/
def oblig_DESC_017 : Prop :=
  ∀ n : Nat,
    n < 0x80000000 →
      parsePathElement (toString n ++ "'") =
        .ok (n + 0x80000000).toUInt32 ∧
      parsePathElement (toString n ++ "h") =
        .ok (n + 0x80000000).toUInt32 ∧
      parsePathElement (toString n) = .ok n.toUInt32

/-- **DESC-019.** A path element containing `<` or `>` is a multipath
specifier; the committed parser rejects it in origins as well as in
ordinary paths.  Core anchor: `src/script/descriptor.cpp:2241`
(`allow_multipath=false` for origins).  Does not claim support for
multipath alternatives or their cardinality rules. -/
def oblig_DESC_019 : Prop :=
  ∀ text : String,
    text.toList.any (fun c => c = '<' ∨ c = '>') = true →
      ∃ e : DescriptorError, parsePathElement text = .error e

/-- **DESC-020.** `pk(K)` expands to the single script
`<push K> OP_CHECKSIG`, for a literal key in the supported contexts.
Core anchor: `src/script/solver.cpp:213-216`
(`GetScriptForRawPubKey`).  Does not claim a 32-byte push for P2TR `pk`,
which the committed parser does not admit. -/
def oblig_DESC_020 : Prop :=
  ∀ (origin : Option Bitcoin.Wallet.Descriptor.KeyOrigin) (pubkey : ByteArray) (xonly : Bool)
      (raw : String),
    expand? (.pk (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [payToPubkey pubkey]

/-- **DESC-021.** `pkh(K)` expands to
`OP_DUP OP_HASH160 <HASH160(K)> OP_EQUALVERIFY OP_CHECKSIG`.
Core anchor: `src/addresstype.cpp:120-123` (`CScriptVisitor`
`PKHash`).  Does not claim that `K` is a valid curve point, which is a
parser precondition. -/
def oblig_DESC_021 : Prop :=
  ∀ (origin : Option Bitcoin.Wallet.Descriptor.KeyOrigin) (pubkey : ByteArray) (xonly : Bool)
      (raw : String),
    expand? (.pkh (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [payToPubkeyHash pubkey]

/-- **DESC-022.** `wpkh(K)` expands to the witness-v0 key-hash program
`OP_0 <HASH160(K)>`.  Core anchor: `src/addresstype.cpp:128-131`
(`WitnessV0KeyHash`).  Does not claim key compression or address
encoding. -/
def oblig_DESC_022 : Prop :=
  ∀ (origin : Option Bitcoin.Wallet.Descriptor.KeyOrigin) (pubkey : ByteArray) (xonly : Bool)
      (raw : String),
    expand? (.wpkh (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [payToWitnessPubkeyHash pubkey]

/-- **DESC-023.** `sh(wpkh(K))` expands to
`OP_HASH160 <HASH160(OP_0 <HASH160(K)>)> OP_EQUAL`.  Core anchor:
`src/addresstype.cpp:125-128` (`ScriptHash`) with
`src/script/descriptor.cpp:2529-2545` (the `sh` wrapper).  Does not claim
that the redeem script is recorded in a signing provider: the committed
expander returns scripts only. -/
def oblig_DESC_023 : Prop :=
  ∀ (origin : Option Bitcoin.Wallet.Descriptor.KeyOrigin) (pubkey : ByteArray) (xonly : Bool)
      (raw : String),
    expand? (.shWpkh (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [payToScriptHash (payToWitnessPubkeyHash pubkey)]

/-- **DESC-025.** `multi` preserves the supplied key order, while
`sortedmulti` first sorts the keys by Core's serialized-key ordering.
Core anchor: `src/script/descriptor.cpp:1366-1395` and
`src/pubkey.h:133-137`.  The hypotheses are Core's parser guards for a
well-formed `multi`: at least one key and `1 ≤ threshold ≤ keys.length`.
Without them the model's `expand?` would also accept an empty key list,
whereas Core rejects `multi(0)` and `multi(t)` with no keys.  Does not
claim that the resulting script satisfies any policy. -/
def oblig_DESC_025 : Prop :=
  ∀ (threshold : Nat) (keys : List ByteArray),
    keys ≠ [] → 1 ≤ threshold → threshold ≤ keys.length →
    expand? (.multi threshold
        (keys.map (fun k => .const none k false "")) false) (fun _ => []) =
      .ok [multiScript threshold keys] ∧
    expand? (.multi threshold
        (keys.map (fun k => .const none k false "")) true) (fun _ => []) =
      .ok [multiScript threshold (sortPubkeys keys)]

/-- **DESC-026.** A bare `multi`/`sortedmulti` with more than three keys
is rejected before expansion.  Core anchor:
`src/script/descriptor.cpp:2488-2493` (the `TOP`-context key cap).  Does
not claim the threshold or curve-validity checks, which are separate
rejection paths. -/
def oblig_DESC_026 : Prop :=
  ∀ (threshold : Nat) (keys : List String),
    3 < keys.length →
      (∀ k ∈ keys, ∃ key : KeyExpr, parseKeyExpr k .legacy = .ok key) →
        ∃ e : DescriptorError,
          parse ("multi(" ++ toString threshold ++ "," ++
            String.intercalate "," keys ++ ")") = .error e

/-- **DESC-028.** A 32-byte taproot internal key expands to the BIP341
key-path-only output computed by `p2trOutput` with a null Merkle root.
Core anchor: `src/script/descriptor.cpp:1561-1568`
(`TaprootBuilder::Finalize` for an empty tree).  Does not claim taproot
script trees, control blocks, or the program equality that the consensus
tree leaves unjudged. -/
def oblig_DESC_028 : Prop :=
  ∀ internalKey : ByteArray,
    internalKey.size = 32 →
      taprootKeyPath internalKey =
        (Bitcoin.Crypto.Taproot.Verify.p2trOutput internalKey none).map
          (fun bytes => (⟨bytes⟩ : Bitcoin.Data.Script))

/-! ## MINISCRIPT -/

/-- **MS-001.** Each of the nineteen type characters owns a distinct bit,
and a singleton type contains exactly its own character.  Core anchor:
`src/script/miniscript.h:167` (the `operator""_mst` bit list).  Does not
claim the subtype/sanitisation assertions of `SanitizeType`. -/
def oblig_MS_001 : Prop :=
  ∀ p q : Ty,
    p.bit < 19 ∧ ((MSType.ofTy p).has q = true ↔ p = q)

/-- **MS-002.** `PK_K` has type `Konudemsxk` in every context.  Core
anchor: `src/script/miniscript.cpp:89`.  Does not validate the key bytes
or claim anything about a surrounding descriptor. -/
def oblig_MS_002 : Prop :=
  ∀ (ctx : MiniscriptContext) (key : Key),
    calcType ctx (.pkK key) =
      ty [.K, .o, .n, .u, .d, .e, .m, .s, .x, .k]

/-- **MS-003.** `PK_H` has type `Knudemsxk` in every context.  Core
anchor: `src/script/miniscript.cpp:90`.  The stored key hash is data; the
statement does not claim it is HASH160 of the key. -/
def oblig_MS_003 : Prop :=
  ∀ (ctx : MiniscriptContext) (key keyHash : Key),
    calcType ctx (.pkH key keyHash) =
      ty [.K, .n, .u, .d, .e, .m, .s, .x, .k]

/-- **MS-004.** `OLDER(n)` has `Bzfmxk`, plus `g` when the sequence
lock-time flag is set and `h` otherwise.  Core anchor:
`src/script/miniscript.cpp:91`.  Only encodable relative timelocks
`1 ≤ n < 2^31` are covered; `older(0)` and values with the disable bit
are outside the domain. -/
def oblig_MS_004 : Prop :=
  ∀ (ctx : MiniscriptContext) (n : Nat),
    1 ≤ n → n < 0x80000000 →
      calcType ctx (.older n) =
        ty ([.B, .z, .f, .m, .x, .k] ++
          (if n &&& 0x400000 ≠ 0 then [.g] else [.h]))

/-- **MS-005.** `AFTER(n)` has `Bzfmxk`, plus `i` at or above
`LOCKTIME_THRESHOLD` and `j` below it.  Core anchor:
`src/script/miniscript.cpp:95`.  Only encodable absolute locktimes
`1 ≤ n < 2^31` are covered. -/
def oblig_MS_005 : Prop :=
  ∀ (ctx : MiniscriptContext) (n : Nat),
    1 ≤ n → n < 0x80000000 →
      calcType ctx (.after n) =
        ty ([.B, .z, .f, .m, .x, .k] ++
          (if n ≥ 500000000 then [.i] else [.j]))

/-- **MS-006.** Each of `SHA256`, `HASH256`, `RIPEMD160` and `HASH160`
has type `Bonudmk` at its digest length.  Core anchor:
`src/script/miniscript.cpp:99`.  Does not claim the preimage relation or
that a satisfaction exists. -/
def oblig_MS_006 : Prop :=
  (∀ (ctx : MiniscriptContext) (h : ByteArray), h.size = 32 →
    calcType ctx (.sha256 h) = ty [.B, .o, .n, .u, .d, .m, .k]) ∧
  (∀ (ctx : MiniscriptContext) (h : ByteArray), h.size = 32 →
    calcType ctx (.hash256 h) = ty [.B, .o, .n, .u, .d, .m, .k]) ∧
  (∀ (ctx : MiniscriptContext) (h : ByteArray), h.size = 20 →
    calcType ctx (.ripemd160 h) = ty [.B, .o, .n, .u, .d, .m, .k]) ∧
  (∀ (ctx : MiniscriptContext) (h : ByteArray), h.size = 20 →
    calcType ctx (.hash160 h) = ty [.B, .o, .n, .u, .d, .m, .k])

/-- **MS-007.** `WRAP_A` has `W` exactly when its child has `B`, inherits
the child's timelock and satisfaction properties, and always adds `x`.
Core anchor: `src/script/miniscript.cpp:105`.  Does not claim stack
execution or satisfaction availability. -/
def oblig_MS_007 : Prop :=
  ∀ (ctx : MiniscriptContext) (x : Node),
    let xt := calcType ctx x
    let t := calcType ctx (.wrapA x)
    (t.has .W = true ↔ xt.has .B = true) ∧
    t.has .x = true ∧
    (∀ p : Ty, p ∈ [.g, .h, .i, .j, .k] → t.has p = xt.has p) ∧
    (∀ p : Ty, p ∈ [.u, .d, .f, .e, .m, .s] → t.has p = xt.has p)

/-- **MS-008.** `WRAP_S` has `W` exactly when its child has both `B` and
`o`, and otherwise inherits every property including `x`.  Core anchor:
`src/script/miniscript.cpp:110`.  Does not claim stack execution. -/
def oblig_MS_008 : Prop :=
  ∀ (ctx : MiniscriptContext) (x : Node),
    let xt := calcType ctx x
    let t := calcType ctx (.wrapS x)
    (t.has .W = true ↔ (xt.has .B = true ∧ xt.has .o = true)) ∧
    (∀ p : Ty, p ∈ [.g, .h, .i, .j, .k, .u, .d, .f, .e, .m, .s, .x] →
      t.has p = xt.has p)

/-- **MS-009.** `WRAP_C` has `B` exactly when its child has `K`, always
has `u` and `s`, and inherits `o,n,d,f,e,m` and the timelock properties.
Core anchor: `src/script/miniscript.cpp:114`.  Does not claim signature
validity. -/
def oblig_MS_009 : Prop :=
  ∀ (ctx : MiniscriptContext) (x : Node),
    let xt := calcType ctx x
    let t := calcType ctx (.wrapC x)
    (t.has .B = true ↔ xt.has .K = true) ∧
    t.has .u = true ∧ t.has .s = true ∧
    (∀ p : Ty, p ∈ [.o, .n, .d, .f, .e, .m, .g, .h, .i, .j, .k] →
      t.has p = xt.has p)

/-- **MS-010.** `WRAP_D` has `B` exactly when its child has both `V` and
`z`, has `u` only in Tapscript, and always has `n,d,x`.  Core anchor:
`src/script/miniscript.cpp:119`.  Does not claim the child's satisfaction
behaviour under `OP_IF`. -/
def oblig_MS_010 : Prop :=
  ∀ (ctx : MiniscriptContext) (x : Node),
    let xt := calcType ctx x
    let t := calcType ctx (.wrapD x)
    (t.has .B = true ↔ (xt.has .V = true ∧ xt.has .z = true)) ∧
    (t.has .u = true ↔ ctx = .tapscript) ∧
    t.has .n = true ∧ t.has .d = true ∧ t.has .x = true

/-- **MS-011.** `WRAP_V` has `V` exactly when its child has `B`, always
has `f` and `x`, and inherits the child's satisfaction and timelock
properties.  Core anchor: `src/script/miniscript.cpp:128`.  Does not
claim that the emitted script ends in a `VERIFY` opcode in every case,
which `v:` implements by folding the child's last opcode. -/
def oblig_MS_011 : Prop :=
  ∀ (ctx : MiniscriptContext) (x : Node),
    let xt := calcType ctx x
    let t := calcType ctx (.wrapV x)
    (t.has .V = true ↔ xt.has .B = true) ∧
    t.has .f = true ∧ t.has .x = true ∧
    (∀ p : Ty, p ∈ [.z, .o, .n, .m, .s, .g, .h, .i, .j, .k] →
      t.has p = xt.has p)

/-- **MS-012.** `WRAP_J` has `B` exactly when its child has both `B` and
`n`, and always has `n,d,x`.  Core anchor:
`src/script/miniscript.cpp:133`.  Does not claim stack-size behaviour. -/
def oblig_MS_012 : Prop :=
  ∀ (ctx : MiniscriptContext) (x : Node),
    let xt := calcType ctx x
    let t := calcType ctx (.wrapJ x)
    (t.has .B = true ↔ (xt.has .B = true ∧ xt.has .n = true)) ∧
    t.has .n = true ∧ t.has .d = true ∧ t.has .x = true

/-- **MS-013.** For `AND_V`, when the left child has `V`, `B`, `V` and
`K` are taken from the right child; `k` holds exactly when both children
have `k` and neither child mixes height and time locks.  Core anchor:
`src/script/miniscript.cpp:143`.  Does not claim satisfaction availability
from either child. -/
def oblig_MS_013 : Prop :=
  ∀ (ctx : MiniscriptContext) (x y : Node),
    let xt := calcType ctx x
    let yt := calcType ctx y
    let t := calcType ctx (.andV x y)
    (xt.has .V = true →
      (t.has .B = yt.has .B ∧ t.has .V = yt.has .V ∧
        t.has .K = yt.has .K)) ∧
    (t.has .k = true ↔
      (xt.has .k = true ∧ yt.has .k = true ∧
        ¬ (((xt.has .g = true ∧ yt.has .h = true) ∨
          (xt.has .h = true ∧ yt.has .g = true) ∨
          (xt.has .i = true ∧ yt.has .j = true) ∨
          (xt.has .j = true ∧ yt.has .i = true)))))

/-- **MS-014.** `AND_B` has `B` exactly when the right child has `W` and
the left has `B`; it always has `u` and `x`; and it has `e` exactly when
both children have `e` and `s`.  Core anchor:
`src/script/miniscript.cpp:157`.  Does not claim non-malleability beyond
the `e` bit. -/
def oblig_MS_014 : Prop :=
  ∀ (ctx : MiniscriptContext) (x y : Node),
    let xt := calcType ctx x
    let yt := calcType ctx y
    let t := calcType ctx (.andB x y)
    (t.has .B = true ↔ (yt.has .W = true ∧ xt.has .B = true)) ∧
    t.has .u = true ∧ t.has .x = true ∧
    (t.has .e = true ↔
      (xt.has .e = true ∧ yt.has .e = true ∧
        xt.has .s = true ∧ yt.has .s = true))

/-- **MS-015.** `OR_B` has `B` exactly when the left child has `B` and `d`
and the right child has `W` and `d`, and always has `d,u,x`.  Core
anchor: `src/script/miniscript.cpp:172`.  Does not claim which branch is
selected. -/
def oblig_MS_015 : Prop :=
  ∀ (ctx : MiniscriptContext) (x y : Node),
    let xt := calcType ctx x
    let yt := calcType ctx y
    let t := calcType ctx (.orB x y)
    (t.has .B = true ↔
      (xt.has .B = true ∧ xt.has .d = true ∧
        yt.has .W = true ∧ yt.has .d = true)) ∧
    t.has .d = true ∧ t.has .u = true ∧ t.has .x = true

/-- **MS-016.** `OR_D` has `B` exactly when its left child has `B,d,u`
(and the right child has `B`), takes `u,f,d,e` from its right child, and
always has `x`.  Core anchor: `src/script/miniscript.cpp:180`.  Does not
claim satisfaction availability. -/
def oblig_MS_016 : Prop :=
  ∀ (ctx : MiniscriptContext) (x y : Node),
    let xt := calcType ctx x
    let yt := calcType ctx y
    let t := calcType ctx (.orD x y)
    (t.has .B = true ↔
      (xt.has .B = true ∧ xt.has .d = true ∧ xt.has .u = true ∧
        yt.has .B = true)) ∧
    (∀ p : Ty, p ∈ [.u, .f, .d, .e] → t.has p = yt.has p) ∧
    t.has .x = true

/-- **MS-017.** `OR_C` has `V` exactly when its left child has `B,d,u` and
its right child has `V`, and always has `f` and `x`.  Core anchor:
`src/script/miniscript.cpp:189`.  Does not claim satisfaction
availability. -/
def oblig_MS_017 : Prop :=
  ∀ (ctx : MiniscriptContext) (x y : Node),
    let xt := calcType ctx x
    let yt := calcType ctx y
    let t := calcType ctx (.orC x y)
    (t.has .V = true ↔
      (xt.has .B = true ∧ xt.has .d = true ∧ xt.has .u = true ∧
        yt.has .V = true)) ∧
    t.has .f = true ∧ t.has .x = true

/-- **MS-018.** `OR_I` intersects `B`, `V` and `K` across both children,
has `o` exactly when both children have `z`, and takes `d` from either
child.  Core anchor: `src/script/miniscript.cpp:197`.  Does not claim
which branch is selected. -/
def oblig_MS_018 : Prop :=
  ∀ (ctx : MiniscriptContext) (x y : Node),
    let xt := calcType ctx x
    let yt := calcType ctx y
    let t := calcType ctx (.orI x y)
    (t.has .B = true ↔ (xt.has .B = true ∧ yt.has .B = true)) ∧
    (t.has .V = true ↔ (xt.has .V = true ∧ yt.has .V = true)) ∧
    (t.has .K = true ↔ (xt.has .K = true ∧ yt.has .K = true)) ∧
    (t.has .o = true ↔ (xt.has .z = true ∧ yt.has .z = true)) ∧
    (t.has .d = true ↔ (xt.has .d = true ∨ yt.has .d = true))

/-- **MS-020.** A well-formed `MULTI` has type `Bnudemsk` in P2WSH and is
ill-typed in Tapscript.  Core anchor: `src/script/miniscript.h:1881`.
The key-count bound is the model's 20-key P2WSH cap; key encodings and
threshold satisfiability are not claimed. -/
def oblig_MS_020 : Prop :=
  ∀ (k : Nat) (keys : List Key),
    1 ≤ k → k ≤ keys.length → keys.length ≤ 20 →
      calcType .p2wsh (.multi k keys) =
          ty [.B, .n, .u, .d, .e, .m, .s, .k] ∧
        calcType .tapscript (.multi k keys) = MSType.empty

/-- **MS-021.** A well-formed `MULTI_A` has type `Budemsk` in Tapscript
and is ill-typed in P2WSH.  Core anchor: `src/script/miniscript.h:1881`.
The key-count bound is the model's 999-key Tapscript cap; key encodings
and threshold satisfiability are not claimed. -/
def oblig_MS_021 : Prop :=
  ∀ (k : Nat) (keys : List Key),
    1 ≤ k → k ≤ keys.length → keys.length ≤ 999 →
      calcType .tapscript (.multiA k keys) =
          ty [.B, .u, .d, .e, .m, .s, .k] ∧
        calcType .p2wsh (.multiA k keys) = MSType.empty

/-- **MS-022.** `THRESH` requires its first child to have `B,d,u` and
every later child `W,d,u`; when that holds it carries `B,d,u`.  For
`k ≥ 2` its `k` bit is absent whenever two branches mix height and time
locks.  The `k ≥ 2` guard is essential: Core applies the mixing test only
when more than one branch is satisfied, so with `k = 1` the type keeps
`k` even if the tree contains both kinds of timelock.  Core anchor:
`src/script/miniscript.cpp:242`.  Does not claim satisfaction cardinality
or branch selection. -/
def oblig_MS_022 : Prop :=
  ∀ (ctx : MiniscriptContext) (k : Nat) (x0 : Node) (rest : List Node),
    1 ≤ k → k ≤ (x0 :: rest).length →
      (calcType ctx (.thresh k (x0 :: rest)) = MSType.empty ↔
        ¬ ((calcType ctx x0).Sub (ty [.B, .d, .u]) = true ∧
          ∀ x : Node, x ∈ rest →
            (calcType ctx x).Sub (ty [.W, .d, .u]) = true)) ∧
      (((calcType ctx x0).Sub (ty [.B, .d, .u]) = true ∧
          ∀ x : Node, x ∈ rest →
            (calcType ctx x).Sub (ty [.W, .d, .u]) = true) →
        (calcType ctx (.thresh k (x0 :: rest))).Sub (ty [.B, .d, .u]) = true) ∧
      (2 ≤ k →
        ∀ (a b : Node), a ∈ x0 :: rest → b ∈ x0 :: rest →
          (((calcType ctx a).has .g = true ∧ (calcType ctx b).has .h = true) ∨
            ((calcType ctx a).has .h = true ∧ (calcType ctx b).has .g = true) ∨
            ((calcType ctx a).has .i = true ∧ (calcType ctx b).has .j = true) ∨
            ((calcType ctx a).has .j = true ∧ (calcType ctx b).has .i = true)) →
          (calcType ctx (.thresh k (x0 :: rest))).has .k = false)

/-- **MS-023.** `ToScript` emits `PK_K` as the key push alone and `PK_H`
as `OP_DUP OP_HASH160 <keyhash> OP_EQUALVERIFY`.  Core anchor:
`src/script/miniscript.h:817`.  Does not claim that the push is minimal
for an invalid key length, which the parser excludes. -/
def oblig_MS_023 : Prop :=
  (∀ (ctx : MiniscriptContext) (key : Key),
    toScript ctx (.pkK key) = pushBytes key) ∧
  (∀ (ctx : MiniscriptContext) (key keyHash : Key),
    toScript ctx (.pkH key keyHash) =
      op 0x76 ++ op 0xa9 ++ pushBytes keyHash ++ op 0x88)

/-- **MS-024.** `ToScript` emits `OLDER` and `AFTER` as `<n>` followed by
`OP_CHECKSEQUENCEVERIFY`/`OP_CHECKLOCKTIMEVERIFY`, and each hash fragment
as `OP_SIZE 32 OP_EQUALVERIFY <hash-op> <digest>` followed by
`OP_EQUAL` or `OP_EQUALVERIFY` according to the verify context.  Core
anchor: `src/script/miniscript.h:819`.  Does not claim execution success
or preimage knowledge. -/
def oblig_MS_024 : Prop :=
  (∀ (ctx : MiniscriptContext) (n : Nat),
    toScript ctx (.older n) = Bitcoin.Wallet.Miniscript.pushInt n ++ op 0xb2) ∧
  (∀ (ctx : MiniscriptContext) (n : Nat),
    toScript ctx (.after n) = Bitcoin.Wallet.Miniscript.pushInt n ++ op 0xb1) ∧
  (∀ (ctx : MiniscriptContext) (h : ByteArray),
    toScriptWith ctx false (.sha256 h) =
        op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xa8 ++
          pushBytes h ++ op 0x87 ∧
      toScriptWith ctx true (.sha256 h) =
        op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xa8 ++
          pushBytes h ++ op 0x88) ∧
  (∀ (ctx : MiniscriptContext) (h : ByteArray),
    toScriptWith ctx false (.hash256 h) =
        op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xaa ++
          pushBytes h ++ op 0x87 ∧
      toScriptWith ctx true (.hash256 h) =
        op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xaa ++
          pushBytes h ++ op 0x88) ∧
  (∀ (ctx : MiniscriptContext) (h : ByteArray),
    toScriptWith ctx false (.ripemd160 h) =
        op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xa6 ++
          pushBytes h ++ op 0x87 ∧
      toScriptWith ctx true (.ripemd160 h) =
        op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xa6 ++
          pushBytes h ++ op 0x88) ∧
  (∀ (ctx : MiniscriptContext) (h : ByteArray),
    toScriptWith ctx false (.hash160 h) =
        op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xa9 ++
          pushBytes h ++ op 0x87 ∧
      toScriptWith ctx true (.hash160 h) =
        op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xa9 ++
          pushBytes h ++ op 0x88)

/-- **MS-025.** `ToScript` emits `a:`, `s:`, `c:`, `d:`, `v:`, `j:` and
`n:` as the altstack round-trip, swap, checksig/checksigverify, dup-if,
verify-or-last-opcode, size-nonzero-if and `0NOTEQUAL` wrappers.  Core
anchor: `src/script/miniscript.h:825`.  The `v:` equation is conditional
on the child's `x` bit, matching the model's opcode folding; execution
semantics are not claimed. -/
def oblig_MS_025 : Prop :=
  ∀ (ctx : MiniscriptContext) (x : Node),
    toScriptWith ctx false (.wrapA x) =
        op 0x6b ++ toScriptWith ctx false x ++ op 0x6c ∧
      toScriptWith ctx false (.wrapS x) =
        op 0x7c ++ toScriptWith ctx false x ∧
      toScriptWith ctx false (.wrapC x) =
        toScriptWith ctx false x ++ op 0xac ∧
      toScriptWith ctx true (.wrapC x) =
        toScriptWith ctx true x ++ op 0xad ∧
      toScriptWith ctx false (.wrapD x) =
        op 0x76 ++ op 0x63 ++ toScriptWith ctx false x ++ op 0x68 ∧
      toScriptWith ctx false (.wrapV x) =
        (let s := toScriptWith ctx true x
         if (calcType ctx x).has .x then s ++ op 0x69 else s) ∧
      toScriptWith ctx false (.wrapJ x) =
        op 0x82 ++ op 0x92 ++ op 0x63 ++ toScriptWith ctx false x ++ op 0x68 ∧
      toScriptWith ctx false (.wrapN x) =
        toScriptWith ctx false x ++ op 0x92

/-- **MS-026.** `ToScript` emits `and_v` by concatenation, `and_b` with
`OP_BOOLAND`, `or_b` with `OP_BOOLOR`, `or_d` with `OP_IFDUP OP_NOTIF`,
`or_c` with `OP_NOTIF`, and `or_i` with `OP_IF`/`OP_ELSE`.  Core anchor:
`src/script/miniscript.h:840`.  `andor` is not a constructor of the
committed node model, so its `OP_NOTIF`/`OP_ELSE` clause is not claimed. -/
def oblig_MS_026 : Prop :=
  ∀ (ctx : MiniscriptContext) (x y : Node),
    toScriptWith ctx false (.andV x y) =
        toScriptWith ctx false x ++ toScriptWith ctx false y ∧
      toScriptWith ctx true (.andV x y) =
        toScriptWith ctx false x ++ toScriptWith ctx true y ∧
      toScriptWith ctx false (.andB x y) =
        toScriptWith ctx false x ++ toScriptWith ctx false y ++ op 0x9a ∧
      toScriptWith ctx false (.orB x y) =
        toScriptWith ctx false x ++ toScriptWith ctx false y ++ op 0x9b ∧
      toScriptWith ctx false (.orD x y) =
        toScriptWith ctx false x ++ op 0x73 ++ op 0x64 ++
          toScriptWith ctx false y ++ op 0x68 ∧
      toScriptWith ctx false (.orC x y) =
        toScriptWith ctx false x ++ op 0x64 ++
          toScriptWith ctx false y ++ op 0x68 ∧
      toScriptWith ctx false (.orI x y) =
        op 0x63 ++ toScriptWith ctx false x ++ op 0x67 ++
          toScriptWith ctx false y ++ op 0x68

/-- **MS-027.** `ToScript` emits `MULTI` as `<k>`, the key pushes, then
`<n> OP_CHECKMULTISIG[VERIFY]`, and `MULTI_A` as the first key with
`OP_CHECKSIG`, each later key with `OP_CHECKSIGADD`, then
`<k> OP_NUMEQUAL[VERIFY]`.  Core anchor: `src/script/miniscript.h:847`.
Does not claim that `k` is satisfiable. -/
def oblig_MS_027 : Prop :=
  ∀ (ctx : MiniscriptContext) (k : Nat) (keys : List Key),
    toScriptWith ctx false (.multi k keys) =
        Bitcoin.Wallet.Miniscript.pushInt k ++ concatScripts (keys.map pushBytes) ++
          Bitcoin.Wallet.Miniscript.pushInt keys.length ++ op 0xae ∧
      toScriptWith ctx true (.multi k keys) =
        Bitcoin.Wallet.Miniscript.pushInt k ++ concatScripts (keys.map pushBytes) ++
          Bitcoin.Wallet.Miniscript.pushInt keys.length ++ op 0xaf ∧
      toScriptWith ctx false (.multiA k keys) =
        multiAKeyScript keys ++ Bitcoin.Wallet.Miniscript.pushInt k ++ op 0x9c ∧
      toScriptWith ctx true (.multiA k keys) =
        multiAKeyScript keys ++ Bitcoin.Wallet.Miniscript.pushInt k ++ op 0x9d

/-- **MS-028.** `ToScript` emits `THRESH` by concatenating the first
child, each later child followed by `OP_ADD`, then `<k> OP_EQUAL` or
`OP_EQUALVERIFY`.  Core anchor: `src/script/miniscript.h:863`.  Does not
claim that `k` branches can be satisfied. -/
def oblig_MS_028 : Prop :=
  ∀ (ctx : MiniscriptContext) (k : Nat) (xs : List Node),
    toScriptWith ctx false (.thresh k xs) =
        intersperseAdd (xs.map (toScriptWith ctx false)) ++
          Bitcoin.Wallet.Miniscript.pushInt k ++ op 0x87 ∧
      toScriptWith ctx true (.thresh k xs) =
        intersperseAdd (xs.map (toScriptWith ctx false)) ++
          Bitcoin.Wallet.Miniscript.pushInt k ++ op 0x88

/-- **MS-029.** `IsValid` holds exactly when the computed type is
non-empty and the emitted script fits `MaxScriptSize` for its context.
Core anchor: `src/script/miniscript.h:1675`.  Does not claim the
operation-count or stack-size limits. -/
def oblig_MS_029 : Prop :=
  ∀ (ctx : MiniscriptContext) (n : Node),
    isValid ctx n = true ↔
      calcType ctx n ≠ MSType.empty ∧
        (toScript ctx n).size ≤ maxScriptSize ctx

/-- **MS-030.** `IsSane` holds exactly when `IsSaneSubexpression`,
`IsValidTopLevel` and `NeedsSignature` all hold.  Core anchor:
`src/script/miniscript.h:1702`.  The operation-count and stack-size limits
are outside the model. -/
def oblig_MS_030 : Prop :=
  ∀ (ctx : MiniscriptContext) (n : Node),
    isSane ctx n = true ↔
      isSaneSubexpression ctx n = true ∧
        (topLevelReasons ctx n).isEmpty = true ∧
        ((topLevelReasons ctx n).isEmpty = true ↔
          ((calcType ctx n).Sub (ty [.B]) = true ∧
            (calcType ctx n).has .s = true))

/-- **MS-034.** `ProduceInput` emits exactly one signature element for
`PK_K` when the satisfier can sign, and is unavailable otherwise.  Core
anchor: `src/script/miniscript.h:1256`.  Does not claim the signature is
valid under the spent output's key or that the stack executes. -/
def oblig_MS_034 : Prop :=
  ∀ (sf : Satisfier) (key : Key),
    satisfy sf (.pkK key) = (sf.sign key).map (fun sig => [sig]) ∧
      (sf.sign key = none → satisfy sf (.pkK key) = none)

/-! ## PSBT -/

/-- **PSBT-001.** `decode` accepts a stream only when it begins with
`psbt\xff`; any other prefix fails with `badMagic`.  Core anchor:
`src/psbt.h:1352`.  Does not claim anything about the maps that follow a
valid magic. -/
def oblig_PSBT_001 : Prop :=
  ∀ b : ByteArray,
    (bL b).take 5 ≠ magicBytes → decode b = .error .badMagic

/-- **PSBT-002.** A successfully decoded map record is exactly a
length-prefixed key followed by a length-prefixed value, with the
canonical CompactSize framing restored by `encKVL`.  Core anchor:
`src/psbt.h:134`.  Does not claim that arbitrary malformed lengths are
rejected with a particular error code. -/
def oblig_PSBT_002 : Prop :=
  ∀ (l : List UInt8) (kv : RawKV) (rest : List UInt8),
    decKV l = .ok (kv, rest) → l = encKVL kv ++ rest

/-- **PSBT-003.** A map is accepted only if it has no duplicate raw key,
and a map containing one is rejected.  Core anchor:
`src/psbt.h:1382`.  The exact error constructor is left existential
because key-encoding checks may report first. -/
def oblig_PSBT_003 : Prop :=
  (∀ (l : List UInt8) (kvs : List RawKV) (rest : List UInt8),
    decMapChecked l = .ok (kvs, rest) → findDuplicate kvs = none) ∧
  (∀ (kvs : List RawKV) (k : ByteArray),
    MapWireOK kvs → findDuplicate kvs = some k →
      ∃ e : PsbtError, decMapChecked (encMapL kvs) = .error e)

/-- **PSBT-004.** An accepted v0 global map has an unsigned transaction
with no witness data and no non-empty input scriptSig.  Core anchor:
`src/psbt.h:1403`.  Does not claim script validity of the unsigned
transaction. -/
def oblig_PSBT_004 : Prop :=
  ∀ (kvs : List RawKV) (g : Global),
    parseGlobal kvs = .ok g →
      hasWitness g.unsignedTx = false ∧
        ∀ ti : TxIn, ti ∈ g.unsignedTx.vin → ti.scriptSig.bytes.isEmpty

/-- **PSBT-005.** A v0 parse succeeds only when
`PSBT_GLOBAL_UNSIGNED_TX` is present.  Core anchor:
`src/psbt.h:1517`.  Does not claim the unsigned transaction is spendable. -/
def oblig_PSBT_005 : Prop :=
  ∀ (kvs : List RawKV) (g : Global),
    parseGlobal kvs = .ok g →
      valueOfType GLOBAL_UNSIGNED_TX kvs ≠ none

/-- **PSBT-006.** A v0 parse accepts no v2-only global field.  Core
anchor: `src/psbt.h:1521`.  Does not claim that a file declaring v2 is
otherwise well formed, because the committed model decodes v0 only. -/
def oblig_PSBT_006 : Prop :=
  ∀ (kvs : List RawKV) (g : Global),
    parseGlobal kvs = .ok g →
      valueOfType GLOBAL_TX_VERSION kvs = none ∧
        valueOfType GLOBAL_FALLBACK_LOCKTIME kvs = none ∧
        valueOfType GLOBAL_INPUT_COUNT kvs = none ∧
        valueOfType GLOBAL_OUTPUT_COUNT kvs = none ∧
        valueOfType GLOBAL_TX_MODIFIABLE kvs = none

/-- **PSBT-007.** A declared global version of 1 is rejected because no
PSBT version 1 exists.  Core anchor: `src/psbt.h:1538`.  Does not claim
how a v2 declaration is handled beyond the rejection stated in PSBT-008. -/
def oblig_PSBT_007 : Prop :=
  checkGlobalVersion
      [(keyOf GLOBAL_VERSION ByteArray.empty, bytesOfList (encU32L 1))] =
    .error (.unsupportedVersion 1)

/-- **PSBT-008.** A v0 decoder rejects a file declaring global version 2;
the v2 map requirements (mandatory TX_VERSION/INPUT_COUNT/OUTPUT_COUNT and
rejection of PSBT_GLOBAL_UNSIGNED_TX) are not modelled.  Core anchor:
`src/psbt.h:1544`.  Only the rejection is claimed. -/
def oblig_PSBT_008 : Prop :=
  ∀ kvs : List RawKV,
    valueOfType GLOBAL_VERSION kvs = some (bytesOfList (encU32L 2)) →
      checkGlobalVersion kvs = .error (.unsupportedVersion 2)

/-- **PSBT-009.** A global xpub entry accepted by the parser has the fixed
78-byte extended-key-plus-version payload.  Core anchor:
`src/psbt.h:1458`.  Internal field validity and the embedded public key
are not interpreted by the model, so those are not claimed. -/
def oblig_PSBT_009 : Prop :=
  ∀ (kvs : List RawKV) (g : Global) (x : XpubEntry),
    parseGlobal kvs = .ok g → x ∈ g.xpubs → x.xpub.size = 78

/-- **PSBT-010.** A non-witness UTXO is projected under type `0x00` as a
full transaction with no witness data.  Core anchor: `src/psbt.h:363`.
Does not claim the transaction is the true prevout of the input. -/
def oblig_PSBT_010 : Prop :=
  ∀ (i : PsbtInput) (u : Tx),
    i.nonWitnessUtxo = some u →
      (keyOf IN_NON_WITNESS_UTXO ByteArray.empty,
        encodeTxNoWitness u) ∈ inputKVs i

/-- **PSBT-011.** A witness UTXO is projected under type `0x01` as a
single `CTxOut`.  Core anchor: `src/psbt.h:366`.  Does not claim the
output matches the spent script or that it is non-null. -/
def oblig_PSBT_011 : Prop :=
  ∀ (i : PsbtInput) (o : TxOut),
    i.witnessUtxo = some o → txOutIsNull o = false →
      (keyOf IN_WITNESS_UTXO ByteArray.empty, serTxOut o) ∈ inputKVs i

/-- **PSBT-012.** Finalizing a non-empty scriptSig or witness clears the
serialized partial signatures, sighash type, redeem/witness scripts, key
paths and taproot signing fields, and preserves the unknown key-value
map.  Core anchor: `src/psbt.h:371`.  The preimage maps are not cleared by
the committed `finalizeInput`, so their suppression is not claimed.  The
unknown map is also deliberately preserved: Core keeps proprietary pairs
after finalization, so signing material stored under a proprietary key is
outside this obligation and can survive. -/
def oblig_PSBT_012 : Prop :=
  ∀ (i : PsbtInput) (scriptSig : ByteArray) (witness : List ByteArray),
    (scriptSig.isEmpty = false ∨ witness.isEmpty = false) →
      (finalizeInput i scriptSig witness).unknown = i.unknown ∧
      entriesOfType IN_PARTIAL_SIG (inputKVs (finalizeInput i scriptSig witness)) = [] ∧
      entriesOfType IN_SIGHASH (inputKVs (finalizeInput i scriptSig witness)) = [] ∧
      entriesOfType IN_REDEEMSCRIPT (inputKVs (finalizeInput i scriptSig witness)) = [] ∧
      entriesOfType IN_WITNESSSCRIPT (inputKVs (finalizeInput i scriptSig witness)) = [] ∧
      entriesOfType IN_BIP32_DERIVATION (inputKVs (finalizeInput i scriptSig witness)) = [] ∧
      entriesOfType IN_TAP_KEY_SIG (inputKVs (finalizeInput i scriptSig witness)) = [] ∧
      entriesOfType IN_TAP_SCRIPT_SIG (inputKVs (finalizeInput i scriptSig witness)) = [] ∧
      entriesOfType IN_TAP_LEAF_SCRIPT (inputKVs (finalizeInput i scriptSig witness)) = [] ∧
      entriesOfType IN_TAP_BIP32_DERIVATION (inputKVs (finalizeInput i scriptSig witness)) = [] ∧
      entriesOfType IN_TAP_INTERNAL_KEY (inputKVs (finalizeInput i scriptSig witness)) = [] ∧
      entriesOfType IN_TAP_MERKLE_ROOT (inputKVs (finalizeInput i scriptSig witness)) = []

/-- **PSBT-013.** A non-empty final scriptSig is projected under type
`0x07` and a non-empty final scriptWitness under type `0x08`.  Core
anchor: `src/psbt.h:510`.  Does not claim the scripts satisfy the spent
output. -/
def oblig_PSBT_013 : Prop :=
  (∀ (i : PsbtInput) (s : ByteArray),
    i.finalScriptSig = some s → s.isEmpty = false →
      (keyOf IN_SCRIPTSIG ByteArray.empty, s) ∈ inputKVs i) ∧
  (∀ (i : PsbtInput) (ws : List ByteArray),
    i.finalScriptWitness = some ws → ws.isEmpty = false →
      (keyOf IN_SCRIPTWITNESS ByteArray.empty,
        bytesOfList (encStackL ws)) ∈ inputKVs i)

/-- **PSBT-014.** A taproot key-path signature is read and written under
type `0x13` as a 64- or 65-byte value.  Core anchor:
`src/psbt.h:787`.  Does not claim the signature is valid or that the
sighash byte is consistent with the input's declared type. -/
def oblig_PSBT_014 : Prop :=
  (∀ (kvs : List RawKV) (i : PsbtInput) (s : ByteArray),
    parseInput kvs = .ok i → i.tapKeySig = some s →
      s.size = 64 ∨ s.size = 65) ∧
  (∀ (i : PsbtInput) (s : ByteArray),
    i.tapKeySig = some s → (s.size = 64 ∨ s.size = 65) →
      (keyOf IN_TAP_KEY_SIG ByteArray.empty, s) ∈ inputKVs i)

/-- **PSBT-015.** A taproot script-path signature uses a 64-byte key made
of the x-only public key followed by the leaf hash, under type `0x14`.
Core anchor: `src/psbt.h:432`.  Does not claim the leaf hash matches a
tree leaf or that the signature verifies. -/
def oblig_PSBT_015 : Prop :=
  (∀ (kvs : List RawKV) (i : PsbtInput) (e : TapScriptSigEntry),
    parseInput kvs = .ok i → e ∈ i.tapScriptSigs →
      e.xonly.size = 32 ∧ e.leafHash.size = 32) ∧
  (∀ (i : PsbtInput) (e : TapScriptSigEntry),
    e ∈ i.tapScriptSigs →
      (keyOf IN_TAP_SCRIPT_SIG (e.xonly ++ e.leafHash),
        e.signature) ∈ inputKVs i)

/-- **PSBT-016.** A taproot leaf script is projected under type `0x15`
with the control block as key and the script followed by its leaf version
as value.  Core anchor: `src/psbt.h:440`.  Does not claim the control
block commits to the leaf or that the leaf version is valid. -/
def oblig_PSBT_016 : Prop :=
  ∀ (i : PsbtInput) (e : TapLeafEntry),
    e ∈ i.tapLeafScripts →
      (keyOf IN_TAP_LEAF_SCRIPT e.controlBlock,
        encTapLeafValue e.script e.leafVersion) ∈ inputKVs i

/-- **PSBT-017.** A taproot BIP32 derivation uses a 32-byte x-only key
and a value holding the leaf-hash set followed by the key origin.  Core
anchor: `src/psbt.h:450`.  Does not claim the origin's fingerprint or
path is correct for the key. -/
def oblig_PSBT_017 : Prop :=
  (∀ (kvs : List RawKV) (i : PsbtInput) (e : TapBip32Entry),
    parseInput kvs = .ok i → e ∈ i.tapBip32Derivation →
      e.xonly.size = 32) ∧
  (∀ (i : PsbtInput) (e : TapBip32Entry),
    e ∈ i.tapBip32Derivation →
      (keyOf IN_TAP_BIP32_DERIVATION e.xonly,
        encTapBip32Value e.leafHashes e.origin) ∈ inputKVs i)

/-- **PSBT-018.** A taproot output tree value is rejected when empty, and
every accepted tree has at least one leaf record.  Core anchor:
`src/psbt.h:1162`.  The committed parser does not check the depth bound,
the `TAPROOT_LEAF_MASK` bits, or builder completeness, so those clauses
are not claimed. -/
def oblig_PSBT_018 : Prop :=
  ∀ (v : ByteArray) (tree : List (Nat × Nat × ByteArray)),
    parseTapTree v = .ok tree → v.isEmpty = false ∧ tree ≠ []

/-- **PSBT-029.** Extraction succeeds exactly when every input is
signed, and its result is the unsigned transaction with each input's
final scriptSig and witness stack filled in.  Core anchor:
`src/psbt.cpp:832`.  The `FinalizePSBT` signing step that precedes
extraction is not modelled, so a failed finalization is not claimed. -/
def oblig_PSBT_029 : Prop :=
  (∀ p : Psbt, allInputsSigned p = true →
    extract p = some (fillTx p.global.unsignedTx p.inputs)) ∧
  (∀ p : Psbt, allInputsSigned p = false → extract p = none)

/-! ## SPEND ARITHMETIC -/

/-- **WSP-014.** Change is created exactly when the residual reaches the
minimum viable change; below that threshold no change output is produced.
Core anchor: `src/wallet/coinselection.cpp:1043-1060` and
`src/wallet/spend.cpp:1259-1271`.  Does not claim the separate dust check
or the random output position. -/
def oblig_WSP_014 : Prop :=
  ∀ (inputs outputs : List Amount) (feeNeeded minViableChange : Amount),
    (minViableChange ≤ total inputs - total outputs - feeNeeded →
      (fundWithChange inputs outputs feeNeeded minViableChange).change =
        some (total inputs - total outputs - feeNeeded)) ∧
    (total inputs - total outputs - feeNeeded < minViableChange →
      (fundWithChange inputs outputs feeNeeded minViableChange).change = none)

/-- **WSP-021.** Minimum viable change is the larger of one satoshi above
the discard-rate cost of spending change and the change output's dust
threshold.  Core anchor: `src/wallet/spend.cpp:1192-1193`.  Does not claim
how the discard rate or dust threshold is obtained. -/
def oblig_WSP_021 : Prop :=
  ∀ (discardRate : FeeRate) (changeSpendVsize : Nat)
      (changeDust : Amount),
    minViableChange discardRate changeSpendVsize changeDust =
      max (discardRate.getFee changeSpendVsize + 1) changeDust

/-- **WSP-025.** Subtract-fee-from-outputs divides the reduction equally
over the flagged recipients, with the remainder charged to the first one,
so the total reduction is exactly the requested fee.  Core anchor:
`src/wallet/spend.cpp:1357-1394`.  Does not claim that every reduced
output stays above dust, nor Core's negative-`to_reduce` overpay branch. -/
def oblig_WSP_025 : Prop :=
  ∀ (outputs : List Amount) (flags : List Bool) (fee : Amount) (k : Nat),
    feeShares fee (k + 1) =
        (fee - (k : Amount) *
          (fee / ((k + 1 : Nat) : Amount))) ::
          List.replicate k (fee / ((k + 1 : Nat) : Amount)) ∧
      (0 < countTrue flags →
        flags.length ≤ outputs.length →
          total (subtractFeeFromOutputs outputs flags fee) =
            total outputs - fee)

/-- **WSP-029.** Both funding modes conserve value: inputs equal outputs
plus the recorded fee, and the SFFO mode conserves when at least one
recipient is flagged and every flag has an output.  Core anchor:
`src/wallet/spend.cpp:1348-1400` and `:1255-1400`.  Does not claim
non-negative fees without an explicit coverage hypothesis, nor the
consensus validity of the resulting transaction. -/
def oblig_WSP_029 : Prop :=
  ∀ (inputs outputs : List Amount) (feeNeeded minViableChange : Amount),
    (fundWithChange inputs outputs feeNeeded minViableChange).Conserves ∧
      ∀ (flags : List Bool),
        0 < countTrue flags →
          flags.length ≤ outputs.length →
            (fundSubtractFee inputs outputs flags feeNeeded
              minViableChange).Conserves

/-! ## Rows without an obligation declaration

Ten census rows are graded `theorem` but have no `oblig_` declaration
because the committed wallet models expose no API for their sentence.
They stay `no obligation: unmodelled` in
`spec/db/rules-wallet.obligations.tsv`; none is replaced by a vacuous
`True` or by a predicate invented here.  Core anchors are line numbers
in the pinned tree `cce32b168`.

* **MS-019** — `andor` is not a constructor of
  `Bitcoin.Wallet.Miniscript.Node`; anchor `script/miniscript.cpp:206`.
* **MS-031** — no `Ops`/`CheckOpsLimit` in
  `Bitcoin.Wallet.Miniscript.Satisfy`; anchor `script/miniscript.h:1573`.
* **MS-032** — no `StackSize`/`CheckStackSize` in the same module;
  anchor `script/miniscript.h:1595`.
* **MS-033** — satisfaction records only `none`/`some`, with no
  `malleable` or `has_sig`; anchor `script/miniscript.h:1709`.
* **MS-035** — no Miniscript `FromString` parser; anchor
  `script/miniscript.h:1901`.
* **PSBT-023** — no `PartiallySignedTransaction::Merge`; anchor
  `psbt.cpp:42`.
* **PSBT-024** — no `PSBTInput::Merge`; anchor `psbt.cpp:420`.
* **PSBT-025** — no `AddInput`; `checkUtxos` does not test duplicate
  prevouts; anchor `psbt.cpp:169`.
* **PSBT-026** — PSBT v2 excluded, no `ComputeTimeLock`; anchor
  `psbt.cpp:92`.
* **PSBT-027** — PSBT v2 excluded, no `GetUnsignedTx`; anchor
  `psbt.cpp:134`.
-/

end BitcoinProofs.Wallet
