import Bitcoin.Data.Basic
import Bitcoin.Data.Tx

/-!
# Bitcoin.Activation — consensus script flags & soft-fork activation (W06)

## Ownership block (do not edit outside an interface-change PR)

Owning workstream     : W06 (Consensus flags & activation)
Dependent workstreams : W09 (flags drive EvalScript/VerifyScript),
                        W10 (CSV/CLTV contextual checks), W12 (BIP34
                        height gate), W16 (audit of flag vectors)
Core counterpart files: src/validation.cpp (GetBlockScriptFlags:2249-2288),
                        src/kernel/chainparams.cpp:113-137 (two mainnet
                        exception blocks, buried heights, testdummy),
                        src/versionbits.cpp:26-131 (BIP9 machine),
                        src/deploymentstatus.h:14-37, src/consensus/params.h
Status                : bodies filled + theorems proved 2026-10-16 by W06.
                        INTERFACE-CHANGE vs the W01 freeze — see below.

## Scope (B2/B4/B5-verified)

Consensus script flags are EXACTLY {P2SH, DERSIG, CLTV, CSV, NULLDUMMY,
WITNESS, TAPROOT}; LOW_S/STRICTENC/MINIMALDATA/MINIMALIF(v0)/NULLFAIL/
CLEANSTACK/CONST_SCRIPTCODE/WITNESS_PUBKEYTYPE are policy-only (BIP146
never activated) and are catalogued in `Bitcoin.Activation.Flags`
(`PolicyFlag`), not modeled here. Flag selection reduces to
`getBlockScriptFlags` + buried heights + 2 named mainnet exception
blocks. The dormant BIP9 machine is modeled for future soft forks.

## Interface changes vs the W01 freeze (each verified against Bitcoin Core
master as fetched 2026-10-16; full argument in
research/w2-06-flags-activation.md §3)

1. `BIP147_HEIGHT` corrected 419328 → 481824: BIP147 NULLDUMMY activates
   with SEGWIT (`DeploymentActiveAt(DEPLOYMENT_SEGWIT)`,
   validation.cpp:2280-2283). 419328 is Core's CSVHeight — kept as the
   new `CSV_HEIGHT`. `SEGWIT_HEIGHT` added.
2. `BIP16_EXCEPTION_BLOCKS` corrected [173805, 176360] → [170060, 692261]:
   Core's `script_flag_exceptions` (kernel/chainparams.cpp:115-118) is
   keyed by BLOCK HASH; the two mainnet entries are the BIP16-violating
   block 00000000000002dc…4f9c22 (= height 170060) and the
   taproot-violating block 0000000000000000000f14…1e395ad (= height
   692261); both height↔hash pairs verified against a public block
   explorer API (report §2.2). The hash-keyed map is modeled in
   `Bitcoin.Activation.Flags.mainnetExceptionMap`; this frozen surface
   keys by height (unique per mainnet block), with the agreement theorem
   `Bitcoin.Activation.Flags.mainnet_height_hash_agree`.
3. `flags_after_burial` gained `height ∉ EXCEPTION_HEIGHTS`: the taproot
   exception block (692261) sits above every buried height and drops
   TAPROOT, so the unqualified statement was false.
4. `flags_exception_blocks` restated to what is true of BOTH exception
   blocks (TAPROOT off); the exact per-block vectors are separate
   theorems `flags_bip16_exception` / `flags_taproot_exception`.
5. `flags_monotone` restated pointwise with both endpoints off the
   exception list. The frozen `∀ f : ScriptFlags → Bool, f (flags h₁) →
   f (flags h₂)` form is equivalent to `flags h₁ = flags h₂` (take
   `f := (· = flags h₁)`), which is false across activation heights —
   W01's handoff anticipated the tightening.
6. `getBlockScriptFlags` is a real `def` (was an `opaque` sorry stub).
7. `lockin_survives_timeout` gained the no-overflow hypothesis `hno`
   (UInt32 height arithmetic in the conclusion must not wrap).
-/

namespace Bitcoin.Activation

open Bitcoin.Data

/-! ## Flags (verify_flags.h; consensus subset as Bool-record, C1 R4) -/

/-- Consensus script flags. A Bool-record (not a UInt32 bitset): fields
stay `decide`-able and self-documenting; the `→ UInt32` mapping is
`Bitcoin.Activation.Flags.flagBits` (exact Core bit values). Policy-only
flags are deliberately absent (catalogued in `Flags.PolicyFlag`). -/
structure ScriptFlags where
  p2sh : Bool := false          -- SCRIPT_VERIFY_P2SH (BIP16)
  dersig : Bool := false        -- SCRIPT_VERIFY_DERSIG (BIP66)
  cltv : Bool := false          -- SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY (BIP65)
  csv : Bool := false           -- SCRIPT_VERIFY_CHECKSEQUENCEVERIFY (BIP112)
  nullDummy : Bool := false     -- SCRIPT_VERIFY_NULLDUMMY (BIP147)
  witness : Bool := false       -- SCRIPT_VERIFY_WITNESS (BIP141)
  taproot : Bool := false       -- SCRIPT_VERIFY_TAPROOT (BIP341)
deriving Repr, DecidableEq, BEq

/-- Buried activation heights, mainnet (VERIFIED: kernel/chainparams.cpp
CMainParams, lines 119-124 as fetched 2026-10-16; same values @cce32b168).
`DeploymentActiveAt` for buried deployments is the plain height compare
`height ≥ since` (deploymentstatus.h:27-31) — a block at exactly the
buried height already carries the flag (BLK-072). -/
def BIP34_HEIGHT : UInt32 := 227931
def BIP66_HEIGHT : UInt32 := 363725   -- DERSIG
def BIP65_HEIGHT : UInt32 := 388381   -- CLTV
def CSV_HEIGHT : UInt32 := 419328     -- CSV (BIP68/112/113)
def SEGWIT_HEIGHT : UInt32 := 481824  -- SegWit (BIP141/143/144)
/-- BIP147 NULLDUMMY activates with segwit (validation.cpp:2280-2283:
`DeploymentActiveAt(DEPLOYMENT_SEGWIT)` gates NULLDUMMY). W01's stub had
419328 here, which is Core's CSVHeight — corrected per interface-change
note 1. -/
def BIP147_HEIGHT : UInt32 := 481824

/-- The two named mainnet exception blocks, by height (interface-change
note 2; hash-keyed map + exact hashes in `Bitcoin.Activation.Flags`).

* `BIP16_EXCEPTION_HEIGHT` = block 00000000000002dc756eebf4f49723ed8d30
  cc28a5f108eb94b1ba88ac4f9c22 (height 170060): validated with
  SCRIPT_VERIFY_NONE (kernel/chainparams.cpp:115-116).
* `TAPROOT_EXCEPTION_HEIGHT` = block 0000000000000000000f14c35b2d841e986
  ab5441de8c585d5ffe55ea1e395ad (height 692261): validated with
  P2SH|WITNESS only (kernel/chainparams.cpp:117-118). -/
def BIP16_EXCEPTION_HEIGHT : UInt32 := 170060
def TAPROOT_EXCEPTION_HEIGHT : UInt32 := 692261
def EXCEPTION_HEIGHTS : List UInt32 := [170060, 692261]
/-- Kept frozen name, corrected data (was [173805, 176360] — neither is a
Core exception block; see interface-change note 2). -/
def BIP16_EXCEPTION_BLOCKS : List UInt32 := [170060, 692261]

/-- The always-on base flag set (validation.cpp:2256-2260):
`SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_WITNESS | SCRIPT_VERIFY_TAPROOT`,
applied to every mainnet block from genesis except the two exception
blocks, whose entry REPLACES this base before the buried flags are
OR-ed back in (BLK-083). -/
def mainnetBaseFlags : ScriptFlags :=
  { p2sh := true, witness := true, taproot := true }

/-- `GetBlockScriptFlags` restricted to its mainnet inputs (the frozen
signature; the Core-faithful port over `ChainParams` + block hash is
`Bitcoin.Activation.Flags.getBlockScriptFlagsP`, and
`Flags.mainnet_height_hash_agree` proves the two agree).  Mainnet
exception blocks are identified by height here — sound on mainnet, where
each height has exactly one canonical block.

Transliteration of validation.cpp:2249-2288 @master (fetched 2026-10-16):
base := P2SH|WITNESS|TAPROOT; if block hash ∈ script_flag_exceptions then
flags := exceptions[hash] (REPLACES the base); then DERSIG/CLTV/CSV
OR-ed in when `height ≥` the buried height, and NULLDUMMY when
`height ≥ SegwitHeight` (BIP147 rides segwit). -/
def getBlockScriptFlags (height : UInt32) : ScriptFlags :=
  let base :=
    if height = BIP16_EXCEPTION_HEIGHT then
      { p2sh := false, witness := false, taproot := false }  -- SCRIPT_VERIFY_NONE
    else if height = TAPROOT_EXCEPTION_HEIGHT then
      { p2sh := true, witness := true, taproot := false }    -- P2SH|WITNESS
    else mainnetBaseFlags
  { base with
      dersig    := base.dersig    || (BIP66_HEIGHT  ≤ height)
      cltv      := base.cltv      || (BIP65_HEIGHT  ≤ height)
      csv       := base.csv       || (CSV_HEIGHT    ≤ height)
      nullDummy := base.nullDummy || (BIP147_HEIGHT ≤ height) }

/-- All four buried flag heights sit at/below the last one (481824):
routing helper so `omega` derives each `c ≤ height` from `BIP147_HEIGHT <
height`. -/
private theorem u32_le_of_last {c height : UInt32}
    (hc : c.toNat ≤ 481824) (h : (481824 : UInt32) < height) : c ≤ height := by
  have h3 : BIP147_HEIGHT.toNat = 481824 := rfl
  have h2 : BIP147_HEIGHT.toNat < height.toNat := UInt32.lt_iff_toNat_lt.mp h
  exact UInt32.le_iff_toNat_le.mpr (by omega)

/-- Normal form away from the exception blocks: the base set is exactly
{P2SH, WITNESS, TAPROOT} and each buried flag is its height compare. -/
theorem flags_norm (height : UInt32)
    (he1 : height ≠ BIP16_EXCEPTION_HEIGHT)
    (he2 : height ≠ TAPROOT_EXCEPTION_HEIGHT) :
    getBlockScriptFlags height =
      { p2sh := true, witness := true, taproot := true,
        dersig := (BIP66_HEIGHT ≤ height : Bool),
        cltv := (BIP65_HEIGHT ≤ height : Bool),
        csv := (CSV_HEIGHT ≤ height : Bool),
        nullDummy := (BIP147_HEIGHT ≤ height : Bool) } := by
  simp [getBlockScriptFlags, he1, he2, mainnetBaseFlags]

/-- SCR-015 (+ BLK-085..088): flags above the last buried height (481824)
at a non-exception block are exactly the always-on set {P2SH, WITNESS,
TAPROOT} + {DERSIG, CLTV, CSV, NULLDUMMY}.  (Interface-change note 3:
the exception hypothesis is necessary — block 692261 is above every
buried height yet drops TAPROOT.) -/
theorem flags_after_burial (height : UInt32)
    (h : BIP147_HEIGHT < height) (hexc : height ∉ EXCEPTION_HEIGHTS) :
    getBlockScriptFlags height =
      { p2sh := true, dersig := true, cltv := true, csv := true,
        nullDummy := true, witness := true, taproot := true } := by
  simp [EXCEPTION_HEIGHTS] at hexc
  obtain ⟨he1, he2⟩ := hexc
  rw [flags_norm height he1 he2]
  have h66 : BIP66_HEIGHT ≤ height := u32_le_of_last (by decide) h
  have h65 : BIP65_HEIGHT ≤ height := u32_le_of_last (by decide) h
  have hcsv : CSV_HEIGHT ≤ height := u32_le_of_last (by decide) h
  have h147 : BIP147_HEIGHT ≤ height := u32_le_of_last (by decide) h
  simp [h66, h65, hcsv, h147]

/-- SCR-016: the BIP16 exception block (170060) validates with
`SCRIPT_VERIFY_NONE` — every consensus flag off.  Exact mainnet vector;
at height 170060 no buried deployment is active, so the buried ORs add
nothing (faithful to validation.cpp's order: exception REPLACES base,
buried flags OR-ed after). -/
@[rule "SCR-016"] theorem flags_bip16_exception :
    getBlockScriptFlags BIP16_EXCEPTION_HEIGHT =
      { p2sh := false, dersig := false, cltv := false, csv := false,
        nullDummy := false, witness := false, taproot := false } :=
  by decide

/-- SCR-016: the taproot exception block (692261) validates with
P2SH|WITNESS plus all four buried flags (all buried heights < 692261),
TAPROOT off.  Exact mainnet vector. -/
theorem flags_taproot_exception :
    getBlockScriptFlags TAPROOT_EXCEPTION_HEIGHT =
      { p2sh := true, dersig := true, cltv := true, csv := true,
        nullDummy := true, witness := true, taproot := false } :=
  by decide

/-- SCR-016 (restated, interface-change note 4): what holds for BOTH
exception blocks is that TAPROOT is dropped; the exact historical sets
are the two vector theorems above. -/
theorem flags_exception_blocks (height : UInt32)
    (h : height ∈ BIP16_EXCEPTION_BLOCKS) :
    (getBlockScriptFlags height).taproot = false := by
  simp [BIP16_EXCEPTION_BLOCKS] at h
  rcases h with h | h
  · rw [h]; exact congrArg ScriptFlags.taproot flags_bip16_exception
  · rw [h]; exact congrArg ScriptFlags.taproot flags_taproot_exception

/-- Pointwise flag ordering (interface-change note 5): away from the two
exception blocks, consensus flags only accumulate with height.  Stated
per-field because the frozen `∀ f : ScriptFlags → Bool` form is
equivalent to equality (false across activation heights). -/
theorem flags_monotone (h₁ h₂ : UInt32) (hlt : h₁ ≤ h₂)
    (h₁ex : h₁ ∉ EXCEPTION_HEIGHTS) (h₂ex : h₂ ∉ EXCEPTION_HEIGHTS) :
    ((getBlockScriptFlags h₁).p2sh = true → (getBlockScriptFlags h₂).p2sh = true) ∧
    ((getBlockScriptFlags h₁).dersig = true → (getBlockScriptFlags h₂).dersig = true) ∧
    ((getBlockScriptFlags h₁).cltv = true → (getBlockScriptFlags h₂).cltv = true) ∧
    ((getBlockScriptFlags h₁).csv = true → (getBlockScriptFlags h₂).csv = true) ∧
    ((getBlockScriptFlags h₁).nullDummy = true → (getBlockScriptFlags h₂).nullDummy = true) ∧
    ((getBlockScriptFlags h₁).witness = true → (getBlockScriptFlags h₂).witness = true) ∧
    ((getBlockScriptFlags h₁).taproot = true → (getBlockScriptFlags h₂).taproot = true) := by
  simp [EXCEPTION_HEIGHTS] at h₁ex h₂ex
  obtain ⟨he1₁, he2₁⟩ := h₁ex
  obtain ⟨he1₂, he2₂⟩ := h₂ex
  rw [flags_norm h₁ he1₁ he2₁, flags_norm h₂ he1₂ he2₂]
  have hle : ∀ c : UInt32, c ≤ h₁ → c ≤ h₂ := by
    intro c hc
    have p1 : c.toNat ≤ h₁.toNat := UInt32.le_iff_toNat_le.mp hc
    have p2 : h₁.toNat ≤ h₂.toNat := UInt32.le_iff_toNat_le.mp hlt
    exact UInt32.le_iff_toNat_le.mpr (by omega)
  refine ⟨fun _ => rfl, ?_, ?_, ?_, ?_, fun _ => rfl, fun _ => rfl⟩
  · intro hd₁
    have hd : BIP66_HEIGHT ≤ h₁ := of_decide_eq_true hd₁
    exact decide_eq_true (hle BIP66_HEIGHT hd)
  · intro hc₁
    have hc : BIP65_HEIGHT ≤ h₁ := of_decide_eq_true hc₁
    exact decide_eq_true (hle BIP65_HEIGHT hc)
  · intro hcs₁
    have hc : CSV_HEIGHT ≤ h₁ := of_decide_eq_true hcs₁
    exact decide_eq_true (hle CSV_HEIGHT hc)
  · intro hn₁
    have hc : BIP147_HEIGHT ≤ h₁ := of_decide_eq_true hn₁
    exact decide_eq_true (hle BIP147_HEIGHT hc)

/-! ## Dormant BIP9 machine (versionbits.cpp) -/

/-- BIP9 threshold states (versionbits_impl.h:ThresholdState). -/
inductive ThresholdState where
  | defined | started | lockedIn | active | failed
deriving Repr, DecidableEq, BEq

/-- Sentinel encodings of Core's `BIP9Deployment::ALWAYS_ACTIVE` (-1) and
`NEVER_ACTIVE` (-2) start times in the UInt32 height abstraction: heights
are < 2³², so 2³²-1 / 2³²-2 can never be reached (BLK-079). -/
def BIP9_ALWAYS_ACTIVE : UInt32 := 4294967295
def BIP9_NEVER_ACTIVE : UInt32 := 4294967294

/-- BIP9 deployment parameters, time→height abstracted: `start` is the
height from which the deployment is STARTED (faithful because MTP is
monotone in height, so `mtp ≥ nStartTime` is a height threshold);
`timeoutPeriods` is the number of confirmation periods before timeout
(`deadline = start + timeoutPeriods * period`); `count h` is the number
of signalling blocks in the period ending at boundary height `h`
(versionbits.cpp:88-92 counts exactly those `period` blocks). -/
structure Bip9Params where
  start : Nat
  timeoutPeriods : Nat
  threshold : Nat
  period : Nat
  minActivation : Nat := 0
  count : Nat → Nat

/-- The timeout deadline in the height abstraction (BIP9: a deployment
that has not locked in by its timeout fails). -/
def bip9Deadline (P : Bip9Params) : Nat := P.start + P.timeoutPeriods * P.period

/-- Height of the last block of confirmation period `k` (0-indexed): the
boundary heights Core evaluates the machine at are exactly these
(versionbits.cpp:49-51 aligns `pindexPrev` to
`nHeight - ((nHeight+1) % nPeriod)`, i.e. `(h+1) % period = 0`). -/
def bip9BoundaryHeight (P : Bip9Params) (k : Nat) : Nat := (k + 1) * P.period - 1

theorem bip9BoundaryHeight_succ (P : Bip9Params) (k : Nat) :
    bip9BoundaryHeight P (k + 1) = bip9BoundaryHeight P k + P.period := by
  simp only [bip9BoundaryHeight]
  rcases Nat.eq_zero_or_pos P.period with hp | hp
  · rw [hp]; rfl
  · have hrel : (k + 1 + 1) * P.period = (k + 1) * P.period + P.period := by
      rw [Nat.add_mul, Nat.one_mul]
    have hb : 1 ≤ (k + 1) * P.period :=
      Nat.le_trans (Nat.succ_le_succ (Nat.zero_le k)) (Nat.le_mul_of_pos_right _ hp)
    omega

/-- One state transition at period boundary `h` (versionbits.cpp:83-124).
The ORDER of the two tests in the STARTED case is load-bearing: the count
test (:93) precedes the timeout test (:95), so the period ending exactly
at the timeout still locks in — the 2017 BIP9 erratum, BLK-077. -/
@[rule "INV-121"] def bip9Transition (P : Bip9Params) : ThresholdState → Nat → ThresholdState
  | .defined, h => if P.start ≤ h then .started else .defined
  | .started, h =>
      if P.threshold ≤ P.count h then .lockedIn
      else if bip9Deadline P ≤ h then .failed
      else .started
  | .lockedIn, h => if h + 1 ≥ P.minActivation then .active else .lockedIn
  | .active, _ => .active
  | .failed, _ => .failed

/-- The state machine by confirmation-period index: state at boundary
`k` = `bip9BoundaryHeight P k`.  Genesis / pre-start boundaries are
DEFINED (versionbits.cpp:57-63: null parent ⇒ DEFINED; `mtp < start` ⇒
DEFINED, assigned WITHOUT a transition, exactly as the cache walk does).
Structural recursion — the machine is total by construction. -/
def bip9StateByPeriod (P : Bip9Params) : Nat → ThresholdState
  | 0 =>
      if bip9BoundaryHeight P 0 < P.start then .defined
      else bip9Transition P .defined (bip9BoundaryHeight P 0)
  | k + 1 =>
      if bip9BoundaryHeight P (k + 1) < P.start then .defined
      else bip9Transition P (bip9StateByPeriod P k) (bip9BoundaryHeight P (k + 1))

/-- BIP9 state at chain height `h`: the state at the last period boundary
`≤ h` (versionbits.cpp:49-51: a block's state is always that of the first
block of its period, computed at the aligned ancestor).  Heights before
the first full period are DEFINED (null-ancestor base,
versionbits.cpp:57-60).  Total for every `h` and every `P` (the
`period = 0` degenerate guard makes the alignment division safe). -/
def bip9State (P : Bip9Params) (h : Nat) : ThresholdState :=
  if P.period = 0 then .defined
  else if h + 1 < P.period then .defined
  else bip9StateByPeriod P ((h + 1) / P.period - 1)

theorem bip9State_pre (P : Bip9Params) (h : Nat) (hk : h + 1 < P.period) :
    bip9State P h = .defined := by
  have hP0 : P.period ≠ 0 := by omega
  simp only [bip9State, if_neg hP0, if_pos hk]

@[rule "INV-126"] theorem bip9State_eq (P : Bip9Params) (hP0 : P.period ≠ 0)
    (h : Nat) (hk : P.period ≤ h + 1) :
    bip9State P h = bip9StateByPeriod P ((h + 1) / P.period - 1) := by
  simp only [bip9State, if_neg hP0, if_neg (by omega : ¬ (h + 1 < P.period))]

private theorem div_add_period (n p : Nat) (hp : 0 < p) : (n + p) / p = n / p + 1 := by
  have h1 : n + p = n + p * 1 := by simp
  rw [h1, Nat.add_mul_div_left _ _ hp]

/-- BLK-074: the aligned `pindexPrev` at which Core evaluates the BIP9
machine for a block at height `h` — the last confirmation-period boundary
at or below `h`, i.e. the unique height `b` with `(b+1) % period = 0` and
`b ≤ h < b + period`.  (`versionbits.cpp:46-52` walks `pindexPrev` back
to the block with `(nHeight + 1) % nPeriod == 0`.) -/
def bip9AlignedHeight (P : Bip9Params) (h : Nat) : Nat :=
  ((h + 1) / P.period) * P.period - 1

/-- BLK-074 (period-scoped evaluation): for every height `h` at or after
the first full confirmation period, the BIP9 state is the state at the
aligned `pindexPrev` `bip9AlignedHeight P h`, that node satisfies
`(b+1) % period = 0`, lies at or below `h` and within one period of it,
and the state is constant over the whole period `[b, b + period)`.

This is the `GetStateFor` evaluation rule the audit found missing: the
machine is evaluated once per period at `pindexPrev`, not per block. -/
@[rule "BLK-074"] theorem bip9State_period_aligned (P : Bip9Params)
    (hP : 0 < P.period) (h : Nat) (hk : P.period ≤ h + 1) :
    let b := bip9AlignedHeight P h
    bip9State P h = bip9State P b ∧
    (b + 1) % P.period = 0 ∧
    b ≤ h ∧ h < b + P.period ∧
    (∀ h', b ≤ h' → h' < b + P.period → bip9State P h' = bip9State P h) := by
  have hP0 : P.period ≠ 0 := by omega
  have hqpos : 0 < (h + 1) / P.period := Nat.div_pos hk hP
  have hq1 : 1 ≤ (h + 1) / P.period := hqpos
  have hqp1 : 1 ≤ ((h + 1) / P.period) * P.period := by
    have h := Nat.mul_le_mul hq1 (Nat.succ_le_of_lt hP)
    simpa using h
  -- `b + 1 = q * period` for `q = (h+1)/period`
  have hb1 : bip9AlignedHeight P h + 1 = ((h + 1) / P.period) * P.period := by
    unfold bip9AlignedHeight
    exact Nat.sub_add_cancel hqp1
  -- `b ≤ h`
  have hble : bip9AlignedHeight P h ≤ h := by
    unfold bip9AlignedHeight
    have hqp_le : ((h + 1) / P.period) * P.period ≤ h + 1 :=
      Nat.div_mul_le_self (h + 1) P.period
    omega
  -- `h < b + period`
  have hltq : h + 1 < (((h + 1) / P.period) + 1) * P.period := by
    have hlt : (h + 1) / P.period < (h + 1) / P.period + 1 :=
      Nat.lt_succ_self _
    exact (Nat.div_lt_iff_lt_mul hP).mp hlt
  have hltb : h < bip9AlignedHeight P h + P.period := by
    unfold bip9AlignedHeight
    have hsplit : (((h + 1) / P.period) + 1) * P.period
        = ((h + 1) / P.period) * P.period + P.period := by
      rw [Nat.add_mul, Nat.one_mul]
    omega
  -- state at `h` and at `b` are both the state at period index `q - 1`
  have hstate_h : bip9State P h
      = bip9StateByPeriod P ((h + 1) / P.period - 1) :=
    bip9State_eq P hP0 h hk
  have hstate_b : bip9State P (bip9AlignedHeight P h)
      = bip9StateByPeriod P ((h + 1) / P.period - 1) := by
    have hkb : P.period ≤ bip9AlignedHeight P h + 1 := by
      rw [hb1]
      exact Nat.le_mul_of_pos_left P.period hqpos
    rw [bip9State_eq P hP0 (bip9AlignedHeight P h) hkb, hb1,
      Nat.mul_div_left ((h + 1) / P.period) hP]
  refine ⟨hstate_h.trans hstate_b.symm, ?_, hble, hltb, ?_⟩
  · rw [hb1]
    exact Nat.mul_mod_left ((h + 1) / P.period) P.period
  · intro h' hle hlt
    have hdiv : (h' + 1) / P.period = (h + 1) / P.period := by
      apply Nat.div_eq_of_lt_le
      · omega
      · have hsplit : (((h + 1) / P.period) + 1) * P.period
            = ((h + 1) / P.period) * P.period + P.period := by
          rw [Nat.add_mul, Nat.one_mul]
        unfold bip9AlignedHeight at hlt
        omega
    rw [hstate_h]
    rw [bip9State_eq P hP0 h' (by
      have hb : bip9AlignedHeight P h < h' + 1 := by omega
      unfold bip9AlignedHeight at hb
      have hp_le : P.period ≤ ((h + 1) / P.period) * P.period :=
        Nat.le_mul_of_pos_left P.period hqpos
      omega)]
    rw [hdiv]

/-- BLK-074: the state at `h + period` is one transition applied to the
state at `h`, evaluated at the boundary `k = (h+1)/period` closing h's
period (versionbits.cpp:49-52 + 83-124).  This is the machine's only
recursion step; everything else is period-alignment bookkeeping. -/
@[rule "BLK-074"] theorem bip9State_next_period (P : Bip9Params) (hP : 0 < P.period)
    (h : Nat) (hk : P.period ≤ h + 1) :
    bip9State P (h + P.period) =
      if bip9BoundaryHeight P ((h + 1) / P.period) < P.start then .defined
      else bip9Transition P (bip9State P h) (bip9BoundaryHeight P ((h + 1) / P.period)) := by
  have hP0 : P.period ≠ 0 := by omega
  have hassoc : h + P.period + 1 = h + 1 + P.period := by omega
  have hdiv : (h + 1 + P.period) / P.period = (h + 1) / P.period + 1 :=
    div_add_period (h + 1) P.period hP
  rw [bip9State_eq P hP0 (h + P.period) (by omega), hassoc, hdiv, Nat.add_sub_cancel,
    bip9State_eq P hP0 h hk]
  obtain ⟨k, hk2⟩ : ∃ k, (h + 1) / P.period = k + 1 :=
    ⟨(h + 1) / P.period - 1, by
      have hpos : 0 < (h + 1) / P.period := Nat.div_pos hk hP
      omega⟩
  rw [hk2]
  rfl

/-- A LOCKED_IN boundary is at/after the deployment start: the pre-start
walk-back (versionbits.cpp:60-63) assigns DEFINED without a transition,
so a locked-in state can only arise in the post-start branch. -/
theorem bip9StateByPeriod_lockIn_atStart (P : Bip9Params) (k : Nat)
    (hl : bip9StateByPeriod P k = .lockedIn) :
    ¬ (bip9BoundaryHeight P k < P.start) := by
  cases k with
  | zero =>
    simp only [bip9StateByPeriod] at hl
    by_cases hb : bip9BoundaryHeight P 0 < P.start
    · rw [if_pos hb] at hl; exact absurd hl (by simp)
    · exact hb
  | succ k' =>
    simp only [bip9StateByPeriod] at hl
    by_cases hb : bip9BoundaryHeight P (k' + 1) < P.start
    · rw [if_pos hb] at hl; exact absurd hl (by simp)
    · exact hb

/-- Machine-level content of the lock-in-survives-timeout lemma: once
LOCKED_IN (with `min_activation_height = 0`, the value of every mainnet
deployment), the deployment is ACTIVE from the next period on and stays
ACTIVE.  The timeout plays no role — in Core the LOCKED_IN→ACTIVE
transition (versionbits.cpp:100-104) never consults it. -/
theorem lockin_then_active (P : Bip9Params) (h : Nat)
    (hP : 0 < P.period) (hmin : P.minActivation = 0)
    (hlocked : bip9State P h = .lockedIn) :
    bip9State P (h + P.period + P.period) = .active := by
  have hP0 : P.period ≠ 0 := by omega
  have hk : P.period ≤ h + 1 := by
    by_cases hc : P.period ≤ h + 1
    · exact hc
    · rw [bip9State_pre P h (by omega)] at hlocked
      exact absurd hlocked (by simp)
  have hk1 : 0 < (h + 1) / P.period := Nat.div_pos hk hP
  have e1' : bip9StateByPeriod P ((h + 1) / P.period - 1) = .lockedIn := by
    rw [← bip9State_eq P hP0 h hk]; exact hlocked
  have hbstart : ¬ (bip9BoundaryHeight P ((h + 1) / P.period) < P.start) := by
    have hnb := bip9StateByPeriod_lockIn_atStart P ((h + 1) / P.period - 1) e1'
    have hmono := bip9BoundaryHeight_succ P ((h + 1) / P.period - 1)
    rw [show ((h + 1) / P.period - 1) + 1 = (h + 1) / P.period from by omega] at hmono
    omega
  -- step 1: one period after lock-in ⇒ ACTIVE
  have s1 : bip9State P (h + P.period) = .active := by
    rw [bip9State_next_period P hP h hk, if_neg hbstart, hlocked]
    simp only [bip9Transition]
    rw [if_pos (by omega : bip9BoundaryHeight P ((h + 1) / P.period) + 1 ≥ P.minActivation)]
  -- step 2: two periods after lock-in ⇒ ACTIVE
  have hk2 : P.period ≤ h + P.period + 1 := by omega
  have hdiv2 : (h + P.period + 1) / P.period = (h + 1) / P.period + 1 := by
    have e : h + P.period + 1 = h + 1 + P.period := by omega
    rw [e, div_add_period (h + 1) P.period hP]
  have hb2 : ¬ (bip9BoundaryHeight P ((h + 1) / P.period + 1) < P.start) := by
    have hmono : bip9BoundaryHeight P ((h + 1) / P.period + 1)
        = bip9BoundaryHeight P ((h + 1) / P.period) + P.period := by
      exact bip9BoundaryHeight_succ P _
    rw [hmono]; omega
  rw [bip9State_next_period P hP (h + P.period) hk2, hdiv2, if_neg hb2, s1]
  rfl

/-- Core-faithful wrapper (versionbits.cpp:37-52): sentinel start times
short-circuit (ALWAYS_ACTIVE ⇒ ACTIVE at :37-39, NEVER_ACTIVE ⇒ FAILED at
:40-42), otherwise the height-abstraction machine.  `count` is indexed by
boundary height and converted through UInt32 — sound because boundary
heights of a queried UInt32 height are < 2³². -/
def thresholdState (start timeout : UInt32) (threshold period : Nat)
    (count : UInt32 → UInt32) (h : UInt32) : ThresholdState :=
  if start = BIP9_ALWAYS_ACTIVE then .active
  else if start = BIP9_NEVER_ACTIVE then .failed
  else
    bip9State
      { start := start.toNat, timeoutPeriods := timeout.toNat
        threshold := threshold, period := period, minActivation := 0
        count := fun A => (count A.toUInt32).toNat }
      h.toNat

/-- BLK-079: ALWAYS_ACTIVE start ⇒ ACTIVE for every height, no state
machine (versionbits.cpp:37-39). -/
theorem bip9_always_active (timeout : UInt32) (threshold period : Nat)
    (count : UInt32 → UInt32) (h : UInt32) :
    thresholdState BIP9_ALWAYS_ACTIVE timeout threshold period count h = .active := by
  unfold thresholdState
  rw [if_pos (rfl : BIP9_ALWAYS_ACTIVE = BIP9_ALWAYS_ACTIVE)]

/-- BLK-079: NEVER_ACTIVE start ⇒ FAILED for every height, no state
machine (versionbits.cpp:40-42). -/
@[rule "BLK-079"] theorem bip9_never_active (timeout : UInt32) (threshold period : Nat)
    (count : UInt32 → UInt32) (h : UInt32) :
    thresholdState BIP9_NEVER_ACTIVE timeout threshold period count h = .failed := by
  unfold thresholdState
  rw [if_neg (by decide : ¬ (BIP9_NEVER_ACTIVE = BIP9_ALWAYS_ACTIVE)),
      if_pos (rfl : BIP9_NEVER_ACTIVE = BIP9_NEVER_ACTIVE)]

private theorem u32_toNat_add_lt (a b : UInt32) (h : a.toNat + b.toNat < 4294967296) :
    (a + b).toNat = a.toNat + b.toNat := by
  have h32 : (2 : Nat) ^ 32 = 4294967296 := by decide
  rw [UInt32.toNat_add, Nat.mod_eq_of_lt (by omega)]

/-- Lock-in-on-timeout ordering lemma (the frozen statement, with the
no-overflow hypothesis added per interface-change note 7): once a
deployment is LOCKED_IN, it is ACTIVE one period later and stays there,
regardless of the timeout — `hto` records that the deadline has even
passed by `h + period`, yet activation happens anyway (in Core the
LOCKED_IN→ACTIVE transition at versionbits.cpp:100-104 never consults
the timeout).  NOTE `hto` is deliberately not needed by the proof: with
`min_activation_height = 0` (every mainnet deployment), LOCKED_IN ⇒
ACTIVE unconditionally; the load-bearing timeout ordering (count test
before timeout test) is the sharper `Bip9.count_beats_timeout`. -/
theorem lockin_survives_timeout (start timeout : UInt32) (threshold : Nat)
    (period : UInt32) (count : UInt32 → UInt32) (h : UInt32)
    (hlocked : thresholdState start timeout threshold period.toNat count h = .lockedIn)
    (_hto : start + timeout * period ≤ h + period)
    (hno : h.toNat + period.toNat + period.toNat < 4294967296) :
    thresholdState start timeout threshold period.toNat count (h + period + period)
      = .active := by
  unfold thresholdState at hlocked ⊢
  by_cases hsa : start = BIP9_ALWAYS_ACTIVE
  · rw [if_pos hsa] at hlocked; exact absurd hlocked (by decide)
  by_cases hsn : start = BIP9_NEVER_ACTIVE
  · rw [if_pos hsn, if_neg hsa] at hlocked; exact absurd hlocked (by decide)
  rw [if_neg hsa, if_neg hsn] at hlocked ⊢
  have hc1 : (h + period).toNat = h.toNat + period.toNat :=
    u32_toNat_add_lt h period (by omega)
  have hc2 : (h + period + period).toNat = h.toNat + period.toNat + period.toNat := by
    have step : (h + period + period).toNat = (h + period).toNat + period.toNat :=
      u32_toNat_add_lt (h + period) period (by omega)
    rw [step, hc1]
  rcases Nat.eq_zero_or_pos period.toNat with h0 | hpos
  · rw [h0] at hlocked
    simp [bip9State] at hlocked
  · rw [hc2]
    exact lockin_then_active
      { start := start.toNat, timeoutPeriods := timeout.toNat, threshold := threshold,
        period := period.toNat, minActivation := 0,
        count := fun A => (count A.toUInt32).toNat }
      h.toNat hpos rfl hlocked

end Bitcoin.Activation
