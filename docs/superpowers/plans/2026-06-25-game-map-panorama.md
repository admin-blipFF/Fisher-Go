# Game Map Panorama Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the skewed transformed live map with a clean 3D game overworld and add a full-screen accurate map for finding fishing spots.

**Architecture:** Keep existing `GameHomeScreen` state as the source of truth. Use a decorative `_GameWorldMapShell` for the default screen and build a separate untransformed `FlutterMap` inside a modal route for panoramic spot browsing.

**Tech Stack:** Flutter, flutter_map, latlong2, flutter_test.

---

## File Structure

- Modify `lib/features/game_home/presentation/game_home_screen.dart`
  - Remove the transformed `FlutterMap` from `_GameWorldMapShell`.
  - Add a full-screen panoramic map route using the real `FlutterMap`.
  - Add a round map icon button to open the panoramic map.
- Modify `test/widget_test.dart`
  - Assert that the new panoramic map button exists.

## Task 1: Split 3D Overworld From Accurate Map

- [ ] Update `_GameWorldMapShell` so it no longer accepts or transforms a `FlutterMap` child.
- [ ] Add `_openPanoramaMap`, `_buildAccurateFishingMap`, `_PanoramaMapButton`, and `_PanoramaMapSheet`.
- [ ] Wire the new map button into the home `Stack`.
- [ ] Update widget smoke expectations.
- [ ] Run `flutter analyze` and `flutter test`.
- [ ] Commit and push.
