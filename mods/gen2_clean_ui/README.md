# Gen2 Clean UI 0.2.0

This is the modular Pokémon Gold product for the Clean UI rebuild. Version
0.2.0 is an early public follow-up release.

Battle UI is deliberately deferred as of 2026-08-15. The previous Clean UI
battle adapters, presenters, detached renderer, ownership latch, and battle
fixtures were removed from the active package and preserved as a local design
snapshot in `docs/archive/battle-ui-deferred-2026-08-15/`. Gen2 battle and
battle-transition screens remain explicitly native/deferred, so the official
host continues to own battle timing, input, sound, randomization, state-stack
transitions, and presentation. No battle rewrite architecture has been
selected yet.

The Pokegear family is likewise native for now: `Gen2Pokegear` and
`Gen2MapRadio`, including phone, clock, map/Fly, and radio child surfaces, are
not registered as active replacements. Their adapters and presenters remain
inactive reference code for a later redesign.

The current source package requires host release `0.1.87` or newer and contains
the complete audited `v0.1.87` Gen2 screen registry, native-safety provider, and
pinned shared `clean-ui-core` snapshot. The v0.1.86 exact-ID fallback is
shared across all 51 official records, including Party, native Pokegear-family
boundaries, dialogue,
and the retained pointer/touch input groundwork. Pointer/touch is
disabled by default while its screen coverage is incomplete. The package
targets official host builds
from v0.1.87 through (but not including) v2.0.0.

The runtime retains a compatibility fallback for older 0.1.86-style hosts, but
that release is no longer inside the manifest support floor. The supported
drop-in target for this line is the official 0.1.87 release or newer.

On v0.1.86, generated Party sprite images and retained visual fixtures use a
narrowly validated sandboxed graphics fallback because that release does not provide
`mod.ui.sourceImage`. Newer hosts use the host image facade. Both paths remain
entirely inside the drop-in package.

Key safety guarantees:

- exact `Gen2*` ID and official class checks;
- instance draw overrides always remain native;
- malformed or drifted state always remains native;
- no screen is hidden before a complete replacement exists;
- `Gen2Pokegear` and `Gen2MapRadio` remain explicitly native, including their
  phone, clock, map/Fly, and radio child surfaces;
- battle and battle-owned child stacks remain wholly native while the battle
  rewrite is deferred;
- the shared world/UI scene canvas is never cleared by this product.

The host repository and launcher are external, read-only compatibility
references. This mod must remain drop-in compatible with the latest released
host satisfying the manifest floor; host changes do not belong in this
repository.

Plain Pixel is host-provided and always uses whole authored raster steps.
The repository's `docs/SANDBOX_COMPATIBILITY.md` records the source-only loader,
private-global, path, persistence, and release-verification contract.
