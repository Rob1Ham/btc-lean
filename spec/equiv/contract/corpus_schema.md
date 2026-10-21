# Corpus record schema (normative)

Status: E0. A corpus is a `.jsonl` file: **one JSON object per line**, UTF-8,
LF line endings, no comments, no trailing commas, no BOM. Blank lines are not
records and are ignored. Files live outside this directory (CELLS/LEDGER own
them); this document defines their shape.

The tape semantics are `tape.md`. The error values are `error_kind.h` /
`error_enum.md`. This schema records **Core's** expected outcome; a
divergence in another leg is a finding, never a per-leg override here.

## Record

```json
{
  "schema": "btc-lean/equiv-corpus/v1",
  "id": "stack/op-add/001",
  "tx_bytes": "02000000010000000000000000000000000000000000000000000000000000000000000000ffffffff00ffffffff010000000000000000015100000000",
  "spk": "51",
  "amount": 0,
  "input_index": 0,
  "flags": 0,
  "expected": {
    "result": 1,
    "verdict": "pass",
    "error_kind": "EQUIV_ERR_OK",
    "error_value": 0,
    "produced_by": "shims/core/entry.cpp",
    "contract_hash": "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  },
  "source": {
    "corpus": "hand",
    "ref": "OP_1 scriptPubKey, flags 0",
    "license": "CC0-1.0",
    "commit": null
  },
  "tags": ["stack", "push"],
  "notes": "Example is a real tape: decodes and passes at the pin."
}
```

The example's `contract_hash` is a placeholder. Real records must carry the
value computed per `tape.md` §10. The `tx_bytes`/`spk` pair above was replayed
through `shims/core/entry.cpp` (result `(1, EQUIV_ERR_OK)`); do not edit it
without re-running the Core lane.

## Fields

| Field | Type | Required | Rules |
|---|---|---|---|
| `schema` | string | yes | Exactly `"btc-lean/equiv-corpus/v1"`. |
| `id` | string | yes | Unique in the corpus. `^[a-z0-9][a-z0-9._/-]*$`, no spaces; family prefix recommended. |
| `tx_bytes` | string | yes | Lowercase hex, `^([0-9a-f]{2})*$`; raw `TX_WITH_WITNESS` bytes. `""` is allowed (and is bad input). |
| `spk` | string | yes | Lowercase hex, `^([0-9a-f]{2})*$`; raw scriptPubKey, no length prefix. `""` allowed. |
| `amount` | integer | yes | `0 <= amount <= 2100000000000000` (sats). |
| `input_index` | integer | yes | `0 <= input_index <= 4294967295`. Decoding/index rules decide result `2`. |
| `flags` | integer | yes | `0 <= flags <= 0x1fffff`; Core script-verify bits (`tape.md` §5). Implication violations are bad input, but corpus authors should not rely on them except in explicit bad-input cases. |
| `expected` | object | yes | See below. |
| `source` | object | yes | See below. |
| `tags` | array of string | no | Free-form, lowercase; used by `coverage.py`. |
| `notes` | string | no | Human context; never machine-parsed. |
| `preconditions` | array of string | no | Only for restrictions **narrower** than the tape domain. Each must name a filed cell/gap; must not silently drop inputs. |

### `expected`

| Field | Type | Required | Rules |
|---|---|---|---|
| `result` | integer | yes | One of `0,1,2,3` (`0` fail, `1` pass, `2` bad input, `3` internal). |
| `verdict` | string | yes | `"fail"`, `"pass"`, `"bad-input"`, `"internal"` respectively. Redundant by design; must agree with `result`. |
| `error_kind` | string | yes | Full shared enum name (`EQUIV_ERR_*`). On pass: `EQUIV_ERR_OK`. On `2`/`3`: `EQUIV_ERR_UNKNOWN_ERROR`. On fail: any value in `2..54` (Core can return `EQUIV_ERR_UNKNOWN_ERROR` from its catch-all). |
| `error_value` | integer | yes | The numeric value of `error_kind` per `error_kind.h`; must agree. |
| `produced_by` | string | no | How the expectation was obtained: `"shims/core/entry.cpp"`, `"core-test-suite"`, `"manual-review"`, etc. |
| `contract_hash` | string | no | `sha256:<hex>` from `tape.md` §10. Required for newly generated expectations; may be absent for imported upstream vectors until replayed. |

`expected` is **Core's** outcome. It is never "whatever the majority says".
If Core is wrong (a consensus bug), the record still states Core's behavior
and the finding is filed separately.

### `source`

| Field | Type | Required | Rules |
|---|---|---|---|
| `corpus` | string | yes | Upstream/source name, e.g. `core-script-tests`, `core-script-assets`, `rbitcoin-tests`, `lean-model`, `fuzz`, `hand`. |
| `ref` | string | yes | Stable locator: file + JSON pointer/line, test name, or a one-line description for `hand`. |
| `license` | string | yes | SPDX identifier of the source (`MIT`, `CC0-1.0`, ...). |
| `commit` | string or null | no | 40-hex upstream commit when the source is versioned. |
| `generator` | string | no | For synthesized cases: script/command and version. |

## Corpus-level rules

1. IDs are unique; duplicate `id` is a hard error.
2. Two records with identical `(tx_bytes, spk, amount, input_index, flags)`
   but different `expected` is a hard error (tape ambiguity).
3. Records are order-independent; consumers sort by `id` for reproducible
   matrices.
4. No field may disable a leg. Leg-specific exclusions belong to the cell
   record or gap ledger.
5. Hex is canonical lowercase; a re-serialization of the transaction is a
   different tape and must be a different record if kept.
6. Every record must be accepted by the validator in `tools/` (TODO(TOOLS):
   `validate_corpus.py`). Until that exists, the rules above are checked by
   review and by the Core replay lane.
7. `source.license` must permit redistribution if the corpus is checked in.

## JSON Schema (informative)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "btc-lean/equiv-corpus/v1",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema", "id", "tx_bytes", "spk", "amount", "input_index", "flags", "expected", "source"],
  "properties": {
    "schema": {"const": "btc-lean/equiv-corpus/v1"},
    "id": {"type": "string", "pattern": "^[a-z0-9][a-z0-9._/-]*$"},
    "tx_bytes": {"type": "string", "pattern": "^([0-9a-f]{2})*$"},
    "spk": {"type": "string", "pattern": "^([0-9a-f]{2})*$"},
    "amount": {"type": "integer", "minimum": 0, "maximum": 2100000000000000},
    "input_index": {"type": "integer", "minimum": 0, "maximum": 4294967295},
    "flags": {"type": "integer", "minimum": 0, "maximum": 2097151},
    "expected": {
      "type": "object",
      "additionalProperties": false,
      "required": ["result", "verdict", "error_kind", "error_value"],
      "properties": {
        "result": {"enum": [0, 1, 2, 3]},
        "verdict": {"enum": ["fail", "pass", "bad-input", "internal"]},
        "error_kind": {"type": "string", "pattern": "^EQUIV_ERR_[A-Z0-9_]+$"},
        "error_value": {"type": "integer", "minimum": 0, "maximum": 55},
        "produced_by": {"type": "string"},
        "contract_hash": {"type": "string", "pattern": "^sha256:[0-9a-f]{64}$"}
      }
    },
    "source": {
      "type": "object",
      "additionalProperties": false,
      "required": ["corpus", "ref", "license"],
      "properties": {
        "corpus": {"type": "string"},
        "ref": {"type": "string"},
        "license": {"type": "string"},
        "commit": {"type": ["string", "null"], "pattern": "^[0-9a-f]{40}$"},
        "generator": {"type": "string"}
      }
    },
    "tags": {"type": "array", "items": {"type": "string"}},
    "notes": {"type": "string"},
    "preconditions": {"type": "array", "items": {"type": "string"}}
  }
}
```

The schema cannot express hex/length parity, enum-name↔value agreement, or
the flag implications; a validator must enforce those.
