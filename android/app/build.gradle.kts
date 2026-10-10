import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Play upload key. android/key.properties (gitignored) points at a
// keystore kept OUTSIDE the repo. Losing it means asking Google for an
// upload-key reset, so it must be backed up.
val keyProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

// Only Play bundles (`flutter build appbundle`) use the upload key. APKs
// shared by hand stay on the debug key, so everyone already testing them
// can keep updating in place - a phone refuses an update signed with a
// different key unless the old app (and its data) is removed first.
val buildingBundle = gradle.startParameter.taskNames.any {
    it.contains("bundle", ignoreCase = true)
}

android {
    namespace = "com.alokraj.habit_reward_tracker"
    // Google Play requires new apps to target Android 16 (API 36) since
    // 31 Aug 2026. Flutter 3.32 defaults to 35.
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.alokraj.habit_reward_tracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // workmanager (nightly Drive backup) needs Android 6.0+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // With minSdk 23 the build tools default to storing native libraries
    // uncompressed, which doubled the APK (33 -> 69 MB). The APK is shared
    // by hand, so keep it compressed.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    signingConfigs {
        if (keyProperties.containsKey("storeFile")) {
            create("upload") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (buildingBundle) {
                signingConfigs.findByName("upload")
                    ?: throw GradleException(
                        "Play bundles need android/key.properties (the upload key).")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
