import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release Android source set excludes the integration test plugin', () {
    final gradleFile = File('android/app/build.gradle.kts');
    final androidGitignore = File('android/.gitignore');
    final releaseRegistrant = File(
      'android/app/src/release/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
    );

    expect(gradleFile.existsSync(), isTrue);
    expect(androidGitignore.existsSync(), isTrue);
    expect(releaseRegistrant.existsSync(), isTrue);

    final gradle = gradleFile.readAsStringSync();
    final gitignore = androidGitignore.readAsStringSync();
    final registrant = releaseRegistrant.readAsStringSync();

    expect(gradle, contains('compileReleaseJavaWithJavac'));
    expect(gradle, contains('source = project.fileTree("src/release/java")'));
    expect(gradle, contains('doFirst'));
    expect(gradle, contains('org.maplibre.gl'));
    expect(gradle, contains('useVersion(mapLibreNativeVersion)'));
    expect(gradle, contains('?: "13.2.0"'));
    expect(gradle, contains('FISHERGO_MAP_NATIVE_VERSION'));
    expect(gradle, contains('mapLibreNativeVersion'));
    expect(gradle, contains('FISHERGO_MAP_VULKAN'));
    expect(gradle, contains('FISHERGO_MAP_VULKAN_VERSION'));
    expect(gradle, contains('mapLibreVulkanVersion'));
    expect(gradle, contains(r'android-sdk-vulkan:$mapLibreVulkanVersion'));
    expect(gradle, contains('FisherGO MapLibre OpenGL renderer baseline'));
    expect(gradle, contains('FISHERGO_MAP_HCPP'));
    expect(gradle, contains('fishergoEnableHcpp'));
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue);
    final manifestContents = manifest.readAsStringSync();
    expect(
      manifestContents,
      contains('io.flutter.embedding.android.EnableHcpp'),
    );
    expect(manifestContents, contains(r'${fishergoEnableHcpp}'));
    expect(
      gitignore,
      contains(
          '!app/src/release/java/io/flutter/plugins/GeneratedPluginRegistrant.java'),
    );
    expect(registrant, isNot(contains('dev.flutter.plugins.integration_test')));
    expect(registrant, contains('com.github.josxha.maplibre.MapLibrePlugin'));
    expect(registrant, contains('com.baseflow.geolocator.GeolocatorPlugin'));
  });
}
