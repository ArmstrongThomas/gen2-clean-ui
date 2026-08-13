# Pokemon Gold screen contract matrix

Authority: official host `v0.1.79`, commit
`04490c9b9ad03b814f297793dd7a950dad7c3adf`.

“Supported” denotes an audited Clean UI target contract. Main Menu, Start
Menu, and Options expose detached `model_ready` snapshots for
Gallery and future presenters; they still render natively until a complete
renderer and stack proof are available. Other supported contracts remain
`pending_presenter`. “Native” is native by design. “Deferred” is reserved for
the later complete Gold battle design.

| # | Exact ID | Target | Milestone | Envelope |
|---:|---|---|---|---|
| 1 | `Gen2BankOfMom` | Supported | 0.3.0 | XS |
| 2 | `Gen2BattleState` | Deferred | Post-1.0 | -- |
| 3 | `Gen2BattleTransition` | Deferred | Post-1.0 | -- |
| 4 | `Gen2BoxMenu` | Supported | 0.2.0 | XL |
| 5 | `Gen2CardFlip` | Native | Native | -- |
| 6 | `Gen2CenterPcMenu` | Supported | 0.2.0 | M |
| 7 | `Gen2ContestMenu` | Supported | 0.3.0 | L |
| 8 | `Gen2CopyrightSplash` | Native | Native | -- |
| 9 | `Gen2Credits` | Native | Native | -- |
| 10 | `Gen2DayCareMenu` | Supported | 0.3.0 | L |
| 11 | `Gen2DecorationMenu` | Supported | 0.3.0 | L |
| 12 | `Gen2Diploma` | Supported | 0.3.0 | L |
| 13 | `Gen2EggHatchAnim` | Native | Native | -- |
| 14 | `Gen2ElevatorMenu` | Supported | 0.3.0 | S |
| 15 | `Gen2EvolutionAnim` | Native | Native | -- |
| 16 | `Gen2GameFreakPresents` | Native | Native | -- |
| 17 | `Gen2GoldSilverIntro` | Native | Native | -- |
| 18 | `Gen2HallOfFame` | Supported: viewer only | 0.3.0 | L |
| 19 | `Gen2HeldItemMenu` | Supported | 0.3.0 | L |
| 20 | `Gen2InitClock` | Supported | 0.3.0 | M |
| 21 | `Gen2ItemPcMenu` | Supported | 0.2.0 | L |
| 22 | `Gen2MagnetTrainRide` | Native | Native | -- |
| 23 | `Gen2MailCompose` | Supported | 0.3.0 | XL |
| 24 | `Gen2MailMenu` | Supported | 0.3.0 | M |
| 25 | `Gen2MailRead` | Supported | 0.3.0 | M |
| 26 | `Gen2MailboxMenu` | Supported | 0.3.0 | M |
| 27 | `Gen2MapRadio` | Supported | 0.3.0 | L |
| 28 | `Gen2MainMenu` | Supported | 0.1.0 | M |
| 29 | `Gen2MartMenu` | Supported | 0.3.0 | L |
| 30 | `Gen2MoveDeleter` | Supported | 0.3.0 | L |
| 31 | `Gen2NamePick` | Supported | 0.3.0 | M |
| 32 | `Gen2NamingScreen` | Supported outside battle | 0.2.0 | XL |
| 33 | `Gen2OakSpeech` | Native parent | Native | -- |
| 34 | `Gen2OptionsMenu` | Supported | 0.1.0 | M |
| 35 | `Gen2PackMenu` | Supported outside battle | 0.2.0 | L |
| 36 | `Gen2PartyMenu` | Supported outside battle | 0.2.0 | L |
| 37 | `Gen2PcMenu` | Supported | 0.2.0 | M |
| 38 | `Gen2PhotoStudio` | Supported | 0.3.0 | L |
| 39 | `Gen2PokedexMenu` | Supported | 0.2.0 | L |
| 40 | `Gen2Pokegear` | Supported | 0.3.0 | L |
| 41 | `Gen2SaveMenu` | Supported | 0.2.0 | M |
| 42 | `Gen2ScriptMenu` | Supported | 0.3.0 | M |
| 43 | `Gen2SlotMachine` | Native | Native | -- |
| 44 | `Gen2StartMenu` | Supported | 0.1.0 | NAV |
| 45 | `Gen2SummaryMenu` | Supported outside battle | 0.2.0 | L |
| 46 | `Gen2TitleState` | Native | Native | -- |
| 47 | `Gen2TradeAnim` | Native | Native | -- |
| 48 | `Gen2TradeMenu` | Supported | 0.3.0 | L |
| 49 | `Gen2TrainerCard` | Supported | 0.2.0 | L |
| 50 | `Gen2UnownPrinter` | Supported | 0.3.0 | L |
| 51 | `Gen2UnownPuzzle` | Native | Native | -- |

Shared, unregistered seams are tracked as `shared.TextBox`,
`shared.ChoiceBox`, and `gold.CallerBox`. `CallerBox` remains explicitly
native/pending because the public host API has no proven exact identity seam.
Anonymous `PrizeMenu` is denied;
prize-counter fixtures use `Gen2ScriptMenu`.

The executable source of truth is
`mods/gen2_clean_ui/src/contracts/catalog.lua`. A future host ID must fail the
development coverage check while remaining unknown/native at runtime.
