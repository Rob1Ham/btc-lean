# MANIFEST-SPEC — field definitions and failure modes

This specification defines the two checksum manifests used by the data
release. It is intentionally strict: a manifest that is merely "close" is
rejected rather than repaired, because the point of the file is to detect
drift, not to guess what the publisher meant.

See [DATA.md](DATA.md) for what is distributed and where.

## 1. Manifest kinds

| File | Kind | Lines cover | Verified against |
|---|---|---|---|
| `manifest.sha256` | content manifest | every regular file in the extracted payload | the extracted payload, with `sha256sum -c` |
| `assets.sha256` | transport manifest | the other downloadable release files (`manifest.sha256`, archive) | the download directory, with `sha256sum -c` |

Both use the same line syntax. `manifest.sha256` is the file attached to every
release; `assets.sha256` exists only to make the
transport step checkable without extracting anything. `assets.sha256` is
pinned out of band; it never lists itself.

## 2. Line grammar

A manifest is a sequence of lines, each terminated by LF (`\n`). A final LF is
required. There are no blank lines, comments, headers, timestamps, or
continuation lines.

```
line     = digest SP SP path LF
digest   = 64HEX
HEX      = "0" / "1" / ... / "9" / "a" / "b" / ... / "f"
SP       = %x20
path     = path-char { path-char }
```

Requirements:

1. **Digest.** Exactly 64 lowercase hexadecimal characters. Uppercase is not
   canonical and is rejected by the validator even though GNU `sha256sum` may
   accept it.
2. **Separator.** Exactly two ASCII spaces (`0x20 0x20`) between digest and
   path. One space, a tab, or `*` mode is invalid.
3. **Path.** Relative to the manifest's stated root. `/`-separated. Must not
   begin with `/`, must not contain a `.` or `..` component, and must not be
   empty. Must not contain LF, CR, tab, NUL, or backslash. Non-ASCII bytes are
   allowed but must be valid UTF-8 so the path list has a canonical byte order.
4. **Ordering.** Lines are sorted by the path field in ascending byte order
   under the C locale (`LC_ALL=C sort`). Sorting by digest is wrong.
5. **Uniqueness.** A path appears at most once, even if two rows produce the
   same digest. Overlapping selection (`DIR` and `DIR/file`) is a duplicate.
6. **Coverage.** A content manifest lists every regular file in the payload and
   nothing else. Directories, symlinks, devices, sockets, and the manifest
   itself are not listed. A transport manifest lists exactly the named release
   assets and not itself.
7. **No self-entry.** A checksum file cannot contain a correct hash of itself.
   Writing the manifest to a path inside the hashed set is an error.

## 3. Field definitions

### `<sha256>`

SHA-256 of the file's exact byte content, computed over the file as stored
after extraction. No normalization (line endings, BOM, permissions, mtime) is
part of the hash. A file with the same bytes at a different path has the same
digest; that is expected and not a duplicate-path error.

### `<path>`

The stable payload path. For the release bundle the path is repository-relative
(`spec/vectors/...` or `spec/db/...`); the bundle excludes `docs/`, executable
sources, scripts, caches, and logs. The in-tree subset uses the
repository-relative `spec/data/...` paths; its source files are the same
relative subpaths under `spec/vectors/`. Paths never change across versions;
a rename is a layout change, not a manifest edit.

For an extracted bundle, the manifest root is the extraction directory. For
the in-tree subset, the root is the repository root (`spec/data/...` paths).
The release content manifest always uses repository-relative paths.

### Sorting key

The path field's UTF-8 bytes, compared lexicographically by unsigned byte
value. Directory separators are ordinary bytes. Numeric fields are not parsed:
`file10` sorts before `file2`. This matches `LC_ALL=C sort -t $'\t' -k1,1` on
the generator's internal `path<TAB>file` records.

## 4. Canonical generation

`scripts/make_manifest.sh` is the reference generator:

* collects explicit files and directories (directories are walked without
  following directory symlinks);
* rejects missing paths, absolute paths, paths escaping `--root`, unsupported
  path characters, and duplicate paths;
* rejects symlinks unless `--follow-symlinks` is supplied; with that flag a
  symlink to a regular file is hashed under the link path;
* sorts by path bytes and emits `<digest>  <path>` with no header;
* writes nothing until validation succeeds.

The release archive materializes symlinks as regular files. Therefore
`make_manifest.sh` on the extracted payload needs no special flag.

## 5. Verification procedure

### 5.1 Content manifest

1. Download and verify the transport manifest first (section 5.2).
2. Download the archive and verify its digest against `assets.sha256`.
3. Extract the archive into a clean directory.
4. From the extraction root, run:

   ```sh
   sha256sum -c manifest.sha256
   ```

   Every line must print `OK`. Any `FAILED` is a hard failure.
5. Optional: regenerate from the extracted payload using the release's
   selector set and compare with `manifest.sha256`:

   ```sh
   scripts/make_manifest.sh -C . <release-selectors> > build/manifest.reproduced
   cmp build/manifest.reproduced manifest.sha256
   ```

   The exact selector set is a property of the release, not of this
   specification; a manifest that lists a different path set is a new bundle
   version, not a repair to the old one.

### 5.2 Transport manifest

1. Obtain the expected SHA-256 of `assets.sha256` from an out-of-band channel
   (release notes or a signed commit).
2. Hash the downloaded `assets.sha256` and compare exactly.
3. Run `sha256sum -c assets.sha256` in the download directory.
4. Only then trust `manifest.sha256` and the archive.

Without step 1, HTTPS is the only trust anchor. That is integrity in transit,
not publisher authentication.

## 6. Failure modes

| Condition | Detection | Required action |
|---|---|---|
| Digest not 64 hex chars | validator / spec check | reject manifest |
| Uppercase digest | strict validator | reject; regenerate lowercase |
| One space or tab separator | strict parser | reject; regenerate |
| `*` binary-mode marker | strict parser | reject; the format uses two spaces |
| Missing final LF | byte check | reject; regenerate |
| Blank line, comment, header | line parser | reject; manifests are pure data |
| Path absolute (`/...`) | path check | reject |
| Path contains `..` | path check | reject |
| Path contains `.` component | path check | reject or normalize before hashing, then regenerate |
| Path contains LF/CR/tab/NUL/backslash | path check | reject; unsupported path |
| Duplicate path | `sort | uniq -d` | reject; overlapping inputs are a generator bug |
| Unsorted lines | compare with canonical sort | reject; regenerate |
| File missing from payload | `sha256sum -c` reports missing | hard failure |
| Extra file not in manifest | coverage check / regeneration diff | hard failure; either re-publish or document the new file in a new version |
| Digest mismatch | `sha256sum -c` prints `FAILED` | hard failure; delete the download and re-fetch |
| Manifest lists itself | self-entry check | reject; impossible to satisfy |
| Manifest lists a directory | `-type f` check | reject; directories are not hashed |
| Symlink in payload | `find -type l` check | materialize it in the archive or exclude it by policy |
| Archive digest mismatch | `assets.sha256` check | delete archive, re-fetch; do not extract |
| `assets.sha256` digest mismatch | out-of-band pin | abort; do not use any file from that release |
| Correct digest, wrong publisher | pin/signature check | out of scope for checksums; do not claim identity |
| CRLF line endings | byte check | reject; convert to LF and regenerate |

### 6.1 What is not a failure

* Two different paths with the same digest (identical content) — allowed.
* A file whose digest changes between versions — expected; that is why a new
  version exists.
* An archive whose compressed bytes differ after a local rebuild with another
  gzip implementation — expected; compare the content manifest, and use the
  published archive digest for the published file.
* A subset whose path set is smaller than the full corpus — by design.

## 7. Security notes

* Checksums are not signatures. The out-of-band `assets.sha256` pin is the
  only identity-bearing step in this design.
* Verify before extracting. The fetcher refuses symlink/hardlink archive
  members and rejects absolute or `..` member names; do not bypass those
  checks with a hand-written extraction command on an unverified archive.
* Never execute a downloaded binary, script, or shell fragment. The data
  bundle contains data and documentation; extraction is the only operation.
* Keep historical manifests and tags. Replacing bytes under an old version
  destroys the meaning of every saved verification command.
