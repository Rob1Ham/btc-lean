import Bitcoin.Interpreter.Defs

/-!
# SCR-055 L-link probe — Lean side

Evaluates the model's `isPayToAnchor` (Defs.lean:523-526) and the P2A branch
of `verifyWitnessProgram` (Defs.lean:1319) on the same cases as
`p2a_link_probe.py`.  This is the model's own verdict, not a re-reading of
the source: the twin hook that `findings/handoffs/CELLS-to-TWIN-002-*` asks
for is supposed to mirror exactly these equations.

Run from the `spec/` directory (the `core` package must be built):

    lake build core
    lake env lean equiv/findings/wave64/61-p2a-l-link/p2a_link_probe.lean

Every `#eval` line carries its expected value in a comment; the output is
also recorded in `report.md` in this directory.
-/

open Bitcoin.Interpreter

/-- The two-byte P2A witness program `4e73`. -/
def p2aProgram : ByteArray := ⟨#[0x4e, 0x73]⟩
/-- Off-by-one neighbour: v1 program `4e74`. -/
def notP2aProgram : ByteArray := ⟨#[0x4e, 0x74]⟩

def wit0 : List ByteArray := []
def wit1 : List ByteArray := [⟨#[0x01]⟩]

#eval isPayToAnchor 1 p2aProgram        -- true
#eval isPayToAnchor 1 notP2aProgram    -- false
#eval isPayToAnchor 0 p2aProgram       -- false
#eval isPayToAnchor 16 p2aProgram      -- false
#eval isPayToAnchor 1 ⟨#[0x4e]⟩        -- false (size 1)

/-- `verifyWitnessProgram` with the default checker and the witness flag on. -/
def wp (pol : PolicyFlags) (wit : List ByteArray) (version : Nat)
    (prog : ByteArray) (isP2SH : Bool) : VerifyOutcome :=
  verifyWitnessProgram 200000 wit version prog { witness := true } pol
    (default : ScriptChecker) isP2SH

-- P2A branch: `!isP2SH ∧ isPayToAnchor` → .ok, before the discourage check.
#eval wp {} wit0 1 p2aProgram false                                  -- ok
#eval wp {} wit1 1 p2aProgram false                                  -- ok (witness ignored)
#eval wp { discourageUpgradableWitnessProgram := true } wit0 1 p2aProgram false
                                                                     -- ok (branch ordering)
-- The `!isP2SH` guard: a P2SH-wrapped P2A falls through to the tail.
#eval wp {} wit0 1 p2aProgram true                                   -- ok
#eval wp { discourageUpgradableWitnessProgram := true } wit0 1 p2aProgram true
                                                                     -- fail discourage…
-- Non-P2A v1 two-byte program: unencumbered future version → ok.
#eval wp {} wit0 1 notP2aProgram false                               -- ok
-- v0 20-byte program with an empty witness: mismatch.
#eval wp {} wit0 0 (ByteArray.mk (Array.replicate 20 0x11)) false
                                                                     -- fail witnessProgramMismatch
