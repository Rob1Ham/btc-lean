import Bitcoin.Interpreter.Defs

/-! # FindAndDelete regression checks (Test-scoped)

`FindAndDelete` must copy only the unmatched tail after the last match.
Before the `fdLastPc2` fix, the final `script.extract pc2 script.size`
started at the pre-match `pc2`, so a head/middle match re-appended the
already-deleted suffix (and a whole-tail match put the needle back).

These are executable checks; `native_decide` is allowed only in Test
files (D2 L1 convention). -/

open Bitcoin.Interpreter

namespace Bitcoin.Test.Script.Interpreter

/-- Whole-tail: the script is exactly the needle, so deletion leaves ∅. -/
example :
    findAndDelete (ByteArray.mk #[0x01, 0xaa]) (ByteArray.mk #[0x01, 0xaa]) =
      (1, ByteArray.empty) := by
  native_decide

/-- Head match: the suffix is preserved exactly once. -/
example :
    findAndDelete (ByteArray.mk #[0x01, 0xaa, 0x51, 0x52])
        (ByteArray.mk #[0x01, 0xaa]) =
      (1, ByteArray.mk #[0x51, 0x52]) := by
  native_decide

/-- Middle match: the prefix and the suffix are both preserved exactly
once. -/
example :
    findAndDelete (ByteArray.mk #[0x51, 0x01, 0xaa, 0x52])
        (ByteArray.mk #[0x01, 0xaa]) =
      (1, ByteArray.mk #[0x51, 0x52]) := by
  native_decide

/-- No match: the script is returned unchanged. -/
example :
    findAndDelete (ByteArray.mk #[0x51, 0x52]) (ByteArray.mk #[0x01, 0xaa]) =
      (0, ByteArray.mk #[0x51, 0x52]) := by
  native_decide

end Bitcoin.Test.Script.Interpreter
