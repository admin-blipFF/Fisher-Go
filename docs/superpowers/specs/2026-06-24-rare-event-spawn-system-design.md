# Rare Event Spawn System Design

## Purpose

FisherGO already supports location-based fishing spots, biome-based backdrops, local fish spawn rules, distance-gated fishing, daily rewards, and verified real catch photo proof. The next master-plan step is to make the map feel alive: certain waters should become more attractive at specific times, and some rare opportunities should appear as short-lived local events.

This feature adds a deterministic rare-event spawn layer without paid weather, tide, or map APIs. It uses local device time and the existing Hong Kong spot-name rules so Android can be tested immediately.

## Product Goals

- Make the map feel more like a Pokemon GO-style world where timing matters.
- Give players a reason to revisit known spots at different times of day.
- Surface simple, readable event labels on spot cards before fishing starts.
- Keep spawn math deterministic and testable.
- Avoid paid APIs until the base loop is fun and stable.

## Non-Goals

- No live tide/weather integration in this phase.
- No push notifications yet.
- No server-controlled events yet.
- No monetization changes.
- No broad UI redesign.

## Recommended Approach

Use a local `FishingEventRules` domain layer that combines:

- **Time windows:** morning, dusk, night, daytime.
- **Spot families:** Tsing Ma waters, East Water, Sam Mun Tsai/Tai Po inner sea, Tung Chung runway/north water.
- **Fish families:** grouper, catfish, scad, bream, mullet, chicken fish.

The existing `FishingSpawnRules.locationMultiplier` remains the base truth for location-special fish. The new layer returns an additional multiplier and display label. Game code multiplies existing spawn weight by both values.

## Player-Facing Event Examples

- `青馬夜釣`: night bonus near Tsing Ma/Ma Wan/Tsing Yi waters for grouper and catfish.
- `東水池仔潮`: dusk bonus in East Water spots for scad and chicken fish.
- `大埔內海烏頭窗口`: morning bonus around Sam Mun Tsai/Tai Po/Tolo Harbour for mullet.
- `跑道尾立魚窗口`: morning or dusk bonus around Tung Chung runway waters for bream.

Labels should be short and useful:

- `夜水：石斑 / 海塘蝨提升`
- `黃昏：池仔 / 黃雞魚提升`
- `早水：烏頭提升`
- `早晚：立魚提升`

## Architecture

### New Domain Unit

Create `lib/features/game_home/domain/fishing_event_rules.dart`.

Responsibilities:

- Classify a `DateTime` into a fishing time window.
- Detect active event labels for a spot at a given time.
- Return an event spawn multiplier for a spot/fish/time tuple.

The API should be pure Dart and side-effect free:

```dart
enum FishingTimeWindow {
  morning,
  daytime,
  dusk,
  night,
}

class FishingEventRules {
  const FishingEventRules._();

  static FishingTimeWindow timeWindowFor(DateTime now);

  static double eventMultiplier({
    required String spotName,
    required String fishName,
    String? fishId,
    required DateTime now,
  });

  static List<String> activeEventLabels({
    required String spotName,
    required DateTime now,
  });
}
```

### Existing Rule Integration

Modify `FishingSpawnRules.locationMultiplier` to accept an optional `DateTime now`.

```dart
static double locationMultiplier({
  required String spotName,
  required String fishName,
  String? fishId,
  FishingSpotBiome? biome,
  DateTime? now,
})
```

If `now` is null, use `DateTime.now()` in the UI path. Tests should always pass an explicit time.

The final multiplier should be:

```text
location multiplier * biome multiplier * event multiplier
```

The existing behavior must stay unchanged for non-event fish and non-event times.

### Spot Card Integration

Modify the spot bottom sheet/card in `game_home_screen.dart` to show active event labels near the existing local fish intel. The event label should be visible before the player presses `開釣`.

No new card layout is required. A compact chip row is enough:

- biome label
- current local fish intel
- active event label when available

### Fishing Overlay Integration

When rolling fish for a selected spot, pass `DateTime.now()` into `FishingSpawnRules.locationMultiplier`.

The existing tests should use fixed times to avoid flaky behavior.

## Event Windows

Use local device time:

- Morning: 05:00-09:59
- Daytime: 10:00-16:59
- Dusk: 17:00-19:59
- Night: 20:00-04:59

These are simple enough for players to understand and stable enough for tests. A future weather/tide phase can refine these windows without changing the public API.

## Event Rules

### Tsing Ma Night Fishing

Active when:

- Spot name matches Tsing Ma waters.
- Time window is night.

Boost:

- Grouper and catfish: `2.0x`

Label:

- `夜水：石斑 / 海塘蝨提升`

### East Water Dusk Run

Active when:

- Spot name matches East Water.
- Time window is dusk.

Boost:

- Scad, chicken fish, red bream: `1.8x`

Label:

- `黃昏：池仔 / 黃雞魚提升`

### Inner Sea Morning Mullet

Active when:

- Spot name matches Sam Mun Tsai/Tai Po/Tolo Harbour inner sea.
- Time window is morning.

Boost:

- Mullet: `1.8x`

Label:

- `早水：烏頭提升`

### Runway Bream Window

Active when:

- Spot name matches Tung Chung runway or north water.
- Time window is morning or dusk.

Boost:

- Bream: `1.6x`

Label:

- `早晚：立魚提升`

## Data Flow

1. `GameHomeScreen` renders a spot card.
2. Spot card calls `FishingEventRules.activeEventLabels(spotName, DateTime.now())`.
3. Player taps `開釣`.
4. Fishing overlay rolls fish.
5. Spawn weight calls `FishingSpawnRules.locationMultiplier(..., now: DateTime.now())`.
6. `FishingSpawnRules` applies existing location/biome rules and the new event multiplier.

## Error Handling

- If spot name does not match any event family, return multiplier `1.0` and no labels.
- If fish name is unknown, return multiplier `1.0`.
- If event labels duplicate local fish intel conceptually, keep both; one explains resident fish, one explains current timing.
- No network failures exist in this phase because no external API is used.

## Testing Plan

Add `test/fishing_event_rules_test.dart` covering:

- Time window classification at boundary times.
- Tsing Ma night boosts grouper/catfish only.
- East Water dusk boosts scad/chicken fish/red bream only.
- Inner sea morning boosts mullet only.
- Runway morning/dusk boosts bream only.
- Non-event times return `1.0` and no labels.

Update `test/fishing_spawn_rules_test.dart` covering:

- Existing spawn behavior stays unchanged when no `now` is passed or when non-event time is supplied.
- Event multiplier stacks on top of the existing local multiplier for matching fish.
- Location-special fish remain blocked outside their matching waters even during unrelated events.

Run:

```powershell
flutter test test\fishing_event_rules_test.dart test\fishing_spawn_rules_test.dart
flutter analyze
flutter test
flutter build apk --debug
```

Finish with the existing emulator smoke test.

## Scope Review

This is focused enough for one implementation plan because it touches one domain layer, one existing spawn-rule integration point, one spot-card display surface, and tests. It deliberately avoids server events, notifications, paid APIs, and large UI redesign.

## Spec Self-Review

- Spec scan: no empty markers or vague event values remain.
- Internal consistency: event labels, time windows, multipliers, and test requirements match the architecture.
- Scope check: limited to local deterministic rare events.
- Ambiguity check: local device time is the source of truth for this phase.
