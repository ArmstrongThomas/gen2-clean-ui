# Gen2 Clean UI release status

Current line: `0.4.1` (development). The `0.4.0` release is complete.

## Battle UI deferment — 2026-08-15

The failed Gen2 Clean UI battle implementation has been removed from the
active package and archived at
`docs/archive/battle-ui-deferred-2026-08-15/`. `Gen2BattleState` and
`Gen2BattleTransition` are explicitly deferred/native, so the official host
retains the complete battle path. No battle rewrite architecture is selected;
the design goals remain documented in `docs/BATTLE_SYSTEM_HANDOFF.md` for a
later effort.

## Pokegear-family deferment — 2026-08-15

The active replacements for `Gen2Pokegear` and `Gen2MapRadio` are disabled.
The official renderer owns the complete Pokegear flow, including phone, clock,
map/Fly, and radio surfaces. Existing adapters, presenters, and fixtures are
retained only as inactive reference material for a later redesign.

The Pokédex remains active. The 0.4.1 redesign now uses clearer Info and
Habitat compositions, map-backed landmark markers, number-first rows,
seen/owned markers, type badges, palette-aware detached sprites, totals, and
navigation hints. Evolution, level-up move, and TM/HM reference data is
detached and model-ready, but additional live pages remain pending a
drop-in-compatible navigation seam.

## Poké Mart commerce UI — 2026-08-15

The active Mart presenter covers the top-level menu, BUY list, SELL Pack child,
buy/sell quantity states, money, prices, owned inventory counts, and half-price
sell values from detached V3 data. The official transparent `MartMenu` contract
is now non-opaque, fixing the live `opacity_mismatch` fallback. A user
walkthrough confirms Clean UI ownership after sync; minor Mart bugs remain.

## Current state

- Shared font policy: OpenTTD Mono is the default 10px 1x face; Plain Pixel
  and System remain 15px 1x alternatives. Public choices are AUTO/1x/2x/3x,
  while explicit 4x is reserved for internal authored styles. The shared
  solver probes required text across the shell and detached V3 presentation
  families and steps down before truncation; this is deterministic coverage,
  not live-launcher proof.
- Current milestone: continue the 0.4.1 Pokédex visual redesign and
  verification. Battle is deferred and is not a release milestone for this
  worktree.
  Battle is deferred and is not a release milestone for this worktree.
- Runtime status: battle remains official-host/native by design. The previous
  live failure is no longer masked by an active Clean UI battle replacement.
- Follow-up order: Party; Trainer Card and Summary; Pack; Pokédex, Save,
  dialogue, and settings/pointer-touch behavior. Pokegear/Map/Radio remain
  native until a separate redesign.
- The preferred future map treatment is the extracted native graphic/composed
  map used by Gen1 Modern UI; the current Gen2 map renderer remains a
  follow-up target. Battle animation parity also needs the host's background
  scanline/palette and displacement/picture data before it can claim full
  visual equivalence.
- Caught-Pokémon nickname entry now selects the Gen1 Modern-style compact
  keyboard only after the released `ui.naming.grid` hook is confirmed; player,
  rival, and box naming remain native-board compatible.
- The release PR includes the accumulated source, documentation, and archived
  battle reference changes; it includes no screenshots or host-repository
  changes. The GitHub release archive remains workflow-generated after merge.

- Manifest version: `0.4.1`.
- Host floor: `>=0.1.87 <2.0.0`.
- Core lock: pinned to the `0.1.0-alpha.13-local` development snapshot recorded
  in `clean-ui-core.lock.json`; the shared settings compatibility fallback now
  persists through public `mod.storage` on hosts without `mod.options:set`.
- GitHub Actions validate the product and build logic. The `v0.1.0` release is
  published and its updater-ready archive is attached.
- The release workflow's `GH_TOKEN` binding is covered by commit `115e1bb`;
  the release job now completes archive creation, tag handling, notes, and
  publication.
- The product has 51 exact official contract records, 37 active production
  presenters, 12 native-by-design records, and 2 explicitly deferred battle
  records. The v0.1.86 exact-ID/source-registry fallback and live state-game
  lookup remain shared across all 51 records.

## Historical release notes

The remaining detailed battle and Pokegear bullets in this status document
record earlier experiments and host probes. They are retained for provenance
only and are not current Clean UI support, live proof, or active release
claims. The current boundaries are the deferments above and the battle archive
at `docs/archive/battle-ui-deferred-2026-08-15/`.
- The v0.1.86 generated-image compatibility fix lives entirely inside the
  drop-in mod and vendored Core. When `mod.ui.sourceImage` is unavailable, the
  runtime loads only validated `assets/generated/*.png` paths through
  sandboxed `love.graphics.newImage`. This restores the sprite-bearing Party
  and Battle replacement path without modifying the released launcher or
  host source.
- The 0.1.87 release-floor live-stack fix preserves the source-owned
  overworld backdrop beneath clean menus and submenus instead of treating the
  unlabelled world state as an unsupported UI layer. Labelled retained UI
  states still require a complete V3 presenter before native suppression.
- The Gen II Copyright splash, Game Freak Presents splash, Gold/Silver intro,
  and Gold title screen remain explicitly native/source-owned for the initial
  release. The experimental V3 raster/tile presenters are not registered for
  gameplay, preventing incomplete scanline or sprite extraction from touching
  these screens. Credits remains on its separately audited V3 path.
- Egg Hatch now uses a full-viewport V3 animation presenter with source-owned
  beat timing, extracted egg and hatchling art, palette selection, crack
  frames, and normalized shell fragments; incomplete art still fails open.
- Evolution now uses the same canonical V3 animation seam for source-owned
  flash/reveal timing, blackout and palette-aware species art, text beats, and
  expanding light-circle particles; incomplete art/data still fails open.
- Gold/Silver Intro is explicitly native until its scrolling raster/tile seam
  is proven; the callback-free cinematic fixture remains an editor experiment,
  not a gameplay replacement.
- Core and Studio now share strict V3 animation-sprite validation for asset
  paths, placement rectangles, integer crops, flips, and palettes. Product
  smoke validates every direct screen published by the callback-free V3 catalog
  before presenter coverage is considered green.
- `Gen2BattleState` menu, move-selection, message, forced-switch,
  next-Pokémon, progression, evolution, and nickname frames now use a
  phase-independent Clean UI battle envelope sized for the four-move state,
  so the status cards, sprites, and arena do not squish when menus open.
  Metadata-rich status cards retain gender, conditions, wild catch state, and
  player EXP, with HP above EXP on the player card and the native Gen II
  diagonal: enemy status upper-left/enemy sprite upper-right, player sprite
  lower-left, and player status lower-right. The portrait command menu remains
  a 2x2 grid.
- Battle now uses a spacious 960×540 logical 16:9 surface (540×960 on phones)
  so the fixed upper stage remains roughly three times the lower dock instead
  of collapsing toward a 1:1 split. The classic 10:9 surface remains opt-in.
- Intro/trainer-slide rendering now uses detached trainer descriptors when the
  source phase says a trainer is on screen; Pokémon sprites are not drawn into
  the trainer slot before send-out. Incomplete animation OAM cannot blank the
  clean base sprites or clear a status rail.
- V3 also exposes `BATTLE_CLASSIC`, a centered 10:9 surface for original-ratio
  portrait previews, alongside the default 16:9 wide and 9:16 phone surfaces;
  resolved layout metadata reports the selected aspect to Studio tooling.
- Live intro/send-out, faint, move/item/Poké Ball OAM frames stay inside the
  Clean UI presenter. The OAM crop-index multi-return regression that exposed
  native battle frames is fixed, unavailable optional effect sheets skip only
  that effect tile, and Park Ball/item variants are classified through the
  same detached animation model. Supported battle child Party/Pack/Naming and
  related screens now replace their native battle frame; unknown/native child
  stacks still fail open. Tutorial battles without a player Pokémon receive a
  safe detached placeholder so the clean frame does not crash or expose a
  partial native overlay. Source timing/scanline parity remains authoritative.
- Battle intro also carries the released host's player back-pic and opponent
  trainer-class front-pic through palette-aware V3 descriptors, then hands off
  to Pokémon sprites at the source send-out/slide boundary; old asset caches
  without those paths fail open without suppressing native art.
- Egg Hatch is now a V3 cinematic presenter with source-owned beat timing,
  extracted egg/hatchling art, palettes, cracks, and normalized shell fragments;
  missing assets fail open to native.
- Pokegear now has a responsive smartphone-style shell and the Map card uses
  the extracted native Johto/Kanto tilemaps, shared gear sheet, and per-tile
  palette map. Landscape view uses a 16:9 shell, portrait view uses a 9:16
  shell, and Fly presents the map beside its destination list. The renderer
  retains a marker/grid fallback when the host asset loader is unavailable and
  uses the native cursor-sheet artwork when it is available.
- API V3 now advertises the editor-facing `contract_catalog` capability. Its
  `cleanUiHost.listContracts(filter)` method returns copied declarative
  descriptors without action or rendering callbacks. Direct V3 presentation
  model screens now cover menu, dialogue, choice, battle, and animation previews. The
  product's Main Menu, Start Menu, Options, TextBox, ChoiceBox, Party, Summary,
  Pack, Pokegear, Map Radio, Pokedex, Trainer Card, Save, Battle, Credits,
  Egg Hatch, and Evolution presenters emit the
  canonical V3 model shape
  and register `gen2_foundation_menus`, `gen2_shared_dialogue`,
  `gen2_party_menus`, `gen2_inventory_device`, `gen2_progress_menus`,
   `gen2_battle_preview`, `gen2_battle_animations`, `gen2_boot_animations`,
   `gen2_cinematic_animations`, and `gen2_extended_menus` for the standalone editor
   WIP; the core's
   `ui-editor-fixture` remains the deterministic panel/dropdown/modal and
   direct-presentation target.
- Gen2 additionally publishes `gen2_official_catalog`, a callback-free
  51-entry status inventory carrying each exact host screen ID, support state,
  milestone, and native reason. It is metadata-only and does not alter native
  suppression behavior.
- The former Pokegear V3 gap is now closed at the declarative boundary:
  smartphone/card views emit `kind="device"`, while Map/Fly emit
  `kind="map"`. Core validates and renders their portable device descriptor,
  landmark/Fly rows, native tilemap geometry, and cursor-sheet metadata.
  Live animation timing, source identity, and complete child-stack ownership
  remain source-owned/fail-open boundaries; no legacy callback or placeholder
  banner is being counted as a replacement.
- Battle regression coverage also verifies that live move/item/Poké Ball OAM
  frames are detached data under the canonical V3 battle model rather than
  callback or renderer state, including the no-native-fallback crop path,
  Park Ball/item classification, tutorial extraction, supported battle-child
  stack assessment, and touch selection of the next-Pokémon prompt.
- V3 presenters are now gated at the provider boundary on the canonical schema,
  `apiVersion=3`, and a non-empty model kind; malformed markers fail open before
  suppression.
- Product smoke validates every model-ready production Gallery fixture against
  the canonical Core V3 model validator.
- Release tooling now derives its smoke-test version, tag, and curated blurb
  from the manifest rather than hard-coding `0.2.0`.
- The normal scaffold gate also requires that matching curated blurb to exist
  and be non-empty.
- Product smoke also asserts the exact twelve native-by-design IDs, including
  the complete Pokegear family and the Copyright, Game Freak Presents,
  Gold/Silver Intro, and Title boundaries, so rejected presenters cannot
  return silently.
- The shared core now repeats canonical V3 presentation validation immediately
  before measurement and rendering, so malformed direct provider results fail
  open before they can suppress native UI.
- The standalone Studio bridge now boots the sibling core source when present,
  delegates direct V3 model validation/measurement/rendering to that source,
  and preserves callback-free catalog presentation models during export.
- Core and Studio share strict V3 panel descriptor validation for dense
  component collections, stable IDs, known fields, nested options/fields,
  footer lists, and type-specific required payloads; malformed panel contracts
  fail before export or registration and replacement remains atomic.
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
- The combined NAV/M responsive matrix passes 40,567 checks across the same
  viewport, UI-size, text-size, font, density, and safe-area combinations,
  including the shared largest-fitting font-step fallback regression.
- The product now exports the Modern UI v1/v2 compatibility facade alongside
  `cleanUiHost` V3; its compatibility suite passes 33 checks with a graphics
  window and 30 in headless mode, and v2 surface failures retain native UI.
- The shared-core unit suite passes 259 checks after the live battle OAM
  regression was added; the vendored-core lock and host
  `gen2check --strict --notes` remain covered by the product test run.
- The Gold route driver now excludes the active battle mon when choosing both
  an optional SHIFT replacement and a switch-training fighter; the host battle
  UI regression suite covers that selection rule.
- The Gold route bot now recognizes live `SMASHABLE_ROCK` objects, uses the
  real Rock Smash A-press flow when a reachable rock blocks navigation, and
  re-plans before entering the destination warp.
- Connected-edge navigation now checks the destination landing strip while
  selecting a source border cell. The Route 37 -> Ecruteak edge probe chooses
  `(8,0)` and lands at `(18,35)`, avoiding nearer source cells whose aligned
  destination is scenery.
- The route bot's trainer recovery now requires a live sighted trainer record,
  ignores beaten trainers, and gives each failed interaction a finite retry
  budget. Defeated trainers that leave the player boxed against their approach
  cell now trigger a bounded retreat and re-plan. This removes the previously
  observed false-positive recovery loop on an ordinary Route 36 NPC.
- Connected-edge landing validation now treats a Surf-capable water border as
  a shore-to-water transition even while the player is still on foot. Focused
  native LOVE checks pass for both boarding Surf at the seam and crossing while
  already Surfing; this targets the Cianwood City -> Route 41 failure.
- Region-aware travel now carries its intended destination region through edge
  hops and filters candidate landings with a static forward/reverse fill. A
  native behavior check excludes a disconnected destination pocket as expected;
  arrival warps are re-armed before edge-target selection, live source-region
  exits can replace stale pre-warp hints, and a failed border walk is rescanned
  after dynamic trainer recovery.
- The battle responsive matrix passes 21,921 checks across short landscape,
  portrait, desktop, ultrawide, 4K, and 5K combinations, including explicit
  diagonal card/sprite mapping, HUD/sprite containment, and overlap checks.
- Real-route evidence is scoped: the contract, presenter, Gallery, and visual
  suites cover integrated Clean UI surfaces; the Gold run proves only the
  supported screens encountered along that gameplay path. The remaining
  native-by-design records remain explicitly outside Clean UI replacement
  coverage; the official battle transition now uses the V3 transparent overlay
  seam.

## Official v0.1.87 release-floor smoke (2026-08-14)

- The current AppData package is synced to the released, unmodified 0.1.87
  launcher path. No `gen1recomp` source or binary is patched or rebuilt.
- The live runtime probe reaches the Main Menu, Options, Start Menu, Pokédex,
  Pack, Pokegear, Trainer Card, Save, and Options submenu with
  `lastReason=ready` and native suppression active. A retained source-owned
  backdrop beneath Start Menu and Pack also suppresses cleanly instead of
  vetoing the stack.
- The complete contract/Gallery suite covers all 41 production presenter
  records and 779 production fixtures; the ten explicitly native-by-design
  boot/title records remain source-owned.

## Historical v0.1.86 compatibility smoke (2026-08-14)

- Testing uses the released, unmodified v0.1.86 launcher and the AppData mod
  installation. No `gen1recomp` source or binary is patched or rebuilt.
- The public-launcher runtime probe confirms that Party and Battle each
  produce a complete V3 candidate, render their generated Pokémon sprite art,
  and suppress the corresponding native screen.
- The same Battle probe exposes all four native command targets. The retained
  pointer provider can consume a pointer press and select the requested
  source-owned menu index in isolation, but production pointer/touch handling
  is currently disabled while screen-family coverage is incomplete.

## Real Gold host smoke (2026-08-13)

- The local patched Gold host loaded `gen2_clean_ui` with all 51 contract
  records and the vendored core marked ready.
- `tests/drivers/gold_menu_shots.lua` completed against the real Gold cache and
  produced 35 visual frames covering overworld, boot/menu states, Start Menu,
  Party, Pack, Pokegear clock/map/radio/phone, Trainer Card, Pokedex views,
  Options, Save, PC/storage, clock setup, and Fly Map. The captured frames were
  visually inspected locally.
- Real Gold battle-host probes also pass: trainer intro and sprite scaling,
  battle Pack refusal/return, forced-switch Party selection, and catch through
  the post-catch state. Battle-owned Pack/Party and post-catch child stacks
  remain native by design.
- The post-catch nickname path is now verified end to end on the real host:
  YES opens the Clean UI naming keyboard, directional input enters `CATCH`,
  and the settled party record retains the nickname. Evidence is retained
  under `G:\dev\misc\gold-battle-nickname-normal`.
- The full-party catch boundary also passes: with six party members, a caught
  Pidgey is inserted at slot 1 of the active PC box and the party remains full.
  Evidence is retained under `G:\dev\misc\gold-battle-boxfull-next`.
- Additional native-boundary probes pass on the same host: the EXP-bar crawl
  reaches level 10 through intermediate widths, and the naming/party flow
  passes full-name entry, spaces, NPC-held item display, and TAKE-to-bag
  behavior. These progression and child-stack paths remain native by design.
- Native battle-boundary smoke also passes all 17 sampled move animations, a
  benched REVIVE, and ETHER through the real move-selection screen. The host
  PP dispatch now normalizes the 1-based move index returned by both field and
  battle selectors; the probe explicitly honors Gold's persistent last-picked
  party cursor.
- Focused Gen 2 item coverage is green: 104/104 field checks and 94/94 battle
  checks. The battle fixture now supplies the A edges required by PromptButton
  text waits, so its headless turn drain matches the native host contract.
- The native battle-item probe was rerun against the established
  `pokemon-love2d` Gold cache identity and exited cleanly with both REVIVE on a
  benched mon and ETHER through move selection passing. The original Gold save
  remained byte-for-byte unchanged.
- Additional real-host child-state smoke passes Gold evolution, including
  B-cancel, PC move-to-box, Pack item submenu/toss, Egg summary rendering, and
  the live battle move-learning prompt/list path through `BattleState`. These
  remain native/deferred seams and do not claim stable-frame replacement.
- The evolution driver now observes the native flash/wait cancellation phase
  directly, avoiding screenshot-capture timing drift. An explicit rerun passes
  both full Chikorita -> Bayleef evolution and held-B cancellation back to
  Chikorita; evidence is retained under
  `G:\dev\misc\gold-evolution-next-fixed3`, and the original Gold save remains
  byte-for-byte unchanged.
- Real-host Summary coverage now captures the party list, all three Summary
  pages, poisoned and dual-type cases, and move descriptions. The naming/trade
  probe passes full rival-name keyboard edge cases, Kyle's named BITTER BERRY
  Onix, and TAKE-to-bag behavior; evidence is retained under
  `G:\dev\misc\gold-summary-next` and
  `G:\dev\misc\gold-naming-trade-next`.
- The native Egg boundary also passes the complete crack/wobble/burst/fragment
  sequence and the Sentret hatch-state Summary page. Evidence is retained
  under `G:\dev\misc\gold-egg-next`; hatch/evolution animation paths remain
  native by contract.
- A fresh replay of the deferred battle-child boundary passes independently:
  the native move-learning flow replaces TACKLE with QUICK ATTACK in slot 1,
  while the battle Pack revives a benched TOTODILE and restores PP through the
  move list with ETHER. The move-learning screenshots are retained under
  `G:\dev\misc\gold-battle-learn-next`; both drivers left the Gold save
  byte-for-byte unchanged.
- The real-host faint/forced-switch probe also passes: the fainted sprite exits
  its frame, the native party list rejects the fainted slot, accepts the healthy
  replacement, and the trainer sends out its next Pokémon. The animation and
  child list remain native by contract.
- Latest retained faint/forced-switch frames are under
  `G:\dev\misc\gold-battle-faint-next`.
- The long `tests/drivers/gold_bot.lua` route reached the Pryce checkpoint
  (`11.44`) through real map loading, warps, wild and trainer
  battles, Violet, Union Cave, Azalea, Kurt, Mart purchases, Slowpoke Well,
  Olivine, Cianwood, and the Lake of Rage. It completed 165 route rows with no
  teleport shortcuts; the required Cianwood all-party grind completed after
  widening its finite wipe-recovery budget, and one optional route miss remains
  (`04.5d`).
- The route fix was narrowly scoped to the host test adapter: both healthy-mon
  selectors now skip `battle.player`, preventing the prior repeated
  `QUILAVA is already out` loop.
- The Gold route validator now resolves the platform-specific LOVE cache when
  `GOLD_CACHE` is not provided; running it through LOVE against the Windows
  Gold cache passes all 4 shape, geometry, and milestone checks.
- Follow-up no-write Gold probes, each started from the fresh slot, passed the
  route through `12.0c` (Ecruteak), `12.9b` (Radio Tower Executive), `12.33`
  (Radio Tower clear), `13.10b` (Ice Path HM07 acquisition and teaching),
  `13.11` (Ice Path B1F), and `13.12a` (the first Strength boulder push),
  reaching route row `234/315` in the clean probe; the bot summary reported
  `233/315` completed after optional misses. Two independent no-write probes
  also completed `13.12b` (the full 11-tile second boulder push), reaching row
  `235/315`, but used one or two pre-Ice-Path harness teleports. A targeted
  no-write Love2D probe now exercises the repaired path: the bot clears the
  Dark Cave Violet rocks at `(7,14)` and `(16,14)` through the real Rock Smash
  script and enters Route 46 from `(35,33)` without a teleport shortcut. These
  are separate gameplay probes rather than a saved resume from `11.44`; the
  original save remained untouched. Logs are retained under
  `G:\dev\misc\gold-route-*.log`.
- A subsequent full no-write replay from the untouched initial save reached
  `13.12c` with the repaired Dark Cave traversal. The targeted Route 37 ->
  Ecruteak edge crossed naturally, and later full-route crossings used the
  same real seam; the latest replay also crossed Route 42's east seam at
  `(59,6)` without a Route 42 shortcut, selected Lake of Rage's main region
  for both the travel and Red Gyarados rows, completed the Mahogany staircase
  scene, and reached `13.12c` with zero teleport shortcuts. The retained log
  is `G:\dev\misc\gold-route-13.12c-lake-battle-region-fixed-replay.log`.
- Two further fresh-slot, no-write replays now complete the remaining first
  Ice Path B3 pushes through `13.12d`, `13.12e`, and the flag-backed `13.12`
  objective at route row `239/315`. The retained logs are
  `G:\dev\misc\gold-route-13.12d-boundary-replay.log` and
  `G:\dev\misc\gold-route-13.12-first-boulder-complete.log`; the original
  Gold save remains untouched.
- A further fresh-slot, no-write replay completes the second Ice Path B3
  sequence through `13.13a`–`13.13d` and the flag-backed `13.13` objective at
  route row `244/315`. The retained log is
  `G:\dev\misc\gold-route-13.13-second-boulder-complete.log`.
- Another fresh-slot, no-write replay completes the third Ice Path B3 sequence
  through `13.14a`–`13.14c` and the flag-backed `13.14` objective at route row
  `248/315`. The retained log is
  `G:\dev\misc\gold-route-13.14-third-boulder-complete.log`.
- A fresh-slot, no-write replay completes the fourth Ice Path B1F sequence
  through `13.15a`–`13.15d` and the flag-backed `13.15` objective at route row
  `253/315`. The retained log is
  `G:\dev\misc\gold-route-13.15-fourth-boulder-complete.log`.
- The Gold route planner now chains an Ice Path slide after a ledge jump,
  matching the live host's movement semantics. A fresh-slot, no-write replay
  reaches Blackthorn through `13.26` and completes the `13.27` heal at route
  row `255/315` with zero harness teleports. The retained log is
  `G:\dev\misc\gold-route-13.27-blackthorn-heal-fixed.log`.
- The same fresh-slot, no-write route reaches optional `13.26b`, buying two
  FULL RESTOREs at Blackthorn for ¥6000. The retained log is
  `G:\dev\misc\gold-route-13.26b-full-restores.log`.
- The fresh-slot, no-write route then satisfies the `13.g` level gate and
  reaches `13.28` at route row `258/315` (Blackthorn Gym 1F) with zero
  harness teleports. The retained log is
  `G:\dev\misc\gold-route-13.28-blackthorn-gym.log`.
- The next fresh-slot, no-write replay reaches `13.28b` at route row
  `259/315` (Blackthorn Gym 2F) with zero harness teleports. The retained log
  is `G:\dev\misc\gold-route-13.28b-gym2f.log`.
- A follow-up fresh-slot, no-write replay exercises the Gym trainer slice:
  `13.28c` reaches the live Fran/Cody battles, `13.28d` confirms the Fran
  event, and `13.28h` heals at Blackthorn's Pokécenter (`262/315`). It uses
  zero harness teleports. The retained log is
  `G:\dev\misc\gold-route-13.28h-gym-heal.log`.
- Gold route recovery now escapes both defeated-trainer approach cells and
  fixed map-object blockers such as Route 36's fruit tree. Targeted route
  preferences keep Ecruteak on the direct Route 36 -> Route 37 approach and
  Blackthorn Gym objectives on the direct Route 45 -> Blackthorn City
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
  seven bounded retry laps. This remains progression evidence rather than a
  clean route proof: that long replay contained two pre-League harness
  teleports, one `13.g` route failure, and five bounded travel-loop
  recoveries. The retained log is
  `G:\dev\misc\gold-route-18.20-champion-finish.log`.
- The Gold route harness now vetoes live slot writes by default, with explicit
  checkpoint files still available for retry/resume work. The Hall of Fame
  ceremony now uses the owning game's canonical save writer, so the veto also
  covers its in-ceremony SaveGameData path. A post-fix replay preserved the
  original 4,345-byte slot byte-for-byte; it did not independently re-prove
  the Champion before its battle retry budget expired. The retained log is
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
- The product's experimental opt-in was force-enabled only for the isolated
  smoke process and the temporary environment hook was removed afterward; the
  manifest remains unchanged.
- The local patched-host `mod.options:set` regression passes `74/74` checks
  across toggle, choice, number, and text schemas, including persistence,
  live/profile state, post-write event emission, and atomic invalid-write
  rejection. This is local host evidence only; the release floor remains the
  first official tagged host carrying the public API.
- The current working tree also rebuilds the deterministic 153-entry
  `gen2_clean_ui-0.1.0.zip` locally. Its SHA-256 is
  `2B6ECE65D7A52B8EFE372FA1A54CD06BAD3203D2BFAC68373FF2C36DFA129EA2`.
  This validation artifact was not published and does not replace the
  GitHub asset recorded above.

## Follow-up after 0.1.0

1. Expand the real-host smoke around deferred battle-owned child states.
2. Verify the native-art Pokegear Map and smartphone shell against the next
   host build, including the Johto/Kanto transition after the Elite Four.
3. Keep the v3 editor WIP aligned with the callback-free contract catalog;
   `ui-editor-fixture` is now validator-tested and is the next standalone
   editor integration target.
4. Promote the experimental flag only after the broader host route and release
   evidence are complete.

## Release automation

The workflow validates the manifest, core lock, sandbox, scaffold, and tests.
Its validation job also runs `tests/smoke_release_tools.ps1` in an isolated
temporary copy, rebuilding the archive twice and checking deterministic hash,
archive containment/order, manifest version, and required vendored-core files.
When the host floor is real, it builds one updater-ready ZIP, creates the
version tag if missing, writes notes from the previous tag's commit range,
loads the matching curated body from `docs/releases/vX.Y.Z.md`, records the
archive SHA-256, and creates the GitHub release. The release smoke test verifies
that the blurb, generated change section, and hash all appear in the rendered
notes. Development pushes with a `0.0.0-dev` host floor continue to skip
 publication; the current 0.2.0 package requires the official v0.1.87 floor.
Local visual-audit captures are intentionally not release files.
