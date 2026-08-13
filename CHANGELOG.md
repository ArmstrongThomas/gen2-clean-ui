# Changelog

Release history for Gen2 Clean UI. Version 0.1.0 is an intentionally early,
experimental public release.

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
- Real Gold-host visual smoke completed 35 captured frames across boot/menu,
  Start Menu, Party, Pack, Pokegear, Trainer Card, Pokedex, Options, Save,
  PC/storage, clock setup, and Fly Map through the host's menu driver.
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
- Release evidence now distinguishes full integrated-presenter/Gallery coverage
  from sampled real-gameplay coverage; native-by-design and deferred screens
  remain outside Clean UI replacement claims.

### Release readiness

- Shared-core `scripts\invoke_tests.ps1 -Suite all`, vendored-core lock, Gen2
  product verification, compatibility, and host checks are green.
- The manifest remains development-only (`game_version: 0.0.0-dev`), so the
  automated release job is expected to skip archive publication until an
  official host floor is selected.
- See [release status](docs/RELEASE_STATUS.md) for the exact gates remaining.
