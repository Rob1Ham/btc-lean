import Bitcoin.Activation.Interface

/-!
# BitcoinProofs.Theorems.Exhaust.LeafVersionSweep — M02 (Review-6): taproot leaf-version sweep

The full 256-entry sweep over the control-block version byte: which byte values
mark a **valid tapscript leaf**, plus the **control-block parse-domain** theorem
(the size lattice accepted by Core's script-path gate).

## Ground truth (pinned)

- Bitcoin Core v32.99 @ `cce32b168` (DECISIONS.md D-001), local probe copy
  `build/scratch/X03/src/interpreter.h:242-247`,
  `interpreter.cpp:1979-1997`:
  - `TAPROOT_LEAF_MASK = 0xfe`, `TAPROOT_LEAF_TAPSCRIPT = 0xc0` (h:242-243);
  - `TAPROOT_CONTROL_BASE_SIZE = 33`, `TAPROOT_CONTROL_NODE_SIZE = 32`,
    `TAPROOT_CONTROL_MAX_NODE_COUNT = 128`,
    `TAPROOT_CONTROL_MAX_SIZE = 33 + 32·128 = 4129` (h:244-247);
  - script path: control size must lie in `[33, 4129]` with
    `(size − 33) % 32 = 0`, else `SCRIPT_ERR_TAPROOT_WRONG_CONTROL_SIZE`
    (cpp:1979-1981); tapscript is *executed* iff
    `(control[0] & 0xfe) == 0xc0` (cpp:1988-1994); any other leaf version ⇒
    no script execution, the spend succeeds (anyone-can-spend, cpp:1996-1997).
- BIP341:70: `v = c[0] & 0xfe` is the leaf version; bit 0 of `c[0]` is the
  output-key parity, so `v` is always even, and each version occupies an
  (even, odd) byte pair.
- BIP342:52: "The leaf version is 0xc0 (i.e. the first byte of the last witness
  element after removing the optional annex is 0xc0 **or 0xc1**), marking it as
  a tapscript spend." — exactly 2 of the 256 byte values.

Python cross-check: `scratch/M02/crosscheck.py` (W6suite tree) — zero
mismatches. Axiom probe: `scratch/M02/axcheck.lean`. All theorems sorry-free;
no `native_decide` (kernel `decide`/`rfl`/`omega` only).
-/

set_option maxRecDepth 32768

namespace BitcoinProofs.Theorems.Exhaust.LeafVersionSweep

/-! ## A. Pinned constants (Core interpreter.h:242-247) -/

/-- `TAPROOT_LEAF_MASK` (interpreter.h:242). -/
def LEAF_MASK : Nat := 0xfe

/-- `TAPROOT_LEAF_TAPSCRIPT` (interpreter.h:243). -/
def LEAF_TAPSCRIPT : Nat := 0xc0

/-- `TAPROOT_CONTROL_BASE_SIZE` (interpreter.h:244): 1 version/parity byte +
32 internal-key bytes. -/
def CONTROL_BASE_SIZE : Nat := 33

/-- `TAPROOT_CONTROL_NODE_SIZE` (interpreter.h:245). -/
def CONTROL_NODE_SIZE : Nat := 32

/-- `TAPROOT_CONTROL_MAX_NODE_COUNT` (interpreter.h:246): BIP341 caps the
taproot merkle depth at 128. -/
def CONTROL_MAX_NODE_COUNT : Nat := 128

/-- `TAPROOT_CONTROL_MAX_SIZE` (interpreter.h:247) = `33 + 32·128 = 4129`. -/
def CONTROL_MAX_SIZE : Nat :=
  CONTROL_BASE_SIZE + CONTROL_NODE_SIZE * CONTROL_MAX_NODE_COUNT

/-- The pinned constants in literal form (all `rfl`). -/
theorem control_constants :
    CONTROL_BASE_SIZE = 33 ∧ CONTROL_NODE_SIZE = 32 ∧
      CONTROL_MAX_NODE_COUNT = 128 ∧ CONTROL_MAX_SIZE = 33 + 32 * 128 :=
  ⟨rfl, rfl, rfl, rfl⟩

/-- The leaf version of a control byte, Core's mask extraction
(interpreter.cpp:1983: `control[0] & TAPROOT_LEAF_MASK`). -/
def leafVersion (b : Nat) : Nat := b &&& LEAF_MASK

/-- Core's tapscript test (interpreter.cpp:1988):
`(control[0] & TAPROOT_LEAF_MASK) == TAPROOT_LEAF_TAPSCRIPT`. -/
def isTapscriptByte (b : Nat) : Bool := leafVersion b == LEAF_TAPSCRIPT

/-- Division-form leaf version: the top 7 bits of the byte
(`b / 2 % 128`; bit 0 is the output-key parity lane, BIP341:70). -/
def leafVersionDiv (b : Nat) : Nat := (b / 2) % 128

/-- Division-form tapscript test: version `0x60` (= `0xc0 / 2`). -/
def isTapscriptByteDiv (b : Nat) : Bool := leafVersionDiv b == 0x60

/-! ## B. Evenness: the extracted leaf version is always even -/

/-- The mask extraction always clears bit 0 — bit 0 of the control byte is
the OUTPUT-KEY PARITY lane (BIP341:70; mask `0xfe`, interpreter.h:242). -/
theorem leafVersion_even (b : Nat) : leafVersion b % 2 = 0 := by
  unfold leafVersion
  rcases Nat.mod_two_eq_zero_or_one _ with h | h
  · exact h
  · exfalso
    have h1 := (Nat.and_mod_two_eq_one.mp h).2
    exact absurd h1 (by decide)

/-- Corollary: byte `0xc1` carries leaf version `0xc0` — the parity bit never
reaches the version lane (BIP341:70's even/odd byte pairs). -/
theorem leafVersion_0xc1 : leafVersion 0xc1 = 0xc0 := by rfl

/-! ## C. The 256-entry decide-matrix over the version byte -/

/-- **The sweep, as a computed list**: filtering all 256 byte values through
Core's tapscript test (kernel-evaluated). -/
def passList : List Nat := (List.range 256).filter isTapscriptByte

/-- Matrix verdict: exactly `0xc0` (192) and `0xc1` (193) pass —
BIP342:52's "0xc0 or 0xc1". -/
theorem passList_val : passList = [0xc0, 0xc1] := by rfl

/-- Count: exactly 2 of the 256 version bytes pass. -/
theorem passList_length : passList.length = 2 := by rw [passList_val]; rfl

/-- Count: exactly 254 of the 256 version bytes are NOT tapscript leaf
versions (they remain *valid spends* — anyone-can-spend per
interpreter.cpp:1996-1997 — but no script is executed under them). -/
theorem rejected_count :
    ((List.range 256).filter (fun b => !isTapscriptByte b)).length = 254 := by rfl

/-- **The decide-matrix** (pointwise): for every byte value `b < 256`,
Core's tapscript test holds iff `b ∈ {0xc0, 0xc1}`. -/
theorem matrix_byte (b : Nat) (hb : b < 256) :
    isTapscriptByte b = true ↔ (b = 0xc0 ∨ b = 0xc1) := by
  have h1 : b ∈ passList ↔ b ∈ List.range 256 ∧ isTapscriptByte b = true :=
    List.mem_filter ..
  have h2 : b ∈ passList ↔ (b = 0xc0 ∨ b = 0xc1) := by
    rw [passList_val]; simp
  rw [← h2, h1, List.mem_range]
  simp [hb]

/-- The same matrix over `Fin 256` (the version byte as a type). -/
theorem matrix (b : Fin 256) :
    isTapscriptByte b.val = true ↔ (b.val = 0xc0 ∨ b.val = 0xc1) :=
  matrix_byte b.val b.isLt

/-- Parity split: each passing byte is version `0xc0` with one of the two
output-key parities (BIP341:70's "even byte value and the immediately
following odd byte value"). -/
theorem parity_split (b : Nat) (hb : b < 256) :
    isTapscriptByte b = true ↔ ∃ p : Nat, p < 2 ∧ b = 0xc0 + p := by
  rw [matrix_byte b hb]
  constructor
  · rintro (rfl | rfl)
    · exact ⟨0, by decide, rfl⟩
    · exact ⟨1, by decide, rfl⟩
  · rintro ⟨p, hp, rfl⟩
    have hp' : p = 0 ∨ p = 1 := by omega
    rcases hp' with rfl | rfl <;> decide

/-! ## D. Division form: the general (∀ ℕ) leaf-version statement -/

/-- The top-7-bit version of a natural depends only on its low byte:
`(b / 2) % 128 = (b % 256) / 2` for ALL `b` (omega over the div/mod lattice). -/
theorem version_lift (b : Nat) : (b / 2) % 128 = (b % 256) / 2 := by omega

/-- General statement: the division-form version is the tapscript version
`0x60` iff the byte is `0xc0`/`0xc1` modulo 256. -/
theorem div_iff (b : Nat) :
    leafVersionDiv b = 0x60 ↔ (b % 256 = 0xc0 ∨ b % 256 = 0xc1) := by
  unfold leafVersionDiv
  omega

theorem isTapscriptByteDiv_iff (b : Nat) :
    isTapscriptByteDiv b = true ↔ leafVersionDiv b = 0x60 := by
  unfold isTapscriptByteDiv
  exact beq_iff_eq

/-- The division-form tapscript test, unrestricted: byte (mod 256) is
`0xc0`/`0xc1`. -/
theorem isTapscriptByteDiv_gen (b : Nat) :
    isTapscriptByteDiv b = true ↔ (b % 256 = 0xc0 ∨ b % 256 = 0xc1) := by
  rw [isTapscriptByteDiv_iff, div_iff]

/-- Kernel-evaluated bridge over all 256 bytes: Core's mask extraction
agrees with `2 · (top-7-bits division form)` on every byte value. -/
def bridgeVec : List Bool :=
  (List.range 256).map (fun b => leafVersion b == 2 * leafVersionDiv b)

theorem bridgeVec_all : bridgeVec = List.replicate 256 true := by rfl

/-- Bridge on the two live bytes. -/
theorem bridge_live :
    leafVersion 0xc0 = 2 * leafVersionDiv 0xc0 ∧
      leafVersion 0xc1 = 2 * leafVersionDiv 0xc1 := ⟨rfl, rfl⟩

/-! ## E. The control-block parse domain (size lattice) -/

/-- Core's script-path control-block size gate (interpreter.cpp:1979-1981):
`33 ≤ size ≤ 4129` and `(size − 33) % 32 = 0`. -/
@[rule "TPR-009"]
def controlSizeOk (n : Nat) : Bool :=
  (decide (33 ≤ n) && decide (n ≤ 33 + 32 * 128) && decide ((n - 33) % 32 = 0))

/-- Minimal control block: 33 bytes (version+parity byte, internal key; the
leaf sits directly under the output key, `m = 0`). -/
theorem controlSizeOk_33 : controlSizeOk 33 = true := by rfl

/-- Maximal control block: 33 + 32·128 = 4129 bytes (`m = 128`, the deepest
tapscript tree; BIP341 §"Script validation"). -/
theorem controlSizeOk_4129 : controlSizeOk CONTROL_MAX_SIZE = true := by rfl

/-- Off-lattice rejects (kernel-evaluated): one byte short, one node without
the base, one byte over a node boundary, one node past the depth cap
(`4161 = 33 + 32·129`, i.e. `m = 129 > 128`). -/
theorem controlSizeOk_rejects :
    controlSizeOk 32 = false ∧ controlSizeOk 34 = false ∧
      controlSizeOk 66 = false ∧ controlSizeOk (33 + 32 * 129) = false :=
  ⟨rfl, rfl, rfl, rfl⟩

/-- **The parse-domain theorem**: the size gate accepts exactly the lattice
`{33 + 32·m | 0 ≤ m ≤ 128}` — every accepted size recovers its node count
`m`, and every lattice point is accepted. -/
theorem controlSizeOk_iff (n : Nat) :
    controlSizeOk n = true ↔
      ∃ m : Nat, m ≤ 128 ∧ n = 33 + 32 * m := by
  unfold controlSizeOk
  simp only [Bool.and_eq_true, decide_eq_true_iff]
  constructor
  · rintro ⟨⟨h1, h2⟩, h3⟩
    refine ⟨(n - 33) / 32, ?_, ?_⟩
    · have hlt : n - 33 < 32 * 129 := by omega
      have := Nat.div_lt_of_lt_mul hlt
      omega
    · have := Nat.div_add_mod (n - 33) 32
      omega
  · rintro ⟨m, hm, rfl⟩
    refine ⟨⟨by omega, by omega⟩, by omega⟩

/-- The parse domain as a computed list over `33 … 4129`: exactly the 129
lattice points `33 + 32·m`, `m ≤ 128` (kernel-evaluated). -/
def sizeList : List Nat := (List.range (CONTROL_MAX_SIZE + 1)).filter controlSizeOk

theorem sizeList_val :
    sizeList = (List.range 129).map (fun m => 33 + 32 * m) := by rfl

theorem sizeList_length : sizeList.length = 129 := by rw [sizeList_val]; rfl

/-! ## F. The joint script-path gate -/

/-- The full script-path parse gate (interpreter.cpp:1979-1994): size
domain × version byte. -/
def controlGate (size cb0 : Nat) : Bool :=
  controlSizeOk size && isTapscriptByte cb0

/-- The joint gate theorem: a script-path witness parses into an *executed
tapscript* spend iff the control-block size is on the `33 + 32·m` lattice
(`m ≤ 128`) AND the version byte is `0xc0`/`0xc1`. -/
theorem controlGate_iff (size cb0 : Nat) (hb : cb0 < 256) :
    controlGate size cb0 = true ↔
      ((∃ m : Nat, m ≤ 128 ∧ size = 33 + 32 * m) ∧ (cb0 = 0xc0 ∨ cb0 = 0xc1)) := by
  unfold controlGate
  simp only [Bool.and_eq_true, controlSizeOk_iff, matrix_byte cb0 hb]
/-- The annex byte `0x50` can never masquerade as a tapscript version byte
(BIP341:70's annex-ambiguity footnote): `0x50 & 0xfe = 0x50 ≠ 0xc0`. -/
theorem annex_50_not_tapscript : isTapscriptByte 0x50 = false := by rfl

end BitcoinProofs.Theorems.Exhaust.LeafVersionSweep
