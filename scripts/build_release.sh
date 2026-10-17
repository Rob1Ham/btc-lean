#!/usr/bin/env bash
# build_release.sh -- deterministic, data-only release builder.
#
# The bundle contains data, not generators or development narrative:
#   * every retained regular file from spec/vectors/ (symlinks dereferenced);
#   * a fixed data metadata allowlist from spec/db/.
#
# Selection is an allowlist of data extensions.  Source, build, log, and
# narrative extensions are rejected even if they sit under cases/ or
# results/.  Any path component .lake, __pycache__, or .git is pruned.
#
# Kept UTF-8 vector text is sanitized for private absolute paths and the
# process vocabulary Agent/agent, fleet, Wave/wave, RECOVERY, and lane.
# Binary and cryptographic data (.raw, .seeds, .parent, .hash, .sha256,
# .hex, .header, .f2c, .want, .core-src) are copied byte-for-byte and are
# never rewritten.  .l2c/.l2r get comment-only sanitization; their data
# lines stay exact.  JSON files whose lane fields/IDs are actual vector data
# are explicitly left unchanged (see JSON_KEEP_VOCAB below).  Every
# METADATA_DATA file is copied byte-for-byte and is never sanitized.
#
# The archive is deterministic: sorted members, mtime=0, uid=gid=0,
# fixed mode 0644, no links or device nodes, and gzip -n (zero MTIME).
#
# This script only reads the repository and vectors tree.  It writes scratch
# files under --work-dir and the three release files under --out.  It never
# executes or sources anything from the corpus, and it does not use git-lfs.
#
# Usage: scripts/build_release.sh [options]
# Exit codes: 0 success; 1 preflight/build/verification error.

set -euo pipefail

export LC_ALL=C
export TZ=UTC
umask 022

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
VECTORS_DIR=""
OUT_DIR="$REPO_ROOT/release"
WORK_BASE="${TMPDIR:-/tmp}"
FORCE=0

readonly VERSION="2026.10.17"
readonly ASSET_NAME="btc-lean-data-${VERSION}.tar.gz"
readonly MANIFEST_NAME="manifest.sha256"
readonly ASSETS_NAME="assets.sha256"

# Data metadata allowlist.  The previous README.md and capstone.md entries are
# deliberately dropped: the new rules exclude narrative .md files.  They are
# still checked for presence and reported as excluded.
METADATA_DATA=(
  spec/db/rules.yaml
  spec/db/rules-wallet.yaml
  spec/db/rules-wallet.lock
  spec/db/rules-wallet.obligations.tsv
  spec/db/axiom-manifest.txt
  spec/db/axiom-manifest-wallet.txt
  spec/db/vector_ids.yaml
)
METADATA_NARRATIVE=(
  spec/db/README.md
  spec/db/capstone.md
)

# Explicitly excluded classes.  .out has no exception: the historical .out
# files are human run summaries, not vector payloads.
EXCLUDED_EXTS=(
  .pyc .log .olean .ilean .c .h .cpp .hpp .py .lean .sh .bat .md .out
  .bak .tmp .swp
)

# Data-only allowlist.  Anything not listed here is excluded rather than
# guessed at; new data formats must be added deliberately.
DATA_EXTS=(
  .json .jsonl .ndjson .csv .tsv .txt .mediawiki
  .raw .seeds .parent .hash .sha256 .l2c .l2r
  .header .hex .want .f2c .core-src .yaml .yml .lock
)

# Byte-for-byte formats.  These are never sanitized.
PRESERVE_EXTS=(
  .raw .seeds .parent .hash .sha256
  .header .hex .want .f2c .core-src
)

# Text formats eligible for sanitization.
SANITIZE_EXTS=(
  .json .jsonl .ndjson .csv .tsv .txt .mediawiki .yaml .yml .lock
)

# Case-semantic case files: sanitize only '#' header comments; data lines
# remain byte-exact.  A private path in a data line is a hard error.
COMMENT_SANITIZE_EXTS=(
  .l2c .l2r
)

# JSON files where "lane" is an actual vector field, ID, or label.  Their
# bytes are not rewritten.  The only one excluded as ambiguous is
# l2/sgn/results/xcheck_sgn.txt (a human result label "0-lane-none").
JSON_KEEP_VOCAB=(
  coretests/CT01/vectors/CT01-cases.json
  l2/fuzz/annex/results/detail.json
  l2/fuzz/annex/results/gen/pyres.json
  l2/replay/cases/F-V12-006/regression.json
)

# JSON files whose process words occur in prose values, not in vector fields.
# Vocabulary sanitization is applied only to these files; .txt and .mediawiki
# prose is sanitized generically.  An unclassified file with process
# vocabulary is a hard error rather than a silent rewrite.
#
# Metadata is deliberately outside this mechanism: every METADATA_DATA file
# is copied byte-for-byte and never passed to sanitize_file.
VOCAB_SANITIZE_FILES=(
  incidents/CV01/cve-2018-17144-dup-input-0value.json
  incidents/CV01/cve-2018-17144-dup-input-inflation.json
  l2/replay/INVENTORY.json
  l2/replay/results/live_diff.json
)
AMBIGUOUS_EXCLUDED=(
  l2/sgn/results/xcheck_sgn.txt
)

usage() {
  cat <<'EOF'
build_release.sh -- deterministic, data-only btc-lean bundle

Usage:
  scripts/build_release.sh [options]

Options:
  --repo-root DIR     candidate tree (default: parent of this script)
  --vectors DIR       complete corpus root (default: <repo-root>/spec/vectors)
  --out DIR           output directory (default: <repo-root>/release)
  --work-dir DIR      scratch directory (default: $TMPDIR or /tmp)
  --force             replace the three output files if they already exist
  -h, --help          show this text

Output set (fixed):
  btc-lean-data-2026.10.17.tar.gz
  manifest.sha256
  assets.sha256

Selection policy:
  * prune any path component .lake, __pycache__, or .git;
  * prefer the sanitized `<repo-root>/spec/data/<rel>` copy when it exists;
  * exclude .pyc .log .olean .ilean .c .h .cpp .hpp .py .lean .sh .bat
    .md .out .bak .tmp .swp (no .out exceptions);
  * keep only the data allowlist .json .jsonl .ndjson .csv .tsv .txt
    .mediawiki .raw .seeds .parent .hash .sha256 .l2c .l2r .header .hex
    .want .f2c .core-src .yaml .yml .lock;
  * metadata data allowlist: rules.yaml, rules-wallet.yaml,
    rules-wallet.lock, rules-wallet.obligations.tsv, axiom-manifest.txt,
    axiom-manifest-wallet.txt, vector_ids.yaml;
  * spec/db/README.md and spec/db/capstone.md are allowlisted narrative
    files but are excluded by the .md rule;
  * l2/sgn/results/xcheck_sgn.txt is excluded as ambiguous (its
    "0-lane-none" label is a result identifier).

Sanitization:
  * private absolute paths are replaced with <checkout> placeholders;
  * whole-word Agent/agent -> tool, fleet -> group, Wave/wave -> stage,
    RECOVERY -> recovery, lane -> path in prose;
  * .l2c/.l2r header comments are sanitized, but every data line is
    byte-exact; a private path in a data line aborts the build;
  * every METADATA_DATA file is copied byte-for-byte and is never sanitized,
    even when it contains technical words such as lane;
  * raw/binary/cryptographic formats are copied byte-for-byte;
  * lane fields/IDs that are actual vector data are retained unchanged.

The manifest covers exactly the payload, uses repository-relative paths,
and is sorted by path bytes.  Output is <sha256> SP SP <path>.  assets.sha256
lists the archive and manifest.sha256, sorted by path, and never itself.

This is a local builder.  It does not commit, push, download, or invoke
git-lfs.  Existing output files are refused unless --force is given.
EOF
}

die() {
  echo "build_release: ERROR: $*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-root)
      [ "$#" -ge 2 ] || die "$1 requires an argument"
      REPO_ROOT="$2"; shift 2 ;;
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --vectors)
      [ "$#" -ge 2 ] || die "$1 requires an argument"
      VECTORS_DIR="$2"; shift 2 ;;
    --vectors=*) VECTORS_DIR="${1#*=}"; shift ;;
    --out)
      [ "$#" -ge 2 ] || die "$1 requires an argument"
      OUT_DIR="$2"; shift 2 ;;
    --out=*) OUT_DIR="${1#*=}"; shift ;;
    --work-dir)
      [ "$#" -ge 2 ] || die "$1 requires an argument"
      WORK_BASE="$2"; shift 2 ;;
    --work-dir=*) WORK_BASE="${1#*=}"; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; [ "$#" -eq 0 ] || die "unexpected argument: $1" ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *) die "unexpected argument: $1 (see --help)" ;;
  esac
done

[ -n "$REPO_ROOT" ] || die "--repo-root must not be empty"
[ -d "$REPO_ROOT" ] || die "repository root is not a directory: $REPO_ROOT"
REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)" || die "cannot resolve --repo-root"
if [ -z "$VECTORS_DIR" ]; then
  VECTORS_DIR="$REPO_ROOT/spec/vectors"
fi
[ -d "$VECTORS_DIR" ] || die "vectors directory is not a directory: $VECTORS_DIR"
VECTORS_DIR="$(cd "$VECTORS_DIR" && pwd -P)" || die "cannot resolve --vectors"
[ -n "$OUT_DIR" ] || die "--out must not be empty"
[ -n "$WORK_BASE" ] || die "--work-dir must not be empty"

for tool in tar gzip sha256sum find sort mktemp realpath cmp awk od cut sed grep iconv; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool not found: $tool"
done
tar --version 2>/dev/null | grep -q 'GNU tar' \
  || die "GNU tar is required for deterministic --mtime/--owner options"
gzip --help 2>&1 | grep -q -- '-n' \
  || die "gzip does not advertise -n; refusing non-deterministic gzip"
sed --version 2>/dev/null | grep -q 'GNU sed' \
  || die "GNU sed is required for deterministic sanitization"

MAKE_MANIFEST="$REPO_ROOT/scripts/make_manifest.sh"
[ -f "$MAKE_MANIFEST" ] || die "reference generator missing: $MAKE_MANIFEST"

# Validate the data metadata allowlist before touching the output directory.
for rel in "${METADATA_DATA[@]}"; do
  src="$REPO_ROOT/$rel"
  [ -f "$src" ] || die "required metadata file missing or not a regular file: $rel"
done

# Refuse to clobber existing release files unless explicitly forced.
if [ "$FORCE" -ne 1 ]; then
  for name in "$ASSET_NAME" "$MANIFEST_NAME" "$ASSETS_NAME"; do
    if [ -e "$OUT_DIR/$name" ] || [ -L "$OUT_DIR/$name" ]; then
      die "output already exists (use --force to replace): $OUT_DIR/$name"
    fi
  done
fi

mkdir -p "$WORK_BASE" || die "cannot create work directory: $WORK_BASE"
WORK="$(mktemp -d "$WORK_BASE/btc-release-build.XXXXXX")" \
  || die "cannot create temporary build directory under: $WORK_BASE"
cleanup() { rm -rf -- "$WORK"; }
trap cleanup EXIT HUP INT TERM

STAGE="$WORK/stage"
OUT_TMP="$WORK/out"
mkdir -p "$STAGE/spec/vectors" "$STAGE/spec/db" "$OUT_TMP" "$WORK/tmp"
export TMPDIR="$WORK/tmp"

# ---- classification helpers ---------------------------------------------
extension_of() {
  local base="${1##*/}"
  case "$base" in
    *.*) printf '%s' ".${base##*.}" | tr '[:upper:]' '[:lower:]' ;;
    *) printf '%s' '' ;;
  esac
}

in_list() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [ "$needle" = "$item" ] && return 0
  done
  return 1
}

is_excluded_ext() { in_list "$1" "${EXCLUDED_EXTS[@]}"; }
is_data_ext()     { in_list "$1" "${DATA_EXTS[@]}"; }
is_preserve_ext() { in_list "$1" "${PRESERVE_EXTS[@]}"; }
is_sanitize_ext() { in_list "$1" "${SANITIZE_EXTS[@]}"; }

is_component_excluded() {
  case "/$1/" in
    */.lake/*|*/__pycache__/*|*/.git/*) return 0 ;;
  esac
  return 1
}

is_ambiguous_excluded() { in_list "$1" "${AMBIGUOUS_EXCLUDED[@]}"; }

json_keeps_vocab() { in_list "$1" "${JSON_KEEP_VOCAB[@]}"; }

# validate_rel PATH -- reject anything that cannot be a canonical manifest path.
validate_rel() {
  local p="$1"
  case "$p" in
    ''|/*) return 1 ;;
    *\\*|*$'\n'*|*$'\r'*|*$'\t'*) return 1 ;;
  esac
  case "/$p/" in
    */../*|*/./*) return 1 ;;
  esac
  return 0
}

# ---- sanitization -------------------------------------------------------
SANITIZED_COUNT=0
SANITIZED_LIST=()
COMMENT_SANITIZED_LIST=()
LANE_RETAINED=()
NARRATIVE_EXCLUDED_LIST=()
AMBIGUOUS_EXCLUDED_LIST=()

sanitize_comment_file() { # dest rel
  local file="$1" rel="$2"
  LC_ALL=C grep -Iq . "$file" || return 0

  # Only '#' prose lines may change.  A private path in a data line cannot
  # be rewritten without altering case semantics, so fail closed.
  if awk '!/^#/ && /(\/home\/|\/tmp\/)/ { found=1 } END { exit found ? 0 : 1 }' "$file"; then
    die "private absolute path outside comments in case-semantic data: $rel"
  fi

  local path_hit=0 vocab_hit=0
  if LC_ALL=C grep -Eq '^#.*/(home|tmp)/' "$file"; then
    path_hit=1
  fi
  if LC_ALL=C grep -Eq '^#.*(\b(Agent|agent|fleet|Wave|wave|RECOVERY|lane)\b)' "$file"; then
    vocab_hit=1
  fi
  if [ "$path_hit" -eq 0 ] && [ "$vocab_hit" -eq 0 ]; then
    return 0
  fi

  local args=()
  if [ "$path_hit" -eq 1 ]; then
    args+=(
      -e '/^#/ s#/home/[^/[:space:]]+/btc-lean#<checkout>#g'
      -e '/^#/ s#/tmp/[^/[:space:]]+/btc-lean#<checkout>#g'
      -e '/^#/ s#/tmp/[^/[:space:]]+/#<checkout>/#g'
      -e '/^#/ s#/home/[^/[:space:]]+/#<checkout>/#g'
      -e '/^#/ s#(^|[^A-Za-z0-9_])/tmp/#\1<checkout>/#g'
      -e '/^#/ s#(^|[^A-Za-z0-9_])/home/#\1<checkout>/#g'
    )
  fi
  if [ "$vocab_hit" -eq 1 ]; then
    args+=(
      -e '/^#/ s/\bAgent\b/tool/g'
      -e '/^#/ s/\bagent\b/tool/g'
      -e '/^#/ s/\bfleet\b/group/g'
      -e '/^#/ s/\bWave\b/stage/g'
      -e '/^#/ s/\bwave\b/stage/g'
      -e '/^#/ s/\bRECOVERY\b/recovery/g'
      -e '/^#/ s/\blane\b/path/g'
    )
  fi
  [ "${#args[@]}" -gt 0 ] || return 0

  local tmp="$WORK/sanitize-comment.tmp"
  if ! LC_ALL=C sed -E "${args[@]}" -- "$file" > "$tmp"; then
    rm -f -- "$tmp"
    die "comment sanitization failed: $rel"
  fi
  if ! iconv -f UTF-8 -t UTF-8 < "$tmp" > /dev/null 2>&1; then
    rm -f -- "$tmp"
    die "comment sanitization produced invalid UTF-8: $rel"
  fi
  if cmp -s -- "$file" "$tmp"; then
    rm -f -- "$tmp"
    return 0
  fi
  mv -f -- "$tmp" "$file"
  chmod 0644 -- "$file"
  SANITIZED_COUNT=$((SANITIZED_COUNT + 1))
  SANITIZED_LIST+=("$rel")
  COMMENT_SANITIZED_LIST+=("$rel")
}

sanitize_file() { # dest rel ext
  local file="$1" rel="$2" ext="$3"
  if in_list "$ext" "${COMMENT_SANITIZE_EXTS[@]}"; then
    sanitize_comment_file "$file" "$rel"
    return 0
  fi
  is_sanitize_ext "$ext" || return 0
  # Only UTF-8 text: grep -I refuses binary data.  Empty files are untouched.
  if ! LC_ALL=C grep -Iq . "$file"; then
    return 0
  fi

  local path_hit=0 vocab_hit=0
  if LC_ALL=C grep -Eq '/(home|tmp)/' "$file"; then
    path_hit=1
  fi
  if LC_ALL=C grep -Eqw 'Agent|agent|fleet|Wave|wave|RECOVERY|lane' "$file"; then
    vocab_hit=1
  fi
  if [ "$path_hit" -eq 0 ] && [ "$vocab_hit" -eq 0 ]; then
    return 0
  fi

  local vocab_allowed=0
  case "$ext" in
    .txt|.mediawiki) vocab_allowed=1 ;;
  esac
  if in_list "$rel" "${VOCAB_SANITIZE_FILES[@]}"; then
    vocab_allowed=1
  fi
  if [ "$vocab_hit" -eq 1 ] && [ "$vocab_allowed" -eq 0 ]; then
    if [ "$ext" = ".json" ] && json_keeps_vocab "$rel"; then
      LANE_RETAINED+=("$rel")
    else
      die "process vocabulary in unclassified file; classify it or exclude it: $rel"
    fi
  fi

  local args=()
  if [ "$path_hit" -eq 1 ]; then
    args+=(
      -e 's#/home/[^/[:space:]]+/btc-lean#<checkout>#g'
      -e 's#/tmp/[^/[:space:]]+/btc-lean#<checkout>#g'
      -e 's#/tmp/[^/[:space:]]+/#<checkout>/#g'
      -e 's#/home/[^/[:space:]]+/#<checkout>/#g'
      -e 's#(^|[^A-Za-z0-9_])/tmp/#\1<checkout>/#g'
      -e 's#(^|[^A-Za-z0-9_])/home/#\1<checkout>/#g'
    )
  fi
  if [ "$vocab_hit" -eq 1 ] && [ "$vocab_allowed" -eq 1 ]; then
    args+=(
      -e 's/\bAgent\b/tool/g'
      -e 's/\bagent\b/tool/g'
      -e 's/\bfleet\b/group/g'
      -e 's/\bWave\b/stage/g'
      -e 's/\bwave\b/stage/g'
      -e 's/\bRECOVERY\b/recovery/g'
      -e 's/\blane\b/path/g'
    )
  fi
  [ "${#args[@]}" -gt 0 ] || return 0

  local tmp="$WORK/sanitize.tmp"
  if ! LC_ALL=C sed -E "${args[@]}" -- "$file" > "$tmp"; then
    rm -f -- "$tmp"
    die "sanitization failed: $rel"
  fi
  if ! iconv -f UTF-8 -t UTF-8 < "$tmp" > /dev/null 2>&1; then
    rm -f -- "$tmp"
    die "sanitization produced invalid UTF-8: $rel"
  fi
  if cmp -s -- "$file" "$tmp"; then
    rm -f -- "$tmp"
    return 0
  fi
  mv -f -- "$tmp" "$file"
  chmod 0644 -- "$file"
  SANITIZED_COUNT=$((SANITIZED_COUNT + 1))
  SANITIZED_LIST+=("$rel")
}

# ---- 1. materialize the vectors payload ----------------------------------
EXPECTED="$WORK/expected.nul"
: > "$EXPECTED"

ALL_ENTRIES="$(find "$VECTORS_DIR" \( -type f -o -type l \) -printf '.' | wc -c)"
VECTOR_LIST_RAW="$WORK/vector-files.raw.nul"
VECTOR_LIST="$WORK/vector-files.sorted.nul"

# Prune any component exactly named .lake, __pycache__, or .git.
find "$VECTORS_DIR" \
     \( -type d \( -name .lake -o -name __pycache__ -o -name .git \) -prune \) -o \
     \( \( -type f -o -type l \) -print0 \) \
     > "$VECTOR_LIST_RAW" \
  || die "cannot enumerate vectors directory: $VECTORS_DIR"
POST_COMPONENT_ENTRIES="$(find "$VECTORS_DIR" \
  \( -type d \( -name .lake -o -name __pycache__ -o -name .git \) -prune \) -o \
  \( \( -type f -o -type l \) -printf '.' \) | wc -c)"
COMPONENT_EXCLUDED=$((ALL_ENTRIES - POST_COMPONENT_ENTRIES))
[ -s "$VECTOR_LIST_RAW" ] || die "vectors directory contains no files: $VECTORS_DIR"
LC_ALL=C sort -z "$VECTOR_LIST_RAW" -o "$VECTOR_LIST" \
  || die "cannot sort vectors file list"

declare -A EXCL_EXT=()
declare -A EXCL_NONDATA=()
declare -A KEPT_BY_EXT=()
vector_count=0
TRACKED_SOURCE_COUNT=0
NARRATIVE_EXCLUDED_COUNT=0

while IFS= read -r -d '' src; do
  case "$src" in
    "$VECTORS_DIR"/*) rel="${src#"$VECTORS_DIR"/}" ;;
    *) die "source path escaped --vectors: $src" ;;
  esac
  validate_rel "$rel" || die "unsupported path characters or components: $rel"
  if is_component_excluded "$rel"; then
    die "internal component survived pruning: $rel"
  fi
  # Exclude human run logs/provenance that are not vector payload.
  case "$rel" in
    anchors2/V15/PROVENANCE.txt|anchors3/V2-02/run/RUNTREE.gitstate.txt|anchors3/V2-02/run/RUNTREE.txt)
      NARRATIVE_EXCLUDED_COUNT=$((NARRATIVE_EXCLUDED_COUNT + 1))
      continue ;;
  esac
  # Prefer the sanitized in-tree subset when it contains the same path.
  # This keeps release data consistent with spec/data and avoids
  # reintroducing prose that was sanitized in the tracked subset.
  if [ "$rel" != "MANIFEST.sha256" ] && [ -f "$REPO_ROOT/spec/data/$rel" ]; then
    src="$REPO_ROOT/spec/data/$rel"
    TRACKED_SOURCE_COUNT=$((TRACKED_SOURCE_COUNT + 1))
  fi

  ext="$(extension_of "$rel")"
  if is_ambiguous_excluded "$rel"; then
    AMBIGUOUS_EXCLUDED_LIST+=("$rel")
    continue
  fi
  if is_excluded_ext "$ext"; then
    EXCL_EXT["$ext"]=$(( ${EXCL_EXT["$ext"]:-0} + 1 ))
    continue
  fi
  if ! is_data_ext "$ext"; then
    key="$ext"
    [ -n "$key" ] || key="(none)"
    EXCL_NONDATA["$key"]=$(( ${EXCL_NONDATA["$key"]:-0} + 1 ))
    continue
  fi

  if [ -L "$src" ] && [ -d "$src" ]; then
    die "directory symlink cannot be materialized as a regular file: $rel"
  fi
  [ -f "$src" ] || die "broken symlink or non-regular file: $rel"

  dest="$STAGE/spec/vectors/$rel"
  mkdir -p -- "$(dirname -- "$dest")" || die "cannot create directory for: $rel"
  cp -L -- "$src" "$dest" || die "cannot dereference/copy: $rel"
  chmod 0644 -- "$dest" || die "cannot normalize mode: $rel"

  if is_preserve_ext "$ext"; then
    if LC_ALL=C grep -aqE '/(home|tmp)/' "$dest"; then
      die "private absolute path in preserved data file, refusing to rewrite: $rel"
    fi
  else
    sanitize_file "$dest" "$rel" "$ext"
  fi

  printf '%s\0' "spec/vectors/$rel" >> "$EXPECTED"
  KEPT_BY_EXT["$ext"]=$(( ${KEPT_BY_EXT["$ext"]:-0} + 1 ))
  vector_count=$((vector_count + 1))
done < "$VECTOR_LIST"
[ "$vector_count" -gt 0 ] || die "no vector payload files selected"

# ---- 2. copy data metadata; report dropped narrative metadata ------------
meta_count=0
for rel in "${METADATA_DATA[@]}"; do
  src="$REPO_ROOT/$rel"
  ext="$(extension_of "$rel")"
  is_data_ext "$ext" || die "metadata is not a data extension: $rel"
  dest="$STAGE/$rel"
  mkdir -p -- "$(dirname -- "$dest")" || die "cannot create metadata directory: $rel"
  cp -L -- "$src" "$dest" || die "cannot copy metadata: $rel"
  cmp -s -- "$src" "$dest" \
    || die "metadata copy is not byte-identical to candidate: $rel"
  chmod 0644 -- "$dest" || die "cannot normalize metadata mode: $rel"
  printf '%s\0' "$rel" >> "$EXPECTED"
  KEPT_BY_EXT["$ext"]=$(( ${KEPT_BY_EXT["$ext"]:-0} + 1 ))
  meta_count=$((meta_count + 1))
done

for rel in "${METADATA_NARRATIVE[@]}"; do
  if [ -e "$REPO_ROOT/$rel" ] || [ -L "$REPO_ROOT/$rel" ]; then
    NARRATIVE_EXCLUDED_LIST+=("$rel")
  fi
done

EXPECTED_SORTED="$WORK/expected.sorted.nul"
EXPECTED_UNIQUE="$WORK/expected.unique.nul"
LC_ALL=C sort -z "$EXPECTED" -o "$EXPECTED_SORTED"
LC_ALL=C sort -z -u "$EXPECTED" -o "$EXPECTED_UNIQUE"
cmp -s -- "$EXPECTED_SORTED" "$EXPECTED_UNIQUE" \
  || die "duplicate payload path selected"

ACTUAL="$WORK/actual.nul"
find "$STAGE" -type f -printf '%P\0' > "$ACTUAL" \
  || die "cannot enumerate staged payload"
LC_ALL=C sort -z "$ACTUAL" -o "$ACTUAL"
cmp -s -- "$EXPECTED_SORTED" "$ACTUAL" \
  || die "staged payload does not match the selected path set"

# Staging must contain only regular files; links were dereferenced.
if find "$STAGE" \( -type l -o \( ! -type f ! -type d \) \) -print -quit | grep -q .; then
  die "staged payload contains a symlink or special file"
fi

PAYLOAD_COUNT="$(find "$STAGE" -type f -printf '.' | wc -c)"
[ "$PAYLOAD_COUNT" -eq $((vector_count + meta_count)) ] \
  || die "payload file count mismatch"

# ---- 3. content manifest over exactly the payload ------------------------
MANIFEST_TMP="$OUT_TMP/$MANIFEST_NAME"
manifest_args=(spec/vectors)
for rel in "${METADATA_DATA[@]}"; do
  manifest_args+=("$rel")
done
bash "$MAKE_MANIFEST" -C "$STAGE" -L -o "$MANIFEST_TMP" -- "${manifest_args[@]}" \
  || die "content manifest generation failed"

[ -s "$MANIFEST_TMP" ] || die "content manifest is empty"
[ "$(tail -c 1 -- "$MANIFEST_TMP" | od -An -tu1 | tr -d ' \n')" = 10 ] \
  || die "content manifest does not end with LF"
if grep -q $'\r' "$MANIFEST_TMP"; then
  die "content manifest contains CR"
fi

# Strict grammar, relative paths, no dot components, no control characters.
awk '
  BEGIN { ok = 1 }
  {
    if (length($0) < 67) {
      printf "line %d: shorter than digest+separator+path\n", NR > "/dev/stderr"; ok = 0; next
    }
    d = substr($0, 1, 64)
    sep = substr($0, 65, 2)
    p = substr($0, 67)
    if (length(d) != 64 || d !~ /^[0-9a-f]+$/) {
      printf "line %d: digest is not 64 lowercase hex characters\n", NR > "/dev/stderr"; ok = 0
    }
    if (sep != "  ") {
      printf "line %d: separator is not exactly two spaces\n", NR > "/dev/stderr"; ok = 0
    }
    if (p == "") {
      printf "line %d: empty path\n", NR > "/dev/stderr"; ok = 0
    }
    if (substr(p, 1, 1) == "/") {
      printf "line %d: absolute path\n", NR > "/dev/stderr"; ok = 0
    }
    if (index(p, "\\") || index(p, "\t") || index(p, "\r")) {
      printf "line %d: unsupported character in path\n", NR > "/dev/stderr"; ok = 0
    }
    n = split(p, parts, "/")
    for (i = 1; i <= n; i++) {
      if (parts[i] == "." || parts[i] == "..") {
        printf "line %d: dot component in path\n", NR > "/dev/stderr"; ok = 0
      }
    }
  }
  END { exit ok ? 0 : 1 }
' "$MANIFEST_TMP" || die "content manifest failed strict grammar validation"

MANIFEST_PATHS="$WORK/manifest.paths"
cut -c 67- "$MANIFEST_TMP" > "$MANIFEST_PATHS"
LC_ALL=C sort -c -u "$MANIFEST_PATHS" \
  || die "content manifest paths are not sorted and unique"
[ "$(wc -l < "$MANIFEST_PATHS")" -eq "$PAYLOAD_COUNT" ] \
  || die "content manifest line count does not match payload file count"
tr '\0' '\n' < "$EXPECTED_SORTED" > "$WORK/expected.paths"
cmp -s -- "$WORK/expected.paths" "$MANIFEST_PATHS" \
  || die "content manifest does not cover exactly the selected payload"

if ! ( cd "$STAGE" && sha256sum -c --strict "$MANIFEST_TMP" ) > "$WORK/manifest-check.log" 2>&1; then
  cat "$WORK/manifest-check.log" >&2
  die "payload does not verify against the generated manifest"
fi

# ---- 4. deterministic archive -------------------------------------------
ARCHIVE_TMP="$OUT_TMP/$ASSET_NAME"
tar -C "$STAGE" \
    --create --format=gnu --mtime=@0 \
    --owner=0 --group=0 --numeric-owner --mode=0644 \
    --no-recursion --null --files-from="$EXPECTED_SORTED" \
    --file=- \
  | gzip -n > "$ARCHIVE_TMP" \
  || die "archive creation or gzip failed"

[ -s "$ARCHIVE_TMP" ] || die "archive is empty"

# gzip MTIME field is bytes 4..7 of the header and must be zero.
[ "$(od -An -j4 -N4 -tx1 "$ARCHIVE_TMP" | tr -d ' \n')" = "00000000" ] \
  || die "gzip header MTIME is not zero"

# No directory/link/device members: every verbose member line starts with '-'.
if ! tar --quoting-style=literal -tvzf "$ARCHIVE_TMP" \
       | awk 'substr($0,1,1) != "-" { bad=1 } END { exit bad ? 1 : 0 }'; then
  die "archive contains a non-regular member"
fi

tar --quoting-style=literal -tzf "$ARCHIVE_TMP" > "$WORK/archive.members" \
  || die "cannot list archive members"
LC_ALL=C sort "$WORK/archive.members" -o "$WORK/archive.members.sorted"
cmp -s -- "$WORK/archive.members.sorted" "$MANIFEST_PATHS" \
  || die "archive members do not match the content manifest exactly"

# ---- 5. transport manifest over exactly archive + manifest --------------
archive_hash="$(sha256sum -- "$ARCHIVE_TMP" | cut -d' ' -f1)"
manifest_hash="$(sha256sum -- "$MANIFEST_TMP" | cut -d' ' -f1)"
case "$archive_hash" in
  [0-9a-f][0-9a-f]*) : ;;
  *) die "unexpected archive digest output" ;;
esac
[ "${#archive_hash}" -eq 64 ] || die "unexpected archive digest length"
[ "${#manifest_hash}" -eq 64 ] || die "unexpected manifest digest length"

RECORDS="$WORK/assets.records"
{
  printf '%s\t%s\n' "$archive_hash" "$ASSET_NAME"
  printf '%s\t%s\n' "$manifest_hash" "$MANIFEST_NAME"
} > "$RECORDS"
LC_ALL=C sort -t $'\t' -k2,2 "$RECORDS" -o "$RECORDS.sorted"
while IFS=$'\t' read -r h p; do
  printf '%s  %s\n' "$h" "$p"
done < "$RECORDS.sorted" > "$OUT_TMP/$ASSETS_NAME"

# ---- 6. publish atomically-ish, assets.sha256 last ----------------------
mkdir -p -- "$OUT_DIR" || die "cannot create output directory: $OUT_DIR"
if [ "$FORCE" -ne 1 ]; then
  for name in "$ASSET_NAME" "$MANIFEST_NAME" "$ASSETS_NAME"; do
    if [ -e "$OUT_DIR/$name" ] || [ -L "$OUT_DIR/$name" ]; then
      die "output appeared during build (use --force to replace): $OUT_DIR/$name"
    fi
  done
fi
mv -f -- "$ARCHIVE_TMP" "$OUT_DIR/$ASSET_NAME" || die "cannot publish archive"
mv -f -- "$MANIFEST_TMP" "$OUT_DIR/$MANIFEST_NAME" || die "cannot publish manifest"
mv -f -- "$OUT_TMP/$ASSETS_NAME" "$OUT_DIR/$ASSETS_NAME" || die "cannot publish assets"

archive_bytes="$(stat -c '%s' "$OUT_DIR/$ASSET_NAME")"
manifest_bytes="$(stat -c '%s' "$OUT_DIR/$MANIFEST_NAME")"
assets_bytes="$(stat -c '%s' "$OUT_DIR/$ASSETS_NAME")"

printf 'build_release: version        %s\n' "$VERSION"
printf 'build_release: vectors        %s\n' "$VECTORS_DIR"
printf 'build_release: payload files  %s (%s vectors, %s metadata)\n' \
  "$PAYLOAD_COUNT" "$vector_count" "$meta_count"
printf 'build_release: tracked-subset source files %s\n' "$TRACKED_SOURCE_COUNT"
printf 'build_release: excluded narrative logs %s\n' "$NARRATIVE_EXCLUDED_COUNT"
printf 'build_release: metadata byte-identical %s/%s (copied, never sanitized)\n' \
  "$meta_count" "${#METADATA_DATA[@]}"
for rel in "${METADATA_DATA[@]}"; do
  printf '  %s\n' "$rel"
done
printf 'build_release: component-excluded files %s (.lake/__pycache__/.git)\n' \
  "$COMPONENT_EXCLUDED"
printf 'build_release: extension-excluded files %s\n' \
  "$(for e in "${!EXCL_EXT[@]}"; do printf '%s\n' "${EXCL_EXT[$e]}"; done | awk '{s+=$1} END{printf "%d", s+0}')"
if [ "${#EXCL_EXT[@]}" -gt 0 ]; then
  for ext in $(printf '%s\n' "${!EXCL_EXT[@]}" | LC_ALL=C sort); do
    printf '  %-10s %s\n' "$ext" "${EXCL_EXT[$ext]}"
  done
fi
printf 'build_release: non-data-excluded files %s\n' \
  "$(for e in "${!EXCL_NONDATA[@]}"; do printf '%s\n' "${EXCL_NONDATA[$e]}"; done | awk '{s+=$1} END{printf "%d", s+0}')"
if [ "${#EXCL_NONDATA[@]}" -gt 0 ]; then
  for ext in $(printf '%s\n' "${!EXCL_NONDATA[@]}" | LC_ALL=C sort); do
    printf '  %-10s %s\n' "$ext" "${EXCL_NONDATA[$ext]}"
  done
fi
printf 'build_release: ambiguous-excluded files %s\n' "${#AMBIGUOUS_EXCLUDED_LIST[@]}"
for rel in "${AMBIGUOUS_EXCLUDED_LIST[@]}"; do
  printf '  %s\n' "$rel"
done
printf 'build_release: narrative-metadata-excluded files %s\n' "${#NARRATIVE_EXCLUDED_LIST[@]}"
for rel in "${NARRATIVE_EXCLUDED_LIST[@]}"; do
  printf '  %s\n' "$rel"
done
printf 'build_release: kept by extension\n'
for ext in $(printf '%s\n' "${!KEPT_BY_EXT[@]}" | LC_ALL=C sort); do
  printf '  %-10s %s\n' "$ext" "${KEPT_BY_EXT[$ext]}"
done
printf 'build_release: sanitized files %s\n' "$SANITIZED_COUNT"
if [ "${#SANITIZED_LIST[@]}" -gt 0 ]; then
  while IFS= read -r rel; do
    printf '  %s\n' "$rel"
  done < <(printf '%s\n' "${SANITIZED_LIST[@]}" | LC_ALL=C sort)
fi
printf 'build_release: comment-only sanitized files %s\n' "${#COMMENT_SANITIZED_LIST[@]}"
if [ "${#COMMENT_SANITIZED_LIST[@]}" -gt 0 ]; then
  while IFS= read -r rel; do
    printf '  %s\n' "$rel"
  done < <(printf '%s\n' "${COMMENT_SANITIZED_LIST[@]}" | LC_ALL=C sort)
fi
printf 'build_release: lane-retained-as-vector-data files %s\n' "${#LANE_RETAINED[@]}"
if [ "${#LANE_RETAINED[@]}" -gt 0 ]; then
  while IFS= read -r rel; do
    printf '  %s\n' "$rel"
  done < <(printf '%s\n' "${LANE_RETAINED[@]}" | LC_ALL=C sort)
fi
printf 'build_release: archive        %s (%s bytes)\n' "$OUT_DIR/$ASSET_NAME" "$archive_bytes"
printf 'build_release: manifest       %s (%s bytes, %s lines)\n' \
  "$OUT_DIR/$MANIFEST_NAME" "$manifest_bytes" "$PAYLOAD_COUNT"
printf 'build_release: assets         %s (%s bytes)\n' "$OUT_DIR/$ASSETS_NAME" "$assets_bytes"
printf 'build_release: archive sha256 %s\n' "$archive_hash"
printf 'build_release: manifest sha256 %s\n' "$manifest_hash"
printf 'build_release: assets sha256  %s\n' \
  "$(sha256sum -- "$OUT_DIR/$ASSETS_NAME" | cut -d' ' -f1)"
