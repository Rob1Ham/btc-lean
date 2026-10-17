#!/usr/bin/env bash
# check_subset_size.sh — in-tree data-subset gate.
#
# Policy (docs/DATA.md):
#   * the tracked data subset must be 2-5 MiB (2,097,152-5,242,880 bytes);
#   * the project does NOT use git-lfs: no tracked file may be an LFS pointer
#     and no tracked .gitattributes may enable `filter=lfs`;
#   * the subset must contain regular files only (no symlinks or gitlinks).
#
# SIZE IS MEASURED FROM THE GIT INDEX, not the working tree. That is the set
# of blobs a fresh clone receives, and it cannot be masked by untracked
# scratch files or by an unstaged deletion.
#
# Usage:
#   check_subset_size.sh [--root PATH] [--min-bytes N] [--max-bytes N]
#
#   --root PATH      tracked data root (default: spec/data). May be a file.
#   --min-bytes N    lower bound, inclusive (default: 2097152 = 2 MiB)
#   --max-bytes N    upper bound, inclusive (default: 5242880 = 5 MiB)
#   -h, --help       show this help
#
# Exit codes: 0 pass, 1 policy violation, 2 usage/environment error.
#
# Dependencies: git, coreutils, awk. No network, no git-lfs.

set -euo pipefail

MIN_BYTES=$((2 * 1024 * 1024))
MAX_BYTES=$((5 * 1024 * 1024))
ROOT="spec/data"

usage() {
  cat <<'EOF'
check_subset_size.sh — in-tree data-subset gate.

Policy (docs/DATA.md):
  * the tracked data subset must be 2-5 MiB (2,097,152-5,242,880 bytes);
  * the project does NOT use git-lfs: no tracked file may be an LFS pointer
    and no tracked .gitattributes may enable `filter=lfs`;
  * the subset must contain regular files only (no symlinks or gitlinks).

SIZE IS MEASURED FROM THE GIT INDEX, not the working tree. That is the set
of blobs a fresh clone receives, and it cannot be masked by untracked
scratch files or by an unstaged deletion.

Usage:
  check_subset_size.sh [--root PATH] [--min-bytes N] [--max-bytes N]

  --root PATH      tracked data root (default: spec/data). May be a file.
  --min-bytes N    lower bound, inclusive (default: 2097152 = 2 MiB)
  --max-bytes N    upper bound, inclusive (default: 5242880 = 5 MiB)
  -h, --help       show this help

Exit codes: 0 pass, 1 policy violation, 2 usage/environment error.

Dependencies: git, coreutils, awk. No network, no git-lfs.
EOF
}

die_usage() {
  echo "check-subset: $*" >&2
  echo "try --help" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      [ "$#" -ge 2 ] || die_usage "--root requires a value"
      ROOT=$2
      shift 2
      ;;
    --min-bytes)
      [ "$#" -ge 2 ] || die_usage "--min-bytes requires a value"
      MIN_BYTES=$2
      shift 2
      ;;
    --max-bytes)
      [ "$#" -ge 2 ] || die_usage "--max-bytes requires a value"
      MAX_BYTES=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die_usage "unknown argument: $1"
      ;;
  esac
done

case "$MIN_BYTES" in
  ''|*[!0-9]*) die_usage "--min-bytes must be a non-negative integer" ;;
esac
case "$MAX_BYTES" in
  ''|*[!0-9]*) die_usage "--max-bytes must be a non-negative integer" ;;
esac
[ "$MIN_BYTES" -le "$MAX_BYTES" ] || die_usage "--min-bytes exceeds --max-bytes"
[ -n "$ROOT" ] || die_usage "--root must not be empty"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "check-subset: not inside a git worktree" >&2
  exit 2
}
cd "$REPO_ROOT"

# Normalize an absolute --root to a repo-relative pathspec and reject paths
# outside the worktree.
case "$ROOT" in
  /*)
    root_abs=$(realpath -m -- "$ROOT")
    case "$root_abs" in
      "$REPO_ROOT"/*) ROOT=${root_abs#"$REPO_ROOT"/} ;;
      "$REPO_ROOT") ROOT="." ;;
      *) die_usage "--root is outside the repository: $ROOT" ;;
    esac
    ;;
esac
ROOT=${ROOT#./}
ROOT=${ROOT%/}
[ -n "$ROOT" ] || ROOT="."

tmp=$(mktemp "${TMPDIR:-/tmp}/p5-subset.XXXXXX")
trap 'rm -f "$tmp" "$tmp.sorted"' EXIT

total=0
count=0
violations=0

echo "check-subset: root=$ROOT"

# Walk the index entries. `git ls-files -s -z` gives:
#   <mode> <object> <stage>\t<path>\0
while IFS= read -r -d '' record; do
  meta=${record%%$'\t'*}
  path=${record#*$'\t'}
  if [ "$meta" = "$record" ]; then
    echo "check-subset: malformed index entry for $path" >&2
    exit 2
  fi

  # shellcheck disable=SC2086
  read -r mode sha stage <<< "$meta"

  if [ "$stage" != "0" ]; then
    echo "VIOLATION: unmerged index entry in data subset: $path (stage $stage)"
    violations=$((violations + 1))
    continue
  fi

  case "$mode" in
    100644|100755) ;;
    120000)
      echo "VIOLATION: symlink in data subset: $path"
      violations=$((violations + 1))
      continue
      ;;
    160000)
      echo "VIOLATION: gitlink/submodule in data subset: $path"
      violations=$((violations + 1))
      continue
      ;;
    *)
      echo "VIOLATION: unsupported index mode $mode in data subset: $path"
      violations=$((violations + 1))
      continue
      ;;
  esac

  size=$(git cat-file -s "$sha") || {
    echo "check-subset: cannot read index blob $sha for $path" >&2
    exit 2
  }
  total=$((total + size))
  count=$((count + 1))
  printf '%s\t%s\n' "$size" "$path" >> "$tmp"
done < <(git ls-files -s -z -- "$ROOT")

if [ "$count" -eq 0 ]; then
  echo "check-subset: ERROR — no tracked files under '$ROOT'" >&2
  exit 2
fi

# git-lfs policy, part 1: no tracked pointer blobs anywhere in the repo.
# `git grep --cached` searches the index, so a staged pointer is caught even
# if the working-tree file was deleted. Verify the first line exactly and
# bound the size so a doc quoting the pointer line is not a false positive.
while IFS= read -r -d '' candidate; do
  size=$(git cat-file -s ":$candidate" 2>/dev/null) || continue
  [ "$size" -lt 1024 ] || continue
  first=$(git cat-file blob ":$candidate" | head -n 1 | tr -d '\r')
  if [ "$first" = "version https://git-lfs.github.com/spec/v1" ]; then
    echo "VIOLATION: tracked Git LFS pointer: $candidate"
    violations=$((violations + 1))
  fi
done < <(git grep --cached -I -l -z -F \
  'version https://git-lfs.github.com/spec/v1' -- . 2>/dev/null || true)

# git-lfs policy, part 2: no LFS filter configuration in any tracked
# .gitattributes, and no tracked .lfsconfig.
while IFS= read -r -d '' tracked; do
  case "$tracked" in
    *.gitattributes)
      if git cat-file blob ":$tracked" |
        grep -Eq '(^|[[:space:]])filter=lfs([[:space:]]|$)'; then
        echo "VIOLATION: tracked .gitattributes enables the LFS filter: $tracked"
        violations=$((violations + 1))
      fi
      ;;
    *.lfsconfig|.lfsconfig)
      echo "VIOLATION: tracked git-lfs configuration file: $tracked"
      violations=$((violations + 1))
      ;;
  esac
done < <(git ls-files -z)

total_mib=$(awk -v b="$total" 'BEGIN { printf "%.2f", b / 1048576 }')
min_mib=$(awk -v b="$MIN_BYTES" 'BEGIN { printf "%.2f", b / 1048576 }')
max_mib=$(awk -v b="$MAX_BYTES" 'BEGIN { printf "%.2f", b / 1048576 }')

echo "check-subset: tracked files=$count bytes=$total (${total_mib} MiB)"
echo "check-subset: allowed ${MIN_BYTES}..${MAX_BYTES} bytes (${min_mib}..${max_mib} MiB)"

if [ "$total" -lt "$MIN_BYTES" ]; then
  echo "VIOLATION: data subset is ${total_mib} MiB, below the ${min_mib} MiB floor"
  violations=$((violations + 1))
elif [ "$total" -gt "$MAX_BYTES" ]; then
  echo "VIOLATION: data subset is ${total_mib} MiB, above the ${max_mib} MiB ceiling"
  violations=$((violations + 1))
fi

echo "check-subset: largest tracked files (index bytes):"
sorted="$tmp.sorted"
sort -rn -k1,1 "$tmp" > "$sorted"
while IFS=$'\t' read -r size path; do
  printf '  %10s  %s\n' "$size" "$path"
done < <(head -n 5 "$sorted")

if [ "$violations" -ne 0 ]; then
  echo "check-subset: FAIL ($violations violation(s))"
  exit 1
fi

echo "check-subset: PASS"
