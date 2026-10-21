# E5:F-TOOL-001 — whole-function SAW/Alive2 blockers

**legs:** C, L
**cell:** `cells/e5-whole` (scoped residual, not a green cell)
**symptom:** no whole-function `VerifyScript`/`EvalScript` proof.
**evidence:** `findings/e5/E5-RESIDUAL.md`; raw logs under
`cells/e5-whole/logs/`; `cells/e5-whole/SHA256SUMS`.
**disposition:** open / tool-gap (scoped residual accepted for E5).
**notes:**

1. `_Z11GetScriptOp...` is an undefined external in the single-TU module; the
   first non-empty script stops SAW with "No implementation or override".
2. After linking `script.cpp`, the next stop is the C++ heap (`_Znwm`,
   `malloc`, `free`, `realloc`); `std::vector` must be modeled with allocation
   failure to avoid hiding a real Core error path.
3. `EvalScript` has an unbounded dispatch loop (IR header `%336`, backedge
   `:8200`; 4,638 IR lines) with no supplied invariant.
4. `VerifyScript`/`EvalScript` carry 58/336 invokes and 6/32 landingpads;
   Alive2 rejects `invoke`, so raw O0 cannot translate.
5. The one green empty-script line is a concrete, concolic, **non-pin** run
   (module `b8f17c1f...`), not a pinned equivalence artifact and not a green
   ledger row.
