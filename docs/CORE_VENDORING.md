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

The current development lock is ready and records the exact vendored snapshot:

```json
{ "schema_version": 1, "status": "ready",
  "core": { "tag": "0.1.0-alpha.10",
    "commit": "cfed683ff907a1cad57331058ebc6f23bf4f5110" } }
```

The host source checkout is not part of this lock and must never be copied into
or modified by the product repository. If the host API changes, update the
drop-in mod/core contract and its tests, then refresh the pinned vendor snapshot
only through the scoped sync script.
