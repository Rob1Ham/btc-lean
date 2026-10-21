---
# Cell C-L-w66-scr086-clamp-uses

contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 8142cff
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: e2-numeric/C-L-w66-scr086-clamp-uses
family: numeric
tool_status: both-green (five loop-free scalar leaves; every depth/count call site)
precondition: |
  - `cell_clamp_int32(x)`: `x` is Core's `int64_t CScriptNum::m_value`,
    completely symbolic over all 64-bit values.  Both clamp arms fire.
  - `cell_depth_read(len, b0..b4, depth, minimal)`: the operand is an
    arbitrary stack element: `len` is its byte length (symbolic, so the
    width arm `len > 4` and every length 0..4 are covered), `b0..b3` are its
    bytes (symbolic), `b4` is present but unread (Core rejects length > 4
    before reading).  `minimal` models `fRequireMinimal` (0 = false, any
    nonzero = true; the MINIMALDATA flag).  `depth` is the pre-pop stack
    size.  The engine invariant `depth <= 1000` (MAX_STACK_SIZE,
    script.h:44) is explicit: larger values hit a distinct domain arm.
    This is the single depth call site textually shared by OP_PICK and
    OP_ROLL (interpreter.cpp:840).
  - `cell_cms_key_count(len, b0..b3, opCount, minimal)`: arbitrary
    four-byte-capable operand, both minimal-data settings, and Core's
    EvalScript-local `nOpCount` with the maintained invariant
    `opCount <= 201` (MAX_OPS_PER_SCRIPT, script.h:32; larger values hit a
    domain arm).  It is the `nKeysCount` read at interpreter.cpp:1126.
  - `cell_cms_sig_prefix(lk, kb0..kb3, depth, opCount, minimal)`: the same
    key-side read as it appears in the `nSigsCount` path, with the
    key-side depth gate (`depth < 2 + nKeysCount`).  Status 0 means the
    signature read is reached; the pack then carries the decoded key count
    and `ikey2`.
  - `cell_cms_sig_read(nk, depth, ls, sb0..sb3, minimal)`: the `nSigsCount`
    read (interpreter.cpp:1140-1146) given the decoded key count `nk`, with
    the signature operand arbitrary, both minimal-data settings and
    symbolic `depth`.  `nk` outside `[0, 20]` is an unreachable-state
    domain arm (status 7) so the leaf is total; the composition only
    applies it on prefix status 0, where `nk` is already in `[0, 20]`.
    The nSigsCount path is split here only so each SAW query contains one
    decode; spec.md's composition argument joins the two leaves into the
    full path.
postcondition: |
  - `cell_clamp_int32` returns Core `CScriptNum::getint()`
    (script.h:326-333): `INT_MAX` above the range, `INT_MIN` below it, the
    value itself in range.  L is Lean `getIntClamped`
    (Numeric/ScriptNum.lean:741-744).
  - `cell_depth_read` returns
    `status(2) | err(6)<<2 | idx(16)<<8 | n(32)<<24`
    (status 0 ok, 1 SCRIPTNUM, 2 INVALID_STACK_OPERATION, 3 out of the
    depth domain).  In Core's order: the `size() < 2` guard
    (interpreter.cpp:838-839), the CScriptNum width check
    (script.h:249-251), the minimal-encoding check (script.h:252-268), the
    clamped `getint()`, `popstack`, the `n < 0 || n >= size()` guard
    (:842-843), and `stacktop(-n-1)`'s index (:844).  `n` is exposed so a
    clamp difference cannot hide in the index.
  - `cell_cms_key_count` returns `status(3) | nKeys(32)<<3 | ikey2(6)<<35`
    (0 ok, 1 PUBKEY_COUNT, 2 OP_COUNT, 5 SCRIPTNUM, 7 out of domain), with
    the clamped key count exposed: Core's nKeysCount read, the
    `[0, 20]` bound, `nOpCount += nKeysCount` and the `> 201` check, and
    the derived `ikey2 = nKeys + 2` (:1126-1138).
  - `cell_cms_sig_prefix` returns
    `status(3) | nSigs(32)<<3 | ikey2(6)<<35 | isig(6)<<41 | nKeys(5)<<47`
    on its failure arms (1 PUBKEY_COUNT, 2 OP_COUNT, 3 INVALID_STACK_OPERATION
    for the key-side gate, 5 SCRIPTNUM, 7 out of domain) and the same layout
    with status 0 on the reached read, carrying `nKeys` and `ikey2`.
  - `cell_cms_sig_read` returns the same layout for the signature read:
    status 0 ok, 3 INVALID_STACK_OPERATION (signature-side gate), 4
    SIG_COUNT, 5 SCRIPTNUM, 7 out of the unreachable `nk` domain, with the
    clamped signature count, `ikey2`, the accepted key count and `isig`
    exposed.  Cursor arithmetic follows Core:
    `i = 1` at entry, the key read, `i += nKeysCount` (key gate
    `depth < 2 + nKeysCount`), then `isig = ++i` and `i += nSigsCount`
    (signature gate `depth < isig + nSigsCount`).
  - Composition of the two leaves (same for both legs): for any inputs, if
    the prefix status is nonzero the full `nSigsCount` path returns exactly
    the prefix pack; otherwise it returns `sig_read(prefix.nKeys, depth,
    ls, sb0..sb3, minimal)`.  Both legs implement that same split, the two
    leaves are proved equal to the independent oracle pointwise, and the
    read leaf's `ikey2`/`isig` are recomputed from `prefix.nKeys` exactly as
    Core does.  Hence the full path is equal on both legs.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-086
scr_row_coverage: |
  full — every `getint()` depth/count consumer named by the row is proved
  for arbitrary reachable inputs, and the clamp function itself is proved
  total.
  - The depth consumer is one call site (`CScriptNum(stacktop(-1),
    fRequireMinimal).getint()`, interpreter.cpp:840) shared by OP_PICK and
    OP_ROLL.  `cell_depth_read` covers every operand length (0..4 plus the
    width arm), every operand byte, both minimal-data settings, every
    pre-pop depth in the engine domain, the underflow/width/minimal error
    arms, every in-range index, and the decoded depth value.
  - The count consumers are `nKeysCount` (:1126) and `nSigsCount` (:1140).
    `cell_cms_key_count`, `cell_cms_sig_prefix` and `cell_cms_sig_read`
    cover every operand length/byte, both minimal-data settings, every
    domain depth and nOpCount, all precedence arms, both derived cursors and
    the accepted counts.  The `nSigsCount` path is split at its read so each
    leaf has one decode; the two leaves compose as stated in the
    postcondition.
  - `cell_clamp_int32` proves Core's clamp on all `int64_t`, including both
    firing arms that no four-byte operand can reach.  Composition: on the
    four-byte-capped domain `set_vch` lies in `[-2^31+1, 2^31-1]`, so the
    clamp is the identity (Lean: `decodeNum_getIntClamped`); hence the
    unclamped L value equals Core's clamped value at every consumer.
  - The OP_ROLL stack-shift loop and the CHECKMULTISIG verification loops
    are stack-effect subjects (SCR-075 and SCR-114/116-121), not clamp
    subjects, and are downstream of the values proved here.  The clamp is
    applied to the decoded scalar before either loop is reached; these
    leaves expose that scalar, so a clamp difference would be a
    counterexample here regardless of the loop.  The twin handler body is
    still present verbatim in the L leg and the build's provenance gate
    passes (see notes.md).
patches: none
source_citations:
  - "script.h:32,44 (MAX_OPS_PER_SCRIPT = 201, MAX_STACK_SIZE = 1000)"
  - "script.h:326-333 (getint int32 clamp)"
  - "script.h:246-271 (CScriptNum width and minimal checks; nMaxNumSize = 4)"
  - "script.h:376-391 (set_vch, little-endian sign-magnitude)"
  - "interpreter.cpp:833-849 (OP_PICK/OP_ROLL depth read and guard/index)"
  - "interpreter.cpp:1122-1146 (CHECKMULTISIG count reads and precedence)"
  - "spec/core/Bitcoin/Numeric/ScriptNum.lean:741-744 (getIntClamped)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:966-976 (PICK/ROLL decode)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1071-1096 (checkMultiSig front matter)"
  - "spec/proofs/BitcoinProofs/AF/PDW86/PDW86Clamp.lean (clamp identity at all four sites)"
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.h and
  interpreter.cpp at the pin, not the whole EvalScript.  L calls the twin's
  own `decode_num` (w32_twin.h, the bounded loop-free form of
  twin/runtime.inc:167-188) and the handler's guard/index prefix; the
  verbatim OP_PICK/OP_ROLL handler body from twin/ops_ir.py (wires
  0x79,0x7a) is present in l_leaf.cpp and `build_w32.sh`'s provenance gate
  reports `provenance OK: 1 handler body/bodies verbatim in l_leaf.cpp`,
  with no twin file edited.  For CHECKMULTISIG the twin has no handler, so
  the L leg is a reviewed transliteration of Lean `checkMultiSig`
  (Defs.lean:1071-1096) and `decodeNum` (minimal-data-aware, as Lean's
  `decodeScriptNum` is); the clamp leaf's L leg transliterates
  `getIntClamped`.  The L legs deliberately contain no clamp applied to
  consumers, matching Lean's unbounded `Int`; the cell proves that this is
  unobservable, not that the twin or Lean contains a clamp.  The
  depth/opCount domain arms make the leaves total without claiming
  unreachable engine states.  No Core, twin, Lean, contract, ledger,
  results, docs, or shared-harness file is modified.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - build/ (both legs' IR, build.txt, cell.cry, cell.saw, twin_ops.h)
mutant: >
  In the clamp leaf, change INT_MAX to INT_MAX-1 or drop an arm.  In the
  depth leaf, use the unclamped decode in C (or clamp in L) so the exposed
  `n` differs for a five-byte operand.  In the CMS leaves, change the `[0,
  20]` bound, the `nSigs <= nKeys` bound, or a cursor by one.  Expected:
  Alive2 counterexample and SAW oracle failure.  The clamp leaf's firing
  arms are exercised by the oracle, so a clamp-only mutation cannot hide
  behind the vacuous four-byte domain.
mutant_site: |
  e2-numeric/C-L-w66-scr086-clamp-uses/src/{c,l}_leaf.cpp (any listed
  function), or the independent src/cell.cry for a spec-side mutation.
---
