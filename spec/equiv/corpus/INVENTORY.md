# Corpus inventory (in-tree subset)

Hashes and counts computed from the tracked files at
`/home/ubuntu/btc-lean-public` (2026-10-19). Regenerate with
`python3 corpus/manifest.py`.

## Core corpora (vendored from Bitcoin Core @ `cce32b168`)

| File | Bytes | sha256 | Top-level entries | Case-like | Use |
|---|---:|---|---:|---:|---|
| `spec/data/core/script_tests.json` | 227,812 | `7fb93dea245f68b627d214e0d51969c4f29fefaae1ac94ca1eba5fe8322f864c` | 1318 | **1258** | E1–E4 script cells; the 1258 matches the runner's `sc-0000..sc-1257` |
| `spec/data/core/tx_valid.json` | 87,306 | `0abeb1a6e4b942e4e43ef8d49b7356c1f6204bcb14163f24153f4d0ec5418011` | 255 | 122 | tx-level context; not script cells |
| `spec/data/core/tx_invalid.json` | 53,412 | `0c02ce44ff3a880458f9569a25589315a07f924fcaadac828613d4615776ca52` | 201 | 93 | tx-level context; not script cells |
| `spec/data/core/sighash.json` | 210,483 | `52cf23c2076e7f129c71d5508631d3e5ae3be1b1cb0585c0e23bbb4bb373e924` | 501 | 500 | E3 signature-hash cells |

Top-level entries include comment strings; only list-shaped entries are
vectors. `script_tests.json` has two vector shapes:

- no witness: `[scriptSig, scriptPubKey, flags, expected, comment?]` (1141)
- witness: `[[wit_items..., amount], scriptSig, scriptPubKey, flags, expected, comment?]` (117)

`flags` is a comma-separated list of Core flag names (`P2SH`, `WITNESS`,
`TAPROOT`, `STRICTENC`, ...). `expected` is `OK` or a `SCRIPT_ERR_*` name.
The witness form carries the amount needed for SegWit v0+.

## L2-SCR lane (in-tree subset)

| File | Bytes | sha256 | Notes |
|---|---:|---|---|
| `spec/data/l2/scr/cases/seam.l2c` | 723 | `c4c265c21778389891f072bb0966e26c7c13e9530883e783d23dbc9f300360ca` | 5 policy-flag seam cases (+2 comment lines) |
| `spec/data/l2/scr/results/tierC.l2r` | 48,039 | `88624ebfb4c772be5f353feea4ea3972923e7dcca1ed0cc57805d6361d7df1b6` | verdicts for the 1258 pinned `script_tests` rows; includes the 7 unjudged taproot rows `sc-1237..sc-1243` |
| `spec/data/l2/scr/results/tierG.l2r` | 91,662 | `357e4b52efc235f2d3f77fff5729113d04772c5a62dbbc2d04b1a1a0b8b9e9a8` | verdicts for 1788 generated rows |
| `spec/data/l2/scr/results/seam.l2r` | 223 | `11e813b3475e127eb1edda76fb5eafad185c13ec9433168602afea7274d30c9f` | 5 seam verdicts |

The **tier-G case file** (`cases/tierG.l2c`) and the generator
(`gen_l2scr.py`, `oracle_l2scr.py`) are in the release data bundle, not the
in-tree subset; `spec/data/l2/scr/README.md` documents their reproduction.

Verbatim result-line format (`*.l2r`): `id|T|our_error|our_bool|want|AGREE`
(see `results/tierC.l2r`).

## Pin note (important for cell records)

- Census/consensus pin: `cce32b168` (`spec/db/rules.yaml`).
- The L2-SCR lane's **source oracle** was read at `c50817fe` (a later master
  snapshot), per `spec/data/l2/scr/README.md`. The vendored corpora are at
  `cce32b168`.
- Cell records must state which pin supplied the expected values. Our
  three-leg harness computes expectations from the **Core oracle built at
  `cce32b168`**, so the L2-SCR results are cross-checks, not the primary
  oracle.

## Derived family selections

`corpus/select_families.py` deterministically derives per-family JSONL
selections from the pinned `script_tests.json` (no invented expectations;
`expected` is copied verbatim). Regenerate with:

```sh
python3 corpus/select_families.py
```

| Family | Rows |
|---|---:|
| stack | 316 |
| flow | 297 |
| numeric | 335 |
| hash | 115 |
| checksig | 90 |
| cms | 117 |
| locktime | 21 |
| disabled | 24 |
| witness (flag) | 134 |
| taproot (flag) | **7** |

The 7 taproot rows are exactly the 7 UNJUDGED rows in
`spec/data/l2/scr/results/tierC.l2r` (`sc-1237..sc-1243`) — an independent
consistency check on the corpus and the seam boundary. Rows may appear in
several families; `source_index` and `row_sha256` locate the original entry.

## Mapping to milestones

- **E1** stack ops: `script_tests` subset by opcode name, plus hand-built tapes.
- **E2** flow/numeric/hash: `script_tests` subset; numeric edges from
  `script_tests` + targeted tapes.
- **E3** checksig/sighash: `script_tests` checksig rows + `sighash.json` (500).
- **E4** witness/taproot: the 117 witness-form rows; the 7 unjudged taproot
  rows are expected seam gaps; `seam.l2c` for policy-flag edge cases.

## Non-goals

`tx_valid`/`tx_invalid` are not script cells; they exist for contextual
cross-checks only. Do not grow the corpus inside this workstream — new cases
belong with the generators and must be hash-pinned.
