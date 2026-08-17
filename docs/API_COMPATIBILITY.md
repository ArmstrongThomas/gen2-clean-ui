# Modern UI compatibility

Gen2 Clean UI keeps the public Modern UI presentation contracts available while
source mods migrate to Clean UI API V3. V3 is preferred for new integrations;
the compatibility facade is isolated from the V3 registry and fails open to
native UI when a legacy callback, model, or surface fails.

## Host boundary and release-floor rule

This repository is a drop-in mod, not a host fork. `gen1recomp` checkouts and
launcher binaries are read-only compatibility references; never patch,
rebuild, or commit host changes from this project. Host differences are
handled by feature detection inside the mod/core package, with native fail-open
behavior when a required seam is unavailable. The manifest floor is the first
released host we support (`0.1.87` for the current line), and testing must use
a released host or a separately maintained host checkout without modifying it.

The screen fallback is shared by every official screen record: exact
`screenId`, source registry ownership, and the absence of an instance `draw`
override replace the newer optional builtin-class predicate. It is not a
main-menu exception. The runtime also uses the state-provided `game` object
when the host calls `screen.render_visible`, so Party, Battle, Pokegear,
dialogue, and every other screen family use the same fallback path. The live
stack preserves the source-owned overworld as a backdrop while requiring every
labelled retained UI state to pass its V3 presenter gate.

The public v0.1.86 host also predates `mod.ui.sourceImage`. The presentation
runtime therefore prefers that helper when available, but on v0.1.86 it may
load only validated `assets/generated/*.png` paths through the sandboxed
`love.graphics.newImage` facade. This release-floor fallback restores
generated sprite rendering for Party and Battle without broadening filesystem
access or requiring a host modification.

The public v0.1.86 host does expose the gameplay `input.pointer` hook and the
source-safe `mod.input:tap` helper. Clean UI retains the V3 pointer/touch
provider and hit-testing groundwork, but it is intentionally disabled and
hidden from the settings menu because screen-family pointer behavior is not
yet reliable. This is low priority until keyboard/controller and screen
replacement coverage are stable. The options facade is read-only on that host,
so the settings shell uses the public `mod.storage` facade as a persistent V3
fallback for the remaining toggles and reset actions. The fallback is scoped
to the active playthrough and is session-local only before a storage context
exists; a future `mod.options:set` writer remains preferred.

## Discovering the product

The host product ID is `gen2_clean_ui`. A source mod that supports both
generations should feature-detect both IDs:

```lua
local ui = mod:find("gen2_clean_ui") or mod:find("gen1_modern_ui")
if ui and ui.exports and ui.exports.registerAdapter then
  ui.exports.registerAdapter({
    owner = mod.id,
    contract = mod.exports.gen1ModernUi,
  })
end
```

The contract itself remains the Modern UI shape. Clean UI does not publish a
loader-level alias named `gen1_modern_ui`, because that would make dependency,
conflict, and game selection ambiguous. Existing Gen1 installs continue to use
the original product ID.

## API v1

The compatibility export preserves `version = 1`,
`compatibilityApiVersion = 1`, `registerAdapter`, `unregisterAdapter`,
`dispatchScreenAction`, `registerTheme`, and `registerFrame`. Data-first screen
models are normalized into Clean UI menu, choice, or dialogue models. Semantic
actions remain callbacks owned by the source mod and receive the same
`(game, state, payload)` arguments.

V1 screen draw/render callbacks are rejected. Models, themes, and frame
descriptors are copied and checked for callbacks, cycles, and unsupported
values before they can affect presentation.

## API v2

The facade advertises `surfaceApiVersion = 2` and preserves v1 data screens plus
v2 structured details, named actions, and custom surfaces. A custom surface
requires the same data-only virtual layout, explicit `native.policy`, and
`render(model, ctx)` callback as Modern UI. Clean UI renders it on a private
canvas inside a protected graphics-state transaction, commits only when the
callback returns `true`, and leaves native UI visible on failure.

Surface layouts use `contain` with `integer-fit` or `smooth-fit`, enforce the
2048-by-2048/four-million-pixel limits, and retain virtual-coordinate pointer
regions. `replace` surfaces must cover the complete visible stack; otherwise
the frame is rejected fail-open.

## V3 migration

New work should discover `exports.cleanUiHost` and require `apiVersion == 3`:

```lua
local host = ui and ui.exports and ui.exports.cleanUiHost
if host and host.apiVersion == 3 then
  host.register(mod.id, {
    id = "my_tools",
    version = "1.0.0",
    games = { "gen2" },
    actions = {},
    screens = {},
  })
end
```

V3 supplies atomic owner-scoped registration, declarative data, named actions,
capability discovery, Gallery fixtures, and stronger source/native ownership
rules. Hosts advertising `contract_catalog = "0.1.0"` also expose
`host.listContracts(filter)`, which returns copied editor-safe descriptors and
sorted `actionIds` without runtime callbacks. This is an inspection seam for
the standalone editor WIP; it does not execute actions or grant control of a
live game screen. Screen component action references are validated atomically
against the registered action table. Party and Summary presenters now also emit
the canonical V3 presentation model, and callback-free representative screens
are available through `gen2_party_menus`. The compatibility methods are
retained for existing v1/v2 source mods, not as a reason to add new legacy
contracts.

When the same UI contract is valid across both Clean UI products, use
`all_generations = true` instead of repeating the generation list:

```lua
host.register(mod.id, {
  id = "shared_tools", version = "1.0.0",
  all_generations = true,
  screens = {}, actions = {},
})
```

The V3 flag is preserved in `listContracts` descriptors. The mod manifest
still needs both product IDs in its `games` list because the launcher filters
packages before the V3 host can be discovered.

The v0.1.86 host predates `mod.ui.isBuiltinScreen`. Official Gen2 identity
validation therefore treats that predicate as optional: when it is available
it remains an additional class check, while the v0.1.86 path uses the exact
stamped `screenId`, the source screen registry, and the native draw-override
guard. This keeps native-screen replacement compatible with the released host
without weakening newer-host validation.

Gen2 additionally publishes `gen2_official_catalog`. Its 51 callback-free
Gallery descriptors preserve the exact host screen ID, `supported`/`native`
status, milestone, and native reason. Status entries are metadata-only and do
not claim a V3 replacement; a native record remains source-owned at runtime.

The former Pokegear V3 gap is now closed at the declarative model boundary:
its smartphone shell/cards emit `kind = "device"`, while Map and Fly emit
`kind = "map"`. Core validates and renders the portable device descriptor,
landmark/Fly rows, native tilemap geometry, and cursor-sheet metadata without
exposing callbacks. Source-owned navigation and asset loading remain behind
the product provider and continue to fail open when incomplete.

The remaining V3 gap is live animation timing, source identity, gameplay
mutation, and complete child-stack ownership. The animation model describes a
visual frame but does not own those source seams; they must be added and
validated in Core before Gen2 claims timing-heavy paths as fully portable.

Hosts advertising `presentation_models = "0.1.0"` enforce the canonical
`clean_ui.v3.presentation.v1` schema, `apiVersion = 3`, and a non-empty preset
for direct `menu`, `dialogue`, `choice`, `battle`, `animation`, `device`, and
`map` screens. Invalid direct
screens fail registration or action-result replacement without displacing the
previous valid screen.

The product itself is migrating its active presentation families through this
same model vocabulary. The current active slices include the Main Menu, Start
Menu, Options, TextBox, ChoiceBox, Party, Summary, Pack, Pokedex, Trainer
Card, Save, and supported service/commerce screens. Battle and the complete
Pokegear family are explicitly native/deferred in the current product; their
historical models and fixtures are not live replacement claims. Active slices
emit `clean_ui.v3.presentation.v1` models, and the product registers
callback-free `gen2_foundation_menus`, `gen2_shared_dialogue`,
`gen2_party_menus`, `gen2_inventory_device`, `gen2_progress_menus`,
`gen2_battle_preview`, `gen2_battle_animations`, and `gen2_extended_menus` contracts so the standalone
editor can inspect real Gen2 screens across naming, storage, services, mail,
clock, and Hall of Fame flows. Source-owned timing, navigation, and callbacks stay behind the
product provider until each family has an equivalent V3 action and replacement
seam.

The shared core repeats canonical model validation at the final
pre-measure/render boundary. A direct result with the wrong schema, API
version, kind, preset, required payload shape, sparse collection, or invalid
selection index fails open before native UI can be suppressed; legacy/custom
surfaces remain an explicitly validated compatibility path. The active product
goal is V3-first coverage for at least 99% of replaceable interactive
surfaces. Native/deferred IDs remain explicit only where complete-stack
suppression, timing, or world-capture seams are not yet proven; any must-have
capability found while closing those gaps should become a V3 fixture and API
regression before adding a compatibility-only path.

### Gen2 Party/Summary control boundary

The current development slice presents Gen2 Party and Summary through a
detached Clean layout. Party rows carry animated icon-sheet crops, the supplied
gender-sheet descriptor, HP, status codes, and one/two-type data; Summary
presents source-ordered `JOURNAL`, `MOVES`, and `DETAILS` tabs without resizing
the content envelope. Core also exposes reusable non-stretched text styles for
future panels. Presenters expose a plain-data `controlScheme` descriptor for
the intended Clean navigation.

Gender presentation uses the Gen2 species `genderRatio` when that V3 field is
available: `0x00` is male-only, `0xFE` is female-only, and `0xFF` is
genderless. The host uses `unknown` as its genderless runtime sentinel, which
the Clean adapter maps to the authored none icon. Ordinary ratios continue to
use the host's runtime gender so the mod does not reimplement battle
semantics. The current host `Mon.gender` implementation is known to derive
some ordinary and forced-gender results from DVs incorrectly; the adapter can
correct the forced endpoint species only when `genderRatio` is present in the
V3 species definition. If that field is absent from a payload, the adapter
falls back to the raw host value and records a remaining V3-data limitation.

That descriptor is not a controller implementation. The released V3 host
keeps update/navigation and action dispatch source-owned and does not expose a
safe edge-interception/remapping seam for these replacement screens. The
summary strip therefore follows the official source page order rather than
inventing a controller remap; this removes the visual tab inversion without
altering source input. The current product still does not claim live tab,
move-control, or icon-cadence proof, and does not synthesize held-input
behavior from `mod.input:tap`.
