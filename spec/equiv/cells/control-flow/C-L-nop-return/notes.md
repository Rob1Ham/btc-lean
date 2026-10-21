# control/C-L-nop-return

This cell closes the narrow, operand-free rules SCR-069 (OP_RETURN is an
error), SCR-071 (NOP1 and NOP4..NOP10 are no-ops and succeed), and SCR-072
(without flags they are plain NOPs).

The C side is a line-cited slice of Core's opcode cases. The L side uses the
twin's `OP_NOP`, `OP_RETURN`, and `OP_NOP_UPGRADABLE` handler bodies copied
verbatim by `cells/_tools/mk_leaf.py`. The four functions are closed; the
tools therefore prove/compare the exact witnesses, not a symbolic op law.
That is sufficient for these rows because the rows are themselves closed op
semantics and the coverage claim is limited to flags=0.

The `OP_NOP_UPGRADABLE` policy branch (`DISCOURAGE_UPGRADABLE_NOPS`) is not
exercised: the cell is the SCR-072 flag-free premise. A policy-flag cell is a
separate E2/E4 gap, not a hidden extension of this one.
