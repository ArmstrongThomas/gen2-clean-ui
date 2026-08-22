# Gen2 Clean UI roadmap progress

Last verified: 2026-08-17
Release floor: `0.1.87`  
Current manifest: `0.4.1`
Release policy: 0.4.0 is released; the current 0.4.1 development line carries
the Pokédex visual redesign and follow-up verification. No host-repository
changes or screenshots are checked in.

## Pokédex visual redesign — 0.4.1

- [x] Audit the read-only host data and navigation boundaries.
- [x] Add detached evolution, level-up move, and TM/HM reference snapshots.
- [x] Redesign the reachable Info presentation within the existing V3 menu
  contract.
- [x] Redesign the reachable Habitat presentation with map-backed landmark
  markers and safe route-list fallback.
- [ ] Add and validate mod-owned navigation seams for Evolution, Moves, and
  TM/HM after the visual redesign is complete.
- [ ] Perform the first live in-game walkthrough of the redesigned Info and
  Habitat pages.

## Shared font choices — 2026-08-16

- [x] Made OpenTTD Mono the default bundled font and retained Plain Pixel and
  System as alternatives in the shared Core settings and both products.
- [x] Kept the public size control discrete at AUTO/1×/2×/3×. Explicit 4× is
  retained only for internal authored display styles; AUTO never selects it.
- [x] Added general largest-fitting font-step fallback so required text steps
  down before the renderer can truncate a line. Live launcher proof remains
  user-test work.
- [x] Added deterministic choice-order, physical-size, invalid-size, vendor
  lock, asset-hash, and sandbox coverage. Visual font preference and live
  launcher proof remain user-test work.

## Pixel-perfect image presentation — 2026-08-17

- [x] Centralized Core-owned image drawing so party icons, gender assets, map
  tiles, sprite-sheet crops, and other detached raster layers use nearest
  filtering, integer-aligned destinations, and whole-pixel/reciprocal scaling
  to avoid mixed-size raster pixels.
- [x] Sized gender assets from the selected font's measured pixel height so
  the 16px authored sheet does not overpower OpenTTD Mono at 1× while still
  growing with 2×/3× font selections.
- [x] Added deterministic crop/filter/coordinate regression coverage and
  refreshed the vendored Core snapshot in both products. Live visual proof at
  multiple window sizes remains user-test work.

## Battle UI deferment — 2026-08-15

- [x] Removed the active Gen2 battle adapters, presenters, battle renderer,
  battle layout, battle input routing, battle V3 preview contracts, and
  battle-specific deterministic test runner.
- [x] Archived the failed implementation and shared integration snapshots at
  `docs/archive/battle-ui-deferred-2026-08-15/` for reference only. The
  archive is not an active dependency and should not be restored piecemeal.
- [x] Marked `Gen2BattleState` and `Gen2BattleTransition` explicitly
  deferred/native. The official host now keeps ownership of battle rendering,
  timing, input, sound, randomization, semantics, and state-stack transitions.
- [x] Removed battle-specific Core model kinds and battle-only surface presets
  from the active package. Battle-themed assets retained by Egg Hatch,
  Evolution, or other non-battle fixtures are unrelated visual resources.
- [ ] Rewrite the battle UI later from the official V3 seams. This is deferred,
  not cancelled; no replacement architecture is selected in this roadmap.

## Pokegear-family deferment — 2026-08-15

- [x] Disabled the active `Gen2Pokegear` and `Gen2MapRadio` replacements.
  Phone, map/Fly, radio, clock, and related child surfaces now remain owned by
  the official native renderer.
- [x] Removed the Pokegear-family presenter registrations, active V3 preview
  screens/actions, pointer map-marker routing, and production-screen claims.
- [x] Kept the existing adapters, presenters, and source fixtures only as
  inactive reference coverage for a future redesign; Gallery marks those
  variants status-only/native and does not treat them as live support.
- [x] Refreshed the Pokédex list/entry composition within the existing V3 menu
  contract: stable list/preview split, number-first rows, seen/owned markers,
  Gen II type badges, detached sprite palette data, totals, and navigation
  hints inspired by Gen1 Modern's Pokédex composition.
- [ ] Revisit the Pokegear family later as a separate design pass. No new
  architecture or live replacement boundary is selected here.

## Poké Mart commerce UI — 2026-08-15

- [x] Kept the active V3 Mart flow scoped to the detached menu composition:
  top-level BUY/SELL/QUIT, item buying, quantity confirmation, selling through
  the audited Pack child, sell quantity, money, item price, and half-price
  sell value are represented by the production presenter.
- [x] Added owned inventory counts from the detached `save.inventory` snapshot
  to buy entries, selected-item details, and sell details. The count is also
  covered by explicit BUY/SELL/quantity Gallery fixtures.
- [x] Added deterministic commerce and Gallery regressions for owned counts,
  buy rows, sell summaries, quantity states, and the 23 declared commerce
  variants.
- [x] Initial official-launcher walkthrough after sync confirms the Clean UI
  Mart owns the visible surface instead of the native Mart. Minor purchase,
  sale, or layout bugs remain for a later patch pass; this is not a claim of
  complete Mart polish.

## Gen2 Party/Summary visual redesign — 2026-08-16

- [x] Added a Gen2-first detached party list composition with six stable
  visible slots, source-owned row indices, animated icon-sheet descriptors,
  the supplied gender sheet, HP/current-max values, and independent
  type/status regions.
- [x] Added beveled type badges for one or two distinct types. Healthy rows
  leave the status region empty; abnormal rows expose `PSN`, `PAR`, `SLP`,
  `BRN`, `FRZ`, or `FNT` without replacing the condition with prose.
- [x] Aligned the summary tab strip to the host-owned navigation order
  `JOURNAL`, `MOVES`, `DETAILS`, so LEFT/RIGHT cannot land on the opposite
  visual tab; the independent move list/detail panel and fixed envelope remain
  intact.
- [x] Added reusable Core text styles for labels, values, strong headings,
  and accent text. Strong text uses an integer-pixel second pass instead of
  stretching or squishing the authored PlainPixel font, and summary fields now
  occupy structured two-column cards rather than floating at the top of a
  mostly empty panel.
- [x] Added deterministic Gen2 presenter assertions and shared-core geometry
  assertions for row count, source indices, icon crops, healthy/abnormal
  status, dual types, tab order, move slots, and envelope containment.
- [ ] Live-verify Party/Summary controller behavior and icon motion in the
  official launcher. The page strip now follows the host's source order, but
  this deterministic work does not replace the required user walkthrough;
  move control and child-stack behavior remain source-owned until tested.

Future design ideas only — not an architecture decision:

- preserve a fixed upper field envelope and independently composed lower dock
  across landscape 16:9, portrait 9:16, and classic 10:9;
- reconstruct source-timed battle frames from exposed V3 data, including
  sprites, OAM/effects, field layers, status rails, messages, commands, moves,
  and progression screens;
- make native ownership/suppression explicit and latched only after a valid
  clean frame, with safe documented boundaries when V3 data is missing;
- keep host timing, input, sound, randomization, battle semantics, and state
  transitions authoritative; never use captured native pixels as the renderer.

## Historical battle attempt (archived; not active product support)

The completed bullets below describe the removed attempt. They are retained as
history and design context only; they are not live-launcher proof or current
release claims.

- [x] Replaced the earlier Gen2 source-canvas composition seam with a detached
  Clean UI battle renderer. The V3 model now carries the canonical 160x144
  animation frame, source-timed intro offsets, trainer/faint displacement,
  sprite scale/true-color metadata, OAM sheet/crop/palette/flip data, and
  background scroll/palette state; the renderer reconstructs the field and
  lower dock without reading native pixels.
- [x] Kept supported clean battle children in the same detached ownership
  transaction while unknown/native children remain fail-open. The upper field
  and lower dock retain their fixed landscape, portrait, and classic envelopes;
  opening menus does not resize or squish the field or status cards.
- [x] Added deterministic regressions for detached suppression, stable battle
  ownership latching, intro/trainer/faint frame timing, one- and zero-based
  scanline payloads, kept sprites, path-specific sprite scale, OAM frame
  extraction, and unsupported picture overrides. This is repository proof
  only; it is not official-launcher visual proof.
- [x] Removed the Gen2 `render.compose`/native-canvas battle path entirely.
  Missing V3 runner containers or transform/substitute/minimize replacement
  descriptors fail closed as documented V3 gaps; an owned battle retains its
  last complete detached frame instead of handing the scene back to native UI.

- [x] Hardened the battle ownership transaction around supported child-stack
  events: `screen.pushed` and `screen.popped` now discard only the current
  rendered candidate while retaining the last complete battle frame for the
  next stable-identity latch. Leaving battle still releases that frame.
- [x] Added a fail-open detached-frame boundary for move, item, Poké Ball, and
  send-out animation kinds. The adapter detaches host scroll/palette/scanline
  registers and `picHidden` state; the presenter refuses suppression when the
  released frame containers are structurally absent. The renderer consumes
  available trainer/faint displacement and background state without inventing
  an `ENEMY DAMAGE`/`PLAYER DAMAGE` banner.
- [x] Added deterministic regressions for child push/pop latching, missing
  animation frame data, detached background registers, hidden battlers, and
  faint progress. These prove the repository contract only; official launcher
  observation remains required before closing the battle milestone.
- [x] Added an explicit fail-open boundary for released `AnimRunner`
  transform/substitute/minimize picture overrides: the current V3 snapshot
  exposes the override identity but not the replacement sprite descriptor, so
  Clean UI refuses to draw the wrong base sprite and records the exact gap.

- [x] Fixed the released-build post-send-out hand-off: incomplete player or
  enemy battler snapshots now advertise a transient V3 state, allowing Core's
  battle ownership latch to retain the prior complete detached frame rather
  than paint an empty arena or reveal native UI; valid animation frames no
  longer hide base Pokémon art when their optional effect payload is incomplete.
- [x] Fixed the host-refresh ownership gap: a redraw at a new viewport no
  longer counts as leaving battle while the source is between V3 snapshots.
  The last complete detached Clean frame stays authoritative until the next
  complete battle prepare re-solves the layout; this is covered by a
  deterministic refresh regression and is not live-launcher proof.
- [x] Preserved the adapter's explicit `battle_finished` boundary through the
  presenter so terminal cleanup releases the latch instead of retaining a
  stale battle canvas.
- [x] Added readable fallback labels for message-free battle stages including
  battle start, resolving, switching, move learning, level-up, and evolution.

- [x] Audited the 51-entry official Gen2 catalog against the released-host
  floor and kept the ten explicitly native/source-owned IDs native.
- [x] Kept all 41 supported catalog records on the V3 model/presenter path;
  product smoke now checks that every supported record has both pieces.
- [x] Fixed live-stack suppression so supported clean screens do not fail just
  because a native source-owned parent remains below them.
- [x] Added safe battle child-stack handling: supported clean children replace
  their native battle frame, while unknown/native children fail open.
- [x] Reconciled the public stack assessor with the live child-stack path so
  supported Party/Pack/Naming children are not rejected before rendering.
- [x] Added released-host tutorial/no-player battle extraction, Park Ball and
  item animation classification, and touch selection for the next-Pokémon
  prompt.
- [x] Covered the battle pages already represented by the source state machine:
  intro/trainer/faint transitions, move/item/Poké Ball animations, command and
  move selection, battle messages, forced-switch/next-Pokémon prompts,
  experience growth, level-up stats, evolution, nickname, and shift prompts.
- [x] Added V3 detached trainer-art descriptors for the released host's player
  back-pic and opponent trainer front-pic during intro/trainer-slide; older
  caches without the generated paths fall back safely.
- [x] Preserved a phase-independent battle envelope so the upper field and
  status cards do not get squished when the command or move panel opens.
- [x] Updated the released-host contract authority to `v0.1.87`, and exposed
  callback-free provider coverage diagnostics for tooling.
- [x] Added a battle ownership latch keyed by stable battle/screen identity so
  rebuilt source snapshots during intro, move, item, Poké Ball, faint, and
  finishing-hit transitions cannot briefly reveal the native renderer.
- [x] Added the V3 `sceneFrame` battle-frame alias and native-stage metadata;
  OAM effects stay inside the protected arena and are prevented from painting
  over either status rail. The combined visual direction is now the working
  plan: open battle arena/status rails, compact 2x2 command dock, and a
  dedicated move-information panel/list.
- [x] Completed the combined battle composition pass: the V3 adapter caps the
  move surface at four rows, mirrors the live scene frame at the battle-model
  level, and the detail panel reflows long move descriptions inside its
  reserved region.
- [x] Added an explicit V3 `BATTLE_CLASSIC` surface for the original 10:9
  battle framing, alongside the existing 16:9 wide and 9:16 phone envelopes;
  the resolved aspect is available to Studio and alternate presenters.
- [x] Promoted the released-host compatibility fixes back into shared Core:
  v0.1.86 generated-PNG loading, game resolution through visibility state,
  screen-stack lifecycle invalidation, settings fallback, and pointer/touch
  disabled by default.
- [x] Rebalanced the battle composition around a fixed spacious stage:
  default 16:9 uses a 960×540 logical canvas (540×960 on phones), keeping the
  upper field visually dominant and the lower dock near one-third of its
  height without phase-dependent resizing. The wide layout now declares and
  tests a roughly 3:1 upper-stage-to-dock hierarchy while retaining a
  content-driven floor for four moves and their detail panel. Intro/trainer
  slides now draw the detached trainer descriptors, and incomplete OAM cannot
  blank base sprites.
- [x] Added the first post-battle visual polish slice: caught-Pokémon
  nicknames use a Gen1 Modern-style compact keyboard through the released
  naming-grid hook, while player/rival/box naming remains source-faithful.
  The adapter stays on the native board until product bootstrap confirms that
  the released hook was installed. Core renders entry slots and the keyboard
  card grid through the V3 model.

## Current milestone and follow-ups

- [x] Superseded the broken battle milestone with an explicit deferment. The
  official launcher keeps the complete native battle path; this repository no
  longer claims a Clean UI battle replacement.
- [ ] Future battle rewrite: turn the design ideas above into a new plan only
  after the official V3 data seams and ownership boundary are re-evaluated.
- [ ] Continue non-battle polish and verification: Party first, then Trainer
  Card, Summary, Pack, Pokédex, Save, dialogue, and settings/pointer-touch
  behavior. Pokegear/Map/Radio remain native until a separate redesign.
- [ ] Replace the current map presentation with the Gen1 Modern native-map
  extraction/composition approach; its full graphic treatment is the preferred
  follow-up over the current marker-first fallback.
- [ ] Keep the pass free of screenshots, generated release archives, and Git
  artifacts; no commits or host-repository changes are part of this roadmap
  update.

## Automated verification

- [x] Shared `clean-ui-core` and product suites pass after the battle removal;
  prior battle-renderer counts are historical archive results only.
- [x] `tests/run_lua_tests.ps1`
-  - Lua syntax: 198 files passed
  - Contract/foundation/shared/product checks: all passed
  - Non-battle Gallery/production checks: 779 and 180 checks passed
  - Responsive NAV/M matrix: 40,567 checks passed, including the shared
    largest-fitting font-step fallback regression
  - Battle-specific adapter/renderer tests are no longer in the active suite;
    the source and tests are preserved under the deferment archive.
- [x] `scripts/verify_core_lock.ps1` and `scripts/verify_sandbox.ps1` pass.
- [ ] Release/scaffold and archive checks are deferred in this working pass;
  the tree currently contains the pre-existing untracked
  `gen2_clean_ui-0.2.0.zip`, which the scaffold intentionally rejects as a
  stale release artifact. No release archive was rebuilt or committed.
- [ ] Live battle walkthrough is intentionally deferred with the rewrite. This
  pass did not sync the package, launch the game, or perform controller
  testing.
- [x] Deterministic Pokegear-family tests still exercise the inactive
  extraction/presentation reference code; product smoke verifies that neither
  native-boundary ID has an active adapter or presenter.

## Deliberate native boundaries

- [ ] Copyright splash, Game Freak Presents, Gold/Silver intro, and title stay
  source-owned until a proven released-host raster seam exists.
- [ ] Hall of Fame induction, trade/complex nested party-picker stacks, and
  shared `gold.CallerBox` remain fail-open/native where exact ownership is not
  provable.
- [ ] Source-owned animation timing and input remain in the host; the clean
  UI consumes detached V3 frame data and does not patch the host repository.
- [x] Battle and battle-owned child stacks remain explicit source-owned/native
  boundaries while the rewrite is deferred.

## Next user test

When available, run `G:\dev\misc\gen2-clean-ui\sync_gen2_clean_ui.cmd`, restart
the official launcher, and verify the non-battle surfaces: main menu, start
menu, party, pack, Pokédex, native Pokegear/map/radio, dialogue, and
pointer/touch settings.
Battle should be observed as the native host path until a future rewrite is
planned and implemented.
