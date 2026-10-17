import Bitcoin.Crypto.Taproot.Program

open Bitcoin.Crypto.Taproot.Program (p2trProgram isAnnex)

#print p2trProgram
#print isAnnex

-- shape A: decide-coercion?
example (v : Nat) (program : ByteArray) :
    p2trProgram v program = decide (v = 1 ∧ program.size = 32) := rfl

-- shape B: Iff face?
example (v : Nat) (program : ByteArray) :
    (p2trProgram v program = true) = (decide (v = 1 ∧ program.size = 32) = true) := rfl

-- shape C: isAnnex decide?
example (items : List ByteArray) :
    isAnnex items =
      decide (2 ≤ items.length ∧ (items.getLast!).size ≠ 0 ∧
        ((items.getLast!).get! 0).toNat = 0x50) := rfl

-- shape D: Iff variant
example (items : List ByteArray) :
    (isAnnex items = true) =
      (decide (2 ≤ items.length ∧ (items.getLast!).size ≠ 0 ∧
        ((items.getLast!).get! 0).toNat = 0x50) = true) := rfl
