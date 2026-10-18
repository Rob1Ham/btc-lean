import Bitcoin.Crypto.Seam.Interface
import Bitcoin.Data.Basic

/-!
# Bitcoin.Crypto.Seam.Mock — table-driven checker

The bootstrap checker the design calls for: verdicts come from
a pre-baked `(sig, pubkey) → Bool` table instead of real EC math
(This implementation ships "pre-baked verdicts" behind the frozen seam
if the crypto layer has not landed). Byte equality is `Bitcoin.Data.bytesBEq` so no
BEq instance assumptions creep in.

Theorems: table hits return `true`, misses return `false`, and the
checker is deterministic — the property `stubChecker_deterministic`
pinned in the axiom manifest generalizes to every table.
-/

namespace Bitcoin.Crypto.Seam.Mock

open Bitcoin.Data

/-- One verdict row: `(sig, pubkey)` pair plus the pre-baked verdict. -/
abbrev MockRow := (ByteArray × ByteArray) × Bool

/-- The verdict table: first matching row wins (Core's script test
framework semantics for `script_tests.json` expectations). -/
abbrev MockTable := List MockRow

/-- Table lookup: the verdict of the FIRST row whose sig and pubkey both
match byte-for-byte; no match ⇒ `false` (fail-closed, like Core's
missing-data handling). -/
def mockFind : MockTable → ByteArray → ByteArray → Bool
  | [], _, _ => false
  | ((s, p), v) :: t, sig, pk =>
      if bytesBEq s sig && bytesBEq p pk then v else mockFind t sig pk

/-- The table-driven checker: BOTH entry points consult the same table
(the seam's two entry points share the verdict store, exactly as
Core's one checker object backs both vtable slots). -/
def mockChecker (table : MockTable) : BaseSignatureChecker :=
  { checkECDSASignature := fun sig pk _ _ _ => mockFind table sig pk
    checkSchnorrSignature := fun sig pk _ _ => mockFind table sig pk }

/-- A row `(sig, pk, true)` anywhere in the table makes BOTH entry
points return true on `(sig, pk)` — the byte-equality is reflexive. -/
theorem mockChecker_hit (table : MockTable) (s p : ByteArray)
    (code : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    (mockChecker table).checkECDSASignature s p code v d
      = (mockChecker table).checkSchnorrSignature s p v d := by
  unfold mockChecker; rfl

theorem bytesBEq_refl (b : ByteArray) : bytesBEq b b = true := by
  unfold bytesBEq
  simp

/-- Verdict lookup is order-consistent: prefixing a NON-matching row
does not change the verdict for `(sig, pk)`. -/
theorem mockFind_skip (row : MockRow) (t : MockTable) (sig pk : ByteArray)
    (hm : (bytesBEq row.1.1 sig && bytesBEq row.1.2 pk) = false) :
    mockFind (row :: t) sig pk = mockFind t sig pk := by
  have hc : ¬((bytesBEq row.1.1 sig && bytesBEq row.1.2 pk) = true) := by
    rw [hm]; simp
  simp only [mockFind, if_neg hc]

/-- Empty table: fail-closed on both entry points. -/
theorem mockFind_nil (sig pk : ByteArray) : mockFind [] sig pk = false := rfl

/-- Determinism: repeated queries agree — the mock generalizes
`stubChecker_deterministic` (script evaluation is a pure function of
(tx, input, flags)). -/
theorem mockChecker_deterministic (table : MockTable)
    (sig pk code : ByteArray) (v : SigVersion) (d₁ d₂ : ScriptExecutionData) :
    (mockChecker table).checkECDSASignature sig pk code v d₁
      = (mockChecker table).checkECDSASignature sig pk code v d₂ := rfl

end Bitcoin.Crypto.Seam.Mock
