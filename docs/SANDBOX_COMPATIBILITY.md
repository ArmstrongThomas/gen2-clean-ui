# Sandbox Compatibility

Gen2 Clean UI treats Bryan's announced private mod sandbox as a release
contract. The installed product does not require raw filesystem, process,
thread, package, debug, native-code, or bytecode access.

## Audited behavior

- Product and vendored-core source is read only with `mod:read` and compiled by
  the sandbox-provided source-only `load` function.
- Product modules are selected from internal identifiers; the entry point and
  options schema are safe forward-slash paths inside the mod.
- The product publishes API V3 through `mod.exports.cleanUiHost` and diagnostics
  through `mod.exports.gen2CleanUi`. Other mods discover the product with
  `mod.find("gen2_clean_ui")`; no shared `_G` is used.
- Clean UI options use `mod.options`. Per-save state belongs in `mod.save`; any
  independently persisted data must use `mod.storage`. No state is written with
  `io` or `love.filesystem`.
- Graphics use the provided LÖVE graphics/window APIs. The product does not use
  blocked `love.filesystem`, `love.thread`, `love.system`, or `love.event`
  namespaces.
- Generated UI images prefer `mod.ui.sourceImage` on hosts that provide it. On
  v0.1.86, the runtime instead uses sandboxed `love.graphics.newImage` only for
  validated forward-slash `assets/generated/*.png` paths; traversal,
  backslashes, drive separators, and non-PNG paths are rejected. This remains
  read-only asset loading and does not use blocked filesystem APIs or modify
  the host.

The complete installable mod root, including the pinned core snapshot, was
audited on 2026-08-12. The scanner passed 108 UTF-8 Lua source files with no
blocked API, private-global coupling, unsafe literal or manifest path, reparse
point, native binary, or Lua/LuaJIT bytecode.

The sandbox boundary is `mods/gen2_clean_ui`. Repository-only PowerShell and
test harnesses run outside the game and may use host filesystem APIs to inspect
the package; they are not included in the updater ZIP's mod root.

The external `gen1recomp` source checkouts and released launcher are read-only
compatibility targets. This product never patches, rebuilds, or commits host
changes. Release-floor differences are handled by feature-detected mod seams;
the drop-in package must remain usable with the latest released host that
satisfies its manifest.

## Local release gate

Run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\verify_sandbox.ps1
```

The gate scans every file under `mods/gen2_clean_ui`, not only product-owned
Lua. It rejects:

- blocked globals and modules, including aliases, bare `require "..."`, and
  bracket access to blocked LÖVE namespaces;
- `_G` integration instead of `mod.exports`/`mod.find`;
- invalid `entry` or `options_schema` paths and statically visible traversal in
  `mod:read`, `mod.assets:path`, or `mod.assets:image` calls;
- reparse points/symlinks, native-library extensions, PE/ELF/Mach-O/WebAssembly
  signatures, `.luac`, and disguised Lua/LuaJIT bytecode; and
- invalid UTF-8 Lua source.

The scanner runs positive and negative self-tests each time. It is a static
release gate, so the final release must also pass the product's private-sandbox
smoke test and the official validator on the first tagged supported sandboxed
host. There is no filesystem permission to request as a fallback.
