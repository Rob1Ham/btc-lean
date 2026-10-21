---
# Cell checksig/C-L-checksig-pubkey-encoding
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 76dbfe5
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: pinned rbitcoin shim has no typed ScriptError and rejects flags != 0 (F-HARNESS-002)"
cell: checksig/C-L-checksig-pubkey-encoding
family: checksig
tool_status: both-green
precondition: |
  - The pubkey is represented by the only two fields every predicate below
    reads: `hdr`, the first byte (i8, so exactly 0..255), and `len`, the
    vector length.  The payload bytes are not read by `CPubKey::Set`,
    `CPubKey::ValidSize`, `IsCompressedOrUncompressedPubKey`,
    `IsCompressedPubKey`, or `CheckPubKeyEncoding`, so omitting them is
    behavior-preserving for this slice; no EC or sighash property is claimed.
  - `strict_enc` is `flags & SCRIPT_VERIFY_STRICTENC` (Lean
    `pol.strictEnc`); `witness_pubkey_type` is
    `flags & SCRIPT_VERIFY_WITNESS_PUBKEYTYPE` (Lean
    `pol.witnessPubkeyType`); `sv = 1` means `SigVersion::WITNESS_V0` and
    `sv = 0` means `SigVersion::BASE`.
  - The signature is assumed to pass `CheckSignatureEncoding`: empty, or a
    valid DER encoding whose hashtype is accepted for the active flags.  The
    cell therefore isolates the pubkey-encoding gate and does not re-prove
    SCR-105/108/109.
  - `sig_len` is the full signature length including the trailing hashtype
    byte.  `crypto_ok` is the abstract ECDSA verification verdict (same-crypto
    premise, docs/DECISION-lax-ecdsa.md).
  - Block/default policy is the instantiation `strict_enc = 0`,
    `witness_pubkey_type = 0`, `null_fail = 0`.  Policy STRICTENC is
    `strict_enc = 1`; v0 policy WITNESS_PUBKEYTYPE is
    `witness_pubkey_type = 1` with `sv = 1`.
postcondition: |
  - `cell_pubkey_encoding` computes Core's `CheckPubKeyEncoding` from the raw
    fields: pass (1), `PUBKEYTYPE` = 29 under STRICTENC, or
    `WITNESS_PUBKEYTYPE` = 44 under v0 WITNESS_PUBKEYTYPE.  The C and L
    predicates agree on every `(hdr, len)` pair in the domain.
  - `cell_pubkey_encoding_checksig` computes
    `EvalChecksigPreTapscript` + `OP_CHECKSIG` + the EVAL_FALSE tail:
    - an encoding abort returns the exact error ordinal before the checker;
    - otherwise the checker is `validSize(hdr,len) ? (sig_len != 0 &&
      crypto_ok != 0) : false`, exactly Core's `CheckECDSASignature` order
      (CPubKey gate at interpreter.cpp:1704-1706, empty-sig false at
      :1708-1709);
    - a false verdict with `null_fail != 0` and a non-empty signature returns
      `SIG_NULLFAIL` = 32; otherwise false is pushed and the EVAL_FALSE tail
      reports 264 (result 0, error 2, depth 1, empty top);
    - a true verdict reports 10497.
  - `cell_pubkey_encoding_continue` appends one `OP_NOT`: a false CHECKSIG
    verdict yields a true final stack (10497), i.e. the block continues; a
    true verdict yields the false element retained on top (2312).
  - The block-mode invalid-key instantiation is the SCR-112 core claim:
    `hdr = 0x02, len = 1, strict_enc = 0, witness_pubkey_type = 0, sv = 0,
    sig_len != 0, null_fail = 0` -> 264 (or 10497 through OP_NOT), for every
    `crypto_ok`, because `CPubKey::ValidSize` rejects the length.
  - The policy-mode instantiations are the SCR-106/107 face, kept distinct:
    the same key with `strict_enc = 1` aborts with 29 before the checker; a
    65-byte uncompressed key with `sv = 1, witness_pubkey_type = 1` aborts
    with 44.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-112
scr_row_coverage: partial
coverage: partial
patches: none
source_citations:
  - "src/pubkey.h:69-76@cce32b168 (CPubKey::GetLen)"
  - "src/pubkey.h:86-88@cce32b168 (CPubKey::ValidSize)"
  - "src/pubkey.h:98-105@cce32b168 (CPubKey::Set: accept iff ValidSize)"
  - "src/pubkey.h:194-197@cce32b168 (CPubKey::IsValid)"
  - "src/script/interpreter.cpp:74-99@cce32b168 (IsCompressedOrUncompressedPubKey, IsCompressedPubKey)"
  - "src/script/interpreter.cpp:228-237@cce32b168 (CheckPubKeyEncoding)"
  - "src/script/interpreter.cpp:331-356@cce32b168 (EvalChecksigPreTapscript, NULLFAIL 351-352)"
  - "src/script/interpreter.cpp:1069-1092@cce32b168 (OP_CHECKSIG / OP_CHECKSIGVERIFY)"
  - "src/script/interpreter.cpp:1701-1724@cce32b168 (CheckECDSASignature)"
  - "src/script/interpreter.cpp:1876-1880@cce32b168 (EVAL_FALSE tail)"
  - "spec/core/Bitcoin/Crypto/EcdsaDeep/PubKeyParse.lean:123-136 (pubKeyLen, validPubKeySize)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:382-403 (isCompressedOrUncompressedPubKey, isCompressedPubKey, checkPubKeyEncoding)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:720-742 (evalChecksigPreTapscript)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1033-1047 (stepBody CHECKSIG arm)"
  - "contract/error_kind.h: EVAL_FALSE=2, PUBKEYTYPE=29, SIG_NULLFAIL=32, WITNESS_PUBKEYTYPE=44"
trust_note: >
  **partial — the L leg is the F-DIV-004 remediation target, not the pinned
  seam predicate.**  The C leg computes the exact byte-level
  `CPubKey::ValidSize`/`CheckPubKeyEncoding` from `(hdr, len)`.  The L leg is
  a reviewed transliteration of the pinned Lean definitions, but at the
  ECDSA gate it uses `Bitcoin.Crypto.EcdsaDeep.PubKeyParse.validPubKeySize`
  (the size-exact port of `CPubKey::ValidSize`, PubKeyParse.lean:135-136),
  NOT `Bitcoin.Crypto.Seam.Der.isValidPubKey` (Der.lean:175), which is
  header-only and remains the open divergence.  Therefore this cell proves
  that the intended/fixed gate is behavior-preserving against Core under the
  exact encoding rules; it cannot promote SCR-112 while the pinned
  `Seam/Entry.ecdsaVerdict` still calls the header-only predicate.  The
  companion probe in findings/wave65/13-scr-112/probe/ runs the pinned
  header-only predicate against the same C slice and exhibits the
  counterexample (`hdr=0x02, len=1, strict_enc=0, crypto_ok=1`).  The valid
  EC verdict is an input (same-crypto premise); no EC/sighash property is
  claimed; there is no R leg.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - saw/pk_encoding.cry (independent Cryptol predicate)
mutant: "use the header-only `pub_key_len != 0` gate (drop the length equality), or let an invalid encoding reach the checker / skip the NULLFAIL or encoding abort; Alive2 and SAW must both fail"
mutant_site: "spec/equiv/findings/wave65/13-scr-112/probe/l_pinned_probe.cpp (the header-only mutant is run as a live counterexample, not a green cell)"
---

# checksig/C-L-checksig-pubkey-encoding

**partial — SCR-112 stays `gap` until F-DIV-004 is fixed in the Lean seam.**

This cell closes the gap that the wave64 report named: the earlier
`checksig/C-L-checksig-invalid-pubkey` cell takes `pk_valid` as an
unconstrained input, so it cannot say which byte strings are invalid.  Here
both legs compute the predicate from the raw `(header byte, length)` pair and
then walk `CheckPubKeyEncoding` → `CheckECDSASignature` → `OP_CHECKSIG`.

What the cell shows, all over symbolic inputs and in both directions:

1. **Block flags (the SCR-112 consensus arm).** For a size-invalid key such
   as `hdr = 0x02, len = 1` with `strict_enc = witness_pubkey_type =
   null_fail = 0`, `CPubKey::ValidSize` is false, the checker is false for
   every `crypto_ok`, `OP_CHECKSIG` pushes false (264) and the script
   continues (`OP_NOT` witness → 10497).
2. **Policy STRICTENC (SCR-106).** The same key with `strict_enc = 1` aborts
   with `PUBKEYTYPE` = 29 *before* the checker; no push happens.
3. **Policy WITNESS_PUBKEYTYPE (SCR-107).** A 65-byte uncompressed key
   (`hdr = 0x04, len = 65`) under `sv = witnessV0` with
   `witness_pubkey_type = 1` aborts with `WITNESS_PUBKEYTYPE` = 44.
4. **NULLFAIL is a separate policy gate**: an invalid key with a non-empty
   signature and `null_fail = 1` returns `SIG_NULLFAIL` = 32 rather than
   pushing false.  Block validation never sets it through the consensus
   `ScriptFlags` path.

The behaviour split in (1) vs (2)/(3) is exactly the row text: the abort is
policy, the false-and-continue is consensus.

## Why this cannot be "both-green" for SCR-112

The pinned Lean `Seam/Entry.ecdsaVerdict` calls `Der.isValidPubKey`, which is
`pubKeyLen pk ≠ 0` — a header-only predicate that accepts `[0x02]`.
`validPubKeySize` exists one layer down and is not used at the gate.  The L
leg here deliberately uses the size-exact predicate, so the cell demonstrates
the *post-fix* behaviour and a concrete route to closure, while the live
divergence is kept open in the findings probe and in F-DIV-004.  The cell is
labelled `partial`, the ledger row keeps its `gap` status, and no existing
cell or proof is edited.

## What is not claimed

- No ECDSA/Schnorr/sighash semantics: `crypto_ok` is an input.
- No payload-byte parse beyond the header and length (neither Core predicate
  reads more).
- No R leg.
- No full block replay: the continuation is an `OP_NOT` slice, matching the
  existing invalid-pubkey cell's convention.
- No claim that the pinned `Seam/Entry.ecdsaVerdict` currently passes this
  cell; it does not (see the probe).
