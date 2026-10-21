# Tool installation and pins (E0)

Status: **TOOLS role, executed 2026-10-19 on Ubuntu 24.04 (noble), x86_64, 16 cores.**
Everything marked *executed* below was actually run in this environment. Steps
marked *recommended / not executed* are not part of the E0 trust base.

The pins recorded here are the ones written to `PINS.lock` under `[tools]`.
`[llvm]` is intentionally left for the CORE-IR/TOOLS pin decision; this file
records what was verified.

## Summary of verified versions

| Component | Verified version | Path / source | Status |
|---|---|---|---|
| z3 | 4.8.12 | Ubuntu `z3`, `/usr/bin/z3`, `libz3-dev` | executed |
| clang | 20.1.2 | `clang-20`, `/usr/bin/clang-20` | executed |
| LLVM | 20.1.2 | `llvm-20`, `llvm-20-dev`, `/usr/lib/llvm-20` | executed |
| Alive2 | v20.0 (`c0f5434f402ad91714ee0952f686cd0f524920ad`) | built from source; `/opt/equiv-tools/alive-tv-v20.0` | executed |
| SAW | 1.6 (`68eed5f release-1.6`) | official Ubuntu 24.04 X64 + solvers tarball; `/opt/equiv-tools/saw-1.6` | executed |
| cvc5 | 1.3.1 | shipped in SAW 1.6 bundle | executed |
| re2c | 3.1 | Ubuntu `re2c` (Alive2 build dep) | executed |
| ninja | 1.11.1 | Ubuntu `ninja-build` | executed |

Not installed / not claimed: **kani**, **miri**, **rustc pin** (owned by
RUST-IR; see `PINS.lock`). No Docker fallback was needed.

## 1. System packages (executed)

```sh
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  clang-18 llvm-18 llvm-18-dev lld-18 ninja-build libz3-dev z3 unzip curl
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  re2c libzstd-dev zlib1g-dev libcurl4-openssl-dev libedit-dev libxml2-dev
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  llvm-20 llvm-20-dev clang-20 lld-20
```

Why both LLVM 18 and 20: Ubuntu's default is 18, but Alive2 **v20.0** is built
against LLVM 20. LLVM 18 was installed first and retained; it is not the pin.

Verification actually run:

```console
$ clang-20 --version
Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)
Target: x86_64-pc-linux-gnu
$ llvm-config-20 --version
20.1.2
$ llvm-config-20 --has-rtti
YES
$ z3 --version
Z3 version 4.8.12 - 64 bit
$ ninja --version
1.11.1
$ re2c --version
re2c 3.1
```

Notes:
- Ubuntu's unversioned `clang` package (18) is **not** installed; use
  `clang-20` explicitly or the symlink below. Do not silently fall back to
  `clang` 18 when emitting pinned IR.
- LLVM must be built with RTTI for Alive2 `BUILD_LLVM_UTILS`; Ubuntu's LLVM 20
  reports `--has-rtti = YES` (verified).

## 2. Alive2 v20.0 (executed)

The current Alive2 `master` (checked out 2026-10-19) tracks newer LLVM and does
**not** compile against LLVM 18 or 20. First failure, for the record:

```text
llvm_util/llvm2alive.cpp:1721: error: 'const class llvm::Attribute' has no member named 'getInitializes'
llvm_util/llvm2alive.cpp:1737: error: 'NoFreeObj' is not a member of 'llvm::Attribute'
llvm_util/llvm2alive.cpp:1839: error: 'DenormalFPEnv' is not a member of 'llvm::Attribute'
```

Fix: pin the released **v20.0** tag, which matches LLVM 20.

```sh
mkdir -p /tmp/opencode/equiv-work
cd /tmp/opencode/equiv-work
git clone https://github.com/AliveToolkit/alive2.git alive2
cd alive2
git checkout v20.0
# c0f5434f402ad91714ee0952f686cd0f524920ad

cmake -S . -B build -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_LLVM_UTILS=ON \
  -DLLVM_DIR=/usr/lib/llvm-20/lib/cmake/llvm
ninja -C build -j16 alive-tv
```

Only the `alive-tv` target was built. This is sufficient for file-to-file
equivalence and avoids unrelated tools (`quick-fuzz`) whose LLVM API usage is
more brittle. CMake found Z3 4.8.12 at `/usr/include` +
`/usr/lib/x86_64-linux-gnu/libz3.so`.

Stable install + PATH (executed):

```sh
sudo mkdir -p /opt/equiv-tools
sudo cp /tmp/opencode/equiv-work/alive2/build/alive-tv /opt/equiv-tools/alive-tv-v20.0
sudo ln -sf /opt/equiv-tools/alive-tv-v20.0 /usr/local/bin/alive-tv
alive-tv --version
# Ubuntu LLVM version 20.1.2
#   Optimized build.
```

`alive-tv --version` reports the LLVM version, **not** the Alive2 tag; the
Alive2 identity is the git commit above. `ldd` confirms linkage to system
`libz3.so.4`.

## 3. SAW 1.6 (executed, official prebuilt)

Checked the GitHub releases API; `v1.6` (2026-09-17) publishes Ubuntu 24.04
X64 assets. Downloaded the bundle **with solvers** (abc/cvc5/z3/yices/etc.):

```sh
cd /tmp/opencode/equiv-work
curl -L --fail -o saw-1.6-ubuntu-24.04-X64-with-solvers.tar.gz \
  https://github.com/GaloisInc/saw-script/releases/download/v1.6/saw-1.6-ubuntu-24.04-X64-with-solvers.tar.gz
sha256sum saw-1.6-ubuntu-24.04-X64-with-solvers.tar.gz
# 0b25c8b32db8b4a7ec32d6700024af60bb2a0398ee350b630dd84ff377c938f7

mkdir -p saw
tar -xzf saw-1.6-ubuntu-24.04-X64-with-solvers.tar.gz -C saw --strip-components=1
saw/bin/saw --version
# 1.6 (68eed5f release-1.6)
```

Stable install + PATH (executed):

```sh
sudo rm -rf /opt/equiv-tools/saw-1.6
sudo cp -a /tmp/opencode/equiv-work/saw /opt/equiv-tools/saw-1.6
sudo ln -sf /opt/equiv-tools/saw-1.6/bin/saw /usr/local/bin/saw
sudo ln -sf /opt/equiv-tools/saw-1.6/bin/cvc5 /usr/local/bin/cvc5
cvc5 --version   # cvc5 version 1.3.1 [git ea1b484fa]
```

**PATH is load-bearing.** `llvm_verify ... abc` spawns the bundled `abc`
solver by name. If `/opt/equiv-tools/saw-1.6/bin` is not on `PATH`, SAW reports:

```text
abc: readCreateProcessWithExitCode: posix_spawnp: does not exist (No such file or directory)
```

The helper scripts in this directory prepend the bundle `bin/` to `PATH`.

SAW 1.6 successfully loaded LLVM 20.1.2 bitcode emitted by `clang-20`.
The maximum supported LLVM bitcode version was not probed beyond that; see the
capability matrix.

## 4. E0 smoke tests (executed)

```sh
cd spec/equiv
alive-tv tools/tests/hello-a.ll tools/tests/hello-b.ll
# 2 correct transformations; exit 0
alive-tv tools/tests/hello-a.ll tools/tests/hello-bad.ll
# 1 incorrect transformation + counterexample; NOTE: exit code is still 0
PATH=/opt/equiv-tools/saw-1.6/bin:$PATH \
  saw tools/tests/hello.saw
# Proof succeeded (id32, add_one); prints SAW_E0_HELLO_OK; exit 0
```

Logs: `findings/tools/alive2-hello.out`,
`findings/tools/alive2-hello-bad.out`, `findings/tools/saw-hello.out`,
`findings/tools/saw-hello-nsw-poison.out` (a real `nsw` poison finding).

## 5. Kani / Miri notes for the Rust leg (NOT executed)

These are recommendations only; RUST-IR owns the Rust pins. Do not cite them
as verified.

- **Kani** (MIR → CBMC; checks panic/UB-ish properties, not LLVM refinement):
  ```sh
  cargo install --locked kani-verifier
  cargo kani setup            # downloads the matching CBMC bundle
  cargo kani --version
  ```
  Pin the `kani-verifier` crate version in `PINS.lock` before any result.
- **Miri** (UB interpreter; needs a nightly toolchain, not the pinned stable):
  ```sh
  rustup toolchain install nightly-YYYY-MM-DD
  rustup +nightly-YYYY-MM-DD component add miri
  cargo +nightly-YYYY-MM-DD miri test
  ```
  Pin the exact nightly date; Miri results are interpreter evidence, not an
  LLVM IR equivalence proof.

## 6. Reproducibility caveats

- `/opt/equiv-tools` is outside the repository. The build recipe above is the
  reproducible source of truth; the `/opt` copy is only a stable PATH target.
- Do not upgrade `z3` under Alive2 without rebuilding: the binary is linked
  against `libz3.so.4` (4.8.12). SAW's own solvers are self-contained in its
  bundle.
- Alive2 `alive-tv` returns **0 even when it prints "Transformation doesn't
  verify!"**. All gates must parse the report, never trust the exit code. This
  was verified with `hello-bad.ll`.
