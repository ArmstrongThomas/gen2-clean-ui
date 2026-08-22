# Gen2 Pokédex handoff

## Current state

The active Gen2 development line is `0.4.1`. Version `0.4.0` is already a
GitHub release, so follow-up Pokédex and Core-integration work uses `0.4.1`.

The reachable Pokédex screens now use the shared V3 document presentation
contract. The identity panel presents the sprite, species name,
classification, Pokédex number, and type badges. The adjacent panel presents
height, weight, and status metadata. Entry pages select the active source page
instead of concatenating both pages, while preserving the native action
selection and color-art data.

The Gen2 Core snapshot is synchronized from merged Core `main` and its lock
contains every synchronized file, including Core presentation assets. The
vendor directory and lock must always be refreshed together through
`sync_gen2_clean_ui.cmd`.

## Validation baseline

The Linux suite currently passes all groups, including:

- syntax and contract checks;
- shared/foundation/load checks;
- Party/Summary and Pack/Dex/Trainer/Save checks;
- Pokegear/MapRadio, services, mail, and Gallery checks;
- the responsive NAV/M matrix.

On Windows, run `.\tests\verify_scaffold.ps1` before publishing a release
branch. If it reports a Core lock count or hash failure, inspect the actual
vendor file set before changing assertions. If it reports a missing release
blurb, add `docs/releases/v<manifest version>.md`.

## Branch and merge notes

The Core document contract was developed in `clean-ui-core` and must be merged
to Core `main` before syncing Gen2. Gen2 changes should be developed on a
feature branch from the merged Gen2 `main`, then published and merged through a
GitHub pull request.

GitHub Desktop only shows branches available in its own checkout. A branch
created in another worktree must be transferred to the checkout path used by
GitHub Desktop and then published. A clean local `main` does not mean that
another feature branch, stash, or GitHub remote is clean.

## Do not change

- Do not edit the host `gen1recomp` repository or launcher/AppData copy.
- Do not manually patch `mods/gen2_clean_ui/vendor/clean_ui_core`.
- Do not commit an incomplete Core sync that removes document files.
- Do not reuse a released version number.
- Do not claim CI is green until the Windows scaffold/release gates pass.

## Next work

Continue visual refinement in the Studio/product workflow while preserving the
native navigation boundary. Evolution, level-up move, and TM/HM pages remain
model-ready but are not claimed as live pages until a compatible mod-owned
navigation seam exists.
