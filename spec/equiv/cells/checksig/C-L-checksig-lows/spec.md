---
# Cell checksig/C-L-checksig-lows
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: pinned rbitcoin shim has no typed ScriptError and rejects flags != 0 (F-HARNESS-002)"
cell: checksig/C-L-checksig-lows
family: checksig
tool_status: both-green
precondition: |
  - `lowS` is the LOW_S policy bit (Core SCRIPT_VERIFY_LOW_S / Lean
    pol.lowS).
  - The signature's S scalar is supplied as four little-endian 64-bit limbs
    (s0 lowest).  Domain: the scalar is canonical, s < n, i.e. the signature
    already passed BIP66 strict DER (cell C-L-checksig-der) and the ECDSA
    compact parser did not hit its overflow window.  The s >= n reduction
    window of `ecdsa_signature_parse_der_lax` is OUTSIDE this cell.
  - No checker call, no transaction context.
postcondition: |
  - cell_lows_gate(lowS, s0..s3) = 0 when LOW_S is off.
  - When LOW_S is on: 0 iff s <= floor(n/2), else SIG_HIGH_S = 27
    (Core IsLowDERSignature -> CPubKey::CheckLowS ->
    secp256k1_ecdsa_signature_normalize; Lean isLowDERSignature s % n <= n/2).
  - floor(n/2) = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-104
scr_row_coverage: partial
coverage: partial
patches: none
source_citations:
  - "src/script/interpreter.cpp:183-198@cce32b168 (IsLowDERSignature)"
  - "src/script/interpreter.cpp:211-224@cce32b168 (CheckSignatureEncoding LOW_S arm)"
  - "src/pubkey.cpp:393-399@cce32b168 (CPubKey::CheckLowS)"
  - "spec/core/Bitcoin/Crypto/Ecdsa/Der.lean:203-215 (halfN, isLowDERSignature)"
  - "contract/error_kind.h:62 (EQUIV_ERR_SIG_HIGH_S = 27)"
trust_note: >
  No crypto seam in the modelled comparison: s <= n/2 is a 256-bit integer
  compare, proved over all symbolic limbs.  The cell does NOT model how the
  S scalar is extracted from the DER blob, nor the lax parser's s >= n
  overflow/reduction window; both are named as remaining coverage below, so
  the row stays partial.  The L leg is a reviewed transliteration of
  Der.lean isLowDERSignature under the canonical-scalar domain (s % n = s).
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - saw/policy.cry (independent Cryptol predicate)
mutant: "use n-1 instead of floor(n/2), or reverse the comparison; Alive2 and SAW must both fail"
mutant_site: "findings/wave16/10-checksig-policy/tools/{c,l}_policy.cpp"
---

# checksig/C-L-checksig-lows

LOW_S dispatch and the exact 256-bit `s <= floor(n/2)` comparison, over
symbolic S limbs.  **Partial**: the lax-DER S extraction and the `s >= n`
overflow/reduction window (the SGN-107 seam from
`docs/DECISION-lax-ecdsa.md`) remain outside the cell, so SCR-104 is not
claimed complete.
