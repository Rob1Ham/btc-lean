---
# Cell policy-flags/C-L-strictenc-pubkey
cell: C-L-strictenc-pubkey
family: policy-flags
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic predicate over the declared domain)
consensus: false
precondition: |
  - Scope: `CheckPubKeyEncoding` (interpreter.cpp:227-237), the STRICTENC
    branch only (:229-231), and its callee
    `IsCompressedOrUncompressedPubKey` (:74-94).
  - flags is an arbitrary 64-bit script_verify_flags word; the cell reads
    STRICTENC (0x2) and nothing else.
  - The pubkey is modelled by the only two facts its encoding check reads:
    its length (0 .. 2**64-1) and its first byte (masked to 0 .. 255).
  - SigVersion is not read by the STRICTENC branch (Core passes it only for the
    WITNESS_PUBKEYTYPE branch), so it is not an input.
  - The signature-encoding half of STRICTENC (hashtype, CheckSignatureEncoding
    :219-223) is a different table entry and is not exercised here.
postcondition: |
  - STRICTENC set and the pubkey is neither (0x04 + 64 bytes) nor
    (0x02/0x03 + 32 bytes)                -> 29 SCRIPT_ERR_PUBKEYTYPE
    otherwise                             -> 0
  - Exact truth table (len, first byte):
      len < 33                              -> error
      first byte 0x04, len != 65            -> error
      first byte 0x02 or 0x03, len != 33    -> error
      any other first byte                  -> error
      first byte 0x04 and len == 65         -> pass
      first byte 0x02 or 0x03 and len == 33 -> pass
    and, with STRICTENC clear, every (len, byte) passes.
scr_rows: SCR-176
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
  - "interpreter.cpp:74-94 (IsCompressedOrUncompressedPubKey)"
  - "interpreter.cpp:227-237 (CheckPubKeyEncoding; STRICTENC branch :229-231)"
  - "src/pubkey.h (CPubKey::COMPRESSED_SIZE=33, CPubKey::SIZE=65)"
  - "src/script/interpreter.h:56-60 (STRICTENC is \"(not used or intended as a consensus rule)\")"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets STRICTENC)"
  - "src/policy/policy.h:118-133 (STRICTENC is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:382-387 (isCompressedOrUncompressedPubKey)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:398-403 (checkPubKeyEncoding)"
  - "contract/error_enum.md:75 (29 SIG_PUBKEYTYPE)"

trust_note: >
  C is a line-cited source excerpt of interpreter.cpp at the pin, restricted to
  the two functions the row names; it is not the whole EvalScript.  L is a
  REVIEWED TRANSLITERATION of Bitcoin.Interpreter.isCompressedOrUncompressedPubKey
  and checkPubKeyEncoding (Defs.lean:382-403), not generated from
  twin/ops_ir.py.  No crypto, hash or signature check is involved, so no
  same-crypto premise is needed.  No Core patch is used.
scope: |
  FULL for SCR-176 as cited (:74-94, :229-231): the pubkey-encoding predicate
  is total over (flag word, length, first byte), which is exactly the domain the
  check reads.  The hashtype half of the STRICTENC flag (in
  CheckSignatureEncoding) is a different rule and is not part of this row.
---

## What this cell proves

`CheckPubKeyEncoding` rejects a hybrid/unknown pubkey encoding *only* when the
STRICTENC policy bit is set.  The cell proves the total predicate over
(flags, pubkey length, pubkey first byte) and shows the flag is the only gate:
with STRICTENC clear every encoding passes, with it set exactly the
0x04/65-byte and 0x02-or-0x03/33-byte forms pass.  Consensus status is a source
fact: STRICTENC is not in `GetBlockScriptFlags` and is not in
MANDATORY_SCRIPT_VERIFY_FLAGS.


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
sets STRICTENC, and interpreter.h:56-60 documents it as "(not used or intended
as a consensus rule)".  STRICTENC is in STANDARD_SCRIPT_VERIFY_FLAGS
(policy.h:118-133) and absent from MANDATORY_SCRIPT_VERIFY_FLAGS.  A
hybrid-pubkey spend is therefore policy-invalid, not consensus-invalid.

