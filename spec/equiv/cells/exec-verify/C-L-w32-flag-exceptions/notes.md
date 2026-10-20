# exec-verify/C-L-w32-flag-exceptions

SCR-016, the two named mainnet blocks whose flag sets are reduced by
`script_flag_exceptions` (kernel/chainparams.cpp:115-118,
validation.cpp:2262-2265).

## What is proved

1. **Symbolic lookup.** `cell_exc_select` over every 256-bit hash returns
   1 for the BIP16 exception hash, 2 for the taproot exception hash and 0 for
   every other hash (exact two-entry map, fail-closed). SAW against
   `saw/spec.cry` over symbolic limbs; Alive2 C-vs-L.
2. **Full height schedules for those hashes.** `cell_flags_bip16_at(height)`
   returns exactly the buried ORs (base `NONE`, so P2SH/WITNESS/TAPROOT are
   never regained at any height); `cell_flags_taproot_at(height)` returns
   `P2SH|WITNESS` plus the buried ORs and never sets TAPROOT. Both are
   symbolic over all uint32 heights.
3. **The two named blocks at their real heights** (closed witnesses, both
   tools):
   * BIP16 block, height 170060: `0x0` (all three base bits off; every buried
     height is above it).
   * taproot block, height 692261: `P2SH|WITNESS|DERSIG|CLTV|CSV|NULLDUMMY`
     = `0xe15` (all four buried deployments active, TAPROOT still off).

Green on both tools; ten SAW proofs (five functions on C and L) and six
Alive2 compares.

## Height/hash provenance

The hash<->height pairs (BIP16 170060, taproot 692261) are the ones recorded
in `spec/core/Bitcoin/Activation/Flags.lean:42-57`, cross-referenced there to
the public block data; the cell does not re-derive a hash from a header. The
exact words are a consequence of the pinned mainnet heights and the pinned
two-entry map.

## Exact commands

```sh
spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/saw/run.sh
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/saw/certificate.sha256
```

## Trust note

C is a line-cited slice; L is a reviewed hand transliteration of
`mainnetExceptionMap` / `getBlockScriptFlagsP`. The `cell_exc_select` return
encoding (0/1/2) is cell harness; it distinguishes exactly the two Option
payloads of the Lean map, which is why the lookup proof also covers the
payloads. No Core patch, no crypto, no block-header parsing.
