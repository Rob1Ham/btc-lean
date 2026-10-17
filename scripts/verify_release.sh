#!/usr/bin/env bash
# verify_release.sh -- strict verification of a built data release.
#
# Verification chain:
#   1. optional out-of-band pin of assets.sha256;
#   2. strict grammar/order/coverage checks on assets.sha256;
#   3. transport hashes: assets.sha256 against archive + manifest.sha256;
#   4. strict grammar/order checks on manifest.sha256;
#   5. archive safety checks (regular files only, safe relative names,
#      member set exactly equal to the content manifest);
#   6. extraction into a fresh temporary directory;
#   7. sha256sum -c --strict over every payload file, plus a coverage check
#      that the extracted file set is exactly the manifest path set.
#
# Downloaded files are never executed, sourced, imported, installed, or
# chmodded.  The only operations on the archive are list and extract.
# The temporary extraction directory is removed on exit unless the process
# is killed with SIGKILL.
#
# Usage: scripts/verify_release.sh [options]
# Exit codes: 0 success; 1 input/verification/policy error.

set -euo pipefail

export LC_ALL=C
export TZ=UTC
umask 022

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
RELEASE_DIR="$REPO_ROOT/release"
WORK_BASE="${TMPDIR:-/tmp}"
ASSETS_PIN=""

readonly VERSION="2026.10.17"
readonly ASSET_NAME="btc-lean-data-${VERSION}.tar.gz"
readonly MANIFEST_NAME="manifest.sha256"
readonly ASSETS_NAME="assets.sha256"

usage() {
  cat <<'EOF'
verify_release.sh -- strict btc-lean data release verification

Usage:
  scripts/verify_release.sh [options]

Options:
  --release DIR        directory containing the three release files
                       (default: <repo-root>/release)
  --work-dir DIR       scratch parent for the clean extraction directory
                       (default: $TMPDIR or /tmp)
  --assets-sha256 HEX  required out-of-band SHA-256 pin of assets.sha256
  -h, --help           show this text

Expected files in --release:
  btc-lean-data-2026.10.17.tar.gz
  manifest.sha256
  assets.sha256

Checks performed:
  * assets.sha256 has exactly two entries (archive and manifest.sha256),
    strictly formatted, sorted by path, and hashes match the files;
  * manifest.sha256 is strictly formatted, sorted, unique, and contains no
    absolute paths, dot components, or transport-file self entries;
  * the archive has only regular-file members, no links/devices, safe
    relative names, and a member set exactly equal to manifest.sha256;
  * the gzip header MTIME is zero;
  * extraction into a newly created temporary directory, then
    sha256sum -c --strict and an exact extracted-file-set comparison.

No downloaded file is executed or sourced.  assets.sha256 is verified as a
transport checksum; pass --assets-sha256 to add publisher-side pinning.
EOF
}

die() {
  echo "verify_release: ERROR: $*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --release)
      [ "$#" -ge 2 ] || die "$1 requires an argument"
      RELEASE_DIR="$2"; shift 2 ;;
    --release=*) RELEASE_DIR="${1#*=}"; shift ;;
    --work-dir)
      [ "$#" -ge 2 ] || die "$1 requires an argument"
      WORK_BASE="$2"; shift 2 ;;
    --work-dir=*) WORK_BASE="${1#*=}"; shift ;;
    --assets-sha256)
      [ "$#" -ge 2 ] || die "$1 requires an argument"
      ASSETS_PIN="$2"; shift 2 ;;
    --assets-sha256=*) ASSETS_PIN="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; [ "$#" -eq 0 ] || die "unexpected argument: $1" ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *) die "unexpected argument: $1 (see --help)" ;;
  esac
done

[ -n "$RELEASE_DIR" ] || die "--release must not be empty"
[ -d "$RELEASE_DIR" ] || die "release directory is not a directory: $RELEASE_DIR"
RELEASE_DIR="$(cd "$RELEASE_DIR" && pwd -P)" || die "cannot resolve --release"
[ -n "$WORK_BASE" ] || die "--work-dir must not be empty"

case "$ASSETS_PIN" in
  '') ;;
  *[!0-9a-fA-F]*) die "--assets-sha256 must be 64 hex characters" ;;
  *) [ "${#ASSETS_PIN}" -eq 64 ] || die "--assets-sha256 must be 64 hex characters" ;;
esac

for tool in tar gzip sha256sum find sort mktemp cmp awk od cut; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool not found: $tool"
done

for name in "$ASSET_NAME" "$MANIFEST_NAME" "$ASSETS_NAME"; do
  path="$RELEASE_DIR/$name"
  [ -e "$path" ] || die "missing release file: $path"
  [ ! -L "$path" ] || die "release file is a symlink, refusing: $path"
  [ -f "$path" ] || die "release file is not a regular file: $path"
done

mkdir -p "$WORK_BASE" || die "cannot create work directory: $WORK_BASE"
WORK="$(mktemp -d "$WORK_BASE/btc-release-verify.XXXXXX")" \
  || die "cannot create temporary verification directory under: $WORK_BASE"
cleanup() { rm -rf -- "$WORK"; }
trap cleanup EXIT HUP INT TERM

EXTRACT="$WORK/extract"
mkdir -p "$EXTRACT"

# validate_rel PATH -- same canonical path policy as the builder.
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

# strict_paths FILE LABEL OUT_PATHS
# Validates line grammar, final LF, no CR, and sorted/unique paths; writes
# the path field to OUT_PATHS.  Fails closed on any malformed line.
strict_paths() {
  local file="$1" label="$2" out="$3"
  [ -s "$file" ] || die "$label is empty"
  [ "$(tail -c 1 -- "$file" | od -An -tu1 | tr -d ' \n')" = 10 ] \
    || die "$label does not end with LF"
  if grep -q $'\r' "$file"; then
    die "$label contains CR"
  fi

  awk -v label="$label" '
    BEGIN { ok = 1 }
    {
      if (length($0) < 67) {
        printf "%s line %d: shorter than digest+separator+path\n", label, NR > "/dev/stderr"
        ok = 0; next
      }
      d = substr($0, 1, 64)
      sep = substr($0, 65, 2)
      p = substr($0, 67)
      if (length(d) != 64 || d !~ /^[0-9a-f]+$/) {
        printf "%s line %d: digest is not 64 lowercase hex characters\n", label, NR > "/dev/stderr"
        ok = 0
      }
      if (sep != "  ") {
        printf "%s line %d: separator is not exactly two spaces\n", label, NR > "/dev/stderr"
        ok = 0
      }
      if (p == "") {
        printf "%s line %d: empty path\n", label, NR > "/dev/stderr"
        ok = 0
      }
      if (substr(p, 1, 1) == "/") {
        printf "%s line %d: absolute path\n", label, NR > "/dev/stderr"
        ok = 0
      }
      if (index(p, "\\") || index(p, "\t") || index(p, "\r")) {
        printf "%s line %d: unsupported character in path\n", label, NR > "/dev/stderr"
        ok = 0
      }
      n = split(p, parts, "/")
      for (i = 1; i <= n; i++) {
        if (parts[i] == "." || parts[i] == "..") {
          printf "%s line %d: dot component in path\n", label, NR > "/dev/stderr"
          ok = 0
        }
      }
    }
    END { exit ok ? 0 : 1 }
  ' "$file" || die "$label failed strict grammar validation"

  cut -c 67- "$file" > "$out"
  LC_ALL=C sort -c -u "$out" || die "$label paths are not sorted and unique"
  [ "$(wc -l < "$out")" -eq "$(wc -l < "$file")" ] \
    || die "$label path extraction lost lines"
}

ASSETS_PATH="$RELEASE_DIR/$ASSETS_NAME"
MANIFEST_PATH="$RELEASE_DIR/$MANIFEST_NAME"
ARCHIVE_PATH="$RELEASE_DIR/$ASSET_NAME"

# ---- 1. optional out-of-band pin -----------------------------------------
assets_hash="$(sha256sum -- "$ASSETS_PATH" | cut -d' ' -f1)"
[ "${#assets_hash}" -eq 64 ] || die "unexpected assets.sha256 digest length"
if [ -n "$ASSETS_PIN" ]; then
  pin_lower="$(printf '%s' "$ASSETS_PIN" | tr 'A-F' 'a-f')"
  [ "$assets_hash" = "$pin_lower" ] \
    || die "assets.sha256 does not match --assets-sha256 (got $assets_hash)"
  echo "verify_release: assets.sha256 matches the out-of-band pin"
else
  echo "verify_release: WARNING: assets.sha256 is not pinned out of band; transport trust is HTTPS-only" >&2
fi

# ---- 2. assets.sha256 shape and exact set --------------------------------
ASSETS_PATHS="$WORK/assets.paths"
strict_paths "$ASSETS_PATH" "assets.sha256" "$ASSETS_PATHS"
[ "$(wc -l < "$ASSETS_PATHS")" -eq 2 ] \
  || die "assets.sha256 must list exactly the archive and $MANIFEST_NAME"
printf '%s\n%s\n' "$ASSET_NAME" "$MANIFEST_NAME" | LC_ALL=C sort > "$WORK/assets.expected"
cmp -s -- "$WORK/assets.expected" "$ASSETS_PATHS" \
  || die "assets.sha256 path set is not exactly {archive, $MANIFEST_NAME}"
if grep -Fxq -- "$ASSETS_NAME" "$ASSETS_PATHS"; then
  die "assets.sha256 lists itself"
fi

# ---- 3. transport hashes -------------------------------------------------
if ! ( cd "$RELEASE_DIR" && sha256sum -c --strict "$ASSETS_NAME" ) > "$WORK/assets-check.log" 2>&1; then
  cat "$WORK/assets-check.log" >&2
  die "transport verification against assets.sha256 failed"
fi

archive_hash="$(sha256sum -- "$ARCHIVE_PATH" | cut -d' ' -f1)"
manifest_hash="$(sha256sum -- "$MANIFEST_PATH" | cut -d' ' -f1)"
printf '%s  %s\n' "$archive_hash" "$ASSET_NAME" > "$WORK/asset.actual.archive"
printf '%s  %s\n' "$manifest_hash" "$MANIFEST_NAME" > "$WORK/asset.actual.manifest"
if ! awk '
  {
    want[$2] = $1
  }
  END {
    if (length(want) != 2) exit 1
    if (want["'"$ASSET_NAME"'"] != "'"$archive_hash"'") exit 1
    if (want["'"$MANIFEST_NAME"'"] != "'"$manifest_hash"'") exit 1
  }
' "$ASSETS_PATH"; then
  die "assets.sha256 digests do not match the actual archive/manifest bytes"
fi

# ---- 4. content manifest shape ------------------------------------------
MANIFEST_PATHS="$WORK/manifest.paths"
strict_paths "$MANIFEST_PATH" "manifest.sha256" "$MANIFEST_PATHS"
if grep -Fxq -- "$MANIFEST_NAME" "$MANIFEST_PATHS" \
   || grep -Fxq -- "$ASSETS_NAME" "$MANIFEST_PATHS"; then
  die "content manifest contains a transport-file self entry"
fi
[ "$(wc -l < "$MANIFEST_PATHS")" -gt 0 ] || die "content manifest has no entries"

# ---- 5. archive safety and member coverage ------------------------------
# gzip header MTIME must be zero for the deterministic bundle.
[ "$(od -An -j4 -N4 -tx1 "$ARCHIVE_PATH" | tr -d ' \n')" = "00000000" ] \
  || die "gzip header MTIME is not zero"

if ! tar --quoting-style=literal -tvzf "$ARCHIVE_PATH" \
       | awk 'substr($0,1,1) != "-" { bad=1 } END { exit bad ? 1 : 0 }'; then
  die "archive contains a non-regular member (directory, link, or device)"
fi

tar --quoting-style=literal -tzf "$ARCHIVE_PATH" > "$WORK/archive.members" \
  || die "cannot list archive members"
[ -s "$WORK/archive.members" ] || die "archive has no members"
while IFS= read -r member; do
  validate_rel "$member" || die "unsafe archive member name: $member"
done < "$WORK/archive.members"
LC_ALL=C sort "$WORK/archive.members" -o "$WORK/archive.members.sorted"
[ "$(wc -l < "$WORK/archive.members")" -eq "$(wc -l < "$MANIFEST_PATHS")" ] \
  || die "archive member count does not match manifest.sha256"
cmp -s -- "$WORK/archive.members.sorted" "$MANIFEST_PATHS" \
  || die "archive member set does not match manifest.sha256 exactly"

# ---- 6. clean extraction ------------------------------------------------
if ! tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT" \
       --no-same-owner --no-same-permissions --no-overwrite-dir; then
  die "archive extraction failed"
fi

if find "$EXTRACT" \( -type l -o \( ! -type f ! -type d \) \) -print -quit | grep -q .; then
  die "extracted payload contains a symlink or special file"
fi

# ---- 7. content hashes and exact coverage -------------------------------
if ! ( cd "$EXTRACT" && sha256sum -c --strict "$MANIFEST_PATH" ) > "$WORK/content-check.log" 2>&1; then
  cat "$WORK/content-check.log" >&2
  die "content verification against manifest.sha256 failed"
fi
if grep -q 'FAILED' "$WORK/content-check.log"; then
  cat "$WORK/content-check.log" >&2
  die "content verification reported a failure"
fi

find "$EXTRACT" -type f -printf '%P\0' > "$WORK/extracted.nul" \
  || die "cannot enumerate extracted payload"
LC_ALL=C sort -z "$WORK/extracted.nul" -o "$WORK/extracted.sorted.nul"
tr '\n' '\0' < "$MANIFEST_PATHS" | LC_ALL=C sort -z > "$WORK/manifest.paths.nul"
cmp -s -- "$WORK/extracted.sorted.nul" "$WORK/manifest.paths.nul" \
  || die "extracted file set is not exactly the manifest path set"

extracted_count="$(find "$EXTRACT" -type f -printf '.' | wc -c)"
extracted_bytes="$(find "$EXTRACT" -type f -printf '%s\n' | awk '{ s += $1 } END { printf "%.0f\n", s }')"
archive_bytes="$(stat -c '%s' "$ARCHIVE_PATH")"

printf 'verify_release: release        %s\n' "$RELEASE_DIR"
printf 'verify_release: archive        %s (%s bytes)\n' "$ASSET_NAME" "$archive_bytes"
printf 'verify_release: payload files  %s (%s bytes)\n' "$extracted_count" "$extracted_bytes"
printf 'verify_release: archive sha256 %s\n' "$archive_hash"
printf 'verify_release: manifest sha256 %s\n' "$manifest_hash"
printf 'verify_release: assets sha256  %s\n' "$assets_hash"
printf 'verify_release: all checks passed; no downloaded file was executed\n'
