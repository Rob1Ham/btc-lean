# F-HARNESS-002 — R ABI boundary is untyped and domain-restricted

- **status:** open (domain restriction; not an equivalence failure)
- **legs:** R (and any C-R/E3 comparison)
- **cells:** every R behavioral cell; E3 error-enum equality
- **severity for the claim:** limits what R can assert. Verdicts inside the
  domain are usable; error-kind equality outside the three mapped tokens is
  not.

## Symptom

The clean R shim (`shims/rust/entry.rs`) is built only from rbitcoin's
**public** API. That API has no typed script error:

- `ConsensusError::Script(String)` (`crates/rbitcoin-consensus/src/error.rs:5-12`).
- `verify_tx_scripts_with_flags(prevouts, tx, flags)` verifies **all inputs**
  and returns `ConsensusError` (`crates/rbitcoin-consensus/src/lib.rs:66`).

The shim therefore does three boundary things:

1. **Narrow error map.** Only tokens exercised by E0 are mapped to Core
   ordinals: `script false` → `EVAL_FALSE(2)`, `unknown opcode 0x6a` →
   `OP_RETURN(3)`, other `unknown opcode` → `BAD_OPCODE(16)`. Every other
   message stays `EQUIV_ERR_UNKNOWN_ERROR(1)`. This is boundary mapping, which
   `shims/README.md` permits; it is **not** evidence that rbitcoin's full
   error taxonomy equals Core's.
2. **Single-input domain.** The ABI carries `input_index`; the public entry
   verifies all inputs. The shim accepts only `tx.input.len() == 1` and
   `input_index == 0`; anything else is `BAD_INPUT(2)`. This is safe for E0
   and the signature-free E1 stack family, but it cannot express a
   multi-input CHECKSIG/CHECKMULTISIG cell.
3. **Flags = 0 only.** The shim returns `BAD_INPUT` for any `flags != 0`.
   `ScriptVerifyFlags` has no field for `SIGPUSHONLY` or
   `DISCOURAGE_UPGRADABLE_NOPS`, so even a partial map would not cover the
   whole Core flag word. Policy/witness/taproot cells are out of this lane.

`amount < 0`, undecodable transactions, and null/oversized buffers are also
`BAD_INPUT`.

## Evidence

- `shims/rust/entry.rs` (map and domain checks), sha256 of the built shim
  `73e3d2d96de864e11e7cfb7cc5cc9fbba5d0dad1dc5de08b4cad6114ad1dffde`.
- `shims/rust/build.sh` (clean-tree check, rustc 1.95.0, public API).
- `results/e0/run-triple.txt` (E0 uses only the three mapped tokens).
- `PINS.lock [rbitcoin] abi_shim_error_map` / `abi_shim_domain`.
- `findings/rust/rust-ir-report.md` R-GAP-01 (typed error), R-GAP-02 (flags),
  R-GAP-03 (entry/domain).

## Disposition

- **Domain-restrict** R cells to: one input, `input_index == 0`, `flags == 0`,
  `amount >= 0`, and failures whose message is one of the three mapped
  tokens. A cell outside this is a **gap with this finding id**, not a green.
- **E3 is blocked on R** for error-enum equality. A typed error (or a complete,
  tested string map) is an upstream rbitcoin request. Until then, E3 can
  compare C-L and record R verdict-only at best.
- **Do not** infer error equality from the three E0 tokens.
- R IR evidence is separate: the clean rustc-1.88 proof lane and SAW cells
  (`PINS.lock [rbitcoin]`) do not inherit this behavioral restriction, but
  they also do not establish ABI equality.
