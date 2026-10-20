# wave16 task 05-control-flow

## Scope

Control-flow SCR rows 056-068 and 070, as bounded C↔L cells with both legs
built from line-cited source slices at the pinned commit and checked by real
Alive2 and SAW runs. Writes are confined to
`spec/equiv/cells/control-flow/` and this report; no shared file, patch, pin,
or twin source is modified (`patches: none` for every cell).

- branch: `wave16/05-control-flow`
- repo head at authoring: `805c8042f92d3bed909ca40219a4d21fc9150cc1`
- Core pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- contract hash: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- C compiler: clang 20.1.2, LLVM 20.1.2; Alive2 20.1.2
- SAW: 1.6 (68eed5f release-1.6)

## Cells

| Cell | SCR rows | Coverage | Alive2 pairs | SAW proofs | Alive2 cert | SAW cert |
|---|---|---|---|---|---|---|
| `C-L-casttobool` | 057 | full (len 0-2) | 3/3 green | 6 | `e276070342d855ad2030f34cfe9af72c243244e8df3247923c0bdc601102af65` | `bf1fb3a65a850fc416da46687b6adc05c45b251c18348e42d86803ea5544d9c4` |
| `C-L-if-notif` | 056, 058, 059, 060 | full (len 0-2) | 3/3 green | 6 | `6e7e03380d63ff2ed44fa973c5cc4075dc44d9d0e0592415a3a28e40f24127d6` | `663f36c16fdb52918efe136b8a015313e5120b25b90bc0b53d98e6d40c41d15a` |
| `C-L-conditional-stack` | 061, 062, 063, 064 | full (one dispatch, cond depth 0-2) | 1/1 green | 2 | `d84cf415777a20b253ea86a294e7260eb96e81a82d5d3bb279467ba21183eb1c` | `66f4b1acd1da69d6b1c2620248f0d1f681557d115f44e62a91a5cc8f65968e92` |
| `C-L-bad-opcode` | 065, 066 | full (4 wire classes) | 1/1 green | 2 | `c55f20a6adebf6a0429875e3757b96a1e542af4cad11fe666c20e95edbe872e8` | `1fc78cddd3bca8aefa52a2b9536ceec402cc9ca35607feaa62a805f3772f8200` |
| `C-L-opcount` | 067 | full (all 256 wires) | 1/1 green | 2 | `a6fdc3e44ee4711c7de468e86dfd354c78f1feb5c09d63099ee4f1b670c2c883` | `c552fd6b6596512512cb142c06db2c6057b5937ba8445cf03a2f4025478e52a1` |
| `C-L-unspendable` | 070 | full (whole 32-bit size) | 1/1 green | 2 | `4bc7504d950857e4109fad0ab8fbcff2c96663afee9fb340723a2f722f71354d` | `7c89ac55a5503107eec6fd82a48544b5547b4d19b837ad5b9e69714698aac278` |
| `C-L-verify` | 068 | full (len 0-2) | 3/3 green | 6 | `863282bb98c592b6f809b48fc17ba3ae17f744f9fb3a107b35f2f84d42d0c80a` | `1e61d7d92e88f05f821dbdcb968c3e56005c326f5cf942f8022c87cd02b4b011` |

Every Alive2 certificate is the file hash of `alive2/certificate.sha256`; every
SAW row is the file hash of `saw/certificate.sha256`. Each certificate is a
`sha256sum` manifest over the cell's `spec.md`, runners, sources, generated
harness, tool outputs, and the tool log, and verifies with `sha256sum -c` from
the repository root. Log endings: all 14 manifests are
`STATUS=alive2-green` / `STATUS=saw-green`.

## Row dispositions

- **SCR-056** `CastToBool of top (NOTIF inverts); pop` — full. Covered by
  `C-L-if-notif` for IF and NOTIF, every byte value at lengths 0-2, symbolic
  stack depth, and the pop/no-pop observable.
- **SCR-057** `any nonzero byte = true; lone 0x80 = false; ∅ = false` — full.
  `C-L-casttobool` exercises all three outcomes plus the negative-zero test at
  the last position and at a non-last position.
- **SCR-058** `IF/NOTIF arg ∈ {∅, 01} else TAPSCRIPT_MINIMALIF` — full.
  `C-L-if-notif` proves error 51 and the accepting arm under `sv = tapscript`.
- **SCR-059** `same check under flag` — full. `C-L-if-notif` proves error 31
  for `witnessV0` with `SCRIPT_VERIFY_MINIMALIF`, and proves the flag-clear
  arm falls through to CastToBool.
- **SCR-060** `no stack pop when skipped` — full. `C-L-if-notif` proves
  `fExec = false` leaves depth unchanged and pushes false without inspecting
  the argument.
- **SCR-061** `toggle_top; empty cond-stack ⇒ UNBALANCED_CONDITIONAL` — full.
  `C-L-conditional-stack` covers ELSE toggle at depth 1/2 and error 20 at
  depth 0.
- **SCR-062** `empty cond-stack ⇒ UNBALANCED_CONDITIONAL` — full. ENDIF at
  depth 0 gives 20; ENDIF at depth 1 pops.
- **SCR-063** `non-empty cond-stack after loop ⇒ fail` — full. The loop-exit
  check returns 20 when a skip or ENDIF leaves depth >= 1.
- **SCR-064** `in [OP_IF..OP_ENDIF] gate` — full. An in-range opcode (ELSE)
  dispatches with `fExec = false`; a non-conditional opcode (NOP) is skipped
  and the `executed` bit stays 0.
- **SCR-065** `BAD_OPCODE even in unexecuted branches` — full.
  OP_VERIF/OP_VERNOTIF give error 16 with `fExec = false`; the cell also shows
  OP_COUNT takes precedence when the budget is exhausted first.
- **SCR-066** `BAD_OPCODE when executed; unexecuted OP_VER passes` — full.
  OP_VER/OP_RESERVED give 16 when executed and are skipped when not (OP_VER
  still charges the budget).
- **SCR-067** `each IF counts 1 opcode` — full. Proven for all 256 wire
  values, which includes OP_IF = 0x63; the counter increments by exactly one,
  and 202 is OP_COUNT.
- **SCR-068** `pop iff true else VERIFY` — full. `C-L-verify` proves pop on
  true, error 11 on false, and error 18 on an empty stack, for every byte
  value at lengths 0-2.
- **SCR-070** `first-byte OP_RETURN or >10k script ⇒ never spendable` — full.
  `C-L-unspendable` proves the whole predicate over all 32-bit sizes and all
  first bytes, including the 10000/10001 boundary.

## Domain bounds (not coverage gaps)

These are declared bounds on the machine-checked domain; none of them is an
unexercised branch named by a row.

- Element length is 0-2 (the twin's bounded element domain) for
  CastToBool-bearing cells. Lengths 3-520 are argued positionally, not
  machine-enumerated.
- `C-L-conditional-stack` models one dispatch followed by loop exit, with
  condition depth 0-2; it does not model multi-opcode scripts or deeper
  nesting. IF/NOTIF's push side is the separate `C-L-if-notif` cell.
- `C-L-bad-opcode` selects the four `default:` wires; OP_RESERVED1/2 are the
  same branch and are not separately instantiated.
- `C-L-opcount` proves the per-opcode step with a symbolic starting counter
  (including the 201/202 boundary), not an accumulation over a script.

## Twin finding (filed, not patched)

`twin/ops_ir.py`'s `OP_IF` handler (wires 0x63/0x64, annotated
`Defs.lean:878-891`) checks only `stack.n < 1` and then `cast_to_bool`; it
omits both minimal-IF arms that its own citation contains:

- tapscript: argument must be exactly `{}` or `{1}`, else
  `TAPSCRIPT_MINIMALIF` (51);
- witness v0 with `minimalIf`: the same test, else `MINIMALIF` (31).

Consequence: the twin's OP_IF accepts non-minimal arguments in both settings,
so rows SCR-058 and SCR-059 are not satisfied by the current twin handler.
This task does not patch `twin/` (out of write scope). `C-L-if-notif`'s L leg
therefore transcribes the Lean model directly, and its green result must not
be read as certifying `twin/ops_ir.py`. Suggested fix (for the twin owner):
insert the two arms between the stack check and `cast_to_bool`, using
`ctx.sv` and `ctx.pol.minimalIf`, returning `TWIN_TAPSCRIPT_MINIMALIF` and
`TWIN_MINIMALIF` respectively.

The twin's `OP_BAD_OPCODE` handler (0x50, 0x62, 0x65, 0x66, 0x89, 0x8a,
0xbb-0xff) returns `TWIN_BAD_OPCODE` unconditionally, which is correct because
`runtime.inc` applies Core's `fExec || 0x63 <= wire <= 0x68` gate before
dispatch. No twin gap for SCR-065/066 was found.

## Method notes

- Every build post-processes the extracted `.ll` with
  `sed 's/ or disjoint / or /g'` before `llvm-as`. SAW 1.6 leaves the `or
  disjoint` poison flag unconstrained in returned terms; the packed observable
  fields are bit-disjoint by construction, so the rewrite is value-preserving.
  Alive2 and SAW consume the same normalized artifact.
- `C-L-bad-opcode` masks its two-bit opcode selector (`& 3`) in both leaves and
  in the Cryptol spec. Without the mask clang lowers the selector mapping to a
  bit-test `switch` whose symbolic `lshr` amount is poison for selectors >= 4;
  Alive2 tolerates it (identical UB on both legs) but SAW cannot refine it.
- Each `build/` directory is gitignored; certificates hash build artifacts, so
  the runners were executed before the commit and all manifests were re-checked
  with `sha256sum -c`.
