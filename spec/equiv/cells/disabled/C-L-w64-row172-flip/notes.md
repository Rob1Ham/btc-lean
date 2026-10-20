# notes — C-L-w64-row172-flip

Row: SCR-172 (`same bytes become success in tapscript`).

This is an independent wave64 cell, additive only. It does not edit the
shared ledger, matrix, rules, pins, contract, or the wave32 cells.

## What is proved

Two small exported functions, both verified by Alive2 (C <=> L) and by SAW
against the independent `src/cell.cry` predicate:

1. `cell_pair(w, flags)` returns `(base << 32) | tapscript` for a one-byte
   non-push script. For all 2^8 wires and all 2^64 flag words:

   | condition | BASE | TAPSCRIPT |
   |---|---|---|
   | `w < 0x4f` | 254 out of domain | 254 out of domain |
   | `w` in the fifteen disabled wires | 17 `DISABLED_OPCODE` | 0 `OK`, or 36 `DISCOURAGE_OP_SUCCESS` if flag bit 19 is set |
   | other `IsOpSuccess(w)` (0x50, 0x62, 0xbb-0xfe) | 64 reaches switch | 0 or 36 |
   | other wire | 64 reaches switch | 66 scan completes |

   `64` and `66` are cell markers, not ScriptError values; only the
   disabled/OK/36 cases are verdict claims.

2. `cell_flip(w, flags)` returns 1 exactly for the fifteen
   CVE-2010-5137 wires `0x7e,0x7f,0x80,0x81,0x83,0x84,0x85,0x86,0x8d,
   0x8e,0x95,0x96,0x97,0x98,0x99` — the bytes that are a BASE consensus
   `DISABLED_OPCODE` (17) and a TAPSCRIPT `OK` (0), or the policy-level
   `DISCOURAGE_OP_SUCCESS` (36) when `SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS`
   (bit 19) is set. It is 0 for every other wire, including the other
   OP_SUCCESSx bytes: this cell is the disabled-to-success flip, not the
   full OP_SUCCESSx set.

## Policy-flag caveat (the part that must not be overclaimed)

`DISCOURAGE_OP_SUCCESS` is a policy/standardness flag, not a consensus rule.
The cell proves both branches of that bit: clear => tapscript succeeds; set
=> the node returns `SCRIPT_ERR_DISCOURAGE_OP_SUCCESS` (36). It does not
claim that block validation sets the bit. The BASE disabled error (17) is
consensus and is independent of this flag.

The `flags` word is symbolic; bit 19 is the only bit read, and it is the
real `script_verify_flag_name` ordinal (interpreter.h:143-144) shifted by
`script_verify_flags`'s `1 << ordinal` constructor, not an abstract "policy
bit 0".

## What is not covered

- The arbitrary-length scan induction: the pre-scan is a fold of the same
  per-byte predicate; only a one-byte script is instantiated here.
- Push payloads, truncated pushes, and decode ordering (F-DIV-001); the
  domain excludes 0x00-0x4e.
- The rest of `ExecuteWitnessScript` (initial stack size, 520-byte item cap,
  validation-weight budget, annex/control block) and EvalScript after the
  disabled guard. Those are SCR-153/157/168 and the wave32 scan cell's
  remaining edges.
- Whether a node sets the policy bit, and the mempool-vs-block context.

## Tool note

Alive2 compares the two compiled slices (clang++-20, LLVM 20.1.2) directly;
SAW uses `llvm_verify` on the extracted functions against `cell.cry`. The
L leg is a literal transcription of the Lean definitions, not generated
twin output. Certificates hash the cell spec/notes/sources, the contract
error enum, the three pinned Lean source files and the build/result inputs.
