# Theorem portfolio

Research note, 2026-10-16.
Status: survey and design.

---

## Executive summary

- **The portfolio is a 5-tier pyramid, not a flat list**: T1 per-rule sanity (~20 thms, no crypto, `omega`/`decide`), T2 interpreter invariants (~14, no crypto *modulo a signature oracle*), T3 ledger invariants (~13 — the headline results: value conservation, 21M cap, no double-spend, UTXO-update correctness), T4 spec↔Core conformance (harness-level, not kernel-level), T5 protocol-level (deferred).
- **~55% of the theorem table (T1 + much of T3) is provable with ZERO crypto tower.** Value conservation is provable *modulo a one-line abstraction* ("every script that must authorize an input does" — a hypothesis, not an axiom about secp256k1). This is the single most important design decision: it decouples the money proofs from the crypto layer.
- Survey confirms the gap: IsabeLLM proves *protocol-level* PoW safety (common-prefix ⇒ `take k p = take k p'`) but nothing about validation rules; the Lean-4 AMM paper (arXiv:2402.06064) is the closest "money conservation in Lean 4" precedent — its technique (validity baked into dependent transaction types; invariants by induction over transaction traces) should be imported directly.
- Agda-Script proves weakest-precondition correctness of exactly two scripts (P2PKH, P2MS). Our T2 generalizes: totality/determinism of the *whole* interpreter, plus WP-style lemmas for the standard templates.
- **No prior work formalizes C++ semantics in Lean.** (Norrish's C++ semantics is HOL/Isabelle-era; Verifiable C is Coq/VST; CompCert C semantics is Coq; CSLib 2026 only *plans* real-language semantics.) ⇒ T4 must be **conformance-by-testing**, not a proved compiler-style equivalence; a deep embedding of Core's C++ is explicitly future work.
- Probe result (Lean 4.34.1, **zero deps**): weight additivity, MoneyRange decidability, subsidy saturation and per-epoch emission bound all close with `omega`/`decide`/core lemmas. The friction points are `Nat` div/pow API ergonomics — mathlib removes them, which strengthens model architecture's case for a mathlib dependency (or a thin `Nat`-div/pow shim).
- Probe caught a genuine spec subtlety: `subsidy 33 = 0` (1 satoshi at halving 32, **zero** from halving 33) — exactly the kind of "geometric bookkeeping" error the 21M-cap theorem exists to prevent, caught in 20 minutes.
- Sorry-budget doctrine: every theorem carries a `#print axioms` footprint; `sorry`-carrying statements live in a `Thm.Pending` namespace with tracked issue IDs; per-milestone budget from trust accounting's ladder.
- Recommended M0→M6 order: T1 first (M0–M1, confidence-building), T2 totality/determinism at M2 (when the interpreter lands), T3 conservation at M3–M4, 21M cap exact-sum at M4, conformance T4 continuous from M1 (harness), T5 never (documented deferral).

---

## Key findings (with citations)

**F1 — IsabeLLM proves the wrong layer for us, but validates our tooling bet.**
arXiv:2601.07654 (Jones & Knottenbelt, Jan 2026) mechanizes Bitcoin's PoW *protocol* in Isabelle as an n-ary block tree and proves the **common-prefix property** (`theorem consensus: p, p' ∈ longest(State(hd t)) → take k p = take k p'`) under majority-honesty + synchrony, following the Bitcoin Backbone (Garay–Kiayias–Leonardos 2015). 16 lemmas, 175+193 LoP (binary) / 395 LoP (n-ary). It says nothing about validation rules, Script, or the ledger. The follow-up (arXiv:2606.18098, Jun 2026) adds RAG/error-tracing to IsabeLLM — evidence that LLM-assisted proving of consensus-level lemmas is now *routine*, directly relevant to proof-engineering practice.

**F2 — The Lean-4 AMM paper is the closest methodological precedent ("money in Lean 4").**
arXiv:2402.06064 (Pusceddu & Bartoletti, 2024; code: github.com/danielepusceddu/lean4-amm) formalizes Uniswap-v2-style AMMs in Lean 4 + mathlib and proves: existence-of-AMM ⟺ positive minted-supply in any *reachable* state (Prop 3.1, by induction on the transaction trace); an explicit gain formula (Lemma 3.5); swap-rate-vs-exchange-rate trichotomy (Lemma 3.7); optimal-swap condition (Thm 3.12). Two patterns to copy: **(i)** transactions are *dependent types with validity proofs as fields* (`structure Swap where enough: x ≤ wallet; exi: pair exists; nodrain: …`) so invalid transactions are uninhabitable — this is our `ValidTx`-as-subtype design; **(ii)** all conservation-style results go by **induction on `Tx` traces** from a `validInit` state — the exact shape of our "value conservation across any reachable chain state".

**F3 — Agda-Script sets the Script-proof bar; it's low and narrow.**
arXiv:2203.03054 (Alhabardi, Beckmann, Lazar, Setzer; TYPES'21) formalizes operational semantics of the Script fragment for P2PKH and P2MS in Agda, reasons with **Hoare triples / weakest preconditions** (two derivation styles: backward step-by-step, and symbolic execution → nested case distinction), and proves access-control correctness of those two templates. No limits, no flags, no SegWit/Taproot, no totality meta-theorems. Our T2 (interpreter totality, determinism, stack bounds, fuel monotonicity) has no precedent in the Bitcoin literature at all.

**F4 — Verified-compiler line: the spec↔code theorem shape exists, but not for C++-in-Lean.**
- CompCert (Leroy et al., Coq): *semantics preservation* — a compiler verified against a formal C semantics (`Clight` → Asm); the theorem shape is `∀ p, semantic-equiv (compile p) p`.
- Verifiable C / VST (Appel et al., Coq): a *program logic* (separation logic) on top of a deep C semantics; per-program functional-correctness specs.
- Norrish, "A Formal Semantics for C++" (NICTA, 2002): HOL, dynamic semantics, pre-Lean era; never ported.
- CSLib (arXiv:2602.04846, 2026): a new "Lean Computer Science Library" that *plans* to formalize real-language semantics in Lean — as of writing, aspiration, not result.
⇒ **Nothing proves Bitcoin Core's C++ correct, and nothing could be reused to.** T4 therefore = *equivalence-by-conformance*: a decidable, machine-checked conformance relation over Core's finite test-vector corpus, plus a documented "deep-embedding of Core's C++" assessment as XL/future.

**F5 — KEVM/Isabelle-EVM conformance template.**
KEVM (Hildenbrandt et al., CSF 2018) is a *complete executable* EVM semantics validated against the official test suite; Amani et al. (CPP 2018) verify EVM bytecode *programs* in Isabelle via a program logic. The template we import: **executable spec first, pass the official vectors second, prove program-logic-style invariants third** — exactly the T2/T4 split. This is the project's "KEVM / Isabelle-EVM / Hornet standard" made concrete as a proof-obligation ordering.

**F6 — seL4's refinement ladder is the honest model for "spec vs code" claims.**
seL4 (Klein et al.) proves abstract-spec ⇢ refined-spec ⇢ C-implementation refinement. btc-lean can only deliver the *abstract-spec* level, plus conformance evidence at the C++ level. The report's T4 statement wording ("this Lean function is what Core computes *on all tested inputs*, and every Lean def traces to a Core function") must never overclaim refinement.

Compiles clean under Lean 4.34.1, **no mathlib**: MoneyRange decidability; `weight b t = 3*b + t` nonneg + `weight ≥ base` + additivity across transactions (`weight b1 t1 + weight b2 t2 = weight (b1+b2) (t1+t2)`, pure `omega`); `subsidy h = 5000000000 / 2^min h 64` bounded by 5e9; `subsidy 33 = 0` by `decide`; `subsidy h ≥ 1` for `h ≤ 32`; per-epoch emission `210000 * subsidy h ≤ 1.05e15`. Friction: core `Nat.pow_le_pow_right`/`Nat.div_pos` signature archaeology (4 iterations) — mathlib or a 30-line shim kills this class of annoyance. `omega` does NOT close division/pow facts (`5000000000 / 2^min h 64` is nonlinear to it) — division lemmas must be established once, as helper infrastructure.

---

## Detailed analysis

### (a) Survey — what comparable projects prove

| Project | Theorem shape | Granularity | Lesson for btc-lean |
|---|---|---|---|
| **IsabeLLM** (2601.07654 / 2606.18098) | Safety of the *abstract protocol*: common-prefix (`take k p = take k p'`), checked by bounded-lookahead lemmas (`bounded_check`, `check_add`), over n-ary chain trees, majority-honest assumption | ~16 lemmas, one protocol property | Prove *one flagship safety theorem* per layer rather than many shallow ones; their per-lemma LoP table is a good effort calibration (5–158 LoP per lemma in Isar) |
| **KEVM / EVM-in-Isabelle (Amani et al. CPP'18)** | Executable semantics + conformance to test vectors; program logic for bytecode safety | Whole VM | T2 = our "program logic layer"; conformance is a *separate* deliverable from proof |
| **Agda-Script (2203.03054)** | Hoare triples / WPs for P2PKH & P2MS; human-readable WPs | 2 templates | WP style is right for Script soundness; our T2-THM soundness rows mirror their `wp` predicates. Their "no false negatives" shape = completeness direction |
| **Lean-4 AMM (2402.06064)** | Reachable-state invariants by trace induction; validity-in-the-type; conservation-style equalities | 1 model, ~10 results | **Import**: dependent-type validity + trace induction + "split supply definitions to help `simp`" (their Table-2 note) |
| **BitML / formal-bitml (Agda)** | Contract calculus with a semantics-preserving *compilation* into Bitcoin txs | Above consensus | Out of scope, but their `SpendFromUTXO`-style well-foundedness (admissible-honesty histories) is a precedent for our THM on spending termination |
| **CompCert / VST / seL4** | Refinement / semantics-preservation / program logic on deep C semantics | Whole compiler/kernel | Defines the T4 ceiling: full C++-semantics-in-Lean is a CompCert-sized project. We do conformance, not refinement |
| **StarkWare Lean-3 secp256k1, sha2-fv (Aeneas→Lean), SHA-3 in Lean (eprint 2024/1880), safegcd/VST secp256k1** | Crypto primitives verified in isolation | Tower elements | Confirms crypto tower's tower is buildable; our theorems should *abstract* it so tower upgrades don't ripple (see (d)) |

**IsabeLLM's PoW specifics (for T5 deferral):** they verify safety of longest-chain-under-majority-honesty as a *chain-structure* property; the difficulty retarget function, the 2016-block window, and timewarp-style attacks are **not** modeled. Our T5 deferral is therefore consistent with the state of the art — nobody has mechanized Bitcoin's *actual* retarget function's safety properties.

### (b) The portfolio, tier by tier

**T1 — Per-rule sanity (M0–M1).** Every consensus rule from upstream-track's rule-ID database becomes a decidable predicate; each gets ≥1 small lemma. Purpose: (1) exercise every definition the moment it exists; (2) build the sorry-free culture on easy ground; (3) machine-auditable rule coverage. Examples: MoneyRange bounds (THM-001, probe-verified), weight algebra (THM-002/003/004, probe-verified), varint injectivity, nBits compact-target round-trip, coinbase shape, scriptNum canonicalization. Nearly all `decide`/`omega`/`simp`.

**T2 — Interpreter invariants (M2, tracks the interpreter and architecture's interpreter).** Four families:
1. **Totality**: `Eval` is a total function (fuel-indexed recursion ⇒ definitionally total; theorem: fuel always sufficient, i.e. `∃ fuel, terminates` and `steps ≤ f(script, stack)` — THM-021/023). Bitcoin's Script *is* designed to terminate; making that a theorem (bounded by opcount + script-size + stack rules) is a real result nobody has mechanized.
2. **Determinism**: same inputs ⇒ same result, no environment dependence (THM-022/031).
3. **Resource invariants preserved**: stack ≤ 1000, element ≤ 520, opcount ≤ 201, script-size monotone (THM-024–026).
4. **Soundness/completeness of access control** (Agda-style, generalized): WP for P2PKH/P2MS/CSV/CLTV templates (THM-028/029), and the completeness direction "no false negatives for valid scripts" (THM-030) — stated modulo the signature oracle.

**T3 — Ledger invariants (M3–M4). The flagship tier.** Abstraction doctrine: define `InputAuth : TxIn → Prop` ("this input is authorized") as an *opaque interface*; the crypto tower instantiates it later. Then:
- **Value conservation per tx** (THM-035): `Σ outputs = Σ inputs − fee` given each input's `MoneyRange` value — pure arithmetic, no crypto.
- **Value conservation per block** (THM-036): by induction over txs in block order (needs THM-047 ordering), coinbase capped (THM-037).
- **21M cap** (THM-038/039): total issuance `Σ_{k<∞} 210000 · (5e9 >> min k 64) = 2_099_999_997_690_000 sats < MAX_MONEY`. Exact value via `decide`-style computation + a geometric-sum lemma; the inequality is the theorem, the exact sum the spectacular corollary. (Probe already bounds per-epoch emission.)
- **No double-spend survives validation** (THM-040): connect processes txs sequentially against a functional UTXO map; second spend of an outpoint fails lookup. Needs only finite-map semantics.
- **UTXO update = set update** (THM-041): `ApplyBlock` commutes with the spec-level `utxo Δ` operator — the seL4-flavored "spec-level statement" of T3.
- **SpendFromUTXO well-foundedness** (THM-042): spending relation decreases (block height, then tx index) lexicographic measure ⇒ chains of spends are well-founded ⇒ no transactional cycles (a tx cannot spend its own output at validation time).
- **Supply monotonicity** (THM-043) and fee non-negativity (THM-044).

**T4 — Spec↔Core equivalence (M1+, continuous; never "proved" in the refinement sense).**
- **Conformance theorem** (THM-048): for the finite Core test-vector corpus (conformance's harness), `∀ v ∈ corpus, validate v = expected v` — decidable, machine-checked, re-runnable per commit. This is KEVM-style conformance, formalized as a Lean-level `decide`-able statement over an indexed vector type.
- **Traceability completeness** (THM-049, meta): every `ConsensusRule` predicate carries a proof-relevant `ruleId` mapping into the Core↔BIP↔CVE database (enforced by CI, roadmap's matrix, not a kernel theorem — document as such).
- **Explicitly NOT claimed**: refinement of Core's C++. Assessment (F4): no C++-in-Lean semantics exists (Norrish = HOL; VST = Coq; CompCert = Coq; CSLib = plans). A deep embedding of Core's `CheckTransaction`/`CheckBlock`/interpreter as a Lean EDSL with an (unproved) correspondence is **future work, XL**, worth a standalone report later.

**T5 — Protocol-level (deferred, documented).** Chain growth / common-prefix / chain quality for *actual* Bitcoin (with retarget function). IsabeLLM did the abstract-tree version (F1); the real retarget function's interaction with difficulty bounds is untouched anywhere. Defer to post-M6; the T3 difficulty lemmas (THM-016/018) are our toehold.

### (c) Prioritization

Value/effort scoring (H = headline, M = medium, L = plumbing), crypto-dependency, and milestone mapping are in Appendix B. Highlights:
- **Highest value/effort**: THM-035/036/040 (conservation + no-double-spend) — S/M effort, zero crypto, headline claims.
- **Highest effort**: THM-021 totality-with-bounds (L, needs careful fuel design), THM-038 exact 21M sum (M — the geometric sum needs one induction + `decide` on the closed form; the *hard* part is stating `Σ` over epochs without mathlib's `Finset.sum`… which argues for mathlib), THM-017 header PoW (only via crypto tower's SHA-256).
- **Crypto-tower map**: of 49 theorems, **31 need no crypto at all**; 6 need SHA-256(d) only (merkle/txid/wtxid/PoW/sighash-totality); 6 need sig verification only through the `InputAuth` oracle; 6 are meta/conformance.

### (d) Proof-infrastructure doctrine

- **`decide`/`omega`/`simp` will carry**: all of T1 arithmetic, weight algebra, varint, nBits decode totality for fixed-width cases, UTXO finite-map lemmas, per-tx conservation. They will NOT carry: anything with `Nat` division/`pow` under quantifiers (probe F7), geometric sums, any real finite-field math (only needed if we ever *prove* ECDSA-level facts — we don't, we abstract).
- **`abstract`/opaque interfaces** (the load-bearing decision): define `InputAuth`, `VerifySig`, `HashFunction` as structures/classes with *axiomatized or later-instantiated* properties (determinism, correctness of the sighash preimage relation). Theorem statements in T2/T3 reference only the interface ⇒ crypto tower can swap the crypto tower (axiomatized → verified → `native_decide`-conformed) without touching a single theorem statement. `#print axioms` stays honest because the interface properties are *named hypotheses in the theorem*, not axioms, wherever possible — prefer **section hypotheses** over `axiom`.
- **`sorry`-budget protocol** (aligned with the project scope and trust accounting): (1) every public theorem is listed in the theorem index with its `#print axioms` output checked in CI; (2) `sorry` allowed only in namespace `BtcLean.Pending.<Milestone>` and must reference an issue ID; (3) sorry-count per module is a dashboard metric (proof engineering); (4) a theorem is "DONE" only when sorry-free *and* axiom-footprint ⊆ declared budget (standard + `native_decide` if opted-in, per conformance).
- **Statement stability**: parameterize theorems over a `ConsensusEnv` structure (constants: MAX_MONEY, MAX_BLOCK_WEIGHT, subsidy schedule, …) so upstream-track's pinned-commit drift changes *instances*, not theorem statements.

---

## Implications for the project

1. **the model architecture must ship the interfaces** (`InputAuth`, `HashFunction`, `ConsensusEnv`) in M0 — the theorem portfolio's shape depends on them; retrofitting costs a rewrite of T3 statements.
2. **Order of work**: T1 lemmas can start *now* (probe shows zero-dep feasibility) — they are the ideal first-milestone filler and sorry-free-confidence builder while upstream-track pins Core.
3. **mathlib dependency**: T3's exact-sum theorem and T2's totality bounds get materially easier with `Finset.sum`/`Finset.prod` and mathlib's `Nat` API. Recommend mathlib as a dependency from M1 (trust accounting decision), with the zero-dep core-probe as fallback evidence.
4. **The abstraction doctrine changes what "needs crypto" means** for planning: crypto tower (crypto tower) is on the critical path only for THM-014/017/028–033; everything else proceeds in parallel.
5. **T4 wording discipline**: repo README/theorem list must say "conformance to Bitcoin Core's test vectors + traceability," never "verified equivalent to Bitcoin Core."

## Open questions & risks

- **R1 — Conservation statement precision.** "No creation except coinbase ≤ subsidy+fees" must be stated per *validation function*, not per math ideal: Core's `ConnectBlock` checks coinbase outputs ≤ subsidy + Σfees *with fee computed from the UTXO view*. Off-by-one/maturity subtleties (BIP34's height-in-coinbase, THM-020) need block validation's input before THM-036/037 statements are frozen.
- **R2 — Exact 21M sum**: 2,099,999,997,690,000 sats assumes subsidy=0 from halving 33 onward *and* that the last epoch is partial (height cap 0 at chain end is irrelevant to total issuance but is to the statement). Freeze statement against block validation's `GetBlockSubsidy` reading, not the wiki.
- **R3 — Totality theorem scope**: Script totality is easy with fuel; the interesting version (fuel bound *as a function of the consensus limits*, so `decide`-checkable per real script) needs the limit interactions (opcount vs script size vs stack) mapped by interpreter first.
- **R4 — `decide` blowup** on corpus-conformance (THM-048) if corpus is embedded as one giant theorem; mitigation: one theorem per vector + a `∀ i, …` wrapper over an `Array` indexed by `Fin n` (conformance's harness design).
- **O1** — Does any Lean work formalize CMMI-level C semantics since CSLib (Feb 2026)? Re-check before freezing the T4 future-work assessment.
- **O2** — Should P2MS soundness use the Agda paper's WP formulation directly (translating) or native Lean `Finset` multisig reasoning? Defer to M2 PoC.

## Recommendations

1. **Adopt the 5-tier portfolio + `InputAuth`/`HashFunction` abstraction interfaces as M0 deliverables** (goes into roadmap's roadmap and the model architecture contract).
2. **Freeze the top-10 "headline" theorems now** (marked ★ in Appendix B) and require each milestone to land at least one.
3. **Start T1 immediately**: port `probe.lean` into `BtcLean/Amounts.lean`, `BtcLean/Weight.lean`, `BtcLean/Subsidy.lean` skeletons.
4. **CI: `#print axioms` + sorry-count dashboard from day 1** (trust accounting/proof engineering), theorem table (Appendix B) as `THEOREMS.csv` with auto-generated coverage vs the rule-ID database.
5. **T4: write the conformance doctrine doc** (one page, with the F4/F6 caveats) before any external communication claims "verified Bitcoin".
6. **Defer T5 explicitly** with a one-paragraph rationale citing F1 (nobody has mechanized the real retarget function — it's a legit follow-on paper, not a v1 obligation).

---

## Appendix A — Sources

1. Jones & Knottenbelt, *Towards Automating Blockchain Consensus Verification with IsabeLLM*, arXiv:2601.07654 (Jan 2026) — model §4 (n-ary tree, common-prefix, consensus theorem `take k p = take k p'`), LoP tables; code: github.com/EllbellCode/IsabeLLM. *(full HTML read)*
2. Jones & Knottenbelt, *IsabeLLM: Automated Theorem Proving Applied to Formally Verifying Consensus*, arXiv:2606.18098 (Jun 2026) — abstract; RAG/error-tracing upgrade. *(abstract read)*
3. Pusceddu & Bartoletti, *Formalizing Automated Market Makers in the Lean 4 Theorem Prover*, arXiv:2402.06064 (2024) — dependent-type validity (`Swap.enough/exi/nodrain`), trace-induction invariants (Prop 3.1, Lemmas 3.3–3.9, Thm 3.12), `finsupp`-based state; code: github.com/danielepusceddu/lean4-amm. *(full HTML read)*
4. Alhabardi, Beckmann, Lazar, Setzer, *Verification of Bitcoin Script in Agda using Weakest Preconditions for Access Control*, arXiv:2203.03054 / TYPES'21 — WP/Hoare-triple methodology, P2PKH + P2MS only. *(abstract read)*
5. Hildenbrandt et al., *KEVM: A Complete Formal Semantics of the EVM*, CSF 2018 — conformance-to-test-suite template (cited via 2601.07654 §3).
6. Amani, Bégel, Bortin, Staples, *Towards Verifying Ethereum Smart Contract Bytecode in Isabelle/HOL*, CPP 2018 — program-logic layer (cited via 2601.07654).
7. Norrish, *A Formal Semantics for C++*, NICTA (2002), trustworthy.systems/publications/nicta_full_text/1203.pdf — HOL, pre-Lean; the only serious C++ formal semantics found.
8. Appel et al., *Verifiable C* (VST) — Coq separation-logic program logic over deep C semantics (background knowledge, flagged as such).
9. Leroy et al., *CompCert* — semantics-preservation theorem shape (background knowledge, flagged).
10. *CSLib: The Lean Computer Science Library*, arXiv:2602.04846 (2026) — plans real-language semantics in Lean; no C++ semantics yet. *(search snippet)*
11. Klein et al., seL4 refinement chain (abstract ⇢ C) — the refinement-ladder ceiling for T4 claims (cited via 2601.07654 §3).
12. Garay, Kiayias, Leonardos, *The Bitcoin Backbone Protocol*, EUROCRYPT 2015 — common-prefix/chain-quality definitions IsabeLLM mechanizes.

## Appendix B — THE THEOREM TABLE

Legend: ★ = headline theorem. `Needs-crypto`: **No** / **SHA** (hash only) / **Auth** (via `InputAuth` oracle only) / **Full**. Effort: S (<1 day) / M (days) / L (1–2 weeks) / XL (multi-week). VERIFIED = compiled in a standalone probe at the time of the survey; all others are PROPOSED (statement drafted, proof pending).

### Tier 1 — per-rule sanity (M0–M1)

| ID | Statement (informal but precise) | Tier | Needs-crypto? | Effort | Milestone | Status |
|---|---|---|---|---|---|---|
| THM-001 | `MoneyRange n ↔ -MAX_MONEY ≤ n ≤ MAX_MONEY` is decidable; the bound constant equals 21_000_000·10^8 | T1 | No | S | M0 | VERIFIED (probe: decidable instance) |
| THM-002 | `0 ≤ weight base total` and `base ≤ weight base total` where `weight b t = 3b + t` | T1 | No | S | M0 | VERIFIED (probe) |
| THM-003 | Weight is additive: `weight b₁ t₁ + weight b₂ t₂ = weight (b₁+b₂) (t₁+t₂)` (per-tx weight sums over a block's txs) | T1 | No | S | M0 | VERIFIED (probe) |
| THM-004 | If a block's total weight ≤ MAX_BLOCK_WEIGHT (4M) then its witless size ≤ 4M and each tx's base size ≤ 4M | T1 | No | S | M0 | PROPOSED |
| THM-005 | MAX_MONEY < Int64.max: no amount can overflow int64 (Core's `MAX_MONEY = 21e6·COIN` fits) | T1 | No | S | M0 | PROPOSED |
| THM-006 | `CTxOut::nValue` well-formedness: a tx output passes validation iff `MoneyRange value` and tx total ≤ MAX_MONEY (Core `CheckTransaction`) | T1 | No | S | M0 | PROPOSED |
| THM-007 | scriptNum decode is injective on canonical encodings; re-encoding a decoded value yields the minimal encoding | T1 | No | S | M1 | PROPOSED |
| THM-008 | scriptNum of any ≤4-byte operand fits in int64 without overflow (Core's CScriptNum 4-byte ctor) | T1 | No | S | M1 | PROPOSED |
| THM-009 | Varint decode is a bijection ℕ ↔ canonical encodings; non-canonical forms are detectable (Core reads varint with canonical flag) | T1 | No | S | M1 | PROPOSED |
| THM-010 | nLockTime decodes: `nLockTime < 500_000_000` ↔ block-height interpretation; `≥` ↔ time interpretation (BIP113 boundary constant) | T1 | No | S | M1 | PROPOSED |
| THM-011 | Sequence-based CSV decode: `nSequence` enables RBF/CSV bits per BIP68 — bit-15 mask semantics as a decidable lemma | T1 | No | S | M1 | PROPOSED |
| THM-012 | Coinbase shape: exactly 1 input with null prevout (`IsNull()`); all other txs have ≥1 non-null input and ≥1 output (Core `CheckTransaction`) | T1 | No | S | M0 | PROPOSED |
| THM-013 | nBits compact-target decode: `expand(nBits) = mantissa · 2^(8·(exponent−3))` for exponent ≤ 3 adjusted; decode is total and monotone in (exponent, mantissa) lexicographically | T1 | No | M | M1 | PROPOSED |
| THM-014 | Target bounds: `0 < expand(nBits) ≤ powLimit` for all consensus-valid nBits | T1 | SHA (only to state PoW check; bound itself is No) | S | M1 | PROPOSED |
| THM-015 | `subsidy h = 5000000000 >>> min h 64` satisfies `0 ≤ subsidy h ≤ 5·10^9` (BIP42 shift-saturation) | T1 | No | S | M0 | VERIFIED (probe: `subsidy_le_max`) |
| THM-016 | Subsidy schedule corner: `subsidy 32 = 1` sat and `subsidy 33 = 0` — the last nonzero and first zero epoch | T1 | No | S | M0 | VERIFIED (probe: `subsidy_zero_at_33`, 32 analogous) |
| THM-017 | Coinbase maturity: an output of the coinbase at height H is spendable from height H+100 (COINBASE_MATURITY); decidability of the check | T1 | No | S | M1 | PROPOSED |
| THM-018 | Per-tx sigop count ≤ bounds (MAX_OPS_PER_SCRIPT=201 legacy; BIP141 sigop accounting) — count function total and bounded by script size | T1 | No | M | M1 | PROPOSED |
| THM-019 | Block header field sanity: version is int32; timestamp, nBits, nonce range-checked (decidable predicates mirror Core's `CheckBlockHeader` shape checks) | T1 | No | S | M1 | PROPOSED |
| THM-020 | Merkle parse totality: merkle-root computation over a txid list is total and its shape (pairwise concat + SHA256d) matches Core's `ComputeMerkleRoot` recursion | T1 | SHA | S | M1 | PROPOSED |

### Tier 2 — interpreter invariants (M2–M3)

| ID | Statement | Tier | Needs-crypto? | Effort | Milestone | Status |
|---|---|---|---|---|---|---|
| THM-021 | **Totality**: the script interpreter is a total function — for every (script, stack, flags) there exists a fuel at which `Eval` returns a verdict; the interpreter "never panics" (no undefined cases) | T2 | No | L | M2 | PROPOSED ★ |
| THM-022 | **Determinism**: `Eval script stack flags = Eval script stack flags` trivially; the real content: result is independent of fuel when fuel ≥ fuelBound — `∀ f₁ f₂ ≥ bound, result f₁ = result f₂` | T2 | No | M | M2 | PROPOSED ★ |
| THM-023 | Fuel/step bound: execution steps ≤ `K · (opcount + Σ element sizes)`; a consensus-limit-fuel suffices (script-size/201-op/1000-stack limits imply termination) | T2 | No | L | M2–M3 | PROPOSED |
| THM-024 | Stack-size invariant: throughout execution, `|stack| ≤ 1000` (MAX_STACK_SIZE) is preserved by every non-`;` op, and every op's stack-pop precondition is checked (Core `popstack`) | T2 | No | M | M2 | PROPOSED |
| THM-025 | Element-size invariant: every pushed element ≤ 520 bytes (MAX_SCRIPT_ELEMENT_SIZE) unless pushed by an explicit exception op (OP_PUSHDATA4/sep-clone per Core) | T2 | No | M | M2 | PROPOSED |
| THM-026 | Op-count invariant: scripts without disabled ops execute ≤ 201 non-condition ops on the legacy path; conditionals don't count (`fExec` semantics of Core's switch) | T2 | No | M | M2–M3 | PROPOSED |
| THM-027 | Disabled-opcode soundness: a script containing a disabled opcode is rejected at parse/dispatch, never partially executed | T2 | No | S | M2 | PROPOSED |
| THM-028 | P2PKH soundness (WP/Hoare): weakest precondition of `scriptPubKey = DUP HASH160 <h> EQUALVERIFY CHECKSIG` w.r.t. stack-top truth = "witness stack contains (sig, pk) with `hash160 pk = h` and sig verifies"; mirrors Agda result (2203.03054) in Lean | T2 | Auth | M | M2–M3 | PROPOSED ★ |
| THM-029 | P2MS soundness: bare m-of-n CHECKMULTISIG accepts iff the (deduped) stack provides ≥ m valid sigs against ≥ m of the n keys in order; null-dummy (BIP147) flag handled | T2 | Auth | L | M3 | PROPOSED |
| THM-030 | **No-false-negatives** (completeness modulo oracle): if all input authorizations genuinely verify (under `InputAuth`), and the script is standard-template, the interpreter returns true — signature failures are the only false negatives, and they are excluded by hypothesis | T2 | Auth | M | M3 | PROPOSED ★ |
| THM-031 | Flag-determinism partition: for the consensus flag sets (legacy / SegWit v0 / Taproot), `VerifyScript` result is a function of (tx, idx, scriptPubKey, flags) only | T2 | No | M | M3 | PROPOSED |
| THM-032 | BIP143 sighash computation is total and deterministic (no exception path; midstate-free) | T2 | SHA | M | M3 | PROPOSED |
| THM-033 | BIP341 sighash computation is total and deterministic (tag-hash precomputable: `SHA256(SHA256(tag)‖SHA256(tag))` associativity lemma) | T2 | SHA | M | M3–M4 | PROPOSED |
| THM-034 | Clean-stack discipline: with CLEANSTACK, success implies final stack has exactly 1 element = true (bool-cast semantics of Core) | T2 | No | S | M3 | PROPOSED |
| THM-035 | Script-size monotonicity of fuel: for nested scriptExec (e.g., P2SH redeem), total fuel ≤ f(outer) + f(inner), no exponential blowup — the interpreter's recursion is bounded by script nesting | T2 | No | M | M3 | PROPOSED |

### Tier 3 — ledger invariants (M3–M4)

| ID | Statement | Tier | Needs-crypto? | Effort | Milestone | Status |
|---|---|---|---|---|---|---|
| THM-036 | **Per-tx value conservation**: for any tx passing `CheckTxInputs` against a UTXO view where all spent outputs are MoneyRange-valid: `Σ outputs ≤ Σ inputs` and `fee = Σ inputs − Σ outputs ≥ 0` | T3 | No | S–M | M3 | PROPOSED ★ |
| THM-037 | **Per-block value conservation**: for any block accepted by `ConnectBlock` (with `InputAuth` abstraction for sigs): `Σ all outputs = Σ all inputs − fees + coinbaseExtra`, equivalently **money created ≤ coinbase subsidy + fees** and exactly `Σ inputs(t) over txs − Σ outputs = fees claimable by coinbase` | T3 | Auth | M | M3–M4 | PROPOSED ★ |
| THM-038 | Coinbase cap: coinbase output total ≤ `GetBlockSubsidy(height) + Σ fees` (Core's `ConnectBlock` vouts check), given THM-015/016 subsidy | T3 | No | M | M3 | PROPOSED ★ |
| THM-039 | **Money-supply bound (21M cap)**: total issuance over any chain ≤ `Σ_{k≥0} 210000 · (5·10^9 >>> min k 64) = 2_099_999_997_690_000 < 21_000_000·10^8` (geometric series; needs Finset.sum + one induction) | T3 | No | M–L | M4 | PROPOSED ★ |
| THM-040 | Exact supply at height H: `supply H = Σ_{k < epochOf H} 210000·subsidy k + partial-epoch term`, computed exactly (decide on the closed form) | T3 | No | M | M4 | PROPOSED |
| THM-041 | **No double-spend survives validation**: if a block's tx list contains two txs spending the same outpoint, sequential `ConnectTx` fails at the second (functional UTXO map: lookup-after-delete) — no admissibility of duplicates, no BIP30-style exception in the modern rule set | T3 | No | M | M3 | PROPOSED ★ |
| THM-042 | **UTXO-update correctness**: `ApplyBlock utxo blk = (utxo ∖ spent blk) ∪ (outputs blk)` as set-level semantics (spent/outputs defined pointwise); equivalently ApplyBlock is a function of the *set* of (outpoint→coin) and commutes with disjoint union of independent tx sets | T3 | No | L | M4 | PROPOSED ★ |
| THM-043 | SpendFromUTXO well-foundedness: the "spends" relation on (height, txidx, vout) is strictly lexicographically decreasing along validation order ⇒ no tx consumes its own outputs, and chains of spends within a block are well-founded | T3 | No | M | M4 | PROPOSED ★ |
| THM-044 | Money-supply monotonicity: `supply(H+1) ≤ supply(H) + subsidy(H+1)`; equality iff coinbase claims exactly subsidy+fees and no output is dropped | T3 | Auth | S–M | M4 | PROPOSED |
| THM-045 | UTXO-set value consistency: `Σ value (utxoAfter blk) = Σ value (utxoBefore blk) − Σ fees + Σ coinbaseOutputs` (fees are *claimable*, not burned; unclaimed fees reduce coinbase, not supply) | T3 | Auth | M | M4 | PROPOSED |
| THM-046 | In-block dependency ordering: if tx j spends an output of tx i in the same block, then validation order places i < j (Core's `ConnectBlock` sequential application ⇒ a `LinearOrder` on the tx list induced by the spends relation) | T3 | No | M | M4 | PROPOSED |
| THM-047 | Duplicate-txid rule (BIP30 + CVE-2012-2459 / BIP98): the validator rejects a second tx with an already-existing txid unless at the two grandfathered mainnet heights (91_842, 91_880); lemma: merkle root of a txid list with one duplicated pair equals the deduped root — hence the explicit duplicate check is *necessary* | T3 | SHA | M–L | M4 | PROPOSED |
| THM-048 | Genesis/state bootstrapping: the genesis block's coinbase is unspendable (BIP34/BIP30 exception), and `supply(0) = 50 BTC` exactly | T3 | No | S | M3 | PROPOSED |

### Tier 4 — spec ↔ reference equivalence (M1+, continuous)

| ID | Statement | Tier | Needs-crypto? | Effort | Milestone | Status |
|---|---|---|---|---|---|---|
| THM-049 | **Conformance (harness)**: for the pinned Core test-vector corpus `V` (conformance's extraction), `∀ v ∈ V, ourValidate v = expected v`, machine-checked; stated as a `decide`-able ∀ over a finite indexed type | T4 | Full (via tower or conformed) | M (infra: L, conformance) | M1→ continuous | PROPOSED ★ |
| THM-050 | Traceability completeness (meta-theorem, CI-enforced): every `ConsensusRule` predicate in the Lean spec maps to a row (Core function@commit, BIP, CVE?) in the rule-ID database; the Lean-side proof is a decidable registry lookup | T4 | No | M | M1→ continuous | PROPOSED |
| THM-051 | Abstraction-instance consistency: the `InputAuth`/`HashFunction` interfaces are instantiated by the actual tower such that `VerifySig`-level determinism holds (interface lemmas, not crypto proofs) | T4 | Auth | S | M2 | PROPOSED |
| THM-052 | (Future-work assessment, not a theorem) Deep-embedding of Core's C++ semantics in Lean: verified-refinement style claim is **out of scope**; no prior C++-in-Lean semantics exists (Norrish=HOL, VST/CompCert=Coq, CSLib=planned) — document as XL follow-on | T4 | Full | XL | post-M6 | PROPOSED (deferred) |

### Tier 5 — protocol-level (documented deferral)

| ID | Statement | Tier | Needs-crypto? | Effort | Milestone | Status |
|---|---|---|---|---|---|---|
| THM-053 | Common-prefix property for longest-chain-under-majority-honesty, n-ary tree version: `p, p' ∈ longest(State(hd t)) → take k p = take k p'` — *IsabeLLM's theorem*; we defer, citing 2601.07654 as the existing mechanization | T5 | No (adversarial-probabilistic assumptions) | L (in Lean, re-do) | post-M6 | PROPOSED (deferred) |
| THM-054 | Difficulty-retarget safety: retarget keeps `target ∈ [powLimit⁻¹, powLimit]`-style bounds and monotone response to hash-rate; **nobody has mechanized the real 2016-block retarget function** (IsabeLLM models abstract PoW only) | T5 | SHA | L–XL | post-M6 | PROPOSED (deferred) |
| THM-055 | Chain-growth quality bound (Backbone chain-quality under ⅓ adversary): deferred with THM-053 | T5 | No | XL | post-M6 | PROPOSED (deferred) |

**Totals: 55 rows — 6 VERIFIED (probe), 49 PROPOSED; ★ headline = 10.** Crypto map: 31× No, 7× SHA, 8× Auth, 9× Full/deferred.

*Effort calibration note: IsabeLLM's lemma LoP table (5–158 Isar lines/lemma, median ~25) suggests our S/M/L/XL bands translate to ~10 / 10–50 / 50–200 / 200+ Lean lines for comparable statements — LLM-assisted proving (2606.18098) should compress this further.*
