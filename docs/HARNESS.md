# Harness and data-release boundary

This repository separates three artifacts that are often bundled together:

1. the Lean model and proof tree;
2. the executable conformance harness and reference scripts;
3. the bulk vector corpus.

Only the first two are git objects. The third is a checksum-pinned release
asset. This note records the boundary, what each artifact can prove, and the
remaining gap.

## 1. What a git checkout contains

A fresh checkout contains the model, proofs, census, test runners, reference
implementations, and the size-bounded corpus subset:

| Path | Contents |
|---|---|
| `spec/core/` | executable zero-dependency Lean model and model-level tests |
| `spec/proofs/` | theorem package and generated vector batteries |
| `spec/Test/`, `spec/core/Test/`, `spec/runners/` | conformance runners |
| `spec/scripts/` | gates, extraction, packaging, and reproducibility checks |
| `spec/data/` | tracked subset: 161 files, 4,852,246 bytes |

The tracked subset is enough for the static gates and the in-tree
conformance harnesses that read `spec/data`. It is not the full
`spec/vectors/` staging corpus.

## 2. What the data release contains

The `data-2026.10.17` release is a **data-only** bundle:

| Property | Value |
|---|---:|
| Payload files | 615 |
| Vector data files | 608 |
| `spec/db/` metadata files | 7 |
| Archive bytes | 357,916,214 |
| Archive SHA-256 | `1ac846bdc24740cfdcf599c3ccf357e48bed50d7fd32071efae605d2a84168b8` |

The payload is extracted at the repository root and supplies the larger data
tree read by the anchor-replay runners. It contains no executable sources,
scripts, logs, build caches, or narrative worklogs. See
[`DATA.md`](DATA.md) for the fetch and checksum commands.

## 3. The gap

There is no single artifact that contains both the full source tree and the
full data corpus.

- A git checkout has the harness but only the selected corpus.
- The release has the larger corpus but no harness.
- The full `spec/vectors/` staging tree is not a git object and is not intended
  to become one; the release assets are the distribution path for bulk data.
- Some reference generators need an upstream Core/BIP checkout or network
  anchor data. They are reproducible from the pinned upstream inputs, but not
  from this repository alone.
- The tracked subset is a deliberate, size-bounded selection, not a claim that
  the untracked corpus is unnecessary for every run. The release manifest is
  the authority for the payload that is distributed.

The practical pairing is therefore: clone the source at a commit, then fetch
and verify the release bundle for data-dependent runs.

## 4. Source-only harness pack

If an offline mirror needs a single source archive, create it from git rather
than from the working tree:

```sh
git archive --format=tar.gz --prefix=btc-lean-src/ HEAD > btc-lean-src.tar.gz
sha256sum btc-lean-src.tar.gz
```

That archive contains the harness, scripts, model, proofs, docs, and tracked
subset. It does not contain the release corpus. Pair it with the data bundle
and verify both against their published digests.

Do not add `spec/vectors/`, `.lake/`, `build/`, or extracted release payloads
to a source pack. They are either bulk data or local build state.

## 5. What is still open

- There is no automated end-to-end recipe that rebuilds every release vector
  byte-for-byte from public inputs alone. The generators cover the tracked and
  generated batteries; some external anchor and fuzz corpora depend on network
  or upstream checkouts.
- The release is data-only by design. A future source pack should be a
  separate, reproducible archive of a git commit, not a second copy of the
  Lean tree.

Those limits are part of the public claim. The model and proof checks are
separate from the data-distribution guarantees.
