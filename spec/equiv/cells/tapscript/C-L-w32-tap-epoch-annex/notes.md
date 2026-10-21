# tapscript/C-L-w32-tap-epoch-annex

## What is proved

- `cell_epoch_ht`: message bytes 0..1 are `0x00` (epoch) then the hashtype
  byte, for every 8-bit hashtype.
- `cell_spend_type`: `spend_type = 2*ext_flag + annex_present` for
  `ext_flag = 0` (TAPROOT) and `1` (TAPSCRIPT), both annex states.
- `cell_annex_slice`: the annex-hash slice is empty without an annex and
  exactly 32 bytes with one; the first word of the supplied uint256 appears
  unchanged.

Alive2 checks the C↔L pair; SAW checks each leg against the independent
Cryptol `epochHt`/`spendType`/`annexSlice`.

## Why SCR-169 is not full

The row's own summary is "epoch 0; spend_type; annex hash". The first two
are fully checked. The third is only checked structurally: the cell proves
that the 32-byte `m_annex_hash` is appended iff the annex is present, not
that `m_annex_hash` equals `SHA256(CompactSize(len) || annex)`
(`interpreter.cpp:1964`). No SHA256 is linked into either leaf, and the
cell does not connect Core's `HashWriter` to the executable Lean
`Sha256.sha256` (`Crypto/Seam/Hash.lean:133`).

A second gap is the full `SigMsg` byte order (four tx sub-hashes, optional
ACP slice, optional SINGLE output hash). Those require a tx
decoder/serializer model that the cell seam does not have.

The cell therefore records `scr_row_coverage: partial` and the blocker in
`spec.md`. It must not be promoted to a green SCR-169 row.
