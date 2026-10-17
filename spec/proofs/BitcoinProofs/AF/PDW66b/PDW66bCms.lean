import BitcoinProofs.Theorems.Ops.O09

/-! # PDW66bCms — SWT-064/065: NULLDUMMY gate + unconditional dummy pop. -/

namespace BitcoinProofs.AF.PDW66b

open Bitcoin.Interpreter Bitcoin.Data
open BitcoinProofs.Theorems.Ops.O09

set_option maxHeartbeats 1000000

/-- SWT-064: with the consensus NULLDUMMY flag, a non-empty CHECKMULTISIG
dummy is rejected (`SIG_NULLDUMMY`) — interpreter.cpp:1209-1213. -/
@[rule "SWT-064"]
theorem cms_nulldummy_nonempty :
    stepBody { ctx0 with flags := { nullDummy := true } } opCMS
        { st0 with stack := [enc 0, enc 0, serU8 7] } = .error .sigNullDummy :=
  cms_nulldummy_concrete.1

/-- SWT-065: with NULLDUMMY off the dummy is popped unconditionally; a
non-empty dummy still yields success and is discarded. -/
@[rule "SWT-065"]
theorem cms_dummy_consumed_unchecked :
    stepBody ctx0 opCMS { st0 with stack := [enc 0, enc 0, serU8 7, serU8 9] } =
      .ok { st0 with opCount := 1, stack := vchTrue :: [serU8 9] } :=
  cms_0of0_concrete

end BitcoinProofs.AF.PDW66b
