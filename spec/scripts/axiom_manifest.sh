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
#                                  # (shape + no sorryAx/native axioms) without
#                                  # invoking Lean. The dynamic #print axioms
#                                  # probe is intentionally NOT run in CI:
#                                  # it needs elan + the mathlib proofs env,
#                                  # and the CI policy forbids Lean builds.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROBE="$ROOT/scripts/axiom_probe.lean"
MANIFEST="$ROOT/db/axiom-manifest.txt"
TMP="$(mktemp "${TMPDIR:-/tmp}/axiom-manifest.XXXXXX.txt")"
trap 'rm -f "$TMP"' EXIT

if [ "${1:-}" = "--check-static" ]; then
  if [ ! -s "$MANIFEST" ]; then
    echo "axiom-manifest[static]: missing or empty $MANIFEST" >&2
    exit 1
  fi
  # Manifest entries may wrap across lines (long axiom lists). Join each
  # entry that starts with a quoted theorem name, then validate the result.
  python3 - "$MANIFEST" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
entries, cur, start = [], [], 0
for n, line in enumerate(path.read_text().splitlines(), 1):
    if not line.strip():
        continue
    if line.startswith("'"):
        if cur:
            entries.append((start, " ".join(cur)))
        cur, start = [line.strip()], n
    elif cur:
        cur.append(line.strip())
    else:
        entries.append((n, line.strip()))
if cur:
    entries.append((start, " ".join(cur)))

pat = re.compile(r"^'[^']+' (?:does not depend on any axioms|"
                 r"depends on axioms: \[[^\]]*\])$")
bad = [(n, e) for n, e in entries if not pat.fullmatch(e)]
if bad:
    print("axiom-manifest[static]: malformed manifest entries:", file=sys.stderr)
    for n, e in bad:
        print(f"  {path}:{n}: {e[:120]}", file=sys.stderr)
    sys.exit(1)
if not entries:
    print("axiom-manifest[static]: no entries", file=sys.stderr)
    sys.exit(1)
text = path.read_text()
for marker in ("sorryAx", "Lean.ofReduceBool", "Lean.trustCompiler", "_native"):
    if marker in text:
        print(f"axiom-manifest[static]: forbidden axiom/trust marker: {marker}",
              file=sys.stderr)
        sys.exit(1)
print(f"axiom-manifest[static]: OK ({len(entries)} entries, no sorryAx/_native)")
PY
  echo "axiom-manifest[static]: dynamic #print axioms probe SKIPPED (CI does not build Lean; run locally with Lean installed)"
  exit 0
fi

cd "$ROOT/proofs"
# W15: the probe now imports proof-side modules (BitcoinProofs.*), which
# live in the `proofs` package; that package requires `core`, so running
# the probe from the proofs env sees every module it names.
lake env lean "$PROBE" > "$TMP" 2>/dev/null || {
  echo "axiom-manifest: probe failed"; cat "$TMP"; exit 1; }

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
