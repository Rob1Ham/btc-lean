# Differential summary — C vs L (twin), with Lean-model cross-check

Behavioral replay of the pinned `script_tests.json` through the C leg (`equiv_entry`, ABI v2), the generated C++ twin (`libtwin.so`, the L leg), and the Lean-model verdict file (`tierC.l2r`, an oracle cross-check). This is **behavioral evidence, not an LLVM IR proof**.

**Label note (F-HARNESS-001).** `tierC.l2r` is the Lean *interpreter model*, not the generated twin. Only the `C vs L_twin` lane may be called C-L.

## Totals

| Metric | Count |
|---|---:|
| Case-like rows | 1258 |
| C calls attempted | 1258 |
| **C vs L_twin agree** | **922** |
| **C vs L_twin disagree** | **0** |
| C vs L_twin blocked (twin result 3, declared boundary) | 336 |
| C vs Lean-model oracle agree | 1251 |
| C vs Lean-model oracle disagree | 0 |
| C vs Lean-model blocked (UNJUDGED) | 7 |
| C vs expected agree | 1258 |
| C vs expected disagree | 0 |
| Out of contract domain | 0 |
| C internal (result 3) | 0 |
| Encode failures | 0 |
| R rows blocked | 1258 |
| Determinism re-run | identical |

## By family

Rows may belong to several families (`families` in `c-l.jsonl`), so family counts overlap. `unassigned` are case-like rows that match no derived selection (pure pushes and similar), replayed anyway so that no vector is hidden.

| Family | Rows | Attempted | Twin agree | Twin disagree | Twin blocked | Lean agree | Lean disagree | Lean blocked | C~expected agree | Out of domain |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| stack | 316 | 316 | 258 | 0 | 58 | 316 | 0 | 0 | 316 | 0 |
| flow | 297 | 297 | 271 | 0 | 26 | 297 | 0 | 0 | 297 | 0 |
| numeric | 335 | 335 | 254 | 0 | 81 | 335 | 0 | 0 | 335 | 0 |
| hash | 115 | 115 | 55 | 0 | 60 | 115 | 0 | 0 | 115 | 0 |
| checksig | 90 | 90 | 5 | 0 | 85 | 90 | 0 | 0 | 90 | 0 |
| cms | 117 | 117 | 1 | 0 | 116 | 117 | 0 | 0 | 117 | 0 |
| locktime | 21 | 21 | 6 | 0 | 15 | 21 | 0 | 0 | 21 | 0 |
| disabled | 24 | 24 | 24 | 0 | 0 | 24 | 0 | 0 | 24 | 0 |
| witness | 134 | 134 | 28 | 0 | 106 | 127 | 0 | 7 | 134 | 0 |
| taproot | 7 | 7 | 0 | 0 | 7 | 0 | 0 | 7 | 7 | 0 |
| unassigned | 170 | 170 | 170 | 0 | 0 | 170 | 0 | 0 | 170 | 0 |

## Legs

- **C**: `equiv_entry` from `/tmp/opencode/cbuild/libequiv-core.so`, sha256 `5fef1df004adae637ffd7d3d7bf7dc96700c552dc2c22729d0de06d81457fbb5`.
- **L_twin**: `/home/ubuntu/btc-lean-public/spec/equiv/twin/build/libtwin.so`, sha256 `b9ed129b9a0bd719da789c7accab7e522f436b08eb33e8cd18874659edeea72b`, 2516 calls; 922 agree, 0 disagree, 336 blocked (result 3).
  Declared subset: base-script E1: pushes + stack/altstack/flow + EQUAL/SIZE + numeric unary/binary + RIPEMD160/SHA256/HASH160/HASH256 + P2SH wrapper; flags accepted.
- **Lean-model oracle** (not L): `spec/data/l2/scr/results/tierC.l2r`, sha256 `88624ebfb4c772be5f353feea4ea3972923e7dcca1ed0cc57805d6361d7df1b6`; joined by id and `want`, 1258/1258 rows verified; 1251 agree, 0 disagree, 7 blocked.
- **R**: blocked — R leg not run: no clean R shim exists (spec/equiv/shims/rust/entry.rs is a STUB) and the rbitcoin worktree at ae47aa98 carries an unregistered FFI patch. C-vs-L only.

