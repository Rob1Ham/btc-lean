from: orchestrator
to: TWIN
status: open
artifacts:
  - spec/equiv/twin/gen.py (generated twin; `twin_entry` + 7-arg `entry`)
  - spec/equiv/contract/ABI.md (contract §1/§4: tx carries scriptSig, spk separate)
  - spec/equiv/contract/error_kind.h (Core ScriptError ordinals, authoritative)
  - spec/equiv/corpus/selections/*.jsonl (pinned family selections)
ask: |
  Three concrete changes before the twin can enter any E1 cell:
  (1) Decode the input `scriptSig` from `tx_bytes` (TX_WITH_WITNESS at the
      contract pin) and evaluate it before `spk`, with the exact VerifyScript
      ordering. Today `twin_entry` ignores `tx_bytes` and assumes an empty
      scriptSig.
  (2) Accept `flags != 0` at least for P2SH (wrapper detection) and treat the
      policy-only flags as explicitly inert with a recorded justification;
      today every flagged row returns result 3.
  (3) At the boundary emit Core ScriptError ordinals from
      `contract/error_kind.h`, not the Lean-constructor-derived TwinErr ids
      (e.g. EVAL_FALSE is 2 in Core but 14 in the current twin enum). Keep
      TwinErr internally; add a total mapping plus a static assertion that
      every TwinErr has a Core ordinal. ABI.md §3 makes Core's enum the
      reference and a mapping divergence a finding.
blockers: none (ABI + pinned corpus are present)
evidence: |
  $ python3 - <<'PY'  # over corpus/selections/*.jsonl
  stack  n=316 empty_scriptSig=50 flags_empty=42 both(usable domain)=0
  flow   n=297 empty_scriptSig=24 flags_empty=2  both=1
  numeric n=335 empty_scriptSig=7 flags_empty=69 both=0
  ...
  Current twin domain (empty sig AND flags==0) contains 0/1258 corpus rows.
  Error-id mismatch example: TWIN_EVAL_FALSE = 14; EQUIV_ERR_EVAL_FALSE = 2.
