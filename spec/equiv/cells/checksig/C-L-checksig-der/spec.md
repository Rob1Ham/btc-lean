---
# Cell checksig/C-L-checksig-der
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: pinned rbitcoin shim has no typed ScriptError and rejects flags != 0 (F-HARNESS-002); Alive2 v20 cannot ingest the LLVM 22 R module (F-TOOL-001)"
cell: checksig/C-L-checksig-der
family: checksig
tool_status: both-green
precondition: |
  - The signature is an arbitrary byte string of length n, n in [0, 2^32),
    carried as 80 bytes in ten 64-bit little-endian words (byte i is
    (w[i/8] >> 8*(i%8)) & 0xff).  All 673 bits are symbolic in both tools.
  - Flags are symbolic booleans: `dersig` (SCRIPT_VERIFY_DERSIG),
    `lowS` (LOW_S policy word), `strictEnc` (STRICTENC policy word).  The
    function under test is only CheckSignatureEncoding's DER arm; the
    LOW_S and STRICTENC arms are other rows and are not entered.
  - No transaction context, no sighash byte interpretation beyond being the
    final byte of the encoding, no checker call.
  - Loop-free; both legs are total functions of their arguments.
postcondition: |
  - cell_der(n, bytes) = 1 iff IsValidSignatureEncoding(sig) (strict BIP66
    DER over the byte string including the trailing sighash byte): n in
    [9, 73], sig[0] = 0x30, sig[1] = n-3, canonical short-form integer
    headers, non-negative, minimally padded R and S, exact total length.
    Otherwise 0.
  - cell_der_gate(dersig, lowS, strictEnc, n, bytes) = 0 if n = 0 (the
    empty-signature bypass in CheckSignatureEncoding); else 24
    (EQUIV_ERR_SIG_DER) iff (dersig or lowS or strictEnc) and cell_der = 0;
    else 0.
  - C and L agree on every input in the domain, in both directions.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-102, SCR-108
scr_row_coverage: full
coverage: full
patches: none
source_citations:
  - "src/script/interpreter.cpp:118-181@cce32b168 (IsValidSignatureEncoding)"
  - "src/script/interpreter.cpp:211-224@cce32b168 (CheckSignatureEncoding: empty bypass, DERSIG arm)"
  - "spec/core/Bitcoin/Crypto/Ecdsa/Der.lean:186-211 (isDERSignature)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:373-382 (checkSigEncoding)"
  - "contract/error_kind.h:59 (EQUIV_ERR_SIG_DER = 24)"
trust_note: >
  No crypto seam is used: this cell never calls the ECDSA checker, so it is
  not conditional on same-crypto.  The two legs are (a) a line-cited slice of
  pinned Core interpreter.cpp and (b) a reviewed transliteration of the Lean
  model (Der.lean isDERSignature / Defs.lean checkSigEncoding), not generated
  by twin/gen.py.  Both read the signature through the same 80-byte word
  accessor, a pure data-representation change; every length guard is kept in
  the source order so in-range reads coincide with the original vector reads.
  Alive2 quantifies over the full 673-bit input space; SAW proves each leg
  against an independently written Cryptol predicate.  Tool-ingestion note:
  Alive2 v20 rejects TBAA/alias.scope attached metadata in this shape
  ("Unsupported metadata"), so the runner strips those optimizer hints from
  both legs identically before comparison.  This is bounded-cell evidence,
  not a whole-engine proof and not a Lean-kernel theorem.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - saw/cell.saw, saw/der.cry (independent Cryptol predicate)
mutant: "swap the 9/73 bounds, drop the minimal-padding clause, or return 0 instead of 24 in the gate; Alive2 and SAW must both fail"
mutant_site: "findings/wave16/10-checksig-policy/tools/{c,l}_der.cpp"
---

# checksig/C-L-checksig-der

Full BIP66 strict-DER predicate (SCR-102) over a symbolic 80-byte signature
buffer, plus the `CheckSignatureEncoding` DERSIG arm and the empty-signature
bypass (SCR-108).  Alive2 proves C ≡ L over 673 symbolic bits; SAW proves each leg
against an independent Cryptol restatement of the same rule.  No checker call
is made, so the cell is not conditional on the same-crypto premise.
