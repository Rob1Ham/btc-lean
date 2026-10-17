import Bitcoin.TxValidation.Interface
import Bitcoin.Ledger.Interface

/-!
# W10 cross-check — TxValidation ↔ Ledger interface consistency

Kept in its own file so the main `Tests.lean` battery does not depend on
the Ledger interface module (W12-owned; it imports TxValidation).

* TXV-042: the locally re-declared `mempoolHeight` sentinel equals
  `Bitcoin.Ledger.MEMPOOL_HEIGHT` (both `0x7FFFFFFF`, txmempool.h:51).
-/

namespace Test.TxValidation.LedgerCross

open Bitcoin.TxValidation Bitcoin.Ledger

/-- TXV-042: the local `mempoolHeight` sentinel equals the Ledger
module's `MEMPOOL_HEIGHT` (both `0x7FFFFFFF`, txmempool.h:51). -/
example : mempoolHeight = Bitcoin.Ledger.MEMPOOL_HEIGHT := by decide

end Test.TxValidation.LedgerCross
