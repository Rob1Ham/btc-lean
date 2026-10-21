#!/bin/sh
# Reproduce the R-leg E0 tool-capability matrix.
# Needs rustup toolchains 1.88.0/1.95.0/1.99.0, LLVM 20 tools, and SAW 1.6
# with its solvers on PATH (the OpenCode work dir's saw/bin).
set -e
LLVM=/usr/lib/llvm-20/bin
for tc in 1.88.0 1.95.0 1.99.0; do
  rustc +$tc --crate-type=lib --emit=llvm-bc -C opt-level=0 -C panic=abort \
        -o rust_hello_$tc.bc rust_hello.rs
  rustc +$tc --crate-type=lib --emit=llvm-ir -C opt-level=0 -C panic=abort \
        -o rust_hello_$tc.ll rust_hello.rs
  $LLVM/llvm-extract --func=add_one rust_hello_$tc.ll -S \
        -o add_one_$tc.ll
  sed -e "s/@BC@/rust_hello_$tc.bc/" -e "s/@TC@/$tc/" \
        rust_hello.saw.tmpl > rust_hello_$tc.saw
  alive-tv rust_hello_$tc.bc > alive2_$tc.out 2>&1 || true
  saw rust_hello_$tc.saw > saw_$tc.out 2>&1 || true
done
{
  echo "toolchain | LLVM | Alive2 | SAW"
  for tc in 1.88.0 1.95.0 1.99.0; do
    llvm=$(rustc +$tc -Vv | sed -n 's/^LLVM version: //p')
    a=$(grep -q '1 correct transformations' alive2_$tc.out && echo PASS || echo FAIL)
    s=$(grep -q "SAW_${tc}_OK" saw_$tc.out && echo PASS || echo FAIL)
    echo "$tc | $llvm | $a | $s"
  done
} > matrix.txt
sha256sum rust_hello_1.88.0.ll rust_hello_1.95.0.ll rust_hello_1.99.0.ll \
          rust_hello_1.88.0.bc rust_hello_1.95.0.bc rust_hello_1.99.0.bc \
          > hashes.txt
cat matrix.txt
