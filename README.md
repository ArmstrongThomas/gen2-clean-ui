# Gen2 Clean UI

Development line for a clean, modular Pokémon Gold UI. Main, Start, Options,
shared dialogue/choices, the 0.2 gameplay/storage family, and the complete
audited 0.3 family set now have exact-contract production presenters behind a
fail-open offscreen frame gate. Stable Gen2 battle menus, move selection, and
message frames are included; transitions, animations, and battle-owned child
stacks remain native by design.

The shipped mod is compatible with the upcoming host sandbox: it uses
`mod:read`, sandboxed source loading, `mod.options`, `mod.save`, and
`mod.storage` only. No raw filesystem, process, thread, package, or bytecode
access is required.

The installed mod is sandbox-ready: product and vendored-core modules load
through `mod:read` plus sandboxed `load`, never through raw filesystem APIs.
Run `scripts\verify_sandbox.cmd` before packaging. See the full
[sandbox compatibility contract](docs/SANDBOX_COMPATIBILITY.md) for the audited
API, path, bytecode/native-code, private-global, and persistence boundaries.

Gen2 Clean UI is the installable Pokemon Gold product from the Clean UI
rebuild. This repository deliberately keeps game-specific contracts and
presenters separate from the shared `clean-ui-core` design/layout runtime.

This checkout is a **native-safe product development line**. It inventories
and validates all 51 official Gold screen IDs from host `v0.1.79` and vendors
an exact, hashed shared-core development snapshot. The shell, dropdown,
Gallery, Mod Menus, and pinning foundations are active. All 37 supported
records have production presenters; 13 records are native by design and the
battle transition remains deferred.

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
- 37 records have production presenters (36 full + Hall viewer-only scope).
- 13 records are native by design.
- `Gen2BattleState` has a responsive production presenter for stable menu,
  move-selection, and message frames; `Gen2BattleTransition` remains deferred.
- Battle layout coverage includes short landscape, portrait phone, desktop,
  ultrawide, 4K, and 5K viewport matrices with native fail-open timing frames.
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

Reset Defaults writes every schema default through public
`mod.options:set`; there is no private manager writer or legacy import path.

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
```

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

No commit, tag, push, or release is produced by these scripts.
