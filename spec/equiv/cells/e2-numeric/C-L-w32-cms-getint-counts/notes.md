# Notes — C-L-w32-cms-getint-counts

## What this cell is for

SCR-086's summary is "clamp to int32 for depth/count uses" and its core_ref is
`script.h:326-333`.  The prior gap said the OP_PICK depth use was proved for
all four-byte operands, while OP_ROLL, the CHECKMULTISIG count reads, and an
L-side clamp counterpart remained.  This cell does two things and nothing
more:

1. **Isolates the clamp itself.** `cell_clamp_int32` is Core's
   `CScriptNum::getint()` on a fully symbolic `int64_t`.  Both firing arms
   (`> INT_MAX`, `< INT_MIN`) are reachable, and both C and L legs are proved
   against an independent Cryptol statement of the three-way clamp.  This is
   the "int32 clamp semantics" part, without the vacuity of the operand-width
   cap hiding a wrong clamp.
2. **Adds one call site: the CMS key/sig count reads.** `cell_cms_counts4`
   decodes two raw four-byte CScriptNum operands, applies `getint()`, and runs
   Core's front-matter decision in order (`interpreter.cpp:1122-1146`).  Both
   directions are proved for every byte pattern of both operands, and SAW
   checks each leg against a byte-level Cryptol oracle.

## What is not claimed

- **Not** a claim that the twin or Lean implements the clamp.  The twin's
  `decode_num` has no int32 clamp, and `twin/ops_ir.py` has no CHECKMULTISIG
  handler.  The L CMS leg is a reviewed transliteration of Lean
  `checkMultiSig`, which keeps an unbounded `Int`; it deliberately contains
  no clamp.  The proof shows the clamp is unobservable at this call site, not
  that an L clamp exists.  The L clamp leaf is a transliteration of
  `getIntClamped`, again not a twin handler.
- **Not** a full CHECKMULTISIG proof.  The signature/pubkey verification
  loops (`cmsLoop`), `FindAndDelete`, NULLDUMMY, and the cleanup pops are out
  of scope.  Only the count decode and the front-matter decision are here.
- **Not** OP_ROLL.  See the blocker below.
- **Not** a five-byte or wider operand case.  Four bytes is the maximum the
  count call site accepts; wider operands are rejected by the CScriptNum
  width guard before `getint()` and are already covered by
  `push-encoding/C-L-w32-num-decode-minimal` (nMaxNumSize 4 and 5).
- **Not** `fRequireMinimal = true`.  The cell fixes the flag false; the
  minimal subset is a restriction of the proved domain, and the decode cell
  covers minimality separately.

## Why the clamp is vacuous at these sites

For a four-byte little-endian sign-magnitude operand the top byte contributes
at most `0x7f << 24` and the other three bytes at most `0xffffff`, so the
magnitude is at most `0x7fffffff = 2147483647`.  The negative range is
`[-2147483647, -1]` (negative zero is 0).  Every value is already inside
`[INT_MIN, INT_MAX]`, so `getint()` returns it unchanged.  The Lean statement
is `PDW86Clamp.setVchBE_bounds_of_length_le_four` and
`PDW86Clamp.decodeNum_getIntClamped`.

The firing arms therefore exist only in the isolated clamp leaf, fed by
`int64_t` values that a four-byte operand cannot produce.  That is exactly
why the missing L clamp is not an equivalence bug: the domain cannot reach
the clamp arms.  It would become observable only if a caller passed a wider
`m_value`, which the CMS/PICK/ROLL decoders do not.

## Exact OP_ROLL blocker

OP_ROLL shares the twin handler body with OP_PICK in `twin/ops_ir.py`
(wires `0x79, 0x7a`).  The ROLL branch contains

```c
for (uint32_t i = idx; i + 1 < st.stack.n - 1; ++i) {
  std::memcpy(st.stack.e[i], st.stack.e[i + 1], st.stack.len[i + 1]);
  st.stack.len[i] = st.stack.len[i + 1];
}
```

Alive2 does not unroll loops (`--unroll` is not part of the pinned Alive2
configuration used by the rest of this family), and the loop bound is
symbolic in the operand `idx`.  So the verbatim twin ROLL body cannot be
ingested.  An unrolled bounded ROLL (depth 4) would be a transliteration, not
the `mk_leaf.py`-generated body, and `build_w32.sh`'s provenance gate would
correctly reject it; claiming it as the twin ROLL would overclaim.  A separate
unrolled transliteration is possible as future work but does not advance the
clamp question beyond this cell: the depth operand is four bytes, so the
clamp is identity exactly as in OP_PICK and CMS.

This is the exact residual, not a tool failure: Alive2 did run on both leaves
here, and the blocker is loop shape plus provenance, not a timeout or a
missing binary.

## Scope of "all four-byte operands"

Both count operands are exactly four bytes with all eight bytes symbolic.
This is the maximal accepted width, and it includes every non-minimal
encoding at that width.  Zero- to three-byte counts are a subset of the
same sign-magnitude range; their decode is proved in
`push-encoding/C-L-w32-num-decode-minimal` and the clamp leaf proves the
clamp on the full int64 domain, so no clamp behavior is left unexamined for
shorter operands.  What is not written as a single symbolic-length function
is the CMS layout at every length simultaneously; that would add no clamp
coverage, only re-prove decode.

## Tool configuration

- Alive2: `/usr/local/bin/alive-tv --bidirectional`, so `L ⊑ C` and `C ⊑ L`
  are both real results.  Both functions are pure, loop-free, and take only
  scalar arguments; no external calls or memory are involved.  The runner
  requires the success line, a 1/2 summary, zero incorrect transformations,
  and no error.
- SAW: pinned `/opt/equiv-tools/saw-1.6/bin/saw`, solver `z3`.  Four
  `Proof succeeded!` lines (C and L for each leaf).  The oracle is
  `src/cell.cry`, written from the Core lines and Lean statements, not from
  either leg.
- Certificates are root-relative `sha256sum` manifests over `spec.md`,
  `notes.md`, both runners, `src/` sources, the shared wave-32 harness
  (`_tools/w32-num/*`, `_tools/mk_leaf.py`, `twin/ops_ir.py`, `twin/gen.py`,
  `contract/error_kind.h`), the build records, the raw result, and the three
  tracked Lean inputs for the L transliteration.  Verify with
  `sha256sum -c` from the worktree root.

## Reproduction

```sh
cd /tmp/opencode/wave64/21-scr-086
./spec/equiv/cells/e2-numeric/C-L-w32-cms-getint-counts/alive2/run.sh
./spec/equiv/cells/e2-numeric/C-L-w32-cms-getint-counts/saw/run.sh
(cd . && sha256sum -c spec/equiv/cells/e2-numeric/C-L-w32-cms-getint-counts/alive2/certificate.sha256)
(cd . && sha256sum -c spec/equiv/cells/e2-numeric/C-L-w32-cms-getint-counts/saw/certificate.sha256)
```
