# Rare Event Spawn System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic local rare-event spawn layer so FisherGO fishing spots can show time-based event labels and boost matching fish during morning, dusk, and night windows.

**Architecture:** Create a pure Dart `FishingEventRules` domain unit, then integrate it into the existing `FishingSpawnRules.locationMultiplier` flow. Keep UI changes small by adding event chips beside existing spot intel chips in the fishing overlay.

**Tech Stack:** Flutter, Dart, existing FisherGO game-home domain rules, existing widget tests, Android emulator smoke workflow.

---

## File Structure

- Create: `lib/features/game_home/domain/fishing_event_rules.dart`
  - Owns time-window classification, event labels, and event multipliers.
- Modify: `lib/features/game_home/domain/fishing_spawn_rules.dart`
  - Accepts optional `DateTime now` and stacks event multipliers after existing location/biome logic.
- Modify: `lib/features/game_home/presentation/game_home_screen.dart`
  - Passes `DateTime.now()` into spawn rules and displays active event chips in spot select.
- Create: `test/fishing_event_rules_test.dart`
  - Covers all event windows, labels, matching fish, and non-event cases.
- Modify: `test/fishing_spawn_rules_test.dart`
  - Covers event multiplier stacking and existing behavior preservation.

---

### Task 1: Add Pure Event Rule Tests

**Files:**
- Create: `test/fishing_event_rules_test.dart`

- [x] **Step 1: Write failing tests for time windows and event labels**

Create `test/fishing_event_rules_test.dart`:

```dart
import 'package:fishergo/features/game_home/domain/fishing_event_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FishingEventRules', () {
    test('classifies local fishing time windows at boundaries', () {
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 5, 0)),
        FishingTimeWindow.morning,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 9, 59)),
        FishingTimeWindow.morning,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 10, 0)),
        FishingTimeWindow.daytime,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 16, 59)),
        FishingTimeWindow.daytime,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 17, 0)),
        FishingTimeWindow.dusk,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 19, 59)),
        FishingTimeWindow.dusk,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 20, 0)),
        FishingTimeWindow.night,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 4, 59)),
        FishingTimeWindow.night,
      );
    });

    test('shows Tsing Ma night event label only at night', () {
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '青馬大橋橋底',
          now: DateTime(2026, 6, 24, 22),
        ),
        contains('夜水：石斑 / 海塘蝨提升'),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '青馬大橋橋底',
          now: DateTime(2026, 6, 24, 14),
        ),
        isEmpty,
      );
    });

    test('shows East Water dusk event label only at dusk', () {
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '東龍洲碼頭',
          now: DateTime(2026, 6, 24, 18),
        ),
        contains('黃昏：池仔 / 黃雞魚提升'),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '東龍洲碼頭',
          now: DateTime(2026, 6, 24, 11),
        ),
        isEmpty,
      );
    });

    test('shows inner sea morning mullet label only in morning', () {
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '三門仔村碼頭',
          now: DateTime(2026, 6, 24, 7),
        ),
        contains('早水：烏頭提升'),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '三門仔村碼頭',
          now: DateTime(2026, 6, 24, 20),
        ),
        isEmpty,
      );
    });

    test('shows runway bream label in morning and dusk', () {
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 6),
        ),
        contains('早晚：立魚提升'),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 18),
        ),
        contains('早晚：立魚提升'),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 13),
        ),
        isEmpty,
      );
    });
  });
}
```

- [x] **Step 2: Run tests to verify RED**

Run:

```powershell
flutter test test\fishing_event_rules_test.dart
```

Expected: FAIL because `fishing_event_rules.dart` does not exist.

---

### Task 2: Implement `FishingEventRules`

**Files:**
- Create: `lib/features/game_home/domain/fishing_event_rules.dart`
- Test: `test/fishing_event_rules_test.dart`

- [x] **Step 1: Create the domain rule file**

Create `lib/features/game_home/domain/fishing_event_rules.dart`:

```dart
import 'dart:collection';

enum FishingTimeWindow {
  morning,
  daytime,
  dusk,
  night,
}

class FishingEventRules {
  static const double tsingMaNightMultiplier = 2.0;
  static const double eastWaterDuskMultiplier = 1.8;
  static const double innerSeaMorningMultiplier = 1.8;
  static const double runwayBreamMultiplier = 1.6;

  const FishingEventRules._();

  static FishingTimeWindow timeWindowFor(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 10) return FishingTimeWindow.morning;
    if (hour >= 10 && hour < 17) return FishingTimeWindow.daytime;
    if (hour >= 17 && hour < 20) return FishingTimeWindow.dusk;
    return FishingTimeWindow.night;
  }

  static List<String> activeEventLabels({
    required String spotName,
    required DateTime now,
  }) {
    final spot = _normalize(spotName);
    final window = timeWindowFor(now);
    final labels = <String>[];

    if (_isTsingMaWater(spot) && window == FishingTimeWindow.night) {
      labels.add('夜水：石斑 / 海塘蝨提升');
    }
    if (_isEastWater(spot) && window == FishingTimeWindow.dusk) {
      labels.add('黃昏：池仔 / 黃雞魚提升');
    }
    if (_isInnerSea(spot) && window == FishingTimeWindow.morning) {
      labels.add('早水：烏頭提升');
    }
    if (_isRunwayOrNorthWater(spot) &&
        (window == FishingTimeWindow.morning ||
            window == FishingTimeWindow.dusk)) {
      labels.add('早晚：立魚提升');
    }

    return List.unmodifiable(LinkedHashSet<String>.from(labels));
  }

  static double eventMultiplier({
    required String spotName,
    required String fishName,
    String? fishId,
    required DateTime now,
  }) {
    final spot = _normalize(spotName);
    final fish = _normalize('$fishName ${fishId ?? ''}');
    final window = timeWindowFor(now);

    if (_isTsingMaWater(spot) &&
        window == FishingTimeWindow.night &&
        (_isGrouper(fish) || _isCatfish(fish))) {
      return tsingMaNightMultiplier;
    }
    if (_isEastWater(spot) &&
        window == FishingTimeWindow.dusk &&
        (_isScad(fish) || _isChickenFish(fish) || _isBream(fish))) {
      return eastWaterDuskMultiplier;
    }
    if (_isInnerSea(spot) &&
        window == FishingTimeWindow.morning &&
        _isMullet(fish)) {
      return innerSeaMorningMultiplier;
    }
    if (_isRunwayOrNorthWater(spot) &&
        (window == FishingTimeWindow.morning ||
            window == FishingTimeWindow.dusk) &&
        _isBream(fish)) {
      return runwayBreamMultiplier;
    }

    return 1.0;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static bool _hasAny(String value, List<String> keywords) =>
      keywords.any(value.contains);

  static bool _isTsingMaWater(String spot) => _hasAny(spot, const [
        '青馬',
        '青衣',
        '馬灣',
        '汲水門',
        '藍巴勒',
        '荃灣',
        '深井',
        '長索',
      ]);

  static bool _isEastWater(String spot) => _hasAny(spot, const [
        '東水',
        '東龍',
        '東平洲',
        '果洲',
        '伙頭墳洲',
        '牛尾洲',
        '滘西洲',
        '破邊洲',
        '蒲台',
        '清水灣',
        '西貢',
        '將軍澳',
      ]);

  static bool _isInnerSea(String spot) => _hasAny(spot, const [
        '三門仔',
        '大埔',
        '吐露港',
        '大美督',
        '船灣',
        '馬屎洲',
        '內海',
      ]);

  static bool _isRunwayOrNorthWater(String spot) => _hasAny(spot, const [
        '北水',
        '塔門',
        '東平洲',
        '鴨洲',
        '吉澳',
        '印洲塘',
        '沙頭角',
        '赤門',
        '大鵬',
        '馬屎洲',
        '東涌',
        '赤鱲角',
        '機場',
        '跑道',
        '三跑',
      ]);

  static bool _isBream(String fish) => _hasAny(fish, const [
        '立',
        '鱲',
        '黃腳',
        '赤鱲',
        '紅鱲',
        'fish-096',
        'fish-097',
        'fish-099',
        'fish-100',
        'fish-102',
        'fish-103',
        'fish-109',
        'fish-110',
        'fish-111',
      ]);

  static bool _isMullet(String fish) => _hasAny(fish, const [
        '烏頭',
        '灰烏頭',
        '大眼烏頭',
        '草魚',
        'fish-063',
        'fish-067',
      ]);

  static bool _isGrouper(String fish) => _hasAny(fish, const [
        '斑',
        '班',
        '石斑',
        '紅斑',
        '青斑',
        '龍躉',
        'grouper',
        'fish-072',
        'fish-073',
        'fish-074',
        'fish-075',
        'fish-076',
        'fish-077',
        'fish-078',
        'fish-079',
        'fish-080',
        'fish-081',
        'fish-082',
        'fish-083',
        'fish-084',
      ]);

  static bool _isCatfish(String fish) => _hasAny(fish, const [
        'catfish',
        '鯰',
        '鮎',
        '塘蝨',
        '海塘蝨',
        'fish-069',
        'fish-070',
      ]);

  static bool _isScad(String fish) => _hasAny(fish, const [
        '池仔',
        '池魚',
        '真池魚',
        '深海沙丁',
        'scad',
        'fish-131',
        'fish-135',
      ]);

  static bool _isChickenFish(String fish) => _hasAny(fish, const [
        '雞魚',
        '黃雞魚',
        '花雞',
        'fish-101',
      ]);
}
```

- [x] **Step 2: Add multiplier tests**

Append to `test/fishing_event_rules_test.dart` inside the group:

```dart
test('boosts only grouper and catfish during Tsing Ma night fishing', () {
  final night = DateTime(2026, 6, 24, 22);
  expect(
    FishingEventRules.eventMultiplier(
      spotName: '青馬大橋橋底',
      fishName: '石斑魚',
      fishId: 'fish-073',
      now: night,
    ),
    2.0,
  );
  expect(
    FishingEventRules.eventMultiplier(
      spotName: '馬灣碼頭',
      fishName: '海塘蝨',
      fishId: 'fish-069',
      now: night,
    ),
    2.0,
  );
  expect(
    FishingEventRules.eventMultiplier(
      spotName: '馬灣碼頭',
      fishName: '烏頭',
      fishId: 'fish-063',
      now: night,
    ),
    1.0,
  );
});

test('boosts matching East Water fish only at dusk', () {
  final dusk = DateTime(2026, 6, 24, 18);
  expect(
    FishingEventRules.eventMultiplier(
      spotName: '東龍洲碼頭',
      fishName: '深海沙丁',
      fishId: 'fish-131',
      now: dusk,
    ),
    1.8,
  );
  expect(
    FishingEventRules.eventMultiplier(
      spotName: '西貢東水',
      fishName: '黃雞魚',
      fishId: 'fish-101',
      now: dusk,
    ),
    1.8,
  );
  expect(
    FishingEventRules.eventMultiplier(
      spotName: '西貢東水',
      fishName: '石斑魚',
      fishId: 'fish-073',
      now: dusk,
    ),
    1.0,
  );
});

test('boosts inner sea mullet only during morning', () {
  expect(
    FishingEventRules.eventMultiplier(
      spotName: '三門仔村碼頭',
      fishName: '烏頭',
      fishId: 'fish-063',
      now: DateTime(2026, 6, 24, 7),
    ),
    1.8,
  );
  expect(
    FishingEventRules.eventMultiplier(
      spotName: '三門仔村碼頭',
      fishName: '烏頭',
      fishId: 'fish-063',
      now: DateTime(2026, 6, 24, 13),
    ),
    1.0,
  );
});

test('boosts runway bream during morning and dusk only', () {
  expect(
    FishingEventRules.eventMultiplier(
      spotName: '赤鱲角機場跑道尾',
      fishName: '黃腳鱲',
      fishId: 'fish-109',
      now: DateTime(2026, 6, 24, 6),
    ),
    1.6,
  );
  expect(
    FishingEventRules.eventMultiplier(
      spotName: '赤鱲角機場跑道尾',
      fishName: '黃腳鱲',
      fishId: 'fish-109',
      now: DateTime(2026, 6, 24, 18),
    ),
    1.6,
  );
  expect(
    FishingEventRules.eventMultiplier(
      spotName: '赤鱲角機場跑道尾',
      fishName: '黃腳鱲',
      fishId: 'fish-109',
      now: DateTime(2026, 6, 24, 13),
    ),
    1.0,
  );
});
```

- [x] **Step 3: Run event tests**

Run:

```powershell
flutter test test\fishing_event_rules_test.dart
```

Expected: PASS.

- [x] **Step 4: Commit domain event rules**

Run:

```powershell
git add lib\features\game_home\domain\fishing_event_rules.dart test\fishing_event_rules_test.dart
git commit -m "FisherGO: add local fishing event rules"
```

---

### Task 3: Stack Event Multipliers Into Spawn Rules

**Files:**
- Modify: `lib/features/game_home/domain/fishing_spawn_rules.dart`
- Modify: `test/fishing_spawn_rules_test.dart`

- [x] **Step 1: Write failing spawn integration tests**

Add to `test/fishing_spawn_rules_test.dart`:

```dart
test('stacks Tsing Ma night event on top of location and biome boosts', () {
  final normal = FishingSpawnRules.locationMultiplier(
    spotName: '青馬大橋橋底',
    fishName: '石斑魚',
    fishId: 'fish-073',
    biome: FishingSpotBiome.bridge,
    now: DateTime(2026, 6, 24, 13),
  );
  final event = FishingSpawnRules.locationMultiplier(
    spotName: '青馬大橋橋底',
    fishName: '石斑魚',
    fishId: 'fish-073',
    biome: FishingSpotBiome.bridge,
    now: DateTime(2026, 6, 24, 22),
  );

  expect(event, normal * 2.0);
});

test('does not unblock location-special fish in unrelated event waters', () {
  expect(
    FishingSpawnRules.locationMultiplier(
      spotName: '東龍洲碼頭',
      fishName: '石斑魚',
      fishId: 'fish-073',
      now: DateTime(2026, 6, 24, 18),
    ),
    0,
  );
});

test('keeps generic fish unchanged during active event windows', () {
  expect(
    FishingSpawnRules.locationMultiplier(
      spotName: '青馬大橋橋底',
      fishName: '藍鰭鮪',
      fishId: 'fish-153',
      now: DateTime(2026, 6, 24, 22),
    ),
    1,
  );
});
```

Also add:

```dart
import 'package:fishergo/features/game_home/domain/fishing_biome_rules.dart';
```

- [x] **Step 2: Run spawn tests to verify RED**

Run:

```powershell
flutter test test\fishing_spawn_rules_test.dart
```

Expected: FAIL because `locationMultiplier` does not accept `now`.

- [x] **Step 3: Integrate `FishingEventRules`**

In `lib/features/game_home/domain/fishing_spawn_rules.dart`, add:

```dart
import 'fishing_event_rules.dart';
```

Change the signature:

```dart
static double locationMultiplier({
  required String spotName,
  required String fishName,
  String? fishId,
  FishingSpotBiome? biome,
  DateTime? now,
})
```

After `biomeMultiplier`, add:

```dart
final eventMultiplier = now == null
    ? 1.0
    : FishingEventRules.eventMultiplier(
        spotName: spotName,
        fishName: fishName,
        fishId: fishId,
        now: now,
      );
```

Then change matching returns:

```dart
return targetMultiplier * biomeMultiplier * eventMultiplier;
```

And final generic return:

```dart
return biomeMultiplier * eventMultiplier;
```

Keep this block unchanged:

```dart
if (isSpecialLocationFish) return 0;
```

- [x] **Step 4: Run spawn tests**

Run:

```powershell
flutter test test\fishing_spawn_rules_test.dart
```

Expected: PASS.

- [x] **Step 5: Commit spawn integration**

Run:

```powershell
git add lib\features\game_home\domain\fishing_spawn_rules.dart test\fishing_spawn_rules_test.dart
git commit -m "FisherGO: stack fishing event spawn boosts"
```

---

### Task 4: Show Active Event Chips In Fishing Overlay

**Files:**
- Modify: `lib/features/game_home/presentation/game_home_screen.dart`

- [x] **Step 1: Import event rules**

Add:

```dart
import '../domain/fishing_event_rules.dart';
```

- [x] **Step 2: Pass time into spawn rolls**

In `_FishingOverlayState._selectRandomFish`, change:

```dart
final locationBoost = FishingSpawnRules.locationMultiplier(
  spotName: widget.spotName,
  fishName: fish.name,
  fishId: fish.fishId,
  biome: widget.spotBiome,
);
```

to:

```dart
final locationBoost = FishingSpawnRules.locationMultiplier(
  spotName: widget.spotName,
  fishName: fish.name,
  fishId: fish.fishId,
  biome: widget.spotBiome,
  now: DateTime.now(),
);
```

- [x] **Step 3: Display event chips near existing intel chips**

In `_buildSpotSelect`, after:

```dart
final intelLabels = FishingSpawnRules.spotIntelLabels(widget.spotName);
```

add:

```dart
final eventLabels = FishingEventRules.activeEventLabels(
  spotName: widget.spotName,
  now: DateTime.now(),
);
```

After the existing intel chips block:

```dart
if (intelLabels.isNotEmpty) ...[
  const SizedBox(height: 10),
  _spotIntelChips(intelLabels),
],
```

add:

```dart
if (eventLabels.isNotEmpty) ...[
  const SizedBox(height: 8),
  _spotEventChips(eventLabels),
],
```

Add a widget helper near `_spotIntelChips`:

```dart
Widget _spotEventChips(List<String> labels) {
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    alignment: WrapAlignment.center,
    children: labels
        .map(
          (label) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.amberAccent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, size: 14, color: Colors.amberAccent),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(growable: false),
  );
}
```

- [x] **Step 4: Run analyzer**

Run:

```powershell
flutter analyze
```

Expected: No issues found.

- [x] **Step 5: Commit UI integration**

Run:

```powershell
git add lib\features\game_home\presentation\game_home_screen.dart
git commit -m "FisherGO: show active fishing event chips"
```

---

### Task 5: Full Verification

**Files:**
- Verify all touched code.

- [x] **Step 1: Format edited files**

Run:

```powershell
dart format lib\features\game_home\domain\fishing_event_rules.dart lib\features\game_home\domain\fishing_spawn_rules.dart lib\features\game_home\presentation\game_home_screen.dart test\fishing_event_rules_test.dart test\fishing_spawn_rules_test.dart
```

Expected: formatter completes successfully.

- [x] **Step 2: Run focused tests**

Run:

```powershell
flutter test test\fishing_event_rules_test.dart test\fishing_spawn_rules_test.dart
```

Expected: all tests pass.

- [x] **Step 3: Run full analyzer and test suite**

Run:

```powershell
flutter analyze
flutter test
```

Expected: analyzer clean and full test suite passes.

- [x] **Step 4: Build Android debug APK**

Run:

```powershell
flutter build apk --debug
```

Expected: `build\app\outputs\flutter-apk\app-debug.apk` is created.

- [x] **Step 5: Run emulator smoke**

Run:

```powershell
$sdk=Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb=Join-Path $sdk 'platform-tools\adb.exe'
$apk='build\app\outputs\flutter-apk\app-debug.apk'
& $adb -s emulator-5554 install -r $apk
& $adb -s emulator-5554 shell am force-stop com.fishergo.app
& $adb -s emulator-5554 logcat -c
& $adb -s emulator-5554 shell monkey -p com.fishergo.app -c android.intent.category.LAUNCHER 1
Start-Sleep -Seconds 25
& $adb -s emulator-5554 logcat -d -t 3000 | Select-String -Pattern 'FATAL EXCEPTION|AndroidRuntime.*com\.fishergo|E/flutter|Can request only one|flutter_map|ClientException|Unable to load asset'
```

Expected: no matching app-level fatal/error lines.

---

## Self-Review

- Spec coverage: covers local event rules, time windows, event labels, spawn multiplier stacking, UI chips, focused tests, full tests, APK build, and emulator smoke.
- Empty-marker scan: no incomplete markers or vague event values remain.
- Type consistency: `FishingEventRules`, `FishingTimeWindow`, `eventMultiplier`, `activeEventLabels`, and `locationMultiplier(now:)` names match across tasks.
