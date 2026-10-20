#!/bin/sh
# Deterministic IR transform for Alive2 v20 ingestion of Rust/LLVM 20 IR.
#
# Alive2 v20 rejects these Rust-emitted annotations on this artifact:
#   noalias, nocapture, sret([N x i8]), and non-debug metadata.
# It also rejects volatile loads of the Rust allocator-shim guard.
#
# Usage:
#   sanitize_ir.sh in.ll out.ll
#   grep -v 'load volatile i8, ptr @__rust_no_alloc_shim_is_unstable' \
#       out.ll > out.no-volatile.ll
#
# This is a TOOL-SIDE transform, not a source patch. Every cell that uses it
# must record the transform and re-check that the removed annotation was not
# load-bearing. Dropping argument attributes makes a function more general;
# removing the allocator guard is valid only for the single-threaded harness,
# where the volatile result is unused and there is no concurrent allocator
# initialization.
set -eu

in=$1
out=$2

opt -S -strip-debug "$in" -o - \
 | perl -pe 's/,[ \t]*!(alias\.scope|noalias|annotation|tbaa|prof|range|nonnull|noundef|align|invariant\.load|dereferenceable|llvm\.loop) [^,)\n]*//g; s/^\s*![A-Za-z0-9_.]+ = .*\n//g; s/^\s*![0-9]+ = .*\n//g; s/,?[ \t]*metadata !\d+//g; s/ (noalias|nocapture|nonnull|readonly|writeonly|noundef)//g; s/sret\(\[[0-9]+ x i8\]\) //g' \
 | grep -v 'llvm.experimental.noalias.scope.decl' > "$out"
