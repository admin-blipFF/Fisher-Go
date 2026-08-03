import 'package:flutter/material.dart';

/// Prefer regional Traditional Chinese families when the host provides them.
/// Flutter falls through this list to the platform's generic sans-serif face.
const List<String> fisherGoFontFamilyFallback = <String>[
  'Noto Sans CJK TC',
  'Noto Sans TC',
  'PingFang TC',
  'Microsoft JhengHei',
  'sans-serif',
];

ThemeData fisherGoTheme() {
  return ThemeData(
    colorSchemeSeed: Colors.teal,
    useMaterial3: true,
    fontFamilyFallback: fisherGoFontFamilyFallback,
  );
}
