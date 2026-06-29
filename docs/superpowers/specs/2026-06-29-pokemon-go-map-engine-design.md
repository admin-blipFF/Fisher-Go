# Pokemon GO-Level Map Engine Design

## Goal

Replace the current patched game-map painter with a shared FisherGO map engine that can support a beautiful Pokemon GO-style fishing overworld on both web and Android APK.

The map must stay GPS-centered, rotate cleanly, show fishing spots at their real positions, and render water, land, roads, piers, bridges, coastline, player radius, and spot markers as a coherent game world rather than a repeated decorative pattern.

## Product Requirements

- The home map is the primary game surface, not a plain utility map.
- The visible area should default to roughly 500 meters around the player and support zoom tuning without breaking marker accuracy.
- The user can rotate map direction. Rotation must be camera-based, so all map geometry and spot markers remain spatially correct.
- Fishing spots must be projected from real latitude/longitude into the same map camera as terrain features.
- The full-screen panoramic map remains available for precise map browsing and spot selection.
- The same Dart renderer and map model must run on web and Android. Platform-specific differences should be limited to permissions, haptics, packaging, and runtime verification.
- Android APK and web release builds are both required acceptance artifacts.

## Architecture

### Map Camera

Add a `GameMapCamera` domain model responsible for:

- center latitude/longitude
- visible radius or zoom scale
- bearing degrees
- viewport size
- projecting `LatLng` into screen coordinates
- inverse projection if later needed for tapping/inspection

The existing `_mapBearingDegrees` state should move toward this camera model. The renderer should no longer manually rotate one painter layer without a shared projection model.

### Map Feature Store

Add a feature store that reads bundled terrain data and exposes typed geometry:

- water polygons
- land polygons
- coastline paths
- road line strings
- pier and bridge line strings
- fishing spot points

The current `GeoTerrainDataSource` and `TerrainVectorFeature` are useful stepping stones, but the final engine should not classify everything only through tile centers. Tile classification may remain as a texture/fill fallback, while vector geometry becomes the primary visual source.

### Renderer Layers

Build a layered renderer, either as focused painters or one painter with clear private layer methods:

1. sea base and subtle water motion texture
2. land masses from geometry or generated fallback
3. coastline highlight and foam stroke
4. roads, bridges, piers, and runway/major paths
5. fishing spot markers projected from real coordinates
6. player avatar, GPS radius, unlock radius, and radar
7. atmosphere/lighting overlay

The renderer should avoid repeating visible grid patterns as the main map language. Texture is allowed, but geometry should define the map.

### Fishing Spot Accuracy

Fishing spot markers on the game map and panoramic map must use the same source coordinates. If a spot is visible on the game map, selecting it must open the same spot detail card and distance gate already used by the current flow.

Fallback display of nearest spots can remain, but fallback markers still need to be projected through the same camera model.

### Controls

The home screen keeps:

- locate/recenter
- rotate direction
- panoramic map button
- side action buttons
- bottom fishing bar

The rotate control should change the camera bearing. Later, compass sensor heading can be added for Android, but Phase 1 can keep manual 45-degree or smooth rotation.

## Data Strategy

Phase 1 should use the bundled `assets/maps/hk_terrain_mvp.json` plus `data/hk_geo/osm_vector_cache.json` and improve the rendering architecture without adding external paid services.

Phase 2 should expand the OSM cache for higher coverage around Hong Kong fishing areas:

- Tsing Ma / Ma Wan
- Tung Chung runway tail
- Sam Mun Tsai / Tai Po inner sea
- East waters
- North waters
- common public piers

The feature schema should remain simple JSON so web and APK builds can bundle it reliably.

## Testing

Add focused tests for:

- `GameMapCamera` projects the center GPS coordinate to the player center.
- camera bearing rotates projected points around the player center.
- fishing spot projection uses real spot coordinates, not normalized fallback positions.
- map feature store exposes road/coastline geometry around key Hong Kong areas.
- home renderer source uses the new engine and keeps the panoramic map path.

Keep existing tests for daily tasks, fish collection, location spawn rules, and tutorial flows green.

## Verification

Before claiming this map-system goal complete, verify:

- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- local or live web mobile screenshot at 390x844
- `flutter build apk`
- APK artifact exists under `build/app/outputs/flutter-apk/`
- if an emulator/device is available, install and launch smoke test
- no relevant fatal Android logs, Flutter errors, missing asset errors, or map permission warnings

## Out of Scope For Phase 1

- Paid Mapbox/Google Maps 3D SDKs.
- Full offline vector tile generation for all Hong Kong.
- Compass auto-heading.
- Multiplayer or live nearby players.
- Tide/weather-based visual map changes.

These can be added later after the shared map engine is stable.

## Acceptance

The Phase 1 map engine is acceptable when:

- the home map is visibly more like a coherent game world than a repeated tile pattern;
- roads/coastlines/piers appear as continuous geometry where source data exists;
- fishing spot markers are projected through the same camera as map geometry;
- manual rotation preserves marker/terrain alignment;
- web and Android APK builds both succeed.
