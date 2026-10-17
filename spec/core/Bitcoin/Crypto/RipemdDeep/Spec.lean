import Bitcoin.Crypto.RipemdDeep.SpecTables

/-!
# Bitcoin.Crypto.RipemdDeep.Spec — the kernel-decidable C mirror (S06 U3)

`Bitcoin.Crypto.RipemdDeep.SpecTables` (U2) pinned the r/s/k tables:
clones `S_*` = the consensus-path originals `RMD_*` (`Hashes.lean:166-191`)
= the C `Transform` call-sequence extraction (anchors/ripemd160.cpp
L64-222), **zero-axiom** rfl-pins + len/spot decide-pins (U2 commit
8eeaea3), negative-control'd (1 wrong entry breaks the pin).

This file mirrors the two remaining `Transform` layers, C-verbatim:

* `rolS` = C `rol` L36: `(x << i) | (x >> (32 - i))` — **NO `% 32`**
  (C has none; s-domain = [5,15] ∪ {10}, see `rolS_domain` in proofs).
* `rmdRoundS j x st` = C `Round` L37-41 verbatim:
  `Round(a, b, c, d, e, f, x, k, r) { a = rol(a + f + x + k, r) + e;
  c = rol(c, 10); }` — the left/right 10-tuple tower: `tL := (rolS (a +
  fL rnd b c d + kL rnd + x[rL j]) (sL j)) + e`, `tR` mirrored
  (f2/rR/kR/sR = the C macro mirror R{g+1}1 / R{5-g}2, `f := f_{g+1}`
  left vs `f := f_{5-g}` right), state `(e, tL, b, rolS c 10, d)` per
  line. f/k/x/r/s notation = the C L37-41 args; our tables = U2 clones.
* `rmdCompressS h block off` = C `Transform` L57-232: x-load = 16 ×
  `ReadLE32(chunk + 4i)` (L58-61) as a **push-fold** (the F-S06-001
  fix: `Array.map` over `List.toArray` = the elaborator-stuck op),
  80-step `rmdRoundS` tower, combine L225-231
  `#[h[1]+c1+d2, h[2]+d1+e2, h[3]+e1+a2, h[4]+a1+b2, h[0]+t?+b1+c2]`
  (C L226-230: `t = s[0]; s[0] = s[1]+c1+d2; ... s[4] = t+b1+c2`).

The impl bridge lives in the proofs package
(`BitcoinProofs.RipemdDeep.Convert`): `rmdRoundR`/`rmdCompressR` = the
`rotl32`/`RMD_*`-twin of `rmdRoundS`/`rmdCompressS`
(argument-exact), `rolS_eq_rotl32` (s-domain congruence: `n % 32 = n`
for 0 < n < 32) + foldl congruence → `rmdCompressS_eq_rmdCompress`.
All theorems Convert-side; this file = C-verbatim defs, no theorems.
-/

namespace Bitcoin.Crypto.RipemdDeep

open Bitcoin.Interpreter (rmdF rmdF2 wordLE)

/-! ## `rolS` = C `rol` (anchors/ripemd160.cpp L36) -/

/-- `rol(x, i) = (x << i) | (x >> (32 - i))` — C L36 verbatim, NO `% 32`
(s-domain = [5,15] ∪ {10}; cf. the impl `rotl32` (Hashes.lean:45-47)
which is `% 32`-guarded — equal on the s-domain, see Convert.lean). -/
def rolS (x : UInt32) (n : Nat) : UInt32 :=
  (x <<< n.toUInt32) ||| (x >>> (32 - n).toUInt32)

/-! ## `rmdRoundS` = C `Round` (anchors/ripemd160.cpp L37-41) -/

/-- One 80-step-tower state: the left line `(a, b, c, d, e)` × the right
line `(aa, bb, cc, dd, ee)` (C `Transform` locals L59-60). -/
abbrev RState := (UInt32 × UInt32 × UInt32 × UInt32 × UInt32) ×
                 (UInt32 × UInt32 × UInt32 × UInt32 × UInt32)

/-- C `Round(a, b, c, d, e, f, x, k, r)` L37-41, one step `j` of the
160-step interleaved tower (L64-222): left step = `R{g+1}1` (C L43-49:
`f = f_{g+1}(b,c,d)`, `x = w[rL j]`, `k = kL g`, `r = sL j`), right
step = `R{5-g}2` (C L50-54: `f = f_{5-g}`, `x = w[rR j]`, `k = kR g`,
`r = sR j`), both lines `Round`-shaped L37-41:
`a' = rol(a + f + x + k, r) + e ; c' = rol(c, 10)`. -/
def rmdRoundS (j : Nat) (x : Array UInt32) (st : RState) : RState :=
  let (a, b, c, d, e) := st.1
  let (aa, bb, cc, dd, ee) := st.2
  let g := j / 16
  let tL := (rolS (a + rmdF g b c d + S_K1[g]! + x[S_R1[j]!]!) (S_S1[j]!)) + e
  let tR := (rolS (aa + rmdF2 g bb cc dd + S_K2[g]! + x[S_R2[j]!]!) (S_S2[j]!)) + ee
  ((e, tL, b, rolS c 10, d), (ee, tR, bb, rolS cc 10, dd))

/-! ## `rmdCompressS` = C `Transform` (anchors/ripemd160.cpp L57-232) -/

/-- C `Transform(s, chunk)` L57-232. x-load = 16 × `ReadLE32(chunk+4i)`
(L58-61) as a **push-fold** (NOT `(List.range 16).toArray.map` —
that Array.map op is the elaborator-stuck op of the impl
`rmdCompress` (Hashes.lean:212), F-S06-001); 80-step `rmdRoundS`
tower; combine L225-231:
`t = s[0]; s[0] = s[1]+c1+d2; s[1] = s[2]+d1+e2; s[2] = s[3]+e1+a2;
s[3] = s[4]+a1+b2; s[4] = t+b1+c2` (C L226-230; `t` = `h[0]`). -/
def rmdCompressS (h : Array UInt32) (block : ByteArray) (off : Nat) : Array UInt32 :=
  let x : Array UInt32 := (List.range 16).foldl (fun x i => x.push (wordLE block (off + 4*i))) #[]
  let st := (List.range 80).foldl (fun st j => rmdRoundS j x st)
    ((h[0]!, h[1]!, h[2]!, h[3]!, h[4]!), (h[0]!, h[1]!, h[2]!, h[3]!, h[4]!))
  let (a, b, c, d, e) := st.1
  let (aa, bb, cc, dd, ee) := st.2
  let t := h[0]!
  #[h[1]! + c + dd, h[2]! + d + ee, h[3]! + e + aa, h[4]! + a + bb, t + b + cc]

end Bitcoin.Crypto.RipemdDeep
