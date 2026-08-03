import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/announcement/presentation/announcement_modal.dart',
  ).readAsStringSync();

  test('announcement reward modal exposes state and claim semantics', () {
    expect(source, contains('announcementRewardSemanticsLabel'));
    expect(source, contains('announcementClaimSemanticsLabel'));
    expect(source, contains('announcementClaimedSemanticsLabel'));
    expect(
      source,
      contains('onTap: _loading ? null : () => _claim(context, data)'),
    );
    expect(source, contains('ExcludeSemantics'));
  });
}
