#!/usr/bin/env python3
"""Generate the SAW script for limits/C-L-scr-040-witness-budget.

The serializer loop is unrolled to the declared bound 8.  SAW's solver cost is
much lower when the item count is concrete, so the script checks every count
0..8 separately.  This is a complete case split for the declared bound (the
count is a uint32 and the precondition is <= 8), not a sample: each case uses
still-symbolic 32-bit item lengths.
"""
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "cell.saw"

HEADER = '''import "cell.cry";

// ---------------------------------------------------------------------------
// SCR-040 cell: C and L IR against the independent Cryptol byte-count spec.
//
// Three scalar functions x two legs = 6 function proofs, plus the serializer
// loop and budget checked at every count 0..8 (9 counts x 2 functions x 2 legs
// = 36 proofs).  The count is uint32; "every count 0..8" is the complete case
// split of the declared unrolling bound, with symbolic 32-bit lengths in each
// case.  Total llvm_verify proofs: 42.
//
// The proven statement is bounded to 8 items.  The arbitrary-count identity is
// a cell-local Lean theorem (src/lean/BudgetComposition.lean); the bridge from
// this C loop to the Lean fold is a reviewed premise and SCR-040 stays partial.
// ---------------------------------------------------------------------------
mCz <- llvm_load_module "c_cell_compact_size_size.bc";
mLz <- llvm_load_module "l_cell_compact_size_size.bc";
mCn <- llvm_load_module "c_cell_witness_budget_count.bc";
mLn <- llvm_load_module "l_cell_witness_budget_count.bc";
mCs <- llvm_load_module "c_cell_witness_item_step.bc";
mLs <- llvm_load_module "l_cell_witness_item_step.bc";
mCw <- llvm_load_module "c_cell_witness_serialized_size.bc";
mLw <- llvm_load_module "l_cell_witness_serialized_size.bc";
mCb <- llvm_load_module "c_cell_witness_budget.bc";
mLb <- llvm_load_module "l_cell_witness_budget.bc";

// GetSizeOfCompactSize over the full 64-bit domain: exercises the 9-byte
// branch (n > 0xffffffff), which a uint32 item length can never take.
let cs_size_spec = do {
  n <- llvm_fresh_var "n" (llvm_int 64);
  llvm_execute_func [llvm_term n];
  llvm_return (llvm_term {{ cs_size n }});
};
llvm_verify mCz "cell_compact_size_size" [] false cs_size_spec bitwuzla;
llvm_verify mLz "cell_compact_size_size" [] false cs_size_spec bitwuzla;

// Stack-count term: CompactSize(n_items) + 50 for every 32-bit count.
let budget_count_spec = do {
  ni <- llvm_fresh_var "n_items" (llvm_int 32);
  llvm_execute_func [llvm_term ni];
  llvm_return (llvm_term {{ budget_count ni }});
};
llvm_verify mCn "cell_witness_budget_count" [] false budget_count_spec bitwuzla;
llvm_verify mLn "cell_witness_budget_count" [] false budget_count_spec bitwuzla;

// One serializer element: acc + CompactSize(len) + len, for every 32-bit
// length and every accumulator in the non-negative executed-domain range.
// (The real budget is <= 4237 WU for any reachable 8-item stack, so this
// domain is a declared model bound, not an engine assumption.)
let item_step_spec = do {
  len <- llvm_fresh_var "len" (llvm_int 32);
  acc <- llvm_fresh_var "acc" (llvm_int 64);
  llvm_precond {{ (acc >=$ 0) && (acc <=$ 4611686018427387904) }};
  llvm_execute_func [llvm_term len, llvm_term acc];
  llvm_return (llvm_term {{ item_step len acc }});
};
llvm_verify mCs "cell_witness_item_step" [] false item_step_spec bitwuzla;
llvm_verify mLs "cell_witness_item_step" [] false item_step_spec bitwuzla;

'''


def loop_specs() -> str:
    out = []
    for k in range(9):
        out.append(f'''// ----- count = {k}: Core-shaped serializer loop, symbolic 32-bit lengths -----
let serialized_size_spec_{k} = do {{
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
  llvm_return (llvm_term {{{{ serialized_size ({k} : [32]) [l0, l1, l2, l3, l4, l5, l6, l7] }}}});
}};
llvm_verify mCw "cell_witness_serialized_size" [] false serialized_size_spec_{k} bitwuzla;
llvm_verify mLw "cell_witness_serialized_size" [] false serialized_size_spec_{k} bitwuzla;

let budget_spec_{k} = do {{
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
  llvm_return (llvm_term {{{{ budget ({k} : [32]) [l0, l1, l2, l3, l4, l5, l6, l7] }}}});
}};
llvm_verify mCb "cell_witness_budget" [] false budget_spec_{k} bitwuzla;
llvm_verify mLb "cell_witness_budget" [] false budget_spec_{k} bitwuzla;

''')
    return "".join(out)


FOOTER = '''// ---------------------------------------------------------------------------
// CompactSize / range lemmas.  `prove_print` is silent on success in SAW 1.6;
// each marker below is only printed if the preceding proof did not abort.
// ---------------------------------------------------------------------------

// Exact condition for the 9-byte branch.
prove_print bitwuzla {{ \\(n : [64]) -> (cs_size n == 9) == (n > t32) }};
print "PROVED lemma_cs_size_9byte_iff_gt_0xffffffff";

// A length representable in 32 bits never takes the 9-byte branch.
prove_print bitwuzla {{ \\(n : [32]) -> cs_size (zext n) != 9 }};
print "PROVED lemma_cs_size_no_9byte_for_uint32";

// The stack-count prefix for any accepted stack (<= MAX_STACK_SIZE = 1000)
// is 1 or 3 bytes.
prove_print bitwuzla {{ \\(n : [32]) -> (n <= 1000) ==> cs_size (zext n) <= 3 }};
print "PROVED lemma_cs_size_count_cap_1000";

// Any witness item that reaches tapscript execution is capped at
// MAX_SCRIPT_ELEMENT_SIZE = 520 bytes, so its per-item term <= 3 + 520.
prove_print bitwuzla {{ \\(l : [32]) -> (l <= 520) ==> cs_size (zext l) + zext l <= 523 }};
print "PROVED lemma_item_term_cap_520";

// Executed-domain range: an 8-item stack of <=520-byte items has budget
// <= 50 + 3 + 8*523 = 4237 WU, far inside int64_t.
prove_print bitwuzla {{
  \\(n : [32]) -> \\(ls : [8][32]) ->
    ((n <= 8) && (all (\\(l : [32]) -> l <= 520) ls)) ==> (budget n ls <= 4237)
}};
print "PROVED lemma_budget_range_8x520";

// The budget is exactly the serialized byte count plus the 50 WU offset.
prove_print bitwuzla {{
  \\(n : [32]) -> \\(ls : [8][32]) -> budget n ls == serialized_size n ls + 50
}};
print "PROVED lemma_budget_is_serialized_plus_50";

print "CELL_limits_C_L_scr_040_witness_budget_SAW_GREEN";
'''


def main() -> None:
    OUT.write_text(HEADER + loop_specs() + FOOTER)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
