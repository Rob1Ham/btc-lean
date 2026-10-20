# push-encoding/C-L-w32-p2a-anchor

SCR-055 at the predicate level.

Both the C and L legs are four comparisons.  The C leg is the core of
`IsPayToAnchor`; the L leg is a reviewed transcription of the Lean
`isPayToAnchor` because the imperative twin has no anchor helper.  This is
called out in `spec.md` and is the main trust gap of the cell.

The serialized 4-byte script `51 02 4e 73` is recognised by the sibling cell
`push-encoding/C-L-w32-witness-program` (SCR-053) as witness v1 with program
length 2; this cell then recognises the program bytes as `4e73`.
