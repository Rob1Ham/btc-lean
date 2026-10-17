import Bitcoin.Interpreter.Defs

/-! FuelStability probe: stage-by-stage shape of `stepBody ⟨.pushBytes d,_,_⟩`
after `simp only [stepBody]` + splits. Each `exact h` FAILS on purpose and
dumps h's type. -/

namespace Bitcoin.Proofs.Theorems.FuelStability.Probe

open Bitcoin.Interpreter

example {ctx : Ctx} {d : ByteArray} {wire next : Nat} {st st' : State}
    (h : stepBody ctx ⟨.pushBytes d, wire, next⟩ st = .ok st') : True := by
  simp only [stepBody] at h
  exact h

example {ctx : Ctx} {d : ByteArray} {wire next : Nat} {st st' : State}
    (h : stepBody ctx ⟨.pushBytes d, wire, next⟩ st = .ok st') : True := by
  simp only [stepBody] at h
  split at h
  · exact h
  · exact h

example {ctx : Ctx} {d : ByteArray} {wire next : Nat} {st st' : State}
    (h : stepBody ctx ⟨.pushBytes d, wire, next⟩ st = .ok st') : True := by
  simp only [stepBody] at h
  split at h
  · exact h
  · split at h
    · exact h
    · exact h

example {ctx : Ctx} {d : ByteArray} {wire next : Nat} {st st' : State}
    (h : stepBody ctx ⟨.pushBytes d, wire, next⟩ st = .ok st') : True := by
  simp only [stepBody] at h
  split at h
  · exact h
  · split at h
    · exact h
    · split at h
      · exact h
      · split at h
        · exact h
        · exact h

end Bitcoin.Proofs.Theorems.FuelStability.Probe
