# exec-verify/C-L-w32-block-flags

SCR-015, `GetBlockScriptFlags` (validation.cpp:2249-2288), mainnet.

## What is proved

For every 256-bit block hash and every uint32 height, the C slice and the
Lean transliteration return the same flag word, equal to
`getBlockScriptFlagsP mainnetParams hash height`:

* base `P2SH|WITNESS|TAPROOT`, except that a hit on either
  `script_flag_exceptions` entry **replaces** the base
  (BIP16 -> `NONE`, taproot -> `P2SH|WITNESS`);
* `DERSIG` at height >= 363725, `CHECKLOCKTIMEVERIFY` >= 388381,
  `CHECKSEQUENCEVERIFY` >= 419328, `NULLDUMMY` >= 481824.

Alive2 and SAW are both symbolic over the full hash and height domain (no
closed witness): SAW proves each leg against `saw/spec.cry`; Alive2 proves
C-vs-L. All four proofs are green.

## Source faithfulness

* The exception map is `std::map<uint256, script_verify_flags>` with exactly
  two mainnet entries (kernel/chainparams.cpp:115-118). The slice expresses
  the lookup as four-limb 256-bit equality; any other hash takes the normal
  base, i.e. the map is fail-closed.
* The four `DeploymentActiveAt` calls in the pinned function are all
  `Consensus::BuriedDeployment` (params.h:26-38, deploymentstatus.h:27-31),
  for which activation is exactly `index.nHeight >= DeploymentHeight(dep)`,
  with `DeploymentHeight` = BIP66/BIP65/CSV/Segwit height (params.h:140-157).
  The slice uses those plain compares, so no versionbits state is abstracted
  away.
* The trailing row sentence "Scripts and costs use actual candidate flags"
  is about the caller (ConnectBlock / TXV-055) and is **not** claimed here.

## Exact commands

```sh
spec/equiv/cells/exec-verify/C-L-w32-block-flags/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-block-flags/saw/run.sh
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-block-flags/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-block-flags/saw/certificate.sha256
```

## Trust note

The L leg is a reviewed hand transliteration of
`spec/core/Bitcoin/Activation/Flags.lean:69-76,127-128,145-157` (no generated
twin for `Bitcoin.Activation`). It is deliberately a *different
representation* from C — Bool record plus `Option` versus a 64-bit bitmask
and equality lookup — so the Alive2 compare is not a compare of identical
expressions. Flag bits and heights are transcribed from the pinned headers in
`_tools/w32/w32_common.h`; Core headers are not included. This is the flag
selector, not block connection and not script execution.
