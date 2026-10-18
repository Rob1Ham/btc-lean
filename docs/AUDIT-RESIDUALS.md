# Accepted proof-surface residuals

This page records claim reductions and open proof obligations that were
accepted while reconciling the proof build after the source audit. These are
**not** consensus-row residuals: the row-level ledger is
[`RESIDUALS.md`](RESIDUALS.md) and its machine-readable copy is
[`spec/db/residuals.yaml`](../spec/db/residuals.yaml).

A proof-surface residual means the model no longer claims a result that was
advertised but not present, or a theorem is deliberately stated with a
narrower hypothesis than the prose around it. Removing a false or dangling
claim is preferred to leaving a vacuous theorem.

## BC-01 — `SmallCurve` interface restricted to 16-bit scalars

- module: `spec/proofs/BitcoinProofs/SmallCurve/TweakCorSmall.lean`
- change: `E02E03IFSmall.mulP_okE` and `mulP_noneE` now require `k < 2^16`.
- reason: `Scheme.mulP' k q` is `bitListRec (bitsOfW 16 k) q`: it reads only
  the low 16 bits of `k`. The unrestricted fields asserted
  `(k + 2^16) • B = k • B` for arbitrary `B`, which is false for `B = G`
  (`n = 65173` and `2^16 ≢ 0 (mod n)`). The MAIN theorems derive the bound
  from the code's own range check (`tweakScalarS p root < n < 2^16`).
- open obligation: construct `SCDE : E02E03IFSmall SC` (the E03/E05
  raw-case-table transport). The two MAIN theorems remain conditional on
  that record, as in the secp original.

## BC-02 — `PubKeyCor` U2 parse iff removed

- module: `spec/proofs/BitcoinProofs/EcdsaDeep/PubKeyCor.lean`
- change: the advertised `CoreVerifyParse`/`CorSerDec` iff
  (`parsePubKeyDeep_core`), `coreVerifyParse_false_iff`, `coreRel_none_iff`
  and `coreParse_none_blenTag` are removed from the header. U1
  (`GetLen`/`ValidSize`) is proved and axiom-pinned.
- reason: the declarations did not exist, and the file did not elaborate
  (non-Lean `Bool.eq_true mp_eq??` placeholder, malformed tactic block,
  truncated `validPubKeySize_cases`).
- open obligation: state and prove the parse-success ↔ Core
  `IsValid() ∧ ge_parse` equivalence. The 33-byte Some-path is the R6 lane
  (`sqrtP = expM`), so a total statement must split into a kernel-decidable
  matrix half and an R6 half.

## BC-03 — `PubKeyMatrix` R6 rows documented, not decided

- module: `spec/proofs/BitcoinProofs/EcdsaDeep/PubKeyMatrix.lean`
- change: five rows that called `by decide` through `sqrtP` are no longer
  claimed as kernel-decided examples. They are listed in an explicit R6
  section at the end of the module:
  `M2b-33B-02`, `M2b-33B-03`, `M6-pk-compressed-wrong-parity`,
  `M6-syn-02-33`, `M6-syn-03-33`.
- reason: `sqrtP`/`expM` are WellFounded in the core package; `decide`
  cannot reduce the 33-byte compressed Some-path. The expected verdicts are
  pyC/C oracle values, not kernel facts.
- open obligation: a reducible square root (or an R6-admitted oracle result)
  for the 33-byte Some lane. The 65-byte matrix and all tag/length gates
  remain kernel-decided.

## BC-04 — `SmulCor` conditional group lane not formalized

- module: `spec/proofs/BitcoinProofs/EcdsaDeep/SmulCor.lean`
- change: references to a `SmulCorIF.lean` module providing
  `MulPIF`/`SmulIF` (`mulP_okφ`, `mulP_noneφ`, `smulAdd_okφ`) are replaced
  by an explicit statement that the module and results do not exist. The
  zero-hypothesis results (`smulBits_eq_mulP`, `smulAdd` lemmas,
  `addP_self`) are unchanged.
- reason: the file did not exist; the docstring described conditional
  theorems as if they were in the tree.
- open obligation: the monoid-hom rung
  `φ (mulP k p) = k • φ p` and its `smulAdd`/`smulBits` corollaries over
  `φ : RawPoint → M` with `φ none = 0` and
  `φ (addP p q) = φ p + φ q`.

## BC-05 — `FuelStability` reduced to `evalFrom` stability

- module: `spec/proofs/BitcoinProofs/Theorems/FuelStability.lean`
- change: the module now proves
  `evalFrom_eventually_constant`: for `ops.length < f₁`, every `f₂ ≥ f₁`
  gives the same `evalFrom` verdict. The advertised `FUEL-STAB`,
  `FUEL-OPS`, `FUEL-LIT`, `FUEL-CAN`, `PushShaped`/`litOfOp` and the
  malformed `stepBody_pushBytes` claim are removed.
- reason: none of the advertised declarations existed; the one remaining
  proof was malformed.
- open obligation: bound the parsed-op count by script/witness byte mass
  (including the P2SH inner-evaluation lane) and prove that
  `pipelineFuel = ss.size + spk.size + wbytes + 28` is above the stability
  bound. That is the missing link for `FUEL-CAN`.

## BC-06 — `O07` hash examples corrected

- module: `spec/proofs/BitcoinProofs/Theorems/Ops/O07.lean`
- change: the five concrete hash-op examples now expect the digest to
  **replace** the top stack item (`stack := [digest]`), matching
  `opHash_effect`; the missing `#print axioms` bodies for the five size
  lemmas are filled in. The examples also discharge the
  `MAX_OPS_PER_SCRIPT = 201` reduction and the `disabledWire` hash-opcode
  guards explicitly, which is what made the concrete verdicts elaborate.
  One axiom pin (`step_hash_underflow_base`) was corrected to its actual
  footprint (`propext`, `Classical.choice`, `Quot.sound`). This is a fix,
  not a residual.
- status: the module builds and its cited row target
  `step_codesep_const_dead` is now in a passing build.
