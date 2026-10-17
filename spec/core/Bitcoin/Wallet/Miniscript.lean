import Bitcoin.Wallet.Miniscript.Type
import Bitcoin.Wallet.Miniscript.Node
import Bitcoin.Wallet.Miniscript.Script
import Bitcoin.Wallet.Miniscript.Satisfy

/-!
# Bitcoin.Wallet.Miniscript

Umbrella module for the Miniscript fragment: the type lattice
(`Type.lean`), the node tree and canonical type computation
(`Node.lean`), script emission for P2WSH and tapscript (`Script.lean`),
and abstract satisfaction plus the sanity predicate (`Satisfy.lean`).

Ground truth is Bitcoin Core `cce32b168` (a v21.99 development snapshot),
`src/script/miniscript.h`, `src/script/miniscript.cpp`,
`src/script/script.h`, and `src/test/miniscript_tests.cpp`.

Scope limits: no policy compiler, no descriptor parser, no `ToString` or
`FromScript`, no `just_0`/`just_1`/`andor`, and no malleability model.
-/
