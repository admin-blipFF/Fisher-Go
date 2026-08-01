import org.gradle.api.tasks.compile.JavaCompile

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningValues = mapOf(
    "storeFile" to System.getenv("FISHERGO_ANDROID_KEYSTORE_PATH").orEmpty(),
    "storePassword" to System.getenv("FISHERGO_ANDROID_KEYSTORE_PASSWORD").orEmpty(),
    "keyAlias" to System.getenv("FISHERGO_ANDROID_KEY_ALIAS").orEmpty(),
    "keyPassword" to System.getenv("FISHERGO_ANDROID_KEY_PASSWORD").orEmpty(),
)
val releaseSigningConfigured = releaseSigningValues.values.all(String::isNotBlank)
val requireReleaseSigning =
    System.getenv("FISHERGO_REQUIRE_RELEASE_SIGNING").equals("true", ignoreCase = true)
val useMapLibreHcppDiagnostic =
    System.getenv("FISHERGO_MAP_HCPP").equals("true", ignoreCase = true)

if (requireReleaseSigning && !releaseSigningConfigured) {
    throw GradleException(
        "Release signing is required. Configure the FISHERGO_ANDROID_* signing environment variables.",
    )
}

android {
    namespace = "com.fishergo.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.fishergo.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["fishergoEnableHcpp"] =
            useMapLibreHcppDiagnostic.toString()
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("fisherGoRelease") {
                storeFile = file(releaseSigningValues.getValue("storeFile"))
                storePassword = releaseSigningValues.getValue("storePassword")
                keyAlias = releaseSigningValues.getValue("keyAlias")
                keyPassword = releaseSigningValues.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("fisherGoRelease")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// The Flutter plugin currently requests MapLibre Native 13.0.+. Keep the
// Android renderer independently upgradeable so native performance fixes can
// be evaluated without forking the generated JNI bindings first. Vulkan stays
// an explicit diagnostic because it is a separate native backend artifact.
val useMapLibreVulkanDiagnostic =
    System.getenv("FISHERGO_MAP_VULKAN").equals("true", ignoreCase = true)
val mapLibreNativeVersion =
    System.getenv("FISHERGO_MAP_NATIVE_VERSION")
        .takeIf { !it.isNullOrBlank() }
        ?: "13.2.0"
val mapLibreVulkanVersion =
    System.getenv("FISHERGO_MAP_VULKAN_VERSION")
        .takeIf { !it.isNullOrBlank() }
        ?: "13.0.2"

configurations.configureEach {
    resolutionStrategy.eachDependency {
        if (requested.group == "org.maplibre.gl" &&
            requested.name == "android-sdk-opengl") {
            if (useMapLibreVulkanDiagnostic) {
                useTarget("org.maplibre.gl:android-sdk-vulkan:$mapLibreVulkanVersion")
                because("FisherGO MapLibre Vulkan renderer diagnostic: $mapLibreVulkanVersion")
            } else {
                useVersion(mapLibreNativeVersion)
                because("FisherGO MapLibre OpenGL renderer baseline: $mapLibreNativeVersion")
            }
        }
    }
}

// Flutter 3.44 still generates dev-only integration_test registration in the
// shared registrant. Filter only that generated main source from the release
// Java compile; the release source set supplies the production-only overlay.
tasks.withType<JavaCompile>().configureEach {
    if (name == "compileReleaseJavaWithJavac") {
        doFirst {
            source = project.fileTree("src/release/java")
        }
    }
}
