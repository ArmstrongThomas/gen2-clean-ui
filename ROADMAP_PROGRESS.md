# Gen2 Clean UI roadmap progress

Last verified: 2026-08-14  
Release floor: `0.1.87`  
Current manifest: `0.2.0`  
Worktree policy: no commits or pushes in this pass; no host-repository changes;
no screenshots checked in.

## Completed in this pass

- [x] Audited the 51-entry official Gen2 catalog against the released-host
  floor and kept the ten explicitly native/source-owned IDs native.
- [x] Kept all 41 supported catalog records on the V3 model/presenter path;
  product smoke now checks that every supported record has both pieces.
- [x] Fixed live-stack suppression so supported clean screens do not fail just
  because a native source-owned parent remains below them.
- [x] Added safe battle child-stack handling: supported clean children replace
  their native battle frame, while unknown/native children fail open.
- [x] Reconciled the public stack assessor with the live child-stack path so
  supported Party/Pack/Naming children are not rejected before rendering.
- [x] Added released-host tutorial/no-player battle extraction, Park Ball and
  item animation classification, and touch selection for the next-Pokémon
  prompt.
- [x] Covered the battle pages already represented by the source state machine:
  intro/trainer/faint transitions, move/item/Poké Ball animations, command and
  move selection, battle messages, forced-switch/next-Pokémon prompts,
  experience growth, level-up stats, evolution, nickname, and shift prompts.
- [x] Added V3 detached trainer-art descriptors for the released host's player
  back-pic and opponent trainer front-pic during intro/trainer-slide; older
  caches without the generated paths fall back safely.
- [x] Preserved a phase-independent battle envelope so the upper field and
  status cards do not get squished when the command or move panel opens.
- [x] Updated the released-host contract authority to `v0.1.87`, and exposed
  callback-free provider coverage diagnostics for tooling.

## Automated verification

- [x] `tests/run_lua_tests.ps1`
  - Lua syntax: 201 files
  - Contract/foundation/shared/product checks: all passed
  - Gallery/production checks: 779 checks passed
  - Responsive NAV/M matrix: 34,325 checks passed
  - Responsive battle matrix: 21,909 checks passed
- [x] Battle adapter regression checks include cleaned `<NEXT>` messages,
  next-Pokémon confirmation and touch selection, detached OAM frames,
  item/Poké Ball/Park Ball frames, tutorial extraction, supported child-stack
  assessment, all known upstream battle phases, and level-up/evolution models.
- [x] Release/scaffold and archive checks were rerun after the final code and
  documentation changes; the archive remained deterministic and the scaffold
  passed with the root release ZIP preserved.
- [ ] Live controller walkthrough on the official launcher: not run in this
  pass because no game window was available while the user was away.

## Deliberate native boundaries

- [ ] Copyright splash, Game Freak Presents, Gold/Silver intro, and title stay
  source-owned until a proven released-host raster seam exists.
- [ ] Hall of Fame induction, trade/complex nested party-picker stacks, and
  shared `gold.CallerBox` remain fail-open/native where exact ownership is not
  provable.
- [ ] Source-owned animation timing and input remain in the host; the clean
  UI consumes detached V3 frame data and does not patch the host repository.

## Next user test

Run `G:\dev\misc\gen2-clean-ui\sync_gen2_clean_ui.cmd`, restart the official
launcher, and walk through the main menu, start menu, party, pack, Pokédex,
Pokegear/map, dialogue, battle command/move pages, a held/used item, a capture,
level-up/evolution/nickname flow, and pointer/touch settings. Confirm that no
native frame remains visible underneath a supported clean page and that native
boot/title pages remain unchanged.
