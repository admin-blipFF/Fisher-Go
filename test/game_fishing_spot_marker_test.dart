import 'dart:io';

import 'package:fishergo/features/game_home/presentation/game_fishing_spot_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildMarker({
    required String name,
    required int rarity,
    bool isNew = false,
    bool compact = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: GameFishingSpotMarker(
            name: name,
            rarity: rarity,
            isNew: isNew,
            compact: compact,
          ),
        ),
      ),
    );
  }

  testWidgets('renders the beacon, name, and rarity semantic label',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(buildMarker(name: '中環碼頭', rarity: 3));

    expect(
      tester.getSize(find.byType(GameFishingSpotMarker)),
      const Size(118, 124),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/fishing/map_markers/fishing_spot_beacon_3d.png',
    );
    expect(find.text('中環碼頭'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Fishing spot: 中環碼頭, Epic rarity'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('shows NEW only for newly discovered spots', (tester) async {
    await tester.pumpWidget(
      buildMarker(name: '西貢碼頭', rarity: 2, isNew: true),
    );
    expect(find.text('NEW'), findsOneWidget);

    await tester.pumpWidget(buildMarker(name: '西貢碼頭', rarity: 2));
    expect(find.text('NEW'), findsNothing);
  });

  testWidgets('keeps a long spot name bounded without layout exceptions',
      (tester) async {
    const longName = '香港仔避風塘長長長長長長長長長長長長釣魚熱點';

    await tester.pumpWidget(buildMarker(name: longName, rarity: 5));

    final name = tester.widget<Text>(find.text(longName));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact distant marker keeps the 3D beacon but hides labels',
      (tester) async {
    await tester.pumpWidget(
      buildMarker(name: '遠處釣點', rarity: 3, isNew: true, compact: true),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('遠處釣點'), findsNothing);
    expect(find.text('NEW'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('proximity ring uses a dedicated non-filled painter without spread', () {
    final source = File(
      'lib/features/game_home/presentation/game_fishing_spot_marker.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('fishing-spot-proximity-ring')"));
    expect(
        source, contains('class _ProximityRingPainter extends CustomPainter'));
    expect(source, isNot(contains('spreadRadius:')));
  });

  test('map renderer leaves visible spot bodies to the projected overlay', () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains('fishingSpots: const <ProjectedFishingSpot>[],'));
    expect(
      source,
      contains('..._buildProjectedSpotButtons(camera, fishingSpots),'),
    );
    expect(source, contains('=> GameFishingSpotMarker('));
    expect(source, contains('..sort(_compareProjectedSpotDepth)'));
    expect(source, contains('compact: _isProjectedSpotCompact('));
  });
}
