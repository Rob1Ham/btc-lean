#!/usr/bin/env bash
# Run the wave65/28 SAW obligations and assert the expected outcome of each.
# Logs go to ../logs/<spec>.log.  Exit status is nonzero if any expectation is
# not met (a timeout is never counted as a proof).
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SAW="${SAW:-/opt/equiv-tools/saw-1.6/bin/saw}"
OUT="${OUT:-/tmp/opencode/wave65/28-e5-heap-scratch}"
LOGS="$ROOT/logs"
mkdir -p "$LOGS"
fail=0

run() { # spec expected
  local spec="$1"
  local expected="$2"
  local log="$LOGS/$(basename "$spec" .saw).log"
  timeout 1800 "$SAW" "$ROOT/specs/$spec" > "$log" 2>&1
  local rc=$?
  local ok
  case "$expected" in
    proved)   grep -q 'Proof succeeded' "$log" && [ $rc -eq 0 ] && ok=1 || ok=0 ;;
    failed)   grep -q 'Proof failed' "$log" && ok=1 || ok=0 ;;
    throw)    grep -q 'Failed to load function handle: _ZSt17__throw_bad_allocv' "$log" && ok=1 || ok=0 ;;
    *) echo "bad expectation $expected" >&2; ok=0 ;;
  esac
  printf '%-48s expect=%-7s rc=%d %s\n' "$spec" "$expected" "$rc" "$([ $ok -eq 1 ] && echo PASS || echo FAIL)"
  [ $ok -eq 1 ] || fail=1
}

run singletu-op1.saw                        proved
run singletu-op1add.saw                     proved
run singletu-op1sub.saw                     proved
run closure-op1add.saw                      proved
run closure-op1sub.saw                      proved
run closure-op1add-cap66.saw                proved
run neg-singletu-op1sub-expect-true.saw     failed
run neg-closure-pinned-op1sub-expect-false.saw failed
run neg-closure-op1add-cap65.saw            throw
run pinned-singletu-op1sub.saw              proved
run pinned-closure-op1sub.saw               proved

{
  echo "spec,expected,result"
  echo "see stdout above (regenerate with run-all.sh)"
} > /dev/null
echo
if [ $fail -eq 0 ]; then echo "ALL EXPECTATIONS MET"; else echo "SOME EXPECTATIONS FAILED"; fi
exit $fail
