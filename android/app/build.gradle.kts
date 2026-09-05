plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.gold_gym_fe_android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Application ID mengikuti domain android.okejual.com (reverse-DNS).
        // production -> com.okejual.android ; staging + suffix -> com.okejual.android.staging
        applicationId = "com.okejual.android"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
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

    // Flavor per-environment: nama app berbeda antara staging & production.
    // Build dengan `flutter run --flavor staging` / `--flavor production`.
    flavorDimensions += "env"
    productFlavors {
        create("staging") {
            dimension = "env"
            // staging-android.okejual.com -> com.okejual.android.staging
            // (suffix .staging; tanda hubung tak boleh di applicationId).
            // Juga membuat staging & production bisa terpasang bersamaan.
            applicationIdSuffix = ".staging"
            manifestPlaceholders["appName"] = "Okejual-staging"
        }
        create("production") {
            dimension = "env"
            manifestPlaceholders["appName"] = "Okejual"
        }
    }
}

flutter {
    source = "../.."
}
