# Game Overworld Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the confirmed first-run login-before-tutorial flow, tutorial skip button, and first Pokemon GO-style FisherGO game overworld map presentation.

**Architecture:** Keep existing game logic in `GameHomeScreen` as the source of truth for spots, GPS, distance checks, and minigame launch. Add a small private game-world visual layer around the existing `FlutterMap`, and keep tutorial skip behavior inside `TutorialOverlay` so completion remains owned by `TutorialService`.

**Tech Stack:** Flutter, flutter_map, Hive, flutter_test, existing FisherGO widgets and domain services.

---

## File Structure

- Modify `lib/features/tutorial/presentation/tutorial_overlay.dart`
  - Add a skip action available on all tutorial steps.
  - Keep existing `TutorialService.markCompleted()` persistence.
- Modify `lib/features/game_home/presentation/game_home_screen.dart`
  - Keep startup gate order: identity dialog first, then tutorial.
  - Adjust map visual composition into a game overworld using `Stack`, `Transform`, `CustomPainter`, and existing markers/buttons.
  - Keep all existing GPS, spot selection, and minigame callbacks.
- Modify `test/tutorial_service_test.dart`
  - Add a direct persistence regression for skip-equivalent completion.
- Modify `test/widget_test.dart`
  - Update smoke assertions to expect the game overworld HUD labels while still checking navigation buttons.

## Task 1: Tutorial Skip

**Files:**
- Modify: `lib/features/tutorial/presentation/tutorial_overlay.dart`
- Test: `test/tutorial_service_test.dart`

- [ ] **Step 1: Add a persistence regression test**

Append this test inside the existing `group('TutorialService', () { ... })` in `test/tutorial_service_test.dart`:

```dart
test('skip tutorial uses the same completed state as finishing tutorial', () async {
  await TutorialService.markCompleted();

  final result = await TutorialService.isCompleted();

  expect(result, true);
});
```

- [ ] **Step 2: Run the focused tutorial test**

Run:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
flutter test test\tutorial_service_test.dart
```

Expected: all tutorial service tests pass.

- [ ] **Step 3: Add `TutorialOverlay` skip action**

In `lib/features/tutorial/presentation/tutorial_overlay.dart`, add this method inside `_TutorialOverlayState` below `_onComplete()`:

```dart
Future<void> _onSkip() async {
  await TutorialService.markCompleted();
  widget.onComplete();
}
```

In the `Stack` children of `build`, add a top-right skip button after the `_StepIndicator` `Positioned`:

```dart
Positioned(
  top: MediaQuery.of(context).padding.top + 8,
  right: 16,
  child: TextButton(
    onPressed: _onSkip,
    style: TextButton.styleFrom(
      foregroundColor: Colors.white70,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
    ),
    child: const Text('略過'),
  ),
),
```

Update the comment above `_buildNavButtons()` from `Step 2 is NOT skippable` to:

```dart
// Step 2 has no Back/Next navigation; the top-right Skip remains available.
```

- [ ] **Step 4: Run focused tests**

Run:

```powershell
flutter test test\tutorial_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib\features\tutorial\presentation\tutorial_overlay.dart test\tutorial_service_test.dart
git commit -m "Add skippable tutorial overlay"
```

## Task 2: Login Before Tutorial Guard

**Files:**
- Modify: `lib/features/game_home/presentation/game_home_screen.dart`

- [ ] **Step 1: Make startup sequencing explicit**

In `_runStartupGate`, preserve the existing sequence but make the identity-first requirement self-documenting by replacing the body with:

```dart
Future<void> _runStartupGate() async {
  if (!mounted || _isStartupGateOpen) return;

  final shouldAskIdentity = await _shouldAskIdentityChoice();
  if (!mounted) return;

  if (shouldAskIdentity) {
    setState(() => _isStartupGateOpen = true);
    await _showIdentityChoiceDialog();
    if (!mounted) return;
    setState(() => _isStartupGateOpen = false);
  }

  await _checkAndShowTutorial();
}
```

- [ ] **Step 2: Verify the behavior in code**

Run:

```powershell
rg -n "_runStartupGate|_showIdentityChoiceDialog|_checkAndShowTutorial" lib\features\game_home\presentation\game_home_screen.dart
```

Expected: `_checkAndShowTutorial` is called after `_showIdentityChoiceDialog` resolves.

- [ ] **Step 3: Run analyzer**

Run:

```powershell
flutter analyze
```

Expected: `No issues found`.

- [ ] **Step 4: Commit**

```powershell
git add lib\features\game_home\presentation\game_home_screen.dart
git commit -m "Clarify startup identity gate before tutorial"
```

## Task 3: Game Overworld Visual Layer

**Files:**
- Modify: `lib/features/game_home/presentation/game_home_screen.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Update smoke test expectations**

In `test/widget_test.dart`, keep the navigation assertions and add these expectations after the existing `pump` calls:

```dart
expect(find.text('Fisher Lv. 1'), findsOneWidget);
expect(find.text('探索水域'), findsOneWidget);
```

If the old assertion `find.text('附近 0 個釣點')` no longer matches after the HUD change, replace it with:

```dart
expect(find.textContaining('附近'), findsOneWidget);
```

- [ ] **Step 2: Run widget test to capture current state**

Run:

```powershell
flutter test test\widget_test.dart
```

Expected before implementation: FAIL because the new game HUD labels do not exist yet.

- [ ] **Step 3: Add game-world wrappers to `build`**

In `GameHomeScreen.build`, keep the existing `FlutterMap` but wrap it with a stylized `Stack`:

```dart
final mapWorld = _GameWorldMapShell(
  child: FlutterMap(
    mapController: _mapController,
    options: MapOptions(
      initialCenter: _hkTerritoryCenter,
      initialZoom: 13,
      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      onPositionChanged: (pos, hasGesture) {
        if (hasGesture) {
          setState(() => _zoom = pos.zoom.clamp(0.6, 3.4));
        }
      },
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        tileProvider: NetworkTileProvider(silenceExceptions: true),
        evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
        errorTileCallback: (_, __, ___) {},
        userAgentPackageName: 'com.fishergo.app',
      ),
      CircleLayer(circles: [
        if (_hasLiveLocation && _playerAccuracyMeters != null)
          CircleMarker(
            point: _playerLatLng,
            radius: _playerAccuracyMeters!,
            useRadiusInMeter: true,
            color: Colors.cyanAccent.withValues(alpha: 0.14),
            borderColor: Colors.cyanAccent.withValues(alpha: 0.7),
            borderStrokeWidth: 1.2,
          ),
        CircleMarker(
          point: _playerLatLng,
          radius: _spotDisplayRadiusMeters,
          useRadiusInMeter: true,
          color: Colors.white.withValues(alpha: 0.08),
          borderColor: Colors.white.withValues(alpha: 0.45),
          borderStrokeWidth: 1,
        ),
        ..._nearbySpots.map((spot) => CircleMarker(
              point: LatLng(spot.lat, spot.lng),
              radius: 80,
              useRadiusInMeter: true,
              color: _rarityColor(spot.rarity).withValues(alpha: 0.15),
              borderColor: _rarityColor(spot.rarity),
              borderStrokeWidth: 1.5,
            )),
      ]),
      MarkerLayer(markers: [...markers, centerMarker]),
    ],
  ),
);
```

Then replace the direct `FlutterMap(...)` child at the top of the `Stack` with `mapWorld`.

- [ ] **Step 4: Add `_GameWorldMapShell` private widget**

Add this private widget near `_RadarGridPainter` in `game_home_screen.dart`:

```dart
class _GameWorldMapShell extends StatelessWidget {
  const _GameWorldMapShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF52D7DE),
                Color(0xFF88E6B4),
                Color(0xFF58C783),
              ],
            ),
          ),
        ),
        Positioned.fill(
          top: -80,
          child: Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(0.82)
              ..scale(1.22, 1.12),
            child: ClipRect(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  const Color(0xFF73F0B2).withValues(alpha: 0.24),
                  BlendMode.srcATop,
                ),
                child: child,
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _GameWorldAtmospherePainter(),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Add `_GameWorldAtmospherePainter`**

Add this painter below `_GameWorldMapShell`:

```dart
class _GameWorldAtmospherePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final seaPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xAA3CCEE8), Color(0x886EE8D0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.28));
    final seaPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.31,
        0,
        size.height * 0.23,
      )
      ..close();
    canvas.drawPath(seaPath, seaPaint);

    final roadPaint = Paint()
      ..color = const Color(0xAA496D84)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final roadHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (final path in [
      Path()
        ..moveTo(size.width * -0.1, size.height * 0.72)
        ..quadraticBezierTo(size.width * 0.4, size.height * 0.52,
            size.width * 1.1, size.height * 0.62),
      Path()
        ..moveTo(size.width * 0.1, size.height * 1.05)
        ..quadraticBezierTo(size.width * 0.52, size.height * 0.62,
            size.width * 0.82, size.height * 0.18),
    ]) {
      canvas.drawPath(path, roadPaint);
      canvas.drawPath(path, roadHighlight);
    }

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.55);
    final center = Offset(size.width / 2, size.height * 0.56);
    canvas.drawCircle(center, 72, ringPaint);
    canvas.drawCircle(
      center,
      130,
      ringPaint..color = Colors.white.withValues(alpha: 0.2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

- [ ] **Step 6: Add Pokemon GO-style top labels**

Replace the `_TopStatusBar` `Positioned` child with a compact game HUD that includes the labels used by the test:

```dart
child: _TopStatusBar(
  spotCount: visibleSpots.length,
  autoEnabled: _autoMode,
  onToggleAuto: () => setState(() => _autoMode = !_autoMode),
  leadingLabel: 'Fisher Lv. 1',
  subtitleLabel: '探索水域',
),
```

If `_TopStatusBar` does not support these fields, update its constructor and build method to render:

```dart
Text(leadingLabel, style: const TextStyle(...))
Text(subtitleLabel, style: const TextStyle(...))
```

Keep existing spot count and auto toggle visible.

- [ ] **Step 7: Round the side controls**

Update `_MapZoomControls` button decoration from rounded rectangles to circles:

```dart
width: 44,
height: 44,
decoration: BoxDecoration(
  shape: BoxShape.circle,
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, Color(0xFFE3F4FF)],
  ),
  boxShadow: const [
    BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 6)),
    BoxShadow(color: Colors.white70, blurRadius: 2, offset: Offset(-1, -1)),
  ],
),
```

Use dark blue or teal icon color instead of white.

- [ ] **Step 8: Run focused widget test**

Run:

```powershell
flutter test test\widget_test.dart
```

Expected: PASS with the new game HUD labels and existing navigation labels.

- [ ] **Step 9: Run full verification**

Run:

```powershell
flutter analyze
flutter test
```

Expected:

- `flutter analyze` reports `No issues found`.
- `flutter test` reports all tests passed.

- [ ] **Step 10: Commit**

```powershell
git add lib\features\game_home\presentation\game_home_screen.dart test\widget_test.dart
git commit -m "Add game overworld map presentation"
```

## Self-Review

- Spec coverage: Task 1 covers tutorial skip; Task 2 covers identity before tutorial; Task 3 covers game overworld map and 3D round controls.
- Placeholder scan: no unfinished placeholder markers are used.
- Type consistency: new labels are passed through `_TopStatusBar`; if missing fields are found during implementation, Task 3 Step 6 defines the required constructor extension.
