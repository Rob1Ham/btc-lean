#!/usr/bin/env bash
# make_manifest.sh — deterministic sha256 manifest generator.
#
# Output format (one line per regular file, no header, no blank lines):
#
#   <sha256>  <path>
#
# <sha256> is 64 lowercase hex characters; <path> is relative to --root and
# uses '/' separators.  Lines are sorted by path bytes in the C locale.  The
# result is directly consumable by `sha256sum -c`.
#
# Guarantees:
#   * no absolute paths and no path that escapes --root;
#   * missing paths are an error (never silently skipped);
#   * duplicate paths (including overlaps such as DIR and DIR/file) are an
#     error;
#   * symlinks are an error unless --follow-symlinks is given, in which case
#     a symlink that resolves to a regular file is hashed under the link path;
#   * output does not depend on filesystem enumeration order, mtime, locale,
#     inode numbers, or the hash values.
#
# The manifest never lists itself: write it outside the hashed set.
#
# Usage:
#   make_manifest.sh -C DIR PATH...
#   make_manifest.sh -C DIR -o manifest.sha256 spec/vectors spec/db/rules.yaml
#   make_manifest.sh -C spec/vectors -L -- a b c
#
# Exit codes: 0 success; 1 policy/usage/IO error.

set -euo pipefail
export LC_ALL=C

ROOT="."
OUTPUT=""
FOLLOW=0
PATHS=()

usage() {
  cat <<'EOF'
make_manifest.sh — deterministic sha256 manifest generator

Usage:
  make_manifest.sh [options] PATH...

Options:
  -C, --root DIR          paths are interpreted relative to DIR (default: .)
  -o, --output FILE       write the manifest to FILE (default: stdout)
  -L, --follow-symlinks   hash symlinks that resolve to regular files
  -h, --help              show this text

PATH may be a regular file, a symlink (with -L), or a directory.  A directory
is walked without following directory symlinks.  At least one PATH is
required.  The output is sorted by path and contains no comments.
EOF
}

die() { echo "make_manifest: ERROR: $*" >&2; exit 1; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    -C|--root)
      [ "$#" -ge 2 ] || die "$1 requires an argument"
      ROOT="$2"; shift 2 ;;
    --root=*) ROOT="${1#*=}"; shift ;;
    -o|--output)
      [ "$#" -ge 2 ] || die "$1 requires an argument"
      OUTPUT="$2"; shift 2 ;;
    --output=*) OUTPUT="${1#*=}"; shift ;;
    -L|--follow-symlinks) FOLLOW=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do PATHS+=("$1"); shift; done ;;
    -*)
      die "unknown option: $1 (use -- before paths that begin with -)" ;;
    *)
      PATHS+=("$1"); shift ;;
  esac
done

[ "${#PATHS[@]}" -gt 0 ] || die "no paths given (see --help)"
[ -d "$ROOT" ] || die "root is not a directory: $ROOT"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"
command -v realpath  >/dev/null 2>&1 || die "realpath is required"
command -v sort      >/dev/null 2>&1 || die "sort is required"

ROOT_ABS="$(cd "$ROOT" && pwd -P)" || die "cannot resolve root: $ROOT"
TMP="$(mktemp -d "${TMPDIR:-build/scratch}/make-manifest.XXXXXX")" \
  || die "cannot create temporary directory"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT HUP INT TERM

: > "$TMP/entries"

add_entry() { # rel_abs_entry
  local rel="$1" abs="$2"
  case "$rel" in
    ''|/*|..|../*|*/..|*/../*) die "path escapes root: $rel" ;;
  esac
  case "$rel" in
    *$'\n'*|*$'\r'*|*$'\t'*|*\\*) die "unsupported character in path: $rel" ;;
  esac
  printf '%s\t%s\n' "$rel" "$abs" >> "$TMP/entries"
}

add_file() { # absolute path
  local abs="$1" rel
  [ -f "$abs" ] || die "not a regular file: $abs"
  rel="$(realpath -ms --relative-to="$ROOT_ABS" "$abs")" \
    || die "cannot relativize: $abs"
  add_entry "$rel" "$abs"
}

for p in "${PATHS[@]}"; do
  case "$p" in
    ''|/*) die "absolute or empty path not allowed: '$p'" ;;
  esac
  abs="$ROOT_ABS/$p"

  if [ -L "$abs" ]; then
    [ "$FOLLOW" -eq 1 ] || die "symlink not allowed without --follow-symlinks: $p"
    if [ -d "$abs" ]; then
      die "directory symlink not supported; materialize it first: $p"
    fi
    [ -f "$abs" ] || die "broken symlink or non-file target: $p"
    add_file "$abs"
  elif [ -d "$abs" ]; then
    while IFS= read -r -d '' f; do
      add_file "$f"
    done < <(find "$abs" -type f -print0)
    if [ "$FOLLOW" -eq 1 ]; then
      while IFS= read -r -d '' f; do
        if [ -d "$f" ]; then
          die "directory symlink not supported; materialize it first: $f"
        fi
        [ -f "$f" ] || die "broken symlink or non-file target: $f"
        add_file "$f"
      done < <(find "$abs" -type l -print0)
    fi
  elif [ -f "$abs" ]; then
    add_file "$abs"
  elif [ -e "$abs" ]; then
    die "not a regular file or directory: $p"
  else
    die "missing path: $p"
  fi
done

# Duplicate paths are a hard error, including DIR plus DIR/file overlaps.
if [ -s "$TMP/entries" ]; then
  dups="$(cut -f1 "$TMP/entries" | sort | uniq -d)"
  if [ -n "$dups" ]; then
    echo "make_manifest: ERROR: duplicate path(s):" >&2
    printf '%s\n' "$dups" >&2
    exit 1
  fi
else
  die "no regular files matched the requested paths"
fi

# Sort by path (first tab-separated field), then emit <hash>  <path>.
: > "$TMP/manifest"
while IFS=$'\t' read -r rel abs; do
  if ! hash="$(sha256sum -- "$abs" | cut -d' ' -f1)"; then
    die "cannot hash: $abs"
  fi
  case "$hash" in
    [0-9a-f][0-9a-f]*) : ;;
    *) die "unexpected sha256sum output for: $abs" ;;
  esac
  [ "${#hash}" -eq 64 ] || die "unexpected sha256 length for: $abs"
  printf '%s  %s\n' "$hash" "$rel" >> "$TMP/manifest"
done < <(sort -t $'\t' -k1,1 "$TMP/entries")

if [ -n "$OUTPUT" ]; then
  out_dir="$(dirname -- "$OUTPUT")"
  [ -d "$out_dir" ] || die "output directory does not exist: $out_dir"
  tmp_out="$(mktemp "$out_dir/.make-manifest.XXXXXX")" \
    || die "cannot create output temporary in: $out_dir"
  cat "$TMP/manifest" > "$tmp_out"
  mv -f -- "$tmp_out" "$OUTPUT"
else
  cat "$TMP/manifest"
fi
