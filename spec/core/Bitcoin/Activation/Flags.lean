import Bitcoin.Activation.Interface
import Bitcoin.Crypto.Seam.Interface

/-!
# Bitcoin.Activation.Flags — Core-faithful hash-keyed port + policy catalogue

## Interface contract

Core counterpart files: src/validation.cpp (GetBlockScriptFlags:2249-2288),
                        src/kernel/chainparams.cpp:113-137,
                        src/deploymentstatus.h, src/script/interpreter.cpp
                        (MINIMALIF/CLEANSTACK tapscript semantics),
                        BIP146 (policy flags, never activated on mainnet)
Status: implemented + proved 2026-10-16.

## What this module adds over `Bitcoin.Activation.Interface`

1. The **hash-keyed** general port: Core identifies exception blocks by
   BLOCK HASH (`script_flag_exceptions`, kernel/chainparams.cpp:115-118),
   not by height. `getBlockScriptFlagsP` is the Core-faithful
   transliteration over a `ChainParams` record; the frozen height-keyed
   `getBlockScriptFlags` is the mainnet specialization, and the
   `mainnet_height_hash_agree_*` theorems prove the two agree (on mainnet
   a height determines its canonical block's hash).
2. The **policy catalogue**: the eight script
   verification flags that are NOT consensus on mainnet (BIP146 was never
   activated; LOW_S/STRICTENC/MINIMALDATA/NULLFAIL/CLEANSTACK/
   CONST_SCRIPTCODE are mempool policy, MINIMALIF applies to v0 witness
   spends only, WITNESS_PUBKEYTYPE is policy), plus the load-bearing
   BIP342 fact that tapscript **re-imports** MINIMALIF and CLEANSTACK as
   consensus rules (BIP342 §8; interpreter.cpp enforces both
   unconditionally for `SigVersion::TAPSCRIPT`).
3. `flagBits`: the exact `verify_flags.h` bit values for the consensus
   subset, so downstream work can compare against Core's UInt32 flags.
-/

namespace Bitcoin.Activation

/-! ## Hash-keyed exception map (kernel/chainparams.cpp:115-118) -/

/-- Block hash as a 256-bit value written as a hex literal (`Nat` —
arbitrary precision, no truncation). -/
abbrev BlockHash : Type := Nat

/-- The BIP16-violating block: validated with SCRIPT_VERIFY_NONE
(kernel/chainparams.cpp:115-116). Height 170060; height↔hash pair
verified against a public block explorer API on 2026-10-16
(research/w2-06-flags-activation.md §2.2). -/
def bip16ExceptionHash : BlockHash :=
  0x00000000000002dc756eebf4f49723ed8d30cc28a5f108eb94b1ba88ac4f9c22

/-- The taproot-violating block: validated with P2SH|WITNESS only
(kernel/chainparams.cpp:117-118). Height 692261; pair verified
2026-10-16. -/
def taprootExceptionHash : BlockHash :=
  0x0000000000000000000f14c35b2d841e986ab5441de8c585d5ffe55ea1e395ad

/-- The BIP34 activation block hash (kernel/chainparams.cpp:119-120,
BLK-070). Height 227931. -/
def bip34ActivationHash : BlockHash :=
  0x000000000000024b89b42a942fe0d9fea3bb44ab7bd1b19115dd6a759c0808b8

/-- Core's `script_flag_exceptions`: keyed by BLOCK HASH; each hit
REPLACES the base flag set before the buried flags are OR-ed back in
(validation.cpp:2262-2265). if/else form (not a match) so `simp` can
reduce it under ≠ hypotheses. -/
@[rule "INV-133"]
def mainnetExceptionMap : BlockHash → Option ScriptFlags := fun hash =>
  if hash = bip16ExceptionHash then
    some { p2sh := false, witness := false, taproot := false }  -- SCRIPT_VERIFY_NONE
  else if hash = taprootExceptionHash then
    some { p2sh := true, witness := true, taproot := false }    -- P2SH | WITNESS
  else none

/-- Exact map entry, BIP16 exception (SCR-016 / BLK-084 ground data). -/
theorem mainnet_bip16_exception_lookup :
    mainnetExceptionMap bip16ExceptionHash =
      some { p2sh := false, witness := false, taproot := false } := by
  rw [mainnetExceptionMap, if_pos rfl]

/-- Exact map entry, taproot exception (SCR-016 / BLK-084 ground data). -/
theorem mainnet_taproot_exception_lookup :
    mainnetExceptionMap taprootExceptionHash =
      some { p2sh := true, witness := true, taproot := false } := by
  rw [mainnetExceptionMap,
      if_neg (by decide : ¬ (taprootExceptionHash = bip16ExceptionHash))]
  rfl

/-! ## Chain params + the Core-faithful port -/

/-- The subset of `Consensus::Params` that flag selection reads
(kernel/chainparams.cpp): the exception map and the buried activation
heights. -/
structure ChainParams where
  scriptFlagExceptions : BlockHash → Option ScriptFlags
  bip34Height : UInt32 := 227931
  bip66Height : UInt32 := 363725
  bip65Height : UInt32 := 388381
  csvHeight : UInt32 := 419328
  segwitHeight : UInt32 := 481824

/-- Mainnet chain params: the exception map + Core's buried heights. -/
def mainnetParams : ChainParams :=
  { scriptFlagExceptions := mainnetExceptionMap
    bip34Height := BIP34_HEIGHT, bip66Height := BIP66_HEIGHT
    bip65Height := BIP65_HEIGHT, csvHeight := CSV_HEIGHT
    segwitHeight := SEGWIT_HEIGHT }

/-- BLK-070/071: mainnet buried heights + the BIP34 activation hash,
verbatim from kernel/chainparams.cpp:117-124 (values also confirmed in
the pinned tree @cce32b168). SWT-035: mainnet segwit active from block
481,824 (flags via pindexPrev — `buriedActive` + `getBlockScriptFlagsP`). -/
@[rule "BLK-070", rule "BLK-071", rule "SWT-035", rule "INV-127"] theorem buried_heights_mainnet :
    mainnetParams.bip34Height = 227931 ∧
    mainnetParams.bip66Height = 363725 ∧
    mainnetParams.bip65Height = 388381 ∧
    mainnetParams.csvHeight = 419328 ∧
    mainnetParams.segwitHeight = 481824 ∧
    bip34ActivationHash =
      0x000000000000024b89b42a942fe0d9fea3bb44ab7bd1b19115dd6a759c0808b8 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- BLK-072: `DeploymentActiveAt` for a buried deployment is the plain
height compare `height ≥ since` (deploymentstatus.h:27-31) — a block at
exactly the buried height already carries the flag. -/
@[rule "BLK-072"] def buriedActive (_P : ChainParams) (since height : UInt32) : Bool :=
  since ≤ height

@[rule "BLK-072"] theorem buriedActive_true (P : ChainParams) (since height : UInt32)
    (h : since ≤ height) : buriedActive P since height = true :=
  decide_eq_true h

@[rule "BLK-072"] theorem buriedActive_false (P : ChainParams) (since height : UInt32)
    (h : height < since) : buriedActive P since height = false :=
  decide_eq_false (by
    have h' := UInt32.lt_iff_toNat_lt.mp h
    exact Nat.not_le.mpr h')

/-- Core-faithful `GetBlockScriptFlags` (validation.cpp:2249-2288) over
arbitrary chain params + block hash: base := P2SH|WITNESS|TAPROOT; a
hash-map exception hit REPLACES the base; then DERSIG/CLTV/CSV/NULLDUMMY
are OR-ed in by their buried heights (NULLDUMMY rides segwit,
validation.cpp:2280-2283). -/
@[rule "SCR-015", rule "TXV-055"] def getBlockScriptFlagsP (P : ChainParams) (hash : BlockHash)
    (height : UInt32) : ScriptFlags :=
  let base :=
    match P.scriptFlagExceptions hash with
    | some exf => exf
    | none => { p2sh := true, witness := true, taproot := true }
  { base with
      dersig    := base.dersig    || buriedActive P P.bip66Height  height
      cltv      := base.cltv      || buriedActive P P.bip65Height  height
      csv       := base.csv       || buriedActive P P.csvHeight    height
      nullDummy := base.nullDummy || buriedActive P P.segwitHeight height }

/-- BLK-083: away from exception blocks the base set is exactly
P2SH | WITNESS | TAPROOT (validation.cpp:2256-2260) and is never dropped
by the buried ORs. -/
@[rule "BLK-083", rule "INV-132"] theorem base_flags_p2sh_witness_taproot (P : ChainParams)
    (hash : BlockHash) (height : UInt32)
    (hnone : P.scriptFlagExceptions hash = none) :
    (getBlockScriptFlagsP P hash height).p2sh = true ∧
    (getBlockScriptFlagsP P hash height).witness = true ∧
    (getBlockScriptFlagsP P hash height).taproot = true := by
  simp [getBlockScriptFlagsP, hnone]

/-- SWT-016: the WITNESS flag requires P2SH (BIP141 structural pairing;
Core's flag derivation never yields WITNESS without P2SH, and the
interpreter's WITNESS_UNEXPECTED path interpreter.cpp:2113-2114,2124 is
predicated on it). Away from exception blocks this is immediate from
BLK-083 (base = P2SH | WITNESS | TAPROOT, buried ORs don't touch either). -/
@[rule "SWT-016"] theorem witness_implies_p2sh (P : ChainParams)
    (hash : BlockHash) (height : UInt32)
    (hnone : P.scriptFlagExceptions hash = none) :
    (getBlockScriptFlagsP P hash height).witness = true →
    (getBlockScriptFlagsP P hash height).p2sh = true := by
  have h := base_flags_p2sh_witness_taproot P hash height hnone
  intro _; exact h.1

/-- BLK-084: an exception entry REPLACES the base set for the three
always-on flags (the buried ORs only ever touch DERSIG/CLTV/CSV/
NULLDUMMY) — validation.cpp:2262-2265. -/
@[rule "BLK-084", rule "TXV-056"] theorem exception_replaces_base (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (exf : ScriptFlags)
    (hexc : P.scriptFlagExceptions hash = some exf) :
    (getBlockScriptFlagsP P hash height).p2sh = exf.p2sh ∧
    (getBlockScriptFlagsP P hash height).witness = exf.witness ∧
    (getBlockScriptFlagsP P hash height).taproot = exf.taproot := by
  simp [getBlockScriptFlagsP, hexc]

/-- BLK-085: DERSIG is set exactly when BIP66 is active at the block
(validation.cpp:2266-2269). SWT-061: strict-DER signature encoding is
CONSENSUS from height 363,725 — the flag flows into `checkSigEncoding`'s
DER gate (`flags.dersig` term) and seam (`dersig_iff`). SCR-103:
the BIP66 activation row (validation.cpp:2268-2270). The `hnone`-free
faces `dersig_flag_flow_any` / `dersig_flag_flow_mainnet_any` cover the
exception-hash branch too (Core ORs DERSIG after the replacement). -/
@[rule "BLK-085", rule "SWT-061", rule "SCR-103", rule "INV-128"] theorem dersig_flag_flow (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (hnone : P.scriptFlagExceptions hash = none)
    (hact : P.bip66Height ≤ height) :
    (getBlockScriptFlagsP P hash height).dersig = true := by
  simp [getBlockScriptFlagsP, hnone, buriedActive, decide_eq_true hact]

/-- BLK-085 (converse): below the BIP66 height DERSIG is off. -/
theorem dersig_flag_off (P : ChainParams) (hash : BlockHash) (height : UInt32)
    (hnone : P.scriptFlagExceptions hash = none) (hlt : height < P.bip66Height) :
    (getBlockScriptFlagsP P hash height).dersig = false := by
  have hcmp : ¬ (P.bip66Height ≤ height) :=
    Nat.not_le.mpr (UInt32.lt_iff_toNat_lt.mp hlt)
  simp [getBlockScriptFlagsP, hnone, buriedActive, decide_eq_false hcmp]

/-- SCR-103 (mainnet constant): for mainnet, DERSIG is ON exactly from the
BIP66 buried height **363,725** — the row's constant is
`mainnetParams.bip66Height` (pinned by `buried_heights_mainnet`;
validation.cpp:2268-2270 `DeploymentActiveAt(DEPLOYMENT_DERSIG)`). -/
@[rule "SCR-103"] theorem dersig_flag_flow_mainnet (hash : BlockHash)
    (height : UInt32) (hnone : mainnetParams.scriptFlagExceptions hash = none)
    (hact : 363725 ≤ height) :
    (getBlockScriptFlagsP mainnetParams hash height).dersig = true := by
  have hb : mainnetParams.bip66Height ≤ height := by
    simpa [mainnetParams, BIP66_HEIGHT] using hact
  exact dersig_flag_flow mainnetParams hash height hnone hb

/-- SCR-103 (mainnet constant, converse): below 363,725 DERSIG is off. -/
@[rule "SCR-103"] theorem dersig_flag_off_mainnet (hash : BlockHash)
    (height : UInt32) (hnone : mainnetParams.scriptFlagExceptions hash = none)
    (hlt : height < 363725) :
    (getBlockScriptFlagsP mainnetParams hash height).dersig = false := by
  have hb : height < mainnetParams.bip66Height := by
    simpa [mainnetParams, BIP66_HEIGHT] using hlt
  exact dersig_flag_off mainnetParams hash height hnone hb

/-- SCR-103 (exception-hash-free activation): Core ORs DERSIG in after
the exception replacement (validation.cpp:2262-2270), so at and above
the BIP66 buried height the flag is on for EVERY block hash — including
the BIP16 and taproot exception hashes whose replacement sets carry
`dersig = false`. -/
@[rule "SCR-103"] theorem dersig_flag_flow_any (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (hact : P.bip66Height ≤ height) :
    (getBlockScriptFlagsP P hash height).dersig = true := by
  simp [getBlockScriptFlagsP, buriedActive, decide_eq_true hact]

/-- SCR-103 (mainnet, exception-hash-free): DERSIG is on from height
363,725 for every mainnet block hash, exception hashes included. -/
@[rule "SCR-103"] theorem dersig_flag_flow_mainnet_any (hash : BlockHash)
    (height : UInt32) (hact : 363725 ≤ height) :
    (getBlockScriptFlagsP mainnetParams hash height).dersig = true := by
  refine dersig_flag_flow_any mainnetParams hash height ?_
  simpa [mainnetParams, BIP66_HEIGHT] using hact

/-- SCR-103 (mainnet converse, exception-hash-free): below 363,725
DERSIG is off for every mainnet hash. Both mainnet exception replacement
sets have `dersig = false` (BIP16: SCRIPT_VERIFY_NONE; taproot:
P2SH|WITNESS), and away from them the base set also has `dersig = false`
until the buried OR fires. -/
@[rule "SCR-103"] theorem dersig_flag_off_mainnet_any (hash : BlockHash)
    (height : UInt32) (hlt : height < 363725) :
    (getBlockScriptFlagsP mainnetParams hash height).dersig = false := by
  have hb : height < mainnetParams.bip66Height := by
    simpa [mainnetParams, BIP66_HEIGHT] using hlt
  have hcmp : ¬ (mainnetParams.bip66Height ≤ height) :=
    Nat.not_le.mpr (UInt32.lt_iff_toNat_lt.mp hb)
  have hcmp' : ¬ (BIP66_HEIGHT ≤ height) := by
    simpa [mainnetParams, BIP66_HEIGHT] using hcmp
  by_cases h1 : hash = bip16ExceptionHash
  · subst h1
    simp [getBlockScriptFlagsP, mainnetParams, mainnetExceptionMap,
      buriedActive, hcmp']
  · by_cases h2 : hash = taprootExceptionHash
    · subst h2
      simp [getBlockScriptFlagsP, mainnetParams, mainnetExceptionMap,
        h1, buriedActive, hcmp']
    · simp [getBlockScriptFlagsP, mainnetParams, mainnetExceptionMap,
        h1, h2, buriedActive, hcmp']

/-- BLK-086: CLTV is set exactly when BIP65 is active (validation.cpp:2271-2274). -/
@[rule "BLK-086", rule "INV-129"] theorem cltv_flag_flow (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (hnone : P.scriptFlagExceptions hash = none)
    (hact : P.bip65Height ≤ height) :
    (getBlockScriptFlagsP P hash height).cltv = true := by
  simp [getBlockScriptFlagsP, hnone, buriedActive, decide_eq_true hact]

/-- BLK-087: CSV is set exactly when CSV is active (validation.cpp:2276-2278;
the CSV opcode itself also requires LOCKTIME_VERIFY_SEQUENCE, handled by
contextual checks — flag selection is this height compare). -/
@[rule "BLK-087", rule "INV-130"] theorem csv_flag_flow (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (hnone : P.scriptFlagExceptions hash = none)
    (hact : P.csvHeight ≤ height) :
    (getBlockScriptFlagsP P hash height).csv = true := by
  simp [getBlockScriptFlagsP, hnone, buriedActive, decide_eq_true hact]

/-- BLK-088: NULLDUMMY is set exactly when segwit is active — BIP147
rides segwit (validation.cpp:2280-2283). SWT-063: NULLDUMMY active
exactly with segwit (buried height); the activation direction is this
theorem, the below-height direction is `buriedActive_false` + the
`||`-gate in `getBlockScriptFlagsP`; `nulldummy_flag_flow_any` and
`nulldummy_flag_iff_mainnet_any` are the `hnone`-free exception-hash
faces (Core ORs NULLDUMMY after the replacement). -/
@[rule "BLK-088", rule "SWT-063", rule "INV-131", rule "TXV-057"] theorem nulldummy_flag_flow (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (hnone : P.scriptFlagExceptions hash = none)
    (hact : P.segwitHeight ≤ height) :
    (getBlockScriptFlagsP P hash height).nullDummy = true := by
  simp [getBlockScriptFlagsP, hnone, buriedActive, decide_eq_true hact]

/-- SWT-063 (converse): away from the exception blocks NULLDUMMY is on
EXACTLY when segwit is buried-active — the `||`-gate contributes
`buriedActive P P.segwitHeight height`, whose base disjunct is false under
`hnone`.  This is the "only with segwit" half the activation-direction
theorem does not give. -/
@[rule "SWT-063"] theorem nulldummy_flag_iff (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (hnone : P.scriptFlagExceptions hash = none) :
    (getBlockScriptFlagsP P hash height).nullDummy = true ↔
      P.segwitHeight ≤ height := by
  by_cases h : P.segwitHeight ≤ height
  · simp [getBlockScriptFlagsP, hnone, buriedActive, h]
  · have hcmp : ¬ (P.segwitHeight ≤ height) := h
    simp [getBlockScriptFlagsP, hnone, buriedActive, hcmp]

/-- SWT-063 (mainnet ground data): NULLDUMMY is on exactly from the
buried segwit height 481,824 (`mainnetParams.segwitHeight`, pinned by
`buried_heights_mainnet`; validation.cpp:2282-2285). -/
@[rule "SWT-063"] theorem nulldummy_flag_iff_mainnet (hash : BlockHash)
    (height : UInt32) (hnone : mainnetParams.scriptFlagExceptions hash = none) :
    (getBlockScriptFlagsP mainnetParams hash height).nullDummy = true ↔
      481824 ≤ height := by
  have h := nulldummy_flag_iff mainnetParams hash height hnone
  simpa [mainnetParams, SEGWIT_HEIGHT] using h

/-- SWT-063 (exception-hash-free activation): NULLDUMMY is OR-ed in after
the exception replacement (validation.cpp:2280-2285), so at and above
the buried segwit height it is on for EVERY block hash, the two
exception hashes included. -/
@[rule "SWT-063"] theorem nulldummy_flag_flow_any (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (hact : P.segwitHeight ≤ height) :
    (getBlockScriptFlagsP P hash height).nullDummy = true := by
  simp [getBlockScriptFlagsP, buriedActive, decide_eq_true hact]

/-- SWT-063 (mainnet, exception-hash-free): NULLDUMMY is on exactly from
height 481,824 for EVERY mainnet block hash. Both mainnet exception
replacement sets have `nullDummy = false` (BIP16: SCRIPT_VERIFY_NONE;
taproot: P2SH|WITNESS), so the flag's base disjunct is false everywhere
and the segwit OR is the whole truth value. -/
@[rule "SWT-063"] theorem nulldummy_flag_iff_mainnet_any (hash : BlockHash)
    (height : UInt32) :
    (getBlockScriptFlagsP mainnetParams hash height).nullDummy = true ↔
      481824 ≤ height := by
  by_cases h : 481824 ≤ height
  · have hb : mainnetParams.segwitHeight ≤ height := by
      simpa [mainnetParams, SEGWIT_HEIGHT] using h
    rw [nulldummy_flag_flow_any mainnetParams hash height hb]
    exact ⟨fun _ => h, fun _ => rfl⟩
  · have hb : ¬ (mainnetParams.segwitHeight ≤ height) := by
      simpa [mainnetParams, SEGWIT_HEIGHT] using h
    have hb' : ¬ (SEGWIT_HEIGHT ≤ height) := by
      simpa [mainnetParams, SEGWIT_HEIGHT] using hb
    have hfalse : (getBlockScriptFlagsP mainnetParams hash height).nullDummy = false := by
      by_cases h1 : hash = bip16ExceptionHash
      · subst h1
        simp [getBlockScriptFlagsP, mainnetParams, mainnetExceptionMap,
          buriedActive, hb']
      · by_cases h2 : hash = taprootExceptionHash
        · subst h2
          simp [getBlockScriptFlagsP, mainnetParams, mainnetExceptionMap,
            h1, buriedActive, hb']
        · simp [getBlockScriptFlagsP, mainnetParams, mainnetExceptionMap,
            h1, h2, buriedActive, hb']
    rw [hfalse]
    exact ⟨fun hc => absurd hc (by simp), fun hc => absurd hc h⟩

/-! ### Exact mainnet exception vectors + height↔hash agreement -/

/-- SCR-016: the BIP16 exception block (hash …4f9c22, height 170060)
validates with SCRIPT_VERIFY_NONE — every consensus flag off (no buried
deployment is active at 170060, so the buried ORs add nothing). -/
theorem mainnet_bip16_exception_flags (height : UInt32)
    (h : height = BIP16_EXCEPTION_HEIGHT) :
    getBlockScriptFlagsP mainnetParams bip16ExceptionHash height =
      { p2sh := false, dersig := false, cltv := false, csv := false,
        nullDummy := false, witness := false, taproot := false } := by
  rw [h]; decide

/-- SCR-016: the taproot exception block (hash …1e395ad, height 692261)
validates with P2SH|WITNESS plus all four buried flags, TAPROOT off. -/
theorem mainnet_taproot_exception_flags (height : UInt32)
    (h : height = TAPROOT_EXCEPTION_HEIGHT) :
    getBlockScriptFlagsP mainnetParams taprootExceptionHash height =
      { p2sh := true, dersig := true, cltv := true, csv := true,
        nullDummy := true, witness := true, taproot := false } := by
  rw [h]; decide

/-- The exact replacement set Core's `script_flag_exceptions` assigns to
the BIP16-violating block: SCRIPT_VERIFY_NONE
(kernel/chainparams.cpp:115-116). -/
def bip16ExceptionFlags : ScriptFlags :=
  { p2sh := false, witness := false, taproot := false }

/-- The exact replacement set for the taproot-violating block:
P2SH | WITNESS (kernel/chainparams.cpp:117-118). -/
def taprootExceptionFlags : ScriptFlags :=
  { p2sh := true, witness := true, taproot := false }

/-- BLK-084: both historical exception blocks, by the exact 256-bit
block-hash literals Core keys `script_flag_exceptions` on, together with
the exact replacement flag sets (BIP16 ⇒ SCRIPT_VERIFY_NONE; taproot ⇒
P2SH|WITNESS) and the effective `GetBlockScriptFlags` verdicts at their
heights (validation.cpp:2260-2265). -/
@[rule "BLK-084"] theorem mainnet_exception_blocks_exact :
    mainnetExceptionMap
        0x00000000000002dc756eebf4f49723ed8d30cc28a5f108eb94b1ba88ac4f9c22 =
      some bip16ExceptionFlags ∧
    mainnetExceptionMap
        0x0000000000000000000f14c35b2d841e986ab5441de8c585d5ffe55ea1e395ad =
      some taprootExceptionFlags ∧
    getBlockScriptFlagsP mainnetParams
        0x00000000000002dc756eebf4f49723ed8d30cc28a5f108eb94b1ba88ac4f9c22
        BIP16_EXCEPTION_HEIGHT =
      { p2sh := false, dersig := false, cltv := false, csv := false,
        nullDummy := false, witness := false, taproot := false } ∧
    getBlockScriptFlagsP mainnetParams
        0x0000000000000000000f14c35b2d841e986ab5441de8c585d5ffe55ea1e395ad
        TAPROOT_EXCEPTION_HEIGHT =
      { p2sh := true, dersig := true, cltv := true, csv := true,
        nullDummy := true, witness := true, taproot := false } := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · exact mainnet_bip16_exception_lookup
  · exact mainnet_taproot_exception_lookup
  · exact mainnet_bip16_exception_flags _ rfl
  · exact mainnet_taproot_exception_flags _ rfl

/-- TXV-056: mainnet's `script_flag_exceptions` contains EXACTLY two
hashes, and both entries are REDUCED base sets (neither is the always-on
P2SH|WITNESS|TAPROOT base): the BIP16 block (SCRIPT_VERIFY_NONE) and the
taproot block (P2SH|WITNESS, TAPROOT off).  Every other hash falls
through to the base set. -/
@[rule "TXV-056"] theorem mainnet_exception_exactly_two_reduced
    (hash : BlockHash) :
    mainnetExceptionMap hash = none ∨
    (hash = bip16ExceptionHash ∧
      mainnetExceptionMap hash = some bip16ExceptionFlags ∧
      bip16ExceptionFlags.taproot = false) ∨
    (hash = taprootExceptionHash ∧
      mainnetExceptionMap hash = some taprootExceptionFlags ∧
      taprootExceptionFlags.taproot = false) := by
  by_cases h1 : hash = bip16ExceptionHash
  · refine Or.inr (Or.inl ⟨h1, ?_, rfl⟩)
    rw [h1]
    show mainnetExceptionMap bip16ExceptionHash =
      some { p2sh := false, witness := false, taproot := false }
    exact mainnet_bip16_exception_lookup
  · by_cases h2 : hash = taprootExceptionHash
    · refine Or.inr (Or.inr ⟨h2, ?_, rfl⟩)
      rw [h2]
      show mainnetExceptionMap taprootExceptionHash =
        some { p2sh := true, witness := true, taproot := false }
      exact mainnet_taproot_exception_lookup
    · exact Or.inl (by simp [mainnetExceptionMap, h1, h2])

/-- The two models agree on the BIP16 exception block. -/
theorem mainnet_height_hash_agree_bip16 (height : UInt32)
    (h : height = BIP16_EXCEPTION_HEIGHT) :
    getBlockScriptFlagsP mainnetParams bip16ExceptionHash height =
      getBlockScriptFlags height := by
  rw [h]; rfl

/-- The two models agree on the taproot exception block. -/
theorem mainnet_height_hash_agree_taproot (height : UInt32)
    (h : height = TAPROOT_EXCEPTION_HEIGHT) :
    getBlockScriptFlagsP mainnetParams taprootExceptionHash height =
      getBlockScriptFlags height := by
  rw [h]; rfl

/-- The two models agree away from the exception blocks. -/
theorem mainnet_height_hash_agree_default (height : UInt32) (hash : BlockHash)
    (hne : mainnetExceptionMap hash = none)
    (he1 : height ≠ BIP16_EXCEPTION_HEIGHT) (he2 : height ≠ TAPROOT_EXCEPTION_HEIGHT) :
    getBlockScriptFlagsP mainnetParams hash height = getBlockScriptFlags height := by
  simp [getBlockScriptFlagsP, mainnetParams, hne, buriedActive,
        getBlockScriptFlags, he1, he2, mainnetBaseFlags]
  refine ⟨rfl, rfl, rfl, rfl⟩

/-- Master agreement theorem: given the height↔hash correspondence for
the two named exception blocks (on mainnet each height has exactly one
canonical block), the hash-keyed Core-faithful port and the frozen
height-keyed interface coincide for every block. -/
theorem mainnet_height_hash_agree (height : UInt32) (hash : BlockHash)
    (h1 : (hash = bip16ExceptionHash ↔ height = BIP16_EXCEPTION_HEIGHT))
    (h2 : (hash = taprootExceptionHash ↔ height = TAPROOT_EXCEPTION_HEIGHT)) :
    getBlockScriptFlagsP mainnetParams hash height = getBlockScriptFlags height := by
  by_cases e1 : hash = bip16ExceptionHash
  · have hh : height = BIP16_EXCEPTION_HEIGHT := h1.mp e1
    rw [e1, hh]
    exact mainnet_height_hash_agree_bip16 _ rfl
  by_cases e2 : hash = taprootExceptionHash
  · have hh : height = TAPROOT_EXCEPTION_HEIGHT := h2.mp e2
    rw [e2, hh]
    exact mainnet_height_hash_agree_taproot _ rfl
  · refine mainnet_height_hash_agree_default height hash ?_ ?_ ?_
    · simp [mainnetExceptionMap, e1, e2]
    · intro hh; exact e1 (h1.mpr hh)
    · intro hh; exact e2 (h2.mpr hh)

/-! ## `verify_flags.h` bit values (consensus subset) -/

/-- Exact Core bit assignment (verify_flags.h @master, fetched 2026-10-16):
P2SH=1«0, DERSIG=1«2, NULLDUMMY=1«4, CLTV=1«9, CSV=1«10, WITNESS=1«11,
TAPROOT=1«17. The Bool-record → UInt32 mapping. -/
def flagBits (f : ScriptFlags) : UInt32 :=
  (bif f.p2sh then (1 : UInt32) <<< 0 else 0) |||
  (bif f.dersig then (1 : UInt32) <<< 2 else 0) |||
  (bif f.nullDummy then (1 : UInt32) <<< 4 else 0) |||
  (bif f.cltv then (1 : UInt32) <<< 9 else 0) |||
  (bif f.csv then (1 : UInt32) <<< 10 else 0) |||
  (bif f.witness then (1 : UInt32) <<< 11 else 0) |||
  (bif f.taproot then (1 : UInt32) <<< 17 else 0)

/-- The always-on base set is exactly `SCRIPT_VERIFY_P2SH |
SCRIPT_VERIFY_WITNESS | SCRIPT_VERIFY_TAPROOT` = 0x20801. -/
theorem flagBits_base : flagBits mainnetBaseFlags = 0x20801 := by decide

/-- The full post-burial set (all 7 consensus flags) is 0x20E15
(0x20801 | DERSIG(4) | NULLDUMMY(16) | CLTV(512) | CSV(1024)). -/
theorem flagBits_full :
    flagBits { p2sh := true, dersig := true, cltv := true, csv := true,
               nullDummy := true, witness := true, taproot := true } = 0x20E15 := by
  decide

/-- Each consensus flag owns exactly one bit: the singleton records map
to the `verify_flags.h` values (so the record carries the same
information as Core's UInt32 bitset). -/
theorem flagBits_singletons :
    flagBits { p2sh := true } = 1 ∧
    flagBits { dersig := true } = 4 ∧
    flagBits { nullDummy := true } = 16 ∧
    flagBits { cltv := true } = 512 ∧
    flagBits { csv := true } = 1024 ∧
    flagBits { witness := true } = 2048 ∧
    flagBits { taproot := true } = 131072 := by
  decide

/-! ## Policy-only flags (NOT consensus — the activation layer, item b) -/

/-- The eight script-verification flags that are NOT consensus rules on
mainnet. BIP146 ("mandatory consensus consistency" — LOW_S, STRICTENC,
MINIMALDATA, NULLFAIL, CLEANSTACK) was never activated; CONST_SCRIPTCODE
is consensus-preserving-only policy; MINIMALIF applies to v0 witness
spends only (and tapscript re-imports it, see below); WITNESS_PUBKEYTYPE
is policy. These live in Core's mempool/tx-validation flag sets, never in
`GetBlockScriptFlags` (validation.cpp:2249-2288 mentions none of them). -/
-- Lean tag bundle: the catalogue rows SCR-175..SCR-182 (one per flag).
@[rule "SCR-175", rule "SCR-176", rule "SCR-177", rule "SCR-178",
  rule "SCR-179", rule "SCR-180", rule "SCR-181", rule "SCR-182"]
inductive PolicyFlag where
  | lowS             -- SCRIPT_VERIFY_LOW_S            (BIP146)
  | strictEnc        -- SCRIPT_VERIFY_STRICTENC        (BIP146)
  | minimalData      -- SCRIPT_VERIFY_MINIMALDATA      (BIP146)
  | minimalIfV0      -- SCRIPT_VERIFY_MINIMALIF        (v0 witness only)
  | nullFail         -- SCRIPT_VERIFY_NULLFAIL         (BIP146)
  | cleanStack       -- SCRIPT_VERIFY_CLEANSTACK       (BIP146)
  | constScriptCode  -- SCRIPT_VERIFY_CONST_SCRIPTCODE
  | witnessPubKeyType -- SCRIPT_VERIFY_WITNESS_PUBKEYTYPE
deriving Repr, DecidableEq, BEq

/-- The full verification-flag view: a consensus `ScriptFlags` set plus a
policy assignment. `VerifyScript` consumes this; block validation
consumes only the `consensus` projection. (No DecidableEq: the policy
field is a function; compare per-flag instead.) -/
structure FullFlags where
  consensus : ScriptFlags := {}
  policy : PolicyFlag → Bool := fun _ => false

/-- The consensus-only view — what `GetBlockScriptFlags` produces. Policy
flags are all off: block validation never consults them. -/
def consensusFullFlags (f : ScriptFlags) : FullFlags :=
  { consensus := f, policy := fun _ => false }

/-- Policy flags are absent from consensus flag selection. -/
theorem policy_absent_from_consensus (f : ScriptFlags) (p : PolicyFlag) :
    (consensusFullFlags f).policy p = false := rfl

/-- The consensus projection of the consensus-only view is the input. -/
theorem consensus_consensusFullFlags (f : ScriptFlags) :
    (consensusFullFlags f).consensus = f := rfl

/-! ### Tapscript re-imports MINIMALIF / CLEANSTACK as consensus -/

/-- Whether minimal-IF semantics are enforced for a spend: policy opt-in,
or TAPSCRIPT (BIP342 §8: "MINIMALIF is the rule for tapscript";
interpreter.cpp enforces MINIMALIF unconditionally when
`sigversion == SigVersion::TAPSCRIPT`, regardless of the flag). -/
def minimalIfRequired (f : FullFlags) (sigv : Bitcoin.Crypto.Seam.SigVersion) : Bool :=
  f.policy .minimalIfV0 || decide (sigv = Bitcoin.Crypto.Seam.SigVersion.tapscript)

/-- Whether clean-stack is enforced: policy opt-in, or TAPSCRIPT
(BIP342 §5: clean stack is consensus for tapscript;
interpreter.cpp's VerifyStack requires scriptSize = 0 for
`SigVersion::TAPSCRIPT`). -/
def cleanStackRequired (f : FullFlags) (sigv : Bitcoin.Crypto.Seam.SigVersion) : Bool :=
  f.policy .cleanStack || decide (sigv = Bitcoin.Crypto.Seam.SigVersion.tapscript)

/-- For tapscript spends, minimal-IF is enforced even when the policy
flag is off (BIP342 re-imports it as consensus). -/
theorem minimalif_consensus_in_tapscript (f : FullFlags) :
    minimalIfRequired f Bitcoin.Crypto.Seam.SigVersion.tapscript = true := by
  simp [minimalIfRequired]

/-- For tapscript spends, clean-stack is enforced even when the policy
flag is off (BIP342 re-imports it as consensus). -/
theorem cleanstack_consensus_in_tapscript (f : FullFlags) :
    cleanStackRequired f Bitcoin.Crypto.Seam.SigVersion.tapscript = true := by
  simp [cleanStackRequired]

/-- BIP342 re-import: both policy flags become consensus requirements for
tapscript, in one statement (SCR-183).  (For `SigVersion::base` /
`witnessV0` the policy bits are the only source — the `||` left disjunct.) -/
@[rule "SCR-183"] theorem tapscript_reimports_policy (f : FullFlags) :
    minimalIfRequired f Bitcoin.Crypto.Seam.SigVersion.tapscript = true ∧
    cleanStackRequired f Bitcoin.Crypto.Seam.SigVersion.tapscript = true := by
  constructor <;> simp [minimalIfRequired, cleanStackRequired]

/-- And in the other direction the re-import is faithful: for base and
v0-witness spends, minimal-IF is enforced iff the policy bit says so. -/
theorem minimalif_policy_only_off_tapscript (f : FullFlags)
    (sigv : Bitcoin.Crypto.Seam.SigVersion) (h : sigv ≠ Bitcoin.Crypto.Seam.SigVersion.tapscript) :
    minimalIfRequired f sigv = f.policy .minimalIfV0 := by
  simp [minimalIfRequired, h]

end Bitcoin.Activation
