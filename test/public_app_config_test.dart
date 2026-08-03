import 'package:fishergo/core/config/public_app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web defaults to the motion-safe MapLibre style', () {
    expect(PublicAppConfig.mapWebMotionStyleEnabled, isTrue);
  });

  test('operational kill switches default to enabled', () {
    expect(PublicAppConfig.eventsEnabled, isTrue);
    expect(PublicAppConfig.fishRecognitionEnabled, isTrue);
    expect(PublicAppConfig.fishingSpotsEnabled, isTrue);
  });

  test('destructive account deletion stays disabled by default', () {
    expect(PublicAppConfig.accountDeletionEnabled, isFalse);
  });

  test('legal and support links are public build-time configuration', () {
    expect(PublicAppConfig.privacyPolicyUrl, isA<String>());
    expect(PublicAppConfig.supportEmail, isA<String>());
  });

  test('problem report URI is omitted without an owner mailbox', () {
    expect(PublicAppConfig.problemReportUriFor('  '), isNull);

    final uri = PublicAppConfig.problemReportUriFor('support@example.com');
    expect(uri, isNotNull);
    expect(uri!.scheme, 'mailto');
    expect(uri.path, 'support@example.com');
    expect(uri.queryParameters['subject'], 'FisherGO 問題報告');
    expect(uri.queryParameters['body'], contains('重現步驟'));
  });
}
