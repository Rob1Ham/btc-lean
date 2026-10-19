# State of mechanization of Bitcoin

Research note, 2026-10-16.
Scope: every known proof-assistant / mechanized / model-checked formalization of Bitcoin or Bitcoin-like consensus, plus the closest executable-specification prior art (Hornet); prover, level, coverage, code, aliveness, gap to btc-lean.

---

## Executive summary

1. **The single most important correction to the earlier project scope:** the Rupić/Rožić/Derek FMBC 2020 model — previously listed as "prover/coverage to be verified" — is **Coq, not Isabelle** (verified by cloning the repo: `Bitcoin.v` + `Utils.v`, Coq 8.10.2).
2. I cloned and read it: ~4,031 lines of Coq, **8 main theorems** (no-double-spending, transaction uniqueness, UTXO value bounded by coinbase value, chain-consistency implications) over a *symbolic* model: script is a small denotational expression language, crypto is uninterpreted (`ver` returns a `bool`), no PoW, **no merkle trees (explicitly lists, not merkle), no serialization, no SegWit/Taproot semantics**. **Dead since July 2020** (last commit 2020-07-15).
3. **IsabeLLM (2026, Imperial College)** is the only active proof-assistant line on *Bitcoin* consensus — but it formalizes the **abstract PoW protocol** (n-ary block tree, common-prefix property, constant difficulty), not validation rules; there are no transactions, script, or UTXO in the model at all.
4. **There is no nontrivial Bitcoin-validation formalization in Coq beyond Rupić '20**, and none in Lean 4 at all (Lean hits are DeFi/AMM/fraud-games/EVM — all above or beside consensus validation). No proof-assistant mechanization is executable against mainnet data. The nearest *executable* prior art is **Hornet** (Sharp, arXiv:2509.15754, 2025): a declarative C++ specification plus a purpose-built functional DSL that syncs mainnet, designed to enable formal reasoning and code generation downstream of the spec. It is prior public work on the same subject and is credited here, but it is not itself a proof-assistant development or a machine-checked artifact.
5. **Hornet is the direct executable-specification predecessor, not a mechanization.** Its paper, code, and DSL are cited in "Prior work and attribution" below and in Appendices A–B. btc-lean's claimed advance is the Lean 4 kernel-checked model, proofs, real Script/SigHash coverage, and conformance harness; it does not claim the executable-specification idea itself as novel.
6. The **closest completed analogue to btc-lean's goal is not Bitcoin work at all**: IOG/Input Output's **Cardano formal ledger specification in Agda** (FMBC 2024) — a complete, executable, mechanized, conformance-tested ledger of a whole chain. It is the existence proof and the methodological template for "complete consensus spec in a dependent prover."
7. Conclusion: the fragments that exist (symbolic UTXO/ledger in Coq; abstract PoW safety in Isabelle; Script in Agda; hash/curve towers in Lean; Hornet's executable C++/DSL spec) **do not compose** and share no common formalization. A complete, executable, proof-checked Lean 4 consensus spec of Bitcoin remains genuinely novel — essentially every concrete layer (serialization, real Script bytecode, SigHash, SegWit/Taproot, difficulty retarget, coinbase maturity, activation) has **zero** prior mechanization.

---

## Prior work and attribution — Hornet (Toby Sharp)

Hornet is the closest prior public work to btc-lean's executable-specification goal, and this survey credits it in that capacity. It is a minimal, executable, declarative C++ specification of Bitcoin consensus plus a purpose-built functional DSL, with a node that syncs mainnet. The design deliberately places formal reasoning downstream of a readable, executable specification; the paper presents formal reasoning, consensus code generation, and AI-driven adversarial testing as the path enabled by the spec.

Hornet is **not** a proof-assistant mechanization. As surveyed at commit `151462fa` (2026-04-15), the public repository contains the declarative C++ spec, the DSL sketch, and the node, but no machine-checked proof development. It should therefore be cited for its architecture, rule inventory, and DSL design — not described as a mechanization, and not omitted as unrelated implementation work.

- **Paper:** Toby Sharp, "Hornet Node and the Hornet DSL: A Minimal, Executable Specification for Bitcoin Consensus", arXiv:2509.15754v2 (2025-09-24), DOI [10.48550/arXiv.2509.15754](https://doi.org/10.48550/arXiv.2509.15754).
- **Code:** [github.com/tobysharp/hornet](https://github.com/tobysharp/hornet) (MIT), project site [hornetnode.org](https://hornetnode.org).

---

## Key findings

### F1 (VERIFIED, cloned + read) — Rupić/Rožić/Derek FMBC 2020 is **Coq**, symbolic, ~4k lines, dead

- Repo: https://github.com/krupic2402/bitcoin-blockchain-validation-formal-model — README: *"This is the Coq artifact of our paper… Checked with Coq version 8.10.2."* Header of `Bitcoin.v`: same. Last commit **2020-07-15** (`2bfcd10`). No activity since. DROPS shows ~8 citations.
- Size: `Bitcoin.v` 3,247 lines + `Utils.v` 784 lines = **4,031 lines**; 46 lemmas/theorems in `Bitcoin.v`, 56 in `Utils.v` (mostly equality/list helper lemmas).
- What is mechanized (VERIFIED by reading the definitions):
  - Mutually inductive `Exp`/`StackValue`/`TxStub` with a **denotational semantics** (`denote`) of a Bitcoin-Script-*like* expression language: `e_plus/e_minus/e_equal/e_less/e_if/e_length/e_hash/e_versig`, plus `e_abs_after`/`e_rel_after` (absolute/relative locktime). This is an expression calculus, **not** Bitcoin's stack-based bytecode.
  - SIGHASH modifier enum (ALL/NONE/SINGLE × ANYONECANPAY); `ver : PK → Sigma → TxStub → Index → bool` — **abstract/symbolic signature check** (perfect cryptography assumption, per paper abstract).
  - `Tx := stub + witnesses` (a SegWit-*shaped* witness list, but witness = list of stack values, no real Script program).
  - `TxHistory`, `UTXO`/`STXO` computed as list partitions; `sum_inputs ≥ sum_outputs`; coinbase with height & block reward (halving constants toy-scaled: reward 100, interval 21).
  - `Blockchain` as an inductive chain of blocks (txs + witnesses + **timestamp**); `blockchain_consistent` inductive predicate (coinbase first, coinbase height/reward correct, per-tx value conservation).
  - Theorems: `no_double_spending`, `no_double_spending_distinct`, `transaction_uniqueness(_strong)`, `UTXO_value_bounded_by_coinbase_value` (no-inflation), `UTXO_dominate_inputs`, `bc_consistent_implies_tx_hist_consistent` (+ corollaries), `bc_consistent_utxo_value`.
- What is **absent** (grep-verified in the repo): PoW/nonce/difficulty/target — 0 hits; merkle trees — the source comment states *"Transactions and witnesses are segregated, but stored as lists rather than merkle trees"*; no serialization, no real opcode interpreter, no P2SH/SegWit/Taproot rules, no soft-fork activation, no coinbase maturity (BIP34 partially via height-in-coinbase check only).
- Executability: none in our sense — no extraction, no run against real data; `ver`/`e_hash` are uninterpreted.

### F2 (VERIFIED, papers + repo) — IsabeLLM (Jones & Knottenbelt, Imperial College, 2026)

Three artifacts form one line:
1. **Jones & Marmsoler, "Towards Mechanised Consensus in Isabelle", FMBC 2024** (OASIcs 118, 10.4230/OASIcs.FMBC.2024.4; artifact Zenodo 10.5281/zenodo.10479776): blockchain = longest branch of a **binary tree**; proves **common prefix** under majority-honesty + synchrony (Bitcoin Backbone properties). 22 lemmas.
2. **arXiv:2601.07654 (Jan 2026), "Towards Automating Blockchain Consensus Verification with IsabeLLM"**: generalizes to an **n-ary block tree**; 16 non-trivial lemmas + `theorem consensus` (`take k p = take k p'`); ~395 lines of proof (vs 175+193 binary). LLM = DeepSeek R1 via OpenRouter; Isabelle 2022 + Scala-Isabelle + Sledgehammer (60 s) loop. Every non-trivial lemma was proven with LLM assistance.
3. **arXiv:2606.18098 (Jun 2026), "IsabeLLM: Automated Theorem Proving Applied to Formally Verifying Consensus"**: IsabeLLM-RAG — adds (a) RAG DB (ChromaDB + all-MiniLM-L6-v2 embeddings of the 22 binary-tree proofs, dependency-graph BFS bundling, top-3 similar lemmas injected into prompts), (b) **Nitpick counterexample generation** to kill logically-false proof steps, (c) **error trace** between LLM calls (stops fixate-and-loop failures), (d) Isabelle 2025 + single-process Sledgehammer. Success rates over 10 attempts × 16 lemmas: DeepSeek R1 76.3% avg SR / 1.31 iters → R1T2 Chimera **94.4% / 1.06** → Nemotron-3-Super 87.5% → GPT-OSS-120b 67.5%.
- **Level: protocol only.** Constant difficulty (longest-chain, not heaviest-chain), synchrony assumed, **no transactions, no script, no UTXO, no PoW arithmetic** (the "PoW" is an abstract honest/dishonest block-add event model). Explicitly stated in the paper: model deliberately abstracts difficulty to avoid a computational model.
- Repo: https://github.com/EllbellCode/IsabeLLM — cloned; last commit **2026-04-10** (ALIVE). Theory files: `ConsensusRaw.thy` (527), `nConsensusRaw.thy` (593), `nConsensusAnnotated.thy` (887), `test.thy` (361). Tooling in Scala (build.sbt) + Python OpenAI client; RAG DB dump included.
- **proof engineering-relevant methodology findings (VERIFIED from both papers):** IsabeLLM proves *statements humans write*, not statement generation; main failure modes are (i) LLM fixating on one failing proof step (mitigated by error trace + Nitpick), (ii) Sledgehammer timeouts on big steps (mitigated by Isabelle 2025 + step decomposition), (iii) hallucinated facts/methods (filtered by build errors); RAG on *structurally similar proofs from the same development* is the single highest-leverage automation win (branch_height 0% → 90%).

### F3 (VERIFIED) — Chaudhary/Fehnker/van de Pol/Stoelinga 2015: UPPAAL model checking, protocol level

"Modeling and Verification of the Bitcoin Protocol", MARS 2015 workshop (EPTCS), arXiv:1511.04173. Bitcoin modeled as **UPPAAL timed automata** (block generation, propagation, difficulty adjustment); verified properties about **double-spending attack success probability/possibility**. Protocol/economic-behavior level; no validation rules, no ledger, no script; not a proof assistant; not maintained (one-off).

### F4 (VERIFIED) — Coq landscape: Rupić is the *only* Bitcoin-validation artifact

Searches ("bitcoin coq formalization", "bitcoin consensus coq", awesome-coq/rocq lists) find no other Bitcoin-specific Coq development. Adjacent Coq work, all *not* Bitcoin-validation:
- **Pîrlea & Sergey, "Mechanising Blockchain Consensus" (Toychain), CPP 2018** — Coq; generic PoW chain with merkle trees & transactions; proves global system safety (all peers agree on one chain of blocks with valid txs). Abstract crypto, abstract validity; a *framework*, not Bitcoin's rule set. https://ilyasergey.net/papers/toychain-cpp18.pdf
- Alturki et al., Algorand in Coq (FM 2019); Casper finality proofs (CoqPL'19); PoS-NSB (Nakamoto-style PoS in Coq); Bu & Sun, CKB (Nervos, Bitcoin-like UTXO) **block synchronization** protocol in Coq (ICFEM 2020); Ceresa & Sánchez "Multi" (FMBC 2022) and Lean fraud-proof games (FMBC 2025).
- **Finding: absence of a serious Bitcoin consensus/validator formalization in Coq is itself a result** — the one attempt (Rupić) stopped in 2020 at a symbolic model.

### F5 (VERIFIED) — FMBC 2019–2026: Bitcoin-specific papers are a handful

Volumes: FMBC'19 (LNCS 12232, Springer — no OASIcs volume), 2020 (OASIcs 84), 2021 (95), 2022 (105), 2024 (118), 2025 (129), 2026 (142). Bitcoin-relevant items across all volumes:
- FMBC 2020: **Rupić et al. (Coq, above)**; Boss/Brünnler/Doukmak, **"Towards Verifying the Bitcoin-S Library"** (short paper, 10.4230/OASIcs.FMBC.2020.8 — property-based/spec work toward the Scala bitcoin-s library, did not become a maintained formalization); Lochbihler & Marić, **"Authenticated Data Structures as Functors in Isabelle/HOL"** (generic merkle trees — directly reusable theory for our merkle/witness-commitment rules); Wu/Gjøsteen/Boyd "A Blockchain Model in Tamarin" (protocol-level, symbolic).
- FMBC 2021, 2022: **nothing Bitcoin-consensus** (Tezos/DeFi/Coq-smart-contract focus).
- FMBC 2024: **Jones & Marmsoler (Isabelle PoW, above)**; **Knispel et al., "Formal Specification of the Cardano Blockchain Ledger, Mechanized in Agda"** (10.4230/OASIcs.FMBC.2024.2; repo https://github.com/IntersectMBO/formal-ledger-specifications) — full-scale executable mechanized ledger of Cardano with conformance testing against the production implementation. **This is the gold-standard template for btc-lean's endgame.**
- FMBC 2025: Melkonian et al., **"Program Logics for Ledgers"** (ledger-agnostic program logic, Bitcoin/Atzei-tx-model lineage; Coq, archived at Software Heritage); Ceresa & Sánchez, fraud-proof games in Lean 4 (L2 layer).
- FMBC 2026: EVM-in-Isabelle (10.4230/OASIcs.FMBC.2026.3, "A Novel Formalization of the EVM in Isabelle/HOL"), reentrancy-from-EVM-traces, Isabelle/Solidity — Ethereum-centric; **no Bitcoin validation paper**.

### F6 (VERIFIED) — TLA+/Alloy/model checking of Bitcoin: protocol-level only

- Tendermint sync in TLA+ (FMBC 2020); Tenderbake TLA+ (FMBC 2021); **Lightning Network in TLA+** (Grundmann & Hartenstein, arXiv:2307.02342) — L2, not consensus; Quint/TLA+ toy blockchain specs (github.com/christophercampbell/blockchain-specs); stochastic PRISM/PEPA models of Bitcoin (Bistarelli et al.); Chaudhary UPPAAL (F3). Ivy models of BFT chains (Supra/Moonshot FMBC 2024, Tendermint by Galois).
- **No TLA+/Alloy model of Bitcoin's validation rules exists** (they are not naturally a concurrent-system problem). Model checking of Bitcoin is uniformly about attack dynamics (double-spend probability, fork behavior), not rule faithfulness.

### F7 (INFERRED, citation VERIFIED) — Tolmach et al. survey positioning

Tolmach, Li, Lin, Liu, "A Survey of Smart Contract Formal Specification and Verification", ACM Computing Surveys 54(7), article 148 (2022; online 2021), DOI 10.1145/3464421. Its taxonomy (contract-level verification: languages, semantic models, tools; a smaller section on protocol/consensus verification) leaves **Bitcoin's validation rules essentially unmapped**: Bitcoin appears as ledger background and via tx-model papers (Atzei et al. 2017, *non-mechanized*), while the verified-contract machinery (KEVM, Move Prover, Certora) is all Ethereum-side. On their map, btc-lean sits in the under-populated intersection "protocol/consensus formalization × proof assistant × executable spec" — for Bitcoin, that cell is empty.

### F8 (VERIFIED/INFERRED mix) — Everything else surfaced

- **Setzer, "Modelling Bitcoin in Agda" (arXiv:1804.06398, 2018)** — early toy Agda model of transactions/blockchain; teaching/sketch scale, superseded by the Alhabardi/Setzer **Bitcoin-Script-in-Agda** line (arXiv:2203.03054, TYPES 2021; weakest-precondition program logic for a Script subset) — detailed treatment belongs to script semantics.
- **Atzei/Bartoletti/Lande/Zunino, "A Formal Model of Bitcoin Transactions" (eprint 2017/1124)** — pen-and-paper (Isabelle-*style* math but **not mechanized**); proves no-double-spend & value-decrease on an abstract tx model; the de-facto citation for "formal model of Bitcoin txs" and the ancestor of Rupić's and Melkonian's models.
- **Lean 4 hits (2024–2026)** are all adjacent, none consensus-validation: Pusceddu & Bartoletti AMMs in Lean 4 (FMBC 2024); Ceresa & Sánchez fraud-proof games; Nethermind's Lean EVM/Yul semantics + Lean crypto (zk, Halo2); StarkWare-style secp256k1 Lean 3; Lean 4 SHA-2/SHA-3 (Lean ecosystem's territory).
- No "bitcoin Agda" beyond Setzer/Alhabardi; no "bitcoin Isabelle" beyond FMBC'20 pieces + IsabeLLM line; no 2024–2026 new entrants on Bitcoin validation in any prover (searches: "bitcoin formal verification theorem prover 2025", "bitcoin mechanized").

### F9 (VERIFIED) — Hornet (Sharp 2025): executable declarative C++ spec + functional DSL; prior art, not a proof assistant

Hornet is the direct predecessor line for btc-lean's executable-specification ambition and is cited as prior public work on the same subject. At the surveyed commit (`151462fa`, 2026-04-15; repo public, MIT, active):

- The consensus layer is a compact, statically composed rule graph (header / local / contextual / spending checks) expressed as pure, deterministic, immutable C++ functions over explicit contexts, with the spec itself represented as a first-class value and rendered to an English rule table.
- The Hornet DSL is a purpose-built functional notation for the same rules; the paper positions it as the route to formal reasoning and consensus code generation. The DSL compiler is future work, so the C++ remains the executable artifact.
- The node syncs mainnet; however, as surveyed, spend-script execution and signature checks are stubs/TODO, and the activation model uses fixed heights rather than BIP9/Taproot state.
- No proof assistant or machine-checked theorem is part of the published artifact. The paper's "formal" claim is about purity, declarativeness, and the path to formal reasoning, not a kernel-checked development.

**Why it matters here:** Hornet supplies a worked rule inventory/decomposition and the spec-as-data discipline that btc-lean can mirror; btc-lean's distinct contribution is the Lean 4 mechanization (definitions + proofs), its full Script/SigHash target, and Core-vector conformance. Credit for the executable-specification approach belongs to Hornet.

---

## Detailed analysis

### The state-of-mechanization table (see Appendix B for full-width version)

Reading the landscape by *level*:

| Level | What exists | What's missing for a complete consensus spec |
|---|---|---|
| **Protocol (PoW/Nakamoto)** | IsabeLLM n-ary-tree common-prefix (Isabelle, alive); Backbone-style Coq (Toychain, PoS-NSB); UPPAAL/TLA+/PRISM attack dynamics | Difficulty retarget arithmetic, heaviest-chain (not longest), timewarp/meantime rules — *nothing* mechanized |
| **Validation / ledger (UTXO, block checks)** | Rupić Coq model (symbolic, dead 2020); Atzei tx model (paper); Cardano Agda ledger (different chain, complete) | Real block/tx validation pipeline: every contextual check, coinbase maturity, BIP30/34/90, weight, amounts, activation state machine — 0% mechanized anywhere |
| **Script** | Agda weakest-preconditions for a Script subset (script semantics); Rupić mini-expression denotational semantics; Klomp/Bracciali symbolic | Full legacy+SegWit+Taproot bytecode interpreter semantics incl. every opcode limit — 0% mechanized at *bytecode* level |
| **Crypto** | Lean islands (SHA-2/3, secp256k1 partial); Isabelle EVM's keccak; Agda/Cardano hash towers | BIP340 Schnorr + BIP341/342 SigHash verification end-to-end in one prover — 0% |

**Gap analysis — which fragments exist:**
1. *Fragment: abstract UTXO ledger laws* — exists (Rupić Coq, Atzei paper, Program Logics for Ledgers). Value: the theorem statements (no-double-spend, uniqueness, value-bounded-by-coinbase) transfer almost verbatim to btc-lean's theorem portfolio. The *proofs* do not (different prover, symbolic crypto, list-based UTXO vs Core's coins-view).
2. *Fragment: PoW consensus safety* — exists (IsabeLLM). Value: for this project it is a *reference track*; protocol-level PoW safety is out of scope for v1. The IsabeLLM studies are also a useful precedent for proof automation.
3. *Fragment: Script semantics* — exists in Agda, symbolic (script semantics's brief).
4. *Fragment: crypto primitives* — exist scattered in Lean/others (Lean ecosystem's brief).

**Which fragments are missing entirely (no prior mechanization, in any prover):**
- Serialization (tx/block encodings, CompactSize, witness format) — prerequisite for executability.
- The **real** Script interpreter (stack machine, opcode-by-opcode, `OP_CHECKMULTISIG` off-by-one, `OP_RETURN`/cleanstack policy-vs-consensus distinctions, Taproot leaf versions).
- SigHash computation (legacy, BIP143, BIP342) — the single most CVE-dense corner.
- PoW/difficulty retarget & consensus-relevant time rules (BIP94 timewarp, MTP windows).
- Coinbase maturity (BIP34 height, 100-block rule), BIP30 duplicate-tx handling, which Rupić cites but does not mechanize.
- Soft-fork activation (BIP9/8, height+version locks, the 2012–2017 deployment history).
- Weight/size limits, mempool-vs-consensus boundary documentation.

**What's genuinely novel in btc-lean (estimate):** conservatively, **>90% of the concrete spec** (by rule count of the Core inventory) has no prior mechanization of any kind; the reusable prior art is (a) theorem *statements* and model-shape lessons from Rupić/Atzei/Melkonian, (b) methodology (conformance testing against the production client) proven at scale by Cardano's Agda ledger, (c) the IsabeLLM LLM-assisted proving playbook for proof engineering, (d) generic merkle-tree Isabelle theory (Lochbihler/Marić) as a design reference, and (e) Hornet's executable-specification architecture, rule inventory, and DSL design — prior public work on the same subject, credited but not a mechanization.

**Aliveness check (VERIFIED):** Rupić repo dead (2020); IsabeLLM alive (Apr 2026); Hornet active (public, MIT; pushed 2026-10-19); formal-ledger-specifications (Cardano) actively maintained (large org repo); Toychain archived; bitcoin-s verification line dormant; UPPAAL/TLA+ one-offs.

### IsabeLLM and proof automation

The IsabeLLM work is relevant as a precedent, not as a dependency. It reports
94.4% average lemma success with retrieval and counterexample feedback, and its
most useful lesson is that automation helps discharge statements but does not
write the specification. Statement and model authoring remain the limiting
step.

---

## Implications for btc-lean

1. **Scope note:** Rupić et al. = **Coq**, symbolic, 4k lines, 8 theorems, dead since 2020 — and *weaker* than the earlier project wording suggested: "the first mechanized formal model of Bitcoin's blockchain validation" is a symbolic, list-not-merkle, no-PoW model. This *strengthens* the novelty claim.
2. **Theorem portfolio:** import the Rupić/Atzei theorem statements as the *ledger-level* tranche (no-double-spend, tx uniqueness, UTXO-value ≤ total coinbase subsidy+fees, consistency-preservation of block application). These are proven statements about the right abstractions; proving them over an *executable, bit-exact* Lean model is a strictly stronger result.
3. **Roadmap:** the Cardano formal-ledger-specifications project is the phased-roadmap existence proof: hierarchy of modular transitions → executable spec → conformance harness against the production node → meta-theorems. Its structure (per-era modules, property test suite) maps cleanly onto our M0–M6 with Bitcoin's "eras" = consensus deployments.
4. **Proof automation:** IsabeLLM demonstrates ~94% first-pass-ish automation on *protocol-math* lemmas with RAG over the project's own proof corpus — implying: seed btc-lean early with a self-RAG corpus (our own proofs are the best retrieval base), budget counterexample checking (Lean's `native_decide`/`decide` + e.g. QuickChick-style testing analog), and treat model/statement authorship as the human specification bottleneck.
5. **Script semantics and Lean ecosystem hooks:** Lochbihler/Marić functors-for-merkle-trees is the design reference for our merkle/witness-commitment layer; the IsabeLLM Common-Prefix development is a citable precedent if we later add the Nakamoto-protocol track.
6. **Publication positioning:** "first complete mechanization of Bitcoin's actual validation rules" is defensible; the three lines reviewers will name are Rupić (Coq, symbolic validation), IsabeLLM (Isabelle, abstract protocol), and Hornet (executable C++/DSL, not a proof assistant). All are partial or orthogonal to the target: validation-but-symbolic, protocol-but-abstract, and executable-but-unproved. No reviewer can point at an existing complete proof-checked artifact.

## Open questions & risks

- **R1 — Does the IsabeLLM line intend to expand toward validation rules?** Their stated future work is tool generality + Isabelle/Solidity integration, *not* Bitcoin validation. Low competitive risk, but monitor Imperial College output (last paper Jun 2026).
- **R2 — Cardano-style scale cost:** formal-ledger-specifications is a multi-year, team-scale effort (Input Output funding). A single lean effort must scope M-milestones to be publishable per-fragment; risk is the "90% done = abandoned" pattern that killed Rupić.
- **R3 — Symbolic-crypto debt:** every prior Bitcoin mechanization assumed perfect crypto. btc-lean's decision (Lean ecosystem/crypto tower) on verified-vs-axiomatized SHA-256/secp256k1 determines whether "no double spend *without forging signatures*" is even expressible; the literature offers no shortcut.
- **R4 — Un-verified claim risk:** Tolmach-survey positioning (F7) is INFERRED from citation record + known scope, not a full re-read of all 38 pages; a design-track pass over the survey PDF would close it.
- **R5 — Hornet's formal-reasoning line continues.** Hornet is actively developed, and its author describes formal reasoning as downstream of the readable, executable specification. Monitor the repo for a proof-assistant artifact; until then, credit Hornet as executable prior art rather than treating it as a mechanization or as a competitor to dismiss.
- **Q1 —** Did any Bitcoin Core-adjacent effort (e.g., bitcoin-s, rust-bitcoin, Kernel-lab) quietly formalize rules in a prover post-2024? My searches found none, but Kernel/C++ verification work (upstream-track) is the likelier place to double-check.
- **Q2 —** Should the Rupić Coq artifact be ported/reviewed as a *design doc* for our ledger module? (Recommend: read, don't port — its `Den`-monad semantics is elegant but its list-UTXO and symbolic crypto don't match our goals.)

## Recommendations

1. **Update the comparison table** (Rupić = Coq; add Cardano Agda ledger as the completeness template; mark IsabeLLM as alive/2026).
2. **Adopt Cardano-FLS's pattern** for roadmap: modular transition hierarchy + executable + conformance-tested + meta-theorems; cite 10.4230/OASIcs.FMBC.2024.2 as the methodological precedent.
3. **Stand up the proof engineering tooling early with self-RAG**: mirror IsabeLLM's architecture (build→extract sorry→LLM→rebuild→automate-fallback→error-trace→counterexample) but on Lean (LeanDojo-style programmatic access), seeded by btc-lean's own proof corpus from M1 onward.
4. **Contact-free reuse:** mine Rupić's theorem statements and Atzei's tx-model properties for the theorem portfolio; mine Lochbihler/Marić for merkle design; do not port code.
5. **Claim & verify novelty at publication time** with a fresh literature sweep (this report's searches, re-run at M4), focusing on Coq/Lean/Isabelle repos + FMBC 2027 CFP.

---

## Appendix A — Sources (primary where possible)

| # | Source | Type | Status |
|---|---|---|---|
| 1 | Rupić, Rožić, Derek — "Mechanized Formal Model of Bitcoin's Blockchain Validation Procedures", FMBC 2020, OASIcs 84, 7:1–7:14, DOI 10.4230/OASIcs.FMBC.2020.7 | paper (DROPS, PDF) | VERIFIED (abstract, refs, metadata) |
| 2 | Repo `krupic2402/bitcoin-blockchain-validation-formal-model` (clone @ `2bfcd10`, 2020-07-15; `Bitcoin.v` 3247 ln, `Utils.v` 784 ln, Coq 8.10.2) | code | VERIFIED (cloned, read, grepped) |
| 3 | Jones, Knottenbelt — "Towards Automating Blockchain Consensus Verification with IsabeLLM", arXiv:2601.07654 (2026-01-12) | paper (HTML full text) | VERIFIED |
| 4 | Jones, Knottenbelt — "IsabeLLM: Automated Theorem Proving Applied to Formally Verifying Consensus", arXiv:2606.18098 (2026-06-16) | paper (HTML full text) | VERIFIED |
| 5 | Repo `EllbellCode/IsabeLLM` (clone @ `355114e`, 2026-04-10; .thy files 527/593/887/361 ln, Scala+Python tooling, RAGdb) | code | VERIFIED (cloned) |
| 6 | Jones, Marmsoler — "Towards Mechanised Consensus in Isabelle", FMBC 2024, OASIcs 118, 4:1–4:22, DOI 10.4230/OASIcs.FMBC.2024.4; artifact Zenodo 10479776 | paper + artifact | VERIFIED (DROPS metadata/abstract) |
| 7 | Chaudhary, Fehnker, van de Pol, Stoelinga — "Modeling and Verification of the Bitcoin Protocol", MARS 2015 / EPTCS, arXiv:1511.04173 | paper | VERIFIED (abstract/primary pages) |
| 8 | Pîrlea, Sergey — "Mechanising Blockchain Consensus" (Toychain), CPP 2018, DOI 10.1145/3167086 | paper | VERIFIED (PDF) |
| 9 | Knispel, Melkonian, Chapman, Hill, Jääger, DeMeo, Norell — "Formal Specification of the Cardano Blockchain Ledger, Mechanized in Agda", FMBC 2024, DOI 10.4230/OASIcs.FMBC.2024.2; github.com/IntersectMBO/formal-ledger-specifications | paper + code | VERIFIED (DROPS metadata, artifact link) |
| 10 | Boss, Brünnler, Doukmak — "Towards Verifying the Bitcoin-S Library", FMBC 2020, DOI 10.4230/OASIcs.FMBC.2020.8 | paper | VERIFIED (metadata) |
| 11 | Lochbihler, Marić — "Authenticated Data Structures as Functors in Isabelle/HOL", FMBC 2020 | paper | VERIFIED (program listing) |
| 12 | Melkonian et al. — "Program Logics for Ledgers", FMBC 2025, DOI 10.4230/OASIcs.FMBC.2025.10 | paper | VERIFIED (DROPS) |
| 13 | Ceresa, Sánchez — "Towards a Mechanization of Fraud Proof Games in Lean", FMBC 2025, DOI 10.4230/OASIcs.FMBC.2025.5 | paper | VERIFIED (DROPS) |
| 14 | FMBC volumes 2019–2026 (OASIcs 84/95/105/118/129/142; FMBC'19 = LNCS 12232) + FMBC 2020 EasyChair program | proceedings | VERIFIED (volume TOCs scanned) |
| 15 | Atzei, Bartoletti, Lande, Zunino — "A Formal Model of Bitcoin Transactions", eprint 2017/1124; FC 2018 | paper | VERIFIED (eprint) |
| 16 | Setzer — "Modelling Bitcoin in Agda", arXiv:1804.06398 (2018) | paper | VERIFIED (cited in primary sources) |
| 17 | Alhabardi, Beckmann, Lazar, Setzer — "Verification of Bitcoin Script in Agda…", TYPES 2021, LIPIcs 239 | paper | VERIFIED (cited in primary sources; detail = script semantics) |
| 18 | Grundmann, Hartenstein — "Towards a Formal Verification of the Lightning Network with TLA+", arXiv:2307.02342 | paper | VERIFIED (abstract) |
| 19 | Tolmach, Li, Lin, Liu — "A Survey of Smart Contract Formal Specification and Verification", ACM Comput. Surv. 54(7):148, DOI 10.1145/3464421 | survey | citation VERIFIED; positioning INFERRED |
| 20 | "A Novel Formalization of the EVM in Isabelle/HOL", FMBC 2026, DOI 10.4230/OASIcs.FMBC.2026.3 | paper | VERIFIED (listing) |
| 21 | Bu, Sun — "Towards Modeling and Verification of the CKB Block Synchronization Protocol in Coq", ICFEM 2020 | paper | VERIFIED (cited in FMBC 2024 refs) |
| 22 | Sharp — "Hornet Node and the Hornet DSL: A Minimal, Executable Specification for Bitcoin Consensus", arXiv:2509.15754v2 (2025-09-24), DOI 10.48550/arXiv.2509.15754; project site hornetnode.org | paper | VERIFIED (abstract, metadata) |
| 23 | Repo `tobysharp/hornet` (MIT; public; active; surveyed @ `151462fa`, 2026-04-15) | code | VERIFIED (cloned, inspected) |

## Appendix B — State of mechanization of Bitcoin (full table)

| Work | Prover / tool | Level | Coverage / scope | Code | Alive? | Gap to btc-lean goal |
|---|---|---|---|---|---|---|
| Rupić/Rožić/Derek, FMBC 2020 ([paper](https://drops.dagstuhl.de/entities/document/10.4230/OASIcs.FMBC.2020.7)) | **Coq 8.10.2** | validation/ledger (symbolic) + toy script-as-expressions | Tx/witness data structures; mini-script denotational semantics; locktimes (abs/rel); SIGHASH flags; UTXO/STXO; fees; coinbase+reward; block-level consistency predicate; ~4,031 ln, 8 main thms: no-double-spend, tx uniqueness, UTXO ≤ coinbase value, consistency implications. **No PoW, no merkle (lists!), no serialization, no real bytecode, abstract crypto** | [github.com/krupic2402/bitcoin-blockchain-validation-formal-model](https://github.com/krupic2402/bitcoin-blockchain-validation-formal-model) | ❌ dead (2020-07) | Theorem statements reusable; everything concrete missing; wrong prover, symbolic crypto, not executable |
| Jones/Marmsoler, FMBC 2024 ([10.4230/OASIcs.FMBC.2024.4](https://drops.dagstuhl.de/entities/document/10.4230/OASIcs.FMBC.2024.4)) | Isabelle/HOL | protocol (PoW consensus safety) | Binary block tree; common-prefix property; majority-honest+synchronous assumptions; 22 lemmas; no txs/UTXO/script | Zenodo [10.5281/zenodo.10479776](https://doi.org/10.5281/zenodo.10479776) | ⚠️ superseded by n-ary | Abstract protocol only; out of btc-lean v1 scope; citable precedent |
| IsabeLLM v1 (arXiv:[2601.07654](https://arxiv.org/abs/2601.07654)) | Isabelle 2022 + DeepSeek R1 (LLM-automated) | protocol | n-ary block tree; 16 lemmas + `consensus` theorem (take k p = take k p'); ~395 LoP; constant difficulty (longest≠heaviest chain); no validation rules | [github.com/EllbellCode/IsabeLLM](https://github.com/EllbellCode/IsabeLLM) | ✅ alive (2026-04) | Same as above + proof engineering methodology donor |
| IsabeLLM-RAG (arXiv:[2606.18098](https://arxiv.org/abs/2606.18098)) | Isabelle 2025 + R1T2 Chimera/Nemotron/GPT-OSS + RAG + Nitpick + error trace | protocol | Same model; success-rate study (76.3%→94.4% avg, 1.31→1.06 iters); RAG over own proof corpus | same repo | ✅ alive | proof engineering blueprint: self-RAG, counterexamples, error traces |
| Chaudhary/Fehnker/van de Pol/Stoelinga, MARS 2015 ([arXiv:1511.04173](https://arxiv.org/abs/1511.04173)) | UPPAAL (timed model checker) | protocol dynamics | Block generation/propagation/difficulty as timed automata; double-spend attack reachability/probability | none found | ❌ one-off | Different problem class entirely; no validation content |
| Pîrlea/Sergey Toychain, CPP 2018 ([PDF](https://ilyasergey.net/papers/toychain-cpp18.pdf)) | Coq | protocol/ledger (generic) | Abstract PoW chain w/ merkle trees + valid-tx ledger; global-safety (Cliq) theorem; executable operational model | `toychain` (Coq, archived branch cpp2018) | ❌ archived | Framework precedent; Bitcoin rules absent; abstract validity predicate |
| Cardano formal ledger (FMBC 2024, [10.4230/OASIcs.FMBC.2024.2](https://drops.dagstuhl.de/entities/document/10.4230/OASIcs.FMBC.2024.2)) | **Agda** | validation/ledger (complete, for Cardano) | Full Cardano ledger: modular transition hierarchy, UTxO+scripts+governance; executable; conformance-tested vs production; meta-theorems | [github.com/IntersectMBO/formal-ledger-specifications](https://github.com/IntersectMBO/formal-ledger-specifications) | ✅ active | **Not Bitcoin** — but the completeness/conformance template to replicate |
| Program Logics for Ledgers (FMBC 2025, [10.4230/OASIcs.FMBC.2025.10](https://drops.dagstuhl.de/entities/document/10.4230/OASIcs.FMBC.2025.10)) | Coq (archived SH) | ledger program logic | General ledger/tx-model program logic (Bitcoin tx-model lineage); reasoning framework, not a consensus spec | Software Heritage `swh:1:dir:fe2bce9…` | ⚠️ research | Logic-level donor; no concrete rules |
| Boss/Brünnler/Doukmak, FMBC 2020 ([10.4230/OASIcs.FMBC.2020.8](https://drops.dagstuhl.de/entities/document/10.4230/OASIcs.FMBC.2020.8)) | (spec/verification of Scala bitcoin-s) | library-level, partial | Early steps toward verifying bitcoin-s (tx/script helpers); short paper, no sustained artifact | (bitcoin-s repo, not a proof artifact) | ❌ dormant | None directly |
| Lochbihler/Marić, FMBC 2020 (ADS as functors) | Isabelle/HOL | merkle/authenticated data structures | Generic merkle-tree theory via functors | AFP-style release | ✅ AFP maintained | Reusable *design* for merkle/witness-commitment layer |
| Atzei/Bartoletti/Lande/Zunino 2017 ([eprint 2017/1124](https://eprint.iacr.org/2017/1124.pdf)) | pen & paper (not mechanized) | tx model | Abstract Bitcoin tx model; thms: no double-spend of outputs, value (ex-coinbase) non-increasing | n/a | n/a | Model + property list donor |
| Setzer 2018 ([arXiv:1804.06398](https://arxiv.org/abs/1804.06398)) | Agda | tx/blockchain model (toy) | Exploratory Agda model of Bitcoin txs | (sketch) | ❌ superseded | Historical only |
| Alhabardi/Beckmann/Lazar/Setzer, TYPES 2021 (arXiv:2203.03054) | Agda | script (subset) | Weakest-precondition program logic for a Bitcoin Script subset | (paper artifact) | ⚠️ research line | Script-side only — script semantics's brief; no ledger/block layer |
| Wu/Gjøsteen/Boyd, FMBC 2020 (Blockchain Model in Tamarin) | Tamarin | protocol (symbolic) | Generic blockchain model in symbolic protocol prover | (paper) | ❌ one-off | Not Bitcoin-validation |
| Tenderbake TLA+ (FMBC 2021), Tendermint sync (FMBC 2020), Lightning TLA+ ([arXiv:2307.02342](https://arxiv.org/abs/2307.02342)) | TLA+ | BFT/L2 protocols | Model checking of Tezos/Tendermint/LN protocols | various | mixed | Different consensus family; no Bitcoin validation |
| Bu & Sun, ICFEM 2020 (CKB sync in Coq) | Coq | protocol (sync), CKB (Bitcoin-like UTXO) | Nervos CKB block-synchronization protocol verification | (paper) | ❌ | Sync protocol, not validation rules |
| Ceresa/Sánchez Lean fraud games (FMBC 2025) | Lean 4 | L2 fraud proofs | Machine-checked arbitration-game strategies | gitlab.imdea `leanfpgames` | ⚠️ research | Lean precedent, unrelated layer |
| Pusceddu/Bartoletti AMMs (FMBC 2024) | Lean 4 | DeFi | AMM formalization in Lean 4 | arXiv:2402.06064 | ⚠️ | Shows Lean 4 readiness, not consensus |
| Hornet (Sharp 2025, [arXiv:2509.15754](https://arxiv.org/abs/2509.15754)) | C++23 declarative spec + Hornet DSL (functional) | validation (executable specification) | Compact rule graph for header/local/contextual/spending checks; mainnet IBD; designed to enable formal reasoning and code generation; no proof-assistant artifact; spend-script execution and signature checks are stubs/TODO at the surveyed commit (`151462fa`, 2026-04-15) | [github.com/tobysharp/hornet](https://github.com/tobysharp/hornet) (MIT) | ✅ active (pushed 2026-10-19) | Direct executable-specification predecessor; btc-lean targets Lean 4 mechanization, proofs, full Script/SigHash, and Core-vector conformance |
| **BTC validation rules, executable+proven — the btc-lean target** | Lean 4 | full stack | — | — | — | **~90%+ of concrete rules have zero prior mechanization (finding F8)** |

---
