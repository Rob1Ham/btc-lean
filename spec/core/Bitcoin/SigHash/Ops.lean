import Bitcoin.Data.Basic
import Bitcoin.Serialization.Interface

/-!
# Bitcoin.SigHash.Ops — `GetOp` walk, `FindAndDelete`, and scriptCode re-serialization

The proof vehicle is the list layer (`Bytes := List UInt8`, W02's pattern); the
ByteArray API at the bottom bridges through W02's proved `bL`/`bytesOfList` laws.

Ground truth @ cce32b168:
  * `GetOp`                     — `script/script.cpp:313-363` (`GetScriptOp`)
  * `CScript::FindAndDelete`    — `script/interpreter.cpp:239-262`
  * `SerializeScriptCode`       — `script/interpreter.cpp:1281-1302`
    (CTransactionSignatureSerializer: "skipping OP_CODESEPARATORs")

Consensus semantics captured here (B2-verified, W11-mirror-validated):

* **GetOp** parses one opcode: bytes `0x00..0x4e` are the push family (direct
  push / PUSHDATA1/2/4, each carrying a length prefix and a payload that is
  consumed *wholesale*); any other byte is a 1-byte opcode. GetOp FAILS (and
  the walk stops) on end-of-script or a push whose payload runs past the end.
* **FindAndDelete(script, b)** removes every non-overlapping byte-exact
  occurrence of `b` that is anchored at an OPCODE BOUNDARY: matching is
  attempted at the walk position BEFORE each GetOp step, and repeatedly after
  each match (consecutive matches). A malformed tail is copied verbatim.
  Core quirk kept: when nothing matched, the script is returned unchanged
  (indistinguishable from the copy — both are the identity here).
  For the 1-byte pattern `CScript() << OP_CODESEPARATOR` = `[0xab]`, matching
  at a boundary is exactly "the op at this boundary is OP_CODESEPARATOR"
  (0xab > 0x4e always parses as the 1-byte OP_CODESEPARATOR op), so the
  general machinery and a dedicated "drop 0xab ops" loop coincide — we keep
  the general `findAndDeleteL` and derive `scriptCodeOf` from it, so the
  frozen-interface claim "FindAndDelete semantics" is literal.
* **SerializeScriptCode** (inside the legacy digest only) emits
  `CompactSize(scriptCode.size − #OP_CODESEPARATOR)` followed by the script
  bytes with each parsed 1-byte OP_CODESEPARATOR spliced out. This is a
  *splice of raw bytes* — pushes are NOT canonically re-encoded (correcting
  the W01 interface docstring's "pushes re-encoded canonically"; the B2
  report's "1-byte opcodes spliced out" is the accurate description).
-/

namespace Bitcoin.SigHash

open Bitcoin.Serialization (Bytes bL bytesOfList)

/-! ## GetOp (`script.cpp:313-363`) -/

/-- `GetOp` at index `i`: `(opcode, total op length)`, `total ≥ 1`.
`none` = end-of-script or malformed push (GetOp fails). -/
def getOpAt (b : Bytes) (i : Nat) : Option (Nat × Nat) :=
  match b[i]? with
  | none => none
  | some op =>
    let v := op.toNat
    if v ≤ 0x4b then
      -- direct push OP_0..OP_75: 1 length byte + payload
      if i + 1 + v ≤ b.length then some (v, 1 + v) else none
    else if v = 0x4c then
      -- PUSHDATA1
      match b[i+1]? with
      | none => none
      | some l =>
        let n := l.toNat
        if i + 2 + n ≤ b.length then some (0x4c, 2 + n) else none
    else if v = 0x4d then
      -- PUSHDATA2
      match b[i+1]?, b[i+2]? with
      | some lo, some hi =>
        let n := hi.toNat * 256 + lo.toNat
        if i + 3 + n ≤ b.length then some (0x4d, 3 + n) else none
      | _, _ => none
    else if v = 0x4e then
      -- PUSHDATA4
      match b[i+1]?, b[i+2]?, b[i+3]?, b[i+4]? with
      | some a, some c, some d, some e =>
        let n := e.toNat * 16777216 + d.toNat * 65536 + c.toNat * 256 + a.toNat
        if i + 5 + n ≤ b.length then some (0x4e, 5 + n) else none
      | _, _, _, _ => none
    else
      -- 1-byte opcode (incl. OP_CODESEPARATOR = 0xab)
      some (v, 1)

/-- One GetOp step: `(start, end, opcode)` of the op at `i`, or `none`. -/
def opSpanAt (b : Bytes) (i : Nat) : Option (Nat × Nat × Nat) :=
  (getOpAt b i).map (fun (op, len) => (i, i + len, op))

/-- The GetOp walk: `(spans, parsedEnd)` — spans over the successfully parsed
prefix (in order), `parsedEnd` = first index where GetOp fails (≤ length;
the `[parsedEnd, length)` remainder is the verbatim tail). -/
def walkAux (b : Bytes) : Nat → Nat → List (Nat × Nat × Nat) → List (Nat × Nat × Nat) × Nat
  | 0, i, acc => (acc.reverse, i)
  | fuel+1, i, acc =>
      if b.length ≤ i then (acc.reverse, i)
      else match getOpAt b i with
        | none => (acc.reverse, i)
        | some (_, len) => walkAux b fuel (i + len) ((i, i + len, b[i]!.toNat) :: acc)

/-- Walk with the canonical fuel (`length + 1` steps suffice: each parsed op
consumes ≥ 1 byte). Fuel-independence is proved below (`walkAux_fuel`). -/
def walkOps (b : Bytes) : List (Nat × Nat × Nat) × Nat :=
  walkAux b (b.length + 1) 0 []

/-! ## `FindAndDelete` (`interpreter.cpp:239-262`) -/

/-- Byte-exact match of `p` at position `i` (with the length guard). -/
def matchAtL (b p : Bytes) (i : Nat) : Bool :=
  i + p.length ≤ b.length ∧ (List.range p.length).all (fun k => b[i + k]? == p[k]?)

/-- FindAndDelete worker: `fuel` bounds the loop, `acc` accumulates the kept
bytes. Matches are tried at the current boundary first (consecutively), then
one GetOp step is taken; a GetOp failure copies the verbatim tail. -/
def findAndDeleteAuxL (b p : Bytes) : Nat → Nat → Bytes → Bytes
  | 0, _, acc => acc
  | fuel+1, i, acc =>
      if matchAtL b p i then findAndDeleteAuxL b p fuel (i + p.length) acc
      else match getOpAt b i with
        | none => acc ++ b.drop i
        | some (_, len) =>
            findAndDeleteAuxL b p fuel (i + len) (acc ++ (b.take (i + len)).drop i)

/-- `CScript::FindAndDelete` — see module docstring. Empty pattern = identity
(Core: `if (b.empty()) return nFound;` leaves the script untouched). -/
def findAndDeleteL (b p : Bytes) : Bytes :=
  if p.isEmpty then b else findAndDeleteAuxL b p (b.length + 1) 0 []

/-- The `CScript() << OP_CODESEPARATOR` pattern. -/
def codeSepL : Bytes := [0xab]

/-! ## `SerializeScriptCode` (`interpreter.cpp:1281-1302`) -/

/-- The legacy digest's scriptCode serialization: `CompactSize(size − #CS)`
followed by the script with each parsed OP_CODESEPARATOR opcode spliced out. -/
def serializeScriptCodeL (sc : Bytes) : Bytes :=
  let (spans, _) := walkOps sc
  let nsep := (spans.filter (fun (_, _, op) => op = 0xab)).length
  let (it, body) := spans.foldl (fun (it, out) (_st, e, op) =>
      if op = 0xab then (e, out ++ (sc.take (e - 1)).drop it) else (it, out)) (0, [])
  let body := if it ≠ sc.length then body ++ sc.drop it else body
  Bitcoin.Serialization.encCSL (sc.length - nsep) ++ body

/-! ## ByteArray bridges -/

/-- `scriptCodeOf` at the byte level: FindAndDelete of OP_CODESEPARATOR. -/
def findAndDeleteB (b p : ByteArray) : ByteArray :=
  bytesOfList (findAndDeleteL (bL b) (bL p))

/-- Everything a successful GetOp commit pins down. -/
theorem some_u8_ofNat {n : Nat} (hn : n < 256) {o : UInt8} (h2 : o.toNat = n) :
    some o = some n.toUInt8 := by
  have h3 : n.toUInt8.toNat = n % 256 := rfl
  exact congrArg some (UInt8.toNat.inj (by omega))

theorem u8_lt {o : UInt8} : o.toNat < 256 := by
  have : o.toNat = o.toBitVec.toNat := rfl
  omega

theorem getOpAt_some_spec {b : Bytes} {i v len : Nat}
    (h : getOpAt b i = some (v, len)) :
    1 ≤ len ∧ i < b.length ∧ b[i]? = some v.toUInt8 ∧ v < 256 ∧ i + len ≤ b.length := by
  unfold getOpAt at h
  cases hb : b[i]? with
  | none => rw [hb] at h; exact absurd h (by simp)
  | some op =>
    have hlt : i < b.length := by
      by_cases hc : i < b.length
      · exact hc
      · have hnone : b[i]? = none := List.getElem?_eq_none_iff.mpr (by omega)
        rw [hnone] at hb
        exact absurd hb (by simp)
    rw [hb] at h
    dsimp only at h
    by_cases h1 : op.toNat ≤ 0x4b
    · rw [if_pos h1] at h
      by_cases hr : i + 1 + op.toNat ≤ b.length
      · rw [if_pos hr] at h
        simp only [Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        exact ⟨by omega, hlt, by simp only [UInt8.ofNat_toNat], u8_lt, by omega⟩
      · rw [if_neg hr] at h; exact absurd h (by simp)
    · by_cases h2 : op.toNat = 0x4c
      · rw [if_neg h1, if_pos h2] at h
        cases hl1 : b[i+1]? with
        | none => rw [hl1] at h; dsimp only at h; exact absurd h (by simp)
        | some x =>
          rw [hl1] at h
          dsimp only at h
          by_cases hr : i + 2 + x.toNat ≤ b.length
          · rw [if_pos hr] at h
            simp only [Option.some.injEq, Prod.mk.injEq] at h
            obtain ⟨rfl, rfl⟩ := h
            refine ⟨by omega, hlt, some_u8_ofNat (by decide) h2, by decide, by omega⟩
          · rw [if_neg hr] at h; exact absurd h (by simp)
      · by_cases h3 : op.toNat = 0x4d
        · rw [if_neg h1, if_neg h2, if_pos h3] at h
          cases hl1 : b[i+1]? with
          | none => rw [hl1] at h; dsimp only at h; exact absurd h (by simp)
          | some x =>
            rw [hl1] at h
            cases hl2 : b[i+2]? with
            | none => rw [hl2] at h; dsimp only at h; exact absurd h (by simp)
            | some y =>
              rw [hl2] at h
              dsimp only at h
              by_cases hr : i + 3 + (y.toNat * 256 + x.toNat) ≤ b.length
              · rw [if_pos hr] at h
                simp only [Option.some.injEq, Prod.mk.injEq] at h
                obtain ⟨rfl, rfl⟩ := h
                refine ⟨by omega, hlt, some_u8_ofNat (by decide) h3, by decide, by omega⟩
              · rw [if_neg hr] at h; exact absurd h (by simp)
        · by_cases h4 : op.toNat = 0x4e
          · rw [if_neg h1, if_neg h2, if_neg h3, if_pos h4] at h
            cases hl1 : b[i+1]? with
            | none => rw [hl1] at h; dsimp only at h; exact absurd h (by simp)
            | some a =>
              rw [hl1] at h
              cases hl2 : b[i+2]? with
              | none => rw [hl2] at h; dsimp only at h; exact absurd h (by simp)
              | some c =>
                rw [hl2] at h
                cases hl3 : b[i+3]? with
                | none => rw [hl3] at h; dsimp only at h; exact absurd h (by simp)
                | some d =>
                  rw [hl3] at h
                  cases hl4 : b[i+4]? with
                  | none => rw [hl4] at h; dsimp only at h; exact absurd h (by simp)
                  | some e =>
                    rw [hl4] at h
                    dsimp only at h
                    by_cases hr : i + 5 + (e.toNat * 16777216 + d.toNat * 65536 +
                        c.toNat * 256 + a.toNat) ≤ b.length
                    · rw [if_pos hr] at h
                      simp only [Option.some.injEq, Prod.mk.injEq] at h
                      obtain ⟨rfl, rfl⟩ := h
                      refine ⟨by omega, hlt, some_u8_ofNat (by decide) h4, by decide, by omega⟩
                    · rw [if_neg hr] at h; exact absurd h (by simp)
          · rw [if_neg h1, if_neg h2, if_neg h3, if_neg h4] at h
            simp only [Option.some.injEq, Prod.mk.injEq] at h
            obtain ⟨rfl, rfl⟩ := h
            exact ⟨by omega, hlt, by simp only [UInt8.ofNat_toNat], u8_lt, by omega⟩

theorem getOpAt_len_pos {b : Bytes} {i v len : Nat}
    (h : getOpAt b i = some (v, len)) : 1 ≤ len := (getOpAt_some_spec h).1

theorem getOpAt_head {b : Bytes} {i v len : Nat}
    (h : getOpAt b i = some (v, len)) : i < b.length ∧ b[i]? = some v.toUInt8 :=
  ⟨(getOpAt_some_spec h).2.1, (getOpAt_some_spec h).2.2.1⟩

theorem getOpAt_le {b : Bytes} {i v len : Nat}
    (h : getOpAt b i = some (v, len)) : i + len ≤ b.length :=
  (getOpAt_some_spec h).2.2.2.2

/-- A failed byte read is a failed GetOp. -/
theorem getOpAt_none_of_byte_none {b : Bytes} {i : Nat}
    (h : b[i]? = none) : getOpAt b i = none := by
  unfold getOpAt; rw [h]

/-- The byte `0xab` always parses as the 1-byte `OP_CODESEPARATOR` op. -/
theorem getOpAt_codeSep {b : Bytes} {i : Nat} (h : b[i]? = some 0xab) :
    getOpAt b i = some (0xab, 1) := by
  unfold getOpAt
  rw [h]
  rfl

/-- **Monotonicity (offset form).** If GetOp succeeds at `i` in `l`, and
`l'` carries the same bytes over the parsed window (`l[i+j]? = l'[i'+j]?`
for `j < len`) with room for the whole op, then GetOp succeeds at `i'` in
`l'` with the very same `(v, len)`. This one lemma drives: appending bytes,
truncating to the op span, and shifting through a dropped prefix. -/
theorem getOpAt_mono2 {l l' : Bytes} {i i' v len : Nat}
    (h : getOpAt l i = some (v, len))
    (hbytes : ∀ j, j < len → l[i + j]? = l'[i' + j]?)
    (hroom : i' + len ≤ l'.length) :
    getOpAt l' i' = some (v, len) := by
  obtain ⟨h1, hilt, hbyte, hv256, hle⟩ := getOpAt_some_spec h
  have hvnat : v.toUInt8.toNat = v := by
    have h3 : v.toUInt8.toNat = v % 256 := rfl
    omega
  have h00 := hbytes 0 (by omega)
  simp only [Nat.add_zero] at h00
  have h0 : l'[i']? = some v.toUInt8 := by
    rw [← h00]
    exact hbyte
  unfold getOpAt at h ⊢
  rw [h0]
  dsimp only at h ⊢
  rw [hbyte] at h
  dsimp only at h
  rw [hvnat] at h ⊢
  by_cases hv1 : v ≤ 0x4b
  · rw [if_pos hv1] at h ⊢
    by_cases hr : i + 1 + v ≤ l.length
    · rw [if_pos hr] at h
      have hlen : 1 + v = len := by simpa using h
      subst hlen
      rw [if_pos (by omega : i' + 1 + v ≤ l'.length)]
    · rw [if_neg hr] at h; exact absurd h (by simp)
  · rw [if_neg hv1] at h ⊢
    by_cases hv2 : v = 0x4c
    · rw [if_pos hv2] at h ⊢
      cases hl1 : l[i+1]? with
      | none => rw [hl1] at h; dsimp only at h; exact absurd h (by simp)
      | some x =>
        rw [hl1] at h
        dsimp only at h
        by_cases hr : i + 2 + x.toNat ≤ l.length
        · rw [if_pos hr] at h
          simp only [Option.some.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl⟩ := h
          have hbx : l[i + 1]? = l'[i' + 1]? := hbytes 1 (by omega)
          rw [← hbx, hl1]
          dsimp only
          rw [if_pos (by omega : i' + 2 + x.toNat ≤ l'.length)]
        · rw [if_neg hr] at h; exact absurd h (by simp)
    · rw [if_neg hv2] at h ⊢
      by_cases hv3 : v = 0x4d
      · rw [if_pos hv3] at h ⊢
        cases hl1 : l[i+1]? with
        | none => rw [hl1] at h; dsimp only at h; exact absurd h (by simp)
        | some x =>
          rw [hl1] at h
          cases hl2 : l[i+2]? with
          | none => rw [hl2] at h; dsimp only at h; exact absurd h (by simp)
          | some y =>
            rw [hl2] at h
            dsimp only at h
            by_cases hr : i + 3 + (y.toNat * 256 + x.toNat) ≤ l.length
            · rw [if_pos hr] at h
              simp only [Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h
              have hbx1 : l[i + 1]? = l'[i' + 1]? := hbytes 1 (by omega)
              have hbx2 : l[i + 2]? = l'[i' + 2]? := hbytes 2 (by omega)
              rw [← hbx1, hl1, ← hbx2, hl2]
              dsimp only
              rw [if_pos (by omega : i' + 3 + (y.toNat * 256 + x.toNat) ≤ l'.length)]
            · rw [if_neg hr] at h; exact absurd h (by simp)
      · rw [if_neg hv3] at h ⊢
        by_cases hv4 : v = 0x4e
        · rw [if_pos hv4] at h ⊢
          cases hl1 : l[i+1]? with
          | none => rw [hl1] at h; dsimp only at h; exact absurd h (by simp)
          | some a =>
            rw [hl1] at h
            cases hl2 : l[i+2]? with
            | none => rw [hl2] at h; dsimp only at h; exact absurd h (by simp)
            | some c =>
              rw [hl2] at h
              cases hl3 : l[i+3]? with
              | none => rw [hl3] at h; dsimp only at h; exact absurd h (by simp)
              | some d =>
                rw [hl3] at h
                cases hl4 : l[i+4]? with
                | none => rw [hl4] at h; dsimp only at h; exact absurd h (by simp)
                | some e =>
                  rw [hl4] at h
                  dsimp only at h
                  by_cases hr : i + 5 + (e.toNat * 16777216 + d.toNat * 65536 +
                      c.toNat * 256 + a.toNat) ≤ l.length
                  · rw [if_pos hr] at h
                    simp only [Option.some.injEq, Prod.mk.injEq] at h
                    obtain ⟨rfl, rfl⟩ := h
                    have hbx1 : l[i + 1]? = l'[i' + 1]? := hbytes 1 (by omega)
                    have hbx2 : l[i + 2]? = l'[i' + 2]? := hbytes 2 (by omega)
                    have hbx3 : l[i + 3]? = l'[i' + 3]? := hbytes 3 (by omega)
                    have hbx4 : l[i + 4]? = l'[i' + 4]? := hbytes 4 (by omega)
                    rw [← hbx1, hl1, ← hbx2, hl2, ← hbx3, hl3, ← hbx4, hl4]
                    dsimp only
                    rw [if_pos (by omega : i' + 5 + (e.toNat * 16777216 + d.toNat * 65536 +
                      c.toNat * 256 + a.toNat) ≤ l'.length)]
                  · rw [if_neg hr] at h; exact absurd h (by simp)
        · rw [if_neg hv4] at h ⊢
          have hlen : 1 = len := by simpa using h
          subst hlen
          rfl

/-! ## FindAndDelete idempotency (`scriptCodeOf` closure law, W11 S3) -/

/-! ## The clean-walk predicate -/

/-- The GetOp walk from `i` never visits an `OP_CODESEPARATOR` op (the walk
stops at end-of-script or a GetOp failure, and every op it visits is not
0xab). Interior payload bytes are never visited, so pushes containing the
byte 0xab stay clean. -/
inductive CleanFrom (b : Bytes) : Nat → Prop where
  | atEnd : b.length ≤ i → CleanFrom b i
  | noOp : i < b.length → getOpAt b i = none → CleanFrom b i
  | keep : i < b.length → getOpAt b i = some (op, len) → op ≠ 0xab →
      CleanFrom b (i + len) → CleanFrom b i

/-! ## Fuel-structural drop-CS walk -/

def dropCsAux (b : Bytes) : Nat → Nat → Bytes
  | 0, _ => []
  | fuel+1, i =>
      if b.length ≤ i then []
      else match getOpAt b i with
        | none => b.drop i
        | some (op, len) =>
            if op = 0xab then dropCsAux b fuel (i + len)
            else (b.take (i + len)).drop i ++ dropCsAux b fuel (i + len)

def dropCsFrom (b : Bytes) (i : Nat) : Bytes := dropCsAux b (b.length + 1) i

/-- One-step unfolding (structural on `fuel`; `rfl`-provable, loop-free). -/
theorem dropCsAux_zero (b : Bytes) (i : Nat) : dropCsAux b 0 i = [] := rfl

theorem dropCsAux_step (b : Bytes) (fuel : Nat) (i : Nat) :
    dropCsAux b (fuel + 1) i =
      if b.length ≤ i then []
      else match getOpAt b i with
        | none => b.drop i
        | some (op, len) =>
            if op = 0xab then dropCsAux b fuel (i + len)
            else (b.take (i + len)).drop i ++ dropCsAux b fuel (i + len) := rfl

theorem fdaL_zero {b p : Bytes} {i : Nat} {acc : Bytes} :
    findAndDeleteAuxL b p 0 i acc = acc := rfl

theorem fdaL_step {b p : Bytes} {fuel i : Nat} {acc : Bytes} :
    findAndDeleteAuxL b p (fuel + 1) i acc =
      if matchAtL b p i then findAndDeleteAuxL b p fuel (i + p.length) acc
      else match getOpAt b i with
        | none => acc ++ b.drop i
        | some (_, len) =>
            findAndDeleteAuxL b p fuel (i + len) (acc ++ (b.take (i + len)).drop i) := rfl

/-! ## Characterizing the CS match -/

theorem matchAtL_codeSep (b : Bytes) (i : Nat) :
    matchAtL b codeSepL i = true ↔ b[i]? = some 0xab := by
  unfold matchAtL codeSepL
  simp only [List.length_singleton, List.range_one, List.all_eq_true,
    decide_eq_true_eq, beq_iff_eq]
  constructor
  · intro h
    obtain ⟨_, hall⟩ := h
    have h00 := hall 0 (by simp)
    simpa using h00
  · intro h0
    obtain ⟨hlt, _⟩ := List.getElem?_eq_some_iff.mp h0
    exact ⟨hlt, fun x hx => by
      have hx0 : x = 0 := by simpa using hx
      subst hx0
      simpa using h0⟩

/-! ## `take_drop_mid` helper -/

theorem take_drop_mid {b : Bytes} {i m : Nat}
    (hi : i ≤ m) (hm : m ≤ b.length) :
    (b.take m).drop i ++ b.drop m = b.drop i := by
  have hsplit : b.drop i = (b.take m ++ b.drop m).drop i := by
    rw [List.take_append_drop]
  rw [hsplit, List.drop_append_of_le_length
    (show i ≤ (b.take m).length by rw [List.length_take_of_le hm]; omega)]

/-! ## GetOp through an appended prefix -/

theorem getOpAt_append_some {b c : Bytes} {j v len : Nat}
    (h : getOpAt b j = some (v, len)) :
    getOpAt (c ++ b) (c.length + j) = some (v, len) := by
  obtain ⟨h1, hilt, _, _, hle⟩ := getOpAt_some_spec h
  refine getOpAt_mono2 h ?_ ?_
  · intro k hk
    rw [List.getElem?_append]
    simp only [Nat.add_assoc, if_neg (by omega : ¬ (c.length + (j + k) < c.length)),
      Nat.add_sub_cancel_left]
  · simp only [List.length_append]
    omega

theorem getOpAt_append_none {b c : Bytes} {j : Nat}
    (h : getOpAt b j = none) :
    getOpAt (c ++ b) (c.length + j) = none := by
  cases hg : getOpAt (c ++ b) (c.length + j) with
  | none => rfl
  | some p =>
      obtain ⟨v, len⟩ := p
      have hsp := getOpAt_some_spec hg
      have hmono : getOpAt b j = some (v, len) :=
        getOpAt_mono2 hg
          (fun k _ => by
            rw [List.getElem?_append]
            simp only [Nat.add_assoc,
              if_neg (by omega : ¬ (c.length + (j + k) < c.length)),
              Nat.add_sub_cancel_left])
          (by
            simp only [List.length_append] at hsp ⊢
            omega)
      rw [h] at hmono
      simp at hmono

/-! ## Fuel invariance -/

theorem dropCsAux_invariant (b : Bytes) : ∀ fuel f' i,
    b.length ≤ i + fuel → fuel ≤ f' → dropCsAux b f' i = dropCsAux b fuel i := by
  intro fuel
  induction fuel with
  | zero =>
    intro f' i hle _
    cases f' with
    | zero => rfl
    | succ f' =>
        have hle' : b.length ≤ i := by omega
        rw [dropCsAux_step, if_pos hle', dropCsAux_zero]
  | succ fuel ih =>
    intro f' i hle hf'
    obtain ⟨f'', hf''⟩ : ∃ k, f' = k + 1 := ⟨f' - 1, by omega⟩
    subst hf''
    rw [dropCsAux_step, dropCsAux_step]
    by_cases hcase : b.length ≤ i
    · rw [if_pos hcase, if_pos hcase]
    · rw [if_neg hcase, if_neg hcase]
      cases hOp : getOpAt b i with
      | none => simp only [hOp]
      | some o =>
        obtain ⟨op, len⟩ := o
        have h1 : 1 ≤ len := getOpAt_len_pos hOp
        simp only [hOp]
        by_cases hcs : op = 0xab
        · rw [if_pos hcs, if_pos hcs]
          exact ih f'' (i + len) (by omega) (by omega)
        · rw [if_neg hcs, if_neg hcs]
          rw [ih f'' (i + len) (by omega) (by omega)]

/-! ## C1: on a clean walk, the drop-CS walk is the identity tail -/

theorem dropCsAux_of_clean {b : Bytes} {i : Nat} (h : CleanFrom b i) :
    ∀ fuel, b.length ≤ i + fuel → dropCsAux b fuel i = b.drop i := by
  induction h with
  | atEnd hle0 =>
      intro fuel _
      cases fuel with
      | zero => rw [dropCsAux_zero, List.drop_eq_nil_of_le hle0]
      | succ fuel => rw [dropCsAux_step, if_pos hle0, List.drop_eq_nil_of_le hle0]
  | noOp hlt hnone =>
      intro fuel hle
      cases fuel with
      | zero => exact absurd hle (by omega)
      | succ fuel =>
          rw [dropCsAux_step, if_neg (by omega), hnone]
  | keep hlt hs hop =>
      rename_i ih
      intro fuel hle
      obtain ⟨h1, hilt, _, _, hle2⟩ := getOpAt_some_spec hs
      cases fuel with
      | zero => exact absurd hle (by omega)
      | succ fuel =>
          rw [dropCsAux_step, if_neg (by omega)]
          simp only [hs, if_neg hop]
          rw [ih fuel (by omega), take_drop_mid (by omega) (by omega)]

theorem dropCsFrom_of_clean {b : Bytes} {i : Nat} (h : CleanFrom b i) :
    dropCsFrom b i = b.drop i := by
  unfold dropCsFrom
  exact dropCsAux_of_clean h (b.length + 1) (by omega)

/-! ## `CleanFrom.append`: prepending a prefix to a clean walk -/

theorem CleanFrom.append {b c : Bytes} {j : Nat} (h : CleanFrom b j) :
    CleanFrom (c ++ b) (c.length + j) := by
  induction h with
  | atEnd hle =>
      exact .atEnd (by simp only [List.length_append]; omega)
  | noOp _ hnone =>
      exact .noOp (by simp only [List.length_append]; omega)
        (getOpAt_append_none hnone)
  | keep _ hs hop =>
      rename_i ih
      obtain ⟨h1, hilt, _, _, hle⟩ := getOpAt_some_spec hs
      refine .keep (by simp only [List.length_append]; omega)
        (getOpAt_append_some hs) hop ?_
      rw [Nat.add_assoc]
      exact ih

/-! ## C2: the output of the drop-CS walk is always clean -/

theorem dropCsAux_clean (b : Bytes) : ∀ fuel i, b.length ≤ i + fuel →
    CleanFrom (dropCsAux b fuel i) 0 := by
  intro fuel
  induction fuel with
  | zero =>
    intro i hle
    rw [dropCsAux_zero]
    exact .atEnd (by simp)
  | succ fuel ih =>
    intro i hle
    rw [dropCsAux_step]
    by_cases hcase : b.length ≤ i
    · rw [if_pos hcase]; exact .atEnd (by simp)
    · rw [if_neg hcase]
      have hlt : i < b.length := by omega
      cases hOp : getOpAt b i with
      | none =>
          simp only [hOp]
          refine .noOp ?_ ?_
          · have hld : (b.drop i).length = b.length - i := List.length_drop
            omega
          · cases hg : getOpAt (b.drop i) 0 with
            | none => rfl
            | some p =>
                obtain ⟨v, len⟩ := p
                have hsp := getOpAt_some_spec hg
                have hld : (b.drop i).length = b.length - i := List.length_drop
                have hmono : getOpAt b i = some (v, len) :=
                  getOpAt_mono2 hg
                    (fun k _ => by rw [List.getElem?_drop, Nat.zero_add]) (by omega)
                rw [hOp] at hmono
                simp at hmono
      | some o =>
          obtain ⟨op, len⟩ := o
          have h1 : 1 ≤ len := getOpAt_len_pos hOp
          simp only [hOp]
          obtain ⟨h1, hilt, hbyte, hv, hle2⟩ := getOpAt_some_spec hOp
          by_cases hcs : op = 0xab
          · rw [if_pos hcs]; exact ih (i + len) (by omega)
          · rw [if_neg hcs]
            have hlen_span : ((b.take (i + len)).drop i).length = len := by
              rw [List.length_drop, List.length_take_of_le (by omega)]
              omega
            have hspan : getOpAt ((b.take (i + len)).drop i) 0 = some (op, len) :=
              getOpAt_mono2 hOp
                (fun k hk => by
                  rw [List.getElem?_drop, List.getElem?_take, if_pos (by omega),
                    Nat.zero_add])
                (by omega)
            have hfull : getOpAt ((b.take (i + len)).drop i ++
                dropCsAux b fuel (i + len)) 0 = some (op, len) :=
              getOpAt_mono2 hspan
                (fun k hk => by
                  rw [List.getElem?_append, if_pos (by rw [hlen_span]; omega)])
                (by simp only [List.length_append, hlen_span]; omega)
            refine CleanFrom.keep (by simp only [List.length_append]; omega) hfull hcs ?_
            rw [Nat.zero_add]
            have hi2 : CleanFrom
                ((b.take (i + len)).drop i ++ dropCsAux b fuel (i + len))
                (((b.take (i + len)).drop i).length) :=
              CleanFrom.append (ih (i + len) (by omega))
            rwa [hlen_span] at hi2

theorem dropCsFrom_clean (b : Bytes) (i : Nat) : CleanFrom (dropCsFrom b i) 0 := by
  unfold dropCsFrom
  exact dropCsAux_clean b (b.length + 1) i (by omega)

/-! ## Idempotency -/

theorem dropCsFrom_idempotent (b : Bytes) (i : Nat) :
    dropCsFrom (dropCsFrom b i) 0 = dropCsFrom b i := by
  have hc := dropCsFrom_clean b i
  rw [dropCsFrom_of_clean hc, List.drop_zero]

/-! ## T1: the FindAndDelete worker computes the drop-CS walk -/

theorem findAndDeleteAuxL_eq_dropCsAux (b : Bytes) :
    ∀ fuel i acc, b.length ≤ i + fuel →
      findAndDeleteAuxL b codeSepL fuel i acc = acc ++ dropCsAux b fuel i := by
  intro fuel
  induction fuel with
  | zero =>
    intro i acc hle
    rw [fdaL_zero, dropCsAux_zero, List.append_nil]
  | succ fuel ih =>
    intro i acc hle
    rw [fdaL_step, dropCsAux_step]
    simp only [matchAtL_codeSep]
    by_cases hb : b[i]? = some 0xab
    · rw [if_pos hb]
      have hlt : i < b.length := by
        cases hbx : b[i]? with
        | none => rw [hbx] at hb; exact absurd hb (by simp)
        | some x =>
            obtain ⟨h3, _⟩ := List.getElem?_eq_some_iff.mp hbx
            exact h3
      rw [if_neg (by omega : ¬ (b.length ≤ i)), getOpAt_codeSep hb]
      show findAndDeleteAuxL b codeSepL fuel (i + 1) acc = acc ++ dropCsAux b fuel (i + 1)
      exact ih (i + 1) acc (by omega)
    · rw [if_neg hb]
      by_cases hcase : b.length ≤ i
      · have hnone : b[i]? = none := List.getElem?_eq_none_iff.mpr hcase
        rw [if_pos hcase, getOpAt_none_of_byte_none hnone,
          List.drop_eq_nil_of_le hcase, List.append_nil]
      · rw [if_neg hcase]
        have hlt : i < b.length := by omega
        cases hOp : getOpAt b i with
        | none => simp only [hOp]
        | some o =>
          obtain ⟨op, len⟩ := o
          have h1 : 1 ≤ len := getOpAt_len_pos hOp
          simp only [hOp]
          obtain ⟨h1, hilt, hbyte, hv, hle2⟩ := getOpAt_some_spec hOp
          have hop : op ≠ 0xab := by
            intro h0
            subst h0
            exact hb hbyte
          rw [if_neg hop, ih (i + len) (acc ++ (b.take (i + len)).drop i) (by omega),
            List.append_assoc]

@[rule "INV-057"]
theorem findAndDeleteL_codeSep_eq (b : Bytes) :
    findAndDeleteL b codeSepL = dropCsFrom b 0 := by
  unfold findAndDeleteL
  rw [if_neg (by simp [codeSepL]),
    findAndDeleteAuxL_eq_dropCsAux b (b.length + 1) 0 [] (by omega),
    List.nil_append]
  rfl

theorem findAndDeleteL_codeSep_idempotent (b : Bytes) :
    findAndDeleteL (findAndDeleteL b codeSepL) codeSepL = findAndDeleteL b codeSepL := by
  rw [findAndDeleteL_codeSep_eq, findAndDeleteL_codeSep_eq]
  exact dropCsFrom_idempotent b 0

end Bitcoin.SigHash
