# Gen2 Clean UI release status

Current line: `0.1.0` (early experimental public release).

## Current state

- Manifest version: `0.1.0`.
- Host floor: `>=0.1.79 <2.0.0`.
- Core lock: pinned to the committed and tagged `0.1.0-alpha.10` snapshot.
- GitHub Actions validate the product and build logic. Because the host floor
  is now real, a push to `main` will run the release job after validation.
- The product has 51 exact official contract records, 37 production
  presenters, 13 native-by-design records, and 1 deferred battle transition.
- Stable `Gen2BattleState` menu, move-selection, and message frames now use a
  responsive Clean UI battle presenter with metadata-rich status cards
  (gender, conditions, wild catch state, and player EXP) and the native Gen II diagonal:
  enemy status upper-left/enemy sprite upper-right, player sprite lower-left,
  and player status lower-right. Intro/transition, trainer/faint/move
  animation, Pack/Party child states, evolution/stat screens, move-learning
  completion, and post-catch naming fail open to native rendering.
- NAV shell views use a content-driven 320–440 logical-pixel width but retain
  their full 560-pixel logical height; this is covered by core regression
  tests.
- Ordinary M list menus now use a locked 320–600 logical-pixel content width
  while retaining their full 420-pixel logical height; rich detail/sprite M
  menus remain full-width by design.
- Content sizing uses active font metrics for row values and two-column detail
  panels, so larger text settings widen eligible menus before truncation.
- Shared dialogue reflow now keeps native continuation-only breaks inside one
  Clean UI message while preserving intentional page boundaries.
- The production Start Menu responsive matrix passes 23,404 checks in both
  normal and headless runs across all required viewport/font/density settings.
- The combined NAV/M responsive matrix passes 34,325 checks across the same
  viewport, UI-size, text-size, font, density, and safe-area combinations.
- The product now exports the Modern UI v1/v2 compatibility facade alongside
  `cleanUiHost` V3; its compatibility suite passes 33 checks with a graphics
  window and 30 in headless mode, and v2 surface failures retain native UI.
- The shared-core `scripts\invoke_tests.ps1 -Suite all` runner passes all seven
  suites with 204 checks each; the vendored-core lock and host
  `gen2check --strict --notes` also pass.
- The Gold route driver now excludes the active battle mon when choosing both
  an optional SHIFT replacement and a switch-training fighter; the host battle
  UI regression suite covers that selection rule.
- The battle responsive matrix passes 21,859 checks across short landscape,
  portrait, desktop, ultrawide, 4K, and 5K combinations, including explicit
  diagonal card/sprite mapping, HUD/sprite containment, and overlap checks.
- Real-route evidence is scoped: the contract, presenter, Gallery, and visual
  suites cover integrated Clean UI surfaces; the Gold run proves only the
  supported screens encountered along that gameplay path. The remaining
  deferred/native records remain explicitly outside Clean UI replacement
  coverage.

## Real Gold host smoke (2026-08-13)

- The local patched Gold host loaded `gen2_clean_ui` with all 51 contract
  records and the vendored core marked ready.
- `tests/drivers/gold_menu_shots.lua` completed against the real Gold cache and
  produced 35 visual frames covering overworld, boot/menu states, Start Menu,
  Party, Pack, Pokegear clock/map/radio/phone, Trainer Card, Pokedex views,
  Options, Save, PC/storage, clock setup, and Fly Map. The captured frames were
  visually inspected locally.
- The long `tests/drivers/gold_bot.lua` route reached the Lake of Rage/Lance
  milestone (`10.34`) through real map loading, warps, wild and trainer
  battles, Violet, Union Cave, Azalea, Kurt, Mart purchases, Slowpoke Well,
  Olivine, Cianwood, and the Lake of Rage. It completed 165 route rows with no
  teleport shortcuts; the required Cianwood all-party grind completed after
  widening its finite wipe-recovery budget, and one optional route miss remains
  (`04.5d`).
- The route fix was narrowly scoped to the host test adapter: both healthy-mon
  selectors now skip `battle.player`, preventing the prior repeated
  `QUILAVA is already out` loop.
- The product's experimental opt-in was force-enabled only for the isolated
  smoke process and the temporary environment hook was removed afterward; the
  manifest remains unchanged.

## Follow-up after 0.1.0

1. Extend the real Gold route smoke beyond the completed Lake of Rage milestone
   and resolve any newly exposed route or host blockers; the required synthetic
   responsive viewport/font/density matrix and the visual menu smoke now pass.
2. Expand the real-host smoke as the next Grandma's Kitchen build becomes
   available, especially around deferred battle-owned child states.
3. Promote the experimental flag only after the broader host route and release
   evidence are complete.

## Release automation

The workflow validates the manifest, core lock, sandbox, scaffold, and tests.
When the host floor is real, it builds one updater-ready ZIP, creates the
version tag if missing, writes notes from the previous tag's commit range,
records the archive SHA-256, and creates the GitHub release. Development pushes
with a `0.0.0-dev` host floor continue to skip publication; this 0.1.0 package
deliberately uses the official v0.1.79 floor instead.
