---
# Cell exec-verify/C-L-w32-flags-combo
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-w32-flags-combo
family: exec-verify
tool_status: both-green (symbolic over all 2^64 flag words x both cleanstack values)
precondition: |
  - The VerifyScript flag well-formedness domain: every 64-bit
    `script_verify_flags` word and both values of the CLEANSTACK policy bit.
  - No script, transaction, witness, or height input is read by the cell:
    the row is the flag-combination constraint itself.
postcondition: |
  - `cell_flags_combo(flags, cleanstack) == 1` exactly when
      (!cleanstack || (P2SH && WITNESS)) && (!WITNESS || P2SH)
    and 0 otherwise. Both legs return the same value for every input.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-014
scr_row_coverage: full — the row names one constraint (WITNESS requires P2SH);
  the cell proves the complete `flagsComboOk` predicate over the whole 64-bit
  flag space plus the CLEANSTACK policy bit, including both branches of each
  implication and the CLEANSTACK => (P2SH && WITNESS) arm that Core asserts at
  the same site. SCR-009 is not claimed separately.
patches: none
source_citations:
  - interpreter.cpp:2110-2119 (CLEANSTACK asserts: P2SH, WITNESS)
  - interpreter.cpp:2120-2127 (WITNESS requires P2SH assert)
  - src/script/interpreter.h:49-153 (script_verify_flag_name ordinals)
  - src/script/verify_flags.h:31 (bit value = 1 << ordinal)
  - src/script/interpreter.h:48 (SCRIPT_VERIFY_NONE = 0)
  - spec/core/Bitcoin/Interpreter/Rules.lean:48-50 (flagsComboOk)
trust_note: >
  C is a line-cited source-excerpt slice: Core phrases the constraint as two
  assert()s on the VerifyScript success path. The cell models the predicate
  they encode (the `flagsComboOk` face of the row); the assert's own
  UB/NDEBUG behaviour is outside the cell and no claim is made about it.
  L is a reviewed hand transliteration of the Lean `flagsComboOk`
  (spec/equiv/README.md section 3 fallback: the Activation module has no
  generated twin). Bit values in `_tools/w32/w32_common.h` are transcribed
  from the pinned headers, not included from Core. Neither leg is the whole
  VerifyScript. No Core source patch is used.
---
