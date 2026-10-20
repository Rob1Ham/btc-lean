# Contract version of the recorded differential run

`summary.json`, `summary.md`, and `archive-d560/` were produced under contract
**v2** (`c2fcc67ad440...`). The live contract is **v3**
(`f1841e36...`), which adds `contract/error_enum.md` to the hash recipe; no
tape, ABI, or error ordinal changed. See `contract/CHANGELOG.md`.

The recorded C-vs-L rows and IR hashes are unchanged. This note prevents the
v2 hash in the JSON from being mistaken for the live contract; the JSON is
historical evidence, not relabelled.
