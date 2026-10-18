import Bitcoin.Capstone.Block

/-!
# Capstone checker wiring

Every input now passes through ordinary script/witness verification with the
typed production checker. The three former universal bypass theorems
`verifyInput_taproot_lane`, `verifyInput_taproot_not_pass` and
`verifyInput_taproot_not_fail` were false after that repair and are removed.
The historical witness recognizer facts remain mathematical facts only.

The module proves error shape, totality, exact dispatch/fuel wiring and the
legacy/ECDSA compatibility adapter contracts. The latter describe
`realCheckerOf`; production extends that adapter with typed real Schnorr
verification in `realCheckerWithTaproot`. Cache completeness and public
script adjudication status are proved in CapstoneTaproot and Block.
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

/-- The gate is exactly "witness program with version ≥ 1"; a non-witness
scriptPubKey is not recognized by this historical helper. -/
theorem isTaprootProgram_none_false (spk : ByteArray)
    (h : isWitnessProgram spk = none) :
    isTaprootProgram spk = false := by
  unfold isTaprootProgram
  rw [h]

/-- **SCR-053 corollary**: a v0 witness program is not a Taproot program —
v0 P2WPKH/P2WSH coins stay on the fully-adjudicated path. -/
theorem isTaprootProgram_v0_false (spk prog : ByteArray)
    (h : isWitnessProgram spk = some (0, prog)) :
    isTaprootProgram spk = false := by
  unfold isTaprootProgram
  rw [h]; rfl

/-- The positive direction of the gate: any witness version ≥ 1 (v1 =
Taproot key/script path; higher = upgradable) satisfies this recognizer. -/
theorem isTaprootProgram_ge1_true (spk prog : ByteArray) (v : Nat)
    (hv : 1 ≤ v) (h : isWitnessProgram spk = some (v, prog)) :
    isTaprootProgram spk = true := by
  unfold isTaprootProgram
  rw [h]
  exact decide_eq_true hv

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
(every real input is — the module checks vin indices): away from the lane
gate, `verifyInput` is literally a three-way match on `verifyScriptFull`
at the documented fuel (`ss.size + spk.size + witness bytes + 10`),
`getBlockScriptFlags`, default policy, and the REAL checker wiring
(adapter × `verifyImpl` × dispatch). -/
theorem verifyInput_dispatch (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat)
    (hlen : i < tx.vin.length) :
    verifyInput height tx i coin txIdx inputIdx =
      match verifyScriptFull
        ((tx.vin[i]'hlen).scriptSig.bytes.size + coin.scriptPubKey.bytes.size
          + ((witnessAt tx i).map (·.size)).foldl Nat.add 0 + 10)
        (getBlockScriptFlags height) default
        ((tx.vin[i]'hlen).scriptSig.bytes) (coin.scriptPubKey.bytes)
        (witnessAt tx i) (realCheckerWithTaproot tx i coin.value none) with
      | .ok => InputVerdict.pass
      | .unjudged => InputVerdict.unjudgedTaproot
      | .fail e => InputVerdict.fail (CapError.scriptFail txIdx inputIdx e) := by
  unfold verifyInput
  rw [getD_eq_get hlen]
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

/-- **The slot is fail-closed**: through the capstone wiring, NO
Schnorr signature can ever verify (`checkSchnorrSignature ≡ false`) —
this is precisely why routes v1-witness inputs to the unjudged lane
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

/-- The ECDSA entry point of the real checker, fully unfolded:
`verifyImpl` behind `ecdsaVerdict` gates, on dispatched
sighash, with `hasAmount = true`. -/
theorem realCheckerOf_ecdsa_def (tx : Tx) (nIn : Nat) (amount : Amount)
    (sig pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    (realCheckerOf tx nIn amount).base.checkECDSASignature sig pk code v d
      = ecdsaVerdict verifyImpl (sighashDispatch tx nIn amount) true v sig pk code := rfl

/-- dispatch, witness lane: `WITNESS_V0 → SignatureHashBIP143`
(interpreter.cpp:1718-1722), amount-carrying. -/
theorem sighashDispatch_witnessV0 (tx : Tx) (nIn : Nat) (amount : Amount)
    (code : ByteArray) (ht : UInt8) :
    sighashDispatch tx nIn amount code ht SigVersion.witnessV0
      = signatureHashBip143 tx nIn ⟨code⟩ (htToU32 ht) amount := rfl

/-- dispatch, legacy lane: every non-witness sigversion uses the
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
pubkey, nonempty signature) the real checker hands `verifyImpl`
EXACTLY `sig` minus its trailing hashtype byte, hashed with
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
before any EC math — verifier is never reached. -/
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
