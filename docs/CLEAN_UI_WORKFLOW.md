# Clean UI development and GitHub workflow

This repository is the Gen2 product source. The host game, launcher/AppData
installation, and vendored Core snapshots are not edited by hand.

## Ownership

- Shared runtime behavior belongs in `clean-ui-core`.
- Gen2-specific adapters, presenters, fixtures, assets, and release metadata
  belong here.
- Gen1 behavior belongs in `gen1-clean-ui`.
- Studio tooling belongs in `clean-ui-studio`.

Develop and commit changes in the owning repository first. Publish the branch,
open a pull request, and merge it through GitHub before consuming a shared
change from another repository.

## Core synchronization

The product contains a pinned Core snapshot at
`mods/gen2_clean_ui/vendor/clean_ui_core/`. Its contents and
`clean-ui-core.lock.json` must be refreshed together.

From a Windows checkout with the sibling repositories in the usual layout:

```powershell
.\sync_gen2_clean_ui.cmd
```

This synchronizes from `..\clean-ui-core`, verifies the lock, runs the product
checks, and only then copies the drop-in package to the launcher. Do not patch
files under `vendor/clean_ui_core` manually. If the Core source is on a
feature branch, merge that branch into Core `main` first, then sync Gen2 from
the updated Core `main`.

## Local validation

Native Linux LÖVE 11.5 can run the Lua suite:

```bash
bash tests/run_lua_tests.sh
```

On Windows, the release/scaffold gate is:

```powershell
.\tests\verify_scaffold.ps1
```

The gate verifies the manifest, the manifest-matched release blurb, the Core
lock file count/hashes, sandbox constraints, and release tooling. A clean
working tree does not prove that a committed vendor snapshot is valid.

## Version and release files

`mods/gen2_clean_ui/manifest.json` is the version source of truth. When a
version is already released, bump to the next version instead of reusing it.
For every releaseable version `X.Y.Z`, add:

```text
docs/releases/vX.Y.Z.md
```

The release blurb must be non-empty and describe the committed release. The
GitHub release workflow reads the manifest version, runs the release gate,
requires that matching blurb, builds the archive, creates tag `vX.Y.Z`, and
publishes the GitHub release from `main`. Do not manually create a conflicting
tag or release.

## GitHub Desktop and pull requests

Branches created in an agent checkout are not automatically visible in a
developer's checkout. Transfer/push the branch to the developer checkout,
refresh GitHub Desktop, and publish it to GitHub before opening a pull request.
Use the pull request's target and compare branches explicitly:

```text
base:    main
compare: feature-or-fix branch
```

Pull requests run CI. Pushes to `main` run CI and, when the manifest is
releaseable, the release workflow. Merge only after the required checks pass.
After merging, pull the updated `main` locally before running a Core sync.

Git stashes are repository-wide rather than branch-specific. A stash shown
while viewing `main` may have been created on another branch. Do not restore an
old stash over a newer merged change without reviewing its diff.

## Safe order for a cross-repository change

1. Change and test the owning source repository.
2. Commit and publish its feature branch.
3. Merge the source change through GitHub.
4. Pull the source repository's updated `main`.
5. Sync the dependent product with the scoped sync script.
6. Bump the product version/release blurb when required.
7. Run the full local tests and Windows scaffold/release gates.
8. Commit and publish the product branch.
9. Merge the product pull request only after CI passes.
