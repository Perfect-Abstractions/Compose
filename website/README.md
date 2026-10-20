# Website

This website is built using [Docusaurus](https://docusaurus.io/), a modern static website generator.

## Prerequisites

- Node.js >= 20.0
- npm (comes with Node.js)

## Installation

```bash
npm install
```

## Local Development

```bash
npm start
```

This command starts a local development server and opens up a browser window. Most changes are reflected live without having to restart the server.

## Build

```bash
npm run build
```

This command generates static content into the `build` directory and can be served using any static contents hosting service.

## Generate Facets & Modules Documentation

```bash
npm run generate-docs
```

## Library Catalog Snapshot

`src/data/libraryCatalog.json` is generated from this checkout's `../src` Solidity
files and `../cli/bases` presets. Website components can import the JSON without
GitHub access or runtime requests. Both `npm start` and `npm run build` regenerate
it before Docusaurus runs. After editing sources or presets during development,
run `npm run catalog:generate` again.

```bash
npm run catalog:generate
npm run catalog:check
npm run catalog:test
```

The checked-in snapshot provides a reviewable baseline. Builds regenerate it
from the checkout, so source and preset PRs do not need a bot commit to refresh
the deployed graph. Refresh the baseline when changing the generator or preparing
a catalog update. The check command detects a stale baseline. Output is
deterministic and normalizes CRLF line endings, with a content hash instead of a
build timestamp or changing HEAD.

`files` inventories all Solidity source paths, with filename-based kinds,
category/family grouping and preset memberships. Grouping describes directory
membership, not Solidity dependencies. `presets` preserves each CLI definition
and its source file, plus resolved references with required/optional roles and
exact metadata field paths. CLI-local templates (such as Counter) remain
`external` references and do not become library facets. Missing package source
references fail generation.

The Library index imports the snapshot through `src/components/LibraryGraph`.
It uses Docusaurus document IDs and their published routes to link available
facet pages, including custom slugs, in new tabs. Facets without a matching doc
remain inspectable. CLI preset and search filters change emphasis without
removing or repositioning nodes. The 3D view loads Three.js only in the browser,
with an automatic keyboard-operable SVG fallback when WebGL is unavailable and
a facet list for direct navigation.

Run `npm run graph:test` to check route matching, preset membership and stable
layout. Grouping edges represent family membership, not Solidity dependencies.

The map uses Babylon's constellation arrangement: feature families occupy
different depths, with small glowing facet stars and an oblique orbit camera.
Portrait screens rotate the same sky into a taller composition. The SVG view
uses the same camera projection, so switching renderers preserves the map.
