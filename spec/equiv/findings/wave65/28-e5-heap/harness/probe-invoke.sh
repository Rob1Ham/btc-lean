#!/usr/bin/env bash
# Micro-probe: how does SAW 1.6 treat `invoke` / `landingpad`?
#
# If SAW took the unwind edge, `return == 2` would be reachable.  It is not:
# SAW executes `invoke` as a non-unwinding call.  This is the exact assumption
# that `erase_exceptions.py` encodes as an IR rewrite; dropping the rewrite
# does not remove it (B4 stays open).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="${OUT:-/tmp/opencode/wave65/28-e5-heap-scratch}"
SAW="${SAW:-/opt/equiv-tools/saw-1.6/bin/saw}"
LOGS="$ROOT/logs"
mkdir -p "$OUT" "$LOGS"
cd "$OUT"

cat > probe-invoke.ll <<'EOF'
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"
declare i32 @__gxx_personality_v0(...)
define void @may_throw() { ret void }
define i32 @f() personality ptr @__gxx_personality_v0 {
entry:
  invoke void @may_throw() to label %ok unwind label %lp
ok:
  ret i32 1
lp:
  %l = landingpad { ptr, i32 } cleanup
  ret i32 2
}
EOF
/usr/lib/llvm-20/bin/llvm-as probe-invoke.ll -o probe-invoke.bc

cat > probe-invoke-normal.saw <<'EOF'
m <- llvm_load_module "probe-invoke.bc";
llvm_verify m "f" [] false (do { llvm_execute_func []; llvm_return (llvm_term {{ 1 : [32] }}); }) z3;
print "NORMAL_EDGE_1_PROVED";
EOF
cat > probe-invoke-unwind.saw <<'EOF'
m <- llvm_load_module "probe-invoke.bc";
llvm_verify m "f" [] false (do { llvm_execute_func []; llvm_return (llvm_term {{ 2 : [32] }}); }) z3;
print "UNWIND_EDGE_2_PROVED";
EOF

"$SAW" probe-invoke-normal.saw > "$LOGS/probe-invoke-normal.log" 2>&1
echo "normal-edge(return 1) rc=$? : $(grep -m1 'Proof succeeded\|Proof failed' "$LOGS/probe-invoke-normal.log")"
"$SAW" probe-invoke-unwind.saw > "$LOGS/probe-invoke-unwind.log" 2>&1
echo "unwind-edge(return 2) rc=$? : $(grep -m1 'Proof succeeded\|Proof failed' "$LOGS/probe-invoke-unwind.log")"
