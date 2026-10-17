import Bitcoin.Activation.Bip9

/-!
# W06 test harness — dormant BIP9 machine (Interface + Bip9)

Run: `bash spec/Test/Activation/run.sh`.
The state-machine table uses a small toy period (3) so the full
DEFINED→STARTED→LOCKED_IN→ACTIVE walk is human-checkable; mainnet's
2016-period numbers are checked separately (testdummy, BLK-081).
-/

open Bitcoin.Activation

set_option maxRecDepth 100000

/-! ## Toy machine: period 3, start boundary 2, threshold 2, timeout at 8 -/

/-- Toy deployment: boundaries at 2, 5, 8, 11, …; STARTED from boundary 2;
signals 2-of-2 in the period ending at 8 (exactly the timeout deadline —
the 2017-erratum corner); min_activation 0. -/
def toy : Bip9Params :=
  { start := 2, timeoutPeriods := 2, threshold := 2, period := 3,
    minActivation := 0, count := fun b => if 8 ≤ b then 2 else 1 }

-- Full transition table (BLK-074/075/077/078 in one decidably-checked walk):
-- k=0 (h=2): DEFINED → STARTED (start ≤ boundary)
-- k=1 (h=5): count 1 < 2, deadline 8 > 5 → stays STARTED
-- k=2 (h=8): count 2 ≥ 2 AT the deadline → LOCKED_IN (BLK-077: count test first)
-- k=3 (h=11): LOCKED_IN → ACTIVE (min_activation 0, BLK-078)
-- k=4 (h=14): ACTIVE forever
example : bip9StateByPeriod toy 0 = .started := by decide
example : bip9StateByPeriod toy 1 = .started := by decide
example : bip9StateByPeriod toy 2 = .lockedIn := by decide
example : bip9StateByPeriod toy 3 = .active := by decide
example : bip9StateByPeriod toy 4 = .active := by decide

-- bip9State agrees at chain heights (period alignment, BLK-074):
-- heights before the first full period are DEFINED.
example : bip9State toy 0 = .defined := by decide
example : bip9State toy 1 = .defined := by decide
example : bip9State toy 2 = .started := by decide
example : bip9State toy 5 = .started := by decide
example : bip9State toy 8 = .lockedIn := by decide
example : bip9State toy 11 = .active := by decide
example : bip9State toy 999 = .active := by decide

-- A failed toy deployment: count never reaches threshold, deadline 8.
def toyFail : Bip9Params :=
  { start := 2, timeoutPeriods := 2, threshold := 2, period := 3,
    minActivation := 0, count := fun _ => 1 }

example : bip9StateByPeriod toyFail 2 = .failed := by decide
example : bip9StateByPeriod toyFail 3 = .failed := by decide
example : bip9StateByPeriod toyFail 9 = .failed := by decide

-- min_activation_height > 0 holds LOCKED_IN one extra period (BLK-078).
def toyDelayed : Bip9Params :=
  { start := 2, timeoutPeriods := 2, threshold := 2, period := 3,
    minActivation := 100, count := fun b => if 8 ≤ b then 2 else 1 }

example : bip9StateByPeriod toyDelayed 3 = .lockedIn := by decide
example : bip9StateByPeriod toyDelayed 4 = .lockedIn := by decide

/-! ## Mainnet: dormant testdummy (BLK-079 / BLK-081) -/

example : mainnetTestdummy.bit = 28 := by rfl
example : mainnetTestdummy.threshold = 1815 := by rfl
example : mainnetTestdummy.period = 2016 := by rfl
example : mainnetTestdummy.start = BIP9_NEVER_ACTIVE := by rfl
example : mainnetDeployments.length = 1 := by rfl

-- NEVER_ACTIVE start ⇒ FAILED at every height, any count function.
example (count : UInt32 → UInt32) (h : UInt32) :
    thresholdState mainnetTestdummy.start mainnetTestdummy.timeout
      mainnetTestdummy.threshold mainnetTestdummy.period count h = .failed := by
  exact bip9_never_active _ _ _ _ h

-- The full dormancy corollary.
example (count : UInt32 → UInt32) (h : UInt32) :
    (∀ d ∈ mainnetDeployments,
       thresholdState d.start d.timeout d.threshold d.period count h = .failed) ∧
    mainnetDeployments.length = 1 := by
  exact ⟨fun d hd => mainnet_deployments_dormant count h d hd, rfl⟩

-- Signal predicate vectors (BLK-073).
example : versionBitsSignals 0x20000001 0 = true := by decide
example : versionBitsSignals 0xA0000001 0 = false := by decide
example : versionBitsSignals 0x22000000 29 = true := by decide

/-! ## Axiom pins (D2 L3) -/

/-- info: 'Bitcoin.Activation.bip9_threshold_locks_in' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.bip9_threshold_locks_in
/-- info: 'Bitcoin.Activation.bip9_timeout_fails' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Activation.bip9_timeout_fails
/-- info: 'Bitcoin.Activation.count_beats_timeout' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.count_beats_timeout
/-- info: 'Bitcoin.Activation.bip9_min_activation' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Activation.bip9_min_activation
/-- info: 'Bitcoin.Activation.bip9_genesis_defined' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.bip9_genesis_defined
/-- info: 'Bitcoin.Activation.lockin_survives_timeout' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Activation.lockin_survives_timeout
/-- info: 'Bitcoin.Activation.bip9State_next_period' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Activation.bip9State_next_period

/-! ## Runtime harness -/

def check (name : String) (b : Bool) : IO Unit :=
  IO.println s!"[{if b then "PASS" else "FAIL"}] {name}"

def checkR (name : String) (b : Bool) : IO Bool := do
  check name b
  return b

def main : IO UInt32 := do
  let r1 ← checkR "toy machine: STARTED,STARTED,LOCKED_IN,ACTIVE,ACTIVE"
    (bip9StateByPeriod toy 0 == .started && bip9StateByPeriod toy 1 == .started &&
     bip9StateByPeriod toy 2 == .lockedIn && bip9StateByPeriod toy 3 == .active &&
     bip9StateByPeriod toy 4 == .active)
  let r2 ← checkR "lock-in at the timeout boundary (BLK-077 erratum corner)"
    (bip9StateByPeriod toy 2 == .lockedIn)
  let r3 ← checkR "bip9State period-alignment at chain heights"
    (bip9State toy 0 == .defined && bip9State toy 2 == .started &&
     bip9State toy 8 == .lockedIn && bip9State toy 11 == .active)
  let r4 ← checkR "timeout without threshold ⇒ FAILED"
    (bip9StateByPeriod toyFail 3 == .failed && bip9StateByPeriod toyFail 9 == .failed)
  let r5 ← checkR "min_activation_height holds LOCKED_IN"
    (bip9StateByPeriod toyDelayed 3 == .lockedIn && bip9StateByPeriod toyDelayed 4 == .lockedIn)
  let r6 ← checkR "mainnet testdummy dormant at every height"
    (thresholdState mainnetTestdummy.start mainnetTestdummy.timeout
       mainnetTestdummy.threshold mainnetTestdummy.period (fun _ => 0) 0 == .failed &&
     thresholdState mainnetTestdummy.start mainnetTestdummy.timeout
       mainnetTestdummy.threshold mainnetTestdummy.period (fun _ => 0) 900000 == .failed)
  let r7 ← checkR "mainnet deployment table: exactly one entry"
    (mainnetDeployments.length == 1)
  let r8 ← checkR "BIP9 signal predicate vectors"
    (versionBitsSignals 0x20000001 0 && ¬ versionBitsSignals 0xA0000001 0 &&
     versionBitsSignals 0x22000000 29)
  IO.println "Bip9Test done."
  let all := [r1, r2, r3, r4, r5, r6, r7, r8]
  return if all.foldl (· && ·) true then 0 else 1
