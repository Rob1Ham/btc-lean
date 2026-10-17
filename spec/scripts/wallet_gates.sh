#!/usr/bin/env bash
# wallet_gates.sh - local acceptance gate for the additive wallet layer.
#
#   CORE_SRC=/path/to/bitcoin/src bash spec/scripts/wallet_gates.sh
#
# The Core source is only needed for the wallet census anchor check.  The
# sorry, tag/row, isolation, and axiom checks are static against this tree.
set -euo pipefail
cd "$(dirname "$0")/../.."

python3 spec/scripts/wallet_sorry_lint.py
python3 spec/scripts/wallet_crosscheck.py
python3 spec/scripts/wallet_isolation.py
bash spec/scripts/wallet_axiom_manifest.sh --check-static

if [[ -n "${CORE_SRC:-}" ]]; then
  python3 spec/scripts/wallet_census.py --lock --core-src "$CORE_SRC"
else
  echo "wallet-gates: CORE_SRC unset; skipping the 140-anchor census check"
fi

if [[ "${WALLET_SKIP_PROBE:-0}" != "1" ]]; then
  bash spec/scripts/wallet_axiom_manifest.sh --probe
fi

echo "wallet-gates: OK"
