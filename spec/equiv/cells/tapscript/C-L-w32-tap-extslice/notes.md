# tapscript/C-L-w32-tap-extslice

## What is proved

The BIP342 tapscript extension slice, byte for byte, for both SigVersions:

- TAPSCRIPT (`ext_flag = 1`): `tapleaf_hash` (32 bytes) ‖ `0x00`
  (`key_version`) ‖ `codeseparator_pos` (4 LE bytes), length 37.
- TAPROOT: empty slice.

The C leg is word-granular; the L leg is a byte-level transliteration of
`extSlice`. SAW verifies both legs against one independent Cryptol `slice`,
Alive2 checks the C↔L pair for all five words.

## Deliberate limits

- `key_version = 0` is proved as the written byte. The *reason* it is 0
  (`TAPSCRIPT` only supports 32-byte keys today, `interpreter.cpp:1517-1522`)
  is a comment/assert in Core, not a branch.
- The caller-contract asserts (`m_tapleaf_hash_init`,
  `m_codeseparator_pos_init`) are premises. Core aborts on violation; Lean
  returns `none`. Neither is a consensus-observable state, so no behaviour
  is claimed for it.
- The hash *value* is an uninterpreted 32-byte input. SHA256/TapLeaf is
  SCR-146 and is not claimed by this cell.
- The position of this slice inside the whole `SigMsg` (it is last) follows
  from the cited lines but the full message layout is SCR-169's partial
  cell.
