import Bitcoin.Crypto.Schnorr.Verify
import BitcoinProofs.EcdsaDeep.SchnorrEquation

/-!
# [CROWNLINK] CrownSchnorr - the E08 extension: the 19 official BIP340
# vectors x the E08 BIP340-IFF crown (sample-consistency twin)

CROWNLINK, 2026-10-17, Unit 4 = the E08
extension lane (secondary objective). See the ECDSA-lane files
(CrownBattery/CrownLink/CrownLinkKernel/CrownLinkRun = the E05 x E06
bridge). THIS file is the same
CROWNLINK bridge, one lane over: E08's verify-equation IFF crown
(SchnorrEquation.lean 7df8f20, READ-ONLY here:
`verifyImpl_iff : verifyImpl sig pk msg = true <-> satisfiesEquation
sig pk msg`, sorry-free) x X02's 19 official BIP340 vectors
(SchnorrTest.lean = the generated bip-0340_test-vectors.csv
corpus, 9 accept / 10 reject) - via X02's REAL verifier
(`Bitcoin.Crypto.Schnorr.Verify.verifyImpl`, read-only).

Bridges (the CrownLink.lean twins, Schnorr-only opens):

* `crownSchnorrLink` - THE bridge: for a row r whose verifyImpl verdict
  equals the battery's expected value (hv), expected = true is
  EQUIVALENT to the E08 crown's equation side satisfiesEquation.
  Proof = `rw [<- verifyImpl_iff]` + hv (E06-lane b2/b3 shape verbatim).
* `crownSchnorrLink_rej` (10 rows) - expected-reject rows are dead on
  the equation side; `crownSchnorrLink_acc` (9 rows) - expected-accept
  rows satisfy it (E08's soundness `verifyImpl_true_satisfies`).
* `crownSchnorr_corpus` + `_split` - the corpus-level statement (19
  rows, under the per-row verdict pinning hvs).

Verdict pinning = the ECDSA-lane 3 layers, but the FRONTIER is one
lane over (F-CK-003, empirical probeS 19/20 examples green-ex-1):

* **kernel layer = 1/19 rows**: `b340-14` (pk = p+1) - the ONLY
  kernel-decidable BIP340 row. `liftX x := if P <= x then none else
  ...isSqrt (liftCand x)...` fires the `P <= x` gate BEFORE
  `sqrtP`/`expM` -> verifyImpl = false by kernel `decide`, and the
  crown-kill `not satisfiesEquation` via `rw [<- verifyImpl_iff]` +
  `decide` (CrownLinkKernel's 17-row shape, 1 row here). Both
  hypothesis-free.
* **the other 18/19 = the R6 wall (WF-recursive `expM`/`mulP`)**:
  the 32-byte x-only pk gives verifyImpl NO parse layer (ECDSA-lane's
  8 parse-rejects + 8 of 9 pk-structural-rejects are kernel-green
  THERE; here there is no tag/length/hybrid/onCurveN path), and every
  on-curve-potential pk row (x < p) reaches `isSqrt (liftCand x)` =
  `expM` - including b340-05 (pk off curve), b340-11 (r off curve),
  b340-12 (r = p: pk DFF1.. x < p -> liftX -> isSqrt -> wall) and all
  9 accepts (b340-15..18 = msg 0/1/17/100B, msg NOT size-gated).
  probeS (24.6s/1.75GB): 18 "decide failed to reduce" + b340-14
  verdict + crown-kill green.
* **runtime layer = ALL 19 rows**: `runVectors` (the
  SchnorrTest.lean:122-131 / CrownLinkRun.lean:44-59 main shape),
  compiled-interpreter execution of verifyImpl vs the battery's
  expected verdicts (NO native_decide D-004/D2, NO kernel decide
  through the WF layer R6). Exit 0 + `TOTAL 19 FAILURES 0` = all 19
  verdicts = expected = (with crownSchnorrLink_corpus) all 19 battery
  verdicts pass through the E08 crown's equation side: 9 accept-rows
  satisfy satisfiesEquation, 10 reject-rows are dead on it.

Corpus: 19 rows read VERBATIM from SchnorrTest.lean `vectors`
(emit_crownschnorr.py = the verbatim-check emitter; (name, expected,
pk, msg, sig) tuples -> CrownSRow (name, expected, sig, pk, msg)).
The official per-vector comments (the bip-0340 property map) are
carried on the row lines. Corpus-integrity pins = kernel decides
(19 / 9+10; own crownSCount, the v4.35.0 List.count avoidance).
`fromHex`/`hexDigitVal` = the harness read-only copies
(SchnorrTest.lean:40-57). NO mathlib.

E08 crown build note: SchnorrEquation.lean (E08 7df8f20, direct-lean
route) was built read-only for this file: the one legal foreground
flock `lake build BitcoinProofs.EcdsaDeep.SchnorrEquation` = 13/13
green RC=0 3.5s = the independent-witness note (X02's verifyImpl +
E08's iff, neither touched).

Honesty note (CrownLink.lean's, one lane over): crownSchnorrLink is a
conditional per-row theorem; its logical content is E08's
verifyImpl_iff (the crown); its sample content = the 19 rows + the 3
verdict-pinning layers (1 kernel + 19 runtime, the kernel layer
covering the 1 row of 19 the R6 wall leaves visible). The equation
side is NOT re-evaluated per row at the Prop level (satisfiesEquation
is Classical); what is checked per row is verifyImpl (kernel for
b340-14, runtime for all 19), and the E08 crown is what makes that
check a check of the EQUATION. No sorry, no native_decide, no new
axioms (footprints pinned below).
-/

namespace BitcoinProofs.EcdsaDeep.CrownSchnorr

open Bitcoin.Crypto.Schnorr.Verify
open BitcoinProofs.EcdsaDeep.SchnorrEquation

set_option maxRecDepth 100000

/-- Parse a hex string into a ByteArray (test infra only; copied from
the harness, SchnorrTest.lean:40-57, read-only). -/
def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

/-- A battery row (CrownRow's shape): `name` (SchnorrTest id =
bip-0340 vector number), `expected` (the official BIP340 verdict),
and the three verifyImpl inputs `sig`/`pk`/`msg` (BIP340: sig =
r‖s 64B, pk = x-only 32B, msg = any length). -/
structure CrownSRow where
  name : String
  expected : Bool
  sig : ByteArray
  pk : ByteArray
  msg : ByteArray

/-- **The CROWNSCHNORR corpus** = the 19 official BIP340 vectors,
read verbatim from SchnorrTest.lean `vectors`
(emit_crownschnorr.py). 9 accept / 10 reject; the official
per-vector comments carried on the row lines. -/
def crownSchnorr : List CrownSRow := [
    -- vector 0: (canonical accept case)
    ⟨"b340-00", true, fromHex
    "E907831F80848D1069A5371B402410364BDF1C5F8307B0084C55F1CE2DCA821525F66A4A85EA8B71E482A74F382D2CE5EBEEE8FDB2172F477DF4900D310536C0", fromHex
    "F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9", fromHex
    "0000000000000000000000000000000000000000000000000000000000000000"⟩,
    -- vector 1: (canonical accept case)
    ⟨"b340-01", true, fromHex
    "6896BD60EEAE296DB48A229FF71DFE071BDE413E6D43F917DC8DCF8C78DE33418906D11AC976ABCCB20B091292BFF4EA897EFCB639EA871CFA95F6DE339E4B0A", fromHex
    "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659", fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89"⟩,
    -- vector 2: (canonical accept case)
    ⟨"b340-02", true, fromHex
    "5831AAEED7B44BB74E5EAB94BA9D4294C49BCF2A60728D8B4C200F50DD313C1BAB745879A5AD954A72C45A91C3A51D3C7ADEA98D82F8481E0E1E03674A6F3FB7", fromHex
    "DD308AFEC5777E13121FA72B9CC1B7CC0139715309B086C960E18FD969774EB8", fromHex
    "7E2D58D8B3BCDF1ABADEC7829054F90DDA9805AAB56C77333024B9D0A508B75C"⟩,
    -- vector 3: test fails if msg is reduced modulo p or n
    ⟨"b340-03", true, fromHex
    "7EB0509757E246F19449885651611CB965ECC1A187DD51B64FDA1EDC9637D5EC97582B9CB13DB3933705B32BA982AF5AF25FD78881EBB32771FC5922EFC66EA3", fromHex
    "25D1DFF95105F5253C4022F628A996AD3A0D95FBF21D468A1B33F8C160D8F517", fromHex
    "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"⟩,
    -- vector 4: (canonical accept case)
    ⟨"b340-04", true, fromHex
    "00000000000000000000003B78CE563F89A0ED9414F5AA28AD0D96D6795F9C6376AFB1548AF603B3EB45C9F8207DEE1060CB71C04E80F593060B07D28308D7F4", fromHex
    "D69C3509BB99E412E68B0FE8544E72837DFA30746D8BE2AA65975F29D22DC7B9", fromHex
    "4DF3C3F68FCC83B27E9D42C90431A72499F17875C81A599B566C9889B9696703"⟩,
    -- vector 5: public key not on the curve
    ⟨"b340-05", false, fromHex
    "6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E17776969E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B", fromHex
    "EEFDEA4CDB677750A420FEE807EACF21EB9898AE79B9768766E4FAA04A2D4A34", fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89"⟩,
    -- vector 6: has_even_y(R) is false
    ⟨"b340-06", false, fromHex
    "FFF97BD5755EEEA420453A14355235D382F6472F8568A18B2F057A14602975563CC27944640AC607CD107AE10923D9EF7A73C643E166BE5EBEAFA34B1AC553E2", fromHex
    "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659", fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89"⟩,
    -- vector 7: negated message
    ⟨"b340-07", false, fromHex
    "1FA62E331EDBC21C394792D2AB1100A7B432B013DF3F6FF4F99FCB33E0E1515F28890B3EDB6E7189B630448B515CE4F8622A954CFE545735AAEA5134FCCDB2BD", fromHex
    "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659", fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89"⟩,
    -- vector 8: negated s value
    ⟨"b340-08", false, fromHex
    "6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E177769961764B3AA9B2FFCB6EF947B6887A226E8D7C93E00C5ED0C1834FF0D0C2E6DA6", fromHex
    "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659", fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89"⟩,
    -- vector 9: sG - eP is infinite. Test fails in single verification if has_even_y(inf) is defined as true and x(inf) as 0
    ⟨"b340-09", false, fromHex
    "0000000000000000000000000000000000000000000000000000000000000000123DDA8328AF9C23A94C1FEECFD123BA4FB73476F0D594DCB65C6425BD186051", fromHex
    "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659", fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89"⟩,
    -- vector 10: sG - eP is infinite. Test fails in single verification if has_even_y(inf) is defined as true and x(inf) as 1
    ⟨"b340-10", false, fromHex
    "00000000000000000000000000000000000000000000000000000000000000017615FBAF5AE28864013C099742DEADB4DBA87F11AC6754F93780D5A1837CF197", fromHex
    "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659", fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89"⟩,
    -- vector 11: sig[0:32] is not an X coordinate on the curve
    ⟨"b340-11", false, fromHex
    "4A298DACAE57395A15D0795DDBFD1DCB564DA82B0F269BC70A74F8220429BA1D69E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B", fromHex
    "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659", fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89"⟩,
    -- vector 12: sig[0:32] is equal to field size
    ⟨"b340-12", false, fromHex
    "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F69E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B", fromHex
    "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659", fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89"⟩,
    -- vector 13: sig[32:64] is equal to curve order
    ⟨"b340-13", false, fromHex
    "6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E177769FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141", fromHex
    "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659", fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89"⟩,
    -- vector 14: public key is not a valid X coordinate because it exceeds the field size
    ⟨"b340-14", false, fromHex
    "6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E17776969E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B", fromHex
    "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC30", fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89"⟩,
    -- vector 15: message of size 0 (added 2022-12)
    ⟨"b340-15", true, fromHex
    "71535DB165ECD9FBBC046E5FFAEA61186BB6AD436732FCCC25291A55895464CF6069CE26BF03466228F19A3A62DB8A649F2D560FAC652827D1AF0574E427AB63", fromHex
    "778CAA53B4393AC467774D09497A87224BF9FAB6F6E68B23086497324D6FD117", fromHex
    ""⟩,
    -- vector 16: message of size 1 (added 2022-12)
    ⟨"b340-16", true, fromHex
    "08A20A0AFEF64124649232E0693C583AB1B9934AE63B4C3511F3AE1134C6A303EA3173BFEA6683BD101FA5AA5DBC1996FE7CACFC5A577D33EC14564CEC2BACBF", fromHex
    "778CAA53B4393AC467774D09497A87224BF9FAB6F6E68B23086497324D6FD117", fromHex
    "11"⟩,
    -- vector 17: message of size 17 (added 2022-12)
    ⟨"b340-17", true, fromHex
    "5130F39A4059B43BC7CAC09A19ECE52B5D8699D1A71E3C52DA9AFDB6B50AC370C4A482B77BF960F8681540E25B6771ECE1E5A37FD80E5A51897C5566A97EA5A5", fromHex
    "778CAA53B4393AC467774D09497A87224BF9FAB6F6E68B23086497324D6FD117", fromHex
    "0102030405060708090A0B0C0D0E0F1011"⟩,
    -- vector 18: message of size 100 (added 2022-12)
    ⟨"b340-18", true, fromHex
    "403B12B0D8555A344175EA7EC746566303321E5DBFA8BE6F091635163ECA79A8585ED3E3170807E7C03B720FC54C7B23897FCBA0E9D0B4A06894CFD249F22367", fromHex
    "778CAA53B4393AC467774D09497A87224BF9FAB6F6E68B23086497324D6FD117", fromHex
    "99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999"⟩,
]

/-- Own accept/reject count over the literal (the v4.35.0
List.count elaboration-avoidance, CrownBattery.lean:953 pattern). -/
def crownSCount (b : Bool) : List CrownSRow → Nat
  | [] => 0
  | ⟨_, e, _, _, _⟩ :: t => (if e == b then 1 else 0) + crownSCount b t

/-- The corpus has exactly the official battery's 19 rows. -/
theorem crownSchnorr_length : crownSchnorr.length = 19 := by decide

/-- The corpus's accept/reject split = the official 9/10 split
(`crownSCount` over the 19-literal = a kernel decide). -/
theorem crownSchnorr_stats :
    crownSCount true crownSchnorr = 9 ∧
    crownSCount false crownSchnorr = 10 := by decide

/-! ## The sample-consistency bridge (Prop layer, the CrownLink twin) -/

/-- **THE CROWNSCHNORR BRIDGE THEOREM** (per-row, equation side): for
a battery row `r` whose `verifyImpl` verdict equals the battery's
expected value (`hv : verifyImpl r.sig r.pk r.msg = r.expected`),
the expected verdict and the E08 crown's equation side
`satisfiesEquation r.sig r.pk r.msg` are equivalent. For an
expected-accept row (`r.expected = true`) this is E08's soundness
direction (acceptance ⇒ the verification equation); for an
expected-reject row (`r.expected = false`) it says the equation side
is DEAD for that row (the crown's completeness-on-the-equation
direction: the equation would have forced acceptance). Proof:
`rw [← verifyImpl_iff]` moves the crown into the goal, then `hv`
alone kills both directions. -/
theorem crownSchnorrLink (r : CrownSRow)
    (hv : verifyImpl r.sig r.pk r.msg = r.expected) :
    (r.expected = true ↔ satisfiesEquation r.sig r.pk r.msg) := by
  rw [← verifyImpl_iff]
  constructor
  · intro he
    rw [he] at hv
    exact hv
  · intro he
    rw [he] at hv
    exact hv.symm

/-- **Bridge, reject direction**: a battery row with the verdict
`verifyImpl = false` pinned (`r.expected = false` + `hv`) is dead on
the crown's equation side - `¬ satisfiesEquation`. (The 10
expected rejects, conditional on their runtime/kernel-pinned
verdicts.) -/
theorem crownSchnorrLink_rej (r : CrownSRow)
    (hv : verifyImpl r.sig r.pk r.msg = r.expected)
    (hr : r.expected = false) :
    ¬ satisfiesEquation r.sig r.pk r.msg := by
  have hc := crownSchnorrLink r hv
  rw [hr] at hc
  exact fun heq => Bool.noConfusion (hc.mpr heq)

/-- **Bridge, accept direction**: a battery row with the verdict
`verifyImpl = true` pinned (`r.expected = true` + `hv`) satisfies
the crown's equation - E08's soundness `verifyImpl_true_satisfies`
on the corpus rows. (The 9 expected accepts, conditional on their
runtime-pinned verdicts.) -/
theorem crownSchnorrLink_acc (r : CrownSRow)
    (hv : verifyImpl r.sig r.pk r.msg = r.expected)
    (hr : r.expected = true) :
    satisfiesEquation r.sig r.pk r.msg :=
  verifyImpl_true_satisfies r.sig r.pk r.msg (by rw [hv]; exact hr)

/-- **The corpus-level statement**: the sample-consistency bridge
holds on EVERY row of the 19-vector battery, under the per-row
verdict pinning `hvs` (the kernel layer supplies 1 of the 19 `hv`s
unconditionally; the runtime layer all 19). -/
theorem crownSchnorr_corpus
    (hvs : ∀ r ∈ crownSchnorr, verifyImpl r.sig r.pk r.msg = r.expected) :
    ∀ r ∈ crownSchnorr,
      (r.expected = true ↔ satisfiesEquation r.sig r.pk r.msg) :=
  fun r hr => crownSchnorrLink r (hvs r hr)

/-- **Corpus split form**: under the full verdict pinning `hvs`,
every expected-REJECT row of the battery is dead on the equation
side (the 10), and every expected-ACCEPT row satisfies it (the 9) -
the CROWNSCHNORR reading of `crownSchnorr_stats`. -/
theorem crownSchnorr_corpus_split
    (hvs : ∀ r ∈ crownSchnorr, verifyImpl r.sig r.pk r.msg = r.expected) :
    (∀ r ∈ crownSchnorr, r.expected = false →
      ¬ satisfiesEquation r.sig r.pk r.msg) ∧
    (∀ r ∈ crownSchnorr, r.expected = true →
      satisfiesEquation r.sig r.pk r.msg) :=
  ⟨fun r hr hrj => crownSchnorrLink_rej r (hvs r hr) hrj,
   fun r hr hra => crownSchnorrLink_acc r (hvs r hr) hra⟩

/-! ## Axiom pins (L3 discipline: `#guard_msgs in #print axioms`;
drift on any of these fails the build) -/

/-- info: 'BitcoinProofs.EcdsaDeep.CrownSchnorr.crownSchnorrLink' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms crownSchnorrLink

/-- info: 'BitcoinProofs.EcdsaDeep.CrownSchnorr.crownSchnorrLink_rej' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms crownSchnorrLink_rej

/-- info: 'BitcoinProofs.EcdsaDeep.CrownSchnorr.crownSchnorrLink_acc' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms crownSchnorrLink_acc

/-- info: 'BitcoinProofs.EcdsaDeep.CrownSchnorr.crownSchnorr_corpus' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms crownSchnorr_corpus

/-- info: 'BitcoinProofs.EcdsaDeep.CrownSchnorr.crownSchnorr_corpus_split' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms crownSchnorr_corpus_split


/-! ## The kernel layer (F-CK-003): 1/19 rows pinned hypothesis-free -/

-- b340-14 [pk-x-ge-p: pk = p+1, liftX's `P ≤ x` gate fires before
-- sqrtP/expM] (1) the VERDICT
example : verifyImpl (fromHex
    "6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E17776969E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B") (fromHex
    "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC30") (fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89") = false := by decide
-- b340-14 (2) THE CROWN-KILL (the money pin): dead on the E08
-- crown's equation side, unconditionally (no hypothesis, no runtime)
example : ¬ satisfiesEquation (fromHex
    "6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E17776969E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B") (fromHex
    "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC30") (fromHex
    "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89") := by
  rw [← verifyImpl_iff]
  decide

/-! ## The runtime layer: ALL 19 verdicts through `verifyImpl` (the
SchnorrTest.lean:122-131 / CrownLinkRun.lean:44-59 main shape; the
18 WF-wall rows + the 1 kernel row uniformly). Verdicts forced in
the `!=`-discriminant (the lazy-eval trap, CROWNLINK probe2). -/

def runVectors : IO Unit := do
  let mut fails := 0
  let mut accs := 0
  let mut rejs := 0
  for r in crownSchnorr do
    let got := verifyImpl r.sig r.pk r.msg
    if got != r.expected then
      fails := fails + 1
      IO.println s!"FAIL {r.name}: expected {r.expected}, got {got}"
    else if got then
      accs := accs + 1
    else
      rejs := rejs + 1
  IO.println s!"CROWNSCHNORR-RUN total {crownSchnorr.length} accepts {accs} rejects {rejs}"
  IO.println s!"TOTAL {crownSchnorr.length} FAILURES {fails}"
  if fails > 0 then throw (IO.userError "CROWNSCHNORR conformance failures")

end BitcoinProofs.EcdsaDeep.CrownSchnorr

/-- Runner entry (root `main` for `lake env lean --run`). -/
def main : IO Unit := BitcoinProofs.EcdsaDeep.CrownSchnorr.runVectors
