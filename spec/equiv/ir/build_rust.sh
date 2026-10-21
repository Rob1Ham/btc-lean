#!/usr/bin/env bash
# build_rust.sh -- clean build of rbitcoin's consensus crate at the pin and
# LLVM IR emission for the R leg.
#
# Leg: R. rbitcoin @ ae47aa98174e04d0d8c493f13041daf65e4ac1d3.
# Producer: rustc 1.95.0 (59807616e 2026-04-14), LLVM 22.1.2, target
# x86_64-unknown-linux-gnu. No FFI patch is applied and the `equiv-ffi`
# feature is NOT enabled; the artifact is the unmodified crate.
#
# Outputs:
#   rust-consensus-O0.bc/.ll         raw rustc 1.95 bitcode + text (pin producer)
#   rust-consensus-O0-v20.bc/.ll     LLVM-20-normalised derivative (see below)
#   rust-verify-input-O0.bc/.ll      extracted single-input verifier
#
# Why the v20 derivative exists: LLVM 20 readers (Alive2 v20, llvm-nm-20)
# reject rustc-1.95 bitcode with "Unknown attribute kind (105)" because LLVM 22
# emits the `nocreateundeforpoison` attribute. The derivative removes that one
# token textually and reassembles with llvm-as-20. It is a *conversion*, not
# the pin artifact; both files and the transform are recorded. See report.md.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

RBTC_PIN=ae47aa98174e04d0d8c493f13041daf65e4ac1d3
TOOLCHAIN=${TOOLCHAIN:-1.95.0}
BUILD_ROOT=${BUILD_ROOT:-/tmp/opencode/ir-pipeline}
RBTC_SRC=${RBTC_SRC:-$BUILD_ROOT/rbitcoin}
ARTIFACTS_DIR=${ARTIFACTS_DIR:-$BUILD_ROOT/artifacts}
TARGET_DIR=${TARGET_DIR:-$BUILD_ROOT/out/rust-target}
LLVM_BIN=${LLVM_BIN:-/usr/lib/llvm-20/bin}

die() { echo "build_rust: $*" >&2; exit 1; }

[ -d "$RBTC_SRC/.git" ] || die "no git tree at $RBTC_SRC"
head=$(git -C "$RBTC_SRC" rev-parse HEAD)
[ "$head" = "$RBTC_PIN" ] || die "rbitcoin HEAD is $head, pin is $RBTC_PIN"
status=$(git -C "$RBTC_SRC" status --porcelain)
[ -z "$status" ] || die "rbitcoin tree is dirty; refusing to build: $status"

# The dirty scratch clone carries a feature-gated FFI patch. Make sure this
# clone does not: no ffi.rs and no equiv_entry anywhere in the crate.
if find "$RBTC_SRC/crates/rbitcoin-consensus" -name 'ffi.rs' | grep -q .; then
  die "unexpected ffi.rs in clean clone"
fi
if grep -Rqn "equiv_entry" "$RBTC_SRC/crates/rbitcoin-consensus/src"; then
  die "unexpected equiv_entry in clean clone (FFI patch present?)"
fi

version=$(rustup run "$TOOLCHAIN" rustc -Vv)
echo "$version" | grep -q "^rustc 1.95.0 (59807616e 2026-04-14)$" \
  || die "rustc is not 1.95.0 (59807616e): $version"
echo "$version" | grep -q "^LLVM version: 22.1.2$" \
  || die "rustc LLVM is not 22.1.2: $version"

mkdir -p "$ARTIFACTS_DIR/logs"
rm -rf "$TARGET_DIR"

# Emit both bitcode and text for the target crate only. Dependencies are
# compiled normally and appear as external declarations in this module.
( cd "$RBTC_SRC" && \
  CARGO_TARGET_DIR="$TARGET_DIR" RUSTUP_TOOLCHAIN="$TOOLCHAIN" CARGO_NET_OFFLINE=true \
  cargo rustc --offline -p rbitcoin-consensus --lib --profile dev -- \
    -C codegen-units=1 -C debuginfo=0 --emit=llvm-ir,llvm-bc ) \
  > "$ARTIFACTS_DIR/logs/rust-build.log" 2>&1 \
  || die "cargo build failed (see logs/rust-build.log)"

raw_bc=$(find "$TARGET_DIR/debug/deps" -maxdepth 1 -name 'rbitcoin_consensus-*.bc' | head -1)
raw_ll=${raw_bc%.bc}.ll
[ -n "$raw_bc" ] && [ -s "$raw_bc" ] || die "no crate bitcode produced"
[ -s "$raw_ll" ] || die "no crate textual IR produced"

cp "$raw_bc" "$ARTIFACTS_DIR/rust-consensus-O0.bc"
cp "$raw_ll" "$ARTIFACTS_DIR/rust-consensus-O0.ll"

# --- LLVM-20-normalised derivative -----------------------------------------
# The only edit is dropping the LLVM-22-only function attribute token.
sed 's/ nocreateundeforpoison//g' "$ARTIFACTS_DIR/rust-consensus-O0.ll" \
  > "$TARGET_DIR/rust-consensus-O0-v20.src.ll"
"$LLVM_BIN/llvm-as" "$TARGET_DIR/rust-consensus-O0-v20.src.ll" \
  -o "$ARTIFACTS_DIR/rust-consensus-O0-v20.bc"
"$LLVM_BIN/llvm-dis" "$ARTIFACTS_DIR/rust-consensus-O0-v20.bc" \
  -o "$ARTIFACTS_DIR/rust-consensus-O0-v20.ll"
# Structural check: removing the token and reassembling must not change the
# module structure. llvm-diff prints differences and exits non-zero on a
# structural mismatch; an empty log is the expected result.
"$LLVM_BIN/llvm-diff" "$TARGET_DIR/rust-consensus-O0-v20.src.ll" \
  "$ARTIFACTS_DIR/rust-consensus-O0-v20.ll" \
  > "$ARTIFACTS_DIR/logs/rust-llvm-diff.log" 2>&1 \
  || die "llvm-diff found a structural difference in the v20 derivative"

# --- single-input verifier extraction --------------------------------------
# Symbol names are located with llvm-nm (on the v20 derivative, the only
# LLVM-20-readable form) and cross-checked against the textual IR.
vi_sym=$("$LLVM_BIN/llvm-nm" --defined-only "$ARTIFACTS_DIR/rust-consensus-O0-v20.bc" \
  | awk '{print $NF}' | grep -E '^_ZN18rbitcoin_consensus6script12verify_input17h[0-9a-f]+E$' | head -1)
[ -n "$vi_sym" ] || die "could not locate script::verify_input in crate bitcode"
"$LLVM_BIN/llvm-extract" --func="$vi_sym" "$ARTIFACTS_DIR/rust-consensus-O0-v20.bc" \
  -o "$ARTIFACTS_DIR/rust-verify-input-O0.bc"
"$LLVM_BIN/llvm-dis" "$ARTIFACTS_DIR/rust-verify-input-O0.bc" \
  -o "$ARTIFACTS_DIR/rust-verify-input-O0.ll"
echo "$vi_sym" > "$ARTIFACTS_DIR/rust-verify-input-O0.symbol.txt"

# A representative simple-signature leaf, used only as a tool-ingestion smoke
# (Alive2 cannot translate the aggregate-returning verify_input). Not a proof
# of the engine.
leaf_sym=$("$LLVM_BIN/llvm-nm" --defined-only "$ARTIFACTS_DIR/rust-consensus-O0-v20.bc" \
  | awk '{print $NF}' | grep -E '^_ZN18rbitcoin_consensus6script11interpreter13is_op_success17h[0-9a-f]+E$' | head -1)
[ -n "$leaf_sym" ] || die "could not locate interpreter::is_op_success in crate bitcode"
"$LLVM_BIN/llvm-extract" --func="$leaf_sym" "$ARTIFACTS_DIR/rust-consensus-O0-v20.bc" \
  -o "$ARTIFACTS_DIR/rust-is-op-success-O0.bc"
"$LLVM_BIN/llvm-dis" "$ARTIFACTS_DIR/rust-is-op-success-O0.bc" \
  -o "$ARTIFACTS_DIR/rust-is-op-success-O0.ll"
echo "$leaf_sym" > "$ARTIFACTS_DIR/rust-is-op-success-O0.symbol.txt"

# --- provenance -------------------------------------------------------------
python3 - "$ARTIFACTS_DIR" "$RBTC_SRC" "$TARGET_DIR" "$head" "$TOOLCHAIN" "$version" "$vi_sym" "$leaf_sym" <<'PY'
import hashlib, json, os, subprocess, sys

art, src, target, head, toolchain, version, vi_sym, leaf_sym = sys.argv[1:]
LLVM = "/usr/lib/llvm-20/bin"

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()

def syms(bc, defined):
    flag = "--defined-only" if defined else "--undefined-only"
    r = subprocess.run([f"{LLVM}/llvm-nm", flag, bc], capture_output=True, text=True)
    if r.returncode != 0:
        return None
    return sorted({l.split()[-1] for l in r.stdout.splitlines() if l.split()})

def ir_header(ll):
    triple = datalayout = None
    for line in open(ll, errors="replace"):
        if line.startswith("target datalayout"):
            datalayout = line.split("=", 1)[1].strip().strip('"')
        elif line.startswith("target triple"):
            triple = line.split("=", 1)[1].strip().strip('"')
        elif line.startswith("define "):
            break
    return triple, datalayout

def art_entry(name, leg, kind):
    bc = os.path.join(art, f"{name}.bc")
    ll = os.path.join(art, f"{name}.ll")
    triple, dl = ir_header(ll)
    d = {
        "id": name, "leg": leg, "kind": kind, "opt": "-O0 (dev profile, opt-level=0)",
        "bc_path": bc, "bc_sha256": sha(bc), "bc_bytes": os.path.getsize(bc),
        "ll_path": ll, "ll_sha256": sha(ll), "ll_bytes": os.path.getsize(ll),
        "triple": triple, "datalayout": dl,
        "undefined_symbols": syms(bc, False),
    }
    s = syms(bc, True)
    d["defined_symbols"] = s
    d["defined_symbol_count"] = len(s) if s is not None else None
    return d

arts = [
    art_entry("rust-consensus-O0", "R", "raw-rustc-1.95-llvm22"),
    art_entry("rust-consensus-O0-v20", "R", "llvm20-normalised-derivative"),
    art_entry("rust-verify-input-O0", "R", "extracted-single-input-verifier"),
    art_entry("rust-is-op-success-O0", "R", "extracted-smoke-leaf"),
]
arts[0]["llvm20_readable"] = False
arts[1]["llvm20_readable"] = True
arts[2]["llvm20_readable"] = True
arts[3]["llvm20_readable"] = True

# Which crate functions matter to the workstream (located by nm / text IR).
raw_ll = os.path.join(art, "rust-consensus-O0.ll")
text_syms = sorted({l.split("@", 1)[1].split("(", 1)[0].strip('"')
                    for l in open(raw_ll, errors="replace")
                    if l.startswith("define ") and "@" in l})
key = [s for s in text_syms if any(k in s for k in
       ("verify_input", "verify_job_all_inputs", "verify_tx_scripts_with_flags",
        "verify_bare", "script_pool"))]

frag = {
    "leg": "R",
    "commands": {
        "build_and_emit": (
            "cd <rbtc_src> && CARGO_TARGET_DIR=<target> RUSTUP_TOOLCHAIN=1.95.0 "
            "CARGO_NET_OFFLINE=true cargo rustc --offline -p rbitcoin-consensus --lib "
            "--profile dev -- -C codegen-units=1 -C debuginfo=0 --emit=llvm-ir,llvm-bc"
        ),
        "copy_outputs": ("cp <target>/debug/deps/rbitcoin_consensus-*.bc "
                         "<artifacts>/rust-consensus-O0.bc (same for .ll)"),
        "normalise": ("sed 's/ nocreateundeforpoison//g' <artifacts>/rust-consensus-O0.ll "
                      "> <target>/rust-consensus-O0-v20.src.ll && "
                      "/usr/lib/llvm-20/bin/llvm-as <target>/rust-consensus-O0-v20.src.ll "
                      "-o <artifacts>/rust-consensus-O0-v20.bc && "
                      "/usr/lib/llvm-20/bin/llvm-dis <artifacts>/rust-consensus-O0-v20.bc "
                      "-o <artifacts>/rust-consensus-O0-v20.ll"),
        "extract_verify_input": (
            "/usr/lib/llvm-20/bin/llvm-extract --func=<verify_input mangled> "
            "<artifacts>/rust-consensus-O0-v20.bc -o <artifacts>/rust-verify-input-O0.bc"
        ),
        "extract_leaf": (
            "/usr/lib/llvm-20/bin/llvm-extract --func=<is_op_success mangled> "
            "<artifacts>/rust-consensus-O0-v20.bc -o <artifacts>/rust-is-op-success-O0.bc"
        ),
        "toolchain": "rustup run 1.95.0 rustc -Vv",
    },
    "source": {
        "repo": "reardencode/rbitcoin", "head": head,
        "version": "ae47aa9 (untagged; the pin is the commit)",
        "tree_clean": True, "patches": "none (equiv-ffi feature NOT enabled)",
        "cargo_lock": os.path.join(src, "Cargo.lock"),
        "cargo_lock_sha256": sha(os.path.join(src, "Cargo.lock")),
        "rust_toolchain_toml": os.path.join(src, "rust-toolchain.toml"),
        "rust_toolchain_toml_sha256": sha(os.path.join(src, "rust-toolchain.toml")),
        "ffi_rs_present": False,
        "equiv_entry_present": False,
    },
    "producer": {
        "tool": "rustc", "toolchain": toolchain, "version_vv": version.strip().splitlines(),
        "llvm": "22.1.2", "target": "x86_64-unknown-linux-gnu",
        "profile": "dev (opt-level=0, codegen-units=1, debuginfo=0)",
        "cargo_command": ("cargo rustc --offline -p rbitcoin-consensus --lib "
                          "--profile dev -- -C codegen-units=1 -C debuginfo=0 "
                          "--emit=llvm-ir,llvm-bc"),
    },
    "key_symbols": key,
    "single_input_verifier": {
        "source": "crates/rbitcoin-consensus/src/script/mod.rs::verify_input (pub(crate))",
        "mangled": vi_sym,
    },
    "smoke_leaf": {
        "source": "crates/rbitcoin-consensus/src/script/interpreter.rs::is_op_success",
        "mangled": leaf_sym,
        "purpose": "simple-signature leaf so Alive2/SAW ingestion can be exercised; not an engine proof",
    },
    "artifacts": arts,
    "normalisation": {
        "input": os.path.join(art, "rust-consensus-O0.ll"),
        "output": os.path.join(art, "rust-consensus-O0-v20.bc"),
        "transform": "sed 's/ nocreateundeforpoison//g' then llvm-as-20",
        "attribute": "nocreateundeforpoison (LLVM 22 attribute kind 105)",
        "replacements": open(raw_ll, errors="replace").read().count(" nocreateundeforpoison"),
        "is_pin_artifact": False,
        "note": "Derivative only so LLVM-20-based tools can read the module. "
                "The pin artifact is rust-consensus-O0.bc.",
    },
    "notes": [
        "Clean clone of the pin; git status empty before build; no FFI patch.",
        "Only rbitcoin-consensus is compiled with --emit; dependencies are external.",
        "Raw rustc 1.95 bitcode is rejected by LLVM 20 readers (attribute kind 105).",
    ],
}
os.makedirs(os.path.join(art, "fragments"), exist_ok=True)
with open(os.path.join(art, "fragments", "rust.json"), "w") as f:
    json.dump(frag, f, indent=2, sort_keys=True)
    f.write("\n")
print("wrote", os.path.join(art, "fragments", "rust.json"))
print("verify_input symbol:", vi_sym)
for a in arts:
    print(a["id"], "bc", a["bc_sha256"][:16], "ll", a["ll_sha256"][:16],
          "defs", a["defined_symbol_count"])
PY
