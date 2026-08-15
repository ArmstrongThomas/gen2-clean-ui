# Gen2 Clean UI

Early experimental public release of a clean, modular Pokémon Gold UI. Main,
Start, Options,
shared dialogue/choices, the active 0.2 gameplay/storage family, and the
audited 0.3 family set have exact-contract production presenters behind a
fail-open offscreen frame gate. Gen2 battle and the complete Pokegear family
are deliberately native/deferred; the official host owns their timing,
input, rendering, and transitions. The active Pokédex uses detached V3 data
with a stable list/preview composition inspired by Gen1 Modern UI.

The shipped mod is compatible with the upcoming host sandbox: it uses
`mod:read`, sandboxed source loading, `mod.options`, `mod.save`, and
`mod.storage` only. No raw filesystem, process, thread, package, or bytecode
access is required.

The installed mod is sandbox-ready: product and vendored-core modules load
through `mod:read` plus sandboxed `load`, never through raw filesystem APIs.
Run `scripts\verify_sandbox.cmd` before packaging. See the full
[sandbox compatibility contract](docs/SANDBOX_COMPATIBILITY.md) for the audited
API, path, bytecode/native-code, private-global, and persistence boundaries.

The host repository and released launcher are external dependencies. Do not
patch, rebuild, or commit changes to `gen1recomp` from this repository. Use a
read-only host checkout only for API and contract inspection, and keep every
fix inside the drop-in mod, its vendored core snapshot, tests, or
documentation. The supported package must remain installable against the
latest released host that satisfies the manifest floor; host-specific seams
are feature-detected and must fail open when unavailable.

Gen2 Clean UI is the installable Pokemon Gold product from the Clean UI
rebuild. This repository deliberately keeps game-specific contracts and
presenters separate from the shared `clean-ui-core` design/layout runtime.

This checkout is a **native-safe product line**. It requires host release
`0.1.87` or newer, inventories and validates all 51 official Gold screen IDs
from the `v0.1.79` contract audit, and vendors an exact, hashed shared-core
snapshot. The shell, dropdown, Gallery, Mod Menus, and pinning foundations
are active. 37 records have production presenters; 12 records remain native
by design, including the complete Pokegear family and source-owned boot/title
scenes. Two battle records remain explicitly deferred.

## Repository shape

```text
mods/gen2_clean_ui/
  main.lua                 tiny entry/bootstrap handoff
  options.lua              public mod-options schema
  src/
    bootstrap.lua          product-local module loader
    product.lua            composition root
    contracts/             exact audited screen contracts
      families/            foundation, gameplay, services, native/deferred
    provider/              identity, shape, stack, and diagnostic gates
    gallery/               synthetic status-fixture catalog
    integration/           clean-ui-core bridge
  vendor/
    README.md               vendored-core policy
scripts/
  sync_core.ps1            deterministic core snapshot vendor
  verify_core_lock.ps1     exact path/size/SHA-256 verification
build_release.ps1          deterministic updater ZIP builder
```

The entry point is intentionally tiny. New screen work belongs in its screen
family module; reusable behavior belongs in `clean-ui-core`, never in
`main.lua`.

## Current contract status

- 51/51 official `Screens.GEN2_IDS` records are present in official order.
- 37 records have production presenters.
- 12 records are native by design; this includes `Gen2Pokegear` and
  `Gen2MapRadio`, so phone, clock, map/Fly, radio, and related child surfaces
  remain entirely source-owned.
- `Gen2BattleState` and `Gen2BattleTransition` are explicitly deferred/native;
  battle rewrite design notes are retained separately and are not active
  product support.
- NAV shell views choose and lock a 320–440 logical-pixel width from their
  required content, so short Start/Mod/settings menus no longer use unused
  horizontal space.
- Ordinary M list menus use the same content-driven sizing between 320 and
  600 logical pixels while preserving their full 420-pixel logical height;
  rich detail/sprite menus retain the wider envelope when it is required.
- Shared TextBox, ChoiceBox, and CallerBox seams are inventoried separately.
- Anonymous `PrizeMenu` objects are explicitly not claimed.

“Supported” in the catalog means the source contract has an audited target
presenter. It does not by itself authorize suppression. Implemented presenters
can suppress only after returning a complete offscreen result and proving the
whole visible stack; pending service contracts continue to fail open.

## Settings

The product schema contains the intentionally small Clean UI settings set:

- Theme: Clean, Dark, High Contrast
- UI Size: Auto, Small, Medium, Large
- Text Size: Auto or whole Plain Pixel steps 1x-4x
- Font: Plain Pixel or System
- Density: Auto, Comfortable, Compact
- Pointer & Touch
- generation-relevant Use Native UI switches

Reset Defaults writes every schema default through the public options surface,
using the shared V3 session-local fallback on hosts such as v0.1.86 that do not
yet expose `mod.options:set`. There is no private manager writer or legacy
import path.

## Core vendoring and builds

To refresh the checked-in development snapshot or pin a tagged core:

```powershell
.\scripts\sync_core.ps1 `
  -Source ..\clean-ui-core `
  -Tag v0.1.0 `
  -Commit 0123456789abcdef0123456789abcdef01234567

.\scripts\verify_core_lock.ps1
.\build_release.ps1
```

CI may pass a downloaded tagged archive with `-Archive` instead of `-Source`.
The release builder refuses pending or stale core locks. Its one output is
`gen2_clean_ui-<version>.zip`, rooted at `gen2_clean_ui/` for launcher updater
compatibility.

See [Architecture](docs/ARCHITECTURE.md),
[screen contracts](docs/GEN2_CONTRACTS.md), and
[core vendoring](docs/CORE_VENDORING.md),
[release status](docs/RELEASE_STATUS.md), and the
[changelog](CHANGELOG.md).

## Development checks

```powershell
.\tests\verify_scaffold.ps1
.\scripts\verify_core_lock.ps1
.\tests\smoke_release_tools.ps1
```

For local testing with the main launcher, double-click
`sync_gen2_clean_ui.cmd`. It copies the unpacked mod to
`%APPDATA%\pokemon-love2d\mods\gen2_clean_ui`, builds the launcher-ready
archive, and leaves the game ready to reload after restart. When the sibling
`gen1recomp-grandmas-kitchen` checkout exists, it may also mirror the exact
tree to that checkout's `mods/gen2_clean_ui` for an optional local source-tree
smoke test. That checkout is a read-only test target, not a product
dependency; the supported drop-in path is the released launcher and its
AppData mod installation.

For the v0.1.87 release-floor smoke, always use an unmodified released
launcher. After running `sync_gen2_clean_ui.cmd`, fully restart the launcher
and verify:

- Party opens in Clean UI with the Pokémon sprite, HP bar, status, and details
  visible, then closes without leaving a stale frame.
- Pokegear, Map, and Radio remain native while their replacement is deferred.
- Pointer & Touch operates on both replacement surfaces when enabled.

If Settings and Gallery render but Party or another active supported screen
remains native, treat that as a generated-image compatibility regression.
Pokegear-family and battle-native behavior is intentional. Do not patch or
rebuild `gen1recomp`; keep fixes inside the drop-in mod, vendored Core, tests,
or documentation.

The Lua contract tests are in `tests/run_contract_tests.lua` and can be run
with the project's LÖVE/Lua test harness.

## Modern UI compatibility

Gen2 Clean UI exports the Modern UI v1/v2 registration surface while existing
source mods migrate to API V3. See [API compatibility](docs/API_COMPATIBILITY.md)
for the discovery fallback, contract examples, and fail-open rules. New
integrations should use `exports.cleanUiHost` with `apiVersion == 3`.

Against a host checkout, the Gold compatibility gate is:

```powershell
python tools\modkit.py gen2check `
  ..\gen2-clean-ui\mods\gen2_clean_ui --strict --notes
```

The current development tree passes this check. Full `modkit validate` still
requires a standalone `luajit` executable; LÖVE's embedded LuaJIT runtime is
not a command-line substitute for that validator dependency.

### Versioned release blurbs

Keep the curated body for each manifest version in
`docs/releases/vX.Y.Z.md`. The release workflow runs
`scripts/write_release_notes.ps1`, which combines the matching blurb with the
generated commit list and archive SHA-256. A releaseable version fails its
release job when its blurb is missing, so the release description stays
intentional as versions advance.

Local build and verification scripts do not commit or push changes. The
release workflow also runs `tests/smoke_release_tools.ps1` before publication
to verify deterministic archive output. GitHub Actions owns the tagged
release archive and release notes after an authorized push to `main`.
