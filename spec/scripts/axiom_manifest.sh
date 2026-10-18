#!/usr/bin/env bash
# axiom_manifest.sh — L2/L3 gate (D2 formality ladder, research/15):
# runs `#print axioms` (see scripts/axiom_probe.lean) over every named
# public theorem and diffs against the committed manifest
# spec/db/axiom-manifest.txt. Any axiom drift (a new sorryAx, a new
# _native axiom, a new Classical.choice) fails.
#
#   axiom_manifest.sh              # full check mode (needs Lean + mathlib)
#   axiom_manifest.sh --update     # regenerate the manifest (deliberate act)
#   axiom_manifest.sh --check-static
#                                  # CI mode: validate the COMMITTED manifest
#                                  # (shape + strict standard-axiom allowlist) without
#                                  # invoking Lean. The dynamic #print axioms
#                                  # probe is intentionally NOT run in CI:
#                                  # it needs Lean + the mathlib proofs env;
#                                  # the current CI job runs static checks.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROBE="$ROOT/scripts/axiom_probe.lean"
MANIFEST="$ROOT/db/axiom-manifest.txt"

if [ "${1:-}" = "--check-static" ]; then
  if [ ! -s "$MANIFEST" ]; then
    echo "axiom-manifest[static]: missing or empty $MANIFEST" >&2
    exit 1
  fi
  python3 "$ROOT/scripts/axiom_manifest_check.py" "$MANIFEST"
  echo "axiom-manifest[static]: dynamic #print axioms probe SKIPPED (CI does not build Lean; run locally with Lean installed)"
  exit 0
fi

# Keep the X template at the end for both BSD and GNU mktemp. Static
# verification needs no temporary file; concurrent probes need unique ones.
TMP="$(mktemp "${TMPDIR:-/tmp}/axiom-manifest.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

cd "$ROOT/proofs"
# W15: the probe now imports proof-side modules (BitcoinProofs.*), which
# live in the `proofs` package; that package requires `core`, so running
# the probe from the proofs env sees every module it names.
lake env lean "$PROBE" > "$TMP" 2>/dev/null || {
  echo "axiom-manifest: probe failed"; cat "$TMP"; exit 1; }

# A new footprint must satisfy the trust contract before comparison OR update.
# Regeneration may record reviewed footprints; it cannot authorize new axioms.
python3 "$ROOT/scripts/axiom_manifest_check.py" "$TMP"

if [ "${1:-}" = "--update" ]; then
  cp "$TMP" "$MANIFEST"
  echo "axiom-manifest: regenerated $MANIFEST"
  cat "$MANIFEST"
  exit 0
fi

if [ ! -f "$MANIFEST" ]; then
  echo "axiom-manifest: no manifest at $MANIFEST — run with --update to seed it"
  exit 1
fi

if diff -u "$MANIFEST" "$TMP"; then
  echo "axiom-manifest: OK ($(grep -c . "$MANIFEST") lines)"
else
  echo "axiom-manifest: DRIFT — run scripts/axiom_manifest.sh --update after REVIEW"
  exit 1
fi
