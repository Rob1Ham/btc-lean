import Bitcoin.Crypto.Taproot.TapTweak
import Bitcoin.Data.Basic

/-!
# Bitcoin.Crypto.Taproot.Program — P2TR program recognition and
# witness-structure classification (the witness-structure module)

The Taproot-era rows that are implementable STANDALONE of the BIP341
sighash pipeline and the BIP342 tapscript deltas (the Taproot and interpreter delta layers' lanes):

* **P2TR program recognition** — `p2trProgram` / `isPayToTaproot`
  (TPR-001), the `SCRIPT_VERIFY_TAPROOT` flag gate (TPR-002), the
  P2SH-wrapped anyone-can-spend classification (TPR-003) and the P2A
  anchor template (TPR-004).
* **Witness structure for taproot** — annex detection (TPR-005), the
  key-path condition (TPR-007) and the script-path trigger (TPR-008),
  the control-block size gate (TPR-009) and leaf-version extraction
  (TPR-010).
* **Annex rules** — the annex hash `sha_annex` (TPR-006).
* **Tagged-hash construction pin** — TPR-047 (the
  `SHA256(SHA256(tag)‖SHA256(tag)‖msg)` construction, pinned as a
  congruence/definitional theorem over the Schnorr module's `taggedHash`).

Ground truth @cce32b168: `script.cpp:IsPayToTaproot:241-246`,
`IsPayToAnchor:216-222`, `interpreter.cpp:VerifyWitnessProgram
:1957-2008` (annex detection 1961-1969, key-path 1970-1975, script-path
1976-1982), `interpreter.h:244-247`
(TAPROOT_CONTROL_{BASE,NODE,MAX}_SIZE), `hash.cpp:TaggedHash:85-91`,
BIP341 §"Script validation" + §"Constructing and spending Taproot
outputs".

## Deliberate layering

This module is a PURE byte-level spec layer: it imports only
`TapTweak` (the Taproot module, for the TPR-047 pin) and `Data.Basic` (the
CompactSize encoder). The interpreter-side counterpart of the same
rules is `verifyWitnessProgram` taproot branch
(`Bitcoin.Interpreter.Defs`), which the interpreter delta layer owns; the theorems here are
about THESE defs, and the Taproot completion notes map each row to both.

VERIFIED = defs + sorry-free theorems + axiom pins + wallet-vector
conformance (spec/Test/Crypto/TaprootProgramTest.lean); PROPOSED = the
cross-module mapping into the interpreter delta layer's interpreter branch.
-/

namespace Bitcoin.Crypto.Taproot.Program

open Bitcoin.Data (compactSizeEnc serU8)
open Bitcoin.Crypto.Seam.Hash.Sha256 (sha256)
open Bitcoin.Crypto.Seam.Hash (sha256_size)
open Bitcoin.Crypto.Schnorr (taggedHash)

/-! ## TPR-001 — the P2TR output template -/

/-- `script.cpp:IsPayToTaproot:241-246` — witness v1 with a 32-byte
program. The consensus template of a Taproot output (BIP341: "A
Taproot output is a native SegWit output with version number 1, and a
32-byte witness program"). -/
@[rule "TPR-001"]
def p2trProgram (version : Nat) (program : ByteArray) : Bool :=
  version = 1 ∧ program.size = 32

/-- `IsPayToTaproot` on a full scriptPubKey: decode the witness-program
template (`script.cpp:IsWitnessProgram:250-264`, same shape as
`isWitnessProgram`) and apply `p2trProgram`. -/
@[rule "TPR-001"]
def isPayToTaproot (spk : ByteArray) : Bool :=
  if 4 ≤ spk.size ∧ spk.size ≤ 42 then
    let v := (spk.get! 0).toNat
    if v = 0 ∨ (0x51 ≤ v ∧ v ≤ 0x60) then
      let plen := (spk.get! 1).toNat
      if plen + 2 = spk.size ∧ p2trProgram (if v = 0 then 0 else v - 0x50) (spk.extract 2 spk.size)
      then true else false
    else false
  else false

/-- The serialized P2TR template for a 32-byte program: `OP_1 <32B>`
= `0x5120 ‖ program` (script.cpp `CScript << OP_1 << ToByteVector`)
— the wallet-side constructor matching every BIP341 wallet-vector
`scriptPubKey`. -/
def p2trScript (program : ByteArray) : ByteArray :=
  serU8 0x51 ++ serU8 32 ++ program

/-- Recognition introduction form: a scriptPubKey of exactly
`OP_1 <32B>` shape (v-byte 0x51, length byte 32, total 34 bytes) is
P2TR iff the trailing 32 bytes form the program — the round-trip
against `p2trScript` (the wallet-vector constructor). -/
theorem isPayToTaproot_intro (spk program : ByteArray)
    (hv : (spk.get! 0).toNat = 0x51) (hplen : (spk.get! 1).toNat = 32)
    (hlen : spk.size = 34) (hprog : spk.extract 2 34 = program) :
    isPayToTaproot spk = (program.size = 32) := by
  unfold isPayToTaproot p2trProgram
  rw [hlen, hprog, hv, hplen]
  by_cases hsz32 : program.size = 32
  · simp [hsz32]
  · simp [hsz32]

/-- Round-trip: `isPayToTaproot (p2trScript prog)` holds iff `prog` is
32 bytes (the template recognition on its own constructor output). -/
theorem isPayToTaproot_p2trScript (program : ByteArray) :
    isPayToTaproot (p2trScript program) = (program.size = 32) := by
  have h2 : (serU8 0x51 ++ serU8 32).size = 2 := rfl
  have hg0 : ((p2trScript program).get! 0).toNat = 0x51 := by
    unfold p2trScript serU8; rfl
  have hg1 : ((p2trScript program).get! 1).toNat = 32 := by
    unfold p2trScript serU8; rfl
  have hsz : (p2trScript program).size = 2 + program.size := by
    unfold p2trScript; rw [ByteArray.size_append, h2]
  have hext : (p2trScript program).extract 2 (p2trScript program).size = program := by
    unfold p2trScript
    rw [show (serU8 0x51 ++ serU8 32 ++ program).size = 2 + program.size from
      by rw [ByteArray.size_append, h2]]
    exact ByteArray.extract_append_eq_right h2.symm (by omega)
  unfold isPayToTaproot
  rw [hext, hg0, hg1, hsz]
  by_cases hsz32 : program.size = 32
  · simp [p2trProgram, hsz32]
  · simp [p2trProgram, hsz32]

/-! ## TPR-002 — the TAPROOT flag gate -/

/-- The taproot lane is entered only when `SCRIPT_VERIFY_TAPROOT` is
set (interpreter.cpp:1959: `if (!flags.verify_script_verify_taproot) {
set_success; return; }` in the v1-32-native branch — here as the pure
classification Core's `if` implements: without the flag the spend
succeeds REGARDLESS of the witness). -/
@[rule "TPR-002"]
def taprootLane (flagsTaproot : Bool) (version : Nat) (program : ByteArray)
    (isP2SH : Bool) : Bool :=
  flagsTaproot ∧ p2trProgram version program ∧ ¬ isP2SH

/-- TPR-002 (gate side): with the flag off, the v1-32-native witness
program is NOT routed to the taproot lane — Core falls through to
`set_success` (anyone-can-spend semantics preserved pre-activation). -/
theorem taprootLane_off (version : Nat) (program : ByteArray) (isP2SH : Bool) :
    taprootLane false version program isP2SH = false := by
  unfold taprootLane; simp

/-- TPR-002 (accept side): the flag gate is the ONLY flag input — when
it is on, the lane depends only on (version, program, isP2SH), i.e.
the gate is consensus-pure (no policy leakage into lane selection). -/
theorem taprootLane_pure (v₁ v₂ : Nat) (p₁ p₂ : ByteArray) (i₁ i₂ : Bool)
    (hv : v₁ = v₂) (hp : p₁ = p₂) (hi : i₁ = i₂) (f : Bool) :
    taprootLane f v₁ p₁ i₁ = taprootLane f v₂ p₂ i₂ := by
  unfold taprootLane; rw [hv, hp, hi]

/-! ## TPR-003 — P2SH-wrapped v1 = anyone-can-spend -/

/-- TPR-003: a v1-32 witness program reached THROUGH P2SH
(`isP2SH = true`) is not a taproot spend — BIP341's "native only"
clause (interpreter.cpp:1957's `!p2sh` condition; the wrapped spend
falls through to the upgradable-program pass-through, i.e. today the
coins are unencumbered by taproot rules). -/
@[rule "TPR-003"]
theorem taprootLane_p2sh_wrapped (flagsTaproot : Bool) (version : Nat)
    (program : ByteArray) :
    taprootLane flagsTaproot version program true = false := by
  unfold taprootLane; simp

/-- TPR-003 (positive): the native lane classification for a v1-32
program under the active flag. -/
theorem taprootLane_native (flagsTaproot : Bool) (program : ByteArray)
    (h : program.size = 32) :
    taprootLane flagsTaproot 1 program false = flagsTaproot := by
  unfold taprootLane p2trProgram
  simp [h]

/-! ## TPR-004 — the P2A anchor -/

/-- `CScript::IsPayToAnchor` (script.cpp:216-222 @cce32b168): witness
v1, 2-byte program `0x4e73`. Transliterated from
`Bitcoin.Interpreter.Defs.isPayToAnchor` is the same def in the
interpreter layer; this is the recognition-layer twin so the row can
carry a Crypto-side target). -/
@[rule "TPR-004"]
def isPayToAnchor (version : Nat) (program : ByteArray) : Bool :=
  version = 1 ∧ program.size = 2 ∧ (program.get! 0).toNat = 0x4e ∧
    (program.get! 1).toNat = 0x73

/-- The P2A anchor program bytes. -/
def p2aProgram : ByteArray := serU8 0x4e ++ serU8 0x73

/-- TPR-004: the anchor template recognizes exactly `OP_1 <0x4e73>` —
and per interpreter.cpp:2000-2001 such a spend validates
UNCONDITIONALLY (any witness, no key check; the "ephemeral anchor"
commitment output). -/
theorem isPayToAnchor_p2a :
    isPayToAnchor 1 p2aProgram = true := by
  have hg0 : ((p2aProgram.get! 0)).toNat = 0x4e := by
    unfold p2aProgram serU8; rfl
  have hg1 : ((p2aProgram.get! 1)).toNat = 0x73 := by
    unfold p2aProgram serU8; rfl
  have hsz : p2aProgram.size = 2 := by
    unfold p2aProgram serU8
    rw [ByteArray.size_append]; rfl
  unfold isPayToAnchor
  rw [hsz, hg0, hg1]
  simp

/-- TPR-004 (discrimination): the anchor is not the P2TR template —
the program is 2 bytes, so no 32-byte commitment confusion (the two
templates partition the v1 witness programs by program size). -/
theorem isPayToAnchor_not_p2tr :
    p2trProgram 1 p2aProgram = false := by
  have hsz : p2aProgram.size = 2 := by
    unfold p2aProgram serU8
    rw [ByteArray.size_append]; rfl
  unfold p2trProgram
  rw [hsz]
  simp

/-! ## TPR-005 — annex detection -/

/-- Annex detection (interpreter.cpp:1961-1969): with ≥2 witness items,
the LAST item is the annex iff it is nonempty and starts with the
0x50 tag. `SpanPopBack` semantics: the annex is POPPED before spend
classification. -/
@[rule "TPR-005"]
def isAnnex (items : List ByteArray) : Bool :=
  2 ≤ items.length ∧ (items.getLast!).size ≠ 0 ∧
    ((items.getLast!).get! 0).toNat = 0x50

/-- TPR-005 (deterministic split): witness stacks classify into
annex / no-annex exhaustively — `isAnnex` is decidable and total. -/
theorem isAnnex_total (items : List ByteArray) :
    isAnnex items = true ∨ isAnnex items = false := by
  by_cases h : isAnnex items = true
  · exact Or.inl h
  · exact Or.inr (by simpa using h)

/-- TPR-005 (empty stack): no annex on the empty witness (the
interpreter's `witness.length ≥ 1` guard comes first; `isAnnex []` is
false by the arity conjunct). -/
theorem isAnnex_nil : isAnnex [] = false := by
  unfold isAnnex; simp

/-- TPR-005 (single item): a 1-item witness has no annex — the
key-path spend's bare signature is never read as an annex (BIP341:
"if there are at least two witness elements, ..."). -/
theorem isAnnex_single (a : ByteArray) : isAnnex [a] = false := by
  unfold isAnnex; simp

/-- TPR-005 (tag boundary): a last item STARTING with 0x50 is the
annex regardless of the rest of its bytes; a last item whose first
byte differs is not. -/
theorem isAnnex_tag (items : List ByteArray) (a : ByteArray)
    (h₁ : 2 ≤ items.length) (h₂ : a.size ≠ 0)
    (hb : ((a.get! 0).toNat = 0x50) ↔ ((items.getLast!).get! 0).toNat = 0x50)
    (hs : items.getLast! = a) :
    isAnnex items = (a.size ≠ 0 ∧ (a.get! 0).toNat = 0x50) := by
  unfold isAnnex
  rw [hs]
  simp [h₁, h₂, hb]

/-! ## TPR-006 — the annex hash -/

/-- A CompactSize encoding is never empty (it always carries at least
the 1-byte marker). -/
theorem compactSizeEnc_size_pos (n : Nat) : 0 < (compactSizeEnc n).size := by
  have hs1 : ∀ x : UInt8, 0 < (serU8 x).size := by
    intro x; simp [serU8, ByteArray.size_push]
  have hser : ∀ (x : UInt8) (b : ByteArray), 0 < (serU8 x ++ b).size := by
    intro x b
    have : (serU8 x ++ b).size = 1 + b.size := by
      simp [serU8, ByteArray.size_push, ByteArray.size_append]
    omega
  unfold compactSizeEnc
  by_cases h1 : n < 0xfd
  · rw [ite_eq_left h1]; exact hs1 _
  · by_cases h2 : n ≤ 0xffff
    · rw [ite_eq_right h1, ite_eq_left h2]; exact hser _ _
    · by_cases h3 : n ≤ 0xffffffff
      · rw [ite_eq_right h1, ite_eq_right h2, ite_eq_left h3]; exact hser _ _
      · rw [ite_eq_right h1, ite_eq_right h2, ite_eq_right h3]; exact hser _ _

/-- `sha_annex` (interpreter.cpp:1964 + 1554-1556): `SHA256(CSize(len) ‖
annex)` — the HashWriter serializes the SPAN of the annex (its
CompactSize length, then the bytes INCLUDING the 0x50 tag). TPR-006's
computation half; "enters sighash iff present" is the Taproot module sighash lane
(ScriptExecutionData.annexPresent/annexHash, seam already
plumbs both, `schnorrEntry_execData_plumbed` = TPR-072). -/
@[rule "TPR-006"]
def annexHash (annex : ByteArray) : ByteArray :=
  sha256 (compactSizeEnc annex.size ++ annex)

/-- The annex hash is a 32-byte digest (single SHA256, TPR-046's
one-way-hash discipline for the annex field). -/
theorem annexHash_size (annex : ByteArray) :
    (annexHash annex).size = 32 := by
  unfold annexHash
  exact sha256_size _

/-- TPR-006 (domain separation): different annexes hash differently —
the hash is injective on its INPUT BYTES at the preimage level
(hash-of-append congruence: equal outputs force equal inputs only up
to collision-freedom, so the pin is the congruence form). -/
theorem annexHash_congr (a₁ a₂ : ByteArray) (h : a₁ = a₂) :
    annexHash a₁ = annexHash a₂ := by
  unfold annexHash; rw [h]

/-! ## TPR-007 / TPR-008 — spend-path classification -/

/-- The post-annex witness stack (Core `SpanPopBack`s the annex,
interpreter.cpp:1966-1969). -/
def spendStack (items : List ByteArray) : List ByteArray :=
  if isAnnex items then items.dropLast else items

/-- TPR-005 (annex consumption): when the last witness item is the
annex, the spend stack is exactly the pre-annex prefix — Core's
`SpanPopBack(stack)` at interpreter.cpp:1963 removes the last item. -/
@[rule "TPR-005"]
theorem spendStack_eq_dropLast (items : List ByteArray)
    (h : isAnnex items = true) :
    spendStack items = items.dropLast := by
  unfold spendStack
  rw [h]
  simp

/-- TPR-005 (population): every element of the post-annex spend stack
is a pre-annex element, i.e. an element of `items.dropLast`. -/
@[rule "TPR-005"]
theorem spendStack_mem_dropLast (items : List ByteArray)
    (h : isAnnex items = true) {x : ByteArray}
    (hx : x ∈ spendStack items) : x ∈ items.dropLast := by
  rw [spendStack_eq_dropLast items h] at hx
  exact hx

/-- TPR-005 (population, original witness): the consumed spend stack is
contained in the original witness stack. -/
@[rule "TPR-005"]
theorem spendStack_mem_original (items : List ByteArray)
    (h : isAnnex items = true) {x : ByteArray}
    (hx : x ∈ spendStack items) : x ∈ items := by
  have hx' := spendStack_mem_dropLast items h hx
  exact List.dropLast_subset items hx'

/-- TPR-005 (append form): a raw witness `items ++ [annex]` whose last
item is the annex spends exactly the pre-annex `items` — the whole
observable effect of Core's `SpanPopBack`. -/
@[rule "TPR-005"]
theorem spendStack_append_annex (items : List ByteArray) (annex : ByteArray)
    (h : isAnnex (items ++ [annex]) = true) :
    spendStack (items ++ [annex]) = items := by
  rw [spendStack_eq_dropLast _ h]
  exact List.dropLast_concat

/-- The three witness shapes of a taproot spend, classified exactly as
interpreter.cpp:1970-1979:

* `keyPath sig` — exactly 1 post-annex element (TPR-007): a single
  BIP340 signature against the OUTPUT key q;
* `scriptPath script control` — ≥2 elements (TPR-008): last = control
  block, second-to-last = script;
* `malformed` — the empty stack (SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY). -/
inductive SpendPath where
  | keyPath (sig : ByteArray)
  | scriptPath (script control : ByteArray)
  | malformed
  deriving Repr, DecidableEq, BEq

/-- The classification (order of Core's `if stack.size == 1` /
else branches). -/
@[rule "TPR-007", rule "TPR-008"]
def classifySpend (items : List ByteArray) : SpendPath :=
  match spendStack items with
  | [] => .malformed
  | [sig] => .keyPath sig
  | stack => .scriptPath stack[stack.length-2]! stack.getLast!

/-- TPR-007: a 1-item (annex-free) witness is a key-path spend against
the output key — the single element is the BIP340 signature
(interpreter.cpp:1970-1975). -/
theorem classifySpend_keyPath (sig : ByteArray) :
    classifySpend [sig] = .keyPath sig := by
  unfold classifySpend spendStack isAnnex; simp

/-- TPR-008: a 2-element witness whose last item is NOT annex-shaped
is a script-path spend: second-to-last = script, last = control block
(interpreter.cpp:1976-1979). -/
theorem classifySpend_scriptPath (script control : ByteArray)
    (h : isAnnex [script, control] = false) :
    classifySpend [script, control] = .scriptPath script control := by
  unfold classifySpend spendStack
  rw [h]
  simp

/-- TPR-005 + TPR-007 interaction: an annex-carrying key-path spend
(2 raw items, last = annex) classifies as key-path over the FIRST
item — the annex is popped before the arity test (BIP341 §"Script
validation": "If there are at least two witness elements ... the first
element ... is the signature" when one element remains). -/
theorem classifySpend_annex_keyPath (sig annex : ByteArray) :
    isAnnex [sig, annex] = true →
    classifySpend [sig, annex] = .keyPath sig := by
  unfold classifySpend spendStack isAnnex
  simp only [List.length_cons, decide_eq_true_eq]
  rintro ⟨-, hsize, htag⟩
  have h0 : annex.size ≠ 0 := by simpa using hsize
  have h1 : (annex.get! 0).toNat = 0x50 := by simpa using htag
  simp [h0, h1]

/-- TPR-008 + annex: script-path WITH annex — 3 raw items, last = annex;
classification sees the script + control pair. -/
theorem classifySpend_annex_scriptPath (script control annex : ByteArray) :
    isAnnex [script, control, annex] = true →
    classifySpend [script, control, annex] = .scriptPath script control := by
  unfold classifySpend spendStack isAnnex
  simp only [List.length_cons, decide_eq_true_eq]
  rintro ⟨-, hsize, htag⟩
  have h0 : annex.size ≠ 0 := by simpa using hsize
  have h1 : (annex.get! 0).toNat = 0x50 := by simpa using htag
  simp [h0, h1]

/-- TPR-008 (general script-path): for EVERY post-annex stack of length
at least two with no annex, Core's script-path arm reads the control
block from the last item and the script from the second-to-last item
(interpreter.cpp:1976-1979), not just for the two-item special case. -/
@[rule "TPR-008"]
theorem classifySpend_scriptPath_general (stack : List ByteArray)
    (hlen : 2 ≤ stack.length) (h : isAnnex stack = false) :
    classifySpend stack =
      .scriptPath stack[stack.length - 2]! stack.getLast! := by
  cases stack with
  | nil => simp at hlen
  | cons a t =>
    cases t with
    | nil => simp at hlen
    | cons b rest =>
      unfold classifySpend spendStack
      rw [h]
      simp

/-- TPR-008 (annex + general script-path): a raw witness of at least
three items whose last item is the annex classifies over the consumed
prefix `items.dropLast`; the second-to-last item is the script and the
last item is the control block. -/
@[rule "TPR-008"]
theorem classifySpend_annex_scriptPath_general (items : List ByteArray)
    (hlen : 3 ≤ items.length) (h : isAnnex items = true) :
    classifySpend items =
      .scriptPath items.dropLast[items.dropLast.length - 2]!
        items.dropLast.getLast! := by
  cases items with
  | nil => simp at hlen
  | cons a t =>
    cases t with
    | nil => simp at hlen
    | cons b t' =>
      cases t' with
      | nil => simp at hlen
      | cons c rest =>
        unfold classifySpend spendStack
        rw [h]
        simp [List.dropLast_cons_cons]

/-- TPR-008 (needed length fact): popping the annex leaves exactly one
fewer post-annex element, so `2 ≤ items.length - 1` is the raw arity
needed for a script-path classification. -/
@[rule "TPR-008"]
theorem spendStack_length_of_isAnnex (items : List ByteArray)
    (h : isAnnex items = true) :
    (spendStack items).length = items.length - 1 := by
  rw [spendStack_eq_dropLast items h]
  simp [List.length_dropLast]

/-! ## TPR-009 — control-block size gate -/

/-- The three taproot control constants (interpreter.h:244-247 @cce32b168).
FIX (was `:= 65`, 4161): Core's `TAPROOT_CONTROL_BASE_SIZE = 33`
(interpreter.cpp:1918 `XOnlyPubKey p{control.subspan(1, 32)}` = 1 version/
parity byte + 32 x-only internal-key bytes) and `_MAX_SIZE = 33 + 32·128 =
4129` (BIP341 depth ≤ 128). The 65/4161 lattice (65 = 33 + one node)
over-rejected the m = 0 single-leaf control (33 bytes) and over-accepted
m = 129 (4161) — kernel-verified (the offset pin). -/
def TAPROOT_CONTROL_BASE_SIZE : Nat := 33
def TAPROOT_CONTROL_NODE_SIZE : Nat := 32
def TAPROOT_CONTROL_MAX_SIZE : Nat := 33 + 128 * 32

@[rule "TPR-009"]
def controlBlockSizeOk (control : ByteArray) : Bool :=
  TAPROOT_CONTROL_BASE_SIZE ≤ control.size ∧
    control.size ≤ TAPROOT_CONTROL_MAX_SIZE ∧
    (control.size - TAPROOT_CONTROL_BASE_SIZE) % TAPROOT_CONTROL_NODE_SIZE = 0

/-- The gate in literal-constant form (`len = 33 + 32m`, `0 ≤ m ≤ 128`;
`33` = 1 version/parity byte + 32 internal-key bytes). FIX: the
statement previously baked the 65/4161 convention; repaired to the
Core-33 semantics (statement-fidelity path, documented in the commit). -/
theorem controlBlockSizeOk_sizes (control : ByteArray) :
    controlBlockSizeOk control = true ↔
      (33 ≤ control.size ∧ control.size ≤ 33 + 128 * 32 ∧
        (control.size - 33) % 32 = 0) := by
  unfold controlBlockSizeOk
  exact decide_eq_true_iff

/-- TPR-009 (minimal): the minimal control block is the 33-byte
m = 0 case (leaf hash directly under the output key). FIX:
was `h : control.size = 65` (Core: m = 1). -/
theorem controlBlockSizeOk_minimal (control : ByteArray)
    (h : control.size = 33) : controlBlockSizeOk control = true :=
  (controlBlockSizeOk_sizes control).mpr (by omega)

/-- TPR-009 (maximal): m = 128 → 4129 bytes is accepted (the deepest
tapscript tree; BIP341 §"Script validation"). FIX: was
`65 + 128 * 32` = 4161 (Core: m = 129, rejected). -/
theorem controlBlockSizeOk_maximal (control : ByteArray)
    (h : control.size = 33 + 128 * 32) :
    controlBlockSizeOk control = true :=
  (controlBlockSizeOk_sizes control).mpr (by omega)

/-- TPR-009 (reject): any size outside the 33+32m lattice fails —
e.g. a 66-byte control block ((66 − 33) % 32 = 33 % 32 ≠ 0). -/
theorem controlBlockSizeOk_66 (control : ByteArray)
    (h : control.size = 66) : controlBlockSizeOk control = false := by
  have h' : ¬ (33 ≤ control.size ∧ control.size ≤ 33 + 128 * 32 ∧
      (control.size - 33) % 32 = 0) := by
    rw [h]; decide
  exact decide_eq_false_iff_not.mpr h'

/-- TPR-009 (the m-recovery): every accepted size determines its m,
`0 ≤ m ≤ 128`, `size = 33 + 32m`. FIX: was `65 + 32m`. -/
theorem controlBlockSizeOk_m (control : ByteArray)
    (h : controlBlockSizeOk control = true) :
    ∃ m : Nat, 0 ≤ m ∧ m ≤ 128 ∧ control.size = 33 + 32 * m := by
  obtain ⟨h₁, h₂, h₃⟩ := (controlBlockSizeOk_sizes control).mp h
  refine ⟨(control.size - 33) / 32, by omega, ?_, ?_⟩
  · have hlt : control.size - 33 < 32 * 129 := by omega
    have := Nat.div_lt_of_lt_mul hlt
    omega
  · have := Nat.div_add_mod (control.size - 33) 32
    omega

/-! ## TPR-010 — leaf-version extraction -/

/-- Leaf-version extraction (interpreter.cpp:1983; interpreter.h:242):
`v = control[0] & 0xfe` — the low bit is the OUTPUT-KEY PARITY (TPR-011,
the tweak lane), the top 7 bits are the leaf version. -/
@[rule "TPR-010"]
def leafVersionOf (control : ByteArray) : Nat :=
  ((control.get! 0).toNat &&& 0xfe)

/-- TPR-010 (evenness): the extracted leaf version is EVEN — bit 0 of
the control byte is the OUTPUT-KEY PARITY (TPR-011, consumed by the
tweak lane, `OutputKey.lean`), so `& 0xfe` always clears it. -/
theorem leafVersionOf_even (control : ByteArray) :
    leafVersionOf control % 2 = 0 := by
  unfold leafVersionOf
  have h : ((control.get! 0).toNat &&& 0xfe) % 2 = 0 := by
    rcases Nat.mod_two_eq_zero_or_one _ with h0 | h1
    · exact h0
    · exfalso
      have := Nat.and_mod_two_eq_one.mp h1
      simp at this
  omega

/-- The tapscript leaf version constant (0xc0; interpreter.h:243,
`TAPROOT_LEAF_TAPSCRIPT`). -/
def TAPROOT_LEAF_TAPSCRIPT : Nat := 0xc0

/-- The tapscript leaf version is even (it is a leaf VERSION — the
parity bit position is 0). -/
theorem tapscriptLeaf_even : TAPROOT_LEAF_TAPSCRIPT &&& 1 = 0 := by
  decide

/-! ## TPR-047 — the tagged-hash construction (pin) -/

/-- TPR-047: the tagged-hash construction
`SHA256(SHA256(tag) ‖ SHA256(tag) ‖ msg)` — pinned as the definitional
unfolding of the Schnorr module's `taggedHash`, the construction BIP341 reuses for
TapTweak (TPR-015, the Taproot module) / TapLeaf (TPR-012) / TapSighash (TPR-032) /
the annex-free single-SHA256 discipline (TPR-046: exactly ONE sha256
compression over the doubled-tag preimage — see `taggedHash_size`
below: 32-byte digest, no double hashing). -/
@[rule "TPR-047"]
theorem taggedHash_unfold (tag msg : ByteArray) :
    taggedHash tag msg =
      sha256
        (sha256 tag ++
         sha256 tag ++ msg) := rfl

/-! ## TPR-022 / TPR-071 — the BIP342 validation weight budget -/

/-- Witness-serialized size of a stack (Core
`::GetSerializeSize(witness.stack)` — per item CompactSize(length) +
bytes; same def as `Bitcoin.Interpreter.Defs.witnessSerSize`,
restated here as the Crypto-side pin for TPR-071). -/
def witnessSerSize (items : List ByteArray) : Int :=
  items.foldl (fun acc d => acc + Int.ofNat ((compactSizeEnc d.size).size + d.size)) 0

/-- VALIDATION_WEIGHT_OFFSET (interpreter.h; BIP342 §Resource limits). -/
def VALIDATION_WEIGHT_OFFSET : Int := 50

/-- TPR-022: the BIP342 validation-weight budget initializes to
`serialized witness size + 50 WU` (interpreter.cpp:1991:
`ed.validation_weight_left = ::GetSerializeSize(witness.stack) +
VALIDATION_WEIGHT_OFFSET`). -/
@[rule "TPR-022"]
def validationWeightInit (witness : List ByteArray) : Int :=
  witnessSerSize witness + VALIDATION_WEIGHT_OFFSET

/-- TPR-071: the annex COUNTS — the budget is computed over the WHOLE
witness stack (annex included), BEFORE the annex is popped for spend
classification (interpreter.cpp:1991 serializes `witness.stack`; the
pop at 1961-1969 only affects the sighash/verification data). Pin: a
witness with annex has a STRICTLY larger budget base than without
(strictly, since the annex item contributes its CompactSize + size ≥
2). -/
@[rule "TPR-071"]
theorem validationWeightInit_annex_included (items : List ByteArray)
    (annex : ByteArray) (h : isAnnex (items ++ [annex]) = true) :
    witnessSerSize (items ++ [annex]) >
      witnessSerSize ((items ++ [annex]).dropLast) := by
  unfold isAnnex at h
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨hlen, -, -⟩ := h
  have hdrop : ((items ++ [annex]).dropLast) = items := by
    simp [List.dropLast_append, hlen]
  rw [hdrop]
  have happend : witnessSerSize (items ++ [annex]) =
      witnessSerSize items + Int.ofNat ((compactSizeEnc annex.size).size + annex.size) := by
    unfold witnessSerSize
    rw [List.foldl_append]
    simp
  have hposNat : 0 < (compactSizeEnc annex.size).size + annex.size := by
    have h1 : 0 < (compactSizeEnc annex.size).size :=
      compactSizeEnc_size_pos _
    omega
  rw [happend]
  have hb : (0:Int) < Int.ofNat ((compactSizeEnc annex.size).size + annex.size) :=
    Int.ofNat_lt.mpr hposNat
  have h2 : 0 + witnessSerSize items <
      Int.ofNat ((compactSizeEnc annex.size).size + annex.size) + witnessSerSize items :=
    Int.add_lt_add_right hb (witnessSerSize items)
  omega

/-! ## Axiom footprints (the Schnorr and Taproot modules style: `#guard_msgs in #print axioms`)

All sorry-free; footprints ⊆ the standard trio `[propext, Classical.choice,
Quot.sound]` (choice enters only via `by_cases` on undecidable-looking
goals — here everything is decidable, so most pins are the pair).
-/

/-- info: 'Bitcoin.Crypto.Taproot.Program.isPayToTaproot_p2trScript' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms isPayToTaproot_p2trScript

/-- info: 'Bitcoin.Crypto.Taproot.Program.taprootLane_off' depends on axioms: [propext] -/
#guard_msgs in #print axioms taprootLane_off

/-- info: 'Bitcoin.Crypto.Taproot.Program.taprootLane_p2sh_wrapped' depends on axioms: [propext] -/
#guard_msgs in #print axioms taprootLane_p2sh_wrapped

/-- info: 'Bitcoin.Crypto.Taproot.Program.isPayToAnchor_p2a' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms isPayToAnchor_p2a

/-- info: 'Bitcoin.Crypto.Taproot.Program.isAnnex_total' depends on axioms: [propext] -/
#guard_msgs in #print axioms isAnnex_total

/-- info: 'Bitcoin.Crypto.Taproot.Program.classifySpend_annex_keyPath' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms classifySpend_annex_keyPath

/-- info: 'Bitcoin.Crypto.Taproot.Program.classifySpend_annex_scriptPath' depends on axioms: [propext] -/
#guard_msgs in #print axioms classifySpend_annex_scriptPath

/-- info: 'Bitcoin.Crypto.Taproot.Program.controlBlockSizeOk_m' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms controlBlockSizeOk_m

/-- info: 'Bitcoin.Crypto.Taproot.Program.leafVersionOf_even' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms leafVersionOf_even

/-- info: 'Bitcoin.Crypto.Taproot.Program.taggedHash_unfold' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms taggedHash_unfold

/-- info: 'Bitcoin.Crypto.Taproot.Program.validationWeightInit_annex_included' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms validationWeightInit_annex_included

end Bitcoin.Crypto.Taproot.Program
