# Wave 16 — 13-policy-reimport

Convert the nine `policy-flags` / `tapscript-reimport` ledger rows
(SCR-175 … SCR-183) from `gap` / `unjudged-seam` into real both-tool cells.

| field | value |
| --- | --- |
| branch | `wave16/13-policy-reimport` |
| base / `repo_head` | `805c8042f92d3bed909ca40219a4d21fc9150cc1` (PR #29 head) |
| Core pin | `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` |
| contract | `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6` |
| tools | alive-tv 20.0 (LLVM 20.1.2), SAW 1.6 (`68eed5f`), clang 20.1.2 |
| Core patches | none (`patches: none` in every cell) |
| shared files touched | none |

## Row dispositions

Nine cells, one per row. Every cell has a real Alive2 run and a real SAW run;
Alive2 is invoked **both ways** per root (`L ⊑ C` and `C ⊑ L`) and SAW verifies
both the C leg and the L leg against the same independent Cryptol predicate.

| SCR | cell | coverage | consensus | Alive2 | SAW |
| --- | --- | --- | --- | --- | --- |
| 175 | `cells/policy-flags/C-L-lows-policy` | **partial** | false | green, 2 directions | green, 1 root × 2 legs |
| 176 | `cells/policy-flags/C-L-strictenc-pubkey` | full | false | green, 2 directions | green, 1 root × 2 legs |
| 177 | `cells/policy-flags/C-L-minimaldata-push` | full | false | green, 2 directions | green, 1 root × 2 legs |
| 178 | `cells/policy-flags/C-L-minimalif-v0` | full | false | green, 2 directions | green, 1 root × 2 legs |
| 179 | `cells/policy-flags/C-L-nullfail` | full | false | green, 2 directions | green, 1 root × 2 legs |
| 180 | `cells/policy-flags/C-L-cleanstack-base` | full | false | green, 2 directions | green, 1 root × 2 legs |
| 181 | `cells/policy-flags/C-L-const-scriptcode` | full | false | green, 4 directions | green, 2 roots × 2 legs |
| 182 | `cells/policy-flags/C-L-witness-pubkeytype` | full | false | green, 2 directions | green, 1 root × 2 legs |
| 183 | `cells/tapscript-reimport/C-L-tapscript-reimport` | full | **true** | green, 4 directions | green, 2 roots × 2 legs |

Totals: **8 rows full both-tool green, 1 row partial both-tool green**,
22 Alive2 direction checks, 22 SAW proofs, 69 concrete vectors.

The observable in every cell is the single Core `ScriptError` ordinal
(`0` = no error; `contract/error_enum.md`). `0xff` is the cell's
out-of-domain guard and is never produced by Core.

### What each cell pins down

- **175** — `CheckSignatureEncoding` `LOW_S` gate and its precedence after the
  DER gate (`interpreter.cpp:207-224`), with the full 256-bit `S <= n/2`
  comparison. Ordinals 24 (`SIG_DER`) and 27 (`SIG_HIGH_S`).
- **176** — `STRICTENC` pubkey gate and `IsCompressedOrUncompressedPubKey`
  (`:74-94`, `:229-231`); ordinal 29 (`PUBKEYTYPE`).
- **177** — `MINIMALDATA` push gate and `CheckMinimalPush`
  (`:442`, `:487-491`); ordinal 25 (`MINIMALDATA`).
- **178** — `MINIMALIF` policy arm for witness v0 only (`:631-637`);
  ordinal 31 (`MINIMALIF`).
- **179** — `NULLFAIL` gate (`:351-352`); ordinal 32 (`SIG_NULLFAIL`).
- **180** — `CLEANSTACK` policy bit on base spends (`:2110-2118`) versus the
  flag-independent witness-v0 check (`:1876-1878`); ordinal 30.
- **181** — `CONST_SCRIPTCODE` at `OP_CODESEPARATOR` (`:484-486`) and
  `FindAndDelete` (`:339-343`); ordinals 53 and 54.
- **182** — `WITNESS_PUBKEYTYPE`, witness-v0 only (`:233-235`); ordinal 44.
- **183** — tapscript minimal-IF (`:623-629`, consensus, flag-independent;
  ordinal 51) and the shared implicit clean-stack tail (`:1876-1878`;
  ordinal 30).

## Why SCR-175 is partial

The cell's domain is the canonical DER skeleton
`30 25 02 01 <R> 02 20 <S:32> <hashtype>` (`lenR == 1`, `lenS == 32`). Within
that domain the cell proves, for every 64-bit flag word and every 256-bit `S`:

- the three free `IsValidSignatureEncoding` conditions (`:149`, `:172`, `:177`)
  and the resulting DER/DERSIG/STRICTENC precedence;
- the complete `s <= n/2` comparison (`SIG_S_HALF_ORDER`, `Defs.lean:88-91`,
  `checkLowS` `:355-362`);
- C ≡ L in both directions.

**Not covered:** DER shapes with `lenR > 1` or `lenS != 32` (the byte-addressed
parser and the full `:118-180` table for those shapes), the size-bound
rejections, and the libsecp256k1 DER-lax parse and scalar-overflow window
(`docs/DECISION-lax-ecdsa.md` §2-3). Covering those needs a symbolic-length,
byte-addressed signature model; that is the recorded next action, not a claim
here. The `S <= n/2` predicate itself is the same-crypto seam: the cell proves
Core's/Lean's predicate equality, not libsecp256k1.

Rows 176–183 are `full` relative to their cited Core lines and the stated input
domain (documented per cell in `spec.md`); none of them models the surrounding
interpreter loop.

## Consensus status

- **175–182: `consensus: false`.** `GetBlockScriptFlags`
  (`src/validation.cpp:2249-2288`) starts from
  `P2SH | WITNESS | TAPROOT` and only adds `DERSIG`, `CLTV`, `CSV` and
  `NULLDUMMY`. It never sets `LOW_S`, `STRICTENC`, `MINIMALDATA`, `MINIMALIF`,
  `NULLFAIL`, `CLEANSTACK`, `CONST_SCRIPTCODE` or `WITNESS_PUBKEYTYPE`; none of
  these is in `MANDATORY_SCRIPT_VERIFY_FLAGS` (`src/policy/policy.h:104-110`),
  and all of them are in `STANDARD_SCRIPT_VERIFY_FLAGS` (`:118-133`). The cells
  therefore prove policy gates only and make no consensus-invalidity claim.
- **183: `consensus: true`.** Tapscript minimal-IF (`interpreter.cpp:623-629`)
  returns before the witness-v0 `MINIMALIF` policy arm, and the clean-stack tail
  of `ExecuteWitnessScript` (`:1876-1878`) reads no flag. Both are enforced for
  every tapscript spend regardless of the flag word, which the cells show
  symbolically (MINIMALIF is a free input that changes no result).
- **180 is mixed in substance**: the base-spend gate is the policy bit; the
  witness-v0 half is consensus and flag-independent. The cell keeps the halves
  separate and the row is filed `consensus: false` because the *flag* is policy.
  The tapscript instance of clean-stack is SCR-183's cell.

Flag names/masks were read from the pin's `src/script/interpreter.h:46-151`
(`mask = 1 << bit`, `src/script/verify_flags.h`), not copied from comments;
`tools/flags_probe.cpp` includes the real header and
`tools/run_flags_probe.sh` reproduces `tools/flags_probe.out`:

```
P2SH bit=0 0x00001   STRICTENC bit=1 0x00002   DERSIG bit=2 0x00004
LOW_S bit=3 0x00008  NULLDUMMY bit=4 0x00010  MINIMALDATA bit=6 0x00040
CLEANSTACK bit=8 0x00100  WITNESS bit=11 0x00800  MINIMALIF bit=13 0x02000
NULLFAIL bit=14 0x04000  WITNESS_PUBKEYTYPE bit=15 0x08000
CONST_SCRIPTCODE bit=16 0x10000  TAPROOT bit=17 0x20000
```

## Evidence layout and reproduction

Each cell is self-contained:

```
<cell>/spec.md                     front matter (coverage, consensus, citations)
<cell>/c_cell.cpp, l_cell.cpp      C excerpt and reviewed Lean transliteration
<cell>/buildspec                   cell id, roots, SAW marker
<cell>/_tools/                     cell-local harness (header + build/run scripts)
<cell>/alive2/run.sh, result.txt, certificate.sha256
<cell>/saw/run.sh, result.txt, certificate.sha256
<cell>/saw/cell.cry, cell.saw      independent predicate + both-leg proof script
<cell>/ir/                         tracked textual IR hashed by the certificates
<cell>/build/                      gitignored scratch (bitcode, SAW imports)
```

The certificates deliberately hash **tracked** inputs only (`spec.md`, the two
C++ legs, `buildspec`, the cell harness, `saw/cell.cry`, `saw/cell.saw`,
`ir/*.ll`, `ir/build.txt`, `result.txt`) and never `build/`, so
`sha256sum -c` succeeds from a fresh checkout. `ir/*.ll` is `llvm-dis` of the
compiled module; the SAW runner additionally disassembles the bitcode it loads
and byte-compares it with `ir/*.ll` before proving, so the hashed module is the
one SAW verified.

Commands (run from the repo root; already run for this commit):

```sh
for c in spec/equiv/cells/policy-flags/C-L-*/alive2/run.sh \
         spec/equiv/cells/policy-flags/C-L-*/saw/run.sh \
         spec/equiv/cells/tapscript-reimport/*/alive2/run.sh \
         spec/equiv/cells/tapscript-reimport/*/saw/run.sh; do bash "$c"; done

for c in spec/equiv/cells/policy-flags/C-L-*/alive2/certificate.sha256 \
         spec/equiv/cells/policy-flags/C-L-*/saw/certificate.sha256 \
         spec/equiv/cells/tapscript-reimport/*/alive2/certificate.sha256 \
         spec/equiv/cells/tapscript-reimport/*/saw/certificate.sha256; do
  sha256sum -c "$c"
done
```

Observed: all 18 runs exit 0 and end in
`STATUS=alive2-green` / `STATUS=saw-green`; all 18 certificates verify
(`18/18 OK`, 0 failures, no hashed path under `build/`).

## Behavioural cross-check (not proof evidence)

`tools/concrete_check.cpp` links every cell's C leg **and** Lean
transliteration (L symbols renamed `lcell_*`) into one binary and checks 69
hand-computed vectors, each annotated with the Core line it comes from. This is
labelled behavioural: it checks that the predicate the tools proved is the
*right* predicate, not that C ≡ L (Alive2/SAW already prove that for all
inputs).

```
$ bash spec/equiv/findings/wave16/13-policy-reimport/tools/run_concrete.sh
...
vectors=69 failures=0
```

It also exercises the out-of-domain guards (`0xff`) and the
policy-versus-consensus split for tapscript (MINIMALIF free, result unchanged).

## Notable finding during construction

SAW produced a counterexample for the witness-v0 minimal-IF Cryptol predicate:
it read `~notMinimal` where the row requires `notMinimal`, inverting the
verdict. The independent Cryptol spec — not the two C++ legs — caught it; after
the fix the same cell proved green. This is recorded because it shows the SAW
leg is not a restatement of either C++ file.

## Operational note

A single `xargs -P4` rerun of the nine Alive2 cells once reported
`alive2-not-green` for `C-L-nullfail` while that cell's raw text contained two
`Transformation seems to be correct!` summaries and zero errors; rerunning the
cell's own `alive2/run.sh` wrote a green result. The committed artifacts are
from serial/per-cell runs, and the status is derived from the raw tool text, not
from exit codes (alive-tv exits 0 on counterexamples).

## Blockers and remaining work

- No tool or infrastructure blockers.
- SCR-175 remains **partial** for the reasons above; next action is a
  symbolic-length, byte-addressed DER parser cell plus the libsecp lax-parse
  seam.
- `spec/db/equiv-cells.yaml` still shows these rows as `gap` /
  `unjudged-seam`; it was intentionally not edited (shared file). The
  orchestrator's ledger updater should map the rows to the cells above.
- All other rows remain as filed; nothing here narrows them.

## Trust boundaries

C legs are line-cited excerpts, not whole Core functions. L legs are reviewed
transliterations of the Lean definitions at the pin, not generated from
`twin/ops_ir.py`. The rows are pure flag/encoding predicates with the stack or
signature content supplied as inputs, so each cell proves the *enforcement*
predicate, not `EvalScript` or the whole engine loop. Crypto verdicts are inputs
under the same-crypto premise; no libsecp or SHA implementation is claimed.
