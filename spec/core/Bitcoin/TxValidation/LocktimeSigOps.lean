import Bitcoin.TxValidation.Interface
import Bitcoin.Interpreter.Defs
import Bitcoin.Interpreter.Rules
import Bitcoin.Interpreter.SigOps

/-!
# Bitcoin.TxValidation.LocktimeSigOps — the transaction-validation module: CLTV/CSV tx-side checks + sigop accounting

The time-lock rows TXV-043..048 are the TRANSACTION-side halves of
`CheckLockTime` / `CheckSequence` (interpreter.cpp:1755-1848): the
operand-vs-`nLockTime`/`nSequence` comparisons live on the
`LocktimeEnv` the tx supplies — the opcode/disabled-flag decode is
SCR-122..131's. The sigop rows TXV-049/052/054 are the tx-level
accounting over the parsed wire ops (`GetLegacySigOpCount`,
tx_verify.cpp:117-168); the interpreter-side cost model is the sigop model's
`Bitcoin.Interpreter.SigOps`. TXV-066 (OP_RETURN outputs are
consensus-valid: value rules only) and TXV-069 (the i64 incremental
value arithmetic, CVE-2010-5137) close on `checkTransaction`'s output
loop. TXV-003/INV-003 are the exact-weight gate: `checkTransaction`'s `oversize` branch now tests Core's stripped-size
gate (`4 · serTxSize`, witness and marker/flag excluded), not the BIP141
transaction weight (`3·base + total`, which remains the block metric).

## What is proven here (all sorry-free; axiom pins at the file end)

* **TXV-043** — `CheckLockTime`'s type-match gate: operand and
  `tx.nLockTime` must be in the SAME domain (both < or both ≥
  `LOCKTIME_THRESHOLD`); a cross-domain operand fails.
* **TXV-044** — within one domain and with a non-final input sequence,
  the check fails iff the operand exceeds `tx.nLockTime`; cross-domain
  operands and final-sequence inputs also fail (the guarded iff is
  `checkLockTime_gt_iff`).
* **TXV-045** — with the same-domain gate passed and the operand no
  higher than `tx.nLockTime`, the check fails iff this input's sequence
  is `0xFFFFFFFF` (SEQUENCE_FINAL; the tx is final, CLTV is moot).
* **TXV-046** — `CheckSequence` fails when `tx.nVersion < 2`
  (BIP68's version gate).
* **TXV-047** — `CheckSequence` fails when the tx sequence's disable
  flag (bit 31) is set (BIP68: "sequence locked" disabled per input).
* **TXV-048** — both sides are masked with
  `SEQUENCE_LOCKTIME_TYPE_FLAG | SEQUENCE_LOCKTIME_MASK` (bit 22 |
  0xffff) before the same-domain comparison, and the verdict is
  `nMasked ≤ txMasked`.
* **TXV-049** — `txLegacySigOps` is exactly the sum of the shared
  inaccurate per-script counts over every scriptSig and scriptPubKey,
  preserving the valid prefix when a malformed push stops parsing.
* **TXV-052** — the sigop cost scales the legacy + P2SH counts by
  `WITNESS_SCALE_FACTOR` = 4 and the witness term by 1, additively.
* **TXV-054** — the ACCURATE-mode multisig constant: a CHECKMULTISIG
  with no preceding OP_N push falls back to
  `MAX_PUBKEYS_PER_MULTISIG` = 20 (script.h:35) and every per-op
  accurate contribution is ≤ 20. Inaccurate mode always charges twenty
  for CHECKMULTISIG, including after OP_N.
* **TXV-066** — the consensus output loop is BLIND to scriptPubKey
  content (any spk allowed — OP_RETURN outputs included; the value
  rules are the only checks; spending an OP_RETURN output fails later,
  at the interpreter).
* **TXV-069** — the i64 incremental value arithmetic: if the output
  loop accepts, EVERY partial sum (CVE-2010-5137's overflow site) is
  `MoneyRange`d — the checked-accumulation discipline. Over the same
  checked fold, `MoneyRange` is inside the int64 range, so `i64Wrap` is
  the identity on every partial sum and the wrapping i64 accumulator
  agrees with the unbounded `Int` fold (`checkOutputs_none_i64Fold_agrees`;
  at the `checkTransaction` call site the seed `0` is in range, so no
  extra hypothesis is needed: `checkOutputs_none_zero_i64Fold_agrees`).
* **TXV-003 / INV-003** — the oversize gate both ways: acceptance implies
  `4·baseSize ≤ MAX_BLOCK_WEIGHT`, and a tx with `4·baseSize >` it is
  rejected (Core `tx_check.cpp:27-29`, witness-free).
-/

namespace Bitcoin.TxValidation.LocktimeSigOps

open Bitcoin.Data Bitcoin.Consensus Bitcoin.Interpreter
open Bitcoin.Numeric Bitcoin.TxValidation
open Bitcoin.Interpreter.SigOps (sigOpStep isCheckSigWire isCheckMultiSigWire opNumberOf)

/-! ## TXV-043/044/045: the tx-side of `CheckLockTime` -/

/-- The same-domain predicate (`checkLockTimeDef`'s first guard). -/
def lockTimeSameDomain (txlt : Int) (n : ScriptNum) : Prop :=
  (txlt < LOCKTIME_THRESHOLD ∧ n < (LOCKTIME_THRESHOLD : Int)) ∨
    (txlt ≥ (LOCKTIME_THRESHOLD : Int) ∧ n ≥ (LOCKTIME_THRESHOLD : Int))

/-- TXV-043: a cross-domain operand (one side below 500M, the other
at-or-above) fails `CheckLockTime` — the type-match gate. -/
@[rule "TXV-043"]
theorem checkLockTime_domain_mismatch_fails (env : LocktimeEnv) (n : ScriptNum)
    (hcross : ¬((env.txLockTime.toNat : Int) < (LOCKTIME_THRESHOLD : Int) ∧
                n < (LOCKTIME_THRESHOLD : Int) ∨
                (env.txLockTime.toNat : Int) ≥ (LOCKTIME_THRESHOLD : Int) ∧
                n ≥ (LOCKTIME_THRESHOLD : Int))) :
    checkLockTimeDef env n = false := by
  simp only [checkLockTimeDef]
  rw [if_pos (by
    rw [Bool.not_eq_true', decide_eq_false_iff_not]
    exact hcross)]

/-- TXV-044: within one domain, an operand above `tx.nLockTime` fails. -/
@[rule "TXV-044"]
theorem checkLockTime_gt_fails (env : LocktimeEnv) (n : ScriptNum)
    (hdom : lockTimeSameDomain env.txLockTime.toNat n)
    (hgt : (env.txLockTime.toNat : Int) < n) :
    checkLockTimeDef env n = false := by
  unfold lockTimeSameDomain at hdom
  simp only [checkLockTimeDef]
  rw [if_neg (by
    rw [decide_eq_true_eq.mpr hdom]
    simp), if_pos hgt]

/-- TXV-044, converse: with the domain gate passed and the input not
final, `CheckLockTime` fails **iff** the operand exceeds `tx.nLockTime`. -/
@[rule "TXV-044"]
theorem checkLockTime_gt_iff (env : LocktimeEnv) (n : ScriptNum)
    (hdom : lockTimeSameDomain env.txLockTime.toNat n)
    (hfin : env.txSequence.toNat ≠ 0xFFFFFFFF) :
    (checkLockTimeDef env n = false ↔ (env.txLockTime.toNat : Int) < n) := by
  unfold lockTimeSameDomain at hdom
  simp only [checkLockTimeDef]
  rw [if_neg (by rw [decide_eq_true_eq.mpr hdom]; simp)]
  by_cases hgt : n > (env.txLockTime.toNat : Int)
  · rw [if_pos hgt]
    exact ⟨fun _ => hgt, fun _ => rfl⟩
  · rw [if_neg hgt, if_neg hfin]
    simp only [Bool.true_eq_false, false_iff]
    omega

/-- TXV-045: a SEQUENCE_FINAL input makes `CheckLockTime` fail — the
input is already final, so a locktime constraint cannot apply. -/
@[rule "TXV-045"]
theorem checkLockTime_finalSeq_fails (env : LocktimeEnv) (n : ScriptNum)
    (hdom : lockTimeSameDomain env.txLockTime.toNat n)
    (hle : n ≤ (env.txLockTime.toNat : Int))
    (hfin : env.txSequence.toNat = 0xFFFFFFFF) :
    checkLockTimeDef env n = false := by
  unfold lockTimeSameDomain at hdom
  simp only [checkLockTimeDef]
  rw [if_neg (by
    rw [decide_eq_true_eq.mpr hdom]
    simp), if_neg (Int.not_lt.mpr hle), if_pos hfin]

/-- TXV-045, converse: with the same-domain gate passed and the operand
no higher than `tx.nLockTime`, `CheckLockTime` fails **iff** this input's
sequence is `0xFFFFFFFF` (the finality interlock). -/
@[rule "TXV-045"]
theorem checkLockTime_finalSeq_iff (env : LocktimeEnv) (n : ScriptNum)
    (hdom : lockTimeSameDomain env.txLockTime.toNat n)
    (hle : n ≤ (env.txLockTime.toNat : Int)) :
    (checkLockTimeDef env n = false ↔ env.txSequence.toNat = 0xFFFFFFFF) := by
  unfold lockTimeSameDomain at hdom
  simp only [checkLockTimeDef]
  rw [if_neg (by rw [decide_eq_true_eq.mpr hdom]; simp)]
  rw [if_neg (Int.not_lt.mpr hle)]
  by_cases hfin : env.txSequence.toNat = 0xFFFFFFFF
  · rw [if_pos hfin]
    exact ⟨fun _ => hfin, fun _ => rfl⟩
  · rw [if_neg hfin]
    exact ⟨fun h => by simp at h, fun h => absurd h hfin⟩

/-! ## TXV-046/047/048: the tx-side of `CheckSequence` -/

/-- `decide p = true` from the negated Boolean-form condition (the shape
`split` produces for `if !decide p then _ else _`). -/
private theorem decide_of_not_not {p : Prop} [Decidable p]
    (h : ¬((!decide p) = true)) : p := by
  cases hb : decide p with
  | true => exact decide_eq_true_eq.mp hb
  | false =>
    exact absurd hb (by
      intro hf
      apply h
      rw [Bool.not_eq_true']
      exact hf)

/-- TXV-046: `tx.nVersion < 2` fails `CheckSequence` (BIP68's version
gate; the sequence semantics only exist from nVersion ≥ 2). -/
@[rule "TXV-046"]
theorem checkSequence_version_fails (env : LocktimeEnv) (n : ScriptNum)
    (hv : env.txVersion.toUInt32 < 2) :
    checkSequenceDef env n = false := by
  unfold checkSequenceDef
  rw [if_pos hv]

/-- TXV-047: the tx sequence's disable flag (bit 31) set fails
`CheckSequence` (BIP68: this input opts out of relative locktime). -/
@[rule "TXV-047"]
theorem checkSequence_disable_fails (env : LocktimeEnv) (n : ScriptNum)
    (hv : ¬(env.txVersion.toUInt32 < 2))
    (hbit : (env.txSequence.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0) :
    checkSequenceDef env n = false := by
  simp only [checkSequenceDef]
  rw [if_neg hv, if_pos hbit]

/-- TXV-048: the masked comparison law — with the version and disable
gates passed, `CheckSequence` compares BOTH sides under the bit22|0xffff
mask in the same domain, and passes iff `nMasked ≤ txMasked`. -/
@[rule "TXV-048"]
theorem checkSequence_masked (env : LocktimeEnv) (n : ScriptNum)
    (hv : ¬(env.txVersion.toUInt32 < 2))
    (hdis : (env.txSequence.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) = 0)
    (hok : checkSequenceDef env n = true) :
    ((env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) <
        SEQUENCE_LOCKTIME_TYPE_FLAG ∧
      (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) <
        SEQUENCE_LOCKTIME_TYPE_FLAG ∨
     (env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ≥
        SEQUENCE_LOCKTIME_TYPE_FLAG ∧
      (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ≥
        SEQUENCE_LOCKTIME_TYPE_FLAG) ∧
    (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ≤
      env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK) := by
  simp only [checkSequenceDef] at hok ⊢
  rw [if_neg hv, if_neg (by simp [hdis])] at hok
  split at hok
  · simp at hok
  · next hcond =>
    refine ⟨decide_of_not_not hcond, ?_⟩
    · rw [Bool.not_eq_true'] at hok
      have h2 : ¬(n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK) >
          env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) :=
        decide_eq_false_iff_not.mp hok
      exact Nat.not_lt.mp h2

/-! ## TXV-049/052/054: sigop accounting -/

/-- TXV-049: for a single-input single-output tx whose scriptSig and
scriptPubKey both parse, `GetLegacySigOpCount` is exactly the sum of the
two non-accurate per-script counts (tx_verify.cpp:118-130). -/
@[rule "TXV-049"]
theorem txLegacySigOps_one_in_out (tx : Bitcoin.Data.Tx) (i : TxIn) (o : TxOut)
    (sOps pOps : List WireOp)
    (hs : parseWire i.scriptSig.bytes = some sOps)
    (hp : parseWire o.scriptPubKey.bytes = some pOps) :
    txLegacySigOps { tx with vin := [i], vout := [o] } =
      sigOpCount sOps false + sigOpCount pOps false := by
  unfold txLegacySigOps
  simp [SigOps.scriptSigOpCount, SigOps.parseWirePrefix_of_parse _ _ hs,
    SigOps.parseWirePrefix_of_parse _ _ hp, sigOpCount]

/-- `+`-fold as the sum of the mapped values (the general Σ shape). -/
private theorem foldl_add_map_sum {α : Type} (l : List α) (f : α → Nat) :
    ∀ acc, l.foldl (fun a x => a + f x) acc = acc + (l.map f).sum := by
  induction l with
  | nil => intro acc; simp
  | cons x xs ih =>
    intro acc
    rw [List.foldl_cons, ih (acc + f x), List.map_cons, List.sum_cons]
    omega

/-- TXV-049 (general): `GetLegacySigOpCount` is exactly the Σ of the
non-accurate per-script counts — one summand for EVERY input's scriptSig
and EVERY output's scriptPubKey, retaining each valid prefix if parsing stops. -/
@[rule "TXV-049"]
theorem txLegacySigOps_eq_sum (tx : Bitcoin.Data.Tx) :
    txLegacySigOps tx =
      (tx.vin.map (fun i =>
        SigOps.scriptSigOpCount i.scriptSig.bytes false)).sum +
      (tx.vout.map (fun o =>
        SigOps.scriptSigOpCount o.scriptPubKey.bytes false)).sum := by
  unfold txLegacySigOps
  rw [foldl_add_map_sum tx.vin
        (fun i => SigOps.scriptSigOpCount i.scriptSig.bytes false) 0,
      foldl_add_map_sum tx.vout
        (fun o => SigOps.scriptSigOpCount o.scriptPubKey.bytes false) 0]
  simp

/-- TXV-052: the cost law in `WITNESS_SCALE_FACTOR` form — legacy and
P2SH counts each weigh 4 cost units, the witness count weighs 1
(tx_verify.cpp:149-166). -/
@[rule "TXV-052"]
theorem sigOpCost_scale (legacy p2sh witness : Nat) :
    sigOpCost legacy p2sh witness =
      Bitcoin.Consensus.WITNESS_SCALE_FACTOR * (legacy + p2sh) + witness := by
  unfold sigOpCost Bitcoin.Consensus.WITNESS_SCALE_FACTOR
  omega

/-- `opNumberOf` returns `some k` only for OP_1..OP_16, so `k ≤ 16`. -/
private theorem opNumberOf_le (o : Bitcoin.Script.Parser.Opcode) (k : Nat)
    (h : opNumberOf o = some k) : k ≤ 16 := by
  cases o with
  | pushNum m =>
    simp only [opNumberOf] at h
    by_cases hc : 1 ≤ m ∧ m ≤ 16
    · rw [if_pos hc] at h
      simp at h
      omega
    · rw [if_neg hc] at h
      simp at h
  | _ => simp [opNumberOf] at h

/-- `take`-then-`foldl` over a cons, one step (the IH's indexing shape). -/
private theorem take_foldl_value (a : Amount) (b : TxOut) (l : List TxOut) (n : Nat) :
    ((b :: l).take (n + 1)).foldl (fun acc t => acc + t.value) a =
      (l.take n).foldl (fun acc t => acc + t.value) (a + b.value) := by
  rw [List.take_cons (by omega), Nat.add_sub_cancel, List.foldl_cons]

/-- TXV-054, upper half: every per-op accurate-count contribution is
bounded by the multisig constant 20 (`MAX_PUBKEYS_PER_MULTISIG`,
script.h:35). -/
@[rule "TXV-054"]
theorem sigOpStep_le_maxMultisig (prev : Option Bitcoin.Script.Parser.Opcode) (op : WireOp) :
    sigOpStep prev op ≤ MAX_PUBKEYS_PER_MULTISIG := by
  have h20 : MAX_PUBKEYS_PER_MULTISIG = 20 := rfl
  unfold sigOpStep
  split
  · omega
  · split
    · cases hpo : (prev >>= opNumberOf) with
      | some k =>
        have hk : k ≤ 16 := by
          obtain ⟨o, -, ho⟩ := Option.bind_eq_some_iff.mp hpo
          exact opNumberOf_le o k ho
        show k ≤ MAX_PUBKEYS_PER_MULTISIG
        omega
      | none => exact Nat.le_refl _
    · omega

/-- TXV-054, the constant itself: an accurate-mode CHECKMULTISIG with no
OP_1..OP_16 preceding push falls back to exactly
`MAX_PUBKEYS_PER_MULTISIG` = 20. -/
@[rule "TXV-054"]
theorem sigOpStep_multisig_fallback (prev : Option Bitcoin.Script.Parser.Opcode) (op : WireOp)
    (hms : isCheckMultiSigWire op.wire = true)
    (hncs : isCheckSigWire op.wire = false)
    (hno : (prev >>= opNumberOf) = none) :
    sigOpStep prev op = MAX_PUBKEYS_PER_MULTISIG := by
  unfold sigOpStep
  rw [if_neg (by simp [hncs]), if_pos (by simp [hms]), hno]

/-- TXV-054: inaccurate CHECKMULTISIG always costs twenty, including
when no OP_N precedes it. -/
@[rule "TXV-054"]
theorem sigOpCount_inaccurate_checkmultisig (op : WireOp)
    (hms : isCheckMultiSigWire op.wire = true) :
    sigOpCount [op] false = 20 := by
  have hn : isCheckSigWire op.wire = false := by
    simp only [isCheckMultiSigWire, Bool.or_eq_true, decide_eq_true_eq] at hms
    rcases hms with h | h <;> simp [isCheckSigWire, h]
  simp [sigOpCount, SigOps.sigOpCount, SigOps.inaccurateSigOpCount, hn, hms,
    Bitcoin.Interpreter.MAX_PUBKEYS_PER_MULTISIG]

/-! The raw counters now retain valid prefixes on malformed pushes and
charge twenty in inaccurate mode. Activation and the evolving block budget
are caller-side obligations, distinct from these counting theorems. -/

/-! ## TXV-066: OP_RETURN outputs are consensus-valid (value rules only) -/

/-- TXV-066: the consensus output loop never inspects `scriptPubKey` —
rewriting every output's spk (OP_RETURN included) leaves the verdict
unchanged. Any scriptPubKey is consensus-valid; only the value rules
apply (the spend itself fails later, at the interpreter). -/
@[rule "TXV-066"]
theorem checkOutputs_spk_irrelevant (l : List TxOut) (acc : Amount) (s : Script) :
    checkTransaction.checkOutputs (l.map (fun o => { o with scriptPubKey := s })) acc =
      checkTransaction.checkOutputs l acc := by
  induction l generalizing acc with
  | nil => rfl
  | cons o rest ih =>
    unfold checkTransaction.checkOutputs
    simp only [List.map_cons]
    rw [ih]

/-! ## TXV-069: the i64 checked-incremental value arithmetic -/

/-- TXV-069 (CVE-2010-5137): if the output loop accepts, EVERY partial
sum along the checked-accumulation fold is `MoneyRange`d — no
intermediate ever escapes the int64-consistent `0 ≤ acc ≤ MAX_MONEY`
window. -/
@[rule "TXV-069"]
theorem checkOutputs_none_partial_moneyRange (l : List TxOut) (acc : Amount)
    (h : checkTransaction.checkOutputs l acc = none) :
    ∀ k, 1 ≤ k → k ≤ l.length →
      MoneyRange ((l.take k).foldl (fun a o => a + o.value) acc) := by
  induction l generalizing acc with
  | nil => intro k _ hk2; simp at hk2; omega
  | cons o rest ih =>
    simp only [checkTransaction.checkOutputs] at h
    split at h
    · simp at h
    · split at h
      · simp at h
      · split at h
        · simp at h
        · next _ _ hmr0 =>
          have hmr : MoneyRange (acc + o.value) = true :=
            Classical.byContradiction (fun hnp => hmr0 hnp)
          intro k hk1 hk2
          have hl : (o :: rest).length = rest.length + 1 := rfl
          rcases Nat.lt_or_ge k 2 with hk | hk
          · have hk1' : k = 1 := by omega
            subst hk1'
            exact hmr
          · have hke : k = (k - 1) + 1 := by omega
            rw [hke, take_foldl_value]
            exact ih (acc + o.value) h (k - 1) (by omega) (by omega)

/-- The i64-bounded (two's-complement wrapping) version of the output
value fold: the accumulator a 64-bit `CAmount` machine would produce. -/
def checkOutputsFoldI64 (l : List TxOut) (acc : Amount) : Amount :=
  l.foldl (fun a o => i64Wrap (a + o.value)) acc

/-- TXV-069, i64 half: `MoneyRange` bounds every checked partial sum, and
`MoneyRange` is contained in the int64 range, so every partial sum of the
output fold is representable as an `int64_t`. -/
@[rule "TXV-069"]
theorem checkOutputs_none_partial_i64Range (l : List TxOut) (acc : Amount)
    (hacc : MoneyRange acc = true)
    (h : checkTransaction.checkOutputs l acc = none) :
    ∀ k, k ≤ l.length →
      InI64Range ((l.take k).foldl (fun a o => a + o.value) acc) := by
  intro k hk
  rcases Nat.eq_zero_or_pos k with hk0 | hkpos
  · subst hk0
    simpa using moneyRange_in_i64Range hacc
  · exact moneyRange_in_i64Range
      (checkOutputs_none_partial_moneyRange l acc h k hkpos hk)

/-- TXV-069, per-step no-overflow: on the accepted output fold every
partial sum is in `MoneyRange`, hence two's-complement `i64Wrap` is the
identity there. No partial addition ever wraps. -/
@[rule "TXV-069"]
theorem checkOutputs_none_partial_no_overflow (l : List TxOut) (acc : Amount)
    (hacc : MoneyRange acc = true)
    (h : checkTransaction.checkOutputs l acc = none) :
    ∀ k, k ≤ l.length →
      i64Wrap ((l.take k).foldl (fun a o => a + o.value) acc) =
        (l.take k).foldl (fun a o => a + o.value) acc := by
  intro k hk
  exact i64Wrap_eq_self (checkOutputs_none_partial_i64Range l acc hacc h k hk)

/-- TXV-069, i64 agreement: if the output loop accepts from an in-range
seed, the wrapping i64 fold and the unbounded `Int` fold are the same
value — Core's `int64_t` accumulator never diverges from the model on
this path. -/
@[rule "TXV-069"]
theorem checkOutputs_none_i64Fold_agrees (l : List TxOut) (acc : Amount)
    (hacc : MoneyRange acc = true)
    (h : checkTransaction.checkOutputs l acc = none) :
    checkOutputsFoldI64 l acc =
      l.foldl (fun a o => a + o.value) acc := by
  have hpre : ∀ k, k ≤ (l.map (fun o => o.value)).length →
      InI64Range (((l.map (fun o => o.value)).take k).foldl
        (fun a v => a + v) acc) := by
    intro k hk
    rw [List.length_map] at hk
    rw [← List.map_take, List.foldl_map]
    exact checkOutputs_none_partial_i64Range l acc hacc h k hk
  have hgen := i64Foldl_eq_foldl_of_prefix_range (l.map (fun o => o.value)) acc
    (moneyRange_in_i64Range hacc) hpre
  simpa [checkOutputsFoldI64, i64Foldl, List.foldl_map] using hgen

/-- TXV-069 at the real call site: `checkTransaction` seeds the output
loop at `0` (which is in `MoneyRange`), so acceptance gives i64 agreement
without a further hypothesis. -/
@[rule "TXV-069"]
theorem checkOutputs_none_zero_i64Fold_agrees (l : List TxOut)
    (h : checkTransaction.checkOutputs l 0 = none) :
    checkOutputsFoldI64 l 0 =
      l.foldl (fun a o => a + o.value) 0 :=
  checkOutputs_none_i64Fold_agrees l 0 moneyRange_zero h

/-! ## TXV-003 / INV-003: the stripped-size oversize gate -/

/-- The bridge: `TxCheck`'s cycle-free weight replicas are
*definitionally* the frozen interface models — `txWeightL` is `3·base+total`
(block weight) and `txStrippedWeightL` is `4·base` (Core's stateless
oversize gate, `tx_check.cpp:27-29`). -/
theorem txWeightL_eq_dataLaws (tx : Tx) :
    Bitcoin.Consensus.txWeightL tx = Bitcoin.DataLaws.txWeight tx := rfl

/-- `txStrippedWeightL = 4 · baseSize` — Core's `TX_NO_WITNESS` gate. -/
theorem txStrippedWeightL_eq_dataLaws (tx : Tx) :
    Bitcoin.Consensus.txStrippedWeightL tx =
      Bitcoin.DataLaws.baseSize tx * Bitcoin.Consensus.WITNESS_SCALE_FACTOR := rfl

/-- TXV-003: acceptance implies Core's stripped-size bound — a tx
`checkTransaction` accepts has `4·baseSize ≤ MAX_BLOCK_WEIGHT`, i.e. the
oversize gate counts the witness-free serialization only. -/
@[rule "TXV-003"]
theorem checkTransaction_weight_bound (tx : Tx)
    (h : checkTransaction tx = none) :
    Bitcoin.DataLaws.baseSize tx * Bitcoin.Consensus.WITNESS_SCALE_FACTOR ≤
      MAX_BLOCK_WEIGHT := by
  unfold checkTransaction at h
  split at h
  · simp at h
  · split at h
    · simp at h
    · split at h
      · simp at h
      · next hW =>
        rw [txStrippedWeightL_eq_dataLaws] at hW
        omega

/-- INV-003: an over-size tx (`4·baseSize > MAX_BLOCK_WEIGHT`) is
rejected — witness bytes do not enter this gate. -/
@[rule "INV-003"]
theorem checkTransaction_weight_reject (tx : Tx)
    (hW : Bitcoin.DataLaws.baseSize tx * Bitcoin.Consensus.WITNESS_SCALE_FACTOR >
      MAX_BLOCK_WEIGHT) :
    checkTransaction tx ≠ none := by
  have hW' : Bitcoin.Consensus.txStrippedWeightL tx > MAX_BLOCK_WEIGHT := by
    rw [txStrippedWeightL_eq_dataLaws]
    exact hW
  unfold checkTransaction
  split
  · simp
  · split
    · simp
    · simp

/-! ## Axiom pins (every theorem here is sorry-free; standard axioms only) -/

section Pins

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.txWeightL_eq_dataLaws' depends on axioms: [propext] -/
#guard_msgs in #print axioms txWeightL_eq_dataLaws

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.txStrippedWeightL_eq_dataLaws' depends on axioms: [propext] -/
#guard_msgs in #print axioms txStrippedWeightL_eq_dataLaws

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkLockTime_domain_mismatch_fails' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkLockTime_domain_mismatch_fails

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkLockTime_gt_fails' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkLockTime_gt_fails

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkLockTime_gt_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkLockTime_gt_iff

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkLockTime_finalSeq_fails' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkLockTime_finalSeq_fails

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkLockTime_finalSeq_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkLockTime_finalSeq_iff

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkSequence_version_fails' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkSequence_version_fails

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkSequence_disable_fails' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkSequence_disable_fails

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkSequence_masked' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkSequence_masked

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.txLegacySigOps_one_in_out' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txLegacySigOps_one_in_out

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.txLegacySigOps_eq_sum' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txLegacySigOps_eq_sum

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.sigOpCost_scale' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms sigOpCost_scale

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.sigOpStep_le_maxMultisig' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms sigOpStep_le_maxMultisig

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.sigOpStep_multisig_fallback' depends on axioms: [propext] -/
#guard_msgs in #print axioms sigOpStep_multisig_fallback

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.sigOpCount_inaccurate_checkmultisig' depends on axioms: [propext] -/
#guard_msgs in #print axioms sigOpCount_inaccurate_checkmultisig

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_spk_irrelevant' depends on axioms: [Quot.sound] -/
#guard_msgs in #print axioms checkOutputs_spk_irrelevant

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_none_partial_moneyRange' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkOutputs_none_partial_moneyRange

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_none_partial_i64Range' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkOutputs_none_partial_i64Range

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_none_partial_no_overflow' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkOutputs_none_partial_no_overflow

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_none_i64Fold_agrees' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkOutputs_none_i64Fold_agrees

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkOutputs_none_zero_i64Fold_agrees' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkOutputs_none_zero_i64Fold_agrees

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkTransaction_weight_bound' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkTransaction_weight_bound

/-- info: 'Bitcoin.TxValidation.LocktimeSigOps.checkTransaction_weight_reject' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkTransaction_weight_reject

end Pins

end Bitcoin.TxValidation.LocktimeSigOps
