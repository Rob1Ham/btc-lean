from: orchestrator
to: CONTRACT
status: open
artifacts:
  - spec/equiv/contract/ABI.md §1 (7-arg `entry`, no error out-param)
  - spec/equiv/contract/ABI.md §2 ("error_kind ... through a second, optional out-parameter")
  - spec/equiv/twin/gen.py (`twin_entry(..., int32_t* error_kind)` + 7-arg `entry`)
  - spec/equiv/contract/error_kind.h
ask: |
  Pin one normative symbol and signature for all three legs, because §1 and
  §2 currently disagree and the twin already ships both forms. Recommended:
    extern "C" int32_t equiv_entry(const uint8_t*, uint64_t, const uint8_t*,
        uint64_t, int64_t, uint32_t, uint64_t, equiv_error_kind*);
  with status 0..3 as the return and the error kind mandatory (not
  "optional"), plus a documented 7-argument convenience wrapper only if a leg
  needs it. Then: bump an explicit ABI version, record the ABI.md hash in
  PINS.lock, and state that E3's error-enum equality is judged on the
  out-parameter. The Rust and Core shims must use exactly this symbol.
blockers: none
evidence: |
  $ grep -n "extern \"C\"" spec/equiv/twin/gen.py
  extern "C" int twin_entry(..., int32_t* error_kind)
  extern "C" int entry(..., /* no error out-param */)
  ABI.md §1 shows only the 7-arg form; §2 makes error_kind optional.
