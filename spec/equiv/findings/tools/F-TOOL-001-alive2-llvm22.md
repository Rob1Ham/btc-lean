# F-TOOL-001 — Alive2 v20 cannot ingest the pinned rustc-1.95 R leg

- **status:** open (tool-gap; not an equivalence failure)
- **legs:** R
- **cells:** every R/Alive2 attempt whose module comes from rustc 1.95.0
- **cell:** `n/a` (tool-ingest, not a semantic cell)

## Symptom

Alive2 v20.0 is built against LLVM 20.1.2. The R pin is rustc 1.95.0
(LLVM 22.1.2). Two independent ingest failures were reproduced:

1. **Real rbitcoin 1.95 textual IR** (`--emit=llvm-ir`,
   `target-195-ir/release/deps/rbitcoin_consensus-68e7c81c2384e3ba.ll`):
   `llvm-as` 20 and `alive-tv` both stop at
   `ptr dead_on_return ...` with `expected ')' at end of argument list`.
   `dead_on_return` is an LLVM 22 parameter attribute.
2. **A minimal -O2 probe** (`probe_sum`, `Vec<u32>` collect) parses as text
   and bitcode, but Alive2 reports `ERROR: Unsupported metadata: 8` and
   `Could not translate 'probe_sum' to Alive IR` (exit 1). Metadata kind 8 is
   not known to LLVM 20.

The E0 `add_one` leaf passes both tools (`rust-hello/`) because it has neither
construct. That is a true leaf result, not evidence of engine ingestion.

## Evidence

- `findings/tools/probes/alive2-rust195/README.md`
- `findings/tools/probes/alive2-rust195/real-rbitcoin-195-ll.out`
- `findings/tools/probes/alive2-rust195/alive.out`
- `findings/rust/ir-reject-llvm22.txt` (RUST-IR's independent `llvm-as` run)
- `hashes.txt` in the probe directory (sha256 of every input/output).

## Consequence and disposition

- R/Alive2 **at the pin is inapplicable**. R cells at the pin are SAW-only and
  cite this finding in `alive2/inapplicable.md`; that satisfies the
  dual-attempt rule (an attempt plus a named blocking feature).
- The non-pin rustc 1.88.0 / LLVM 20.1.5 lane may be used **advisory only** to
  corroborate a leaf. It is not R-at-pin and may not be counted as an R green
  cell.
- Do **not** strip `dead_on_return` or metadata to force ingestion as a proof
  step: that changes the attribute contract and is not behavior-neutral.
- No Core UB is implied. This finding is about the proof tool, not the engine.

## Upstream

Reportable to Alive2 as "LLVM 22 IR ingest" but no upstream issue is filed by
this campaign; the R leg is pinned and the gap is documented.
