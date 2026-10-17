import BitcoinVectors.Records
import BitcoinVectors.Backend
import BitcoinVectors.Gen.TxVectors
import BitcoinVectors.Gen.EdgeVectors
import BitcoinVectors.Gen.ScriptVectors
import BitcoinVectors.Gen.SighashVectors
import BitcoinVectors.Gen.Bip340Vectors
import BitcoinVectors.Gen.Compiled

/-!
# BitcoinVectors — W07 conformance package root

Aggregates the hand-written seam (Records, Backend) and the GENERATED
vector modules (Gen/*, produced by `spec/scripts/runners/codegen.py`).
Regenerating codegen output never touches this file.
-/
