# R-leg build instructions (rbitcoin → LLVM IR → SAW / Alive2)

Status: reproducible for the **clean** lane at commit
`ae47aa98174e04d0d8c493f13041daf65e4ac1d3`. The `equiv-ffi` lane is a
**proposal only** and is not authorized by `patches/README.md`; see §9.

All commands assume Linux x86-64 and:

```sh
export WORK=${WORK:-/tmp/opencode/equiv-work}
export RBTC=${RBTC:-$WORK/rbitcoin-clean}
export SPEC=${SPEC:-/home/ubuntu/btc-lean-public/spec/equiv}
export LLVM_BIN=/usr/lib/llvm-20/bin
export PATH=$LLVM_BIN:/opt/equiv-tools/saw-1.6/bin:$PATH
```

`/opt/equiv-tools/saw-1.6/bin` must be on `PATH`. SAW's `abc`/`z3`/`cvc5`
lookups fail with `posix_spawnp: does not exist` otherwise.

## 1. Prerequisites

| Tool | Version / path |
|---|---|
| rustc | 1.88.0 (6b00bc388), LLVM 20.1.5: `rustup toolchain install 1.88.0` |
| LLVM | Ubuntu LLVM 20.1.2 in `/usr/lib/llvm-20/bin` (`llvm-as`, `opt`, `llvm-dis`, `llvm-nm`, `llvm-extract`) |
| SAW | 1.6 (68eed5f), `/opt/equiv-tools/saw-1.6/bin/saw` |
| Alive2 | v20.0, `/opt/equiv-tools/alive-tv-v20.0` |
| C toolchain | `cc`, `gcc` (for the staticlib smoke only) |
| Cargo | any recent cargo; the toolchain is selected per command with `+1.88.0` |

Check:

```sh
rustc +1.88.0 -Vv | grep -E 'release|LLVM'
/opt/equiv-tools/saw-1.6/bin/saw --version
/opt/equiv-tools/alive-tv-v20.0 --version   # prints the LLVM version only
```

## 2. Pin the source (clean tree)

```sh
git clone https://github.com/reardencode/rbitcoin "$RBTC"
cd "$RBTC"
git checkout ae47aa98174e04d0d8c493f13041daf65e4ac1d3
test -z "$(git status --porcelain)" || { echo 'tree is dirty'; exit 1; }
git rev-parse HEAD
sha256sum Cargo.lock rust-toolchain.toml
```

Expected:

```text
ae47aa98174e04d0d8c493f13041daf65e4ac1d3
d0f177616e0c48925e24b1a37bfb7faa2059768cb7c7d1c51ed71d03700d5026  Cargo.lock
12dc5d64dbd96c1b07be2943241d52d9f6127a79ba47a820455ba7b873fc896a  rust-toolchain.toml
```

Do **not** use the dirty tree that has `rbitcoin-ffi.patch` applied for
official artifacts. Make a second worktree if you need the proposal lane.

## 3. Clean proof IR (official lane)

```sh
cd "$RBTC"
export CARGO_TARGET_DIR="$WORK/target-188-clean"
timeout 1200 cargo +1.88.0 rustc --release --ignore-rust-version \
  -p rbitcoin-consensus --lib -- \
  --emit=llvm-ir,llvm-bc -C lto=no -C panic=abort
```

`--ignore-rust-version` is required: the workspace declares `rust-version =
"1.95"` and the repo pins 1.95.0. `-C lto=no` keeps one crate-level module;
`-C embed-bitcode=yes` is incompatible with `-C lto` in rustc 1.88, so do not
add it. `panic=abort` is the Alive2 lane (no `invoke`/landing pads).

Locate and record:

```sh
LL=$(ls -t "$CARGO_TARGET_DIR"/release/deps/rbitcoin_consensus-*.ll | head -1)
BC=${LL%.ll}.bc
sha256sum "$LL" "$BC"
wc -c "$LL" "$BC"
```

Expected for this pin/toolchain:

| File | Bytes | sha256 |
|---|---:|---|
| `rbitcoin_consensus-b3449e40c0e43013.ll` | 6,557,818 | `0e80eaff568b0e58e7a93b34ef2ec36c9e3745f8005b073a2924243ee11699ea` |
| `rbitcoin_consensus-b3449e40c0e43013.bc` | 1,404,420 | `a568065fe89349d5c263c551a996c7fc0b1c71321ffafe962c7014376939cfaa` |

The hash suffix in the filename is compilation-dependent; identify by the
content hash, not the suffix. Validate LLVM 20 ingestion:

```sh
llvm-as "$LL" -o "$WORK/clean-roundtrip.bc"
opt -passes=verify -disable-output "$WORK/clean-roundtrip.bc"
```

Sanity symbols:

```sh
llvm-nm --defined-only "$BC" | grep -E 'eval_script|verify_input|verify_job_all_inputs'
```

The clean release keeps `interpreter::eval_script` and `script::verify_input`
as local (`t`) symbols and `verify_job_all_inputs` as global (`T`).

## 4. Cell extraction (clean, no patch)

`llvm-extract --func` does not pull callees. For a whole-function cell, make a
call-graph closure by changing only the target's `define internal` linkage,
then internalize/globaldce:

```sh
EVAL_SYM=$(llvm-nm --defined-only "$BC" | awk '/eval_script/{print $3; exit}')
VI_SYM=$(llvm-nm --defined-only "$BC" | awk '/verify_input/{print $3; exit}')

# Build a closure for eval_script.
perl -pe "s/^define internal /define / if /\Q$EVAL_SYM\E/" "$LL" > "$WORK/eval-ext.ll"
opt -passes='internalize,globaldce' \
    -internalize-public-api-list="$EVAL_SYM" \
    "$WORK/eval-ext.ll" -o "$WORK/eval_closure.bc"

# Same for verify_input.
perl -pe "s/^define internal /define / if /\Q$VI_SYM\E/" "$LL" > "$WORK/vi-ext.ll"
opt -passes='internalize,globaldce' \
    -internalize-public-api-list="$VI_SYM" \
    "$WORK/vi-ext.ll" -o "$WORK/vi_closure.bc"

llvm-nm --defined-only "$WORK/vi_closure.bc" | wc -l
llvm-nm --undefined-only "$WORK/vi_closure.bc" | wc -l
```

Recorded closures:

| File | Bytes | sha256 | defs / undef |
|---|---:|---|---|
| `vi_closure.bc` (`verify_input`) | 530,120 | `265ea2d9cea644d76f082a437b2aa78c3506a22917d2191edc99aab2fa6f8160` | 99 / 81 |
| `eval_closure.bc` (`eval_script`) | 377,128 | `720c298f82cae18e55276d001f27c3e3d6c90e78630720192ac14355f624eefa` | 78 / 68 |

SAW load check:

```sh
printf 'm <- llvm_load_module "%s";\nprint "SAW_LOAD_OK";\n' \
  "$WORK/vi_closure.bc" > "$WORK/saw-vi.saw"
saw "$WORK/saw-vi.saw"
```

Loading succeeds. Verification requires allocator/crypto/helper overrides; see
`spec/equiv/findings/rust/tool-probes.md`.

## 5. Clean leaf: `scriptnum_decode_width`

Build the primitives crate and extract the leaf:

```sh
cd "$RBTC"
export CARGO_TARGET_DIR="$WORK/target-188-clean"
cargo +1.88.0 rustc --release --ignore-rust-version \
  -p rbitcoin-primitives --lib -- \
  --emit=llvm-ir -C lto=no -C panic=abort

PRIM_LL=$(ls -t "$CARGO_TARGET_DIR"/release/deps/rbitcoin_primitives-*.ll | head -1)
llvm-as "$PRIM_LL" -o "$WORK/prim.bc"
LEAF_SYM=$(llvm-nm --defined-only "$WORK/prim.bc" | awk '/scriptnum_decode_width/{print $3; exit}')
llvm-extract --func="$LEAF_SYM" "$WORK/prim.bc" -o "$WORK/scriptnum_decode_width_clean.bc"
sha256sum "$WORK/scriptnum_decode_width_clean.bc"
```

Expected: 3,900 bytes,
`b6298690c605b7491b331e56ef54cf9b5afd087378cb3c8da155dd912f7ca9a1`.

Run the recorded SAW spec from `$WORK` (it expects
`out/bc/scriptnum_decode_width_clean.bc`; copy the artifact there or edit the
path):

```sh
cp "$SPEC/findings/rust/saw-rust-leaf.saw" "$WORK/"
mkdir -p "$WORK/out/bc"
cp "$WORK/scriptnum_decode_width_clean.bc" "$WORK/out/bc/"
PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw "$WORK/saw-rust-leaf.saw"
```

Expected tail:

```text
Proof succeeded! _ZN19rbitcoin_primitives9scriptnum22scriptnum_decode_width...
SAW_RUST_LEAF_OK
```

This spec fixes the input length to 5 and has **no postcondition**. It is a
safety/ingestion check, not an equivalence certificate. A 16-byte sret buffer
allocated as `[16 x i8]` makes SAW 1.6 report `Memory store failed`; use
`[2 x i64]` as in the recorded spec.

## 6. Alive2 lane

Raw Rust IR is rejected. Apply the recorded deterministic transform:

```sh
cp "$SPEC/findings/rust/sanitize_ir.sh" "$WORK/"
VI_SYM=$(llvm-nm --defined-only "$BC" | awk '/verify_input/{print $3; exit}')
llvm-extract --func="$VI_SYM" "$BC" -o "$WORK/vi_cell.bc"
llvm-dis "$WORK/vi_cell.bc" -o "$WORK/vi.ll"
"$WORK/sanitize_ir.sh" "$WORK/vi.ll" "$WORK/vi.clean.ll"
grep -v 'load volatile i8, ptr @__rust_no_alloc_shim_is_unstable' \
  "$WORK/vi.clean.ll" > "$WORK/vi.alive2.ll"
llvm-as "$WORK/vi.alive2.ll" -o "$WORK/vi.alive2.bc"
alive-tv "$WORK/vi.alive2.bc" "$WORK/vi.alive2.bc"
```

The example extracts the single `verify_input` function. The §4 closure is for
SAW; it contains additional std/formatting functions that Alive2 may reject,
so run Alive2 per cell, not on the whole closure.

The transform removes `noalias`, `nocapture`, `sret([N x i8])`, unsupported
metadata, and the discarded allocator-guard volatile loads. Removing an
argument attribute makes the function more general; record the transform and
re-check that the attribute was not load-bearing. The volatile load's result is
unused, and the harness is single-threaded, so dropping it is valid for the
proof lane (not for a concurrent allocator model).

The command above is a **self-comparison**. `syntactically equal` means Alive2
translated both modules; it is not a refinement result. For a real cell, use
two different modules (R vs C or R vs L) with matched signatures and record
the direction.

Known Alive2 blockers:

| Feature | Result |
|---|---|
| `noalias`, `nocapture`, `sret([N x i8])`, non-debug metadata | `Could not translate ... to Alive IR` |
| `load volatile` allocator guard | `Unsupported instruction` |
| `load atomic` / `atomicrmw` | `Unsupported instruction` |
| `invoke` / landing pads | unsupported; use the abort build |
| indirect calls (`call ptr`) | unsupported; remove at the seam/override |

## 7. Proposal-only `equiv-ffi` lane

Only after the patch policy is extended and approved. Use a separate dirty
worktree, never the clean one:

```sh
export RBTC_FFI=${RBTC_FFI:-$WORK/rbitcoin-ffi}
git -C "$RBTC" worktree add --detach "$RBTC_FFI" \
  ae47aa98174e04d0d8c493f13041daf65e4ac1d3
cd "$RBTC_FFI"
git apply "$SPEC/findings/rust/rbitcoin-ffi.patch"
git status --porcelain
```

Abort build (Alive2 lane):

```sh
cd "$RBTC_FFI"
export CARGO_TARGET_DIR="$WORK/target-188-ffi-abort"
cargo +1.88.0 rustc --release --ignore-rust-version \
  -p rbitcoin-consensus --features equiv-ffi --lib -- \
  --emit=llvm-ir,llvm-bc -C lto=no -C panic=abort
```

Unwind build (contract result-3 lane):

```sh
export CARGO_TARGET_DIR="$WORK/target-188-ffi-unwind"
cargo +1.88.0 rustc --release --ignore-rust-version \
  -p rbitcoin-consensus --features equiv-ffi --lib -- \
  --emit=llvm-ir -C lto=no -C panic=unwind
```

The abort build exposes `rbtc_rust_verify` (7 args) with 0 `invoke`; the unwind
build has 2,895 `invoke`, 764 `landingpad`, 349 `resume`. Expected hashes are in
`findings/rust/artifacts.md`. Do not cite these as green.

For the SAW entry probe, internalize the abort module to the entry:

```sh
FFI_BC=$(ls -t "$WORK/target-188-ffi-abort"/release/deps/rbitcoin_consensus-*.bc | head -1)
opt -passes='internalize,globaldce' \
    -internalize-public-api-list=rbtc_rust_verify \
    "$FFI_BC" -o "$WORK/out/bc/rbitcoin_entry.bc"
```

Staticlib C-ABI smoke (also proposal-only):

```sh
mkdir -p "$WORK/shimtest/src"
cat > "$WORK/shimtest/Cargo.toml" <<EOF
[package]
name = "rbtc-equiv-shim"
version = "0.0.0"
edition = "2021"
publish = false

[lib]
crate-type = ["staticlib"]

[dependencies]
rbitcoin-consensus = { path = "$RBTC_FFI/crates/rbitcoin-consensus", features = ["equiv-ffi"] }
EOF
cat > "$WORK/shimtest/src/lib.rs" <<'EOF'
#[no_mangle]
pub extern "C" fn entry(
    tx_bytes: *const u8, tx_len: usize,
    spk: *const u8, spk_len: usize,
    amount: i64, input_index: u32, flags: u64,
) -> i32 {
    unsafe {
        rbitcoin_consensus::rbtc_rust_verify(
            tx_bytes, tx_len, spk, spk_len, amount, input_index, flags)
    }
}
EOF
cat > "$WORK/shimtest/main.c" <<'EOF'
#include <stdint.h>
#include <stdio.h>
#include <string.h>

extern int entry(const uint8_t*, uint64_t, const uint8_t*, uint64_t,
                 int64_t, uint32_t, uint64_t);

static size_t hex2bin(const char *h, uint8_t *out) {
    size_t n = 0;
    while (h[0] && h[1]) {
        unsigned v; sscanf(h, "%2x", &v); out[n++] = (uint8_t)v; h += 2;
    }
    return n;
}

int main(void) {
    const char *txhex =
        "0200000001000000000000000000000000000000000000000000000000000000"
        "0000000000ffffffff00ffffffff010000000000000000015100000000";
    uint8_t tx[256];
    size_t n = hex2bin(txhex, tx);
    const uint8_t spk_true[] = {0x51};
    const uint8_t spk_false[] = {0x00};
    printf("tx_len=%zu\n", n);
    printf("pass   = %d (want 1)\n", entry(tx, n, spk_true, 1, 0, 0, 0));
    printf("fail   = %d (want 0)\n", entry(tx, n, spk_false, 1, 0, 0, 0));
    printf("badidx = %d (want 2)\n", entry(tx, n, spk_true, 1, 0, 1, 0));
    printf("badlen = %d (want 2)\n", entry(tx, 3, spk_true, 1, 0, 0, 0));
    return 0;
}
EOF
cd "$WORK/shimtest"
CARGO_TARGET_DIR="$WORK/target-188-shim" \
  cargo +1.88.0 build --release --ignore-rust-version
gcc -O2 main.c "$WORK/target-188-shim/release/librbtc_equiv_shim.a" \
  -lpthread -ldl -lm -o main188
./main188
```

Expected:

```text
tx_len=61
pass   = 1 (want 1)
fail   = 0 (want 0)
badidx = 2 (want 2)
badlen = 2 (want 2)
```

This validates the 7-argument name/order/result mapping only. It does not
implement the normative 8-argument `equiv_entry`.

## 8. Normative ABI wiring (CONTRACT-owned)

`shims/rust/entry.rs` must export both:

```c
extern "C" int equiv_entry(..., equiv_error_kind *error_kind);  /* normative */
extern "C" int entry(..., /* 7 args */);                        /* wrapper */
```

Required body shape (do not add engine logic):

1. Validate the tape/domain; on violation write `EQUIV_ERR_UNKNOWN_ERROR` and
   return 2.
2. Call `rbtc_rust_verify(...)` (or the approved clean equivalent).
3. Map `1 -> EQUIV_ERR_OK`; map `2/3 -> EQUIV_ERR_UNKNOWN_ERROR`; map `0` to
   the Core `ScriptError` ordinal. Step 3 is blocked until R-GAP-01 is fixed:
   rbitcoin exposes `ConsensusError::Script(String)`, not ordinals.
4. Keep `catch_unwind` in the unwind build; never let a panic cross
   `extern "C"`. Do not build the normative shim with `panic=abort`.

The 7-argument FFI patch has no `error_kind` out-param. It cannot satisfy
ABI v2 as-is. Also reject a null `tx_bytes` before forming a slice; the current
proposal's `(is_null && len != 0)` check lets `null + 0` reach
`from_raw_parts`, which is UB (R-GAP-05).

## 9. Trust and patch policy

- Official R artifacts: clean worktree, no source patch, 1.88.0/LLVM 20.
- `rbitcoin-ffi.patch`: proposal only. `patches/README.md` authorizes Core C++
  patches; extending it to rbitcoin needs a finding and approval. Until then,
  the patched artifact cannot be a green cell.
- The 1.88 front-end is not the repo's 1.95 pin. PINS must record it as a
  proof-lane toolchain or R must be declared SAW-only/Alive2-inapplicable.
- No claim of equivalence from a self-comparison or a no-postcondition SAW
  spec.

## 10. Known build/test failures (recorded, not workarounds)

| Symptom | Cause | Action |
|---|---|---|
| `use of unstable library feature 'round_char_boundary'` / `floor_char_boundary` | `rbitcoin-log` dev-dependency on 1.88 | Use 1.95 for `cargo test`, or `--lib` build only; not on the proof lane |
| `options -C embed-bitcode=no and -C lto are incompatible` | rustc 1.88 LTO/bitcode flags | Drop `-C embed-bitcode`; `-C lto=no` is enough |
| SAW `PtrOpaque` / `FUNC_CODE_INST_ATOMICRMW` | whole module's mpsc drop glue | Use a call-graph closure (§4) |
| SAW `llvm.usub.sat.i64` missing | transaction decoder intrinsic | Add an override/rewrite; not yet implemented |
| Alive2 `Unsupported attribute` | Rust `noalias`/`nocapture`/`sret` | `sanitize_ir.sh` |
| Alive2 `load volatile ... __rust_no_alloc_shim_is_unstable` | Rust allocator guard | Drop the unused load in the single-threaded harness |
| SAW `Memory store failed` on sret | 1.6 quirk with `[N x i8]` sret alloc | Allocate `[N/8 x i64]` |
| `abc: posix_spawnp: does not exist` | solver not on PATH | `export PATH=/opt/equiv-tools/saw-1.6/bin:$PATH` |
