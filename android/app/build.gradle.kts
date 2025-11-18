plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ai_hybrid_hub"
    // WHY: Version 36 du SDK est requise par plusieurs plugins (path_provider_android,
    // share_plus, sqflite_android) et les dépendances androidx.core (1.16.0+).
    // Cette version est rétrocompatible et donne accès aux dernières fonctionnalités
    // et optimisations de l'API Android.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.ai_hybrid_hub"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // WHY: API 23 (Android 6.0) est une base de départ moderne et sécurisée
        // qui couvre la grande majorité des appareils en 2025 tout en étant
        // bien au-dessus du minimum requis (19) par la bibliothèque.
        minSdk = flutter.minSdkVersion
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
