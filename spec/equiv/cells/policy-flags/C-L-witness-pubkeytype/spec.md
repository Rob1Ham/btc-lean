---
# Cell policy-flags/C-L-witness-pubkeytype
cell: C-L-witness-pubkeytype
family: policy-flags
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic predicate over the declared domain)
consensus: false
precondition: |
  - Scope: the WITNESS_PUBKEYTYPE branch of `CheckPubKeyEncoding`,
    interpreter.cpp:233-235, and its callee `IsCompressedPubKey` (:96-106).
  - Inputs: an arbitrary 64-bit flag word (WITNESS_PUBKEYTYPE = 0x8000 is
    read), the SigVersion (0 = BASE, 1 = WITNESS_V0, 2 = TAPSCRIPT; other values
    are the cell's out-of-domain guard), the pubkey length and its first byte
    (masked to 0..255).
  - `IsCompressedPubKey` reads only the length (must be 33) and the first byte
    (must be 0x02 or 0x03), so (len, byte0) is its complete input.
  - The STRICTENC branch above it (:229-231) is a different row (SCR-176) and
    is assumed not to have fired; i.e. the cell models the branch order with
    `strictEnc` clear.
postcondition: |
  - WITNESS_PUBKEYTYPE set and SigVersion == WITNESS_V0 and the pubkey is not
    (33 bytes with first byte 0x02 or 0x03)
      -> 44 SCRIPT_ERR_WITNESS_PUBKEYTYPE
  - otherwise -> 0
  Note the gate is `sigversion == WITNESS_V0` only: TAPSCRIPT and BASE do not
  read this bit here, so an uncompressed key is accepted by this check there.
scr_rows: SCR-182
scr_row_coverage: full
coverage: full
patches: none
direction:
  - L ⊑ C
  - C ⊑ L
evidence:
  - alive2/result.txt, alive2/certificate.sha256 (raw alive-tv v20 output, both directions)
  - saw/result.txt, saw/certificate.sha256 (raw SAW 1.6 output, both legs)
  - ir/ (c_leaf.ll, l_leaf.ll, per-root extracted modules, build.txt; tracked, so the
    certificates hash exactly the modules presented to alive-tv/SAW)
  - findings/wave16/13-policy-reimport/tools/concrete_check.out (hand-computed
    behavioural vectors, C leg == L leg == expectation)
source_citations:
  - "interpreter.cpp:94-106 (IsCompressedPubKey: size 33, prefix 0x02/0x03)"
  - "interpreter.cpp:227-237 (CheckPubKeyEncoding; WITNESS_PUBKEYTYPE branch :233-235)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets WITNESS_PUBKEYTYPE)"
  - "src/policy/policy.h:118-133 (WITNESS_PUBKEYTYPE is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:389-391 (isCompressedPubKey)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:398-403 (checkPubKeyEncoding; v0 arm :401-402)"
  - "contract/error_enum.md:88 (44 SIG_WITNESS_PUBKEYTYPE)"

trust_note: >
  C is a line-cited source excerpt of interpreter.cpp:94-106/227-237 at the
  pin; it is not the whole EvalScript.  L is a REVIEWED TRANSLITERATION of
  Bitcoin.Interpreter.isCompressedPubKey and checkPubKeyEncoding
  (Defs.lean:389-403), not generated from twin/ops_ir.py.  No crypto is
  involved: the check is a length/prefix test, not a curve operation.  No Core
  patch is used.
scope: |
  FULL for SCR-182 as cited (:233-235): total over (flag word, sigversion,
  length, first byte), the complete input of the predicate.  The interaction
  with STRICTENC's error precedence is assumed (strictEnc clear) and is SCR-176's
  cell.
---

## What this cell proves

The cell proves the WITNESS_PUBKEYTYPE policy: in a witness-v0 script an
uncompressed or malformed public key is rejected with
SCRIPT_ERR_WITNESS_PUBKEYTYPE (44) when the bit is set, and the bit is consulted
only on the WITNESS_V0 branch, so BASE and TAPSCRIPT is unaffected at this site.
This is the segwit compressed-key policy, not a consensus rule.


## Both-tool evidence

- Alive2 (`alive2/result.txt`): every root compared in **both** directions
  (`alive-tv c_<fn>.ll l_<fn>.ll` for L ⊑ C and `alive-tv l_<fn>.ll c_<fn>.ll`
  for C ⊑ L); all report `Transformation seems to be correct!` /
  `1 correct transformations, 0 incorrect, 0 failed-to-prove`.
- SAW (`saw/result.txt`): every root verified in the C module and in the L
  module against the *same* Cryptol function in `saw/cell.cry`, which is written
  from the row's rule and is independent of both C++ files.
- Both `certificate.sha256` files verify with `sha256sum -c` from the repo root.

## Consensus status

**Not consensus.**  `GetBlockScriptFlags` (validation.cpp:2249-2288) never
sets WITNESS_PUBKEYTYPE, and it is absent from MANDATORY_SCRIPT_VERIFY_FLAGS
(policy.h:104-113); it appears only in STANDARD_SCRIPT_VERIFY_FLAGS.  An
uncompressed key in a P2WPKH/P2WSH spend is relay-invalid, not
consensus-invalid.

