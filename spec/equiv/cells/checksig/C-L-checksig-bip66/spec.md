---
# Cell checksig/C-L-checksig-bip66
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: pinned rbitcoin shim has no typed flag/error surface for block validation (F-HARNESS-002)"
cell: checksig/C-L-checksig-bip66
family: checksig
tool_status: both-green
precondition: |
  - Block height and the BIP66 buried deployment height are 32-bit values
    bounded to [0, 2^31) so Core's signed `index.nHeight >=
    params.DeploymentHeight(dep)` compare coincides with the unsigned compare
    used in the cell.
  - `exc` selects the block-script-flag base: 0 = no exception hash
    (P2SH|WITNESS|TAPROOT), 1 = BIP16 exception hash (SCRIPT_VERIFY_NONE),
    2 = taproot exception hash (P2SH|WITNESS), any other value = no exception.
  - `base_flags` (cell_dersig_or only) is an arbitrary 4-bit flag word.
  - No transaction or script execution; this cell is the flag derivation only.
postcondition: |
  - cell_dersig_flag(bip66_height, height, exc) = baseFlags(exc) OR
    (height >= bip66_height ? DERSIG : 0), with DERSIG = bit 3.
  - cell_dersig_flag_mainnet(height, exc) is the same with
    bip66_height = 363725 (mainnet Consensus::Params::BIP66Height).
  - cell_dersig_or(bip66_height, height, base_flags) = base_flags OR
    (height >= bip66_height ? DERSIG : 0): the OR never clears a base bit,
    including a base-set DERSIG.
  - In particular DERSIG is on at exactly height 363725 and above for every
    exception class, and off below it unless the base word already has it.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-103
scr_row_coverage: full
coverage: full
patches: none
source_citations:
  - "src/validation.cpp:2249-2270@cce32b168 (GetBlockScriptFlags: base set, exception replacement, DERSIG OR)"
  - "src/deploymentstatus.h:27-31@cce32b168 (DeploymentActiveAt buried deployment = nHeight >= DeploymentHeight)"
  - "src/consensus/params.h:104,151@cce32b168 (BIP66Height / DeploymentHeight)"
  - "src/kernel/chainparams.cpp:117-124@cce32b168 (mainnet BIP66Height = 363725)"
  - "spec/core/Bitcoin/Activation/Flags.lean:114-155 (buried_heights_mainnet, buriedActive, getBlockScriptFlagsP)"
  - "spec/core/Bitcoin/Activation/Flags.lean:199-249 (dersig_flag_flow*, mainnet faces)"
trust_note: >
  No crypto seam: the DERSIG flag is derived before any signature check, so
  this cell is not conditional on same-crypto.  The C leg is a line-cited
  slice of pinned validation.cpp/deploymentstatus.h; the chainstate lookup
  and DeploymentActiveAt call are reduced to their value at the pin for a
  buried deployment (a plain height compare).  The L leg is a reviewed
  transliteration of `getBlockScriptFlagsP`.  Alive2 quantifies over all
  heights and flag words in the domain; SAW proves each leg against an
  independently written Cryptol restatement.  The cell proves the flag
  derivation, not the whole block-validation path that consumes it.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - saw/cell.saw, saw/bip66.cry (independent Cryptol predicate)
mutant: "change `>=` to `>`, or OR DERSIG before the exception replacement; Alive2 and SAW must both fail"
mutant_site: "findings/wave16/10-checksig-policy/tools/{c,l}_bip66.cpp"
---

# checksig/C-L-checksig-bip66

Full SCR-103 flag flow: `GetBlockScriptFlags` ORs `SCRIPT_VERIFY_DERSIG` in
exactly when the BIP66 buried deployment is active (`nHeight >= 363725` on
mainnet), after the exception-hash replacement, for every exception class.
Both tools prove the general height compare, the mainnet constant, and the
non-clearing OR over symbolic heights and flag words.
