// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from a gitignored key.properties file so the keystore
// path and passwords never appear in version control. If the file is absent the
// build falls back to the debug config, which is only ever acceptable for a
// local `flutter run --release`.
val keystoreProperties = Properties()
val keystorePropertiesFile: java.io.File = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.clintoniwoloma.safedepot_pro"
    // permission_handler_android and local_auth compile against API 37, so the
    // project must target it rather than inheriting Flutter's default.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time APIs that need core
        // library desugaring to run on the minimum supported runtime.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.clintoniwoloma.safedepot_pro"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystoreProperties.isNotEmpty()) {
                    signingConfigs.getByName("release")
                } else {
                    // Debug fallback so a release-mode run works without a
                    // keystore. Never distribute an artifact built this way.
                    signingConfigs.getByName("debug")
                }

            // R8 minification and resource shrinking for the release build.
            //
            // R8 and Dart obfuscation are complementary, not redundant: R8
            // works on the Java/Kotlin side (including the Flutter embedding
            // and any plugins written in native Android code), while Dart
            // obfuscation renames Dart identifiers in the AOT snapshot.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// `gen_snapshot` writes the Dart obfuscation map via
// --extra-gen-snapshot-options, but it does not create the parent directory
// first, so a clean tree fails with "Unable to write file". Creating it before
// the Android build runs makes obfuscated Shorebird releases reproducible
// without a manual `mkdir -p build/shorebird`.
val prepareObfuscationMapDir by tasks.registering {
    doLast {
        mkdir(project.layout.buildDirectory.dir("shorebird").get().asFile)
    }
}
tasks.matching { it.name.startsWith("pre") && it.name.endsWith("Build") }.configureEach {
    dependsOn(prepareObfuscationMapDir)
}

dependencies {
    // Enables java.time on older Android runtimes, required by
    // flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
