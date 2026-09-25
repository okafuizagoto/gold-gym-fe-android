import java.util.Properties

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
        // flutter_secure_storage (token disimpan di Android Keystore) butuh minimal API 23 (Android 6).
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Penandatanganan rilis Play Store: android/key.properties (GITIGNORED, jangan di-commit) berisi
    //   storeFile=/path/upload-keystore.jks  storePassword=...  keyAlias=upload  keyPassword=...
    // Tanpa file itu build rilis memakai kunci debug (HANYA untuk uji lokal, Play akan menolak) dan diberi peringatan.
    val keystoreProps = Properties()
    val keystoreFile = rootProject.file("key.properties")
    if (keystoreFile.exists()) keystoreFile.inputStream().use { keystoreProps.load(it) }

    signingConfigs {
        if (keystoreFile.exists()) {
            create("release") {
                storeFile = file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("PERINGATAN: android/key.properties tidak ada -- build rilis ditandatangani kunci DEBUG (tidak bisa diunggah ke Play).")
                signingConfigs.getByName("debug")
            }
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
