#!/usr/bin/env python3
"""Generate the SAW script for limits/C-L-scr-040-loop-fold.

Function set (both legs, same ABI for Alive2 pairing):

  cell_compact_size_size(n)         GetSizeOfCompactSize, full 64-bit domain
  cell_basic_byte_ser(acc, len)     one element's serializer effect, arbitrary
                                    accumulator and 32-bit length
  cell_vector_ser(n, lens)          count prefix + element loop, counts 0..8
  cell_seed(n, lens)                vector_ser + 50

The C function for cell_vector_ser calls the element serializer
cell_basic_byte_ser for each element, so the SAW proof of cell_vector_ser is a
composition of the real per-element function, not a re-inlining of its
arithmetic.  SAW executes loops by unrolling, so every count 0..8 is checked
separately (a complete case split of the declared bound; lengths stay
symbolic).  The arbitrary-count closure is the Lean proof in
src/lean/LoopToFold.lean over the pinned source text.
"""
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "cell.saw"

HEADER = '''import "cell.cry";

// ---------------------------------------------------------------------------
// SCR-040 seed cell: C and L IR against the independent Cryptol byte-count
// spec.  Scalar proofs: 2 functions x 2 legs = 4.  Loop/budget proofs:
// 9 counts x 2 functions x 2 legs = 36.  Total llvm_verify: 40.
//
// cell_vector_ser's C body calls cell_basic_byte_ser once per element (the
// real per-element serializer), so the loop proof composes the proved element
// function.  The arbitrary-count bridge is Lean, not this bounded script.
// ---------------------------------------------------------------------------
mCz <- llvm_load_module "c_cell_compact_size_size.bc";
mLz <- llvm_load_module "l_cell_compact_size_size.bc";
mCi <- llvm_load_module "c_cell_basic_byte_ser.bc";
mLi <- llvm_load_module "l_cell_basic_byte_ser.bc";
mCv <- llvm_load_module "c_cell_vector_ser.bc";
mLv <- llvm_load_module "l_cell_vector_ser.bc";
mCs <- llvm_load_module "c_cell_seed.bc";
mLs <- llvm_load_module "l_cell_seed.bc";

// GetSizeOfCompactSize over the full 64-bit domain: exercises the 9-byte
// branch (n > 0xffffffff), which a uint32 item length can never take.
let cs_size_spec = do {
  n <- llvm_fresh_var "n" (llvm_int 64);
  llvm_execute_func [llvm_term n];
  llvm_return (llvm_term {{ cs_size n }});
};
llvm_verify mCz "cell_compact_size_size" [] false cs_size_spec bitwuzla;
llvm_verify mLz "cell_compact_size_size" [] false cs_size_spec bitwuzla;

// One element's serializer effect: acc + CompactSize(len) + len for every
// 32-bit length and every accumulator in the executed-domain range.
let basic_byte_spec = do {
  acc <- llvm_fresh_var "acc" (llvm_int 64);
  len <- llvm_fresh_var "len" (llvm_int 32);
  llvm_precond {{ (acc >=$ 0) && (acc <=$ 4611686018427387904) }};
  llvm_execute_func [llvm_term acc, llvm_term len];
  llvm_return (llvm_term {{ basic_step len acc }});
};
llvm_verify mCi "cell_basic_byte_ser" [] false basic_byte_spec bitwuzla;
llvm_verify mLi "cell_basic_byte_ser" [] false basic_byte_spec bitwuzla;

'''


def loop_specs() -> str:
    out = []
    for k in range(9):
        out.append(f'''// ----- count = {k}: vector serializer body, symbolic 32-bit lengths -----
let vector_ser_spec_{k} = do {{
  l0 <- llvm_fresh_var "l0" (llvm_int 32);
  l1 <- llvm_fresh_var "l1" (llvm_int 32);
  l2 <- llvm_fresh_var "l2" (llvm_int 32);
  l3 <- llvm_fresh_var "l3" (llvm_int 32);
  l4 <- llvm_fresh_var "l4" (llvm_int 32);
  l5 <- llvm_fresh_var "l5" (llvm_int 32);
  l6 <- llvm_fresh_var "l6" (llvm_int 32);
  l7 <- llvm_fresh_var "l7" (llvm_int 32);
  lens <- llvm_alloc_readonly (llvm_array 8 (llvm_int 32));
  llvm_points_to_at_type lens (llvm_array 8 (llvm_int 32))
    (llvm_array_value [llvm_term l0, llvm_term l1, llvm_term l2, llvm_term l3,
                       llvm_term l4, llvm_term l5, llvm_term l6, llvm_term l7]);
  llvm_execute_func [llvm_term {{{{ {k} : [32] }}}}, lens];
  llvm_return (llvm_term {{{{ vector_size ({k} : [32]) [l0, l1, l2, l3, l4, l5, l6, l7] }}}});
}};
llvm_verify mCv "cell_vector_ser" [] false vector_ser_spec_{k} bitwuzla;
llvm_verify mLv "cell_vector_ser" [] false vector_ser_spec_{k} bitwuzla;

let seed_spec_{k} = do {{
  l0 <- llvm_fresh_var "l0" (llvm_int 32);
  l1 <- llvm_fresh_var "l1" (llvm_int 32);
  l2 <- llvm_fresh_var "l2" (llvm_int 32);
  l3 <- llvm_fresh_var "l3" (llvm_int 32);
  l4 <- llvm_fresh_var "l4" (llvm_int 32);
  l5 <- llvm_fresh_var "l5" (llvm_int 32);
  l6 <- llvm_fresh_var "l6" (llvm_int 32);
  l7 <- llvm_fresh_var "l7" (llvm_int 32);
  lens <- llvm_alloc_readonly (llvm_array 8 (llvm_int 32));
  llvm_points_to_at_type lens (llvm_array 8 (llvm_int 32))
    (llvm_array_value [llvm_term l0, llvm_term l1, llvm_term l2, llvm_term l3,
                       llvm_term l4, llvm_term l5, llvm_term l6, llvm_term l7]);
  llvm_execute_func [llvm_term {{{{ {k} : [32] }}}}, lens];
  llvm_return (llvm_term {{{{ seed ({k} : [32]) [l0, l1, l2, l3, l4, l5, l6, l7] }}}});
}};
llvm_verify mCs "cell_seed" [] false seed_spec_{k} bitwuzla;
llvm_verify mLs "cell_seed" [] false seed_spec_{k} bitwuzla;

''')
    return "".join(out)


FOOTER = '''// ---------------------------------------------------------------------------
// CompactSize / composition lemmas.  `prove_print` is silent on success in SAW
// 1.6; each marker below is printed only if the preceding proof did not abort.
// ---------------------------------------------------------------------------

// Exact condition for the 9-byte branch.
prove_print bitwuzla {{ \\(n : [64]) -> (cs_size n == 9) == (n > t32) }};
print "PROVED lemma_cs_size_9byte_iff_gt_0xffffffff";

// A length representable in 32 bits never takes the 9-byte branch.
prove_print bitwuzla {{ \\(n : [32]) -> cs_size (zext n) != 9 }};
print "PROVED lemma_cs_size_no_9byte_for_uint32";

// A witness item that reaches tapscript execution is capped at
// MAX_SCRIPT_ELEMENT_SIZE = 520 bytes, so its per-item term <= 3 + 520.
prove_print bitwuzla {{ \\(l : [32]) -> (l <= 520) ==> cs_size (zext l) + zext l <= 523 }};
print "PROVED lemma_item_term_cap_520";

// Executed-domain range: an 8-item stack of <=520-byte items has
// seed <= 50 + 3 + 8*523 = 4237 WU, far inside int64_t.
prove_print bitwuzla {{
  \\(n : [32]) -> \\(ls : [8][32]) ->
    ((n <= 8) && (all (\\(l : [32]) -> l <= 520) ls)) ==> (seed n ls <= 4237)
}};
print "PROVED lemma_seed_range_8x520";

// count prefix + element fold: the empty stack is exactly csSize(0) + 50.
prove_print bitwuzla {{ \\() -> seed (0 : [32]) [0, 0, 0, 0, 0, 0, 0, 0] == 51 }};
print "PROVED lemma_empty_seed_51";

// The seed is exactly the vector SizeComputer count plus the 50 WU offset.
prove_print bitwuzla {{
  \\(n : [32]) -> \\(ls : [8][32]) -> seed n ls == vector_size n ls + 50
}};
print "PROVED lemma_seed_is_vector_size_plus_50";

print "CELL_limits_C_L_scr_040_loop_fold_SAW_GREEN";
'''


def main() -> None:
    OUT.write_text(HEADER + loop_specs() + FOOTER)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
