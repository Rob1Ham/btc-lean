import Bitcoin.Chain.Basic
import Bitcoin.RuleAttr

/-!
# Bitcoin.Block.Pow — retarget machinery (X08: BLK-040..055, 056..058)

Faithful ports of Core `pow.cpp @cce32b168` over the minimal index surface
the retarget formulas actually read (per-height `bits`/`time` of the
candidate's ancestors — the `CBlockIndex::GetAncestor` spine):

* `PowParams` — the `Consensus::Params` PoW fields;
  `difficultyAdjustmentInterval` = T / spacing **derived**, exactly Core's
  inline method (BLK-043's 2016 = 1209600/600).
* `getCompact` — `arith_uint256::GetCompact` (the re-encode arm of
  BLK-046 and the round-trip inside BLK-050's boundary bounds).
* `nextWorkRequired` — `GetNextWorkRequired` (BLK-042/043): retarget iff
  the NEW height is a multiple of the interval, else copy `pindexLast`'s
  nBits; testnet min-difficulty branch (BLK-053/054 walk-back).
* `calculateNextWorkRequired` (BLK-044/045/046/047/048/049): timespan
  window = last-block-time − first-of-window time (BLK-044), clamped to
  [T/4, 4T] (BLK-045), new = base·clamped/T truncated (BLK-046), base =
  first-of-period bits iff BIP94 (BLK-047), capped at powLimit (BLK-048),
  copied wholesale under `fPowNoRetargeting` (BLK-049).
* `permittedDifficultyTransition` (BLK-050/051/052): boundary bounds are
  the clamp-endpoint targets capped, `GetCompact`-round-tripped, and
  compared against the observed decode; non-boundary ⇒ bits constant;
  min-difficulty chains always permitted.
* `medianTimePast` (BLK-056) + the `time-too-old` (BLK-057) and
  `time-too-new` (BLK-058, 2 h window) gates.

The decode arm is `Bitcoin.Chain.compactTarget` (W17 BLK-037); every
function is total — missing ancestors give `none` (Core asserts there).
-/

namespace Bitcoin.Block.Pow

open Bitcoin.Chain

/-! ## Parameters (consensus/params.h, the PoW block) -/

structure PowParams where
  /-- `powLimit` as a plain Nat (the 256-bit target magnitude). -/
  powLimit : Nat
  /-- `nPowTargetTimespan` — 1209600 s (2 weeks) on every net. -/
  powTargetTimespan : Nat := 1209600
  /-- `nPowTargetSpacing` — 600 s. -/
  powTargetSpacing : Nat := 600
  /-- regtest. -/
  fPowNoRetargeting : Bool := false
  /-- testnet3/testnet4/regtest. -/
  fPowAllowMinDifficultyBlocks : Bool := false
  /-- testnet4 only (BIP94). -/
  enforceBIP94 : Bool := false

/-- Core's inline `DifficultyAdjustmentInterval()` = T / spacing —
**derived**, so BLK-043's 2016 is 1209600/600, not a stored constant. -/
def difficultyAdjustmentInterval (P : PowParams) : Nat :=
  P.powTargetTimespan / P.powTargetSpacing

/-- **BLK-040**: mainnet AND testnet3/testnet4 `powLimit`
(chainparams.cpp:109/263 — the same 0x00000000ffff… constant). -/
@[rule "BLK-040"]
def powLimitMainnet : Nat :=
  0x00000000FFFF0000000000000000000000000000000000000000000000000000

theorem powLimitMainnet_eq : powLimitMainnet = 0xffff * 256 ^ 26 := by
  decide

/-- **BLK-041**: signet `powLimit` (chainparams.cpp:654-ish:
0x00000377ae0000…). -/
@[rule "BLK-041"]
def powLimitSignet : Nat :=
  0x00000377AE000000000000000000000000000000000000000000000000000000

/-- **BLK-041**: regtest `powLimit` = 0x7fffff… (chainparams.cpp:530-ish). -/
def powLimitRegtest : Nat :=
  0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

/-- Mainnet/testnet parameter instance. -/
def mainnetParams : PowParams :=
  { powLimit := powLimitMainnet }

/-- regtest instance (BLK-049's `fPowNoRetargeting`). -/
def regtestParams : PowParams :=
  { powLimit := powLimitRegtest, fPowNoRetargeting := true,
    fPowAllowMinDifficultyBlocks := true }

/-! ## The index surface

`CBlockIndex` truncated to the retarget/MTP-visible fields, accessed by
height (Core's `GetAncestor`). -/
structure IndexNode where
  bits : UInt32
  time : UInt32

/-! ## `arith_uint256::GetCompact` -/

/-- Bit length (`arith_uint256::bits()`); 0 for 0. -/
def bitLen : Nat → Nat
  | 0 => 0
  | t+1 => Nat.log2 (t+1) + 1

/-- `arith_uint256::GetCompact(false)` (arith_uint256.cpp:26-52):
byte count, low-3-byte mantissa, high-bit shift-up-then-size bump,
`size << 24`. Consensus targets (< 2^256) never hit the asserts. -/
def getCompact (t : Nat) : UInt32 :=
  let nSize := bitLen t
  let nSize := (nSize + 7) / 8
  let low := if nSize ≤ 3 then (t % 0x10000000000000000) * 256 ^ (3 - nSize)
             else (t / 256 ^ (nSize - 3)) % 0x10000000000000000
  let (m, sz) := if low &&& 0x00800000 ≠ 0 then (low >>> 8, nSize + 1) else (low, nSize)
  (((m &&& 0x007fffff) ||| (sz <<< 24)) : Nat).toUInt32

/-! ## GetNextWorkRequired / CalculateNextWorkRequired -/

/-- **BLK-044/045/046/047/048/049**: `CalculateNextWorkRequired`
(pow.cpp:62-84). `lastBits`/`lastTime` = `pindexLast`; `firstTime` =
`pindexFirst->GetBlockTime()` where pindexFirst is the block
`interval−1` below the last (BLK-044's window anchor); `firstBits` =
the first-of-period bits, used **iff** BIP94 (BLK-047). -/
@[rule "BLK-044", rule "BLK-045", rule "BLK-046", rule "BLK-047", rule "BLK-048", rule "BLK-049", rule "INV-097",
  rule "INV-139"]
def calculateNextWorkRequired (P : PowParams)
    (lastBits lastTime firstTime firstBits : UInt32) : UInt32 :=
  if P.fPowNoRetargeting then lastBits
  else
    -- BLK-045: clamp the observed timespan to [T/4, 4T].
    let raw : Int := lastTime.toNat - firstTime.toNat
    let actual : Int :=
      if raw < ((P.powTargetTimespan / 4 : Nat) : Int) then ((P.powTargetTimespan / 4 : Nat) : Int)
      else if raw > ((P.powTargetTimespan * 4 : Nat) : Int) then ((P.powTargetTimespan * 4 : Nat) : Int)
      else raw
    -- BLK-047: BIP94 retargets from the FIRST block of the period.
    let base := if P.enforceBIP94 then compactTarget firstBits else compactTarget lastBits
    -- BLK-046: scale and truncate.
    let newT := base * actual.toNat / P.powTargetTimespan
    -- BLK-048: cap at powLimit, then re-encode (GetCompact).
    getCompact (min newT P.powLimit)

/-- The testnet walk-back (BLK-054): the last ancestor whose nBits is not
(min-difficulty AND non-boundary); Core's `while` loop as a recursion.
`h` is the height currently examined; the step requires `h`'s own parent
to exist in the map (Core's `pindex->pprev` guard). -/
@[rule "BLK-054"]
def minDiffWalkBack (P : PowParams) (get : Nat → Option IndexNode) :
    Nat → Option UInt32
  | 0 => (get 0).map (·.bits)
  | h+1 =>
    match get (h+1) with
    | none => none
    | some idx =>
      if (h+1) % difficultyAdjustmentInterval P != 0
          && idx.bits == getCompact P.powLimit
          && (get h).isSome then
        minDiffWalkBack P get h
      else some idx.bits

/-- **BLK-042/043/053/054**: `GetNextWorkRequired` (pow.cpp:20-59).
`get lastHeight` must resolve (Core asserts); retarget iff the new
height is a period boundary, else copy — with the testnet
min-difficulty exception between. -/
@[rule "BLK-042", rule "BLK-043", rule "BLK-053"]
def nextWorkRequired (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) : Option UInt32 :=
  match get lastHeight with
  | none => none
  | some last =>
    let height := lastHeight + 1
    if height % difficultyAdjustmentInterval P != 0 then
      if P.fPowAllowMinDifficultyBlocks then
        -- BLK-053: > 2× spacing slow ⇒ MUST be min-difficulty.
        if newTime.toNat > last.time.toNat + P.powTargetSpacing * 2 then
          some (getCompact P.powLimit)
        else minDiffWalkBack P get lastHeight   -- BLK-054
      else some last.bits
    else
      -- BLK-044: the window anchor is `interval−1` below the last.
      match get (lastHeight - (difficultyAdjustmentInterval P - 1)) with
      | none => none
      | some first =>
        some (calculateNextWorkRequired P last.bits last.time first.time first.bits)

/-! ## Permitted difficulty transitions -/

/-- **BLK-050/051/052**: `PermittedDifficultyTransition` (pow.cpp:93-134).
Boundary: observed decode ∈ [min_rounded, max_rounded] where the bounds
are the clamp-endpoint targets (×T/4, ×4T, truncated), capped at
powLimit, and GetCompact-round-tripped. Non-boundary: bits constant. -/
@[rule "BLK-050", rule "BLK-051", rule "BLK-052", rule "INV-098"]
def permittedDifficultyTransition (P : PowParams) (height : Nat)
    (oldBits newBits : UInt32) : Bool :=
  if P.fPowAllowMinDifficultyBlocks then true
  else if height % difficultyAdjustmentInterval P == 0 then
    let observed := compactTarget newBits
    -- largest reachable target (timespan ×4)
    let largest0 := compactTarget oldBits * (P.powTargetTimespan * 4) / P.powTargetTimespan
    let largest := min largest0 P.powLimit
    let maximumNew := compactTarget (getCompact largest)
    -- smallest reachable target (timespan /4)
    let smallest0 := compactTarget oldBits * (P.powTargetTimespan / 4) / P.powTargetTimespan
    let smallest := min smallest0 P.powLimit
    let minimumNew := compactTarget (getCompact smallest)
    maximumNew ≥ observed && minimumNew ≤ observed
  else oldBits == newBits

/-- **BLK-055** (BIP94 timewarp guard, validation.cpp:4103-4113, chain
param `enforce_BIP94`): on a period boundary the block's time must be at
least the previous block's time minus one target spacing (`time-timewarp-attack`;
testnet4/regtest only). -/
@[rule "BLK-055", rule "INV-100"]
def timewarpOk (enforce atBoundary : Bool) (blockTime prevTime : UInt32) : Bool :=
  !enforce || !atBoundary || (blockTime.toNat + 600 ≥ prevTime.toNat)

/-! ## Median time past + header time gates -/

private def insertSortedBy (le : α → α → Bool) (x : α) : List α → List α
  | [] => [x]
  | a :: r => if le x a then x :: a :: r else a :: insertSortedBy le x r

private def sortBy (le : α → α → Bool) : List α → List α
  | [] => []
  | a :: r => insertSortedBy le a (sortBy le r)

/-- **BLK-056**: `CBlockIndex::GetMedianTimePast` (chain.h:233-244) —
the median of the last ≤11 block times **including** the index itself
(= the block's own time; "self excluded" refers to the validation-side
convention `MTP(prev)`), sorted, middle element `(n−1)/2`. Missing
heights are skipped (Core walks a connected chain; the map model may
have holes). -/
@[rule "BLK-056"]
def medianTimePast (get : Nat → Option UInt32) (h : Nat) : Option UInt32 :=
  let times : List UInt32 :=
    (List.range 11).filterMap (fun i => if h ≥ i then get (h - i) else none)
  match times with
  | [] => none
  | _ => some ((sortBy (fun a b => a.toNat ≤ b.toNat) times).getD ((times.length - 1) / 2) 0)

/-- **BLK-057** (`time-too-old`): a block's time must be STRICTLY above
the parent's MTP (`block.GetBlockTime() <= pindexPrev->GetMedianTimePast()`
rejects). -/
@[rule "BLK-057", rule "INV-099"]
def timeNotTooOld (blockTime mtp : UInt32) : Bool := blockTime > mtp

/-- **BLK-058** (`time-too-new`): at most 2 h into the future —
`blockTime ≤ node-now + 7200`. -/
@[rule "BLK-058", rule "INV-101"]
def timeNotTooNew (blockTime now : UInt32) : Bool :=
  blockTime.toNat ≤ now.toNat + 7200

end Bitcoin.Block.Pow
