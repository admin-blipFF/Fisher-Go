import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib${Platform.pathSeparator}features${Platform.pathSeparator}fish${Platform.pathSeparator}'
    'presentation${Platform.pathSeparator}fish_encyclopedia_screen.dart',
  ).readAsStringSync();

  test('encyclopedia builds card media lazily through the sliver builder', () {
    expect(source, contains('SliverGrid.builder'));
    expect(source, contains('itemBuilder: (context, index)'));
    expect(source, isNot(contains('SliverGrid.count')));
  });

  test('catalog artwork remains decode-bounded at card density', () {
    expect(source, contains('cacheWidth: fishCatalogArtworkCacheWidth('));
    expect(source, contains('cacheHeight: fishCatalogArtworkCacheHeight('));
    expect(source, contains('Image.asset('));
  });

  test('locked cards select silhouette artwork before image decoding', () {
    final selectionIndex = source.indexOf('fishCatalogArtworkAssetPath(');
    final artworkIndex = source.indexOf('Image.asset(', selectionIndex);

    expect(selectionIndex, greaterThanOrEqualTo(0));
    expect(artworkIndex, greaterThan(selectionIndex));
    expect(source, contains('discovered ? imagePath : silhouettePath'));
  });
}
