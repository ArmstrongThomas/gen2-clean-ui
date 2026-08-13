# Product architecture

## Dependency direction

```text
main.lua
  -> src/bootstrap.lua
    -> src/product.lua
      -> settings
      -> contracts/catalog + screen families
      -> adapters + production presenters
      -> provider/identity + validation + stack policy
      -> gallery/status fixtures
      -> integration/core_bridge
        -> vendor/clean_ui_core/bootstrap.lua (when pinned)
```

`main.lua` only locates and invokes the product bootstrap. It must remain below
80 lines and must never accumulate presenters, contracts, settings, or hooks.

## Module ownership

- `contracts/families/foundation.lua`: Main, Start, and Options.
- `contracts/families/gameplay.lua`: Pack, Party, Summary, Pokedex, Trainer
  Card, Save, Naming, and the PC family.
- `contracts/families/services.lua`: services, Pokegear, mail, commerce, and
  specialty information screens.
- `contracts/families/native.lua`: battle/deferred, cinematics, animations,
  and minigames that Clean UI must not suppress.
- `provider/identity.lua`: exact ID, official metatable, opacity, source
  registry ownership, and instance-draw checks.
- `provider/init.lua`: protected validation and complete-presentation gate.
- `provider/stack_policy.lua`: whole-visible-stack proof and battle veto.
- `provider/live_stack.lua`: exact current-stack discovery and native-toggle
  gating; one unknown or unsupported retained layer keeps the whole frame
  native.
- `provider/source_input.lua`: maps measured pointer/wheel geometry back to
  source-owned selection and queued GB input.
- `adapters/*.lua`: bounded, defensive snapshots of exact official state.
- `presenters/foundation_models.lua`: registration and synthetic Gallery
  extraction for Main, Start, and Options. It does not draw or suppress.
- `presenters/foundation_presenters.lua`: converts those exact snapshots into
  shared production menu models with stable M/NAV envelopes.
- `clean-ui-core`: shared layout, themes, dropdowns, controls, rendering,
  diagnostics UI, V3 registry, and graphics-state transactions.

Product modules describe Gold. They do not duplicate a layout engine.

## Fail-open sequence

The provider evaluates a potential replacement in this order:

1. Exact `screenId` is present in the 51-record catalog.
2. No source screen-registry override owns that exact ID.
3. The state uses the cached official class from its exact host module.
4. The instance has no custom `draw` override and opacity matches the audit.
5. Base and active-mode validators succeed under `pcall`.
6. The record is neither native nor deferred.
7. A registered model adapter may prepare detached, function-free data while
   the source remains visible.
8. The complete visible stack passes policy, including the battle veto.
9. The shared core snapshots every presentation model and renders the entire
   replacement to a private canvas.
10. Only a successfully rendered one-frame candidate may make the exact
    source instances return false from `screen.render_visible`.

Any failure clears the one-frame candidate and leaves the complete native stack
visible. The pre-render boundary is `render.ui.prepare`; composition remains on
`render.hud`. No shared world/UI canvas is cleared.

## Source ownership

Clean UI only presents live source state and pointer geometry. The official
screen retains update, input semantics, callbacks, audio, save mutation,
timers, and transitions. Synthetic Gallery fixtures never construct live
screens or call source callbacks.

Model extraction keeps callable source actions in a separate deferred map.
The function-free model contains only stable action IDs and descriptors;
extracting it never executes source callbacks, row formatters, or mutations.

## Adding a Gold screen presenter

1. Update the existing exact record; do not add a suffix/class heuristic.
2. Tighten its base and mode validators only for fields the presenter reads.
3. Put the presenter in a screen-family module, not `main.lua`.
4. Add valid, malformed, custom-draw, class-override, and exception tests.
5. Add Gallery variants through the same production presenter.
6. Keep `implementation = "pending_presenter"` until the core can prepare the
   whole frame and stack atomically; then mark it `presenter_ready`.

## Host sandbox boundary

Shipped code reads only its own source through `mod:read`, compiles it with the
sandbox-provided `load`, and persists only through `mod.options`, `mod.save`,
or `mod.storage`. It does not use `io`, raw filesystem/process/thread APIs,
global package mutation, or bytecode. `_G` is private; V3 is published through
`mod.exports.cleanUiHost`.
