import 'dart:io';

final _supportEmailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

List<String> validatePublicReleaseConfig({
  required String privacyPolicyUrl,
  required String supportEmail,
}) {
  final issues = <String>[];
  final trimmedPrivacyUrl = privacyPolicyUrl.trim();
  if (trimmedPrivacyUrl.isEmpty) {
    issues.add('FISHERGO_PRIVACY_URL is required');
  } else {
    final parsedUrl = Uri.tryParse(trimmedPrivacyUrl);
    if (parsedUrl == null ||
        parsedUrl.scheme.toLowerCase() != 'https' ||
        parsedUrl.host.isEmpty) {
      issues.add('FISHERGO_PRIVACY_URL must be an HTTPS URL');
    }
  }

  final trimmedEmail = supportEmail.trim();
  if (trimmedEmail.isEmpty) {
    issues.add('FISHERGO_SUPPORT_EMAIL is required');
  } else if (!_supportEmailPattern.hasMatch(trimmedEmail)) {
    issues.add('FISHERGO_SUPPORT_EMAIL must be an email address');
  }
  return issues;
}

void main() {
  final issues = validatePublicReleaseConfig(
    privacyPolicyUrl: Platform.environment['FISHERGO_PRIVACY_URL'] ?? '',
    supportEmail: Platform.environment['FISHERGO_SUPPORT_EMAIL'] ?? '',
  );
  if (issues.isNotEmpty) {
    stderr.writeln('FAIL: public release configuration is incomplete.');
    for (final issue in issues) {
      stderr.writeln('- $issue');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('PASS: public release configuration is valid.');
}
