# FisherGO Game Overworld Onboarding Design

Date: 2026-06-25

## Goal

Move the first-run experience and map screen closer to a mobile game loop inspired by Pokemon GO:

- Show login or guest choice before tutorial.
- Let players skip tutorial.
- Replace the current map-first feeling with a game overworld presentation while preserving existing fishing spots, GPS checks, and fishing flow.

## Confirmed Direction

Use option B from the mockup: Game Overworld.

The screen should feel like a playable fishing world, not a plain map app. The first implementation should use Flutter UI composition rather than a true 3D engine so the current app logic remains stable.

## Onboarding Flow

Current intended sequence:

1. App opens.
2. If the player has not chosen identity mode, show the identity dialog first.
3. Player chooses Google login, Email login/register, or guest play.
4. After the identity choice is resolved, check tutorial state.
5. If tutorial is not completed, show tutorial overlay.
6. Tutorial can be skipped. Skip marks tutorial completed and closes the overlay.

Rules:

- Tutorial must not appear before the identity dialog.
- Guest play must still be allowed.
- Existing tutorial completion storage should continue using `TutorialService`.
- Skip must be obvious and reachable from every tutorial step.

## Game Overworld Map

The existing map data remains the source of truth:

- Fishing spot coordinates.
- Current player location.
- Reachability and distance checks.
- Start fishing action.
- Spot detail card and biome/event labels.

The visual presentation changes:

- Player avatar stays visually centered.
- World layer uses a perspective transform to create a 3D-overworld feel.
- Roads, coastline, sea/water hints, and radar rings are stylized as game visuals.
- Fishing spots become floating game markers.
- Primary bottom command uses a large circular button.
- Side actions use elevated circular 3D buttons.
- HUD keeps useful status but avoids dense map-tool styling.

## Components

Expected scoped changes:

- `GameHomeScreen`: adjust startup sequence and choose the game overworld map layout.
- `TutorialOverlay`: add skip support and keep existing completion behavior.
- Existing game home widgets can be reused where appropriate:
  - `game_hud_layer.dart`
  - `game_bottom_command_bar.dart`
  - `game_side_hud_button.dart`
  - `player_avatar_marker.dart`
  - `fishing_spot_marker.dart`
  - `radar_grid_painter.dart`

If the current map builder is too large, add small private widgets rather than refactoring unrelated game logic.

## Testing

Add or update focused tests where practical:

- Tutorial skip marks tutorial completed.
- Startup sequence checks identity choice before tutorial.
- Existing widget smoke tests still pass.

Manual verification:

- First-run app shows identity choice first.
- Choosing guest then shows tutorial.
- Tutorial skip closes overlay and does not show again.
- Home map visually reads as a game overworld with central avatar, radar ring, floating markers, and 3D round controls.

## Out of Scope For This Step

- True 3D engine or AR mode.
- New login provider setup.
- Changing fishing probability or catch rules.
- Replacing all map data providers.
- Final art polish for App Store screenshots.
