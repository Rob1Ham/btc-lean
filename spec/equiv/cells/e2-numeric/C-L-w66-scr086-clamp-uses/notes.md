# Notes — SCR-086 at the depth/count consumers

Branch `wave66/15-scr-086`, base `8142cff`, pin
`cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.

## What the row asks and what this cell proves

SCR-086 (`rules.yaml`) is `clamp to int32 for depth/count uses`,
`core_ref: script.h:326-333`, `check: getint clamping`.  The Lean targets are

```text
PDW86Clamp.stepBody_pick_ok_clamped
PDW86Clamp.stepBody_roll_ok_clamped
PDW86Clamp.checkMultiSig_key_count_clamped
PDW86Clamp.checkMultiSig_sig_count_clamped
```

i.e. the identity `getIntClamped n = n` at the OP_PICK/OP_ROLL depth read and
at both CHECKMULTISIG count reads.  The Lean proof already establishes it for
an arbitrary `decodeNum pol b 4 = .ok n`, with `pol` arbitrary
(`PDW86Clamp.decodeNum_getIntClamped`).  This cell is the C/L machine-level
counterpart, at all four consumers, with the operand, the decode flags, the
stack depth and `nOpCount` symbolic.

The five leaves are scalar and loop-free:

| Leaf | Exposed value | Arms |
|---|---|---|
| `cell_clamp_int32` | Core `getint()` for all `int64_t` | in range, `>INT_MAX`, `<INT_MIN` |
| `cell_depth_read` | decoded depth `n`, post-pop index | size guard, width, minimal, `n<0`, `n>=size`, ok |
| `cell_cms_key_count` | decoded `nKeys`, `ikey2` | width/minimal, `[0,20]`, `nOpCount>201`, ok |
| `cell_cms_sig_prefix` | decoded `nKeys`, `ikey2`, reached-read status | width/minimal, `[0,20]`, `nOpCount>201`, key-side depth, ok |
| `cell_cms_sig_read` | decoded `nSigs`, `ikey2`, `isig`, `nKeys` | width/minimal, `nSigs<=nKeys`, sig-side depth, ok |

The `nSigsCount` path is split at the signature read so that each SAW query
contains one decode (the unsplit path has two decodes and thirteen symbolic
inputs, which is needlessly expensive and was not reproducible under host
memory pressure).  The composition is exact: the prefix leaf returns the
full result whenever its status is nonzero; on status 0 it has exposed
`nKeys` and `ikey2`, and the read leaf is applied to `(nKeys, depth,
sig operand, minimal)`, recomputing `isig` from `nKeys` exactly as Core
does.  Both legs use the same split, so pointwise leaf equality gives full
path equality.

## Why the clamp is the identity on this domain

Core caps the operand at `nMaxNumSize = 4` before `set_vch`
(script.h:246-251).  A four-byte little-endian sign-magnitude value has
magnitude at most `0x7fffffff`, so the decoded `int64_t m_value` lies in
`[-2147483647, 2147483647]`, strictly inside `[INT_MIN, INT_MAX]`.  Therefore
`getint()` neither arm fires and the unclamped twin/Lean value is the same
`int32`.  The clamp leaf proves the two firing arms anyway (they are reachable
only from an `int64_t` the decoders cannot produce), so a change to either arm
is caught by the oracle rather than hidden by the vacuous domain.

The cell exposes the decoded count/depth as a full 32-bit field, not just the
5-bit/6-bit cursor, so a clamp difference cannot be masked by the bounded
downstream ranges.

## The twin loop and the build_w32 provenance gate

The blocker recorded in waves 64/65 was the verbatim twin handler:

```c
for (uint32_t i = idx; i + 1 < st.stack.n - 1; ++i) { ... }
```

Its trip count is `idx + 1`, which is symbolic whenever the depth operand is
symbolic, so Alive2 cannot ingest it as a loop-free comparison and SAW 1.6
does not terminate on the symbolic-index element copy.  The wave-65 cell
worked around it by fixing the operand per leaf (depths 2/3/4 only).

This cell does not need the workaround and does not edit the twin.  The clamp
is read *before* the loop:

```c
int n = CScriptNum(stacktop(-1), fRequireMinimal).getint();
popstack(stack);
if (n < 0 || n >= (int)stack.size()) return ...;
valtype vch = stacktop(-n-1);
if (opcode == OP_ROLL) stack.erase(stack.end()-n-1);   // <- the loop
```

`n`, the guard decision and the index are exactly the values
`cell_depth_read` exposes.  Proving C (clamped) equal to L (unclamped) on
those values for every operand and every depth shows the handler's loop
receives the same `idx` on both legs.  The loop itself is the stack
permutation of SCR-075 (cell `stack-ops/C-L-pick`, both-green), not a clamp
consumer.  The CHECKMULTISIG signature/pubkey verification loops are
SCR-114/116–121, likewise downstream of the count decode.

To make that honest, the L leg still carries the verbatim OP_PICK/OP_ROLL
handler body from `twin/ops_ir.py` (wires `0x79,0x7a`).  `build_w32.sh` runs
`mk_leaf.py --check` and byte-compares every selected body line, after its
`std::memcpy`/`std::memcmp` re-binding, against `src/l_leaf.cpp`; the build
prints

```text
provenance OK: 1 handler body/bodies verbatim in l_leaf.cpp
```

No hand-edited twin is claimed.  The leaves call the twin's own
`decode_num` (`w32_twin.h`, the bounded loop-free form of
`twin/runtime.inc:167-188`) for the decode, including the minimal-encoding
check, so both minimal-data settings are covered.  Only the compiler
directive `#pragma clang loop unroll(full)` is added in the verbatim block,
exactly as in the wave-65 cell; it is not part of the twin body text.

## Tool detail that mattered

`cell_cms_sig_prefix` and `cell_cms_sig_read` each contain one decode.  In
the earlier unsplit 13-input leaf, at `-O1` clang inlined the first (key)
`core_set_vch` but emitted an out-of-line `fastcc` call for the second.
Alive2 evaluated that call as `0` for a concrete `(len=1, b0=1)` input even
though the definition returns `1`, producing a spurious counterexample
(`%call42 = 0` in the trace).  Marking the scalar helpers
`__attribute__((always_inline))` removes every call from the extracted
modules.  This is a cell-source change, not a tool flag; the shared harness
is untouched.  The same compile settings as the wave-32 numeric family are
used (`-O1 -fno-strict-aliasing -fno-jump-tables`, `--max-depth 4
--max-elem 5`).

The first official SAW pass rejected the unsplit signature leaf on the C
leg only (the oracle, not the legs): the final underflow gate used
`i + nSigsCount` with the pre-`isig` cursor `i = 2 + nKeysCount`, one stack
slot too shallow.  Core increments `i` again at `int isig = ++i` before
`i += nSigsCount` (interpreter.cpp:1145-1146), so the gate is
`depth < isig + nSigsCount`.  SAW's counterexample was `nKeysCount = 15`,
`depth = 19`, `nSigsCount = 2` (Core: underflow; old oracle: ok).  The
oracle was corrected; the split leaves both prove.  Alive2 was unaffected
because it compares the two legs directly, not against the oracle.

## Domain arms

`depth > 1000` and `opCount > 201` are engine invariants (MAX_STACK_SIZE,
MAX_OPS_PER_SCRIPT).  Both legs return a distinct sentinel on those arms
rather than letting a `(int)`/`int64_t` cast decide an unreachable state.
This keeps each function total and the Alive2 query well-defined without
claiming anything about an unreachable stack size.

## Files

```text
spec/equiv/cells/e2-numeric/C-L-w66-scr086-clamp-uses/
  spec.md
  notes.md
  src/{build.sh,fns.txt,ops.txt,c_leaf.cpp,l_leaf.cpp,cell.cry,cell.saw}
  alive2/{run.sh,result.txt,certificate.sha256}
  saw/{run.sh,result.txt,certificate.sha256}
  build/ (regenerated: both legs' IR, build.txt, twin_ops.h, cell.cry, cell.saw)
```

No edit to `PINS.lock`, `contract/**`, `spec/db/*`, `results/**`, `docs/**`,
Lean proofs, the shared ledger, the shared twin/runtime, the wave-32 harness,
or any existing cell.
