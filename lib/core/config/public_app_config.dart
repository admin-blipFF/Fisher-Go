/// Values that are safe to expose in a Flutter client build.
/// Provider credentials and model keys must never be added here. Use a
/// Supabase Edge Function for integrations that require a secret.
class PublicAppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const privacyPolicyUrl = String.fromEnvironment(
    'FISHERGO_PRIVACY_URL',
  );
  static const supportEmail = String.fromEnvironment(
    'FISHERGO_SUPPORT_EMAIL',
  );

  static Uri? get problemReportUri => problemReportUriFor(supportEmail);

  static Uri? problemReportUriFor(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return null;
    return Uri(
      scheme: 'mailto',
      path: trimmed,
      queryParameters: const {
        'subject': 'FisherGO 問題報告',
        'body': '請描述問題、發生位置和重現步驟：\n\n',
      },
    );
  }

  static const fishRecognitionFunction = String.fromEnvironment(
    'FISH_RECOGNITION_FUNCTION',
    defaultValue: 'recognize-fish',
  );
  static const eventsEnabled = bool.fromEnvironment(
    'FISHERGO_EVENTS_ENABLED',
    defaultValue: true,
  );
  static const fishRecognitionEnabled = bool.fromEnvironment(
    'FISHERGO_RECOGNITION_ENABLED',
    defaultValue: true,
  );
  static const fishingSpotsEnabled = bool.fromEnvironment(
    'FISHERGO_SPOTS_ENABLED',
    defaultValue: true,
  );
  static const analyticsEnabled = bool.fromEnvironment(
    'FISHERGO_ANALYTICS_ENABLED',
    defaultValue: false,
  );

  /// Keep the destructive account action hidden until the hosted function
  /// deployment and disposable-account smoke have passed.
  static const accountDeletionEnabled = bool.fromEnvironment(
    'FISHERGO_ACCOUNT_DELETION_ENABLED',
    defaultValue: false,
  );
  static const mapLibreEnabled = bool.fromEnvironment(
    'FISHERGO_MAPLIBRE',
    defaultValue: false,
  );
  static const mapVectorFallbackEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_VECTOR_FALLBACK',
    defaultValue: false,
  );
  static const mapPerformanceEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_PERF',
    defaultValue: false,
  );
  static const mapHudCompositionDiagnosticEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_HUD_COMPOSITION_DIAGNOSTIC',
    defaultValue: false,
  );
  static const mapHudDiagnosticProfile = String.fromEnvironment(
    'FISHERGO_MAP_HUD_PROFILE',
    defaultValue: 'none',
  );

  static bool get mapHudNavigationHidden =>
      mapHudCompositionDiagnosticEnabled ||
      mapHudDiagnosticProfile == 'navigation';

  static bool get mapHudUtilityHidden =>
      mapHudCompositionDiagnosticEnabled ||
      mapHudDiagnosticProfile == 'utility';

  static bool get mapHudBottomHidden =>
      mapHudCompositionDiagnosticEnabled || mapHudDiagnosticProfile == 'bottom';

  /// Hides one HUD child for an opt-in composition attribution run.
  ///
  /// The production profile is `none`, so this remains a no-op unless a
  /// benchmark explicitly supplies a child profile name.
  static bool mapHudWidgetHidden(String profileName) {
    return mapHudCompositionDiagnosticEnabled ||
        mapHudDiagnosticProfile == profileName;
  }

  static const mapOfflineWarmupEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_CACHE_WARMUP',
    defaultValue: false,
  );
  static const mapMarkerProjectionDebugEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_MARKER_DEBUG',
    defaultValue: false,
  );
  static const mapTextureModeEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_TEXTURE',
    defaultValue: true,
  );
  static const mapHybridCompositionEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_HC',
    defaultValue: false,
  );
  static const mapDirectHybridCompositionEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_HC_DIRECT',
    defaultValue: false,
  );
  static const mapVirtualDisplayEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_VD',
    defaultValue: false,
  );
  static const mapCompactStyleEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_COMPACT',
    defaultValue: false,
  );
  static const mapAndroidCompactStyleEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_ANDROID_COMPACT',
    defaultValue: true,
  );
  static const mapLowPowerStyleEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_LOW_POWER',
    defaultValue: false,
  );
  static const mapWebMotionStyleEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_WEB_MOTION',
    // Web remains fully geographic but avoids building extrusion during
    // camera motion. Set FISHERGO_MAP_WEB_MOTION=false for the rich style.
    defaultValue: true,
  );
  static const mapGame3dStyleEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_3D_STYLE',
    defaultValue: false,
  );
  static const mapAndroidGame3dStyleEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_ANDROID_3D_STYLE',
    defaultValue: true,
  );
  static const mapFixedBuildingHeightEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_FIXED_BUILDING_HEIGHT',
    defaultValue: false,
  );
  static const mapFlutterMarkersEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_MARKERS',
    defaultValue: true,
  );
  static const mapAndroidMarkerShadowsEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_ANDROID_MARKER_SHADOWS',
    defaultValue: false,
  );
  static const mapAndroidMarkerMotionOptimizationEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_ANDROID_MARKER_MOTION',
    defaultValue: true,
  );
  static const mapNativeFishingSpotLayerEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_NATIVE_SPOT_LAYER',
    defaultValue: false,
  );
  static const mapNativePlayerLayerEnabled = bool.fromEnvironment(
    'FISHERGO_MAP_NATIVE_PLAYER_LAYER',
    defaultValue: false,
  );

  const PublicAppConfig._();
}
