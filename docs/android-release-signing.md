# Android Release Signing

FisherGO never uses the Android debug key for a release build.

Configure these protected environment variables in the release runner or
local shell that owns the upload keystore:

```text
FISHERGO_ANDROID_KEYSTORE_PATH=C:\secure\fishergo-upload.jks
FISHERGO_ANDROID_KEYSTORE_PASSWORD=<protected value>
FISHERGO_ANDROID_KEY_ALIAS=fishergoRelease
FISHERGO_ANDROID_KEY_PASSWORD=<protected value>
FISHERGO_REQUIRE_RELEASE_SIGNING=true
```

The Gradle release configuration is in
`android/app/build.gradle.kts`. When all four keystore values are present, the
`fisherGoRelease` signing config is used. When
`FISHERGO_REQUIRE_RELEASE_SIGNING=true` is set and any value is missing, the
build fails before packaging. Without the require flag, a local release build
is intentionally unsigned and is not suitable for Play distribution.

Do not commit the keystore, passwords, `key.properties`, or generated signed
artifacts. Play App Signing and the upload key should be managed in the
protected release environment.

## GitHub Actions

The manual workflow at
`.github/workflows/android-release.yml` uses the protected
`fishergo-android-release` environment. Configure these environment secrets:

```text
FISHERGO_ANDROID_KEYSTORE_BASE64
FISHERGO_ANDROID_KEYSTORE_PASSWORD
FISHERGO_ANDROID_KEY_ALIAS
FISHERGO_ANDROID_KEY_PASSWORD
```

The workflow decodes the keystore only into the runner temporary directory,
forces `FISHERGO_REQUIRE_RELEASE_SIGNING=true`, writes a release manifest with
the GitHub commit/version, builds the arm64 AAB and a matching arm64 APK,
keeps separate Dart symbol directories for the AAB and APK builds,
validates the keystore password, key password, and alias before `keytool`,
verifies both JAR signatures, fails if both symbol files were not produced,
and then runs the
client-secret and asset-budget checks for the Android and companion Web
artifacts. Only after all checks pass does it upload `app-release.aab`,
`app-release.apk`, the Dart symbol directory, and `release-manifest.json` as
the `fishergo-android-release` artifact with a 14-day
retention period. Missing secrets fail the job before packaging; the workflow
does not silently create an unsigned release.
