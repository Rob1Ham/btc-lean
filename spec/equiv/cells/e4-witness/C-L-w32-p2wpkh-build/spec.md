---
# Cell e4-witness/C-L-w32-p2wpkh-build
cell: C-L-w32-p2wpkh-build
family: e4-witness
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (exact 25-byte implied-script reconstruction, symbolic 160-bit program)
precondition: |
  - Cell seam: the implied-script construction at interpreter.cpp:1952 only,
    reached only in the v0 20-byte-program arm after the arity guard.  No
    EvalScript loop, no ExecuteWitnessScript, no HASH160, no CHECKSIG, no
    tx/amount/flags context.
  - program is an arbitrary 20-byte value, carried as three little-endian
    u64 words (p0 = bytes 0..7, p1 = bytes 8..15, p2 = bytes 16..19 in the
    low 32 bits; bits 32..63 of p2 do not reach any output byte on either
    leg, so the proof covers the full 64-bit input space and the 160-bit
    program space).
postcondition: |
  - The constructed script is exactly the 25 bytes
      76 a9 14 <program[0..19]> 88 ac
    returned as four little-endian u64 words:
      w0 = bytes 0..7, w1 = bytes 8..15, w2 = bytes 16..23,
      w3 = 0xac (byte 24; bytes 25..31 are zero).
  - Proven for all 2^160 programs, in both directions, against an independent
    Cryptol reconstruction from the Lean byte list
    ([0x76,0xa9,0x14] ++ program ++ [0x88,0xac]).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-136
scr_row_coverage: |
  partial for SCR-136.  The reconstruction half is full: for every 20-byte
  program the cell proves that the C `exec_script << OP_DUP << OP_HASH160 <<
  program << OP_EQUALVERIFY << OP_CHECKSIG` byte expansion and the Lean list
  `[0x76,0xa9,0x14] ++ program ++ [0x88,0xac]` emit the same 25 bytes, with
  the correct PUSHDATA length prefix 0x14.  The row's second half --
  executing that script through ExecuteWitnessScript (EvalScript loop,
  HASH160, ECDSA CHECKSIG, cleanstack) -- is not modelled and remains a
  blocker; see the task report.
patches: none
source_citations:
  - interpreter.cpp:1952 (exec_script << OP_DUP << OP_HASH160 << program << OP_EQUALVERIFY << OP_CHECKSIG)
  - script.h:470-476 (opcode push: one byte per opcode)
  - script.h:484-488 (span push: AppendDataSize then AppendData)
  - script.h:408-411 (size < OP_PUSHDATA1 => single 0x14 prefix byte)
  - script.h:428-431 (AppendData copies the span bytes)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1272-1274 (Lean implied script byte list)
trust_note: >
  C is a line-cited model of the exact byte emissions of CScript::operator<<
  for four opcodes and one 20-byte span; it does not include CScript,
  std::vector or any heap.  L is a reviewed transliteration of the Lean
  byte-list construction (cells/_tools/e4w32/l_cells.cpp), materialising the
  same 32-byte buffer.  The little-endian word marshalling is cell harness,
  not engine semantics, and is identical on both legs and in the Cryptol
  spec.  No crypto or script-execution claim is made.  No Core source patch
  is used.
mutant: >
  Proposed, not executed: change the PUSHDATA prefix from 0x14 to 0x13.
  Expected Alive2 counterexample in byte 2 and a SAW proof failure.
---
