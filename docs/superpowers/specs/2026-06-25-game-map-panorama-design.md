# Game Map Panorama Design

## Goal

Fix the current 3D map visual mismatch by separating the game overworld from the accurate map used for finding fishing spots.

## Design

The home screen should default to a stylized 3D game overworld. This surface is decorative and gameplay-focused, so it must not tilt or transform the real `FlutterMap` tiles. It keeps the player ring, HUD, fishing controls, and side actions visible.

An additional round map button opens a full-screen panoramic map. That view uses the real untransformed `FlutterMap`, so spot markers, zooming, panning, and spot selection remain geographically accurate. Selecting a marker in the panoramic map closes the map and opens the existing spot detail card on the home screen.

## Acceptance

- The default home map no longer shows a skewed rectangular real tile layer.
- A visible map icon opens a full-screen accurate map view.
- The panoramic map shows player location, fishing radius, nearby fishing spot markers, and existing zoom/pan behavior.
- Existing fishing, GPS, tutorial, and navigation flows remain unchanged.
