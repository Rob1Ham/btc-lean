---
# Cell limits/C-L-w32-witness-sigops
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: limits/C-L-w32-witness-sigops
family: limits
tool_status: both-green (symbolic over the whole ABI; witness-script domain <= 4 bytes)
precondition: |
  - pure function: static `WitnessSigOps(witversion, witprogram, witness)` with
    no script execution, flags, or transaction context.  The caller has
    already decoded a witness program (a bare one in this cell).
  - inputs: `version` is the decoded witness version (only zero is special);
    `prog_len` is `witprogram.size()` (the program bytes are never read by
    WitnessSigOps, so only the length is passed); `stack_size` models
    `witness.stack.size()` (only zero/non-zero is observed); `w` packs the
    LAST witness stack item little-endian and `wit_len` is its byte count.
  - witness-script domain: 0 <= wit_len <= 4.  A larger `wit_len` in the
    v0-32-with-items arm returns the shared out-of-domain sentinel
    0xffffffff from both legs and the Cryptol spec; the sentinel is outside
    the semantic claim.
postcondition: |
  - version != 0 returns 0.
  - version == 0 and prog_len == 20 returns 1 (WITNESS_V0_KEYHASH_SIZE).
  - version == 0 and prog_len == 32 with a non-empty stack returns the
    accurate static sigop count of the last item: CHECKSIG/CHECKSIGVERIFY = 1;
    CHECKMULTISIG/CHECKMULTISIGVERIFY = the preceding OP_1..OP_16 value, else
    20; a malformed push stops the count and keeps the valid prefix.
  - version == 0 with any other prog_len, or prog_len == 32 with an empty
    stack, returns 0.
  - C and L return the same uint32_t for every argument tuple, and both equal
    the independent Cryptol `witnessOps32`.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-035
scr_row_coverage: >-
  full — every branch named by SCR-035 is exercised symbolically: v0 with a
  20-byte program = 1; v0 with a 32-byte program and a non-empty witness stack
  = accurate count of the last item (all counting branches, including the
  OP_1..OP_16 accurate lookback and the else-20 arm); v0-32 with an empty
  stack = 0; v1..v16 (and any non-zero version) = 0; every other program
  length = 0.  The four-byte witness-script bound is the cell domain, not a
  branch of the row; the out-of-domain sentinel is outside the semantic claim.
  The program bytes are genuinely unread by WitnessSigOps (only
  `witprogram.size()` is inspected), so passing the length is not an
  abstraction that loses behavior.
patches: none
source_citations:
  - interpreter.cpp:2133-2147 (static WitnessSigOps)
  - interpreter.cpp:2135-2136 (WITNESS_V0_KEYHASH_SIZE = 20 -> 1)
  - interpreter.cpp:2138-2142 (WITNESS_V0_SCRIPTHASH_SIZE = 32 + last stack item)
  - interpreter.cpp:2144-2146 (future versions -> 0)
  - script.cpp:157-181 (CScript::GetSigOpCount(bool), accurate count)
  - script.cpp:313-360 (GetScriptOp)
  - spec/core/Bitcoin/Interpreter/SigOps.lean:376-390 (witnessSigOps)
  - spec/core/Bitcoin/Interpreter/SigOps.lean:247-253 (witnessScriptSigOps)
  - spec/core/Bitcoin/Interpreter/SigOps.lean:132-155 (parseWirePrefix)
  - spec/core/Bitcoin/Interpreter/SigOps.lean:56-101 (sigOpStep)
  - spec/core/Bitcoin/Script/Parser/Defs.lean:206-230 (getOpAux/getOp)
trust_note: >
  C is a line-cited source-excerpt slice of interpreter.cpp/script.cpp at the
  pin, starting at the already-decoded `(witversion, witprogram)` pair.  L is
  a reviewed transliteration of the Lean `witnessSigOps` model (model_rev
  4d62a97e).  `witprogram.size()` is the only property of the program the
  function reads; the last witness item is the only stack item read, and only
  its zero/non-zero stack membership is checked.  The shared harness unpacks
  the item word, unrolls the count walk to the four-byte bound, and applies the
  identical out-of-domain sentinel.  The sentinel exceeds every in-domain
  count.  The decoded-program construction (`IsWitnessProgram`) and the
  caller's WITNESS/P2SH flags are outside this cell; SCR-036 covers the P2SH
  wrap and is reported separately.  No pin, contract, engine source, Lean
  proof, or crypto premise is changed.
---

# limits/C-L-w32-witness-sigops

Symbolic equivalence of Core's static `WitnessSigOps` and the Lean model,
against an independent Cryptol specification, over the whole ABI and a
four-byte witness-script domain.

## Entry point

```c
extern "C" uint32_t cell_witness_sigops(uint32_t version, uint32_t prog_len,
                                        uint32_t stack_size, uint64_t w,
                                        uint32_t wit_len);
```

`w`/`wit_len` describe the last witness stack item; `stack_size` is only
tested for zero.  v0-32 with `wit_len > 4` returns `0xffffffff`.

## What each tool proves

- **Alive2** (`alive2/run.sh`): C and L agree for every argument tuple.  The
  runner guards the extracted IR (no `alloca`, no `= external`, no
  `switch.table`, no residual `llvm.loop`) and requires `--always-verify` plus
  the exact summary counts.
- **SAW** (`saw/run.sh`): both modules are verified against
  `witnessOps32 version progLen stackSize w witLen` for every argument tuple;
  two proofs, solver `abc`.

## Row

**SCR-035** — v0-20 = 1; v0-32 = accurate count of the witness script; v1+ = 0.

See `notes.md` for the encoding decisions and the mutation sanity check.
