---
# Cell policy-flags/C-L-lows-policy
cell: C-L-lows-policy
family: policy-flags
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic predicate over the declared domain)
consensus: false
precondition: |
  - Scope: `CheckSignatureEncoding` (interpreter.cpp:207-224) on the LOW_S
    branch, including the DER-shape gate that precedes it:
      flags is an arbitrary 64-bit script_verify_flags word;
      DERSIG(0x4), LOW_S(0x8) and STRICTENC(0x2) are read exactly as Core does.
  - Signature domain (bounded, declared): the canonical DER skeleton
      30 25 02 01 <R> 02 20 <S:32> <hashtype>
    i.e. sig.size() == 40, lenR == 1, one-byte R, lenS == 32, 32-byte S.
    The symbolic inputs are the R byte and the four 64-bit big-endian words of
    S.  The empty-signature short circuit (:214-216) is excluded by the
    skeleton (sig.size() == 40).
  - The table of IsValidSignatureEncoding (:118-180) is modelled exactly for
    that skeleton: every other condition is fixed by the skeleton, and the
    three free ones (:149 R positive, :172 S positive, :177 minimal S) are
    computed from the symbolic bytes.
  - SAME-CRYPTO PREMISE: Core's `CPubKey::CheckLowS` (pubkey.h) goes through
    the libsecp DER-lax parse and the `s <= n/2` normalisation check.  The Lean
    model spells the same predicate out as `sval <= SIG_S_HALF_ORDER`
    (Defs.lean:355-362).  This cell proves the Lean/ Core *predicate* equality
    under that premise; it does not prove libsecp256k1.
postcondition: |
  - packed as a single ScriptError ordinal (0 = no error):
      (DERSIG|LOW_S|STRICTENC) set and DER-invalid      -> 24 SCRIPT_ERR_SIG_DER
      else LOW_S set and S > n/2                        -> 27 SCRIPT_ERR_SIG_HIGH_S
      else                                              -> 0
    where DER-valid means R < 0x80 && S[0] < 0x80 && (S[0] != 0 || S[1] & 0x80),
    and S > n/2 is the 256-bit big-endian comparison against
    0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0.
  - The error precedence is Core's: an invalid encoding reports SIG_DER even
    when LOW_S is set, because :217-218 runs before :219-221.
  - C and L return the same ordinal for every (flags, R, S) in the domain.
scr_rows: SCR-175
scr_row_coverage: partial
coverage: partial
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
  - "interpreter.cpp:207-224 (CheckSignatureEncoding; :217-218 DER gate, :219-221 LOW_S gate)"
  - "interpreter.cpp:183-196 (IsLowDERSignature: SIG_DER then CPubKey::CheckLowS -> SIG_HIGH_S)"
  - "interpreter.cpp:118-180 (IsValidSignatureEncoding; :149, :172, :177 are the skeleton-free conditions)"
  - "src/pubkey.h (CPubKey::CheckLowS; libsecp normalize, same-crypto premise)"
  - "src/script/verify_flags.h:46-60 (LOW_S is a policy bit; not in GetBlockScriptFlags)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags: P2SH|WITNESS|TAPROOT + DERSIG/CLTV/CSV/NULLDUMMY only)"
  - "src/policy/policy.h:104-134 (LOW_S is in STANDARD_SCRIPT_VERIFY_FLAGS, not MANDATORY)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:88-91 (SIG_S_HALF_ORDER)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:355-362 (checkLowS)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:373-380 (checkSigEncoding)"
  - "contract/error_enum.md:71-73 (24 SIG_DER, 27 SIG_HIGH_S)"

trust_note: >
  C is a line-cited source excerpt of interpreter.cpp at the pin, specialised
  to one DER shape; it is not the whole CheckSignatureEncoding and not the
  whole EvalScript.  L is a REVIEWED TRANSLITERATION of the Lean definitions
  Bitcoin.Interpreter.checkLowS / checkSigEncoding (Defs.lean:355-380), not
  generated from twin/ops_ir.py.  The S <= n/2 comparison is the SAME-CRYPTO
  seam of docs/DECISION-lax-ecdsa.md: the cell compares the Lean predicate
  against Core's predicate shape, and does not prove libsecp256k1's DER-lax
  parser or its scalar normalisation.  No Core patch is used.
scope: |
  PARTIAL.  Proved: the LOW_S policy gate, its error precedence against the
  DER gate, and the full S <= n/2 comparison, over the whole 256-bit S space
  for the fixed skeleton lenR == 1 / lenS == 32.
  NOT proved / not in the domain: DER shapes with lenR > 1 or lenS != 32 (the
  variable-offset S extraction and the full :118-180 table for those shapes),
  signatures rejected by the size bounds, and the libsecp DER-lax parse and
  scalar-overflow window (DECISION-lax-ecdsa.md §2-3, SGN-107).  A cell that
  covers those needs a byte-addressed memory model with a symbolic length; that
  is the recorded next action, not a claim here.
---

## What this cell proves

The row's claim is that LOW_S is a mempool-policy bit that never reaches
block validation, and that when set it rejects S > n/2 in
`CheckSignatureEncoding`.  The cell proves the second half as an exact
predicate: for every 64-bit flag word and every 32-byte S (fixed canonical DER
skeleton), the reported `ScriptError` ordinal is the one Core's branch structure
selects, and the L transliteration of `checkSigEncoding` selects the same one.
The consensus status of the row is a source fact, cited from
`GetBlockScriptFlags`, not something a predicate proof can establish.


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
sets LOW_S; it sets only P2SH|WITNESS|TAPROOT plus DERSIG, CLTV, CSV and
NULLDUMMY as deployments activate.  LOW_S appears only in
`STANDARD_SCRIPT_VERIFY_FLAGS` (policy.h:118-133) and MANDATORY_SCRIPT_VERIFY_FLAGS
does not contain it.  The cell therefore proves the *policy* gate only; it makes
no claim that a LOW_S-violating signature is consensus-invalid.

