#!/usr/bin/env bash
# smoke.sh -- raw tool-ingestion smoke for every IR artifact.
#
# For each artifact this records:
#   * alive-tv v20.0 (single-file self-refinement, plus a targeted --func run
#     where the module is too large to analyse whole within the timeout);
#   * SAW 1.6 llvm_load_module on the .bc file.
#
# These are capability results, not proofs of the engine. A timeout or a
# translation/parse error is recorded verbatim; it is never turned into a
# pass. Raw stdout/stderr stays in $ARTIFACTS_DIR/smoke/.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD_ROOT=${BUILD_ROOT:-/tmp/opencode/ir-pipeline}
ARTIFACTS_DIR=${ARTIFACTS_DIR:-$BUILD_ROOT/artifacts}
ALIVE=${ALIVE:-/opt/equiv-tools/alive-tv-v20.0}
SAW=${SAW:-/opt/equiv-tools/saw-1.6/bin/saw}
ALIVE_TIMEOUT=${ALIVE_TIMEOUT:-120}
SAW_TIMEOUT=${SAW_TIMEOUT:-300}
OUT=$ARTIFACTS_DIR/smoke
mkdir -p "$OUT"

die() { echo "smoke: $*" >&2; exit 1; }
[ -x "$ALIVE" ] || die "no alive-tv at $ALIVE"
[ -x "$SAW" ] || die "no saw at $SAW"
[ -s "$ARTIFACTS_DIR/core-interpreter-O0.bc" ] || die "artifacts missing; run the build scripts first"

alive_version=$("$ALIVE" --version 2>&1 | head -2 | tr '\n' ' ')
saw_version=$("$SAW" --version 2>&1 | head -1)

python3 - "$OUT" "$ALIVE" "$SAW" "$ALIVE_TIMEOUT" "$SAW_TIMEOUT" "$alive_version" "$saw_version" <<'PY'
import json, os, re, subprocess, sys

out, alive, saw, atmo, stmo, alive_version, saw_version = sys.argv[1:]
atmo, stmo = int(atmo), int(stmo)
art = os.path.dirname(out.rstrip("/"))
rows = []

def log(name, text):
    p = os.path.join(out, name)
    with open(p, "w") as f:
        f.write(text)
    return p

def text_of(e):
    def dec(x):
        if x is None:
            return ""
        return x.decode("utf-8", "replace") if isinstance(x, bytes) else x
    return dec(e.stdout) + dec(e.stderr)

def first_error(text):
    for line in text.splitlines():
        s = line.strip()
        if any(k in s for k in ("ERROR:", "Expected ", "error:", "Could not",
                                "Unknown attribute", "Unsupported", "Summary:")):
            return s[:300]
    return ""

def run_alive(tag, artifact, extra=()):
    cmd = [alive, *extra, os.path.join(art, artifact)]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=atmo)
        rc, timed_out = r.returncode, False
        text = (r.stdout or "") + (r.stderr or "")
    except subprocess.TimeoutExpired as e:
        rc, timed_out = 124, True
        text = text_of(e)
    summary = ""
    counts = {}
    for line in text.splitlines():
        s = line.strip()
        for key, pat in (("correct", r"(\d+) correct transformations"),
                         ("incorrect", r"(\d+) incorrect transformations"),
                         ("failed_to_prove", r"(\d+) failed-to-prove transformations"),
                         ("alive2_errors", r"(\d+) Alive2 errors")):
            m = re.search(pat, s)
            if m:
                counts[key] = int(m.group(1))
    if counts:
        summary = " ".join(f"{k}={v}" for k, v in counts.items())
    p = log(f"{tag}.alive.log", text)
    rows.append({
        "id": tag, "tool": "alive-tv", "version": alive_version,
        "argv": cmd, "exit": rc, "timed_out": timed_out,
        "counts": counts,
        "first_error": first_error(text), "summary_line": summary,
        "log": p,
    })

def run_saw_load(tag, artifact):
    bc = os.path.join(art, artifact)
    spec = os.path.join(out, f"{tag}.saw")
    with open(spec, "w") as f:
        f.write(f'm <- llvm_load_module "{bc}";\nprint "LOADED";\n')
    cmd = [saw, spec]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=stmo)
        rc, timed_out = r.returncode, False
        text = (r.stdout or "") + (r.stderr or "")
    except subprocess.TimeoutExpired as e:
        rc, timed_out = 124, True
        text = text_of(e)
    loaded = "LOADED" in text and rc == 0
    p = log(f"{tag}.saw.log", text)
    rows.append({
        "id": tag, "tool": "saw", "version": saw_version,
        "argv": cmd, "exit": rc, "timed_out": timed_out,
        "loaded": loaded, "first_error": first_error(text), "log": p,
    })

# C leg ---------------------------------------------------------------------
CAST = "_Z10CastToBoolRKSt6vectorIhSaIhEE"
for o in (0, 1):
    run_alive(f"alive-core-O{o}-module", f"core-interpreter-O{o}.bc")
    run_alive(f"alive-core-O{o}-CastToBool", f"core-interpreter-O{o}.bc", ["--func=" + CAST])
    run_saw_load(f"saw-core-O{o}", f"core-interpreter-O{o}.bc")

# L leg ---------------------------------------------------------------------
for o in (0, 1):
    run_alive(f"alive-twin-O{o}-module", f"twin-O{o}.bc")
    run_saw_load(f"saw-twin-O{o}", f"twin-O{o}.bc")
run_alive("alive-twin-O0-cast_to_bool", "twin-O0.bc",
          ["--func=_ZN4twinL12cast_to_boolEPKhj"])

# R leg ---------------------------------------------------------------------
run_alive("alive-rust-raw", "rust-consensus-O0.bc")
run_saw_load("saw-rust-raw", "rust-consensus-O0.bc")
run_alive("alive-rust-v20-module", "rust-consensus-O0-v20.bc")
run_saw_load("saw-rust-v20-module", "rust-consensus-O0-v20.bc")
run_alive("alive-rust-verify-input", "rust-verify-input-O0.bc")
run_saw_load("saw-rust-verify-input", "rust-verify-input-O0.bc")
run_alive("alive-rust-is-op-success", "rust-is-op-success-O0.bc")
run_saw_load("saw-rust-is-op-success", "rust-is-op-success-O0.bc")

doc = {
    "alive_version": alive_version,
    "saw_version": saw_version,
    "alive_timeout_s": atmo,
    "saw_timeout_s": stmo,
    "note": "Capability results only. alive-tv single-file mode checks "
            "self-refinement of the module (or of --func); it is not a proof "
            "of any C<=>L<=>R relation.",
    "runs": rows,
}
with open(os.path.join(out, "smoke.json"), "w") as f:
    json.dump(doc, f, indent=2, sort_keys=True)
    f.write("\n")

for r in rows:
    if r["timed_out"]:
        status = "TIMEOUT"
    elif r["tool"] == "saw":
        status = "LOADED" if r.get("loaded") else f"LOAD-FAIL({r['exit']})"
    else:
        c = r.get("counts") or {}
        if c.get("incorrect", 0) > 0:
            status = "INCORRECT"
        elif c.get("alive2_errors", 0) > 0:
            status = "ALIVE-ERRORS"
        elif c.get("failed_to_prove", 0) > 0:
            status = "UNPROVEN"
        elif c.get("correct", 0) > 0:
            status = "PASS"
        else:
            status = f"LOAD-FAIL({r['exit']})"
    detail = r.get("summary_line") or r["first_error"]
    print(f'{r["id"]:<34} {r["tool"]:<9} {status:<13} {detail[:80]}')
print("wrote", os.path.join(out, "smoke.json"))
PY
