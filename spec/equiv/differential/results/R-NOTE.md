# R blocker correction (supersedes the literal reason in summary.json)

The files `summary.json`, `summary.md`, and the archived `c-l.jsonl` rows were
produced before the clean R ABI shim landed. Their per-row `R.reason` still
says `entry.rs is a STUB` and that the rbitcoin worktree is dirty. Those two
statements are false for the official clean lane and are **historical text**,
not a current claim.

Current facts, pinned in `PINS.lock`:

- `shims/rust/entry.rs` is a clean public-API shim, source sha256
  `1fd706b8b27486e2d1897dd65792acc0c6887b2bcc3723468d3b07af5daa8837`.
- `shims/rust/build.sh` builds it with rustc 1.95.0; the built
  `/tmp/opencode/shim-build/libequiv_rust.so` is
  `73e3d2d96de864e11e7cfb7cc5cc9fbba5d0dad1dc5de08b4cad6114ad1dffde`.
- E0 is green with that shim (`results/e0/`).
- The differential oracle still does not run R: its public entry supports one
  input, `input_index = 0`, `flags = 0`, and exposes no typed `ScriptError`.
  Multi-input/flags rows and error-kind parity are blocked by
  `F-HARNESS-002` / `R-GAP-01`.

`differential/run.py` now emits the corrected reason for future runs. The
recorded C-vs-L rows and hashes are unchanged.
