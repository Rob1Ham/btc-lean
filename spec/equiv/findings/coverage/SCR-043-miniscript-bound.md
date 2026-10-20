# SCR-043 — `MAX_PUBKEYS_PER_MULTI_A = 999` is a miniscript-side construction bound, not an interpreter check

- **row:** SCR-043, family `limits`
- **claim (rules.yaml):** "tapscript multisig-mimic bound (miniscript-side resource limit)"
- **core anchor:** `script.h:37-38@cce32b168`
- **census face:** `BitcoinProofs.AF.PDW36.MAX_PUBKEYS_PER_MULTI_A_eq` (a `rfl` constant identity)
- **disposition:** **inapplicable to the script-interpreter equivalence harness; filed gap, no cell, no green**
- **investigated:** 2026-10-20 on base `5946c02`; Core pin `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`

## Verdict

The row is a wallet/miniscript construction limit, not an interpreter or
consensus check. `script.h:37-38` only defines the constant:

```
37  /** The limit of keys in OP_CHECKSIGADD-based scripts. It is due to the stack limit in BIP342. */
38  inline constexpr unsigned int MAX_PUBKEYS_PER_MULTI_A = 999;
```

At the pin the consensus interpreter never reads it. A grep over
`src/script/interpreter.cpp`, `src/script/interpreter.h` and `src/consensus/`
returns no reference (`rc=1`). All uses in `src/` are in the miniscript /
descriptor / solver construction layer (the only other hit is the functional
test framework's copy of the constant):

| Site | Use |
|---|---|
| `script/miniscript.h:1879` | `max_keys` for `multi_a` node construction |
| `script/miniscript.h:2404` | parse: threshold `k > MAX_PUBKEYS_PER_MULTI_A` ⇒ reject |
| `script/miniscript.h:2418` | parse: early reject when `keys.size() > MAX_PUBKEYS_PER_MULTI_A` |
| `script/miniscript.cpp:79` | `CHECK_NONFATAL` on a constructed node's `n_keys` |
| `script/solver.cpp:124` | template solver rejects spans with `> MAX_PUBKEYS_PER_MULTI_A` keys |
| `script/descriptor.cpp:2469-2470` | descriptor parse error for `multi_a`/`sortedmulti_a` |

The actual consensus limits in this area are different constants: the CMS key
count `MAX_PUBKEYS_PER_MULTISIG = 20` (`script.h:35`, enforced at
`interpreter.cpp:1195`, row SCR-026) and the stack limit `MAX_STACK_SIZE =
1000` (`script.h:44`, enforced at `interpreter.cpp:1309` and
`interpreter.cpp:1945`, row SCR-029). The 999 cap is a construction choice
kept below the 1000-element stack tier; it is not a consensus predicate.

The pinned Lean model agrees, in its own words:

- `spec/core/Bitcoin/Interpreter/Rules.lean:346-351` defines the constant and
  documents it as "a miniscript-side resource limit, not an interpreter check
  (the BIP342 interpreter never reads it; it bounds script construction)."
- `spec/proofs/BitcoinProofs/AF/PDW36/PDW36.lean:196` proves
  `MAX_PUBKEYS_PER_MULTI_A = 999` by `rfl`; `:200-203` proves `999 < 1000`.
  These are constant arithmetic, not enforcement.
- `spec/core/Bitcoin/Wallet/Miniscript/Node.lean:139-140,441-442` carries the
  bound in the wallet Miniscript type computation:
  `if ctx = .p2wsh || k = 0 || k > ks.length || ks.length > 999 then
  MSType.empty`.

## Why no minimal cell is honest

Three cell shapes were considered; none discharges this row.

1. **Constant-identity cell** (Alive2/SAW over `999 = 999` between a C excerpt
   and the Lean constant). This is a restatement of the definition, not an
   equivalence of any check the interpreter performs. Entering it as
   `both-green` would claim script-interpreter coverage for a wallet-only
   constant. Rejected on the same grounds as the Wave 16 limits report
   (`spec/equiv/findings/wave16/03-limits-accounting/report.md` §4, SCR-043:
   "a constant restatement, not an equivalence of a check the interpreter
   performs").
2. **Miniscript-parse cell against `miniscript.h:2404/2418`.** The C target
   exists at the pin, but there is no L leg: the pinned Lean tree has no
   Miniscript `FromString` parser. `spec/core/Bitcoin/Wallet/Miniscript.lean`
   states the scope limit ("no policy compiler, no descriptor parser, no
   `ToString` or `FromScript`"), and wallet obligation MS-035 is recorded as
   unmodelled because "the parser object is absent, not merely unproved"
   (`spec/db/rules-wallet.obligations.tsv:66`,
   `docs/WALLET-OBLIGATIONS.md:403-408`).
   `Node.lean:442` checks an already-constructed AST node, not parse input;
   pairing it with Core's parser would compare two different functions. The
   parser is also templated over `Key`/context providers and uses
   `std::span`/`std::vector`, outside the harness's scalar-leaf ABI. No cell.
3. **Interpreter cell.** No interpreter code path exists to slice: the
   constant is not referenced by `interpreter.cpp`, `interpreter.h` or
   `consensus/`. The interpreter rows in this area are SCR-026 and SCR-029,
   which already have cells.

No tool was run for this row. There is nothing in the harness's contract
domain to apply Alive2/SAW to, and a tool result over a fabricated leaf would
be a green that does not mean what the row says. No green is claimed.

## Census metadata flag (reported, not edited)

`spec/db/rules.yaml` marks SCR-043 `consensus: true`, while the row's own
summary says "miniscript-side resource limit" and the wallet census records
the same behavior as `MS-035` with `consensus: false`
(`spec/db/rules-wallet.yaml:860-871`). `rules.yaml` is generated and must not
be hand-edited, so this report records the inconsistency for the census
maintainers instead of changing it. The `proven` status is accurate only in
the narrow sense that a Lean constant definition carries the `@[rule
"SCR-043"]` tag; it is not an enforcement theorem.

## Next action

- Keep the ledger entry at `gap` with this note; do not add a cell.
- If the construction bound is ever to be proved, the correct home is the
  wallet layer (`rules-wallet.yaml` MS-035), and it first needs a Miniscript
  `FromString` model in `spec/core/Bitcoin/Wallet/Miniscript`. That is a
  wallet obligation, not an SCR script-interpreter cell.

## Reproduce

```sh
# pin
git -C /tmp/pcore01 rev-parse HEAD   # cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66

# definition and all code uses
grep -rn MAX_PUBKEYS_PER_MULTI_A /tmp/pcore01/src

# the interpreter/consensus path does not read it (no output, rc=1)
grep -rn MAX_PUBKEYS_PER_MULTI_A \
  /tmp/pcore01/src/script/interpreter.cpp \
  /tmp/pcore01/src/script/interpreter.h \
  /tmp/pcore01/src/consensus

# the pinned Lean tree has no Miniscript parser
grep -rn 'FromString\|parseMiniscript' spec/core/Bitcoin/Wallet   # no output
grep -rn 'no policy compiler, no descriptor parser' spec/core/Bitcoin/Wallet/Miniscript.lean
grep -rn 'MS-035' spec/db/rules-wallet.obligations.tsv docs/WALLET-OBLIGATIONS.md

# no equiv cell references miniscript
grep -rli miniscript spec/equiv/cells   # no output
```

## Non-claims

This report does not claim SCR-043 is false, obsolete, or discharged. It
records that the row is outside the script-interpreter equivalence claim,
that its enforcement path is unmodelled on the Lean side, and that no cell or
tool result is offered.
