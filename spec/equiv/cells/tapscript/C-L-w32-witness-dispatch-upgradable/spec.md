---
# Cell tapscript/C-L-w32-witness-dispatch-upgradable
cell: C-L-w32-witness-dispatch-upgradable
family: tapscript
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic dispatch predicates; taproot/tapscript execution abstracted as uninterpreted inputs)
precondition: |
  - Cell seam: the two post-commitment dispatch decisions of
    VerifyWitnessProgram at the pin.  No tx decoding, no control-block size or
    commitment check, no annex, no SHA256, no Schnorr, no EvalScript.
  - cell_leaf_version_dispatch: control[0] is any byte; the cell starts after
    the control-size check (interpreter.cpp:1913-1925, SCR-145) and the
    commitment match (SCR-146/147).  Lean's `byteOr control 0` is the same byte.
  - cell_program_tail_dispatch: witversion is any 32-bit value (the engine only
    reaches VerifyWitnessProgram with 0..16); program length is any 32-bit
    value; only program[0] and program[1] are read, and only when
    program.size() == 2; is_p2sh is 0/1/other-nonzero; both policy flags are
    arbitrary 32-bit values (nonzero = set).
  - Domain markers: version 0 (the v0 arm, SCR-133..138) and version > 16
    (never a witness program) return the harness bad-input marker (2, 1).
  - Abstraction (declared, uninterpreted): ExecuteWitnessScript for leaf
    version 0xc0 and the whole witversion-1/32-byte/!p2sh taproot arm enter the
    equality as arbitrary 64-bit packed inputs.  They are not fixed to success
    and are not claimed.
postcondition: |
  - Packed observable: result(2) | error_ordinal(6) << 2 | aux << 8
    (w32_common.h).  pass = 1; bad input = 6.
  - cell_leaf_version_dispatch, every control[0] byte c and flag f:
      (c & 0xfe) == 0xc0            -> tapscript_rc (input, not claimed)
      otherwise, f != 0             -> (0, 35) DISCOURAGE_UPGRADABLE_TAPROOT_VERSION
      otherwise                     -> (1, 0)
  - cell_program_tail_dispatch, every (version v, plen, b0, b1, p2sh, f):
      v = 0 or v > 16               -> (2, 1)  harness domain marker
      v = 1, plen = 32, !p2sh       -> taproot_rc (input, not claimed)
      !p2sh, v = 1, plen = 2,
        b0 = 0x4e, b1 = 0x73        -> (1, 0)  P2A, before the discourage check
      otherwise, f != 0             -> (0, 34) DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
      otherwise                     -> (1, 0)
  - Both legs return the same packed value for every input in the domain, in
    both directions; no error precedence is invented.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-149, SCR-150, SCR-151
scr_row_coverage: |
  full for each row, at the dispatch seam, per row:
  - SCR-149 "unknown leaf versions succeed (upgradable); the discourage flag is
    policy": full.  all 256 control[0] values x both flag states x arbitrary
    tapscript outcome.  The node's summary names
    DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM, but the code at the cited location
    (interpreter.cpp:1995, Defs.lean:1316) tests
    DISCOURAGE_UPGRADABLE_TAPROOT_VERSION; the cell models the code.  The flag
    is a policy bit (`pol`, consensus=false), and the consensus path is f = 0.
  - SCR-150 "v1 2-byte 4e73 program => success, no execution": full.  Success is
    returned before the discourage check and without calling
    ExecuteWitnessScript, for all other version/length/byte/p2sh inputs too.
  - SCR-151 "v2-v16 / wrong-size v1 / P2SH-wrapped v1 => success (upgradable)":
    full.  every v in 1..16, every plen, every program[0..1], both p2sh states,
    both discourage states.  v1/32/!p2sh is the taproot arm (SCR-142..147) and
    v0 is SCR-133..138; both are outside this row and excluded by the domain.
  NOT claimed: control size (SCR-145), tapleaf/tweak commitment (SCR-146/147),
  annex (SCR-143), key/script path (SCR-144/148..), P2SH outer evaluation, and
  any executed tapscript.
patches: none
source_citations:
  - interpreter.cpp:1988-1993 (leaf-version dispatch; ExecuteWitnessScript abstracted)
  - interpreter.cpp:1995-1998 (unknown leaf version: DISCOURAGE_UPGRADABLE_TAPROOT_VERSION or success)
  - interpreter.cpp:2000-2001 (P2A arm)
  - interpreter.cpp:2002-2008 (other version/size/p2sh combinations; DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM)
  - script.cpp:216-222 (CScript::IsPayToAnchor(int, program))
  - interpreter.h:242-243 (TAPROOT_LEAF_MASK 0xfe, TAPROOT_LEAF_TAPSCRIPT 0xc0)
  - spec/core/Bitcoin/Interpreter/Defs.lean:523-525 (isPayToAnchor)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1312-1321 (leaf version + upgradable tail)
  - contract/error_kind.h:34-36, 45-52 (ordinals 34, 35)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at the
  pin, not the whole VerifyWitnessProgram.  L is a reviewed transliteration of
  the Verified Lean definition (the twin has no verifyWitnessProgram handler, so
  mk_leaf.py cannot emit one); the transliteration is visible in
  src/l_leaf.cpp.  ExecuteWitnessScript (leaf 0xc0) and the whole taproot arm
  are uninterpreted packed inputs to the equality, so no script-execution,
  annex, control-block, Schnorr, or hash claim is made.  Both tools prove the
  same two symbolic functions: Alive2 compares the -O2 canonical forms of the
  C and L IR directly (two-file mode, `--always-verify`); SAW verifies each
  module against the independent Cryptol function in src/cell.cry.  No Core
  source patch is used.
mutant: >
  Proposed, not executed: in src/l_leaf.cpp change the P2A guard
  `if (!is_p2sh && p2a)` to `if (p2a)`.  Expected Alive2 counterexample at
  version=1, plen=2, b0=0x4e, b1=0x73, is_p2sh=1, disc=0 (C=1, L=1 for that
  input, but disc=1 / p2sh=1 gives C=136, L=1).  Recorded for REDTEAM; the
  unmutated pair is green.
---
