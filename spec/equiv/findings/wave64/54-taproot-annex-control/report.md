# Wave 64 — task `54-taproot-annex-control`

**Branch:** `wave64/54-taproot-annex-control`
**Base:** `5946c02` (worktree clean at start)
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Cell:** `spec/equiv/cells/tapscript/C-L-w64-taproot-annex-control-layout`
**Result:** both-green — 6/6 bidirectional Alive2 checks, 12/12 SAW
obligations, plus 3/3 executed mutants that fail both tools.

## Scope

This is an **independent bounded layout audit**, not a replacement for any
row cell. It targets the taproot witness region *before* the TapLeaf hash,
the Tapbranch hash, the EC tweak and Schnorr: annex position, control-block
slot selection, control-length lattice/parity, leaf-version masking and the
Tapbranch node windows. It composes facts that the existing SCR-143 /
SCR-145 / SCR-146 / SCR-169 cells prove separately.

No ledger, rules, pin, contract, existing cell or proof file was edited.

## Relation to the existing rows/cells

| Existing row / cell | What it already proves | What this audit adds | Claim here |
|---|---|---|---|
| SCR-143 — `tapscript/C-L-taproot-annex` | `n>=2 && last_len!=0 && b0==0x50`; `SpanPopBack` count | the **position**: annex is the last item and sits directly above the control block (`control+1+annex==n`); 0x50 is disjoint from the tapscript control bytes | extension, not a re-status |
| SCR-145 — `tapscript/C-L-taproot-scriptpath-dispatch` | the boolean size gate 33..4129, `% 32 == 0` | lattice characterization `size = 33+32k`, `k <= 128`, **size is odd**, and every Tapbranch window `[33+32i, 33+32i+32)` is in bounds | extension |
| SCR-148 — same cell | `(control[0]&0xfe)==0xc0` dispatch | the byte decomposition `leaf = b&0xfe`, `parity = b&1`, disjointness, evenness, 2-to-1 mask, bit-0 invariance | extension |
| SCR-146 — unjudged-seam (no cell) | — | only the **argument byte** `control[0]&0xfe`; the tagged hash remains unjudged | **not claimed** |
| SCR-147 — unjudged-seam (no cell) | — | only the **parity bit** extraction; `CheckTapTweak` remains EC | **not claimed** |
| SCR-169 — `tapscript/C-L-w32-tap-epoch-annex` (partial) | epoch/hash_type, spend_type, annex-hash inclusion | only the **annex span selection** that feeds the annex hash; no digest | **not claimed** |

## Proved functions

| Function | Statement (all inputs in the cell domain) | Alive2 | SAW |
|---|---|---|---|
| `cell_classify_byte` | one-hot: 1 = 0x50, 2 = 0xc0/0xc1, 4 = other; the 0x50-and-0xc0/1 contradiction is never produced | green | green |
| `cell_witness_layout` | annex iff `n>=2 && last_len!=0 && b0==0x50`; effective `n-annex`; arm 0/1/2; control `eff-1`, script `eff-2`; sentinels otherwise | green | green |
| `cell_layout_position` | `control+1+annex==n`, `script+1==control`, `annex -> n>=2`, `n>0 -> eff>=1`; returns 1 for every in-domain input | green | green |
| `cell_control_lattice` | `ok <-> 33<=size<=4129 && (size-33)%32==0`; `ok -> size=33+32k`, `k<=128`, `size` odd | green | green |
| `cell_node_window` | for accepted size and `i<k`, `33<=lo` and `hi=lo+32<=size`; vacuous otherwise | green | green |
| `cell_leaf_parity` | `leaf=b&0xfe`, `parity=b&1`, `leaf&parity=0`, `leaf|parity=b&0xff`, leaf even, tapscript iff leaf 0xc0, bit-0 flip preserves leaf/complements parity | green | green |

- Alive2: `--bidirectional` on the C IR and the independently written L IR;
  no function reports `syntactically equal`.
- SAW: each leg verified separately against `cell.cry`, a Cryptol statement
  written from the Core branch table and the Lean equations, not from either
  leg.

## Evidence and certificate verification

Tracked-input certificates (generated `build/` files are **not** listed):

```sh
C=spec/equiv/cells/tapscript/C-L-w64-taproot-annex-control-layout
sha256sum -c "$C/alive2/certificate.sha256"
sha256sum -c "$C/saw/certificate.sha256"
```

Certificate digests:

```
alive2/certificate.sha256  9e65279b5cffbb313aa0d7c69fbd1f4cdf9bcb97c1f01c93a954be40817fa65a
saw/certificate.sha256     dc000d3403691fb09208298b07f75bda625ce8a8294248ac0dd8f6acb2f62e18
spec.md                    88868b5ebcda1aca5c9a07b133a58be1605a5c18e5579b7c04a502a6b83485e4
```

Raw result digests:

```
alive2/result.txt          ec0b5b1193b2105678b2ce3ea8d2e13a77d257389c8bebcfe5159960f22d2a5e
saw/result.txt             7b7c968c8693d7b991cd83ca9c4cd431c914b7b6a8a13cad34fb5c5ef6b657a4
mutation/result.txt        ed522d89d389c34ce6dcd51fdbfc5152a6cf79bb6b829b730c9cc88bcc4de29a
```

Status lines:

```
STATUS=alive2-green
CELL_W64_ANNEX_CONTROL_LAYOUT_SAW_GREEN
STATUS=saw-green (12/12 proofs)
```

## Exact commands

```sh
bash spec/equiv/cells/tapscript/C-L-w64-taproot-annex-control-layout/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-w64-taproot-annex-control-layout/saw/run.sh
sha256sum -c spec/equiv/cells/tapscript/C-L-w64-taproot-annex-control-layout/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-w64-taproot-annex-control-layout/saw/certificate.sha256
# non-vacuity only, not cell evidence:
bash spec/equiv/cells/tapscript/C-L-w64-taproot-annex-control-layout/mutation/check.sh
```

## Non-vacuity (executed mutants)

`mutation/check.sh` builds three mutated L legs and runs both tools; all
three failed as expected. Raw output is `mutation/result.txt`.

| mutant | change | Alive2 | SAW |
|---|---|---|---|
| M1 | `control - script == 1` -> `== 2` | value mismatch (C=1, L=0) | `cell_layout_position` fails |
| M2 | annex tag `0x50` -> `0x51` | value mismatch (C=1, L=4) | `cell_classify_byte` fails |
| M3 | max control size `4129` -> `4128` | value mismatch | `cell_control_lattice` fails |

A green mutant would have meant the SAW spec merely restated the
unmutated implementation; none did.

## Remaining crypto / hash seams (precise)

1. **SCR-146 / TapLeaf.** `TapLeaf` is
   `TaggedHash("TapLeaf", leaf_ver, CompactSize(script.size()), script)`
   (`interpreter.cpp:1884`). The cell proves `leaf_ver` and the script slot,
   not the digest. The Lean tree has executable `Sha256.sha256`
   (`Crypto/Seam/Hash.lean:133`, re-exported at
   `Crypto/Seam/Interface.lean:62`) and `taggedHash_unfold`
   (`Crypto/Taproot/Program.lean:590-594`), but there is no proved same-hash
   link from Core's `HashWriter` to it at this seam. Substituting an
   uninterpreted hash would prove only the surrounding layout, which is
   already proved here.
2. **SCR-147 / TapTweak.** `q.CheckTapTweak(p, merkle_root, control[0]&1)`
   (`interpreter.cpp:1913-1925`). The cell proves the parity *bit* and its
   independence from the leaf version, not that it equals the tweaked key's
   Y parity. Pure secp256k1 EC, outside the seam.
3. **SCR-169 / annex hash + TapSighash.** The cell proves the annex is the
   last item and the span that feeds `SHA256(CompactSize(len) || annex)`
   (`interpreter.cpp:1964`); it does not prove the digest, the epoch byte,
   `spend_type`, or the full `SigMsg`. This is the same blocker recorded by
   `tapscript/C-L-w32-tap-epoch-annex`.
4. **Tapbranch root.** `cell_node_window` proves the node span is in bounds;
   `ComputeTapbranchHash` (SHA256, lexicographic ordering) is not modelled.

No tagged-hash, EC or Schnorr claim is made anywhere in this cell.

## Notes / limits

- The layout functions use 16-bit packed lanes, so `n <= 65535`; above that
  both legs return `0xdeadbeefdeadbeef`. The bound is harness, not a Core
  consensus rule.
- The C and L legs are different arithmetic expressions; Alive2 did real SMT
  work (no `syntactically equal` result).
- The first SAW attempt exposed an `lshr exact` poison from an ungated
  `/ 32`; the final legs gate the shift amount on divisibility. This is
  documented in `c_leg.cpp` and is part of why the mutant checks matter.
- The cell deliberately declares `scr_rows: []` with `scr_row_coverage:
  extension only`; it does not promote, demote or re-status any ledger row.
  Declaring rows was tried first: `update_ledger.py` appends every
  `scr_rows` entry to the derived ledger's `cells` list, which makes
  `--check` drift on SCR-143/145/148 even though no status changes. Since
  this branch may not regenerate the ledger, the rows are recorded under
  `related_rows` instead. With the current cell set,
  `python3 spec/equiv/results/scripts/update_ledger.py --check` reports
  `changes: 0` and exits 0.
