---
# Cell limits/C-L-witness-sigop-dispatch
cell: C-L-witness-sigop-dispatch
family: limits
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic dispatch predicate)
precondition: |
  - The cell is WitnessSigOps (interpreter.cpp:2133-2147) / the Lean
    witnessSigOps (Interpreter/SigOps.lean), the function that maps a witness
    version, witness-program length and witness stack to a sigop count.
  - `witversion` is the version decoded by IsWitnessProgram; 0 = v0, >= 1 =
    future versions (taproot). Its domain is 0..16 in Core; the cell proves
    every 8-bit value, which is a superset.
  - `program_len` is witprogram.size() (2..40 for a real witness program;
    the cell proves every 32-bit value, a superset).
  - `witness_nonempty` is `witness.stack.size() > 0` (Core bool; 0/1 in the
    domain).
  - `last_item_sigops` is the accurate GetSigOpCount(true) of
    witness.stack.back(), i.e. the count Core obtains by calling out to the
    static counter. That counter's per-site rule is proved by
    limits/C-L-sigop-site-weights (SCR-032/033); here it is an input.
postcondition: |
  - Returns the witness sigop contribution:
      version = 0, program_len = 20                    -> 1
      version = 0, program_len = 32, stack non-empty   -> last_item_sigops
      version = 0, program_len = 32, stack empty       -> 0
      version = 0, other program_len                   -> 0
      version != 0                                     -> 0
  - No error kind is produced; this function returns a count only.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-035
scr_row_coverage: |
  full. SCR-035 says "v0-20=1; v0-32=accurate(witness script); v1+=0". The
  cell proves exactly that mapping for every version, program length and
  witness-emptiness state, and returns the accurate count of the last witness
  item in the v0-32 case. The accurate counter itself is a separate row
  (SCR-033, proved by limits/C-L-sigop-site-weights); SCR-035 is the
  version/length dispatch and the choice of which count is used, which is
  complete here. The witness-program classification (IsWitnessProgram) is
  upstream of this function and is not part of the row.
patches: none
source_citations:
  - interpreter.cpp:2133-2147 (WitnessSigOps: v0 20-byte -> 1; v0 32-byte and non-empty -> accurate last item; else 0)
  - interpreter.cpp:2136-2137 (WITNESS_V0_KEYHASH_SIZE arm)
  - interpreter.cpp:2139-2142 (WITNESS_V0_SCRIPTHASH_SIZE arm, witness.stack.back(), GetSigOpCount(true))
  - interpreter.h / script.h witness-program size constants (20, 32)
  - spec/core/Bitcoin/Interpreter/SigOps.lean (witnessSigOps, SWT-025/026/028)
trust_note: >
  C is a line-cited source-excerpt slice of interpreter.cpp at the pin. L is
  a reviewed transliteration of the Lean witnessSigOps definition. The
  accurate count of the last witness item is an input (proved separately by
  the sigop-site-weights cell); no signature checking, hash or script
  execution is claimed. Alive2 compares the C and L IR directly; SAW
  verifies both against the independent Cryptol predicate. No Core patch is
  used.
mutant: >
  Proposed, not executed: make the v0-32 empty-witness arm return 1 instead
  of 0 (dropping the `witness.stack.size() > 0` guard). Expected: Alive2
  counterexample at (version=0, len=32, empty=0); SAW failure.
---
