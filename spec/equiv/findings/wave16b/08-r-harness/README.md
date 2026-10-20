# Wave16B / 08-r-harness — public-API R adapter probe

**Status: prototype + behavioral measurement. Advisory only. Not a cell, not a
proof artifact, no green row.**
**Branch:** `wave16b/08-r-harness` (from `805c804`) · **Date:** 2026-10-20
**Attacks:** F-HARNESS-002 (R public entry is untyped and domain-restricted)

## Question

Can a clean **public-API** shim/adapter, without patching rbitcoin, expose a
domain sufficient for C-R and L-R cells? Concretely: a typed error ordinal, the
Core flag word, and the tape's `input_index`/multi-input shape.

## Answer

**Behaviorally, substantially yes. For proof cells, no.**

- A 406-line adapter (`adapter/entry_r3.rs`) built only on
  `rbitcoin_consensus::verify_tx_scripts_with_flags` widens the usable C-R
  domain from *one input / `flags == 0` / 3 error tokens* to
  *`input_index == 0` / multi-input BASE and WITNESS_V0* /
  *16 of Core's 21 flag bits* / *77 source error tokens mapped + 3 dynamic
  families*, with 0 unclassified and 0 stale map entries.
- On 71 behavioral cases in the shared domain it agrees with the pinned Core
  oracle on **`(result, error_kind)` 71/71**, including E0, stack/flow limits,
  locktime flags, P2PKH, P2SH, witness v0, taproot key-path edges, CMS, and
  multi-input input 0.
- Seven domain rows still return `BAD_INPUT (2)` by design (5 policy flag bits,
  `input_index > 0`, multi-input native witness v1+). Five external rows are
  recorded divergences, not gate cases.
- **R proof cells remain blocked** by the entry shape (detached-thread
  all-inputs public API, no public per-input function) and by
  F-TOOL-001 (Alive2 v20 cannot ingest the repo LLVM 22 IR; the 1.88 proof
  lane is advisory). No row may be marked green on the strength of this work.

See `verdict.md` for the decision and `domain-table.md` for the exact domain.

## Pins and artifacts

| Item | Value |
|---|---|
| Repo head under test | `805c8042f92d3bed909ca40219a4d21fc9150cc1` |
| rbitcoin | `ae47aa98174e04d0d8c493f13041daf65e4ac1d3`, clean tree |
| Core | `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (C oracle, unchanged) |
| Repo / behavioral toolchain | rustc 1.95.0 (`59807616e`), LLVM 22.1.2 |
| Proof-lane toolchain (not used here) | rustc 1.88.0, LLVM 20.1.5 |
| Baseline shim `shims/rust/entry.rs` | `73e3d2d96de864e11e7cfb7cc5cc9fbba5d0dad1dc5de08b4cad6114ad1dffde` |
| Adapter `adapter/entry_r3.rs` | `5f040d9563402711e8b72bc5cc72430bc098429b2826b9a176d50a2fbc32c4a9` |
| Adapter `.so` | `94a60b1f4004b16ac304ad1c6e59655ccb21bd0038c47eb19d2a5cf9a0b236ca` |
| Adapter diff vs shim | `914535f6b43fd333cf7c5e47818aa616bbda2823cb22915462634fa998d1b4ea` |
| C oracle `.so` | `5fef1df004adae637ffd7d3d7bf7dc96700c552dc2c22729d0de06d81457fbb5` |

The baseline shim rebuilt from the clean pin reproduces the E0-recorded hash,
so the environment matches the earlier evidence. No rbitcoin or Core source
was modified. `git -C rbitcoin-clean status --porcelain` is empty.

## What the adapter changes (diff, not replacement)

`adapter/entry_r3.diff` is the full diff against `shims/rust/entry.rs`.

1. **Error boundary map.** rbitcoin returns
   `ConsensusError::Script(String)`; it has no typed `ScriptError`. The adapter
   maps the engine's closed message vocabulary to Core ordinals. It is
   flag-dependent in exactly one place: `der sig` is `SIG_DER (24)` when
   DERSIG is on and `EVAL_FALSE (2)` when it is off (fast-path lax parse).
   `unknown opcode 0x6a` is special-cased to `OP_RETURN (3)`, while other
   unknown opcodes map to `BAD_OPCODE (16)`.
2. **Full flag word.** `flags & ~0x1fffff`, `WITNESS ⇒ P2SH`, and
   `CLEANSTACK ⇒ P2SH ∧ WITNESS` are enforced as `BAD_INPUT`. The 16 bits
   mirrored by `ScriptVerifyFlags` are forwarded. The 5 policy-only bits
   (5, 7, 18, 19, 20) have no engine field and are **rejected**, not silently
   dropped.
3. **Multi-input, target input 0.** The public entry verifies every input in
   order. For `input_index == 0` on a multi-input tx, other inputs receive a
   synthetic `OP_TRUE` prevout; a failure annotated `vin != 0` is discarded
   because the contract asks only about input 0. This is exact for BASE and
   WITNESS_V0 (BIP143 does not hash other inputs' amounts/scripts). For a
   native witness v1+ target it returns `BAD_INPUT`, because BIP341 hashes all
   spent outputs. P2SH-wrapped v1 is *not* BIP341 (Core guards the taproot
   branch with `&& !is_p2sh`), so it is supported as an unknown program and
   matches Core. `input_index > 0` remains irreducible and is `BAD_INPUT`.
4. **Baseline domain bugs fixed.** Amount is bounded by `MAX_MONEY`; the
   `spk_len > 10_000` pre-check is removed so Core's `SCRIPT_SIZE (5)` is
   reached; flags are no longer forced to zero.

## Behavioral results

Command (full log in `logs/behavior.log`):

```sh
python3 tools/diff_driver.py --strict
```

| Category | Agreement & C==want | Meaning |
|---|---:|---|
| `core` | **71/71** | shared-domain cases, gate on `--strict` |
| `domain` | 3/10 | 7 rows intentionally `BAD_INPUT`; rest agree |
| `external` | 0/5 | recorded divergences, not gate |

Non-matching rows, all understood:

| Row | C | R | Cause |
|---|---|---|---|
| `multi index1` | `(1,0)` | `(2,1)` | public entry cannot skip input 0 |
| `multi input0 taproot` | `(0,39)` | `(2,1)` | synthetic prevouts would change BIP341 sighash |
| flags bits 5, 7, 18, 19, 20 | varies | `(2,1)` | no `ScriptVerifyFlags` field; rejected |
| `p2sh non-push + hash mismatch` | `(0,2)` | `(0,26)` | **engine** error precedence: Core evaluates spk before push-only |
| `malleated + false program` | `(0,2)` | `(0,41)` | **engine** error precedence: rbitcoin checks scriptSig emptiness first |
| `p2wpkh empty witness item` (3 rows) | `2` or `12` | `(0,1)` | one token, two Core outcomes depending on pubkey hash |

The two **engine** precedence divergences are not boundary artifacts: the
adapter reports the engine's real token. They are C-R findings at the pin and
must not be mapped away to force agreement.

## Error-token census

Command (full log in `logs/census.log`):

```sh
python3 tools/token_census.py --strict
```

The pinned engine source contains **108** `ConsensusError::Script` tokens
(test modules excluded). Classification:

| Class | Count | Handling |
|---|---:|---|
| mapped (exact literal) | 77 | Core ordinal from `mapped_kind`/`kind_of` |
| mapped-dynamic (opcode prefixes) | 3 | `disabled opcode 0x` → 17; `unknown opcode 0x` → 16; `0x6a` → 3 |
| internal | 25 | engine misuse/unreachable encoding error → result 3 |
| test-only | 2 | `#[cfg(test)]` helper only |
| gap | 1 | `p2wpkh empty witness item` → `EQUIV_ERR_UNKNOWN_ERROR` |
| unclassified | **0** | — |
| stale map literals | **0** | — |

`--strict` exits non-zero on any unclassified source token or stale map entry.
This is a **source-drift alarm**, not a proof of totality: a re-pin must re-run
it and review new tokens.

## Remaining blockers (exact)

**Behavioral / boundary**

- B1. Flags 5 (`SIGPUSHONLY`), 7 (`DISCOURAGE_UPGRADABLE_NOPS`), 18, 19, 20
  are in-contract but unrepresentable in `ScriptVerifyFlags`. The adapter
  returns `2`. Cells using them are R-inadmissible.
- B2. `input_index > 0` is in-contract but unreachable: the public entry
  verifies earlier inputs first and their prevouts are not on the tape.
- B3. Multi-input with a native witness v1+ target is `2` (BIP341 commits to
  all spent outputs; the contract's `(0, empty)` convention makes signatures
  synthetic anyway).
- B4. `p2wpkh empty witness item` stays `UNKNOWN` (Core can return 2 or 12;
  deciding requires inspecting witness/spk, i.e. duplicating implied-script
  logic at the boundary).
- B5. Two genuine engine error-precedence divergences (table above).

**Proof / L-R**

- P1. `verify_tx_scripts_with_flags` calls
  `script_pool::run_detached_join`: it spawns an OS thread and joins over an
  `mpsc` channel. It is not a single-function boundary and is not ingestible
  by Alive2/SAW. The single-input verifier `script::verify_input` is
  `pub(crate)`; there is no public per-input entry.
- P2. **F-TOOL-001:** Alive2 v20 rejects LLVM 22/23 IR (`dead_on_return`) and
  SAW 1.6 embeds LLVM 20.1.2. The proof lane uses rustc 1.88 (advisory,
  non-repo front-end). Adapter artifacts here are 1.95/LLVM 22.
- P3. The adapter is a *new* boundary crate. Proving `equiv_entry` would not
  prove rbitcoin internals; proving the engine needs an internal-symbol seam.
- P4. The error map is a string map. Behavioral coverage is not a refinement
  proof; the census only detects source drift.
- P5. Crypto is vendored C libsecp256k1; the same-crypto premise and any
  crypto-internal claim are out of scope here.

## Verdict

- C-R **behavioral** lane: usable over the widened domain, with B1–B5 excluded
  or recorded. This is real evidence, but behavioral only.
- L-R **proof** lane: **no R cell can be built under the pin.** The adapter
  does not change the entry shape or the toolchain blockers. No row may be
  marked green; any R row is `gap (F-HARNESS-002 / F-TOOL-001)`.

Recommended next step: request three upstream changes (typed `ScriptError`
return, public synchronous per-input verify entry, fields for the five policy
bits), and in parallel decide whether the proof lane may use rustc 1.88 or an
Alive2 transform. Until then, use this adapter only for C-R triage and file
B5 as C-R findings. Details in `verdict.md`.

## Refinement obligation / non-claims

- This is a **prototype adapter**, not a cell artifact and not a replacement
  for `shims/rust/entry.rs`.
- Agreement on 71 behaviors does **not** establish C-R or L-R equivalence. The
  remaining rows are exclusions, not passes.
- The error table must be re-derived and re-reviewed at every re-pin; no claim
  is made that the 108-token census is complete for future source.
- No Lean, consensus, crypto-internal, or proof-lane claim is made.
- No `unsafe` precondition was weakened: the adapter keeps the contract's
  pointer/length rules and treats NULL defensively only.

## Reproduction

```sh
# build (clean pin check; reusable rlibs)
RBTC=/tmp/opencode/equiv-work/rbitcoin-clean \
OUT=/tmp/opencode/wave16b-scratch/08-r-harness/libequiv-rust-r3.so \
TARGET=/tmp/opencode/equiv-work/target-195-lib \
sh adapter/build.sh

# behavior (C oracle + adapter)
python3 tools/diff_driver.py --strict

# token map census
python3 tools/token_census.py --strict

# baseline environment / E0-sha reproduction
# see logs/e0-baseline.log for exact commands and versions
```

## Files

| Path | Role |
|---|---|
| `adapter/entry_r3.rs` | adapter prototype (public API only) |
| `adapter/entry_r3.diff` | diff vs `shims/rust/entry.rs` |
| `adapter/build.sh` | pin-checked build |
| `tools/diff_driver.py` | C-vs-R behavioral differential (86 cases) |
| `tools/token_census.py` | token classification / drift alarm |
| `logs/build.log` | exact build output |
| `logs/behavior.log` | full differential output |
| `logs/census.log` | full census output |
| `logs/e0-baseline.log` | pins, versions, hashes, baseline-shim rebuild |
| `logs/artifacts.sha256` | hashes of sources, logs, and built `.so`s |
| `domain-table.md` | contract vs adapter domain, flag table, admissibility |
| `verdict.md` | decision and next step |
