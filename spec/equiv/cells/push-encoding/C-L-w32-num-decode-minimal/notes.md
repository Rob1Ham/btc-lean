# push-encoding/C-L-w32-num-decode-minimal

SCR-051 partial: the shared decode step, not the call sites.

What is proved: for every five-byte operand, every length 0..7, both
`fRequireMinimal` values and both `nMaxNumSize` values (4 and 5), the C
`CScriptNum` constructor and the twin `decode_num` agree with the independent
Cryptol model (OK + value, or SCRIPTNUM).

Why this is **partial**:

1. **CLTV/CSV.** The imperative twin has no decode path for the active flag:
   `ops_ir.py` OP_CLTV/OP_CSV return `TWIN_OK` when the activation flag is
   off and `TWIN_INVALID_UNSUPPORTED` when it is on.  There is no L function
   for the "flag on, decode the operand" step, so the site cannot be compared
   at handler level.  A C-only excerpt would not be a cell.
2. **CHECKMULTISIG counts.** `CHECKMULTISIG` is not in the twin's opcode
   table at all (it is listed as unsupported in `twin/gen.py`'s IR dump).
3. **CHECKSIGADD number.** Under base/witnessV0 the twin returns BAD_OPCODE;
   the tapscript handler is the E4 seam (no Schnorr checker).
4. Even if those handler bodies existed, CLTV/CSV need tx context (locktime,
   sequence) and CMS needs key/sig data; neither is in the leaf ABI.

Smallest next experiments, in order:

- Add a bounded twin handler for the CLTV/CSV *decode step only* (no
  transaction comparison), keyed on the activation flag, then build a
  handler-level cell for the minimality branch.  This is a model change and
  needs review; it is not made here.
- For CMS, a count-only cell can be built once the twin has a CMS handler
  whose key/sig count decode precedes the signature checks.

The decode law itself is green on both tools, so the remaining gap is
integration, not the numeric rule.
