import BitcoinProofs.Theorems.CapstonePipelineCor
import BitcoinProofs.Theorems.T3T4RealCheckerCor

/-!
# BitcoinProofs.Theorems.T3T4PipelineRealCor — THM-036/037/044/045
# Auth-side + pipeline determinism

This module gives the
InputAuth-REAL instantiation of the C4 conservation tier's Auth rows
(THM-037/044/045 — the inversion P13/P15 hypothesize) plus the
real-pipeline determinism half of THM-051, over `validateBlock`
(decode → BLK structure → PoW/merkle → the script
layer → fold).

## What this module proves (C1–C5)

* **C3 (verifyInput inversion/determinism)** — `verifyInput_eq` the
  exact unfolding; `verifyInput_pass_inv` / `verifyInput_fail_inv` /
  `verifyInput_unjudged_inv`: the three verdict constructors invert to
  (gate, `verifyScriptFull`-at-`realCheckerOf`) facts — `.pass`
  inverts to `verifyScriptFull … (realCheckerOf tx i coin.value) = .ok`
  with the taproot-program gate FALSE (the unjudged lane is routed
  upstream of the checker); `.fail` inverts to a
  `CapError.scriptFail txIdx inputIdx e'` wrapping; purity congruences
  for the whole ladder (`verifyInput_pure` … `validateBlock_pure`).
* **C1 (per-tx inversion)** — `applyTx_ok_noncb`: one non-coinbase
  `applyTx` success inverts to (stateless gate none, `verifyTxInputs`
  ok, fold step ok); `applyTxs_ok_verifyTxInputs_each`: the whole
  fold's success inverts PER TX (by position) to its
  `verifyTxInputs` ok against the intermediate UTXO view the tx
  actually saw; `validateBlock_ok_verifyTxInputs_each` threads it
  through P16's `validateBlock_ok_shape`.
* **C4 (InputAuth-real, the headline)** —
  `verifyTxInputs_loop_fail_not_ok` / `verifyTxInputs_ok_no_fail`:
  a `verifyTxInputs` ok means NO input the loop reached was
  adjudicated `.fail`; `validateBlock_ok_input_no_fail` and
  `validateBlock_ok_inputAuth_real`: `validateBlock`-ok ⇒ every decoded
  non-coinbase tx's every (prefix-reachable, coin-present) input was
  adjudicated `.pass` or `.unjudgedTaproot`, and every `.pass` ran
  `verifyScriptFull` to `.ok` at the REAL checker (`realCheckerOf` =
  lax-ECDSA × sighash × real locktime env). This instantiates
  the C4 `InputAuth` abstraction of THM-037/044/045 with "the real
  seam checker accepted".
* **C5 (the honest X03/X04 corner, at the pipeline)** —
  `validateBlock_ok_pass_noninterference`: every adjudicated pass has
  the SAME verdict under X02's both-entries assembly
  (`realCheckerFullOf`) — X02-non-interference lifted from the checker
  (Module A A6) to the block pipeline;
  `validateBlock_ok_schnorr_lane_blind`: the checker bound at every
  adjudicated input has a constantly-`false` Schnorr verdict function —
  NO BIP340 acceptance occurs anywhere in a validated block (no false
  accepts; Taproot inputs take the `unjudgedTaproot` lane upstream).
  STATE NOTE (2026-10-16): X03's BIP341 sighash
  (`Bitcoin.Crypto.Taproot.Sighash.sighashTaproot`, commits
  e904215..1375215) has since landed sorry-free — the remaining
  blocker for real Schnorr adjudication is only the one-parameter
  wiring flip of `sighashSchnorr` in `Capstone/RealChecker.lean`
  (X04's lane). C5b pins the CURRENT (pre-flip) state; at the flip C5b
  (and Module A's A4) are the documented revisit set.

## Statement-fidelity notes (sanctioned path, report §5)

* **The missing-coin early stop.** `verifyTxInputs`' loop TERMINATES
  with `.ok` at the first input whose coin is missing from the view
  (`coinLookup = none`; the HaveInputs error is the module's lane). A
  `.fail` verdict at input k is therefore compatible with an `.ok`
  loop result whenever the loop stopped BEFORE k — the honest
  per-input statement carries the prefix condition "every input ≤ k
  was coin-present" (C4's `hpred`), which exactly excludes the early
  stop. The naive "validateBlock-ok ⇒ every input adjudicated
  non-fail" is FALSE as stated without that corner.
* **The taproot lane is unjudged, not accepted.** `.pass` implies the
  v1-witness-program gate is false; `scriptUnjudged` counts the
  unjudged lane (P16's counter bound). No theorem here claims Taproot
  inputs were verified.
* **reduction discipline** (inherited): no theorem here kernel-decides
  through the EC layer; every EC-fact is a congruence or an inversion
  of the pipeline's own structure. `checkTransaction`, `applyTxStepL`,
  the PoW/merkle gates are treated as fixed opaque checks.
-/

namespace BitcoinProofs.Theorems.T3T4PipelineRealCor

open Bitcoin.Capstone.Block Bitcoin.Capstone.RealChecker
open Bitcoin.Data Bitcoin.Ledger Bitcoin.Consensus Bitcoin.Interpreter
open Bitcoin.Activation Bitcoin.Serialization
open BitcoinProofs.Theorems.CapstonePipeline
  (validateBlock_ok_shape applyTx_eq applyTxCont ebind_ok ebind_err ethrow epure_ok)
open BitcoinProofs.Theorems.T3T4RealCheckerCor
  (verifyScriptFull_realCheckerFullOf_eq_realCheckerOf
   realCheckerOf_schnorr_is_const_false)

/-! ## C3 — the per-input verdict layer -/

/-- **C3-0 — the exact unfolding of `verifyInput`**: the taproot-program
route, else the one `verifyScriptFull` call at the REAL checker with
the fuel/flags/witness dataflow spelled out. All C3 inversions reduce
to case analysis on this equation. -/
theorem verifyInput_eq (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat) :
    verifyInput height tx i coin txIdx inputIdx =
      if isTaprootProgram coin.scriptPubKey.bytes then InputVerdict.unjudgedTaproot
      else
        match verifyScriptFull
          ((tx.vin.getD i dummyTxIn).scriptSig.bytes.size + coin.scriptPubKey.bytes.size
            + ((witnessAt tx i).map (·.size)).foldl Nat.add 0 + 10)
          (getBlockScriptFlags height) default
          (tx.vin.getD i dummyTxIn).scriptSig.bytes coin.scriptPubKey.bytes
          (witnessAt tx i) (realCheckerOf tx i coin.value) with
        | .ok => InputVerdict.pass
        | .unjudged => InputVerdict.unjudgedTaproot
        | .fail e => InputVerdict.fail (CapError.scriptFail txIdx inputIdx e) := by
  rfl

/-- **C3a — `.pass` inversion**: an adjudicated PASS means the
taproot-program gate is FALSE and the REAL checker's `verifyScriptFull`
(witnessV0/base lanes: interpreter × lax-ECDSA × sighash ×
real locktime env) returned `.ok` on exactly this input's dataflow. -/
theorem verifyInput_pass_inv (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat)
    (h : verifyInput height tx i coin txIdx inputIdx = InputVerdict.pass) :
    isTaprootProgram coin.scriptPubKey.bytes = false ∧
    verifyScriptFull
      ((tx.vin.getD i dummyTxIn).scriptSig.bytes.size + coin.scriptPubKey.bytes.size
        + ((witnessAt tx i).map (·.size)).foldl Nat.add 0 + 10)
      (getBlockScriptFlags height) default
      (tx.vin.getD i dummyTxIn).scriptSig.bytes coin.scriptPubKey.bytes
      (witnessAt tx i) (realCheckerOf tx i coin.value) = VerifyOutcome.ok := by
  rw [verifyInput_eq] at h
  split at h
  · simp at h
  · rename_i hc
    split at h
    · rename_i hv
      refine ⟨?_, hv⟩
      simp at hc
      exact hc
    · simp at h
    · simp at h

/-- **C3b — `.fail` inversion**: an adjudicated FAIL is exactly a
`CapError.scriptFail txIdx inputIdx e'` wrapping of a `verifyScriptFull`
`.fail e'` at the REAL checker, with the taproot-program gate false. -/
theorem verifyInput_fail_inv (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat) (e : CapError)
    (h : verifyInput height tx i coin txIdx inputIdx = InputVerdict.fail e) :
    isTaprootProgram coin.scriptPubKey.bytes = false ∧
    ∃ e' : ExecError, e = CapError.scriptFail txIdx inputIdx e' ∧
      verifyScriptFull
        ((tx.vin.getD i dummyTxIn).scriptSig.bytes.size + coin.scriptPubKey.bytes.size
          + ((witnessAt tx i).map (·.size)).foldl Nat.add 0 + 10)
        (getBlockScriptFlags height) default
        (tx.vin.getD i dummyTxIn).scriptSig.bytes coin.scriptPubKey.bytes
        (witnessAt tx i) (realCheckerOf tx i coin.value) = VerifyOutcome.fail e' := by
  rw [verifyInput_eq] at h
  split at h
  · simp at h
  · rename_i hc
    split at h
    · simp at h
    · simp at h
    · rename_i e' hv
      refine ⟨by simp at hc; exact hc, e', ?_, hv⟩
      exact (InputVerdict.fail.inj h).symm

/-- **C3c — `.unjudgedTaproot` inversion**: the unjudged verdict is
either the v1-witness-program route (BEFORE any checker call) or a
`.unjudged` `verifyScriptFull` outcome at the REAL checker. -/
theorem verifyInput_unjudged_inv (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat)
    (h : verifyInput height tx i coin txIdx inputIdx = InputVerdict.unjudgedTaproot) :
    isTaprootProgram coin.scriptPubKey.bytes = true ∨
    verifyScriptFull
      ((tx.vin.getD i dummyTxIn).scriptSig.bytes.size + coin.scriptPubKey.bytes.size
        + ((witnessAt tx i).map (·.size)).foldl Nat.add 0 + 10)
      (getBlockScriptFlags height) default
      (tx.vin.getD i dummyTxIn).scriptSig.bytes coin.scriptPubKey.bytes
      (witnessAt tx i) (realCheckerOf tx i coin.value) = VerifyOutcome.unjudged := by
  rw [verifyInput_eq] at h
  split at h
  · rename_i hc
    exact Or.inl hc
  · rename_i hc
    split at h
    · simp at h
    · rename_i hv
      exact Or.inr hv
    · simp at h

/-! ## C2 — pipeline determinism (purity congruences) -/

/-- **C2a**: `verifyInput` is a pure function of its six declared
arguments (no hidden state — the checker, flags and fuel are all
derived from the same arguments). -/
theorem verifyInput_pure (height₁ height₂ : UInt32) (tx₁ tx₂ : Tx) (i₁ i₂ : Nat)
    (coin₁ coin₂ : Coin) (txIdx₁ txIdx₂ inputIdx₁ inputIdx₂ : Nat)
    (h1 : height₁ = height₂) (h2 : tx₁ = tx₂) (h3 : i₁ = i₂)
    (h4 : coin₁ = coin₂) (h5 : txIdx₁ = txIdx₂) (h6 : inputIdx₁ = inputIdx₂) :
    verifyInput height₁ tx₁ i₁ coin₁ txIdx₁ inputIdx₁
      = verifyInput height₂ tx₂ i₂ coin₂ txIdx₂ inputIdx₂ := by
  subst h1; subst h2; subst h3; subst h4; subst h5; subst h6; rfl

/-- **C2b**: `verifyTxInputs` is a pure function of
(height, tx, txIdx, utxo view). -/
theorem verifyTxInputs_pure (height₁ height₂ : UInt32) (tx₁ tx₂ : Tx)
    (txIdx₁ txIdx₂ : Nat) (u₁ u₂ : List (OutPoint × Coin))
    (h1 : height₁ = height₂) (h2 : tx₁ = tx₂) (h3 : txIdx₁ = txIdx₂)
    (h4 : u₁ = u₂) :
    verifyTxInputs height₁ tx₁ txIdx₁ u₁
      = verifyTxInputs height₂ tx₂ txIdx₂ u₂ := by
  subst h1; subst h2; subst h3; subst h4; rfl

/-- **C2c**: `applyTxs` is a pure function of its six declared
arguments (the fold state is threaded explicitly). -/
theorem applyTxs_pure (height₁ height₂ : UInt32) (txs₁ txs₂ : List Tx)
    (i₁ i₂ : Nat) (l₁ l₂ : List (OutPoint × Coin)) (okN₁ okN₂ unjN₁ unjN₂ : Nat)
    (h1 : height₁ = height₂) (h2 : txs₁ = txs₂) (h3 : i₁ = i₂)
    (h4 : l₁ = l₂) (h5 : okN₁ = okN₂) (h6 : unjN₁ = unjN₂) :
    applyTxs height₁ txs₁ i₁ l₁ okN₁ unjN₁
      = applyTxs height₂ txs₂ i₂ l₂ okN₂ unjN₂ := by
  subst h1; subst h2; subst h3; subst h4; subst h5; subst h6; rfl

/-- **C2d — end-to-end**: `validateBlock` is a pure function of
(raw bytes, chain state) — decode → structure → header → merkle →
script fold, no hidden state anywhere in the pipeline. -/
theorem validateBlock_pure (raw₁ raw₂ : ByteArray) (st₁ st₂ : CapState)
    (hr : raw₁ = raw₂) (hs : st₁ = st₂) :
    validateBlock raw₁ st₁ = validateBlock raw₂ st₂ := by
  subst hr; subst hs; rfl

/-! ## C1 — per-tx ok-inversion -/

/-- **C1a**: one non-coinbase `applyTx` success inverts to the full
three-layer contract: the stateless gate passed
(`checkTransaction = none`), the script layer passed
(`verifyTxInputs = .ok` with exactly the returned counters), and the
fold step succeeded with exactly the returned utxo. -/
theorem applyTx_ok_noncb (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l l' : List (OutPoint × Coin)) (a b : Nat)
    (hcb : tx.isCoinBase = false)
    (h : applyTx height tx txIdx l = .ok (l', a, b)) :
    checkTransaction tx = none ∧
    verifyTxInputs height tx txIdx l = .ok (a, b) ∧
    applyTxStepL l tx (txidKey tx) height = .ok l' := by
  have hi := BitcoinProofs.Theorems.CapstoneFold.applyTx_ok_inv h
  rcases hi.2.1 with ⟨hc, _, _⟩ | ⟨_, _, hv⟩
  · simp [hcb] at hc
  · exact ⟨hi.1, hv, hi.2.2⟩

/-- **C1b**: the whole fold's success inverts PER TX (by list
position): every non-coinbase tx of the list ran its `verifyTxInputs`
to `.ok` against SOME utxo view — namely the intermediate fold state
that tx actually saw (tx i+1 sees the utxo after tx i, B3's same-block
spend ordering). -/
theorem applyTxs_ok_verifyTxInputs_each (height : UInt32) :
    ∀ (txs : List Tx) (i : Nat) (l : List (OutPoint × Coin)) (okN unjN : Nat)
      (l' : List (OutPoint × Coin)) (okN' unjN' : Nat),
      applyTxs height txs i l okN unjN = .ok (l', okN', unjN') →
      ∀ (j : Nat) (tx : Tx), txs[j]? = some tx → tx.isCoinBase = false →
      ∃ (l₁ : List (OutPoint × Coin)) (a b : Nat),
        checkTransaction tx = none ∧
        verifyTxInputs height tx (i + j) l₁ = .ok (a, b) := by
  intro txs
  induction txs with
  | nil =>
      intro i l okN unjN l' okN' unjN' h j tx hj
      simp at hj
  | cons tx rest ih =>
      intro i l okN unjN l' okN' unjN'
      simp only [applyTxs]
      cases hax : applyTx height tx i l with
      | error e =>
          intro h; simp at h
      | ok p =>
          obtain ⟨l'', a, b⟩ := p
          intro h j tx0 hj hcb
          simp only [ebind_ok] at h
          cases j with
          | zero =>
              simp at hj
              subst hj
              obtain ⟨hchk, hv, _⟩ := applyTx_ok_noncb height tx i l l'' a b hcb hax
              exact ⟨l, a, b, hchk, hv⟩
          | succ m =>
              simp at hj
              obtain ⟨l₁, a', b', hchk, hv⟩ :=
                ih (i + 1) l'' (okN + a) (unjN + b) l' okN' unjN' h m tx0 hj hcb
              have hidx : i + (m + 1) = i + 1 + m := by omega
              exact ⟨l₁, a', b', hchk, by rw [hidx]; exact hv⟩

/-- **C1c**: threaded through P16's poststate contract —
`validateBlock`-ok inverts, per decoded non-coinbase tx (by position),
to its `verifyTxInputs = .ok` against the intermediate utxo view, and
its stateless gate passing. -/
theorem validateBlock_ok_verifyTxInputs_each (raw : ByteArray) (st : CapState)
    (r : CapReport) (hval : validateBlock raw st = .ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx),
      decodeBlock raw = .ok (bh, txs) ∧
      ∀ (j : Nat) (tx : Tx), txs[j]? = some tx → tx.isCoinBase = false →
      ∃ (l₁ : List (OutPoint × Coin)) (a b : Nat),
        checkTransaction tx = none ∧
        verifyTxInputs st.height tx j l₁ = .ok (a, b) := by
  obtain ⟨bh, txs, u', k0, j0, hdec, _, _, _, _, _, _, _, _, hfold, _, _, _, _⟩ :=
    validateBlock_ok_shape raw st r hval
  refine ⟨bh, txs, hdec, ?_⟩
  intro j tx hj hcb
  obtain ⟨l₁, a, b, hchk, hv⟩ :=
    applyTxs_ok_verifyTxInputs_each st.height txs 0 st.utxo 0 0 u' k0 j0 hfold
      j tx hj hcb
  rw [Nat.zero_add] at hv
  exact ⟨l₁, a, b, hchk, hv⟩

/-! ## C4 — InputAuth-real: no adjudicated fail in a validated block -/

/-- **C4-0 (loop contrapositive)**: if input `k` of `tx` (with `k`
at distance `d` ahead of the loop cursor `i`) carries an adjudicated
`.fail` verdict, its coin is present at `k`, and every input from `i`
to `k` is coin-present in the view (the prefix condition — see the
statement-fidelity note: it exactly excludes the loop's missing-coin
early stop), then the loop from `i` CANNOT return `.ok`. -/
theorem verifyTxInputs_loop_fail_not_ok (height : UInt32) (tx : Tx) (txIdx : Nat)
    (u : List (OutPoint × Coin)) (k : Nat) (coin : Coin) (e : CapError) :
    ∀ (d i okN unjN : Nat), i + d = k → k < tx.vin.length →
      (∀ j, i ≤ j → j ≤ k →
        (coinLookup u (tx.vin.getD j dummyTxIn).prevout).isSome = true) →
      coinLookup u (tx.vin.getD k dummyTxIn).prevout = some coin →
      verifyInput height tx k coin txIdx k = InputVerdict.fail e →
      ∀ (a b : Nat), verifyTxInputs.loop height tx txIdx u i okN unjN ≠ .ok (a, b) := by
  intro d
  induction d with
  | zero =>
      intro i okN unjN hid hk hp hcoin hv a b hloop
      have hki : k = i := by omega
      subst hki
      rw [verifyTxInputs.loop.eq_1] at hloop
      split at hloop
      · omega
      · dsimp only at hloop
        split at hloop
        · rename_i hcl
          have hc2 : coinLookup u (tx.vin.getD k dummyTxIn).prevout = none := hcl
          have hsome := hp k (Nat.le_refl k) (Nat.le_refl k)
          rw [hc2] at hsome
          simp at hsome
        · rename_i c hcl
          have hc2 : coinLookup u (tx.vin.getD k dummyTxIn).prevout = some c := hcl
          rw [hc2] at hcoin
          have hcc : coin = c := (Option.some.inj hcoin).symm
          subst hcc
          split at hloop
          · rename_i hv'
            rw [hv] at hv'
            simp at hv'
          · rename_i hv'
            rw [hv] at hv'
            simp at hv'
          · simp at hloop
  | succ m ih =>
      intro i okN unjN hid hk hp hcoin hv a b hloop
      rw [verifyTxInputs.loop.eq_1] at hloop
      split at hloop
      · omega
      · dsimp only at hloop
        split at hloop
        · rename_i hcl
          have hc2 : coinLookup u (tx.vin.getD i dummyTxIn).prevout = none := hcl
          have hsome := hp i (Nat.le_refl i) (by omega)
          rw [hc2] at hsome
          simp at hsome
        · rename_i c hcl
          split at hloop
          · exact ih (i + 1) (okN + 1) unjN (by omega) hk
              (fun j hj1 hj2 => hp j (by omega) hj2) hcoin hv a b hloop
          · exact ih (i + 1) okN (unjN + 1) (by omega) hk
              (fun j hj1 hj2 => hp j (by omega) hj2) hcoin hv a b hloop
          · simp at hloop

/-- **C4a**: `verifyTxInputs` ok means NO coin-present,
prefix-reachable input of the tx was adjudicated `.fail` — every
reached input got `.pass` (real-checker accept) or `.unjudgedTaproot`
(the honest Taproot lane). -/
theorem verifyTxInputs_ok_no_fail (height : UInt32) (tx : Tx) (txIdx : Nat)
    (u : List (OutPoint × Coin)) (a b : Nat)
    (h : verifyTxInputs height tx txIdx u = .ok (a, b)) :
    ∀ (k : Nat) (coin : Coin) (e : CapError), k < tx.vin.length →
      (∀ j, j ≤ k → (coinLookup u (tx.vin.getD j dummyTxIn).prevout).isSome = true) →
      coinLookup u (tx.vin.getD k dummyTxIn).prevout = some coin →
      verifyInput height tx k coin txIdx k ≠ InputVerdict.fail e := by
  intro k coin e hk hp hcoin hv
  have h0 : verifyTxInputs height tx txIdx u
      = verifyTxInputs.loop height tx txIdx u 0 0 0 := rfl
  rw [h0] at h
  exact verifyTxInputs_loop_fail_not_ok height tx txIdx u k coin e k 0 0 0
    (by omega) hk (fun j _ hj => hp j hj) hcoin hv a b h

/-- **C4b**: `validateBlock`-ok inverts, per decoded non-coinbase tx
and per coin-present prefix-reachable input, to "NOT adjudicated fail"
— the Auth-side half of the THM-037/044/045 inversion (an inversion
P13/P15 hypothesize), with the missing-coin corner honestly separated
by the prefix condition. -/
theorem validateBlock_ok_input_no_fail (raw : ByteArray) (st : CapState)
    (r : CapReport) (hval : validateBlock raw st = .ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx),
      decodeBlock raw = .ok (bh, txs) ∧
      ∀ (j : Nat) (tx : Tx), txs[j]? = some tx → tx.isCoinBase = false →
      ∃ (l₁ : List (OutPoint × Coin)) (a b : Nat),
        verifyTxInputs st.height tx j l₁ = .ok (a, b) ∧
        ∀ (k : Nat) (coin : Coin) (e : CapError), k < tx.vin.length →
          (∀ j', j' ≤ k →
            (coinLookup l₁ (tx.vin.getD j' dummyTxIn).prevout).isSome = true) →
          coinLookup l₁ (tx.vin.getD k dummyTxIn).prevout = some coin →
          verifyInput st.height tx k coin j k ≠ InputVerdict.fail e := by
  obtain ⟨bh, txs, hdec, hall⟩ := validateBlock_ok_verifyTxInputs_each raw st r hval
  refine ⟨bh, txs, hdec, ?_⟩
  intro j tx hj hcb
  obtain ⟨l₁, a, b, _, hv⟩ := hall j tx hj hcb
  exact ⟨l₁, a, b, hv,
    fun k coin e hk hp hcoin => verifyTxInputs_ok_no_fail st.height tx j l₁ a b hv
      k coin e hk hp hcoin⟩

/-- **C4c — THE InputAuth-REAL INSTANTIATION (headline)**:
`validateBlock`-ok ⇒ every decoded non-coinbase tx's every
(prefix-reachable, coin-present) input that was adjudicated `.pass`
ran `verifyScriptFull` to `.ok` at the REAL checker —
interpreter under `realCheckerOf` (lax-ECDSA × sighash × the
real locktime environment), on exactly this input's fuel/flags/witness
dataflow, with the taproot-program gate false. The C4 conservation
tier's abstract `InputAuth` is thereby instantiated by "the REAL seam
checker accepted", with the unjudged Taproot lane honestly separated
(C4b's `.pass ∨ .unjudgedTaproot`). -/
theorem validateBlock_ok_inputAuth_real (raw : ByteArray) (st : CapState)
    (r : CapReport) (hval : validateBlock raw st = .ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx),
      decodeBlock raw = .ok (bh, txs) ∧
      ∀ (j : Nat) (tx : Tx), txs[j]? = some tx → tx.isCoinBase = false →
      ∃ (l₁ : List (OutPoint × Coin)) (a b : Nat),
        verifyTxInputs st.height tx j l₁ = .ok (a, b) ∧
        ∀ (k : Nat) (coin : Coin), k < tx.vin.length →
          (∀ j', j' ≤ k →
            (coinLookup l₁ (tx.vin.getD j' dummyTxIn).prevout).isSome = true) →
          coinLookup l₁ (tx.vin.getD k dummyTxIn).prevout = some coin →
          verifyInput st.height tx k coin j k = InputVerdict.pass →
          isTaprootProgram coin.scriptPubKey.bytes = false ∧
          verifyScriptFull
            ((tx.vin.getD k dummyTxIn).scriptSig.bytes.size
              + coin.scriptPubKey.bytes.size
              + ((witnessAt tx k).map (·.size)).foldl Nat.add 0 + 10)
            (getBlockScriptFlags st.height) default
            (tx.vin.getD k dummyTxIn).scriptSig.bytes coin.scriptPubKey.bytes
            (witnessAt tx k) (realCheckerOf tx k coin.value) = VerifyOutcome.ok := by
  obtain ⟨bh, txs, hdec, hall⟩ := validateBlock_ok_input_no_fail raw st r hval
  refine ⟨bh, txs, hdec, ?_⟩
  intro j tx hj hcb
  obtain ⟨l₁, a, b, hv, hno⟩ := hall j tx hj hcb
  refine ⟨l₁, a, b, hv, fun k coin hk hpred hcoin hpass => ?_⟩
  exact verifyInput_pass_inv st.height tx k coin j k hpass

/-! ## C5 — the honest X03/X04 corner, at the pipeline level -/

/-- **C5a — X02-NON-INTERFERENCE AT THE PIPELINE**: every adjudicated
`.pass` of a validated block has the same `verifyScriptFull` outcome
under X02's both-real-entries assembly `realCheckerFullOf` as under
`realCheckerOf` the pipeline binds — Module A's checker-level
non-interference (A6) lifted to `validateBlock`. X02's Unit-3 Schnorr
wiring changed zero block-level verdicts; the one-parameter
`sighashSchnorr` flip (now unblocked by X03's landed `sighashTaproot`,
e904215) is the single verdict-visible change point of the Taproot
lane. -/
theorem validateBlock_ok_pass_noninterference (raw : ByteArray) (st : CapState)
    (r : CapReport) (hval : validateBlock raw st = .ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx),
      decodeBlock raw = .ok (bh, txs) ∧
      ∀ (j : Nat) (tx : Tx), txs[j]? = some tx → tx.isCoinBase = false →
      ∃ (l₁ : List (OutPoint × Coin)) (a b : Nat),
        verifyTxInputs st.height tx j l₁ = .ok (a, b) ∧
        ∀ (k : Nat) (coin : Coin), k < tx.vin.length →
          (∀ j', j' ≤ k →
            (coinLookup l₁ (tx.vin.getD j' dummyTxIn).prevout).isSome = true) →
          coinLookup l₁ (tx.vin.getD k dummyTxIn).prevout = some coin →
          verifyInput st.height tx k coin j k = InputVerdict.pass →
          verifyScriptFull
            ((tx.vin.getD k dummyTxIn).scriptSig.bytes.size
              + coin.scriptPubKey.bytes.size
              + ((witnessAt tx k).map (·.size)).foldl Nat.add 0 + 10)
            (getBlockScriptFlags st.height) default
            (tx.vin.getD k dummyTxIn).scriptSig.bytes coin.scriptPubKey.bytes
            (witnessAt tx k) (realCheckerFullOf tx k coin.value) = VerifyOutcome.ok := by
  obtain ⟨bh, txs, hdec, hall⟩ := validateBlock_ok_inputAuth_real raw st r hval
  refine ⟨bh, txs, hdec, ?_⟩
  intro j tx hj hcb
  obtain ⟨l₁, a, b, hv, hpass⟩ := hall j tx hj hcb
  refine ⟨l₁, a, b, hv, ?_⟩
  intro k coin hk hpred hcoin hvin
  obtain ⟨_, hok⟩ := hpass k coin hk hpred hcoin hvin
  rw [verifyScriptFull_realCheckerFullOf_eq_realCheckerOf]
  exact hok

/-- **C5b — NO BIP340 ACCEPTS ANYWHERE IN A VALIDATED BLOCK**: the
checker bound at every coin-present input of every decoded
non-coinbase tx of a `validateBlock`-ok block has a constantly-`false`
Schnorr verdict function — zero adjudicated passes rest on a BIP340
verification (no false accepts, by construction). Taproot inputs take
the `unjudgedTaproot` lane upstream of the checker (C3a's gate). This
pins the CURRENT wiring state: `realSchnorrEntry`'s `sighashSchnorr`
is still the fail-closed `none` stand-in; X03's `sighashTaproot`
(e904215) has landed, so the flip is now a one-parameter change in
`Capstone/RealChecker.lean` (X04's lane) — at which point this
theorem (and Module A's A4) are the revisit set. -/
theorem validateBlock_ok_schnorr_lane_blind (raw : ByteArray) (st : CapState)
    (r : CapReport) (hval : validateBlock raw st = .ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx),
      decodeBlock raw = .ok (bh, txs) ∧
      ∀ (j : Nat) (tx : Tx), txs[j]? = some tx → tx.isCoinBase = false →
      ∃ (l₁ : List (OutPoint × Coin)) (a b : Nat),
        verifyTxInputs st.height tx j l₁ = .ok (a, b) ∧
        ∀ (k : Nat) (coin : Coin), k < tx.vin.length →
          coinLookup l₁ (tx.vin.getD k dummyTxIn).prevout = some coin →
          (realCheckerOf tx k coin.value).base.checkSchnorrSignature
            = (fun _ _ _ _ => false) := by
  obtain ⟨bh, txs, hdec, hall⟩ := validateBlock_ok_verifyTxInputs_each raw st r hval
  refine ⟨bh, txs, hdec, ?_⟩
  intro j tx hj hcb
  obtain ⟨l₁, a, b, _, hv⟩ := hall j tx hj hcb
  exact ⟨l₁, a, b, hv, fun k coin _ _ =>
    realCheckerOf_schnorr_is_const_false tx k coin.value⟩

/-! ## Axiom pins — every theorem sorry-free, footprint audited -/

/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.verifyInput_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verifyInput_eq
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.verifyInput_pass_inv' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyInput_pass_inv
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.verifyInput_fail_inv' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyInput_fail_inv
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.verifyInput_unjudged_inv' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyInput_unjudged_inv
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.verifyInput_pure' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verifyInput_pure
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.verifyTxInputs_pure' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyTxInputs_pure
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.applyTxs_pure' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyTxs_pure
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.validateBlock_pure' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms validateBlock_pure
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.applyTx_ok_noncb' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyTx_ok_noncb
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.applyTxs_ok_verifyTxInputs_each' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms applyTxs_ok_verifyTxInputs_each
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.validateBlock_ok_verifyTxInputs_each' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms validateBlock_ok_verifyTxInputs_each
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.verifyTxInputs_loop_fail_not_ok' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyTxInputs_loop_fail_not_ok
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.verifyTxInputs_ok_no_fail' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyTxInputs_ok_no_fail
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.validateBlock_ok_input_no_fail' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms validateBlock_ok_input_no_fail
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.validateBlock_ok_inputAuth_real' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms validateBlock_ok_inputAuth_real
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.validateBlock_ok_pass_noninterference' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms validateBlock_ok_pass_noninterference
/-- info: 'BitcoinProofs.Theorems.T3T4PipelineRealCor.validateBlock_ok_schnorr_lane_blind' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms validateBlock_ok_schnorr_lane_blind

end BitcoinProofs.Theorems.T3T4PipelineRealCor
