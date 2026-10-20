# stack-ops/C-L-ifdup

Closes SCR-077 (OP_IFDUP) with four bounded entries: empty stack, one
zero-length element, depth 1 with a symbolic top byte, and depth 2 with two
symbolic lower bytes plus a symbolic top byte.

## Why these entries

`OP_IFDUP` is small but has two easy-to-miss false cases:

- the empty vector (`len == 0`);
- the one-byte negative zero `0x80`.

The symbolic `v0` entry ranges over all 256 one-byte encodings, so `0x00`,
`0x80` and every true value are all covered without enumerating them. The
zero-length entry supplies the empty-vector branch that a one-byte input
cannot represent. The depth-2 entry checks that the copy is made from the top
and that the lower elements keep their order; a duplicate or a reordering
would change the packed slots.

## Branches

1. **Budget first.** The empty-stack entry has symbolic nOpCount, so it proves
   that nOpCount 201 returns OP_COUNT (7) even though the opcode would also
   fail with INVALID_STACK_OPERATION (18). TAPSCRIPT charges nothing.
2. **Underflow.** Empty stack -> 18.
3. **False, no duplication.** Zero-length and `0x00`/`0x80` leave the stack
   exactly as seeded.
4. **True, duplicate.** Every other one-byte value appends a copy of the top.
   At depth 1 the result is `[v,v]`; at depth 2 it is `[e0,e1,v,v]`, the
   four-slot maximum.

The observable is `pack_l4`, which exposes the depth and all four slots as
(length, low byte); every element here is at most one byte.

## Trust

C is a line-cited slice of the budget gate and the IFDUP case, with the
CastToBool transcription using the same 0x80 rule as `interpreter.cpp:46-59`.
L calls the handler generated verbatim from `twin/ops_ir.py` by
`cells/_tools/mk_leaf.py`, inside a mirror of `twin/runtime.inc:594-652`.
`cell.cry` is written from the rules and puts the duplicated slot explicitly.
Both tools run at `-O1` from the same source for both legs. No source patch.
