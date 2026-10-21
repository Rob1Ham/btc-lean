# push-encoding/C-L-w66-minimaldata-arbitrary-num

SCR-051 — minimal numeric operands under `SCRIPT_VERIFY_MINIMALDATA` at the
five cited decode sites (`interpreter.cpp:556,584,1126,1140,1103` @
`cce32b168`).  The row is a **policy** row (`consensus: false`).

This is a strengthening of `push-encoding/C-L-w32-minimaldata-sites` (wave
65): the operand length is now a **full 32-bit quantity** (not a 3-bit field),
the predicate carries an **independent canonical round-trip characterisation**
of minimality, the policy and consensus lanes are stated separately, and the
negative controls include precedence and width mutations.

## Shape

Six entry points, both tools on every entry point:

| entry point | cited line(s) | cap | decode |
|---|---|---:|---|
| `pred_cap5` | `:556`, `:584` | 5 | the predicate/observable for an arbitrary operand |
| `pred_cap4` | `:1126`, `:1140`, `:1103` | 4 | the same predicate at the default cap |
| `cell_cltv` | `interpreter.cpp:556` | 5 | `CScriptNum(stacktop(-1), fRequireMinimal, 5)` |
| `cell_csv` | `interpreter.cpp:584` | 5 | `CScriptNum(stacktop(-1), fRequireMinimal, 5)` |
| `cell_cms` | `interpreter.cpp:1126`, `1140` | 4 | key-count and sig-count `CScriptNum(..., fRequireMinimal)` |
| `cell_checksigadd` | `interpreter.cpp:1103` | 4 | number `CScriptNum(stacktop(-2), fRequireMinimal)` |

`fRequireMinimal` is **not a free Boolean** in this cell.  Every entry point
takes the full 64-bit script flags word and computes
`(flags & SCRIPT_VERIFY_MINIMALDATA) != 0`, matching
`interpreter.cpp:442`; the CLTV/CSV activation bits are read from the same
word.  The flag bit values are pinned by `contract/tape.md` and
`script/verify_flags.h:31` (`1 << ordinal`), with ordinals from
`interpreter.h:49-153`.

## Arbitrary-length operand

The operand is five bytes packed little-endian into a register word plus a
FULL 32-bit length.  No pointer, array or alloca is passed or read, so every
byte the proof talks about is a scalar argument.

The 32-bit length is not a modelling convenience: every element that can
reach these decodes has size <= `MAX_SCRIPT_ELEMENT_SIZE` (520), because
`EvalScript` rejects a larger push at `interpreter.cpp:457-458` and every
other element entered the stack through a push.  Both caps are <= 5, so the
width guard runs before the value path for `len > 5`, and for `len <= 5` only
byte indices `len-1` and `len-2` (<= 4) are consulted.  Proving the functions
for the whole 32-bit length therefore covers every legal operand length 0..520
and the unreachable >520 values; the wave-65 cell's 3-bit length could only
represent 0..7.

## The predicate

`script.h:246-271` rejects an operand under `fRequireMinimal` iff

```
(top & 0x7f) == 0  &&  (len <= 1 || (next & 0x80) == 0)
```

with the width guard (`len > nMaxNumSize`) running first.  This is the BIP62
rule-4 test: it rejects negative zero `0x80` and every padded encoding, and it
keeps the ±255 exception (`ff00`/`ff80` are minimal because the second byte's
high bit is set).  Both checks throw `scriptnum_error`, which EvalScript
catches as `SCRIPT_ERR_SCRIPTNUM` (4); their relative order is therefore not
observable in the contract's error kind.

### Round-trip characterisation

The predicate entry points also compute, independently of the two-byte test,

```
rt(operand)  :=  serialize(set_vch(operand)) == operand
```

using `script.h:342-373`'s canonical serialisation (magnitude bytes, then a
`0x00`/`0x80` sign-pad byte when the magnitude's top byte has bit 7 set).
This is the operational meaning of "minimal encoding": no byte can be removed
or changed without changing the decoded number.  The model states

```
len <= 5  =>  (rt(operand) <-> !nonminimal(operand))
```

and the witness driver exhaustively checks the two independent computations
agree for every 1- and 2-byte operand (65,792 cases at two flag settings) and
a 20,000-case sample of lengths 3..5.  The SAW model and both legs carry the
bit, and a pure-Cryptol SAW obligation proves the law for every five-byte
operand and every length 0..5, so the two formulations are linked at the SMT
level as well.

## What is proved

For every value of every parameter (including all 64-bit flag words):

* `pred_cap5` / `pred_cap4`: width guard, minimality, accept under the policy
  bit, the sign/zero/value fields, and the round-trip bit, for every operand
  and every 32-bit length.
* `cell_cltv`: flag-off NOP; depth floor; cap-5 decode; SCRIPTNUM;
  NEGATIVE_LOCKTIME for a negative decoded value; otherwise the handler
  continues.
* `cell_csv`: the same, plus the `SEQUENCE_LOCKTIME_DISABLE_FLAG` NOP after
  the decode (both post-decode branches are OK in this observable).
* `cell_cms`: tapscript rejection **before** the depth floor and decode; key
  count decode cap 4; `PUBKEY_COUNT`, `OP_COUNT`, key arity; sig count decode
  cap 4; `SIG_COUNT`, sig arity.  This is the full Core order at
  `interpreter.cpp:1113-1152` up to the count decode.
* `cell_checksigadd`: base/witnessV0 `BAD_OPCODE` before the depth floor; then
  cap-4 decode; SCRIPTNUM; otherwise the handler continues (the EvalChecksig
  outcome is not observed).

The Cryptol model in `src/cell.cry` states the predicate, the round-trip and
every verdict directly from `script.h`, `interpreter.cpp` and the contract;
C and L are each proved equal to it, so a shared C/L transcription error
cannot pass unnoticed.

## Error precedence

1. Site gates first: activation flag (CLTV/CSV), tapscript rejection (CMS),
   base/witnessV0 rejection (CHECKSIGADD), then the stack/depth floor.
2. Width guard, then the minimality test (same error kind).
3. A decode SCRIPTNUM precedes `NEGATIVE_LOCKTIME`, `PUBKEY_COUNT`,
   `OP_COUNT`, `SIG_COUNT` and the arity errors.  A negative but
   *non-minimal* 2-byte operand such as `01 80` is the witness: with bit 6
   set it returns SCRIPTNUM; with bit 6 clear it decodes to −1 and the next
   check (NEGATIVE_LOCKTIME for CLTV/CSV) fires instead.
4. The CMS tapscript rejection and the CHECKSIGADD base/witnessV0 rejection
   are **consensus** edges (BIP342), not MINIMALDATA effects.  They are in the
   cell only because they precede the decode at the same cited line family.

There is one precedence subtlety that the 32-bit length makes observable and
which the negative controls pin: the width guard runs before the minimality
test.  An over-cap operand is SCRIPTNUM even when it is also non-minimal, and
`M4` (width guard off-by-one) is killed precisely there.

## Policy vs consensus

`MINIMALDATA` is policy: it is not part of block validation.  The cell proves
the conditional statement, for both settings of bit 6:

* bit 6 clear — a within-cap operand is never rejected by this rule, including
  negative zero `0x80`, `00 00 00 00 00`, and every other padded form; the
  value path and the following checks proceed exactly as without a
  minimal-encoding rule;
* bit 6 set — exactly the non-minimal within-cap operands are rejected with
  SCRIPTNUM, i.e. exactly those whose canonical serialisation differs from
  their bytes; minimal operands, the ±255 exception, and width-rejected
  operands behave as above (width remains SCRIPTNUM).

No claim is made that bit 6 is set in consensus, that standardness equals
acceptance, or that the consensus width cap changes.  The width cap is
INV-058 and the width rows are SCR-079..SCR-081.

## Relationship to the earlier SCR-051 cells

`push-encoding/C-L-w32-num-decode-minimal` proved the shared constructor for
both caps; `push-encoding/C-L-w32-num-callsites` added the four handler call
sites but passed the policy bit as a free Boolean, omitted the CMS tapscript
gate, and labelled itself partial because it also modelled downstream
semantics that belong to other rows.  `C-L-w32-minimaldata-sites` (wave 65)
closed the row with four handler slices, but used a 3-bit length and did not
state the round-trip characterisation.

This cell adds the two predicate entry points at a full 32-bit length, the
independent round-trip bit, a policy/consensus lane witness over every
1- and 2-byte operand, and precedence/width mutants.  It is deliberately
scoped to the row's `check` — the minimal-encoding predicate and the policy
error path at the five cited decodes — and stops at the first post-decode
consumer.  The downstream checks are **other rows** (`SCR-122..SCR-129`,
`SCR-114..121`, `SCR-113`), not missing pieces of this one, so this cell does
not mark its row coverage partial.

## L-leg provenance (labelled trust downgrade)

The L handler arms are a reviewed transliteration of the pinned
`Defs.lean` equations (`:857-875`, `:1069-1090`, `:803-811`, `:1048-1059`,
`:629-632`).  The decoder body is the generated twin's `decode_num`
(`runtime.inc:167-188`) with the byte loop unrolled for the concrete length
(<= 5 after the width guard).  The canonical encoder is the generated twin's
`encode_num` (`runtime.inc:139-158`) with the magnitude loop bounded at five
steps: on this domain `|value| < 2^39`, so five magnitude bytes plus at most
one sign/pad byte.  The flag bit values come from the generated twin's
constants (`runtime.inc:348-352`).

The shared generated twin still has no CLTV/CSV decode and no CHECKMULTISIG
handler: `ops_ir.py:42-61` returns `TWIN_INVALID_UNSUPPORTED` when the
activation flag is on, and `gen.py:222-225` lists CHECKMULTISIG unsupported.
This cell therefore does **not** claim equivalence of the shared twin's opcode
table for these sites; it claims the Lean model arms agree with Core at the
row's decode sites, with the L link downgraded to "reviewed transliteration"
(the fallback allowed by `spec/equiv/README.md` section 3).  Closing the
generated-twin gap needs shared-model work, which is outside this cell.

## Results

```
alive2/result.txt   6 comparisons: "Transformation seems to be correct!",
                    "These functions seem to be equivalent!", 1 correct
                    transformation each, 0 Alive2 errors
saw/result.txt      12 x "Proof succeeded!", no "Proof failed", plus a
                    pure-Cryptol obligation proving rtOK <-> !nonminPos for
                    len <= 5 (bitwuzla; SBV->Z3 did not discharge the
                    32-bit-length predicate goals in reasonable time)
mutations/          13 mutant/entry-point pairs, all at the expected verdict
witnesses/          1,178,192 checks, 0 failures
```

SAW uses bitwuzla for all 12 obligations.  The predicate goals carry a full
32-bit length and a canonical re-encoding; the default SBV->Z3 backend did not
discharge them in a useful time, while bitwuzla proves each leg against the
model in seconds.  The same Cryptol model and the same method specs are used
for every proof.

Alive2 is run with a 900 s per-query timeout in this cell's `alive2/run.sh`:
the two predicate functions carry a full 32-bit length and a canonical
re-encoding, and the two-decoder CMS function is markedly harder for the SMT
solver than the one-operand cells.  The shared 60 s default timed out under
load; the predicate queries take roughly 8 minutes each on the loaded host.
The timeout changes only the resource bound, not the query.

## Negative controls

`mutations/run_mutants.sh` patches a scratch copy of the C leaf (the tracked
source is untouched) and compares each mutant with the unmodified L leaf.
Expected verdicts are per (mutant, entry point), so the script also pins
*which* obligation each function carries:

| mutant | mutation | expected red |
|---|---|---|
| M1 | `F_MINIMALDATA` `0x40 -> 0x20` | `pred_cap5`, `cell_cltv`, `cell_cms` |
| M2 | drop the second-byte `0x80` exception | `cell_cltv`, `cell_cms` |
| M3 | accept negative zero (top mask `0x7f -> 0xff`) | `cell_cltv`, `cell_cms` |
| M4 | width guard `len > maxsize + 1` | `cell_cltv`, `cell_cms` |
| M5 | CMS `OP_COUNT` before `PUBKEY_COUNT` | `cell_cms` |
| M6 | drop `NEGATIVE_LOCKTIME` (CLTV and CSV) | `cell_cltv` |
| M7 | flip the round-trip bit in `pred_body` | `pred_cap5`; `cell_cltv` stays green |

Every expected-red pair is killed by a counterexample
(`Transformation doesn't verify!`), not by a solver timeout; the green cell in
M7 (the handler does not observe the round-trip bit) shows the check is not
merely "any mutation fails".  If M1 or M7 survived, the equivalence
obligation would not constrain the policy rule or the round-trip bit the
strengthening is about.

## Witnesses

`witnesses/run_witnesses.sh` compiles `witnesses/driver.cpp` against the
tracked C leaf and checks:

* a 47-row error-precedence table covering every gate order, both caps, the
  ±255 exception, negative zero, the 20-key / 201-op boundaries and the
  nonminimal-vs-next-error precedence;
* the policy lane at a real handler (`cell_checksigadd`): SCRIPTNUM iff
  bit 6 is set and the operand is non-minimal, over every 1- and 2-byte
  operand; with bit 6 clear no operand is rejected by the rule;
* the round-trip law and the decoded value/sign/zero fields over the same
  exhaustive 1- and 2-byte enumeration plus the 3..5 sample;
* width rejection at lengths 6 and 7, and the cap-4/cap-5 difference at
  length 5.

## Commands

From the worktree root:

```sh
spec/equiv/cells/push-encoding/C-L-w66-minimaldata-arbitrary-num/alive2/run.sh
spec/equiv/cells/push-encoding/C-L-w66-minimaldata-arbitrary-num/saw/run.sh
spec/equiv/cells/push-encoding/C-L-w66-minimaldata-arbitrary-num/mutations/run_mutants.sh
spec/equiv/cells/push-encoding/C-L-w66-minimaldata-arbitrary-num/witnesses/run_witnesses.sh
sha256sum -c spec/equiv/cells/push-encoding/C-L-w66-minimaldata-arbitrary-num/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/push-encoding/C-L-w66-minimaldata-arbitrary-num/saw/certificate.sha256
sha256sum -c spec/equiv/cells/push-encoding/C-L-w66-minimaldata-arbitrary-num/mutations/certificate.sha256
sha256sum -c spec/equiv/cells/push-encoding/C-L-w66-minimaldata-arbitrary-num/witnesses/certificate.sha256
```

`build/` is gitignored, as for every cell; a fresh checkout must run the
scripts once before the `build/*` certificate lines verify.  The tracked-input
lines (`src/*`, `spec.md`, `notes.md`, harness, `twin/ops_ir.py`,
`twin/gen.py`, `twin/runtime.inc`, `contract/error_kind.h`) verify
immediately.

## What is not claimed

* The R leg.
* Whole-`EvalScript`/`VerifyScript` equivalence, the `fExec` gate, the 201-op
  budget enforcement outside the CMS counter, or the exception edge.
* `CheckLockTime`/`CheckSequence` comparisons, CMS signature verification,
  NULLDUMMY/NULLFAIL/FindAndDelete, CHECKSIGADD's Schnorr verification or the
  pushed value.
* Any consensus effect of MINIMALDATA; the row is policy.
* Operand lengths above 520 as reachable engine states; they are included in
  the quantified domain but are already rejected at push time.
