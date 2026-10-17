import Bitcoin.RuleAttr
import Bitcoin.Data.Tx
import Bitcoin.Consensus.TxCheck
import Bitcoin.Capstone.Merkle
import Bitcoin.Crypto.Seam.Hash
import Bitcoin.Block.Pow

/-!
# Bitcoin.Invariants.RC08 — INV-085..INV-096 closure (RC08)

Block-level acceptance-spine invariant rows of `research/05-core-inventory.md`
Appendix B §B.7/§B.8 (`validation.cpp::CheckBlock` / `ContextualCheckBlock`,
`pow.cpp` @ `cce32b168`), ported against the existing stable defs:

* `checkBlockTxs` — **INV-085** (`validation.cpp:3967-3976`): `CheckBlock`
  runs `CheckTransaction` on EVERY tx, including the coinbase, with the
  duplicate-input scan (CVE-2018-17144) that `checkTransaction` carries.
* `signetBlockOk` — **INV-086** (`validation.cpp:3939`, BIP325): the signet
  solution check runs only where `signet_blocks` is set (and POW is being
  checked); the deep solution script is abstracted over the script engine.
* `witnessCommitmentMatch` — **INV-090** (`validation.cpp:3898-3906`,
  BIP141): `SHA256d(witness_root ‖ reserved)` must equal
  `scriptPubKey[6..38]`, with the ACTUAL coinbase reserved value; the
  general digest/accept-reject faces are `witnessCommitmentMatch_digest`
  and `witnessCommitmentMatch_iff`. Reduces to X05's
  `witnessCommitmentOk` (BLK-017) when the reserved value is the 32-byte
  zero.
* `blockBitsOk` — **INV-094** (`validation.cpp:4096-4097`): the header nBits
  must equal `GetNextWorkRequired(prev)` (`bad-diffbits`), wrapped over
  X08's `Bitcoin.Block.Pow.nextWorkRequired`.
* `atRetargetBoundary` / `retargetOnlyAtBoundary` — **INV-095**
  (`pow.cpp:20-39`): retargeting happens only at period boundaries; a
  mid-period block must copy the previous block's nBits.
* `clampedTimespan` — **INV-096** (`pow.cpp:57-60`): the observed timespan
  is clamped to `[T/4, 4·T]`; bounds + window-identity theorems.

Vectors: `decide`-pinned block cases (INV-085/086/090) cross-checked by the
python3 mirror in `spec/db/findings-rc/RC08.md` §Vectors; `#eval` pins for
the retarget arithmetic (INV-094/095/096) likewise python-mirrored.
-/

namespace Bitcoin.Invariants.RC08

open Bitcoin.Data Bitcoin.Consensus Bitcoin.Block.Pow Bitcoin.Capstone.Merkle
open Bitcoin.Crypto.Seam.Hash

private def bytes8 (l : List UInt8) : ByteArray := l.foldl (·.push ·) ByteArray.empty

/-! ## INV-085: `CheckTransaction` for every tx in the block -/

/-- **INV-085** (`validation.cpp:3967-3976`): `CheckBlock`'s per-transaction
loop — `CheckTransaction(*tx)` for EVERY tx of the block (first failure
wins, exactly Core's early return), which includes the duplicate-input
scan (`bad-txns-inputs-duplicate`, CVE-2018-17144) inside
`Bitcoin.Consensus.checkTransaction`. -/
@[rule "INV-085"]
def checkBlockTxs : List Tx → Option TxCheckError
  | [] => none
  | t :: rest =>
      match checkTransaction t with
      | some e => some e
      | none => checkBlockTxs rest

/-- The block gate passes iff every transaction passes its own gate. -/
theorem checkBlockTxs_none_iff (txs : List Tx) :
    checkBlockTxs txs = none ↔ ∀ t ∈ txs, checkTransaction t = none := by
  induction txs with
  | nil => simp [checkBlockTxs]
  | cons t rest ih =>
      simp only [checkBlockTxs, List.mem_cons, forall_eq_or_imp]
      cases h : checkTransaction t <;> simp [h, ih]

/-- A well-formed coinbase used by the decide-pinned vectors
(4-byte scriptSig, one 50 BTC output, null prevout). -/
def cbOk : Tx :=
  { version := 1
    vin := [{ prevout := OutPoint.null
              scriptSig := ⟨bytes8 [0x01, 0x02, 0x03, 0x04]⟩
              sequence := 0xFFFFFFFF }]
    vout := [{ value := 5000000000, scriptPubKey := ⟨serU8 0x51⟩ }]
    locktime := 0
    witness := [] }

/-- A non-coinbase tx with two IDENTICAL prevouts — the CVE-2018-17144
duplicate-input instance the block loop must catch. -/
def dupTx : Tx :=
  { version := 1
    vin := [{ prevout := ⟨zeroBytes 32, 0⟩, scriptSig := Script.empty, sequence := 0xFFFFFFFF },
            { prevout := ⟨zeroBytes 32, 0⟩, scriptSig := Script.empty, sequence := 0xFFFFFFFF }]
    vout := [{ value := 1000, scriptPubKey := ⟨serU8 0x51⟩ }]
    locktime := 0
    witness := [] }

/-- A tx with an empty vin — `bad-txns-vin-empty`. -/
def badVinTx : Tx :=
  { version := 1, vin := [], vout := [{ value := 1000, scriptPubKey := ⟨serU8 0x51⟩ }],
    locktime := 0, witness := [] }

/-- Vector (python-mirrored, findings RC08 §V1): the good coinbase alone
passes the block gate. -/
theorem checkBlockTxs_cb_ok : checkBlockTxs [cbOk] = none := by decide

/-- Vector: the duplicate-prevout tx is caught with the exact Core reason. -/
theorem checkBlockTxs_dup : checkBlockTxs [cbOk, dupTx] = some .inputsDuplicate := by decide

/-- Vector: the empty-vin tx is caught with the exact Core reason. -/
theorem checkBlockTxs_badVin : checkBlockTxs [cbOk, badVinTx] = some .vinEmpty := by decide

/-! ## INV-086: signet solution check (param-gated) -/

/-- **INV-086** (`validation.cpp:3939`, BIP325): CheckBlock runs the signet
block-solution check ONLY where `consensus.signet_blocks` is set (and only
when POW is being checked); failure is `bad-signet-blksig`. The deep
solution check (the challenge script spent as a witness) is abstracted
over the script engine, exactly like Core's call into `signet.cpp`. -/
@[rule "INV-086"]
def signetBlockOk (signetBlocks fCheckPOW solutionOk : Bool) : Bool :=
  !(signetBlocks && fCheckPOW) || solutionOk

/-- Mainnet/testnet/testnet4/regtest (`signet_blocks = false`): the check
is skipped, verdict always pass. -/
theorem signetBlockOk_skip (fCheckPOW solutionOk : Bool) :
    signetBlockOk false fCheckPOW solutionOk = true := by
  simp [signetBlockOk]

/-- On signet with POW checked: pass iff the solution validates. -/
theorem signetBlockOk_gate (solutionOk : Bool) :
    (signetBlockOk true true solutionOk = true) ↔ (solutionOk = true) := by
  cases solutionOk <;> simp [signetBlockOk]

/-- Vector (python-mirrored truth table, findings RC08 §V2): the gate. -/
theorem signetBlockOk_table : signetBlockOk true false true = true ∧
    signetBlockOk true false false = true ∧
    signetBlockOk true true false = false ∧
    signetBlockOk false true false = true := by decide

/-! ## INV-090: the witness commitment binds the witness tree -/

/-- **INV-090** (`validation.cpp:3898-3906`, BIP141): with a commitment
present, the coinbase witness must be exactly one 32-byte reserved value
(INV-089) and `SHA256d(witness_merkle_root ‖ reserved)` must equal
`scriptPubKey[6..38]` (`bad-witness-merkle-match`). This is Core's check
with the ACTUAL reserved value; reduces to X05's `witnessCommitmentOk`
(BLK-017) in the zero-reserved special case. -/
@[rule "INV-090"]
def witnessCommitmentMatch (txs : List Tx) (cb : Tx) : Bool :=
  match witnessCommitmentOutput cb with
  | none => false
  | some script =>
      match cb.witness.getD 0 [] with
      | [nonce] =>
          nonce.size = 32 &&
            bytesBEq (sha256d (witnessMerkleRoot txs ++ nonce)) (script.extract 6 38)
      | _ => false

/-- **INV-090 (general reserved value)**: the commitment gate is exactly
Core's digest comparison with the ACTUAL reserved value carried by the
coinbase (`validation.cpp:3905-3906`: `CHash256().Write(hash_witness)
.Write(witness_stack[0]).Finalize(...)` then `memcmp(..., scriptPubKey[6],
32)`). `script = scriptPubKey`, and `nonce = witness_stack[0]`. -/
@[rule "INV-090"]
theorem witnessCommitmentMatch_digest (txs : List Tx) (cb : Tx)
    (script nonce : ByteArray)
    (ho : witnessCommitmentOutput cb = some script)
    (hw : cb.witness.getD 0 [] = [nonce]) (hsz : nonce.size = 32) :
    witnessCommitmentMatch txs cb =
      bytesBEq (sha256d (witnessMerkleRoot txs ++ nonce)) (script.extract 6 38) := by
  unfold witnessCommitmentMatch
  rw [ho, hw]
  simp [hsz]

/-- **INV-090 (accept/reject iff)**: the gate passes iff there is a
commitment output and exactly one 32-byte reserved value whose digest
matches the 32-byte committed value `scriptPubKey[6..38]`. -/
@[rule "INV-090"]
theorem witnessCommitmentMatch_iff (txs : List Tx) (cb : Tx) :
    witnessCommitmentMatch txs cb = true ↔
      ∃ script nonce, witnessCommitmentOutput cb = some script ∧
        cb.witness.getD 0 [] = [nonce] ∧ nonce.size = 32 ∧
        bytesBEq (sha256d (witnessMerkleRoot txs ++ nonce))
          (script.extract 6 38) = true := by
  unfold witnessCommitmentMatch
  cases ho : witnessCommitmentOutput cb with
  | none => simp
  | some script =>
      cases hw : cb.witness.getD 0 [] with
      | nil => simp
      | cons x xs =>
          cases xs with
          | nil => simp [Bool.and_eq_true]
          | cons y ys => simp

/-- **INV-090 (reject)**: a digest mismatch with a correct-shape
commitment and reserved value fails the gate (`bad-witness-merkle-match`). -/
@[rule "INV-090"]
theorem witnessCommitmentMatch_digest_false (txs : List Tx) (cb : Tx)
    (script nonce : ByteArray)
    (ho : witnessCommitmentOutput cb = some script)
    (hw : cb.witness.getD 0 [] = [nonce]) (hsz : nonce.size = 32)
    (hne : bytesBEq (sha256d (witnessMerkleRoot txs ++ nonce))
      (script.extract 6 38) = false) :
    witnessCommitmentMatch txs cb = false := by
  rw [witnessCommitmentMatch_digest txs cb script nonce ho hw hsz]
  exact hne

/-- Agreement with the shipped BLK-017 def: a 32-byte-zero reserved value
is exactly the special case `witnessCommitmentOk` models. -/
@[rule "INV-090"]
theorem witnessCommitmentMatch_zeroNonce (txs : List Tx) (cb : Tx)
    (h : cb.witness.getD 0 [] = [zeroBytes 32]) :
    witnessCommitmentMatch txs cb = witnessCommitmentOk txs cb := by
  have h32 : (zeroBytes 32).size = 32 := by decide
  unfold witnessCommitmentMatch witnessCommitmentOk
  rw [h]
  cases ho : witnessCommitmentOutput cb <;> simp [ho, h32]

/-- A wrong-size reserved value fails the malleation check outright
(`bad-witness-nonce-size`, INV-089's precondition). -/
theorem witnessCommitmentMatch_badNonceSize (txs : List Tx) (cb : Tx)
    (h : cb.witness.getD 0 [] = [zeroBytes 31]) :
    witnessCommitmentMatch txs cb = false := by
  have h31 : (zeroBytes 31).size = 31 := by decide
  unfold witnessCommitmentMatch
  rw [h]
  cases ho : witnessCommitmentOutput cb <;> simp [ho, h31]

/-! ## INV-094/095/096: difficulty continuity over X08's pow port -/

/-- **INV-094** (`validation.cpp:4096-4097`, `bad-diffbits`): the header's
nBits must equal `GetNextWorkRequired(pindexPrev, &block, params)`. -/
@[rule "INV-094"]
def blockBitsOk (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime bits : UInt32) : Bool :=
  nextWorkRequired P get lastHeight newTime == some bits

/-- Mid-period (mainnet shape: no min-difficulty): the required bits ARE
the previous block's bits — the block passes iff its nBits matches. -/
theorem blockBitsOk_midperiod (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hnomin : P.fPowAllowMinDifficultyBlocks = false) :
    blockBitsOk P get lastHeight newTime last.bits = true := by
  unfold blockBitsOk nextWorkRequired
  simp [hget, hnb, hnomin]

/-- Mismatch ⇒ reject (`bad-diffbits`, "incorrect proof of work"). -/
theorem blockBitsOk_badDiffbits (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime bits : UInt32) (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hnomin : P.fPowAllowMinDifficultyBlocks = false)
    (hne : bits ≠ last.bits) :
    blockBitsOk P get lastHeight newTime bits = false := by
  have h1 : nextWorkRequired P get lastHeight newTime = some last.bits := by
    unfold nextWorkRequired
    simp [hget, hnb, hnomin]
  unfold blockBitsOk
  rw [h1]
  exact beq_false_of_ne (fun hc => hne (Option.some.inj hc).symm)

/-- **INV-094 (accept, all branches)**: whatever
`GetNextWorkRequired` returns for the candidate's parent is accepted —
`validation.cpp:4096-4097` compares the header's nBits against that
value. -/
@[rule "INV-094"]
theorem blockBitsOk_required (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime bits : UInt32)
    (h : nextWorkRequired P get lastHeight newTime = some bits) :
    blockBitsOk P get lastHeight newTime bits = true := by
  unfold blockBitsOk
  rw [h]
  simp

/-- **INV-094 (reject, all branches)**: any nBits other than the required
value is rejected (`bad-diffbits`, "incorrect proof of work"). -/
@[rule "INV-094"]
theorem blockBitsOk_reject (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime bits required : UInt32)
    (h : nextWorkRequired P get lastHeight newTime = some required)
    (hne : bits ≠ required) :
    blockBitsOk P get lastHeight newTime bits = false := by
  unfold blockBitsOk
  rw [h]
  exact beq_false_of_ne (fun hc => hne (Option.some.inj hc).symm)

/-- **INV-094 (exact characterization)**: the gate passes iff the header's
nBits is exactly the value `GetNextWorkRequired` returns — Core's
`block.nBits != GetNextWorkRequired(...)` test, both directions. -/
@[rule "INV-094"]
theorem blockBitsOk_iff (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime bits : UInt32) :
    blockBitsOk P get lastHeight newTime bits = true ↔
      nextWorkRequired P get lastHeight newTime = some bits := by
  unfold blockBitsOk
  cases h : nextWorkRequired P get lastHeight newTime with
  | none => simp
  | some required =>
      by_cases hb : bits = required
      · subst hb; simp
      · simp

/-- **INV-094 (min-difficulty, accept)**: with the testnet min-difficulty
rule on, a mid-period block more than 2×spacing after its parent must
carry the pow-limit compact (pow.cpp:22-28) and is accepted. -/
@[rule "INV-094"]
theorem blockBitsOk_minDifficulty (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hmin : P.fPowAllowMinDifficultyBlocks = true)
    (hslow : newTime.toNat > last.time.toNat + P.powTargetSpacing * 2) :
    blockBitsOk P get lastHeight newTime (getCompact P.powLimit) = true := by
  unfold blockBitsOk nextWorkRequired
  simp [hget, hnb, hmin, hslow]

/-- **INV-095**: a height is a retarget boundary iff it is a multiple of
the (derived) difficulty-adjustment interval. -/
@[rule "INV-095"]
def atRetargetBoundary (P : PowParams) (newHeight : Nat) : Bool :=
  newHeight % difficultyAdjustmentInterval P == 0

theorem atRetargetBoundary_def (P : PowParams) (h : Nat) :
    atRetargetBoundary P h = decide (h % difficultyAdjustmentInterval P = 0) := rfl

/-- Mid-period blocks do NOT retarget: `GetNextWorkRequired` returns the
previous block's nBits verbatim (pow.cpp:26-27). -/
theorem retargetOnlyAtBoundary (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hnomin : P.fPowAllowMinDifficultyBlocks = false) :
    nextWorkRequired P get lastHeight newTime = some last.bits := by
  unfold nextWorkRequired
  simp [hget, hnb, hnomin]

/-- At a boundary the new target IS `calculateNextWorkRequired` over the
period window (pow.cpp:33-35). -/
theorem retargetAtBoundary_calculate (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last first : IndexNode)
    (hgetL : get lastHeight = some last)
    (hb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = false)
    (hgetF : get (lastHeight - (difficultyAdjustmentInterval P - 1)) = some first) :
    nextWorkRequired P get lastHeight newTime
      = some (calculateNextWorkRequired P last.bits last.time first.time first.bits) := by
  unfold nextWorkRequired
  simp [hgetL, hb, hgetF]

/-- **INV-094 (period boundary, accept)**: at a boundary the required
nBits is the `CalculateNextWorkRequired` value over the interval window
(pow.cpp:41-47), and the header carrying it is accepted. -/
@[rule "INV-094"]
theorem blockBitsOk_boundary (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last first : IndexNode)
    (hgetL : get lastHeight = some last)
    (hb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = false)
    (hgetF : get (lastHeight - (difficultyAdjustmentInterval P - 1)) = some first) :
    blockBitsOk P get lastHeight newTime
      (calculateNextWorkRequired P last.bits last.time first.time first.bits) = true := by
  unfold blockBitsOk
  rw [retargetAtBoundary_calculate P get lastHeight newTime last first hgetL hb hgetF]
  simp

/-- **INV-094 (period boundary, reject)**: any other nBits at a boundary
is `bad-diffbits`. -/
@[rule "INV-094"]
theorem blockBitsOk_boundary_reject (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime bits : UInt32) (last first : IndexNode)
    (hgetL : get lastHeight = some last)
    (hb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = false)
    (hgetF : get (lastHeight - (difficultyAdjustmentInterval P - 1)) = some first)
    (hne : bits ≠ calculateNextWorkRequired P last.bits last.time first.time first.bits) :
    blockBitsOk P get lastHeight newTime bits = false :=
  blockBitsOk_reject P get lastHeight newTime bits _
    (retargetAtBoundary_calculate P get lastHeight newTime last first hgetL hb hgetF) hne

/-- **INV-095 (mid-period min-difficulty)**: when the testnet rule is on
and the candidate is more than 2×spacing late, `GetNextWorkRequired`
returns the pow-limit compact — the documented mid-period exception to
"retarget only at interval boundaries" (pow.cpp:22-28). -/
@[rule "INV-095"]
theorem retargetMidPeriod_minDifficulty (P : PowParams)
    (get : Nat → Option IndexNode) (lastHeight : Nat) (newTime : UInt32)
    (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hmin : P.fPowAllowMinDifficultyBlocks = true)
    (hslow : newTime.toNat > last.time.toNat + P.powTargetSpacing * 2) :
    nextWorkRequired P get lastHeight newTime = some (getCompact P.powLimit) := by
  unfold nextWorkRequired
  simp [hget, hnb, hmin, hslow]

/-- **INV-095 (mid-period walk-back)**: the non-slow min-difficulty arm
returns `minDiffWalkBack` (Core's last non-min-difficulty ancestor,
pow.cpp:29-36). This can also differ from the immediate parent's nBits. -/
@[rule "INV-095"]
theorem retargetMidPeriod_minDifficulty_walkBack (P : PowParams)
    (get : Nat → Option IndexNode) (lastHeight : Nat) (newTime : UInt32)
    (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hmin : P.fPowAllowMinDifficultyBlocks = true)
    (hnotslow : ¬ newTime.toNat > last.time.toNat + P.powTargetSpacing * 2) :
    nextWorkRequired P get lastHeight newTime = minDiffWalkBack P get lastHeight := by
  unfold nextWorkRequired
  simp [hget, hnb, hmin, hnotslow]

/-- **INV-096** (pow.cpp:57-60): the observed timespan is clamped into
`[T/4, 4·T]` — Core's two-step if/else verbatim. -/
@[rule "INV-096"]
def clampedTimespan (T raw : Int) : Int :=
  if raw < T / 4 then T / 4
  else if raw > T * 4 then T * 4
  else raw

/-- Bounds: `T/4 ≤ clamped ≤ 4·T` (the clamp window is never escaped). -/
theorem clampedTimespan_bounds (T raw : Int) (hT : 0 < T) :
    T / 4 ≤ clampedTimespan T raw ∧ clampedTimespan T raw ≤ T * 4 := by
  unfold clampedTimespan
  by_cases h1 : raw < T / 4
  · simp only [h1, if_true]; omega
  · by_cases h2 : raw > T * 4
    · simp only [h1, h2, if_false, if_true]; omega
    · simp only [h1, h2, if_false]; omega

/-- Inside the window the clamp is the identity. -/
theorem clampedTimespan_window (T raw : Int) (hlo : T / 4 ≤ raw) (hhi : raw ≤ T * 4) :
    clampedTimespan T raw = raw := by
  unfold clampedTimespan
  by_cases h1 : raw < T / 4
  · simp only [h1, if_true]; omega
  · by_cases h2 : raw > T * 4
    · simp only [h1, h2, if_false, if_true]; omega
    · simp only [h1, h2, if_false]

/-! ## Vector pins (python3-mirrored, findings-rc/RC08.md §Vectors) -/

-- V3: commitment digest for the 1-tx block (zero root, zero reserved),
-- python-mirrored in `RC08-vectors.py`.
/-- info: "e2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf9" -/
#guard_msgs in
#eval toHex (sha256d (zeroBytes 32 ++ zeroBytes 32))

-- V4: mainnet mid-period height 1001 ⇒ previous bits `0x1d00ffff`
-- verbatim (python: 0x1d00ffff = 486604799).
/-- info: some 486604799 -/
#guard_msgs in
#eval (nextWorkRequired mainnetParams
  (fun h => if h = 1000 then some ⟨0x1d00ffff, 1279008000⟩ else none) 1000 127900900).map (·.toNat)

-- V4b: mainnet boundary 2015→2016, raw = 2015·600 = 1209000 s ⇒
-- `0x1d00ffde` (python: 486604766).
/-- info: some 486604766 -/
#guard_msgs in
#eval (nextWorkRequired mainnetParams
  (fun h => some ⟨0x1d00ffff, UInt32.ofNat (1279008000 + h * 600)⟩) 2015 1279209600).map (·.toNat)

-- V5: clamp-low raw = 0 ⇒ target = base/4, `0x1c3fffc0` (python: 473956288).
/-- info: 473956288 -/
#guard_msgs in
#eval (calculateNextWorkRequired mainnetParams 0x1d00ffff 1279008000 1279008000
  0x1d00ffff).toNat

-- V5b: clamp-mid raw = T ⇒ base round-trips, `0x1d00ffff` (486604799).
/-- info: 486604799 -/
#guard_msgs in
#eval (calculateNextWorkRequired mainnetParams 0x1d00ffff (1279008000 + 1209600)
  1279008000 0x1d00ffff).toNat

-- V5c: clamp-high raw = 10·T ⇒ 4·base > powLimit ⇒ capped, `0x1d00ffff`.
/-- info: 486604799 -/
#guard_msgs in
#eval (calculateNextWorkRequired mainnetParams 0x1d00ffff (1279008000 + 10 * 1209600)
  1279008000 0x1d00ffff).toNat

/-! ## Axiom pins -/

/-- info: 'Bitcoin.Invariants.RC08.checkBlockTxs_none_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms checkBlockTxs_none_iff
/-- info: 'Bitcoin.Invariants.RC08.checkBlockTxs_cb_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms checkBlockTxs_cb_ok
/-- info: 'Bitcoin.Invariants.RC08.checkBlockTxs_dup' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms checkBlockTxs_dup
/-- info: 'Bitcoin.Invariants.RC08.checkBlockTxs_badVin' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms checkBlockTxs_badVin
/-- info: 'Bitcoin.Invariants.RC08.signetBlockOk_skip' depends on axioms: [propext] -/
#guard_msgs in #print axioms signetBlockOk_skip
/-- info: 'Bitcoin.Invariants.RC08.signetBlockOk_gate' depends on axioms: [propext] -/
#guard_msgs in #print axioms signetBlockOk_gate
/-- info: 'Bitcoin.Invariants.RC08.signetBlockOk_table' does not depend on any axioms -/
#guard_msgs in #print axioms signetBlockOk_table
/-- info: 'Bitcoin.Invariants.RC08.witnessCommitmentMatch_digest' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms witnessCommitmentMatch_digest
/-- info: 'Bitcoin.Invariants.RC08.witnessCommitmentMatch_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms witnessCommitmentMatch_iff
/-- info: 'Bitcoin.Invariants.RC08.witnessCommitmentMatch_digest_false' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms witnessCommitmentMatch_digest_false
/-- info: 'Bitcoin.Invariants.RC08.witnessCommitmentMatch_zeroNonce' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms witnessCommitmentMatch_zeroNonce
/-- info: 'Bitcoin.Invariants.RC08.witnessCommitmentMatch_badNonceSize' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms witnessCommitmentMatch_badNonceSize
/-- info: 'Bitcoin.Invariants.RC08.blockBitsOk_midperiod' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockBitsOk_midperiod
/-- info: 'Bitcoin.Invariants.RC08.blockBitsOk_badDiffbits' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockBitsOk_badDiffbits
/-- info: 'Bitcoin.Invariants.RC08.blockBitsOk_required' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockBitsOk_required
/-- info: 'Bitcoin.Invariants.RC08.blockBitsOk_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockBitsOk_reject
/-- info: 'Bitcoin.Invariants.RC08.blockBitsOk_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockBitsOk_iff
/-- info: 'Bitcoin.Invariants.RC08.blockBitsOk_minDifficulty' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockBitsOk_minDifficulty
/-- info: 'Bitcoin.Invariants.RC08.blockBitsOk_boundary' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockBitsOk_boundary
/-- info: 'Bitcoin.Invariants.RC08.blockBitsOk_boundary_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockBitsOk_boundary_reject
/-- info: 'Bitcoin.Invariants.RC08.retargetOnlyAtBoundary' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms retargetOnlyAtBoundary
/-- info: 'Bitcoin.Invariants.RC08.retargetAtBoundary_calculate' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms retargetAtBoundary_calculate
/-- info: 'Bitcoin.Invariants.RC08.retargetMidPeriod_minDifficulty' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms retargetMidPeriod_minDifficulty
/-- info: 'Bitcoin.Invariants.RC08.retargetMidPeriod_minDifficulty_walkBack' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms retargetMidPeriod_minDifficulty_walkBack
/-- info: 'Bitcoin.Invariants.RC08.clampedTimespan_bounds' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms clampedTimespan_bounds
/-- info: 'Bitcoin.Invariants.RC08.clampedTimespan_window' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms clampedTimespan_window

end Bitcoin.Invariants.RC08
