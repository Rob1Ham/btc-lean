# Wave 16 — 04-push-stack

Advancing PR #29 on branch `wave16/04-push-stack` (cut from `805c804`). This
report covers the assigned `spec/equiv` SCR rows for push-encoding (SCR-045..055)
and stack-ops (SCR-073, 075, 076, 077, 078); SCR-074 was already covered by
`stack-ops/C-L-arity` and is not claimed here.

All cells are bounded, symbolic leaves: the C leg is a line-cited Core
transcription, the L leg calls the twin handler generated verbatim from
`twin/ops_ir.py` by `cells/_tools/mk_leaf.py`, and Alive2 compares C vs L while
SAW proves each leg against an independent Cryptol model. `patches: none` in
every cell. The only new supporting code is family-local harness under
`cells/push-encoding/_harness/` and `cells/stack-ops/_harness/` (dirs prefixed
`_` are skipped by the gate/ledger scripts); no shared file was edited.

## Row disposition

| Row | Cell | Coverage | Alive2 | SAW | Result |
|---|---|---|---|---|---|
| SCR-045 | `push-encoding/C-L-pushparse` | partial | 4/4 funcs | 8/8 proofs | decoder + truncation green; F-DIV-001 tail-precedence seam still open |
| SCR-046 | `push-encoding/C-L-pushnum` | full | 1/1 | 2/2 | both-green |
| SCR-047 | `push-encoding/C-L-pushnum` | full | 1/1 | 2/2 | both-green |
| SCR-048 | `push-encoding/C-L-minpush` | full | 1/1 | 2/2 | both-green |
| SCR-049 | `push-encoding/C-L-execgate` | full | 1/1 | 2/2 | both-green |
| SCR-050 | `push-encoding/C-L-scriptnum` | full | 1/1 | 2/2 | both-green |
| SCR-051 | `push-encoding/C-L-minnum` | partial | 3/3 | 6/6 | shared ctor branch green; CLTV/CSV/multisig sites and lengths 3..5 missing |
| SCR-052 | `push-encoding/C-L-pushonly` | full | 2/2 | 4/4 | both-green |
| SCR-053 | `push-encoding/C-L-templates` | full | 2/2 | 4/4 | both-green |
| SCR-054 | `push-encoding/C-L-templates` | full | 2/2 | 4/4 | both-green |
| SCR-055 | — | blocked | — | — | no twin counterpart for `IsPayToAnchor` |
| SCR-073 | `stack-ops/C-L-altstack` | full | 13/13 | 26/26 | both-green |
| SCR-074 | (covered elsewhere) | n/a | — | — | `stack-ops/C-L-arity`; not claimed here |
| SCR-075 | `stack-ops/C-L-pick` | full | 12/12 | 24/24 | both-green |
| SCR-076 | `stack-ops/C-L-depth-size` | full | 13/13 | 26/26 | both-green |
| SCR-077 | `stack-ops/C-L-ifdup` | full | 4/4 | 8/8 | both-green |
| SCR-078 | `stack-ops/C-L-underflow` | partial | 29/29 | 58/58 | reachable pre-checks green; higher insufficient depths, non-stack sites and the throw are missing |

"full" means every branch named by the row is inside the stated bound and the
cell's `spec.md` says `scr_row_coverage: full`. Partial cells are never used to
claim a row complete.

## Cells

### push-encoding

- `C-L-pushparse` (SCR-045, partial): 4 entries over one-op scripts with a
  symbolic script size 0..8, covering direct pushes, PUSHDATA1/2/4 and the
  truncated length-field/payload arms. The error-precedence seam in
  `findings/cross/F-DIV-001-eager-parse.md` — the twin/L lean eager `parseWire`
  failing before an earlier op runs, while Core's streaming `GetOp` fails at the
  malformed tail — is deliberately outside this cell.
- `C-L-pushnum` (SCR-046, SCR-047, full): one symbolic wire byte 0..255 plus a
  symbolic MINIMALDATA bit; covers `OP_0`, `OP_1NEGATE`, `OP_1..OP_16`, the
  truncated-push control and the non-push wires.
- `C-L-minpush` (SCR-048, full): `CheckMinimalPush` as a pure predicate over a
  symbolic 32-bit length, covering all length classes and both one-byte special
  cases.
- `C-L-execgate` (SCR-049, full): symbolic fExec and MINIMALDATA, including the
  "unexecuted non-minimal push is OK" direction.
- `C-L-scriptnum` (SCR-050, full): the CScriptNum minimality predicate and
  value decode for lengths 0..2, with both sign-byte exceptions.
- `C-L-minnum` (SCR-051, partial): OP_1ADD as the representative numeric arm.
  Three entries (operand length 0, 1, 2), symbolic MINIMALDATA, opcode counter
  and sigversion. It proves the shared CScriptNum policy branch and its
  interaction with the opcode budget, but not SCR-051's cited call sites:
  CLTV/CSV (`interpreter.cpp:556,584`, `nMaxNumSize = 5` plus locktime/sequence
  comparison) and the CHECKMULTISIG counts (`:1103,:1126,:1140`), nor operand
  lengths 3..5.
- `C-L-pushonly` (SCR-052, full): the `opcode <= OP_16` membership rule,
  including OP_RESERVED, in a one-byte and a two-byte law.
- `C-L-templates` (SCR-053, SCR-054, full): the 4..42-byte/program-length
  predicate and the 23-byte HASH160 pattern over fully symbolic inputs.

### stack-ops

- `C-L-altstack` (SCR-073, full): 13 entries; both underflows, both moves at
  every depth pair up to the bound, the unexecuted skip, and both sides of the
  nOpCount 201 edge for all three sigversions.
- `C-L-pick` (SCR-075, full): 12 entries; depth 0 guards, every valid constant
  ROLL index at depths 1..3, symbolic PICK indices at those depths (including
  0x80 negative zero and all out-of-range encodings), budget edge, and skip.
- `C-L-depth-size` (SCR-076, full): 13 entries; DEPTH at depths 0..3 and SIZE
  lengths 0,1,2,127,128,255,256,520, including the empty-stack SIZE case and
  both sign-byte paths of the length encoding.
- `C-L-ifdup` (SCR-077, full): 4 entries; empty-stack underflow, zero-length
  false, both one-byte false encodings (0x00, 0x80), and every true one-byte
  value at depths 1 and 2.
- `C-L-underflow` (SCR-078, partial): 29 entries; depth 0 for all sixteen
  stack-manipulation wires and depth 1 for the thirteen wires requiring two
  elements, each returning INVALID_STACK_OPERATION (18). Missing: higher
  insufficient depths for 3DUP/2OVER/2ROT/2SWAP/ROT, the popstack/stacktop
  sites outside 0x6d..0x7d, and the throw itself.

## Seam and blockers

**SCR-045 / F-DIV-001.** The decoder rule and "truncation => false =>
BAD_OPCODE" are green, but the error-kind precedence on a malformed tail after
a preceding op is a model seam, not a tool failure. The L leg eagerly parses
the whole wire; Core streams `GetOp` op by op. Closing it requires a decision
about which model owns the error precedence, not another bounded leaf. The
partial cell keeps this visible rather than absorbing it into a green.

**SCR-055 (blocked).** The row is `CScript::IsPayToAnchor`
(`src/script/script.cpp:207-222`), two pure predicates over a 4-byte script and
a 2-byte v1 program. There is no twin or Lean counterpart: a search of
`spec/equiv/twin` and `spec/equiv/shims` finds no anchor/P2A predicate. Writing
an L leg by hand would duplicate the C predicate and make the Alive2 comparison
vacuous, so no both-tool cell was built. Next action: first add the predicate
to the twin (a semantic change, outside a cell-scoped task), then a pure-predicate
leaf can be added. Until then SCR-055 remains a filed gap.

**SCR-051 (partial).** The shared ctor branch is proved, but discharging the row
needs the CLTV/CSV and CHECKMULTISIG call sites and their 5-byte allowance.
That is a larger cell (locktime/sequence semantics and multisig count
behaviour), not a minimality witness.

**SCR-078 (partial).** Core's `popstack` throw and `stacktop` `.at` throw have no
twin counterpart, so the throw path cannot be a both-tool green under the
current twin. The reachable pre-check boundary is what this cell proves.

## Harness notes

- Both families use a family-local harness. The push-encoding leaves use
  `pack_snum`/`pack_fail`/`pack_domain`; the stack-ops harness supports optional
  `OPT`/`BUILD_NAME`, which `C-L-pick` uses for separate `-O2` Alive2 and `-O1`
  SAW builds (O1 leaves an undef ROLL extraction Alive2 rejects; O2 makes
  SAW/abc report a `decode_num` poison). Each tool's certificate names its own
  build.
- `C-L-minnum` builds at max element size 3 because `32767 + 1` encodes as
  `00 80 00`. The generated twin `decode_num` is capped at 2 bytes; that cap is
  a harness bound, so the pushed result is read by a cell-local `obs_num` rather
  than turning the bound into a spurious SCRIPTNUM.
- Alive2 cannot handle symbolic stack depth (SMT array stores) or symbolic
  fExec, so depth and fExec are baked constants per entry; symbolic PICK index
  is fine, ROLL index is constant. These choices are stated in each `spec.md`.

## Validation

Run from the repository root after the final cell runs:

```sh
# per-cell (example)
bash spec/equiv/cells/push-encoding/C-L-minnum/alive2/run.sh
bash spec/equiv/cells/push-encoding/C-L-minnum/saw/run.sh
sha256sum -c spec/equiv/cells/push-encoding/C-L-minnum/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/push-encoding/C-L-minnum/saw/certificate.sha256

# every certificate in both families
for c in $(find spec/equiv/cells/push-encoding spec/equiv/cells/stack-ops \
             -name certificate.sha256 | sort); do
  sha256sum -c "$c" || echo "FAIL $c"
done
```

Result: all 28 certificates (14 cells x Alive2/SAW) verify with
`sha256sum -c`. Tool versions: Alive2 `Ubuntu LLVM version 20.1.2`,
SAW `1.6 (68eed5f release-1.6)`, clang `20.1.2`, llvm-extract `20.1.2`.
Raw `result.txt` files carry the commands, the tool tails and the
`STATUS=...-green` markers; no marker was written by hand.

## Changed paths

Only new directories under:

- `spec/equiv/cells/push-encoding/` (eight cells plus `_harness/`)
- `spec/equiv/cells/stack-ops/` (five cells plus `_harness/`)
- `spec/equiv/findings/wave16/04-push-stack/report.md`
