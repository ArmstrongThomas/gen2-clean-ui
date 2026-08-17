# Changelog

Release history for Gen2 Clean UI. Version 0.1.0 is an intentionally early,
experimental public release.

## 0.3.0 — Unreleased

The 0.2.0 release is complete. The development manifest now targets 0.3.0;
the deferred battle and Pokegear boundaries remain unchanged while follow-up
Clean UI work continues.

- Added Yellow and reorganized the palette selector to Red, Blue, Yellow,
  Gold, Silver, Crystal, with a shared Dark Mode toggle instead of separate
  light/dark selector rows. Light High Contrast is now the light counterpart
  to the existing dark High Contrast palette.
- Started the Gen2-first Party/Summary redesign from the clean retro-modern
  reference: a fixed six-slot party list, detached animated icon/gender/HP/
  status/type row data, beveled one- or two-type badges, and source-ordered
  JOURNAL / MOVES / DETAILS summary tabs with a stable independent move panel.
- The party and summary renderers now use the supplied male/female sprite
  sheet, the official two-frame party-icon cadence, and reusable non-stretched
  PlainPixel hierarchy styles for headings, labels, values, and accents.
- Tightened shared image presentation for all detached Gen2 UI art: party and
  gender sprites, map tiles, crops, and animation images now use nearest
  filtering and whole-pixel/reciprocal scaling with integer-aligned output
  bounds. Gender icons follow the selected font's actual pixel height without
  forcing a fractional source scale. Native tilemaps use one shared pixel
  scale for the complete grid so responsive rounding cannot create seams.
- Made OpenTTD Mono the default bundled font family. The public choices are
  OpenTTD Mono, Plain Pixel, and System; public text steps are AUTO/1×/2×/3×.
  Explicit internal 4× remains available for authored display styles only.
- Added shared largest-fitting font-step fallback: required text is measured
  before rendering and falls back one authored step at a time instead of being
  truncated with an ellipsis.
- Added declarative Clean control-scheme metadata for the new Party/Summary
  surfaces. The summary tab strip follows the host's source page order, so it
  does not require a controller remap; live tab, move-control, and icon-cadence
  walkthrough proof still remains a user-test requirement.

## 0.2.0 — 2026-08-15

### Deferred — 2026-08-15

- Removed the failed Gen2 Clean UI battle adapters, presenters, detached
  renderer/layout, battle input routing, battle V3 preview contracts, and
  battle regression runner from the active package.
- Archived the removed attempt and shared integration snapshots under
  `docs/archive/battle-ui-deferred-2026-08-15/`.
- Marked `Gen2BattleState` and `Gen2BattleTransition` explicitly
  deferred/native. The official host remains authoritative for battle
  rendering, timing, input, sound, randomization, semantics, and transitions.
- Retained future battle design goals in `docs/BATTLE_SYSTEM_HANDOFF.md`.
  No replacement battle architecture is selected in this release.
- Disabled the complete Pokegear-family replacement, including
  `Gen2Pokegear` phone/clock/map/Fly/radio surfaces and `Gen2MapRadio`.
  Their official native renderer now owns the flow; the existing adapters,
  presenters, and fixtures remain inactive reference material only.
- Refreshed the Pokédex list and entry composition with a Gen1 Modern-inspired
  stable list/preview split, number-first rows, seen/owned status markers,
  type badges, detached palette-aware art, totals, and cleaner navigation
  hints. This remains a V3 menu composition, not a copied native canvas.
- Synced the shared Core settings compatibility fix into the Gen2 vendor:
  hosts that expose `mod.options:define/get` without `options:set` now persist
  Clean UI settings through public `mod.storage` for the active playthrough.

The battle-specific entries in the historical Added list below describe the
removed attempt and are not current live-launcher support or acceptance proof.
The historical Pokegear entries below likewise describe an inactive reference
implementation; Pokegear and Map Radio are native in the current product.

### Added

- Updated `sync_gen2_clean_ui.cmd` to refresh the sibling `clean-ui-core`
  checkout before syncing the mod or building the launcher archive. Local Core
  sync now records the checkout's current Git HEAD automatically.

- Completed the active Poké Mart V3 menu composition for top-level BUY/SELL,
  item buying, quantity selection, selling through the Pack child, and sell
  quantity. Buy rows and selected-item/sell details now show detached owned
  inventory counts, money, item price, and half-price sell value. Deterministic
  coverage includes 23 commerce variants.
- Fixed the live Poké Mart native fallback: the official transparent
  `MartMenu` contract is now represented as non-opaque, so provider identity
  validation no longer rejects every live Mart state with `opacity_mismatch`.
  A user walkthrough confirmed Clean UI ownership after sync; minor Mart bugs
  remain for follow-up.

- Raised the supported release floor to `0.1.87` after the official launcher
  drop. The live stack now preserves the source-owned overworld backdrop while
  allowing every labelled retained V3 menu/submenu state to initialize and
  suppress its native renderer; unknown labelled UI states still fail open.
- Added the first released-host `0.1.86` compatibility path, removed the
  obsolete experimental manifest flag, and added `sync_gen2_clean_ui.cmd` for
  main-launcher smoke testing. The current manifest floor is now `0.1.87`.
- Adapted Gen2 Clean UI settings to Bryan's v0.1.86 public options surface:
  `mod.options:define/get` is sufficient for loading and settings UI, and
  Reset Defaults now uses the shared V3 session-local fallback when the host
  does not expose the later `mod.options:set` writer.
- Fixed the V3 settings shell to read through that same fallback instead of
  rereading the host's read-only option value. The incomplete pointer/touch
  path is now hidden from settings and disabled by default. Its V3 hook,
  provider hit testing, and `mod.input:tap` integration remain in the package
  as low-priority groundwork for a later input pass.
- Fixed official-screen replacement on Bryan's v0.1.86 host. That host does
  not expose the newer optional `mod.ui.isBuiltinScreen` predicate; requiring
  it caused every native-screen candidate to fail validation while the Clean
  UI settings/gallery shell still loaded. Exact screen IDs, source registry
  ownership, and the native draw guard now provide the released-host fallback.
- Generalized that released-host fallback across all 51 official screen
  records. The legacy visibility hook now resolves the live `game` from the
  state object, so Party, Pokegear, dialogue, and pointer/touch paths no
  longer depend on a newer host facade field or a main-menu-only fixture.
- Added a v0.1.86 generated-image compatibility fallback. The public host
  exposes sandboxed `love.graphics.newImage` but not the newer
  `mod.ui.sourceImage`; the runtime now loads only validated
  `assets/generated/*.png` paths through that release-floor fallback, while
  newer hosts retain `mod.ui.sourceImage` and host cache ownership. This
  restores the Party Clean UI override path instead of failing
  open to native when their generated Pokémon sprites are requested.
- Added explicit V3 canvas invalidation on `screen.pushed` and `screen.popped`.
  This prevents a completed Clean UI frame from surviving a stack transition
  on the v0.1.86 host, which does not always raise the newer prepare seam.
- Refreshed the vendored Core lock entry for the lifecycle runtime so sync and
  release packaging verify the exact runtime that is shipped.
- Made the sync/release SHA-256 checks use the built-in .NET implementation,
  so the launcher command remains reliable when Windows PowerShell starts
  without its optional utility module path.
- Hardened `sync_gen2_clean_ui.cmd` to replace the exact launcher mod target
  instead of leaving deleted/stale files behind; the target path is checked
  before cleanup and copy.
- Shared V3 contracts can now set `all_generations = true` to register the
  same screens and actions with both Clean UI products without duplicating a
  generation list; the launcher manifest remains responsible for package
  eligibility.
- A smartphone-style Pokegear shell with a status bar, app rail, active-card
  treatment, and view-specific content surface while retaining the native
  directional/A/B control flow.
- Native-art Pokegear Map rendering from the extracted 20x18 Johto and Kanto
  tilemaps, shared gear sheet, and per-tile palette map, with a safe marker
  fallback when the host asset loader is unavailable.
- Responsive Pokegear device geometry across phone portrait, phone landscape,
  desktop, 4K, and 5K envelopes, including a split Map/Fly surface and native
  cursor-sheet selection; the Pokegear/MapRadio suite now passes 212 checks.
- API V3 editor support through the `contract_catalog` capability and
  `cleanUiHost.listContracts(filter)`, plus a deterministic core
  `ui-editor-fixture` example with panel, dropdown, named-action, and modal
  flows for the standalone editor WIP. Declarative screen action references
  are now validated atomically during registration, and editor focus skips
  non-actionable label rows.
- The Gen2 host now publishes a callback-free `gen2_official_catalog` V3
  contract with all 51 exact screen IDs, support states, milestones, and
  native reasons, so editor/diagnostic tooling can inspect the complete matrix
  without receiving runtime callbacks or changing native suppression.
- Core now validates and renders first-class V3 `device` and `map` models;
  Gen2 Pokegear emits those kinds for its smartphone/card and Map/Fly views.
  Live animation timing, source identity, and complete child-stack ownership
  remain explicit source-owned boundaries.
- Product smoke now asserts the exact ten native-by-design Gen2 boundaries,
  including Copyright, Game Freak Presents, Gold/Silver Intro, and Title, so
  the previously rejected raster presenters cannot be re-enabled accidentally.
- Battle regression coverage now verifies that live move/item/Poké Ball animation
  frames remain detached data inside the canonical V3 battle model, including
  source sheet geometry and OAM objects.
- Battle presentation now reserves a phase-independent envelope sized for the
  four-move state, so opening the command menu or move list never squishes the
  status cards, sprites, or arena. Player status consistently shows HP above
  EXP, and the portrait command menu remains a 2x2 grid.
- Fixed the live OAM crop-index multi-return regression that could abort a
  battle animation frame and briefly expose native UI. Missing optional effect
  sheets now skip only the unavailable effect tile while the Clean UI frame
  remains active.
- Supported battle child stacks are now accepted by the public stack assessor
  when their V3 presenters are complete; unknown or native children continue
  to fail open instead of being claimed by the mod.
- Added the released-host tutorial/no-player battle fallback, Park Ball and
  held/used item animation classification, and touch selection for the
  next-Pokémon confirmation prompt.
- Completed the battle state-machine audit: move-learning now follows the
  pending Pokémon even when it is benched, the forget picker uses its own
  cursor for keyboard/pointer/touch input, and the level-up stats page exposes
  both Gen II special attack and special defense values.
- Battle intro now carries the released host's player back-pic and opponent
  trainer-class front-pic through detached, palette-aware V3 sprite data; the
  Pokémon sprites take over only after their source send-out/slide phases, and
  older caches without those generated paths fail open safely.
- Expanded battle regression coverage across every known upstream phase,
  including shift/refusal, move learning, stats, evolution, and completion
  hand-off; the responsive matrix now passes 21,909 combinations.
- The Gen2 provider now rejects incomplete V3 presentation markers before
  suppression: `schema`, `apiVersion=3`, and a non-empty `kind` are required,
  with malformed presenters failing open to native UI.
- Product smoke now validates every model-ready production Gallery fixture
  with the canonical Core V3 validator, protecting the editor/catalog examples
  from silently regressing to an internal source-model shape.
- Release-tool smoke now derives the archive version, tag, and curated blurb
  from the manifest, so future version bumps cannot silently keep testing the
  `0.2.0` release notes.
- Scaffold verification now requires a non-empty curated blurb matching the
  manifest version, making the release-note update part of the normal local
  validation gate as well as CI.
- V3 animation sprite descriptors now require complete asset paths and positive
  placement rectangles; integer crops, flips, and palettes are validated by
  both Core and Studio before rendering, with product smoke covering every
  direct screen published by the V3 catalog.
- V3 panel descriptors now have one strict Core/Studio contract for dense
  component collections, stable IDs, known fields, nested options/fields,
  footer lists, duplicate IDs, and type-specific required payloads. Invalid
  panel replacements fail atomically before export, registration, or rendering.
- V3 direct presentation models now cover menu, dialogue, choice, battle, and
  animation previews. Shared TextBox and ChoiceBox use the canonical V3 presentation
  schema, and the product registers the real `gen2_shared_dialogue` contract
  for callback-free editor/catalog inspection while preserving source-owned
  timing and input.
- The Main Menu, Start Menu, and Options presenters now use the same canonical
  V3 presentation schema, with representative `gen2_foundation_menus` screens
  available through the callback-free contract catalog.
- Party and Summary presenter outputs now use the canonical V3 presentation
  schema, including HP/status/EXP and move-detail data, with representative
  `gen2_party_menus` screens available through the callback-free catalog.
- Pack, Pokegear, and Map Radio presenter outputs now use the canonical V3
  presentation schema, with representative inventory/device screens available
  through the callback-free `gen2_inventory_device` catalog contract.
- Pokedex, Trainer Card, and Save presenter outputs now use the canonical V3
  presentation schema, with representative progress screens available through
  the callback-free `gen2_progress_menus` catalog contract.
- Battle presentation models now carry the canonical V3 schema as well, with a
  callback-free `gen2_battle_preview` contract covering status/EXP/action data.
- The V3 presentation vocabulary now includes timed animation models, and the
  product registers `gen2_battle_animations` with six callback-free Gallery
  examples for intro, move, item, experience, level-up, and battle-transition
  states. The live pre-battle transition now uses a transparent V3 overlay over
  the source-owned world; source-owned timing and unproven child stacks remain
  fail-open.
- The Gen II Copyright splash, Game Freak Presents, Gold/Silver intro, and Gold
  title screen remain native/source-owned for the initial release. Their
  experimental V3 raster presenters are no longer registered for gameplay after
  visual verification exposed incorrect scanline/sprite bars.
- The credits roll now uses the same V3 animation contract, including extracted
  scene/banner art and ordered normalized text layers, while retaining the
  source-owned credits clock and exit behavior.
- Egg Hatch now uses a full-viewport V3 animation presenter with source-owned
  beat timing, extracted egg and hatchling art, palette selection, crack frames,
  and normalized shell fragments; incomplete art fails open to native.
- Evolution now uses the canonical V3 animation presenter with source-owned
  flash/reveal timing, blackout and palette-aware species art, text beats, and
  expanding light-circle particles; incomplete art/data fail open to native.
- Core and Studio now validate and render normalized V3 animation circles,
  providing a reusable particle primitive for source-authored cinematic effects.
- Gold/Silver Intro extraction remains an editor-only experiment until its
  native raster seam is proven; gameplay stays on the source renderer.
- The callback-free V3 catalog now includes `gen2_extended_menus` examples for
  naming, storage, marts, mail, clock, and Hall of Fame flows so the standalone
  editor has broader real-product fixtures to exercise.
- The V3 host now advertises `presentation_models` and rejects malformed direct
  presentation screens atomically, including invalid action-result screens.
- The canonical V3 model validator now rejects sparse/keyed rows, scalar
  dialogue lines, malformed options/actions/sprites, and non-integer selection
  indices, malformed animation overlays and labels, and invalid overlay flags before a
  product presenter can reach layout or rendering; the
  portable Studio validator mirrors those rules.
- The shared presentation runtime now applies the same canonical V3 model
  validator immediately before measurement and rendering, preventing a
  non-V3 direct provider result from reaching the renderer or suppressing the
  native screen.
- The shared core now exposes an editor embedding bridge (`validateV3`,
  `measureV3`, `drawV3`, and `renderV3`) so Clean UI Studio can exercise the
  same V3 validation, responsive solver, and presentation renderer used by the
  product runtime.
- Responsive battle geometry now passes 21,909 viewport/font/density checks;
  shared core unit verification passes 259 checks,
  including real V3 validation/catalog coverage for the checked-in editor
  fixture.

### Fixed

- Added Red, Gold, Blue, Silver, and Crystal selectable palettes to the Clean
  UI theme selector; each is included in the vendored Core registry.
- Fixed the Mod Menus shell theme path to use the persistent Core settings
  adapter instead of the released host's default-only `mod.options:get`
  reader. Dark and High Contrast now apply to that page after changing them in
  Clean UI Settings.
- Relaxed live-stack suppression so a complete supported V3 child no longer
  falls back merely because a native source-owned parent remains below it.
  Unknown or native states above a clean state still fail open, while opaque
  clean screens stop the walk at the correct replacement boundary.
- Battle-owned clean child menus now suppress the native battle frame only
  when the complete child stack is supported; native or unknown battle child
  states remain visible instead of being partially covered.
- Completed the remaining battle confirmation/message edges: next-Pokémon
  prompts use the clean YES/NO actions and battle messages remove native
  `<NEXT>` pagination markers.
- Kept battle geometry phase-stable across intro, command, move, message,
  experience, level-up, evolution, and nickname/shift prompts so opening the
  lower panel does not compress the readable upper field.

## 0.1.0 — 2026-08-13

### Added

- A first-public-release Gen2 battle presentation covering stable wild/trainer
  battle menus, move selection, metadata-rich HP/status cards (gender,
  conditions, wild catch state, and player EXP), palette-aware front/back
  sprites, message frames, and touch action geometry. Intro transitions,
  trainer/faint/move animations, and battle-owned child stacks remain native
  through the explicit fail-open boundary.
- Responsive battle envelopes for 320x180 and 360x640 phone layouts through
  desktop, ultrawide, 4K, and 5K displays, including a battle-specific font-fit
  probe and a 21,859-check viewport/font/density matrix. The native Gen II
  diagonal is preserved: enemy status upper-left/enemy sprite upper-right,
  player sprite lower-left/player status lower-right.

- Production model/presenter integration for all audited 0.3 families:
  Pokegear/Map Radio, services/commerce, mail, specialty displays, and the
  Hall of Fame viewer.
- Production Gallery conversion and aggregate runners for every integrated
  0.3 family.
- Headless GitHub Actions test execution with finite job timeouts.
- Release validation now smoke-tests the deterministic archive builder in an
  isolated temporary copy, including repeat-build hashing, archive-root
  containment, manifest ordering/version, and vendored-core entry checks.
- Curated versioned release blurbs now live under `docs/releases/` and are
  automatically combined with the generated commit list and archive hash.
- Real Gold-host visual smoke completed 35 captured frames across boot/menu,
  Start Menu, Party, Pack, Pokegear, Trainer Card, Pokedex, Options, Save,
  PC/storage, clock setup, and Fly Map through the host's menu driver.
- Real Gold battle-host smoke now passes trainer-intro and sprite-scale probes,
  battle Pack return/refusal behavior, forced-switch Party behavior, and the
  catch-to-post-catch path. The probes produced visual evidence under the host
  checkout's `tests/shots/battle-audit*` directories; battle-owned Pack/Party
  and post-catch child stacks remain native by contract.
- The real post-catch nickname path now also passes end to end: accepting the
  YES prompt opens the Clean UI naming keyboard, directional input enters
  `CATCH`, and the settled party record retains that nickname. Screenshots are
  retained under `G:\dev\misc\gold-battle-nickname-normal`.
- The full-party catch boundary also passes on the real host: with six party
  members, a caught Pidgey is inserted at slot 1 of the active PC box while the
  party remains full. Evidence is retained under
  `G:\dev\misc\gold-battle-boxfull-next`.
- Additional real-host progression probes pass: the native EXP-bar crawl
  advances through a level-up without jumping to its final width, and the
  naming/party probe passes full-name entry, spaces, NPC-held item display, and
  TAKE-to-bag behavior. These progression and child-stack paths remain native
  by contract.
- Native battle-boundary smoke now also passes all 17 sampled move animations,
  a benched REVIVE, and ETHER through the real move-selection screen. The host
  PP dispatch now accepts the 1-based move index returned by both field and
  battle selectors; the party cursor is explicitly re-targeted in the probe
  because Gold preserves the last-picked row across openings.
- The focused Gen 2 item regressions now pass 104/104 field checks and 94/94
  battle checks. The battle fixture drains PromptButton text with explicit A
  edges, matching the real host flow instead of spinning on an undismissed
  intro line.
- Additional real-host child-state smoke now passes Gold evolution, including
  B-cancel, PC move-to-box, Pack item submenu/toss, Egg summary rendering, and
  the live battle move-learning prompt/list path. These remain native/deferred
  seams; the probes verify source-owned interaction without Clean UI suppression.
- The evolution probe now keys cancellation to the native flash/wait phase,
  rather than a screenshot-loop frame count: a full Chikorita -> Bayleef run
  completes, while a held B input cancels back to Chikorita. The retained
  evidence is under `G:\dev\misc\gold-evolution-next-fixed3`; the Gold save
  remains byte-for-byte unchanged.
- Real-host Summary coverage now captures the party list, all three pages,
  poisoned and dual-type cases, and move descriptions. The naming/trade probe
  also passes the full rival-name keyboard edge cases, Kyle's Onix carrying a
  named BITTER BERRY, and TAKE moving that item into the bag; evidence is under
  `G:\dev\misc\gold-summary-next` and `G:\dev\misc\gold-naming-trade-next`.
- The native Egg boundary now passes the full crack/wobble/burst/fragment
  sequence and the hatch-state Summary page for Sentret. Evidence is under
  `G:\dev\misc\gold-egg-next`; these animation-heavy paths remain native by
  contract.
- A fresh native-boundary replay re-verified the deferred battle children after
  the release-safety changes: the live move-learning prompt replaced TACKLE
  with QUICK ATTACK in slot 1, and the battle Pack revived a benched TOTODILE
  then restored PP through the move list with ETHER. The retained screenshots
  are under `G:\dev\misc\gold-battle-learn-next`; the item driver passed both
  checks without changing the Gold save.
- The real-host faint/forced-switch probe also passes: the fainted sprite exits
  its frame, the native party list rejects the fainted slot, accepts the healthy
  replacement, and the trainer sends out its next Pokémon. The animation and
  child list remain native by contract.
- Latest retained faint/forced-switch frames are under
  `G:\dev\misc\gold-battle-faint-next`.
- A production-path responsive NAV matrix covering all roadmap viewports,
  UI sizes, text steps, font families, densities, and safe-area variants
  (23,404 checks in normal and headless runs).
- Content-driven NAV shell sizing: Start, Mod Menus, Settings, and
  Compatibility choose a locked 320–440 logical-pixel width from their
  required content instead of always using the full 440-pixel maximum, while
  retaining the full 560-pixel logical height for useful vertical capacity.
- Extended content-driven sizing to ordinary M list menus such as Main,
  Options, PC roots, and script menus: they may use 320–600 logical pixels
  without losing their full 420-pixel logical height. Rich detail/sprite menus
  retain their full width.
- Menu sizing now accounts for the selected font's actual row/detail metrics:
  long right-hand values and two-column save summaries reserve the space they
  need instead of being ellipsized inside the compact minimum envelope.

### Compatibility

- Modern UI compatibility facade for v1 data-first adapters and v2 custom
  surfaces, including namespaced themes/frames, source-owned actions, private
  canvas rendering, and native fail-open behavior.

### Fixed

- Restored the host's `render.ui.prepare` seam before native screen composition;
  without it the V3 provider could register successfully but never prepare a
  replacement frame, leaving the game native across menus, party/pack,
  Pokegear, and battle. The host's public `mod.options:set` writer remains
  required for Reset Defaults and live settings changes.
- Gen2 Mart, Mail Compose, and Trade validators now match the host's
  zero-based ranges.
- Windows CRLF-safe scaffold validation and LF-stable vendored-core checks.
- Shared dialogue presentation now reflows source lines, suppresses native
  continuation-only pagination, and presents a split sentence as one wider
  Clean UI message while retaining true page breaks and source input timing.
- Battle presentation now follows the native Gen II diagonal layout and uses a
  compact card fallback for short screens and large text settings instead of
  allowing HUD/sprite overlap.
- Gold route driver battle selection now skips the active mon for optional
  SHIFT and switch-training prompts, with a Gen 2 battle UI regression check;
  the real route smoke reached the Lake of Rage milestone (`10.34`), completed
  165 route rows without teleport shortcuts, and widened the finite recovery
  budget for the required Cianwood all-party grind so normal variance does not
  turn recoverable wipes into a route failure.
- The local patched-host regression suite now exercises public
  `mod.options:set` across toggle, choice, number, and text schemas, including
  persistence, live/profile state, post-write events, and atomic invalid-write
  rejection; it passes `74/74` checks. The release floor remains the first
  official tagged host carrying this API.
- Gold route navigation now recognizes live `SMASHABLE_ROCK` objects as
  Rock Smash interactions instead of permanent walls, clears them through the
  real A-press script, and re-plans before entering a warp. A targeted no-write
  Love2D probe now clears Dark Cave Violet's two choke-point rocks and walks
  into Route 46 without a harness teleport.
- Gold edge navigation now validates the destination landing strip before
  choosing a source border cell. The targeted Route 37 -> Ecruteak probe
  crosses at `(8,0)` and lands at `(18,35)` instead of selecting source cells
  that map into scenery. The full no-write replay reached `13.12c`; the
  transient Route 36 trainer blockage is now handled by bounded retreat and
  re-planning.
- Gold route recovery now distinguishes real sighted trainers from ordinary
  NPC blockers by requiring the live trainer record, skips already-beaten
  trainers, and caps unsuccessful interactions so a transient blockage cannot
  spin the route harness indefinitely. A defeated trainer that leaves the
  player boxed against its approach cell now triggers a bounded retreat and
  re-plan instead of a blind wait loop.
- Gold connected-edge validation now accounts for a valid shore-to-water Surf
  transition when the player is still on foot. The focused native seam check
  passes for both boarding Surf at the edge and crossing while already Surfing,
  covering the Cianwood City -> Route 41 failure without changing save data.
- Gold region-aware travel now carries the intended destination region through
  connected-edge hops and filters source border candidates against a static
  forward/reverse destination fill. A native behavior check now excludes a
  disconnected destination pocket as expected. Arrival-warp re-arming now
  occurs before edge targeting, live source-region exits override stale
  pre-warp region hints, and a failed border walk is rescanned after dynamic
  trainer recovery. The no-write replay from section `07` crossed Route 42's
  east seam at `(59,6)`, selected Lake of Rage's main region for both the
  travel and Red Gyarados rows, completed the Mahogany staircase scene, and
  reached `13.12c` with zero teleport shortcuts.
- Two additional fresh-slot, no-write Gold replays now cross the remaining
  first Ice Path B3 pushes: one reaches `13.12d`, and the complete replay
  reaches the flag-backed `13.12` objective at route row `239/315`. Logs are
  retained as `gold-route-13.12d-boundary-replay.log` and
  `gold-route-13.12-first-boulder-complete.log`; the original save remains
  untouched.
- A further fresh-slot, no-write replay completes the second Ice Path B3
  sequence through `13.13a`–`13.13d` and the flag-backed `13.13` objective at
  route row `244/315`; its log is `gold-route-13.13-second-boulder-complete.log`.
- Another fresh-slot, no-write replay completes the third Ice Path B3 sequence
  through `13.14a`–`13.14c` and the flag-backed `13.14` objective at route row
  `248/315`; its log is `gold-route-13.14-third-boulder-complete.log`.
- A fresh-slot, no-write replay completes the fourth Ice Path B1F sequence
  through `13.15a`–`13.15d` and the flag-backed `13.15` objective at route
  row `253/315`; its log is
  `gold-route-13.15-fourth-boulder-complete.log`.
- The Gold route planner now chains an Ice Path slide after a ledge jump,
  matching the live host's movement semantics. A fresh-slot, no-write replay
  then reaches Blackthorn through `13.26` and completes the `13.27` heal at
  route row `255/315` with zero harness teleports; its log is
  `gold-route-13.27-blackthorn-heal-fixed.log`.
- The same fresh-slot, no-write route reaches optional `13.26b`, buying two
  FULL RESTOREs at Blackthorn for ¥6000; its retained log is
  `gold-route-13.26b-full-restores.log`.
- The fresh-slot, no-write route then satisfies the `13.g` level gate and
  reaches `13.28` at route row `258/315` (Blackthorn Gym 1F) with zero
  harness teleports; its retained log is
  `gold-route-13.28-blackthorn-gym.log`.
- The next fresh-slot, no-write replay reaches `13.28b` at route row
  `259/315` (Blackthorn Gym 2F) with zero harness teleports; its retained log
  is `gold-route-13.28b-gym2f.log`.
- A follow-up fresh-slot, no-write replay exercises the Gym trainer slice:
  `13.28c` reaches the live Fran/Cody battles, `13.28d` confirms the Fran
  event, and `13.28h` heals at Blackthorn's Pokécenter (`262/315`). It uses
  zero harness teleports; the retained log is
  `gold-route-13.28h-gym-heal.log`.
- Gold route recovery now escapes both defeated-trainer approach cells and
  fixed map-object blockers such as Route 36's fruit tree. Targeted route
  preferences also keep Ecruteak on the direct Route 36 -> Route 37 approach
  and Blackthorn Gym objectives on the direct Route 45 -> Blackthorn City
  approach. A fresh-slot, no-write replay reaches `13.29a0` at row `264/315`
  and pushes the first Blackthorn Gym 2F boulder with zero harness teleports
  and zero travel-loop give-ups; the retained log is
  `G:\dev\misc\gold-route-13.29a0-final-replay.log`. The Gold save remained
  unchanged.
- The next fresh-slot, no-write replay completes the remaining Blackthorn Gym
  2F boulder puzzle through `13.29a`–`13.29f`, reaching route row `272/315`
  with zero harness teleports and zero travel-loop give-ups. The retained log
  is `G:\dev\misc\gold-route-13.29f-boulders.log`; the Gold save remained
  unchanged.
- Gold route battle healing now targets the active battle Pokémon after a
  switch instead of always sizing the item from party slot 1; this prevents a
  healthy switched-in mon from receiving a repeated no-effect item. A fresh
  no-write replay then defeats Clair at `13.30` (route row `274/315`) with
  zero harness teleports, zero travel-loop give-ups, and zero no-effect item
  retries. The retained log is
  `G:\dev\misc\gold-route-13.30-clair-fixed.log`; the Gold save remained
  unchanged.
- A further fresh-slot, no-write replay continues through the Dragon's Den
  boundary: `13.32` arrival, `13.33` Dragon Fang, and the flag-backed
  `13.33b` `ENGINE_RISINGBADGE` check at route row `277/315`. The replay used
  no harness teleport shortcut, recorded no travel-loop give-up, and recorded
  no no-effect item retry. Clair required one bounded retry before her defeat;
  the retained log is
  `G:\dev\misc\gold-route-13.33b-risingbadge.log`, and the Gold save remained
  unchanged.
- The Gold route now models HM07 Waterfall as a real climb from shore/current
  tiles and adds an explicit full-party heal after the Dragon's Den badge
  check (`13.33c`) before Route 27's trainer gauntlet. A second fresh-slot,
  no-write replay reaches the Victory Road gate at `16.55` (route row
  `290/316`), including the Tohjo Falls climb and Route 27 -> Route 26 seam,
  with zero harness teleport shortcuts and no route-row failures. One bounded
  travel-loop recovery occurred while the pre-gate heal searched from the
  Victory Road Gate; the retained log is
  `G:\dev\misc\gold-route-16.55-victory-gate-healed-2.log`, and the Gold save
  remained unchanged.
- The Section 16 route now uses the documented Route 26 heal house (`16.43b`)
  before the Victory Road trainer run. A fresh-slot, no-write replay reaches
  the Victory Road rival at `17.15` (route row `294/317`) and defeats Silver
  with zero harness teleport shortcuts, zero route-row failures, and zero
  no-effect item retries. Two bounded travel-loop recoveries occurred early
  in the fresh replay; the retained log is
  `G:\dev\misc\gold-route-17.15-rival-healhouse.log`, and the Gold save
  remained unchanged.
- A fresh-slot, no-write replay now reaches the Pokémon League entrance at
  `18.4` (route row `295/317`) after the Victory Road rival, with zero harness
  teleport shortcuts and no route-row failures. Two bounded travel-loop
  recoveries occurred during the long fresh replay; the retained log is
  `G:\dev\misc\gold-route-18.4-league-entrance.log`, and the Gold save remained
  unchanged. This proves League entry only; the one-way Elite Four gauntlet
  remains the next host smoke boundary.
- League preparation now passes through `18.4c` (route row `301/317`): the
  Victory Road grind reaches its configured lead-level gate, the pre-gauntlet
  shop restocks HYPER POTION, FULL RESTORE, and REVIVE, and the party heals at
  Indigo Plateau. The fresh no-write replay used zero harness teleports and
  zero travel-loop give-ups; its only route failure was the pre-existing early
  optional `01.6` row. The retained log is
  `G:\dev\misc\gold-route-18.4c-league-prep.log`, and the Gold save remained
  unchanged.
- The first one-way Elite Four battle now passes: a fresh replay reaches
  `18.9` (route row `304/317`) and defeats Will with no route-row failure and
  no no-effect item retry. That long replay had one pre-League Dark Cave
  harness fallback and four bounded early travel-loop recoveries; the retained
  log is `G:\dev\misc\gold-route-18.9-will.log`, and the Gold save remained
  unchanged. Koga, Bruno, Karen, Lance, and the Champion remain unproven.
- The Route 26 heal-house row now suppresses the generic pre-row heal, so the
  real teacher interaction is not preceded by a detour through the Slowpoke
  Well pocket. A fresh no-write replay then defeats Will (`18.9`), Koga
  (`18.11c`), and Bruno (`18.13c`) with zero harness teleports, zero
  travel-loop give-ups, zero route-row failures, and zero no-effect item
  retries. The retained log is
  `G:\dev\misc\gold-route-18.13c-bruno-healhouse-fixed.log`, and the Gold
  save remained unchanged. Karen, Lance, and the Champion remain unproven.
- A fresh no-write replay continues the one-way gauntlet through Karen
  (`18.15c`, route row `313/317`) after Bruno, with zero harness teleports,
  zero travel-loop give-ups, zero route-row failures, and zero no-effect item
  retries. The retained log is
  `G:\dev\misc\gold-route-18.15c-karen.log`, and the Gold save remained
  unchanged. Lance and the Champion remain unproven.
- A subsequent Champion attempt reached the real
  `EVENT_BEAT_CHAMPION_LANCE` flag and the `18.20` Hall of Fame boundary after
  seven bounded retry laps. This is progression evidence only: the long
  replay still contained two pre-League harness teleports, one `13.g` route
  failure, and five bounded travel-loop recoveries. Its retained log is
  `G:\dev\misc\gold-route-18.20-champion-finish.log`.
- The Gold route harness now vetoes live slot writes by default, while
  explicit checkpoint files remain available for retry/resume work. The Gold
  Hall of Fame ceremony now uses the owning game's canonical save writer, so
  the veto also covers its in-ceremony SaveGameData path. A post-fix replay
  retained the original 4,345-byte slot unchanged; it did not independently
  re-prove the Champion before its battle retry budget expired. Its log is
  `G:\dev\misc\gold-route-18.20-champion-no-save-fixed.log`.
- The League segment now has a clean ephemeral proof from a preserved full-
  party `18.4c` checkpoint: the Champion was defeated and the `18.20` Hall of
  Fame boundary was reached with zero harness teleports, zero travel-loop
  give-ups, zero route failures, and eight bounded battle retries. The route
  harness held the post-credits title reset in memory, so no disk write was
  needed; the 4,345-byte Gold slot remained unchanged. The retained log is
  `G:\dev\misc\gold-route-18.20-champion-ephemeral-no-save.log`.
- A single continuous ephemeral replay now covers the untouched initial Gold
  slot through the Champion and `18.20` Hall of Fame boundary. It records zero
  harness teleports, zero travel-loop give-ups, zero route failures, one real
  Champion win, and eight bounded battle retries; the live slot remains the
  original 4,345 bytes. The retained log is
  `G:\dev\misc\gold-route-18.20-full-ephemeral-no-save.log`.
- Release evidence now distinguishes full integrated-presenter/Gallery coverage
  from sampled real-gameplay coverage; native-by-design and deferred screens
  remain outside Clean UI replacement claims.

### Release readiness

- Shared-core `scripts\invoke_tests.ps1 -Suite all`, vendored-core lock, Gen2
  product verification, compatibility, and host checks are green.
- The `v0.1.0` release is published with the updater-ready
  `gen2_clean_ui-0.1.0.zip` asset. GitHub's recorded asset SHA-256 is
  `1460A201BC0F6B8F1BF70A8BB02425B7CB3E0F6D1C75079DDF1F04447752D172`.
- The current working tree also rebuilds a deterministic 153-entry
  `gen2_clean_ui-0.1.0.zip` locally with SHA-256
  `2B6ECE65D7A52B8EFE372FA1A54CD06BAD3203D2BFAC68373FF2C36DFA129EA2`;
  this local artifact was not published and does not replace GitHub's
  recorded release asset.
- Release publication uses the workflow token explicitly through `GH_TOKEN`,
  so archive creation, tag handling, notes generation, and release creation
  complete in one Actions run.
- Follow-up no-write real Gold probes from a fresh slot advanced the gameplay
  route through Ecruteak, Radio Tower, the Goldenrod Underground/Card Key
  sequence, and Ice Path HM07 acquisition/teaching into the Ice Path B1F
  boulder sequence at `13.12a` (the clean probe reached route row `234/315`;
  the bot summary reported `233/315` completed after optional misses). Two
  independent probes also completed the full 11-tile second boulder push at
  `13.12b`, reaching route row `235/315`, but used one or two pre-Ice-Path
  harness teleports. The new host bot fix has been verified independently in a
  no-write targeted Love2D run: it cleared the Dark Cave Violet rocks at
  `(7,14)` and `(16,14)` through the real Rock Smash script and entered Route
  46 at `(35,33)` with no teleport shortcut. The latest full replay from the
  untouched initial save also crossed the Route 42 east seam without a Route
  42 shortcut, completed the Lake of Rage and Mahogany event chain, and
  reached `13.27` with zero teleport shortcuts. See [release status](docs/RELEASE_STATUS.md)
  for the remaining host-readiness gates.
- See [release status](docs/RELEASE_STATUS.md) for the exact gates remaining.
