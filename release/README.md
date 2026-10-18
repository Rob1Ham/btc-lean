# Data release 2026.10.17

This directory records the transport checksums for the data release.
The archive and the content manifest are release assets; they are not
tracked as git objects.

| Asset | Bytes | SHA-256 |
|---|---:|---|
| `btc-lean-data-2026.10.17.tar.gz` | 357,916,214 | `1ac846bdc24740cfdcf599c3ccf357e48bed50d7fd32071efae605d2a84168b8` |
| `manifest.sha256` | 68,925 | `6c2f51e44624cbff05340610d5168dd869dbf9dd6c03f45d0c01a2f3594eba07` |
| `assets.sha256` | 180 | see this directory |

`assets.sha256` lists the archive and `manifest.sha256`; it does not list
itself. The content manifest covers **615 payload files**: 608 data files
from the `spec/vectors/` corpus plus 7 byte-identical `spec/db/` metadata
files. The payload is data-only; executable sources, logs, caches, and
narrative worklogs are excluded. Manifest paths are relative to the archive
root. The source/data boundary is documented in [`../docs/HARNESS.md`](../docs/HARNESS.md).

The release download location is the deployment target configured in
`scripts/fetch_data.sh`; it is not hard-coded here.
