import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // Firebase (FCM): reads android/app/google-services.json. Must be applied after
    // the Android Gradle plugin and before the Flutter plugin.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from android/key.properties when it exists.
// This file is intentionally NOT committed (see android/.gitignore) and must be
// created by the app owner — see android/key.properties.example for the format
// and the keystore-generation command. When the file is absent (e.g. on CI, a
// fresh clone, or any developer machine) DEBUG builds keep working, but a
// RELEASE build is refused rather than being debug-signed (SEC-2 fail-closed —
// see the buildTypes.release signingConfig and the task-graph guard below).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.akshara.erp.akshara_erp"
    // Pinned explicitly (not inherited from the Flutter default) so the Play
    // target-API floor is statically verifiable in-repo. compileSdk/targetSdk 36
    // are above Google Play's API-35 minimum for app updates; minSdk 24 is the
    // Flutter floor and satisfies firebase_core/messaging (FCM push).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.akshara.erp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    signingConfigs {
        // Only declare a "release" signing config when a real keystore is present.
        // Without this guard a missing storeFile would break the build for everyone.
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Use the owner's upload/release keystore when android/key.properties
            // exists. SEC-2: NEVER fall back to debug signing for a release build —
            // leave it unsigned when no release keystore is present so a
            // debug-signed release can never be produced. The task-graph guard
            // below turns this into a hard build failure for any release assembly.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                null
            }

            // R8: shrink + obfuscate Java/Kotlin bytecode and strip unused resources
            // to keep the Play Store APK/AAB small. Keep rules live in
            // android/app/proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// SEC-2 fail-closed guard: refuse to assemble/bundle a RELEASE artifact unless a
// real release keystore (android/key.properties) is present, so no release build
// is ever debug-signed or shipped unsigned. Only fires when a release-packaging
// task is actually scheduled — debug builds are unaffected.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        val n = task.name
        n.contains("Release") &&
            (n.startsWith("assemble") || n.startsWith("bundle") || n.startsWith("package"))
    }
    if (buildingRelease && !hasReleaseKeystore) {
        throw GradleException(
            "Refusing to build a release without android/key.properties (a real " +
                "release keystore). Debug-signing or shipping an unsigned release is " +
                "forbidden (SEC-2). Provide the keystore or build a debug variant.",
        )
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

dependencies {
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
