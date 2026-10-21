---
# Cell exec-verify/C-L-w32-flag-exceptions
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-w32-flag-exceptions
family: exec-verify
tool_status: both-green (symbolic lookup; symbolic height schedules; closed named blocks)
precondition: |
  - Mainnet chain parameters.
  - `cell_exc_select`: any 256-bit block hash (four 64-bit limbs).
  - `cell_flags_{bip16,taproot}_at`: any uint32 height, with the block hash
    fixed to the corresponding exception entry.
  - `cell_flags_{bip16,taproot}_named`: no input; the two named mainnet
    blocks at their real heights (170060 and 692261).
postcondition: |
  - `cell_exc_select` = 1 for the BIP16 exception hash, 2 for the taproot
    exception hash, 0 for every other hash (fail-closed).
  - `cell_flags_bip16_at(height)` = only the buried ORs (base NONE); P2SH,
    WITNESS and TAPROOT are never set.
  - `cell_flags_taproot_at(height)` = P2SH|WITNESS plus the buried ORs;
    TAPROOT is never set.
  - Named blocks: BIP16 block (height 170060) = 0x0 (all three base bits off,
    all four buried heights above it); taproot block (height 692261) =
    P2SH|WITNESS|DERSIG|CLTV|CSV|NULLDUMMY = 0xe15.
  - Both legs return the same value for every input.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-016
scr_row_coverage: full — both named mainnet exception blocks are covered by
  their exact flag words, and the exception map is proved exact and
  fail-closed over the whole 256-bit hash space; the height schedules for
  those two hashes are proved for every height, so there is no height at
  which either named block would regain a dropped base bit.
patches: none
source_citations:
  - src/kernel/chainparams.cpp:115-118 (the two script_flag_exceptions)
  - src/validation.cpp:2262-2265 (exception REPLACES the base)
  - src/validation.cpp:2267-2285 (buried ORs)
  - spec/core/Bitcoin/Activation/Flags.lean:50-76 (hashes + mainnetExceptionMap)
  - spec/core/Bitcoin/Activation/Flags.lean:69-76 (Option payloads)
  - spec/core/Bitcoin/Activation/Flags.lean:42-57 (hash<->height pairs)
  - spec/proofs/BitcoinProofs/AF/PDW27/SCR015INV133.lean:44-66
    (mainnetExceptionMap_bip16 / _taproot, the Lean faces of this cell)
trust_note: >
  C is a line-cited source-excerpt slice; the map lookup is the two 256-bit
  equality tests. L is a reviewed hand transliteration of
  `mainnetExceptionMap`/`getBlockScriptFlagsP` (no generated twin for
  Bitcoin.Activation). `cell_exc_select` returns an encoded Option
  (0 none / 1 BIP16 / 2 taproot); the encoding is cell harness, and the
  distinct payloads are exactly the two Option values of the Lean map. The
  hash<->height pairs are the ones recorded in the Lean module (verified
  2026-10-16); the cell does not re-derive a block hash from a header.
  README.md section 3 labels this L link as reviewed transliteration.
---
