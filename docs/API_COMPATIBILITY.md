# Modern UI compatibility

Gen2 Clean UI keeps the public Modern UI presentation contracts available while
source mods migrate to Clean UI API V3. V3 is preferred for new integrations;
the compatibility facade is isolated from the V3 registry and fails open to
native UI when a legacy callback, model, or surface fails.

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
rules. The compatibility methods are retained for existing v1/v2 source mods,
not as a reason to add new legacy contracts.
