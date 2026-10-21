# Pre-execution mutant plan M-E4-007-e4-cell

- time: 20261020T221110Z
- mutation: `M-E4-007` / `e4-cell`
- target: `spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/l_leg.cpp`
- target sha256 before: `387da37e4cd894e468007de249941906be9d91534d1d581ac8f9213a9c303840`
- expected cell: `cells/tapscript/C-L-tapscript-isopsuccess`
- cell spec sha256 before: `054d1a42aa584cb64397ec8d2c8dd71467a2ea2e4eb4a5f1c4b1f8ea3ae272f6`
- baseline before: alive2=`alive2-green`, saw=`saw-green (2/2 proofs)`

## Declared witness (written before mutation)

cell_is_op_success: opcode w=80 (0x50, OP_SUCCESS80). Baseline: both legs classify 80 as an OP_SUCCESS byte and return 1. Mutant drops the w==80 and w==98 arms, so w=80 returns 0 (the byte would be treated as a non-success/BAD_OPCODE). Expected: cell_is_op_success non-green on both tools.

## Declared mutation diff (mutate.py --dry-run)

```diff
DRY RUN — no write, no record
mutation:    M-E4-007 (e4-taproot)
target:      /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/l_leg.cpp
target kind: e4-cell
sha256 before: 387da37e4cd894e468007de249941906be9d91534d1d581ac8f9213a9c303840
sha256 after:  48bcbc2d010f8be3c36ddf80111896bea0fd4b5e69c3da481df3634f08208b01
expected failing cells: cells/tapscript/C-L-tapscript-isopsuccess
catchers: alive2, saw

--- a/spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/l_leg.cpp
+++ b/spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/l_leg.cpp
@@ -13,7 +13,7 @@
 //
 // The Nat domain is total, matching the C leg's total 64-bit input.
 TAP_INLINE uint64_t l_is_op_success(uint64_t w) {
-  const bool r = w == 80u || w == 98u || (126u <= w && w <= 129u) ||
+  const bool r = (126u <= w && w <= 129u) ||  // M-E4-007 mutant: drop OP_SUCCESS 80/98
                  (131u <= w && w <= 134u) || (137u <= w && w <= 138u) ||
                  (141u <= w && w <= 142u) || (149u <= w && w <= 153u) ||
                  (187u <= w && w <= 254u);
```

