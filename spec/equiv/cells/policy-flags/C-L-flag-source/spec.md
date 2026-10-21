---
# Cell policy-flags/C-L-flag-source
cell: C-L-flag-source
family: policy-flags
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic flag-source/ordering over the bounded domain)
consensus: false
precondition: |
  - Scope: the flag SOURCE and ORDER of `GetBlockScriptFlags`
    (src/validation.cpp:2249-2284 at the pin), not the interpreter gates.
    The two policy bits under test are LOW_S (0x8) and CONST_SCRIPTCODE
    (0x10000).
  - Bounded block input: `(exceptionClass, height)`.
      * `exceptionClass` is the block hash's equivalence class under the
        two-entry mainnet `script_flag_exceptions` map (TXV-056):
        0 = no exception, 1 = the BIP16 exception hash (replacement
        SCRIPT_VERIFY_NONE), 2 = the taproot exception hash (replacement
        P2SH|WITNESS).  Every other 256-bit hash has class 0.  The hash
        itself is not symbolic in this cell.
      * `height` is a mainnet block height, modelled as a 64-bit word
        masked to its low 32 bits (`height & 0xffffffff`).
  - Buried-deployment reduction: for a buried deployment Core's
    `DeploymentActiveAt` is `index.nHeight >= params.DeploymentHeight(dep)`
    (deploymentstatus.h:27-31).  The mainnet heights are BIP66/DERSIG
    363725, BIP65/CLTV 388381, CSV 419328, segwit/NULLDUMMY 481824
    (kernel/chainparams.cpp:121-124).
  - Constant flag words: the standard word is policy.h:118-133
    (MANDATORY | the thirteen standard-only bits, SIGPUSHONLY absent); the
    mandatory word is policy.h:104-110.  Their values are compared through
    the LOW_S|CONST_SCRIPTCODE mask, so the cell asserts only what the rows
    claim.
postcondition: |
  Write `word(kind, h)` for the returned 64-bit flag word and
  `M = LOW_S | CONST_SCRIPTCODE = 0x10008`.
  - base(kind) = P2SH|WITNESS|TAPROOT = 0x20801 for kind ∉ {1,2};
    0x0 for kind = 1; P2SH|WITNESS = 0x801 for kind = 2.
  - word(kind, h) = base(kind)
      | (h >= 363725 ? DERSIG(0x4)       : 0)
      | (h >= 388381 ? CLTV(0x200)       : 0)
      | (h >= 419328 ? CSV(0x400)        : 0)
      | (h >= 481824 ? NULLDUMMY(0x10)   : 0),
    i.e. the exception replacement happens BEFORE the four buried ORs.
    In particular the taproot exception at height 692261 returns 0xE15
    (P2SH|WITNESS plus all four buried flags, TAPROOT off), while the BIP16
    exception at height 170060 returns 0x0.
  - cell_flag_source_policy_mask(kind, h) = word(kind, h) & M = 0 for every
    (kind, h): the block selector never emits either policy bit.  This is
    SCR-175's "never in GetBlockScriptFlags" and SCR-181's policy-only
    source half.
  - cell_standard_policy_mask() = STANDARD_SCRIPT_VERIFY_FLAGS & M = 0x10008:
    the mempool standard word sets both bits.
  - cell_mandatory_policy_mask() = MANDATORY_SCRIPT_VERIFY_FLAGS & M = 0:
    neither bit is mandatory (and neither is a consensus flag).
  - cell_lows_gate_block(kind, h, R, S[0..3]) feeds word(kind, h) to the
    LOW_S branch of CheckSignatureEncoding on the canonical DER skeleton:
    it returns 24 (SIG_DER) when DERSIG is on and the skeleton is
    DER-invalid, and 0 otherwise.  It never returns 27 (SIG_HIGH_S), because
    word(kind, h) never sets LOW_S.  This is the machine-checked composition
    of the source claim with the gate, not a mere citation.
  - cell_const_gate_block(kind, h, sigversion, opcode, found) feeds
    word(kind, h) to the two CONST_SCRIPTCODE gates: it returns 0 for every
    (kind, h, sigversion, opcode, found in {0,1}); 53/54 are unreachable.
    found > 1 returns 0xff (the cell's harness guard).
  - C and L return the same value for every input in the domain, in both
    refinement directions.
scr_rows: SCR-175, SCR-181
scr_row_coverage: partial
coverage: partial
patches: none
direction:
  - L ⊑ C
  - C ⊑ L
evidence:
  - alive2/result.txt, alive2/certificate.sha256 (raw alive-tv v20 output, both directions)
  - saw/result.txt, saw/certificate.sha256 (raw SAW 1.6 output, both legs)
  - ir/ (c_leaf.ll, l_leaf.ll, per-root extracted modules, build.txt; tracked, so
    the certificates hash exactly the modules presented to alive-tv/SAW)
  - tools/concrete_check.out (hand-computed vectors; C leg == L leg == expectation)
  - tools/ordering_mutant.out (wrong-order mutant C module; Alive2 reports
    the counterexample, so the order in the cell is load-bearing)
  - tools/concrete_check.out (also covers the two integration roots)
source_citations:
  - "src/validation.cpp:2249-2284 (GetBlockScriptFlags: base :2258, exception replacement :2259-2265, DERSIG/CLTV/CSV/NULLDUMMY ORs :2267-2282)"
  - "src/kernel/chainparams.cpp:115-118 (mainnet script_flag_exceptions: exactly the BIP16 and taproot entries)"
  - "src/kernel/chainparams.cpp:121-124 (BIP65/BIP66/CSV/segwit buried heights)"
  - "src/deploymentstatus.h:27-31 (buried DeploymentActiveAt is height >= since)"
  - "src/script/interpreter.h:50-150 (script_verify_flag_name bit order; LOW_S bit 3, CONST_SCRIPTCODE bit 16)"
  - "src/policy/policy.h:104-110 (MANDATORY_SCRIPT_VERIFY_FLAGS)"
  - "src/policy/policy.h:118-133 (STANDARD_SCRIPT_VERIFY_FLAGS includes LOW_S and CONST_SCRIPTCODE)"
  - "spec/core/Bitcoin/Activation/Flags.lean:69-81 (mainnetExceptionMap)"
  - "spec/core/Bitcoin/Activation/Flags.lean:127-129 (buriedActive)"
  - "spec/core/Bitcoin/Activation/Flags.lean:145-155 (getBlockScriptFlagsP)"
  - "spec/core/Bitcoin/Activation/Flags.lean:788-796 (flagBits)"
  - "spec/core/Bitcoin/Activation/Flags.lean:854-860 (consensusFullFlags, policy_absent_from_consensus)"
  - "spec/proofs/BitcoinProofs/AF/PDW93/PDW93b.lean:299-311 (standardPolicy, lowS = true)"
  - "contract/error_enum.md (no error ordinal here: the observable is the flag word, not a verdict)"
trust_note: >
  C is a line-cited excerpt of GetBlockScriptFlags at the pin plus the two
  policy.h constants; it is not the whole block validator.  L is a REVIEWED
  TRANSLITERATION of Activation/Flags.lean (mainnetExceptionMap, buriedActive,
  getBlockScriptFlagsP, flagBits) and of PDW93b.standardPolicy, not generated
  from twin/ops_ir.py.  The hash-keyed exception lookup is abstracted to its
  three equivalence classes; TXV-056 proves the mainnet map has exactly the
  two reduced entries, and every other hash is class 0.  The mainnet
  exception heights (170060, 692261) are used only as concrete vectors.  No
  Core patch, no pin change, no twin change.  The rows are policy rows:
  this cell never treats LOW_S or CONST_SCRIPTCODE as consensus bits.
scope: |
  PARTIAL as a row record because it proves one half of each row: the flag
  SOURCE and ORDER.  The interpreter-gate halves live in the sibling cells
  policy-flags/C-L-lows-policy (SCR-175) and
  policy-flags/C-L-const-scriptcode (SCR-181), which are not modified here.
  Within this cell the source claim is FULL over the bounded domain: three
  exception classes x all 2^32 heights, including the replacement-before-OR
  order.  The two integration roots also prove, for that same domain, that
  the block word drives the LOW_S branch to SIG_HIGH_S never and both
  CONST_SCRIPTCODE branches to never fire.  NOT in the domain: the 256-bit
  hash key itself (only its equivalence class), non-mainnet chain params,
  version-bits deployments (the four flags here are buried), and the full
  interpreter/memory model beyond the two declared gate slices.
---

## What this cell proves

Both rows say that a flag is policy-only because of two facts: the mempool
standard word sets it, and the block selector never does.  This cell turns
that into a flag-word equality over a bounded block input:

- `cell_flag_source` is Core's `GetBlockScriptFlags` composition.  The
  exception replacement is applied first, then DERSIG, CLTV, CSV and
  NULLDUMMY are OR-ed in by their buried heights.  The order is observable:
  the taproot exception block at 692261 gets `0xE15`, not `0x801`, because the
  four ORs run after the replacement.
- `cell_flag_source_policy_mask` masks that word with
  `LOW_S|CONST_SCRIPTCODE` and is proved equal to `0` for every (class,
  height).  This is the negative half of SCR-175 and SCR-181.
- `cell_standard_policy_mask` is `0x10008`: the positive, mempool-only half.
- `cell_mandatory_policy_mask` is `0`: neither bit is mandatory, so the cell
  does not conflate the policy catalogue with consensus flags.
- `cell_lows_gate_block` and `cell_const_gate_block` are the composition
  check: the *block* word is fed to the two policy gates, and the policy
  errors (27, 53, 54) are proved unreachable for every block input in the
  domain.  A valid-DER high-S signature at height 481824 returns 0, not 27.

The SAW spec in `saw/cell.cry` is an independent arithmetic encoding of the
same composition, not a copy of either C++ file.  Alive2 compares the C and L
modules directly in both directions.

## Both-tool evidence

- Alive2 (`alive2/result.txt`): every root compared in **both** directions
  (`alive-tv c_<fn>.ll l_<fn>.ll` for L ⊑ C and `alive-tv l_<fn>.ll c_<fn>.ll`
  for C ⊑ L); all report `Transformation seems to be correct!` /
  `1 correct transformations, 0 incorrect, 0 failed-to-prove`.
  `cell_standard_policy_mask` is also "syntactically equal", which counts as a
  correct transformation.
- SAW (`saw/result.txt`): every root verified in the C module and in the L
  module against the *same* Cryptol function in `saw/cell.cry`.
- Both `certificate.sha256` files verify with `sha256sum -c` from the repo
  root.

## Row coverage accounting

This cell is the flag-source/ordering half of both rows; the gate halves are
the sibling cells and are not edited here.

- **SCR-181** — `policy-flags/C-L-const-scriptcode` proves both cited gates
  (full), and this cell proves the block selector never sets
  CONST_SCRIPTCODE and that the gates never fire under the block word.
  Combined coverage: **full** over the cited lines.
- **SCR-175** — `policy-flags/C-L-lows-policy` proves the LOW_S branch for
  the canonical DER skeleton with the full 256-bit S comparison, but records
  that other DER shapes are outside its domain; this cell proves the block
  selector never sets LOW_S and that SIG_HIGH_S is unreachable under the
  block word for the same skeleton.  Combined coverage: the row's
  flag-source clause is **full**; the gate clause is **partial only outside
  the declared DER skeleton**.  The remaining domain (`lenR > 1`,
  `lenS != 32`, the libsecp DER-lax parse) belongs to SCR-102's parser and is
  blocked by the contract's concrete tape, not by this cell; the exact
  blocker is recorded in
  `findings/handoffs/CELLS-to-LEDGER-wave64-policy-flag-source.md`.

## Consensus status

**Not consensus.**  `GetBlockScriptFlags` (validation.cpp:2249-2284) starts
from `P2SH|WITNESS|TAPROOT` and adds only `DERSIG`, `CLTV`, `CSV` and
`NULLDUMMY`.  LOW_S and CONST_SCRIPTCODE appear only in
`STANDARD_SCRIPT_VERIFY_FLAGS` (policy.h:118-133); neither is in
`MANDATORY_SCRIPT_VERIFY_FLAGS` (policy.h:104-110).  The cell proves the
policy source separation only; it makes no claim that a LOW_S- or
CONST_SCRIPTCODE-violating transaction is consensus-invalid.
