import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fishergo/features/fish/data/fish_species_repository.dart';
import 'package:fishergo/features/fish/domain/fish_species.dart';
import 'package:fishergo/features/fish/presentation/fish_encyclopedia_screen.dart';

class _SingleSpeciesRepository implements FishSpeciesRepository {
  @override
  Future<List<FishSpecies>> getSpecies({bool forceRefresh = false}) async {
    return const [
      FishSpecies(
        id: 'fish-001',
        commonNameZh: '測試魚',
        silhouetteUrl: 'assets/fish/icons/locked_silhouette.png',
      ),
    ];
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fishergo_encyclopedia_semantics_test_',
    );
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('encyclopedia exposes progress and locked card semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: FishEncyclopediaScreen(
            repository: _SingleSpeciesRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('圖鑑解鎖進度：0/1，0%，魚鈎認證 0 個'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('魚種 #001，名稱未知，未發現'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });
}
