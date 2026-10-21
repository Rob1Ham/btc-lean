---
# Cell limits/C-L-w32-sigop-count
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: limits/C-L-w32-sigop-count
family: limits
tool_status: both-green (symbolic over the whole ABI; semantic script domain <= 4 bytes)
precondition: |
  - pure script-byte function: no transaction, script flags, stack, or crypto
    input.  `w` packs script bytes little-endian, byte i = (w >> 8*i) & 0xff;
    `len` is the script byte count.
  - domain: 0 <= len <= 4 (`LIMITS_MAX_SCRIPT_BYTES`); for len > 4 both legs
    and the Cryptol spec return the shared out-of-domain sentinel 0xffffffff.
    The tools prove the sentinel identical too, but it is not a claim about
    scripts longer than four bytes.
  - two entry points, one per value of `fAccurate`:
    `cell_sigop_accurate(w, len)` and `cell_sigop_inaccurate(w, len)`.
  - no MINIMALDATA / policy flags: GetSigOpCount is flag-independent.
postcondition: |
  - the return value is `CScript::GetSigOpCount(fAccurate)` over the `len`-byte
    script prefix: walk it with `GetOp`; a truncated length field or a payload
    that runs past the end stops the walk and keeps the count of the already
    parsed prefix; bytes inside push payloads are data, never opcodes.
  - OP_CHECKSIG and OP_CHECKSIGVERIFY add 1.
  - OP_CHECKMULTISIG and OP_CHECKMULTISIGVERIFY add DecodeOP_N(previous
    opcode) when `fAccurate` and the previous opcode is OP_1..OP_16, else add
    MAX_PUBKEYS_PER_MULTISIG = 20.
  - C and L return the same uint32_t for every 64-bit `w` and 32-bit `len`,
    and both equal the independent Cryptol `count32`.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-032, SCR-033
scr_row_coverage: >-
  full — every branch and edge named by the two rows is exercised
  symbolically at every site of a script of up to four bytes, with all bytes
  symbolic: SCR-032's CHECKSIG/CHECKSIGVERIFY = 1 and (inaccurate)
  CHECKMULTISIG/CHECKMULTISIGVERIFY = 20; SCR-033's accurate lookback for
  every preceding OP_1..OP_16 value (1..16) and the else-20 arm for every
  other preceding opcode (pushes, OP_0, OP_1NEGATE, OP_RESERVED, and any
  other opcode), plus the malformed/truncated-push stop.  The four-byte bound
  is the cell domain, not a branch of either row: the out-of-domain sentinel
  is proved identical by Alive2 and SAW but is outside the semantic claim.
patches: none
source_citations:
  - script.cpp:313-360 (GetScriptOp; payload bound at 349)
  - script.cpp:157-181 (CScript::GetSigOpCount)
  - script.cpp:155 (lastOpcode initialised to OP_INVALIDOPCODE)
  - script.h:507-514 (CScript::DecodeOP_N)
  - interpreter.h (MAX_PUBKEYS_PER_MULTISIG = 20)
  - opcodes.h (OP_CHECKSIG/VERIFY, OP_CHECKMULTISIG/VERIFY, OP_1..OP_16)
  - spec/core/Bitcoin/Interpreter/SigOps.lean:56-101 (sigOpStep, accurate/inaccurate counts)
  - spec/core/Bitcoin/Interpreter/SigOps.lean:109-121 (getOpCount)
  - spec/core/Bitcoin/Interpreter/SigOps.lean:132-155 (parseWirePrefix, scriptSigOpCount)
  - spec/core/Bitcoin/Interpreter/Defs.lean:76 (MAX_PUBKEYS_PER_MULTISIG)
  - spec/core/Bitcoin/Script/Parser/Defs.lean:206-230 (getOpAux/getOp)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.cpp/script.h at
  the pin, not the whole interpreter.  L is a reviewed transliteration of the
  Lean SigOps model (model_rev 4d62a97e).  The shared cell harness in
  cells/_tools/limits unpacks the ABI word into bytes, unrolls the count loop
  to the four-byte bound (each decoded opcode consumes at least one byte), and
  applies the identical out-of-domain sentinel in both legs.  The sentinel
  0xffffffff is above every possible count (at most 80 over four bytes), so
  the guard cannot mask an in-domain disagreement; it is proved identical by
  both tools.  No engine source, pin, contract, Lean proof, or crypto premise
  is changed.
---

# limits/C-L-w32-sigop-count

Symbolic equivalence of Core's two static sigop counters and the Lean model,
and an independent Cryptol specification, over the four-byte script domain.

## Entry points

```c
extern "C" uint32_t cell_sigop_accurate  (uint64_t w, uint32_t len);
extern "C" uint32_t cell_sigop_inaccurate(uint64_t w, uint32_t len);
```

`w` packs the script bytes little-endian; `len` is the byte count.  Returns
`0xffffffff` for `len > 4`.

## What each tool proves

- **Alive2** (`alive2/run.sh`): `c_cell_sigop_*.ll` ≡ `l_cell_sigop_*.ll` for
  every 64-bit `w` and 32-bit `len`, for both functions.  The extracted IR is
  guarded to be memory-free and closed (no `alloca`, no `= external`, no
  `switch.table`), and `--always-verify` is mandatory in the runner.
- **SAW** (`saw/run.sh`): each of the four modules (`c` and `l` × accurate and
  inaccurate) is verified against `count32 w len True/False` from
  `src/cell.cry` for every 64-bit `w` and 32-bit `len`.  Four proofs, solver
  `abc`.

## Rows

- **SCR-032** — inaccurate count: CHECKSIG/CHECKSIGVERIFY = 1;
  CHECKMULTISIG/CHECKMULTISIGVERIFY = 20.
- **SCR-033** — accurate count: the immediately preceding OP_1..OP_16 value is
  counted (1..16), otherwise 20, at each CHECKMULTISIG site.

See `notes.md` for the harness rationale, rejected variants, and the mutation
sanity check that rules out a vacuous Alive2 green.
