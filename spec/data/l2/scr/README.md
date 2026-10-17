# L2-SCR — differential script-interpreter lane

This directory contains the L2-SCR corpus.
Core pins: script lane **c50817fe** (sources under `refs/`), consensus
lane **cce32b16** where referenced. No shared-tree file is edited by this
case set; findings are filed in `spec/db/findings-edge/L2-SCR.md`.

## Artefacts

| File | Purpose |
|---|---|
| `L2ScrRunner.lean` | DUT runner: `Backend.scrVerdict` clone that KEEPS the error kind and maps `ExecError` → Core `SCRIPT_ERR_*` name. Modes `corpus` / `cases`. |
| `pkg/` | Private Lake package that builds the runner against `spec/runners` (`bvectors`) without touching the shared lakefile. |
| `oracle_l2scr.py` | Complete independent Python mirror of Core's `EvalScript`/`VerifyScript`/witness-v0 pipeline @c50817fe. This is the want source for tier G. |
| `gen_l2scr.py` | Seeded, deterministic tier-G generator (`SEED=20261017`). Emits `cases/tierG.l2c`; `--seam` emits `cases/seam.l2c`. |
| `mirror_min.py` | Earlier partial mirror (EvalScript-only, hashes stubbed); preserved as work in progress, superseded by `oracle_l2scr.py`. |
| `cases/tierG.l2c` | 1788 generated cases (17 families). |
| `cases/seam.l2c` | 5 policy-flag-seam proof cases (F-L2SCR-003). |
| `results/tierC.l2r` | Tier C: 1258 pinned Core `script_tests.json` rows replayed. |
| `results/tierG.l2r` | Tier G: 1788 generated rows. |
| `results/seam.l2r` | 5 seam proof rows. |

## Reproduce

```bash
cd spec/vectors/l2/scr
python3 oracle_l2scr.py validate          # 1052/1052 supported corpus rows MATCH
python3 gen_l2scr.py                      # byte-identical tierG.l2c
python3 gen_l2scr.py --seam               # seam.l2c
cd pkg && lake build l2scr
./.lake/build/bin/l2scr cases ../cases/tierG.l2c ../results/tierG.l2r
./.lake/build/bin/l2scr cases ../cases/seam.l2c ../results/seam.l2r
cd ../../../.. && python3 spec/scripts/l2/l2_harness.py --class scr
```

Seeds: `SEED=20261017` (structured + `rand`), `SEED+7` (`rand2`),
`SEED+13` (`randw`). Regeneration is byte-identical (`--check`).

## Verdict law

`UNJUDGED` = no DUT verdict; `VERDICT-DIVERGE` = accept/reject differs;
`KIND-DIVERGE` = verdict agrees but Core's `SCRIPT_ERR_*` kind differs;
otherwise `AGREE`. The canonical harness `spec/scripts/l2/l2_harness.py`
recomputes every row (no trusted tallies).
