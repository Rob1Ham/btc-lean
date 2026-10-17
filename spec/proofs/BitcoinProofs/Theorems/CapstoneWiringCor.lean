import Bitcoin.Capstone.Block

/-!
# BitcoinProofs.Theorems.CapstoneWiringCor — P10: the proved checker-wiring spec (sorry-free)

Theorems about THE seam of the capstone pipeline (`Bitcoin.Capstone.Block`):
where W14b's real ECDSA verifier, W11's sighash, W13's checker adapters and
W09's interpreter meet, and where the Taproot unjudged lane is decided
(`verifyInput`'s `isTaprootProgram` gate, decided BEFORE the checker —
W17 report §3's documented per-input assume-valid for v1 witness programs).

Every statement below is proved from the interfaces alone (no `sorry`, no
`native_decide`): the lane gate is a pure `Bool` test, the checker record is
a pure structure of function fields, and the fuel budget is arithmetic.

C4 portfolio linkage:

| C4 ID | theorem here | statement (short) |
|-------|--------------|-------------------|
| (P15-slot cor) | `verifyInput_taproot_lane` | a v1-witness (Taproot) coin routes to `unjudgedTaproot` BEFORE the checker — no sorryAx-bearing Schnorr path can run, at input granularity |
| (SCR-053 cor) | `isTaprootProgram_v0_false` | v0 witness programs are NOT Taproot: P2WPKH/P2WSH stay fully adjudicated |
| (SCR-053 cor) | `isTaprootProgram_none_false` / `isTaprootProgram_ge1_true` | the lane gate is exactly "witness program with version ≥ 1" |
| (BLK wiring) | `verifyInput_fail_shape` | an adjudicated failure is ALWAYS `CapError.scriptFail txIdx inputIdx e` with the caller's indices |
| (BLK wiring) | `verifyInput_trichotomy` / `verifyInput_exclusive` | `verifyInput` is a decidable total function returning exactly one of the three constructors |
| (BLK wiring) | `verifyInput_eq_unjudged` | away from the gate, `verifyInput` is literally the 3-way match on `verifyScriptFull` at the documented fuel |
| (W13 wiring) | `realCheckerOf_*` | the checker record is pure: env fields are projections of `(tx, nIn)`, the Schnorr slot is fail-closed, the ECDSA entry is execData-independent and pops the hashtype into W14b's `verifyImpl` over W11's dispatch |
| (fuel) | `fuel_bound` / `fuel_bound_witness_item` | `verifyInput`'s fuel = ss.size + spk.size + witness bytes + 10 ≥ ss.size + spk.size (each opcode consumes ≥ 1 wire byte) |

Axiom footprints (audited with `#print axioms` in a scratch file):
all theorems here are `sorryAx`-free. The `Classical.choice` in most
footprints is inherited from the core layer below (a bare `rfl` about
`realCheckerOf` already carries it — it enters through the seam/record
definitions' kernel-unfolding, exactly like W15's `InterpCor` theorems
over the same interpreter layer); no theorem here USES choice beyond
what the core unfolds to.

| theorem | axiom footprint |
|---------|-----------------|
| `verifyInput_taproot_lane` | propext, Classical.choice, Quot.sound |
| `isTaprootProgram_none_false` | — (none) |
| `isTaprootProgram_v0_false` | — (none) |
| `isTaprootProgram_ge1_true` | — (none) |
| `verifyInput_taproot_not_pass` | propext, Classical.choice, Quot.sound |
| `verifyInput_taproot_not_fail` | propext, Classical.choice, Quot.sound |
| `verifyInput_fail_shape` | propext, Classical.choice, Quot.sound |
| `verifyInput_trichotomy` | propext, Classical.choice, Quot.sound |
| `verifyInput_exclusive` | propext, Classical.choice, Quot.sound |
| `verifyInput_not_pass_unjudged_or_fail` | propext, Classical.choice, Quot.sound |
| `verifyInput_eq_unjudged` | propext, Classical.choice, Quot.sound |
| `realCheckerOf_congr` | propext, Classical.choice, Quot.sound |
| `realCheckerOf_env_version` | propext, Classical.choice, Quot.sound |
| `realCheckerOf_env_lockTime` | propext, Classical.choice, Quot.sound |
| `realCheckerOf_env_sequence` | propext, Classical.choice, Quot.sound |
| `realCheckerOf_env_sequence_inRange` | propext, Classical.choice, Quot.sound |
| `realCheckerOf_schnorr_failclosed` | propext, Classical.choice, Quot.sound |
| `realCheckerOf_ecdsa_execData_indep` | propext, Classical.choice, Quot.sound |
| `realCheckerOf_ecdsa_def` | propext, Classical.choice, Quot.sound |
| `realCheckerOf_ecdsa_pops_hashtype` | propext, Classical.choice, Quot.sound |
| `realCheckerOf_ecdsa_empty_sig_false` | propext, Classical.choice, Quot.sound |
| `realCheckerOf_ecdsa_witnessV0_hasAmount` | propext, Classical.choice, Quot.sound |
| `sighashDispatch_witnessV0` | propext, Classical.choice, Quot.sound |
| `sighashDispatch_legacy` | propext, Classical.choice, Quot.sound |
| `fuel_bound` | propext, Classical.choice, Quot.sound |
| `fuel_bound_witness_item` | propext, Quot.sound |
-/

namespace BitcoinProofs.Theorems.CapstoneWiring

open Bitcoin.Capstone.Block Bitcoin.Capstone.RealChecker
open Bitcoin.Crypto.Seam Bitcoin.Crypto.Ecdsa.Verify Bitcoin.SigHash
open Bitcoin.Data Bitcoin.Interpreter Bitcoin.Crypto.Seam.Entry
open Bitcoin.Crypto.Seam.Der
open Bitcoin.Ledger Bitcoin.Activation

/-! ## List helper (proof-carrying `get`, no `Inhabited` needed) -/

/-- `getD` with ANY fallback agrees with the proof-carrying `get` once the
index is in range — the fallback is never consulted. Used to expose the
real scriptSig inside `verifyInput`'s `getD`-based plumbing. -/
private theorem getD_eq_get {α : Type} {l : List α} {i : Nat} {d : α}
    (h : i < l.length) : l.getD i d = l[i]'h := by
  induction l generalizing i with
  | nil => simp at h
  | cons a l' ih =>
      cases i with
      | zero => rfl
      | succ i' =>
          rw [List.length_cons] at h
          exact ih (by omega)

/-! ## The Taproot lane gate (P15-slot leakage freedom, input granularity) -/

/-- **The unjudged lane is decided BEFORE the checker**: whenever the spent
coin's scriptPubKey is a v1-witness (Taproot) program, `verifyInput`
returns `unjudgedTaproot` without ever running `verifyScriptFull` — and
therefore without ever reaching W13's fail-closed Schnorr entry. This is
the per-input form of W17's leakage-freedom statement: the only inputs
not fully adjudicated are exactly the ones this gate catches. -/
theorem verifyInput_taproot_lane (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat)
    (h : isTaprootProgram coin.scriptPubKey.bytes = true) :
    verifyInput height tx i coin txIdx inputIdx = InputVerdict.unjudgedTaproot := by
  unfold verifyInput
  exact if_pos h

/-- The gate is exactly "witness program with version ≥ 1"; a non-witness
scriptPubKey never takes the unjudged lane (bare/P2SH scripts are fully
adjudicated). -/
theorem isTaprootProgram_none_false (spk : ByteArray)
    (h : isWitnessProgram spk = none) :
    isTaprootProgram spk = false := by
  unfold isTaprootProgram
  rw [h]

/-- **SCR-053 corollary**: a v0 witness program is not a Taproot program —
v0 P2WPKH/P2WSH coins stay on the fully-adjudicated W09/W11/W14b path. -/
theorem isTaprootProgram_v0_false (spk prog : ByteArray)
    (h : isWitnessProgram spk = some (0, prog)) :
    isTaprootProgram spk = false := by
  unfold isTaprootProgram
  rw [h]; rfl

/-- The positive direction of the gate: any witness version ≥ 1 (v1 =
Taproot key/script path; higher = upgradable) routes to the unjudged lane. -/
theorem isTaprootProgram_ge1_true (spk prog : ByteArray) (v : Nat)
    (hv : 1 ≤ v) (h : isWitnessProgram spk = some (v, prog)) :
    isTaprootProgram spk = true := by
  unfold isTaprootProgram
  rw [h]
  exact decide_eq_true hv

/-- The unjudged lane is NOT an adjudicated pass: a Taproot-lane input can
never contribute to the `scriptOk` counter. -/
theorem verifyInput_taproot_not_pass (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat)
    (h : isTaprootProgram coin.scriptPubKey.bytes = true) :
    verifyInput height tx i coin txIdx inputIdx ≠ InputVerdict.pass := by
  rw [verifyInput_taproot_lane height tx i coin txIdx inputIdx h]
  simp

/-- The unjudged lane is NOT an adjudicated failure either: taking it can
never throw `CapError.scriptFail` (W17's "does not gate the block verdict"). -/
theorem verifyInput_taproot_not_fail (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat) (e : CapError)
    (h : isTaprootProgram coin.scriptPubKey.bytes = true) :
    verifyInput height tx i coin txIdx inputIdx ≠ InputVerdict.fail e := by
  rw [verifyInput_taproot_lane height tx i coin txIdx inputIdx h]
  simp

/-! ## Error shape and totality of the per-input verdict -/

/-- **Failure shape**: whenever `verifyInput` adjudicates a failure, the
error is `CapError.scriptFail txIdx inputIdx e` with EXACTLY the caller's
tx/input indices — the capstone layer can never misattribute a script
failure, and no other `CapError` constructor can leak out of this layer. -/
theorem verifyInput_fail_shape (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat) (e : CapError)
    (h : verifyInput height tx i coin txIdx inputIdx = InputVerdict.fail e) :
    ∃ ee, e = CapError.scriptFail txIdx inputIdx ee := by
  simp only [verifyInput] at h
  split at h
  · simp at h
  · split at h
    · simp at h
    · simp at h
    · rename_i _ ee _
      exact ⟨ee, by simpa using h.symm⟩

/-- **Totality / trichotomy**: `verifyInput` is a decidable total function
returning EXACTLY one of the three `InputVerdict` constructors — pass
(adjudicated true), fail (adjudicated false), or the unjudged Taproot
lane. There is no fourth outcome and no partiality. -/
theorem verifyInput_trichotomy (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat) :
    verifyInput height tx i coin txIdx inputIdx = InputVerdict.pass ∨
    verifyInput height tx i coin txIdx inputIdx = InputVerdict.unjudgedTaproot ∨
    ∃ e, verifyInput height tx i coin txIdx inputIdx = InputVerdict.fail e := by
  simp only [verifyInput]
  split
  · exact Or.inr (Or.inl rfl)
  · split
    · exact Or.inl rfl
    · exact Or.inr (Or.inl rfl)
    · rename_i _ f _
      exact Or.inr (Or.inr ⟨CapError.scriptFail txIdx inputIdx f, rfl⟩)

/-- The trichotomy is exclusive (the three constructors are pairwise
distinct), so "exactly one" — not just "at least one" — holds. -/
theorem verifyInput_exclusive (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat) (e : CapError) :
    (verifyInput height tx i coin txIdx inputIdx = InputVerdict.pass →
       verifyInput height tx i coin txIdx inputIdx ≠ InputVerdict.fail e ∧
       verifyInput height tx i coin txIdx inputIdx ≠ InputVerdict.unjudgedTaproot) ∧
    (verifyInput height tx i coin txIdx inputIdx = InputVerdict.fail e →
       verifyInput height tx i coin txIdx inputIdx ≠ InputVerdict.pass ∧
       verifyInput height tx i coin txIdx inputIdx ≠ InputVerdict.unjudgedTaproot) ∧
    (verifyInput height tx i coin txIdx inputIdx = InputVerdict.unjudgedTaproot →
       verifyInput height tx i coin txIdx inputIdx ≠ InputVerdict.pass ∧
       verifyInput height tx i coin txIdx inputIdx ≠ InputVerdict.fail e) := by
  refine ⟨?_, ?_, ?_⟩
  · intro hp; rw [hp]; simp
  · intro hf; rw [hf]; simp
  · intro hu; rw [hu]; simp

/-- Corollary of shape + totality: a verdict that is neither pass nor the
lane (for a non-gated input) is a script failure with the caller's
indices. Note the `unjudged` outcome of `verifyScriptFull` (Taproot
SCRIPT-path spending inside a P2SH or non-standard wrapper) legitimately
lands on the unjudged lane too — by construction of the interpreter. -/
theorem verifyInput_not_pass_unjudged_or_fail (height : UInt32) (tx : Tx) (i : Nat)
    (coin : Coin) (txIdx inputIdx : Nat)
    (hgate : isTaprootProgram coin.scriptPubKey.bytes = false)
    (h : verifyInput height tx i coin txIdx inputIdx ≠ InputVerdict.pass) :
    verifyInput height tx i coin txIdx inputIdx = InputVerdict.unjudgedTaproot ∨
    ∃ ee, verifyInput height tx i coin txIdx inputIdx
        = InputVerdict.fail (CapError.scriptFail txIdx inputIdx ee) := by
  rcases verifyInput_trichotomy height tx i coin txIdx inputIdx with hp | hu | ⟨e, he⟩
  · exact absurd hp h
  · exact Or.inl hu
  · obtain ⟨ee, hee⟩ := verifyInput_fail_shape height tx i coin txIdx inputIdx e he
    subst hee
    exact Or.inr ⟨ee, he⟩

/-- Unfolding lemma for the non-gated branch with the input IN RANGE
(every real input is — W10/W12 check vin indices): away from the lane
gate, `verifyInput` is literally a three-way match on `verifyScriptFull`
at the documented fuel (`ss.size + spk.size + witness bytes + 10`), W06's
`getBlockScriptFlags`, default policy, and the REAL checker wiring
(W13 adapter × W14b `verifyImpl` × W11 dispatch). -/
theorem verifyInput_eq_unjudged (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat)
    (hgate : isTaprootProgram coin.scriptPubKey.bytes = false)
    (hlen : i < tx.vin.length) :
    verifyInput height tx i coin txIdx inputIdx =
      match verifyScriptFull
        ((tx.vin[i]'hlen).scriptSig.bytes.size + coin.scriptPubKey.bytes.size
          + ((witnessAt tx i).map (·.size)).foldl Nat.add 0 + 10)
        (getBlockScriptFlags height) default
        ((tx.vin[i]'hlen).scriptSig.bytes) (coin.scriptPubKey.bytes)
        (witnessAt tx i) (realCheckerOf tx i coin.value) with
      | .ok => InputVerdict.pass
      | .unjudged => InputVerdict.unjudgedTaproot
      | .fail e => InputVerdict.fail (CapError.scriptFail txIdx inputIdx e) := by
  unfold verifyInput
  rw [if_neg (by simp [hgate]), getD_eq_get hlen]
  rfl

/-! ## The checker wiring is pure and determinism-usable -/

/-- Purity (dependency surface): `realCheckerOf` depends on EXACTLY
`(tx, nIn, amount)` — equal arguments give literally the same checker
record. Its actual signature has NO state parameter at all (the honest
weakening of "state independence": the record is a pure function of these
three, so downstream consumers may substitute it freely). -/
theorem realCheckerOf_congr (tx₁ tx₂ : Tx) (n₁ n₂ : Nat) (a₁ a₂ : Amount)
    (htx : tx₁ = tx₂) (hn : n₁ = n₂) (ha : a₁ = a₂) :
    realCheckerOf tx₁ n₁ a₁ = realCheckerOf tx₂ n₂ a₂ := by
  subst htx; subst hn; subst ha; rfl

/-- The locktime environment is projected from the tx (IC-2): version. -/
theorem realCheckerOf_env_version (tx : Tx) (nIn : Nat) (amount : Amount) :
    (realCheckerOf tx nIn amount).env.txVersion = tx.version := rfl

/-- The locktime environment is projected from the tx (IC-2): locktime. -/
theorem realCheckerOf_env_lockTime (tx : Tx) (nIn : Nat) (amount : Amount) :
    (realCheckerOf tx nIn amount).env.txLockTime = tx.locktime := rfl

/-- The locktime environment is projected from the tx (IC-2): input
`nIn`'s nSequence (with the inhabited stand-in for out-of-range inputs,
which real transactions never hit). -/
theorem realCheckerOf_env_sequence (tx : Tx) (nIn : Nat) (amount : Amount) :
    (realCheckerOf tx nIn amount).env.txSequence
      = (tx.vin.getD nIn Bitcoin.Capstone.RealChecker.dummyTxIn).sequence := rfl

/-- In range, the environment's nSequence is the REAL input's
(`vin[nIn]`), the stand-in being unreachable. -/
theorem realCheckerOf_env_sequence_inRange (tx : Tx) (nIn : Nat) (amount : Amount)
    (h : nIn < tx.vin.length) :
    (realCheckerOf tx nIn amount).env.txSequence = (tx.vin[nIn]'h).sequence := by
  unfold realCheckerOf
  rw [getD_eq_get h]

/-- **The Review-3 slot is fail-closed**: through the capstone wiring, NO
Schnorr signature can ever verify (`checkSchnorrSignature ≡ false`) —
this is precisely why W17 routes v1-witness inputs to the unjudged lane
instead of letting them fail. -/
theorem realCheckerOf_schnorr_failclosed (tx : Tx) (nIn : Nat) (amount : Amount)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    (realCheckerOf tx nIn amount).base.checkSchnorrSignature sig pk v d = false := rfl

/-- The frozen seam's execdata-inertness contract survives the wiring: the
real checker's ECDSA verdict cannot depend on the `ScriptExecutionData`
(ThreadValidationData) the interpreter happens to hold. -/
theorem realCheckerOf_ecdsa_execData_indep (tx : Tx) (nIn : Nat) (amount : Amount)
    (sig pk code : ByteArray) (v : SigVersion) (d₁ d₂ : ScriptExecutionData) :
    (realCheckerOf tx nIn amount).base.checkECDSASignature sig pk code v d₁
      = (realCheckerOf tx nIn amount).base.checkECDSASignature sig pk code v d₂ :=
  ecdsaEntry_execData_independent verifyImpl (sighashDispatch tx nIn amount) true
    sig pk code v d₁ d₂

/-- The ECDSA entry point of the real checker, fully unfolded: W14b's
`verifyImpl` behind W13's `ecdsaVerdict` gates, on W11's dispatched
sighash, with `hasAmount = true`. -/
theorem realCheckerOf_ecdsa_def (tx : Tx) (nIn : Nat) (amount : Amount)
    (sig pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    (realCheckerOf tx nIn amount).base.checkECDSASignature sig pk code v d
      = ecdsaVerdict verifyImpl (sighashDispatch tx nIn amount) true v sig pk code := rfl

/-- W11 dispatch, witness lane: `WITNESS_V0 → SignatureHashBIP143`
(interpreter.cpp:1718-1722), amount-carrying. -/
theorem sighashDispatch_witnessV0 (tx : Tx) (nIn : Nat) (amount : Amount)
    (code : ByteArray) (ht : UInt8) :
    sighashDispatch tx nIn amount code ht SigVersion.witnessV0
      = signatureHashBip143 tx nIn ⟨code⟩ (htToU32 ht) amount := rfl

/-- W11 dispatch, legacy lane: every non-witness sigversion uses the
legacy `SignatureHash`. -/
theorem sighashDispatch_legacy (tx : Tx) (nIn : Nat) (amount : Amount)
    (code : ByteArray) (ht : UInt8) (v : SigVersion) (hv : v ≠ SigVersion.witnessV0) :
    sighashDispatch tx nIn amount code ht v
      = signatureHashLegacy tx nIn ⟨code⟩ (htToU32 ht) := by
  unfold sighashDispatch
  cases v with
  | base => rfl
  | witnessV0 => exact absurd rfl hv
  | taproot => rfl
  | tapscript => rfl

/-- **SWT-053 through the real wiring**: for a well-formed call (valid
pubkey, nonempty signature) the real checker hands W14b's `verifyImpl`
EXACTLY `sig` minus its trailing hashtype byte, hashed with W11's
dispatch on exactly the popped byte (interpreter.cpp:1707-1712). -/
theorem realCheckerOf_ecdsa_pops_hashtype (tx : Tx) (nIn : Nat) (amount : Amount)
    (sig pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hpk : isValidPubKey pk = true) (hne : 0 < sig.size) :
    (realCheckerOf tx nIn amount).base.checkECDSASignature sig pk code v d
      = verifyImpl (sig.extract 0 (sig.size - 1)) pk
          (sighashDispatch tx nIn amount code sig[sig.size - 1]! v) :=
  ecdsaEntry_pops_hashtype verifyImpl (sighashDispatch tx nIn amount) true
    sig pk code v d hpk hne (fun _ => rfl)

/-- **SWT-054 through the real wiring**: an empty signature fails closed
before any EC math — W14b's verifier is never reached. -/
theorem realCheckerOf_ecdsa_empty_sig_false (tx : Tx) (nIn : Nat) (amount : Amount)
    (pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    (realCheckerOf tx nIn amount).base.checkECDSASignature
      ByteArray.empty pk code v d = false :=
  ecdsaEntry_empty_sig_false verifyImpl (sighashDispatch tx nIn amount) true pk code v d

/-- **SWT-055 is dead for anchor runs**: the wiring sets `hasAmount = true`
(the Capstone ledger always supplies the spent coin), so a WITNESS_V0
sighash never fails on missing amount data — the verdict goes through to
the real EC math over BIP143's amount-carrying digest. -/
theorem realCheckerOf_ecdsa_witnessV0_hasAmount (tx : Tx) (nIn : Nat) (amount : Amount)
    (sig pk code : ByteArray) (d : ScriptExecutionData)
    (hpk : isValidPubKey pk = true) (hne : 0 < sig.size) :
    (realCheckerOf tx nIn amount).base.checkECDSASignature
        sig pk code SigVersion.witnessV0 d
      = verifyImpl (sig.extract 0 (sig.size - 1)) pk
          (signatureHashBip143 tx nIn ⟨code⟩ (htToU32 sig[sig.size - 1]!) amount) := by
  rw [realCheckerOf_ecdsa_pops_hashtype tx nIn amount sig pk code _ d hpk hne,
      sighashDispatch_witnessV0]

/-! ## The fuel budget -/

/-- **Fuel bound** (arithmetic layer): `verifyInput`'s fuel is
`ss.size + spk.size + witness bytes + 10`; the scriptSig bytes, the
scriptPubKey bytes, and their total are each covered by the budget. Since
every opcode consumes at least one wire byte, `ss.size + spk.size`
opcodes of work are already paid for, and the `+10` shell covers the
constant-frame overhead before the witness slack is touched. -/
theorem fuel_bound (ss spk : ByteArray) (w : WitnessStack) :
    ss.size ≤ ss.size + spk.size + ((w.map (·.size)).foldl Nat.add 0) + 10 ∧
    spk.size ≤ ss.size + spk.size + ((w.map (·.size)).foldl Nat.add 0) + 10 ∧
    ss.size + spk.size ≤ ss.size + spk.size + ((w.map (·.size)).foldl Nat.add 0) + 10 := by
  omega

/-- Each witness stack item's byte size is covered by the fuel: the
witness slack `Σ item.size` dominates any single item. -/
private theorem le_foldl_add_init : ∀ (m : List Nat) (init : Nat),
    init ≤ m.foldl Nat.add init
  | [], _ => Nat.le_refl _
  | x :: xs, init => by
      rw [List.foldl_cons]
      exact Nat.le_trans (Nat.le_add_right init x) (le_foldl_add_init xs (init + x))

/-- `List.foldl Nat.add` is monotone in its accumulator. -/
private theorem foldl_add_mono : ∀ (m : List Nat) (a c : Nat), a ≤ c →
    m.foldl Nat.add a ≤ m.foldl Nat.add c
  | [], _, _, h => h
  | x :: xs, a, c, h => by
      rw [List.foldl_cons, List.foldl_cons]
      exact foldl_add_mono xs (a + x) (c + x) (by omega)

theorem fuel_bound_witness_item (ss spk : ByteArray) (w : WitnessStack) (b : ByteArray)
    (hb : b ∈ w) :
    b.size ≤ ss.size + spk.size + ((w.map (·.size)).foldl Nat.add 0) + 10 := by
  have h1 : b.size ≤ (w.map (·.size)).foldl Nat.add 0 := by
    induction w generalizing b with
    | nil => simp at hb
    | cons x xs ih =>
        rcases List.mem_cons.1 hb with rfl | hb'
        · simp only [List.map_cons, List.foldl_cons]
          calc b.size ≤ 0 + b.size := Nat.le_add_left _ _
            _ ≤ (xs.map (fun x => x.size)).foldl Nat.add (0 + b.size) :=
                  le_foldl_add_init _ _
        · simp only [List.map_cons, List.foldl_cons]
          have h2 := ih b hb'
          have h3 := foldl_add_mono (xs.map (fun x => x.size)) 0 (0 + x.size)
            (Nat.le_add_left _ _)
          exact Nat.le_trans h2 h3
  omega

end BitcoinProofs.Theorems.CapstoneWiring
