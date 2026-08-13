# Gen2 Clean UI

Development scaffold for a clean, modular Pokémon Gold UI. Main, Start,
Options, shared dialogue/choices, Pack, Party, all three Summary purposes,
Pokédex, Trainer Card, Save, Naming, and the Center/Player/Box/Item PC family
now have exact-contract production presenters behind a fail-open offscreen
frame gate. Remaining Gold surfaces stay native until their individual
validators, actions, Gallery fixtures, and full-stack tests exist.

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

This checkout is a **native-safe product scaffold**. It inventories and
validates all 51 official Gold screen IDs from host `v0.1.79` and vendors an
exact, hashed shared-core development snapshot. The shell, dropdown, Gallery,
Mod Menus, and pinning foundations are active. The foundation and first 0.2
gameplay/storage slice have production presenters; unfinished screens remain
native.

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
- 36 records have an audited future Clean UI contract (35 full + Hall viewer).
- 13 records are native by design.
- 2 battle records are deferred until the post-1.0 battle design.
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
[core vendoring](docs/CORE_VENDORING.md).

## Development checks

```powershell
.\tests\verify_scaffold.ps1
.\scripts\verify_core_lock.ps1
```

The Lua contract tests are in `tests/run_contract_tests.lua` and can be run
with the project's LÖVE/Lua test harness.

Against a host checkout, the Gold compatibility gate is:

```powershell
python tools\modkit.py gen2check `
  ..\gen2-clean-ui\mods\gen2_clean_ui --strict --notes
```

The current development tree passes this check. Full `modkit validate` still
requires a standalone `luajit` executable; LÖVE's embedded LuaJIT runtime is
not a command-line substitute for that validator dependency.

No commit, tag, push, or release is produced by these scripts.
