import BitcoinProofs.EcdsaDeep.CrownBattery
import BitcoinProofs.EcdsaDeep.VerifyEquation

/-!
# [CROWNLINK] CrownLink — the E05-battery × E06-crown bridge
# (sample consistency over the 215-vector corpus)

Contributor CROWNLINK (recovery review 5), 2026-10-17. See the data layer
`CrownBattery.lean` (the corpus) and `db/findings-dl/CROWNLINK.md`.

**The bridge.** E06's verify-equation IFF crown
(`VerifyEquation.verifyImpl_iff` : `verifyImpl sig pk msg = true ↔
VerifyEqRaw sig pk msg`, sorry-free) and E05's 215-vector battery
(`DerBatteryCor`, the kernel-pinned lax-DER corpus + this very
corpus, `crownBattery`, the W14b vectors verbatim) are here COMPOSED:
`crownLink` says that for every battery row whose `verifyImpl`
verdict is pinned to the battery's expected value (`hv`), the
expected verdict and the crown's equation side `VerifyEqRaw` are
EQUIVALENT — i.e. **the battery verdicts all pass through the
crown's characterization**: an expected-accept row satisfies the
verify equation (E06 soundness direction), and an expected-reject
row fails it (the equation side is dead), all through the single
`verifyImpl_iff` of the crown. The verdicts themselves are pinned
in three complementary layers (honest division of labour):

* **kernel layer** (`CrownLinkKernel.lean`, 17/215 rows = 8
  parse-rejects + 9 pk-structural-rejects): `hv`-FREE — `decide`
  kills `verifyImpl ... = false` in the kernel (no WF-recursive
  def is reached: `parseDerLax = none`, or `parsePubKey = none` via
  the tag/length/range/hybrid-parity/`onCurveN` paths), and
  `rw [← verifyImpl_iff]; decide` then kills the EQUATION side
  `¬ VerifyEqRaw ...` unconditionally (through the crown).
* **runtime layer** (`CrownLinkRun.lean`, 198/215 rows = 139
  accept + 59 reject): compiled-interpreter evaluation of
  `verifyImpl` over the corpus (the W14b `EcdsaTest` conformance
  re-run on this corpus) — the R6 wall (WF-recursive
  `mulP`/`expM`/`egcd` cannot be kernel-reduced) is exactly the
  17/198 boundary.
* **Prop layer** (this file): `crownLink`/`crownLink_rej`/
  `crownLink_acc`/`crownLink_corpus` — the sample-consistency
  statement over the whole corpus, conditional on the
  (kernel+runtime-pinned) verdicts `hv`.

**Honesty note.** `crownLink` is a *conditional* per-row theorem:
its logical content is E06's `verifyImpl_iff` (the crown — the
proof only routes `hv` through it); its *sample* content is the
corpus (the 215 rows) + the three verdict-pinning layers. The
equation side is NOT re-evaluated per row at the Prop level (it
cannot be — `VerifyEqRaw` is `Classical`); what is checked per row
is `verifyImpl` (kernel where possible, runtime elsewhere), and
the crown is what makes that check a check of the EQUATION. No
`sorry`, no `native_decide`, no new axioms (footprints pinned
below).
-/

namespace BitcoinProofs.EcdsaDeep.CrownLink

open Bitcoin.Crypto.Ecdsa.Der Bitcoin.Crypto.Ecdsa.Verify
open BitcoinProofs.EcdsaDeep.CrownBattery
open BitcoinProofs.EcdsaDeep.VerifyEquation

/-! ## The sample-consistency bridge (Prop layer) -/

/-- **THE CROWNLINK BRIDGE THEOREM** (per-row, equation side): for a
battery row `r` whose `verifyImpl` verdict equals the battery's
expected value (`hv : verifyImpl r.sig r.pk r.msg = r.expected`),
the expected verdict and the E06 crown's equation side
`VerifyEqRaw r.sig r.pk r.msg` are equivalent. For an
expected-accept row (`r.expected = true`) this is E06's soundness
direction (acceptance ⇒ the verify equation); for an expected-reject
row (`r.expected = false`) it says the equation side is DEAD for
that row (the crown's exactness direction: the equation would have
forced acceptance). Proof: `rw [← verifyImpl_iff]` moves the crown
into the goal, then `hv` alone kills both directions. -/
theorem crownLink (r : CrownRow)
    (hv : verifyImpl r.sig r.pk r.msg = r.expected) :
    (r.expected = true ↔ VerifyEqRaw r.sig r.pk r.msg) := by
  rw [← verifyImpl_iff]
  constructor
  · intro he
    rw [he] at hv
    exact hv
  · intro he
    rw [he] at hv
    exact hv.symm

/-- **Bridge, reject direction**: a battery row with the verdict
`verifyImpl = false` pinned (`r.expected = false` + `hv`) is dead
on the crown's equation side — `¬ VerifyEqRaw`. (The 76 expected
rejects, conditional on their runtime/kernel-pinned verdicts.) -/
theorem crownLink_rej (r : CrownRow)
    (hv : verifyImpl r.sig r.pk r.msg = r.expected)
    (hr : r.expected = false) : ¬ VerifyEqRaw r.sig r.pk r.msg := by
  have hc := crownLink r hv
  rw [hr] at hc
  exact fun heq => Bool.noConfusion (hc.mpr heq)

/-- **Bridge, accept direction**: a battery row with the verdict
`verifyImpl = true` pinned (`r.expected = true` + `hv`) satisfies
the crown's equation — E06's soundness `verifyImpl_sound` on the
corpus rows. (The 139 expected accepts, conditional on their
runtime-pinned verdicts.) -/
theorem crownLink_acc (r : CrownRow)
    (hv : verifyImpl r.sig r.pk r.msg = r.expected)
    (hr : r.expected = true) : VerifyEqRaw r.sig r.pk r.msg :=
  verifyImpl_sound r.sig r.pk r.msg (by rw [hv]; exact hr)

/-- **The corpus-level statement**: the sample-consistency bridge
holds on EVERY row of the 215-vector battery, under the per-row
verdict pinning `hvs` (the kernel layer supplies 17 of the 215
`hv`s unconditionally; the runtime layer the remaining 198). -/
theorem crownLink_corpus
    (hvs : ∀ r ∈ crownBattery, verifyImpl r.sig r.pk r.msg = r.expected) :
    ∀ r ∈ crownBattery, (r.expected = true ↔ VerifyEqRaw r.sig r.pk r.msg) :=
  fun r hr => crownLink r (hvs r hr)

/-- **Corpus split form**: under the full verdict pinning `hvs`,
every expected-REJECT row of the battery is dead on the equation
side (the 76), and every expected-ACCEPT row satisfies it (the
139) — the CROWNLINK reading of `crownBattery_stats`. -/
theorem crownLink_corpus_split
    (hvs : ∀ r ∈ crownBattery, verifyImpl r.sig r.pk r.msg = r.expected) :
    (∀ r ∈ crownBattery, r.expected = false → ¬ VerifyEqRaw r.sig r.pk r.msg) ∧
    (∀ r ∈ crownBattery, r.expected = true → VerifyEqRaw r.sig r.pk r.msg) :=
  ⟨fun r hr hrj => crownLink_rej r (hvs r hr) hrj,
   fun r hr hra => crownLink_acc r (hvs r hr) hra⟩

/-! ## Axiom pins (L3 discipline: `#guard_msgs in #print axioms`;
drift on any of these fails the build) -/

/-- info: 'BitcoinProofs.EcdsaDeep.CrownLink.crownLink' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms crownLink

/-- info: 'BitcoinProofs.EcdsaDeep.CrownLink.crownLink_rej' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms crownLink_rej

/-- info: 'BitcoinProofs.EcdsaDeep.CrownLink.crownLink_acc' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms crownLink_acc

/-- info: 'BitcoinProofs.EcdsaDeep.CrownLink.crownLink_corpus' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms crownLink_corpus

/-- info: 'BitcoinProofs.EcdsaDeep.CrownLink.crownLink_corpus_split' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms crownLink_corpus_split

end BitcoinProofs.EcdsaDeep.CrownLink
