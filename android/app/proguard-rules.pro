# © Flatra Tech Ltd. All rights reserved.
# Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
# Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
# Contact: +2349025975247

# R8 / ProGuard keep rules for SafeDepot Pro.
#
# Kept deliberately small. The Android Gradle Plugin (via the Flutter Gradle
# Plugin) already keeps the Flutter embedding and plugin-registration classes;
# the rules below cover only what those do not, and each carries a reason.

# ---------------------------------------------------------------------------
# Flutter embedding
# ---------------------------------------------------------------------------
# Registered reflectively and referenced from the merged AndroidManifest. R8
# must not rename or strip these.
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# The integrity method channel resolves MainActivity from the manifest.
-keep class com.clintoniwoloma.safedepot_pro.MainActivity { *; }

# ---------------------------------------------------------------------------
# Plugins used by this app
# ---------------------------------------------------------------------------
# flutter_secure_storage — AndroidX Security (EncryptedSharedPreferences,
# MasterKey). The crypto provider classes are looked up by name.
-keep class androidx.security.crypto.** { *; }

# image_picker — resolves ContentProvider authority and FileProvider paths
# declared in the manifest, which R8 cannot see.
-keep class androidx.core.content.FileProvider { *; }

# package_info_plus — reads PackageInfo by reflection across SDK levels.
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# connectivity_plus / path_provider — method-channel plugins whose registrant
# classes are reflection-instantiated.
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# ---------------------------------------------------------------------------
# Shorebird (code push)
# ---------------------------------------------------------------------------
# Shorebird's updater is invoked from Dart through a method channel and
# reflects on its own engine classes. Obfuscating these breaks patch
# application, so they are kept.
-keep class com.shorebird.android.** { *; }
-keep interface com.shorebird.android.** { *; }

# ---------------------------------------------------------------------------
# Crash/stack-trace readability
# ---------------------------------------------------------------------------
# Line numbers so a symbolised crash report points at real source lines, with
# SourceFile renamed to hide nothing meaningful.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ---------------------------------------------------------------------------
# Explicitly NOT kept
# ---------------------------------------------------------------------------
# Decidedly nothing else. Kotlin metadata is stripped by R8 with
# `isMinifyEnabled`, so reflection-based libraries that later need it can be
# handled by adding a rule here, with a comment, rather than by keeping whole
# packages by default.

# ---------------------------------------------------------------------------
# Flutter deferred components
# ---------------------------------------------------------------------------
# The Flutter engine references the Play Core deferred-components API, which is
# only present when the corresponding library is on the classpath. Without these
# warnings suppressed, R8 treats the absent classes as a hard failure rather
# than a normal optional dependency.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
-dontwarn io.flutter.app.FlutterPlayStoreSplitApplication
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
