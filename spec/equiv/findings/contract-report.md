> **HISTORICAL ROLE REPORT — not the current state.** The live E6 checkpoint is
> `spec/equiv/results/STATUS.md` and `spec/equiv/docs/STATE.md`; the generated
> coverage view is `spec/equiv/results/matrix.md`. This file is retained for
> provenance and may describe an earlier zero-green/TODO-pin state.

# CONTRACT report — E0 harness contract and shims

> **Post-report re-pin:** the live contract is **v3**
> (`f1841e36…`), which adds `contract/error_enum.md` to the hash recipe
> (ABI §8 already made it normative). The v2 hash and narrative below are
> historical; no ABI field or error ordinal changed. See
> `contract/CHANGELOG.md`. Live cells cite v3.

Date: 2026-10-19. Role: CONTRACT. Write scope respected: `contract/`,
`shims/`, this report only. Nothing committed.

Pin used for every extraction and build check: Bitcoin Core v32.99 @
`cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (sparse `src/` checkout at
`/tmp/opencode/core-pin`, `git rev-parse HEAD` matched). rbitcoin reference
studied at `master` on the same date.

## Artifacts written

| Path | Purpose |
|---|---|
| `contract/ABI.md` | updated to **ABI v2**: one normative `equiv_entry` (8 args, mandatory `equiv_error_kind *`) + 7-arg `entry` wrapper; fixed §3/§5/§6 |
| `contract/tape.md` | normative tape, domain, witness channel, prevout convention, flags table, contract hash recipe |
| `contract/error_enum.md` | Core `ScriptError` → shared enum, complete grouped table; ABI-name reconciliation |
| `contract/error_kind.h` | generated shared enum (values mirror Core ordinals 0..55), `EQUIV_ABI_VERSION`, 32-bit static assert |
| `contract/extract_error_enum.py` | extractor (md/json/h), runs without Core, clear error + exit 2 if `CORE_SRC` absent |
| `contract/corpus_schema.md` | JSONL record schema + JSON Schema + corpus rules |
| `shims/core/entry.cpp` | complete C-ABI shim over Core `VerifyScript`, both symbols, `error_kind` |
| `shims/twin/entry.cpp` | compiling stub exporting both symbols, marked TODO(TWIN) |
| `shims/rust/entry.rs` | compiling `catch_unwind` stub exporting both symbols, marked TODO(RUST-IR) |
| `shims/README.md` | per-leg build/IR commands, no-engine-logic rule, trust notes |

## ABI v2 resolution (handoff `orchestrator-to-CONTRACT-001`)

The handoff correctly identified that ABI §1 (7-arg `entry`, no out-param)
and §2 ("optional out-parameter") disagreed, and that TWIN already ships
`twin_entry` + 7-arg `entry`. Decision, now normative in `ABI.md`:

* `equiv_entry(tx_bytes, tx_len, spk, spk_len, amount, input_index, flags,
  equiv_error_kind *error_kind)` is the proof-bearing symbol;
  `error_kind` is mandatory and written on every return.
* `entry(...)` (7 args) is a documented convenience wrapper that discards the
  kind. Existing status-only drivers keep working.
* `EQUIV_ABI_VERSION = 2` is in `error_kind.h`; the enum is
  `static_assert`ed 32-bit, so the Rust side can use `*mut i32`.
* E3 error-enum equality is judged on `equiv_entry`'s out-parameter.

All three shims export both symbols and were checked with `nm`. The TWIN
engine's internal `twin_entry` name is unaffected: the L shim is the boundary
and will call it internally.

Remaining coordination (outside CONTRACT write scope): add ABI version and
`contract/ABI.md` hash to `PINS.lock` (TOOLS/LEDGER); mark the handoff closed
(orchestrator); `README.md` §4 still shows only the 7-arg wrapper, which is
now correct but incomplete (owner may add `equiv_entry`).

## What actually ran

1. **Reference study.** Fetched rbitcoin `script-oracle/verify.cpp` and
   `build.rs`; confirmed the pattern (TX_WITH_WITNESS, one-input check,
   `TransactionSignatureChecker`, `PrecomputedTransactionData`,
   `MissingDataBehavior::FAIL`, `1/0/2/3`). Differences are tabulated in
   `tape.md` §9.
2. **Extractor.** `python3 -m py_compile` passed. Against the pinned checkout:
   56 dense entries 0..55, ending `SCRIPT_ERR_ERROR_COUNT`; all names except
   `UNKNOWN_ERROR`/`ERROR_COUNT` have a string. `--format md|json|h` all ran;
   `--strict-pin` matched; regenerating with `--format h` is byte-identical to
   `contract/error_kind.h`. With a nonexistent `CORE_SRC` it printed
   `error: CORE_SRC is absent or incomplete: ...` and exited 2; with
   `CORE_SRC` unset it also exited 2 with a clear message.
3. **Core shim.** `g++ 13.3.0 -std=c++20 -Wall -Wextra -fsyntax-only` clean.
   Then compiled `shims/core/entry.cpp` plus the Core object list with
   `-O0 -g -fPIC`, compiled libsecp256k1 with rbitcoin's defines, linked
   `libequiv-core.so`, and loaded it with a ctypes driver. Result: **23/23
   checks matched** expectations: 22 tape cases plus the 7-arg wrapper.
   Coverage: pass (`OP_1`), `EVAL_FALSE`, `BAD_OPCODE`, `OP_RETURN`,
   `INVALID_STACK_OPERATION`, truncated tx, trailing byte, index OOR, negative
   amount, amount > MAX_MONEY, unknown flag bit, WITNESS-without-P2SH,
   CLEANSTACK-without-P2SH+WITNESS, CLEANSTACK pass, CLEANSTACK fail (30),
   P2WPKH empty witness (40), P2WSH empty witness (39), P2WSH witness
   `[empty script]` (30), P2WSH witness `[OP_1]` pass, v1 program with TAPROOT
   off (pass), v1 with TAPROOT on + empty witness (39), P2SH with empty
   scriptSig (18). The witness cases exercise the in-tx witness channel, not
   just legacy serialization.
4. **Twin stub.** Compiled with g++ and linked to a `.so`; exports
   `equiv_entry` + `entry`; returns `(3, EQUIV_ERR_UNKNOWN_ERROR)` and `3`.
5. **Rust stub.** `rustc 1.99.0 --edition 2021 --crate-type cdylib
   -C panic=unwind` compiles warning-free; exports both symbols; ctypes calls
   return `(3, 1)` and `3`; NULL out-pointer is handled.
6. **Corpus schema.** Both JSON blocks parse with Python `json`; the example
   `tx_bytes`/`spk` was replayed through the Core shim and returns `(1, 0)`.

Hashes at time of writing:

```
contract hash: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
ABI.md sha256: 3c28f66665d033d317de208abeb628a44e6ed0cf0b4be78e9069c687bd2671a5
repo HEAD:     4d62a97e551082a69b13f495365bff0a903b0c99  (spec/equiv untracked)
```

The contract hash is `{ cat contract/ABI.md; cat contract/tape.md;
cat contract/error_kind.h; cat contract/corpus_schema.md; } | sha256sum`.
Changing `ABI.md` (v2) changed the hash from the earlier draft.

## Verification gaps / uncertainty (no fabrication)

* **No Alive2, SAW, clang, z3, cvc5, or alive-tv installed.** No IR was
  emitted or verified, and no proof ran. The C leg was built with **g++ 13.3**
  for a behavioral smoke test only; the proof lane still needs the pinned
  clang and `-emit-llvm` (TODO(TOOLS/CORE-IR)).
* **Core build recipe is not yet canonical.** `streams.cpp` at the pin pulls
  `FileCommit`/`TruncateFile` from `util/fs_helpers.cpp`, which needs the
  CMake-generated `bitcoin-build-config.h`. The smoke test linked a
  **test-only** TU providing those two never-called helpers. A proof artifact
  must use Core's real objects; the hand object list in `shims/README.md` is
  a fallback. TODO(CORE-IR/TOOLS): capture objects from Core's CMake build.
* **Domain decisions need ratification** (CELLS/REDTEAM): `amount` restricted
  to `0..MAX_MONEY`; flags restricted to the 21-bit mask plus
  `WITNESS⇒P2SH`, `CLEANSTACK⇒P2SH|WITNESS` (return 2); trailing bytes
  rejected (2); synthetic `(0, empty)` prevouts for non-current inputs.
  The last makes multi-input TAPROOT sighashes a harness convention, not
  consensus semantics. Cells needing genuine multi-input taproot must be
  filed as a gap. The rbitcoin reference oracle differs on all four points.
* **L/R error mappings are TODO** (TWIN-IR / RUST-IR). The stubs are not
  green and must not be cited in a cell.
* **Static pin guards are partial**: `shims/core/entry.cpp` asserts spot
  enum values + `COUNT` + 21 flag bits, not all 56 values. The generated
  header is the authoritative mapping; `extract_error_enum.py --strict-pin`
  is the full check.
* **Rust panic output**: `catch_unwind` preserves the default panic hook,
  which may print to stderr. Harnesses must compare only `(result, kind)`;
  a proof build may set a no-op hook in the driver, not in the shim.
* **`PINS.lock` not updated** (outside write scope): it still needs
  `abi_version = 2`, the `ABI.md` hash above, and the contract hash.

## Next actions

1. TOOLS/LEDGER: record ABI version/hash and contract hash in `PINS.lock`;
   mark the ABI handoff closed.
2. CORE-IR/TOOLS: pin clang, build Core + shim, emit IR at `-O0`, record
   hashes; replace the fallback object list with CMake-derived objects.
3. TWIN-IR/RUST-IR: fill stubs and publish error mappings; run the same 23
   checks per leg.
4. CELLS/REDTEAM: ratify or change the four domain decisions; add a mutation
   test that must be caught by the smoke cases.
