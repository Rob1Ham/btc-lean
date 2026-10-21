# Shims — build and trust rules

ABI version 2 (`EQUIV_ABI_VERSION` in `../contract/error_kind.h`). Each leg
exports the normative symbol:

```c
extern "C" int equiv_entry(
    const uint8_t *tx_bytes, uint64_t tx_len,
    const uint8_t *spk,      uint64_t spk_len,
    int64_t amount, uint32_t input_index, uint64_t flags,
    equiv_error_kind *error_kind);   /* mandatory, non-NULL */
```

and the non-normative 7-argument convenience wrapper (no out-parameter):

```c
extern "C" int entry(
    const uint8_t *tx_bytes, uint64_t tx_len,
    const uint8_t *spk,      uint64_t spk_len,
    int64_t amount, uint32_t input_index, uint64_t flags);
```

Result: `0` fail, `1` pass, `2` bad input, `3` internal. `error_kind` is an
`equiv_error_kind` value from `../contract/error_kind.h` (`tape.md` §1,
`ABI.md` §1–§2). The tape semantics, domain, and prevout convention are
`../contract/tape.md`. The error taxonomy is `../contract/error_enum.md`.

## The rule: no engine logic

A shim may only:

* check pointer/length pairs and the domain rules in `tape.md` §7;
* deserialize the tape (C: Core's `TX_WITH_WITNESS`; R: equivalent decoder);
* construct the engine's native arguments and call its verify entry point;
* catch boundary exceptions/panics and map the engine's error to the shared
  enum;
* return a contract result code.

A shim must **not**: interpret opcodes, compute sighashes, decide signature
validity, add policy checks, cache results, read clocks/environment/locale, or
"fix" an engine result. If a shim needs engine knowledge to compile, the
engine's API is wrong for this workstream — file a finding, do not grow the
shim. Every line is reviewed and every shim is part of the trust base
(`README.md` §11).

Both symbols per library. Never link two legs into one binary (duplicate
symbols); the harness loads them separately (`dlopen`/separate drivers).

## C leg — `core/entry.cpp`

Status: complete; **syntax-checked at the pin**, and **linked + smoke-tested**
on this host with g++ 13.3.0 against an unmodified sparse checkout of Core at
`cce32b168` (22 tape cases + the 7-arg wrapper, all matched; see
`findings/contract-report.md`). The recipe below is the one that worked, plus
notes for the pieces a real build needs.

Core is used **unmodified** at
`cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.

```sh
CORE_SRC=/path/to/bitcoin            # checkout at the pin
SPEC=/path/to/btc-lean-public/spec/equiv
CXX=${CXX:-clang++}                  # pinned clang for IR artifacts

# 1. Shim + Core objects (the source list mirrors rbitcoin's build.rs,
#    plus the SHA-256 backend and file-I/O helper pulled in at this pin).
$CXX -std=c++20 -O0 -g -fPIC -fno-omit-frame-pointer \
     -I "$SPEC/contract" -I "$CORE_SRC/src" \
     -I "$CORE_SRC/src/secp256k1/include" \
     -c "$SPEC/shims/core/entry.cpp" -o entry-core.o

for f in \
  script/interpreter.cpp script/script.cpp script/script_error.cpp \
  primitives/transaction.cpp pubkey.cpp hash.cpp uint256.cpp arith_uint256.cpp \
  crypto/ripemd160.cpp crypto/sha1.cpp crypto/sha256.cpp crypto/sha512.cpp \
  crypto/hmac_sha512.cpp crypto/hex_base.cpp crypto/sha256_sse4.cpp \
  util/strencodings.cpp streams.cpp support/cleanse.cpp
do
  $CXX -std=c++20 -O0 -g -fPIC -I "$CORE_SRC/src" \
       -I "$CORE_SRC/src/secp256k1/include" \
       -c "$CORE_SRC/src/$f" -o "core-$(basename "$f" .cpp).o" || exit 1
done

# 2. libsecp256k1 (same defines as rbitcoin script-oracle/build.rs).
cc -O2 -I "$CORE_SRC/src/secp256k1/include" -I "$CORE_SRC/src/secp256k1/src" \
   -DENABLE_MODULE_SCHNORRSIG=1 -DENABLE_MODULE_EXTRAKEYS=1 \
   -DENABLE_MODULE_ELLSWIFT=1 -DENABLE_MODULE_RECOVERY=1 \
   -DECMULT_WINDOW_SIZE=15 -DECMULT_GEN_PREC_BITS=4 \
   -DUSE_FIELD_5X52=1 -DUSE_SCALAR_4X64=1 -DHAVE___INT128=1 \
   -c "$CORE_SRC/src/secp256k1/src/secp256k1.c" -o secp.o
cc -O2 -I "$CORE_SRC/src/secp256k1/include" -I "$CORE_SRC/src/secp256k1/src" \
   -DENABLE_MODULE_SCHNORRSIG=1 -DENABLE_MODULE_EXTRAKEYS=1 \
   -DENABLE_MODULE_ELLSWIFT=1 -DENABLE_MODULE_RECOVERY=1 \
   -DECMULT_WINDOW_SIZE=15 -DECMULT_GEN_PREC_BITS=4 \
   -DUSE_FIELD_5X52=1 -DUSE_SCALAR_4X64=1 -DHAVE___INT128=1 \
   -c "$CORE_SRC/src/secp256k1/src/precomputed_ecmult.c" -o ecmult.o
cc -O2 -I "$CORE_SRC/src/secp256k1/include" -I "$CORE_SRC/src/secp256k1/src" \
   -DENABLE_MODULE_SCHNORRSIG=1 -DENABLE_MODULE_EXTRAKEYS=1 \
   -DENABLE_MODULE_ELLSWIFT=1 -DENABLE_MODULE_RECOVERY=1 \
   -DECMULT_WINDOW_SIZE=15 -DECMULT_GEN_PREC_BITS=4 \
   -DUSE_FIELD_5X52=1 -DUSE_SCALAR_4X64=1 -DHAVE___INT128=1 \
   -c "$CORE_SRC/src/secp256k1/src/precomputed_ecmult_gen.c" -o ecmult_gen.o

# 3. Shared library.
$CXX -shared -o libequiv-core.so entry-core.o core-*.o secp.o ecmult.o ecmult_gen.o
```

Notes:

* `script_verify_flags` requires C++20 (`consteval`, `using enum`). Older
  compilers fail; that is intended.
* `-fPIC` is required for the shared-library link; omitting it fails with
  `relocation R_X86_64_PC32 ... can not be used when making a shared object`.
* `crypto/sha256_sse4.cpp` supplies `sha256_sse4::Transform`, referenced by
  `crypto/sha256.cpp` on this pin/x86-64. Other hosts need the matching
  backend (`sha256_avx2.cpp`, `sha256_x86_shani.cpp`, `sha256_arm_shani.cpp`)
  chosen the way Core's CMake build does.
* `streams.cpp` references `FileCommit`/`TruncateFile` from
  `util/fs_helpers.cpp` even though `VerifyScript` never calls them.
  `fs_helpers.cpp` needs the generated `bitcoin-build-config.h` and pulls
  `random.h`, `sync.h`, `util/log.h`, etc. Recommended: let Core's CMake
  configure generate `bitcoin-build-config.h` and add `util/fs_helpers.cpp`
  plus its dependencies. The smoke test used a **test-only** TU defining those
  two file helpers (outside the shim, never called by the engine); that is
  acceptable for a behavioral smoke test but **not** for a proof artifact.
  TODO(CORE-IR/TOOLS): capture the canonical object list from Core's build
  system instead of this hand list.
* Build the Core objects with the **same** compiler/flags as the shim for the
  differential build. For IR artifacts add `-S -emit-llvm` and keep `-O0` as
  the primary lane (`-O1` robustness lane per `PINS.lock`).
* Core's own build system is not required for this TU, but it is the
  authoritative source of any additional transitive objects. If the link
  reports missing symbols, add the producing Core `.cpp`; do not stub it.
* The shim needs exceptions enabled; do not compile with `-fno-exceptions`.
* `NDEBUG` is **not** set in the recipe: debug asserts stay active. The shim's
  domain checks make the asserts unreachable for in-domain tapes.

## L leg — `twin/entry.cpp`

Status: **stub** (returns `3`, `EQUIV_ERR_UNKNOWN_ERROR`). TWIN replaces the
body and adds its objects. The skeleton compiles today:

```sh
g++ -std=c++20 -c shims/twin/entry.cpp -I contract -o twin.o
```

The filled shim must return the same codes and map twin failures onto
`error_kind.h`. It must not call Core (that would make the L/C comparison
circular); Core may only appear in differential test drivers outside the shim.

## R leg — `rust/entry.rs`

Status: **stub** (returns `3`, `EQUIV_ERR_UNKNOWN_ERROR`). Verified to compile
and export `equiv_entry` + `entry` with rustc 1.99.0:

```sh
rustc --edition 2021 --crate-type cdylib -C panic=unwind -C opt-level=0 \
      shims/rust/entry.rs -o libequiv-rust.so
```

IR lane:

```sh
rustc --edition 2021 --crate-type cdylib -C panic=unwind -C opt-level=0 \
      --emit=llvm-ir shims/rust/entry.rs -o entry-rust.ll
```

RUST-IR replaces the closure body with the rbitcoin engine call and the error
mapping. Constraints:

* `catch_unwind` must remain at the boundary; a panic crossing `extern "C"` is
  UB and violates the contract. `panic=abort` is therefore not allowed.
* The panic hook may print to stderr; harnesses must ignore stderr and compare
  only `(result, error_kind)`.
* Use `AssertUnwindSafe` deliberately, not to hide shared mutable state. The
  engine call must be a pure function of the tape (`ABI.md` §7).
* Keep a single `#[no_mangle] extern "C" fn equiv_entry` plus the 7-argument
  wrapper; no Rust types in the ABI. The out-parameter is `*mut i32`
  (C `equiv_error_kind *`); the enum is 32-bit by static assertion.

## ABI smoke test

A driver can load any leg and call `equiv_entry` with, e.g., null/empty
buffers and a local kind, and `entry` with the same tape. The stubs return
`(3, EQUIV_ERR_UNKNOWN_ERROR)` and `3` respectively by design. C callers must
declare the exact signatures above; C++ callers should not rely on name
mangling (`extern "C"`).

## Open build items

* TODO(CORE-IR/TOOLS): exercise the C link recipe, record exact object list,
  clang version and IR hashes in `PINS.lock`.
* TODO(RUST-IR): pin rbitcoin commit and crypto path; record rustc LLVM
  version and whether it can be ingested by the pinned SAW (`README.md` §3).
* TODO(TOOLS): a `build_shims.sh` that emits all three libraries and their
  IR into `results/` reproducibly. Nothing in this directory should be built
  by hand in CI once that exists.
