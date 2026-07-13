# FisherGO Realistic OSM Surface Design

## Goal

Upgrade the FisherGO overworld from a textured flat map into a coherent mobile-game world while preserving real Hong Kong geography. OpenStreetMap geometry remains the source of truth for water, coastline, land, roads, piers, bridges, and buildings. Generated imagery may provide seamless surface material only; it must never determine feature position or shape.

## Scope

This milestone adds three visual systems to the existing shared Web and Android renderer:

1. layered water and coastline treatment;
2. OSM building footprints rendered as lightweight 2.5D forms;
3. depth-aware composition for coastline, buildings, roads, fishing spots, and the player.

The existing GPS camera, roughly 500 metre play area, manual bearing control, real road vectors, 3D fishing spot markers, and panoramic map remain unchanged.

## Data Model

Add `TerrainKind.building` to the terrain schema. A building feature is a closed polygon with optional OSM-derived height metadata. The first implementation may derive a deterministic visual height from footprint size when explicit height is absent, but it must not invent a different footprint.

The terrain generator/cache pipeline must retain:

- coastline and water polygons;
- land and shore polygons;
- building polygons;
- road, bridge, and pier lines;
- feature names when available.

All geometry is bundled JSON and runs offline in both Web and APK builds. Missing building data is an allowed degradation: terrain and roads still render without fabricated building locations.

## Render Architecture

The painter uses one `GameMapCamera` for every layer and projects every geographic point after applying the same bearing and perspective transform.

Render order:

1. deep-water base texture and restrained moving-looking highlights;
2. real water polygons with depth colour grading;
3. real land and shore polygons;
4. coastline depth bands: dark submerged edge, shallow turquoise band, narrow foam highlight;
5. 2.5D building footprints, side extrusion, roof fill, and contact shadow;
6. roads, bridges, piers, intersections, and labels;
7. 3D fishing spots, player avatar, radar, and HUD;
8. atmosphere and accessibility contrast overlays.

The coastline bands follow existing polygon paths. They do not use a full-screen mask or fixed decorative coastline. Building extrusion is screen-space and depth-aware: near buildings receive a slightly taller extrusion and stronger contact shadow; distant buildings flatten softly. Camera bearing rotates the footprint geometry, shadows, roads, spots, and player together.

## Visual Language

Water uses a seamless tile with low-contrast wave structure, two broad depth grades, and sparse specular lines. It must not read as a single cyan fill or a visible square grid.

Land keeps the existing seamless grass palette but reduces texture contrast beneath dense roads and buildings. Shoreline uses a narrow sand/rock transition instead of a large blurred halo.

Buildings use a quiet Hong Kong game-map palette: pale concrete roofs, cool grey-blue sides, thin dark bases, and occasional muted civic/industrial variants. They remain subordinate to fishing spots and navigation.

Fishing spots stay as the current layered 3D beacon design and remain clickable. The renderer must never replace real spots with decorative yellow points.

## Performance Budget

Web is the strictest target. The renderer will:

- cull geometry before projection;
- cap visible building footprints in dense scenes;
- omit roof micro-detail and soft blur when the low-cost render budget is active;
- cache projected paths for equivalent camera inputs where the existing painter architecture permits;
- use vector fills and one texture sample per surface, not one bitmap widget per tile;
- avoid continuous animation loops in this milestone.

Android uses the same painter and data. Platform-specific work is limited to packaging and emulator verification.

## Failure Behaviour

- If OSM building geometry is absent, render land, water, roads, and spots normally.
- If textures fail to load, use the established colour gradients without blank frames.
- Invalid or undersized polygons are ignored rather than producing malformed paths.
- Dense scenes fall back to simplified buildings instead of dropping input or blocking gestures.

## Testing

Add focused tests proving:

- `building` parses from terrain JSON and is returned by the visible feature store;
- only closed, valid building polygons are rendered;
- building depth style scales within a bounded range and remains deterministic;
- coastline styling uses the same camera path as land/water geometry;
- render-budget selection reduces building detail in dense Web scenes;
- source-level layer order keeps buildings below roads and fishing markers;
- existing road, rotation, fishing spot, and terrain tests remain green.

## Verification

Acceptance requires:

- visual Web checks before and after bearing rotation;
- API 35 emulator checks at one dense urban location and one Hong Kong waterfront location;
- real roads, coastline, buildings, player, and 3D fishing spots remaining aligned after rotation;
- fishing spot marker tap opening the existing detail card;
- no visible square texture seams, blank terrain, fatal Flutter errors, FisherGO ANR, or map interaction regression;
- `flutter test`, `flutter analyze`, `flutter build web --release`, and `flutter build apk --release` succeeding.

The Android 6.0 / API 23 device `0123456789ABCDEF` is excluded from all verification.

## Out Of Scope

- a full 3D engine or WebGL city model;
- live downloadable vector tiles;
- continuous animated water or Seedance video layers;
- compass sensor auto-heading;
- invented buildings or fishing spots where OSM/game data has none.
