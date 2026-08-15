# Pokemon Gold screen contract matrix

Authority: official host release `v0.1.87`. The package follows the public
release floor rather than pinning a mutable source-checkout commit.

“Supported” denotes an audited Clean UI target contract with a registered
production model adapter and presenter. Suppression still requires a complete
offscreen frame and whole-visible-stack proof at runtime. “Native” is native by
design. “Deferred” is reserved for a later host integration milestone.

Current implementation status: all 37 supported records are integrated into
product composition, production Gallery conversion, and aggregate tests. The
Gen2 battle records are explicitly deferred/native, and the complete Pokegear
family (`Gen2Pokegear` plus `Gen2MapRadio`) is native while its replacement is
deferred. The Pokédex remains active with a detached V3 list/preview
composition inspired by Gen1 Modern UI. Hall of Fame is viewer/display-only
and its induction phase remains native. Shared `gold.CallerBox` remains
native/pending because the public host API has no proven exact identity seam.

The V3 contract catalog also publishes `gen2_official_catalog`, a metadata-only
51-entry inventory for editor and diagnostic tooling. It preserves exact host
IDs, support state, milestone, and native reason without registering a
replacement screen or exposing source-owned callbacks.

| # | Exact ID | Target | Milestone | Envelope |
|---:|---|---|---|---|
| 1 | `Gen2BankOfMom` | Supported | 0.3.0 | XS |
| 2 | `Gen2BattleState` | Deferred: native battle path | Post-1.0 battle design | -- |
| 3 | `Gen2BattleTransition` | Deferred: native battle path | Post-1.0 battle design | -- |
| 4 | `Gen2BoxMenu` | Supported | 0.2.0 | XL |
| 5 | `Gen2CardFlip` | Native | Native | -- |
| 6 | `Gen2CenterPcMenu` | Supported | 0.2.0 | M |
| 7 | `Gen2ContestMenu` | Supported | 0.3.0 | L |
| 8 | `Gen2CopyrightSplash` | Native: source-owned boot splash | Native | -- |
| 9 | `Gen2Credits` | Supported | 0.2.0 | ANIMATION |
| 10 | `Gen2DayCareMenu` | Supported | 0.3.0 | L |
| 11 | `Gen2DecorationMenu` | Supported | 0.3.0 | L |
| 12 | `Gen2Diploma` | Supported | 0.3.0 | L |
| 13 | `Gen2EggHatchAnim` | Supported | 0.2.0 | ANIMATION |
| 14 | `Gen2ElevatorMenu` | Supported | 0.3.0 | S |
| 15 | `Gen2EvolutionAnim` | Supported | 0.2.0 | ANIMATION |
| 16 | `Gen2GameFreakPresents` | Native: source-owned intro | Native | -- |
| 17 | `Gen2GoldSilverIntro` | Native: raster seam unproven | Native | -- |
| 18 | `Gen2HallOfFame` | Supported: viewer only | 0.3.0 | L |
| 19 | `Gen2HeldItemMenu` | Supported | 0.3.0 | L |
| 20 | `Gen2InitClock` | Supported | 0.3.0 | M |
| 21 | `Gen2ItemPcMenu` | Supported | 0.2.0 | L |
| 22 | `Gen2MagnetTrainRide` | Native | Native | -- |
| 23 | `Gen2MailCompose` | Supported | 0.3.0 | XL |
| 24 | `Gen2MailMenu` | Supported | 0.3.0 | M |
| 25 | `Gen2MailRead` | Supported | 0.3.0 | M |
| 26 | `Gen2MailboxMenu` | Supported | 0.3.0 | M |
| 27 | `Gen2MapRadio` | Native: Pokegear family deferred | Native | -- |
| 28 | `Gen2MainMenu` | Supported | 0.1.0 | M |
| 29 | `Gen2MartMenu` | Supported | 0.3.0 | L |
| 30 | `Gen2MoveDeleter` | Supported | 0.3.0 | L |
| 31 | `Gen2NamePick` | Supported | 0.3.0 | M |
| 32 | `Gen2NamingScreen` | Supported outside battle | 0.2.0 | XL |
| 33 | `Gen2OakSpeech` | Native parent | Native | -- |
| 34 | `Gen2OptionsMenu` | Supported | 0.1.0 | M |
| 35 | `Gen2PackMenu` | Supported, including proven battle child | 0.2.0 | L |
| 36 | `Gen2PartyMenu` | Supported, including proven battle child | 0.2.0 | L |
| 37 | `Gen2PcMenu` | Supported | 0.2.0 | M |
| 38 | `Gen2PhotoStudio` | Supported | 0.3.0 | L |
| 39 | `Gen2PokedexMenu` | Supported | 0.2.0 | L |
| 40 | `Gen2Pokegear` | Native: Pokegear family deferred | Native | -- |
| 41 | `Gen2SaveMenu` | Supported | 0.2.0 | M |
| 42 | `Gen2ScriptMenu` | Supported | 0.3.0 | M |
| 43 | `Gen2SlotMachine` | Native | Native | -- |
| 44 | `Gen2StartMenu` | Supported | 0.1.0 | NAV |
| 45 | `Gen2SummaryMenu` | Supported outside battle | 0.2.0 | L |
| 46 | `Gen2TitleState` | Native: source-owned title | Native | -- |
| 47 | `Gen2TradeAnim` | Native | Native | -- |
| 48 | `Gen2TradeMenu` | Supported | 0.3.0 | L |
| 49 | `Gen2TrainerCard` | Supported | 0.2.0 | L |
| 50 | `Gen2UnownPrinter` | Supported | 0.3.0 | L |
| 51 | `Gen2UnownPuzzle` | Native | Native | -- |

Shared, unregistered seams are tracked as `shared.TextBox`,
`shared.ChoiceBox`, and `gold.CallerBox`. `CallerBox` remains explicitly
native/pending because the public host API has no proven exact identity seam.
The production presentation families—Main Menu, Start Menu, Options, TextBox,
ChoiceBox, Party, Summary, Pack, Pokedex, Trainer Card, Save, and the extracted
cinematic presenters—now emit the canonical
`clean_ui.v3.presentation.v1` model shape. Their representative V3 screens,
including the extended naming, storage, services, mail, clock, and Hall of Fame
examples in `gen2_extended_menus`, are also registered through the product's
  callback-free contract catalog for the standalone editor WIP. The separate
  `gen2_battle_animations`, `gen2_boot_animations`, and
  `gen2_cinematic_animations` provide
  callback-free experimental animation examples;
  source-owned timing and input remain provider-owned.
The 37 integrated official production presenters now require the canonical V3
model at the provider boundary, and the shared renderer repeats that check at
its final pre-measure/render boundary. The remaining 12 official records are
native by design and the two battle records are deferred. Egg Hatch uses
source-owned beat timing with extracted egg, hatchling, crack, and fragment
art. Evolution uses the same seam for source-authored flash/reveal sprites and
expanding light circles. Gold/Silver Intro, the Copyright splash, Game Freak
Presents, the title screen, and the complete Pokegear family remain native
until their replacement boundaries are separately designed and verified.

The migration target is roughly 99% of replaceable UI surfaces. A native
record remains only when the source-owned state or interaction is not yet
expressible without an approximation; a missing must-have is a Core/Studio
V3 capability candidate before the product adds another bespoke surface.

Anonymous `PrizeMenu` is denied;
prize-counter fixtures use `Gen2ScriptMenu`.

The executable source of truth is
`mods/gen2_clean_ui/src/contracts/catalog.lua`. A future host ID must fail the
development coverage check while remaining unknown/native at runtime.
