# Gen2 Clean UI 0.2.0

This is the modular Pokémon Gold product for the Clean UI rebuild. Version
0.2.0 is an early public follow-up release.

The current source package requires host release `0.1.87` or newer and contains
the complete audited `v0.1.87` Gen2 screen registry, native-safety provider, and
a pinned shared `clean-ui-core` snapshot. The v0.1.86 exact-ID fallback is
shared across all 51 official records, including Party, Battle, Pokegear,
dialogue, and the retained pointer/touch input groundwork. Pointer/touch is
disabled by default while its screen coverage is incomplete. The package
targets official host builds
from v0.1.87 through (but not including) v2.0.0.

The runtime retains a compatibility fallback for older 0.1.86-style hosts, but
that release is no longer inside the manifest support floor. The supported
drop-in target for this line is the official 0.1.87 release or newer.

On v0.1.86, generated Party and Battle sprite images use a narrowly validated
sandboxed graphics fallback because that release does not provide
`mod.ui.sourceImage`. Newer hosts use the host image facade. Both paths remain
entirely inside the drop-in package.

Key safety guarantees:

- exact `Gen2*` ID and official class checks;
- instance draw overrides always remain native;
- malformed or drifted state always remains native;
- no screen is hidden before a complete replacement exists;
- unsupported or unknown Gold battle child stacks fail open; supported Party,
  Pack, and naming children use their complete V3 presenters over the clean
  battle envelope;
- released-host battle intro/trainer-slide phases consume the host's generated
  player back-pic and trainer-class front-pic descriptors, with a safe Pokémon
  art fallback for older asset caches;
- the shared world/UI scene canvas is never cleared by this product.

The host repository and launcher are external, read-only compatibility
references. This mod must remain drop-in compatible with the latest released
host satisfying the manifest floor; host changes do not belong in this
repository.

Plain Pixel is host-provided and always uses whole authored raster steps.
The repository's `docs/SANDBOX_COMPATIBILITY.md` records the source-only loader,
private-global, path, persistence, and release-verification contract.
