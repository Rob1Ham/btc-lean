# Verdict — can public-API R cells be built under the pin?

**No for L-R proof cells. Yes for a widened C-R behavioral probe domain.
No row is green.**

## What was asked

F-HARNESS-002 says the pinned R public entry is untyped and domain-restricted:
narrow error tokens, `flags != 0` rejected, single input only. The task was to
find whether a clean adapter can expose a domain sufficient for C-R/L-R cells
without patching rbitcoin, and to prototype the smallest one.

## What was shown

A public-API adapter (`adapter/entry_r3.rs`, built only on
`verify_tx_scripts_with_flags`) exists and behaves as designed:

- **Error map:** 108 pinned engine tokens classified: 77 mapped, 3 dynamic
  opcode families, 25 internal, 2 test-only, 1 explicit gap, **0 unclassified,
  0 stale**. The single context-dependent token (`der sig`) is resolved from
  DERSIG at the boundary.
- **Flags:** 16 of 21 Core bits forwarded; the 5 policy-only bits are rejected
  as `BAD_INPUT` instead of silently dropped.
- **Inputs:** `input_index == 0` works for single-input and for multi-input BASE
  and WITNESS_V0 (other inputs emulated with synthetic prevouts; later `vin`
  failures discarded). Single-input taproot is supported.
- **Behavior:** 71/71 shared-domain cases agree with the pinned Core oracle on
  `(result, error_kind)`. Seven domain rows are deliberate `BAD_INPUT`; five
  external rows are recorded (3 boundary-map gaps, 2 genuine engine precedence
  divergences).

This is a real widening over the baseline shim: from 3 error tokens / flags 0 /
one input, to 77+3 token classes / 16 flags / input 0 on multi-input
BASE+WITNESS_V0. It does **not** make the R leg proof-capable.

## Exact remaining blockers

### Boundary (behavioral)

- **B1 — policy flag bits.** 5 `SIGPUSHONLY`, 7 `DISCOURAGE_UPGRADABLE_NOPS`,
  18 `DISCOURAGE_UPGRADABLE_TAPROOT_VERSION`, 19 `DISCOURAGE_OP_SUCCESS`,
  20 `DISCOURAGE_UPGRADABLE_PUBKEYTYPE` have no `ScriptVerifyFlags` field.
  Adapter returns `2`. These rows are R-inadmissible.
- **B2 — `input_index > 0`.** The public entry verifies earlier inputs first
  and their prevouts are not on the tape. Adapter returns `2`.
- **B3 — multi-input native witness v1+.** BIP341 hashes every spent output;
  synthetic prevouts change the sighash. Adapter returns `2`.
- **B4 — `p2wpkh empty witness item`.** One engine token, two Core outcomes
  (`EVAL_FALSE 2` vs `EQUALVERIFY 12`) depending on whether the empty pubkey
  hashes to the program. Adapter leaves it `UNKNOWN (1)`.
- **B5 — genuine engine divergences.** At the pin, rbitcoin’s error precedence
  differs from Core:
  `p2sh non-push + hash mismatch` → C `(0,2)` / R `(0,26)`;
  `malleated + false program` → C `(0,2)` / R `(0,41)`.
  These are C-R findings; no shim may “fix” them without changing the engine.

### Proof (L-R)

- **P1 — entry shape.** `verify_tx_scripts_with_flags` calls
  `script_pool::run_detached_join`, spawning an OS thread and joining over an
  `mpsc` channel. It is not a single-function boundary for Alive2/SAW. The
  per-input `script::verify_input` is `pub(crate)`, so there is no public
  synchronous per-input entry to prove.
- **P2 — F-TOOL-001.** Alive2 v20 rejects the repo’s LLVM 22/23 IR
  (`dead_on_return`); SAW 1.6 embeds LLVM 20.1.2. The 1.88 proof build is a
  non-repo front-end and advisory. This adapter is built with the repo pin
  (1.95.0), so its IR is not ingestible either.
- **P3 — seam.** The adapter is a new boundary wrapper, not an rbitcoin
  symbol. Proving it does not prove the engine; proving the engine requires an
  internal-symbol seam (and the FFI patch remains unauthorized, R-GAP-04).
- **P4 — map totality.** The string map is validated behaviorally and by a
  source census, not by refinement. A re-pin can add tokens; `--strict` is a
  drift alarm, not a theorem.

## Decision

1. **Do not build R proof cells under the pin.** Mark any such row
   `gap (F-HARNESS-002, F-TOOL-001)`. Do not mark it green on the strength of
   the 71/71 behavioral match.
2. **C-R behavioral cells may use the widened domain** only as advisory
   evidence, with B1–B5 excluded or recorded. The `core` corpus in
   `tools/diff_driver.py` is the current ceiling of that domain.
3. **Do not map around B5.** Reporting Core’s ordinal for those cases would
   hide a real engine divergence.
4. **Do not treat `p2wpkh empty witness item` as a mapped token.** It remains a
   documented gap (B4).

## Recommended next step

Upstream (rbitcoin), smallest set that would actually unblock R:

1. Return a typed `ScriptError` (Core ordinal) from the script entry instead of
   `ConsensusError::Script(String)`; keep the string for diagnostics.
2. Expose a public, synchronous **per-input** verify entry (or make
   `verify_input` public) so a proof sees one function, not a detached thread.
3. Add fields (or an explicit ignore-with-record mechanism) for the five
   policy-only flag bits.

In parallel, the harness owners must resolve F-TOOL-001: either authorize the
rustc 1.88 proof lane as the R evidence lane, or provide an Alive2 transform
for `dead_on_return`/LLVM 22. Until (1) and (2) land, no R cell can be built
even with a perfect adapter.

Interim: use this adapter for C-R triage; file B5 as C-R findings; keep B1–B4
as explicit row exclusions. No change to pins, contract, Lean, census, or
consensus logic is proposed here.

## Evidence index

- Build/env hashes: `README.md`, `logs/e0-baseline.log`, `logs/build.log`
- Behavior: `logs/behavior.log` (`core 71/71`, `domain 3/10`, `external 0/5`)
- Token map: `logs/census.log` (`CENSUS_OK`, 0 unclassified, 0 stale)
- Adapter: `adapter/entry_r3.rs`, `adapter/entry_r3.diff`
- Domain: `domain-table.md`
