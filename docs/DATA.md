# Data layout and release assets

This candidate tree contains the model, the proofs, the census, and a
size-bounded data subset. Bulk data is distributed as release assets, never as
git objects and never through git-lfs.

## 1. What is tracked

The tracked subset is installed at `spec/data/`. It preserves the relative
subpath of the source corpus (`spec/vectors/a/b` becomes `spec/data/a/b`) and
carries `spec/data/MANIFEST.sha256`.

| Property | Value |
|---|---|
| Files (including the manifest) | 168 |
| Tracked bytes | 5,033,780 |
| Budget | 2,097,152–5,242,880 bytes (2–5 MiB) |
| Manifest | `spec/data/MANIFEST.sha256`, one SHA-256 per file, C-locale path order |
| Release archive | `btc-lean-data-2026.10.17.tar.gz`, 357,916,214 bytes |
| Archive SHA-256 | `1ac846bdc24740cfdcf599c3ccf357e48bed50d7fd32071efae605d2a84168b8` |
| Content manifest | `release/manifest.sha256`, 68,925 bytes |
| Content-manifest SHA-256 | `6c2f51e44624cbff05340610d5168dd869dbf9dd6c03f45d0c01a2f3594eba07` |

The subset contains the Core/BIP transaction and script corpora, BIP340/341/143
vectors, CVE/incident/edge fixtures, block-header fixtures, representative
`l2` cases, and the wallet vector fixtures. It is read by the compiled runners;
it is not imported by the Lean model.

Check it from a checkout:

```sh
sha256sum -c --strict spec/data/MANIFEST.sha256
bash scripts/check_subset_size.sh --root spec/data
```

`check_subset_size.sh` measures the git index, rejects symlinks and gitlinks,
and rejects any git-lfs pointer or `.gitattributes` LFS filter.

## 2. Release bundle

Data bundle: **`2026.10.17`**. Release tag: **`data-2026.10.17`**.

The release contains exactly:

```text
assets.sha256
manifest.sha256
btc-lean-data-2026.10.17.tar.gz
```

The archive contains **615 data files**: 608 files from the `spec/vectors/`
corpus plus 7 byte-identical `spec/db/` metadata files needed for
data-dependent runs. Executable sources, generator scripts, build caches,
logs, and narrative worklogs are excluded. The Lean sources are not duplicated
into the archive; they are text and stay in git. The source/data boundary and
the remaining reproducibility gap are recorded in [`HARNESS.md`](HARNESS.md).

* `manifest.sha256` lists every payload file, relative to the archive root.
* `assets.sha256` lists exactly the archive and `manifest.sha256`.
* The archive is deterministic: members sorted, `mtime=0`, `uid=gid=0`, no
  links or device nodes, gzip header MTIME zero.
* `assets.sha256` is a transport checksum, not a signature. Publisher identity
  comes from an out-of-band digest pin, if one is published.

## 3. Fetch and verify

```sh
bash scripts/fetch_data.sh --base-url https://github.com/Rob1Ham/btc-lean/releases/download --dry-run
bash scripts/fetch_data.sh --base-url https://github.com/Rob1Ham/btc-lean/releases/download --assets-sha256 <64-hex-pin> --extract .
```

The downloader verifies `assets.sha256`, then `manifest.sha256` and the archive
against it, extracts only after verification, and runs `sha256sum -c --strict`
over every content entry. It never executes, sources, or installs a downloaded
file.

The release is addressed by the tag `data-2026.10.17`. The download base URL is
a deployment setting of `scripts/fetch_data.sh`; the default is the public release base URL; pass
`--base-url` for a mirror. The transport hashes are also tracked in
`release/assets.sha256` and `release/README.md`. The content manifest is
tracked in `release/manifest.sha256` for convenience; the release asset is the
copy to verify.

## 4. No git-lfs

The project does not use git-lfs. No tracked file may be an LFS pointer, no
tracked `.gitattributes` may contain `filter=lfs`, and no `.lfsconfig` may be
tracked. Release assets already provide versioned, hash-pinned downloads.

## 5. Adding data

A new file belongs in the tracked subset only if a CI check or fresh-clone
run reads it, it is small, and its provenance and license are recorded. Any
change to the tracked path set is a bundle-version change; it is not a silent
re-run of a selector. Bulk data goes to a new `data-<version>` release and a
new `manifest.sha256`.

## R03 tracked regression blocks

`spec/data/review/r03/` adds real mainnet block 1 as an acceptance control and
block 349992 plus its actual parent header for an absolute-finality rejection
under a deliberately changed supplied height. `provenance.json` records the
source hashes, immutable block hashes and conditional-context scope. Their
checksums are included in `spec/data/MANIFEST.sha256`. These small regression
fixtures are separate from the frozen release's full anchor corpora.
