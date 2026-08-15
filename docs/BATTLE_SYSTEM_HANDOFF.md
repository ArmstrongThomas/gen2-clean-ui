# Gen2 Clean UI battle-system handoff

Last updated: 2026-08-15

This is the deferred handoff for a future Gen2 battle UI rewrite. The live
launcher report remains authoritative: the previous Clean UI battle attempt
was not reliable beyond intro, so battle work is intentionally paused rather
than extended from the failed implementation.

## Session safety and coordination

The user may be away and unable to approve permission prompts. Do not take
control of the user's machine, move or click through their desktop, launch
interactive applications, or perform live-controller testing without the
user's explicit direction. Avoid any operation that requires an approval
prompt while the user is away. Prefer repository inspection, deterministic
tests, read-only source comparison, and scripts that do not require approval.
Subagents may be used where they materially accelerate the work, with no more
than four running at once. Close every subagent as soon as its assigned work is
complete, and do not leave background agents running between slices.

## Deferred status — 2026-08-15

- `Gen2BattleState` and `Gen2BattleTransition` are explicitly deferred/native
  in the active contract catalog.
- The active battle adapters, presenters, detached renderer/layout, battle
  input routing, battle V3 preview contracts, ownership logic, and battle test
  runner were removed from the product path.
- The removed attempt is preserved at
  `docs/archive/battle-ui-deferred-2026-08-15/` as a read-only design/debug
  snapshot. Do not restore it piecemeal or treat its green fixtures as proof.
- The official host owns battle drawing, timing, input, sound, randomization,
  battle semantics, and state-stack transitions until a future rewrite is
  deliberately designed and implemented.

## Future design notes (not an architecture decision)

The next battle effort should revisit these product goals without assuming the
removed ownership/latch architecture:

- keep a stable upper field envelope and independently composed lower dock in
  landscape 16:9, portrait 9:16, and classic 10:9;
- reconstruct each visible source-timed frame from official V3 data, including
  field layers, sprites, OAM/effects, palette/scanline changes, rails, menus,
  messages, and post-battle progression;
- make native ownership and suppression explicit, with a safe boundary for
  every missing V3 field and no captured native canvas as a renderer;
- preserve host-owned timing/input/sound/randomization/state semantics and
  prove intro-to-command progression before expanding animation coverage.

## Future acceptance goals

When the rewrite is resumed, it should cover:

1. wild and trainer battle entry, including trainer slide, Poké Ball throw,
   send-out, and the handoff to the command menu;
2. the fixed battle field/status layout, command menu, move list, move detail,
   messages, and all four move slots;
3. move animations and their after-animations, including the correct source
   sheets, crops, palettes, OAM positions, flashes, shakes, and target side;
4. held-item, used-item, potion, Poké Ball, capture, wobble, escape, and
   caught/failure result stages;
5. damage, HP/EXP presentation, faint/final-hit, forced switch, and return to
   the battle command state;
6. experience growth, level-up, move learning, move replacement, nickname,
   evolution, and the final return transition.

The upper field and lower dock must remain fixed-size within each orientation.
Opening the command menu or move list must not squish, overlap, or truncate the
field, sprites, status cards, HP/EXP bars, or move information. These are
design goals only; this handoff does not select the future implementation
architecture.

## Working Gen1 Modern reference

Gen1 Modern is not a drop-in implementation for Gen2, but it is the strongest
reference for the missing runtime behavior. Inspect it read-only:

- `G:\dev\misc\gen1-modern-ui\mods\gen1_modern_ui\main.lua`
  - `battleRuntime.animationOffsets`: converts source animation displacement
    into the responsive battle surface;
  - `battleRuntime.captureSource`, `drawCapturedSource`, and
    `scrubNativeUi`: read these only as ownership/suppression ordering
    references; Gen2 Clean UI must not use a captured canvas as its renderer;
  - the `render.compose`/`render.hud` hook ordering: the important native
    suppression boundary, adapted to Gen2's detached V3 scene frame;
  - the battle presenter and its effect/sprite helpers: reference the way the
    correct move, trainer, ball, and effect assets are selected and drawn.
- `G:\dev\misc\gen1-modern-ui\tests\compose_suppression\main.lua`: use the
  battle suppression and animation tests as behavioral references, not as
  permission to copy Gen1 assumptions into Gen2.

The transferable lesson is the ordering: preserve source-owned timing/input,
consume a complete detached scene/effect frame, suppress the native copy only
after Clean UI ownership is proven, and draw the clean scene exactly once. Do
not replace a missing animation with a banner such as `ENEMY DAMAGE` or
`PLAYER DAMAGE`.

## Gen2 references for the future rewrite

The current product intentionally has no active battle renderer. The removed
attempt and its tests are archived here:

- `docs/archive/battle-ui-deferred-2026-08-15/`

Read-only released-host references:

- `G:\dev\misc\gen1recomp-reference\src\ui\gen2\BattleState.lua`
- `G:\dev\misc\gen1recomp-reference\src\ui\gen2\BattleAnimView.lua`
- `G:\dev\misc\gen1recomp-reference\src\battle\gen2\AnimRunner.lua`

The Gen2 host already owns animation script stepping, waits, sound, battle
semantics, scanline composition, and input. The mod must consume released
state/hook data and must not edit or vendor-patch the host repository. If a
required datum is not exposed, record it as a V3 gap and design a fail-open
boundary; do not silently pretend a text placeholder is a working animation.

The read-only host reference contains detached OAM objects, effect
sheets/palettes, trainer slides, faint slides, picture overrides
(transform/substitute/minimize), HP/EXP animation state, and the animation
runner's after-animation chain. Do not assume any of these reaches the
official V3 payload; re-audit exposure before designing the replacement.

## Debugging order

1. Re-read the official V3 battle seams and record exactly which fields are
   exposed before choosing any implementation shape.
2. Use the archived attempt and Gen1 Modern only to recover product lessons:
   source timing, frame ownership, suppression order, and asset selection.
3. Write a new design/acceptance plan for intro-to-command progression before
   adding move, item, capture, or progression effects.
4. Identify each missing V3 field and its safe native boundary. Do not invent
   timing, use text banners, or use captured native pixels as a substitute.
5. Add deterministic coverage alongside the future implementation, then ask
   the user to perform the official-launcher walkthrough. Repository tests are
   necessary but never live battle proof.

## Acceptance checklist

- No native battle panel, message box, or animation banner flashes during any
  supported battle stage.
- Trainer slide, ball throw, send-out, move, after-move, item, capture,
  damage/HP, faint, switch, EXP, level-up, learn/replace, nickname, and
  evolution stages all show the correct assets and source timing.
- Enemy status/sprite and player sprite/status remain in the correct diagonal
  positions; no status card covers a sprite.
- The field/dock envelope is unchanged when moving between intro, menu, moves,
  messages, and progression; landscape, portrait, and classic surfaces remain
  readable.
- All four known moves work, including fewer-than-four move lists and the
  move-information panel with cleaned descriptions and PP.
- Native title/intro boundaries remain native and do not acquire raster bars.
- The implementation remains drop-in for the current official release, uses
  V3 models/presenters, and makes no changes to `gen1recomp` itself.
- Documentation and `docs/releases/v0.2.0.md` are updated with each verified
  slice. No screenshots, generated archives, commits, or pushes are created
  unless explicitly requested.

## Verification commands

From `G:\dev\misc\gen2-clean-ui`:

```powershell
.\sync_gen2_clean_ui.cmd
.\tests\run_lua_tests.ps1
.\scripts\verify_core_lock.ps1
.\scripts\verify_sandbox.ps1
```

Use `G:\emulators\Pokemon\gen1recomp-win64` for a future official launcher
walkthrough only when the rewrite is resumed and the user is available. The
known stale untracked `gen2_clean_ui-0.2.0.zip` causes the scaffold archive
gate to reject the development tree; do not delete or rebuild it as part of
deferment work without explicit release scope.
