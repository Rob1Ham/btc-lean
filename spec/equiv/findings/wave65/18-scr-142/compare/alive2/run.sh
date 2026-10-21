#!/usr/bin/env bash
# Alive2 pin-vs-model probe for SCR-142 (finding-scoped).
#
# Expected outcomes are stated up front.  A green pair is an equivalence
# proof; a "diff" pair is a machine-checked inequivalence with a raw
# counterexample.  Both are the result: the probe is not a pass/fail gate on
# equivalence, it is a localisation of the historical height term.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$DIR/../../../../../.." && pwd)"
BUILD="$DIR/build"; OUT="$DIR/alive2"
mkdir -p "$OUT"
"$DIR/build.sh"
RES="$OUT/result.txt"
run_pair() {
  local label="$1" src="$2" tgt="$3" expect="$4"
  local body got
  body=$(/usr/local/bin/alive-tv --bidirectional "$BUILD/$src.ll" \
           "$BUILD/$tgt.ll" 2>&1 || true)
  if printf '%s\n' "$body" | grep -q 'These functions seem to be equivalent!' \
     && printf '%s\n' "$body" | grep -q '0 incorrect transformations' \
     && ! printf '%s\n' "$body" | grep -q "Transformation doesn't verify"; then
    got=EQUIV
  elif printf '%s\n' "$body" | grep -q "Transformation doesn't verify" \
       && printf '%s\n' "$body" | grep -Eq '[1-9][0-9]* incorrect transformations' \
       && printf '%s\n' "$body" | grep -q '0 Alive2 errors'; then
    got=DIFF
  else
    got=AMBIGUOUS
  fi
  {
    echo "===== $label ====="
    echo "# command: alive-tv --bidirectional build/$src.ll build/$tgt.ll"
    echo "# src IR sha256: $(sha256sum "$BUILD/$src.ll" | cut -d' ' -f1)"
    echo "# tgt IR sha256: $(sha256sum "$BUILD/$tgt.ll" | cut -d' ' -f1)"
    echo "# expect: $expect   got: $got"
    printf '%s\n' "$body"
    echo
  } >> "$RES"
  [ "$got" = "$expect" ]
}
: > "$RES"
{
  echo "# probe: findings/wave65/18-scr-142/compare"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# scope: pinned cce32b168 slice vs TPR-078 historical model, fixed contexts"
  echo
} >> "$RES"
OK=1
run_pair "A_pin709631_vs_pin709632" v1 v2 EQUIV   || OK=0
run_pair "B_model709631_vs_model709632" v3 v4 DIFF || OK=0
run_pair "C_pin709632_vs_model709632" v2 v4 EQUIV  || OK=0
run_pair "D_pin709631_vs_model709631" v1 v3 DIFF  || OK=0
run_pair "E_pin_exc692261_vs_model_exc692261" v5 v6 EQUIV || OK=0
if [ "$OK" -eq 1 ]; then
  echo "STATUS=probe-as-expected (2 equivalence pairs, 2 inequivalence pairs, 1 exception pair)" >> "$RES"
  echo "RESULT=pin_has_no_height_term; model_has_709632_gate; they_agree_at_709632_and_at_exc692261" >> "$RES"
else
  echo "STATUS=probe-unexpected" >> "$RES"
fi
FILES=("$DIR/README.md" "$DIR/build.sh" "$DIR/compare_common.h"
       "$DIR/variants.cpp" "$DIR/alive2/run.sh" "$DIR/saw/run.sh" "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}" 2>/dev/null || true; done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
