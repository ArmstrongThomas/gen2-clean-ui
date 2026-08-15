# Deferred Gen2 battle UI attempt

Archived on 2026-08-15 after repeated official-launcher failures around the
battle intro, refresh/redraw ownership, and post-intro progression.

This directory is a read-only design/debug snapshot. It is not part of the
active Clean UI product path and must not be restored piecemeal into a future
rewrite. The shared files below were copied because they contained the
attempt's battle integration alongside unrelated product behavior:

- `mods/gen2_clean_ui/src/product.lua`
- `mods/gen2_clean_ui/src/provider/init.lua`
- `mods/gen2_clean_ui/src/provider/live_stack.lua`
- `mods/gen2_clean_ui/src/provider/source_input.lua`
- `mods/gen2_clean_ui/src/contracts/families/native.lua`
- `mods/gen2_clean_ui/src/contracts/v3.lua`
- `mods/gen2_clean_ui/vendor/clean_ui_core/presentation/runtime.lua`
- `tests/run_product_smoke.lua`
- `tests/run_contract_tests.lua`
- `tests/run_all.lua`
- `mods/gen2_clean_ui/README.md`

Battle-only implementation and test files are also preserved here. The next
design pass should begin from the official host V3 seams and a new ownership
model, not from the archived renderer, latch, or frame-extraction architecture.

The active product deliberately leaves `Gen2BattleState` and
`Gen2BattleTransition` native/deferred. Native battle timing, input, sound,
randomization, state transitions, and battle semantics remain host-owned.

No launcher files, host repository files, screenshots, release archives,
commits, or pushes are included in this archive.
