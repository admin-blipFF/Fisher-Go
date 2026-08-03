import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/core/theme/fishergo_theme.dart';

void main() {
  test('Traditional Chinese platform fallback includes regional CJK families',
      () {
    expect(fisherGoFontFamilyFallback, contains('Noto Sans CJK TC'));
    expect(fisherGoFontFamilyFallback, contains('Noto Sans TC'));
    expect(fisherGoFontFamilyFallback, contains('PingFang TC'));
    expect(fisherGoFontFamilyFallback, contains('Microsoft JhengHei'));
    expect(fisherGoFontFamilyFallback, contains('sans-serif'));
  });

  test('FisherGO theme exposes the same fallback list to Flutter text styles',
      () {
    final theme = fisherGoTheme();

    expect(
      theme.textTheme.bodyMedium?.fontFamilyFallback,
      orderedEquals(fisherGoFontFamilyFallback),
    );
  });
}
