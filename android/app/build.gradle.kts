plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.freelance.freelancetahaapp"
    // 36 is required by androidx.browser 1.9 (ephemeral Custom Tabs).
    compileSdk = 36
    // Pinned to the highest NDK any plugin needs (video_player, webview_flutter,
    // url_launcher and shared_preferences all require 27); NDKs are backward
    // compatible, so this satisfies every plugin.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required by flutter_local_notifications (scheduled call notifications).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.freelance.freelancetahaapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // firebase_messaging requires 23.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Custom Tabs, incl. setEphemeralBrowsingEnabled (private session) from 1.9.
    implementation("androidx.browser:browser:1.9.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Firebase is optional: without google-services.json the app still builds and
// runs, just without call pushes. Drop the file in and rebuild to enable them.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
