import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_hk_terrain_mvp.dart';

void main() {
  test('builds terrain asset from geocoded Hong Kong source data', () {
    final asset = buildTerrainAsset(
      sourceCsv: File(
        'data/hk_geo/hk_fishing_spots_master_all_geocoded_gov.csv',
      ).readAsStringSync(),
    );
    final features = asset['features'] as List<Map<String, Object>>;
    final names = features.map((feature) => feature['name']).toSet();
    final kinds = features.map((feature) => feature['kind']).toSet();

    expect(features.length, greaterThan(70));
    expect(
        kinds, containsAll(['water', 'land', 'road', 'pier', 'fishingNode']));
    expect(names, containsAll(['青馬大橋', '三門仔村碼頭', '長洲公眾碼頭', '跑道尾立魚位']));
  });

  test('current bundled terrain asset matches generator output', () {
    final generated = buildTerrainAsset(
      sourceCsv: File(
        'data/hk_geo/hk_fishing_spots_master_all_geocoded_gov.csv',
      ).readAsStringSync(),
    );
    final current = jsonDecode(
      File('assets/maps/hk_terrain_mvp.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(current, generated);
  });
}
