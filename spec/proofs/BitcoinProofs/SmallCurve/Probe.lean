/-!
# BitcoinProofs.SmallCurve.Probe — kernel-decidability gates (E10, U0)

Before the SmallCurve carbon copy is written, five questions must be
answered empirically by the LEAN KERNEL (not the elaborator), because
they decide the definition shapes of the whole lane (R6 / F-W14b-1):

* **P1** — `Nat.shiftRight` on 16-bit literals: does `decide` reduce
  `(x >>> i) % 2`?  (gates `bitsOf u := (List.range 16).map ...`,
  the runtime-computed bit list of the verifier's own `u1`, `u2`.)
* **P2** — the full `bitsOf`-map over `List.range 16` vs a literal
  `List Bool` equality.  (gates `mulP' (bitsOf u) P` — scalar mult
  structural in the 16 bits of a *runtime* scalar.)
* **P3** — one complete affine point op: `addRaw` with the secp256k1
  case table (doubling branch) where the field inverse is the
  STRUCTURAL Fermat exponentiation `invP' x = expB 65647 x bitsP2`
  over a literal 17-bit list.  This is the deepest single reduction
  in the eventual `verifyImpl'` (~35 `mulM` + one 17-round `expB`).
  Literals: `addRaw 1 31426 1 31426 = some (51285, 55626)` (= 2G).
* **P4** — the lax-DER parser (`Ecdsa/Der.lean:56-142` carbon)
  on a literal `ByteArray`, `parseDerLax sig₄ = some (171, 205)`.
  (gates the byte-level `verifyImpl'` carbon; ByteArray literals are
  written `ByteArray.mk (L.toArray)`.)
* **P5** — `parsePubKey`'s compressed branch on a literal 4-byte key
  (`G = (1, 31426)` compressed = `0x02 0x00 0x00 0x01`), including
  the `x ≥ p` reject and the on-curve check.

Every literal was fixed by the python oracle first
(the probe script `probe_lits.py`).

All `decide`s below must be kernel `sorry`-free reductions — if any
fails or hangs, the fallback is the F-W14b-1 route (hardcoded
literal bit lists everywhere), which would cost the parser-level
carbon copy (P4).
-/

namespace BitcoinProofs.SmallCurve.Probe

/-! ## P1 — `Nat.shiftRight` on literals -/

example : (65647 >>> 3) % 2 = 1 := by decide

example : (65171 >>> 9) % 2 = 1 := by decide

example : (31426 >>> 0) % 2 = 0 := by decide

/-! ## P2 — `bitsOf` map vs literal list

First version (no `maxRecDepth`) hit "maximum recursion depth (600)
reached" in the DECIDABILITY instance — E06's `DerBatteryCor.lean:35`
(215 kernel-`decide`s over 256-bit `parseDerLax` literals) sets
`maxRecDepth 100000` file-wide for exactly this reason. P2a = retry
with that. P2b/P2c = the same shape on scalars where the shift count
is a *variable* element index vs a literal (isolate the cost). -/

def bitsOf16 (x : Nat) : List Bool :=
  (List.range 16).map (fun i => (x >>> i) % 2 == 1)

set_option maxRecDepth 100000 in
example : bitsOf16 12345 = [true, false, false, true, true, true, false,
    false, false, false, false, false, true, true, false, false] := by
  decide

set_option maxRecDepth 100000 in
example : bitsOf16 65171 = [true, true, false, false, true, false, false,
    true, false, true, true, true, true, true, true, true] := by
  decide

/-! ## P3 — one `addRaw` (doubling branch) with the structural Fermat `invP'`

`P := 65647`, `bitsP2` = the 17 little-endian bits of `65645 = P - 2`
(python: `[T,F,T,T,F,T,T,F,F,F,F,F,F,F,F,F,T]`).  `invP' x = x^65645`
— the R6 structural replacement for secp's WF-recursive
`invP = invM P d` (extended Euclid). -/

def P : Nat := 65647

def addM (m x y : Nat) : Nat := (x + y) % m
def subM (m x y : Nat) : Nat := (x + m - y) % m
def mulM (m x y : Nat) : Nat := (x * y) % m

def expB (m x : Nat) : List Bool → Nat
  | [] => 1
  | b :: bs => mulM m (mulM m (expB m x bs) (expB m x bs)) (if b then x else 1)

def bitsP2 : List Bool :=
  [true, false, true, true, false, true, true, false, false, false,
   false, false, false, false, false, false, true]

def invP' (d : Nat) : Nat := expB 65647 d bitsP2

def negN (y : Nat) : Nat := subM 65647 0 y

def doubleRaw (x y : Nat) : Option (Nat × Nat) :=
  if y == 0 then none
  else
    let lam := mulM 65647 (mulM 65647 3 (mulM 65647 x x)) (invP' (addM 65647 y y))
    let x3 := subM 65647 (mulM 65647 lam lam) (addM 65647 x x)
    let y3 := subM 65647 (mulM 65647 lam (subM 65647 x x3)) y
    some (x3, y3)

def addRaw (x1 y1 x2 y2 : Nat) : Option (Nat × Nat) :=
  if x1 == x2 && y1 == y2 then doubleRaw x1 y1
  else if x1 == x2 && y1 == negN y2 then none
  else
    let lam := mulM 65647 (subM 65647 y2 y1) (invP' (subM 65647 x2 x1))
    let x3 := subM 65647 (subM 65647 (mulM 65647 lam lam) x1) x2
    let y3 := subM 65647 (mulM 65647 lam (subM 65647 x1 x3)) y1
    some (x3, y3)

/-! ### P3 decides — 2G and 3G (python: 2G = (51285, 55626),
3G = (4305, 5411)) -/

example : addRaw 1 31426 1 31426 = some (51285, 55626) := by
  decide

example : addRaw 51285 55626 1 31426 = some (4305, 5411) := by
  decide

end BitcoinProofs.SmallCurve.Probe
