# spec/equiv — three-leg LLVM IR equivalence
# Targets are intentionally thin; the fleet fills the implementations.

SHELL := bash
PYTHON ?= python3

.PHONY: help e0 equiv gate-ir-pin pins status clean

help:
	@echo "make e0          # E0: hello-world triple + capability matrix"
	@echo "make equiv       # run all cells, regenerate results/matrix"
	@echo "make gate-ir-pin # enforce pins, hashes, SCR coverage, no unfiled gaps"
	@echo "make pins        # check PINS.lock completeness"
	@echo "make status      # print results/STATUS.md"

e0:
	@sh tools/e0.sh

equiv:
	@$(PYTHON) tools/run_equiv.py
	@$(PYTHON) results/scripts/build_matrix.py

gate-ir-pin:
	@$(PYTHON) tools/gate_ir_pin.py

pins:
	@$(PYTHON) tools/check_pins.py

status:
	@cat results/STATUS.md 2>/dev/null || echo "no status yet (E0 not started)"

clean:
	@find results -type f -name '*.tmp' -delete
