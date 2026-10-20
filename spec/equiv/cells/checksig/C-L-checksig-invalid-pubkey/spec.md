---
# Cell checksig/C-L-checksig-invalid-pubkey
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: pinned rbitcoin shim has no typed ScriptError and rejects flags != 0 (F-HARNESS-002)"
cell: checksig/C-L-checksig-invalid-pubkey
family: checksig
tool_status: both-green
precondition: |
  - `pk_valid` is the result of `CPubKey::IsValid()` after `CPubKey
    pubkey(vchPubKey)`, as a symbolic 0/1 input.  `CPubKey::Set` is
    structural (33-byte 02/03 or 65-byte 04/06/07 encoding), so this cell
    does not model the byte-level parse.
  - `crypto_ok` is the abstract EC verdict used only when `pk_valid != 0`
    (same-crypto premise, docs/DECISION-lax-ecdsa.md).
  - `sig_len` is the signature length (0 = empty), `nullFail` the NULLFAIL
    policy bit; both symbolic.
postcondition: |
  - The checker result is `pk_valid ? crypto_ok : 0`: an invalid pubkey
    makes `CheckECDSASignature` return false before any EC work, for every
    value of `crypto_ok`.
  - `cell_invalid_pubkey`: with NULLFAIL off (or an empty signature) the
    false is pushed: 264 (result 0, EVAL_FALSE = 2, depth 1, empty top) when
    the checker failed, 10497 (true, depth 1) when it succeeded.  With
    NULLFAIL on and a non-empty signature the failed check returns 128
    (error 32) before the push.
  - `cell_invalid_pubkey_continue`: the same CHECKSIG followed by OP_NOT, so
    the script continues; a failed invalid-key check yields a true final
    stack (10497), while a successful check yields the false element
    retained on top (2312: EVAL_FALSE, depth 1, top length 1, value 0).
  - C and L agree on every input in the domain, in both directions.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-112
scr_row_coverage: partial
coverage: partial
patches: none
source_citations:
  - "src/script/interpreter.cpp:1704-1706@cce32b168 (CheckECDSASignature: pubkey construction and IsValid false)"
  - "src/script/interpreter.cpp:331-369@cce32b168 (EvalChecksigPreTapscript; NULLFAIL 351-352)"
  - "src/script/interpreter.cpp:1069-1092@cce32b168 (OP_CHECKSIG / OP_CHECKSIGVERIFY)"
  - "src/script/interpreter.cpp:1876-1880@cce32b168 (EVAL_FALSE tail)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:720-742 (evalChecksigPreTapscript)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1033-1047 (stepBody CHECKSIG arm)"
  - "contract/error_kind.h:67 (EQUIV_ERR_SIG_NULLFAIL = 32)"
trust_note: >
  The invalid-key implication needs no crypto agreement: `CPubKey::IsValid()`
  is structural and the pinned checker returns false on it before the EC
  call, so the cell proves the pushed-false/continuation result for every
  `crypto_ok`.  The cell is nonetheless labelled partial because (a) the
  byte-level `CPubKey::Set`/`IsValid` parse is an unconstrained input, not a
  computed predicate, (b) the valid-key branch depends on the abstract EC
  verdict (same-crypto premise), and (c) there is no R leg.  It supplements
  the existing e3-checksig/C-L-checksig-dispatch cell rather than editing it
  (that cell is outside this task's write scope).  The C leg is a line-cited
  slice of pinned Core; the L leg is a reviewed transliteration of the Lean
  seam and CHECKSIG arm.  Alive2 proves C ≡ L in both directions over all
  symbolic inputs; SAW proves each leg against an independent Cryptol
  predicate.  Tool-ingestion note: Alive2 v20 rejects TBAA/alias.scope
  attached metadata in this shape, so the runner strips those optimizer hints
  from both legs identically before comparison.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - saw/invalidpubkey.cry (independent Cryptol predicate)
mutant: "let the EC result override an invalid pubkey, or skip the NULLFAIL guard for a non-empty signature; Alive2 and SAW must both fail"
mutant_site: "findings/wave16/10-checksig-policy/tools/{c,l}_invalidpubkey.cpp"
---

# checksig/C-L-checksig-invalid-pubkey

SCR-112: an invalid pubkey makes `CheckECDSASignature` return false before
the EC check, so `OP_CHECKSIG` pushes false and a surrounding block continues
(OP_NOT witness).  **Partial**: the structural `CPubKey::IsValid` parse is an
input, the valid-key branch rides the abstract EC verdict, and there is no R
leg; the existing `e3-checksig/C-L-checksig-dispatch` cell remains the ledger
anchor for the row.
