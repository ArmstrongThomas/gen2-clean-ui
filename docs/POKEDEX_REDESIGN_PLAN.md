# Gen 2 Pokédex Redesign Plan

This document translates the approved visual concepts into a drop-in
implementation plan for `gen2-clean-ui`.

The target remains `gen1recomp` as a read-only compatibility target. This
project must not require host changes in order to render or navigate a page.

## Approved visual direction

Use the generated **Cartridge Pages** concepts as the visual source of truth,
with the shared header and section treatment from **Field Guide**:

- clipped warm-paper frame
- charcoal pixel typography
- restrained blue focus accent
- page-specific composition rather than a universal list/preview split
- stable controller footer
- no desktop widgets, glossy panels, or decorative complexity

The initial page set is:

1. Info
2. Habitat
3. Evolution
4. Level-up moves
5. TM/HM compatibility

## Compatibility audit

### Data already available on Gold

The host's Gen 2 dataset contains the core records needed by the new pages:

| Page | Source data | Status |
| --- | --- | --- |
| Info | `data.gen2Pokedex.entries`, `data.pokemon` | Available |
| Habitat | `data.gen2Maps`, `data.gen2Landmarks`, `data.gen2Encounters` | Available |
| Evolution | `data.pokemon[species].evolutions` | Available |
| Level-up moves | `data.pokemon[species].levelMoves` | Available |
| TM/HM | `data.pokemon[species].tmhm`, `data.moves` | Available |

Gen 2 species definitions use `levelMoves` and evolution targets named
`into`. The schema and engine already validate and consume these records; the
mod should read them, not duplicate or reinterpret the game's mechanics.

### Data that is not currently a registry target

`gen2Pokedex`, `gen2Landmarks`, and several other Gen 2 presentation tables are
loaded into `game.data` but do not have independent content registries. That
does not prevent a screen adapter from reading them when the host includes them
in the source snapshot, but it does mean the adapter must:

- treat every table as optional
- preserve the native screen when a table is absent
- never assume a mod content patch can add a new Pokédex page through a
  registry

### Navigation boundary

The native `Gen2PokedexMenu` currently exposes these source-owned entry actions:

`PAGE`, `AREA`, `CRY`, and `PRNT`

The released V3 host keeps update/navigation and action dispatch source-owned.
The clean presenter may describe controls, but it cannot safely invent
shoulder-button page transitions or remap the D-pad without a host-supported
action seam.

Consequences:

- Info and existing Area behavior can be redesigned immediately.
- Evolution, moves, and TM/HM data can be prepared as detached models now.
- New live navigation to those pages must use an already-supported host surface
  and action path, or remain fail-open/native until `gen1recomp` exposes a
  compatible seam.
- We must not modify `gen1recomp` locally to bypass this boundary.

## Implementation sequence

### Phase 1: data contract

Extend the Pokédex adapter with function-free snapshots for:

- species identity and metadata
- evolution chains and requirement labels
- level-up move rows
- TM/HM compatibility rows
- encounter details where the source table provides them

Add fixture coverage for:

- missing optional tables
- hidden/unseen species
- branching and non-level evolution requirements
- duplicate move levels
- empty TM/HM lists
- detached source data

No renderer changes should be made until these snapshots are stable.

### Phase 2: existing reachable pages

Replace the current generic preview composition for the reachable Info and Area
views:

- Info uses the generated identity/metadata/entry composition.
- Area uses a map-capable layout when landmark coordinates and encounter data
  are present.
- Area falls back to a readable route list when map geometry is incomplete.
- Native actions remain the source of truth.

The page must fail open if the selected species or source state is malformed.

### Phase 3: reference page models

Add presenter models for Evolution, Level-up Moves, and TM/HM. These models
should be complete and testable even before live navigation is available.
Their interaction descriptors must reference named, registered actions only.

### Phase 4: live navigation decision

After the models exist, verify whether the installed host advertises a
compatible custom-surface/action contract. If it does, implement the pages
behind that contract. If it does not, keep the models available for Gallery
and future host support, but do not claim live functionality.

If a host-side action or data seam is required, prepare an upstream issue
request rather than changing the host in this mod repository.

## Non-negotiable safety rules

- Do not change `gen1recomp`.
- Do not call source callbacks during extraction.
- Do not put functions, userdata, cycles, or live source tables into models.
- Do not claim a page is live unless a complete replacement and its navigation
  have been tested.
- Preserve native UI when data, actions, or complete-stack ownership are not
  available.
- Keep the existing Gen2 API floor and manifest unchanged unless the host
  compatibility audit proves a required capability already exists there.

