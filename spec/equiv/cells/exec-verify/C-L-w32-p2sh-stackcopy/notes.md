# C-L-w32-p2sh-stackcopy — notes

## What the observable is, and why

SCR-007 says "stackCopy (taken after scriptSig) is restored for subscript
eval".  To observe that dataflow without the EvalScript loop, the cell

- takes the post-scriptSig stack and the post-scriptPubKey stack as two
  independent symbolic stacks (depth 0..2, one-byte elements),
- records the redeemScript byte and the stack that
  `EvalScript(stack, pubKey2, ...)` (:2080) is called with,
- and proves both legs derive those values from the **post-scriptSig** stack
  (Core's `swap(stack, stackCopy)` at :2069, Lean's `p :: rest` on
  `stackCopy`).

If the restore were omitted or moved, the recorded redeem byte / stack would
come from the post-spk stack instead and the cell's equality would fail.  The
spec's `mutant:` field names that exact mutation.

## Different shapes on the two legs

- C: `if (flags & P2SH) stackCopy = stack;` then `swap(stack, stackCopy)`.
- L: `let stackCopy := stack1` (unconditional) and `p2shInner` destructures
  it.

The cell keeps the flag-conditional on the C side and shows the condition is
unobservable (the snapshot is only read inside the P2SH arm).  That is a
small but real C/L difference in shape, not a semantic gap.

## Stack representation

Head = top, as in Core's `vector::back()` and the Lean list head.  `popstack`
shifts the second element down; `x_popstack` in `x_common.h` is shared harness
code (Core `stack.pop_back()` at :479).  Depth is capped at 2, which only
projects out-of-domain inputs; the cell domain is depth <= 2.

## Tool notes

- Alive2 v20 and SAW 1.6 with z3.  `abc` did not finish this seven-argument
  cell inside 300 s; z3 proves it in ~2 s (`saw/solver.txt` records the
  choice).  The earlier abc timeout is not a proof result and is not cited.
- The first SAW attempt also exposed a spec/leg mismatch: the C leg masks
  `n_ops` to a byte before clamping, the first Cryptol revision did not.
  The corrected spec uses `% 256` then clamp.

## What a reviewer should check

1. That `redeem` is `stack.back()` of the **restored** stack (:2076) and the
   subscript stack is that stack after `popstack` (:2078).
2. That the post-spk stack only feeds :2037-2040 (empty/falsy) in this cell.
3. That the observable is the argument pair of :2080, not its result
   (execution is abstracted).
