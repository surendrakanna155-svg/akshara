# Akshara ERP — R8 / ProGuard keep rules for release builds.
# Active because build.gradle.kts sets isMinifyEnabled = true for the release
# build type. Keep this list conservative: only suppress/keep what the app and
# its plugins actually need so we do not strip classes loaded via reflection or
# the platform-channel/JNI boundary.

# ---------------------------------------------------------------------------
# Flutter engine + embedding (loaded via JNI / reflection from native code).
# ---------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ---------------------------------------------------------------------------
# Plugins in pubspec.yaml.
#  - flutter_secure_storage: AndroidX security crypto / Tink keysets.
#  - printing / pdf: uses the Android print framework + PdfDocument bridge.
#  - url_launcher, shared_preferences, qr_flutter, dio: no special rules
#    needed (pure-Dart or standard platform channels) but listed for clarity.
# ---------------------------------------------------------------------------

# flutter_secure_storage relies on Google Tink + AndroidX security-crypto.
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.annotations.**

# printing plugin (net.nfet.flutter.printing) bridges to the platform print APIs.
-keep class net.nfet.flutter.printing.** { *; }
-dontwarn net.nfet.flutter.printing.**

# ---------------------------------------------------------------------------
# General safety nets.
# ---------------------------------------------------------------------------
# Keep annotations (used by some plugins for reflective lookups / Tink).
-keepattributes *Annotation*
# Keep enclosing-method / signature metadata so generics + inner classes used
# via reflection (e.g. Tink, kotlin metadata) resolve correctly.
-keepattributes Signature,InnerClasses,EnclosingMethod

# Kotlin runtime metadata.
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Suppress warnings for optional Play Core split-install classes that the
# Flutter deferred-components stub references but the app does not bundle.
-dontwarn com.google.android.play.core.**
