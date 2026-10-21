# Contract version history

The contract hash is the SHA-256 of the concatenation of five normative files
in the order in `contract/tape.md` §10. A hash change is a new contract
version; results are judged under the version they cite.

## v3 — 2026-10-19

- Hash: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- Recipe: `{ cat contract/ABI.md; cat contract/tape.md; cat contract/error_kind.h; cat contract/corpus_schema.md; cat contract/error_enum.md; } | sha256sum`
- Change: `error_enum.md` was added to the recipe. ABI §8 already made it
  normative; the v2 recipe omitted it. This closes evaluator finding B-06.
- No ABI, tape field, error ordinal, or header semantics changed. The only
  normative edit is the recipe text in `tape.md` §10 plus this changelog (the
  changelog is not in the hash).
- All live cell records must cite v3; cells are re-run after the re-pin.

## v2 — before 2026-10-19 (historical)

- Hash: `c2fcc67ad440605062e3619bcdc7310ef8670fc05c2acb118c0d7e4852ebe4ff`
- Recipe omitted `contract/error_enum.md`.
- Recorded E0 and differential summaries that cite v2 are historical evidence
  of what ran; they are not silently relabelled as v3.
