# Miniscript test-vector corpus

`miniscript.jsonl` is a data-only extraction from the miniscript tests in the
pinned Bitcoin Core tree at commit `cce32b16874e`.  It records the miniscript
string, the evaluation context, the expected script hex, the validity and
type assertions that the test makes, and the source line.  It is not a
miniscript implementation, not a proof, and not a claim about script
execution.

## Source pin

| Item | Value |
|---|---|
| Tree | `<core-build>/src` |
| Commit | `cce32b16874e` |
| Test file | `src/test/miniscript_tests.cpp` |
| Grammar/validity model | `src/script/miniscript.h:1848-2208` (`Parse`) |
| Context/size limits | `src/script/miniscript.h:284-295`, `src/policy/policy.h:60` |
| `IsSane` definition | `src/script/miniscript.h:1699-1703` |
| Corpus | 221 rows, 373,920 bytes, 64 rows with a non-null expected script |
| SHA-256 of `miniscript.jsonl` | `8b80f2906e1c0334791954538e200cc3555526540f7b22a23cd29539a0107355` |

The `TestMode` flags and the two-context `Test` wrapper are at
`src/test/miniscript_tests.cpp:435-494`.  The fixed vectors are at
`:501-742`; the script-inference negatives are at `:601-606` and `:652-660`.

## What is machine-extracted

Every data value in the file is machine-extracted from the pinned source.
No miniscript string, script hex, flag, limit, or expectation was transcribed
by hand.

* **Literal `Test("...")` calls.**  The extractor reads the string arguments,
  the `TESTMODE_*` expression, optional ops/stack/witness/exec limits, and the
  trailing source comment.  It emits one row per context (`P2WSH` and
  `TAPSCRIPT`) because the two-context wrapper at
  `src/test/miniscript_tests.cpp:478-487` runs both.  A context is marked
  invalid exactly when the mode has `TESTMODE_INVALID`, or the matching
  `TESTMODE_P2WSH_INVALID` / `TESTMODE_TAPSCRIPT_INVALID` bit.
* **Assertion blocks.**  The `multi()` ops/stack check at `:670-673`, the
  invalid `d:`-in-`thresh` vector at `:681-683`, the duplicate-key sanity
  checks at `:685-708`, the insane-subexpression vector at `:714-720`, and the
  signed-number parse rejections at `:723-726` are extracted from their
  `FromString` arguments and `BOOST_CHECK` assertions.
* **Source-loop vectors.**  The 21-key `multi_a` at `:610-616`, the
  99/110/200-key `and_b(pk(...),a:...)` loops at `:621-628`, and the
  998/999-deep `and_b(older(1),a:...)` loops at `:630-648` are reconstructed
  from the loop bounds and the same test pubkeys.  The pubkeys are derived
  from the `TestData` key bytes (`src/test/miniscript_tests.cpp:51-103`:
  31 zero bytes followed by the key number) using secp256k1; the first two
  derived keys are checked against key strings present in the source file.
  For the 21-key `multi_a`, the x-only keys in the literal tapscript hex are
  checked against the derived keys before the row is written.
* **Script-inference negatives.**  The seven `FromScript` calls that must
  return `nullopt` at `:601-606` and `:652-660` are recorded with
  `miniscript: null`, the input script hex, and `from_script_expected:
  "reject"`.  They are not miniscript vectors and are counted separately.

## What is hand-transcribed

Nothing.  The only non-source text consists of field names, the `id` format,
and the parser's derived classification (`grammar_parse_ok`, `top_fragment`,
`fragment_counts`).  Those derived fields are described below.

## Record schema

| Field | Meaning |
|---|---|
| `id` | Stable row id built from source line and context; loop rows add a short hash suffix. |
| `core_commit`, `source`, `source_line` | Pin and exact source line. |
| `also_source_lines` | Additional identical source occurrences merged into this row. |
| `kind` | `miniscript`, `metrics`, `validity`, `sanity`, `parse_reject`, or `script_inference`. |
| `origin` | `literal_Test_call`, `source_loop_reconstruction`, `assertion_block`, or `from_script_negative`. |
| `context` | `P2WSH` or `TAPSCRIPT`. |
| `miniscript` | Textual miniscript, or `null` for script-inference rows. |
| `expected_script_hex` | Script hex asserted by the source, or `null` when absent. |
| `unasserted_hex_argument` | Hex passed to a context the test marks invalid; the source does not compare it. `null` otherwise. |
| `expected_script_asm` | Always `null`; the source carries no assembly text. |
| `expected_satisfaction`, `expected_witness` | Always `null`; the source computes satisfactions at runtime and stores no static witness. |
| `valid` | `true`/`false` from `TestMode`; `null` when validity is not asserted (sanity-only rows and script-inference rows). |
| `sane` | `true`/`false` only where a `BOOST_CHECK` asserts `IsSane()`; otherwise `null`. |
| `non_malleable`, `needs_signature`, `timelock_mix` | From `TESTMODE_NONMAL`, `TESTMODE_NEEDSIG`, `TESTMODE_TIMELOCKMIX`; only for rows the source treats as valid. |
| `duplicate_key_check` | Explicit `CheckDuplicateKey()` assertion in the sanity vectors; otherwise `null`. |
| `insane_sub_miniscript` | `FindInsaneSub()` string asserted for the timelock-mix vector; otherwise `null`. |
| `ops_limit`, `stack_limit`, `witness_size`, `exec_stack_size` | Non-default limits supplied to `Test`; `null` when the source passes `-1`, `{}`, or omits the argument. |
| `mode_flags` | Raw `TESTMODE_*` names from the source. |
| `loop_parameters` | Loop bounds for `source_loop_reconstruction` rows; otherwise `null`. |
| `grammar_parse_ok`, `grammar_parse_error` | Result of the grammar check described below. |
| `top_fragment` | Outermost fragment after stripping wrappers; `pk`/`pkh` keep their alias names. |
| `fragment_counts` | Post-alias-expansion fragment occurrence counts for parsed rows. |
| `dynamic_satisfaction_test` | `true` when `TestSatisfy` runs on this row at test time. |
| `input_script_hex`, `from_script_expected` | Input script and `"reject"` for script-inference rows; otherwise `null`. |

## Lossy and unknown fields

* **No witness.**  `TestSatisfy` (`src/test/miniscript_tests.cpp:347-433`)
  derives satisfactions from a satisfier and verifies them; no witness bytes
  are written to the source.  Every `expected_witness` and
  `expected_satisfaction` is therefore `null`.
* **No assembly.**  The tests compare `HexStr(computed_script)` with a hex
  literal (`:463`).  `expected_script_asm` is `null` for all rows.
* **Missing expected script.**  When the source passes `"?"`, the row has
  `expected_script_hex: null`.  This is deliberate: the source made no script
  assertion, so no script is invented.
* **Invalid-context hex arguments.**  For a context marked invalid by
  `TESTMODE_P2WSH_INVALID` or `TESTMODE_TAPSCRIPT_INVALID`, the test returns
  before the script comparison.  The row has `expected_script_hex: null` and
  preserves the supplied text in `unasserted_hex_argument`.
* **Sanity is mostly unknown.**  The `Test` helper asserts `IsValid()`,
  `IsValidTopLevel()`, the type flags, ops/stack/witness limits, and the
  script round-trip, but not `IsSane()`.  Rows from `Test` therefore have
  `sane: null` even when `valid: true`; validity does not imply sanity.
  Explicit sanity results exist only for `:685-708` and `:714-720`.
* **Ops/stack limits are not executed.**  They are source literals or
  arithmetic expressions evaluated at extraction time, not observations from
  running the test binary.  On rows the source marks invalid, the supplied
  limits are recorded but the test returns before checking them.
* **No VM execution.**  The parser model checks the grammar, key/hash lengths,
  numeric ranges, arities, `multi`/`multi_a` context restrictions, threshold
  bounds, and the script-size ceiling (3600 bytes for P2WSH; 329,482 bytes for
  tapscript, derived from `src/script/miniscript.h:284-295`).  It does not
  evaluate types, satisfactions, or scripts.  The `valid` field remains the
  source's assertion, not a parser inference.
* **Duplicate occurrences.**  Identical `Test` calls at `:556`/`:731` and
  `:557`/`:732` are merged, with the later line in `also_source_lines`.
  Occurrences that carry different metrics (`:591` and `:739`) remain separate
  rows.
* **Node-API stress test.**  `node_stress_stack` at `:744-778` constructs
  200,000 nested `Node` objects through the C++ API and has no textual
  miniscript or script expectation, so it is not represented.

## Grammar check

The check models `Parse` at `src/script/miniscript.h:1848-2208`:

* wrappers `a s c d j n v u t l`, with `vv` rejected and a colon required;
* `0`, `1`, `pk`, `pkh`, `pk_k`, `pk_h`, the four hash fragments, `after`,
  `older`, `multi`, `multi_a`, `thresh`, `andor`, `and_n`, `and_b`, `and_v`,
  `or_b`, `or_c`, `or_d`, `or_i`;
* compressed or uncompressed SEC public keys, exact hash lengths, unsigned
  decimal timelocks in `[1, 2^31)`, `multi` only under P2WSH with at most 20
  keys, `multi_a` only under tapscript with at most 999 keys, and
  `1 <= k <= n` for `multi`, `multi_a`, and `thresh`;
* the P2WSH/tapscript script-size ceilings above.

Results over the 214 rows that carry a miniscript:

| Classification | Rows |
|---|---:|
| Parses and source says valid | 122 |
| Parses but source says invalid (type/validity failure) | 54 |
| Does not parse under this constraint model, and source says invalid | 32 |
| Parses, validity not asserted (metrics/sanity vectors) | 6 |

All 122 rows marked `valid: true` parse.  The 32 parser-rejected rows are
intentional negative vectors: out-of-range timelocks, `thresh` with `k > n` or
`k = 0`, signed numbers, `multi` used under tapscript, `multi_a` used under
P2WSH, and P2WSH scripts above the 3600-byte ceiling.  The seven
`script_inference` rows have no miniscript and are outside this table.

## Quick inspection

```sh
jq -c 'select(.context=="TAPSCRIPT" and .valid==true)' miniscript.jsonl | head
jq -r 'select(.expected_script_hex != null) | [.id,.miniscript,.expected_script_hex] | @tsv' miniscript.jsonl
jq -r 'select(.grammar_parse_ok==false) | [.id,.grammar_parse_error] | @tsv' miniscript.jsonl
```
