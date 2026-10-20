---
# Cell checksig/C-L-checksig-policy
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: pinned rbitcoin shim has no typed ScriptError and rejects flags != 0 (F-HARNESS-002)"
cell: checksig/C-L-checksig-policy
family: checksig
tool_status: both-green
precondition: |
  - Hashtype byte: `last` is the final byte of the signature (0..255; the
    cell masks it to the byte domain exactly as Core's unsigned char does),
    `n` is the signature length (0 = empty), `strictEnc` is the STRICTENC
    policy bit.
  - Pubkey encoding: `n` is the pubkey length, `pk0` its first byte,
    `strictEnc`/`witnessPubkeyType` are policy bits, `sv` is the SigVersion
    (0 = BASE, 1 = WITNESS_V0).
  - All inputs are fully symbolic; no transaction context and no checker call.
postcondition: |
  - cell_is_defined_hashtype(last,n) = 1 iff n > 0 and (last & 0x7f) in
    {1,2,3}; the SIGHASH_ANYONECANPAY bit (0x80) is masked out.
  - cell_hashtype_gate(strictEnc,last,n) = 0, or SIG_HASHTYPE = 23 iff
    strictEnc and the hashtype is not defined.
  - cell_pubkey_predicates(n,pk0) packs bit0 = IsCompressedOrUncompressedPubKey
    and bit1 = IsCompressedPubKey:
      bit0: n >= 33, and (pk0=0x04 and n=65) or (pk0 in {0x02,0x03} and n=33);
      bit1: n = 33 and pk0 in {0x02,0x03}.
  - cell_pubkey_encoding(strictEnc,witnessPubkeyType,sv,n,pk0) = 0, or
    PUBKEYTYPE = 29 iff STRICTENC and bit0 is false, or
    WITNESS_PUBKEYTYPE = 44 iff the WITNESS_PUBKEYTYPE policy bit is set,
    sv = WITNESS_V0, and bit1 is false.  STRICTENC is checked first.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-105, SCR-106, SCR-107
scr_row_coverage: full
coverage: full
patches: none
source_citations:
  - "src/script/interpreter.cpp:200-209@cce32b168 (IsDefinedHashtypeSignature)"
  - "src/script/interpreter.cpp:211-224@cce32b168 (STRICTENC hashtype arm)"
  - "src/script/interpreter.cpp:74-92@cce32b168 (IsCompressedOrUncompressedPubKey)"
  - "src/script/interpreter.cpp:94-106@cce32b168 (IsCompressedPubKey)"
  - "src/script/interpreter.cpp:226-235@cce32b168 (CheckPubKeyEncoding)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:365-405 (isDefinedHashtype, isCompressedOrUncompressedPubKey, isCompressedPubKey, checkPubKeyEncoding)"
  - "contract/error_kind.h:58,64,83 (SIG_HASHTYPE=23, PUBKEYTYPE=29, WITNESS_PUBKEYTYPE=44)"
trust_note: >
  No crypto seam: the hashtype predicate and the pubkey *encoding* predicates
  are total structural functions over length and prefix byte; they do not
  parse the curve point, so the cell is not conditional on same-crypto.
  (Whether a well-encoded key is on the curve is the checker's business and
  belongs to SCR-112.)  The C leg is a line-cited slice of pinned
  interpreter.cpp; the L leg is a reviewed transliteration of the Lean
  Defs.lean predicates.  Alive2 proves C ≡ L over all symbolic lengths,
  bytes, policy bits, and sigversions; SAW proves each leg against the
  independent Cryptol predicate in saw/policy.cry.  The LOW_S arm of
  CheckSignatureEncoding is a separate cell (checksig/C-L-checksig-lows).
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - saw/policy.cry (independent Cryptol predicate)
mutant: "treat 0x81 as defined, accept a 65-byte 0x02 key, or apply WITNESS_PUBKEYTYPE at BASE; Alive2 and SAW must both fail"
mutant_site: "findings/wave16/10-checksig-policy/tools/{c,l}_policy.cpp"
---

# checksig/C-L-checksig-policy

Full structural policy predicates for the legacy/segwit-v0 signature path:
the hashtype-byte rule (SCR-105), the 33/65-byte pubkey encoding rule
(SCR-106), and the compressed-only rule for v0 witness pubkeys (SCR-107),
including the exact error ordinals (23, 29, 44) and the STRICTENC-before-
WITNESS_PUBKEYTYPE order.  No checker call, so no same-crypto premise.
