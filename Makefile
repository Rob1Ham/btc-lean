# btc-lean — top-level entry points for the static gates.
#
# `make gates` mirrors .github/workflows/gates.yml. It never invokes
# Lean/lake; the dynamic `#print axioms` probe is local-only
# (`make gate-axiom-probe`).

SHELL := /usr/bin/env bash
PYTHON ?= python3
SPEC := spec
SCRIPTS := $(SPEC)/scripts

.PHONY: gates gate-sorry gate-cross gate-axiom-static gate-axiom-probe \
        gate-extract gate-census gate-overrides gate-pin gate-wallet \
        gate-subset gate-repro wallet-gates test-capstone-values test-capstone-funding test-capstone-context test-capstone-finality test-capstone-sigops test-capstone-sigop-budget test-capstone-witness help

help:
	@echo "make gates               # all nine static gates (CI equivalent)"
	@echo "make gate-sorry          # 1: sorry/native_decide/unsafe lint"
	@echo "make gate-cross          # 2: @[rule] <-> rules.yaml cross-check"
	@echo "make gate-axiom-static   # 3: axiom manifest shape (no Lean)"
	@echo "make gate-axiom-probe    # 3b: full #print axioms probe (needs Lean)"
	@echo "make gate-extract        # 4: extract_rules.py --check fixed point"
	@echo "make gate-census         # 5: yaml.safe_load + 726-row census"
	@echo "make gate-overrides      # 6: backfill_overrides.py --check"
	@echo "make gate-pin            # 7: every row anchor @cce32b168"
	@echo "make gate-wallet         # 8: wallet sorry, tags, isolation, static axioms"
	@echo "make gate-subset         # 9: 2-5 MiB data subset, no git-lfs"
	@echo "make gate-repro          # reproducibility scripts + local-path scan"
	@echo "make wallet-gates        # wallet gates (set CORE_SRC for anchors)"
	@echo "make test-capstone-values # live capstone monetary regressions (needs Lean)"
	@echo "make test-capstone-funding # block reward and fee regressions (needs Lean)"
	@echo "make test-capstone-context # contextual header regressions (needs Lean)"
	@echo "make test-capstone-finality # absolute/BIP68 contextual regressions (needs Lean)"
	@echo "make test-capstone-sigops # static sigop counter regressions (needs Lean)"
	@echo "make test-capstone-sigop-budget # live block resource-boundary regressions (needs Lean)"
	@echo "make test-capstone-witness # witness commitment/nonce/value regressions (needs Lean)"

gates: gate-sorry gate-cross gate-axiom-static gate-extract gate-census \
       gate-overrides gate-pin gate-wallet gate-subset
	@echo "gates: all nine static gates passed"

gate-sorry:
	@echo "== gate 1: sorry lint =="
	@bash $(SCRIPTS)/sorry_lint.sh
	@$(PYTHON) -m unittest discover -s $(SCRIPTS)/tests -p 'test_proof_gates.py'

gate-cross:
	@echo "== gate 2: rule cross-check =="
	@$(PYTHON) $(SCRIPTS)/rule_crosscheck.py

gate-axiom-static:
	@echo "== gate 3: axiom manifest (static; Lean probe not run) =="
	@bash $(SCRIPTS)/axiom_manifest.sh --check-static

gate-axiom-probe:
	@echo "== gate 3b: axiom manifest (full Lean probe; local only) =="
	@bash $(SCRIPTS)/axiom_manifest.sh

gate-extract:
	@echo "== gate 4: extract_rules --check =="
	@$(PYTHON) $(SCRIPTS)/extract_rules.py --check

gate-census:
	@echo "== gate 5: yaml census =="
	@$(PYTHON) $(SCRIPTS)/gate_census.py

gate-overrides:
	@echo "== gate 6: overrides sync --check =="
	@$(PYTHON) $(SCRIPTS)/backfill_overrides.py --check

gate-pin:
	@echo "== gate 7: anchor pin =="
	@$(PYTHON) $(SCRIPTS)/anchor_pin_check.py

gate-wallet:
	@echo "== gate 8: wallet static battery =="
	@$(PYTHON) $(SCRIPTS)/wallet_sorry_lint.py
	@$(PYTHON) $(SCRIPTS)/wallet_crosscheck.py
	@$(PYTHON) $(SCRIPTS)/wallet_isolation.py
	@bash $(SCRIPTS)/wallet_axiom_manifest.sh --check-static

gate-subset:
	@echo "== gate 9: data subset =="
	@bash scripts/check_subset_size.sh --root spec/data

gate-repro:
	@echo "== reproducibility: reference scripts and local-path scan =="
	@$(PYTHON) $(SCRIPTS)/check_reproducibility.py
	@$(PYTHON) $(SCRIPTS)/generate_sigop_blocks.py --check
	@$(PYTHON) $(SCRIPTS)/generate_witness_commitment_block.py --check

wallet-gates:
	@bash $(SCRIPTS)/wallet_gates.sh

test-capstone-values:
	@cd $(SPEC)/core && lake env lean --run Test/Capstone/ValueChecks.lean

test-capstone-funding:
	@cd $(SPEC)/core && lake env lean --run Test/Capstone/BlockFunding.lean

test-capstone-context:
	@cd $(SPEC)/core && lake env lean --run Test/Capstone/HeaderContext.lean

test-capstone-finality:
	@cd $(SPEC)/core && lake env lean --run Test/Capstone/Finality.lean

# Static counting includes malformed scripts, independent of execution validity.
test-capstone-sigops:
	cd spec/core && lake env lean --run Test/Capstone/Sigops.lean

test-capstone-sigop-budget:
	cd spec/core && lake env lean --run Test/Capstone/SigopBudget.lean

test-capstone-witness:
	cd spec/core && lake env lean --run Test/Capstone/WitnessCommitment.lean
	cd spec/core && lake env lean --run Test/Capstone/WitnessStage.lean
