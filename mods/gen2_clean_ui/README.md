# Gen2 Clean UI 0.1.0 scaffold

This is the modular Pokemon Gold product for the Clean UI rebuild.

The current source package contains the complete audited `v0.1.79` Gen2 screen
registry, native-safety provider, and a pinned shared `clean-ui-core` snapshot.
Production presenters still remain native until each exact contract passes its
complete-stack fallback tests. This is a development build, not a release.

Key safety guarantees:

- exact `Gen2*` ID and official class checks;
- instance draw overrides always remain native;
- malformed or drifted state always remains native;
- no screen is hidden before a complete replacement exists;
- any Gold battle or battle-owned child stack remains wholly native;
- the shared world/UI scene canvas is never cleared by this product.

Plain Pixel is host-provided and always uses whole authored raster steps.
The repository's `docs/SANDBOX_COMPATIBILITY.md` records the source-only loader,
private-global, path, persistence, and release-verification contract.
