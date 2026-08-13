# Vendored core contract

Gen2 Clean UI has no runtime dependency on a separately installed core mod.
Instead, releases contain a pinned snapshot at:

```text
mods/gen2_clean_ui/vendor/clean_ui_core/
```

The source snapshot comes from `clean-ui-core/src/clean_ui`. Its required
entry is `bootstrap.lua`.

`clean-ui-core.lock.json` records:

- lock schema and readiness status;
- exact core tag and 40-character commit;
- every vendored relative path;
- byte size and lowercase SHA-256 for every file.

`scripts/sync_core.ps1` accepts either a local core checkout or an already
downloaded tagged archive. It stages and hashes the snapshot before replacing
the narrowly scoped vendor target. `scripts/verify_core_lock.ps1` rejects any
missing, changed, or extra file. `build_release.ps1` refuses to run unless that
verification succeeds.

The initial lock remains:

```json
{ "schema_version": 1, "status": "pending", "core": { "tag": null,
  "commit": null }, "files": [] }
```

This is intentional: product contracts can be developed and tested before the
shared core exists, while an incomplete product cannot accidentally become a
release archive.

