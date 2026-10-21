# F-HARNESS-002 addendum — typed-error boundary probe for the R leg

**Status: advisory, off-pin, bounded. No R equivalence claim.**

- wave: `wave64`, agent `50-r-harness-typed-error`
- branch: `wave64/50-r-harness-typed-error`, base `5946c02`
- rbitcoin: `ae47aa98174e04d0d8c493f13041daf65e4ac1d3` (clean tree)
- toolchain: rustc `1.95.0` (`59807616e 2026-04-14`), public API only
- shared artifacts changed: **none**. This is an additive finding directory.
- this report does **not** edit or close
  `findings/cross/F-HARNESS-002-rbitcoin-boundary.md`; it is an addendum with
  a tested candidate fix and a precise blocker statement.

## 1. What the finding actually blocks

The task summary says the boundary is "bool-only". That is true only of the
non-normative 7-argument `entry()` wrapper. ABI v2 already has the right
**shape**:

```c
extern "C" int equiv_entry(..., equiv_error_kind *error_kind);   /* mandatory */
```

The blocker is the **value**. In the pinned shim (`shims/rust/entry.rs`,
sha256 `1fd706b8…`), `kind_of` (lines 49–68) maps only three message tokens:

| rbitcoin token | Core ordinal |
|---|---:|
| `script false` | 2 `EVAL_FALSE` |
| `unknown opcode 0x6a` | 3 `OP_RETURN` |
| any other `unknown opcode …` | 16 `BAD_OPCODE` |

Everything else is `EQUIV_ERR_UNKNOWN_ERROR(1)`. A bounded ABI run confirms
the consequence: the pinned shim matches Core's `(result, error_kind)` on
**6 of 26** tapes (all six are the three mapped tokens plus passes). See
`logs/witness.tsv`.

Two additional facts matter:

- rbitcoin has no typed script error. `ConsensusError::Script(String)` is
  declared at `crates/rbitcoin-consensus/src/error.rs:5,12`; the public entry
  `verify_tx_scripts_with_flags` is at `crates/rbitcoin-consensus/src/lib.rs:66`
  and verifies **all** inputs.
- The string vocabulary is a diagnostic surface, not an API. At the pin,
  `crates/rbitcoin-consensus/src/**/*.rs` contains **109 distinct
  `ConsensusError::Script` literals**. `logs/token-census.tsv` is the full
  census; `tools/census.py` fails if a token is neither mapped, documented as
  unmapped, nor covered by a dynamic opcode pattern.

## 2. What was built

| Artifact | Purpose |
|---|---|
| `src/typed_error.rs` | Minimal boundary classifier: 67 exact tokens, 2 dynamic patterns (`unknown opcode 0x..`, `disabled opcode 0x..`), 42 documented unmapped tokens, annotation stripping. Dependency-free; can be copied next to `entry.rs`. |
| `entry-typed.diff` | Drop-in diff against the pinned `shims/rust/entry.rs`. `git apply --check` passes. |
| `src/witness.rs` | Bounded witness: calls rbitcoin's public `verify_tx_scripts_with_flags` on 27 tapes and reports raw message + classifier ordinal. |
| `tools/witness.py` | Runs the same tapes through the real C shim and two R artifacts (pinned vs proposed typed shim); writes `logs/witness.tsv`. |
| `tools/abi_domain.py` | Separate ABI-domain probes (amount/flags/spk/multi-input); writes `logs/abi-domain.tsv`. |
| `tools/census.py` | Token-vocabulary completeness audit against the pinned source. |
| `build.sh` | Rebuilds the pinned R shim, the witness, the classifier tests, and the proposed typed shim in a scratch directory. |

The proposed change is deliberately small: add `mod typed_error;`, replace
the body of `kind_of` with `typed_error::classify_consensus_error(e)`. No
engine code, no opcode interpretation, no sighash logic.

## 3. Mapping policy (and why 41 source tokens stay UNKNOWN)

The classifier maps a token only when it identifies exactly one Core error at
the pin. `EXACT_MAP` has 67 entries; 66 appear literally in the source and
`unknown opcode 0x6a` is the observed spelling of the dynamic pattern.
`UNMAPPED_TOKENS` has 42 entries: the 41 source literals the census leaves
unmapped (two of which are `cfg(test)` spellings) plus the annotation-test
literal `already`:

| Category | Count | Why UNKNOWN |
|---|---:|---|
| Internal invariants / sighash plumbing (`prevout count`, `bip143 *`, `legacy sighash`, …) | 19 | Core has no corresponding `ScriptError`; these are rbitcoin-internal failure paths. |
| Context-dependent parse tokens (`der sig`, `empty sig`, `pubkey`) | 3 | The ordinal depends on flags and on the calling opcode. |
| Witness typed-path shape (`p2wpkh witness`, `p2wpkh empty witness item`, `p2wsh witness`) | 3 | One rbitcoin token can stand for more than one Core failure. |
| P2PKH / scriptSig shape (`p2pkh scriptSig*`) | 4 | Core's result depends on the synthesized stack/opcode path. |
| P2SH shape (`p2sh spk`, `p2sh empty scriptSig`, `p2sh redeem hash`) | 3 | Depends on where in the P2SH path Core fails. |
| Taproot typed path (`p2tr *`, `tapscript xonly`) | 8 | Taproot is outside the current flags=0 domain; tokens do not identify one Core ordinal. |
| Test-only (`scriptSig non-push`, `already`) | 2 | Not emitted by the production engine (`scriptSig non-push` is `cfg(test)`; `already` is an annotation test). |

Concrete ambiguity examples (all are reasons an enum is needed):

- `der sig` → `SIG_DER(24)` under `DERSIG/LOW_S/STRICTENC`; under flags=0 it
  is just a false signature (`EVAL_FALSE(2)` or `CHECKSIGVERIFY(14)`).
- `empty sig` → `SIG_NULLFAIL(32)` under `NULLFAIL`; otherwise a false path.
- `pubkey` → `PUBKEYTYPE(29)` under `STRICTENC`; otherwise a false path.
- `p2wpkh empty witness item`: an empty **pubkey** makes Core's synthetic
  template fail `EQUALVERIFY(12)`; an empty **signature** with a matching
  pubkey ends at `EVAL_FALSE(2)`. The message does not say which.
- The same message can be annotated with ` txid=… vin=…`
  (`script/mod.rs::annotate_script_err`). The classifier strips that suffix;
  the annotation is diagnostic, not engine identity.

## 4. Bounded witness result

`logs/witness.tsv`, regenerated by `tools/witness.py`:

```
typed classifier vs Core:                 26/26 exact (result+kind)
current pinned R shim vs Core:             6/26 exact
proposed typed shim (entry-typed.diff):   26/26 exact
```

- 26 single-input, flags=0 ABI tapes; 18 distinct `(result, kind)` values.
- Exercised failure ordinals: `2,3,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20`.
- Direct (non-ABI) observation: a 10,001-byte scriptPubKey is classified `5`
  (`SCRIPT_SIZE`). It cannot cross the current ABI because the R shim rejects
  `spk_len > 10_000` as bad input; Core returns `(0, 5)`. See §5.

**Coverage caveat.** The witness is bounded. Mappings for ordinals `4`,
`21–54` are source-read, not exercised end-to-end here; many require policy,
witness, or taproot flags that the R shim does not accept. Do not read
"26/26" as validation of the whole taxonomy.

## 5. ABI-domain divergences found in the same boundary

`logs/abi-domain.tsv` (8 probes, 6 diverge). These are separate from the
typed-error map but block the same cells:

| Probe | Core | R shim | Issue |
|---|---|---|---|
| `amount > MAX_MONEY` | `(2,1)` | `(1,0)` | R checks only `amount < 0`; contract says the upper bound is bad input. |
| any `flags != 0` | executes | `(2,1)` | Documented flags=0 restriction; blocks all policy/witness cells. |
| `spk_len = 10001` | `(0,5)` | `(2,1)` | R's local `spk_len > 10_000` cap is **not** in `tape.md §3` ("Any length is allowed"); it makes `SCRIPT_SIZE` unreachable through the ABI. |
| 2-input tx | verifies `input_index` | `(2,1)` | Public entry verifies all inputs; R rejects `tx.input.len() != 1` / `input_index != 0`. |
| negative amount | `(2,1)` | `(2,1)` | Agrees (control). |
| zero inputs | `(2,1)` | `(2,1)` | Agrees (control). |

The `spk_len` cap and the missing `MAX_MONEY` upper bound are correctness
issues, not merely documented domain limits; they should be fixed or recorded
as explicit gaps in every affected cell.

## 6. Precise upstream ask (the only complete fix)

A tested string map is a bridge, not an API. To unblock E3 error-enum equality
and policy/taproot cells, rbitcoin should expose:

1. A public typed error, e.g.
   ```rust
   #[repr(i32)]
   pub enum ScriptError { EvalFalse = 2, OpReturn = 3, /* … Core ordinals 1:1 */ }
   pub enum ConsensusError { Script(ScriptError), /* … */ }
   ```
   with `Display` preserving today's diagnostic strings. Returning the typed
   value through the existing entry point is enough for the shim to pass an
   ordinal without a string table.
2. A per-input verification entry:
   ```rust
   pub fn verify_input_scripts_with_flags(
       prevouts: &[bitcoin::TxOut],
       tx: &bitcoin::Transaction,
       input_index: usize,
       flags: ScriptVerifyFlags,
   ) -> Result<(), ConsensusError>;
   ```
   The current all-inputs entry cannot express `input_index` tapes.
3. Complete `ScriptVerifyFlags`: it has no `SIGPUSHONLY` or
   `DISCOURAGE_UPGRADABLE_NOPS` field, so even a complete string map could not
   cover Core's 21-bit flag word.
4. Stable, documented error identity (typed or a versioned token list). Any
   re-pin must rerun `tools/census.py`; new tokens fail the audit instead of
   silently becoming `UNKNOWN`.

## 7. Residuals / limitations

- **No R equivalence.** This probe compares one R artifact to one C artifact
  on 26 bounded tapes. It says nothing about the Lean leg, IR equivalence, or
  the full engine.
- **Off-pin.** The source and toolchain are at the pin, but these artifacts
  are not in `PINS.lock` and are not an official lane. Lifting
  `entry-typed.diff` requires a PINS update, a rebuild, and a new E0 result.
- The proposed shim is validated only for single-input, flags=0 tapes. It
  inherits every domain restriction in §5.
- `classify_consensus_error` returns `UNKNOWN` for non-`Script` errors. This
  intentionally drops the old `BadBlock(_) => INTERNAL(3)` arm: `3` is
  `EQUIV_ERR_OP_RETURN`, not an internal sentinel. Non-script consensus errors
  should arguably map to result 3 / unknown, which is a separate ABI change.
- The Core oracle binary is the prebuilt `/tmp/opencode/cbuild/libequiv-core.so`
  (sha256 `5fef1df0…`); its build provenance is the existing E0 lane. The R
  pinned binary was rebuilt from the clean pin and matches `PINS.lock`
  (`73e3d2d9…`), so the "current R vs Core" comparison is against the pinned
  artifact.
- String tokens can change upstream. The census and witness are pinned to
  `ae47aa98`; do not reuse the map after a re-pin without re-running both.

## 8. Verdict

F-HARNESS-002's typed-error gap is **addressable at the ABI boundary** for the
current flags=0, single-input domain: the proposed shim matches Core on all 26
bounded cases, versus 6/26 for the pinned shim. It is **not closed** for
policy/witness/taproot/multi-input flags, nor for taxonomy stability, because
rbitcoin publishes only diagnostic strings. Treat the map as an advisory
bridge; the durable fix is the typed enum + per-input entry in §6.

**Claim status:** advisory / off-pin / bounded witness only. No R
equivalence. No E3 green. No cell records changed.
