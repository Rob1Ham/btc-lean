import Bitcoin.Crypto.Taproot.Program

/-!
# Bitcoin.Crypto.Taproot.OutputKey — output-key reconstruction and the
# parity / internal-key checks (X06)

The BIP341 control-block key lanes that are implementable STANDALONE of
the BIP341 sighash pipeline and the BIP342 tapscript deltas (X03/X04
lanes). Everything here composes X02's `liftX`/`bytesToNatBE` and
X03's `tweakPoint` — no new crypto, just the control-block-facing
plumbing `pubkey.cpp:CheckTapTweak` performs before the sighash lane
runs:

* **Output-key parity** — `parityOk` (TPR-011): the low bit of
  `control[0]` must equal `y(Q) mod 2` for the recomputed tweaked key
  `Q` (interpreter.cpp:1924, `(control[0]&1)` @cce32b168).
* **Internal-key parse** — `internalKeyOk` (TPR-018): the control
  block's 32-byte pubkey field must lift to a curve point via
  `lift_x` (pubkey.cpp:CheckTapTweak:260 @cce32b168; BIP341 §"Script
  validation": "fail if x ≥ p or x³+7 is not a quadratic residue").
* **Composite reconstruction** — `outputKeyOk`: size gate (TPR-009
  base size) → parse (TPR-018) → tweak (X03 `tweakPoint`, TPR-016/017
  reject modes) → parity (TPR-011). `none` at any stage fails closed.
  This is the control-block-facing half of Core's `CheckTapTweak`: the
  separate output-key comparison `q == x(Q)` (the 32-byte witness
  program) lives in `Verify.checkTapTweak` / `VerifyTaprootCommitment`,
  which adds the length-checked byte equality on top of `outputKeyOk`.
  `outputKeyOk` alone must not be read as the full commitment verdict.

Ground truth @cce32b168: `pubkey.cpp:XOnlyPubKey::CheckTapTweak:255-271`,
`interpreter.cpp:VerifyTaprootCommitment:1905-1930` (control[0]&1
parity compare :1924), BIP341 §"Script validation" steps 4-6
(control[0] low bit = parity of y(Q); pubkey parse via lift_x; tweak
recomputation Q = P + int(t)·G).
-/

namespace Bitcoin.Crypto.Taproot.OutputKey

open Bitcoin.Crypto.Curve.Secp (liftX bytesToNatBE RawPoint P)
open Bitcoin.Crypto.Taproot (tweakPoint)
open Bitcoin.Crypto.Taproot.Program (TAPROOT_CONTROL_BASE_SIZE controlBlockSizeOk
  controlBlockSizeOk_sizes)

/-! ## TPR-011 — the output-key parity check -/

/-- TPR-011 (interpreter.cpp:1924 `(control[0]&1)` @cce32b168; BIP341
§"Script validation", verification step: "the low bit of control[0]
MUST equal the parity of y(Q)"): `parityOk control yQ` holds iff
`control[0] & 1 == y(Q) & 1`. Fail-closed: an empty control block
(malformed — the TPR-009 size gate should have rejected it) fails. -/
@[rule "TPR-011"]
def parityOk (control : ByteArray) (yQ : Nat) : Bool :=
  if 0 < control.size then (control.get! 0).toNat % 2 == yQ % 2 else false

/-- TPR-011 (characterization): for a well-formed control block
(`0 < size`, guaranteed by the TPR-009 gate) the check is exactly the
literal Core comparison on `control[0]`. -/
theorem parityOk_eq (control : ByteArray) (yQ : Nat)
    (h : 0 < control.size) :
    parityOk control yQ = ((control.get! 0).toNat % 2 == yQ % 2) := by
  unfold parityOk
  split
  · rfl
  · omega

/-- TPR-011 (fail-closed): the empty control block never passes the
parity check. -/
theorem parityOk_empty (yQ : Nat) :
    parityOk ByteArray.empty yQ = false := by
  unfold parityOk; rfl

/-- TPR-011 (even-output example): control byte `0xc0` (the tapscript
leaf version with even parity bit) matches `y(Q)` even. -/
theorem parityOk_even_example :
    parityOk (ByteArray.empty.push 0xc0) 2 = true := by
  unfold parityOk; rfl

/-- TPR-011 (odd-output example): control byte `0xc1` (odd parity bit)
matches `y(Q)` odd but does NOT match `y(Q)` even. -/
theorem parityOk_odd_example :
    parityOk (ByteArray.empty.push 0xc1) 3 = true ∧
    parityOk (ByteArray.empty.push 0xc1) 2 = false := by
  unfold parityOk
  exact ⟨rfl, rfl⟩

/-- TPR-011 (discrimination): with an even control byte the verdict is
exactly the evenness of `y(Q)` — flipping the parity bit flips the
accept set, so the check is not vacuous. -/
theorem parityOk_flip (b : ByteArray) (yQ : Nat) (h : 0 < b.size)
    (hp : (b.get! 0).toNat % 2 = 0) :
    parityOk b yQ = true ↔ yQ % 2 = 0 := by
  rw [parityOk_eq b yQ h, hp, beq_iff_eq]
  exact eq_comm

/-! ## TPR-018 — the internal-key parse -/

/-- The control block's internal-key field: bytes `control[1..33]`.
For a control block shorter than 33 bytes (malformed — rejected by
the TPR-009 gate in honest executions) this fails closed to the empty
byte string. -/
def internalKeyBytes (control : ByteArray) : ByteArray :=
  if 33 ≤ control.size then control.extract 1 33 else ByteArray.empty

theorem internalKeyBytes_short (control : ByteArray)
    (h : control.size < 33) : internalKeyBytes control = ByteArray.empty := by
  unfold internalKeyBytes
  split
  · omega
  · rfl

theorem internalKeyBytes_eq (control : ByteArray)
    (h : 33 ≤ control.size) :
    internalKeyBytes control = control.extract 1 33 := by
  unfold internalKeyBytes
  split
  · rfl
  · omega

/-- TPR-018 (pubkey.cpp:CheckTapTweak:260 @cce32b168; BIP341: the
control-block pubkey "MUST be a valid public key", parsed with
BIP340 `lift_x`): `internalKeyOk control` iff
`lift_x(bytesToNatBE(control[1..33]))` succeeds (x < p and x³+7 a
quadratic residue mod p). Fail-closed via the 33-byte gate above. -/
@[rule "TPR-018"]
def internalKeyOk (control : ByteArray) : Bool :=
  (liftX (bytesToNatBE (internalKeyBytes control))).isSome

/-- TPR-018 (characterization, well-formed control): for `size ≥ 33`
the check is `liftX` on the big-endian parse of bytes `1..33`. -/
theorem internalKeyOk_eq (control : ByteArray)
    (h : 33 ≤ control.size) :
    internalKeyOk control =
      (liftX (bytesToNatBE (control.extract 1 33))).isSome := by
  rw [internalKeyOk, internalKeyBytes_eq control h]

/-- TPR-018 (reject mode A — x ≥ p): a control block whose pubkey
field encodes x ≥ p does NOT parse, so the check fails. -/
theorem internalKeyOk_geP (control : ByteArray) (h : 33 ≤ control.size)
    (hx : P ≤ bytesToNatBE (control.extract 1 33)) :
    internalKeyOk control = false := by
  rw [internalKeyOk_eq control h]
  have hnone : liftX (bytesToNatBE (control.extract 1 33)) = none := by
    unfold liftX
    split
    · rfl
    · omega
  rw [hnone]; rfl

/-! ## The composite: output-key reconstruction -/

/-- The tweaked-key recomputation as one Option chain (BIP341 §"Script
validation" steps 5-6): parse the internal key, then recompute
`Q = P + int(t)·G` with X03's `tweakPoint` — the TPR-016/017 reject
modes are the `none` cases. -/
def tweakedKey (control : ByteArray) (root : Option ByteArray) :
    Option (Nat × Nat) :=
  (liftX (bytesToNatBE (internalKeyBytes control))).bind
    (fun p => tweakPoint (internalKeyBytes control) p root)

/-- Output-key reconstruction (interpreter.cpp:VerifyTaprootCommitment
:1905-1930 @cce32b168), fail-closed end to end:

1. size gate: `control.size ≥ TAPROOT_CONTROL_BASE_SIZE` (else fail;
   the TPR-009 lattice is the caller's gate — see
   `outputKeyOk_gate_of_controlBlockSizeOk`);
2. parse the internal key (`TPR-018`; else fail);
3. recompute the tweaked key (TPR-016/017; `none` ⇒ fail);
4. parity: `control[0]&1 == y(Q)&1` (`TPR-011`; else fail). -/
def outputKeyOk (control : ByteArray) (root : Option ByteArray) : Bool :=
  if TAPROOT_CONTROL_BASE_SIZE ≤ control.size then
    match tweakedKey control root with
    | none => false
    | some (_, yQ) => parityOk control yQ
  else false

/-- Composite (size gate): a control block below the base size is
rejected outright — the size gate runs FIRST (interpreter.cpp:1911,
`control.size() < TAPROOT_CONTROL_BASE_SIZE` reject). -/
theorem outputKeyOk_short (control : ByteArray) (root : Option ByteArray)
    (h : control.size < TAPROOT_CONTROL_BASE_SIZE) :
    outputKeyOk control root = false := by
  unfold outputKeyOk
  split
  · omega
  · rfl

/-- Composite (TPR-018 reject): a well-sized control block whose
pubkey field does not parse fails. -/
theorem outputKeyOk_parse_none (control : ByteArray) (root : Option ByteArray)
    (h : TAPROOT_CONTROL_BASE_SIZE ≤ control.size)
    (hp : liftX (bytesToNatBE (internalKeyBytes control)) = none) :
    outputKeyOk control root = false := by
  unfold outputKeyOk
  split
  · unfold tweakedKey
    rw [hp]; rfl
  · omega

/-- Composite (TPR-017 reject, composed): a parsed internal key whose
tweak overflows the group order (or lands on 𝒪) fails — X03's
`tweakPoint = none` propagates to `false`. -/
theorem outputKeyOk_tweak_none (control : ByteArray) (root : Option ByteArray)
    (xI yI : Nat)
    (h : TAPROOT_CONTROL_BASE_SIZE ≤ control.size)
    (hp : liftX (bytesToNatBE (internalKeyBytes control)) = some (xI, yI))
    (ht : tweakPoint (internalKeyBytes control) (some (xI, yI)) root = none) :
    outputKeyOk control root = false := by
  unfold outputKeyOk
  split
  · have hbind : tweakedKey control root = none := by
      unfold tweakedKey
      simp only [hp, ht, Option.bind_some]
    rw [hbind]
  · omega

/-- Composite (TPR-011 final gate): a fully-reconstructed tweaked key
`Q` passes iff `control[0]&1 == y(Q)&1` — the parity check is the LAST
verdict (interpreter.cpp:1924). -/
theorem outputKeyOk_parity (control : ByteArray) (root : Option ByteArray)
    (xI yI xQ yQ : Nat)
    (h : TAPROOT_CONTROL_BASE_SIZE ≤ control.size)
    (hp : liftX (bytesToNatBE (internalKeyBytes control)) = some (xI, yI))
    (ht : tweakPoint (internalKeyBytes control) (some (xI, yI)) root
        = some (xQ, yQ)) :
    outputKeyOk control root = parityOk control yQ := by
  unfold outputKeyOk
  split
  · have hbind : tweakedKey control root = some (xQ, yQ) := by
      unfold tweakedKey
      simp only [hp, ht, Option.bind_some]
    rw [hbind]
  · omega

/-- Composite (accept ⇒ parse): `outputKeyOk = true` implies the
internal key parsed (TPR-018 held). -/
theorem outputKeyOk_internalKeyOk (control : ByteArray) (root : Option ByteArray)
    (h : outputKeyOk control root = true) :
    internalKeyOk control = true := by
  by_cases hsize : TAPROOT_CONTROL_BASE_SIZE ≤ control.size
  · by_cases hparse : liftX (bytesToNatBE (internalKeyBytes control)) = none
    · rw [outputKeyOk_parse_none control root hsize hparse] at h
      exact absurd h (by simp)
    · unfold internalKeyOk
      cases hp : liftX (bytesToNatBE (internalKeyBytes control)) with
      | none => exact absurd hp hparse
      | some _ => rfl
  · have hshort := outputKeyOk_short control root (by omega)
    rw [hshort] at h
    exact absurd h (by simp)

/-- Composite (accept ⇒ size gate): `outputKeyOk = true` implies the
control block cleared the base-size bound. -/
theorem outputKeyOk_size (control : ByteArray) (root : Option ByteArray)
    (h : outputKeyOk control root = true) :
    TAPROOT_CONTROL_BASE_SIZE ≤ control.size := by
  by_cases hsize : TAPROOT_CONTROL_BASE_SIZE ≤ control.size
  · exact hsize
  · have hshort := outputKeyOk_short control root (by omega)
    rw [hshort] at h
    exact absurd h (by simp)

/-- Composite (link to the TPR-009 gate): every control block that
passes `controlBlockSizeOk` clears the composite's size gate. -/
theorem outputKeyOk_gate_of_controlBlockSizeOk (control : ByteArray)
    (h : controlBlockSizeOk control = true) :
    TAPROOT_CONTROL_BASE_SIZE ≤ control.size :=
  ((controlBlockSizeOk_sizes control).mp h).1

/-! ## Axiom footprints (X02/X03/X06 style: `#guard_msgs in #print axioms`)

All sorry-free; footprints ⊆ the standard trio `[propext,
Classical.choice, Quot.sound]`.
-/

/-- info: 'Bitcoin.Crypto.Taproot.OutputKey.parityOk_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms parityOk_eq

/-- info: 'Bitcoin.Crypto.Taproot.OutputKey.parityOk_flip' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms parityOk_flip

/-- info: 'Bitcoin.Crypto.Taproot.OutputKey.internalKeyBytes_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms internalKeyBytes_eq

/-- info: 'Bitcoin.Crypto.Taproot.OutputKey.internalKeyOk_geP' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms internalKeyOk_geP

/-- info: 'Bitcoin.Crypto.Taproot.OutputKey.outputKeyOk_short' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms outputKeyOk_short

/-- info: 'Bitcoin.Crypto.Taproot.OutputKey.outputKeyOk_parse_none' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms outputKeyOk_parse_none

/-- info: 'Bitcoin.Crypto.Taproot.OutputKey.outputKeyOk_tweak_none' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms outputKeyOk_tweak_none

/-- info: 'Bitcoin.Crypto.Taproot.OutputKey.outputKeyOk_parity' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms outputKeyOk_parity

/-- info: 'Bitcoin.Crypto.Taproot.OutputKey.outputKeyOk_internalKeyOk' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms outputKeyOk_internalKeyOk

/-- info: 'Bitcoin.Crypto.Taproot.OutputKey.outputKeyOk_size' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms outputKeyOk_size

end Bitcoin.Crypto.Taproot.OutputKey
