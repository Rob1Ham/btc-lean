import Bitcoin
/-!
# BtcLean — workspace-root umbrella module

Imports the core spec root so that `lake build` from the repo root
builds the whole zero-dependency core. Deliberately does NOT import
`BitcoinProofs` (that would pull mathlib into every root build).
-/
