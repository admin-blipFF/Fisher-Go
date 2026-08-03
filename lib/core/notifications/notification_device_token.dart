/// A provider-issued token that can be safely handed to the authenticated
/// Supabase registration RPC.
class NotificationDeviceToken {
  const NotificationDeviceToken({
    required this.platform,
    required this.provider,
    required this.token,
  });

  static const supportedPlatforms = <String>{'android', 'ios', 'web'};
  static const supportedProviders = <String>{'fcm', 'apns', 'web_push'};

  final String platform;
  final String provider;
  final String token;

  String get normalizedPlatform => platform.trim().toLowerCase();
  String get normalizedProvider => provider.trim().toLowerCase();
  String get normalizedToken => token.trim();

  bool get isValid =>
      supportedPlatforms.contains(normalizedPlatform) &&
      supportedProviders.contains(normalizedProvider) &&
      normalizedToken.length >= 16 &&
      normalizedToken.length <= 4096;

  Map<String, Object?> toRpcParams() => <String, Object?>{
        'p_platform': normalizedPlatform,
        'p_provider': normalizedProvider,
        'p_token': normalizedToken,
      };
}

NotificationDeviceToken? notificationDeviceTokenFromPlatformValue(Object? raw) {
  if (raw is! Map) return null;
  final platform = raw['platform'];
  final provider = raw['provider'];
  final token = raw['token'];
  if (platform is! String || provider is! String || token is! String) {
    return null;
  }
  final value = NotificationDeviceToken(
    platform: platform,
    provider: provider,
    token: token,
  );
  return value.isValid ? value : null;
}
