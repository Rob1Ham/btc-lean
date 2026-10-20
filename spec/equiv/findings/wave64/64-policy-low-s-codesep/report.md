# wave64 / 64-policy-low-s-codesep — SCR-175, SCR-181 flag-source/ordering

Task: complete SCR-175 (LOW_S is mempool policy, never in
`GetBlockScriptFlags`) and SCR-181 (CONST_SCRIPTCODE policy gate) with a
bounded flag-source/ordering cell or a precise contract-context blocker.
Policy and consensus flags are kept separate throughout.

## Result

New cell **`spec/equiv/cells/policy-flags/C-L-flag-source`**, both tools
green, six roots, certificates replayable from tracked IR:

| leg | evidence | result |
|---|---|---|
| Alive2 v20.0 | `alive2/result.txt` | 12 direction checks green, 0 incorrect, 0 Alive2 errors |
| SAW 1.6 | `saw/result.txt` | 12 proofs (6 roots x 2 legs), `CELL_policy_flags_flag_source_SAW_GREEN` |
| vectors | `tools/concrete_check.out` | C == L == expectation on 12 block inputs + 6 gate vectors |
| negative control | `tools/ordering_mutant.out` | wrong-order mutant rejected with counterexample |

Result hashes (the ledger's `certificate:` values):

- Alive2 `alive2/result.txt`:
  `a0822d4dd7df08a47dcf97ac694c980333b60acfefb2f05e9e234653aaa9b0ea`
- SAW `saw/result.txt`:
  `9be22b7cfa6c5efb032d685eabeb700bf5514b8aac9ea4f1e345a1aa0eb432b2`

Both `certificate.sha256` files pass `sha256sum -c`; the certificates hash
the textual IR in `ir/`, which is exactly what Alive2 consumed, and the SAW
runner checks `build/<leg>_leaf.bc` byte-for-byte against `ir/<leg>_leaf.ll`
before proving.

## What is proved

Bounded input: `(exceptionClass, height)`.

- `exceptionClass` is the block hash's equivalence class under the two-entry
  mainnet `script_flag_exceptions` map (TXV-056): 0 = none, 1 = BIP16
  exception (replacement `SCRIPT_VERIFY_NONE`), 2 = taproot exception
  (replacement `P2SH|WITNESS`).  The 256-bit hash key is not symbolic.
- `height` is a mainnet height masked to 32 bits.

Roots:

1. `cell_flag_source` — Core's whole selector
   (validation.cpp:2249-2284): base, exception replacement, then
   DERSIG/CLTV/CSV/NULLDUMMY ORs by buried heights.  The replacement-before-OR
   order is load-bearing and proved: taproot exception at 692261 is `0xE15`,
   BIP16 exception at 170060 is `0x0`, normal post-segwit is `0x20E15`.
2. `cell_flag_source_policy_mask` — `word & (LOW_S|CONST_SCRIPTCODE) = 0`.
3. `cell_standard_policy_mask` — `0x10008` (mempool standard sets both).
4. `cell_mandatory_policy_mask` — `0` (neither bit is mandatory/consensus).
5. `cell_lows_gate_block` — block word fed to the LOW_S branch on the
   canonical DER skeleton; `SIG_HIGH_S` (27) unreachable; DERSIG's `SIG_DER`
   (24) still reachable as expected.
6. `cell_const_gate_block` — block word fed to both CONST_SCRIPTCODE gates;
   53/54 unreachable for every `(sigversion, opcode, found∈{0,1})`.

The SAW spec is an independent arithmetic encoding of the same composition;
Alive2 compares the C and L modules directly in both directions.

## Row dispositions

- **SCR-181**: full.  `C-L-const-scriptcode` proves both cited gates
  (full); `C-L-flag-source` proves the block selector never sets bit 16 and
  the gates cannot fire under the block word.  Proposal: `both-green` with
  both cells listed.
- **SCR-175**: the flag-source clause is now full; the gate clause is still
  `C-L-lows-policy`'s canonical-DER-skeleton domain.  Two honest options are
  in the handoff: (A) `both-green` because the row text/cited lines
  (interpreter.cpp:219-221) are the source claim and the DER parser is
  SCR-102; (B) keep `gap` with the precise contract blocker below.

## Precise contract-context blocker (remaining SCR-175 gate domain)

Full-DER-shape equivalence for `CheckSignatureEncoding` / `CheckLowS` cannot
be expressed under the current contract:

- `contract/ABI.md` §1 and `contract/tape.md` §1-2 define the proof-bearing
  entry over concrete `tx_bytes`/`spk` buffers (a serialized
  `TX_WITH_WITNESS`).  There is no symbolic-length byte-array channel.
- The cell lane's C/L leaves are scalar `uint64_t` functions.  A full parser
  proof needs a symbolic `sig.size()` in 0..73 and byte-addressed reads at
  variable offsets (`sig[1]`, `sig[3]`, `sig[lenR+5]`, `sig[lenR+6]`,
  `sig[lenS+6]`), plus a memory model for `CScript`/`CScriptNum` slices and
  `FindAndDelete`.  No such model is part of the ABI or the twin generator.
- The libsecp DER-lax parse/normalisation is the same-crypto seam
  (`docs/DECISION-lax-ecdsa.md` §2-3, SGN-107); a cell can compare the
  predicate shape (`sval <= n/2`), not libsecp itself.

Closing it would require a new contract version (symbolic tape or a
byte-addressed leaf ABI with a memory spec), an unbounded-loop invariant for
the lax parser, and the existing same-crypto premise.  Until then the
skeleton cell is the honest gate coverage.

## Reproduce

```sh
cd /tmp/opencode/wave64/64-policy-low-s-codesep
bash spec/equiv/cells/policy-flags/C-L-flag-source/_tools/build_leaf.sh \
  spec/equiv/cells/policy-flags/C-L-flag-source
bash spec/equiv/cells/policy-flags/C-L-flag-source/alive2/run.sh
bash spec/equiv/cells/policy-flags/C-L-flag-source/saw/run.sh
bash spec/equiv/cells/policy-flags/C-L-flag-source/tools/concrete_check.sh
bash spec/equiv/cells/policy-flags/C-L-flag-source/tools/ordering_mutant.sh
sha256sum -c spec/equiv/cells/policy-flags/C-L-flag-source/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/policy-flags/C-L-flag-source/saw/certificate.sha256
```

`make gate-ir-pin` on this branch still fails on pre-existing
`stack-ops/C-L-pick` certificates that reference gitignored `build-alive2/`
and `build-saw/` artifacts; no `C-L-flag-source` line appears in that
failure set, and both new certificates replay clean.

## Scope discipline

- No shared edits: `spec/db/equiv-cells.yaml`, `spec/equiv/results/`,
  `docs/`, and the sibling policy cells are untouched.  Ledger proposals are
  in `spec/equiv/findings/handoffs/CELLS-to-LEDGER-wave64-policy-flag-source.md`.
- No Core patch, no pin change, no twin change; policy bits are never
  presented as consensus bits.
