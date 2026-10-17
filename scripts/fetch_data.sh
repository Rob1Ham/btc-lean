#!/usr/bin/env bash
# fetch_data.sh — download and verify a published data release.
#
# This script ONLY downloads, hashes, and (optionally) extracts an archive.
# It never executes, sources, imports, or installs any downloaded file.
#
# Release layout expected under <base-url>/<release-tag>/:
#
#   assets.sha256                  transport manifest (archive + manifest.sha256)
#   manifest.sha256                content manifest (every payload file)
#   btc-lean-data-<version>.tar.gz full data bundle
#
# Verification chain:
#   1. assets.sha256 is verified against an out-of-band SHA-256 pin when
#      --assets-sha256 is supplied; otherwise HTTPS is the only trust anchor
#      and the script prints a warning.
#   2. manifest.sha256 and the archive are verified against assets.sha256.
#   3. With --extract DIR, the archive is unpacked and every file is checked
#      against manifest.sha256 with `sha256sum -c`.
#
# Nothing is published or modified in the repository.  Downloads default to
# build/data-bundle/<version>/ (gitignored).
#
# Exit codes: 0 success; 1 download/verification/policy error; 2 usage.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
VERSION="${BTC_LEAN_DATA_VERSION:-2026.10.17}"
RELEASE_TAG="${BTC_LEAN_DATA_RELEASE_TAG:-}"
BASE_URL="${BTC_LEAN_DATA_BASE_URL:-https://github.com/Rob1Ham/btc-lean/releases/download}"
ASSETS_SHA256_PIN="${BTC_LEAN_DATA_ASSETS_SHA256:-}"
ASSET=""
DEST=""
EXTRACT=""
FORCE=0
DRY_RUN=0
ASSETS_NAME="assets.sha256"
MANIFEST_NAME="manifest.sha256"

usage() {
  cat <<'EOF'
fetch_data.sh — download and verify a btc-lean data release (no execution)

Usage:
  bash scripts/fetch_data.sh --dry-run
  bash scripts/fetch_data.sh --assets-sha256 <64-hex-pin>
  bash scripts/fetch_data.sh --extract /tmp/btc-lean-data

Options:
  --version V             bundle version (default: 2026.10.17)
  --release-tag TAG       release tag (default: data-$VERSION)
  --base-url URL          release download base URL
  --dest DIR              download directory (default: build/data-bundle/$VERSION)
  --asset NAME            archive asset name (default: btc-lean-data-$VERSION.tar.gz)
  --assets-sha256 HEX     required SHA-256 of assets.sha256 (out-of-band pin)
  --extract DIR           extract after verification, then verify manifest.sha256
  --force                 re-download and allow extraction over existing files
  --dry-run               print the plan; no network access and no writes
  -h, --help              this text

Environment defaults: BTC_LEAN_DATA_VERSION, BTC_LEAN_DATA_RELEASE_TAG,
BTC_LEAN_DATA_BASE_URL, BTC_LEAN_DATA_ASSETS_SHA256.

The downloaded archive is never executed.  Extraction is opt-in.
EOF
}

die() { echo "fetch_data: ERROR: $*" >&2; exit 1; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)          [ "$#" -ge 2 ] || { usage; exit 2; }; VERSION="$2"; shift 2 ;;
    --release-tag)      [ "$#" -ge 2 ] || { usage; exit 2; }; RELEASE_TAG="$2"; shift 2 ;;
    --base-url)         [ "$#" -ge 2 ] || { usage; exit 2; }; BASE_URL="${2%/}"; shift 2 ;;
    --dest)             [ "$#" -ge 2 ] || { usage; exit 2; }; DEST="$2"; shift 2 ;;
    --asset)            [ "$#" -ge 2 ] || { usage; exit 2; }; ASSET="$2"; shift 2 ;;
    --assets-sha256)    [ "$#" -ge 2 ] || { usage; exit 2; }; ASSETS_SHA256_PIN="$2"; shift 2 ;;
    --extract)          [ "$#" -ge 2 ] || { usage; exit 2; }; EXTRACT="$2"; shift 2 ;;
    --force)            FORCE=1; shift ;;
    --dry-run)          DRY_RUN=1; shift ;;
    -h|--help)          usage; exit 0 ;;
    *) echo "fetch_data: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$RELEASE_TAG" ] || RELEASE_TAG="data-$VERSION"
[ -n "$ASSET" ] || ASSET="btc-lean-data-$VERSION.tar.gz"

# Version/tag/asset become URL and path components: keep them boring.
valid_component() {
  case "$1" in
    ''|*[!A-Za-z0-9._-]*|.*) return 1 ;;
    *) return 0 ;;
  esac
}
valid_component "$VERSION"     || die "invalid --version (use [A-Za-z0-9._-], no leading dot)"
valid_component "$RELEASE_TAG" || die "invalid --release-tag (use [A-Za-z0-9._-], no leading dot)"
valid_component "$ASSET"       || die "invalid --asset (use [A-Za-z0-9._-], no leading dot)"
case "$ASSET" in
  *.tar.gz) : ;;
  *) die "--asset must end in .tar.gz" ;;
esac
[ -n "$BASE_URL" ] || die "--base-url must not be empty"
case "$BASE_URL" in
  https://*) : ;;
  http://localhost|http://localhost/*|http://127.0.0.1|http://127.0.0.1/*) : ;;
  http://*) die "refusing insecure http base URL; use https:// (localhost is allowed for testing)" ;;
  *) die "base URL must be https:// (or localhost http:// for testing)" ;;
esac
case "$ASSETS_SHA256_PIN" in
  '') ;;
  *[!0-9a-fA-F]*) die "--assets-sha256 must be 64 hex characters" ;;
  *) [ "${#ASSETS_SHA256_PIN}" -eq 64 ] || die "--assets-sha256 must be 64 hex characters" ;;
esac

if [ -z "$DEST" ]; then
  DEST="$REPO_ROOT/build/data-bundle/$VERSION"
fi

ASSETS_URL="$BASE_URL/$RELEASE_TAG/$ASSETS_NAME"
MANIFEST_URL="$BASE_URL/$RELEASE_TAG/$MANIFEST_NAME"
ASSET_URL="$BASE_URL/$RELEASE_TAG/$ASSET"
ASSETS_PATH="$DEST/$ASSETS_NAME"
MANIFEST_PATH="$DEST/$MANIFEST_NAME"
ASSET_PATH="$DEST/$ASSET"

echo "fetch_data: version $VERSION (release tag $RELEASE_TAG)"
echo "fetch_data: transport $ASSETS_URL"
echo "fetch_data: manifest  $MANIFEST_URL"
echo "fetch_data: archive   $ASSET_URL"
echo "fetch_data: dest      $DEST"
[ -n "$EXTRACT" ] && echo "fetch_data: extract   $EXTRACT"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "fetch_data: dry run — no network access, no files written, no code executed"
  if [ -n "$ASSETS_SHA256_PIN" ]; then
    echo "fetch_data: assets.sha256 pin supplied"
  else
    echo "fetch_data: no assets.sha256 pin supplied (HTTPS-only trust)"
  fi
  exit 0
fi

command -v tar >/dev/null 2>&1 || die "tar is required"
if command -v sha256sum >/dev/null 2>&1; then
  SHA256_OF=sha256sum
elif command -v shasum >/dev/null 2>&1; then
  SHA256_OF=shasum
else
  die "need sha256sum or shasum"
fi
if command -v curl >/dev/null 2>&1; then
  DOWNLOADER=curl
elif command -v wget >/dev/null 2>&1; then
  DOWNLOADER=wget
else
  die "need curl or wget"
fi

mkdir -p "$DEST"
TMP_DIR="$(mktemp -d "$DEST/.fetch.XXXXXX")" || die "cannot create temporary directory"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT HUP INT TERM

hash_of() { # file -> lowercase hex
  if [ "$SHA256_OF" = sha256sum ]; then
    sha256sum -- "$1" | cut -d' ' -f1
  else
    shasum -a 256 -- "$1" | cut -d' ' -f1
  fi
}

download_to() { # url dest
  local url="$1" dest="$2"
  echo "fetch_data: GET $url" >&2
  if [ "$DOWNLOADER" = curl ]; then
    curl --fail --location --silent --show-error \
         --retry 3 --connect-timeout 20 --output "$dest" "$url" \
      || die "download failed: $url"
  else
    wget --quiet --tries=3 --timeout=20 --output-document="$dest" "$url" \
      || die "download failed: $url"
  fi
}

expected_hash() { # name -> hex from assets.sha256
  local want="$1"
  awk -v want="$want" '
    /^[[:space:]]*(#|$)/ { next }
    {
      name = $2
      sub(/^\*/, "", name)
      if ($1 ~ /^[0-9a-fA-F]+$/ && length($1) == 64 && name == want) {
        print tolower($1); found = 1; exit
      }
    }
    END { if (!found) exit 1 }
  ' "$ASSETS_PATH"
}

# ---- 1. transport manifest ------------------------------------------------
download_to "$ASSETS_URL" "$TMP_DIR/$ASSETS_NAME"
if [ -n "$ASSETS_SHA256_PIN" ]; then
  got="$(hash_of "$TMP_DIR/$ASSETS_NAME")"
  want="$(printf '%s' "$ASSETS_SHA256_PIN" | tr 'A-F' 'a-f')"
  [ "$got" = "$want" ] || die "assets.sha256 does not match --assets-sha256 (got $got)"
  echo "fetch_data: assets.sha256 matches the out-of-band pin"
else
  echo "fetch_data: WARNING: assets.sha256 is not pinned or signed; HTTPS is the only trust anchor" >&2
fi
mv -f "$TMP_DIR/$ASSETS_NAME" "$ASSETS_PATH"

# ---- 2. manifest and archive ---------------------------------------------
MANIFEST_EXPECTED="$(expected_hash "$MANIFEST_NAME")" \
  || die "$ASSETS_NAME has no entry for $MANIFEST_NAME"
ASSET_EXPECTED="$(expected_hash "$ASSET")" \
  || die "$ASSETS_NAME has no entry for $ASSET"

download_to "$MANIFEST_URL" "$TMP_DIR/$MANIFEST_NAME"
got="$(hash_of "$TMP_DIR/$MANIFEST_NAME")"
[ "$got" = "$MANIFEST_EXPECTED" ] \
  || die "$MANIFEST_NAME checksum mismatch (got $got, expected $MANIFEST_EXPECTED)"
mv -f "$TMP_DIR/$MANIFEST_NAME" "$MANIFEST_PATH"

if [ -f "$ASSET_PATH" ] && [ "$FORCE" -eq 0 ]; then
  got="$(hash_of "$ASSET_PATH")"
  if [ "$got" = "$ASSET_EXPECTED" ]; then
    echo "fetch_data: reusing verified archive $ASSET_PATH"
  else
    echo "fetch_data: existing archive does not match; re-downloading" >&2
    rm -f "$ASSET_PATH"
  fi
fi
if [ ! -f "$ASSET_PATH" ]; then
  download_to "$ASSET_URL" "$TMP_DIR/$ASSET"
  got="$(hash_of "$TMP_DIR/$ASSET")"
  [ "$got" = "$ASSET_EXPECTED" ] \
    || die "$ASSET checksum mismatch (got $got, expected $ASSET_EXPECTED)"
  mv -f "$TMP_DIR/$ASSET" "$ASSET_PATH"
else
  got="$(hash_of "$ASSET_PATH")"
  [ "$got" = "$ASSET_EXPECTED" ] \
    || die "$ASSET checksum mismatch (got $got, expected $ASSET_EXPECTED)"
fi
echo "fetch_data: archive verified: $ASSET_PATH"

if [ -z "$EXTRACT" ]; then
  echo "fetch_data: done (archive not extracted; pass --extract DIR to verify every file)"
  exit 0
fi

# ---- 3. optional safe extraction + content verification ------------------
mkdir -p "$EXTRACT"
LIST="$TMP_DIR/archive.list"
tar -tzf "$ASSET_PATH" > "$LIST" || die "cannot list archive: $ASSET_PATH"
while IFS= read -r name; do
  case "$name" in
    ''|/*|..|../*|*/..|*/../*|*\\*)
      die "unsafe path in archive: $name" ;;
  esac
done < "$LIST"

# Materialized data bundles must not contain links or special files.
if tar -tvzf "$ASSET_PATH" | awk 'substr($0,1,1) == "l" || substr($0,1,1) == "h" { bad=1 } END { exit bad ? 0 : 1 }'; then
  die "archive contains symlink or hardlink members; refusing to extract"
fi

if [ "$FORCE" -eq 1 ]; then
  tar -xzf "$ASSET_PATH" --no-same-owner --no-same-permissions -C "$EXTRACT"
else
  tar -xzf "$ASSET_PATH" --no-same-owner --no-same-permissions \
      --keep-old-files -C "$EXTRACT" \
    || die "extraction refused to overwrite an existing file (use --force)"
fi

echo "fetch_data: verifying every extracted file against $MANIFEST_NAME"
( cd "$EXTRACT" && "$SHA256_OF" --check "$MANIFEST_PATH" ) \
  || die "content verification failed for $MANIFEST_NAME"
echo "fetch_data: all checks passed; no downloaded code was executed"
