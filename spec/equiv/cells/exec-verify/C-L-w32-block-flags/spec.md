---
# Cell exec-verify/C-L-w32-block-flags
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-w32-block-flags
family: exec-verify
tool_status: both-green (symbolic over all 2^256 block hashes x all 2^32 heights)
precondition: |
  - Mainnet chain parameters (the pinned `CMainParams` values).
  - Any block hash, carried as four 64-bit limbs of its 256-bit value.
  - Any uint32 block height.
postcondition: |
  - `cell_block_flags(h0,h1,h2,h3,height)` equals
    `getBlockScriptFlagsP mainnetParams hash height`:
      * base P2SH|WITNESS|TAPROOT unless the hash is one of the two
        script_flag_exceptions entries, where the base is REPLACED
        (BIP16 -> NONE, taproot -> P2SH|WITNESS);
      * DERSIG OR-ed for height >= 363725,
        CHECKLOCKTIMEVERIFY for height >= 388381,
        CHECKSEQUENCEVERIFY for height >= 419328,
        NULLDUMMY for height >= 481824.
  - Both legs return the same word for every input.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-015
scr_row_coverage: |
  full — every branch and edge of validation.cpp:2249-2288 is exercised
  symbolically: the normal base, both exception-map entries and the
  fail-closed lookup, and both sides of each of the four buried-height
  comparisons. The row's trailing sentence "Scripts and costs use actual
  candidate flags" is an application note about the caller (ConnectBlock /
  TXV-055), outside core_ref validation.cpp:2249-2288; this cell does not
  claim that wiring.
patches: none
source_citations:
  - src/validation.cpp:2249-2288 (GetBlockScriptFlags)
  - src/kernel/chainparams.cpp:115-118 (script_flag_exceptions, two entries)
  - src/kernel/chainparams.cpp:119-124 (BIP34/BIP66/BIP65/CSV/Segwit heights)
  - src/deploymentstatus.h:27-31 (DeploymentActiveAt buried = height compare)
  - src/consensus/params.h:140-157 (DeploymentHeight mapping)
  - spec/core/Bitcoin/Activation/Flags.lean:69-76,127-128,145-157
    (mainnetExceptionMap, buriedActive, getBlockScriptFlagsP)
trust_note: >
  C is a line-cited source-excerpt slice of GetBlockScriptFlags. The
  `std::map` lookup is expressed as equality against the two mainnet entries;
  the map is exactly those two entries at the pin (kernel/chainparams.cpp:
  115-118), so the slice is fail-closed for every other hash. The four
  `DeploymentActiveAt` calls are the plain `height >= DeploymentHeight`
  compares that the pinned deploymentstatus.h defines for BuriedDeployment.
  L is a reviewed hand transliteration of the Lean record/Option definitions
  (no generated twin exists for Bitcoin.Activation); the two legs differ in
  representation (64-bit bitmask vs Bool record + Option), which is what the
  Alive2 compare closes. Flag-bit and height constants are transcribed from
  the pinned headers in `_tools/w32/w32_common.h`. Neither leg is the whole
  node validation path.
---
