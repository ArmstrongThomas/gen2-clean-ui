# Vendored core

`vendor/clean_ui_core` is generated from the pinned shared source. Run
`scripts/sync_core.ps1` after selecting a `clean-ui-core` snapshot. The
sync script writes the exact tag, commit, paths, and SHA-256 hashes to the
repository-level `clean-ui-core.lock.json`.

The product still leaves unsupported production screens native and visible.
