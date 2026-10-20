# numeric/C-L-numeric-default-4byte

SCR-080 (`all numeric opcodes`, `Default 4-byte operand limit`), a bounded
decode cell with **both tools green** over the complete 4-byte operand domain
plus the width reject edge, at every CScriptNum site in `EvalScript` that takes
the default cap.

## Source

Pinned Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`:

- `src/script/script.h:242` — `static constexpr size_t nDefaultMaxNumSize{4};`
- `src/script/script.h:244-249` — the constructor's default argument
  `const size_t nMaxNumSize = nDefaultMaxNumSize` and the width guard
  `if (vch.size() > nMaxNumSize) throw scriptnum_error("script number overflow");`
- `src/script/script.h:270`, `376-391` — `set_vch` sign-magnitude decode.
- `src/script/interpreter.cpp:432-437`, `1236-1238` — the
  `catch (const scriptnum_error&)` that sets `SCRIPT_ERR_SCRIPTNUM`.

The seven sites, all two-argument calls (so the default is the cap):

| site | line | operands | opcodes |
|---|---:|---|---|
| 1 | 840 | 1 (depth) | `OP_PICK`, `OP_ROLL` |
| 2 | 939 | 1 | `OP_1ADD`..`OP_0NOTEQUAL` (6) |
| 3 | 972-973 | 2 | `OP_ADD`..`OP_MAX` (13, incl. `OP_NUMEQUALVERIFY`) |
| 4 | 1017-1019 | 3 | `OP_WITHIN` |
| 5 | 1103 | 1 | `OP_CHECKSIGADD` (tapscript) |
| 6 | 1126 | 1 | `OP_CHECKMULTISIG` key count |
| 7 | 1140 | 1 | `OP_CHECKMULTISIG` sig count |

The two sites that *do* pass a size argument are excluded here:
`interpreter.cpp:556` and `:584` pass `5` for CLTV/CSV and are SCR-081's row.

## Entry points

```c
uint64_t cell_pick_roll  (uint32_t w, uint32_t lb);                        // site 1
uint64_t cell_unary      (uint32_t w, uint32_t lb);                        // site 2
uint64_t cell_binary     (uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb); // site 3
uint64_t cell_within     (uint32_t wx, uint32_t lx, uint32_t wmn, uint32_t lmn,
                          uint32_t wmx, uint32_t lmx);                     // site 4
uint64_t cell_checksigadd(uint32_t w, uint32_t lb);                        // site 5
uint64_t cell_cms_nkeys  (uint32_t w, uint32_t lb);                        // site 6
uint64_t cell_cms_nsigs  (uint32_t w, uint32_t lb);                        // site 7
```

`w` is the little-endian content word and `lb & 7` the element length.  The
observable is `status | error<<2 | site<<8 | value<<12` (see
`findings/wave64/15-scr-080/tools/dflt_common.h`).

## Symbolic claim

- Alive2: `alive-tv --bidirectional` for all seven entry points.  Both
  directions are required and counted: 7/7 functions, 2/2 directions each,
  `1 correct transformations` per direction, no counterexample.
- SAW: `src/cell.saw` verifies **both** modules against `src/cell.cry` for
  every `(w, l)` pair: 7 entry points x 2 legs = 14/14 `Proof succeeded`.

## What the cell does and does not say

The row's check is the operand limit, so the slice stops at the decode
boundary: it constructs `CScriptNum(vch, fRequireMinimal)` exactly as the site
does and observes the decoded value, or the error.  It does not execute the op
body.  The normal-arm op results for the arithmetic sites are already green in
`numeric/C-L-unary-4byte`, `C-L-binary-4byte` and `C-L-within-4byte` (each
symbolic over lengths 0..7); the post-decode depth/range/count/signature
behaviour belongs to SCR-078, SCR-086, SCR-090 and SCR-114..117.  Compose them
for the whole row.

The site list is a reading of the pinned file (the table above); the cell
proves each listed site, not that the list is the complete set of call sites.

## Model notes

`src/cell.cry` repeats the `decode`/`decodeOk` equations used by the wave-16
numeric cells (`findings/wave16/07-numeric-ops/tools/num.cry`) because the
cell must be self-contained; the observable differs (site-tagged decode
value instead of the post-op stack).  `decodeOk` is `L <= 4`, so the reject
edge depends on length only, as in Core.

## Build normalisation

Two tool-ingestion steps are applied identically to both legs and are recorded
in `build.sh`:

1. Post-extract `opt -passes='default<O2>'` (stock pipeline; scalarises the
   bounded stack alloca so the leaf is loop- and memory-light).
2. `tools/strip_range.py` removes the derived `range(...)` return attribute
   that clang attaches to a leaf.  The C and L legs can derive different lower
   bounds for the same bit pattern and Alive2 then reports "Source and target
   don't have the same return domain" for an equivalent pair.  Removing a
   metadata-only bound weakens the source, which is sound for refinement.

The constructor is `always_inline`; a non-inlined call is an uninterpreted
external for Alive2 and would make the source "not return".

## Tool notes

- Alive2 v20.0 (`/opt/equiv-tools/alive-tv-v20.0`), SMT timeout 120 s.
- SAW 1.6 (`/opt/equiv-tools/saw-1.6`), solver z3 (ABC did not terminate on the
  40-bit serialization predicate in the wave-16 cells; z3 is seconds here too).
- Both sides are branch-light and loop-free after extraction; no timeout or
  unrolling concession is needed.
